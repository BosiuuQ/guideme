import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/profile/presentation/widgets/drawer_profile_widget.dart';
import 'package:guide_me/features/paneladmin/paneladmin_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Supabase import
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
    final supabase = Supabase.instance.client; // ✅ Poprawne użycie
    final user = supabase.auth.currentUser;
    if (user != null) {
      final profile = await supabase
          .from('users')
          .select('rola')
          .eq('id', user.id)
          .single();

      setState(() {
        role = profile['rola'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.7,
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
                      onClick: () => context.pushNamed(AppRoutes.profileView),
                    ),
                    DrawerTileWidget(
                      title: "Garaż",
                      icon: AppAssets.garageIcon,
                      onClick: () => context.pushNamed(AppRoutes.garageView),
                    ),
                    DrawerTileWidget(
                      title: "InstaGuide",
                      icon: AppAssets.guideMeIcon,
                      onClick: () => context.pushNamed(AppRoutes.instagramPosty),
                    ),
                    DrawerTileWidget(
                      title: "Rankingi",
                      icon: Icons.emoji_events,
                      onClick: () => context.pushNamed(AppRoutes.rankingView),
                    ),
                    DrawerTileWidget(
                      title: "Sklep",
                      icon: Icons.store,
                      onClick: () => context.goNamed(AppRoutes.shopHomeView),
                    ),
                    DrawerTileWidget(
                      title: "Znajomi",
                      icon: AppAssets.friendsIcon,
                      onClick: () => context.pushNamed(AppRoutes.znajomiView),
                    ),
                    if (role == 'Admin' || role == 'Ceo' || role == 'Mod')
                      DrawerTileWidget(
                        title: "Panel Moderatorski",
                        icon: Icons.group,
                        onClick: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PanelAdminView(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                "Wersja Beta : 0.4.0",
                style: TextStyle(
                  color: AppColors.lightBlue,
                  fontSize: 10.0,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
