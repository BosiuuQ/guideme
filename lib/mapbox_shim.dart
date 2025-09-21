// mapbox_shim.dart - lightweight shim that wraps mapbox_maps_flutter
// Provides a small subset of the API used by the project (LatLng, CameraPosition,
// MapboxMap widget and a MapboxMapController with simple symbol and camera helpers).
//
// NOTE: This is not a complete drop-in replacement for the previous shim; it aims
// to cover the calls used across the app (addSymbol, updateSymbolImmediate,
// moveCameraImmediate, basic line support). You may need to expand it for full parity.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as native;

/// Simple LatLng struct used throughout the app.
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

/// CameraPosition equivalent used by the app.
class CameraPosition {
  final LatLng target;
  final double zoom;
  final double bearing;
  final double tilt; // kept for compatibility
  const CameraPosition({required this.target, required this.zoom, this.bearing = 0.0, this.tilt = 0.0});
}

/// SymbolOptions and Symbol models (very small subset).
class SymbolOptions {
  final LatLng geometry;
  final String? iconImage; // asset path to an image
  final double? rotation;
  const SymbolOptions({required this.geometry, this.iconImage, this.rotation});
}

class Symbol {
  final String id;
  LatLng geometry;
  Symbol(this.id, this.geometry);
}

/// LineOptions / Line model (minimal)
class LineOptions {
  final List<LatLng> geometry;
  final double? lineWidth;
  final String? lineColor;
  LineOptions({required this.geometry, this.lineWidth, this.lineColor});
}
class Line {
  final String id;
  final List<LatLng> geometry;
  final double? lineWidth;
  final String? lineColor;
  Line({required this.id, required this.geometry, this.lineWidth, this.lineColor});
}

/// MapboxMapController - wraps native MapboxMap and basic annotation managers.
class MapboxMapController {
  final native.MapboxMap _mapboxMap;
  native.PointAnnotationManager? _pointManager;
  native.PolylineAnnotationManager? _lineManager;
  int _symbolCounter = 0;
  int _lineCounter = 0;

  // local cache of symbols/lines
  final Map<String, Symbol> _symbols = {};
  final Map<String, Line> _lines = {};

  // basic camera state cached for compatibility
  double _bearing = 0.0;
  double _tilt = 0.0;
  double get bearing => _bearing;
  double get tilt => _tilt;

  MapboxMapController(this._mapboxMap);

  /// Call after map creation to initialize annotation managers.
  Future<void> initManagers() async {
    try {
      _pointManager = await _mapboxMap.annotations.createPointAnnotationManager();
    } catch (_) {}
    try {
      _lineManager = await _mapboxMap.annotations.createPolylineAnnotationManager();
    } catch (_) {}
    // Do not attempt to call non-existent getCamera() method here; leave camera state at defaults.
  }

  Future<Symbol> addSymbol(SymbolOptions options) async {
    _symbolCounter += 1;
    final id = 'sym_$_symbolCounter';
    // create PointAnnotationOptions
    try {
      Uint8List? imageBytes;
      if (options.iconImage != null) {
        final bd = await rootBundle.load(options.iconImage!);
        imageBytes = bd.buffer.asUint8List();
      }
      final nativeOptions = native.PointAnnotationOptions(
        geometry: native.Point(coordinates: native.Position(options.geometry.longitude, options.geometry.latitude)),
        image: imageBytes,
        // iconSize: options.rotation != null ? 1.0 : null,
      );
      final created = await _pointManager?.create(nativeOptions);
      // created may contain an id; we still return our local Symbol
    } catch (e) {
      // fallback: ignore native creation issues
    }
    final sym = Symbol(id, options.geometry);
    _symbols[id] = sym;
    return sym;
  }

  Future<void> updateSymbolImmediate(Symbol symbol, LatLng newPos) async {
    // Update native annotation if possible; if not, update local cache.
    try {
      // naive approach: delete & recreate native annotation matching geometry
      // (no mapping between native id and our id is kept here)
      await _pointManager?.deleteAll();
      // recreate all symbols with updated positions
      for (final s in _symbols.entries) {
        final pos = s.value.geometry;
        final nativeOptions = native.PointAnnotationOptions(
          geometry: native.Point(coordinates: native.Position(pos.longitude, pos.latitude)),
        );
        await _pointManager?.create(nativeOptions);
      }
    } catch (_) {}
    symbol.geometry = newPos;
    _symbols[symbol.id] = symbol;
  }

