import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaceSearchSheet extends StatelessWidget {
  final LatLng? currentLocation;

  const PlaceSearchSheet({super.key, this.currentLocation});

  static const String _apiKey = 'AIzaSyCvEzWl7SGN5LEAbaIs7nN91M7We3VHr5E'; // <- wstaw swój klucz

  @override
  Widget build(BuildContext context) {
    return _PlaceSearchBody(currentLocation: currentLocation);
  }
}

class _PlaceSearchBody extends StatefulWidget {
  final LatLng? currentLocation;

  const _PlaceSearchBody({required this.currentLocation});

  @override
  State<_PlaceSearchBody> createState() => _PlaceSearchBodyState();
}

class _PlaceSearchBodyState extends State<_PlaceSearchBody> {
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
    if (_recentSearches.length > 5) _recentSearches = _recentSearches.sublist(0, 5);
    await prefs.setStringList('recent_searches', _recentSearches);
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    String locationBias = '';
    if (widget.currentLocation != null) {
      locationBias = '&location=${widget.currentLocation!.latitude},${widget.currentLocation!.longitude}&radius=30000';
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${PlaceSearchSheet._apiKey}&language=pl&components=country:pl$locationBias',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List predictions = data['predictions'];
      if (predictions.isNotEmpty && widget.currentLocation != null) {
        predictions.sort((a, b) {
          return (a['description'].toString().contains(input)) ? -1 : 1;
        });
      }
      setState(() => _suggestions = predictions);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handlePlaceSelected(String placeId, String description) async {
    await _saveSearch(description);

    final detailUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=${PlaceSearchSheet._apiKey}',
    );
    final response = await http.get(detailUrl);
    final detail = json.decode(response.body);

    final lat = detail['result']['geometry']['location']['lat'];
    final lng = detail['result']['geometry']['location']['lng'];
    final LatLng latLng = LatLng(lat, lng);

    if (!mounted) return;
    Navigator.of(context).pop();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PlaceDetailPreview(
          address: description,
          timeToReach: "12 min",
          latLng: latLng,
          currentLocation: widget.currentLocation,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1B1F24),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Wyszukaj miejsce...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: const Color(0xFF2C323A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: _fetchSuggestions,
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          if (!_isLoading && _controller.text.isEmpty)
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text("🕓 Ostatnie wyszukiwania", style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  ),
                  ..._recentSearches.map((e) => ListTile(
                        leading: const Icon(Icons.history, color: Colors.white),
                        title: Text("📍 $e", style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          _controller.text = e;
                          _fetchSuggestions(e);
                        },
                      )),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.place, color: Colors.white),
                    title: Text("🏙 ${item['description']}", style: const TextStyle(color: Colors.white)),
                    onTap: () => _handlePlaceSelected(item['place_id'], item['description']),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

class PlaceDetailPreview extends StatelessWidget {
  final String address;
  final String timeToReach;
  final LatLng latLng;
  final LatLng? currentLocation;

  const PlaceDetailPreview({
    super.key,
    required this.address,
    required this.timeToReach,
    required this.latLng,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1F24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10)),
            ),
            Text(
              address,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_car, size: 20, color: Colors.white),
                const SizedBox(width: 6),
                Text("Czas dojazdu: $timeToReach", style: const TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Start Nawigacja"),
                  onPressed: () {
                    if (currentLocation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Nieznana lokalizacja użytkownika"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      context.goNamed(
                        'routePlanner',
                        extra: {
                          'start': currentLocation!,
                          'end': latLng,
                          'destinationName': address,
                        },
                      );
                    });
                  },
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_outline, color: Colors.white)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined, color: Colors.white)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
