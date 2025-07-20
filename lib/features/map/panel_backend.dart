import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PanelBackend {
  static final _client = Supabase.instance.client;

  /// 🔹 Dodaje nowe zgłoszenie
  static Future<void> addReport({required String type}) async {
    final position = await Geolocator.getCurrentPosition();

    await _client.from('map_reports').insert({
      'user_id': _client.auth.currentUser?.id,
      'type': type,
      'lat': position.latitude,
      'lng': position.longitude,
      'valid_until': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      'likes_up': 0,
      'likes_down': 0,
    });
  }

  /// 🔹 Głosowanie na zgłoszenie (👍 lub 👎)
  static Future<void> voteOnReport(String id, bool upvote) async {
    final field = upvote ? 'likes_up' : 'likes_down';

    // Aktualizacja pola głosów
    await _client.rpc('increment_report_vote', params: {
      'report_id': id,
      'vote_type': field,
    });

    // Pobierz nowe dane głosów
    final report = await _client
        .from('map_reports')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (report == null) return;

    final int likesUp = report['likes_up'] ?? 0;
    final int likesDown = report['likes_down'] ?? 0;

    final int newDuration = 15 + (likesUp * 5) - (likesDown * 5);

    await _client.from('map_reports').update({
      'valid_until': DateTime.now()
          .add(Duration(minutes: newDuration.clamp(1, 60)))
          .toIso8601String(),
    }).eq('id', id);
  }

  /// 🔹 Pobiera tylko aktywne zgłoszenia w promieniu 2 km
  static Future<List<Map<String, dynamic>>> fetchNearbyReports(
    double lat,
    double lng,
  ) async {
    final now = DateTime.now().toIso8601String();

    final response = await _client
        .from('map_reports')
        .select()
        .gt('valid_until', now);

    return (response as List)
        .where((r) => _distance(r['lat'], r['lng'], lat, lng) < 2.0)
        .map((r) => r as Map<String, dynamic>)
        .toList();
  }

  /// 🔧 Obliczanie odległości (km) – Haversine
  static double _distance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);
}
