import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,

    scaffoldBackgroundColor: AppColors.background,

    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
    ),

    cardColor: AppColors.surface,

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withOpacity(.2),
    ),
  );
}