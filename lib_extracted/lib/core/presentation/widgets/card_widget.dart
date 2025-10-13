import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';

class CardWidget extends StatelessWidget {
  const CardWidget(
      {super.key, required this.child, this.padding, this.width, this.height});

  final Widget child;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Ink(
      padding: padding,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: AppColors.lightDarkBlueGradient,
      ),
      child: child,
    );
  }
}
