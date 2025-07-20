import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpotyBackend {
  static final _supabase = Supabase.instance.client;

  /// Pobiera spoty z przypisaną rolą autora i filtruje widoczność
  static Future<List<Map<String, dynamic>>> getSpotyWithRoles(String currentUserId) async {
    try {
      final spoty = await _supabase
          .from('spoty')
          .select('*, autor:users(id, role)')
          .order('data');

      final List<Map<String, dynamic>> result = [];

      for (final s in spoty) {
        final widocznosc = s['widocznosc'];
        final autorId = s['autor']?['id'];
        final autorRola = s['autor']?['role'] ?? 'user';

        final isFriend = await _isFriend(currentUserId, autorId);

        final isPublic = widocznosc == 'publiczna';
        final isVisibleToFriends = widocznosc == 'tylko_znajomi' && (isFriend || autorId == currentUserId);

        if (isPublic || isVisibleToFriends) {
          s['kategoria'] = ['partner', 'admin', 'moderator'].contains(autorRola)
              ? 'oficjalna'
              : 'spolecznosciowa';
          result.add(s);
        }
      }

      debugPrint("📥 Załadowano ${result.length} spotów (po filtrach widoczności)");
      return result;
    } catch (e) {
      debugPrint("❌ Błąd pobierania spotów z rolami: $e");
      return [];
    }
  }

  /// Sprawdza, czy użytkownicy są znajomymi (relacja dwustronna)
  static Future<bool> _isFriend(String userId, String otherId) async {
    try {
      final data = await _supabase
          .from('friends')
          .select()
          .or('user_id.eq.$userId.and(friend_id.eq.$otherId),friend_id.eq.$userId.and(user_id.eq.$otherId)');

      final result = List<Map<String, dynamic>>.from(data);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint("⚠️ Błąd sprawdzania znajomości: $e");
      return false;
    }
  }

  /// Dodaje nowy spot
  static Future<bool> addSpot({
    required String tytul,
    required String opis,
    required String lokalizacja,
    required double lat,
    required double lng,
    required String widocznosc,
    required DateTime data,
    required Duration czasTrwania,
    required String typ,
    required String zasady,
    required String zdjecieUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Użytkownik niezalogowany");

      debugPrint("📤 Dodawanie spotu do Supabase...");
      await _supabase.from('spoty').insert({
        'tytul': tytul,
        'opis': opis,
        'lokalizacja': lokalizacja,
        'lat': lat,
        'lng': lng,
        'widocznosc': widocznosc,
        'data': data.toIso8601String(),
        'czas_trwania': '${czasTrwania.inMinutes} minutes',
        'typ': typ,
        'zasady': zasady,
        'zdjecie_url': zdjecieUrl,
        'autor': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("✅ Spot dodany.");
      return true;
    } catch (e) {
      debugPrint("❌ Błąd dodawania spotu: $e");
      return false;
    }
  }
}