  Future<void> moveCameraImmediate(LatLng target, double zoom) async {
    try {
      final cam = native.CameraOptions(center: native.Point(coordinates: native.Position(target.longitude, target.latitude)), zoom: zoom);
      await _mapboxMap.setCamera(cam);
      try { _bearing = cam.bearing ?? _bearing; } catch(_) {}
      try { _tilt = cam.pitch ?? _tilt; } catch(_) {}
    } catch (_) {}
  }

  /// Smooth move with optional duration in milliseconds
  Future<void> moveCamera(LatLng target, {double? zoom, int ms = 300}) async {
    try {
      final cam = native.CameraOptions(center: native.Point(coordinates: native.Position(target.longitude, target.latitude)), zoom: zoom);
      await _mapboxMap.flyTo(cam, native.MapAnimationOptions(duration: ms));
      try { _bearing = cam.bearing ?? _bearing; } catch(_) {}
      try { _tilt = cam.pitch ?? _tilt; } catch(_) {}
    } catch (_) {}
  }

  Future<Line> addLine(LineOptions options) async {
    _lineCounter += 1;
    final id = 'line_$_lineCounter';
    final line = Line(id: id, geometry: options.geometry, lineWidth: options.lineWidth, lineColor: options.lineColor);
    _lines[id] = line;
    // try to create polyline on native map (best-effort)
    try {
      final pts = options.geometry.map((p) => native.Position(p.longitude, p.latitude)).toList();
      final lineString = native.LineString(coordinates: pts);
      final polylineOptions = native.PolylineAnnotationOptions(geometry: lineString);
      await _lineManager?.create(polylineOptions);
    } catch (_) {}
    return line;
  }
}

/// MapboxMap widget - wraps native MapWidget and exposes a simpler API.
class MapboxMap extends StatefulWidget {
  final CameraPosition initialCameraPosition;
  final String? accessToken;
  final void Function(MapboxMapController)? onMapCreated;
  final void Function(LatLng)? onTap;
  final bool myLocationEnabled;
  final bool trackCameraPosition;
  final VoidCallback? onStyleLoadedCallback;
  final bool zoomGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
  final String? styleString;
  final String? styleUri;

  const MapboxMap({
    Key? key,
    required this.initialCameraPosition,
    this.accessToken,
    this.onMapCreated,
    this.onTap,
    this.myLocationEnabled = false,
    this.trackCameraPosition = false,
    this.onStyleLoadedCallback,
    this.zoomGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.styleString,
    this.styleUri,
  }) : super(key: key);

  @override
  State<MapboxMap> createState() => _MapboxMapState();
}

class _MapboxMapState extends State<MapboxMap> {
  MapboxMapController? _controller;
  native.MapboxMap? _nativeMap;

  @override
  Widget build(BuildContext context) {
    final tok = (widget.accessToken ?? '').trim();
    if (tok.isNotEmpty) {
      // set access token globally if available
      try {
        native.MapboxOptions.setAccessToken(tok);
      } catch (_) {}
    }
    final cam = native.CameraOptions(
      center: native.Point(coordinates: native.Position(widget.initialCameraPosition.target.longitude, widget.initialCameraPosition.target.latitude)),
      zoom: widget.initialCameraPosition.zoom,
      bearing: widget.initialCameraPosition.bearing,
      pitch: widget.initialCameraPosition.tilt,
    );
    return native.MapWidget(
      key: const ValueKey('mapWidget'),
      cameraOptions: cam,
      styleUri: widget.styleUri ?? '',
      onTapListener: (dynamic ctx) {
        try {
          final coords = ctx?.point?.coordinates;
          if (coords != null) {
            // coords typically have fields 'lat' and 'lng' or 'y' and 'x'
            double? lat;
            double? lng;
            try { lat = coords.lat as double; lng = coords.lng as double; } catch (_) {}
            try { lat = coords.y as double; lng = coords.x as double; } catch (_) {}
            if (lat != null && lng != null) {
              widget.onTap?.call(LatLng(lat, lng));
            }
          }
        } catch (_) {}
      },
      onMapCreated: (native.MapboxMap mapboxMap) async {
        _nativeMap = mapboxMap;
        final ctrl = MapboxMapController(mapboxMap);
        await ctrl.initManagers();
        _controller = ctrl;
        widget.onMapCreated?.call(ctrl);
        widget.onStyleLoadedCallback?.call();
      },
    );
  }
}
