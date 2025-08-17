import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/map/mapa/navigation_instruction_bar.dart';
import 'package:guide_me/features/map/mapa/place_search_view.dart';
import 'package:guide_me/features/map/mapa/active_navigation_logic.dart';

class ActiveNavigationView extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng destination;
  final String destinationName;

  const ActiveNavigationView({
    super.key,
    required this.routePoints,
    required this.destination,
    required this.destinationName,
  });

  @override
  State<ActiveNavigationView> createState() => _ActiveNavigationViewState();
}

class _ActiveNavigationViewState extends State<ActiveNavigationView> {
  bool _arrivalShown = false;


  // Build two points that form a short perpendicular "finish line" at the end of the route.
  List<LatLng> _buildFinishLine(List<LatLng> route, {double halfLengthMeters = 12.0}) {
    if (route.length < 2) return [];
    final LatLng end = route.last;
    final LatLng prev = route[route.length - 2];

    // Local meter conversion at end latitude
    final double latRad = end.latitude * 3.141592653589793 / 180.0;
    final double mPerDegLat = 111320.0;
    final double mPerDegLon = 111320.0 * cos(latRad);

    double x(LatLng q) => (q.longitude - end.longitude) * mPerDegLon;
    double y(LatLng q) => (q.latitude - end.latitude) * mPerDegLat;
    LatLng latLng(double x, double y) => LatLng(
      end.latitude + (y / mPerDegLat),
      end.longitude + (x / mPerDegLon),
    );

    final double vx = x(end) - x(prev);
    final double vy = y(end) - y(prev);
    // Perpendicular vector (normalize)
    final double len = sqrt(vx * vx + vy * vy);
    double px = 0.0, py = 0.0;
    if (len > 0.0) {
      px = -vy / len;
      py = vx / len;
    }
    final LatLng p1 = latLng(px * halfLengthMeters, py * halfLengthMeters);
    final LatLng p2 = latLng(-px * halfLengthMeters, -py * halfLengthMeters);
    return [p1, p2];
  }

  Offset? _cursorScreenPosition;
  final double _haloSize = 42.0;
  final double _innerSize = 18.0;

  Timer? _cursorTimer;

  Future<void> _updateCursorScreenPosition() async {
    if (_logic.mapController == null || _logic.currentPosition == null) return;
    try {
      final screenCoord = await _logic.mapController!.getScreenCoordinate(_logic.currentPosition!);
      if (!mounted) return;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      setState(() {
        _cursorScreenPosition = Offset(screenCoord.x.toDouble() / dpr, screenCoord.y.toDouble() / dpr);
      });
      if (_cursorScreenPosition == null) {
        Future.delayed(const Duration(milliseconds: 200), () => _updateCursorScreenPosition());
      }
    } catch (e) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _updateCursorScreenPosition();
      });
    }
  }

  late NavigationLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = NavigationLogic(
      routePoints: widget.routePoints,
      destination: widget.destination,
      destinationName: widget.destinationName,
      onUpdate: () {
      if (mounted) setState(() {});
      _updateCursorScreenPosition();
      if (_logic.isNearDestination && !_arrivalShown) {
        _arrivalShown = true;
        _logic.stopNavigation();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.grey[850],
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.emoji_flags, color: Colors.green, size: 34),
                      SizedBox(width: 12),
                      Expanded(child: Text('Dojechałeś do celu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Trasa została ukończona. Możesz zakończyć nawigację lub wybrać kolejną trasę.', style: TextStyle(fontSize: 14),),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.grey[850],
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (_) => PlaceSearchSheet(currentLocation: _logic.currentPosition),
                            );
                          },
                          child: const Text('Wybierz następną trasę'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.goNamed(AppRoutes.mainView);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Zakończ nawigację'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      }
    },
      onRecalculated: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zmieniono trasę — przeliczono nową trasę')),
          );
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _logic.initLogic(context));
    // start periodic cursor updater
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _updateCursorScreenPosition());

  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _logic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_logic.hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF001E2D),
        body: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Niepoprawne dane trasy", style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
            target: widget.routePoints.first,
              zoom: 16,
            ),
            onMapCreated: (controller) { _logic.handleMapCreated(controller); _updateCursorScreenPosition(); },
            polylines: {
              // full planned route (faded)
              Polyline(
                polylineId: const PolylineId('full_route'),
                color: Colors.cyanAccent.withOpacity(0.6),
                width: 6,
                points: _logic.polylinePoints,
              ),
              // traversed route (darker)
              if (_logic.traversedPolylinePoints.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('traversed_route'),
                  color: Colors.blueGrey,
                  width: 8,
                  points: _logic.traversedPolylinePoints,
                ),
            

              // finish line when close to destination (~150 m)
              if (_logic.isNearDestination)
                Polyline(
                  polylineId: const PolylineId('finish_line'),
                  points: _buildFinishLine(_logic.polylinePoints),
                  color: Colors.grey.shade800,
                  width: 10,
                ),
},
            
            markers: {
              Marker(
                markerId: const MarkerId('destination'),
                position: widget.destination,
                infoWindow: InfoWindow(title: widget.destinationName),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            rotateGesturesEnabled: false,
            onCameraMove: (pos) => _updateCursorScreenPosition(),
            onCameraMoveStarted: () { _logic.notifyUserPanned(); },
            onCameraIdle: () { _logic.notifyProgrammaticIdle(); },
            compassEnabled: false,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          
),

          // Transparent listener overlay to detect user panning gestures without blocking the map.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                _logic.forceStopFollowingUser();
                setState(() {});
              },
            ),
          ),


          
