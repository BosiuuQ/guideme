import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class RoutePlannerView extends StatelessWidget {
  final LatLng origin;
  final LatLng destination;
  final String title;

  const RoutePlannerView({
    Key? key,
    required this.origin,
    required this.destination,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // tutaj logika mapboxa
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text("Mapa trasy z Mapboxa 🚀"),
      ),
    );
  }
}
