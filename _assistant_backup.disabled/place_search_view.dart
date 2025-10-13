
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'package:shared_preferences/shared_preferences.dart';

class PlaceSearchSheet extends StatefulWidget {
  final mb.LatLng? currentLocation;
  const PlaceSearchSheet({super.key, this.currentLocation});

  // Put your Mapbox token here. If empty or invalid, the code will fallback to OpenStreetMap Nominatim.
  static const String _mapboxToken = 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg';

  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<PlaceSearchSheet> {
  // PointAnnotationManager used to add symbols above line layers
  dynamic _pointManager; // will be set to the platform-specific PointAnnotationManager

  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  List<String> _recentSearches = [];
  bool _loading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearch(String search) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(search);
    _recentSearches.insert(0, search);
    if (_recentSearches.length > 6) _recentSearches = _recentSearches.sublist(0, 6);
    await prefs.setStringList('recent_searches', _recentSearches);
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _statusMessage = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    // helper to map Mapbox feature list into internal suggestion format
    List<Map<String,dynamic>> _mapMapboxFeatures(List<dynamic> features) {
      return features.map((f) {
        return {
          'name': f['text'] ?? f['place_name'] ?? '',
          'place_name': f['place_name'] ?? '',
          'lat': (f['center'] != null && f['center'].length >= 2) ? (f['center'][1] as num).toDouble() : null,
          'lng': (f['center'] != null && f['center'].length >= 2) ? (f['center'][0] as num).toDouble() : null,
          'raw': f,
        };
      }).toList();
    }

    try {
      final encoded = Uri.encodeComponent(input);
      final proximity = (widget.currentLocation != null)
          ? '&proximity=${widget.currentLocation!.longitude},${widget.currentLocation!.latitude}'
          : '';

      // First attempt: Mapbox with types (poi,place,address)
      if (PlaceSearchSheet._mapboxToken.isNotEmpty) {
        final urlWithTypes =
            'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json?access_token=${PlaceSearchSheet._mapboxToken}&autocomplete=true&types=poi&language=pl&fuzzyMatch=true&limit=10$proximity';
        final res1 = await http.get(Uri.parse(urlWithTypes));
        if (res1.statusCode == 200) {
          final j = json.decode(res1.body) as Map<String, dynamic>;
          final features = (j['features'] as List<dynamic>?) ?? [];
          if (features.isNotEmpty) {
            setState(() {
              _suggestions = _mapMapboxFeatures(features);
              _loading = false;
            });
            return;
          }
        }

        // Second attempt: Mapbox without types to broaden matches
        final urlNoTypes =
            'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json?access_token=${PlaceSearchSheet._mapboxToken}&autocomplete=true&language=pl&fuzzyMatch=true&limit=10$proximity';
        final res2 = await http.get(Uri.parse(urlNoTypes));
        if (res2.statusCode == 200) {
          final j = json.decode(res2.body) as Map<String, dynamic>;
          final features = (j['features'] as List<dynamic>?) ?? [];
          if (features.isNotEmpty) {
            setState(() {
              _suggestions = _mapMapboxFeatures(features);
              _loading = false;
            });
            return;
          }
        }

        // Third attempt: Mapbox with BROAD types (place, locality, neighborhood, address, poi)
        final urlBroadTypes =
            'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json?access_token=${PlaceSearchSheet._mapboxToken}&autocomplete=true&types=place,locality,neighborhood,address,poi&language=pl&fuzzyMatch=true&limit=10$proximity';
        final res3 = await http.get(Uri.parse(urlBroadTypes));
        if (res3.statusCode == 200) {
          final j3 = json.decode(res3.body) as Map<String, dynamic>;
          final features3 = (j3['features'] as List<dynamic>?) ?? [];
          if (features3.isNotEmpty) {
            setState(() {
              _suggestions = _mapMapboxFeatures(features3);
              _loading = false;
            });
            return;
          }
        }

        // If Mapbox returned no features, fall through to fallback below.
      }

      // Fallback: Nominatim (OpenStreetMap) search - helpful when Mapbox token invalid or restrictions apply.
      final nominatimUrl = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(input)}&format=json&addressdetails=1&limit=8';
      final resN = await http.get(Uri.parse(nominatimUrl), headers: {'User-Agent': 'GuideMeApp/1.0 (+https://example.com)'});
      if (resN.statusCode == 200) {
        final arr = json.decode(resN.body) as List<dynamic>;
        if (arr.isNotEmpty) {
          final list = arr.map((e) {
            final lat = (e['lat'] != null) ? double.tryParse(e['lat'].toString()) : null;
            final lon = (e['lon'] != null) ? double.tryParse(e['lon'].toString()) : null;
            final display = e['display_name'] ?? e['name'] ?? input;
            return {
              'name': display.split(',').first,
              'place_name': display,
              'lat': lat,
              'lng': lon,
              'raw': e,
            };
          }).toList();
          setState(() {
            _suggestions = List<Map<String,dynamic>>.from(list);
            _loading = false;
            _statusMessage = 'Użyto OpenStreetMap (fallback)';
          });
          return;
        }
      }

      // no results
      setState(() {
        _suggestions = [];
        _statusMessage = 'Brak wyników';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _suggestions = [];
        _statusMessage = 'Błąd podczas wyszukiwania';
        _loading = false;
      });
    }
  }

  Widget _buildRecent() {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('Ostatnie wyszukiwania', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        ..._recentSearches.map((s) {
          return ListTile(
            leading: const Icon(Icons.history),
            title: Text(s),
            onTap: () async {
              _ctrl.text = s;
              await _fetchSuggestions(s);
            },
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                setState(() {
                  _recentSearches.remove(s);
                  prefs.setStringList('recent_searches', _recentSearches);
                });
              },
            ),
          );
        }).toList()
      ],
    );
  }

  Widget _buildSuggestion(Map<String,dynamic> it) {
    return ListTile(
      leading: const Icon(Icons.place),
      title: Text(it['name'] ?? ''),
      subtitle: Text(it['place_name'] ?? ''),
      onTap: () async {
        final lat = it['lat'] as double?;
        final lng = it['lng'] as double?;
        final name = it['place_name'] as String?;
        if (lat != null && lng != null) {
          await _saveSearch(name ?? it['name'] ?? '${lat.toString()},${lng.toString()}');
          Navigator.of(context).pop({'lat': lat, 'lng': lng, 'name': name ?? it['name']});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wybrany wynik nie ma współrzędnych')));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Material(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Wyszukaj miasto, adres lub obiekt (np. Wroclavia)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _fetchSuggestions(v);
                        },
                        onSubmitted: (v) {
                          _fetchSuggestions(v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(_statusMessage!, style: const TextStyle(color: Colors.grey)),
                ),
              Expanded(
                child: _suggestions.isNotEmpty
                    ? ListView.builder(
                        itemCount: _suggestions.length,
                        itemBuilder: (c,i) => _buildSuggestion(_suggestions[i]),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildRecent(),
                            if (!_loading)
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: const [
                                    Icon(Icons.search, size: 48, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('Brak sugestii', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
