import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

/// Loads the committed measured font metrics written by
/// `tool/measure_fonts.dart`. Tests that need real measured ramps skip
/// themselves with a clear message when the asset is absent.
Map<String, FontMetrics> loadMeasuredMetrics() {
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

/// Metrics injected by the golden tool/test harness.
final Map<String, FontMetrics> measuredMetrics = loadMeasuredMetrics();

RgbImage grayRampImage(int width, int height) {
  final RgbImage img = RgbImage(width, height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = y * width + x;
      // Store linear-light values directly so assertions are exact.
      final int v = (x / (width - 1) * 255).round().clamp(0, 255);
      img.r[i] = v;
      img.g[i] = v;
      img.b[i] = v;
    }
  }
  return img;
}

Uint8List pngOf(RgbImage img) => encodePngBytes(img);

void main() {
  group('luminance', () {
    test('uses Rec.709 coefficients in linear light', () {
      final RgbImage img = RgbImage(1, 1);
      img.r[0] = 255;
      img.g[0] = 0;
      img.b[0] = 0;
      expect(img.luminanceAt(0), closeTo(kRec709Red, 1e-9));

      final RgbImage white = RgbImage(1, 1)
        ..r[0] = 255
        ..g[0] = 255
        ..b[0] = 255;
      expect(white.luminanceAt(0), closeTo(1.0, 1e-9));

      final RgbImage green = RgbImage(1, 1)
        ..r[0] = 0
        ..g[0] = 255
        ..b[0] = 0;
      // Naive sRGB-space averaging would give 0.587; linear Rec.709 gives
      // 0.7152. The difference is the point of the test.
      expect(green.luminanceAt(0), closeTo(kRec709Green, 1e-9));
      expect(green.luminanceAt(0), greaterThan(0.7));
    });

    test('grey of equal channels equals that channel', () {
      final RgbImage img = RgbImage(4, 4);
      for (int i = 0; i < img.length; i++) {
        img.r[i] = 128;
        img.g[i] = 128;
        img.b[i] = 128;
      }
      final GrayImage gray = img.toGray();
      for (final int v in gray.pixels) {
        expect(v, 128);
      }
    });

    test('sRGB round trip is monotonic and near-exact', () {
      double? previous;
      for (int i = 0; i < 256; i++) {
        final double linear = grayToLinear[i];
        if (previous != null) expect(linear, greaterThan(previous));
        previous = linear;
        // The exact inverse is the float pair; `linearToGray` cannot be a
        // perfect bijection because it quantises the linear scale to /255.
        expect(
          linearToSrgb(linear) * 255.0,
          closeTo(i.toDouble(), 1e-6),
          reason: 'level $i',
        );
      }
    });

    test('linearToGray round-trips to the original linear level', () {
      // `linearToGray` is indexed by the linear level quantised to /255, so
      // the exact sRGB byte cannot always round-trip. What the pipeline relies
      // on is that the encoded byte re-linearises back to the source luminance
      // within one LUT step.
      for (int i = 0; i < 256; i++) {
        final double linear = grayToLinear[i];
        final int index = (linear * 255.0).round().clamp(0, 255);
        final double back = grayToLinear[linearToGray[index]];
        expect(
          (back - linear).abs(),
          lessThanOrEqualTo(1.5 / 255.0),
          reason: 'level $i (linear $linear) -> index $index',
        );
      }
    });
  });

  group('ramp ordering', () {
    test('buildRamp sorts by supplied density, stable on ties', () {
      const Map<String, double> density = <String, double>{
        ' ': 0,
        '.': 0.02,
        '#': 0.4,
        '@': 0.6,
      };
      final List<String> ramp = buildRamp(<String>[
        '@',
        '#',
        ' ',
        '.',
      ], (String c) => density[c]!);
      expect(ramp.join(), ' .#@');
    });

    test('buildRamp de-duplicates', () {
      final List<String> ramp = buildRamp(<String>[
        'a',
        'a',
        'b',
      ], (String c) => c == 'a' ? 0.1 : 0.9);
      expect(ramp.length, 2);
    });

    test('measured fonts order the default ramp light to dark', () {
      if (measuredMetrics.isEmpty) {
        fail(
          'assets/font_metrics.json is missing — run '
          'dart tool/measure_fonts.dart and commit the asset.',
        );
      }
      measuredMetrics.forEach((String family, FontMetrics m) {
        double? previous;
        String? previousChar;
        final List<String> chars = kDefaultRamp.runes
            .map(String.fromCharCode)
            .where((String c) => m.densities.containsKey(c))
            .toList();
        // The ramp is sorted by measured density before use; verify the sorted
        // result is non-decreasing.
        final List<String> sorted = buildRamp(
          chars,
          (String c) => m.densities[c]!,
        );
        for (final String c in sorted) {
          final double d = m.densities[c]!;
          if (previous != null) {
            expect(
              d,
              greaterThanOrEqualTo(previous),
              reason:
                  '$family: "$c" should not be lighter than "$previousChar"',
            );
          }
          previous = d;
          previousChar = c;
        }
        expect(sorted.first, ' ', reason: '$family: space must be lightest');
      });
    });

    test('measured density: space is zero, dense glyphs are heavier', () {
      if (measuredMetrics.isEmpty) {
        fail('assets/font_metrics.json is missing');
      }
      measuredMetrics.forEach((String family, FontMetrics m) {
        expect(m.densities[' '], 0, reason: family);
        for (final String light in <String>['.', ',', '`', '\'']) {
          final double? l = m.densities[light];
          final double? heavy = m.densities['@'];
          if (l != null && heavy != null) {
            expect(l, lessThan(heavy), reason: '$family: "$light" vs @');
          }
        }
      });
    });
  });

  group('aspect correction', () {
    test('grid rows compensate for a non-square text cell', () {
      final FontMetrics metrics = FontMetrics(
        family: 'test-mono',
        unitsPerEm: 1000,
        advance: 500,
        ascender: 800,
        descender: -200,
        densities: const <String, double>{},
      );
      // Cell is 0.5em wide by 1.0em tall at lineHeight 1.0 => aspect 0.5.
      final AsciiEngine engine = AsciiEngine(<String, FontMetrics>{
        'test-mono': metrics,
      });
      final RgbImage square = RgbImage(200, 200);
      final AsciiDocument doc = engine.render(
        square,
        AsciiSettings(
          font: 'test-mono',
          columns: 80,
          lineHeight: 1.0,
          workingLongEdge: 0,
        ),
      );
      // A square source over an aspect-0.5 cell must produce twice as many
      // columns as rows, otherwise the art is stretched.
      expect(doc.columns, 80);
      expect(doc.rows, 40);
      expect(doc.columns * 0.5 / doc.rows, closeTo(1.0, 0.05));
    });

    test('landscape sources yield fewer rows than columns', () {
      final AsciiEngine engine = AsciiEngine(<String, FontMetrics>{});
      final RgbImage wide = RgbImage(400, 100);
      final AsciiDocument doc = engine.render(
        wide,
        AsciiSettings(columns: 100, workingLongEdge: 0),
      );
      expect(doc.columns, 100);
      expect(doc.rows, lessThan(doc.columns));
    });
  });

  group('area averaging', () {
    test('is not nearest neighbour: a 2x average is exact', () {
      final GrayImage src = GrayImage(4, 2);
      for (int i = 0; i < 4; i++) {
        src.pixels[i] = 0;
        src.pixels[4 + i] = 255;
      }
      // Column average of a vertical split must interpolate, never snap.
      final List<double> cells = areaAverage(src, 4, 1);
      expect(cells.length, 4);
      // Half dark, half light in every column.
      for (final double c in cells) {
        expect(c, closeTo(0.5, 1e-9));
      }
    });

    test('a linear ramp maps monotonically to ramp indices', () {
      final AsciiEngine engine = AsciiEngine(<String, FontMetrics>{});
      final RgbImage ramp = gradientStrip(width: 256, height: 24);
      final AsciiDocument doc = engine.render(
        ramp,
        AsciiSettings(columns: 40, workingLongEdge: 0),
      );
      // Row 0, scanning left (dark) to right (light): darkness must be
      // non-increasing and the ramp index non-increasing with it.
      List<String> rampChars = engine.resolveRamp(
        AsciiSettings(workingLongEdge: 0),
        engine.metricsFor('JetBrains Mono'),
      );
      double? previousTone;
      for (int x = 0; x < doc.columns; x++) {
        final double tone = doc.tones[x];
        if (previousTone != null) {
          expect(tone, lessThanOrEqualTo(previousTone + 1e-12));
        }
        previousTone = tone;
      }
      final String darkest = doc.cells[0];
      final String lightest = doc.cells[doc.columns - 1];
      expect(rampChars.indexOf(lightest), lessThan(rampChars.indexOf(darkest)));
      rampChars = <String>[];
    });

    test(
      'checkerboard averages to mid-grey per cell when cells span squares',
      () {
        final RgbImage board = checkerboard(size: 256, cells: 2);
        final GrayImage gray = board.toGray();
        // One output cell covering the whole board is the mean of the halves.
        final List<double> cells = areaAverage(gray, 1, 1);
        expect(cells[0], closeTo(0.5, 0.01));
      },
    );
  });

  group('determinism', () {
    test('identical settings and input give identical output', () {
      final AsciiEngine engine = AsciiEngine(measuredMetrics);
      final RgbImage img = syntheticPortrait(width: 160, height: 200);
      final AsciiSettings settings = AsciiSettings(columns: 60);
      final AsciiDocument a = engine.render(img, settings);
      final AsciiDocument b = engine.render(img, settings);
      expect(a.toPlainText(), b.toPlainText());
      expect(a.toHtml(), b.toHtml());
      expect(a.toPng(), b.toPng());
    });

    test('different column counts change the output', () {
      final AsciiEngine engine = AsciiEngine(measuredMetrics);
      final RgbImage img = syntheticObject(width: 160, height: 160);
      expect(
        engine.render(img, AsciiSettings(columns: 40)).toPlainText(),
        isNot(engine.render(img, AsciiSettings(columns: 120)).toPlainText()),
      );
    });
  });

  group('reference mappings', () {
    late AsciiEngine engine;
    late AsciiSettings base;

    setUp(() {
      engine = AsciiEngine(<String, FontMetrics>{});
      base = AsciiSettings(columns: 40, workingLongEdge: 0);
    });

    test('black maps to the darkest ramp cell, white to the lightest', () {
      final RgbImage half = RgbImage(80, 40);
      for (int y = 0; y < 40; y++) {
        for (int x = 0; x < 80; x++) {
          final int i = y * 80 + x;
          final bool left = x < 40;
          half.r[i] = left ? 0 : 255;
          half.g[i] = left ? 0 : 255;
          half.b[i] = left ? 0 : 255;
        }
      }
      final AsciiDocument doc = engine.render(half, base);
      String cellAt(int column) => doc.cells[0 * doc.columns + column];
      // Column 0 sits entirely in the black half, the last entirely in white.
      expect(
        cellAt(0).trim(),
        isNotEmpty,
        reason: 'a solid black area must not render as blank',
      );
      expect(cellAt(doc.columns - 1), ' ');
      // Numerically: darkness tone 1 for black, 0 for white.
      expect(doc.tones[0], closeTo(1, 1e-9));
      expect(doc.tones[doc.columns - 1], closeTo(0, 1e-9));
      // The darkest cell must be the end of the ramp and the lightest the
      // start: asserted against the resolved ramp, not a hard-coded guess.
      final List<String> ramp = engine.resolveRamp(
        base,
        engine.metricsFor(base.font),
      );
      expect(ramp.indexOf(cellAt(0)), ramp.length - 1);
      expect(ramp.indexOf(cellAt(doc.columns - 1)), 0);
    });

    test('invert swaps the mapping', () {
      final RgbImage solid = RgbImage(80, 40);
      for (int i = 0; i < solid.length; i++) {
        solid.r[i] = 0;
        solid.g[i] = 0;
        solid.b[i] = 0;
      }
      final AsciiDocument normal = engine.render(solid, base);
      final AsciiDocument flipped = engine.render(
        solid,
        base.copyWith(invert: true),
      );
      expect(normal.tones.first, closeTo(1, 1e-9));
      expect(flipped.tones.first, closeTo(0, 1e-9));
    });

    test('gradient tone increases monotonically from dark to light source', () {
      final AsciiDocument doc = engine.render(grayRampImage(200, 24), base);
      // Left column is black (tone 1), right is white (tone 0): so tones must
      // be non-increasing left to right within a row.
      for (int y = 0; y < doc.rows; y++) {
        double? previous;
        for (int x = 0; x < doc.columns; x++) {
          final double t = doc.tones[y * doc.columns + x];
          if (previous != null) expect(t, lessThanOrEqualTo(previous + 1e-9));
          previous = t;
        }
      }
    });

    test('gamma and contrast shift tones in the expected direction', () {
      final RgbImage img = syntheticLandscape(width: 200, height: 120);
      final AsciiDocument plain = engine.render(img, base);
      final AsciiDocument gammaLow = engine.render(
        img,
        base.copyWith(gamma: 0.5),
      );
      final AsciiDocument gammaHigh = engine.render(
        img,
        base.copyWith(gamma: 2.0),
      );
      final AsciiDocument contrast = engine.render(
        img,
        base.copyWith(contrast: 1.8),
      );
      double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
      // gamma<1 brightens linear light, so mean *darkness* drops; gamma>1
      // darkens, so it rises.
      expect(mean(gammaLow.tones), lessThan(mean(plain.tones)));
      expect(mean(gammaHigh.tones), greaterThan(mean(plain.tones)));
      // Higher contrast spreads tones, increasing their standard deviation.
      double stdev(List<double> v) {
        final double m = mean(v);
        return math.sqrt(mean(v.map((double x) => (x - m) * (x - m)).toList()));
      }

      expect(stdev(contrast.tones), greaterThan(stdev(plain.tones)));
    });
  });

  group('modes', () {
    final AsciiEngine engine = AsciiEngine(<String, FontMetrics>{});
    final RgbImage img = syntheticObject(width: 120, height: 120);

    test('default mode uses the built-in ramp', () {
      final AsciiDocument doc = engine.render(
        img,
        AsciiSettings(columns: 40, workingLongEdge: 0),
      );
      expect(
        doc.cells.toSet().difference(kDefaultRamp.split('').toSet()),
        isEmpty,
      );
    });

    test('character-set preset renders only preset characters', () {
      final RampPreset preset = RampPresets.byId('blocks')!;
      final AsciiSettings s = AsciiSettings(
        mode: AsciiMode.characterSet,
        characterSet: preset.characters,
        columns: 40,
        workingLongEdge: 0,
      );
      final AsciiDocument doc = engine.render(img, s);
      final Set<String> allowed = preset.characters.split('').toSet();
      expect(doc.cells.toSet().difference(allowed), isEmpty);
      // Blocks preset must actually use more than one level.
      expect(doc.cells.toSet().length, greaterThan(2));
    });

    test('user-string ramp mode uses unique characters of the string', () {
      const String text = 'SketchGlyph';
      final AsciiSettings s = AsciiSettings(
        mode: AsciiMode.userString,
        userString: text,
        userStringMode: UserStringMode.ramp,
        columns: 60,
        workingLongEdge: 0,
      );
      final AsciiDocument doc = engine.render(img, s);
      final Set<String> allowed = text.split('').toSet();
      // Only characters from the string (plus blank) may appear.
      expect(
        doc.cells.toSet().difference(allowed).difference(<String>{' '}),
        isEmpty,
      );
      final List<String> ramp = engine.resolveRamp(
        s,
        engine.metricsFor(s.font),
      );
      // Ramp holds the unique characters sorted by density, no duplicates.
      expect(ramp.toSet().length, ramp.length);
    });

    test('text-flow mode repeats the string in order', () {
      const String text = 'AB';
      final AsciiSettings s = AsciiSettings(
        mode: AsciiMode.userString,
        userString: text,
        userStringMode: UserStringMode.textFlow,
        columns: 40,
        workingLongEdge: 0,
      );
      final TextFlowResult result = engine.renderTextFlow(img, s);
      final List<String> first = result.document.cells
          .take(text.length * 3)
          .toList();
      expect(first.join(), 'ABABAB');
      expect(result.weights.length, result.document.tones.length);
      expect(result.opacities.length, result.document.tones.length);
      // Brightness modulates weight: darkest tone must have the largest weight.
      final int darkestIndex = result.document.tones.indexOf(
        result.document.tones.reduce(math.max),
      );
      final int lightestIndex = result.document.tones.indexOf(
        result.document.tones.reduce(math.min),
      );
      expect(
        result.weights[darkestIndex],
        greaterThan(result.weights[lightestIndex]),
      );
    });

    test('edge mode uses directional characters only', () {
      final AsciiSettings s = AsciiSettings(
        columns: 60,
        edgeMode: true,
        workingLongEdge: 0,
      );
      final AsciiDocument doc = engine.render(
        syntheticLandscape(width: 240, height: 150),
        s,
      );
      final Set<String> allowed = kEdgeChars.toSet();
      expect(doc.cells.toSet().difference(allowed), isEmpty);
      // A landscape has edges; at least a few directional chars must appear.
      expect(doc.cells.where((String c) => c != ' ').length, greaterThan(0));
    });
  });

  group('validation', () {
    test('rejects out-of-range columns', () {
      expect(
        () => AsciiSettings(columns: 10),
        throwsA(isA<AsciiSettingsException>()),
      );
      expect(
        () => AsciiSettings(columns: 9999),
        throwsA(isA<AsciiSettingsException>()),
      );
    });

    test('rejects empty user string and blank-only strings', () {
      expect(
        () => AsciiSettings(mode: AsciiMode.userString, userString: ''),
        throwsA(isA<AsciiSettingsException>()),
      );
      expect(
        () => AsciiSettings(mode: AsciiMode.userString, userString: '     '),
        throwsA(isA<AsciiSettingsException>()),
      );
    });

    test('ramp sub-mode needs two distinct characters', () {
      expect(
        () => AsciiSettings(
          mode: AsciiMode.userString,
          userString: 'aaaa',
          userStringMode: UserStringMode.ramp,
        ),
        throwsA(isA<AsciiSettingsException>()),
      );
    });

    test('character sets need two distinct characters', () {
      expect(
        () => AsciiSettings(mode: AsciiMode.characterSet, characterSet: '@'),
        throwsA(isA<AsciiSettingsException>()),
      );
    });

    test('reports which field is wrong', () {
      try {
        AsciiSettings(columns: 5);
        fail('should have thrown');
      } on AsciiSettingsException catch (e) {
        expect(e.field, 'columns');
        expect(e.message, contains('Columns'));
      }
    });
  });

  group('outputs', () {
    final AsciiEngine engine = AsciiEngine(
      measuredMetrics.isEmpty ? <String, FontMetrics>{} : measuredMetrics,
    );

    test('plain text has one newline per row boundary', () {
      final AsciiDocument doc = engine.render(
        syntheticPortrait(width: 120, height: 150),
        AsciiSettings(columns: 50, workingLongEdge: 0),
      );
      final String text = doc.toPlainText();
      expect(text.split('\n').length, doc.rows);
      for (final String line in text.split('\n')) {
        expect(line.length, doc.columns);
      }
    });

    test('html escapes markup and carries per-cell colour', () {
      final AsciiDocument doc = engine.render(
        syntheticObject(width: 100, height: 100),
        AsciiSettings(
          columns: 40,
          workingLongEdge: 0,
          colorMode: ColorMode.gradient,
        ),
      );
      final String html = doc.toHtml();
      expect(html, contains('<pre>'));
      expect(html, contains('style="color:#'));
      expect(html, isNot(contains('<script')));
      // HTML special characters must not leak unescaped.
      final AsciiDocument symbols = engine.render(
        syntheticObject(width: 100, height: 100),
        AsciiSettings(
          mode: AsciiMode.characterSet,
          characterSet: '<>&"\'',
          columns: 40,
          workingLongEdge: 0,
        ),
      );
      final String h = symbols.toHtml();
      expect(h, contains('&lt;'));
      expect(h, contains('&amp;'));
      expect(
        h.split('<pre>').last.split('</pre>').first,
        isNot(contains('<>')),
      );
    });

    test('png raster matches the document grid and is deterministic', () {
      final AsciiDocument doc = engine.render(
        syntheticObject(width: 80, height: 80),
        AsciiSettings(columns: 40, workingLongEdge: 0, fontSize: 10),
      );
      final Uint8List a = doc.toPng(scale: 1);
      final Uint8List b = doc.toPng(scale: 1);
      expect(a, b);
      expect(a, hasLength(greaterThan(100)));
      // PNG magic.
      expect(a.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    });
  });

  group('settings serialisation', () {
    test('json round trip preserves every field', () {
      final AsciiSettings s = AsciiSettings(
        mode: AsciiMode.userString,
        userString: 'hello world',
        userStringMode: UserStringMode.textFlow,
        sizing: GridSizing.fitToPage,
        pageSize: PageBox.letter,
        font: 'IBM Plex Mono',
        fontSize: 6.5,
        lineHeight: 1.4,
        letterSpacing: 0.05,
        filter: GridFilter.lanczos,
        contrast: 1.3,
        brightness: 0.02,
        gamma: 0.8,
        invert: true,
        sharpen: 0.6,
        edgeMode: true,
        dither: DitherKind.bayer4,
        ditherStrength: 0.7,
        colorMode: ColorMode.original,
        foreground: 0xFF112233,
        background: 0xFF445566,
        gradientStart: 0xFF778899,
        gradientEnd: 0xFFAABBCC,
        workingLongEdge: 512,
        seed: 4242,
      );
      final AsciiSettings r = AsciiSettings.fromJson(s.toJson());
      expect(r.toJson(), s.toJson());
    });

    test('all presets are resolvable and non-empty', () {
      for (final RampPreset p in RampPresets.all) {
        expect(RampPresets.byId(p.id)!.label, p.label);
        expect(
          p.characters.runes.length,
          greaterThanOrEqualTo(2),
          reason: p.id,
        );
      }
    });
  });

  group('decode', () {
    test('reads PNG bytes back into a planar image', () {
      final RgbImage src = syntheticObject(width: 12, height: 12);
      final RgbImage round = decodeImageBytes(pngOf(src));
      expect(round.width, 12);
      for (int i = 0; i < src.length; i++) {
        expect(round.r[i], src.r[i]);
        expect(round.g[i], src.g[i]);
        expect(round.b[i], src.b[i]);
      }
    });

    test('rejects unreadable files with a user-facing message', () {
      expect(
        () => decodeImageBytes(Uint8List.fromList(<int>[1, 2, 3])),
        throwsA(isA<AsciiSettingsException>()),
      );
    });
  });
}
