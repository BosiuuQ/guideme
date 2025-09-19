
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:guide_me/mapbox_shim.dart' as mb;

class RoutePlannerView extends StatefulWidget {
  final mb.LatLng origin;
  final mb.LatLng destination;
  final String title;

  const RoutePlannerView({
    Key? key,
    required this.origin,
    required this.destination,
    required this.title,
  }) : super(key: key);

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  static const String _mapboxToken = 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg';
  bool _loading = true;
  String? _error;
  double? _distanceMeters;
  double? _durationSeconds;
  List<List<double>> _coords = [];

  mb.MapboxMapController? _controller;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    setState(() { _loading = true; _error = null; });
    try {
      final origin = '${widget.origin.longitude},${widget.origin.latitude}';
      final dest = '${widget.destination.longitude},${widget.destination.latitude}';
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$origin;$dest?geometries=geojson&overview=full&access_token=$_mapboxToken';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        setState(() { _error = 'Błąd serwera: ${res.statusCode}'; _loading = false; });
        return;
      }
      final j = json.decode(res.body) as Map<String,dynamic>;
      final routes = j['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        setState(() { _error = 'Brak trasy'; _loading = false; });
        return;
      }
      final r = routes[0] as Map<String,dynamic>;
      _distanceMeters = (r['distance'] as num?)?.toDouble();
      _durationSeconds = (r['duration'] as num?)?.toDouble();
      final geom = r['geometry'] as Map<String,dynamic>?;
      final coords = (geom?['coordinates'] as List<dynamic>?)?.map((e) {
        return [(e[1] as num).toDouble(), (e[0] as num).toDouble()];
      }).toList();
      _coords = coords != null ? List<List<double>>.from(coords) : [];
      setState(() { _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToRoute();
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _fitMapToRoute() {
    if (_controller == null || _coords.isEmpty) return;
    try {
      double minLat = _coords.first[0], maxLat = _coords.first[0];
      double minLng = _coords.first[1], maxLng = _coords.first[1];
      for (final c in _coords) {
        final lat = c[0], lng = c[1];
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
      final centerLat = (minLat + maxLat) / 2.0;
      final centerLng = (minLng + maxLng) / 2.0;
      final latSpan = (maxLat - minLat).abs();
      final lngSpan = (maxLng - minLng).abs();
      double zoom = 14.0;
      final span = latSpan > lngSpan ? latSpan : lngSpan;
      if (span < 0.002) zoom = 18.0;
      else if (span < 0.01) zoom = 16.0;
      else if (span < 0.05) zoom = 14.0;
      else if (span < 0.3) zoom = 12.0;
      _controller!.moveCameraImmediate(mb.LatLng(centerLat, centerLng), zoom);

      try {
        _controller!.addSymbol(mb.SymbolOptions(geometry: widget.origin, data: {'type': 'origin'}));
        _controller!.addSymbol(mb.SymbolOptions(geometry: widget.destination, data: {'type': 'destination'}));
      } catch (e) {}
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Błąd: $_error'))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.black87,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trasa', style: TextStyle(color: Colors.white70)),
                              Text('${_formatDistance(_distanceMeters ?? 0)} • ${_formatDuration(_durationSeconds ?? 0)}',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start - tryb nawigacji (stub)')));
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Rozpocznij'))
                        ],
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: mb.MapboxMap(
                          accessToken: _mapboxToken,
                          initialCameraPosition: mb.CameraPosition(target: widget.origin, zoom: 14.0),
                          onMapCreated: (c) {
                            _controller = c;
                            _fitMapToRoute();
                          },
                          myLocationEnabled: false,
                          trackCameraPosition: false,
                          onStyleLoadedCallback: () {},
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop({'distance': _distanceMeters, 'duration': _durationSeconds});
                            },
                            child: const Text('Zakończ'),
                          )),
                        ],
                      ),
                    )
                  ],
                ),
    );
  }

  String _formatDistance(double m) {
    if (m >= 1000) return '${(m/1000).toStringAsFixed(1)} km';
    return '${m.toStringAsFixed(0)} m';
  }

  String _formatDuration(double s) {
    final mins = (s/60).round();
    if (mins >= 60) return '${(mins/60).floor()}h ${mins%60}m';
    return '${mins} min';
  }
}
