import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'package:guide_me/mapbox_shim.dart';
import 'package:geolocator/geolocator.dart';


class MapLogicHandler {
  VoidCallback? onUpdate;
  TickerProvider? tickerProvider;

  mb.MapboxMapController? controller;
  mb.Symbol? _userSymbol;

  Position? _lastGpsPosition;
  DateTime? _lastGpsTime;

  LatLng? _displayPos;
  LatLng? _targetLocation;
  double _bearing = 0.0;
  double _currentSpeed = 0.0;
  double _cameraBearing = 0.0;

  final double _speedAlpha = 0.03;
  final double _bearingAlpha = 0.12;
  final double _correctionPerSecond = 1.0;
  final double _maxCorrectionFactor = 2.0;
  final double _minSpeedForBearing = 0.1;


  // Alpha-Beta filter state (simple predictive filter to smooth position and velocity)
  double _abAlpha = 0.45; // position correction
  double _abBeta = 0.20; // velocity correction
  double? _estLat;
  double? _estLon;
  double _estVLat = 0.0; // degrees per second approx
  double _estVLon = 0.0;
  // Logger (CSV) - will append lines if enabled
  bool _enableLogger = true;
  String _logBuffer = "timestamp,measLat,measLon,estLat,estLon,measSpeed,currentSpeed,dt,distToTarget\n";
  // Ticker
  Ticker? _ticker;
  DateTime? _lastTick;
  // Accumulator to run logic at lower tick rate (30 Hz)
  double _tickAccumulator = 0.0;
  final double _desiredTickInterval = 1.0/30.0;

  // moving average window for measured speeds to reduce GPS jitter
  final List<double> _speedWindow = <double>[];
  final int _speedWindowSize = 11;

  // limits on acceleration/deceleration (m/s^2) to prevent sudden jumps
  final double _maxAccelPerSec = 1.5; // max increase per second (reduced)
  final double _maxDecelPerSec = 3.0; // max decrease per second (reduced)

  StreamSubscription<Position>? _posSub;

  MapLogicHandler({this.onUpdate, this.tickerProvider});

  Future<void> onMapCreated(mb.MapboxMapController ctrl) async {
    controller = ctrl;
    try {
      if (tickerProvider != null) {
        _ticker = tickerProvider!.createTicker(_onTick);
        _ticker!.start();
      }
    } catch (e) {}
    _initLocationListening();
  }

