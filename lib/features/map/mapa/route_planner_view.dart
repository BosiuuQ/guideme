
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'active_navigation_view.dart';

class RoutePlannerView extends StatefulWidget {
  final mb.LatLng origin;
  final mb.LatLng destination;
  final String title;

  const RoutePlannerView({
    Key? key,
    required this.origin,
    required this.destination,
    required this.title,
  }) : super(key: key);

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  // PointAnnotationManager used to add symbols above line layers
  dynamic _pointManager; // will be set to the platform-specific PointAnnotationManager

  static const String _mapboxToken = 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg';
  bool _loading = true;
  String? _error;
  double? _distanceMeters;
  double? _durationSeconds;
  List<List<double>> _coords = [];

  mb.MapboxMapController? _controller;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    setState(() { _loading = true; _error = null; });
    try {
      final origin = '${widget.origin.longitude},${widget.origin.latitude}';
      final dest = '${widget.destination.longitude},${widget.destination.latitude}';
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$origin;$dest?geometries=geojson&overview=full&access_token=$_mapboxToken';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        setState(() { _error = 'Błąd serwera: ${res.statusCode}'; _loading = false; });
        return;
      }
      final j = json.decode(res.body) as Map<String,dynamic>;
      final routes = j['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        setState(() { _error = 'Brak trasy'; _loading = false; });
        return;
      }
      final r = routes[0] as Map<String,dynamic>;
      _distanceMeters = (r['distance'] as num?)?.toDouble();
      _durationSeconds = (r['duration'] as num?)?.toDouble();
      final geom = r['geometry'] as Map<String,dynamic>?;
      final coords = (geom?['coordinates'] as List<dynamic>?)?.map((e) {
        return [(e[1] as num).toDouble(), (e[0] as num).toDouble()];
      }).toList();
      _coords = coords != null ? List<List<double>>.from(coords) : [];
      setState(() { _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToRoute();
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fitMapToRoute() async {
    if (_controller == null || _coords.isEmpty) return;
    try {
      double minLat = _coords.first[0], maxLat = _coords.first[0];
      double minLng = _coords.first[1], maxLng = _coords.first[1];
      for (final c in _coords) {
        final lat = c[0], lng = c[1];
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
      final centerLat = (minLat + maxLat) / 2.0;
      final centerLng = (minLng + maxLng) / 2.0;
      // Compute zoom based on route distance if available, otherwise fallback to span-based heuristic.
      double zoom = 14.0;
      if (_distanceMeters != null && _distanceMeters! > 0) {
        final km = _distanceMeters! / 1000.0;
        // Log-scale formula: zoom decreases with distance. Tunable parameters:
        // maxZoom: zoom for very short trips, minZoom: for very long trips, scale controls falloff.
        const double maxZoom = 16.0;
        const double minZoom = 4.0;
        const double scale = 4.0;
        final double log10 = math.log(km + 1) / math.ln10;
        zoom = maxZoom - scale * log10;
        if (zoom < minZoom) zoom = minZoom;
        if (zoom > maxZoom) zoom = maxZoom;
      } else {
        // fallback to previous span heuristic
        final latSpan = (maxLat - minLat).abs();
        final lngSpan = (maxLng - minLng).abs();
        final span = latSpan > lngSpan ? latSpan : lngSpan;
        if (span < 0.002) zoom = 16.5;
        else if (span < 0.01) zoom = 14.5;
        else if (span < 0.05) zoom = 12.5;
        else if (span < 0.3) zoom = 10.5;
      }
      _controller!.moveCameraImmediate(mb.LatLng(centerLat, centerLng), zoom);

      try {

        // ➕ tu poprawka: async/await działa prawidłowo
        final lineCoords = _coords.map((c) => mb.LatLng(c[0], c[1])).toList();
        await _controller!.addEmissiveLine(
          mb.LineOptions(
            geometry: lineCoords,
            lineColor: '#FF0092d2', // neon cyan (AARRGGBB)
            lineWidth: 6.0,
          ),
          emissiveStrength: 1.5, // zwiększ jeśli chcesz jeszcze jaśniej
          layerId: 'route_emissive_line',
        );

      _controller!.addSymbol(mb.SymbolOptions(
        geometry: widget.origin,
        iconImage: 'assets/icons/marker.png',
        iconSize: 0.15,
      ));
      _controller!.addSymbol(mb.SymbolOptions(
        geometry: widget.destination,
        iconImage: 'assets/icons/dest_pin.png',
        iconSize: 0.22,
      ));
      } catch (e) {
        debugPrint('Error while adding symbols/line: $e');
      }
    } catch (e) {
      debugPrint('Error in _fitMapToRoute: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Błąd: $_error'))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.black87,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trasa', style: TextStyle(color: Colors.white70)),
                              Text('${_formatDistance(_distanceMeters ?? 0)} • ${_formatDuration(_durationSeconds ?? 0)}',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveNavigationView(
                                origin: widget.origin,
                                destination: widget.destination,
                                title: widget.title,
                                routeCoords: _coords,
                                durationSeconds: _durationSeconds ?? 0.0,
                              )));
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Rozpocznij'),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            mb.MapboxMap(
                              accessToken: _mapboxToken,
                              initialCameraPosition: mb.CameraPosition(target: widget.origin, zoom: 14.0),
                              onMapCreated: (c) {
                                _controller = c;
                                _fitMapToRoute();
                                // Try to add route as line via controller if available
                                try {
                                  // many shims expose addLine or addPolyline; attempt common variants
                                  final coordsForController = _coords.map((c) => mb.LatLng(c[0], c[1])).toList();
                                  /* native addLine removed */
                                  /* native addPolyline removed */
                                } catch (e) {}
                              },
                              myLocationEnabled: false,
                              trackCameraPosition: false,
                              onStyleLoadedCallback: () {},
                            ),
                            // overlay a quick static preview of the route while the map style loads or if adding native line fails
                            // route overlay removed - using native polylines
          
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop({'distance': _distanceMeters, 'duration': _durationSeconds});
                            },
                            child: const Text('Zakończ'),
                          )),
                        ],
                      ),
                    )
                  ],
                ),
    );
  }

  String _formatDistance(double m) {
    if (m >= 1000) return '${(m/1000).toStringAsFixed(1)} km';
    return '${m.toStringAsFixed(0)} m';
  }

  String _formatDuration(double s) {
    final mins = (s/60).round();
    if (mins >= 60) return '${(mins/60).floor()}h ${mins%60}m';
    return '${mins} min';
  }
}


