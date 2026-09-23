import 'package:flutter/material.dart';
import 'app_fonts.dart';

/// Light, high-contrast palette for outdoor use in direct sunlight.
/// Every color used for text meets WCAG AA (≥ 4.5:1) on white and on the
/// 20% tints used behind status badges.
class AppTheme {
  // Brand colors — Aguas del Valle blue tones
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF1557A8);
  static const Color accentCyan = Color(0xFF006064);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF1F5F9);
  static const Color surfaceVariant = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF455A64);

  // Status (text-safe on white; also used as pin fills)
  static const Color successGreen = Color(0xFF1B5E20);
  static const Color warningAmber = Color(0xFF805300);
  static const Color errorRed = Color(0xFFB71C1C);
  static const Color pendingRed = Color(0xFFB71C1C);
  static const Color visitedGreen = Color(0xFF1B5E20);
  static const Color noReadingOrange = Color(0xFFA34100);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: accentCyan,
        surface: background,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppFonts.text(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentCyan,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppFonts.text(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        // Visible field outline: borderless fills disappear in sunlight
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: textSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: textSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentCyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: AppFonts.text(color: textSecondary),
        hintStyle: AppFonts.text(color: textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        // Dark SnackBars stand out over the light UI
        backgroundColor: textPrimary,
        contentTextStyle: AppFonts.text(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
