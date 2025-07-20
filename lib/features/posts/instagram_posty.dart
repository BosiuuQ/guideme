import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/posts/instagram_backend.dart';

class InstagramPostyView extends StatefulWidget {
  const InstagramPostyView({Key? key}) : super(key: key);

  @override
  State<InstagramPostyView> createState() => _InstagramPostyViewState();
}

class _InstagramPostyViewState extends State<InstagramPostyView> {
  List<Map<String, dynamic>> allPosts = [];
  List<Map<String, dynamic>> filteredPosts = [];
  String searchQuery = "";
  String sortOption = "Od najnowszych";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await InstagramBackend.getPosts();
      setState(() {
        allPosts = posts;
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      print("Błąd pobierania postów: $e");
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> tempPosts = allPosts.where((post) {
      final description = post['caption']?.toString().toLowerCase() ?? "";
      return description.contains(searchQuery.toLowerCase());
    }).toList();

    if (sortOption == "Od najnowszych") {
      tempPosts.sort((a, b) {
        final dtA = DateTime.tryParse(a['created_at'] ?? "") ?? DateTime(1970);
        final dtB = DateTime.tryParse(b['created_at'] ?? "") ?? DateTime(1970);
        return dtB.compareTo(dtA);
      });
    } else if (sortOption == "Najbardziej lubiane dzisiaj") {
      final today = DateTime.now();
      tempPosts = tempPosts.where((post) {
        final dt = DateTime.tryParse(post['created_at'] ?? "") ?? DateTime(1970);
        return dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day;
      }).toList();
      tempPosts.sort((a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0));
    } else if (sortOption == "Najbardziej lubiane w tygodniu") {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      tempPosts = tempPosts.where((post) {
        final dt = DateTime.tryParse(post['created_at'] ?? "") ?? DateTime(1970);
        return dt.isAfter(weekAgo);
      }).toList();
      tempPosts.sort((a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0));
    } else if (sortOption == "Najbardziej lubiane w miesiącu") {
      final monthAgo = DateTime(DateTime.now().year, DateTime.now().month - 1, DateTime.now().day);
      tempPosts = tempPosts.where((post) {
        final dt = DateTime.tryParse(post['created_at'] ?? "") ?? DateTime(1970);
        return dt.isAfter(monthAgo);
      }).toList();
      tempPosts.sort((a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0));
    }

    setState(() {
      filteredPosts = tempPosts;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            _buildSortTile("Od najnowszych"),
            _buildSortTile("Najbardziej lubiane dzisiaj"),
            _buildSortTile("Najbardziej lubiane w tygodniu"),
            _buildSortTile("Najbardziej lubiane w miesiącu"),
          ],
        );
      },
    );
  }

  ListTile _buildSortTile(String option) {
    return ListTile(
      title: Text(option),
      onTap: () {
        setState(() {
          sortOption = option;
          _applyFilters();
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Instaguide"),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showSortOptions,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Wyszukaj posty...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredPosts.isEmpty
              ? const Center(child: Text("Brak postów spełniających kryteria"))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    itemCount: filteredPosts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final post = filteredPosts[index];
                      return InkWell(
                        onTap: () {
                          context.pushNamed(
                            AppRoutes.postDetailsView,
                            extra: post,
                          );
                        },
                        child: Image.network(
                          post['image_url'] ?? "",
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
