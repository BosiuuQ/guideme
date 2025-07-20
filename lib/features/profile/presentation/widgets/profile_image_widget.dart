import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';

class ProfileImageWidget extends StatelessWidget {
  final String level;
  final String avatarUrl;

  const ProfileImageWidget({
    super.key,
    required this.level,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(200),
          child: Container(
            padding: const EdgeInsets.all(2.0),
            color: AppColors.lightBlue,
            child: CircleAvatar(
              radius: 65.0,
              backgroundImage: (avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : const AssetImage(AppAssets.exampleImg) as ImageProvider,
            ),
          ),
        ),
        Positioned(
          bottom: 0.0,
          child: Container(
            width: 70.0,
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.lightBlue,
                  AppColors.lighterDarkBlue,
                ],
              ),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: FittedBox(
              child: Text(
                "$level LVL",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.0,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
