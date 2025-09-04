import 'package:flutter/material.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'package:guide_me/mapbox_shim.dart';
import 'map_logic_handler.dart';
import 'package:guide_me/mapbox_shim.dart';
import 'package:flutter/scheduler.dart';

class MainMapWidget extends StatefulWidget {
  const MainMapWidget({super.key});

  @override
  State<MainMapWidget> createState() => _MainMapWidgetState();
}

class _MainMapWidgetState extends State<MainMapWidget> with SingleTickerProviderStateMixin {
  late MapLogicHandler _mapLogic;

  @override
  void initState() {
    super.initState();
    _mapLogic = MapLogicHandler(onUpdate: () { setState(() {}); }, tickerProvider: this);
  }

  @override
  void dispose() {
    _mapLogic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMap(),
        Positioned(
          bottom: 20,
          left: 20,
          child: _mapLogic.buildSpeedometer(),
        ),
      ],
    );
  }

  Widget _buildMap() {
    return mb.MapboxMap(
      accessToken: 'pk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWI2dDU0c3AwMzV4MnFxcjhlOWVraHZwIn0.IbQtOAFV1MKkx7id3RwtIg', // token from AndroidManifest/Info.plist
      initialCameraPosition: const mb.CameraPosition(target: mb.LatLng(52.2297, 21.0122), zoom: 13.0),
      onMapCreated: _mapLogic.onMapCreated,
      myLocationEnabled: false,
      trackCameraPosition: true,
      onStyleLoadedCallback: () {},
    );
  }
}