import 'package:flutter/material.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/spoty/spot_add_view.dart';
import 'package:guide_me/features/spoty/spoty_backend.dart';
import 'package:guide_me/features/spoty/spot_detail_view.dart';

import '../../core/constants/app_colors.dart';

class SpotyView extends StatefulWidget {
  const SpotyView({super.key});

  @override
  State<SpotyView> createState() => _SpotyViewState();
}

class _SpotyViewState extends State<SpotyView> with SingleTickerProviderStateMixin {
  mb.LatLng? _currentLatLng;
  TabController? _tabController;

  List<Map<String, dynamic>> officialSpots = [];
  List<Map<String, dynamic>> communitySpots = [];
  Map<String, dynamic>? _selectedSpot;

  mb.MapboxMapController? _mapController;

  mb.LatLng? _extractLatLngFromSpot(Map<String, dynamic> spot) {
    try {
      // common keys
      if (spot.containsKey('lat') && spot.containsKey('lng')) {
        final double lat = (spot['lat'] is String)
            ? double.tryParse(spot['lat']) ?? 0.0
            : (spot['lat'] is num ? (spot['lat'] as num).toDouble() : 0.0);
        final double lng = (spot['lng'] is String)
            ? double.tryParse(spot['lng']) ?? 0.0
            : (spot['lng'] is num ? (spot['lng'] as num).toDouble() : 0.0);
        return mb.LatLng(lat, lng);
      }

      if (spot.containsKey('latitude') && spot.containsKey('longitude')) {
        final double lat = (spot['latitude'] is String)
            ? double.tryParse(spot['latitude']) ?? 0.0
            : (spot['latitude'] is num ? (spot['latitude'] as num).toDouble() : 0.0);
        final double lng = (spot['longitude'] is String)
            ? double.tryParse(spot['longitude']) ?? 0.0
            : (spot['longitude'] is num ? (spot['longitude'] as num).toDouble() : 0.0);
        return mb.LatLng(lat, lng);
      }

      // nested location object
      if (spot.containsKey('location') && spot['location'] is Map) {
        final loc = Map<String, dynamic>.from(spot['location'] as Map);
        if (loc.containsKey('lat') && loc.containsKey('lng')) {
          final double lat = (loc['lat'] is String)
              ? double.tryParse(loc['lat']) ?? 0.0
              : (loc['lat'] is num ? (loc['lat'] as num).toDouble() : 0.0);
          final double lng = (loc['lng'] is String)
              ? double.tryParse(loc['lng']) ?? 0.0
              : (loc['lng'] is num ? (loc['lng'] as num).toDouble() : 0.0);
          return mb.LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('extractLatLng error: $e');
    }
    return null;
  }

  Future<void> _updateMapSymbols(List<Map<String,dynamic>> spots) async {
    if (_mapController == null) return;
    try {
      // If possible, you might want to clear previous symbols here (depends on map API).
      for (final s in spots) {
        final pos = _extractLatLngFromSpot(s);
        if (pos == null) continue;
        try {
          await _mapController!.addSymbol(
            mb.SymbolOptions(geometry: pos, iconImage: 'assets/icons/dest_pin.png', iconSize: 0.12),
          );
        } catch (e) {
          debugPrint('Error adding symbol for spot ${s['id'] ?? s['tytul']}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error adding symbols: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLatLng = mb.LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Could not get current position: $e');
    }

    await _loadSpoty();
  }

  Future<void> _loadSpoty() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user logged in when loading spots');
      return;
    }

    final spotyRaw = await SpotyBackend.getSpotyWithRoles(userId);

    // Defensive: ensure we have a list of maps
    final List<Map<String, dynamic>> spoty = [];
    for (final e in spotyRaw) {
      if (e is Map) {
        spoty.add(Map<String, dynamic>.from(e));
      }
    }

    // debug: print first few returned spot titles to understand what's coming from DB
    try {
      debugPrint('DEBUG: Loaded ${spoty.length} spots from backend. First 10 titles:');
      for (var i = 0; i < (spoty.length < 10 ? spoty.length : 10); i++) {
        debugPrint(' * ${i+1}: ${spoty[i]['tytul'] ?? spoty[i]['title'] ?? spoty[i]['id'] ?? '<no title>'}');
      }
    } catch (_) {}

    // classify spots more robustly:
    final List<Map<String, dynamic>> official = [];
    final List<Map<String, dynamic>> community = [];

    bool isOfficialRole(String? role) {
      if (role == null) return false;
      final r = role.toLowerCase();
      return r.contains('admin') || r.contains('moder') || r.contains('partner') || r.contains('ceo') || r.contains('owner');
    }

    for (final s in spoty) {
      // if backend already classified it, respect that
      final kategoria = (s['kategoria'] is String) ? (s['kategoria'] as String).toLowerCase() : null;
      if (kategoria != null) {
        if (kategoria.contains('oficjal') || kategoria.contains('official')) {
          official.add(s);
          continue;
        } else if (kategoria.contains('spolecz') || kategoria.contains('community')) {
          community.add(s);
          continue;
        }
      }

      // determine author role defensively
      final autor = s['autor'];
      String role = 'user';
      try {
        if (autor is Map) {
          final rr = autor['role'];
          if (rr != null) role = rr.toString();
          // if nickname or other fields present, don't break
        } else if (autor is String) {
          // sometimes autor may be just an id string; treat as user
          role = 'user';
        } else {
          role = 'user';
        }
      } catch (_) {
        role = 'user';
      }

      if (isOfficialRole(role)) {
        official.add(s);
      } else {
        // Also treat spots with autor == null as community spots to ensure visibility
        community.add(s);
      }
    }

    // Optional: sort lists by created_at or data if present (newest first)
    int compareByDateDesc(Map a, Map b) {
      try {
        final da = a['created_at']?.toString() ?? a['data']?.toString() ?? '';
        final db = b['created_at']?.toString() ?? b['data']?.toString() ?? '';
        if (da.isEmpty && db.isEmpty) return 0;
        if (da.isEmpty) return 1;
        if (db.isEmpty) return -1;
        final pa = DateTime.tryParse(da) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final pb = DateTime.tryParse(db) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return pb.compareTo(pa);
      } catch (_) {
        return 0;
      }
    }

    official.sort(compareByDateDesc);
    community.sort(compareByDateDesc);

    setState(() {
      officialSpots = official;
      communitySpots = community;
    });

    // Dodajemy symbole na mapie (jeśli kontroler Mapbox jest gotowy)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final combined = [...officialSpots, ...communitySpots];
      _updateMapSymbols(combined);
    });

    debugPrint("📦 Oficjalne: ${officialSpots.length} | Społecznościowe: ${communitySpots.length}");
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
        backgroundColor: const Color(0xFF090A13),
        elevation: 0,
        title: const Text(
          "Spoty",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(width: 3, color: Colors.cyanAccent),
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Oficjalne"),
            Tab(text: "Społecznościowe"),
            Tab(text: "Dodaj spot"),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_tabController?.index != 2)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: 260,
                    child: (_tabController?.index == 2)
                        ? const SizedBox.shrink()
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: mb.MapboxMap(
                          accessToken:
                          'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg',
                          initialCameraPosition:
                          mb.CameraPosition(target: _currentLatLng ?? mb.LatLng(52.2297, 21.0122), zoom: 13),
                          styleUri: 'mapbox://styles/bosiuuq/cmgf5xezs00i701sec30chpp0',
                          onMapCreated: (controller) async {
                            _mapController = controller;
                            try {
                              if (_currentLatLng != null) {
                                await _mapController!.addSymbol(
                                  mb.SymbolOptions(geometry: _currentLatLng!, iconImage: 'assets/icons/marker.png', iconSize: 0.12),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error adding user symbol: $e');
                            }
                          },
                          myLocationEnabled: true,
                          trackCameraPosition: true,
                        ),
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
                    SpotAddView(embedded: true),
                  ],
                ),
              ),
            ],
          ),

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
                        child: const Text("Szczegóły", style: TextStyle(color: AppColors.blue)),
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
                Builder(builder: (ctx) {
                  String _distanceText = '-';
                  try {
                    if (_currentLatLng != null) {
                      final plat = (spot['lat'] is String)
                          ? double.tryParse(spot['lat']) ?? 0.0
                          : (spot['lat'] is num ? (spot['lat'] as num).toDouble() : 0.0);
                      final plng = (spot['lng'] is String)
                          ? double.tryParse(spot['lng']) ?? 0.0
                          : (spot['lng'] is num ? (spot['lng'] as num).toDouble() : 0.0);
                      if (plat != 0.0 || plng != 0.0) {
                        final d = Geolocator.distanceBetween(_currentLatLng!.latitude, _currentLatLng!.longitude, plat, plng) / 1000.0;
                        _distanceText = d >= 1.0 ? '${d.toStringAsFixed(1)} km' : '${(d * 1000).toStringAsFixed(0)} m';
                      }
                    }
                  } catch (_) {}
                  return Text('📍 $_distanceText', style: const TextStyle(color: Colors.grey));
                }),
                const SizedBox(height: 2),
                Text(spot["opis"] ?? "", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 2),
                Text("👥 ${spot['participants_count'] ?? spot['uczestnicy'] ?? 0} uczestników", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SpotDetailView(spot: spot),
                  ),
                );
                await _loadSpoty();
              },
              child: const Text("Szczegóły"),
            ),
          ),
        );
      },
    );
  }
}
