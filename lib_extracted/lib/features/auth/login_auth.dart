import 'package:supabase_flutter/supabase_flutter.dart';

class LoginAuth {
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Nieprawidłowe dane logowania");
      }

      // Sprawdzamy, czy użytkownik ma potwierdzony e-mail
      if (user.emailConfirmedAt == null) {
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

        throw Exception("Musisz potwierdzić e-mail przed logowaniem. Sprawdź swoją skrzynkę.");
      }

      if ((user.identities?.isEmpty ?? true)) {
        throw Exception("Musisz potwierdzić e-mail przed logowaniem");
      }

      final userId = user.id;

      final userResponse = await supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) {
        throw Exception("Nie znaleziono konta w bazie");
      }

      return userResponse as Map<String, dynamic>;
    } on AuthException catch (e) {
      if (e.message.contains("Invalid login credentials")) {
        throw Exception("Złe hasło");
      } else if (e.message.contains("User not found")) {
        throw Exception("Nie ma takiego konta");
      } else {
        throw Exception(e.message);
      }
    } catch (e) {
      throw Exception("Błąd logowania: $e");
    }
  }
}