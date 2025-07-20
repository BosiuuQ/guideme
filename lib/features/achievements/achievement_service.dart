import 'package:supabase_flutter/supabase_flutter.dart';

class AchievementService {
  final _client = Supabase.instance.client;

  Future<void> checkKmAchievements({
    required String userId,
    required double totalKm,
    Function(String title, String description)? onAchievementUnlocked,
  }) async {
    final existing = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', userId);

    final existingIds = (existing as List)
        .map((e) => e['achievement_id'] as String)
        .toSet();

    final all = await _client.from('achievements_km').select();

    for (final item in all) {
      final id = item['id'];
      final required = (item['required_km'] as num).toDouble();
      if (totalKm >= required && !existingIds.contains(id)) {
        await _client.from('user_achievements').insert({
          'user_id': userId,
          'achievement_id': id,
          'unlocked_at': DateTime.now().toIso8601String(),
        });

        onAchievementUnlocked?.call(item['title'], item['description']);
      }
    }
  }

  Future<void> checkPostAchievements({
    required String userId,
    required int totalPosts,
    Function(String title, String description)? onAchievementUnlocked,
  }) async {
    final existing = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', userId);

    final existingIds = (existing as List)
        .map((e) => e['achievement_id'] as String)
        .toSet();

    final all = await _client.from('achievements_posts').select();

    for (final item in all) {
      final id = item['id'];
      final required = (item['required_posts'] as num).toInt();
      if (totalPosts >= required && !existingIds.contains(id)) {
        await _client.from('user_achievements').insert({
          'user_id': userId,
          'achievement_id': id,
          'unlocked_at': DateTime.now().toIso8601String(),
        });

        onAchievementUnlocked?.call(item['title'], item['description']);
      }
    }
  }

  Future<void> checkViewpointAchievements({
    required String userId,
    required int totalPoints,
    Function(String title, String description)? onAchievementUnlocked,
  }) async {
    final existing = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', userId);

    final existingIds = (existing as List)
        .map((e) => e['achievement_id'] as String)
        .toSet();

    final all = await _client.from('achievements_viewpoints').select();

    for (final item in all) {
      final id = item['id'];
      final required = (item['required_points'] as num).toInt();
      if (totalPoints >= required && !existingIds.contains(id)) {
        await _client.from('user_achievements').insert({
          'user_id': userId,
          'achievement_id': id,
          'unlocked_at': DateTime.now().toIso8601String(),
        });

        onAchievementUnlocked?.call(item['title'], item['description']);
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAllAchievements(String userId) async {
    final distanceData = await _client
        .from('user_distance')
        .select('total_km')
        .eq('user_id', userId)
        .maybeSingle();

    final totalKm = (distanceData?['total_km'] ?? 0).toDouble();

    final userAchievements = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', userId);

    final userAchievementIds = (userAchievements as List)
        .map((e) => e['achievement_id'] as String)
        .toSet();

    final allAchievements = await _client
        .from('achievements_km')
        .select()
        .order('required_km', ascending: true);

    return allAchievements.map((achievement) {
      final id = achievement['id'] as String;
      return {
        ...achievement,
        'achieved': userAchievementIds.contains(id),
        'current_km': totalKm,
      };
    }).toList();
  }
}