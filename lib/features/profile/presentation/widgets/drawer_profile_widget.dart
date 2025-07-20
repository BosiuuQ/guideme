import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/profile/profile_backend.dart';
import 'package:guide_me/features/profile/presentation/widgets/profile_image_widget.dart';

class DrawerProfileWidget extends StatelessWidget {
  const DrawerProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ProfileBackend.getUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Błąd: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final data = snapshot.data!;
        final level = data['account_lvl']?.toString() ?? "0";
        final nickname = data['nickname'] ?? "Brak nicka";
        final avatarUrl = data['avatar'] ?? "";

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ProfileImageWidget(
                level: level,
                avatarUrl: avatarUrl,
              ),
              const SizedBox(height: 16.0),
              Text(
                nickname,
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w700,
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
