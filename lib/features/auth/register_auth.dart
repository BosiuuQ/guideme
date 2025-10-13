import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterAuth {
  static Future<bool> registerUser({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      // 1) check nickname uniqueness
      final existingNickname = await supabase
          .from('users')
          .select('id')
          .eq('nickname', nickname)
          .maybeSingle();

      if (existingNickname != null) {
        throw Exception("Ten nickname jest już zajęty.");
      }

      // 2) sign up
      final signUpResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = signUpResponse.user;
      if (user == null) {
        throw Exception("Rejestracja nie powiodła się.");
      }

      // 3) WAIT until trigger created public.users record
      const int maxAttempts = 12;
      const Duration delayBetween = Duration(milliseconds: 700);
      bool profileExists = false;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final profile = await supabase
            .from('users')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          profileExists = true;
          break;
        }
        await Future.delayed(delayBetween);
      }
      if (!profileExists) {
        throw Exception(
            "Profil użytkownika nie pojawił się w bazie (public.users). Spróbuj ponownie później.");
      }

      // 4) re-check nickname (avoid race) then UPDATE profile
      final conflict = await supabase
          .from('users')
          .select('id')
          .eq('nickname', nickname)
          .neq('id', user.id)
          .maybeSingle();
      if (conflict != null) {
        throw Exception("Ten nickname został zajęty w międzyczasie. Wybierz inny.");
      }

      await supabase.from('users').update({
        'nickname': nickname,
        'avatar': 'https://jrwplkznhqxxydtipwec.supabase.co/storage/v1/object/public/avatars/ikonkaa.png',
        'last_online': DateTime.now().toIso8601String(),
        'last_nickname_change': DateTime.now().toIso8601String(),
        'role': 'user',
        'rola': 'Uzytkownik',
        'styl_mapy': 'ciemny',
      }).eq('id', user.id);

      return true;
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        throw Exception("Ten e-mail jest już zajęty.");
      } else {
        throw Exception("Błąd: ${e.message}");
      }
    } catch (e) {
      throw Exception("Błąd rejestracji: ${e.toString().replaceAll('Exception: ', '')}");
    }
  }
}
