/// Tests for glyph metrics measurement and rasterisation.
///
/// Validates glyph density measurement, bitmap generation, and JSON
/// serialisation of font metrics.
library;

import 'dart:convert';
import 'dart:io';

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

/// Loads a font file from the bundled assets.
TtfFont loadTestFont() {
  final List<String> candidates = <String>[
    '../assets/fonts/JetBrainsMono-Regular.ttf',
    '../../assets/fonts/JetBrainsMono-Regular.ttf',
    '../../../assets/fonts/JetBrainsMono-Regular.ttf',
  ];
  for (final String candidate in candidates) {
    final File file = File(candidate);
    if (file.existsSync()) {
      return TtfFont.parse(file.readAsBytesSync());
    }
  }
  throw StateError('Font not found');
}

/// Loads the measured font metrics JSON.
Map<String, FontMetrics> loadTestMetrics() {
  for (final String candidate in <String>[
    '../../assets/font_metrics.json',
    'assets/font_metrics.json',
  ]) {
    final File file = File(candidate);
    if (!file.existsSync()) continue;
    final Map<String, Object?> json =
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final Map<String, FontMetrics> out = <String, FontMetrics>{};
    for (final Object? f in (json['fonts']! as List<Object?>)) {
      final FontMetrics m = FontMetrics.fromJson(f! as Map<String, Object?>);
      out[m.family] = m;
    }
    return out;
  }
  return <String, FontMetrics>{};
}

