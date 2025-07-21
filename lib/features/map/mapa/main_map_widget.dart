import 'package:flutter/material.dart';
import 'package:guide_me/features/clubs/clubs_home_view.dart';
import 'package:guide_me/features/map/mapa/map_logic_handler.dart';
import 'package:guide_me/features/map/mapa/place_search_view.dart';
import 'package:guide_me/features/viewpoint/presentation/views/viewpoint_view.dart';
import 'package:guide_me/features/spoty/spoty_view.dart';

class MainMapWidget extends StatefulWidget {
  const MainMapWidget({super.key});

  @override
  State<MainMapWidget> createState() => _MainMapWidgetState();
}

class _MainMapWidgetState extends State<MainMapWidget> with SingleTickerProviderStateMixin {
  late MapLogicHandler _mapLogic;
  bool _mapInitialized = false;

  @override
  void initState() {
    super.initState();
    _mapLogic = MapLogicHandler(onUpdate: () => setState(() {}), tickerProvider: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapInitialized) {
        _mapLogic.initializeTracking(context);
        _mapInitialized = true;
      }
    });
  }

  @override
  void dispose() {
    _mapLogic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _mapLogic.buildGoogleMap(),

        Positioned(
          top: 40,
          left: 10,
          right: 10,
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  final location = _mapLogic.targetLocation;
                  if (location != null) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => PlaceSearchSheet(currentLocation: location),
                    );
                  }
                },
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                  ),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Wyszukaj miejsce...',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildTagRow(),
            ],
          ),
        ),

        Positioned(
          bottom: 20,
          right: 20,
          child: GestureDetector(
            onTap: () {
              _mapLogic.enableFollowUser();
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _mapLogic.followUser ? const Color(0xFF00C6FF) : Colors.black,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5)],
              ),
              child: const Icon(Icons.navigation_rounded, color: Colors.white),
            ),
          ),
        ),

        Positioned(
          bottom: 20,
          left: 20,
          child: _mapLogic.buildSpeedometer(),
        ),
      ],
    );
  }

  Widget _buildTagRow() {
    Widget buildTag(IconData icon, String label, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 5)],
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          children: [
            buildTag(Icons.calendar_month_rounded, 'Spoty', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SpotyView()));
            }),
            buildTag(Icons.groups_rounded, 'Kluby', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClubsHomeView()));
            }),
            buildTag(Icons.landscape_rounded, 'Punkty Widokowe', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewpointView()));
            }),
          ],
        ),
      ),
    );
  }
}
