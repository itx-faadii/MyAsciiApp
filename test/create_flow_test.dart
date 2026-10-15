/// Phase 6: create-flow tests — session model, undo/redo, batch queue,
/// overlay spec, and the widget-level pick -> decode -> type -> editor flow.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sketchglyph/app.dart';
import 'package:sketchglyph/core/image/image_pipeline.dart';
import 'package:sketchglyph/core/providers/settings_providers.dart';
import 'package:sketchglyph/core/router/app_router.dart';
import 'package:sketchglyph/core/settings/app_settings.dart';
import 'package:sketchglyph/core/settings/settings_repository.dart';
import 'package:sketchglyph/core/theme/app_theme.dart';
import 'package:sketchglyph/features/ascii/domain/ascii_session_controller.dart';
import 'package:sketchglyph/features/ascii/presentation/ascii_editor_screen.dart';
import 'package:sketchglyph/features/create/data/source_picker.dart';
import 'package:sketchglyph/features/create/domain/batch_queue.dart';
import 'package:sketchglyph/features/create/domain/create_session.dart';
import 'package:sketchglyph/features/create/domain/create_session_controller.dart';
import 'package:sketchglyph/features/create/domain/create_types.dart';
import 'package:sketchglyph/features/create/domain/editor_launcher.dart';
import 'package:sketchglyph/features/create/domain/overlay_spec.dart';
import 'package:sketchglyph/features/create/presentation/transform_screen.dart';
import 'package:sketchglyph/features/create/presentation/type_screen.dart';
import 'package:sketchglyph/features/home/presentation/home_screen.dart';
import 'package:sketchglyph/features/sketch/domain/sketch_session_controller.dart';
import 'package:sketchglyph/features/sketch/presentation/sketch_editor_screen.dart';

/// Scriptable fake picker: per-origin canned responses and call counters.
class _FakePicker implements SourcePicker {
  _FakePicker({this.galleryResult});

  PickedImage? galleryResult;
  PickedImage? cameraResult;
  PickedImage? fileResult;
  Object? galleryError;

  int galleryCalls = 0;
  int cameraCalls = 0;
  int fileCalls = 0;

  @override
  Future<PickedImage?> pickFromGallery() async {
    galleryCalls++;
    if (galleryError != null) throw galleryError!;
    return galleryResult;
  }

  @override
  Future<PickedImage?> pickFromCamera() async {
    cameraCalls++;
    return cameraResult;
  }

  @override
  Future<PickedImage?> pickFromFile() async {
    fileCalls++;
    return fileResult;
  }
}

/// Recording fake launcher for the TypeScreen contract test.
class _RecordingLauncher implements EditorLauncher {
  final List<CreateTarget> opened = <CreateTarget>[];
  final List<SourceImage> sources = <SourceImage>[];

  @override
  Future<void> openAscii(WidgetRef ref, SourceImage source) async {
    opened.add(CreateTarget.ascii);
    sources.add(source);
  }

  @override
  Future<void> openSketch(WidgetRef ref, SourceImage source) async {
    opened.add(CreateTarget.sketch);
    sources.add(source);
  }
}

/// 60x40 gradient PNG bytes.
Uint8List _pngBytes({int width = 60, int height = 40}) {
  final img.Image image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int v = width > 1 ? (x * 255 ~/ (width - 1)).clamp(0, 255) : 0;
      image.setPixelRgba(x, y, v, v, v, 255);
    }
  }
  return img.encodePng(image);
}

PickedImage _picked({int width = 60, int height = 40, String name = 'shot'}) {
  return PickedImage(
    bytes: _pngBytes(width: width, height: height),
    origin: SourceOrigin.gallery,
    name: name,
  );
}

/// A small synthetic SourceImage (no isolate needed) for session tests.
SourceImage _makeSource({int width = 8, int height = 8}) {
  return SourceImage(
    width: width,
    height: height,
    rgba: Uint8List(width * height * 4),
    originalWidth: width,
    originalHeight: height,
  );
}

/// Overrides that make the real app bootable in a test: in-memory settings,
/// onboarding skipped, fake picker.
List<Override> _appOverrides(SourcePicker picker) => <Override>[
  settingsRepositoryProvider.overrideWithValue(InMemorySettingsRepository()),
  initialSettingsProvider.overrideWithValue(
    const AppSettings(onboardingSeen: true),
  ),
  sourcePickerProvider.overrideWithValue(picker),
];

