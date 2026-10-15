#!/usr/bin/env dart

/// Build-time tool: measures real glyph ink density and cell metrics for the
/// bundled monospace fonts and writes `assets/font_metrics.json`.
///
/// Run from the repo root:
///   dart packages/sketchglyph_engine/tool/measure_fonts.dart
///
/// The JSON it produces is committed, so the app ships measured ramps without
/// needing a native text shaper at runtime.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sketchglyph_engine/sketchglyph_engine.dart';

/// Every character we want a density entry for: the default ramp, all presets,
/// plus the printable ASCII range and the block/braille characters used by
/// presets.
String get measuredCharset {
  final Set<String> chars = <String>{};
  for (final int r in kDefaultRamp.runes) {
    chars.add(String.fromCharCode(r));
  }
  for (final RampPreset p in RampPresets.all) {
    for (final int r in p.characters.runes) {
      chars.add(String.fromCharCode(r));
    }
  }
  for (int code = 0x20; code <= 0x7E; code++) {
    chars.add(String.fromCharCode(code));
  }
  for (int code = 0x2500; code <= 0x259F; code++) {
    chars.add(String.fromCharCode(code));
  }
  for (int code = 0x2800; code <= 0x28FF; code++) {
    chars.add(String.fromCharCode(code));
  }
  return (chars.toList()..sort()).join();
}

void main(List<String> args) {
  final Directory root = _findRepoRoot();
  final Directory fontDir = Directory('${root.path}/assets/fonts');
  if (!fontDir.existsSync()) {
    stderr.writeln('No fonts in ${fontDir.path} — run from the repo root.');
    exit(1);
  }

  final String charset = measuredCharset;
  final Map<String, Object?> output = <String, Object?>{
    'version': 2,
    'charset': charset,
    'fonts': <Map<String, Object?>>[],
  };

  final List<File> files =
      fontDir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.toLowerCase().endsWith('.ttf'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  for (final File file in files) {
    final Uint8List bytes = file.readAsBytesSync();
    final String fallback = file.uri.pathSegments.last.replaceAll(
      RegExp(r'\.ttf$'),
      '',
    );
    TtfFont font;
    try {
      font = TtfFont.parse(bytes, fallbackName: fallback);
    } on FormatException catch (e) {
      stderr.writeln('SKIP ${file.path}: ${e.message}');
      continue;
    }
    if (!font.hasOutlines) {
      stderr.writeln('SKIP ${file.path}: no usable glyf outlines');
      continue;
    }
    if (!font.isMonospace) {
      // Proportional fonts produce stretched, unusable ASCII grids. They stay
      // in the bundle for UI text but are excluded from the ramp tables.
      stderr.writeln('SKIP ${file.path}: proportional, not monospaced');
      continue;
    }

    final List<GlyphMeasurement> measurements = measureRamp(
      font,
      charset.runes.map(String.fromCharCode),
      resolution: 160,
    );
    final Map<String, double> densities = <String, double>{};
    final List<String> missing = <String>[];
    for (final GlyphMeasurement m in measurements) {
      if (m.char == ' ') {
        densities[m.char] = 0;
        continue;
      }
      if (!m.hasGlyph) {
        missing.add(m.char);
        continue;
      }
      densities[m.char] = double.parse(m.density.toStringAsFixed(5));
    }

    final FontMetrics metrics = FontMetrics(
      family: font.name.isEmpty ? fallback : font.name,
      unitsPerEm: font.unitsPerEm,
      advance: font.advanceFor(0x4D), // 'M'
      ascender: font.ascender,
      descender: font.descender,
      densities: densities,
      missingGlyphs: missing,
    );
    (output['fonts']! as List<Object?>).add(metrics.toJson());

    // Sanity: density ordering must be monotonic for a few known pairs.
    _assertOrder(metrics.family, densities);
    stdout.writeln(
      'OK  ${metrics.family}: upm=${font.unitsPerEm} advance=${metrics.advance} '
      'cell=${metrics.cellWidth.toStringAsFixed(3)}x${metrics.cellHeight.toStringAsFixed(3)} '
      '${densities.length} glyphs, ${missing.length} missing',
    );

    final List<String> ranked = densities.keys.toList()
      ..sort((String a, String b) => densities[a]!.compareTo(densities[b]!));
    stdout.writeln('   lightest: ${ranked.take(6).join(' ')}');
    stdout.writeln('   darkest : ${ranked.reversed.take(6).join(' ')}');
    stdout.writeln(
      '   ramp(default): '
      '${(kDefaultRamp.runes.map(String.fromCharCode).toList()..sort((String a, String b) => densities[a]!.compareTo(densities[b]!))).join()}',
    );
  }

  if ((output['fonts']! as List<Object?>).isEmpty) {
    stderr.writeln('No fonts measured; refusing to write an empty asset.');
    exit(1);
  }

  final File dest = File(
    args.isNotEmpty ? args.first : '${root.path}/assets/font_metrics.json',
  );
  dest.parent.createSync(recursive: true);
  dest.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln(
    'Wrote ${dest.path} '
    '(${(dest.lengthSync() / 1024).toStringAsFixed(1)} KB)',
  );
}

void _assertOrder(String font, Map<String, double> d) {
  void check(String light, String dark) {
    final double? a = d[light];
    final double? b = d[dark];
    if (a == null || b == null) return;
    if (a >= b) {
      throw StateError(
        '$font: "$light" ($a) should be lighter than "$dark" ($b)',
      );
    }
  }

  // Structural invariants that must hold for any real font.
  if (d[' '] != 0) {
    throw StateError('$font: space must measure zero ink, got ${d[' ']}');
  }
  // Structural invariants only. Whether '#' or '@' is darker is a genuine
  // per-font property (Courier Prime's '@' is very open), which is exactly why
  // ramps are measured instead of assumed.
  check(' ', '.');
  check('.', '#');
  check(',', '@');
  check('i', 'W');
  check('l', 'm');
  check('.', '8');
}

Directory _findRepoRoot() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    if (Directory('${dir.path}/assets/fonts').existsSync()) return dir;
    if (Directory('${dir.path}/packages/sketchglyph_engine').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  stderr.writeln(
    'Could not locate the repo root from ${Directory.current.path}',
  );
  exit(1);
}
