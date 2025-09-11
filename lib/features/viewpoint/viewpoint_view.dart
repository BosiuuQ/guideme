import 'package:flutter/material.dart';
import '../../../map/mapbox.shim.dart' show MapboxMap, MapboxMapController, CameraPosition, LatLng, SymbolOptions;

class ViewpointView extends StatefulWidget {
  const ViewpointView({Key? key}) : super(key: key);

  @override
  State<ViewpointView> createState() => _ViewpointViewState();
}

class _ViewpointViewState extends State<ViewpointView> {
  MapboxMapController? _controller;
  final List<Map<String, dynamic>> _viewpoints = [
    {'title': 'Punkt widokowy 1', 'pos': LatLng(52.2400, 21.0150)},
    {'title': 'Punkt widokowy 2', 'pos': LatLng(50.0640, 19.9455)},
    {'title': 'Punkt widokowy 3', 'pos': LatLng(51.1100, 17.0300)},
  ];

  Future<void> _onMapCreated(MapboxMapController controller) async {
    _controller = controller;
    for (var v in _viewpoints) {
      try { await controller.addSymbol(SymbolOptions(geometry: v['pos'], iconSize: 1.0, data: {'asset':''})); } catch (e) {}
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final initial = CameraPosition(target: _viewpoints[0]['pos'] as LatLng, zoom: 12.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Punkty widokowe')),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: MapboxMap(
              initialCameraPosition: initial,
              onMapCreated: (c) => _onMapCreated(c),
              myLocationEnabled: false,
              trackCameraPosition: false,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _viewpoints.length,
              itemBuilder: (ctx, idx) {
                final v = _viewpoints[idx];
                return ListTile(
                  leading: const Icon(Icons.landscape),
                  title: Text(v['title']),
                  subtitle: Text('${(v['pos'] as LatLng).latitude.toStringAsFixed(5)}, ${(v['pos'] as LatLng).longitude.toStringAsFixed(5)}'),
                  onTap: () => _controller?.animateCamera(CameraPosition(target: v['pos'] as LatLng, zoom: 16.0)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
