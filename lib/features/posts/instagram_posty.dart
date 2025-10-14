import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/posts/instagram_backend.dart';

class InstagramPostyView extends StatefulWidget {
  const InstagramPostyView({Key? key}) : super(key: key);

  @override
  State<InstagramPostyView> createState() => _InstagramPostyViewState();
}

class _InstagramPostyViewState extends State<InstagramPostyView>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 30;

  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _offset = 0;

  String _search = '';
  String _period = 'all'; // 'all' | 'today' | 'week' | 'month'
  Timer? _debounce;

  final ScrollController _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetchFirstPage() async {
    setState(() {
      _isLoading = true;
      _posts.clear();
      _offset = 0;
      _hasMore = true;
    });
    final page = await InstagramBackend.getPostsPaged(
      limit: _pageSize,
      offset: _offset,
      search: _search,
      period: _period,
    );
    setState(() {
      _posts.addAll(page);
      _isLoading = false;
      _hasMore = page.length == _pageSize;
      _offset = _posts.length;
    });
  }

  Future<void> _fetchMore() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    final page = await InstagramBackend.getPostsPaged(
      limit: _pageSize,
      offset: _offset,
      search: _search,
      period: _period,
    );
    setState(() {
      _posts.addAll(page);
      _hasMore = page.length == _pageSize;
      _offset = _posts.length;
      _isFetchingMore = false;
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _fetchMore();
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search = v.trim();
      _fetchFirstPage();
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            _buildSortTile("Od najnowszych", 'all'),
            _buildSortTile("Dzisiaj (najnowsze)", 'today'),
            _buildSortTile("Ostatni tydzień (najnowsze)", 'week'),
            _buildSortTile("Ostatni miesiąc (najnowsze)", 'month'),
          ],
        );
      },
    );
  }

  ListTile _buildSortTile(String label, String periodValue) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        setState(() => _period = periodValue);
        _fetchFirstPage();
      },
    );
  }

  Future<void> _onRefresh() => _fetchFirstPage();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("InstaGuide"),
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
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _debounce?.cancel();
                _search = v.trim();
                _fetchFirstPage();
              },
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const Center(child: Text("Brak postów spełniających kryteria"))
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: GridView.builder(
                    controller: _scroll,
                    itemCount: _posts.length + (_isFetchingMore ? 1 : 0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    cacheExtent: 800,
                    itemBuilder: (context, index) {
                      if (index >= _posts.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final post = _posts[index];
                      final imageUrl = (post['image_url'] as String?) ?? '';

                      return InkWell(
                        onTap: () => context.pushNamed(
                          AppRoutes.postDetailsView,
                          extra: post,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                          maxWidthDiskCache: 600,
                          maxHeightDiskCache: 600,
                          placeholder: (context, url) =>
                              Container(color: Colors.black12),
                          errorWidget: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
