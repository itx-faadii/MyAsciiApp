/// SketchGlyph theme builder: Light, Dark ("midnight studio") and AMOLED.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// User-selectable theme modes. [ThemeMode] cannot express AMOLED, so the app
/// owns its own enum and maps it to a [ThemeData].
enum AppThemeMode {
  /// Follow the platform setting.
  system,

  /// Light studio.
  light,

  /// Dark "midnight studio".
  dark,

  /// True-black AMOLED variant of dark.
  amoled,
}

/// Curated accent pairs (primary, secondary) offered in Settings.
class AccentPreset {
  const AccentPreset(this.id, this.primary, this.secondary);

  /// Stable identifier persisted in preferences.
  final String id;

  /// Primary accent.
  final Color primary;

  /// Secondary accent for gradients.
  final Color secondary;

  /// Built-in presets.
  static const List<AccentPreset> all = <AccentPreset>[
    AccentPreset('violet', Color(0xFF8B7CFF), Color(0xFF4CC9F0)),
    AccentPreset('cyan', Color(0xFF4CC9F0), Color(0xFF8B7CFF)),
    AccentPreset('amber', Color(0xFFFFB454), Color(0xFFFF7A59)),
    AccentPreset('green', Color(0xFF6EE7A8), Color(0xFF4CC9F0)),
    AccentPreset('rose', Color(0xFFFF7597), Color(0xFFB388FF)),
  ];

  /// Find a preset by [id], defaulting to the first entry.
  static AccentPreset byId(String id) =>
      all.firstWhere((AccentPreset p) => p.id == id, orElse: () => all.first);
}

/// Raw palette shared by the schemes; the contrast test iterates over these.
class Palette {
  const Palette._();

  /// Dark background.
  static const Color darkBackground = Color(0xFF0E1116);

  /// Dark surface.
  static const Color darkSurface = Color(0xFF151A21);

  /// Dark elevated surface.
  static const Color darkSurfaceHigh = Color(0xFF1C232C);

  /// Dark top surface.
  static const Color darkSurfaceTop = Color(0xFF242D38);

  /// Dark hairline outline.
  static const Color darkOutline = Color(0xFF2E3944);

  /// AMOLED background.
  static const Color amoledBackground = Color(0xFF000000);

  /// AMOLED surface.
  static const Color amoledSurface = Color(0xFF0A0C0F);

  /// AMOLED elevated surface.
  static const Color amoledSurfaceHigh = Color(0xFF11151A);

  /// AMOLED top surface.
  static const Color amoledSurfaceTop = Color(0xFF171D24);

  /// AMOLED outline (brighter than dark mode's).
  static const Color amoledOutline = Color(0xFF39454F);

  /// Primary text on dark surfaces.
  static const Color textPrimary = Color(0xFFE8ECF1);

  /// Secondary text on dark surfaces.
  static const Color textSecondary = Color(0xFF9AA7B5);

  /// Disabled text on dark surfaces.
  static const Color textDisabled = Color(0xFF5C6773);

  /// Light-mode background.
  static const Color lightBackground = Color(0xFFF6F8FB);

  /// Light-mode surface.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light-mode elevated surface.
  static const Color lightSurfaceHigh = Color(0xFFEEF1F6);

  /// Light-mode top surface.
  static const Color lightSurfaceTop = Color(0xFFE4E9F0);

  /// Light-mode outline.
  static const Color lightOutline = Color(0xFFCBD4DF);

  /// Primary text on light surfaces.
  static const Color lightTextPrimary = Color(0xFF12161B);

  /// Secondary text on light surfaces.
  static const Color lightTextSecondary = Color(0xFF51606F);

  /// Disabled text on light surfaces.
  static const Color lightTextDisabled = Color(0xFF8F9AA6);

  /// Dark desk behind sketch previews.
  static const Color paperDesk = Color(0xFF080B0F);
}

/// Builds the three app themes.
class AppTheme {
  const AppTheme._();

  /// Sans family used across the UI.
  static const String uiFont = 'Inter';

