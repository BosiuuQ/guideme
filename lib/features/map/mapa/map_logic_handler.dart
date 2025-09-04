import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:guide_me/mapbox_shim.dart';
import 'package:guide_me/mapbox_shim.dart' as mb;
import 'package:guide_me/mapbox_shim.dart';
import 'package:geolocator/geolocator.dart';

/// Simplified MapLogicHandler rewritten for Mapbox.
/// This provides a minimal API similar to the original project so other widgets can interact with it.
class MapLogicHandler {
  final VoidCallback onUpdate;
  final TickerProvider tickerProvider;
  late final Ticker _ticker;

  mb.MapboxMapController? controller;
  mb.Symbol? _userSymbol;
  LatLng? targetLocation;
  bool mapReady = false;

  double _bearing = 0.0;
  double _currentSpeed = 0.0;

  MapLogicHandler({required this.onUpdate, required this.tickerProvider}) {
    _ticker = tickerProvider.createTicker((_) {});
  }

  void dispose() {
    _ticker.dispose();
  }

  Widget buildSpeedometer() {
    // Simple placeholder speedometer widget to keep UI intact.
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text('${_currentSpeed.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white)),
    );
  }

  Future<void> onMapCreated(mb.MapboxMapController ctrl) async {
    controller = ctrl;
    mapReady = true;
    // optionally set style if you have a custom one
    // await controller.setStyleString(yourStyleJson);
    onUpdate();
  }

  Future<void> updateUserLocation(Position pos) async {
    targetLocation = LatLng(pos.latitude, pos.longitude);
    _currentSpeed = pos.speed * 3.6;
    _bearing = pos.heading;
    await _updateUserSymbol();
    onUpdate();
  }

  Future<void> _updateUserSymbol() async {
    if (controller == null || targetLocation == null) return;
    final mbPos = mb.LatLng(targetLocation!.latitude, targetLocation!.longitude);
    try {
      if (_userSymbol == null) {
        _userSymbol = await controller!.addSymbol(mb.SymbolOptions(
          geometry: mbPos,
          iconImage: 'marker-15',
          iconSize: 1.2,
          iconRotate: _bearing,
        ));
      } else {
        await controller!.updateSymbol(_userSymbol!, mb.SymbolOptions(geometry: mbPos, iconRotate: _bearing));
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> moveToTarget({double zoom = 16}) async {
    if (controller == null || targetLocation == null) return;
    await controller!.animateCamera(mb.CameraUpdate.newCameraPosition(mb.CameraPosition(target: mb.LatLng(targetLocation!.latitude, targetLocation!.longitude), zoom: zoom)));
  }
}
