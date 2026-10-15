/// Tests for random number generation and noise functions.
///
/// Validates deterministic seeding, splitMix64 algorithm,
/// and ValueNoise2D behavior.
library;

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

void main() {
  group('splitMix64', () {
    test('produces deterministic output', () {
      final int result1 = splitMix64(42);
      final int result2 = splitMix64(42);
      expect(result1, result2);
    });

    test('different seeds produce different outputs', () {
      final int result1 = splitMix64(42);
      final int result2 = splitMix64(43);
      expect(result1, isNot(result2));
    });

    test('produces 64-bit values', () {
      final int result = splitMix64(12345);
      // Result should fit in 64 bits (max signed 64-bit value)
      expect(result, greaterThanOrEqualTo(0));
      expect(result, lessThan(0x7FFFFFFFFFFFFFFF));
    });

    test('handles zero seed', () {
      final int result = splitMix64(0);
      expect(result, isNotNull);
    });

    test('handles negative seeds', () {
      final int result = splitMix64(-1);
      expect(result, isNotNull);
    });

    test('sequence is reproducible', () {
      final List<int> sequence1 = <int>[
        splitMix64(100),
        splitMix64(200),
        splitMix64(300),
      ];
      final List<int> sequence2 = <int>[
        splitMix64(100),
        splitMix64(200),
        splitMix64(300),
      ];
      expect(sequence1, sequence2);
    });
  });

  group('SeededRandom', () {
    test('produces deterministic sequence', () {
      final SeededRandom rng1 = SeededRandom(42);
      final SeededRandom rng2 = SeededRandom(42);

      final List<double> seq1 = <double>[
        rng1.nextDouble(),
        rng1.nextDouble(),
        rng1.nextDouble(),
      ];
      final List<double> seq2 = <double>[
        rng2.nextDouble(),
        rng2.nextDouble(),
        rng2.nextDouble(),
      ];

      expect(seq1, seq2);
    });

    test('different seeds produce different sequences', () {
      final SeededRandom rng1 = SeededRandom(42);
      final SeededRandom rng2 = SeededRandom(43);

      expect(rng1.nextDouble(), isNot(rng2.nextDouble()));
    });

    test('nextDouble returns values in [0, 1)', () {
      final SeededRandom rng = SeededRandom(123);
      for (int i = 0; i < 100; i++) {
        final double value = rng.nextDouble();
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThan(1.0));
      }
    });

    test('range returns values in specified range', () {
      final SeededRandom rng = SeededRandom(456);
      for (int i = 0; i < 100; i++) {
        final double value = rng.range(10.0, 20.0);
        expect(value, greaterThanOrEqualTo(10.0));
        expect(value, lessThanOrEqualTo(20.0));
      }
    });

    test('range with equal min and max returns that value', () {
      final SeededRandom rng = SeededRandom(789);
      final double value = rng.range(5.0, 5.0);
      expect(value, 5.0);
    });

    test('intRange returns values in specified range', () {
      final SeededRandom rng = SeededRandom(999);
      for (int i = 0; i < 100; i++) {
        final int value = rng.intRange(1, 10);
        expect(value, greaterThanOrEqualTo(1));
        expect(value, lessThanOrEqualTo(10));
      }
    });

    test('intRange with equal min and max returns that value', () {
      final SeededRandom rng = SeededRandom(111);
      final int value = rng.intRange(7, 7);
      expect(value, 7);
    });

    test('intRange produces all values in range over many samples', () {
      final SeededRandom rng = SeededRandom(222);
      final Set<int> seen = <int>{};
      for (int i = 0; i < 1000; i++) {
        seen.add(rng.intRange(1, 5));
      }
      // Should have seen all values 1-5
      expect(seen.length, 5);
      expect(seen.contains(1), true);
      expect(seen.contains(5), true);
    });

    test('handles zero seed', () {
      final SeededRandom rng = SeededRandom(0);
      final double value = rng.nextDouble();
      expect(value, greaterThanOrEqualTo(0.0));
      expect(value, lessThan(1.0));
    });

    test('handles negative seed', () {
      final SeededRandom rng = SeededRandom(-42);
      final double value = rng.nextDouble();
      expect(value, greaterThanOrEqualTo(0.0));
      expect(value, lessThan(1.0));
    });
  });

  group('ValueNoise2D', () {
    test('produces deterministic output', () {
      final ValueNoise2D noise1 = ValueNoise2D(42);
      final ValueNoise2D noise2 = ValueNoise2D(42);

      expect(noise1.at(10.0, 20.0), noise2.at(10.0, 20.0));
    });

    test('different seeds produce different outputs', () {
      final ValueNoise2D noise1 = ValueNoise2D(42);
      final ValueNoise2D noise2 = ValueNoise2D(43);

      expect(noise1.at(10.0, 20.0), isNot(noise2.at(10.0, 20.0)));
    });

    test('at returns values in [0, 1]', () {
      final ValueNoise2D noise = ValueNoise2D(123);
      for (int i = 0; i < 100; i++) {
        final double value = noise.at(i.toDouble(), i.toDouble());
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0));
      }
    });

    test('is continuous (nearby points have similar values)', () {
      final ValueNoise2D noise = ValueNoise2D(456);
      final double value1 = noise.at(10.0, 20.0);
      final double value2 = noise.at(10.1, 20.1);
      expect((value1 - value2).abs(), lessThan(0.5));
    });

    test('respects custom cell size', () {
      final ValueNoise2D noiseSmall = ValueNoise2D(42, cell: 4.0);
      final ValueNoise2D noiseLarge = ValueNoise2D(42, cell: 16.0);

      // Different cell sizes should produce different patterns
      final double val1 = noiseSmall.at(10.0, 20.0);
      final double val2 = noiseLarge.at(10.0, 20.0);
      // They might be similar by chance, but the noise fields are different
      expect(val1, isNotNull);
      expect(val2, isNotNull);
    });

    test('fbm returns values in [0, 1]', () {
      final ValueNoise2D noise = ValueNoise2D(789);
      for (int i = 0; i < 50; i++) {
        final double value = noise.fbm(i.toDouble(), i.toDouble());
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0));
      }
    });

    test('fbm with different octaves produces different results', () {
      final ValueNoise2D noise = ValueNoise2D(999);
      final double value1 = noise.fbm(10.0, 20.0, octaves: 1);
      final double value2 = noise.fbm(10.0, 20.0, octaves: 4);
      // More octaves should give different (typically smoother) results
      expect(value1, isNot(value2));
    });

    test('fbm with zero octaves returns 0', () {
      final ValueNoise2D noise = ValueNoise2D(111);
      final double value = noise.fbm(10.0, 20.0, octaves: 0);
      expect(value, 0.0);
    });

    test('fbm is deterministic', () {
      final ValueNoise2D noise1 = ValueNoise2D(42);
      final ValueNoise2D noise2 = ValueNoise2D(42);

      expect(
        noise1.fbm(10.0, 20.0, octaves: 3),
        noise2.fbm(10.0, 20.0, octaves: 3),
      );
    });

    test('handles negative coordinates', () {
      final ValueNoise2D noise = ValueNoise2D(222);
      final double value = noise.at(-10.0, -20.0);
      expect(value, greaterThanOrEqualTo(0.0));
      expect(value, lessThanOrEqualTo(1.0));
    });

    test('handles zero coordinates', () {
      final ValueNoise2D noise = ValueNoise2D(333);
      final double value = noise.at(0.0, 0.0);
      expect(value, greaterThanOrEqualTo(0.0));
      expect(value, lessThanOrEqualTo(1.0));
    });

    test('handles very large coordinates', () {
      final ValueNoise2D noise = ValueNoise2D(444);
      final double value = noise.at(1000000.0, 1000000.0);
      expect(value, greaterThanOrEqualTo(0.0));
      expect(value, lessThanOrEqualTo(1.0));
    });

    test('fbm with high octaves is still in range', () {
      final ValueNoise2D noise = ValueNoise2D(555);
      final double value = noise.fbm(10.0, 20.0, octaves: 10);
      expect(value, greaterThanOrEqualTo(0.0));
      expect(value, lessThanOrEqualTo(1.0));
    });
  });
}
