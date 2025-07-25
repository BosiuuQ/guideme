import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/guide_me.dart';
import 'package:intl/intl.dart';
import 'dart:io'; // ← potrzebne do sprawdzania platformy

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientacja
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // EasyLocalization
  await EasyLocalization.ensureInitialized();
  Intl.defaultLocale = 'pl';

  // Status bar + bottom bar
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
  );

  // Supabase
  await Supabase.initialize(
    url: 'https://jrwplkznhqxxydtipwec.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impyd3Bsa3puaHF4eHlkdGlwd2VjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0OTQ1NTIsImV4cCI6MjA1ODA3MDU1Mn0.yqQqEI3SZcoxqFSAtQ0dXFVsq6aTv5Z-HD43s2lcH0k',
  );

  // NIE UŻYWAJ reauthenticate() — powoduje wysyłkę maili
  // Supabase sam utrzymuje sesję przy włączonym persistSession

  // SharedPreferences
  await SharedPreferences.getInstance();

  // Uruchomienie aplikacji
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
