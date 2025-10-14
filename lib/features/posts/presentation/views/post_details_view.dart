import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/posts/instagram_backend.dart';
import 'package:guide_me/features/posts/instagram_report_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PostDetailsView extends StatefulWidget {
  final Map<String, dynamic> postData;
  const PostDetailsView({Key? key, required this.postData}) : super(key: key);

  @override
  _PostDetailsViewState createState() => _PostDetailsViewState();
}

class _PostDetailsViewState extends State<PostDetailsView> {
  late Map<String, dynamic> _postData;
  final TextEditingController _commentController = TextEditingController();
  bool _isLiking = false;
  bool _isAddingComment = false;
  final currentUser = Supabase.instance.client.auth.currentUser;

  // replies / like state
  final Set<String> _expandedThreads = {};
  String? _replyToCommentId;
  String? _replyToNickname;
  bool _isLikingComment = false;

  @override
  void initState() {
    super.initState();
    _postData = widget.postData;
    _refreshPostDetails();
  }

  Future<void> _refreshPostDetails() async {
    try {
      final updatedData = await InstagramBackend.getPostDetails(_postData['id']);
      if (!mounted) return;
      setState(() {
        _postData = updatedData;
      });
    } catch (_) {/* no-op */}
  }

  // -------- POST like --------
  Future<void> _toggleLike() async {
    if (!mounted) return;
    setState(() => _isLiking = true);
    try {
      await InstagramBackend.likePost(_postData['id']);
      await _refreshPostDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd przy aktualizacji lajka: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  // -------- ADD COMMENT (TU BYŁ PROBLEM) --------
  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!mounted) return;
    setState(() => _isAddingComment = true);

    // optimistic UI – wstawiamy lokalnie na chwilę
    final optimistic = {
      'id': 'temp_${DateTime.now().microsecondsSinceEpoch}',
      'comment_text': text,
      'user_id': currentUser?.id,
      'user': {
        'id': currentUser?.id,
        'nickname': 'Ty',
        'avatar': null,
      },
      'created_at': DateTime.now().toIso8601String(),
      'likes_count': 0,
      'liked_by_me': false,
      'replies': <Map<String, dynamic>>[],
      'parent_id': _replyToCommentId,
    };

    // zapamiętamy gdzie wstawiliśmy — do ewentualnego cofnięcia
    Map<String, dynamic>? insertedLocally;

    try {
      if (_replyToCommentId == null) {
        final list = List<Map<String, dynamic>>.from((_postData['comments_list'] ?? []) as List);
        list.insert(0, optimistic);
        insertedLocally = optimistic;
        if (!mounted) return;
        setState(() {
          _postData['comments_list'] = list;
          _postData['comments_count'] = (_postData['comments_count'] ?? 0) + 1;
        });
      } else {
        _insertReplyLocal(_replyToCommentId!, optimistic);
        insertedLocally = optimistic;
      }

      // ⬇️ PRAWDZIWY ZAPIS DO BAZY (wcześniej było zakomentowane)
      await InstagramBackend.addComment(
        _postData['id'],
        text,
        parentCommentId: _replyToCommentId,
      );

      _commentController.clear();
      _clearReplyContext();

      // odświeżamy z backendu żeby mieć ID, usera itd.
      await _refreshPostDetails();
    } catch (e) {
      // cofnij optymistyczną wstawkę, jeśli zapis się nie udał
      if (insertedLocally != null) {
        _removeLocalTemp(insertedLocally['id']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Błąd przy dodawaniu komentarza: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingComment = false);
    }
  }

  // -------- COMMENTS like / replies (frontend) --------
  Future<void> _toggleCommentLike(String commentId) async {
    if (_isLikingComment) return;
    if (!mounted) return;
    setState(() => _isLikingComment = true);
    try {
      _mutateComment(commentId, (c) {
        final liked = (c['liked_by_me'] == true || c['liked_by_me'] == 'true');
        final likes = (c['likes_count'] ?? 0) as int;
        c['liked_by_me'] = !liked;
        c['likes_count'] = liked ? (likes - 1).clamp(0, 999999) : likes + 1;
      });
      // Backend toggle
      await InstagramBackend.likeComment(commentId);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isLikingComment = false);
    }
  }

  void _setReplyTarget(String commentId, String? nickname) {
    if (!mounted) return;
    setState(() {
      _replyToCommentId = commentId;
      _replyToNickname = nickname;
    });
  }

  void _clearReplyContext() {
    if (!mounted) return;
    setState(() {
      _replyToCommentId = null;
      _replyToNickname = null;
    });
  }

