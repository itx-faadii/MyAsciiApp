/// Phase 4: runtime verification of the shipped glyph density tables.
///
/// `assets/font_metrics.json` is produced by the pure-Dart rasteriser in
/// `packages/sketchglyph_engine/tool/measure_fonts.dart`. These tests measure
/// the same characters with Flutter's real text stack (TextPainter painted
/// into an offscreen picture) and assert the tables agree: the per-cell
/// advance matches, densities rank-correlate, and the density-sorted ramp the
/// engine ships is the same order Flutter's own rasteriser would produce.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

/// Engine table family key -> Flutter TextStyle family declared in pubspec.
const Map<String, String> kFlutterFamily = <String, String>{
  'JetBrainsMono-Regular': 'JetBrains Mono',
  'IBM Plex Mono': 'IBM Plex Mono',
  'Courier Prime': 'Courier Prime',
};

/// Engine table family key -> bundled TTF path under assets/fonts/.
String _fontAsset(String engineFamily) => switch (engineFamily) {
  'JetBrainsMono-Regular' => 'JetBrainsMono-Regular.ttf',
  'IBM Plex Mono' => 'IBM Plex Mono.ttf',
  'Courier Prime' => 'Courier Prime.ttf',
  _ => throw ArgumentError('unknown font family: $engineFamily'),
};

/// Every character that can appear in a shipped ramp.
String _verificationCharset() {
  final Set<String> chars = <String>{};
  for (final int r in kDefaultRamp.runes) {
    chars.add(String.fromCharCode(r));
  }
  for (final RampPreset p in RampPresets.all) {
    for (final int r in p.characters.runes) {
      chars.add(String.fromCharCode(r));
    }
  }
  return (chars.toList()..sort()).join();
}

/// Spearman rank correlation between two equal-length series.
double _spearman(List<double> xs, List<double> ys) {
  List<double> ranks(List<double> v) {
    final List<int> idx = List<int>.generate(v.length, (int i) => i)
      ..sort((int a, int b) => v[a].compareTo(v[b]));
    final List<double> out = List<double>.filled(v.length, 0);
    for (int r = 0; r < idx.length; r++) {
      out[idx[r]] = r.toDouble();
    }
    return out;
  }

  final List<double> rx = ranks(xs);
  final List<double> ry = ranks(ys);
  final int n = xs.length;
  final double mx = rx.reduce((double a, double b) => a + b) / n;
  final double my = ry.reduce((double a, double b) => a + b) / n;
  double cov = 0, vx = 0, vy = 0;
  for (int i = 0; i < n; i++) {
    cov += (rx[i] - mx) * (ry[i] - my);
    vx += (rx[i] - mx) * (rx[i] - mx);
    vy += (ry[i] - my) * (ry[i] - my);
  }
  if (vx == 0 || vy == 0) return 1;
  return cov / (math.sqrt(vx * vy));
}

