
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'package:shared_preferences/shared_preferences.dart';

class PlaceSearchSheet extends StatefulWidget {
  final mb.LatLng? currentLocation;
  const PlaceSearchSheet({super.key, this.currentLocation});

  // Replace with your Mapbox public token or provide it via environment/config.
  static const String _mapboxToken = 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg';

  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<PlaceSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _suggestions = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
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
      });
      return;
    }

    setState(() => _isLoading = true);

    final params = <String, String>{
      'access_token': PlaceSearchSheet._mapboxToken,
      'autocomplete': 'true',
      'limit': '8',
      'language': 'pl',
    };

    if (widget.currentLocation != null) {
      // Mapbox expects longitude,latitude for proximity
      params['proximity'] = '${widget.currentLocation!.longitude},${widget.currentLocation!.latitude}';
    }

    final uri = Uri.https('api.mapbox.com', '/geocoding/v5/mapbox.places/${Uri.encodeComponent(input)}.json', params);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];
        // Simple client-side ranking: prefer features with shorter text and those with matching text prefix
        final q = input.toLowerCase().trim();
        int scoreFor(Map f) {
          try {
            final text = (f['text'] as String?)?.toLowerCase() ?? '';
            final placeName = (f['place_name'] as String?)?.toLowerCase() ?? '';
            int score = 0;
            if (text.startsWith(q)) score += 5000;
            if (placeName.startsWith(q)) score += 3000;
            score += (50 - text.length) * 10;
            return score;
          } catch (e) {
            return 0;
          }
        }

        final list = List<Map<String, dynamic>>.from(features.cast<Map>());
        list.sort((a, b) => scoreFor(b).compareTo(scoreFor(a)));

        setState(() {
          _suggestions = list;
        });
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    } catch (e) {
      setState(() {
        _suggestions = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSuggestionTile(dynamic feature) {
    final text = feature['text'] ?? '';
    final placeName = feature['place_name'] ?? '';
    return ListTile(
      title: Text(text),
      subtitle: Text(placeName, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () {
        final center = feature['center'] as List<dynamic>?;
        double? lng, lat;
        if (center != null && center.length >= 2) {
          lng = (center[0] as num).toDouble();
          lat = (center[1] as num).toDouble();
        }
        // save recent search
        if (placeName is String && placeName.isNotEmpty) _saveSearch(placeName);
        // return selected place to caller
        Navigator.of(context).pop({
          'lat': lat,
          'lng': lng,
          'name': placeName,
          'raw': feature,
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, sc) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Szukaj miejsca',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (v) {
                            _fetchSuggestions(v);
                          },
                          onSubmitted: (v) {
                            _fetchSuggestions(v);
                          },
                        ),
                      ),
                      if (_isLoading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          if (_controller.text.isEmpty) {
                            Navigator.of(context).pop();
                          } else {
                            _controller.clear();
                            setState(() {
                              _suggestions = [];
                            });
                          }
                        },
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _controller.text.isEmpty
                      ? _buildRecentList()
                      : ListView.separated(
                          controller: sc,
                          itemBuilder: (context, index) {
                            final f = _suggestions[index];
                            return _buildSuggestionTile(f);
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemCount: _suggestions.length,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentList() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Text(
          'Brak ostatnich wyszukiwań. Zacznij wpisywać, aby wyszukać miejsca.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }
    return ListView.separated(
      itemCount: _recentSearches.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = _recentSearches[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(s),
          onTap: () {
            _controller.text = s;
            _fetchSuggestions(s);
          },
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                _recentSearches.removeAt(index);
                prefs.setStringList('recent_searches', _recentSearches);
              });
            },
          ),
        );
      },
    );
  }
}
