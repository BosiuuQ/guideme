
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterAuth {
  static Future<bool> registerUser({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      // Sprawdź, czy nickname jest już zajęty
      final existingNickname = await supabase
          .from('users')
          .select('id')
          .eq('nickname', nickname)
          .maybeSingle();

      if (existingNickname != null) {
        throw Exception("Ten nickname jest już zajęty.");
      }

      // Rejestracja użytkownika (auth.users)
      final signUpResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://prowadzmnie.pl/auth/callback',
      );

      final user = signUpResponse.user;

      if (user == null) {
        throw Exception("Rejestracja nie powiodła się.");
      }

      // Dodanie do tabeli users z pełnymi danymi
      await supabase.from('users').insert({
        'id': user.id,
        'nickname': nickname,
        'avatar': 'https://jrwplkznhqxxydtipwec.supabase.co/storage/v1/object/public/avatars/avatar.png',
        'account_lvl': 1,
        'guideme_points': 0,
        'kilomets_travel': 0,
        'created_at': DateTime.now().toIso8601String(),
        'description': '',
        'last_online': DateTime.now().toIso8601String(),
        'last_nickname_change': DateTime.now().toIso8601String(),
        'role': 'user',
        'rola': 'Uzytkownik',
        'fcm_token': null,
        'styl_mapy': 'ciemny',
        'map_visibility': null,
        'last_location': null,
      });

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
