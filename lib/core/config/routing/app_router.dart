import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/config/routing/router_transition.dart';
import 'package:guide_me/core/config/routing/router_transition_type.dart';
import 'package:guide_me/core/config/routing/auth_refresh_notifier.dart';

import 'package:guide_me/features/map/mapa/route_planner_view.dart';


import 'package:guide_me/core/presentation/views/main_view.dart';
import 'package:guide_me/core/presentation/views/scalable_image_view.dart';

import 'package:guide_me/features/achievements/presentation/views/achievement_details_view.dart';
import 'package:guide_me/features/auth/presentation/views/login_view.dart';
import 'package:guide_me/features/auth/presentation/views/register_view.dart';
import 'package:guide_me/features/auth/presentation/views/reset_password_view.dart';
import 'package:guide_me/features/auth/presentation/views/RegulationsView.dart';

import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/presentation/views/add_new_vehicle_view.dart';
import 'package:guide_me/features/garage/presentation/views/garage_view.dart';
import 'package:guide_me/features/garage/presentation/views/vehicle_details_view.dart';
import 'package:guide_me/features/garage/user_garage_view.dart';

import 'package:guide_me/features/posts/presentation/views/post_details_view.dart';
import 'package:guide_me/features/posts/post_add_view.dart';

import 'package:guide_me/features/profile/presentation/views/profile_view.dart';
import 'package:guide_me/features/settings/presentation/views/settings_view.dart';

import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:guide_me/features/viewpoint/presentation/views/viewpoint_add_view.dart';
import 'package:guide_me/features/viewpoint/presentation/views/viewpoint_details_view.dart';
import 'package:guide_me/features/viewpoint/presentation/views/viewpoint_view.dart';

import 'package:guide_me/features/znajomi/presentation/views/chat_view.dart';
import 'package:guide_me/features/znajomi/presentation/views/znajomi_view.dart';
import 'package:guide_me/features/znajomi/presentation/views/search_user_view.dart';

import 'package:guide_me/features/posts/instagram_posty.dart';
import 'package:guide_me/features/ranking/ranking_view.dart';

import 'package:guide_me/features/clubs/clubs_home_view.dart' as clubs_home;
import 'package:guide_me/features/clubs/clubs_list_view.dart';
import 'package:guide_me/features/clubs/create_club_view.dart';
import 'package:guide_me/features/clubs/my_club_view.dart' as my_club;
import 'package:guide_me/features/clubs/club_details_view.dart';
import 'package:guide_me/features/clubs/edit_club_view.dart';
import 'package:guide_me/features/clubs/invite_to_club_view.dart';

import 'package:guide_me/features/shop/shop_home_view.dart';
import 'package:guide_me/features/znajomi/PremiumChatView.dart';

import 'package:guide_me/features/spoty/spot_add_view.dart';


final routerProvider = Provider((ref) => _router);

