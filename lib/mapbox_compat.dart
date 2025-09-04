// Compatibility types to replace Google Maps types so project compiles.
// These are simple holders and do not perform map rendering.
// Use mapbox_gl.MapboxMap for actual rendering elsewhere.
import 'package:flutter/material.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'package:guide_me/mapbox_shim.dart';
import 'dart:typed_data';

class LatLng extends mb.LatLng {
  LatLng(double latitude, double longitude) : super(latitude, longitude);
}

class CameraPosition extends mb.CameraPosition {
  CameraPosition({required LatLng target, double zoom = 0, double bearing = 0, double tilt = 0})
      : super(target: target, zoom: zoom, bearing: bearing, tilt: tilt);
}

class MarkerId {
  final String value;
  const MarkerId(this.value);
  @override
  bool operator ==(Object other) => other is MarkerId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

class BitmapDescriptor {
  final Uint8List? bytes;
  const BitmapDescriptor._(this.bytes);
  static const BitmapDescriptor defaultMarker = BitmapDescriptor._(null);
  static BitmapDescriptor fromBytes(Uint8List b) => BitmapDescriptor._(b);
}

typedef MarkerTapCallback = void Function();

class Marker {
  final MarkerId markerId;
  final LatLng position;
  final BitmapDescriptor icon;
  final double rotation;
  final Offset? anchor;
  final bool flat;
  final MarkerTapCallback? onTap;
  const Marker({
    required this.markerId,
    required this.position,
    this.icon = BitmapDescriptor.defaultMarker,
    this.rotation = 0,
    this.anchor,
    this.flat = false,
    this.onTap,
  });
}

class CameraUpdate {
  // placeholder
  CameraUpdate._();
  static final none = CameraUpdate._();
  static CameraUpdate newCameraPosition(CameraPosition p) => CameraUpdate._();
  static CameraUpdate newLatLng(mb.LatLng p) => CameraUpdate._();
  static CameraUpdate newLatLngBounds(dynamic b, double padding) => CameraUpdate._();
}