  void _toggleThreadExpanded(String commentId) {
    if (!mounted) return;
    setState(() {
      if (_expandedThreads.contains(commentId)) {
        _expandedThreads.remove(commentId);
      } else {
        _expandedThreads.add(commentId);
      }
    });
  }

  // -------- helpers (nested structure) --------
  void _mutateComment(String commentId, void Function(Map<String, dynamic>) mutate) {
    final list = (_postData['comments_list'] ?? []) as List;
    for (var i = 0; i < list.length; i++) {
      final c = Map<String, dynamic>.from(list[i]);
      if (c['id'].toString() == commentId.toString()) {
        mutate(c);
        list[i] = c;
        _postData['comments_list'] = list;
        return;
      }
      final mutated = _mutateReplyRecursive(c, commentId, mutate);
      if (mutated) {
        list[i] = c;
        _postData['comments_list'] = list;
        return;
      }
    }
  }

  bool _mutateReplyRecursive(Map<String, dynamic> node, String commentId, void Function(Map<String, dynamic>) mutate) {
    final replies = List<Map<String, dynamic>>.from((node['replies'] ?? []) as List);
    for (var i = 0; i < replies.length; i++) {
      var r = Map<String, dynamic>.from(replies[i]);
      if (r['id'].toString() == commentId.toString()) {
        mutate(r);
        replies[i] = r;
        node['replies'] = replies;
        return true;
      }
      if (_mutateReplyRecursive(r, commentId, mutate)) {
        replies[i] = r;
        node['replies'] = replies;
        return true;
      }
    }
    return false;
  }

  void _insertReplyLocal(String parentId, Map<String, dynamic> reply) {
    _mutateComment(parentId, (c) {
      final reps = List<Map<String, dynamic>>.from((c['replies'] ?? []) as List);
      reps.insert(0, reply);
      c['replies'] = reps;
    });
    _expandedThreads.add(parentId);
  }

