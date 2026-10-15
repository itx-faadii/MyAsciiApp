/// SketchGlyph entry point.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/settings_providers.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolve preferences BEFORE the first frame so the persisted theme is
  // applied immediately (no white flash on cold start).
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final SettingsRepository repository = PrefsSettingsRepository(prefs);
  final AppSettings settings = await repository.load();
  runApp(
    ProviderScope(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const SketchGlyphApp(),
    ),
  );
}
