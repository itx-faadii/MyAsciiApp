/// SketchGlyph root widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/app_localizations.dart';
import 'core/providers/settings_providers.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';

/// MaterialApp.router wired to Riverpod theming. The theme is applied from the
/// settings controller synchronously (main() pre-resolves preferences), and
/// switches animate via [MaterialApp.themeAnimationDuration].
class SketchGlyphApp extends ConsumerWidget {
  /// Creates the app root.
  const SketchGlyphApp({super.key});

  /// Overlay style for dark backgrounds: light system icons.
  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// Overlay style for light backgrounds: dark system icons.
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final ThemeBundle bundle = ref.watch(themeBundleProvider);
    final GoRouter router = ref.watch(routerProvider);

    ThemeMode mode = ThemeMode.system;
    ThemeData darkTheme = bundle.dark;
    switch (settings.themeMode) {
      case AppThemeMode.system:
        mode = ThemeMode.system;
        darkTheme = bundle.dark;
      case AppThemeMode.light:
        mode = ThemeMode.light;
        darkTheme = bundle.dark;
      case AppThemeMode.dark:
        mode = ThemeMode.dark;
        darkTheme = bundle.dark;
      case AppThemeMode.amoled:
        mode = ThemeMode.dark;
        darkTheme = bundle.amoled;
    }

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: bundle.light,
      darkTheme: darkTheme,
      themeMode: mode,
      themeAnimationDuration: Motion.slow,
      themeAnimationCurve: Motion.curve,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appName,
      builder: (BuildContext context, Widget? child) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final SurfaceTokens tokens = Theme.of(context)
            .extension<SurfaceTokens>()!;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark ? darkOverlay : lightOverlay,
          child: MediaQuery.withClampedTextScaling(
            // Support up to 200% text scaling without breaking layouts.
            minScaleFactor: 0.8,
            maxScaleFactor: 2.0,
            child: _ReduceBlurOverride(
              enabled: settings.reduceBlur,
              tokens: tokens,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

/// Re-stamps [SurfaceTokens.useGlass] off when the user (or the OS) asks for
/// reduced transparency, so every glass widget falls back without rebuilding
/// the whole theme.
class _ReduceBlurOverride extends StatelessWidget {
  const _ReduceBlurOverride({
    required this.enabled,
    required this.tokens,
    required this.child,
  });

  final bool enabled;
  final SurfaceTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          tokens.copyWith(useGlass: false, glassSigma: 0),
          theme.extension<AccentTokens>()!,
        ],
      ),
      child: child,
    );
  }
}