  Future<void> dispose() async {
    await _posSub?.cancel();
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  Future<void> _initLocationListening() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      try {
        final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        _onNewGps(p);
      } catch (e) {}

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0),
      ).listen((pos) {
        _onNewGps(pos);
      });
    } catch (e) {}
    _ticker?.start();
  }

  void _onNewGps(Position pos) {
    final now = DateTime.now();
    double measuredSpeed = pos.speed != null && pos.speed!.isFinite ? pos.speed! : 0.0;
    if (_lastGpsPosition != null && _lastGpsTime != null) {
      final dt = now.difference(_lastGpsTime!).inMilliseconds / 1000.0;
      if (dt > 0) {
        final meters = _distanceMeters(_lastGpsPosition!.latitude, _lastGpsPosition!.longitude, pos.latitude, pos.longitude);
        final calcSpeed = meters / dt;
        if (measuredSpeed <= 0.01) measuredSpeed = calcSpeed;
      }
    }

    // add measuredSpeed into sliding window for a short moving average to reduce spike noise
    if (_speedWindow.length >= _speedWindowSize) {
      _speedWindow.removeAt(0);
    }
    _speedWindow.add(measuredSpeed);
    double windowAvg = (_speedWindow.isNotEmpty ? ( () {
      final tmp = List<double>.from(_speedWindow)..sort();
      return tmp[tmp.length ~/ 2];
    } )() : 0.0);

    // compute dt since last GPS update to limit acceleration/deceleration
    double desiredSpeed = windowAvg;
    if (_lastGpsTime != null) {
      final dt = now.difference(_lastGpsTime!).inMilliseconds / 1000.0;
      if (dt > 0) {
        final double maxInc = _maxAccelPerSec * dt;
        final double maxDec = _maxDecelPerSec * dt;
        final double diff = desiredSpeed - _currentSpeed;
        final double clampedDiff = diff.clamp(-maxDec, maxInc);
        desiredSpeed = _currentSpeed + clampedDiff;
      }
    }

    // apply smoothing to the (clamped) desired speed
    _currentSpeed = (_speedAlpha * desiredSpeed) + ((1 - _speedAlpha) * _currentSpeed);

    _targetLocation = LatLng(pos.latitude, pos.longitude);

    // Alpha-Beta filter measurement update
    if (_estLat == null || _estLon == null) {
      // initialize
      _estLat = pos.latitude;
      _estLon = pos.longitude;
      _estVLat = 0.0;
      _estVLon = 0.0;
    } else {
      final now2 = DateTime.now();
      final dtMeas = (_lastGpsTime != null) ? now2.difference(_lastGpsTime!).inMilliseconds / 1000.0 : 0.0;
      if (dtMeas > 0) {
        // predict
        _estLat = _estLat! + _estVLat * dtMeas;
        _estLon = _estLon! + _estVLon * dtMeas;
        // residual in degrees
        final resLat = pos.latitude - _estLat!;
        final resLon = pos.longitude - _estLon!;
        // update
        _estLat = _estLat! + _abAlpha * resLat;
        _estLon = _estLon! + _abAlpha * resLon;
        _estVLat = _estVLat + (_abBeta * resLat) / dtMeas;
        _estVLon = _estVLon + (_abBeta * resLon) / dtMeas;
      }
    }

    // log measurement
    try {
      if (_enableLogger) {
        final ts = DateTime.now().toIso8601String();
        final measSpeed = (pos.speed != null && pos.speed!.isFinite) ? pos.speed! : 0.0;
        final estLatStr = _estLat?.toStringAsFixed(7) ?? '';
        final estLonStr = _estLon?.toStringAsFixed(7) ?? '';
        _logBuffer += '\$ts,${pos.latitude},${pos.longitude},' + estLatStr + ',' + estLonStr + ',\$measSpeed,\$_currentSpeed,0.0,0.0\n';
      }
    } catch (e) {}

    \1
      final bearingNow = _calculateBearing(LatLng(_lastGpsPosition!.latitude, _lastGpsPosition!.longitude), _targetLocation!);
      if (_currentSpeed > _minSpeedForBearing) {
        _bearing = bearingNow;
      }
    }

    if (_displayPos == null) {
      _displayPos = LatLng(pos.latitude, pos.longitude);
      try {
        if (_userSymbol == null && controller != null) {
          controller!.addSymbol(SymbolOptions(geometry: _displayPos!, iconImage: 'assets/icons/user_dot.png', iconSize: 0.40)).then((sym) {
            _userSymbol = sym;
          }).catchError((e) {});
        } else if (_userSymbol != null && controller != null) {
          controller!.updateSymbolImmediate(_userSymbol!, _displayPos!);
        }
        if (controller != null) controller!.moveCameraImmediate(_displayPos!, 19, bearing: _animBearing ?? _currentBearing);
      } catch (e) {}
    }

    _lastGpsPosition = pos;
    _lastGpsTime = now;

    // ensure immediate UI update
    try { onUpdate?.call(); } catch (e) {}
  }

  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    if (_lastTick == null) {
      _lastTick = now;
      return;
    }
    final rawDt = now.difference(_lastTick!).inMilliseconds / 1000.0;
    _lastTick = now;
    if (rawDt <= 0) return;

    // accumulate elapsed time and process at _desiredTickInterval (30 Hz) to reduce CPU and smooth movements
    _tickAccumulator += rawDt;
    if (_tickAccumulator < _desiredTickInterval) return;
    // cap dt to avoid huge jumps on resume
    final dt = _tickAccumulator.clamp(0.0, 0.5);
    _tickAccumulator = 0.0;

    if (_displayPos == null) return;

    if (_currentSpeed > 0.001) {
      // apply small slowdown factor so cursor runs slightly slower than raw GPS speed
      final moveMeters = _currentSpeed * dt * 0.75;
      // compute tentative new position
      final newPos = _destinationPoint(_displayPos!, _bearing, moveMeters);
      // prevent backward jumps: if moving increases distance to target significantly, reduce movement
      if (_targetLocation != null) {
        final prevDist = _distanceMeters(_displayPos!.latitude, _displayPos!.longitude, _targetLocation!.latitude, _targetLocation!.longitude);
        final newDist = _distanceMeters(newPos.latitude, newPos.longitude, _targetLocation!.latitude, _targetLocation!.longitude);
        // allow small epsilon due to rounding
        if (newDist <= prevDist + 0.5) {
          _displayPos = newPos;
        } else {
          // discard forward movement that would go away from target; instead apply a reduced correction toward target
          // keep _displayPos unchanged here to avoid reverse motion
        }
      } else {
        _displayPos = newPos;
      }
    }

    if (_targetLocation != null) {
      final distToTarget = _distanceMeters(_displayPos!.latitude, _displayPos!.longitude, _targetLocation!.latitude, _targetLocation!.longitude);
      if (distToTarget > 0.01) {
        double corrSpeed = (_correctionPerSecond * (distToTarget / 5.0)).clamp(0.0, _maxCorrectionFactor) * 0.3;
        final corrMeters = corrSpeed * dt;
        if (corrMeters >= distToTarget) {
          _displayPos = _targetLocation;
        } else {
          final corrBearing = _calculateBearing(_displayPos!, _targetLocation!);
          _displayPos = _destinationPoint(_displayPos!, corrBearing, corrMeters);
        }
      }
    }

    if (_currentSpeed > _minSpeedForBearing) {
      _cameraBearing = _lerpAngle(_cameraBearing, _bearing, _bearingAlpha);
    } else {
      _cameraBearing = _lerpAngle(_cameraBearing, 0.0, _bearingAlpha);
    }

    try {
      if (_userSymbol != null && controller != null && _displayPos != null) {
        controller!.updateSymbolImmediate(_userSymbol!, _displayPos!);
        controller!.moveCameraImmediate(_displayPos!, 19, bearing: _animBearing ?? _currentBearing);
      }
    } catch (e) {}

    try { onUpdate?.call(); } catch (e) {}

  }


  LatLng _destinationPoint(LatLng from, double bearingDeg, double distanceMeters) {
    final double R = 6371000.0;
    final double brng = bearingDeg * math.pi / 180.0;
    final double lat1 = from.latitude * math.pi / 180.0;
    final double lon1 = from.longitude * math.pi / 180.0;
    final double dDivR = distanceMeters / R;
    final double lat2 = math.asin(math.sin(lat1) * math.cos(dDivR) + math.cos(lat1) * math.sin(dDivR) * math.cos(brng));
    final double lon2 = lon1 + math.atan2(math.sin(brng) * math.sin(dDivR) * math.cos(lat1), math.cos(dDivR) - math.sin(lat1) * math.sin(lat2));
    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    final R = 6371000.0;
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final dPhi = (lat2 - lat1) * math.pi / 180.0;
    final dLambda = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) + math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _lerpAngle(double a, double b, double t) {
    final delta = ((((b - a) + 180) % 360) - 180);
    return (a + delta * t) % 360;
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lon1 = from.longitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final lon2 = to.longitude * math.pi / 180;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }


  double get currentSpeed => _currentSpeed;
  double get currentSpeedKmh => _currentSpeed * 3.6;
  double get currentBearing => _bearing;

  void setUserSymbol(mb.Symbol symbol) { _userSymbol = symbol; }
  LatLng? get displayPosition => _displayPos;

  Future<void> snapTo(LatLng pos, {bool moveCamera = false}) async {
    _displayPos = pos;
    _targetLocation = pos;
    _lastGpsPosition = null;
    _lastGpsTime = null;
    try {
      if (_userSymbol == null && controller != null) {
        _userSymbol = await controller!.addSymbol(SymbolOptions(geometry: pos, iconImage: 'assets/icons/user_dot.png'));
      } else if (_userSymbol != null && controller != null) {
        controller!.updateSymbolImmediate(_userSymbol!, pos);
      }
      if (moveCamera && controller != null) controller!.moveCameraImmediate(pos, 19, bearing: null);
    } catch (e) {}
    try { onUpdate?.call(); } catch (e) {}
  }
}
