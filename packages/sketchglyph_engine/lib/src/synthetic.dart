/// Procedurally generated reference images so visual proof needs no binary
/// assets in git, and so tests have deterministic inputs.
library;

import 'dart:math' as math;

import 'color.dart';

/// A stylised portrait: head, hair, eyes, nose, mouth, neck and shoulders, with
/// smooth shading so tone mapping is visible.
RgbImage syntheticPortrait({int width = 480, int height = 600}) {
  final RgbImage out = RgbImage(width, height);
  final double cx = width * 0.5;
  final double cy = height * 0.42;
  final double faceR = math.min(width, height) * 0.28;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = y * width + x;
      // Background: vertical gradient, lighter at the top.
      double lum = 0.78 - 0.45 * (y / height);
      double sat = 0.12;
      double hue = 0.58;

      final double dx = (x - cx) / faceR;
      final double dy = (y - cy) / (faceR * 1.28);
      final double faceDist = math.sqrt(dx * dx + dy * dy);

      // Skin with a light source from the upper left.
      if (faceDist < 1) {
        final double shade = 0.92 - 0.5 * math.max(0, (dx * 0.6 + dy * 0.4));
        lum = shade.clamp(0.18, 0.95);
        sat = 0.34;
        hue = 0.07;
      }

      // Hair mass above and around the head.
      final double hairDy = (y - (cy - faceR * 0.55)) / (faceR * 0.95);
      final double hairDx = (x - cx) / (faceR * 1.06);
      final double hair = math.sqrt(hairDx * hairDx + hairDy * hairDy);
      if (hair < 1 && (y < cy || faceDist > 0.92)) {
        lum = 0.12 + 0.18 * (1 - hair);
        sat = 0.25;
        hue = 0.09;
      }

      // Eyes.
      for (final int side in <int>[-1, 1]) {
        final double ex = cx + side * faceR * 0.42;
        final double ey = cy - faceR * 0.12;
        final double d = math.sqrt(
          math.pow((x - ex) / (faceR * 0.19), 2) +
              math.pow((y - ey) / (faceR * 0.1), 2),
        );
        if (d < 1) {
          lum = 0.16 + 0.25 * d;
          sat = 0.1;
          hue = 0.6;
        }
        // Brow.
        final double bd =
            (y - (ey - faceR * 0.3)).abs() / (faceR * 0.05) +
            ((x - ex).abs() / (faceR * 0.26)).clamp(0, 4);
        if (bd < 1) lum = math.min(lum, 0.22);
      }

      // Nose shadow.
      final double nose =
          (x - cx).abs() / (faceR * 0.08) +
          ((y - (cy + faceR * 0.16)) / (faceR * 0.3)).abs();
      if (nose < 1 && x > cx) {
        lum = math.min(lum, 0.92 - 0.42 * (1 - nose));
      }

      // Mouth.
      final double mouth = math.sqrt(
        math.pow((x - cx) / (faceR * 0.34), 2) +
            math.pow((y - (cy + faceR * 0.55)) / (faceR * 0.08), 2),
      );
      if (mouth < 1) {
        lum = 0.3 + 0.2 * mouth;
        hue = 0.99;
        sat = 0.45;
      }

      // Neck and shoulders.
      if (y > cy + faceR * 0.95) {
        final double shoulder = (y - (cy + faceR * 0.95)) / (height * 0.25);
        final double wide = (x - cx).abs() / (width * 0.5);
        if (y < cy + faceR * 1.5 && wide < 0.22) {
          lum = 0.55 - 0.2 * shoulder;
          hue = 0.07;
          sat = 0.3;
        } else {
          lum = 0.3 - 0.12 * wide;
          hue = 0.62;
          sat = 0.3;
        }
      }

      // Soft directional light on everything.
      lum *= 0.86 + 0.2 * (1 - x / width);
      final _Hsl hsl = _hslToRgb(hue, sat, lum.clamp(0.0, 1.0));
      out.r[i] = hsl.r;
      out.g[i] = hsl.g;
      out.b[i] = hsl.b;
    }
  }
  return out;
}

/// A landscape: sky gradient, sun, distant ridge, mid ridge, lake with
/// horizontal reflections.
RgbImage syntheticLandscape({int width = 800, int height = 500}) {
  final RgbImage out = RgbImage(width, height);
  final int horizon = (height * 0.52).round();
  final List<double> ridgeA = _ridge(
    width,
    amplitude: height * 0.09,
    base: horizon - height * 0.05,
    cycles: 2.2,
    phase: 0.4,
  );
  final List<double> ridgeB = _ridge(
    width,
    amplitude: height * 0.14,
    base: horizon - height * 0.01,
    cycles: 1.3,
    phase: 2.1,
  );

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = y * width + x;
      double lum, sat, hue;
      if (y < horizon) {
        final double t = y / horizon;
        lum = 0.18 + 0.62 * t;
        sat = 0.55 - 0.35 * t;
        hue = 0.62 - 0.08 * t;
        // Sun.
        final double sx = width * 0.68, sy = horizon * 0.42;
        final double d = math.sqrt((x - sx) * (x - sx) + (y - sy) * (y - sy));
        if (d < height * 0.07) {
          lum = 0.97;
          sat = 0.25;
          hue = 0.12;
        } else if (d < height * 0.2) {
          lum = math.min(0.97, lum + 0.35 * (1 - d / (height * 0.2)));
          hue = 0.11;
          sat = 0.4;
        }
      } else {
        // Water with banded reflections.
        final double t = (y - horizon) / (height - horizon);
        final double ripple =
            0.5 + 0.5 * math.sin(y * 0.9 + math.sin(x * 0.03) * 2);
        lum = 0.42 - 0.3 * t + 0.1 * ripple * (1 - t);
        sat = 0.4;
        hue = 0.55;
        // Sun glint column.
        final double dx = (x - width * 0.68).abs() / (width * 0.06);
        if (dx < 1) {
          lum = math.min(0.96, lum + 0.45 * (1 - dx) * (1 - t));
          hue = 0.12;
          sat = 0.3;
        }
      }

      // Ridges: nearer is darker.
      if (y < horizon && y > ridgeA[x]) {
        lum = 0.34 - 0.05 * (y - ridgeA[x]) / height;
        sat = 0.28;
        hue = 0.58;
      }
      if (y >= horizon && y < ridgeB[x]) {
        lum = 0.16;
        sat = 0.2;
        hue = 0.6;
      }

      final _Hsl c = _hslToRgb(hue, sat, lum.clamp(0.0, 1.0));
      out.r[i] = c.r;
      out.g[i] = c.g;
      out.b[i] = c.b;
    }
  }
  return out;
}

