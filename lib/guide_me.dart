// ✅ guide_me.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guide_me/core/config/routing/app_router.dart';
import 'package:guide_me/core/constants/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/auth/last_online_updater.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class GuideMe extends ConsumerStatefulWidget {
  const GuideMe({super.key});

  @override
  ConsumerState<GuideMe> createState() => _GuideMeState();
}

class _GuideMeState extends ConsumerState<GuideMe> with WidgetsBindingObserver {
  final LastOnlineUpdater _lastOnlineUpdater = LastOnlineUpdater();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _lastOnlineUpdater.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lastOnlineUpdater.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _lastOnlineUpdater.stop();
      print("⏸️ Aktualizacja last_online zatrzymana – aplikacja w tle lub zamykana.");
    } else if (state == AppLifecycleState.resumed) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        try {
          await Supabase.instance.client.auth.reauthenticate();
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            _lastOnlineUpdater.start();
            print("✅ Użytkownik zalogowany – wznowiono last_online i sesję.");
          } else {
            print("❌ Brak zalogowanego użytkownika po reautoryzacji.");
          }
        } catch (e) {
          print("⚠️ Błąd podczas reautoryzacji: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.read(routerProvider);

    return MaterialApp(
      title: 'GuideMe',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorObservers: [routeObserver],
      builder: (context, child) => child!,
      home: Router(
        routerDelegate: router.routerDelegate,
        routeInformationParser: router.routeInformationParser,
        routeInformationProvider: router.routeInformationProvider,
        backButtonDispatcher: RootBackButtonDispatcher(), // ← najważniejsze!
      ),
    );
  }
}
