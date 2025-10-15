// Gas station service to fetch nearby gas stations using Overpass API
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:guide_me/mapbox_shim.dart' as mb;

class GasStation {
  final String id;
  final String name;
  final mb.LatLng position;
  final String? brand;
  final String? operator;

  GasStation({
    required this.id,
    required this.name,
    required this.position,
    this.brand,
    this.operator,
  });
}

class GasStationService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Fetch gas stations within a radius (in meters) around the given position
  static Future<List<GasStation>> fetchNearbyGasStations(
      mb.LatLng center,
      double radiusMeters,
      ) async {
    try {
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      // Overpass QL query to find fuel/gas stations
      final query = '''
[out:json][timeout:25];
(
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

  node["amenity"="fuel"](around:$radiusMeters,${center.latitude},${center.longitude});
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

  way["amenity"="fuel"](around:$radiusMeters,${center.latitude},${center.longitude});
);
out center;
''';

      print('[GasStationService] Querying Overpass API for gas stations near ${center.latitude},${center.longitude} within ${radiusMeters}m radius');

      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: query,
        headers: {'Content-Type': 'text/plain'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        print('[GasStationService] Failed to fetch gas stations: HTTP ${response.statusCode}');
        print('[GasStationService] Response body: ${response.body}');
        return [];
      }

      print('[GasStationService] Successfully received response from Overpass API');
      final data = json.decode(response.body);
      final elements = data['elements'] as List<dynamic>? ?? [];
      print('[GasStationService] Found ${elements.length} elements in response');

      final List<GasStation> gasStations = [];
      for (var element in elements) {
        try {
          final tags = element['tags'] as Map<String, dynamic>? ?? {};

          // Get coordinates - for nodes use lat/lon, for ways use center
          double? lat;
          double? lon;

          if (element['type'] == 'node') {
            lat = (element['lat'] as num?)?.toDouble();
            lon = (element['lon'] as num?)?.toDouble();
          } else if (element['type'] == 'way' && element['center'] != null) {
            lat = (element['center']['lat'] as num?)?.toDouble();
            lon = (element['center']['lon'] as num?)?.toDouble();
          }

          if (lat == null || lon == null) continue;

          final name = tags['name'] as String? ??
              tags['brand'] as String? ??
              tags['operator'] as String? ??
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

              'Stacja paliw';

          gasStations.add(GasStation(
            id: element['id'].toString(),
            name: name,
            position: mb.LatLng(lat, lon),
            brand: tags['brand'] as String?,
            operator: tags['operator'] as String?,
          ));
        } catch (e) {
          print('[GasStationService] Error parsing element: $e');
        }
      }

      print('[GasStationService] Found ${gasStations.length} gas stations');
      return gasStations;
    } catch (e) {
      print('[GasStationService] Error fetching gas stations: $e');
      return [];
    }
  }
}