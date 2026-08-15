import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,

    scaffoldBackgroundColor: AppColors.background,

    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
    ),

    // Space Grotesk para títulos (aire técnico, de "panel de control"),
    // Inter para texto de lectura — reemplaza la fuente por defecto.
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
        .copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
      headlineSmall: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.text,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    ),

    cardColor: AppColors.surface,

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withOpacity(.2),
    ),

    // Transición suave (deslizar) entre pantallas, igual en todas
    // las plataformas, en vez del efecto por defecto de Android
    // (que se siente más brusco).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}