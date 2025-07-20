import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/achievements/presentation/widgets/achievements_tab_widget.dart';
import 'package:guide_me/features/posts/presentation/widgets/user_posts_tab_widget.dart';
import 'package:guide_me/features/profile/presentation/widgets/profile_image_widget.dart';
import 'package:guide_me/features/profile/profile_backend.dart';
import 'package:guide_me/features/profile/user_search_delegate.dart';
import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:guide_me/features/viewpoint/presentation/widgets/viewpoint_card_widget.dart';
import 'package:guide_me/features/znajomi/znajomi_backend.dart';
import 'package:guide_me/features/garage/garage_backend.dart';
import 'package:guide_me/features/profile/profile_report_service.dart';
import 'package:guide_me/features/viewpoint/presentation/views/viewpoint_add_view.dart';
import 'package:guide_me/features/posts/post_add_view.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/profile/presentation/views/levelview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileView extends StatefulWidget {
  final String? userId;
  const ProfileView({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool isRequestSent = false;
  bool isLoadingRequestStatus = true;
  double currentKm = 0;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _checkFriendRequestStatus();
    }
    _loadDistance();
  }

  Future<void> _checkFriendRequestStatus() async {
    final result = await ZnajomiBackend.isFriendRequestSent(widget.userId!);
    setState(() {
      isRequestSent = result;
      isLoadingRequestStatus = false;
    });
  }

  Future<void> _loadDistance() async {
    final userId = widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final data = await Supabase.instance.client
        .from('user_distance')
        .select('total_km')
        .eq('user_id', userId)
        .maybeSingle();

    setState(() {
      currentKm = (data?['total_km'] ?? 0).toDouble();
    });
  }

  Future<void> _sendFriendRequest() async {
    await ZnajomiBackend.sendFriendRequest(widget.userId!);
    setState(() {
      isRequestSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Zaproszenie wysłane")),
    );
  }

  Future<void> _handleGarageAccess() async {
    final userId = widget.userId!;
    final status = await GarageBackend.getGarageStatusForUser(userId);

    if (status == 'zamkniety') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Garaż jest zamknięty")),
      );
      return;
    }

    if (status == 'dla_znajomych') {
      final isFriend = await ZnajomiBackend.areFriends(userId);
      if (!isFriend) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Garaż dostępny tylko dla znajomych")),
        );
        return;
      }
    }

    context.pushNamed('userGarage', extra: userId);
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == null;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.darkBlue,
        appBar: AppBar(
          backgroundColor: AppColors.darkBlue,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () {
                showSearch(context: context, delegate: UserSearchDelegate());
              },
              icon: const Icon(Icons.search_rounded, color: AppColors.superLightBlue),
            ),
            IconButton(
              onPressed: () {
                context.pushNamed(AppRoutes.settingsView);
              },
              icon: const Icon(Icons.settings, color: AppColors.superLightBlue),
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: ProfileBackend.getUserProfile(userId: widget.userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text("Błąd: \${snapshot.error}", style: const TextStyle(color: Colors.red)),
                      );
                    }

                    final data = snapshot.data!;
                    final nickname = data['nickname'] ?? "Brak nickname";
                    final description = data['description'] ?? "Brak opisu profilu";
                    final level = data['account_lvl']?.toString() ?? "0";
                    final avatarUrl = data['avatar'] ?? "";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                         Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => LevelView(
      currentLevel: int.tryParse(level) ?? 1,
    ),
  ),
);
                            },
                            child: SizedBox(
                              height: 100,
                              width: 100,
                              child: ProfileImageWidget(level: level, avatarUrl: avatarUrl),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nickname,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_view_rounded)),
                      Tab(icon: Icon(Icons.emoji_events_rounded, color: Colors.amber)),
                      Tab(icon: Icon(Icons.landscape_rounded)),
                    ],
                    dividerColor: Colors.transparent,
                    indicatorWeight: 2,
                    indicatorColor: AppColors.blue,
                    labelColor: AppColors.blue,
                    splashFactory: NoSplash.splashFactory,
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              UserPostsTabWidget(userId: widget.userId),
              const AchievementsTabWidget(),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ProfileBackend.getUserViewpoints(userId: widget.userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text("Błąd: \${snapshot.error}"));
                  final viewpoints = snapshot.data ?? [];
                  if (viewpoints.isEmpty) return const Center(child: Text("Brak punktów widokowych"));
                  return ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: viewpoints.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final data = viewpoints[index];
                      return ViewpointCardWidget(viewpoint: Viewpoint.fromMap(data));
                    },
                  );
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: isOwnProfile
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showReportDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.flag),
                        label: const Text("Zgłoś"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isLoadingRequestStatus
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: isRequestSent ? null : _sendFriendRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRequestSent ? Colors.grey : AppColors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(isRequestSent ? "Zaproszenie wysłane" : "Dodaj do znajomych"),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleGarageAccess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.directions_car),
                        label: const Text("Wejdź do garażu"),
                      ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: isOwnProfile
            ? FloatingActionButton(
                backgroundColor: AppColors.blue,
                onPressed: () => _showAddOptions(context),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_photo_alternate, color: Colors.white),
            title: const Text("Dodaj post IG", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              context.pushNamed(AppRoutes.postAddView);
            },
          ),
          ListTile(
            leading: const Icon(Icons.landscape_rounded, color: Colors.white),
            title: const Text("Dodaj punkt widokowy", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              context.pushNamed(AppRoutes.viewpointAddView);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final List<String> reasons = ['Spam', 'Obraźliwy profil', 'Fałszywe konto', 'Inne'];
    String? selectedReason;
    String customReason = '';

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text("Zgłoś profil", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...reasons.map((reason) {
                return RadioListTile<String>(
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (val) => setState(() => selectedReason = val),
                  activeColor: Colors.redAccent,
                  title: Text(reason, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              if (selectedReason == 'Inne')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    onChanged: (val) => customReason = val,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Wpisz powód...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Anuluj", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final reasonToSend = selectedReason == 'Inne' ? customReason.trim() : selectedReason;

                if (reasonToSend == null || reasonToSend.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wybierz powód zgłoszenia")));
                  return;
                }

                Navigator.pop(dialogContext);
                try {
                  await ProfileReportService.reportUser(widget.userId!, reasonToSend);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zgłoszenie wysłane")));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
                  );
                }
              },
              child: const Text("Zgłoś"),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.darkBlue, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) => false;
}
