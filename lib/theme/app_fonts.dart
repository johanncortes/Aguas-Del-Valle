import 'package:flutter/material.dart';

/// Offline-first local font provider replacing the `google_fonts` network package.
///
/// Bundles local Inter (.ttf) assets from `assets/fonts/` so the app operates
/// 100% offline in rural areas without SocketException errors to fonts.gstatic.com.
class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    TextBaseline? textBaseline,
    FontStyle? fontStyle,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextOverflow? overflow,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      textBaseline: textBaseline,
      fontStyle: fontStyle,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      overflow: overflow,
    );
  }

  static TextStyle robotoMono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    TextBaseline? textBaseline,
    FontStyle? fontStyle,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextOverflow? overflow,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      textBaseline: textBaseline,
      fontStyle: fontStyle,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      overflow: overflow,
    );
  }

  static TextTheme interTextTheme([TextTheme? base]) {
    final textTheme = base ?? ThemeData.dark().textTheme;
    return textTheme.apply(fontFamily: 'Inter');
  }
}
