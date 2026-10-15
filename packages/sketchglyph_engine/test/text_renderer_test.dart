/// Tests for ASCII text rendering and cell geometry.
///
/// Validates cell geometry calculations, PNG rendering with and without
/// glyph sources, and background handling.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    '../assets/font_metrics.json',
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
  group('AsciiCellGeometry', () {
    late FontMetrics metrics;

    setUp(() {
      metrics = const FontMetrics(
        family: 'Test',
        unitsPerEm: 1000,
        advance: 600,
        ascender: 800,
        descender: -200,
        densities: <String, double>{},
      );
    });

    test('cellWidth scales linearly with fontSize', () {
      final AsciiSettings settings1 = AsciiSettings(fontSize: 8.0);
      final AsciiSettings settings2 = AsciiSettings(fontSize: 16.0);

      final AsciiCellGeometry geo1 = AsciiCellGeometry(settings1, metrics);
      final AsciiCellGeometry geo2 = AsciiCellGeometry(settings2, metrics);

      expect(geo2.cellWidth, closeTo(geo1.cellWidth * 2, 0.01));
    });

    test('cellWidth scales linearly with dpi', () {
      final AsciiSettings settings = AsciiSettings(fontSize: 8.0);

      final AsciiCellGeometry geo96 = AsciiCellGeometry(
        settings,
        metrics,
        dpi: 96,
      );
      final AsciiCellGeometry geo192 = AsciiCellGeometry(
        settings,
        metrics,
        dpi: 192,
      );

      expect(geo192.cellWidth, closeTo(geo96.cellWidth * 2, 0.01));
    });

    test('cellWidth honours letterSpacing', () {
      final AsciiSettings settings0 = AsciiSettings(
        fontSize: 8.0,
        letterSpacing: 0.0,
      );
      final AsciiSettings settings1 = AsciiSettings(
        fontSize: 8.0,
        letterSpacing: 0.1,
      );

      final AsciiCellGeometry geo0 = AsciiCellGeometry(settings0, metrics);
      final AsciiCellGeometry geo1 = AsciiCellGeometry(settings1, metrics);

      expect(geo1.cellWidth, closeTo(geo0.cellWidth * 1.1, 0.01));
    });

    test('cellHeight scales linearly with fontSize', () {
      final AsciiSettings settings1 = AsciiSettings(fontSize: 8.0);
      final AsciiSettings settings2 = AsciiSettings(fontSize: 16.0);

      final AsciiCellGeometry geo1 = AsciiCellGeometry(settings1, metrics);
      final AsciiCellGeometry geo2 = AsciiCellGeometry(settings2, metrics);

      expect(geo2.cellHeight, closeTo(geo1.cellHeight * 2, 0.01));
    });

    test('cellHeight scales linearly with dpi', () {
      final AsciiSettings settings = AsciiSettings(fontSize: 8.0);

      final AsciiCellGeometry geo96 = AsciiCellGeometry(
        settings,
        metrics,
        dpi: 96,
      );
      final AsciiCellGeometry geo192 = AsciiCellGeometry(
        settings,
        metrics,
        dpi: 192,
      );

      expect(geo192.cellHeight, closeTo(geo96.cellHeight * 2, 0.01));
    });

    test('cellHeight honours lineHeight', () {
      final AsciiSettings settings1 = AsciiSettings(
        fontSize: 8.0,
        lineHeight: 1.0,
      );
      final AsciiSettings settings2 = AsciiSettings(
        fontSize: 8.0,
        lineHeight: 1.5,
      );

      final AsciiCellGeometry geo1 = AsciiCellGeometry(settings1, metrics);
      final AsciiCellGeometry geo2 = AsciiCellGeometry(settings2, metrics);

      expect(geo2.cellHeight, closeTo(geo1.cellHeight * 1.5, 0.01));
    });

    test('cellWidth and cellHeight use correct font metrics', () {
      final AsciiSettings settings = AsciiSettings(
        fontSize: 8.0,
        lineHeight: 1.0,
      );
      final AsciiCellGeometry geo = AsciiCellGeometry(settings, metrics);

      // advanceRatio = 600/1000 = 0.6
      // lineBoxRatio = (800 - (-200))/1000 = 1.0
      final double expectedWidth = 8.0 / 72 * 96 * 0.6;
      final double expectedHeight = 8.0 / 72 * 96 * 1.0;

      expect(geo.cellWidth, closeTo(expectedWidth, 0.01));
      expect(geo.cellHeight, closeTo(expectedHeight, 0.01));
    });
  });

  group('renderAsciiPng', () {
    late AsciiEngine engine;
    late AsciiDocument doc;

    setUp(() {
      final Map<String, FontMetrics> metrics = loadTestMetrics();
      engine = AsciiEngine(metrics.isEmpty ? <String, FontMetrics>{} : metrics);
      final RgbImage img = syntheticObject(width: 120, height: 120);
      doc = engine.render(img, AsciiSettings(columns: 40, workingLongEdge: 0));
    });

    test('produces valid PNG bytes', () {
      final Uint8List png = renderAsciiPng(doc);

      expect(png.length, greaterThan(100));
      // PNG magic number
      expect(png.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    });

    test('scale parameter affects output size', () {
      final Uint8List png1 = renderAsciiPng(doc, scale: 1.0);
      final Uint8List png2 = renderAsciiPng(doc, scale: 2.0);

      // Both should be valid PNGs
      expect(png1.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      expect(png2.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);

      // Larger scale should produce larger file (generally)
      expect(png2.length, greaterThan(png1.length));
    });

    test('transparentBackground yields alpha 0 somewhere', () {
      final Uint8List png = renderAsciiPng(doc, transparentBackground: true);

      // Decode and check for transparent pixels
      final RgbImage decoded = decodeImageBytes(png);
      bool hasTransparent = false;
      for (int i = 0; i < decoded.length; i++) {
        if (decoded.a[i] == 0) {
          hasTransparent = true;
          break;
        }
      }
      expect(hasTransparent, isTrue);
    });

    test('backgroundArgb override is respected', () {
      final Uint8List png1 = renderAsciiPng(
        doc,
        backgroundArgb: 0xFFFF0000, // Red
      );
      final Uint8List png2 = renderAsciiPng(
        doc,
        backgroundArgb: 0xFF0000FF, // Blue
      );

      // Both should be valid PNGs but different
      expect(png1, isNot(equals(png2)));
    });

    test('without glyph source uses tone squares', () {
      final Uint8List png = renderAsciiPng(doc, scale: 2.0);

      expect(png.length, greaterThan(100));
      expect(png.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    });

    test('with TtfGlyphSource uses real glyphs', () {
      final TtfFont font = loadTestFont();
      final TtfGlyphSource glyphs = TtfGlyphSource(font);

      final Uint8List png = renderAsciiPng(doc, scale: 2.0, glyphs: glyphs);

      expect(png.length, greaterThan(100));
      expect(png.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    });

    test('glyph source vs no glyph source produce different output', () {
      final TtfFont font = loadTestFont();
      final TtfGlyphSource glyphs = TtfGlyphSource(font);

      final Uint8List pngNoGlyphs = renderAsciiPng(doc, scale: 2.0);
      final Uint8List pngWithGlyphs = renderAsciiPng(
        doc,
        scale: 2.0,
        glyphs: glyphs,
      );

      expect(pngNoGlyphs, isNot(equals(pngWithGlyphs)));
    });

    test('deterministic: same doc twice produces identical bytes', () {
      final Uint8List png1 = renderAsciiPng(doc);
      final Uint8List png2 = renderAsciiPng(doc);

      expect(png1, equals(png2));
    });

    test('small cell size falls back to tone squares', () {
      // Very small font size means small cells
      final RgbImage img = syntheticObject(width: 120, height: 120);
      final AsciiDocument smallDoc = engine.render(
        img,
        AsciiSettings(columns: 40, fontSize: 2.0, workingLongEdge: 0),
      );

      final TtfFont font = loadTestFont();
      final TtfGlyphSource glyphs = TtfGlyphSource(font);

      // Should still produce valid PNG even if too small for glyphs
      final Uint8List png = renderAsciiPng(
        smallDoc,
        scale: 1.0,
        glyphs: glyphs,
      );

      expect(png.length, greaterThan(50));
    });
  });

  group('TtfGlyphSource', () {
    late TtfFont font;
    late TtfGlyphSource source;

    setUp(() {
      font = loadTestFont();
      source = TtfGlyphSource(font);
    });

    test('bitmapFor returns bitmap for character with outline', () {
      final GlyphBitmap? bitmap = source.bitmapFor('A', columns: 12, rows: 16);

      expect(bitmap, isNotNull);
      expect(bitmap!.columns, 12);
      expect(bitmap.rows, 16);
    });

    test('bitmapFor returns null for space', () {
      final GlyphBitmap? bitmap = source.bitmapFor(' ', columns: 12, rows: 16);

      expect(bitmap, isNull);
    });

    test('bitmapFor caches results', () {
      final GlyphBitmap? bitmap1 = source.bitmapFor('A', columns: 12, rows: 16);
      final GlyphBitmap? bitmap2 = source.bitmapFor('A', columns: 12, rows: 16);

      expect(bitmap1, same(bitmap2));
    });

    test('different sizes produce different cache entries', () {
      final GlyphBitmap? bitmap1 = source.bitmapFor('A', columns: 12, rows: 16);
      final GlyphBitmap? bitmap2 = source.bitmapFor('A', columns: 24, rows: 32);

      expect(bitmap1, isNot(same(bitmap2)));
      expect(bitmap1!.columns, 12);
      expect(bitmap2!.columns, 24);
    });

    test('bitmapFor returns null for unassigned codepoint', () {
      final GlyphBitmap? bitmap = source.bitmapFor(
        String.fromCharCode(0xE000),
        columns: 12,
        rows: 16,
      );

      expect(bitmap, isNull);
    });
  });

  group('AsciiDocument.toPng', () {
    late AsciiEngine engine;
    late AsciiDocument doc;

    setUp(() {
      final Map<String, FontMetrics> metrics = loadTestMetrics();
      engine = AsciiEngine(metrics.isEmpty ? <String, FontMetrics>{} : metrics);
      final RgbImage img = syntheticObject(width: 120, height: 120);
      doc = engine.render(img, AsciiSettings(columns: 40, workingLongEdge: 0));
    });

    test('delegates to renderAsciiPng', () {
      final Uint8List png1 = doc.toPng();
      final Uint8List png2 = renderAsciiPng(doc);

      expect(png1, equals(png2));
    });

    test('passes through parameters', () {
      final Uint8List png = doc.toPng(
        scale: 1.5,
        transparentBackground: true,
        backgroundArgb: 0xFF112233,
      );

      expect(png.length, greaterThan(100));
    });

    test('with glyph source parameter', () {
      final TtfFont font = loadTestFont();
      final TtfGlyphSource glyphs = TtfGlyphSource(font);

      final Uint8List png = doc.toPng(glyphs: glyphs);

      expect(png.length, greaterThan(100));
    });
  });
}
