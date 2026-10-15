/// Tests for image resampling and filtering operations.
///
/// Validates area averaging, Gaussian blur, sharpening, and downscaling
/// with various filters and edge cases.
library;

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

void main() {
  // The engine averages in linear light (gamma-correct Rec.709), so an sRGB
  // byte of 128 maps to linear ~0.216, not 0.5. These tests assert the real
  // linear-light outputs; see grayToLinear for the transfer curve.
  final double lin128 = grayToLinear[128];
  final double lin100 = grayToLinear[100];
  final double lin200 = grayToLinear[200];

  group('areaAverage', () {
    test('box filter on constant image returns its linear value', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      final List<double> result = areaAverage(
        src,
        5,
        5,
        filter: ResampleFilter.box,
      );

      expect(result.length, 25);
      for (final double v in result) {
        expect(v, closeTo(lin128, 0.01));
      }
    });

    test('lanczos filter on constant image returns constant', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      final List<double> result = areaAverage(
        src,
        5,
        5,
        filter: ResampleFilter.lanczos,
      );

      expect(result.length, 25);
      for (final double v in result) {
        expect(v, closeTo(lin128, 0.01));
      }
    });

    test('downscaling 2x2 to 1x1 averages correctly', () {
      final GrayImage src = GrayImage(2, 2);
      src.pixels[0] = 0;
      src.pixels[1] = 255;
      src.pixels[2] = 255;
      src.pixels[3] = 0;

      final List<double> result = areaAverage(src, 1, 1);
      expect(result.length, 1);
      // Half black (linear 0) + half white (linear 1) => 0.5.
      expect(result[0], closeTo(0.5, 0.01));
    });

    test('upscaling preserves linear values', () {
      final GrayImage src = GrayImage(2, 2, fill: 100);
      final List<double> result = areaAverage(src, 4, 4);

      expect(result.length, 16);
      for (final double v in result) {
        expect(v, closeTo(lin100, 0.01));
      }
    });

    test('box filter on checkerboard averages to mid-grey', () {
      final GrayImage src = GrayImage(4, 4);
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          src.pixels[y * 4 + x] = ((x + y) % 2 == 0) ? 0 : 255;
        }
      }

      final List<double> result = areaAverage(src, 2, 2);
      for (final double v in result) {
        expect(v, closeTo(0.5, 0.05));
      }
    });

    test('lanczos undershoots on a max-frequency checkerboard', () {
      // Lanczos has negative lobes, so a hard 1px checkerboard rings far
      // below the true mean. This documents the ringing, not a target value.
      final GrayImage src = GrayImage(4, 4);
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          src.pixels[y * 4 + x] = ((x + y) % 2 == 0) ? 0 : 255;
        }
      }

      final List<double> result = areaAverage(
        src,
        2,
        2,
        filter: ResampleFilter.lanczos,
      );
      final double boxMean =
          areaAverage(src, 2, 2).reduce((double a, double b) => a + b) / 4;
      // The ringing value differs clearly from the box mean.
      expect((result[0] - boxMean).abs(), greaterThan(0.1));
    });

    test('non-integer ratios handled correctly', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      final List<double> result = areaAverage(src, 3, 7);

      expect(result.length, 21);
      for (final double v in result) {
        expect(v, closeTo(lin128, 0.01));
      }
    });

    test('1x1 source to 1x1 returns its linear value', () {
      final GrayImage src = GrayImage(1, 1, fill: 200);
      final List<double> result = areaAverage(src, 1, 1);

      expect(result.length, 1);
      expect(result[0], closeTo(lin200, 0.01));
    });
  });

  group('gaussianBlur', () {
    test('sigma 0 returns clone', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      final GrayImage result = gaussianBlur(src, 0);

      expect(result.width, src.width);
      expect(result.height, src.height);
      expect(result.pixels, src.pixels);
    });

    test('negative sigma returns clone', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      final GrayImage result = gaussianBlur(src, -1);

      expect(result.pixels, src.pixels);
    });

    test('blur on constant image returns constant', () {
      final GrayImage src = GrayImage(20, 20, fill: 100);
      final GrayImage result = gaussianBlur(src, 2.0);

      for (final int v in result.pixels) {
        expect(v, closeTo(100, 1));
      }
    });

    test('blur reduces variance at edges', () {
      final GrayImage src = GrayImage(20, 20);
      // Create a sharp edge
      for (int y = 0; y < 20; y++) {
        for (int x = 0; x < 20; x++) {
          src.pixels[y * 20 + x] = x < 10 ? 0 : 255;
        }
      }

      final GrayImage result = gaussianBlur(src, 3.0);

      // Edge should be smoothed
      int edgeVariance(GrayImage img) {
        int sum = 0;
        for (int x = 8; x <= 12; x++) {
          sum +=
              (img.pixels[10 * 20 + x] - 128) * (img.pixels[10 * 20 + x] - 128);
        }
        return sum;
      }

      expect(edgeVariance(result), lessThan(edgeVariance(src)));
    });

    test('blur preserves flat field', () {
      final GrayImage src = GrayImage(30, 30, fill: 150);
      final GrayImage result = gaussianBlur(src, 5.0);

      for (final int v in result.pixels) {
        expect(v, closeTo(150, 2));
      }
    });

    test('small sigma produces subtle blur', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      src.pixels[5 * 10 + 5] = 255; // Single bright pixel

      final GrayImage result = gaussianBlur(src, 0.5);

      // Center should still be bright
      expect(result.pixels[5 * 10 + 5], greaterThan(200));
      // Neighbors should be slightly brighter
      expect(result.pixels[5 * 10 + 4], greaterThan(128));
    });

    test('large sigma produces strong blur', () {
      final GrayImage src = GrayImage(20, 20, fill: 0);
      src.pixels[10 * 20 + 10] = 255; // Single bright pixel

      final GrayImage result = gaussianBlur(src, 5.0);

      // Brightness should spread out
      expect(result.pixels[10 * 20 + 10], lessThan(255));
      expect(result.pixels[10 * 20 + 9], greaterThan(0));
      expect(result.pixels[10 * 20 + 11], greaterThan(0));
    });
  });

  group('sharpen', () {
    test('amount 0 returns original', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      final GrayImage result = sharpen(src, amount: 0);

      expect(result.pixels, src.pixels);
    });

    test('sharpen on constant image returns constant', () {
      final GrayImage src = GrayImage(20, 20, fill: 100);
      final GrayImage result = sharpen(src, amount: 1.0);

      for (final int v in result.pixels) {
        expect(v, closeTo(100, 1));
      }
    });

    test('sharpen increases edge contrast', () {
      final GrayImage src = GrayImage(20, 20);
      // Use an unsaturated edge so sharpening has room to increase contrast
      // without clipping at 0/255.
      for (int y = 0; y < 20; y++) {
        for (int x = 0; x < 20; x++) {
          src.pixels[y * 20 + x] = x < 10 ? 100 : 150;
        }
      }

      final GrayImage result = sharpen(src, amount: 1.5);

      int edgeContrast(GrayImage img) {
        return (img.pixels[10 * 20 + 10] - img.pixels[10 * 20 + 9]).abs();
      }

      expect(edgeContrast(result), greaterThan(edgeContrast(src)));
    });

    test('custom sigma affects blur radius', () {
      final GrayImage src = GrayImage(20, 20, fill: 128);
      src.pixels[10 * 20 + 10] = 255;

      final GrayImage smallSigma = sharpen(src, amount: 1.0, sigma: 0.5);
      final GrayImage largeSigma = sharpen(src, amount: 1.0, sigma: 3.0);

      // Both should sharpen, but with different characteristics
      expect(smallSigma.pixels[10 * 20 + 10], greaterThan(128));
      expect(largeSigma.pixels[10 * 20 + 10], greaterThan(128));
    });

    test('output is clamped to 0-255', () {
      final GrayImage src = GrayImage(10, 10, fill: 250);
      src.pixels[5 * 10 + 5] = 0; // Dark pixel surrounded by bright

      final GrayImage result = sharpen(src, amount: 2.0);

      for (final int v in result.pixels) {
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(255));
      }
    });
  });

  group('downscaleGray', () {
    test('image smaller than maxEdge returns clone', () {
      final GrayImage src = GrayImage(50, 50, fill: 128);
      final GrayImage result = downscaleGray(src, 100);

      expect(result.width, src.width);
      expect(result.height, src.height);
      expect(result.pixels, src.pixels);
    });

    test('image equal to maxEdge returns clone', () {
      final GrayImage src = GrayImage(100, 100, fill: 128);
      final GrayImage result = downscaleGray(src, 100);

      expect(result.width, src.width);
      expect(result.height, src.height);
    });

    test('downscales to fit maxEdge on long side', () {
      final GrayImage src = GrayImage(200, 100, fill: 128);
      final GrayImage result = downscaleGray(src, 100);

      expect(result.width, 100);
      expect(result.height, 50);
    });

    test('preserves aspect ratio', () {
      final GrayImage src = GrayImage(400, 200, fill: 128);
      final GrayImage result = downscaleGray(src, 100);

      expect(result.width, 100);
      expect(result.height, 50);
    });

    test('portrait image downscales correctly', () {
      final GrayImage src = GrayImage(100, 300, fill: 128);
      final GrayImage result = downscaleGray(src, 150);

      expect(result.width, 50);
      expect(result.height, 150);
    });

    test('square image downscales correctly', () {
      final GrayImage src = GrayImage(200, 200, fill: 128);
      final GrayImage result = downscaleGray(src, 100);

      expect(result.width, 100);
      expect(result.height, 100);
    });

    test('maxEdge 0 returns clone', () {
      final GrayImage src = GrayImage(100, 100, fill: 128);
      final GrayImage result = downscaleGray(src, 0);

      expect(result.width, src.width);
      expect(result.height, src.height);
    });

    test('very small maxEdge produces 1x1', () {
      final GrayImage src = GrayImage(100, 100, fill: 128);
      final GrayImage result = downscaleGray(src, 1);

      expect(result.width, greaterThanOrEqualTo(1));
      expect(result.height, greaterThanOrEqualTo(1));
    });

    test('downscaled constant image remains constant', () {
      final GrayImage src = GrayImage(200, 200, fill: 150);
      final GrayImage result = downscaleGray(src, 100);

      for (final int v in result.pixels) {
        expect(v, closeTo(150, 2));
      }
    });
  });

  group('GrayImage', () {
    test('at clamps out-of-bounds coordinates', () {
      final GrayImage img = GrayImage(10, 10, fill: 128);

      expect(img.at(-1, 5), 128);
      expect(img.at(10, 5), 128);
      expect(img.at(5, -1), 128);
      expect(img.at(5, 10), 128);
    });

    test('setAt ignores out-of-bounds coordinates', () {
      final GrayImage img = GrayImage(10, 10, fill: 128);

      img.setAt(-1, 5, 255);
      img.setAt(10, 5, 255);
      img.setAt(5, -1, 255);
      img.setAt(5, 10, 255);

      // All pixels should remain 128
      for (final int v in img.pixels) {
        expect(v, 128);
      }
    });

    test('setAt clamps values to 0-255', () {
      final GrayImage img = GrayImage(10, 10);

      img.setAt(5, 5, 300);
      expect(img.pixels[5 * 10 + 5], 255);

      img.setAt(5, 5, -10);
      expect(img.pixels[5 * 10 + 5], 0);
    });

    test('clone creates independent copy', () {
      final GrayImage src = GrayImage(10, 10, fill: 128);
      final GrayImage copy = src.clone();

      copy.pixels[5 * 10 + 5] = 255;

      expect(src.pixels[5 * 10 + 5], 128);
      expect(copy.pixels[5 * 10 + 5], 255);
    });

    test('toLinear converts to linear light', () {
      final GrayImage img = GrayImage(2, 2);
      img.pixels[0] = 0;
      img.pixels[1] = 128;
      img.pixels[2] = 255;
      img.pixels[3] = 64;

      final List<double> linear = img.toLinear();

      expect(linear.length, 4);
      expect(linear[0], closeTo(0.0, 0.01));
      // sRGB 128 is a perceptual mid-grey, but linear-light ~0.216.
      expect(linear[1], closeTo(grayToLinear[128], 0.001));
      expect(linear[2], closeTo(1.0, 0.01));
      expect(linear[3], closeTo(grayToLinear[64], 0.001));
    });

    test('length returns width * height', () {
      final GrayImage img = GrayImage(10, 20);
      expect(img.length, 200);
    });
  });

  group('RgbImage', () {
    test('toGray converts using Rec.709', () {
      final RgbImage rgb = RgbImage(1, 1);
      rgb.r[0] = 255;
      rgb.g[0] = 0;
      rgb.b[0] = 0;

      final GrayImage gray = rgb.toGray();

      // Red contributes 0.2126 linear luminance; toGray re-encodes to an
      // sRGB byte, so decode it back before checking.
      expect(grayToLinear[gray.pixels[0]], closeTo(0.2126, 0.01));
    });

    test('toGray white becomes white', () {
      final RgbImage rgb = RgbImage(1, 1);
      rgb.r[0] = 255;
      rgb.g[0] = 255;
      rgb.b[0] = 255;

      final GrayImage gray = rgb.toGray();

      expect(gray.pixels[0], closeTo(255, 2));
    });

    test('toGray black becomes black', () {
      final RgbImage rgb = RgbImage(1, 1);
      rgb.r[0] = 0;
      rgb.g[0] = 0;
      rgb.b[0] = 0;

      final GrayImage gray = rgb.toGray();

      expect(gray.pixels[0], 0);
    });

    test('luminanceAt computes Rec.709 luminance', () {
      final RgbImage rgb = RgbImage(1, 1);
      rgb.r[0] = 128;
      rgb.g[0] = 128;
      rgb.b[0] = 128;

      final double lum = rgb.luminanceAt(0);

      // Linear-light value of sRGB mid-grey.
      expect(lum, closeTo(grayToLinear[128], 0.01));
    });

    test('length returns width * height', () {
      final RgbImage rgb = RgbImage(10, 20);
      expect(rgb.length, 200);
    });
  });
}
