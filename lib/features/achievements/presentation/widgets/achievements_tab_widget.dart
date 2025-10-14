import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/achievements/presentation/widgets/achievement_card_widget.dart';

class AchievementsTabWidget extends StatefulWidget {
  const AchievementsTabWidget({
    super.key,
    this.userId,
  });

  /// Gdy podasz userId – pokaże osiągnięcia tego użytkownika (np. na cudzym profilu).
  /// Gdy null – użyje aktualnie zalogowanego.
  final String? userId;

  @override
  State<AchievementsTabWidget> createState() => _AchievementsTabWidgetState();
}

class _AchievementsTabWidgetState extends State<AchievementsTabWidget>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? currentKm;
  Map<String, dynamic>? nextKm;

  Map<String, dynamic>? currentPosts;
  Map<String, dynamic>? nextPosts;

  Map<String, dynamic>? currentViewpoints;
  Map<String, dynamic>? nextViewpoints;

  double totalKm = 0;
  int totalPosts = 0;
  int totalViewpoints = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final client = Supabase.instance.client;
      final userId = widget.userId ?? client.auth.currentUser?.id;

      if (userId == null) {
        setState(() => loading = false);
        return;
      }

      // Suma km
      final distanceRes = await client
          .from('user_distance')
          .select('total_km')
          .eq('user_id', userId)
          .maybeSingle();

      totalKm = ((distanceRes?['total_km']) as num?)?.toDouble() ?? 0.0;

      // Liczba postów
      final postsRes = await client
          .from('instagram_posty')
          .select('id')
          .eq('user_id', userId);
      totalPosts = (postsRes as List).length;

      // Liczba punktów widokowych
      final viewpointsRes = await client
          .from('punkty_widokowe')
          .select('id')
          .eq('author_id', userId);
      totalViewpoints = (viewpointsRes as List).length;

      // Odblokowane osiągnięcia
      final unlockedRes = await client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);

      final unlockedIds = (unlockedRes as List)
          .map((e) => e['achievement_id'])
          .whereType<String>()
          .toSet();

      // Lista progów KM
      final kmList = await client
          .from('achievements_km')
          .select()
          .order('required_km', ascending: true);

      _assignCurrentAndNext(
        kmList as List<dynamic>,
        unlockedIds,
        totalKm.toDouble(),
        (current, next) {
          currentKm = current;
          nextKm = next;
        },
      );

      // Lista progów postów
      final postsList = await client
          .from('achievements_posts')
          .select()
          .order('required_posts', ascending: true);

      _assignCurrentAndNext(
        postsList as List<dynamic>,
        unlockedIds,
        totalPosts.toDouble(),
        (current, next) {
          currentPosts = current;
          nextPosts = next;
        },
      );

      // Lista progów punktów widokowych
      final viewpointsList = await client
          .from('achievements_viewpoints')
          .select()
          .order('required_points', ascending: true);

      _assignCurrentAndNext(
        viewpointsList as List<dynamic>,
        unlockedIds,
        totalViewpoints.toDouble(),
        (current, next) {
          currentViewpoints = current;
          nextViewpoints = next;
        },
      );
    } catch (e) {
      // ewentualnie możesz dodać log/Toast
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _assignCurrentAndNext(
    List<dynamic> list,
    Set<String> unlockedIds,
    double total,
    void Function(Map<String, dynamic>?, Map<String, dynamic>?) callback,
  ) {
    final all = List<Map<String, dynamic>>.from(list);

    Map<String, dynamic>? current;
    Map<String, dynamic>? next;

    for (var i = 0; i < all.length; i++) {
      final ach = all[i];
      final requiredNum = ((ach['required_km'] ??
                  ach['required_posts'] ??
                  ach['required_points']) as num?)
              ?.toDouble() ??
          0.0;

      if (total >= requiredNum) {
        current = ach;
        next = i + 1 < all.length ? all[i + 1] : null;
      } else {
        next ??= ach;
        break;
      }
    }

    callback(current, next);
  }

  void _showModal({
    required Map<String, dynamic>? current,
    required Map<String, dynamic>? next,
    required double value,
    required Icon icon,
    required String unit,
    required String fieldName,
  }) {
    final requiredValue =
        ((next ?? current)?[fieldName] as num?)?.toDouble() ?? 1.0;
    final remaining = (requiredValue - value).clamp(0, requiredValue);
    final percent = (value / requiredValue).clamp(0.0, 1.0);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1C1F26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                icon,
                const SizedBox(height: 12),
                Text(
                  current?['title'] ?? next?['title'] ?? "Brak osiągnięcia",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${value.toStringAsFixed(unit == 'km' ? 2 : 0)} $unit zdobyte",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: percent,
                  backgroundColor: Colors.grey[800],
                  color: Colors.blueAccent,
                  minHeight: 6,
                  // jeśli masz Flutter z borderRadius w LPI – ok; jeśli nie, usuń poniższą linię:
                  // borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 8),
                Text(
                  "${value.toStringAsFixed(unit == 'km' ? 2 : 0)} / ${requiredValue.toStringAsFixed(0)} $unit",
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (next != null) ...[
                  Text("Kolejny poziom: ${next['title']}",
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    "Brakuje ci jeszcze ${remaining.toStringAsFixed(unit == 'km' ? 2 : 0)} $unit",
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          if (currentKm != null || nextKm != null)
            AchievementCardWidget(
              icon: const Icon(Icons.speed, size: 36, color: Colors.cyan),
              title: (currentKm ?? nextKm)!['title'],
              description: (currentKm ?? nextKm)!['description'],
              onTap: () => _showModal(
                current: currentKm,
                next: nextKm,
                value: totalKm,
                icon: const Icon(Icons.speed, size: 36, color: Colors.cyan),
                unit: 'km',
                fieldName: 'required_km',
              ),
            ),
          if (currentPosts != null || nextPosts != null)
            AchievementCardWidget(
              icon: const Icon(Icons.camera_alt, size: 36, color: Colors.pink),
              title: (currentPosts ?? nextPosts)!['title'],
              description: (currentPosts ?? nextPosts)!['description'],
              onTap: () => _showModal(
                current: currentPosts,
                next: nextPosts,
                value: totalPosts.toDouble(),
                icon: const Icon(Icons.camera_alt, size: 36, color: Colors.pink),
                unit: 'postów',
                fieldName: 'required_posts',
              ),
            ),
          if (currentViewpoints != null || nextViewpoints != null)
            AchievementCardWidget(
              icon: const Icon(Icons.location_on, size: 36, color: Colors.orange),
              title: (currentViewpoints ?? nextViewpoints)!['title'],
              description: (currentViewpoints ?? nextViewpoints)!['description'],
              onTap: () => _showModal(
                current: currentViewpoints,
                next: nextViewpoints,
                value: totalViewpoints.toDouble(),
                icon: const Icon(Icons.location_on, size: 36, color: Colors.orange),
                unit: 'punktów',
                fieldName: 'required_points',
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
