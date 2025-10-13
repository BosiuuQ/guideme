import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guide_me/features/auth/auth_session.dart';

/// Provider dostarczający aktualnie zalogowanego użytkownika
/// z lokalnej sesji (SharedPreferences).
final userSessionProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return await AuthSession.getUser();
});