/// Overlay painter which paints a scaled route over the map widget's area.
/// This is a static overlay (doesn't track map panning/zoom), but gives immediate visual feedback.
class RoutePainterOverlay extends StatelessWidget {
  final List<List<double>> coords;
  const RoutePainterOverlay({required this.coords, super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoutePainter(coords: coords),
      child: Container(),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<List<double>> coords;
  _RoutePainter({required this.coords});

  @override
  void paint(Canvas canvas, Size size) {
    if (coords.isEmpty) return;
    double minLat = coords.first[0], maxLat = coords.first[0];
    double minLng = coords.first[1], maxLng = coords.first[1];
    for (final c in coords) {
      final lat = c[0], lng = c[1];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    final latRange = (maxLat - minLat) != 0 ? (maxLat - minLat) : 0.0001;
    final lngRange = (maxLng - minLng) != 0 ? (maxLng - minLng) : 0.0001;
    final pad = 12.0;
    final scaleX = (size.width - pad*2) / lngRange;
    final scaleY = (size.height - pad*2) / latRange;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = (size.width - ((lngRange)*scale))/2;
    final offsetY = (size.height - ((latRange)*scale))/2;
    final paintLine = Paint()..style = PaintingStyle.stroke..strokeWidth = 4.0..color = Color(0xFF3B82F6).withOpacity(0.9);
    final paintOrigin = Paint()..style = PaintingStyle.fill..color = Color(0xFF10B981);
    final paintDest = Paint()..style = PaintingStyle.fill..color = Color(0xFFEF4444);

    Path path = Path();
    for (var i=0;i<coords.length;i++) {
      final lat = coords[i][0];
      final lng = coords[i][1];
      final x = offsetX + ((lng - minLng) * scale);
      final y = offsetY + ((maxLat - lat) * scale);
      if (i==0) path.moveTo(x,y); else path.lineTo(x,y);
    }
    canvas.drawPath(path, paintLine);
    final o = coords.first;
    final ox = offsetX + ((o[1] - minLng) * scale);
    final oy = offsetY + ((maxLat - o[0]) * scale);
    canvas.drawCircle(Offset(ox,oy), 6, paintOrigin);
    final d = coords.last;
    final dx = offsetX + ((d[1] - minLng) * scale);
    final dy = offsetY + ((maxLat - d[0]) * scale);
    canvas.drawCircle(Offset(dx,dy), 6, paintDest);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.coords != coords;
  }
}
