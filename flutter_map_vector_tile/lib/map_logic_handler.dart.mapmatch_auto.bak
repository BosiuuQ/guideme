
// map_logic_handler.dart (updated v4)
// Major fixes to address persistent delay, jitter, and non-stopping:
// - Use sample received time (receivedAt) to compute exact delayed target, avoiding backlog caused by old sample timestamps.
// - Accuracy-weighted exponential smoothing (EMA) for animated position to reduce GPS noise.
// - Smoothed speed and position variance used for robust stationary detection.
// - Conservative catch-up logic that accelerates when backlog exists but avoids overshoot.
// - Increased thresholds and hold timings to prevent flicker on stop/start.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class LocationSample {
  final double latitude;
  final double longitude;
  final double accuracy; // meters
  final double? bearing; // degrees, nullable
  final DateTime timestamp; // original sample time (if provided)
  final DateTime receivedAt; // when the app received the sample

  LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.bearing,
    DateTime? timestamp,
    DateTime? receivedAt,
  })  : timestamp = timestamp ?? DateTime.now(),
        receivedAt = receivedAt ?? DateTime.now();

  @override
  String toString() =>
      'LocationSample($latitude, $longitude, acc:$accuracy, bearing:$bearing, time:$timestamp, recv:$receivedAt)';
}

class AnimatedLocation {
  final double latitude;
  final double longitude;
  final double bearing; // degrees
  final DateTime timestamp;

  AnimatedLocation({
    required this.latitude,
    required this.longitude,
    required this.bearing,
    required this.timestamp,
  });

  @override
  String toString() =>
      'AnimatedLocation($latitude,$longitude,bearing:$bearing,time:$timestamp)';
}

/// Simple utility: linear interpolation between two doubles
double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Interpolate latitude/longitude taking shortest path on the globe for small distances
double _interpLat(double a, double b, double t) => _lerp(a, b, t);
double _interpLng(double a, double b, double t) => _lerp(a, b, t);

/// Normalize bearing to [0,360)
double _normalizeBearing(double b) {
  double v = b % 360;
  if (v < 0) v += 360;
  return v;
}

/// Interpolate bearing with shortest rotation direction
double _interpBearing(double a, double b, double t) {
  a = _normalizeBearing(a);
  b = _normalizeBearing(b);
  double diff = b - a;
  if (diff.abs() > 180) {
    if (diff > 0) diff -= 360;
    else diff += 360;
  }
  return _normalizeBearing(a + diff * t);
}

/// Simple distance (Haversine) for small distances — returns meters
double haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0; // Earth radius in meters
  final phi1 = lat1 * (math.pi / 180.0);
  final phi2 = lat2 * (math.pi / 180.0);
  final dphi = (lat2 - lat1) * (math.pi / 180.0);
  final dlambda = (lon2 - lon1) * (math.pi / 180.0);

  final a = math.sin(dphi/2) * math.sin(dphi/2) +
      math.cos(phi1) * math.cos(phi2) *
      math.sin(dlambda/2) * math.sin(dlambda/2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
  return R * c;
}

/// Compute bearing (degrees) from point A to B
double computeBearing(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = lat1 * (math.pi / 180.0);
  final phi2 = lat2 * (math.pi / 180.0);
  final lambda1 = lon1 * (math.pi / 180.0);
  final lambda2 = lon2 * (math.pi / 180.0);

  final y = math.sin(lambda2 - lambda1) * math.cos(phi2);
  final x = math.cos(phi1)*math.sin(phi2) - math.sin(phi1)*math.cos(phi2)*math.cos(lambda2 - lambda1);
  final theta = math.atan2(y, x);
  return (_normalizeBearing(theta * 180.0 / math.pi));
}

/// Represents a straight polyline route for optional map-matching.
class RoutePolyline {
  final List<List<double>> points; // [[lat, lng], ...]
  RoutePolyline(this.points);
}

/// Main handler
class MapLogicHandler {
  /// how long to delay incoming samples (in milliseconds). For your request: 1000ms.
  final int delayMs;

