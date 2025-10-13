import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsBackend {
  static final _client = Supabase.instance.client;

  // == TABLE CONFIG ==
  static const String _tableUsers = 'users';
  static const String _tablePosts = 'instagram_posty';
  static const String _tableViewpoints = 'punkty_widokowe';
  static const String _tableFriends = 'friends';
  static const String _tableBlocked = 'blocked_users';
  static const String _tableChangelog = 'app_changelog';
  static const String _tableAppContact = 'app_contact';
  static const String _tableUserDistance = 'user_distance';

  // == COLUMNS ==
  static const String _colId = 'id';
  static const String _colNickname = 'nickname';
  static const String _colBio = 'description';
  static const String _colAvatar = 'avatar';
  static const String _colCreatedAt = 'created_at';
  static const String _colAccountLvl = 'account_lvl';
  static const String _colGuideMePoints = 'guideme_points';

  // user_distance
  static const String _colUDUserId = 'user_id';
  static const String _colUDTotalKm = 'total_km';

  // ======================
  // == PROFILE / ACCOUNT ==
  // ======================

  static Future<Map<String, dynamic>> getUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    try {
      final data = await _client
          .from(_tableUsers)
          .select()
          .eq(_colId, user.id)
          .maybeSingle();

      final profile = data ?? {};
      profile['email'] = user.email ?? '';
      return profile;
    } catch (_) {
      return {'email': user.email ?? ''};
    }
  }

  static Future<void> updateNickname(String nickname) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from(_tableUsers).update({_colNickname: nickname}).eq(_colId, userId);
  }

  static Future<void> updateBio(String bio) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from(_tableUsers).update({_colBio: bio}).eq(_colId, userId);
  }

  static Future<void> updateAvatar(File file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final bytes = await file.readAsBytes();
    final filename = 'avatars/${const Uuid().v4()}.jpg';
    final storage = _client.storage.from('avatars');
    await storage.uploadBinary(
      filename,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );

    final publicUrl = storage.getPublicUrl(filename);
    await _client.from(_tableUsers).update({_colAvatar: publicUrl}).eq(_colId, userId);
  }

  static Future<void> updateEmail(String email) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.auth.updateUser(UserAttributes(email: email));
  }

  static Future<void> updatePassword(String password) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (password.length < 8) throw Exception('Hasło musi mieć co najmniej 8 znaków.');
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  // ==================
  // == USER STATS   ==
  // ==================

  static Future<Map<String, dynamic>> getUserStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    final result = <String, dynamic>{
      'account_lvl': 1,
      'guideme_points': 0,      // oficjalny klucz
      'guidepoints': 0,         // alias dla zgodności z istniejącym UI
      'km_total': 0.0,
      'km_total_pretty': '0,00 km',
      'posts': 0,
      'viewpoints': 0,
      'friends': 0,
      'created_at': null,
      'created_at_pretty': '—',
    };

    // users: account_lvl + created_at + guideme_points
    try {
      final u = await _client
          .from(_tableUsers)
          .select('$_colAccountLvl, $_colCreatedAt, $_colGuideMePoints')
          .eq(_colId, user.id)
          .maybeSingle();

      if (u != null) {
        result['account_lvl'] = (u[_colAccountLvl] ?? 1) as int;
        result['created_at'] = u[_colCreatedAt];
        result['created_at_pretty'] = _formatDateDMY(u[_colCreatedAt]);

        final gp = _asNum(u[_colGuideMePoints]).toInt();
        result['guideme_points'] = gp; // z users.guideme_points
        result['guidepoints'] = gp;    // alias
      }
    } catch (_) {}

    // km_total z public.user_distance.total_km
    try {
      final dist = await _client
          .from(_tableUserDistance)
          .select('$_colUDTotalKm')
          .eq(_colUDUserId, user.id)
          .maybeSingle();

      if (dist != null) {
        final km = _asNum(dist[_colUDTotalKm]).toDouble();
        result['km_total'] = km;
        result['km_total_pretty'] = _formatKm(km);
      }
    } catch (_) {}

    // posts – w tabeli instagram_posty po kolumnie user_id
    try {
      final count = await _countForUser(_tablePosts, 'user_id', user.id);
      result['posts'] = count;
    } catch (_) {}

    // viewpoints – jeśli masz inną kolumnę właściciela, podmień 'author_id'
    try {
      final count = await _countForUser(_tableViewpoints, 'author_id', user.id);
      result['viewpoints'] = count;
    } catch (_) {}

    // friends (accepted)
    try {
      final resp = await _client
          .from(_tableFriends)
          .select('id')
          .or('user_id.eq.${user.id},friend_id.eq.${user.id}')
          .eq('status', 'accepted');
      result['friends'] = (resp as List).length;
    } catch (_) {}

    return result;
  }

  // ======================
  // == BLOCKED ACCOUNTS ==
  // ======================

  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _client
          .from(_tableBlocked)
          .select('blocked_id, reason, users!inner (id, nickname)')
          .eq('blocker_id', user.id);

      return (rows as List).map((r) {
        final u = r['users'] as Map<String, dynamic>?;
        return {
          'id': r['blocked_id'] ?? u?['id'] ?? '',
          'nickname': u?['nickname'] ?? 'Użytkownik',
          'reason': r['reason'] ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> unblockUser(String blockedUserId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from(_tableBlocked).delete().eq('blocker_id', user.id).eq('blocked_id', blockedUserId);
  }

  // ================
  // == APP INFO   ==
  // ================

  static Future<Map<String, dynamic>> getAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return {'version': info.version, 'build': info.buildNumber};
    } catch (_) {
      return {'version': '—', 'build': ''};
    }
  }

  static Future<String?> getChangelog() async {
    try {
      final row = await _client
          .from(_tableChangelog)
          .select('content')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row?['content']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> getContactInfo() async {
    try {
      final row = await _client
          .from(_tableAppContact)
          .select('email, discord, www')
          .limit(1)
          .maybeSingle();

      return {
        'email': (row?['email'] ?? 'guideme.biznes@gmail.com').toString(),
        'instagram': (row?['discord'] ?? '@guideme.official').toString(),
        'www': (row?['www'] ?? 'prowadzmnie.pl').toString(),
      };
    } catch (_) {
      return {
        'email': 'guideme.biznes@gmail.com',
        'instagram': '@guideme.official',
        'www': 'prowadzmnie.pl',
      };
    }
  }

  // =====================
  // == ACCOUNT DELETE  ==
  // =====================

  static Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from(_tableUsers).update({
        _colNickname: 'deleted_${user.id.substring(0, 6)}',
        _colBio: null,
        _colAvatar: null,
        'is_deleted': true,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq(_colId, user.id);
    } catch (_) {}

    await _client.auth.signOut();
  }

  // ==================
  // == HELPERS      ==
  // ==================

  static String _formatKm(num value) {
    final d = (value).toDouble();
    return '${d.toStringAsFixed(2).replaceAll('.', ',')} km';
  }

  static String _formatDateDMY(dynamic isoLike) {
    if (isoLike == null) return '—';
    try {
      final dt = DateTime.parse(isoLike.toString()).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString();
      return '$dd-$mm-$yy';
    } catch (_) {
      return '—';
    }
  }

  static num _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  static Future<int> _countForUser(String table, String userColumn, String userId) async {
    try {
      final resp = await _client
          .from(table)
          .select('$_colId')
          .eq(userColumn, userId);
      return (resp as List).length;
    } catch (_) {
      return 0;
    }
  }
}
