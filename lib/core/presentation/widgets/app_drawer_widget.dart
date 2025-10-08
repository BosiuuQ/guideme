import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/profile/presentation/widgets/drawer_profile_widget.dart';
import 'package:guide_me/features/paneladmin/paneladmin_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'drawer_tile_widget.dart';

class AppDrawerWidget extends StatefulWidget {
  const AppDrawerWidget({super.key});

  @override
  State<AppDrawerWidget> createState() => _AppDrawerWidgetState();
}

class _AppDrawerWidgetState extends State<AppDrawerWidget> {
  String? role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('users')
          .select('rola')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() => role = profile?['rola'] as String?);
    } catch (_) {
      // opcjonalnie: log/snackbar
    }
  }

  void _closeDrawer() {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop(); // zamknij Drawer
  }

  void _pushNamed(String routeName) {
    _closeDrawer();
    context.pushNamed(routeName); // dodaje do stosu -> „Wstecz” działa
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 24.0),
              child: DrawerProfileWidget(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    DrawerTileWidget(
                      title: "Profil",
                      icon: AppAssets.profileIcon,
                      onClick: () => _pushNamed(AppRoutes.profileView),
                    ),
                    DrawerTileWidget(
                      title: "Garaż",
                      icon: AppAssets.garageIcon,
                      onClick: () => _pushNamed(AppRoutes.garageView),
                    ),
                    DrawerTileWidget(
                      title: "InstaGuide",
                      icon: AppAssets.guideMeIcon,
                      onClick: () => _pushNamed(AppRoutes.instagramPosty),
                    ),
                    DrawerTileWidget(
                      title: "Rankingi",
                      icon: Icons.emoji_events,
                      onClick: () => _pushNamed(AppRoutes.rankingView),
                    ),
                    DrawerTileWidget(
                      title: "Sklep",
                      icon: Icons.store,
                      onClick: () => _pushNamed(AppRoutes.shopHomeView),
                    ),
                    DrawerTileWidget(
                      title: "Znajomi",
                      icon: AppAssets.friendsIcon,
                      onClick: () => _pushNamed(AppRoutes.znajomiView),
                    ),
                    if (role == 'Admin' || role == 'Ceo' || role == 'Mod')
                      DrawerTileWidget(
                        title: "Panel Moderatorski",
                        icon: Icons.group,
                        onClick: () {
                          _closeDrawer();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PanelAdminView()),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                "Wersja: Beta 0.2.0",
                style: TextStyle(
                  color: AppColors.lightBlue,
                  fontSize: 10.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
