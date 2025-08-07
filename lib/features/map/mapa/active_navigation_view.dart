import 'package:flutter/material.dart';
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
  late NavigationLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = NavigationLogic(
      routePoints: widget.routePoints,
      destination: widget.destination,
      destinationName: widget.destinationName,
      onUpdate: () => setState(() {}),
      onRecalculated: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zmieniono trasę — przeliczono nową trasę')),
          );
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _logic.initLogic(context));
  }

  @override
  void dispose() {
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
            initialCameraPosition: CameraPosition(target: widget.routePoints.first, zoom: 16),
            onMapCreated: _logic.handleMapCreated,
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
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            rotateGesturesEnabled: false,
            compassEnabled: false,
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
