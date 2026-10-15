import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sketchglyph/core/image/image_pipeline.dart';
import 'package:sketchglyph/core/theme/app_theme.dart';
import 'package:sketchglyph/features/sketch/domain/sketch_session_controller.dart';
import 'package:sketchglyph/features/sketch/presentation/controls/style_carousel.dart';
import 'package:sketchglyph/features/sketch/presentation/sketch_editor_screen.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(theme: AppTheme.dark(AccentPreset.all.first), home: child);
}

SourceImage _createTestSource({int width = 60, int height = 40}) {
  final img.Image image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int gray = ((x + y) % 256).toInt();
      image.setPixelRgba(x, y, gray, gray, gray, 255);
    }
  }
  final img.Image rgba = image.convert(numChannels: 4);
  return SourceImage(
    width: rgba.width,
    height: rgba.height,
    rgba: rgba.getBytes(order: img.ChannelOrder.rgba),
    originalWidth: rgba.width,
    originalHeight: rgba.height,
  );
}

void main() {
  const Size phone = Size(420, 940);

  // The sketch render runs in a real isolate, which fake-async pumps cannot
  // await. Fire the fake debounce timer, then let the isolate finish inside
  // runAsync with a bounded wall-clock wait.
  Future<void> settleRender(
    WidgetTester tester,
    SketchEditorController controller,
  ) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() async {
      final DateTime start = DateTime.now();
      while (controller.state.render == null &&
          controller.state.error == null &&
          DateTime.now().difference(start) < const Duration(seconds: 30)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
  }

  SketchEditorController controllerOf(WidgetTester tester) {
    final BuildContext context = tester.element(
      find.byType(SketchEditorScreen),
    );
    return ProviderScope.containerOf(context)
        .read(sketchEditorControllerProvider.notifier);
  }

  // Open the fine-tune sheet with fixed pumps: pumpAndSettle would hang on
  // the shimmer's repeating animation once a render is in flight.
  Future<void> openFineTuneSheet(WidgetTester tester) async {
    await tester.tap(find.text('Fine-tune'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('SketchEditorScreen shows empty state when no source', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const SketchEditorScreen())),
    );
    await tester.pump();

    expect(find.text('Sketch'), findsOneWidget);
    expect(find.text('No sketch yet'), findsOneWidget);
    expect(find.text('Import an image to start sketching'), findsOneWidget);
  });

  testWidgets('SketchEditorScreen shows render after source is set', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const SketchEditorScreen())),
    );
    await tester.pump();

    final SketchEditorController controller = controllerOf(tester);
    final SourceImage source = _createTestSource();
    controller.setSource(source);

    await settleRender(tester, controller);

    expect(controller.state.error, isNull);
    expect(controller.state.render, isNotNull);
    // Should now show the render
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Fine-tune sheet opens and shows Paper section', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const SketchEditorScreen())),
    );
    await tester.pump();

    // Set a source to enable the Fine-tune button
    final BuildContext context = tester.element(
      find.byType(SketchEditorScreen),
    );
    final ProviderContainer container = ProviderScope.containerOf(context);
    final SketchEditorController controller = container.read(
      sketchEditorControllerProvider.notifier,
    );
    controller.setSource(_createTestSource());
    await tester.pump();

    // Tap Fine-tune button
    await tester.tap(find.text('Fine-tune'));
    // Wait for bottom sheet animation (avoid pumpAndSettle due to shimmer)
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));

    // Check that sheet opened with Paper section
    expect(find.text('Paper'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Ink'), findsOneWidget);
  });

  testWidgets('Tapping a style card updates state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const SketchEditorScreen())),
    );
    await tester.pump();

    final SketchEditorController controller = controllerOf(tester);
    controller.setSource(_createTestSource());
    await tester.pump();

    await openFineTuneSheet(tester);

    // The carousel is horizontal and only a few cards are on screen.
    final Finder charcoalLabel = find.text('Charcoal');
    await tester.scrollUntilVisible(
      charcoalLabel,
      200,
      scrollable: find.descendant(
        of: find.byType(StyleCarousel),
        matching: find.byType(Scrollable),
      ),
    );
    expect(charcoalLabel, findsOneWidget);

    await tester.tap(charcoalLabel);
    await tester.pump();

    expect(controller.state.settings.style, SketchStyle.charcoal);

    // Flush the debounced re-render so no timer stays pending.
    await settleRender(tester, controller);
  });

  testWidgets('Seed randomize button changes seed', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(child: _wrapWithTheme(const SketchEditorScreen())),
    );
    await tester.pump();

    final SketchEditorController controller = controllerOf(tester);
    controller.setSource(_createTestSource());
    await tester.pump();

    await openFineTuneSheet(tester);

    final int initialSeed = controller.state.settings.seed;
    final Finder refreshIcon = find.byIcon(Icons.refresh);
    // The seed row sits below the fold of the sheet's lazy ListView.
    // `.first` is the outer sheet list (the carousel is nested deeper).
    final Finder sheetScrollable = find
        .descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      refreshIcon,
      300,
      scrollable: sheetScrollable,
    );
    expect(refreshIcon, findsOneWidget);

    await tester.tap(refreshIcon);
    await tester.pump();

    expect(controller.state.settings.seed, isNot(equals(initialSeed)));
    // The seed exposed by the state must follow the settings seed.
    expect(controller.state.seed, controller.state.settings.seed);

    // Flush the debounced re-render so no timer stays pending.
    await settleRender(tester, controller);
  });

  testWidgets('SketchEditorState has correct default values', (
    WidgetTester tester,
  ) async {
    final SketchEditorState state = SketchEditorState();

    expect(state.source, isNull);
    expect(state.render, isNull);
    expect(state.rendering, false);
    expect(state.error, isNull);
    expect(state.seed, 1);
    expect(state.settings.style, SketchStyle.graphite2b);
  });

  testWidgets('SketchEditorState copyWith works correctly', (
    WidgetTester tester,
  ) async {
    final SketchEditorState original = SketchEditorState();
    final SketchEditorState modified = original.copyWith(rendering: true);

    expect(original.rendering, false);
    expect(modified.rendering, true);
    expect(modified.settings, original.settings);
  });
}
