import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/achievements/presentation/widgets/achievement_card_widget.dart';

class AchievementsTabWidget extends StatefulWidget {
  const AchievementsTabWidget({super.key});

  @override
  State<AchievementsTabWidget> createState() => _AchievementsTabWidgetState();
}

class _AchievementsTabWidgetState extends State<AchievementsTabWidget>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? currentKm;
  Map<String, dynamic>? nextKm;

  double totalKm = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final client = Supabase.instance.client;

    final distanceRes = await client
        .from('user_distance')
        .select('total_km')
        .eq('user_id', userId)
        .maybeSingle();

    final unlockedRes = await client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', userId);

    final unlockedIds = Set<String>.from(unlockedRes.map((e) => e['achievement_id']));

    totalKm = (distanceRes?['total_km'] ?? 0).toDouble();

    final kmList = await client
        .from('achievements_km')
        .select()
        .order('required_km', ascending: true);

    _assignCurrentAndNext(kmList, unlockedIds, totalKm, (current, next) {
      currentKm = current;
      nextKm = next;
    });

    setState(() {
      loading = false;
    });
  }

  void _assignCurrentAndNext(List<dynamic> list, Set<String> unlockedIds, double total,
      void Function(Map<String, dynamic>?, Map<String, dynamic>?) callback) {
    final all = List<Map<String, dynamic>>.from(list);

    Map<String, dynamic>? current;
    Map<String, dynamic>? next;

    for (var i = 0; i < all.length; i++) {
      final ach = all[i];
      final required = (ach['required_km'] ?? ach['required_posts'] ?? ach['required_points']) as num;
      if (total >= required) {
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
  }) {
    final requiredKm = ((next ?? current)?['required_km'] as num?)?.toDouble() ?? 1;
    final remaining = (requiredKm - value).clamp(0, requiredKm);
    final percent = (value / requiredKm).clamp(0.0, 1.0);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  "${value.toStringAsFixed(2)} km zdobyte",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: percent,
                  backgroundColor: Colors.grey[800],
                  color: Colors.blueAccent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 8),
                Text(
                  "${value.toStringAsFixed(2)} / ${requiredKm.toStringAsFixed(0)} km",
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (next != null) ...[
                  Text("Kolejny poziom: ${next['title']}", style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text("Brakuje ci jeszcze ${remaining.toStringAsFixed(2)} km",
                      style: const TextStyle(color: Colors.white38)),
                ]
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
        spacing: 16,
        runSpacing: 16,
        children: [
          if (currentKm != null)
            AchievementCardWidget(
              icon: const Icon(Icons.speed, size: 36, color: Colors.cyan),
              title: currentKm!['title'],
              description: currentKm!['description'],
              onTap: () => _showModal(
                current: currentKm,
                next: nextKm,
                value: totalKm,
                icon: const Icon(Icons.speed, size: 36, color: Colors.cyan),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
