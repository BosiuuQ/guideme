import 'package:supabase_flutter/supabase_flutter.dart';

class RatingService {
  final _client = Supabase.instance.client;
  final _table = 'viewpoint_ratings';

  Future<double> getAverageRating(String viewpointId) async {
    final data = await _client
        .from(_table)
        .select('rating')
        .eq('viewpoint_id', viewpointId);

    if (data.isEmpty) return 0;
    final ratings = data.map((e) => (e['rating'] as num).toDouble()).toList();
    final sum = ratings.reduce((a, b) => a + b);
    return sum / ratings.length;
  }

  Future<int> getUserRating(String viewpointId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _client
        .from(_table)
        .select()
        .eq('viewpoint_id', viewpointId)
        .eq('user_id', userId)
        .maybeSingle();

    return (data != null) ? data['rating'] : 0;
  }

  Future<void> rateViewpoint(String viewpointId, int rating) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final existing = await _client
        .from(_table)
        .select()
        .eq('viewpoint_id', viewpointId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from(_table)
          .update({'rating': rating})
          .eq('viewpoint_id', viewpointId)
          .eq('user_id', userId);
    } else {
      await _client.from(_table).insert({
        'viewpoint_id': viewpointId,
        'user_id': userId,
        'rating': rating,
      });
    }
  }

  Future<int> getUserRatingFor({required String viewpointId, required String userId}) async {
    final data = await _client
        .from(_table)
        .select('rating')
        .eq('viewpoint_id', viewpointId)
        .eq('user_id', userId)
        .maybeSingle();

    return (data != null) ? data['rating'] : 0;
  }
}
