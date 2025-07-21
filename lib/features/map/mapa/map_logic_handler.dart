// 🔄 FINALNA WERSJA map_logic_handler.dart z płynnym 60/120 FPS i bez obracania gdy stoisz
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' as services;
import 'package:guide_me/features/map/distance_tracker.dart';
import 'package:guide_me/features/map/mapa/dark_map_style.dart';

class MapLogicHandler {
  final VoidCallback onUpdate;
  final TickerProvider tickerProvider;
  late final Ticker _ticker;

  MapLogicHandler({required this.onUpdate, required this.tickerProvider}) {
    _ticker = tickerProvider.createTicker(_onTick);
  }

  static const Duration _locationInterval = Duration(milliseconds: 200);
  GoogleMapController? _controller;
  final DistanceTracker _distanceTracker = DistanceTracker();
  StreamSubscription<Position>? _positionStream;

  LatLng? _prevLocation;
  LatLng? _targetLocation;
  DateTime? _lastUpdate;
  double _bearing = 0.0;

  BitmapDescriptor? _customIcon;
  Marker? _userMarker;

  bool followUser = true;
  bool forceFollowUser = true;
  bool mapReady = false;

  double _currentSpeed = 0.0;
  double _lastSpeed = 0.0;
  double _cameraBearing = 0.0; // aktualne wychylenie kamery

  LatLng? get targetLocation => _targetLocation;

  Future<void> initializeTracking(BuildContext context) async {
    await _loadCustomMarker();
    await _distanceTracker.initialize();

    final permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) return;

    final pos = await Geolocator.getCurrentPosition();
    _prevLocation = LatLng(pos.latitude, pos.longitude);
    _targetLocation = _prevLocation;
    _lastUpdate = DateTime.now();
    _currentSpeed = pos.speed * 3.6;
    _cameraBearing = 0.0;
    _updateUserMarker(_targetLocation!);

    onUpdate();
    _ticker.start();

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: _locationInterval,
      ),
    ).listen((position) {
      _prevLocation = _targetLocation;
      _targetLocation = LatLng(position.latitude, position.longitude);
      _lastSpeed = _currentSpeed;
      _currentSpeed = position.speed * 3.6;

      final newBearing = _calculateBearing(_prevLocation!, _targetLocation!);
      if (_currentSpeed > 2.5) {
        _bearing = newBearing;
      }

      _lastUpdate = DateTime.now();
      _distanceTracker.updateDistance(position);
    });
  }

  void _onTick(Duration elapsed) {
    if (!mapReady || _prevLocation == null || _targetLocation == null || _lastUpdate == null) return;

    final elapsedMs = DateTime.now().difference(_lastUpdate!).inMilliseconds;
    final t = (elapsedMs / _locationInterval.inMilliseconds).clamp(0.0, 1.0);

    final lat = _lerp(_prevLocation!.latitude, _targetLocation!.latitude, t);
    final lng = _lerp(_prevLocation!.longitude, _targetLocation!.longitude, t);
    final interpolated = LatLng(lat, lng);

    // płynne obracanie
    if (_currentSpeed > 2.5) {
      _cameraBearing = _lerpAngle(_cameraBearing, _bearing, 0.05); // wygładzenie
    } else {
      _cameraBearing = _lerpAngle(_cameraBearing, 0, 0.05);
    }

    _updateUserMarker(interpolated);

    if ((followUser || forceFollowUser) && _controller != null) {
      _controller!.moveCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: interpolated,
          zoom: 17,
          bearing: _cameraBearing,
          tilt: 45,
        ),
      ));
    }

    onUpdate();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _lerpAngle(double a, double b, double t) {
    final delta = ((((b - a) + 180) % 360) - 180);
    return (a + delta * t) % 360;
  }

  Future<void> _loadCustomMarker() async {
    final bd = await services.rootBundle.load('assets/icons/marker.png');
    final codec = await ui.instantiateImageCodec(
      bd.buffer.asUint8List(),
      targetWidth: 140,
      targetHeight: 140,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    _customIcon = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  void _updateUserMarker(LatLng pos) {
    _userMarker = Marker(
      markerId: const MarkerId('user'),
      position: pos,
      icon: _customIcon ?? BitmapDescriptor.defaultMarker,
      rotation: _bearing,
      anchor: const Offset(0.5, 0.5),
      flat: true,
    );
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lon1 = from.longitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final lon2 = to.longitude * pi / 180;
    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  Widget buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _targetLocation ?? const LatLng(52.2297, 21.0122),
        zoom: 17,
        tilt: 45,
      ),
      onMapCreated: (ctrl) async {
        _controller = ctrl;
        await _controller!.setMapStyle(darkMapStyle);
        mapReady = true;

        if (_targetLocation != null) {
          _controller!.moveCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: _targetLocation!, zoom: 17, bearing: 0, tilt: 45),
          ));
        }
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: _userMarker != null ? {_userMarker!} : {},
      onCameraMoveStarted: () {
        if (!forceFollowUser) {
          followUser = false;
          onUpdate();
        }
      },
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
    );
  }

  Widget buildSpeedometer() {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _lastSpeed, end: _currentSpeed),
        duration: const Duration(milliseconds: 250),
        builder: (ctx, val, child) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              val.toInt().toString(),
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
            const Text('km/h', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  void enableFollowUser() {
    followUser = forceFollowUser = true;
    if (_targetLocation != null && _controller != null && mapReady) {
      _controller!.moveCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _targetLocation!, zoom: 17, bearing: _bearing, tilt: 45),
      ));
    }
    onUpdate();
  }

  void dispose() {
    _ticker.dispose();
    _positionStream?.cancel();
  }
}
