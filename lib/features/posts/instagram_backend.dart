import 'package:supabase_flutter/supabase_flutter.dart';

class InstagramBackend {
  static final supabase = Supabase.instance.client;

  /// Pobiera listę postów wraz z danymi autora (nickname, avatar)
  static Future<List<Map<String, dynamic>>> getPosts() async {
    final data = await supabase
        .from('instagram_posty')
        .select('*, user:users(nickname, avatar)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Pobiera szczegóły posta wraz z lajkami i komentarzami
  static Future<Map<String, dynamic>> getPostDetails(String postId) async {
    final post = await supabase
        .from('instagram_posty')
        .select('*, user:users(id, nickname, avatar)')
        .eq('id', postId)
        .maybeSingle();

    if (post == null) {
      throw Exception("Post nie został znaleziony.");
    }

    final postMap = Map<String, dynamic>.from(post);

    final likesData = await supabase
        .from('instagram_post_likes')
        .select('id')
        .eq('post_id', postId);
    postMap['likes'] = (likesData as List).length;

    final commentsData = await supabase
        .from('instagram_post_comments')
        .select('*, user:users(id, nickname, avatar)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final commentsList = List<Map<String, dynamic>>.from(commentsData);
    postMap['comments_list'] = commentsList;
    postMap['comments_count'] = commentsList.length;

    return postMap;
  }

  /// Dodaje lub usuwa lajka (toggle)
  static Future<void> likePost(String postId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Użytkownik nie jest zalogowany.");

    final existing = await supabase
        .from('instagram_post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', currentUser.id)
        .maybeSingle();

    if (existing != null) {
      await supabase
          .from('instagram_post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentUser.id);
    } else {
      await supabase.from('instagram_post_likes').insert({
        'post_id': postId,
        'user_id': currentUser.id,
      });
    }
  }

  /// Dodaje komentarz do posta
  static Future<void> addComment(String postId, String commentText) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Użytkownik nie jest zalogowany.");

    await supabase.from('instagram_post_comments').insert({
      'post_id': postId,
      'user_id': currentUser.id,
      'comment_text': commentText,
    });
  }

  /// Usuwa komentarz
  static Future<void> deleteComment(String commentId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Użytkownik nie jest zalogowany.");

    await supabase
        .from('instagram_post_comments')
        .delete()
        .eq('id', commentId);
  }

  /// Edytuje komentarz
  static Future<void> editComment(String commentId, String newText) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Użytkownik nie jest zalogowany.");

    await supabase
        .from('instagram_post_comments')
        .update({'comment_text': newText})
        .eq('id', commentId);
  }

  /// Dodaje nowy post
  static Future<void> addPost(String caption, String imageUrl) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Użytkownik nie jest zalogowany.");

    await supabase.from('instagram_posty').insert({
      'user_id': currentUser.id,
      'caption': caption,
      'image_url': imageUrl,
    });
  }

  /// Usuwa post
  static Future<void> deletePost(String postId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Użytkownik nie jest zalogowany.");

    await supabase
        .from('instagram_posty')
        .delete()
        .eq('id', postId)
        .eq('user_id', currentUser.id);
  }
}
