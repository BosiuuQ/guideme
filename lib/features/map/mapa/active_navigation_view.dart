
import 'package:flutter/material.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'map_logic_handler.dart';

class ActiveNavigationView extends StatefulWidget {
  final mb.LatLng origin;
  final mb.LatLng destination;
  final String title;
  final List<List<double>> routeCoords; // [[lat, lng], ...]
  final double? durationSeconds;

  const ActiveNavigationView({
    Key? key,
    required this.origin,
    required this.destination,
    required this.title,
    required this.routeCoords,
    this.durationSeconds,
  }) : super(key: key);

  @override
  State<ActiveNavigationView> createState() => _ActiveNavigationViewState();
}

class _ActiveNavigationViewState extends State<ActiveNavigationView> with SingleTickerProviderStateMixin {
  late MapLogicHandler _mapLogic;
  double _speedKmh = 0.0;
  double _bearing = 0.0;
  bool _lineAdded = false;

  @override
  void initState() {
    super.initState();
    _mapLogic = MapLogicHandler();
    _mapLogic.tickerProvider = this;
    _mapLogic.onUpdate = () {
      try {
        final v = _mapLogic.currentSpeedKmh;
        final b = _mapLogic.currentBearing;
        if (mounted) {
          setState(() {
            _speedKmh = double.parse(v.toStringAsFixed(1));
            _bearing = b;
          });
        }
      } catch (e) {}
    };
  }

  @override
  void dispose() {
    _mapLogic.dispose();
    super.dispose();
  }

  Future<void> _addRouteLineIfNeeded() async {
    if (_lineAdded) return;
    final ctrl = _mapLogic.controller;
    if (ctrl == null) return;
    final coords = widget.routeCoords;
    if (coords.isEmpty) return;
    try {
      final lineCoords = coords.map((c) => mb.LatLng(c[0], c[1])).toList();
      await ctrl.addLine(
        mb.LineOptions(
          geometry: lineCoords,
          lineColor: '#3B82F6',
          lineWidth: 6.0,
        ),
      );
      _lineAdded = true;
    } catch (e) {
      debugPrint('Error while adding navigation line: $e');
    }
  }

  Widget _buildMap() {
    return mb.MapboxMap(
      accessToken: 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg',
      initialCameraPosition: mb.CameraPosition(target: widget.origin, zoom: 18),
      onMapCreated: (controller) async {
        _mapLogic.onMapCreated(controller);
        // wait a tick to ensure controller is ready
        WidgetsBinding.instance.addPostFrameCallback((_) => _addRouteLineIfNeeded());
      },
      myLocationEnabled: false,
      trackCameraPosition: true,
      onStyleLoadedCallback: () {
        // try to add line when style is ready too
        WidgetsBinding.instance.addPostFrameCallback((_) => _addRouteLineIfNeeded());
      },
    );
  }

  String _formatArrival() {
    final ds = widget.durationSeconds ?? 0.0;
    final arrival = DateTime.now().toLocal().add(Duration(seconds: ds.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _minutesLeft() {
    final ds = widget.durationSeconds ?? 0.0;
    final mins = (ds / 60.0).round();
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),

          // center crosshair like main map
          Center(
            child: IgnorePointer(
              child: SizedBox(
                width: 48.0 * 1.2,
                height: 48.0 * 1.2,
                child: Image.asset('assets/icons/marker.png', fit: BoxFit.contain),
              ),
            ),
          ),

          // Top instructions bar
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: SafeArea(
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.navigation, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Następny manewr', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            SizedBox(height: 4),
                            Text('Skręć w prawo za 200 m', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatArrival(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(_minutesLeft(), style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Speedometer - above bottom widget in right corner
          Positioned(
            right: 16,
            bottom: 120,
            child: Material(
              elevation: 6,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,3))],
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_speedKmh.toStringAsFixed(0)}', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('km/h', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          // Bottom info widget
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(12),
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Przewidywany czas przybycia', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          SizedBox(height: 6),
                          Text(_formatArrival(), style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Pozostało', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          SizedBox(height: 6),
                          Text(_minutesLeft(), style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
