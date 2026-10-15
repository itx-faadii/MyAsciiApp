/// Persistent, user-facing app settings (theme, accent, blur, onboarding).
library;

import '../../core/theme/app_theme.dart';

/// Immutable snapshot of everything the user can toggle outside a project.
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.accentId = 'violet',
    this.reduceBlur = false,
    this.onboardingSeen = false,
  });

  /// Which theme the user picked.
  final AppThemeMode themeMode;

  /// [AccentPreset.id] of the chosen accent.
  final String accentId;

  /// When true, glass/blur effects fall back to flat surfaces.
  final bool reduceBlur;

  /// Whether onboarding has been completed or skipped.
  final bool onboardingSeen;

  /// Resolved accent preset.
  AccentPreset get accent => AccentPreset.byId(accentId);

  /// Copy with replacements.
  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? accentId,
    bool? reduceBlur,
    bool? onboardingSeen,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentId: accentId ?? this.accentId,
      reduceBlur: reduceBlur ?? this.reduceBlur,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    );
  }
}
