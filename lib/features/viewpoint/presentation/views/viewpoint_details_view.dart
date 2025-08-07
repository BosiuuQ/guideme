import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/viewpoint/data/comment_service.dart';
import 'package:guide_me/features/viewpoint/data/rating_service.dart';
import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:guide_me/features/viewpoint/presentation/widgets/viewpoint_comment_tile.dart';

class ViewpointDetailsView extends StatefulWidget {
  final Viewpoint viewpoint;
  const ViewpointDetailsView({super.key, required this.viewpoint});

  @override
  State<ViewpointDetailsView> createState() => _ViewpointDetailsViewState();
}

class _ViewpointDetailsViewState extends State<ViewpointDetailsView> {
  final commentController = TextEditingController();
  double? distanceKm;
  List<Map<String, dynamic>> comments = [];
  int myRating = 0;
  double avgRating = 0.0;
  String? currentUserId;

  bool get isOwner => currentUserId == widget.viewpoint.userId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    currentUserId = Supabase.instance.client.auth.currentUser?.id;
    await _loadData();
    await _calculateDistance();
  }

  Future<void> _loadData() async {
    comments = await CommentService().fetchComments(widget.viewpoint.id);
    avgRating = await RatingService().getAverageRating(widget.viewpoint.id);
    myRating = await RatingService().getUserRating(widget.viewpoint.id);
    setState(() {});
  }

  Future<void> _calculateDistance() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
    final position = await Geolocator.getCurrentPosition();
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.viewpoint.coordinates.y,
      widget.viewpoint.coordinates.x,
    ) / 1000;
    setState(() => distanceKm = distance);
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
            onPressed: _showReportDialog,
          )
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
          Text(widget.viewpoint.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(widget.viewpoint.description ?? "Brak opisu.", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (distanceKm != null)
            Text("📍 Odległość: ${distanceKm!.toStringAsFixed(2)} km", style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Śr. ocena: ${avgRating.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Komentarze", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          for (final comment in comments) ViewpointCommentTile(comment: comment),
          const SizedBox(height: 20),
          TextField(
            controller: commentController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Dodaj komentarz...",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final text = commentController.text.trim();
              if (text.isEmpty) return;
              await CommentService().addComment(viewpointId: widget.viewpoint.id, commentText: text);
              commentController.clear();
              await _loadData();
            },
            child: const Text("Dodaj komentarz"),
          )
        ],
      ),
    );
  }

  void _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Usuń punkt', style: TextStyle(color: Colors.white)),
        content: const Text('Czy na pewno chcesz usunąć ten punkt widokowy?', style: TextStyle(color: Colors.white70)),
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

  Future<void> _showReportDialog() async {
    // Nie zmieniam - zostaje jak w Twojej wersji
  }

  Future<void> _sendReport(String reason) async {
    // Nie zmieniam - zostaje jak w Twojej wersji
  }

  Future<void> _sendDiscordEmbed(String reason) async {
    // Nie zmieniam - zostaje jak w Twojej wersji
  }
}
