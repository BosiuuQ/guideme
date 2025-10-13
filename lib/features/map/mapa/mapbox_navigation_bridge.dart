import 'dart:async';
import 'package:flutter/services.dart';

class MapboxNavigationBridge {
  static const MethodChannel _channel = MethodChannel('com.example.guide_me/navigation');
  static const EventChannel _events = EventChannel('com.example.guide_me/navigation_events');

  static Stream<Map<String, dynamic>>? _stream;

  static Future<bool> startNavigation(List<List<double>> routeCoords) async {
    try {
      final res = await _channel.invokeMethod('startNavigation', {'route': routeCoords});
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopNavigation() async {
    try {
      final res = await _channel.invokeMethod('stopNavigation');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Stream<Map<String, dynamic>> navigationEvents() {
    _stream ??= _events.receiveBroadcastStream().map((dynamic event) {
      return Map<String, dynamic>.from(event as Map);
    });
    return _stream!;
  }
}
