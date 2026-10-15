// Widget tests for AsciiPreview. Uses domain PreviewResult.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sketchglyph/core/theme/app_theme.dart';
import 'package:sketchglyph/features/ascii/domain/ascii_job.dart';
import 'package:sketchglyph/features/ascii/presentation/ascii_preview.dart';

PreviewResult _fakePreview({int columns = 20, int rows = 10}) {
  final List<String> cells = List<String>.generate(
    columns * rows,
    (int i) => (i % 2 == 0) ? '█' : '.',
  );
  final List<int> colors = List<int>.filled(columns * rows, 0xFFE8ECF1);
  return PreviewResult(
    text: cells.join(),
    cells: cells,
    colors: colors,
    columns: columns,
    rows: rows,
    foreground: 0xFFE8ECF1,
    background: 0xFF0E1116,
    cellWidthEm: 0.6,
    cellRatio: 0.5,
  );
}

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(AccentPreset.all.first),
    home: Scaffold(body: child),
  );
}

void main() {
  const Size phone = Size(420, 940);

  testWidgets('AsciiPreview renders CustomPaint with a preview', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapWithTheme(
        AsciiPreview(
          preview: _fakePreview(),
          interactive: false,
          fontSizePx: 10,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(AsciiPreview), findsOneWidget);
  });

  testWidgets('AsciiPreview wraps in InteractiveViewer when interactive', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapWithTheme(AsciiPreview(preview: _fakePreview(), interactive: true)),
    );
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('AsciiPreview skips InteractiveViewer when not interactive', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapWithTheme(AsciiPreview(preview: _fakePreview(), interactive: false)),
    );
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('PreviewResult intrinsic size is sane', (
    WidgetTester tester,
  ) async {
    final PreviewResult preview = _fakePreview(columns: 20, rows: 10);
    expect(preview.columns, 20);
    expect(preview.rows, 10);
    expect(preview.cells.length, 200);
    expect(preview.colors.length, 200);
  });

  testWidgets('ShimmerSkeleton renders while loading', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrapWithTheme(const ShimmerSkeleton(height: 200)));
    await tester.pump();

    expect(find.byType(ShimmerSkeleton), findsOneWidget);
  });
}
