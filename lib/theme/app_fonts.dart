import 'package:flutter/material.dart';

/// Text styles for the app. Uses the platform's system font (Roboto on
/// Android), which needs no bundled assets and reads well outdoors.
class AppFonts {
  AppFonts._();

  /// Regular UI text in the system font.
  static TextStyle text({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Monospaced text, e.g. coordinates.
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
