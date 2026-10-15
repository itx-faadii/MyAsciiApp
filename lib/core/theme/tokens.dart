/// SketchGlyph design tokens, exposed as [ThemeExtension]s so every screen can
/// read them from [Theme.of] instead of hard-coding values.
library;

import 'package:flutter/material.dart';

/// Spacing scale: 4 and 8 form the base rhythm.
class Spacing {
  const Spacing._();

  /// 4 logical pixels.
  static const double xs = 4;

  /// 8 logical pixels.
  static const double sm = 8;

  /// 12 logical pixels.
  static const double md = 12;

  /// 16 logical pixels.
  static const double lg = 16;

  /// 24 logical pixels.
  static const double xl = 24;

  /// 32 logical pixels.
  static const double xxl = 32;

  /// 48 logical pixels, the minimum comfortable tap target.
  static const double touch = 48;
}

/// Corner radii. Named `Radii` because [Radius] is already taken by the
/// framework.
class Radii {
  const Radii._();

  /// Small chips and badges.
  static const BorderRadius chip = BorderRadius.all(Radius.circular(999));

  /// Buttons and inputs.
  static const BorderRadius control = BorderRadius.all(Radius.circular(12));

  /// Cards.
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));

  /// Sheets and dialogs.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(24),
  );
}

/// Motion durations.
class Motion {
  const Motion._();

  /// Micro feedback such as a chip state change.
  static const Duration fast = Duration(milliseconds: 120);

  /// Most transitions.
  static const Duration normal = Duration(milliseconds: 220);

  /// Sheets, page transitions and theme cross-fades.
  static const Duration slow = Duration(milliseconds: 320);

  /// Curve used across the app.
  static const Curve curve = Curves.easeOutCubic;
}

/// Non-colour surface, outline and glow tokens.
@immutable
class SurfaceTokens extends ThemeExtension<SurfaceTokens> {
  /// Creates tokens.
  const SurfaceTokens({
    required this.surfaceHigh,
    required this.surfaceTop,
    required this.outline,
    required this.outlineStrong,
    required this.glow,
    required this.glassSigma,
    required this.useGlass,
    required this.paperDesk,
  });

  /// Elevated surface, one step above `colorScheme.surface`.
  final Color surfaceHigh;

  /// Highest surface, used for nav bars and dialogs.
  final Color surfaceTop;

  /// 1px hairline border colour.
  final Color outline;

  /// Border colour for selected or focused containers.
  final Color outlineStrong;

  /// Accent glow applied to selected cards.
  final Color glow;

  /// Blur sigma for glass surfaces.
  final double glassSigma;

  /// Whether glass effects are enabled at all.
  final bool useGlass;

  /// Dark "desk" behind sketch previews.
  final Color paperDesk;

  @override
  SurfaceTokens copyWith({
    Color? surfaceHigh,
    Color? surfaceTop,
    Color? outline,
    Color? outlineStrong,
    Color? glow,
    double? glassSigma,
    bool? useGlass,
    Color? paperDesk,
  }) => SurfaceTokens(
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    surfaceTop: surfaceTop ?? this.surfaceTop,
    outline: outline ?? this.outline,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    glow: glow ?? this.glow,
    glassSigma: glassSigma ?? this.glassSigma,
    useGlass: useGlass ?? this.useGlass,
    paperDesk: paperDesk ?? this.paperDesk,
  );

  @override
  SurfaceTokens lerp(covariant SurfaceTokens? other, double t) {
    if (other == null) return this;
    return SurfaceTokens(
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceTop: Color.lerp(surfaceTop, other.surfaceTop, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      glassSigma: glassSigma + (other.glassSigma - glassSigma) * t,
      useGlass: t < 0.5 ? useGlass : other.useGlass,
      paperDesk: Color.lerp(paperDesk, other.paperDesk, t)!,
    );
  }
}

/// Gradient and semantic colour tokens that Material's scheme cannot express.
@immutable
class AccentTokens extends ThemeExtension<AccentTokens> {
  /// Creates tokens.
  const AccentTokens({
    required this.secondary,
    required this.heroGradient,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.danger,
  });

  /// Secondary accent that pairs with [ColorScheme.primary].
  final Color secondary;

  /// Gradient reserved for hero elements only.
  final LinearGradient heroGradient;

  /// Secondary text colour.
  final Color textSecondary;

  /// Disabled text colour.
  final Color textDisabled;

  /// Positive feedback.
  final Color success;

  /// Cautionary feedback.
  final Color warning;

  /// Destructive feedback.
  final Color danger;

  @override
  AccentTokens copyWith({
    Color? secondary,
    LinearGradient? heroGradient,
    Color? textSecondary,
    Color? textDisabled,
    Color? success,
    Color? warning,
    Color? danger,
  }) => AccentTokens(
    secondary: secondary ?? this.secondary,
    heroGradient: heroGradient ?? this.heroGradient,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
  );

  @override
  AccentTokens lerp(covariant AccentTokens? other, double t) {
    if (other == null) return this;
    return AccentTokens(
      secondary: Color.lerp(secondary, other.secondary, t)!,
      heroGradient: LinearGradient(
        colors: <Color>[
          for (int i = 0; i < heroGradient.colors.length; i++)
            Color.lerp(
              heroGradient.colors[i],
              other.heroGradient.colors[i],
              t,
            )!,
        ],
        begin: heroGradient.begin,
        end: heroGradient.end,
      ),
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
