/// Tests for color space conversions and image operations.
///
/// Validates sRGB/linear conversions, Rec.709 luminance calculations,
/// and image manipulation edge cases.
library;

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

void main() {
  group('srgbToLinear', () {
    test('converts black correctly', () {
      expect(srgbToLinear(0.0), closeTo(0.0, 1e-9));
    });

    test('converts white correctly', () {
      expect(srgbToLinear(1.0), closeTo(1.0, 1e-9));
    });

    test('converts mid-grey correctly', () {
      final double linear = srgbToLinear(0.5);
      expect(linear, greaterThan(0.0));
      expect(linear, lessThan(1.0));
      // sRGB 0.5 should be around 0.214 in linear
      expect(linear, closeTo(0.214, 0.01));
    });

    test('is monotonic', () {
      double prev = 0.0;
      for (int i = 0; i <= 255; i++) {
        final double linear = srgbToLinear(i / 255.0);
        expect(linear, greaterThanOrEqualTo(prev));
        prev = linear;
      }
    });

    test('clamps values outside 0-1', () {
      expect(srgbToLinear(-0.5), closeTo(0.0, 1e-9));
      expect(srgbToLinear(1.5), closeTo(1.0, 1e-9));
    });

    test('handles low values with linear segment', () {
      // Below 0.04045, sRGB uses linear scaling
      final double low = srgbToLinear(0.02);
      expect(low, closeTo(0.02 / 12.92, 1e-6));
    });

    test('handles high values with gamma curve', () {
      // Above 0.04045, sRGB uses power curve
      final double high = srgbToLinear(0.5);
      expect(high, greaterThan(0.0));
    });
  });

  group('linearToSrgb', () {
    test('converts black correctly', () {
      expect(linearToSrgb(0.0), closeTo(0.0, 1e-9));
    });

    test('converts white correctly', () {
      expect(linearToSrgb(1.0), closeTo(1.0, 1e-9));
    });

    test('is monotonic', () {
      double prev = 0.0;
      for (int i = 0; i <= 255; i++) {
        final double srgb = linearToSrgb(i / 255.0);
        expect(srgb, greaterThanOrEqualTo(prev));
        prev = srgb;
      }
    });

    test('clamps values outside 0-1', () {
      expect(linearToSrgb(-0.5), closeTo(0.0, 1e-9));
      expect(linearToSrgb(1.5), closeTo(1.0, 1e-9));
    });

    test('round-trips with srgbToLinear', () {
      for (int i = 0; i <= 255; i++) {
        final double srgb = i / 255.0;
        final double linear = srgbToLinear(srgb);
        final double back = linearToSrgb(linear);
        expect(back, closeTo(srgb, 0.01));
      }
    });
  });

  group('grayToLinear', () {
    test('has 256 entries', () {
      expect(grayToLinear.length, 256);
    });

    test('starts at 0', () {
      expect(grayToLinear[0], closeTo(0.0, 1e-9));
    });

    test('ends at 1', () {
      expect(grayToLinear[255], closeTo(1.0, 1e-9));
    });

    test('is monotonic', () {
      for (int i = 1; i < 256; i++) {
        expect(grayToLinear[i], greaterThanOrEqualTo(grayToLinear[i - 1]));
      }
    });

    test('matches srgbToLinear for all values', () {
      for (int i = 0; i < 256; i++) {
        final double expected = srgbToLinear(i / 255.0);
        expect(grayToLinear[i], closeTo(expected, 1e-9));
      }
    });
  });

  group('linearToGray', () {
    test('has 256 entries', () {
      expect(linearToGray.length, 256);
    });

    test('starts at 0', () {
      expect(linearToGray[0], 0);
    });

    test('ends at 255', () {
      expect(linearToGray[255], 255);
    });

    test('is monotonic', () {
      for (int i = 1; i < 256; i++) {
        expect(linearToGray[i], greaterThanOrEqualTo(linearToGray[i - 1]));
      }
    });

    test('values are in 0-255 range', () {
      for (final int v in linearToGray) {
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(255));
      }
    });
  });

  group('Rec.709 coefficients', () {
    test('sum to 1.0', () {
      final double sum = kRec709Red + kRec709Green + kRec709Blue;
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('green has highest weight', () {
      expect(kRec709Green, greaterThan(kRec709Red));
      expect(kRec709Green, greaterThan(kRec709Blue));
    });

    test('red has middle weight', () {
      expect(kRec709Red, greaterThan(kRec709Blue));
    });

    test('have expected values', () {
      expect(kRec709Red, closeTo(0.2126, 1e-4));
      expect(kRec709Green, closeTo(0.7152, 1e-4));
      expect(kRec709Blue, closeTo(0.0722, 1e-4));
    });
  });

  group('GrayImage', () {
    test('creates with default fill', () {
      final GrayImage img = GrayImage(10, 10);
      for (final int v in img.pixels) {
        expect(v, 0);
      }
    });

    test('creates with custom fill', () {
      final GrayImage img = GrayImage(10, 10, fill: 128);
      for (final int v in img.pixels) {
        expect(v, 128);
      }
    });

    test('clamps fill value', () {
      final GrayImage img = GrayImage(10, 10, fill: 300);
      for (final int v in img.pixels) {
        expect(v, 255);
      }
    });

    test('has correct dimensions', () {
      final GrayImage img = GrayImage(20, 30);
      expect(img.width, 20);
      expect(img.height, 30);
      expect(img.pixels.length, 600);
    });

    test('at returns pixel value', () {
      final GrayImage img = GrayImage(10, 10, fill: 100);
      expect(img.at(5, 5), 100);
    });

    test('setAt sets pixel value', () {
      final GrayImage img = GrayImage(10, 10);
      img.setAt(5, 5, 200);
      expect(img.at(5, 5), 200);
    });

    test('setAt clamps value', () {
      final GrayImage img = GrayImage(10, 10);
      img.setAt(5, 5, 300);
      expect(img.at(5, 5), 255);
    });

    test('clone creates independent copy', () {
      final GrayImage original = GrayImage(10, 10, fill: 100);
      final GrayImage copy = original.clone();
      copy.setAt(5, 5, 200);
      expect(original.at(5, 5), 100);
      expect(copy.at(5, 5), 200);
    });

    test('toLinear converts to linear space', () {
      final GrayImage img = GrayImage(2, 2);
      img.pixels[0] = 0;
      img.pixels[1] = 128;
      img.pixels[2] = 255;
      img.pixels[3] = 64;

      final List<double> linear = img.toLinear();
      expect(linear.length, 4);
      expect(linear[0], closeTo(0.0, 1e-9));
      expect(linear[2], closeTo(1.0, 1e-9));
    });
  });

  group('RgbImage', () {
    test('creates with correct dimensions', () {
      final RgbImage img = RgbImage(20, 30);
      expect(img.width, 20);
      expect(img.height, 30);
      expect(img.r.length, 600);
      expect(img.g.length, 600);
      expect(img.b.length, 600);
      expect(img.a.length, 600);
    });

    test('initializes channels to zero', () {
      final RgbImage img = RgbImage(10, 10);
      for (int i = 0; i < img.length; i++) {
        expect(img.r[i], 0);
        expect(img.g[i], 0);
        expect(img.b[i], 0);
        expect(img.a[i], 255);
      }
    });

    test('luminanceAt computes Rec.709 luminance', () {
      final RgbImage img = RgbImage(1, 1);
      img.r[0] = 255;
      img.g[0] = 0;
      img.b[0] = 0;

      final double lum = img.luminanceAt(0);
      expect(lum, closeTo(kRec709Red, 1e-6));
    });

    test('luminanceAt for white is 1.0', () {
      final RgbImage img = RgbImage(1, 1);
      img.r[0] = 255;
      img.g[0] = 255;
      img.b[0] = 255;

      final double lum = img.luminanceAt(0);
      expect(lum, closeTo(1.0, 0.01));
    });

    test('luminanceAt for black is 0.0', () {
      final RgbImage img = RgbImage(1, 1);
      img.r[0] = 0;
      img.g[0] = 0;
      img.b[0] = 0;

      final double lum = img.luminanceAt(0);
      expect(lum, closeTo(0.0, 1e-9));
    });

    test('toGray converts to grayscale', () {
      final RgbImage rgb = RgbImage(2, 2);
      rgb.r[0] = 255;
      rgb.g[0] = 0;
      rgb.b[0] = 0;

      rgb.r[1] = 0;
      rgb.g[1] = 255;
      rgb.b[1] = 0;

      rgb.r[2] = 0;
      rgb.g[2] = 0;
      rgb.b[2] = 255;

      rgb.r[3] = 128;
      rgb.g[3] = 128;
      rgb.b[3] = 128;

      final GrayImage gray = rgb.toGray();
      expect(gray.width, 2);
      expect(gray.height, 2);
      expect(gray.pixels.length, 4);

      // Green should have highest luminance
      expect(gray.pixels[1], greaterThan(gray.pixels[0]));
      expect(gray.pixels[1], greaterThan(gray.pixels[2]));
    });

    test('toGray preserves dimensions', () {
      final RgbImage rgb = RgbImage(20, 30);
      final GrayImage gray = rgb.toGray();
      expect(gray.width, 20);
      expect(gray.height, 30);
    });
  });
}
