// mapbox_shim.dart - expanded shim to satisfy mapbox_gl API usage in project
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;



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
  final void Function(MapboxMapController)? onMapCreated;
  final void Function(LatLng)? onTap;
  final bool myLocationEnabled;
  final bool trackCameraPosition;
  final VoidCallback? onStyleLoadedCallback;
  final bool zoomGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
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
  }) : super(key: key);

  @override
  State<MapboxMap> createState() => _MapboxMapState();
}

class _MapboxMapState extends State<MapboxMap> {
  late MapboxMapController _controller;
  late fm.MapController _fmController;

  @override
  void initState() {
    super.initState();
    _controller = MapboxMapController(widget.initialCameraPosition.target);
    _fmController = fm.MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapCreated?.call(_controller);
      widget.onStyleLoadedCallback?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LatLng c = widget.initialCameraPosition.target;
    final double z = widget.initialCameraPosition.zoom;
    final token = (widget.accessToken ?? '').trim();

    final String urlTemplate;
    if (token.isEmpty) {
      urlTemplate = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    } else {
      urlTemplate = 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=${token}';
    }

    // Build marker list from controller symbols (use geometry if present)
    final List<fm.Marker> markers = _controller._symbols.values.where((s) => s.geometry != null).map((s) {
      final lat = s.geometry!.latitude;
      final lon = s.geometry!.longitude;
      return fm.Marker(
        point: ll.LatLng(lat, lon),
        width: 40,
        height: 40,
        // Use a simple Icon for markers; if you have custom icon bytes in s.data, you can extend this.
        child: GestureDetector(
          onTap: () {
            // If symbol has callback stored in data, try to call it (best-effort)
            try {
              final cb = s.data['onTap'];
              if (cb is Function) cb();
            } catch (e) {}
          },
          child: Container(
            alignment: Alignment.center,
            child: const Icon(Icons.location_on, size: 32),
          ),
        ),
      );
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      child: fm.FlutterMap(
        mapController: _fmController,
        options: fm.MapOptions(
          initialCenter: ll.LatLng(c.latitude, c.longitude),
          initialZoom: z,
          // interaction options left default
          onTap: (tapPosition, point) {
            if (widget.onTap != null) widget.onTap!(LatLng(point.latitude, point.longitude));
          },
          onPositionChanged: (pos, hasGesture) {
            if (widget.trackCameraPosition) {
              final center = pos.center;
              if (center != null) {
                _controller.center = LatLng(center.latitude, center.longitude);
              }
            }
          },
        ),
        children: [
          fm.TileLayer(
            urlTemplate: urlTemplate,
            subdomains: const ['a', 'b', 'c'],
            tileProvider: fm.NetworkTileProvider(),
            userAgentPackageName: 'com.example.guide_me',
          ),
          fm.MarkerLayer(
            markers: markers,
          ),
        ],
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