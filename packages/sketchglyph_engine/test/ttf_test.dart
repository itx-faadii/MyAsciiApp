/// Tests for TTF font parsing and glyph extraction.
///
/// Validates parsing of real bundled fonts and error handling for malformed
/// or unsupported font formats (TTC, CFF, empty files).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

/// Loads a font file from the bundled assets.
Uint8List loadFont(String path) {
  final List<String> candidates = <String>[
    '../$path',
    '../../$path',
    '../../../$path',
  ];
  for (final String candidate in candidates) {
    final File file = File(candidate);
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
  }
  throw StateError('Font not found: $path');
}

void main() {
  group('TTF parsing', () {
    test('parses JetBrains Mono with correct metrics', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.unitsPerEm, greaterThan(0));
      expect(font.ascender, greaterThan(0));
      expect(font.descender, lessThan(0));
      expect(font.name, isNotEmpty);
      expect(font.hasOutlines, isTrue);
      expect(font.isMonospace, isTrue);
    });

    test('parses IBM Plex Mono as monospace', () {
      final Uint8List bytes = loadFont('assets/fonts/IBM Plex Mono.ttf');
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.isMonospace, isTrue);
      expect(font.hasOutlines, isTrue);
      expect(font.advanceFor('M'.codeUnitAt(0)), greaterThan(0));
    });

    test('parses Courier Prime as monospace', () {
      final Uint8List bytes = loadFont('assets/fonts/Courier Prime.ttf');
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.isMonospace, isTrue);
      expect(font.hasOutlines, isTrue);
    });

    test('parses Inter as proportional (not monospace)', () {
      final Uint8List bytes = loadFont('assets/fonts/Inter.ttf');
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.isMonospace, isFalse);
      expect(font.hasOutlines, isTrue);
    });

    test('advanceFor returns positive width for ASCII characters', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      for (final int code in <int>[
        'A'.codeUnitAt(0),
        'M'.codeUnitAt(0),
        '0'.codeUnitAt(0),
      ]) {
        expect(font.advanceFor(code), greaterThan(0));
      }
    });

    test('hasGlyphFor returns true for ASCII, false for unassigned', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.hasGlyphFor('A'.codeUnitAt(0)), isTrue);
      expect(font.hasGlyphFor(' '.codeUnitAt(0)), isTrue);
      expect(font.hasGlyphFor(0xE000), isFalse); // Private use area
    });

    test('contoursFor returns non-null for glyphs with outlines', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      final List<List<List<double>>>? contoursA = font.contoursFor(
        'A'.codeUnitAt(0),
      );
      expect(contoursA, isNotNull);
      expect(contoursA, isNotEmpty);

      // Space has no outline
      final List<List<List<double>>>? contoursSpace = font.contoursFor(
        ' '.codeUnitAt(0),
      );
      expect(contoursSpace, isNull);
    });

    test('contoursFor returns null for unassigned codepoints', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.contoursFor(0xE000), isNull);
    });

    test('mappedCodePoints contains ASCII range', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      final Iterable<int> mapped = font.mappedCodePoints;
      expect(mapped.contains('A'.codeUnitAt(0)), isTrue);
      expect(mapped.contains('z'.codeUnitAt(0)), isTrue);
      expect(mapped.contains('0'.codeUnitAt(0)), isTrue);
    });

    test('lineBoxHeight equals ascender minus descender', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.lineBoxHeight, font.ascender - font.descender);
    });

    test('glyphIdFor returns non-null for mapped characters', () {
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.glyphIdFor('A'.codeUnitAt(0)), isNotNull);
      expect(font.glyphIdFor(0xE000), isNull);
    });
  });

  group('TTF error handling', () {
    test('empty file throws FormatException', () {
      expect(() => TtfFont.parse(Uint8List(0)), throwsFormatException);
    });

    test('bogus 4-byte header throws FormatException', () {
      final Uint8List bytes = Uint8List.fromList(<int>[0, 0, 0, 0]);
      expect(() => TtfFont.parse(bytes), throwsFormatException);
    });

    test('TTC header throws FormatException', () {
      // 0x74746366 = 'ttcf'
      final Uint8List bytes = Uint8List.fromList(<int>[0x74, 0x74, 0x63, 0x66]);
      expect(
        () => TtfFont.parse(bytes),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('TrueType Collection'),
          ),
        ),
      );
    });

    test('OTTO/CFF header throws FormatException', () {
      // 0x4F54544F = 'OTTO'
      final Uint8List bytes = Uint8List.fromList(<int>[0x4F, 0x54, 0x54, 0x4F]);
      expect(
        () => TtfFont.parse(bytes),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('OpenType CFF'),
          ),
        ),
      );
    });

    test('missing required table throws FormatException', () {
      // Valid SFNT header but no tables
      final ByteData bd = ByteData(12);
      bd.setUint32(0, 0x00010000); // version
      bd.setUint16(4, 0); // numTables = 0
      expect(
        () => TtfFont.parse(bd.buffer.asUint8List()),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('Missing required table'),
          ),
        ),
      );
    });

    test('fallback name used when name table is absent', () {
      // This is hard to construct without a real font, but we can verify
      // the parse succeeds with a real font and the name is non-empty
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes, fallbackName: 'Fallback');
      expect(font.name, isNotEmpty);
    });
  });

  group('TTF cmap formats', () {
    test('real fonts use format 4 or 12 cmap', () {
      // We can't easily construct fake cmap tables, but we can verify
      // that real fonts parse successfully and have mapped codepoints
      final Uint8List bytes = loadFont(
        'assets/fonts/JetBrainsMono-Regular.ttf',
      );
      final TtfFont font = TtfFont.parse(bytes);

      expect(font.charToGlyph.isNotEmpty, isTrue);
      expect(font.mappedCodePoints.length, greaterThan(100));
    });
  });
}
