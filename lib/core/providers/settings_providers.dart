/// Riverpod providers for app-wide settings and theming.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Overridden in `main` with the SharedPreferences-backed repository (resolved
/// before the first frame) or an in-memory fake in tests.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) {
      throw UnimplementedError('settingsRepositoryProvider must be overridden');
    });

/// Pre-loaded settings, overridden in `main` (and tests) after the repository
/// resolves them, so the first frame is already themed with the saved values.
final Provider<AppSettings> initialSettingsProvider = Provider<AppSettings>(
  (Ref ref) => const AppSettings(),
);

/// Holds the live settings and writes changes back to the repository.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  /// Set the theme mode.
  void setThemeMode(AppThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  /// Set the accent by [AccentPreset.id].
  void setAccent(String accentId) =>
      _update(state.copyWith(accentId: accentId));

  /// Toggle blur/transparency reduction.
  void setReduceBlur(bool value) => _update(state.copyWith(reduceBlur: value));

  /// Mark onboarding complete (or skipped).
  void setOnboardingSeen(bool value) =>
      _update(state.copyWith(onboardingSeen: value));

  void _update(AppSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).save(next);
  }
}

final NotifierProvider<SettingsController, AppSettings>
settingsControllerProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// The three [ThemeData]s for the current accent, kept stable so cross-fades
/// can animate between them.
class ThemeBundle {
  /// Creates a bundle.
  const ThemeBundle({
    required this.light,
    required this.dark,
    required this.amoled,
    required this.mode,
  });

  /// Light theme.
  final ThemeData light;

  /// Dark theme.
  final ThemeData dark;

  /// AMOLED theme.
  final ThemeData amoled;

  /// The user's selected mode.
  final AppThemeMode mode;
}

final Provider<ThemeBundle> themeBundleProvider = Provider<ThemeBundle>((
  Ref ref,
) {
  final AppSettings settings = ref.watch(settingsControllerProvider);
  final AccentPreset accent = settings.accent;
  ThemeData applyBlur(ThemeData theme) {
    if (!settings.reduceBlur) return theme;
    final SurfaceTokens tokens = theme.extension<SurfaceTokens>()!;
    return theme.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        tokens.copyWith(useGlass: false, glassSigma: 0),
        theme.extension<AccentTokens>()!,
      ],
    );
  }

  return ThemeBundle(
    light: applyBlur(AppTheme.light(accent)),
    dark: applyBlur(AppTheme.dark(accent)),
    amoled: applyBlur(AppTheme.amoled(accent)),
    mode: settings.themeMode,
  );
});