  /// Monospace family used for ASCII previews and code-like text.
  static const String monoFont = 'JetBrains Mono';

  /// The light theme.
  static ThemeData light(AccentPreset accent) =>
      _build(accent, Brightness.light);

  /// The dark "midnight studio" theme.
  static ThemeData dark(AccentPreset accent) => _build(accent, Brightness.dark);

  /// The AMOLED theme: dark chrome, pure-black canvas.
  static ThemeData amoled(AccentPreset accent) =>
      _build(accent, Brightness.dark, amoled: true);

  /// Resolve a [ThemeData] for a mode and accent.
  static ThemeData of(AppThemeMode mode, AccentPreset accent) {
    switch (mode) {
      case AppThemeMode.light:
        return light(accent);
      case AppThemeMode.dark:
        return dark(accent);
      case AppThemeMode.amoled:
        return amoled(accent);
      case AppThemeMode.system:
        final Brightness b = PlatformDispatcher.instance.platformBrightness;
        return b == Brightness.light ? light(accent) : dark(accent);
    }
  }

  static ThemeData _build(
    AccentPreset accent,
    Brightness brightness, {
    bool amoled = false,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final Color background = !isDark
        ? Palette.lightBackground
        : amoled
        ? Palette.amoledBackground
        : Palette.darkBackground;
    final Color surface = !isDark
        ? Palette.lightSurface
        : amoled
        ? Palette.amoledSurface
        : Palette.darkSurface;
    final Color surfaceHigh = !isDark
        ? Palette.lightSurfaceHigh
        : amoled
        ? Palette.amoledSurfaceHigh
        : Palette.darkSurfaceHigh;
    final Color surfaceTop = !isDark
        ? Palette.lightSurfaceTop
        : amoled
        ? Palette.amoledSurfaceTop
        : Palette.darkSurfaceTop;
    final Color outline = !isDark
        ? Palette.lightOutline
        : amoled
        ? Palette.amoledOutline
        : Palette.darkOutline;
    final Color textPrimary = isDark
        ? Palette.textPrimary
        : Palette.lightTextPrimary;
    final Color textSecondary = isDark
        ? Palette.textSecondary
        : Palette.lightTextSecondary;
    final Color textDisabled = isDark
        ? Palette.textDisabled
        : Palette.lightTextDisabled;

    final ColorScheme scheme = isDark
        ? ColorScheme.dark(
            primary: accent.primary,
            onPrimary: const Color(0xFF12101F),
            secondary: accent.secondary,
            onSecondary: const Color(0xFF08202A),
            surface: surface,
            onSurface: textPrimary,
            surfaceContainerHighest: surfaceHigh,
            surfaceContainerHigh: surfaceTop,
            onSurfaceVariant: textSecondary,
            outline: outline,
            outlineVariant: outline,
            error: const Color(0xFFFF6B6B),
            onError: const Color(0xFF2B0606),
            scrim: const Color(0xCC000000),
          )
        : ColorScheme.light(
            primary: _darkenForLightMode(accent.primary),
            onPrimary: Colors.white,
            secondary: _darkenForLightMode(accent.secondary),
            onSecondary: Colors.white,
            surface: surface,
            onSurface: textPrimary,
            surfaceContainerHighest: surfaceHigh,
            surfaceContainerHigh: surfaceTop,
            onSurfaceVariant: textSecondary,
            outline: outline,
            outlineVariant: outline,
            error: const Color(0xFFB3261E),
            onError: Colors.white,
          );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: uiFont,
      textTheme: _textTheme(scheme, textPrimary, textSecondary, textDisabled),
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge,
        systemOverlayStyle: isDark ? darkOverlayStyle : lightOverlayStyle,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surfaceTop,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.primary.withValues(alpha: 0.16),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? accent.primary : textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return base.textTheme.labelMedium!.copyWith(
            color: selected ? accent.primary : textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent.primary,
        inactiveTrackColor: surfaceHigh,
        trackHeight: 4,
        thumbColor: accent.primary,
        overlayColor: accent.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: accent.primary.withValues(alpha: 0.18),
        side: BorderSide(color: outline),
        labelStyle: base.textTheme.labelLarge!.copyWith(color: textPrimary),
        secondaryLabelStyle: base.textTheme.labelLarge!.copyWith(
          color: accent.primary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceTop,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: outline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceTop,
        contentTextStyle: base.textTheme.bodyMedium!.copyWith(
          color: textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.control),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? accent.primary.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? accent.primary
                : textSecondary,
          ),
          side: WidgetStatePropertyAll<BorderSide?>(BorderSide(color: outline)),
          shape: const WidgetStatePropertyAll<OutlinedBorder?>(
            RoundedRectangleBorder(borderRadius: Radii.control),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Spacing.touch),
          shape: const RoundedRectangleBorder(borderRadius: Radii.control),
          textStyle: base.textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Spacing.touch),
          side: BorderSide(color: outline),
          foregroundColor: textPrimary,
          shape: const RoundedRectangleBorder(borderRadius: Radii.control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent.primary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: base.textTheme.bodyMedium!.copyWith(color: textDisabled),
        border: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: accent.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent.primary,
        linearTrackColor: surfaceHigh,
        circularTrackColor: surfaceHigh,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceTop,
          borderRadius: Radii.chip,
          border: Border.all(color: outline),
        ),
        textStyle: base.textTheme.labelMedium!.copyWith(color: textPrimary),
      ),
      extensions: <ThemeExtension<dynamic>>[
        SurfaceTokens(
          surfaceHigh: surfaceHigh,
          surfaceTop: surfaceTop,
          outline: outline,
          outlineStrong: accent.primary,
          glow: accent.primary.withValues(alpha: isDark ? 0.35 : 0.22),
          glassSigma: isDark ? 16 : 12,
          useGlass: true,
          paperDesk: Palette.paperDesk,
        ),
        AccentTokens(
          secondary: accent.secondary,
          heroGradient: LinearGradient(
            colors: <Color>[accent.primary, accent.secondary],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          textSecondary: textSecondary,
          textDisabled: textDisabled,
          success: isDark ? const Color(0xFF6EE7A8) : const Color(0xFF17864A),
          warning: isDark ? const Color(0xFFFFB454) : const Color(0xFF9C5B00),
          danger: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFB3261E),
        ),
      ],
    );
  }

  static TextTheme _textTheme(
    ColorScheme scheme,
    Color primary,
    Color secondary,
    Color disabled,
  ) {
    return Typography.blackMountainView
        .apply(
          bodyColor: primary,
          displayColor: primary,
          decorationColor: scheme.primary,
        )
        .copyWith(
          displaySmall: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: primary,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: primary,
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primary,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: primary,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: primary,
          ),
          titleSmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: primary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: primary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: secondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: secondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primary,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.3,
            color: secondary,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.3,
            color: disabled,
          ),
        );
  }

  /// Accents chosen for dark mode are too light to sit under white text in
  /// light mode; step the lightness down until white text clears 4.5:1.
  static Color _darkenForLightMode(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final double saturation = hsl.saturation.clamp(0.45, 1.0);
    for (
      double lightness = hsl.lightness;
      lightness >= 0.10;
      lightness -= 0.02
    ) {
      final Color candidate = hsl
          .withLightness(lightness)
          .withSaturation(saturation)
          .toColor();
      if (candidate.computeLuminance() <= 0.1762) return candidate;
    }
    return hsl.withLightness(0.10).withSaturation(saturation).toColor();
  }
}

/// Overlay style for dark/AMOLED: light status & nav icons.
final SystemUiOverlayStyle darkOverlayStyle = SystemUiOverlayStyle.light
    .copyWith(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    );

/// Overlay style for light mode: dark status & nav icons.
final SystemUiOverlayStyle lightOverlayStyle = SystemUiOverlayStyle.dark
    .copyWith(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    );
