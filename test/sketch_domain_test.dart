import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sketchglyph/core/image/image_pipeline.dart';
import 'package:sketchglyph/features/sketch/domain/sketch_job.dart';
import 'package:sketchglyph/features/sketch/domain/sketch_presets.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

/// Creates a SourceImage from an img.Image.
SourceImage _toSourceImage(img.Image image) {
  final img.Image rgba = image.convert(numChannels: 4);
  return SourceImage(
    width: rgba.width,
    height: rgba.height,
    rgba: rgba.getBytes(order: img.ChannelOrder.rgba),
    originalWidth: rgba.width,
    originalHeight: rgba.height,
  );
}

/// Creates a gradient SourceImage.
SourceImage _gradientImage({int width = 60, int height = 40, int offset = 0}) {
  final img.Image image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int gray = ((x + y + offset) % 256).toInt();
      image.setPixelRgba(x, y, gray, gray, gray, 255);
    }
  }
  return _toSourceImage(image);
}

void main() {
  group('SketchPreset', () {
    test('all presets have unique ids', () {
      final Set<String> ids = <String>{};
      for (final SketchPreset preset in SketchPreset.all) {
        expect(
          ids.add(preset.id),
          isTrue,
          reason: 'Duplicate id: ${preset.id}',
        );
      }
    });

    test('all presets have unique labels', () {
      final Set<String> labels = <String>{};
      for (final SketchPreset preset in SketchPreset.all) {
        expect(
          labels.add(preset.label),
          isTrue,
          reason: 'Duplicate label: ${preset.label}',
        );
      }
    });

    test('presets can build valid settings', () {
      for (final SketchPreset preset in SketchPreset.all) {
        final SketchSettings settings = preset.toSettings(seed: 42);
        expect(settings.style, preset.style);
        expect(settings.paper, preset.paper);
        expect(settings.seed, 42);
      }
    });
  });

  group('InkColorPreset', () {
    test('all ink presets have unique ids', () {
      final Set<String> ids = <String>{};
      for (final InkColorPreset preset in InkColorPreset.all) {
        expect(
          ids.add(preset.id),
          isTrue,
          reason: 'Duplicate id: ${preset.id}',
        );
      }
    });

    test('exactly 5 ink presets', () {
      expect(InkColorPreset.all.length, 5);
    });
  });

  group('renderSketch', () {
    test('renders a tiny image successfully', () async {
      final SourceImage source = _gradientImage(width: 60, height: 40);

      final SketchRequest request = SketchRequest(
        source: source,
        settings: SketchSettings(
          style: SketchStyle.graphite2b,
          paper: PaperType.whiteCartridge,
          longEdge: 200,
          seed: 1,
        ),
      );

      final SketchRender result = await renderSketch(request);

      expect(result.pngBytes, isNotEmpty);
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
      expect(result.strokeCount, greaterThanOrEqualTo(0));
    });

    test('determinism: same settings produce identical output', () async {
      final SourceImage source = _gradientImage(
        width: 60,
        height: 40,
        offset: 5,
      );

      final SketchSettings settings = SketchSettings(
        style: SketchStyle.fineliner,
        paper: PaperType.cream,
        longEdge: 200,
        seed: 42,
      );

      final SketchRender result1 = await renderSketch(
        SketchRequest(source: source, settings: settings),
      );

      final SketchRender result2 = await renderSketch(
        SketchRequest(source: source, settings: settings),
      );

      expect(result1.pngBytes, equals(result2.pngBytes));
      expect(result1.width, equals(result2.width));
      expect(result1.height, equals(result2.height));
      expect(result1.strokeCount, equals(result2.strokeCount));
    });

    test('different seeds produce different output', () async {
      final SourceImage source = _gradientImage(
        width: 60,
        height: 40,
        offset: 10,
      );

      final SketchRender result1 = await renderSketch(
        SketchRequest(
          source: source,
          settings: SketchSettings(
            style: SketchStyle.charcoal,
            longEdge: 200,
            seed: 1,
          ),
        ),
      );

      final SketchRender result2 = await renderSketch(
        SketchRequest(
          source: source,
          settings: SketchSettings(
            style: SketchStyle.charcoal,
            longEdge: 200,
            seed: 999,
          ),
        ),
      );

      // Different seeds should produce different byte output
      expect(result1.pngBytes, isNot(equals(result2.pngBytes)));
    });
  });
}
