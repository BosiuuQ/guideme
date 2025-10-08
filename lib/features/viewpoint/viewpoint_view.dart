import 'package:flutter/material.dart';
import 'package:guide_me/mapbox_shim.dart' show MapboxMap, MapboxMapController, CameraPosition, LatLng, SymbolOptions;

class ViewpointView extends StatefulWidget {
  const ViewpointView({Key? key}) : super(key: key);

  @override
  State<ViewpointView> createState() => _ViewpointViewState();
}

class _ViewpointViewState extends State<ViewpointView> {
  // PointAnnotationManager used to add symbols above line layers
  dynamic _pointManager; // will be set to the platform-specific PointAnnotationManager

  MapboxMapController? _controller;

  final List<Map<String, dynamic>> _viewpoints = [
    {'title': 'Punkt widokowy 1', 'pos': LatLng(52.2400, 21.0150)},
    {'title': 'Punkt widokowy 2', 'pos': LatLng(50.0640, 19.9455)},
    {'title': 'Punkt widokowy 3', 'pos': LatLng(51.1100, 17.0300)},
  ];

  void _onMapCreated(MapboxMapController controller) {
    _controller = controller;
    // Add markers (symbols) for each viewpoint
    for (var v in _viewpoints) {
      final LatLng p = v['pos'] as LatLng;
      try {
        _controller?.addSymbol(SymbolOptions(geometry: p, iconImage: 'assets/icons/marker.png',  ));
      } catch (e) {}
    }
  }

  void _goTo(LatLng pos) {
    _controller?.moveCamera(pos, zoom: 16.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punkty widokowe')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MapboxMap(scrollGesturesEnabled: false, /*scroll-inserted*/

              initialCameraPosition: const CameraPosition(target: LatLng(52.2297, 21.0122), zoom: 13.0),
              onMapCreated: _onMapCreated,
              trackCameraPosition: true,
            ),
          ),
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _viewpoints.length,
              itemBuilder: (context, index) {
                final v = _viewpoints[index];
                final LatLng pos = v['pos'] as LatLng;
                return ListTile(
                  leading: const Icon(Icons.landscape),
                  title: Text(v['title'] as String),
                  subtitle: Text('${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'),
                  onTap: () => _goTo(pos),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
