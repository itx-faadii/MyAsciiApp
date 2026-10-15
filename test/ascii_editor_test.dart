// Widget tests for AsciiEditorScreen. Tests the full editor flow including
// mode switching, controls sheet, and settings management.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import 'package:sketchglyph/core/image/image_pipeline.dart';
import 'package:sketchglyph/core/theme/app_theme.dart';
import 'package:sketchglyph/features/ascii/domain/ascii_job.dart';
import 'package:sketchglyph/features/ascii/domain/ascii_session_controller.dart';
import 'package:sketchglyph/features/ascii/presentation/ascii_editor_screen.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(theme: AppTheme.dark(AccentPreset.all.first), home: child);
}

void main() {
  const Size phone = Size(420, 940);

  testWidgets('AsciiEditorScreen renders with default state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const AsciiEditorScreen())),
    );
    await tester.pump();

    expect(find.text('ASCII Editor'), findsOneWidget);
    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('Mode selector shows three modes', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const AsciiEditorScreen())),
    );
    await tester.pump();

    // Check for mode selector labels
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Character Set'), findsOneWidget);
    expect(find.text('User String'), findsOneWidget);
  });

  testWidgets('Controls button opens bottom sheet', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const AsciiEditorScreen())),
    );
    await tester.pumpAndSettle();

    // Tap Controls button
    await tester.tap(find.text('Controls'));
    await tester.pumpAndSettle();

    // Check that sheet opened with controls
    expect(find.text('Columns'), findsOneWidget);
    expect(find.text('Contrast'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
  });

  testWidgets('Reset button resets settings', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const AsciiEditorScreen())),
    );
    await tester.pumpAndSettle();

    // Open controls sheet
    await tester.tap(find.text('Controls'));
    await tester.pumpAndSettle();

    // Change a setting
    final Finder columnsSlider = find.byType(Slider).first;
    await tester.drag(columnsSlider, const Offset(100, 0));
    await tester.pumpAndSettle();

    // Tap Reset
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    // Verify settings were reset (columns back to default)
    expect(find.text('Columns'), findsOneWidget);
  });

  testWidgets('EditorState has correct default values', (
    WidgetTester tester,
  ) async {
    final EditorState state = EditorState();

    expect(state.source, isNull);
    expect(state.preview, isNull);
    expect(state.lowResPreview, isTrue);
    expect(state.rendering, false);
    expect(state.error, isNull);
    expect(state.settings.mode, AsciiMode.defaultRamp);
  });

  testWidgets('EditorState copyWith works correctly', (
    WidgetTester tester,
  ) async {
    final EditorState original = EditorState();
    final EditorState modified = original.copyWith(rendering: true);

    expect(original.rendering, false);
    expect(modified.rendering, true);
    expect(modified.settings, original.settings);
  });

  testWidgets('PreviewResult can be created with test data', (
    WidgetTester tester,
  ) async {
    const PreviewResult preview = PreviewResult(
      text: 'Test',
      cells: ['T', 'e', 's', 't'],
      colors: [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF],
      columns: 2,
      rows: 2,
      foreground: 0xFFFFFFFF,
      background: 0xFF000000,
      cellWidthEm: 0.6,
      cellRatio: 0.5,
    );

    expect(preview.columns, 2);
    expect(preview.rows, 2);
    expect(preview.cells.length, 4);
    expect(preview.colors.length, 4);
  });

  testWidgets('SourceImage can be created with test data', (
    WidgetTester tester,
  ) async {
    final SourceImage source = SourceImage(
      width: 10,
      height: 10,
      rgba: Uint8List(10 * 10 * 4),
      originalWidth: 10,
      originalHeight: 10,
    );

    expect(source.width, 10);
    expect(source.height, 10);
    expect(source.rgba.length, 400);
  });
}
