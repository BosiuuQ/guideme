import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/spoty/spot_add_view.dart';
import 'package:guide_me/features/spoty/spoty_backend.dart';
import 'package:guide_me/features/spoty/spot_detail_view.dart';


class SpotyView extends StatefulWidget {
  const SpotyView({super.key});

  @override
  State<SpotyView> createState() => _SpotyViewState();
}

class _SpotyViewState extends State<SpotyView> with SingleTickerProviderStateMixin {
  LatLng? _currentLatLng;
  GoogleMapController? _mapController;
  TabController? _tabController;

  List<Map<String, dynamic>> officialSpots = [];
  List<Map<String, dynamic>> communitySpots = [];
  Set<Marker> _markers = {};
  Map<String, dynamic>? _selectedSpot;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
    });

    await _loadSpoty();
  }

  Future<void> _loadSpoty() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final spoty = await SpotyBackend.getSpotyWithRoles(userId);

    setState(() {
      officialSpots = spoty.where((s) {
        final role = s['autor']?['role'] ?? 'user';
        return ['admin', 'moderator', 'partner'].contains(role);
      }).toList();

      communitySpots = spoty.where((s) {
        final role = s['autor']?['role'] ?? 'user';
        return role == 'user';
      }).toList();
    });

    _createMarkers(spoty);
    debugPrint("📦 Oficjalne: ${officialSpots.length} | Społecznościowe: ${communitySpots.length}");
  }

  void _createMarkers(List<Map<String, dynamic>> spots) {
    final newMarkers = spots.map((spot) {
      return Marker(
        markerId: MarkerId(spot['id']),
        position: LatLng(spot['lat'], spot['lng']),
        icon: BitmapDescriptor.defaultMarker,
        onTap: () {
          setState(() {
            _selectedSpot = spot;
          });
        },
      );
    }).toSet();

    setState(() {
      _markers = newMarkers;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLatLng == null || _tabController == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0F1C),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0F1C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Spoty", style: TextStyle(color: Colors.white, fontSize: 24)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Oficjalne Spoty"),
            Tab(text: "Społecznościowe Spoty"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SpotAddView()));
          _loadSpoty(); // odśwież po powrocie
        },
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  height: 260,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentLatLng!,
                        zoom: 13,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        controller.setMapStyle('''
                          [
                            {
                              "featureType": "poi",
                              "elementType": "all",
                              "stylers": [{"visibility": "off"}]
                            }
                          ]
                        ''');
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      zoomControlsEnabled: false,
                      markers: _markers,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSpotList(officialSpots),
                    _buildSpotList(communitySpots),
                  ],
                ),
              ),
            ],
          ),

          // 🔵 Małe okienko po kliknięciu pinezki
          if (_selectedSpot != null)
            Positioned(
              left: 16,
              right: 16,
              top: 60,
              child: Material(
                color: const Color(0xFF1A1D2E),
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _selectedSpot!['zdjecie_url'] ?? "",
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset("assets/images/nightspot.jpg", width: 60, height: 60),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedSpot!['tytul'] ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text("📍 ${_selectedSpot!['lokalizacja']}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text("👥 Uczestnicy: brak (placeholder)", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => setState(() => _selectedSpot = null),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: szczegóły
                        },
                        child: const Text("Szczegóły", style: TextStyle(color: Colors.cyanAccent)),
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

  Widget _buildSpotList(List<Map<String, dynamic>> spots) {
    if (spots.isEmpty) {
      return const Center(
        child: Text("Brak spotów w tej kategorii", style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                spot["zdjecie_url"] ?? "",
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset("assets/images/nightspot.jpg", width: 60, height: 60),
              ),
            ),
            title: Text(
              spot["tytul"] ?? "",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("📍 ${spot["lokalizacja"] ?? ''}", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 2),
                Text(spot["opis"] ?? "", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 2),
                Text("Typ: ${spot["typ"] ?? ''}", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            trailing: ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpotDetailView(spot: spot),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.cyanAccent,
    foregroundColor: Colors.black,
  ),
  child: const Text("Szczegóły"),
),
          ),
        );
      },
    );
  }
}
