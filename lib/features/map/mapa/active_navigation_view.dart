import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/map/mapa/navigation_instruction_bar.dart';
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
  // Screen position of the in-app cursor overlay (keeps the same look as previous map circles,
  // but rendered above map labels by drawing on top of the GoogleMap widget).
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
      // if we somehow didn't get pixels, schedule a short retry
      if (_cursorScreenPosition == null) {
        Future.delayed(const Duration(milliseconds: 200), () => _updateCursorScreenPosition());
      }
    } catch (e) {
      // retry once after a short delay (map might not be fully ready)
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
              Polyline(
                polylineId: const PolylineId('full_route'),
                color: Colors.cyanAccent,
                width: 6,
                points: _logic.polylinePoints,
              )
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
            compassEnabled: false,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          ),



          
Positioned(
            top: 50,
            left: 12,
            right: 12,
            child: NavigationInstructionBar(
              maneuverType: _logic.maneuver ?? 'straight',
              distanceMeters: _logic.distanceToNextTurn,
              streetName: _logic.streetName ?? '',
              nextManeuverText: _logic.nextInstruction ?? '',
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
                    child: const Text("Zakończ nawigację", style: TextStyle(color: Colors.white, fontSize: 16)),
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
            ),
          ),
],
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}

          // Overlay cursor drawn above map labels (same visual as previous map circles).
          