final GoRouter _router = GoRouter(
  initialLocation: AppRoutes.mainView,
  refreshListenable: AuthRefreshNotifier(),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final path = state.uri.path;

    final isAuthFlow = path == AppRoutes.loginView ||
        path == AppRoutes.registerView;

    if (session == null && !isAuthFlow) {
      return AppRoutes.loginView;
    }

    if (session != null && path == AppRoutes.loginView) {
      return AppRoutes.mainView;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.loginView,
      name: AppRoutes.loginView,
      pageBuilder: (context, state) => const NoTransitionPage(child: LoginView()),
    ),
    GoRoute(
      path: AppRoutes.registerView,
      name: AppRoutes.registerView,
      pageBuilder: (context, state) => const NoTransitionPage(child: RegisterView()),
    ),
GoRoute(
  path: AppRoutes.viewpointAddView, // "/viewpointAddView"
  name: 'viewpointAddView',         // ← Uwaga! Tylko identyfikator – bez slasha!
  pageBuilder: (context, state) => const NoTransitionPage(child: ViewpointAddView()),
),
    GoRoute(
      path: AppRoutes.regulationsView,
      name: AppRoutes.regulationsView,
      pageBuilder: (context, state) => const NoTransitionPage(child: RegulationsView()),
    ),
    GoRoute(
      path: '/reset-password',
      name: 'resetPassword',
      pageBuilder: (context, state) => const NoTransitionPage(child: ResetPasswordView()),
    ),
    GoRoute(
      path: '/user-garage',
      name: 'userGarage',
      builder: (context, state) {
        final userId = state.extra as String;
        return UserGarageView(userId: userId);
      },
    ),
    GoRoute(
      path: '/premium-chat',
      name: AppRoutes.premiumChat,
      pageBuilder: (context, state) => const NoTransitionPage(child: PremiumChatView()),
    ),
    GoRoute(
      path: '/search-user',
      name: AppRoutes.searchUser,
      pageBuilder: (context, state) => const NoTransitionPage(child: SearchUserView()),
    ),
    GoRoute(
      name: AppRoutes.shopHomeView,
      path: '/shop',
      builder: (context, state) => const ShopHomeView(),
    ),
    GoRoute(
  path: '/route-planner',
  name: 'routePlanner',
  builder: (context, state) {
    final extra = state.extra;

    if (extra is! Map<String, dynamic>) {
      return const Scaffold(body: Center(child: Text("❌ Brak danych nawigacji")));
    }

    final start = extra['start'];
    final end = extra['end'];
    final destinationName = extra['destinationName'];

    if (start is! LatLng || end is! LatLng || destinationName is! String) {
      return const Scaffold(body: Center(child: Text("❌ Niepoprawne dane trasy")));
    }

    return RoutePlannerView(
      start: start,
      end: end,
      destinationName: destinationName,
    );
  },
),
    GoRoute(
      path: AppRoutes.mainView,
      name: AppRoutes.mainView,
      pageBuilder: (context, state) => RouterTransition.getTransitionPage(
        context: context,
        state: state,
        child: const MainView(),
      ),
      
      routes: [
        GoRoute(
          path: AppRoutes.garageView,
          name: AppRoutes.garageView,
          pageBuilder: (context, state) => RouterTransition.getTransitionPage(
            context: context,
            state: state,
            transitionType: RouterTransitionType.FADE,
            child: const GarageView(),
          ),
          
          routes: [
GoRoute(
  path: '/vehicle-details',
  name: AppRoutes.vehicleDetailsView,
  builder: (context, state) {
    final vehicle = state.extra;
    if (vehicle is Vehicle) {
      return VehicleDetailsView(vehicle: vehicle);
    } else {
      return const Scaffold(
        body: Center(
          child: Text(
            '❌ Brak danych pojazdu',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  },
),
                GoRoute(
              path: AppRoutes.addNewVehicleView,
              name: AppRoutes.addNewVehicleView,
              pageBuilder: (context, state) => RouterTransition.getTransitionPage(
                context: context,
                state: state,
                transitionType: RouterTransitionType.FADE,
                child: const AddNewVehicleView(),
              ),
            ),
          ],
        ),
        
        GoRoute(
          path: AppRoutes.viewpointView,
          name: AppRoutes.viewpointView,
          pageBuilder: (context, state) => RouterTransition.getTransitionPage(
            context: context,
            state: state,
            transitionType: RouterTransitionType.FADE,
            child: const ViewpointView(),
          ),
        ),
        GoRoute(
          path: AppRoutes.instagramPosty,
          name: AppRoutes.instagramPosty,
          pageBuilder: (context, state) => const NoTransitionPage(child: InstagramPostyView()),
        ),
        GoRoute(
          path: AppRoutes.profileView,
          name: AppRoutes.profileView,
          pageBuilder: (context, state) => const NoTransitionPage(child: ProfileView()),
        ),
        GoRoute(
          path: '/profile/:userId',
          name: 'userProfile',
          pageBuilder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return NoTransitionPage(child: ProfileView(userId: userId));
          },
        ),
        GoRoute(
          path: AppRoutes.settingsView,
          name: AppRoutes.settingsView,
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsView()),
        ),
        GoRoute(
          path: AppRoutes.imageView,
          name: AppRoutes.imageView,
          pageBuilder: (context, state) {
            final image = state.extra as String;
            return NoTransitionPage(child: ScalableImageView(image: image));
          },
        ),
        GoRoute(
          path: AppRoutes.achievementsDetailsView,
          name: AppRoutes.achievementsDetailsView,
          pageBuilder: (context, state) => const NoTransitionPage(child: AchievementDetailsView()),
        ),
        GoRoute(
          name: AppRoutes.postDetailsView,
          path: '/post-details',
          pageBuilder: (context, state) {
            final postData = state.extra as Map<String, dynamic>;
            return NoTransitionPage(child: PostDetailsView(postData: postData));
          },
        ),
        GoRoute(
          name: AppRoutes.postAddView,
          path: '/post-add',
          pageBuilder: (context, state) => const NoTransitionPage(child: PostAddView()),
        ),
        GoRoute(
          path: AppRoutes.znajomiView,
          name: AppRoutes.znajomiView,
          pageBuilder: (context, state) => const NoTransitionPage(child: ZnajomiView()),
        ),
        GoRoute(
          path: '/ranking',
          name: AppRoutes.rankingView,
          builder: (context, state) => const RankingView(),
        ),
        GoRoute(
          path: AppRoutes.chatView,
          name: AppRoutes.chatView,
          pageBuilder: (context, state) {
            final extras = state.extra as Map<String, String>;
            final friendId = extras['friendId']!;
            final friendNickname = extras['friendNickname']!;
            return NoTransitionPage(child: ChatView(friendId: friendId, friendNickname: friendNickname));
          },
        ),
      ],
    ),
    GoRoute(
      path: '/clubs',
      name: AppRoutes.clubsHome,
      pageBuilder: (context, state) => RouterTransition.getTransitionPage(
        context: context,
        state: state,
        transitionType: RouterTransitionType.FADE,
        child: const clubs_home.ClubsHomeView(),
      ),
    ),
    GoRoute(
      path: '/clubs/list',
      name: AppRoutes.clubsList,
      pageBuilder: (context, state) => RouterTransition.getTransitionPage(
        context: context,
        state: state,
        transitionType: RouterTransitionType.FADE,
        child: const ClubsListView(),
      ),
    ),
    GoRoute(
      path: '/club-edit',
      name: 'club-edit',
      builder: (context, state) {
        final club = state.extra as Map<String, dynamic>;
        return EditClubView(club: club);
      },
    ),
    GoRoute(
      path: '/clubs/invite',
      name: 'club-invite',
      builder: (context, state) {
        final clubId = state.extra as String;
        return InviteToClubView(clubId: clubId);
      },
    ),
    GoRoute(
      path: '/clubs/create',
      name: AppRoutes.createClub,
      pageBuilder: (context, state) => RouterTransition.getTransitionPage(
        context: context,
        state: state,
        transitionType: RouterTransitionType.FADE,
        child: const CreateClubView(),
      ),
    ),
    GoRoute(
      path: '/clubs/my',
      name: AppRoutes.myClub,
      pageBuilder: (context, state) => RouterTransition.getTransitionPage(
        context: context,
        state: state,
        child: const my_club.MyClubView(),
      ),
    ),
    GoRoute(
      path: '/clubs/details',
      builder: (context, state) {
        final club = state.extra as Map<String, dynamic>;
        return ClubDetailsView(club: club);
      },
    ),
    GoRoute(
      name: AppRoutes.viewpointDetailsView,
      path: '/viewpoint-details',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! Viewpoint) {
          return const Scaffold(
            body: Center(
              child: Text(
                '❌ Brak danych Viewpoint',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        return ViewpointDetailsView(viewpoint: extra);
      },
    ),
  ],
);
