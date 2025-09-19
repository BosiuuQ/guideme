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

  final GlobalKey _bottomKey = GlobalKey();
  double _bottomWidgetHeight = 0.0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomWidget());
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

  void _measureBottomWidget() {
    try {
      final ctx = _bottomKey.currentContext;
      if (ctx != null) {
        final size = ctx.size;
        if (size != null) {
          final h = size.height;
          if (h != _bottomWidgetHeight) {
            setState(() {
              _bottomWidgetHeight = h;
            });
          }
        }
      }
    } catch (e) {}
  }

  Widget _buildMap() {
    return mb.MapboxMap(
      accessToken: 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg',
      initialCameraPosition: mb.CameraPosition(target: widget.origin, zoom: 18),
      onMapCreated: (controller) async {
        _mapLogic.onMapCreated(controller);
        WidgetsBinding.instance.addPostFrameCallback((_) => _addRouteLineIfNeeded());
      },
      myLocationEnabled: false,
      trackCameraPosition: true,
      onStyleLoadedCallback: () {
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
    // ensure we measure bottom widget after layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomWidget());
    final double overlayBottom = (_bottomWidgetHeight > 0) ? _bottomWidgetHeight + 20.0 : 100.0;

    return Scaffold(
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

          // Top guide bar (flush to top edge)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  SizedBox(width: 12),
                  Icon(Icons.menu, color: Colors.white70),
                  SizedBox(width: 8),
                  Expanded(child: Text('Guide Me', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  SizedBox(width: 12),
                ],
              ),
            ),
          ),

          // Top instructions bar (immediately under guide bar) - flush left/right, top corners square
          Positioned(
            left: 0,
            right: 0,
            top: 56,
            child: Material(
              elevation: 6,
              color: Colors.black87,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
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

          // Speedometer - aligned right, positioned dynamically above bottom widget
          Positioned(
            right: 16,
            bottom: overlayBottom,
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

          // 'Zakończ' button - aligned left, same vertical offset as speedometer
          Positioned(
            left: 20,
            bottom: overlayBottom,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0,4))],
                  border: Border.all(color: Colors.red.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.close, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('Zakończ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          // Bottom info widget - flush to bottom edge, only top corners rounded
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Material(
                key: _bottomKey,
                elevation: 12,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
