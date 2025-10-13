import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class LastOnlineUpdater {
  Timer? _timer;
  final Duration updateInterval;

  LastOnlineUpdater({this.updateInterval = const Duration(seconds: 30)});

  void start() {
    _timer?.cancel();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print("❌ Brak zalogowanego użytkownika");
      return;
    }

    _timer = Timer.periodic(updateInterval, (timer) async {
      try {
        final nowIso = DateTime.now().toUtc().toIso8601String();

        await Supabase.instance.client
            .from('users')
            .update({'last_online': nowIso})
            .eq('id', user.id);

        print("✅ last_online zaktualizowany: $nowIso");
      } catch (e) {
        print("❌ Wyjątek podczas aktualizacji last_online: $e");
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    print("🛑 Zatrzymano aktualizację last_online");
  }
}
