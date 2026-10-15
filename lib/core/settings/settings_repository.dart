/// Settings persistence. Local-only: backed by SharedPreferences.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import 'app_settings.dart';

/// Storage abstraction so tests can inject an in-memory fake.
abstract class SettingsRepository {
  /// Load the last saved settings, or defaults.
  Future<AppSettings> load();

  /// Persist [settings].
  Future<void> save(AppSettings settings);
}

/// SharedPreferences-backed repository.
class PrefsSettingsRepository implements SettingsRepository {
  /// Creates with an already-resolved instance (resolved in `main` before the
  /// first frame so the theme applies with no white flash).
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _kThemeMode = 'theme_mode';
  static const String _kAccent = 'accent_id';
  static const String _kReduceBlur = 'reduce_blur';
  static const String _kOnboarding = 'onboarding_seen';

  @override
  Future<AppSettings> load() async {
    final String modeName = _prefs.getString(_kThemeMode) ?? 'system';
    final AppThemeMode mode = AppThemeMode.values.firstWhere(
      (AppThemeMode m) => m.name == modeName,
      orElse: () => AppThemeMode.system,
    );
    return AppSettings(
      themeMode: mode,
      accentId: _prefs.getString(_kAccent) ?? 'violet',
      reduceBlur: _prefs.getBool(_kReduceBlur) ?? false,
      onboardingSeen: _prefs.getBool(_kOnboarding) ?? false,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_kThemeMode, settings.themeMode.name);
    await _prefs.setString(_kAccent, settings.accentId);
    await _prefs.setBool(_kReduceBlur, settings.reduceBlur);
    await _prefs.setBool(_kOnboarding, settings.onboardingSeen);
  }
}

/// In-memory repository for tests and previews.
class InMemorySettingsRepository implements SettingsRepository {
  /// Creates with optional initial [settings].
  InMemorySettingsRepository([AppSettings? settings])
    : _current = settings ?? const AppSettings();

  AppSettings _current;

  @override
  Future<AppSettings> load() async => _current;

  @override
  Future<void> save(AppSettings settings) async => _current = settings;
}
