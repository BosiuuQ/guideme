import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DirectionsService {
  static const _token = 'sk.eyJ1IjoiYm9zaXV1cSIsImEiOiJjbWJtbTRlcmwxNnh4MmpxdHEyZTR2ZXZ3In0.Yu0FVUSeR4ain51ihyEwZQ';

  Future<DirectionsResult> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '$originLng,$originLat;$destLng,$destLat'
      '?steps=true&geometries=polyline6&access_token=$_token',
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Directions API error: ${res.body}');
    }
    final data = jsonDecode(res.body)['routes'][0];
    final geometry = data['geometry'] as String;
    final legs = (data['legs'] as List).cast<Map<String, dynamic>>();
    final steps = legs
        .expand((leg) => (leg['steps'] as List).cast<Map<String, dynamic>>())
        .map(NavigationStep.fromJson)
        .toList();

    // Domyślnie bez parametru precision
    final points = PolylinePoints()
        .decodePolyline(geometry)
        .map((p) => Point(coordinates: Position(p.longitude, p.latitude)))
        .toList();

    return DirectionsResult(points: points, steps: steps);
  }
}

class DirectionsResult {
  final List<Point> points;
  final List<NavigationStep> steps;
  DirectionsResult({required this.points, required this.steps});
}

class NavigationStep {
  final String instruction;
  final double distance; // metry
  final double duration; // sekundy
  final Position maneuverPoint;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuverPoint,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    final mani = json['maneuver'] as Map<String, dynamic>;
    return NavigationStep(
      instruction: mani['instruction'] as String,
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      maneuverPoint: Position(
        (mani['location'][0] as num).toDouble(),
        (mani['location'][1] as num).toDouble(),
      ),
    );
  }
}
