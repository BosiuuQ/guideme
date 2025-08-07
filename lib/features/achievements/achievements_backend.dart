import 'package:supabase_flutter/supabase_flutter.dart';
import 'achievement_service.dart';

class AchievementsBackend {
  static final _client = Supabase.instance.client;

  static Future<int> getUserPostCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _client
        .from('instagram_posty')
        .select('id')
        .eq('user_id', userId);

    return (data as List).length;
  }

  static Future<int> getUserViewpointCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _client
        .from('punkty_widokowe')
        .select('id')
        .eq('author_id', userId);

    return (data as List).length;
  }

  static Future<void> checkAllAchievements({
    Function(String title, String description)? onUnlocked,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final achievementService = AchievementService();

    // Kilometry
    final kmData = await _client
        .from('user_distance')
        .select('total_km')
        .eq('user_id', userId)
        .maybeSingle();
    final totalKm = (kmData?['total_km'] ?? 0).toDouble();

    await achievementService.checkKmAchievements(
      userId: userId,
      totalKm: totalKm,
      onAchievementUnlocked: onUnlocked,
    );

    // Posty IG
    final posts = await getUserPostCount();
    await achievementService.checkPostAchievements(
      userId: userId,
      totalPosts: posts,
      onAchievementUnlocked: onUnlocked,
    );

    // Punkty widokowe
    final points = await getUserViewpointCount();
    await achievementService.checkViewpointAchievements(
      userId: userId,
      totalPoints: points,
      onAchievementUnlocked: onUnlocked,
    );
  }
}
