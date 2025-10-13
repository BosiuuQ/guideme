import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:guide_me/features/map/mapa/active_navigation_view.dart';

class RoutePlannerView extends StatefulWidget {
  final LatLng start;
  final LatLng end;
  final String destinationName;

  const RoutePlannerView({
    super.key,
    required this.start,
    required this.end,
    required this.destinationName,
  });

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String _transport = 'car';

  bool _isLoading = true;
  bool _hasError = false;

  double _distanceKm = 0;
  int _durationMin = 0;
  String _arrivalTime = "--:--";

  final Map<String, double> speedKmh = {
    'car': 50,
    'walk': 5,
    'bike': 15,
  };

  @override
  void initState() {
    super.initState();
    _loadRoute(_transport);
  }

  Future<void> _loadRoute(String transportMode) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final polylinePoints =
        await _fetchRoutePolyline(widget.start, widget.end, transportMode);

    if (polylinePoints == null || polylinePoints.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId("A"),
          position: widget.start,
          infoWindow: const InfoWindow(title: "Moja lokalizacja"),
        ),
        Marker(
          markerId: const MarkerId("B"),
          position: widget.end,
          infoWindow: InfoWindow(title: widget.destinationName),
        ),
      };

      _polylines = {
        Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.blueAccent,
          width: 6,
          points: polylinePoints,
        )
      };

      _calculateRouteInfo();
      _isLoading = false;

      Future.delayed(const Duration(milliseconds: 300), _fitBounds);
    });
  }

  Future<List<LatLng>?> _fetchRoutePolyline(
      LatLng start, LatLng end, String mode) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&mode=$mode'
        '&key=AIzaSyCvEzWl7SGN5LEAbaIs7nN91M7We3VHr5E', // <- Zmień na swój klucz!
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] != 'OK') {
        debugPrint("❌ Directions API error: ${data['status']} - ${data['error_message'] ?? 'No message'}");
        return null;
      }

      final points = data['routes']?[0]?['overview_polyline']?['points'];
      if (points != null) {
        return _decodePolyline(points);
      }
    } catch (e) {
      debugPrint("❌ Błąd pobierania trasy: $e");
    }

    return null;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  void _fitBounds() {
    if (_mapController == null || _polylines.isEmpty) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(widget.start.latitude, widget.end.latitude),
        min(widget.start.longitude, widget.end.longitude),
      ),
      northeast: LatLng(
        max(widget.start.latitude, widget.end.latitude),
        max(widget.start.longitude, widget.end.longitude),
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _calculateRouteInfo() {
    final distanceMeters = _calculateDistance(widget.start, widget.end);
    _distanceKm = distanceMeters / 1000;

    final speed = speedKmh[_transport]!;
    final timeHours = _distanceKm / speed;
    _durationMin = (timeHours * 60).round();

    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: _durationMin));
    _arrivalTime = DateFormat('HH:mm').format(arrival);
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(p2.latitude - p1.latitude);
    final dLng = _degToRad(p2.longitude - p1.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(p1.latitude)) *
            cos(_degToRad(p2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  Future<void> _changeTransport(String type) async {
    if (_isLoading) return;
    setState(() => _transport = type);
    await _loadRoute(type);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(target: widget.start, zoom: 14),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
        ),
        if (_hasError)
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Nie udało się pobrać trasy. Spróbuj zmienić tryb lub wróć.",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
          ),
        _buildTopInfo(),
        _buildBottomPanel(),
      ]),
    );
  }

  Widget _buildTopInfo() {
    return Positioned(
      top: 120,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Moja lokalizacja", style: TextStyle(color: Colors.black54)),
            Text(widget.destinationName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 80,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${_distanceKm.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.white)),
                Text("ok. $_durationMin min", style: const TextStyle(color: Colors.white)),
                Text("do celu $_arrivalTime", style: const TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _transportButton(Icons.directions_car, 'car'),
                _transportButton(Icons.directions_walk, 'walk'),
                _transportButton(Icons.directions_bike, 'bike'),
                if (!_hasError)
                  ElevatedButton(
                    onPressed: _polylines.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActiveNavigationView(
                                  routePoints: _polylines.first.points,
                                  destination: widget.end,
                                  destinationName: widget.destinationName,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text("Rozpocznij", style: TextStyle(color: Colors.white)),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _transportButton(IconData icon, String type) {
    final isActive = _transport == type;
    return GestureDetector(
      onTap: () => _changeTransport(type),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blueAccent : Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.white : Colors.grey[400]),
      ),
    );
  }
}
