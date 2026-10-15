/// Deterministic pseudo-random helpers so seeded jitter is reproducible.
library;

import 'dart:math' as math;

/// 64-bit splitmix64 mixer used to seed [math.Random] deterministically.
int splitMix64(int state) {
  int z = (state + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF;
  z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF;
  z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF;
  return (z ^ (z >> 31)) & 0xFFFFFFFFFFFFFFFF;
}

/// A reproducible random stream.
class SeededRandom {
  /// Creates a stream from an integer [seed].
  SeededRandom(int seed)
    : _rng = math.Random(splitMix64(seed) & 0x7FFFFFFFFFFFFFFF);

  final math.Random _rng;

  /// Uniform value in `[0, 1)`.
  double nextDouble() => _rng.nextDouble();

  /// Uniform value in `[min, max]`.
  double range(double min, double max) => min + (max - min) * _rng.nextDouble();

  /// Signed uniform value in `[-1, 1]`.
  double signed() => _rng.nextDouble() * 2 - 1;

  /// Uniform integer in `[min, max]` inclusive.
  int intRange(int min, int max) => _rng.nextInt(max - min + 1) + min;
}

/// A deterministic 2D value-noise generator (gradient-free, cheap, seeded).
class ValueNoise2D {
  /// Builds a noise field from [seed] with lattice cell size [cell].
  ValueNoise2D(int seed, {this.cell = 8.0})
    : _hashBase = splitMix64(seed) & 0x7FFFFFFFFFFFFFFF;

  /// Lattice cell size in pixels.
  final double cell;
  final int _hashBase;

  double _hash(int ix, int iy) {
    int h = _hashBase;
    h = splitMix64(h ^ (ix * 0x9E3779B185EBCA87));
    h = splitMix64(h ^ (iy * 0xC2B2AE3D27D4EB4F));
    return (h & 0xFFFFFF) / 0xFFFFFF;
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);

  /// Noise value in `[0, 1]` at continuous coordinates [x], [y].
  double at(double x, double y) {
    final double gx = x / cell;
    final double gy = y / cell;
    final int x0 = gx.floor();
    final int y0 = gy.floor();
    final double tx = _smooth(gx - x0);
    final double ty = _smooth(gy - y0);
    final double v00 = _hash(x0, y0);
    final double v10 = _hash(x0 + 1, y0);
    final double v01 = _hash(x0, y0 + 1);
    final double v11 = _hash(x0 + 1, y0 + 1);
    final double a = v00 + (v10 - v00) * tx;
    final double b = v01 + (v11 - v01) * tx;
    return a + (b - a) * ty;
  }

  /// Fractal sum of [octaves] octaves, normalised to `[0, 1]`.
  double fbm(double x, double y, {int octaves = 4}) {
    double sum = 0;
    double amp = 1;
    double freq = 1;
    double norm = 0;
    for (int i = 0; i < octaves; i++) {
      sum += at(x * freq, y * freq) * amp;
      norm += amp;
      amp *= 0.5;
      freq *= 2;
    }
    return norm == 0 ? 0 : sum / norm;
  }
}
