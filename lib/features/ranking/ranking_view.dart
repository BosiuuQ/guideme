import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/ranking/ranking_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RankingView extends StatefulWidget {
  const RankingView({super.key});

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  String _selected = 'km';
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = Supabase.instance.client.auth.currentUser?.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        title: const Text("Ranking"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSelector(),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: RankingBackend.fetchRanking(_selected),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text("Brak danych", style: TextStyle(color: Colors.white70)),
                  );
                }

                final data = snapshot.data!;
                final top3 = data.take(3).toList();
                final rest = data.skip(3).toList();
                final currentIndex = data.indexWhere((item) => item['user_id'] == currentUserId);
                final currentUserItem = currentIndex >= 0 ? data[currentIndex] : null;

                final isClubRanking = _selected == 'clubs';

                return Column(
                  children: [
                    if (!isClubRanking)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(top3.length, (index) {
                          final item = top3[index];
                          return Column(
                            children: [
                              CircleAvatar(
                                backgroundImage: item['avatar'] != null
                                    ? NetworkImage(item['avatar'])
                                    : null,
                                backgroundColor: Colors.grey.shade800,
                                radius: 36,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['nickname'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _getStatText(item),
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              TextButton(
                                onPressed: () => context.pushNamed('userProfile', pathParameters: {
                                  'userId': item['user_id'],
                                }),
                                child: const Text("Zobacz profil", style: TextStyle(color: Colors.blueAccent)),
                              )
                            ],
                          );
                        }),
                      )
                    else
                      Column(
                        children: List.generate(top3.length, (index) {
                          final club = top3[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "#${index + 1} ${club['name']}",
                                  style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text("⭐ Śr. lvl: ${club['average_lvl']}", style: const TextStyle(color: Colors.white70)),
                                Text("🛣️ Śr. km: ${club['average_km']} km", style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          );
                        }),
                      ),

                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),

                    if (currentUserItem != null && currentIndex >= 3 && !isClubRanking)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: currentUserItem['avatar'] != null
                                  ? NetworkImage(currentUserItem['avatar'])
                                  : null,
                              backgroundColor: Colors.grey.shade800,
                            ),
                            title: Text(currentUserItem['nickname'], style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              _getStatText(currentUserItem),
                              style: const TextStyle(color: Colors.white60),
                            ),
                            trailing: Text("Twoje miejsce: #${currentIndex + 1}",
                                style: const TextStyle(color: Colors.white38)),
                            onTap: () => context.pushNamed('userProfile', pathParameters: {
                              'userId': currentUserItem['user_id'],
                            }),
                          ),
                        ),
                      ),

                    Expanded(
                      child: ListView.separated(
                        itemCount: rest.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemBuilder: (context, index) {
                          final item = rest[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: !isClubRanking
                                  ? CircleAvatar(
                                      backgroundImage: item['avatar'] != null
                                          ? NetworkImage(item['avatar'])
                                          : null,
                                      backgroundColor: Colors.grey.shade800,
                                    )
                                  : null,
                              title: Text(
                                isClubRanking ? item['name'] : item['nickname'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_getStatText(item), style: const TextStyle(color: Colors.white60)),
                                  if (!isClubRanking)
                                    TextButton(
                                      onPressed: () => context.pushNamed('userProfile', pathParameters: {
                                        'userId': item['user_id'],
                                      }),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                      child: const Text("Zobacz profil", style: TextStyle(color: Colors.blueAccent)),
                                    )
                                ],
                              ),
                              trailing: Text("#${index + 4}", style: const TextStyle(color: Colors.white38)),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getStatText(Map<String, dynamic> item) {
    switch (_selected) {
      case 'km':
        return "${item['total_km']} km przejechane";
      case 'lvl':
        return "Poziom ${item['account_lvl']}";
      case 'posts':
        return "${item['post_count']} postów";
      case 'clubs':
        return "⭐ ${item['average_lvl']} • 🛣️ ${item['average_km']} km";
      default:
        return "";
    }
  }

  Widget _buildSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSelectorButton('km', 'Kilometry'),
          _buildSelectorButton('lvl', 'Poziom'),
          _buildSelectorButton('posts', 'Posty IG'),
          _buildSelectorButton('clubs', 'Kluby'),
        ],
      ),
    );
  }

  Widget _buildSelectorButton(String value, String label) {
    final isSelected = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : Colors.white10,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
