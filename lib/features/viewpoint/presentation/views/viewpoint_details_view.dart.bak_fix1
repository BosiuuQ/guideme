// lib/features/viewpoint/presentation/views/viewpoint_details_view.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/viewpoint/data/comment_service.dart';
import 'package:guide_me/features/viewpoint/data/rating_service.dart';
import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';

class ViewpointDetailsView extends StatefulWidget {
  final Viewpoint viewpoint;
  const ViewpointDetailsView({super.key, required this.viewpoint});

  @override
  State<ViewpointDetailsView> createState() => _ViewpointDetailsViewState();
}

class _ViewpointDetailsViewState extends State<ViewpointDetailsView> {
  final commentController = TextEditingController();

  String? currentUserId;
  String? get _ownerId => widget.viewpoint.creatorId; // używamy creatorId z Twojego modelu
  Map<String, dynamic>? _ownerProfile;

  double? distanceKm;
  List<Map<String, dynamic>> comments = [];
  int myRating = 0;
  double avgRating = 0.0;

  bool get isOwner => currentUserId != null && _ownerId != null && currentUserId == _ownerId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    currentUserId = Supabase.instance.client.auth.currentUser?.id;
    await Future.wait([
      _loadOwnerProfile(),
      _loadData(),
      _calculateDistance(),
    ]);
  }

  Future<void> _loadOwnerProfile() async {
    try {
      final uid = _ownerId;
      if (uid == null) return;
      final res = await Supabase.instance.client
          .from('users')
          .select('id, nickname, avatar')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _ownerProfile = res == null ? null : Map<String, dynamic>.from(res));
    } catch (_) {}
  }

  Future<void> _loadData() async {
    comments = await CommentService().fetchComments(widget.viewpoint.id);
    avgRating = await RatingService().getAverageRating(widget.viewpoint.id);
    myRating = await RatingService().getUserRating(widget.viewpoint.id);
    if (mounted) setState(() {});
  }

  Future<void> _calculateDistance() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition();
      final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            widget.viewpoint.coordinates.y,
            widget.viewpoint.coordinates.x,
          ) /
          1000;
      if (mounted) setState(() => distanceKm = distance);
    } catch (_) {}
  }

  // ---------- Comment actions ----------

  Future<void> _addComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;

    // avatar autora (jeśli to my i mamy profil)
    final selfAvatar = (_ownerProfile != null &&
            _ownerProfile!['id'] != null &&
            _ownerProfile!['id'] == currentUserId)
        ? _ownerProfile!['avatar']
        : null;

    // optimistic insert
    final optimistic = {
      'id': 'temp_${DateTime.now().microsecondsSinceEpoch}',
      'user_id': currentUserId,
      'comment_text': text,
      'created_at': DateTime.now().toIso8601String(),
      'likes_count': 0,
      'liked_by_me': false,
      'user': {
        'id': currentUserId,
        'nickname': 'Ty',
        'avatar': selfAvatar,
      }
    };
    setState(() {
      comments = [optimistic, ...comments];
      commentController.clear();
    });

    try {
      await CommentService().addComment(
        viewpointId: widget.viewpoint.id,
        commentText: text,
      );
      await _loadData(); // odśwież prawdziwe id i liczniki
    } catch (e) {
      setState(() {
        comments.removeWhere((c) => c['id'] == optimistic['id']);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się dodać komentarza: $e')),
      );
    }
  }

  Future<void> _likeComment(String commentId) async {
    // optimistic toggle
    setState(() {
      final idx = comments.indexWhere((c) => c['id'].toString() == commentId);
      if (idx != -1) {
        final c = Map<String, dynamic>.from(comments[idx]);
        final liked = (c['liked_by_me'] == true || c['liked_by_me'] == 'true');
        final likes = (c['likes_count'] ?? 0) as int;
        c['liked_by_me'] = !liked;
        c['likes_count'] = liked ? (likes - 1).clamp(0, 999999) : likes + 1;
        comments[idx] = c;
      }
    });

    try {
      await CommentService().likeComment(commentId);
    } catch (e) {
      // revert
      setState(() {
        final idx = comments.indexWhere((c) => c['id'].toString() == commentId);
        if (idx != -1) {
          final c = Map<String, dynamic>.from(comments[idx]);
          final liked = (c['liked_by_me'] == true || c['liked_by_me'] == 'true');
          final likes = (c['likes_count'] ?? 0) as int;
          c['liked_by_me'] = !liked;
          c['likes_count'] = liked ? likes + 1 : (likes - 1).clamp(0, 999999);
          comments[idx] = c;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się polubić komentarza: $e')),
      );
    }
  }

  Future<void> _reportComment(String commentId) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final items = [
          'Spam / reklama',
          'Mowa nienawiści',
          'Treści niebezpieczne',
          'Naruszenie prywatności',
          'Prawa autorskie',
          'Inne'
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Zgłoś komentarz',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),
                ...items.map((label) => ListTile(
                      title: Text(label, style: const TextStyle(color: Colors.white)),
                      onTap: () => Navigator.pop(ctx, label),
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (reason == null) return;

    try {
      await CommentService().reportComment(commentId: commentId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dziękujemy za zgłoszenie.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zgłosić komentarza: $e')),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Usuń komentarz', style: TextStyle(color: Colors.white)),
        content: const Text('Na pewno chcesz usunąć ten komentarz?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await CommentService().deleteComment(commentId);
      setState(() {
        comments.removeWhere((c) => c['id'].toString() == commentId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się usunąć komentarza: $e')),
      );
    }
  }

  // ---------- Viewpoint delete ----------

  void _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Usuń punkt', style: TextStyle(color: Colors.white)),
        content: const Text('Czy na pewno chcesz usunąć ten punkt widokowy?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client
          .from('punkty_widokowe')
          .delete()
          .eq('id', widget.viewpoint.id);

      if (mounted) Navigator.pop(context, true);
    }
  }

  // ---------- UI ----------

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        title: Text(widget.viewpoint.title),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Usuń punkt',
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _showReportDialog, // placeholder na raport punktu
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: widget.viewpoint.imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.viewpoint.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),

          _buildOwnerRow(),
          const SizedBox(height: 8),

          Text(
            widget.viewpoint.description ?? "Brak opisu.",
            style: const TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 12),

          if (distanceKm != null)
            Text(
              "📍 Odległość: ${distanceKm!.toStringAsFixed(2)} km",
              style: const TextStyle(color: Colors.white54),
            ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Śr. ocena: ${avgRating.toStringAsFixed(1)}",
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              RatingBar.builder(
                initialRating: myRating.toDouble(),
                minRating: 1,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 24,
                unratedColor: Colors.white24,
                itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (value) async {
                  await RatingService().rateViewpoint(widget.viewpoint.id, value.toInt());
                  myRating = value.toInt();
                  avgRating = await RatingService().getAverageRating(widget.viewpoint.id);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text("Komentarze",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          ...comments.map(_buildCommentTile).toList(),

          const SizedBox(height: 20),

          _buildAddCommentCard(),
        ],
      ),
    );
  }

  Widget _buildOwnerRow() {
    final avatar = _ownerProfile?['avatar'];
    final nickname = _ownerProfile?['nickname'] ?? 'Użytkownik';
    final canOpenProfile = _ownerId != null;

    return InkWell(
      onTap: canOpenProfile
          ? () => context.pushNamed(
                'userProfile',
                pathParameters: {'userId': _ownerId!},
              )
          : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                ? NetworkImage(avatar)
                : null,
            child: (avatar == null || avatar.toString().isEmpty)
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
          const SizedBox(width: 8),
          Text(nickname, style: const TextStyle(color: Colors.white70)),
          if (canOpenProfile) ...[
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new, size: 14, color: Colors.white38),
          ],
        ],
      ),
    );
  }

  Widget _buildAddCommentCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          TextField(
            controller: commentController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Dodaj komentarz...",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addComment,
              icon: const Icon(Icons.send),
              label: const Text("Dodaj komentarz"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> c) {
    final user = (c['user'] ?? {}) as Map<String, dynamic>;
    final nickname = user['nickname'] ?? 'Użytkownik';
    final avatar = user['avatar'];
    final userId = c['user_id']?.toString();
    final commentId = c['id']?.toString() ?? '';

    final liked = (c['liked_by_me'] == true || c['liked_by_me'] == 'true');
    final likes = (c['likes_count'] ?? 0) as int;

    final canDelete = isOwner || (currentUserId != null && currentUserId == userId);

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
            backgroundImage:
                (avatar != null && avatar.toString().isNotEmpty) ? NetworkImage(avatar) : null,
            child: (avatar == null || avatar.toString().isEmpty)
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nick + menu
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteComment(commentId);
                        } else if (value == 'report') {
                          _reportComment(commentId);
                        }
                      },
                      icon: const Icon(Icons.more_vert, color: Colors.white60),
                      color: AppColors.darkBlue,
                      itemBuilder: (_) => [
                        if (canDelete)
                          const PopupMenuItem(value: 'delete', child: Text("Usuń")),
                        const PopupMenuItem(value: 'report', child: Text("Zgłoś")),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Treść
                Text(
                  c['comment_text'] ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 8),

                // Meta: like
                Row(
                  children: [
                    InkWell(
                      onTap: () => _likeComment(commentId),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: liked ? Colors.redAccent : Colors.white60,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$likes',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder – raport punktu (zostawiony do Twojej implementacji)
  Future<void> _showReportDialog() async {}
}