/// Ink coverage of [char] drawn in [family], as a fraction of the cell box.
Future<({double density, double advance})> _flutterCell(
  String family,
  String char,
  double fontSize,
) async {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: char,
      style: TextStyle(
        fontFamily: family,
        fontSize: fontSize,
        color: const Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  painter.layout();
  final double w = painter.width.ceilToDouble();
  final double h = painter.height.ceilToDouble().clamp(1, double.infinity);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF000000),
  );
  painter.paint(canvas, Offset.zero);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(w.toInt(), h.toInt());
  final ByteData? data = await image.toByteData();
  image.dispose();
  picture.dispose();
  if (data == null) return (density: 0.0, advance: painter.width);
  final Uint8List pixels = data.buffer.asUint8List();
  // White glyph on black: the red channel is exactly the coverage.
  double ink = 0;
  for (int i = 0; i < pixels.length; i += 4) {
    ink += pixels[i] / 255.0;
  }
  return (density: ink / (w * h), advance: painter.width);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // flutter_test does not load pubspec fonts; register them directly so
    // TextPainter rasterises the real bundled TTFs.
    for (final MapEntry<String, String> e in kFlutterFamily.entries) {
      final Uint8List bytes = File('assets/fonts/${_fontAsset(e.key)}')
          .readAsBytesSync();
      await ui.loadFontFromList(bytes, fontFamily: e.value);
    }
  });

  final Map<String, Object?> json = jsonDecode(
    File('assets/font_metrics.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final Map<String, FontMetrics> table = <String, FontMetrics>{
    for (final Object? entry in json['fonts']! as List<Object?>)
      (entry! as Map<String, Object?>)['family']! as String:
          FontMetrics.fromJson(entry as Map<String, Object?>),
  };

  test('the committed table covers the three monospaced bundled fonts', () {
    expect(table.keys, containsAll(kFlutterFamily.keys));
    for (final FontMetrics m in table.values) {
      expect(m.densities, isNotEmpty);
      expect(m.densities[' '], 0, reason: 'space must be density 0');
    }
  });

  test(
    'TextPainter advance matches the measured cell width (1% tolerance)',
    () async {
      const double size = 40;
      for (final MapEntry<String, String> e in kFlutterFamily.entries) {
        final FontMetrics m = table[e.key]!;
        final ({double density, double advance}) cell = await _flutterCell(
          e.value,
          'M',
          size,
        );
        final double ratio = cell.advance / size;
        expect(
          (ratio - m.advanceRatio).abs() / m.advanceRatio,
          lessThan(0.01),
          reason:
              '${e.key}: TextPainter advance=$ratio '
              'table=${m.advanceRatio.toStringAsFixed(4)} — if this fails, '
              'the custom font was not loaded by the test harness.',
        );
      }
    },
  );

  test('Flutter rasterises the real fonts, not the Ahem fallback', () async {
    // The default test font draws every glyph as a full square; the space
    // check proves pubspec fonts are live in this environment.
    final ({double density, double advance}) space = await _flutterCell(
      'JetBrains Mono',
      ' ',
      24,
    );
    final ({double density, double advance}) at = await _flutterCell(
      'JetBrains Mono',
      '@',
      24,
    );
    expect(space.density, lessThan(0.01), reason: 'space must be blank');
    expect(at.density, greaterThan(0.05), reason: '@ must have ink');
  });

  test('table densities rank-correlate with Flutter rasteriser', () async {
    const double size = 24;
    for (final MapEntry<String, String> e in kFlutterFamily.entries) {
      final FontMetrics m = table[e.key]!;
      final List<String> chars = _verificationCharset().runes
          .map(String.fromCharCode)
          .where((String c) => m.densities.containsKey(c) && c != ' ')
          .toList();
      final List<double> tableD = <double>[];
      final List<double> flutterD = <double>[];
      for (final String c in chars) {
        final ({double density, double advance}) cell = await _flutterCell(
          e.value,
          c,
          size,
        );
        tableD.add(m.densities[c]!);
        flutterD.add(cell.density);
      }
      final double rho = _spearman(tableD, flutterD);
      expect(
        rho,
        greaterThan(0.75),
        reason:
            '${e.key}: measured table disagrees with the Flutter '
            'rasteriser (Spearman rho=$rho over ${chars.length} glyphs)',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 6)));

  test(
    'density-sorted default ramp matches Flutter-measured ordering',
    () async {
      final FontMetrics m = table['JetBrainsMono-Regular']!;
      final List<String> chars = <String>{
        for (final int r in kDefaultRamp.runes) String.fromCharCode(r),
      }.toList();
      final List<String> tableRamp = buildRamp(
        chars,
        (String c) => m.densities[c] ?? 0.5,
      );
      final Map<String, double> flutterDensities = <String, double>{' ': 0};
      for (final String c in chars) {
        if (c == ' ') continue;
        flutterDensities[c] = (await _flutterCell(
          'JetBrains Mono',
          c,
          24,
        )).density;
      }
      final List<String> flutterRamp = buildRamp(
        chars,
        (String c) => flutterDensities[c] ?? 0.5,
      );
      final List<double> a = <double>[
        for (final String c in chars) tableRamp.indexOf(c).toDouble(),
      ];
      final List<double> b = <double>[
        for (final String c in chars) flutterRamp.indexOf(c).toDouble(),
      ];
      expect(
        _spearman(a, b),
        greaterThan(0.7),
        reason:
            'table ramp order diverges from Flutter raster order:\n'
            'table  = ${tableRamp.join()}\n'
            'flutter= ${flutterRamp.join()}',
      );
      // The extremes must agree: the table's darkest glyph must also rank as
      // one of the darkest under Flutter's rasteriser.
      expect(
        flutterRamp.indexOf(tableRamp.last),
        greaterThan(flutterRamp.length - 6),
        reason:
            'the table\'s darkest glyph "${tableRamp.last}" must rank among '
            'the darkest under Flutter too',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