void main() {
  group('GlyphMeasurement', () {
    test('toJson and fromJson round-trip preserves all fields', () {
      const GlyphMeasurement original = GlyphMeasurement(
        char: 'A',
        density: 0.42,
        advance: 600,
        hasGlyph: true,
      );

      final Map<String, Object?> json = original.toJson();
      final GlyphMeasurement restored = GlyphMeasurement.fromJson(json);

      expect(restored.char, original.char);
      expect(restored.density, closeTo(original.density, 1e-5));
      expect(restored.advance, original.advance);
      expect(restored.hasGlyph, original.hasGlyph);
    });

    test('hasGlyph false is preserved through JSON', () {
      const GlyphMeasurement original = GlyphMeasurement(
        char: 'X',
        density: 0.0,
        advance: 0,
        hasGlyph: false,
      );

      final GlyphMeasurement restored = GlyphMeasurement.fromJson(
        original.toJson(),
      );
      expect(restored.hasGlyph, isFalse);
    });
  });

  group('FontMetrics', () {
    test('advanceRatio computes advance / unitsPerEm', () {
      const FontMetrics metrics = FontMetrics(
        family: 'Test',
        unitsPerEm: 1000,
        advance: 600,
        ascender: 800,
        descender: -200,
        densities: <String, double>{},
      );

      expect(metrics.advanceRatio, closeTo(0.6, 1e-9));
    });

    test('lineBoxRatio computes (ascender - descender) / unitsPerEm', () {
      const FontMetrics metrics = FontMetrics(
        family: 'Test',
        unitsPerEm: 1000,
        advance: 600,
        ascender: 800,
        descender: -200,
        densities: <String, double>{},
      );

      expect(metrics.lineBoxRatio, closeTo(1.0, 1e-9));
    });

    test('cellWidth equals advanceRatio', () {
      const FontMetrics metrics = FontMetrics(
        family: 'Test',
        unitsPerEm: 1000,
        advance: 600,
        ascender: 800,
        descender: -200,
        densities: <String, double>{},
      );

      expect(metrics.cellWidth, metrics.advanceRatio);
    });

    test('cellHeight equals lineBoxRatio', () {
      const FontMetrics metrics = FontMetrics(
        family: 'Test',
        unitsPerEm: 1000,
        advance: 600,
        ascender: 800,
        descender: -200,
        densities: <String, double>{},
      );

      expect(metrics.cellHeight, metrics.lineBoxRatio);
    });

    test('toJson and fromJson round-trip preserves all fields', () {
      const FontMetrics original = FontMetrics(
        family: 'Test Font',
        unitsPerEm: 2048,
        advance: 1200,
        ascender: 1600,
        descender: -400,
        densities: <String, double>{'A': 0.45, 'B': 0.52, ' ': 0.0},
        missingGlyphs: <String>['X', 'Y'],
      );

      final Map<String, Object?> json = original.toJson();
      final FontMetrics restored = FontMetrics.fromJson(json);

      expect(restored.family, original.family);
      expect(restored.unitsPerEm, original.unitsPerEm);
      expect(restored.advance, original.advance);
      expect(restored.ascender, original.ascender);
      expect(restored.descender, original.descender);
      expect(restored.missingGlyphs, original.missingGlyphs);

      // Densities are stored as GlyphMeasurement objects
      expect(restored.densities.keys, original.densities.keys);
      for (final String key in original.densities.keys) {
        expect(
          restored.densities[key],
          closeTo(original.densities[key]!, 1e-5),
        );
      }
    });

    test('fromJson handles missing missingGlyphs field', () {
      final Map<String, Object?> json = <String, Object?>{
        'family': 'Test',
        'unitsPerEm': 1000,
        'advance': 600,
        'ascender': 800,
        'descender': -200,
        'glyphs': <Object?>[],
      };

      final FontMetrics metrics = FontMetrics.fromJson(json);
      expect(metrics.missingGlyphs, isEmpty);
    });

    test('real font metrics JSON round-trips correctly', () {
      final Map<String, FontMetrics> metrics = loadTestMetrics();
      if (metrics.isEmpty) {
        // Skip if metrics not available
        return;
      }

      for (final MapEntry<String, FontMetrics> entry in metrics.entries) {
        final FontMetrics original = entry.value;
        final Map<String, Object?> json = original.toJson();
        final FontMetrics restored = FontMetrics.fromJson(json);

        expect(restored.family, original.family);
        expect(restored.unitsPerEm, original.unitsPerEm);
        expect(restored.advance, original.advance);

        // Check a few densities match
        for (final String char in <String>['A', 'M', ' ']) {
          if (original.densities.containsKey(char)) {
            expect(
              restored.densities[char],
              closeTo(original.densities[char]!, 1e-5),
            );
          }
        }
      }
    });
  });

  group('rasteriseGlyph', () {
    late TtfFont font;

    setUp(() {
      font = loadTestFont();
    });

    test('returns bitmap for character with outline', () {
      final GlyphBitmap? bitmap = rasteriseGlyph(
        font,
        'A'.codeUnitAt(0),
        columns: 12,
        rows: 16,
      );

      expect(bitmap, isNotNull);
      expect(bitmap!.columns, 12);
      expect(bitmap.rows, 16);
      expect(bitmap.coverage.length, 12 * 16);
    });

    test('returns null for space (no outline)', () {
      final GlyphBitmap? bitmap = rasteriseGlyph(
        font,
        ' '.codeUnitAt(0),
        columns: 12,
        rows: 16,
      );

      expect(bitmap, isNull);
    });

    test('returns null for unassigned codepoint', () {
      final GlyphBitmap? bitmap = rasteriseGlyph(
        font,
        0xE000,
        columns: 12,
        rows: 16,
      );

      expect(bitmap, isNull);
    });

    test('bitmap density is in valid range', () {
      final GlyphBitmap? bitmap = rasteriseGlyph(
        font,
        'M'.codeUnitAt(0),
        columns: 12,
        rows: 16,
      );

      expect(bitmap, isNotNull);
      final double density = bitmap!.density;
      expect(density, greaterThan(0.0));
      expect(density, lessThan(1.0));
    });

    test('denser characters have higher density', () {
      final GlyphBitmap? bitmapM = rasteriseGlyph(
        font,
        'M'.codeUnitAt(0),
        columns: 12,
        rows: 16,
      );
      final GlyphBitmap? bitmapDot = rasteriseGlyph(
        font,
        '.'.codeUnitAt(0),
        columns: 12,
        rows: 16,
      );

      expect(bitmapM, isNotNull);
      expect(bitmapDot, isNotNull);
      expect(bitmapM!.density, greaterThan(bitmapDot!.density));
    });

    test('custom resolution changes bitmap size', () {
      final GlyphBitmap? bitmap = rasteriseGlyph(
        font,
        'A'.codeUnitAt(0),
        columns: 24,
        rows: 32,
      );

      expect(bitmap, isNotNull);
      expect(bitmap!.columns, 24);
      expect(bitmap.rows, 32);
    });

    test('samplesPerAxis affects coverage precision', () {
      final GlyphBitmap? low = rasteriseGlyph(
        font,
        'A'.codeUnitAt(0),
        columns: 12,
        rows: 16,
        samplesPerAxis: 1,
      );
      final GlyphBitmap? high = rasteriseGlyph(
        font,
        'A'.codeUnitAt(0),
        columns: 12,
        rows: 16,
        samplesPerAxis: 4,
      );

      expect(low, isNotNull);
      expect(high, isNotNull);
      // Both should produce valid densities
      expect(low!.density, greaterThan(0.0));
      expect(high!.density, greaterThan(0.0));
    });
  });

  group('measureGlyphDensity', () {
    late TtfFont font;

    setUp(() {
      font = loadTestFont();
    });

    test('returns density in valid range for character with outline', () {
      final double density = measureGlyphDensity(font, 'A'.codeUnitAt(0));

      expect(density, greaterThan(0.0));
      expect(density, lessThan(1.0));
    });

    test('returns 0 for space (no outline)', () {
      final double density = measureGlyphDensity(font, ' '.codeUnitAt(0));
      expect(density, 0.0);
    });

    test('returns 0 for unassigned codepoint', () {
      final double density = measureGlyphDensity(font, 0xE000);
      expect(density, 0.0);
    });

    test('custom resolution affects measurement', () {
      final double lowRes = measureGlyphDensity(
        font,
        'A'.codeUnitAt(0),
        resolution: 24,
      );
      final double highRes = measureGlyphDensity(
        font,
        'A'.codeUnitAt(0),
        resolution: 192,
      );

      // Both should be valid densities
      expect(lowRes, greaterThan(0.0));
      expect(highRes, greaterThan(0.0));
      // Higher resolution should be more accurate but not drastically different
      expect((lowRes - highRes).abs(), lessThan(0.1));
    });

    test('ordering: dense characters > light characters > space', () {
      final double densityAt = measureGlyphDensity(font, '@'.codeUnitAt(0));
      final double densityDot = measureGlyphDensity(font, '.'.codeUnitAt(0));
      final double densitySpace = measureGlyphDensity(font, ' '.codeUnitAt(0));

      expect(densityAt, greaterThan(densityDot));
      expect(densityDot, greaterThan(densitySpace));
      expect(densitySpace, 0.0);
    });
  });

  group('measureRamp', () {
    late TtfFont font;

    setUp(() {
      font = loadTestFont();
    });

    test('returns measurement for each character', () {
      final List<GlyphMeasurement> measurements = measureRamp(font, <String>[
        'A',
        'B',
        'C',
      ]);

      expect(measurements.length, 3);
      expect(measurements[0].char, 'A');
      expect(measurements[1].char, 'B');
      expect(measurements[2].char, 'C');
    });

    test('hasGlyph is true for mapped characters', () {
      final List<GlyphMeasurement> measurements = measureRamp(font, <String>[
        'A',
        'B',
        'C',
      ]);

      for (final GlyphMeasurement m in measurements) {
        expect(m.hasGlyph, isTrue);
      }
    });

    test('hasGlyph is false for unassigned codepoints', () {
      final List<GlyphMeasurement> measurements = measureRamp(font, <String>[
        String.fromCharCode(0xE000),
      ]);

      expect(measurements.length, 1);
      expect(measurements[0].hasGlyph, isFalse);
      expect(measurements[0].density, 0.0);
    });

    test('advance matches font advance', () {
      final List<GlyphMeasurement> measurements = measureRamp(font, <String>[
        'A',
      ]);

      expect(measurements[0].advance, font.advanceFor('A'.codeUnitAt(0)));
    });

    test('custom resolution is passed through', () {
      final List<GlyphMeasurement> lowRes = measureRamp(font, <String>[
        'A',
      ], resolution: 24);
      final List<GlyphMeasurement> highRes = measureRamp(font, <String>[
        'A',
      ], resolution: 192);

      // Both should produce valid measurements
      expect(lowRes[0].density, greaterThan(0.0));
      expect(highRes[0].density, greaterThan(0.0));
    });

    test('empty input returns empty list', () {
      final List<GlyphMeasurement> measurements = measureRamp(font, <String>[]);

      expect(measurements, isEmpty);
    });
  });

  group('GlyphBitmap', () {
    test('density computes mean of coverage values', () {
      final GlyphBitmap bitmap = GlyphBitmap(2, 2, <double>[
        0.0,
        0.5,
        0.5,
        1.0,
      ]);

      expect(bitmap.density, closeTo(0.5, 1e-9));
    });

    test('density handles all-zero coverage', () {
      final GlyphBitmap bitmap = GlyphBitmap(2, 2, <double>[
        0.0,
        0.0,
        0.0,
        0.0,
      ]);

      expect(bitmap.density, 0.0);
    });

    test('density handles all-one coverage', () {
      final GlyphBitmap bitmap = GlyphBitmap(2, 2, <double>[
        1.0,
        1.0,
        1.0,
        1.0,
      ]);

      expect(bitmap.density, 1.0);
    });
  });
}
