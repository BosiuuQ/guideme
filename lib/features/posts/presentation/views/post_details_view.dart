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

  @override
  void initState() {
    super.initState();
    _postData = widget.postData;
    _refreshPostDetails();
  }

  Future<void> _refreshPostDetails() async {
    try {
      final updatedData = await InstagramBackend.getPostDetails(_postData['id']);
      setState(() {
        _postData = updatedData;
      });
    } catch (e) {
      print("Error refreshing post details: $e");
    }
  }

  Future<void> _toggleLike() async {
    setState(() => _isLiking = true);
    try {
      await InstagramBackend.likePost(_postData['id']);
      await _refreshPostDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd przy aktualizacji lajka: $e")),
      );
    } finally {
      setState(() => _isLiking = false);
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;
    setState(() => _isAddingComment = true);
    try {
      await InstagramBackend.addComment(_postData['id'], commentText);
      _commentController.clear();
      await _refreshPostDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd przy dodawaniu komentarza: $e")),
      );
    } finally {
      setState(() => _isAddingComment = false);
    }
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
        if (mounted) context.pop(true); // Zwraca wartość do poprzedniego widoku
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Błąd podczas usuwania: $e")),
        );
      }
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result ?? "Zgłoszono posta pomyślnie.")),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(_postData['created_at'])),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                children: ((_postData['comments_list'] ?? []) as List)
                    .map((comment) => _buildCommentCard(Map<String, dynamic>.from(comment)))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Dodaj komentarz...",
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isAddingComment
                      ? const CircularProgressIndicator(strokeWidth: 2.0)
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.blueAccent),
                          onPressed: _addComment,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final user = comment['user'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: user?['avatar'] != null
                ? NetworkImage(user!['avatar'])
                : const AssetImage(AppAssets.exampleImg) as ImageProvider,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?['nickname'] ?? "Użytkownik",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['comment_text'] ?? "",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
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
    );
  }
}