/// Waits for a condition driven by real-isolate async work.
///
/// A single long runAsync never completes: the isolate's result is delivered
/// into the fake-async zone, whose microtasks only run when the tree is
/// pumped. So interleave short real waits with pumps until the condition
/// holds.
Future<void> _waitFor(
  WidgetTester tester,
  bool Function() done, {
  int seconds = 60,
}) async {
  final DateTime start = DateTime.now();
  while (!done()) {
    if (DateTime.now().difference(start) > Duration(seconds: seconds)) {
      throw TestFailure('Timed out after ${seconds}s waiting for condition');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Fixed pumps (never pumpAndSettle on screens with shimmer/repeat
/// animations) to settle route transitions and post-async continuations.
Future<void> _pumpFor(WidgetTester tester, {int count = 8}) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  const Size phone = Size(420, 940);

  group('CreateSession', () {
    test('empty session has no data and no step', () {
      expect(CreateSession.empty.picked, isNull);
      expect(CreateSession.empty.source, isNull);
      expect(CreateSession.empty.target, isNull);
      expect(CreateSession.empty.currentStep, isNull);
      expect(CreateSession.empty.historyIndex, -1);
      expect(CreateSession.empty.overlay.enabled, isFalse);
    });

    test('copyWith preserves fields and clears selectively', () {
      final PickedImage picked = _picked();
      final CreateSession s1 = CreateSession(picked: picked);
      final CreateSession s2 = s1.copyWith(target: CreateTarget.ascii);
      expect(s2.picked, picked);
      expect(s2.target, CreateTarget.ascii);
      final CreateSession s3 = s2.copyWith(clearPicked: true);
      expect(s3.picked, isNull);
      expect(s3.target, CreateTarget.ascii);
    });

    test('currentStep follows historyIndex', () {
      const CreateSession s = CreateSession(
        history: <CreateStep>[CreateStep.pickSource, CreateStep.decode],
        historyIndex: 1,
      );
      expect(s.currentStep, CreateStep.decode);
      const CreateSession oob = CreateSession(
        history: <CreateStep>[CreateStep.pickSource],
        historyIndex: 5,
      );
      expect(oob.currentStep, isNull);
    });
  });

  group('CreateSessionController', () {
    late ProviderContainer container;
    late CreateSessionController ctrl;

    setUp(() {
      container = ProviderContainer(overrides: _appOverrides(_FakePicker()));
      addTearDown(container.dispose);
      ctrl = container.read(createSessionProvider.notifier);
    });

    test('initial state is empty', () {
      expect(container.read(createSessionProvider), CreateSession.empty);
    });

    test('setPicked records the step and allows undo back to empty', () {
      final PickedImage picked = _picked();
      ctrl.setPicked(picked);
      final CreateSession s = container.read(createSessionProvider);
      expect(s.picked, picked);
      expect(s.history, <CreateStep>[CreateStep.pickSource]);
      expect(s.historyIndex, 0);
      expect(ctrl.canUndo, isTrue);
      ctrl.undo();
      expect(container.read(createSessionProvider).picked, isNull);
      expect(ctrl.canRedo, isTrue);
      ctrl.redo();
      expect(container.read(createSessionProvider).picked, picked);
    });

    test('setSource then chooseTarget append steps', () {
      final SourceImage source = _makeSource();
      ctrl.setPicked(_picked());
      ctrl.setSource(source);
      expect(ctrl.canUndo, isTrue);
      ctrl.chooseTarget(CreateTarget.sketch);
      final CreateSession s = container.read(createSessionProvider);
      expect(s.history, <CreateStep>[
        CreateStep.pickSource,
        CreateStep.decode,
        CreateStep.chooseTarget,
      ]);
      expect(s.historyIndex, 2);
      expect(s.currentStep, CreateStep.chooseTarget);
      expect(s.target, CreateTarget.sketch);
    });

    test('updateSource replaces without pushing history', () {
      final SourceImage a = _makeSource();
      final SourceImage b = _makeSource(width: 4, height: 4);
      ctrl.setPicked(_picked());
      ctrl.setSource(a);
      final int len = container.read(createSessionProvider).history.length;
      ctrl.updateSource(b);
      final CreateSession s = container.read(createSessionProvider);
      expect(s.source, same(b));
      expect(s.history.length, len);
    });

    test('setOverlay does not push history', () {
      ctrl.setPicked(_picked());
      final int len = container.read(createSessionProvider).history.length;
      ctrl.setOverlay(const OverlaySpec(enabled: true, caption: 'hi'));
      expect(container.read(createSessionProvider).overlay.caption, 'hi');
      expect(container.read(createSessionProvider).history.length, len);
    });

    test('undo walks back through full snapshots, redo walks forward', () {
      final PickedImage picked = _picked();
      final SourceImage source = _makeSource();
      ctrl.setPicked(picked);
      ctrl.setSource(source);
      ctrl.chooseTarget(CreateTarget.ascii);

      // One undo moves back exactly one step.
      ctrl.undo();
      expect(ctrl.canRedo, isTrue);
      expect(container.read(createSessionProvider).target, isNull);
      expect(container.read(createSessionProvider).source, same(source));
      expect(container.read(createSessionProvider).picked, picked);

      ctrl.undo();
      expect(container.read(createSessionProvider).source, isNull);
      expect(container.read(createSessionProvider).picked, picked);

      // A third undo returns to the empty session before any pick.
      ctrl.undo();
      expect(container.read(createSessionProvider), CreateSession.empty);
      expect(ctrl.canUndo, isFalse);
      ctrl.undo(); // no-op at the boundary

      ctrl.redo();
      expect(container.read(createSessionProvider).picked, picked);
      ctrl.redo();
      expect(container.read(createSessionProvider).source, same(source));
      ctrl.redo();
      expect(container.read(createSessionProvider).target, CreateTarget.ascii);
      expect(ctrl.canRedo, isFalse);
    });

    test('a mid-branch push drops the redo future', () {
      ctrl.setPicked(_picked());
      ctrl.setSource(_makeSource());
      ctrl.chooseTarget(CreateTarget.ascii);
      ctrl.undo();
      ctrl.undo();
      ctrl.chooseTarget(CreateTarget.sketch);
      expect(ctrl.canRedo, isFalse);
      expect(container.read(createSessionProvider).target, CreateTarget.sketch);
      expect(container.read(createSessionProvider).picked, isNotNull);
    });

    test('clear wipes session and history', () {
      ctrl.setPicked(_picked());
      ctrl.clear();
      expect(container.read(createSessionProvider), CreateSession.empty);
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });
  });

  group('OverlaySpec', () {
    test('defaults are disabled, bottom-right, full opacity', () {
      const OverlaySpec o = OverlaySpec();
      expect(o.enabled, isFalse);
      expect(o.position, OverlayPosition.bottomRight);
      expect(o.opacity, 1.0);
      expect(o.caption, isNull);
      expect(o.watermark, isNull);
    });

    test('json round trip preserves every field', () {
      const OverlaySpec o = OverlaySpec(
        caption: 'Sunset',
        watermark: 'sketchglyph',
        position: OverlayPosition.topLeft,
        opacity: 0.4,
        enabled: true,
      );
      expect(OverlaySpec.fromJsonString(o.toJsonString()), o);
    });

    test('invalid json falls back to the default spec', () {
      expect(OverlaySpec.fromJsonString('not json'), const OverlaySpec());
      expect(OverlaySpec.fromJsonString('{}'), isA<OverlaySpec>());
    });

    test('copyWith clears caption and watermark independently', () {
      const OverlaySpec o = OverlaySpec(caption: 'a', watermark: 'b');
      expect(o.copyWith(clearCaption: true).caption, isNull);
      expect(o.copyWith(clearCaption: true).watermark, 'b');
      expect(o.copyWith(clearWatermark: true).caption, 'a');
      expect(o.copyWith(enabled: true).enabled, isTrue);
    });
  });

  group('BatchQueue', () {
    test('runs items through the processor in order', () async {
      final BatchQueue queue = BatchQueue();
      queue.add(_picked(name: 'a'));
      queue.add(_picked(name: 'b'));
      final List<String> seen = <String>[];
      await queue.run((PickedImage p, void Function(double) _) async {
        seen.add(p.name!);
        return _makeSource();
      });
      expect(seen, <String>['a', 'b']);
      expect(
        queue.items.map((BatchItem i) => i.status).toList(),
        <BatchItemStatus>[BatchItemStatus.done, BatchItemStatus.done],
      );
      expect(queue.items.first.source, isNotNull);
      expect(queue.isRunning, isFalse);
    });

    test(
      'progress callback updates item state, final progress is 1.0',
      () async {
        final BatchQueue queue = BatchQueue();
        queue.add(_picked());
        final List<double> updates = <double>[];
        await queue.run((
          PickedImage p,
          void Function(double) onProgress,
        ) async {
          onProgress(0.5);
          updates.add(queue.items.single.progress);
          return _makeSource();
        });
        expect(updates, <double>[0.5]);
        expect(queue.items.single.progress, 1.0);
      },
    );

    test('ImagePipelineException surfaces its friendly message', () async {
      final BatchQueue queue = BatchQueue();
      queue.add(_picked());
      await queue.run((PickedImage p, void Function(double) _) async {
        throw const ImagePipelineException(
          ImageFailure.corrupted,
          'That file looks incomplete or damaged.',
        );
      });
      expect(queue.items.single.status, BatchItemStatus.failed);
      expect(
        queue.items.single.error,
        'That file looks incomplete or damaged.',
      );
    });

    test('generic errors get a wrapped message', () async {
      final BatchQueue queue = BatchQueue();
      queue.add(_picked());
      await queue.run((PickedImage p, void Function(double) _) async {
        throw StateError('boom');
      });
      expect(queue.items.single.status, BatchItemStatus.failed);
      expect(queue.items.single.error, contains('Processing failed:'));
      expect(queue.items.single.error, contains('boom'));
    });

    test('cancel marks remaining items and stops processing', () async {
      final BatchQueue queue = BatchQueue();
      queue.add(_picked(name: 'first'));
      queue.add(_picked(name: 'second'));
      await queue.run((PickedImage p, void Function(double) _) async {
        queue.cancel();
        return _makeSource();
      });
      expect(queue.items.first.status, BatchItemStatus.done);
      expect(queue.items.last.status, BatchItemStatus.cancelled);
    });

    test('onUpdate fires and the items view is unmodifiable', () async {
      final BatchQueue queue = BatchQueue();
      queue.add(_picked());
      int updates = 0;
      await queue.run(
        (PickedImage p, void Function(double) _) async => _makeSource(),
        onUpdate: (_) => updates++,
      );
      expect(updates, greaterThanOrEqualTo(2));
      expect(() => queue.items.add(queue.items.first), throwsUnsupportedError);
    });

    test('clear empties the queue', () {
      final BatchQueue queue = BatchQueue();
      queue.add(_picked());
      queue.clear();
      expect(queue.items, isEmpty);
    });
  });

  group('TypeScreen contract', () {
    late _RecordingLauncher launcher;

    Future<void> pumpType(WidgetTester tester, SourceImage? source) async {
      launcher = _RecordingLauncher();
      await tester.binding.setSurfaceSize(phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _appOverrides(_FakePicker()),
          child: MaterialApp(
            theme: AppTheme.dark(AccentPreset.all.first),
            home: TypeScreen(launcher: launcher),
          ),
        ),
      );
      if (source != null) {
        final ProviderContainer c = ProviderScope.containerOf(
          tester.element(find.byType(TypeScreen)),
        );
        c.read(createSessionProvider.notifier)
          ..setPicked(_picked())
          ..setSource(source);
        await tester.pump();
      }
    }

    testWidgets('shows a placeholder when no image is loaded', (
      WidgetTester tester,
    ) async {
      await pumpType(tester, null);
      expect(find.text('No image'), findsOneWidget);
    });

    testWidgets('ASCII card records target and hands over the source', (
      WidgetTester tester,
    ) async {
      final SourceImage source = _makeSource();
      await pumpType(tester, source);

      await tester.tap(find.text('ASCII'));
      await _pumpFor(tester, count: 3);

      expect(launcher.opened, <CreateTarget>[CreateTarget.ascii]);
      expect(launcher.sources.single, same(source));
      final ProviderContainer c = ProviderScope.containerOf(
        tester.element(find.byType(TypeScreen)),
      );
      expect(c.read(createSessionProvider).target, CreateTarget.ascii);
      expect(
        c.read(createSessionProvider).currentStep,
        CreateStep.chooseTarget,
      );
    });

    testWidgets('Sketch card opens the sketch launcher', (
      WidgetTester tester,
    ) async {
      await pumpType(tester, _makeSource());
      await tester.tap(find.text('Sketch'));
      await _pumpFor(tester, count: 3);
      expect(launcher.opened, <CreateTarget>[CreateTarget.sketch]);
    });
  });

  group('create flow through the real router', () {
    late _FakePicker picker;

    /// The Create tab, scoped to the bottom navigation bar so it cannot match
    /// the "Create" app-bar title or home-screen copy.
    Finder createTab() => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Create'),
    );

    Future<ProviderContainer> boot(
      WidgetTester tester, {
      _FakePicker? withPicker,
    }) async {
      picker = withPicker ?? _FakePicker(galleryResult: _picked());
      await tester.binding.setSurfaceSize(phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _appOverrides(picker),
          child: const SketchGlyphApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(createTab());
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(SketchGlyphApp)),
      );
    }

    /// The sheet's option labels, scoped to the open BottomSheet so a nav
    /// destination with the same label (e.g. "Gallery") can't collide.
    Finder sheetOption(String label) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );

    /// Taps the pick CTA, chooses Gallery in the sheet, and waits for the
    /// background decode to land in the session.
    ///
    /// While the sheet is up the body shows an endless CircularProgressIndicator,
    /// so every step here uses fixed pumps instead of pumpAndSettle.
    Future<void> pickGallery(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Choose an image'));
      await _pumpFor(tester, count: 4);
      await tester.tap(sheetOption('Gallery'));
      // Pumps flush the sheet pop + await continuations; the decode itself
      // runs in a real isolate and needs the runAsync poll below.
      await _pumpFor(tester, count: 4);
      await _waitFor(
        tester,
        () => container.read(createSessionProvider).source != null,
      );
      await _pumpFor(tester);
    }

    testWidgets('empty create screen offers pick and batch actions', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      expect(find.text('Choose an image'), findsWidgets);
      expect(find.text('Batch Mode'), findsOneWidget);
      expect(
        find.text('All processing happens on your device.'),
        findsOneWidget,
      );
      expect(container.read(createSessionProvider).picked, isNull);
    });

    testWidgets('batch button opens the batch screen', (
      WidgetTester tester,
    ) async {
      await boot(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Batch Mode'));
      await tester.pumpAndSettle();
      expect(find.text('No images in queue'), findsOneWidget);
      expect(find.text('Process All'), findsOneWidget);
    });

    testWidgets('dismissing the sheet records nothing', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Choose an image'));
      await _pumpFor(tester, count: 4);
      expect(sheetOption('Gallery'), findsOneWidget);

      // Tap the modal barrier above the sheet to dismiss it.
      await tester.tapAt(const Offset(30, 30));
      await _pumpFor(tester, count: 4);

      expect(picker.galleryCalls, 0);
      expect(container.read(createSessionProvider).picked, isNull);
      expect(find.text('Batch Mode'), findsOneWidget);
    });

    testWidgets('camera picks call pickFromCamera, never the gallery', (
      WidgetTester tester,
    ) async {
      // null results model a cancelled camera shot: no decode starts.
      await boot(tester, withPicker: _FakePicker()..cameraResult = null);
      await tester.tap(find.widgetWithText(FilledButton, 'Choose an image'));
      await _pumpFor(tester, count: 4);
      await tester.tap(sheetOption('Camera'));
      await _pumpFor(tester, count: 4);

      expect(picker.cameraCalls, 1);
      expect(picker.galleryCalls, 0);
      expect(picker.fileCalls, 0);
    });

    testWidgets('file picks call pickFromFile and decode through', (
      WidgetTester tester,
    ) async {
      final _FakePicker filePicker = _FakePicker()
        ..fileResult = PickedImage(
          bytes: _pngBytes(width: 30, height: 30),
          origin: SourceOrigin.file,
          name: 'file',
        );
      final ProviderContainer container = await boot(
        tester,
        withPicker: filePicker,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Choose an image'));
      await _pumpFor(tester, count: 4);
      await tester.tap(sheetOption('File'));
      await _pumpFor(tester, count: 4);
      await _waitFor(
        tester,
        () => container.read(createSessionProvider).source != null,
      );
      await _pumpFor(tester);

      expect(picker.fileCalls, 1);
      expect(picker.galleryCalls, 0);
      expect(
        container.read(createSessionProvider).picked!.origin,
        SourceOrigin.file,
      );
      expect(container.read(createSessionProvider).source!.width, 30);
    });

    testWidgets('pick -> decode reaches Transform with the decoded source', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      await pickGallery(tester, container);

      expect(picker.galleryCalls, 1);
      final CreateSession s = container.read(createSessionProvider);
      expect(s.picked, isNotNull);
      expect(s.source, isNotNull);
      expect(s.source!.width, 60);
      expect(s.source!.height, 40);
      expect(s.history, <CreateStep>[CreateStep.pickSource, CreateStep.decode]);
      expect(find.text('Transform'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('1:1 preset + Apply crops the session source to 40x40', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      await pickGallery(tester, container);

      await tester.tap(find.text('1:1'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await _waitFor(
        tester,
        () => container.read(createSessionProvider).source!.width == 40,
      );
      await _pumpFor(tester);

      final SourceImage source = container.read(createSessionProvider).source!;
      expect(source.width, 40);
      expect(source.height, 40);
    });

    testWidgets('backing out of Transform resumes on the type step', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      await pickGallery(tester, container);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // CreateScreen resumes the live session: source set, no target yet.
      expect(find.text('Choose Editor'), findsOneWidget);
      expect(find.text('ASCII'), findsOneWidget);
      expect(find.text('Sketch'), findsOneWidget);
      expect(
        container.read(createSessionProvider).currentStep,
        CreateStep.decode,
      );
    });

    testWidgets('choosing ASCII seeds the real editor and navigates', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      await pickGallery(tester, container);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ASCII'));
      await _waitFor(
        tester,
        () => container.read(asciiEditorControllerProvider).source != null,
      );
      await _pumpFor(tester);

      expect(find.byType(AsciiEditorScreen), findsOneWidget);
      expect(container.read(createSessionProvider).target, CreateTarget.ascii);

      // The debounced low-res preview runs in an isolate; wait for it.
      await tester.pump(const Duration(milliseconds: 200));
      await _waitFor(tester, () {
        final EditorState st = container.read(asciiEditorControllerProvider);
        return st.preview != null || st.error != null;
      });
      final EditorState st = container.read(asciiEditorControllerProvider);
      expect(st.error, isNull);
      expect(st.preview, isNotNull);
      expect(st.preview!.text, isNotEmpty);
    });

    testWidgets('choosing Sketch seeds the sketch editor', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      await pickGallery(tester, container);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sketch'));
      await _waitFor(
        tester,
        () => container.read(sketchEditorControllerProvider).source != null,
      );
      // Fixed pumps only: the sketch screen has a repeating shimmer.
      await _pumpFor(tester);

      expect(find.byType(SketchEditorScreen), findsOneWidget);
      expect(container.read(createSessionProvider).target, CreateTarget.sketch);

      await tester.pump(const Duration(milliseconds: 250));
      await _waitFor(tester, () {
        final SketchEditorState st = container.read(
          sketchEditorControllerProvider,
        );
        return st.render != null || st.error != null;
      });
      final SketchEditorState st = container.read(
        sketchEditorControllerProvider,
      );
      expect(st.error, isNull);
      expect(st.render, isNotNull);
    });

    testWidgets(
      'transform: rotate CW swaps dimensions, crop clips the source',
      (WidgetTester tester) async {
        final ProviderContainer container = await boot(tester);
        await pickGallery(tester, container);

        await tester.tap(find.text('CW'));
        await _waitFor(
          tester,
          () => container.read(createSessionProvider).source!.width == 40,
        );
        // Let TransformScreen rebuild so its handlers see the rotated source.
        await _pumpFor(tester, count: 2);
        SourceImage rotated = container.read(createSessionProvider).source!;
        expect(rotated.width, 40);
        expect(rotated.height, 60);

        // 1:1 on the rotated 40x60 frame fills the width entirely.
        await tester.tap(find.text('1:1'));
        await tester.pump();
        await tester.tap(find.text('Apply'));
        await _waitFor(
          tester,
          () => container.read(createSessionProvider).source!.height == 40,
        );
        await _pumpFor(tester);
        rotated = container.read(createSessionProvider).source!;
        expect(rotated.width, 40);
        expect(rotated.height, 40);
      },
    );

    testWidgets('switching tabs keeps the session and resumes at Type', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await boot(tester);
      await pickGallery(tester, container);

      // Leave the create branch entirely and come back without losing state:
      // the session lives in the provider container, not the widget tree.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(createTab());
      await tester.pumpAndSettle();

      expect(container.read(createSessionProvider).source, isNotNull);
      // Transform is still on the branch stack, so its screen stays visible.
      expect(find.byType(TransformScreen), findsOneWidget);
    });
  });
}
