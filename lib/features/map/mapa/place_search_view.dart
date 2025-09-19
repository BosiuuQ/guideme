import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;

/// Dark, bottom-sheet-first Place Search rewritten for Mapbox Search Box API
/// - Designed to be shown with showModalBottomSheet(... isScrollControlled: true)
/// - Slides up from bottom to ~2/3 of the screen, rounded top corners
/// - Dark theme, modern look, drag handle, animated list tiles
/// - Uses Mapbox SearchBox /suggest + /retrieve with session_token
///
class PlaceSearchSheet extends StatefulWidget {
  final mb.LatLng? currentLocation;
  /// Optional height fraction (0.2 .. 0.95). Default ~0.66
  final double heightFraction;
  const PlaceSearchSheet({super.key, this.currentLocation, this.heightFraction = 0.66});

  // Set your token here (or inject from env/secrets)
  static const String _mapboxToken = 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg';

  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<PlaceSearchSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  List<Map<String, dynamic>> _suggestions = [];
  List<String> _recentSearches = [];
  String _sessionToken = _generateSessionToken();
  final Map<String, Map<String, dynamic>> _retrieveCache = {};

  static String _generateSessionToken() {
    final rnd = Random.secure();
    String hex(int n) => List.generate(n, (_) => rnd.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final a = hex(4);
    final b = hex(2);
    final c = ((rnd.nextInt(0xffff) & 0x0fff) | 0x4000).toRadixString(16).padLeft(4, '0');
    final d = ((rnd.nextInt(0xffff) & 0x3fff) | 0x8000).toRadixString(16).padLeft(4, '0');
    final e = hex(6);
    return '$a-$b-$c-$d-$e';
  }

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveRecent(String text) async {
    if (text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches.remove(text);
      _recentSearches.insert(0, text);
      if (_recentSearches.length > 12) _recentSearches = _recentSearches.sublist(0, 12);
      prefs.setStringList('recent_searches', _recentSearches);
    });
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _ctrl.text.trim();
      if (q.isEmpty) {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
        return;
      }
      _fetchSuggestions(q);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return;
    setState(() { _loading = true; });

    final token = Uri.encodeQueryComponent(query);
    final lang = 'pl';
    final limit = 8;

    String proximity = '';
    if (widget.currentLocation != null) {
      proximity = '&proximity=${widget.currentLocation!.longitude},${widget.currentLocation!.latitude}';
    }

    final url = 'https://api.mapbox.com/search/searchbox/v1/suggest?q=$token&language=$lang&limit=$limit&session_token=$_sessionToken$proximity&access_token=${Uri.encodeQueryComponent(PlaceSearchSheet._mapboxToken)}';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final j = json.decode(res.body) as Map<String, dynamic>?;
        final suggestions = (j?['suggestions'] as List<dynamic>?) ?? [];
        setState(() {
          _suggestions = suggestions.map((s) => Map<String, dynamic>.from(s as Map)).toList();
          _loading = false;
        });
      } else {
        setState(() { _suggestions = []; _loading = false; });
      }
    } catch (e) {
      setState(() { _loading = false; _suggestions = []; });
    }
  }

  Future<Map<String, dynamic>?> _retrieveFeature(String mapboxId) async {
    if (mapboxId.isEmpty) return null;
    if (_retrieveCache.containsKey(mapboxId)) return _retrieveCache[mapboxId];

    final url = 'https://api.mapbox.com/search/searchbox/v1/retrieve/${Uri.encodeComponent(mapboxId)}?session_token=$_sessionToken&access_token=${Uri.encodeQueryComponent(PlaceSearchSheet._mapboxToken)}&language=pl';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final j = json.decode(res.body) as Map<String, dynamic>?;
        final features = (j?['features'] as List<dynamic>?) ?? [];
        if (features.isNotEmpty) {
          final f = Map<String, dynamic>.from(features.first as Map);
          Map<String, dynamic>? props = f['properties'] is Map ? Map<String, dynamic>.from(f['properties'] as Map) : null;
          double? lat;
          double? lng;
          if (props != null) {
            if (props.containsKey('coordinates')) {
              try {
                final coords = props['coordinates'] as Map<String, dynamic>;
                lat = (coords['latitude'] as num?)?.toDouble();
                lng = (coords['longitude'] as num?)?.toDouble();
              } catch (_) {}
            }
          }
          if ((lat == null || lng == null) && f['geometry'] is Map) {
            try {
              final geom = f['geometry'] as Map<String, dynamic>;
              final coords = (geom['coordinates'] as List<dynamic>?) ?? [];
              if (coords.length >= 2) {
                lng = (coords[0] as num).toDouble();
                lat = (coords[1] as num).toDouble();
              }
            } catch (_) {}
          }

          final out = {
            'name': props?['name'] ?? f['id'] ?? mapboxId,
            'mapbox_id': props?['mapbox_id'] ?? f['id'] ?? mapboxId,
            'address': props?['full_address'] ?? props?['address'] ?? null,
            'lat': lat,
            'lng': lng,
            'raw': f,
          };

          _retrieveCache[mapboxId] = out;
          return out;
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  Widget _buildSuggestionTile(Map<String, dynamic> s) {
    final name = (s['name'] ?? '').toString();
    final address = (s['full_address'] ?? s['place_formatted'] ?? s['address'] ?? '').toString();
    final type = (s['feature_type'] ?? '').toString();
    final distance = s['distance'];

    IconData iconData;
    if (type.contains('poi')) iconData = Icons.local_activity;
    else if (type.contains('address')) iconData = Icons.home;
    else iconData = Icons.place;

    return InkWell(
      onTap: () async {
        final mapboxId = (s['mapbox_id'] ?? s['mapboxId'] ?? s['id'] ?? '').toString();
        if (mapboxId.isEmpty) return;
        setState(() { _loading = true; });
        final full = await _retrieveFeature(mapboxId);
        setState(() { _loading = false; });
        if (full != null && full['lat'] != null && full['lng'] != null) {
          final nameToSave = full['name'] ?? name;
          await _saveRecent(nameToSave);
          if (mounted) Navigator.of(context).pop({ 'lat': full['lat'], 'lng': full['lng'], 'name': nameToSave, 'mapbox_id': full['mapbox_id'], 'raw': full['raw'] });
        } else {
          await _saveRecent(name);
          if (mounted) Navigator.of(context).pop({ 'name': name, 'mapbox_id': mapboxId, 'raw_suggestion': s });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: Offset(0,4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (address.isNotEmpty) SizedBox(height: 6),
                  if (address.isNotEmpty)
                    Text(address, style: TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${(distance/1000).toStringAsFixed(1)} km', style: TextStyle(color: Colors.white70, fontSize: 12)),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList() {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ostatnie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('recent_searches');
                  setState(() { _recentSearches = []; });
                },
                child: Text('Wyczyść', style: TextStyle(color: Colors.blue[300])),
              )
            ],
          ),
        ),
        const SizedBox(height: 6),
        ..._recentSearches.map((s) => ListTile(
          leading: Icon(Icons.history, color: Colors.white70),
          title: Text(s, style: TextStyle(color: Colors.white)),
          onTap: () async {
            _ctrl.text = s;
            await _fetchSuggestions(s);
          },
          trailing: IconButton(
            icon: Icon(Icons.close, color: Colors.white24),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() { _recentSearches.remove(s); prefs.setStringList('recent_searches', _recentSearches); });
            },
          ),
        ))
      ],
    );
  }

  Widget _buildSuggestionsList() {
    if (_suggestions.isEmpty && !_loading) return Center(child: Text('Brak wyników', style: TextStyle(color: Colors.white70)));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: _suggestions.length,
      itemBuilder: (context, i) {
        final s = _suggestions[i];
        return _buildSuggestionTile(s);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final heightFrac = widget.heightFraction.clamp(0.2, 0.95);
    final height = MediaQuery.of(context).size.height * heightFrac;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: Colors.grey[900],
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Top search row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: Colors.white70),
                    ),
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.white54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                style: TextStyle(color: Colors.white),
                                cursorColor: Colors.blue[300],
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Szukaj miejsca...',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                                onSubmitted: (v) async {
                                  await _fetchSuggestions(v.trim());
                                  if (_suggestions.isNotEmpty) {
                                    final mapboxId = (_suggestions.first['mapbox_id'] ?? '').toString();
                                    if (mapboxId.isNotEmpty) {
                                      final full = await _retrieveFeature(mapboxId);
                                      if (full != null && full['lat'] != null && full['lng'] != null) {
                                        await _saveRecent(full['name'] ?? v.trim());
                                        if (mounted) Navigator.of(context).pop({'lat': full['lat'], 'lng': full['lng'], 'name': full['name']});
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                            if (_ctrl.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white54),
                                onPressed: () { _ctrl.clear(); setState(() { _suggestions = []; }); },
                              )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () { _ctrl.clear(); setState(() { _suggestions = []; }); },
                      icon: Icon(Icons.mic, color: Colors.white54),
                    )
                  ],
                ),
              ),

              if (_loading) LinearProgressIndicator(minHeight: 2, color: Colors.blue[300]),

              // content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _ctrl.text.isEmpty ? _buildRecentList() : _buildSuggestionsList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
