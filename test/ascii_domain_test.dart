/// Tests for ASCII domain layer: presets, rendering, and controller.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import 'package:sketchglyph/features/ascii/domain/ascii_presets.dart';
import 'package:sketchglyph/features/ascii/domain/ascii_job.dart';
import 'package:sketchglyph/features/ascii/domain/ascii_renderer_service.dart';
import 'package:sketchglyph/features/ascii/domain/ascii_session_controller.dart';

/// Creates an 80x40 RGBA image with left half red, right half blue.
Uint8List _patternImageRgba({int width = 80, int height = 40}) {
  final img.Image image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final bool left = x < width ~/ 2;
      image.setPixelRgba(
        x,
        y,
        left ? 255 : 10,
        left ? 0 : 10,
        left ? 0 : 255,
        255,
      );
    }
  }
  return image.getBytes(order: img.ChannelOrder.rgba);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AsciiPreset', () {
    test('all presets build valid AsciiSettings without throwing', () {
      for (final AsciiPreset preset in AsciiPreset.all) {
        expect(() => preset.build(), returnsNormally);
      }
    });

    test('each preset has unique id and label', () {
      final Set<String> ids = <String>{};
      final Set<String> labels = <String>{};
      for (final AsciiPreset preset in AsciiPreset.all) {
        expect(
          ids.add(preset.id),
          isTrue,
          reason: 'Duplicate id: ${preset.id}',
        );
        expect(
          labels.add(preset.label),
          isTrue,
          reason: 'Duplicate label: ${preset.label}',
        );
      }
    });
  });

  group('CharSetPreset', () {
    test('all character-set presets pass validation in characterSet mode', () {
      for (final CharSetPreset preset in CharSetPreset.charSets) {
        expect(
          () => AsciiSettings(
            mode: AsciiMode.characterSet,
            characterSet: preset.characters,
          ),
          returnsNormally,
          reason: 'Preset ${preset.id} failed validation',
        );
      }
    });

    test('each preset has unique id and label', () {
      final Set<String> ids = <String>{};
      final Set<String> labels = <String>{};
      for (final CharSetPreset preset in CharSetPreset.charSets) {
        expect(
          ids.add(preset.id),
          isTrue,
          reason: 'Duplicate id: ${preset.id}',
        );
        expect(
          labels.add(preset.label),
          isTrue,
          reason: 'Duplicate label: ${preset.label}',
        );
      }
    });
  });

  group('PalettePreset', () {
    test('exactly five palettes defined', () {
      expect(PalettePreset.palettes.length, 5);
    });

    test('each palette has unique id and label', () {
      final Set<String> ids = <String>{};
      final Set<String> labels = <String>{};
      for (final PalettePreset preset in PalettePreset.palettes) {
        expect(
          ids.add(preset.id),
          isTrue,
          reason: 'Duplicate id: ${preset.id}',
        );
        expect(
          labels.add(preset.label),
          isTrue,
          reason: 'Duplicate label: ${preset.label}',
        );
      }
    });
  });

  group('FontOption', () {
    test('all bundled fonts have unique ids and engine families', () {
      final Set<String> ids = <String>{};
      final Set<String> families = <String>{};
      for (final FontOption font in FontOption.bundled) {
        expect(ids.add(font.id), isTrue, reason: 'Duplicate id: ${font.id}');
        expect(
          families.add(font.engineFamily),
          isTrue,
          reason: 'Duplicate engineFamily: ${font.engineFamily}',
        );
      }
    });
  });

  group('renderPreview', () {
    test('lowRes preview returns columns <= 140 and non-empty text', () async {
      final Uint8List rgba = _patternImageRgba();
      final AsciiSettings settings = AsciiSettings(
        font: 'JetBrainsMono-Regular',
      );
      final AsciiRendererService service = const AsciiRendererService();

      final PreviewResult result = await service.renderPreview(
        rgba,
        80,
        40,
        settings,
        lowRes: true,
      );

      expect(result.columns, lessThanOrEqualTo(140));
      expect(result.text, isNotEmpty);
      expect(result.cells, isNotEmpty);
      expect(result.rows, greaterThan(0));
    });

    test('determinism: same bytes+settings produce identical text', () async {
      final Uint8List rgba = _patternImageRgba();
      final AsciiSettings settings = AsciiSettings(
        font: 'JetBrainsMono-Regular',
      );
      final AsciiRendererService service = const AsciiRendererService();

      final PreviewResult result1 = await service.renderPreview(
        rgba,
        80,
        40,
        settings,
        lowRes: true,
      );

      final PreviewResult result2 = await service.renderPreview(
        rgba,
        80,
        40,
        settings,
        lowRes: true,
      );

      expect(result1.text, equals(result2.text));
      expect(result1.columns, equals(result2.columns));
      expect(result1.rows, equals(result2.rows));
    });
  });

  group('AsciiEditorController', () {
    test('update with invalid settings surfaces error message', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final AsciiEditorController controller = container.read(
        asciiEditorControllerProvider.notifier,
      );

      // Try to set columns out of range.
      controller.update((AsciiSettings s) => s.copyWith(columns: 10));

      final EditorState state = container.read(asciiEditorControllerProvider);
      expect(state.error, isNotNull);
      expect(state.error, contains('Columns must be between'));
    });

    test('update with valid settings clears error', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final AsciiEditorController controller = container.read(
        asciiEditorControllerProvider.notifier,
      );

      // Set an error first.
      controller.update((AsciiSettings s) => s.copyWith(columns: 10));
      expect(container.read(asciiEditorControllerProvider).error, isNotNull);

      // Now update with valid settings.
      controller.update((AsciiSettings s) => s.copyWith(columns: 80));

      final EditorState state = container.read(asciiEditorControllerProvider);
      expect(state.error, isNull);
      expect(state.settings.columns, 80);
    });

    test('reset restores default settings', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final AsciiEditorController controller = container.read(
        asciiEditorControllerProvider.notifier,
      );

      // Change settings.
      controller.update((AsciiSettings s) => s.copyWith(columns: 120));
      expect(
        container.read(asciiEditorControllerProvider).settings.columns,
        120,
      );

      // Reset.
      controller.reset();

      final EditorState state = container.read(asciiEditorControllerProvider);
      expect(state.settings.columns, 100); // default
    });
  });
}
