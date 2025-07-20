import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/viewpoint/data/rating_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ViewpointCommentsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final String viewpointId;
  final String? currentUserId;
  final TextEditingController controller;
  final bool isLoading;
  final Function(String commentId) onDelete;
  final VoidCallback onAddComment;

  const ViewpointCommentsWidget({
    super.key,
    required this.comments,
    required this.viewpointId,
    required this.currentUserId,
    required this.controller,
    required this.isLoading,
    required this.onDelete,
    required this.onAddComment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Komentarze:",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...comments.map((comment) => _buildSingleComment(context, comment)),
        const SizedBox(height: 16),
        _buildAddCommentField(),
      ],
    );
  }

  Widget _buildSingleComment(BuildContext context, Map<String, dynamic> comment) {
    final user = comment['users'] ?? {};
    final nickname = user['nickname'] ?? "Użytkownik";
    final level = user['account_lvl'] ?? 1;
    final avatar = user['avatar'];
    final commentUserId = user['id'];
    final isMyComment = currentUserId == commentUserId;

    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          ListTile(
            onTap: () {
              if (commentUserId != null) {
                context.pushNamed('userProfile', pathParameters: {'userId': commentUserId});
              }
            },
            leading: GestureDetector(
              onTap: () {
                if (commentUserId != null) {
                  context.pushNamed('userProfile', pathParameters: {'userId': commentUserId});
                }
              },
              child: CircleAvatar(
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                backgroundColor: Colors.blueGrey,
              ),
            ),
            title: GestureDetector(
              onTap: () {
                if (commentUserId != null) {
                  context.pushNamed('userProfile', pathParameters: {'userId': commentUserId});
                }
              },
              child: Text("$nickname (Lvl $level)",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            subtitle: Text(comment['comment'],
                style: const TextStyle(color: Colors.white70)),
            trailing: isMyComment
                ? PopupMenuButton<String>(
                    onSelected: (value) => onDelete(comment['id']),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Usuń komentarz'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  )
                : null,
          ),
          Positioned(
            top: 8,
            right: isMyComment ? 48 : 12,
            child: FutureBuilder<int>(
              future: RatingService().getUserRatingFor(
                  viewpointId: viewpointId, userId: commentUserId),
              builder: (context, snapshot) {
                final rating = snapshot.data ?? 0;
                if (rating > 0) {
                  return RatingBarIndicator(
                    rating: rating.toDouble(),
                    itemBuilder: (context, index) =>
                        const Icon(Icons.star, color: Colors.amber),
                    itemCount: 5,
                    itemSize: 14,
                    unratedColor: Colors.white24,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCommentField() {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Dodaj komentarz...",
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white24,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: isLoading
              ? const CircularProgressIndicator()
              : const Icon(Icons.send, color: Colors.blueAccent),
          onPressed: onAddComment,
        ),
      ),
    );
  }
}