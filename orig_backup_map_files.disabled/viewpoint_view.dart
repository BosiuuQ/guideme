import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:guide_me/features/viewpoint/viewpoint_backend.dart';
import 'package:guide_me/features/viewpoint/data/rating_service.dart';
import 'package:guide_me/features/viewpoint/presentation/widgets/viewpoint_card_widget.dart';

class ViewpointView extends StatefulWidget {
  const ViewpointView({super.key});

  @override
  State<ViewpointView> createState() => _ViewpointViewState();
}

class _ViewpointViewState extends State<ViewpointView> {
  late Future<List<Viewpoint>> _futureViewpoints;
  List<Viewpoint> _allViewpoints = [];
  String _searchQuery = "";
  String _selectedFilter = 'najnowsze';

  @override
  void initState() {
    super.initState();
    _loadViewpoints();
  }

  Future<void> _loadViewpoints() async {
    if (!mounted) return;

    List<Viewpoint> results;

    final userId = Supabase.instance.client.auth.currentUser?.id;

    switch (_selectedFilter) {
      case 'ulubione':
        if (userId == null) {
          setState(() => _futureViewpoints = Future.value([]));
          return;
        }
        final favRows = await Supabase.instance.client
            .from('favourites')
            .select('viewpoint_id')
            .eq('user_id', userId);
        final favIds = favRows.map<String>((row) => row['viewpoint_id'] as String).toList();
        results = await ViewpointBackend.getFavouriteViewpoints(favIds);
        break;

      case 'moje':
        if (userId == null) {
          setState(() => _futureViewpoints = Future.value([]));
          return;
        }
        results = await ViewpointBackend.getMyViewpoints(userId);
        break;

      case 'blisko':
        results = await _loadNearby();
        break;

      default:
        results = await ViewpointBackend.getAllViewpoints();
        break;
    }

    setState(() {
      _allViewpoints = results;
      _futureViewpoints = Future.value(_filterBySearch(results));
    });
  }

  Future<List<Viewpoint>> _loadNearby() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return [];
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return [];
        }
      }
      final position = await Geolocator.getCurrentPosition();
      return await ViewpointBackend.getNearbyViewpoints(position.latitude, position.longitude);
    } catch (_) {
      return [];
    }
  }

  List<Viewpoint> _filterBySearch(List<Viewpoint> viewpoints) {
    if (_searchQuery.isEmpty) return viewpoints;
    final q = _searchQuery.toLowerCase();
    return viewpoints.where((v) =>
        v.title.toLowerCase().contains(q) || v.description.toLowerCase().contains(q)).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _futureViewpoints = Future.value(_filterBySearch(_allViewpoints));
    });
  }

  Future<Map<String, dynamic>> _prepareExtraData(Viewpoint v) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        v.coordinates.y,
        v.coordinates.x,
      ) / 1000;
      final avgRating = await RatingService().getAverageRating(v.id);
      return {'distance': distance, 'avgRating': avgRating};
    } catch (_) {
      return {'distance': null, 'avgRating': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        title: const Text("GuideMe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () async {
              final query = await showSearch(
                context: context,
                delegate: _ViewpointSearchDelegate(allViewpoints: _allViewpoints),
              );
              if (query != null && query is String) _onSearchChanged(query);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(AppRoutes.viewpointAddView),
        backgroundColor: AppColors.blue,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<Viewpoint>>(
              future: _futureViewpoints,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Błąd: ${snapshot.error}", style: TextStyle(color: Colors.white)));
                }
                final viewpoints = snapshot.data ?? [];
                if (viewpoints.isEmpty) {
                  return const Center(child: Text("Brak punktów widokowych", style: TextStyle(color: Colors.white)));
                }

                return ListView.separated(
                  itemCount: viewpoints.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final viewpoint = viewpoints[index];
                    return FutureBuilder<Map<String, dynamic>>(
                      future: _prepareExtraData(viewpoint),
                      builder: (context, snapshot) {
                        final distance = snapshot.data?['distance'] as double?;
                        final avgRating = snapshot.data?['avgRating'] as double?;
                        return ViewpointCardWidget(
                          viewpoint: viewpoint,
                          distanceKm: distance,
                          avgRating: avgRating,
                          onTap: () {
                            context.pushNamed(
                              AppRoutes.viewpointDetailsView,
                              extra: viewpoint,
                            );
                          },
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 16.0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.lighterDarkBlue.withOpacity(0.6),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _filterOption("Ulubione", 'ulubione'),
            const SizedBox(width: 8),
            _filterOption("Blisko mnie", 'blisko'),
            const SizedBox(width: 8),
            _filterOption("Moje punkty", 'moje'),
            const SizedBox(width: 8),
            _filterOption("Najnowsze", 'najnowsze'),
          ],
        ),
      ),
    );
  }

  Widget _filterOption(String text, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadViewpoints();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: AppColors.blue, width: 1.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.0,
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ViewpointSearchDelegate extends SearchDelegate<String> {
  final List<Viewpoint> allViewpoints;

  _ViewpointSearchDelegate({required this.allViewpoints});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      scaffoldBackgroundColor: AppColors.darkBlue,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      inputDecorationTheme: const InputDecorationTheme(hintStyle: TextStyle(color: Colors.white70)),
      textTheme: theme.textTheme.copyWith(titleLarge: const TextStyle(color: Colors.white)),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions();

  Widget _buildSuggestions() {
    final results = allViewpoints.where((v) {
      final q = query.toLowerCase();
      return v.title.toLowerCase().contains(q) || v.description.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(results[index].title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          results[index].description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70),
        ),
        onTap: () => close(context, query),
      ),
    );
  }
}
