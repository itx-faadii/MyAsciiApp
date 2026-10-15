/// Phase 1 exit gate: every text/background token pair must reach WCAG AA
/// (4.5:1) in Light, Dark and AMOLED, for every accent preset.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sketchglyph/core/theme/app_theme.dart';

/// WCAG 2.1 contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('contrast (>= 4.5:1)', () {
    for (final AccentPreset accent in AccentPreset.all) {
      test('accent ${accent.id} passes in every theme', () {
        final List<ThemeData> themes = <ThemeData>[
          AppTheme.light(accent),
          AppTheme.dark(accent),
          AppTheme.amoled(accent),
        ];

        for (final ThemeData theme in themes) {
          final Color bg = theme.scaffoldBackgroundColor;
          final Color surface = theme.cardColor;
          final Color primary = theme.textTheme.bodyLarge!.color!;
          final Color secondary = theme.textTheme.bodyMedium!.color!;
          final Color onPrimary = theme.colorScheme.onPrimary;
          final Color primaryColor = theme.colorScheme.primary;

          expect(
            contrastRatio(primary, bg),
            greaterThanOrEqualTo(4.5),
            reason:
                'primary text on background (${theme.brightness}, '
                '${accent.id})',
          );
          expect(
            contrastRatio(primary, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'primary text on surface (${theme.brightness})',
          );
          expect(
            contrastRatio(secondary, bg),
            greaterThanOrEqualTo(4.5),
            reason: 'secondary text on background (${theme.brightness})',
          );
          expect(
            contrastRatio(secondary, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'secondary text on surface (${theme.brightness})',
          );
          expect(
            contrastRatio(onPrimary, primaryColor),
            greaterThanOrEqualTo(4.5),
            reason: 'onPrimary text on primary fill (${theme.brightness})',
          );
        }
      });
    }

    test('disabled text keeps 3:1 (non-essential labels only)', () {
      expect(
        contrastRatio(Palette.textDisabled, Palette.darkBackground),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('dark text is never pure white', () {
      expect(Palette.textPrimary, isNot(const Color(0xFFFFFFFF)));
    });
  });
}
