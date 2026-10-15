/// App-shell smoke tests: routing, theme switching, onboarding redirect.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sketchglyph/app.dart';
import 'package:sketchglyph/core/providers/settings_providers.dart';
import 'package:sketchglyph/core/settings/app_settings.dart';
import 'package:sketchglyph/core/settings/settings_repository.dart';
import 'package:sketchglyph/core/theme/app_theme.dart';
import 'package:sketchglyph/shared/widgets/app_shell.dart';

Widget _harness(SettingsRepository repo, AppSettings initial) {
  return ProviderScope(
    overrides: <Override>[
      settingsRepositoryProvider.overrideWithValue(repo),
      initialSettingsProvider.overrideWithValue(initial),
    ],
    child: const SketchGlyphApp(),
  );
}

void main() {
  const Size phone = Size(420, 940);

  testWidgets('skips onboarding when already seen and lands on Home', (
    WidgetTester tester,
  ) async {
    final InMemorySettingsRepository repo = InMemorySettingsRepository();
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(repo, const AppSettings(onboardingSeen: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turn photos into art'), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('forces onboarding on first run and skip persists', (
    WidgetTester tester,
  ) async {
    final InMemorySettingsRepository repo = InMemorySettingsRepository();
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(repo, const AppSettings()));
    await tester.pumpAndSettle();

    expect(find.text('One tap art'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Turn photos into art'), findsOneWidget);
    final AppSettings saved = await repo.load();
    expect(saved.onboardingSeen, isTrue);
  });

  testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
    final InMemorySettingsRepository repo = InMemorySettingsRepository();
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(repo, const AppSettings(onboardingSeen: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Gallery').last);
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);

    await tester.tap(find.text('Create').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose an image'), findsAtLeastNWidgets(1));
  });

  testWidgets('theme mode change is applied and persisted', (
    WidgetTester tester,
  ) async {
    final InMemorySettingsRepository repo = InMemorySettingsRepository();
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(repo, const AppSettings(onboardingSeen: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    // The compact live-preview card for Light mode.
    await tester.tap(find.bySemanticsLabel('Light').first);
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('Appearance'));
    expect(Theme.of(context).brightness, Brightness.light);

    final AppSettings saved = await repo.load();
    expect(saved.themeMode, AppThemeMode.light);
  });

  testWidgets('renders the navigation bar with four destinations', (
    WidgetTester tester,
  ) async {
    final InMemorySettingsRepository repo = InMemorySettingsRepository();
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(repo, const AppSettings(onboardingSeen: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });
}
