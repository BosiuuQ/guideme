import 'package:supabase_flutter/supabase_flutter.dart';

class CommentService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchComments(String viewpointId) async {
    final response = await supabase
        .from('viewpoint_comments')
        .select('id, comment, created_at, users(id, nickname, avatar, account_lvl)') // ✅ zmiana content ➔ comment
        .eq('viewpoint_id', viewpointId)
        .order('created_at', ascending: false);

    if (response == null) {
      return [];
    }
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addComment({
    required String viewpointId,
    required String commentText,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('viewpoint_comments').insert({
      'viewpoint_id': viewpointId,
      'user_id': userId,
      'comment': commentText,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteComment(String commentId) async {
    await supabase.from('viewpoint_comments').delete().eq('id', commentId);
  }
}
