import 'dart:math';

import 'package:flutter/material.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'map_logic_handler.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/presentation/widgets/app_drawer_widget.dart';
import 'mapbox_navigation_bridge.dart' as _mb;

class ActiveNavigationView extends StatefulWidget {
  final mb.LatLng origin;
  final mb.LatLng destination;
  final String title;
  final List<List<double>> routeCoords; // [[lat, lng], ...]
  final double? durationSeconds;

  const ActiveNavigationView({
    Key? key,
    required this.origin,
    required this.destination,
    required this.title,
    required this.routeCoords,
    this.durationSeconds,
  }) : super(key: key);

  @override
  State<ActiveNavigationView> createState() => _ActiveNavigationViewState();
}

class _ActiveNavigationViewState extends State<ActiveNavigationView> with SingleTickerProviderStateMixin {
  late MapLogicHandler _mapLogic;
  // --- navigation hint state (computed from routeCoords + current position) ---
  String? _nextNavInstruction;
  double? _distanceToNextManeuverMeters;
  int _navComputeCounter = 0; // simple throttle for heavy computation

  double _speedKmh = 0.0;
  double _bearing = 0.0;
  bool _lineAdded = false;

  final GlobalKey _bottomKey = GlobalKey();
  double _bottomWidgetHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _mapLogic = MapLogicHandler();
    _mapLogic.tickerProvider = this;
    _mapLogic.onUpdate = () {
      try {
        final v = _mapLogic.currentSpeedKmh;
        final b = _mapLogic.currentBearing;
        if (mounted) {
          setState(() {
            _speedKmh = double.parse(v.toStringAsFixed(1));
            _bearing = b;
          });
        }
      } catch (e) {}
    
      // update navigation hints (next instruction + distance)
      try { _updateNavigationHints(); } catch (e) {}
};
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomWidget());

    _mapLogic.start();
    try {
      if (widget.routeCoords.isNotEmpty) {
        _mb.MapboxNavigationBridge.startNavigation(widget.routeCoords);
      }
    } catch (e) {}

  }

  @override
  void dispose() {
    _mapLogic.dispose();
    super.dispose();
  }

  Future<void> _addRouteLineIfNeeded() async {
    if (_lineAdded) return;
    final ctrl = _mapLogic.controller;
    if (ctrl == null) return;
    final coords = widget.routeCoords;
    if (coords.isEmpty) return;
    try {
      final lineCoords = coords.map((c) => mb.LatLng(c[0], c[1])).toList();
      await ctrl.addEmissiveLine(
        mb.LineOptions(
          geometry: lineCoords,
          lineColor: '#FF00FFFF', // neon cyan (AARRGGBB)
          lineWidth: 6.0,
        ),
        emissiveStrength: 2.5, // zwiększ jeśli chcesz jeszcze jaśniej
        layerId: 'route_emissive_line',
      );
      _lineAdded = true;
    } catch (e) {
      debugPrint('Error while adding navigation line: $e');
    }
  }

  void _measureBottomWidget() {
    try {
      final ctx = _bottomKey.currentContext;
      if (ctx != null) {
        final size = ctx.size;
        if (size != null) {
          final h = size.height;
          if (h != _bottomWidgetHeight) {
            setState(() {
              _bottomWidgetHeight = h;
            });
          }
        }
      }
    } catch (e) {}
  }

  Widget _buildMap() {
    return mb.MapboxMap(scrollGesturesEnabled: false, /*scroll-inserted*/

      accessToken: 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg',
      initialCameraPosition: mb.CameraPosition(target: widget.origin, zoom: 18, bearing: 0.0, tilt: 75.0),
      onMapCreated: (controller) async {
        _mapLogic.onMapCreated(controller);
        WidgetsBinding.instance.addPostFrameCallback((_) => _addRouteLineIfNeeded());
      },
      myLocationEnabled: false,
      trackCameraPosition: true,
      onStyleLoadedCallback: () {
        WidgetsBinding.instance.addPostFrameCallback((_) => _addRouteLineIfNeeded());
      },
    );
  }

  

  // ---------------- Navigation hint helpers ----------------
  // Haversine distance in meters
  double _haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // metres
    final phi1 = lat1 * (3.141592653589793 / 180.0);
    final phi2 = lat2 * (3.141592653589793 / 180.0);
    final dphi = (lat2 - lat1) * (3.141592653589793 / 180.0);
    final dlambda = (lon2 - lon1) * (3.141592653589793 / 180.0);
    final a = (sin(dphi/2) * sin(dphi/2)) + (cos(phi1) * cos(phi2) * sin(dlambda/2) * sin(dlambda/2));
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  double _deg2rad(double d) => d * (3.141592653589793 / 180.0);
  double _rad2deg(double r) => r * (180.0 / 3.141592653589793);

  // bearing from point A to B in degrees (0..360)
  double _computeBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _deg2rad(lat1);
    final phi2 = _deg2rad(lat2);
    final lambda1 = _deg2rad(lon1);
    final lambda2 = _deg2rad(lon2);
    final y = sin(lambda2 - lambda1) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(lambda2 - lambda1);
    var brng = (_rad2deg(atan2(y, x)) + 360.0) % 360.0;
    return brng;
  }

  // project point P onto segment AB, return the closest point and t [0..1]
  Map<String, dynamic> _projectOnSegment(double plat, double plon, double alat, double alon, double blat, double blon) {
    // convert to Cartesian (approx) using simple equirectangular projection around A
    final latRad = _deg2rad(plat);
    final latA = _deg2rad(alat);
    final latB = _deg2rad(blat);
    final xA = alon * cos(latRad);
    final xB = blon * cos(latRad);
    final xP = plon * cos(latRad);
    final yA = alat;
    final yB = blat;
    final yP = plat;
    final dx = xB - xA;
    final dy = yB - yA;
    final len2 = dx*dx + dy*dy;
    double t = 0.0;
    if (len2 > 1e-9) {
      t = ((xP - xA)*dx + (yP - yA)*dy) / len2;
      if (t < 0.0) t = 0.0;
      if (t > 1.0) t = 1.0;
    }
    final cx = xA + dx * t;
    final cy = yA + dy * t;
    // convert back approx to lat/lon
    final closestLat = cy;
    final closestLon = cx / cos(latRad);
    return {'lat': closestLat, 'lon': closestLon, 't': t};
  }

  // find next maneuver along the route given current position
  void _updateNavigationHints() {
    // throttle a bit to avoid heavy computation every frame
    _navComputeCounter = (_navComputeCounter + 1) % 3;
    if (_navComputeCounter != 0) return;

    final disp = _mapLogic.displayPosition;
    if (disp == null) return;
    final plat = disp.latitude;
    final plon = disp.longitude;

    final coords = widget.routeCoords;
    if (coords.isEmpty) {
      setState(() { _nextNavInstruction = null; _distanceToNextManeuverMeters = null; });
      return;
    }

    // find nearest segment along route
    double bestDist = double.infinity;
    int bestSeg = 0;
    double bestT = 0.0;
    for (int i = 0; i < coords.length - 1; i++) {
      final a = coords[i];
      final b = coords[i+1];
      final proj = _projectOnSegment(plat, plon, a[0], a[1], b[0], b[1]);
      final d = _haversineDistanceMeters(plat, plon, proj['lat'], proj['lon']);
      if (d < bestDist) {
        bestDist = d;
        bestSeg = i;
        bestT = proj['t'];
      }
    }

    // look ahead along route to find a significant heading change
    const angleThreshold = 30.0; // degrees to consider a turn
    int lookIndex = bestSeg;
    double accumulatedDist = 0.0;
    double lastBearing = _computeBearing(coords[bestSeg][0], coords[bestSeg][1], coords[bestSeg+1][0], coords[bestSeg+1][1]);
    bool found = false;
    double foundDist = 0.0;
    String instr = "Continue";
    for (int i = bestSeg; i < coords.length - 1; i++) {
      final a = coords[i];
      final b = coords[i+1];
      final br = _computeBearing(a[0], a[1], b[0], b[1]);
      if (i > bestSeg) {
        final diff = ((br - lastBearing + 540) % 360) - 180; // -180..180
        final absdiff = diff.abs();
        if (absdiff >= angleThreshold) {
          // turn detected at segment i
          found = true;
          // distance from current position to point a
          foundDist = _haversineDistanceMeters(plat, plon, a[0], a[1]) + accumulatedDist;
          if (diff > 0) instr = "Turn right";
          else instr = "Turn left";
          break;
        }
      }
      accumulatedDist += _haversineDistanceMeters(a[0], a[1], b[0], b[1]);
      lastBearing = br;
    }

    // if not found, set arrive if close to end
    final end = coords.last;
    final distToEnd = _haversineDistanceMeters(plat, plon, end[0], end[1]);
    if (!found && distToEnd < 40.0) {
      instr = "Arrive at destination";
      foundDist = distToEnd;
      found = true;
    }

    // if still not found, set next instruction as continue and distance to end of route segment
    if (!found) {
      instr = "Continue";
      // distance to end of the route
      foundDist = distToEnd;
    }

    setState(() {
      _nextNavInstruction = instr;
      _distanceToNextManeuverMeters = foundDist;
    });
  }

