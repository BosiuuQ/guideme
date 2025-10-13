import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop(); // wraca do poprzedniego ekranu
          return false; // NIE zamykaj aplikacji
        }
        return false; // zapobiega zamykaniu
      },
      child: child,
    );
  }
}
