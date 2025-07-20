// active_navigation_logic.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:guide_me/features/map/mapa/dark_map_style.dart';
import 'package:guide_me/features/map/distance_tracker.dart';

class NavigationLogic {
  final List<LatLng> routePoints;
  final LatLng destination;
  final String destinationName;
  final VoidCallback onUpdate;
  final Function(String) onRecalculated;

  GoogleMapController? mapController;
  StreamSubscription<Position>? positionStream;
  Timer? interpolationTimer;

  LatLng? _prevLocation;
  LatLng? _targetLocation;
  DateTime? _lastUpdate;
  double bearing = 0;

  DateTime? _arrivalTime;
  double _remainingDistance = 0;
  int _remainingDuration = 0;
  double _distanceToNextTurn = 0;
  String? _maneuver;

  List<dynamic> steps = [];
  int currentStepIndex = 0;
  String? roadName;
  String? roadNumber;
  List<LatLng> fullRoutePolyline = [];
  bool isError = false;

  final DistanceTracker _distanceTracker = DistanceTracker();

  NavigationLogic({
    required this.routePoints,
    required this.destination,
    required this.destinationName,
    required this.onUpdate,
    required this.onRecalculated,
  });

  void dispose() {
    positionStream?.cancel();
    interpolationTimer?.cancel();
  }

  bool get hasError => isError;
  List<LatLng> get polylinePoints => fullRoutePolyline;
  String? get streetName => roadName;
  String? get nextInstruction => _getNextInstruction();
  String? get maneuverType => _maneuver;
  double get distanceToNextTurn => _distanceToNextTurn;
  double get remainingDistance => _remainingDistance;
  int get remainingDuration => _remainingDuration;
  DateTime? get arrivalTime => _arrivalTime;
  String? get maneuver => _maneuver;

  void handleMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController?.setMapStyle(darkMapStyle);
  }

  Future<void> initLogic(BuildContext context) async {
    await _distanceTracker.initialize();
    await fetchRouteSteps();
    await _startLocationUpdates(context);
  }

  Future<void> fetchRouteSteps() async {
    final start = routePoints.first;
    final end = routePoints.last;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&language=pl&key=AIzaSyCvEzWl7SGN5LEAbaIs7nN91M7We3VHr5E');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawSteps = data['routes']?[0]?['legs']?[0]?['steps'];
      if (rawSteps != null && rawSteps.isNotEmpty) {
        fullRoutePolyline.clear();
        for (var step in rawSteps) {
          final points = _decodePolyline(step['polyline']['points']);
          fullRoutePolyline.addAll(points);
        }
        steps = rawSteps;
        currentStepIndex = 0;
        _updateNextInstruction();
        _calculateETA();
        isError = false;
      } else {
        isError = true;
      }
    } else {
      isError = true;
    }
    onUpdate();
  }

  Future<void> _startLocationUpdates(BuildContext context) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }

    final pos = await Geolocator.getCurrentPosition();
    _prevLocation = LatLng(pos.latitude, pos.longitude);
    _targetLocation = _prevLocation;
    _lastUpdate = DateTime.now();
    await _distanceTracker.updateDistance(pos);
    onUpdate();

    final locationSettings = Theme.of(context).platform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            intervalDuration: const Duration(milliseconds: 200),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
          );

    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) async {
      _prevLocation = _targetLocation;
      _targetLocation = LatLng(position.latitude, position.longitude);
      bearing = position.heading;
      _lastUpdate = DateTime.now();
      await _distanceTracker.updateDistance(position);
      _updateLiveNavigationData(context);
      onUpdate();
    });

    interpolationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_prevLocation == null || _targetLocation == null || _lastUpdate == null) return;
      final elapsed = DateTime.now().difference(_lastUpdate!).inMilliseconds / 200;
      final t = elapsed.clamp(0.0, 1.0);
      final lat = _lerp(_prevLocation!.latitude, _targetLocation!.latitude, t);
      final lng = _lerp(_prevLocation!.longitude, _targetLocation!.longitude, t);
      final interpolated = LatLng(lat, lng);

      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: interpolated,
          bearing: bearing,
          zoom: 18,
          tilt: 45,
        )));
      }
      onUpdate();
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _calculateETA() {
    _remainingDistance = 0;
    for (int i = currentStepIndex; i < steps.length - 1; i++) {
      final stepStart = LatLng(steps[i]['start_location']['lat'], steps[i]['start_location']['lng']);
      final stepEnd = LatLng(steps[i]['end_location']['lat'], steps[i]['end_location']['lng']);
      _remainingDistance += _calculateDistance(stepStart, stepEnd);
    }
    final durationMinutes = (_remainingDistance / 50 * 60).round();
    _remainingDuration = durationMinutes;
    _arrivalTime = DateTime.now().add(Duration(minutes: durationMinutes));
  }

  void _updateLiveNavigationData(BuildContext context) {
    if (_targetLocation == null || steps.isEmpty) return;
    final currentStep = steps[currentStepIndex];
    final stepEnd = LatLng(currentStep['end_location']['lat'], currentStep['end_location']['lng']);
    final distanceToStepEnd = _calculateDistance(_targetLocation!, stepEnd) * 1000;
    _distanceToNextTurn = distanceToStepEnd;

    if (distanceToStepEnd < 100 && currentStepIndex < steps.length - 1) {
      currentStepIndex++;
      _updateNextInstruction();
    }

    final distanceToStepStart = _calculateDistance(
      _targetLocation!,
      LatLng(currentStep['start_location']['lat'], currentStep['start_location']['lng']),
    ) * 1000;

    if (distanceToStepStart > 100) {
      fetchRouteSteps();
      onRecalculated('Zmieniono trasę — przeliczono nową trasę');
    }

    _calculateETA();
  }

  void _updateNextInstruction() {
    if (steps.isEmpty) return;
    final step = steps[currentStepIndex];
    String instruction = step['html_instructions'] ?? '';
    instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), '');
    roadName = _extractRoadName(instruction);
    roadNumber = _extractRoadNumber(instruction);
    _maneuver = step['maneuver'] ?? 'straight';
  }

  String? _extractRoadName(String instruction) {
    final match = RegExp(r'\bna (ul\\.|alei|ulicy)? ?(.*?)\b').firstMatch(instruction);
    return match != null ? match.group(2) : null;
  }

  String? _extractRoadNumber(String instruction) {
    final match = RegExp(r'([A-Z]?[0-9]{2,4})').firstMatch(instruction);
    return match?.group(1);
  }

  String? _getNextInstruction() {
    return 'Za ${_distanceToNextTurn.toStringAsFixed(0)} m skręć ${_maneuver == 'left' ? 'w lewo' : _maneuver == 'right' ? 'w prawo' : 'prosto'}';
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final aCalc = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(aCalc), sqrt(1 - aCalc));
    return R * c / 1000;
  }

  double _degToRad(double deg) => deg * pi / 180;
}
