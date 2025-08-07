import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:guide_me/features/viewpoint/viewpoint_backend.dart';

class ViewpointCardWidget extends StatefulWidget {
  final Viewpoint viewpoint;
  final double? distanceKm;
  final double? avgRating;
  final VoidCallback? onTap;

  const ViewpointCardWidget({
    super.key,
    required this.viewpoint,
    this.distanceKm,
    this.avgRating,
    this.onTap,
  });

  @override
  State<ViewpointCardWidget> createState() => _ViewpointCardWidgetState();
}

class _ViewpointCardWidgetState extends State<ViewpointCardWidget> {
  bool _isFavourite = false;

  @override
  void initState() {
    super.initState();
    _loadFavourite();
  }

  Future<void> _loadFavourite() async {
    final isFav = await ViewpointBackend.isFavourite(widget.viewpoint.id);
    if (mounted) {
      setState(() => _isFavourite = isFav);
    }
  }

  Future<void> _toggleFavourite() async {
    await ViewpointBackend.toggleFavourite(widget.viewpoint.id);
    setState(() => _isFavourite = !_isFavourite);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.0),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(widget.viewpoint.imageUrl),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                Positioned(
                  top: 0.0,
                  right: 0.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _iconCircleButton(
                      icon: _isFavourite ? Icons.favorite : Icons.favorite_border,
                      iconColor: _isFavourite ? Colors.redAccent : Colors.white,
                      onTap: _toggleFavourite,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0.0,
                  right: 0.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        _iconCircleButton(icon: Icons.navigation_rounded, onTap: () {}),
                        const SizedBox(width: 4),
                        _iconCircleButton(icon: Icons.share, onTap: () {}),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.viewpoint.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18.0,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.viewpoint.address,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 10.0,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.distanceKm != null)
                              Text(
                                "${widget.distanceKm!.toStringAsFixed(1)} km",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.0,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        widget.avgRating != null
                            ? widget.avgRating!.toStringAsFixed(1)
                            : "–",
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Icon(
                        Icons.star,
                        color: Colors.yellow,
                        size: 16.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.blue,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.0),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.lighterDarkBlue,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(200),
              blurRadius: 4.0,
              offset: const Offset(1.5, 1.5),
              spreadRadius: 1.0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(6.0),
        child: Icon(icon, size: 22.0, color: iconColor),
      ),
    );
  }
}