Positioned(
            bottom: 180,
            right: 20,
            child: Visibility(
              visible: !_logic.followUser,
              child: ElevatedButton.icon(
                onPressed: () {
                  _logic.enableFollowUser();
                  setState(() {});
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Wycentruj'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoTile(Icons.timer, '${_logic.remainingDuration} min'),
                      _infoTile(Icons.pin_drop, '${_logic.remainingDistance.toStringAsFixed(1)} km'),
                      _infoTile(Icons.access_time, _logic.arrivalTime != null ? DateFormat('HH:mm').format(_logic.arrivalTime!) : '--:--'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => context.goNamed(AppRoutes.mainView),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text("Zakończ nawigację", style: TextStyle(color: Colors.grey[850], fontSize: 16)),
                  )
                ],
              ),
            ),
          ),
        
          
          

// Overlay cursor drawn above map labels (same visual as previous map circles).
          if (_logic.currentPosition != null) Positioned(
            left: (_cursorScreenPosition?.dx ?? (MediaQuery.of(context).size.width / 2)) - (_haloSize / 2),
            top: (_cursorScreenPosition?.dy ?? (MediaQuery.of(context).size.height / 2)) - (_haloSize / 2),
            child: IgnorePointer(
              child: SizedBox(
                width: _haloSize,
                height: _haloSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: _haloSize,
                      height: _haloSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.lightBlueAccent.withOpacity(0.25),
                      ),
                    ),
                    Container(
                      width: _innerSize,
                      height: _innerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.lightBlue.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            )),

          // Navigation instruction bar (shows next maneuver and distance)
          Positioned(
            left: 16,
            right: 16,
            top: 30,
            child: NavigationInstructionBar(
              maneuverType: _logic.maneuverType ?? 'straight',
              distanceMeters: _logic.distanceToNextTurn ?? 0.0,
              nextManeuverText: _logic.nextInstruction,
              streetName: _logic.streetName,
            ),
          ),

          ]));

  }

  Widget _infoTile(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(text, style: TextStyle(color: Colors.grey[850], fontSize: 14)),
      ],
    );
  }
}

          // Overlay cursor drawn above map labels (same visual as previous map circles).
          