  /// smoothing/tick rate (frame rate for animation). Default 60 fps.
  final int fps;

  /// Optional route for simple map-matching (snapping to nearest segment when within thresholdMeters).
  final RoutePolyline? route;
  final double mapMatchThresholdMeters;

  // debug flag
  final bool debug;

  // thresholds and parameters
  final double stopSpeedThresholdMs = 0.5; // m/s
  final double startSpeedThresholdMs = 0.9; // m/s
  final double stationaryDeadZoneMeters = 1.2; // within this distance we snap and hold
  final int stationaryHoldMs = 1000;
  final int movingHoldMs = 600;
  final int speedWindow = 5;

  // EMA smoothing base (ms) - adapted by accuracy
  final double baseSmoothingMs = 220.0;

  // Internal buffers
  final List<LocationSample> _buffer = [];

  // Last known animated state
  AnimatedLocation? _lastAnimated;
  LocationSample? _lastDelayedReturnedSample;

  // recent delayed samples for speed averaging
  final List<LocationSample> _recentDelayed = [];

  // smoothed speed and variance
  double _smoothedSpeed = 0.0; // m/s
  double _smoothedVar = 0.0; // m^2

  // EMA state for animated lat/lng (use lat/lng directly)
  double? _emaLat;
  double? _emaLng;
  double? _emaBearing;

  // stationary state with hysteresis
  bool _stationary = false;
  DateTime? _stationaryCandidateSince;
  DateTime? _movingCandidateSince;

  // Timer to drive frame-based interpolation
  Timer? _ticker;
  bool _running = false;

  // Stream controller for UI
  final StreamController<AnimatedLocation> _outController =
      StreamController<AnimatedLocation>.broadcast();

  Stream<AnimatedLocation> get onAnimatedLocation => _outController.stream;

  MapLogicHandler({
    this.delayMs = 1000,
    this.fps = 60,
    this.route,
    this.mapMatchThresholdMeters = 20.0,
    this.debug = false,
  });

  /// Call this whenever you get a new raw GPS sample from the system/location stream.
  /// IMPORTANT: pass receivedAt: DateTime.now() if you can't provide original receive time.
  void onLocation(LocationSample sample) {
    // ensure receivedAt is set to now if not provided by source
    final s = LocationSample(
      latitude: sample.latitude,
      longitude: sample.longitude,
      accuracy: sample.accuracy,
      bearing: sample.bearing,
      timestamp: sample.timestamp,
      receivedAt: sample.receivedAt,
    );

    _buffer.add(s);

    // Trim old samples relative to latest receivedAt
    _buffer.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    final latest = _buffer.last;
    final cutoff = latest.receivedAt.subtract(Duration(seconds: 12));
    while (_buffer.isNotEmpty && _buffer.first.receivedAt.isBefore(cutoff)) {
      _buffer.removeAt(0);
    }
  }

  /// Start the engine (begins ticker that emits animated positions)
  void start() {
    if (_running) return;
    _running = true;
    final period = Duration(milliseconds: (1000 / fps).round());
    _ticker = Timer.periodic(period, (_) => _tick());
  }