String _formatArrival() {
    final ds = widget.durationSeconds ?? 0.0;
    final arrival = DateTime.now().toLocal().add(Duration(seconds: ds.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _minutesLeft() {
    final ds = widget.durationSeconds ?? 0.0;
    final mins = (ds / 60.0).round();
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomWidget());
    final double overlayBottom = (_bottomWidgetHeight > 0) ? _bottomWidgetHeight + 20.0 : 100.0;

    return Scaffold(
      endDrawer: const AppDrawerWidget(),
      appBar: AppBar(
        centerTitle: false,
        leadingWidth: 0,
        title: Image.asset(
          AppAssets.logoImg,
          width: 100.0,
          height: 100.0,
          alignment: AlignmentDirectional.centerStart,
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),

          // crosshair marker
          Center(
            child: IgnorePointer(
              child: SizedBox(
                width: 58.0,
                height: 58.0,
                child: Image.asset('assets/icons/marker.png', fit: BoxFit.contain),
              ),
            ),
          ),

          // Top instructions bar - flush with bottom of AppBar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Material(
              elevation: 6,
              color: Colors.black87,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.navigation, color: Colors.white, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Następny manewr', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          SizedBox(height: 6),
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

                          Text('Skręć w prawo za 200 m', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Speedometer
          // Navigation hint card
          Positioned(
            left: 16,
            right: 16,
            bottom: overlayBottom + 110,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 250),
              opacity: (_nextNavInstruction == null) ? 0.0 : 1.0,
              child: _nextNavInstruction == null ? SizedBox.shrink() : Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text(_nextNavInstruction ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      if (_distanceToNextManeuverMeters != null) Text('${_distanceToNextManeuverMeters!.round()} m', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: overlayBottom,
            child: Material(
              elevation: 6,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_speedKmh.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('km/h', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          // 'Zakończ' button
          Positioned(
            left: 20,
            bottom: overlayBottom,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
                  border: Border.all(color: Colors.red.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.close, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Zakończ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          // Bottom info widget
          // Bottom info widget
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Material(
                key: _bottomKey,
                elevation: 12,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.black87,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start, // <<< dociąga tekst do góry
                        children: [
                          const Text('Przewidywany czas przybycia',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(_formatArrival(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.start, // <<< to samo po prawej
                        children: [
                          const Text('Pozostało',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(_minutesLeft(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}