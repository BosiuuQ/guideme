import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileBackend {
  static final _client = Supabase.instance.client;

  /// Pobiera profil użytkownika (nickname, avatar, opis, poziom konta)
  static Future<Map<String, dynamic>> getUserProfile({String? userId}) async {
    String? targetUserId = userId;
    if (targetUserId == null) {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception("Brak zalogowanego użytkownika.");
      }
      targetUserId = currentUser.id;
    }

    final data = await _client
        .from('users')
        .select('nickname, description, account_lvl, avatar, role')
        .eq('id', targetUserId)
        .maybeSingle();

    if (data == null) {
      throw Exception("Nie znaleziono użytkownika w tabeli 'users'.");
    }

    return Map<String, dynamic>.from(data);
  }

  /// Pobiera wszystkie posty dodane przez użytkownika (z tabeli instagram_posty)
  static Future<List<Map<String, dynamic>>> getUserPosts({String? userId}) async {
    String? targetUserId = userId;
    if (targetUserId == null) {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception("Nie jesteś zalogowany.");
      }
      targetUserId = currentUser.id;
    }

    final data = await _client
        .from('instagram_posty')
        .select('*, user:users(nickname, avatar)')
        .eq('user_id', targetUserId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Pobiera wszystkie punkty widokowe dodane przez użytkownika
  static Future<List<Map<String, dynamic>>> getUserViewpoints({String? userId}) async {
    String? targetUserId = userId;
    if (targetUserId == null) {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception("Nie jesteś zalogowany.");
      }
      targetUserId = currentUser.id;
    }

    final data = await _client
        .from('punkty_widokowe')
        .select()
        .eq('author_id', targetUserId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Aktualizuje profil użytkownika (nickname, opis, avatar)
  static Future<void> updateUserProfile({
    String? nickname,
    String? description,
    String? avatar,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception("Nie jesteś zalogowany.");
    }

    final updates = <String, dynamic>{};
    if (nickname != null) updates['nickname'] = nickname;
    if (description != null) updates['description'] = description;
    if (avatar != null) updates['avatar'] = avatar;
    if (updates.isEmpty) return;

    await _client
        .from('users')
        .update(updates)
        .eq('id', currentUser.id);
  }

  /// 🔍 Szukaj użytkowników po nickname
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final result = await _client
        .from('users')
        .select('id, nickname, avatar, account_lvl')
        .ilike('nickname', '%$query%');
    return List<Map<String, dynamic>>.from(result);
  }
}