  /// Stop the engine
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
  }

  /// Clean up
  Future<void> dispose() async {
    stop();
    await _outController.close();
  }

  /// Find delayed sample by receivedAt times (interpolates exactly at latest.receivedAt - delayMs)
  LocationSample? _findDelayedSampleByReceived() {
    if (_buffer.length < 1) return null;
    _buffer.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    final latest = _buffer.last;
    final targetTime = latest.receivedAt.subtract(Duration(milliseconds: delayMs));

    // If targetTime is after latest.receivedAt (shouldn't happen), return latest
    if (targetTime.isAfter(latest.receivedAt)) {
      return latest;
    }

    // find prev and next around targetTime based on receivedAt
    LocationSample? prev;
    LocationSample? next;
    for (final s in _buffer) {
      if (s.receivedAt.isBefore(targetTime) || s.receivedAt.isAtSameMomentAs(targetTime)) {
        prev = s;
      } else {
        next = s;
        break;
      }
    }

    if (prev == null && next == null) return latest;
    if (prev != null && next == null) return prev;
    if (prev == null && next != null) return next;

    final totalMs = next!.receivedAt.difference(prev!.receivedAt).inMilliseconds;
    if (totalMs <= 0) return prev;
    final elapsedMs = targetTime.difference(prev.receivedAt).inMilliseconds;
    double frac = elapsedMs / totalMs;
    frac = frac.clamp(0.0, 1.0);

    final lat = _lerp(prev.latitude, next.latitude, frac);
    final lng = _lerp(prev.longitude, next.longitude, frac);
    final acc = _lerp(prev.accuracy, next.accuracy, frac);

    double? bearing;
    if (prev.bearing != null && next.bearing != null) {
      bearing = _interpBearing(prev.bearing!, next.bearing!, frac);
    } else if (prev.bearing != null) {
      bearing = prev.bearing;
    } else if (next.bearing != null) {
      bearing = next.bearing;
    }

    return LocationSample(
      latitude: lat,
      longitude: lng,
      accuracy: acc,
      bearing: bearing,
      timestamp: prev.timestamp.add(Duration(milliseconds: (elapsedMs.toInt()))),
      receivedAt: targetTime,
    );
  }

  double _averageSpeedMsFromRecent(List<LocationSample> samples) {
    if (samples.length < 2) return 0.0;
    double totalDist = 0.0;
    double totalTime = 0.0;
    for (int i = 1; i < samples.length; i++) {
      final a = samples[i - 1];
      final b = samples[i];
      final d = haversineDistanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
      final dt = b.receivedAt.difference(a.receivedAt).inMilliseconds.abs() / 1000.0;
      if (dt > 0) {
        totalDist += d;
        totalTime += dt;
      }
    }
    if (totalTime == 0) return 0.0;
    return totalDist / totalTime;
  }

  double _positionVariance(List<LocationSample> samples, double meanLat, double meanLng) {
    if (samples.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in samples) {
      final d = haversineDistanceMeters(s.latitude, s.longitude, meanLat, meanLng);
      sum += d * d;
    }
    return sum / samples.length;
  }

  /// Optionally snap to route polyline (simple perpendicular snap to nearest segment)
  List<double> _snapToRoute(double lat, double lng) {
    if (route == null || route!.points.length < 2) return [lat, lng];
    double bestDist = double.infinity;
    List<double> bestPoint = [lat, lng];
    for (int i = 0; i < route!.points.length - 1; i++) {
      final a = route!.points[i];
      final b = route!.points[i+1];
      final snap = _projectPointToSegment(lat, lng, a[0], a[1], b[0], b[1]);
      final d = haversineDistanceMeters(lat, lng, snap[0], snap[1]);
      if (d < bestDist) {
        bestDist = d;
        bestPoint = snap;
      }
    }
    if (bestDist <= mapMatchThresholdMeters) return bestPoint;
    return [lat, lng];
  }

  /// Project point P to segment AB and return projected point lat/lng
  List<double> _projectPointToSegment(double plat, double plng, double alat, double alng, double blat, double blng) {
    // Convert to simple Cartesian approx using lat/lng degrees scaled by cos(lat) for lng
    final avgLat = (alat + blat) / 2.0;
    final latScale = 111320.0; // meters per degree lat approx
    final lngScale = 111320.0 * math.cos(avgLat * math.pi / 180.0);

    final ax = (alat) * latScale;
    final ay = (alng) * lngScale;
    final bx = (blat) * latScale;
    final by = (blng) * lngScale;
    final px = (plat) * latScale;
    final py = (plng) * lngScale;

    final vx = bx - ax;
    final vy = by - ay;
    final wx = px - ax;
    final wy = py - ay;
    final vlen2 = vx*vx + vy*vy;
    if (vlen2 == 0) return [alat, alng];
    double t = (vx*wx + vy*wy) / vlen2;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final projx = ax + vx * t;
    final projy = ay + vy * t;
    final rlat = projx / latScale;
    final rlng = projy / lngScale;
    return [rlat, rlng];
  }

  // Ticker tick: compute target (delayed) sample and produce smoothed animated location.
  void _tick() {
    final frameMs = (1000 / fps);
    final targetSample = _findDelayedSampleByReceived();
    if (targetSample == null) {
      return;
    }
    if (debug) {
      try {
        final latestReceived = _buffer.isNotEmpty ? _buffer.last.receivedAt : DateTime.now();
        final backlogMs = latestReceived.difference(targetSample.receivedAt).inMilliseconds.abs();
        print('[MapLogic DEBUG] latestReceived: \$latestReceived targetReceived: \${targetSample.receivedAt} backlogMs: \$backlogMs smoothedSpeed: \$_smoothedSpeed avgRecent: \${_recentDelayed.length} stationary: \$_stationary');
      } catch (e) {
        print('[MapLogic DEBUG] debug print error: \$e');
      }
    }

    // map-match if available
    final snapped = _snapToRoute(targetSample.latitude, targetSample.longitude);
    final targetLat = snapped[0];
    final targetLng = snapped[1];

    // record recent delayed samples for speed/variance
    _recentDelayed.add(LocationSample(
      latitude: targetLat,
      longitude: targetLng,
      accuracy: targetSample.accuracy,
      bearing: targetSample.bearing,
      timestamp: targetSample.timestamp,
      receivedAt: targetSample.receivedAt,
    ));
    if (_recentDelayed.length > speedWindow) _recentDelayed.removeAt(0);

    // compute avg speed and variance
    final avgSpeed = _averageSpeedMsFromRecent(_recentDelayed);
    final meanLat = _recentDelayed.isNotEmpty ? _recentDelayed.map((s)=>s.latitude).reduce((a,b)=>a+b)/_recentDelayed.length : targetLat;
    final meanLng = _recentDelayed.isNotEmpty ? _recentDelayed.map((s)=>s.longitude).reduce((a,b)=>a+b)/_recentDelayed.length : targetLng;
    final varPos = _positionVariance(_recentDelayed, meanLat, meanLng);

    // smooth speed and variance (EMA)
    const double speedAlpha = 0.25;
    const double varAlpha = 0.25;
    _smoothedSpeed = _smoothedSpeed * (1 - speedAlpha) + avgSpeed * speedAlpha;
    _smoothedVar = _smoothedVar * (1 - varAlpha) + varPos * varAlpha;

    // Stationary detection with hysteresis and accuracy check
    final now = DateTime.now();
    final accOk = targetSample.accuracy <= 20.0; // only trust good accuracy for stop decisions
    if (!_stationary) {
      if (_smoothedSpeed < stopSpeedThresholdMs && accOk && math.sqrt(_smoothedVar) <= stationaryDeadZoneMeters) {
        _stationaryCandidateSince ??= now;
        if (now.difference(_stationaryCandidateSince!).inMilliseconds >= stationaryHoldMs) {
          _stationary = true;
          _movingCandidateSince = null;
        }
      } else {
        _stationaryCandidateSince = null;
      }
    } else {
      if (_smoothedSpeed > startSpeedThresholdMs && accOk) {
        _movingCandidateSince ??= now;
        if (now.difference(_movingCandidateSince!).inMilliseconds >= movingHoldMs) {
          _stationary = false;
          _stationaryCandidateSince = null;
        }
      } else {
        _movingCandidateSince = null;
      }
    }

    // Determine target bearing
    double targetBearing;
    if (targetSample.bearing != null) {
      targetBearing = targetSample.bearing!;
    } else if (_lastDelayedReturnedSample != null) {
      targetBearing = computeBearing(_lastDelayedReturnedSample!.latitude, _lastDelayedReturnedSample!.longitude, targetLat, targetLng);
    } else if (_lastAnimated != null) {
      targetBearing = computeBearing(_lastAnimated!.latitude, _lastAnimated!.longitude, targetLat, targetLng);
    } else {
      targetBearing = 0.0;
    }

    _lastDelayedReturnedSample = LocationSample(
      latitude: targetLat,
      longitude: targetLng,
      accuracy: targetSample.accuracy,
      bearing: targetSample.bearing,
      timestamp: targetSample.timestamp,
      receivedAt: targetSample.receivedAt,
    );

    // If stationary, hold last animated position (snap if none)
    if (_stationary) {
      if (_lastAnimated == null) {
        final animated0 = AnimatedLocation(
          latitude: targetLat,
          longitude: targetLng,
          bearing: _normalizeBearing(targetBearing),
          timestamp: DateTime.now(),
        );
        _lastAnimated = animated0;
        _emaLat = animated0.latitude;
        _emaLng = animated0.longitude;
        _emaBearing = animated0.bearing;
        if (debug) print('[MapLogic DEBUG] EMIT initial -> lat:\${animated0.latitude.toStringAsFixed(6)} lng:\${animated0.longitude.toStringAsFixed(6)} bearing:\${animated0.bearing.toStringAsFixed(1)}');
        _outController.add(animated0);
        return;
      } else {
        // keep frozen position (prevent micro-movements), but update bearing slowly
        final newBearing = _interpBearing(_lastAnimated!.bearing, targetBearing, 0.05);
        final hold = AnimatedLocation(
          latitude: _lastAnimated!.latitude,
          longitude: _lastAnimated!.longitude,
          bearing: newBearing,
          timestamp: DateTime.now(),
        );
        _lastAnimated = hold;
        _emaBearing = newBearing;
        if (debug) print('[MapLogic DEBUG] EMIT hold -> lat:\${hold.latitude.toStringAsFixed(6)} lng:\${hold.longitude.toStringAsFixed(6)} bearing:\${hold.bearing.toStringAsFixed(1)}');
        _outController.add(hold);
        return;
      }
    }

    // Not stationary -> animate with EMA smoothing
    // Compute smoothing alpha based on accuracy (higher accuracy => larger alpha => faster responsiveness)
    final acc = targetSample.accuracy.clamp(5.0, 200.0);
    final smoothingMs = baseSmoothingMs * (1.0 + (acc / 25.0)); // accuracy increases smoothing window
    double alpha = frameMs / smoothingMs;
    alpha = alpha.clamp(0.02, 1.0);

    // Catch-up factor: if backlog grows (latest.receivedAt - target.receivedAt) > threshold, accelerate alpha up to 3x
    final latestReceived = _buffer.isNotEmpty ? _buffer.last.receivedAt : DateTime.now();
    final backlogMs = latestReceived.difference(targetSample.receivedAt).inMilliseconds.abs();
    if (backlogMs > 1500) {
      final k = (backlogMs / 1500.0).clamp(1.0, 3.0);
      alpha = (alpha * k).clamp(alpha, 0.95);
    }

    // Initialize EMA if needed
    if (_emaLat == null) {
      _emaLat = targetLat;
      _emaLng = targetLng;
      _emaBearing = _normalizeBearing(targetBearing);
    }

    // Apply EMA to lat/lng and bearing
    _emaLat = _lerp(_emaLat!, targetLat, alpha);
    _emaLng = _lerp(_emaLng!, targetLng, alpha);
    _emaBearing = _interpBearing(_emaBearing ?? targetBearing, targetBearing, alpha.clamp(0.01, 0.8));

    final animated = AnimatedLocation(
      latitude: _emaLat!,
      longitude: _emaLng!,
      bearing: _emaBearing ?? _normalizeBearing(targetBearing),
      timestamp: DateTime.now(),
    );

    _lastAnimated = animated;
    if (debug) print('[MapLogic DEBUG] EMIT animated -> lat:\${animated.latitude.toStringAsFixed(6)} lng:\${animated.longitude.toStringAsFixed(6)} bearing:\${animated.bearing.toStringAsFixed(1)}');
    _outController.add(animated);
  }
}
