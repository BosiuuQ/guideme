import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';

class ViewpointCommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;

  const ViewpointCommentTile({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final user = comment['users'];
    final avatar = user?['avatar'];
    final nickname = user?['nickname'] ?? 'Nieznany';
    final lvl = user?['account_lvl'] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            backgroundColor: AppColors.blue,
            radius: 20,
            child: avatar == null ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$nickname • lvl $lvl', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(comment['comment'], style: const TextStyle(color: Colors.white70)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
