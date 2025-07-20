import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DistanceTracker {
  Position? _lastPosition;
  double _sessionDistance = 0.0;
  double _initialDistance = 0.0;
  bool _initialized = false;

  final supabase = Supabase.instance.client;

  Future<void> initialize() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print('❌ [DistanceTracker] Brak zalogowanego użytkownika.');
      return;
    }

    try {
      final response = await supabase
          .from('user_distance')
          .select('total_km')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['total_km'] != null) {
        _initialDistance = (response['total_km'] as num).toDouble();
        print('ℹ️ [DistanceTracker] Początkowy dystans z Supabase: $_initialDistance km');
      } else {
        print('ℹ️ [DistanceTracker] Brak rekordu – start od zera.');
      }

      _initialized = true;
    } catch (e) {
      print('❗ [DistanceTracker] Błąd podczas inicjalizacji: $e');
    }
  }

  Future<void> updateDistance(Position currentPosition) async {
    if (!_initialized) {
      print('❌ [DistanceTracker] Tracker nie został zainicjalizowany.');
      return;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print('❌ [DistanceTracker] Brak zalogowanego użytkownika.');
      return;
    }

    print('📍 [DistanceTracker] Nowa lokalizacja: ${currentPosition.latitude}, ${currentPosition.longitude}');

    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      print('↔️ [DistanceTracker] Przemieszczono się o: ${distance.toStringAsFixed(2)} m');

      if (distance > 2) {
        _sessionDistance += distance;
        final totalDistanceKm = _initialDistance + (_sessionDistance / 1000);

        print('🚀 [DistanceTracker] Aktualizacja dystansu w Supabase: ${totalDistanceKm.toStringAsFixed(3)} km');

        try {
          await supabase.from('user_distance').upsert({
            'user_id': userId,
            'total_km': totalDistanceKm,
            'last_update': DateTime.now().toUtc().toIso8601String(),
          });

          await LevelService.updateUserLevel(km: totalDistanceKm);

          print('✅ [DistanceTracker] Supabase upsert zakończony sukcesem.');
        } catch (e) {
          print('❗ [DistanceTracker] Błąd przy zapisie do Supabase: $e');
        }
      } else {
        print('ℹ️ [DistanceTracker] Zmiana poniżej 2m – ignorowana.');
      }
    } else {
      print('🟡 [DistanceTracker] To pierwsza pozycja – nie mierzę jeszcze dystansu.');
    }

    _lastPosition = currentPosition;
  }

  void resetSession() {
    _sessionDistance = 0.0;
    _lastPosition = null;
    print('🔁 [DistanceTracker] Sesja dystansu zresetowana.');
  }
}

class LevelService {
  static final _client = Supabase.instance.client;
  static int? _lastLevel;

  static const Map<int, int> levelThresholds = {
    1: 0,
    2: 5,
    3: 25,
    4: 60,
    5: 140,
    6: 200,
    7: 270,
    8: 350,
    9: 440,
    10: 540,
    11: 650,
    12: 770,
    13: 900,
    14: 1040,
    15: 1190,
    16: 1350,
    17: 1520,
    18: 1700,
    19: 1890,
    20: 2090,
    21: 2300,
    22: 2520,
    23: 2750,
    24: 2990,
    25: 3240,
    26: 3500,
    27: 3770,
    28: 4050,
    29: 4340,
    30: 4640,
    31: 4950,
    32: 5270,
    33: 5600,
    34: 5940,
    35: 6290,
    36: 6650,
    37: 7020,
    38: 7400,
    39: 7790,
    40: 8190,
    41: 8600,
    42: 9020,
    43: 9450,
    44: 9890,
    45: 10340,
    46: 10800,
    47: 11270,
    48: 11750,
    49: 12240,
    50: 12740,
    51: 13250,
    52: 13770,
    53: 14300,
    54: 14840,
    55: 15390,
    56: 15950,
    57: 16520,
    58: 17100,
    59: 17690,
    60: 18290,
    61: 18900,
    62: 19520,
    63: 20150,
    64: 20790,
    65: 21440,
    66: 22100,
    67: 22770,
    68: 23450,
    69: 24140,
    70: 24840,
    71: 25550,
    72: 26270,
    73: 27000,
    74: 27740,
    75: 28490,
    76: 29250,
    77: 30020,
    78: 30800,
    79: 31590,
    80: 32390,
    81: 33200,
    82: 34020,
    83: 34850,
    84: 35690,
    85: 36540,
    86: 37400,
    87: 38270,
    88: 39150,
    89: 40040,
    90: 40940,
    91: 41850,
    92: 42770,
    93: 43700,
    94: 44640,
    95: 45590,
    96: 46550,
    97: 47520,
    98: 48500,
    99: 49490,
    100: 30000,
  };

  static Future<void> updateUserLevel({required double km}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    int level = 1;
    for (final entry in levelThresholds.entries) {
      if (km >= entry.value) {
        level = entry.key;
      } else {
        break;
      }
    }

    if (_lastLevel == null || level != _lastLevel) {
      print('[LevelService] Zmieniono poziom: $_lastLevel → $level');
      _lastLevel = level;

      await _client
          .from('users')
          .update({'account_lvl': level})
          .eq('id', user.id);

      print('[LevelService] Poziom użytkownika zaktualizowany w Supabase na $level');
    }
  }
}