/// A still-life object: a sphere with specular highlight on a table plane.
RgbImage syntheticObject({int width = 600, int height = 600}) {
  final RgbImage out = RgbImage(width, height);
  final double cx = width * 0.48, cy = height * 0.44;
  final double r = math.min(width, height) * 0.3;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = y * width + x;
      final double dx = (x - cx) / r;
      final double dy = (y - cy) / r;
      final double d2 = dx * dx + dy * dy;
      double lum, sat, hue;

      if (d2 < 1) {
        final double nz = math.sqrt(1 - d2);
        // Diffuse from an upper-left light.
        final double ndl = (-0.5 * dx - 0.5 * dy + 0.72 * nz).clamp(0.0, 1.0);
        lum = 0.08 + 0.72 * ndl;
        // Specular.
        final double spec = math.pow(ndl, 28).toDouble();
        lum = math.min(0.99, lum + 0.85 * spec);
        sat = 0.6 - 0.3 * spec;
        hue = 0.05 + 0.02 * ndl;
      } else {
        final double t = (y - height * 0.5).abs() / height;
        lum = y > cy + r ? 0.55 - t * 0.3 : 0.8 - t * 0.2;
        sat = 0.12;
        hue = 0.09;
        // Cast shadow ellipse under the sphere.
        final double sx = (x - cx - r * 0.35) / (r * 1.25);
        final double sy = (y - (cy + r * 1.06)) / (r * 0.3);
        final double sd = sx * sx + sy * sy;
        if (sd < 1) {
          lum = math.min(lum, 0.16 + 0.28 * sd);
          sat = 0.16;
          hue = 0.1;
        }
      }
      final _Hsl c = _hslToRgb(hue, sat, lum.clamp(0.0, 1.0));
      out.r[i] = c.r;
      out.g[i] = c.g;
      out.b[i] = c.b;
    }
  }
  return out;
}

/// Left-to-right black-to-white linear ramp, [height] rows tall.
RgbImage gradientStrip({
  int width = 256,
  int height = 32,
  bool gammaEncoded = true,
}) {
  final RgbImage out = RgbImage(width, height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final double t = x / (width - 1);
      // Store linear ramps directly (no sRGB encoding) for numeric assertions.
      final int v = gammaEncoded
          ? ((linearToSrgb(t) * 255).round().clamp(0, 255))
          : (t * 255).round().clamp(0, 255);
      final int i = y * width + x;
      out.r[i] = v;
      out.g[i] = v;
      out.b[i] = v;
    }
  }
  return out;
}

/// Checkerboard with [cells] squares per side.
RgbImage checkerboard({
  int size = 256,
  int cells = 8,
  int dark = 0,
  int light = 255,
}) {
  final RgbImage out = RgbImage(size, size);
  final int cell = size ~/ cells;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final bool on = ((x ~/ cell) + (y ~/ cell)) % 2 == 0;
      final int v = on ? light : dark;
      final int i = y * size + x;
      out.r[i] = v;
      out.g[i] = v;
      out.b[i] = v;
    }
  }
  return out;
}

List<double> _ridge(
  int width, {
  required double amplitude,
  required double base,
  required double cycles,
  required double phase,
}) {
  return <double>[
    for (int x = 0; x < width; x++)
      base -
          amplitude *
              (0.5 + 0.5 * math.sin(x / width * math.pi * 2 * cycles + phase)) -
          amplitude *
              0.35 *
              (0.5 +
                  0.5 *
                      math.sin(
                        x / width * math.pi * 2 * cycles * 2.7 + phase * 3,
                      )),
  ];
}

class _Hsl {
  const _Hsl(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;
}

_Hsl _hslToRgb(double h, double s, double l) {
  h = h % 1.0;
  if (h < 0) h += 1;
  final double c = (1 - (2 * l - 1).abs()) * s;
  final double x = c * (1 - ((h * 6) % 2 - 1).abs());
  final double m = l - c / 2;
  double r = 0, g = 0, b = 0;
  final int sector = (h * 6).floor() % 6;
  switch (sector) {
    case 0:
      r = c;
      g = x;
      b = 0;
    case 1:
      r = x;
      g = c;
      b = 0;
    case 2:
      r = 0;
      g = c;
      b = x;
    case 3:
      r = 0;
      g = x;
      b = c;
    case 4:
      r = x;
      g = 0;
      b = c;
    default:
      r = c;
      g = 0;
      b = x;
  }
  return _Hsl(
    ((r + m) * 255).round().clamp(0, 255),
    ((g + m) * 255).round().clamp(0, 255),
    ((b + m) * 255).round().clamp(0, 255),
  );
}
