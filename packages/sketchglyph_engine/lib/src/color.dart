library;

import 'dart:math' as math;

/// sRGB-aware image primitives shared by both engines.

/// Rec.709 red coefficient, applied in linear light.
const double kRec709Red = 0.2126;

/// Rec.709 green coefficient, applied in linear light.
const double kRec709Green = 0.7152;

/// Rec.709 blue coefficient, applied in linear light.
const double kRec709Blue = 0.0722;

const double _srgbToLinearLow = 0.04045;
const double _srgbToLinearSlope = 1 / 12.92;
const double _srgbGammaOffset = 0.055;
const double _srgbGammaScale = 1 / 1.055;
const double _srgbGammaExponent = 2.4;

/// Converts an sRGB channel value in `0..1` to linear light.
double srgbToLinear(double channel) {
  final double c = channel.clamp(0.0, 1.0);
  return c <= _srgbToLinearLow
      ? c * _srgbToLinearSlope
      : math
            .pow(
              c * _srgbGammaScale + _srgbGammaOffset * _srgbGammaScale,
              _srgbGammaExponent,
            )
            .toDouble();
}

/// Converts a linear-light value in `0..1` back to sRGB.
double linearToSrgb(double linear) {
  final double c = linear.clamp(0.0, 1.0);
  return c <= _srgbToLinearLow * _srgbToLinearSlope
      ? c / _srgbToLinearSlope
      : 1.055 * math.pow(c, 1 / _srgbGammaExponent).toDouble() - 0.055;
}

/// A single-plane 8-bit image stored row-major, values `0..255`.
class GrayImage {
  /// Creates a grey image of the given size filled with [fill].
  GrayImage(this.width, this.height, {int fill = 0})
    : pixels = List<int>.filled(width * height, fill.clamp(0, 255));

  /// Wraps an existing pixel buffer without copying.
  GrayImage.raw(this.width, this.height, this.pixels)
    : assert(width * height == 0 || pixels.length == width * height);

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Row-major grey values in `0..255`.
  final List<int> pixels;

  /// Number of pixels.
  int get length => width * height;

  /// Reads the value at [x], [y], clamping coordinates into the image.
  int at(int x, int y) {
    final int cx = x < 0 ? 0 : (x >= width ? width - 1 : x);
    final int cy = y < 0 ? 0 : (y >= height ? height - 1 : y);
    return pixels[cy * width + cx];
  }

  /// Writes [value] at [x], [y], ignoring out-of-range coordinates.
  void setAt(int x, int y, int value) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    pixels[y * width + x] = value.clamp(0, 255);
  }

  /// Copies this image.
  GrayImage clone() => GrayImage.raw(width, height, List<int>.of(pixels));

  /// Converts to linear-light values in `0..1`.
  List<double> toLinear() {
    final List<double> out = List<double>.filled(pixels.length, 0);
    for (int i = 0; i < pixels.length; i++) {
      out[i] = grayToLinear[pixels[i]];
    }
    return out;
  }
}

/// Pre-computed sRGB -> linear tables for 8-bit channels.
final List<double> grayToLinear = List<double>.generate(
  256,
  (int i) => srgbToLinear(i / 255.0),
  growable: false,
);

/// Pre-computed linear-light level (quantised to 0..255) -> sRGB byte.
final List<int> linearToGray = List<int>.generate(
  256,
  (int i) => (linearToSrgb(i / 255.0) * 255.0).round().clamp(0, 255),
  growable: false,
);

/// Planar RGBA image: one `0..255` list per channel, row-major.
class RgbImage {
  /// Creates an RGB image of the given size.
  RgbImage(this.width, this.height, {this.hasAlpha = false})
    : r = List<int>.filled(width * height, 0),
      g = List<int>.filled(width * height, 0),
      b = List<int>.filled(width * height, 0),
      a = List<int>.filled(width * height, 255);

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Whether the alpha plane carries meaningful data.
  final bool hasAlpha;

  /// Red plane.
  final List<int> r;

  /// Green plane.
  final List<int> g;

  /// Blue plane.
  final List<int> b;

  /// Alpha plane, `255` when [hasAlpha] is false.
  final List<int> a;

  /// Number of pixels.
  int get length => width * height;

  /// Rec.709 luminance in linear light, normalised to `0..1`.
  double luminanceAt(int index) =>
      kRec709Red * grayToLinear[r[index]] +
      kRec709Green * grayToLinear[g[index]] +
      kRec709Blue * grayToLinear[b[index]];

  /// Grey version carrying Rec.709 luminance, re-encoded to sRGB.
  ///
  /// Values are sRGB bytes, so [GrayImage.toLinear] recovers the linear-light
  /// luminance used by the pipeline. Encoding here is what keeps a mid-grey
  /// input a mid-grey output instead of collapsing it.
  GrayImage toGray() {
    final GrayImage gray = GrayImage(width, height);
    for (int i = 0; i < length; i++) {
      final int index = (luminanceAt(i) * 255.0).round().clamp(0, 255);
      gray.pixels[i] = linearToGray[index];
    }
    return gray;
  }
}
