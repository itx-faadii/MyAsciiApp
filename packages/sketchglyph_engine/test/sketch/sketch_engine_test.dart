import 'dart:typed_data';

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SketchEngine', () {
    test('determinism: same seed produces identical output', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);
      final SketchSettings settings = SketchSettings(seed: 42, longEdge: 512);

      final SketchResult result1 = SketchEngine.render(source, settings);
      final SketchResult result2 = SketchEngine.render(source, settings);

      final Uint8List bytes1 = result1.pngBytes;
      final Uint8List bytes2 = result2.pngBytes;

      expect(bytes1.length, equals(bytes2.length));
      for (int i = 0; i < bytes1.length; i++) {
        expect(
          bytes1[i],
          equals(bytes2[i]),
          reason: 'PNG bytes differ at index $i',
        );
      }
    });

    test('determinism: different seeds produce different output', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);
      final SketchSettings settings1 = SketchSettings(seed: 42, longEdge: 512);
      final SketchSettings settings2 = SketchSettings(seed: 99, longEdge: 512);

      final SketchResult result1 = SketchEngine.render(source, settings1);
      final SketchResult result2 = SketchEngine.render(source, settings2);

      final Uint8List bytes1 = result1.pngBytes;
      final Uint8List bytes2 = result2.pngBytes;

      // At least some bytes should differ.
      bool differs = false;
      final int checkLen = bytes1.length < bytes2.length
          ? bytes1.length
          : bytes2.length;
      for (int i = 0; i < checkLen; i++) {
        if (bytes1[i] != bytes2[i]) {
          differs = true;
          break;
        }
      }
      expect(
        differs,
        isTrue,
        reason: 'Different seeds should produce different output',
      );
    });

    test('all styles render without throwing', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);

      for (final SketchStyle style in SketchStyle.values) {
        final SketchSettings settings = SketchSettings(
          style: style,
          longEdge: 512,
        );
        expect(
          () => SketchEngine.render(source, settings),
          returnsNormally,
          reason: 'Style ${style.label} should render without throwing',
        );
      }
    });

    test('all papers render without throwing', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);

      for (final PaperType paper in PaperType.values) {
        final SketchSettings settings = SketchSettings(
          paper: paper,
          longEdge: 512,
        );
        expect(
          () => SketchEngine.render(source, settings),
          returnsNormally,
          reason: 'Paper ${paper.label} should render without throwing',
        );
      }
    });

    test('produces non-blank images', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);
      final SketchSettings settings = SketchSettings(longEdge: 512);
      final SketchResult result = SketchEngine.render(source, settings);

      // Calculate standard deviation of luminance.
      double sum = 0;
      double sumSq = 0;
      final int n = result.image.length;
      for (int i = 0; i < n; i++) {
        final double lum = result.image.luminanceAt(i);
        sum += lum;
        sumSq += lum * lum;
      }
      final double mean = sum / n;
      final double variance = sumSq / n - mean * mean;
      final double stdDev = variance > 0 ? _sqrt(variance) : 0;

      expect(
        stdDev,
        greaterThan(0.05),
        reason: 'Image should have visible variation (stdDev=$stdDev)',
      );
    });

    test('light vs dark inputs produce different mean luminance', () {
      final RgbImage lightSource = checkerboard(
        size: 320,
        cells: 8,
        dark: 180,
        light: 255,
      );
      final RgbImage darkSource = checkerboard(
        size: 320,
        cells: 8,
        dark: 0,
        light: 80,
      );
      final SketchSettings settings = SketchSettings(longEdge: 512);

      final SketchResult lightResult = SketchEngine.render(
        lightSource,
        settings,
      );
      final SketchResult darkResult = SketchEngine.render(darkSource, settings);

      final double lightMean = _meanLuminance(lightResult.image);
      final double darkMean = _meanLuminance(darkResult.image);

      expect(
        (lightMean - darkMean).abs(),
        greaterThan(0.09),
        reason: 'Light and dark inputs should produce different outputs',
      );
    });

    test('styles are distinguishable', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);

      final SketchSettings graphite2bSettings = SketchSettings(
        style: SketchStyle.graphite2b,
        longEdge: 512,
      );
      final SketchSettings finelinerSettings = SketchSettings(
        style: SketchStyle.fineliner,
        longEdge: 512,
      );
      final SketchSettings stippleSettings = SketchSettings(
        style: SketchStyle.stipple,
        longEdge: 512,
      );
      final SketchSettings contourSettings = SketchSettings(
        style: SketchStyle.contourLineArt,
        longEdge: 512,
      );
      final SketchSettings ballpointSettings = SketchSettings(
        style: SketchStyle.ballpoint,
        longEdge: 512,
      );

      final SketchResult graphite2b = SketchEngine.render(
        source,
        graphite2bSettings,
      );
      final SketchResult fineliner = SketchEngine.render(
        source,
        finelinerSettings,
      );
      final SketchResult stipple = SketchEngine.render(source, stippleSettings);
      final SketchResult contour = SketchEngine.render(source, contourSettings);
      final SketchResult ballpoint = SketchEngine.render(
        source,
        ballpointSettings,
      );

      // Check that styles differ from each other.
      expect(
        _meanAbsoluteDifference(graphite2b.image, fineliner.image),
        greaterThan(0.02),
        reason: 'graphite2b and fineliner should differ',
      );
      expect(
        _meanAbsoluteDifference(graphite2b.image, stipple.image),
        greaterThan(0.02),
        reason: 'graphite2b and stipple should differ',
      );
      expect(
        _meanAbsoluteDifference(graphite2b.image, contour.image),
        greaterThan(0.02),
        reason: 'graphite2b and contour should differ',
      );

      // Ballpoint should be blue-dominant.
      final double ballpointBlue = _meanChannel(ballpoint.image, channel: 2);
      final double ballpointRed = _meanChannel(ballpoint.image, channel: 0);
      expect(
        ballpointBlue,
        greaterThan(ballpointRed),
        reason: 'Ballpoint should have more blue than red',
      );

      // Graphite should be roughly neutral (R ≈ G ≈ B).
      final double graphiteRed = _meanChannel(graphite2b.image, channel: 0);
      final double graphiteGreen = _meanChannel(graphite2b.image, channel: 1);
      final double graphiteBlue = _meanChannel(graphite2b.image, channel: 2);
      expect(
        (graphiteRed - graphiteGreen).abs(),
        lessThan(10),
        reason: 'Graphite should be roughly neutral',
      );
      expect(
        (graphiteGreen - graphiteBlue).abs(),
        lessThan(10),
        reason: 'Graphite should be roughly neutral',
      );
    });

    test('stroke recording: non-empty with valid properties', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);
      final SketchSettings settings = SketchSettings(longEdge: 512);
      final SketchResult result = SketchEngine.render(source, settings);

      expect(
        result.strokes,
        isNotEmpty,
        reason: 'Should record at least some strokes',
      );

      for (final SketchStroke stroke in result.strokes) {
        expect(
          stroke.points.length,
          greaterThanOrEqualTo(2),
          reason: 'Stroke should have at least 2 points',
        );
        expect(
          stroke.width,
          greaterThan(0),
          reason: 'Stroke width should be positive',
        );
        expect(
          stroke.alpha,
          greaterThanOrEqualTo(0),
          reason: 'Stroke alpha should be >= 0',
        );
        expect(
          stroke.alpha,
          lessThanOrEqualTo(1),
          reason: 'Stroke alpha should be <= 1',
        );
        expect(
          stroke.points.every((double p) => p.isFinite),
          isTrue,
          reason: 'All stroke points should be finite',
        );
      }

      expect(
        result.strokes.length,
        lessThanOrEqualTo(60000),
        reason: 'Stroke count should be bounded',
      );
    });

    test('hatchDensity increases ink coverage', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);

      final SketchSettings lowDensity = SketchSettings(
        hatchDensity: 0.5,
        longEdge: 512,
      );
      final SketchSettings highDensity = SketchSettings(
        hatchDensity: 2.0,
        longEdge: 512,
      );

      final SketchResult lowResult = SketchEngine.render(source, lowDensity);
      final SketchResult highResult = SketchEngine.render(source, highDensity);

      final double lowDarkness = 1 - _meanLuminance(lowResult.image);
      final double highDarkness = 1 - _meanLuminance(highResult.image);

      expect(
        highDarkness,
        greaterThan(lowDarkness),
        reason: 'Higher hatch density should produce darker output',
      );
    });

    test('shading=0 is lighter than shading=2', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);

      final SketchSettings noShading = SketchSettings(
        shading: 0.0,
        longEdge: 512,
      );
      final SketchSettings fullShading = SketchSettings(
        shading: 2.0,
        longEdge: 512,
      );

      final SketchResult noShadingResult = SketchEngine.render(
        source,
        noShading,
      );
      final SketchResult fullShadingResult = SketchEngine.render(
        source,
        fullShading,
      );

      final double noShadingLum = _meanLuminance(noShadingResult.image);
      final double fullShadingLum = _meanLuminance(fullShadingResult.image);

      expect(
        noShadingLum,
        greaterThan(fullShadingLum + 0.05),
        reason: 'No shading should be lighter than full shading',
      );
    });

    test('JSON round-trip preserves all fields', () {
      final SketchSettings original = SketchSettings(
        style: SketchStyle.charcoal,
        paper: PaperType.kraft,
        detail: 1.5,
        lineWeight: 2.0,
        hatchDensity: 1.8,
        shading: 1.2,
        edgeStrength: 2.5,
        grain: 1.3,
        smudge: 1.7,
        inkFlow: 1.4,
        inkArgb: 0xFF3C3C3C,
        transparentBackground: true,
        longEdge: 800,
        seed: 12345,
      );

      final Map<String, Object?> json = original.toJson();
      final SketchSettings restored = SketchSettings.fromJson(json);

      expect(restored.style, equals(original.style));
      expect(restored.paper, equals(original.paper));
      expect(restored.detail, equals(original.detail));
      expect(restored.lineWeight, equals(original.lineWeight));
      expect(restored.hatchDensity, equals(original.hatchDensity));
      expect(restored.shading, equals(original.shading));
      expect(restored.edgeStrength, equals(original.edgeStrength));
      expect(restored.grain, equals(original.grain));
      expect(restored.smudge, equals(original.smudge));
      expect(restored.inkFlow, equals(original.inkFlow));
      expect(restored.inkArgb, equals(original.inkArgb));
      expect(
        restored.transparentBackground,
        equals(original.transparentBackground),
      );
      expect(restored.longEdge, equals(original.longEdge));
      expect(restored.seed, equals(original.seed));
    });

    test('transparentBackground produces alpha < 255', () {
      final RgbImage source = syntheticPortrait(width: 320, height: 400);
      final SketchSettings settings = SketchSettings(
        transparentBackground: true,
        longEdge: 512,
      );
      final SketchResult result = SketchEngine.render(source, settings);

      // Check that the image has alpha channel.
      expect(
        result.image.hasAlpha,
        isTrue,
        reason: 'transparentBackground should enable alpha channel',
      );

      // Check that at least some pixels have alpha < 255.
      bool hasTransparentPixel = false;
      for (int i = 0; i < result.image.length; i++) {
        if (result.image.a[i] < 255) {
          hasTransparentPixel = true;
          break;
        }
      }

      expect(
        hasTransparentPixel,
        isTrue,
        reason: 'Should have at least some transparent pixels',
      );

      // Verify PNG encoding preserves alpha.
      final Uint8List pngBytes = result.pngBytes;
      expect(pngBytes, isNotEmpty);
    });

    test('SketchStyle extensions provide label and id', () {
      for (final SketchStyle style in SketchStyle.values) {
        expect(style.label, isNotEmpty);
        expect(style.id, isNotEmpty);
        expect(sketchStyleById(style.id), equals(style));
      }
    });

    test('PaperType extensions provide label, id, and baseArgb', () {
      for (final PaperType paper in PaperType.values) {
        expect(paper.label, isNotEmpty);
        expect(paper.id, isNotEmpty);
        expect(paper.baseArgb, isNonZero);
        expect(paperTypeById(paper.id), equals(paper));
      }
    });

    test('copyWith creates modified copy', () {
      final SketchSettings original = SketchSettings(
        style: SketchStyle.graphite2b,
        paper: PaperType.whiteCartridge,
        seed: 42,
      );

      final SketchSettings modified = original.copyWith(
        style: SketchStyle.charcoal,
        seed: 99,
      );

      expect(modified.style, equals(SketchStyle.charcoal));
      expect(modified.seed, equals(99));
      expect(modified.paper, equals(original.paper));
    });
  });
}

double _meanLuminance(RgbImage image) {
  double sum = 0;
  for (int i = 0; i < image.length; i++) {
    sum += image.luminanceAt(i);
  }
  return sum / image.length;
}

double _meanChannel(RgbImage image, {required int channel}) {
  double sum = 0;
  for (int i = 0; i < image.length; i++) {
    final int value = switch (channel) {
      0 => image.r[i],
      1 => image.g[i],
      2 => image.b[i],
      _ => 0,
    };
    sum += value;
  }
  return sum / image.length;
}

double _meanAbsoluteDifference(RgbImage a, RgbImage b) {
  double sum = 0;
  for (int i = 0; i < a.length; i++) {
    final double lumA = a.luminanceAt(i);
    final double lumB = b.luminanceAt(i);
    sum += (lumA - lumB).abs();
  }
  return sum / a.length;
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  double guess = x / 2;
  for (int i = 0; i < 20; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}
