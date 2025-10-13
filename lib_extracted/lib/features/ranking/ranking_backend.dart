import 'package:supabase_flutter/supabase_flutter.dart';

class RankingBackend {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchRanking(String type) async {
    /// 🔹 Ranking przejechanych kilometrów
    if (type == 'km') {
      final data = await _supabase
          .from('user_distance')
          .select('total_km, user_id, users!user_id(nickname, avatar, account_lvl)')
          .order('total_km', ascending: false)
          .limit(10);

      return (data as List).map<Map<String, dynamic>>((item) {
        final user = item['users'];
        return {
          'user_id': item['user_id'],
          'total_km': (item['total_km'] as num).toStringAsFixed(0),
          'nickname': user?['nickname'] ?? 'Użytkownik',
          'avatar': user?['avatar'],
          'account_lvl': user?['account_lvl'] ?? 1,
        };
      }).toList();
    }

    /// 🔹 Ranking poziomu użytkownika
    if (type == 'lvl') {
      final data = await _supabase
          .from('users')
          .select('id, nickname, avatar, account_lvl')
          .order('account_lvl', ascending: false)
          .limit(10);

      return (data as List).map<Map<String, dynamic>>((user) {
        return {
          'user_id': user['id'],
          'nickname': user['nickname'],
          'avatar': user['avatar'],
          'account_lvl': user['account_lvl'],
        };
      }).toList();
    }

    /// 🔹 Ranking liczby postów (np. Instagram)
    if (type == 'posts') {
      final result = await _supabase
          .from('instagram_posty')
          .select('user_id, users(nickname, avatar, account_lvl)');

      final counts = <String, Map<String, dynamic>>{};

      for (final post in result as List) {
        final userId = post['user_id'];
        final user = post['users'];
        if (userId == null || user == null) continue;

        if (!counts.containsKey(userId)) {
          counts[userId] = {
            'user_id': userId,
            'nickname': user['nickname'],
            'avatar': user['avatar'],
            'account_lvl': user['account_lvl'],
            'post_count': 1,
          };
        } else {
          counts[userId]!['post_count'] += 1;
        }
      }

      return counts.values.toList()
        ..sort((a, b) => (b['post_count'] as int).compareTo(a['post_count'] as int));
    }

    /// 🔹 Ranking klubów wg score: avg_km + 20 * avg_lvl
    if (type == 'clubs') {
      final data = await _supabase
          .from('clubs')
          .select('id, name, average_km, average_level')
          .not('average_km', 'is', null)
          .not('average_level', 'is', null)
          .limit(20); // można zwiększyć limit

      final ranked = (data as List).map((club) {
        final avgKm = (club['average_km'] ?? 0) as num;
        final avgLvl = (club['average_level'] ?? 0) as num;
        final score = avgKm + 20 * avgLvl;

        return {
          'club_id': club['id'],
          'name': club['name'],
          'average_km': avgKm.toStringAsFixed(0),
          'average_lvl': avgLvl.toStringAsFixed(1),
          'score': score.toStringAsFixed(0),
        };
      }).toList();

      ranked.sort((a, b) => num.parse(b['score']!).compareTo(num.parse(a['score']!)));
      return ranked;
    }

    return [];
  }
}
