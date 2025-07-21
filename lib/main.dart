import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/guide_me.dart';
import 'package:intl/intl.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await EasyLocalization.ensureInitialized();
  Intl.defaultLocale = 'pl';

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
  );

  await Supabase.initialize(
    url: 'https://jrwplkznhqxxydtipwec.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impyd3Bsa3puaHF4eHlkdGlwd2VjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0OTQ1NTIsImV4cCI6MjA1ODA3MDU1Mn0.yqQqEI3SZcoxqFSAtQ0dXFVsq6aTv5Z-HD43s2lcH0k',
  );

  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    try {
      await Supabase.instance.client.auth.reauthenticate();
    } catch (e) {
      print("⚠️ Błąd reautoryzacji: $e");
    }
  }

  await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('pl', 'PL')],
        path: 'assets/translations',
        fallbackLocale: const Locale('pl', 'PL'),
        startLocale: const Locale('pl', 'PL'),
        child: const GuideMe(),
      ),
    ),
  );
}