  void _removeLocalTemp(String tempId) {
    final list = List<Map<String, dynamic>>.from((_postData['comments_list'] ?? []) as List);
    bool removed = false;

    Map<String, dynamic>? _removeFromNode(Map<String, dynamic> node) {
      final replies = List<Map<String, dynamic>>.from((node['replies'] ?? []) as List);
      replies.removeWhere((r) => r['id'] == tempId);
      node['replies'] = replies;
      return node;
    }

    list.removeWhere((c) {
      if (c['id'] == tempId) {
        removed = true;
        return true;
      }
      final before = (c['replies'] as List?)?.length ?? 0;
      final nc = _removeFromNode(c);
      final after = (nc?['replies'] as List?)?.length ?? 0;
      return false;
    });

    if (removed && mounted) {
      setState(() {
        _postData['comments_list'] = list;
        _postData['comments_count'] = (_postData['comments_count'] ?? 1) - 1;
      });
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final author = _postData['user'] as Map<String, dynamic>?;
    final isOwner = author?['id'] == currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        titleSpacing: 8.0,
        title: InkWell(
          onTap: () {
            if (author?['id'] != null) {
              context.pushNamed('userProfile', pathParameters: {'userId': author!['id']});
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 16.0,
                backgroundImage: author?['avatar'] != null
                    ? NetworkImage(author!['avatar'])
                    : const AssetImage(AppAssets.exampleImg) as ImageProvider,
              ),
              const SizedBox(width: 8.0),
              Text(
                author?['nickname'] ?? "Użytkownik",
                style: const TextStyle(fontSize: 16.0, color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _showDeleteDialog,
            ),
          IconButton(
            icon: const Icon(Icons.flag_rounded, color: Colors.orangeAccent),
            onPressed: () {
              InstagramReportService.showReasonDialog(
                context: context,
                onSubmit: (reason) async {
                  final result = await InstagramReportService.report(
                    type: 'post',
                    reportedItemId: _postData['id'],
                    reason: reason,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result ?? "Zgłoszono posta pomyślnie.")),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: _postData['image_url'] != null && (_postData['image_url'] as String).isNotEmpty
                        ? Image.network(_postData['image_url'], fit: BoxFit.cover)
                        : Image.asset(AppAssets.exampleImg, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: _isLiking
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                                )
                              : Icon(
                                  Icons.favorite,
                                  color: (_postData['liked_by_me'] == true || _postData['liked_by_me'] == 'true')
                                      ? Colors.red
                                      : Colors.white.withOpacity(0.5),
                                  size: 28,
                                ),
                        ),
                        const SizedBox(width: 6),
                        Text("${_postData['likes'] ?? 0}", style: const TextStyle(color: Colors.white)),
                        const SizedBox(width: 16),
                        const Icon(Icons.mode_comment_outlined, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text("${_postData['comments_count'] ?? 0}", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_postData['caption'] ?? "", style: const TextStyle(fontSize: 16, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_postData['created_at'] ?? ''),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      children: (List.from((_postData['comments_list'] ?? []) as List))
                          .map((c) => _buildCommentCard(Map<String, dynamic>.from(c)))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_replyToCommentId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.white10,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 18, color: Colors.white70),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Odpowiadasz ${_replyToNickname != null ? 'do @$_replyToNickname' : ''}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearReplyContext,
                    child: const Text("Anuluj", style: TextStyle(color: Colors.lightBlueAccent)),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyToNickname != null ? "Odpowiedz @$_replyToNickname..." : "Dodaj komentarz...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                _isAddingComment
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.blueAccent),
                        onPressed: _addComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment, {int depth = 0}) {
    final user = comment['user'] as Map<String, dynamic>?;
    final replies = List<Map<String, dynamic>>.from((comment['replies'] ?? []) as List);
    final likedByMe = (comment['liked_by_me'] == true || comment['liked_by_me'] == 'true');
    final likesCount = (comment['likes_count'] ?? 0) as int;
    final hasReplies = replies.isNotEmpty;
    final isExpanded = _expandedThreads.contains(comment['id'].toString());

    const previewCount = 2;
    final visibleReplies = !hasReplies
        ? const <Map<String, dynamic>>[]
        : isExpanded
            ? replies
            : replies.take(previewCount).toList();
    final hiddenCount = hasReplies ? (replies.length - visibleReplies.length) : 0;

    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 8, left: depth == 0 ? 0 : 48.0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: user?['avatar'] != null
                    ? NetworkImage(user!['avatar'])
                    : const AssetImage(AppAssets.exampleImg) as ImageProvider,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user?['nickname'] ?? "Użytkownik",
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    InstagramBackend.deleteComment(comment['id']).then((_) => _refreshPostDetails());
                  } else if (value == 'report') {
                    InstagramReportService.showReasonDialog(
                      context: context,
                      onSubmit: (reason) async {
                        final result = await InstagramReportService.report(
                          type: 'comment',
                          reportedItemId: comment['id'],
                          reason: reason,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result ?? "Zgłoszono komentarz.")),
                        );
                      },
                    );
                  }
                },
                icon: const Icon(Icons.more_vert, color: Colors.white60),
                color: AppColors.darkBlue,
                itemBuilder: (_) => [
                  if (comment['user_id'] == currentUser?.id)
                    const PopupMenuItem(value: 'delete', child: Text("Usuń")),
                  const PopupMenuItem(value: 'report', child: Text("Zgłoś")),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment['comment_text'] ?? "", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(_formatDate(comment['created_at'] ?? ''), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _toggleCommentLike(comment['id'].toString()),
                child: Row(
                  children: [
                    Icon(likedByMe ? Icons.favorite : Icons.favorite_border, size: 16,
                        color: likedByMe ? Colors.redAccent : Colors.white60),
                    const SizedBox(width: 4),
                    Text("$likesCount", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _setReplyTarget(comment['id'].toString(), user?['nickname']),
                child: const Text("Odpowiedz", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
              ),
            ],
          ),
          if (hasReplies) const SizedBox(height: 8),
          if (hasReplies)
            ...visibleReplies.map((r) => _buildCommentCard(Map<String, dynamic>.from(r), depth: depth + 1)).toList(),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 6),
              child: InkWell(
                onTap: () => _toggleThreadExpanded(comment['id'].toString()),
                child: Text("Pokaż kolejne odpowiedzi ($hiddenCount)",
                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
              ),
            ),
          if (hasReplies && isExpanded && replies.length > previewCount)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 6),
              child: InkWell(
                onTap: () => _toggleThreadExpanded(comment['id'].toString()),
                child: const Text("Zwiń odpowiedzi", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        title: const Text("Usuń post", style: TextStyle(color: Colors.white)),
        content: const Text("Czy na pewno chcesz usunąć ten post?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Anuluj", style: TextStyle(color: Colors.lightBlueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Usuń", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await InstagramBackend.deletePost(_postData['id']);
        if (mounted) context.pop(true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Błąd podczas usuwania: $e")),
        );
      }
    }
  }
}
