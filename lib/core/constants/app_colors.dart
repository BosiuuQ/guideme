import 'package:flutter/material.dart';

class AppColors {
  static const Color darkBlue = Color(0xFF0D1B2A);
  static const Color lighterDarkBlue = Color(0xFF1B263B);
  static const Color lightBlue = Color(0xFF778DA9);
  static const Color superLightBlue = Color(0xFFB3CDE0);
  static const Color blue = Color(0xff0e8bd6);

  static const LinearGradient lightDarkBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4F5871),
      AppColors.lighterDarkBlue,
    ],
  );
}
