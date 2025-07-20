import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router_transition_type.dart';

class RouterTransition {
  static CustomTransitionPage getTransitionPage({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    RouterTransitionType? transitionType,
  }) {
    return CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          switch (transitionType) {
            case RouterTransitionType.FADE:
              return FadeTransition(opacity: animation, child: child);
            case RouterTransitionType.ROTATE:
              return RotationTransition(turns: animation, child: child);
            case RouterTransitionType.SIZE:
              return SizeTransition(sizeFactor: animation, child: child);
            case RouterTransitionType.SCALE:
              return ScaleTransition(scale: animation, child: child);
            default:
              return FadeTransition(opacity: animation, child: child);
          }
        });
  }
}
