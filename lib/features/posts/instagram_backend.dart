// lib/features/posts/instagram_backend.dart
import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstagramBackend {
  static final supabase = Supabase.instance.client;

  // -------------------- helpers: log + err --------------------
  static void _log(String msg) {
    if (kDebugMode) print('[IG] $msg');
  }

  static Exception _pgErr(String where, PostgrestException e) {
    final code = e.code ?? 'unknown';
    final msg = e.message ?? 'no message';
    final details = (e.details ?? '').toString();
    final hint = (e.hint ?? '').toString();
    return Exception(
      'Supabase @$where → $code: $msg'
      '${details.isNotEmpty ? ' | $details' : ''}'
      '${hint.isNotEmpty ? ' | $hint' : ''}',
    );
  }

  // -------------------- posts (list/paged/details) --------------------

  /// Paginowane kafelki (RPC)
  static Future<List<Map<String, dynamic>>> getPostsPaged({
    required int limit,
    required int offset,
    String search = '',
    String period = 'all',
  }) async {
    const where = 'getPostsPaged';
    try {
      final res = await supabase.rpc('rpc_get_posts_paged', params: {
        'lim': limit,
        'off': offset,
        'search': search,
        'period': period,
      });
      final list = (res as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
      _log('$where ← ${list.length}');
      return list;
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  /// Pełna lista (autor dołączony z public.users)
  static Future<List<Map<String, dynamic>>> getPosts() async {
    const where = 'getPosts';
    try {
      final postsData = await supabase
          .from('instagram_posty')
          .select('id, user_id, caption, image_url, created_at')
          .order('created_at', ascending: false);
      final posts = List<Map<String, dynamic>>.from(postsData as List);

      final userIds = posts
          .map((p) => p['user_id'])
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      final profiles = await _profilesById(userIds);
      for (final p in posts) {
        final uid = p['user_id'] as String?;
        p['user'] = _attachUser(profiles, uid);
      }
      return posts;
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  /// Szczegóły posta + drzewo komentarzy
  static Future<Map<String, dynamic>> getPostDetails(String postId) async {
    const where = 'getPostDetails';
    try {
      final me = supabase.auth.currentUser;

      // 1) Post
      final post = await supabase
          .from('instagram_posty')
          .select('id, user_id, caption, image_url, created_at')
          .eq('id', postId)
          .maybeSingle();
      if (post == null) throw Exception('Post nie został znaleziony.');
      final postMap = Map<String, dynamic>.from(post as Map);

      // 2) Lajki posta
      List likeRows = const [];
      try {
        final rows = await supabase
            .from('instagram_post_likes')
            .select('user_id')
            .eq('post_id', postId);
        likeRows = (rows as List);
      } catch (_) {
        likeRows = const [];
      }
      postMap['likes'] = likeRows.length;
      postMap['liked_by_me'] =
          me == null ? false : likeRows.any((r) => r['user_id'] == me.id);

      // 3) Komentarze (płasko)
      final cRows = await supabase
          .from('instagram_post_comments')
          .select(
              'id, post_id, user_id, comment_text, parent_id, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments = List<Map<String, dynamic>>.from(cRows as List);

      // 4) Lajki komentarzy (zbiorczo)
      final commentIds =
          comments.map((c) => c['id']).where((x) => x != null).toList();

      final likesByComment = <String, int>{};
      final likedByMe = <String>{};
      if (commentIds.isNotEmpty) {
        try {
          final rows = await supabase
              .from('instagram_comment_likes')
              .select('comment_id, user_id')
              .inFilter('comment_id', commentIds);
          for (final r in (rows as List)) {
            final cid = r['comment_id']?.toString();
            if (cid == null) continue;
            likesByComment[cid] = (likesByComment[cid] ?? 0) + 1;
            if (me != null && r['user_id'] == me.id) likedByMe.add(cid);
          }
        } catch (_) {
          // brak SELECT polityki -> traktuj jako 0
        }
      }

      // 5) Profile wszystkich użytych userów
      final userIds = <String>{
        if (postMap['user_id'] != null) postMap['user_id'] as String,
        ...comments.map((c) => c['user_id']).whereType<String>(),
      }.toList();
      final profiles = await _profilesById(userIds);
      postMap['user'] = _attachUser(profiles, postMap['user_id'] as String?);

      for (final c in comments) {
        final cid = c['id']?.toString();
        c['likes_count'] = cid == null ? 0 : (likesByComment[cid] ?? 0);
        c['liked_by_me'] = cid == null ? false : likedByMe.contains(cid);
        c['replies'] = <Map<String, dynamic>>[];
        c['user'] = _attachUser(profiles, c['user_id'] as String?);
      }

      final tree = _buildTree(comments);
      postMap['comments_list'] = tree;
      postMap['comments_count'] = comments.length;

      _log('$where ← ok (comments=${comments.length}, likes=${postMap['likes']})');
      return postMap;
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  // -------------------- likes (post/comment) --------------------

  static Future<void> likePost(String postId) async {
    const where = 'likePost';
    try {
      final me = supabase.auth.currentUser;
      if (me == null) throw Exception('Użytkownik nie jest zalogowany.');

      final existing = await supabase
          .from('instagram_post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', me.id)
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('instagram_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', me.id);
      } else {
        await supabase.from('instagram_post_likes').insert({
          'post_id': postId,
          'user_id': me.id,
        });
      }
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  static Future<void> likeComment(String commentId) async {
    const where = 'likeComment';
    try {
      final me = supabase.auth.currentUser;
      if (me == null) throw Exception('Użytkownik nie jest zalogowany.');

      final existing = await supabase
          .from('instagram_comment_likes')
          .select('id')
          .eq('comment_id', commentId)
          .eq('user_id', me.id)
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('instagram_comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', me.id);
      } else {
        await supabase.from('instagram_comment_likes').insert({
          'comment_id': commentId,
          'user_id': me.id,
        });
      }
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  // -------------------- comments (add/edit/delete) --------------------

  /// Dodaj komentarz (root/odpowiedź). MUSI zapisać – w razie problemu rzuci wyjątek.
  static Future<void> addComment(
    String postId,
    String commentText, {
    String? parentCommentId,
  }) async {
    const where = 'addComment';
    final me = supabase.auth.currentUser;
    if (me == null) throw Exception('Użytkownik nie jest zalogowany.');
    final text = commentText.trim();
    if (text.isEmpty) throw Exception('Komentarz jest pusty.');

    try {
      final inserted = await supabase
          .from('instagram_post_comments')
          .insert({
            'post_id': postId,
            'user_id': me.id,
            'comment_text': text,
            'parent_id': parentCommentId,
          })
          // to wymusza ZAPIS + zwrot rekordu; jeżeli RLS zabroni, dostaniesz wyjątek
          .select('id, post_id, user_id, created_at')
          .single();

      _log('addComment ← inserted=$inserted'); // dowód zapisu
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  static Future<void> editComment(String commentId, String newText) async {
    const where = 'editComment';
    try {
      final me = supabase.auth.currentUser;
      if (me == null) throw Exception('Użytkownik nie jest zalogowany.');
      final text = newText.trim();
      if (text.isEmpty) throw Exception('Komentarz jest pusty.');

      await supabase
          .from('instagram_post_comments')
          .update({'comment_text': text})
          .eq('id', commentId)
          .eq('user_id', me.id);
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  static Future<void> deleteComment(String commentId) async {
    const where = 'deleteComment';
    try {
      final me = supabase.auth.currentUser;
      if (me == null) throw Exception('Użytkownik nie jest zalogowany.');

      await supabase
          .from('instagram_post_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', me.id);
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  // -------------------- posts (add/delete) --------------------

  static Future<void> addPost(String caption, String imageUrl) async {
    const where = 'addPost';
    try {
      final me = supabase.auth.currentUser;
      if (me == null) throw Exception('Użytkownik nie jest zalogowany.');

      final last = await supabase
          .from('instagram_posty')
          .select('created_at')
          .eq('user_id', me.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (last != null) {
        final lastCreated = DateTime.parse(last['created_at'] as String);
        final diff = DateTime.now().difference(lastCreated);
        if (diff.inMinutes < 60) {
          final m = 60 - diff.inMinutes;
          final s = 60 - diff.inSeconds % 60;
          throw Exception('Możesz dodać nowy post za ${m}m ${s}s.');
        }
      }

      await supabase.from('instagram_posty').insert({
        'user_id': me.id,
        'caption': caption,
        'image_url': imageUrl,
      });
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  static Future<void> deletePost(String postId) async {
    const where = 'deletePost';
    try {
      final me = supabase.auth.currentUser;
      if (me == null) throw Exception('Użytkownik nie jest zalogowany.');

      await supabase
          .from('instagram_posty')
          .delete()
          .eq('id', postId)
          .eq('user_id', me.id);
    } on PostgrestException catch (e) {
      throw _pgErr(where, e);
    } catch (e) {
      throw Exception('Unexpected @$where → $e');
    }
  }

  // -------------------- internal: profiles & tree --------------------

  static Future<Map<String, Map<String, dynamic>>> _profilesById(
      List<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    if (ids.isEmpty) return out;

    final rows =
        await supabase.from('users').select('id, nickname, avatar').inFilter('id', ids);

    for (final r in (rows as List)) {
      final m = Map<String, dynamic>.from(r);
      final id = m['id'] as String?;
      if (id == null) continue;
      out[id] = {'id': id, 'nickname': m['nickname'], 'avatar': m['avatar']};
    }
    return out;
  }

  static Map<String, dynamic> _attachUser(
      Map<String, Map<String, dynamic>> profiles, String? userId) {
    final p = userId != null ? profiles[userId] : null;
    return {
      'id': userId,
      'nickname': p?['nickname'] ?? 'Użytkownik',
      'avatar': p?['avatar'],
    };
  }

  static List<Map<String, dynamic>> _buildTree(List<Map<String, dynamic>> flat) {
    final byId = <String, Map<String, dynamic>>{};
    final roots = <Map<String, dynamic>>[];

    for (final c in flat) {
      final id = c['id']?.toString();
      if (id == null) continue;
      byId[id] = c;
      c['replies'] = <Map<String, dynamic>>[];
    }

    for (final c in flat) {
      final pid = c['parent_id']?.toString();
      if (pid == null) {
        roots.add(c);
      } else {
        final parent = byId[pid];
        if (parent != null) {
          final list = List<Map<String, dynamic>>.from(parent['replies'] as List);
          list.add(c);
          parent['replies'] = list;
        } else {
          roots.add(c); // parent usunięty – nie gub
        }
      }
    }
    return roots;
  }
}
