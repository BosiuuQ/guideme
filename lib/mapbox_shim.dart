// mapbox_shim.dart - expanded shim to satisfy mapbox_gl API usage in project
import 'package:flutter/material.dart';
import 'dart:typed_data';

// Basic LatLng compatible with mapbox_gl usage
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

// CameraPosition similar API
class CameraPosition {
  final LatLng target;
  final double zoom;
  final double bearing;
  final double tilt;
  const CameraPosition({required this.target, this.zoom = 12.0, this.bearing = 0.0, this.tilt = 0.0});
}

// CameraUpdate placeholder (compat) - holds either a CameraPosition or a LatLng
class CameraUpdate {
  final CameraPosition? position;
  final LatLng? latLng;
  CameraUpdate._({this.position, this.latLng});
  static CameraUpdate newCameraPosition(CameraPosition p) => CameraUpdate._(position: p);
  static CameraUpdate newLatLng(LatLng p) => CameraUpdate._(latLng: p);
  static CameraUpdate newLatLngBounds(dynamic b, double padding) => CameraUpdate._();
}

// SymbolOptions and Symbol simple implementations
class Symbol {
  final String id;
  LatLng? geometry;
  Map<String, dynamic> data = {};
  Symbol(this.id, {this.geometry});
}

class SymbolOptions {
  final LatLng geometry;
  final String? iconImage;
  final double? iconSize;
  final double? zIndex;
  final double? iconRotate;
  final Map<String,dynamic>? data;
  const SymbolOptions({required this.geometry, this.iconImage, this.iconSize, this.zIndex, this.iconRotate, this.data});
}

// Minimal Controller that supports addSymbol/updateSymbol and camera operations
class MapboxMapController {
  LatLng center;
  int _symbolIdCounter = 0;
  final Map<String, Symbol> _symbols = {};
  MapboxMapController(this.center);

  Future<void> animateCamera(dynamic update) async {
    if (update is CameraPosition) {
      center = update.target;
    } else if (update is CameraUpdate) {
      if (update.position != null) {
        center = update.position!.target;
      } else if (update.latLng != null) {
        center = update.latLng!;
      }
    }
    return;
  }

  Future<Symbol> addSymbol(SymbolOptions options) async {
    _symbolIdCounter += 1;
    final id = 'sym_${_symbolIdCounter}';
    final sym = Symbol(id, geometry: options.geometry);
    if (options.data != null) sym.data.addAll(options.data!);
    _symbols[id] = sym;
    return sym;
  }

  Future<void> updateSymbol(Symbol symbol, SymbolOptions options) async {
    symbol.geometry = options.geometry;
    if (options.data != null) symbol.data.addAll(options.data!);
    return;
  }

  // placeholder for removeSymbol
  Future<void> removeSymbol(Symbol symbol) async {
    _symbols.remove(symbol.id);
    return;
  }
}

typedef MapCreatedCallback = void Function(MapboxMapController controller);
typedef MapTapCallback = void Function(LatLng position);
typedef StyleLoadedCallback = void Function();

// MapboxMap widget - accepts many named parameters used elsewhere in project.
class MapboxMap extends StatefulWidget {
  final CameraPosition initialCameraPosition;
  final String? accessToken;
  final MapCreatedCallback? onMapCreated;
  final MapTapCallback? onTap;
  final bool myLocationEnabled;
  final bool trackCameraPosition;
  final StyleLoadedCallback? onStyleLoadedCallback;
  // accept common map options (kept for compatibility)
  final bool zoomGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
  final double? minMaxZoomPreferenceMin;
  final double? minMaxZoomPreferenceMax;

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
    this.minMaxZoomPreferenceMin,
    this.minMaxZoomPreferenceMax,
  }) : super(key: key);

  @override
  State<MapboxMap> createState() => _MapboxMapState();
}

class _MapboxMapState extends State<MapboxMap> {
  late MapboxMapController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller = MapboxMapController(widget.initialCameraPosition.target);
      widget.onMapCreated?.call(_controller);
      widget.onStyleLoadedCallback?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LatLng c = widget.initialCameraPosition.target;
    final double z = widget.initialCameraPosition.zoom;
    final size = MediaQuery.of(context).size;
    final int width = (size.width * MediaQuery.of(context).devicePixelRatio).clamp(200, 1280).toInt();
    final int height = (size.height * 0.4 * MediaQuery.of(context).devicePixelRatio).clamp(200, 1280).toInt();
    final token = widget.accessToken ?? '';
    final url = 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/' + '\${c.longitude},\${c.latitude},\${z}/' + '\${width}x\${height}?access_token=\${token}';

    return GestureDetector(
      onTapUp: (details) {
        if (widget.onTap != null) widget.onTap!(widget.initialCameraPosition.target);
      },
      child: Container(
        color: Colors.grey[200],
        height: size.height * 0.4,
        width: double.infinity,
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => Center(child: Text('Mapa nie mogła się załadować'))),
      ),
    );
  }
}

// Export commonly used names for convenience
class BitmapDescriptor {
  final Uint8List? bytes;
  const BitmapDescriptor._(this.bytes);
  static const BitmapDescriptor defaultMarker = BitmapDescriptor._(null);
  static BitmapDescriptor fromBytes(Uint8List b) => BitmapDescriptor._(b);
}

class MarkerId {
  final String value;
  const MarkerId(this.value);
}

class Marker {
  final MarkerId markerId;
  final LatLng position;
  final BitmapDescriptor icon;
  final double rotation;
  final Offset? anchor;
  final bool flat;
  final void Function()? onTap;
  const Marker({required this.markerId, required this.position, this.icon = BitmapDescriptor.defaultMarker, this.rotation = 0, this.anchor, this.flat = false, this.onTap});
}
