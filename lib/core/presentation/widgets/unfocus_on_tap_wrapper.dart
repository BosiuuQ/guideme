import 'package:flutter/material.dart';

class UnfocusOnTapWrapper extends StatelessWidget {
  final Widget child;

  const UnfocusOnTapWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: child,
    );
  }
}
