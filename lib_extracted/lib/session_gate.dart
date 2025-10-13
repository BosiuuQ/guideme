import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guide_me/features/auth/presentation/views/login_view.dart';
import 'package:guide_me/features/map/presentation/widgets/main_map_widget.dart';
import 'package:guide_me/user_session_provider.dart';

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userSessionProvider);

    return user.when(
      data: (userData) {
        if (userData != null && userData.isNotEmpty) {
          return const MainMapWidget();
        } else {
          return const LoginView();
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(child: Text('Błąd ładowania sesji')),
    );
  }
}
