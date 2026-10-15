/// Deterministic resampling and pixel operations.
library;

import 'dart:math' as math;

import 'color.dart';

/// Resampling kernels available to the pipeline.
enum ResampleFilter {
  /// Integral box average over the exact cell footprint.
  box,

  /// Windowed-sinc Lanczos3 over the cell footprint.
  lanczos,
}

/// Area-average resample of a grey image to [columns] x [rows].
///
/// Never nearest-neighbour: every output cell is the weighted average of the
/// source pixels that overlap its footprint, with fractional edges handled.
List<double> areaAverage(
  GrayImage src,
  int columns,
  int rows, {
  ResampleFilter filter = ResampleFilter.box,
}) {
  final int width = src.width;
  final int height = src.height;
  final List<double> out = List<double>.filled(columns * rows, 0);
  final List<double> linear = src.toLinear();

  for (int oy = 0; oy < rows; oy++) {
    final double y0 = oy * height / rows;
    final double y1 = (oy + 1) * height / rows;
    for (int ox = 0; ox < columns; ox++) {
      final double x0 = ox * width / columns;
      final double x1 = (ox + 1) * width / columns;
      out[oy * columns + ox] = filter == ResampleFilter.box
          ? _boxAverage(linear, width, x0, x1, y0, y1)
          : _lanczosAverage(linear, width, x0, x1, y0, y1);
    }
  }
  return out;
}

double _boxAverage(
  List<double> px,
  int width,
  double x0,
  double x1,
  double y0,
  double y1,
) {
  final int ix0 = x0.floor();
  final int ix1 = math.max(x1.ceil(), ix0 + 1);
  final int iy0 = y0.floor();
  final int iy1 = math.max(y1.ceil(), iy0 + 1);
  double sum = 0;
  double wsum = 0;
  for (int y = iy0; y < iy1 && y < px.length ~/ width; y++) {
    final double wy = (math.min(y + 1.0, y1) - math.max(y.toDouble(), y0))
        .clamp(0.0, 1.0);
    if (wy <= 0) continue;
    for (int x = ix0; x < ix1 && x < width; x++) {
      final double wx = (math.min(x + 1.0, x1) - math.max(x.toDouble(), x0))
          .clamp(0.0, 1.0);
      if (wx <= 0) continue;
      final double w = wx * wy;
      sum += px[y * width + x] * w;
      wsum += w;
    }
  }
  return wsum == 0 ? 0 : sum / wsum;
}

const double _lanczosA = 3.0;

double _sinc(double x) {
  if (x.abs() < 1e-9) return 1.0;
  final double px = math.pi * x;
  return math.sin(px) / px;
}

double _lanczosWeight(double x) {
  if (x <= -_lanczosA || x >= _lanczosA) return 0;
  return _sinc(x) * _sinc(x / _lanczosA);
}

double _lanczosAverage(
  List<double> px,
  int width,
  double x0,
  double x1,
  double y0,
  double y1,
) {
  final double cx = (x0 + x1) / 2;
  final double cy = (y0 + y1) / 2;
  final double scale = math.max((x1 - x0) / 2, 1.0);
  final double scaleY = math.max((y1 - y0) / 2, 1.0);
  final int radiusX = (scale * _lanczosA).ceil();
  final int radiusY = (scaleY * _lanczosA).ceil();
  final int height = px.length ~/ width;

  double sum = 0;
  double wsum = 0;
  for (int y = (cy - radiusY).floor(); y <= (cy + radiusY).ceil(); y++) {
    if (y < 0 || y >= height) continue;
    final double wy = _lanczosWeight((y - cy) / scaleY);
    if (wy == 0) continue;
    for (int x = (cx - radiusX).floor(); x <= (cx + radiusX).ceil(); x++) {
      if (x < 0 || x >= width) continue;
      final double wx = _lanczosWeight((x - cx) / scale);
      if (wx == 0) continue;
      final double w = wx * wy;
      sum += px[y * width + x] * w;
      wsum += w;
    }
  }
  return wsum == 0 ? 0 : (sum / wsum).clamp(0.0, 1.0);
}

/// Separable Gaussian blur with standard deviation [sigma] (in pixels).
GrayImage gaussianBlur(GrayImage src, double sigma) {
  if (sigma <= 0) return src.clone();
  final int radius = math.max(1, (sigma * 3).ceil());
  final List<double> kernel = <double>[];
  double total = 0;
  for (int i = -radius; i <= radius; i++) {
    final double v = math.exp(-(i * i) / (2 * sigma * sigma));
    kernel.add(v);
    total += v;
  }
  for (int i = 0; i < kernel.length; i++) {
    kernel[i] = kernel[i] / total;
  }

  final List<double> h = List<double>.filled(src.length, 0);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      double sum = 0;
      for (int k = -radius; k <= radius; k++) {
        sum += src.at(x + k, y) * kernel[k + radius];
      }
      h[y * src.width + x] = sum;
    }
  }
  final GrayImage out = GrayImage(src.width, src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      double sum = 0;
      for (int k = -radius; k <= radius; k++) {
        sum +=
            h[((y + k).clamp(0, src.height - 1)) * src.width + x] *
            kernel[k + radius];
      }
      out.pixels[y * src.width + x] = sum.round().clamp(0, 255);
    }
  }
  return out;
}

/// Downscale so the long edge is at most [maxEdge]; keeps aspect ratio.
GrayImage downscaleGray(GrayImage src, int maxEdge) {
  final int longEdge = math.max(src.width, src.height);
  if (maxEdge <= 0 || longEdge <= maxEdge || longEdge == 0) return src.clone();
  final double factor = maxEdge / longEdge;
  final int w = math.max(1, (src.width * factor).round());
  final int h = math.max(1, (src.height * factor).round());
  final List<double> cells = areaAverage(src, w, h);
  final GrayImage out = GrayImage(w, h);
  for (int i = 0; i < cells.length; i++) {
    out.pixels[i] = (linearToGray[(cells[i] * 255).round().clamp(0, 255)]);
  }
  return out;
}

/// Unsharp mask using a Gaussian surround.
GrayImage sharpen(GrayImage src, {double amount = 0.8, double sigma = 1.5}) {
  final GrayImage blur = gaussianBlur(src, sigma);
  final GrayImage out = GrayImage(src.width, src.height);
  for (int i = 0; i < src.length; i++) {
    final double v = src.pixels[i] + (src.pixels[i] - blur.pixels[i]) * amount;
    out.pixels[i] = v.round().clamp(0, 255);
  }
  return out;
}
