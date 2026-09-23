import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aguas_monte_patria/theme/app_theme.dart';
import 'package:aguas_monte_patria/theme/visit_status_style.dart';
import 'package:aguas_monte_patria/models/client_meter_record.dart';

/// WCAG 2 contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// [color] at [alpha] over white, like the badge backgrounds.
Color _tint(Color color, double alpha) =>
    Color.alphaBlend(color.withValues(alpha: alpha), Colors.white);

void main() {
  const white = AppTheme.background;

  test('the app uses a light theme', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.background, Colors.white);
  });

  test('text colors meet WCAG AA (4.5:1) on white and light surfaces', () {
    for (final text in [AppTheme.textPrimary, AppTheme.textSecondary]) {
      for (final bg in [white, AppTheme.surface, AppTheme.surfaceVariant]) {
        expect(_contrast(text, bg), greaterThanOrEqualTo(4.5),
            reason: '$text on $bg');
      }
    }
  });

  test('status and accent colors are readable as text on white and on '
      'their 20% badge tint', () {
    final colors = {
      'pending': VisitStatus.pending.color,
      'read': VisitStatus.read.color,
      'noReading': VisitStatus.noReading.color,
      'warningAmber': AppTheme.warningAmber,
      'errorRed': AppTheme.errorRed,
      'accentCyan': AppTheme.accentCyan,
      'primaryLight': AppTheme.primaryLight,
    };
    colors.forEach((name, color) {
      expect(_contrast(color, white), greaterThanOrEqualTo(4.5), reason: name);
      expect(_contrast(color, _tint(color, 0.2)), greaterThanOrEqualTo(4.5),
          reason: '$name on its tint');
      // White icons/text on filled pins and buttons
      expect(_contrast(Colors.white, color), greaterThanOrEqualTo(4.5),
          reason: 'white on $name');
    });
  });
}
