// lib/features/viewpoint/data/comment_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentService {
  final supabase = Supabase.instance.client;

  /// Pobiera komentarze dla punktu widokowego i dokleja:
  /// - likes_count, liked_by_me
  /// - user: {id, nickname, avatar} z public.users
  Future<List<Map<String, dynamic>>> fetchComments(String viewpointId) async {
    // 1) surowe komentarze (bez embedów – 100% przewidywalne)
    final raw = await supabase
        .from('viewpoint_comments')
        .select('id, viewpoint_id, user_id, comment, created_at')
        .eq('viewpoint_id', viewpointId)
        .order('created_at', ascending: false);

    final comments =
        List<Map<String, dynamic>>.from((raw ?? []) as List<dynamic>);

    if (comments.isEmpty) return [];

    // 2) polubienia komentarzy – zbiorczo
    final commentIds =
        comments.map((c) => c['id']).where((e) => e != null).toList();
    final currentUser = supabase.auth.currentUser;

    final Map<String, int> likesCountById = {};
    final Set<String> likedByMeIds = {};

    final likesRows = await supabase
        .from('viewpoint_comment_likes')
        .select('comment_id, user_id')
        .inFilter('comment_id', commentIds);

    for (final row in (likesRows ?? []) as List) {
      final cid = row['comment_id']?.toString();
      if (cid == null) continue;
      likesCountById[cid] = (likesCountById[cid] ?? 0) + 1;
      if (currentUser != null && row['user_id'] == currentUser.id) {
        likedByMeIds.add(cid);
      }
    }

    // 3) profile autorów z public.users
    final userIds = comments
        .map((c) => c['user_id'])
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    final usersRows = userIds.isEmpty
        ? []
        : await supabase
            .from('users')
            .select('id, nickname, avatar')
            .inFilter('id', userIds);

    final Map<String, Map<String, dynamic>> profileById = {};
    for (final r in (usersRows ?? []) as List) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['id'] as String?;
      if (id == null) continue;
      profileById[id] = {
        'id': id,
        'nickname': m['nickname'],
        'avatar': m['avatar'],
      };
    }

    // 4) złącz i zmapuj na format dla UI (comment_text + user + likes)
    final result = <Map<String, dynamic>>[];
    for (final c in comments) {
      final cid = c['id']?.toString();
      final uid = c['user_id'] as String?;
      result.add({
        'id': cid,
        'user_id': uid,
        'comment_text': c['comment'], // mapujemy kolumnę 'comment' -> 'comment_text'
        'created_at': c['created_at'],
        'likes_count': cid == null ? 0 : (likesCountById[cid] ?? 0),
        'liked_by_me': cid == null ? false : likedByMeIds.contains(cid),
        'user': {
          'id': uid,
          'nickname': profileById[uid]?['nickname'] ?? 'Użytkownik',
          'avatar': profileById[uid]?['avatar'],
        },
      });
    }

    return result;
  }

  /// Dodaje komentarz
  Future<void> addComment({
    required String viewpointId,
    required String commentText,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Użytkownik nie jest zalogowany.');
    }
    final text = commentText.trim();
    if (text.isEmpty) return;

    await supabase.from('viewpoint_comments').insert({
      'viewpoint_id': viewpointId,
      'user_id': userId,
      'comment': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Usuwa komentarz (DB powinna egzekwować RLS: autor komentarza lub autor punktu)
  Future<void> deleteComment(String commentId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Użytkownik nie jest zalogowany.');
    }
    await supabase.from('viewpoint_comments').delete().eq('id', commentId);
  }

  /// Toggle like na komentarzu
  Future<void> likeComment(String commentId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Użytkownik nie jest zalogowany.');
    }

    final existing = await supabase
        .from('viewpoint_comment_likes')
        .select('id')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await supabase
          .from('viewpoint_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    } else {
      await supabase.from('viewpoint_comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
    }
  }

  /// Zgłoś komentarz – zapis do tabeli 'reports'
  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Użytkownik nie jest zalogowany.');
    }

    await supabase.from('reports').insert({
      'user_id': userId,
      'type': 'viewpoint_comment',
      'item_id': commentId,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
