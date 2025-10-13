import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/features/profile/profile_backend.dart';

class UserPostsTabWidget extends StatefulWidget {
  final String? userId;
  const UserPostsTabWidget({Key? key, this.userId}) : super(key: key);

  @override
  State<UserPostsTabWidget> createState() => _UserPostsTabWidgetState();
}

class _UserPostsTabWidgetState extends State<UserPostsTabWidget>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    // Przekazujemy userId (jeśli jest podane) do metody pobierającej posty
    _postsFuture = ProfileBackend.getUserPosts(userId: widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Błąd: ${snapshot.error}"));
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(child: Text("Brak postów"));
        }
        return GridView.builder(
          key: const PageStorageKey<String>('userPostsTab'),
          padding: const EdgeInsets.all(4.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1.0, // Komórki kwadratowe
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final imageUrl = post['image_url'] as String?;
            return InkWell(
              onTap: () {
                context.pushNamed(
                  AppRoutes.postDetailsView,
                  extra: post,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Image.asset(AppAssets.exampleImg, fit: BoxFit.cover),
              ),
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
