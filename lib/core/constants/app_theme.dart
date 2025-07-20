import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.darkBlue,
  iconTheme: const IconThemeData(
    color: AppColors.lightBlue,
    size: 24.0,
  ),
  cardTheme: const CardThemeData(
    margin: EdgeInsets.zero,
  ),
  colorScheme: ColorScheme.dark(
    onSurface: Colors.grey,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: AppColors.darkBlue,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkBlue,
    systemOverlayStyle: mySystemDarkTheme,
    surfaceTintColor: Colors.transparent,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: AppColors.darkBlue,
  ),
  textSelectionTheme: const TextSelectionThemeData(
    selectionHandleColor: AppColors.blue,
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(AppColors.blue),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    hintStyle: const TextStyle(color: AppColors.lightBlue),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
      ),
    ),
    fillColor: AppColors.lighterDarkBlue,
    filled: true,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: const BorderSide(
        color: AppColors.blue,
        width: 2.0,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 12.0,
      vertical: 6.0,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(AppColors.blue),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      overlayColor: WidgetStateProperty.resolveWith((state) {
        if (state.contains(WidgetState.pressed)) {
          return AppColors.darkBlue.withAlpha(60);
        }
        return AppColors.blue;
      }),
    ),
  ),
);

const mySystemDarkTheme = SystemUiOverlayStyle(
  systemNavigationBarColor: AppColors.darkBlue,
  systemNavigationBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  statusBarIconBrightness: Brightness.light,
  statusBarColor: Colors.black38,
);
