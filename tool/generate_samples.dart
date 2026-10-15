#!/usr/bin/env dart

/// Phase 4 sample generator: renders ASCII art for three procedural reference
/// images across every ASCII mode and writes `.txt` + `.png` pairs plus contact
/// sheets into `docs/samples/ascii`.
///
/// Run from the repo root:
///   dart tool/generate_samples.dart
///
/// Uses only the pure-Dart engine, doubling as proof the whole pipeline works
/// without Flutter.
library;

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

/// Reference subject: label -> procedural image builder.
Map<String, RgbImage Function()> _subjects() => <String, RgbImage Function()>{
  'portrait': syntheticPortrait,
  'landscape': syntheticLandscape,
  'object': syntheticObject,
};

/// The three mode A/B/C variants stacked into a contact sheet.
const List<String> _contactVariants = <String>[
  'mode_a_default',
  'mode_b_blocks',
  'mode_c_flow',
];

void main() {
  final Directory root = _findRepoRoot();
  final Directory outDir = Directory('${root.path}/docs/samples/ascii');
  outDir.createSync(recursive: true);

  final Map<String, FontMetrics> metrics = _loadMetrics(root);
  if (metrics.isEmpty) {
    stderr.writeln(
      'No font metrics found — run '
      'dart packages/sketchglyph_engine/tool/measure_fonts.dart first.',
    );
    exit(1);
  }

  final AsciiEngine engine = AsciiEngine(metrics);
  // Real glyph outlines, so sample PNGs use the same metrics as the app.
  final TtfFont ttf = TtfFont.parse(
    File('${root.path}/assets/fonts/JetBrainsMono-Regular.ttf')
        .readAsBytesSync(),
    fallbackName: 'JetBrainsMono-Regular',
  );
  final TtfGlyphSource glyphs = TtfGlyphSource(ttf);
  int written = 0;

  for (final MapEntry<String, RgbImage Function()> subject
      in _subjects().entries) {
    final RgbImage source = subject.value.call();
    final List<({String variant, AsciiSettings Function() build})> variants =
        <({String variant, AsciiSettings Function() build})>[
          // Mode A — default ramp, the one-tap look.
          (variant: 'mode_a_default', build: () => _base()),
          // Mode B — every character-set preset.
          for (final RampPreset p in RampPresets.all)
            (
              variant: 'mode_b_${p.id}',
              build: () => _base().copyWith(
                mode: AsciiMode.characterSet,
                characterSet: p.characters,
              ),
            ),
          // Mode C — user string as a ramp and as flowing text.
          (
            variant: 'mode_c_ramp',
            build: () => _base().copyWith(
              mode: AsciiMode.userString,
              userString: 'sketchglyph',
              userStringMode: UserStringMode.ramp,
            ),
          ),
          (
            variant: 'mode_c_flow',
            // Original colour mode maps each cell's tone into its colour,
            // approximating how the app modulates size/weight/opacity in
            // text-flow previews.
            build: () => _base().copyWith(
              mode: AsciiMode.userString,
              userString: 'sketchglyph',
              userStringMode: UserStringMode.textFlow,
              colorMode: ColorMode.original,
            ),
          ),
          // Colour modes on the default ramp.
          (
            variant: 'color_gradient',
            build: () => _base().copyWith(
              colorMode: ColorMode.gradient,
              gradientStart: 0xFF00FF66,
              gradientEnd: 0xFFB6FF3D,
            ),
          ),
          (
            variant: 'color_original',
            build: () => _base().copyWith(colorMode: ColorMode.original),
          ),
          // Sobel edge mode and dithering.
          (
            variant: 'edge_directional',
            build: () => _base().copyWith(edgeMode: true),
          ),
          (
            variant: 'dither_floyd',
            build: () => _base().copyWith(
              dither: DitherKind.floydSteinberg,
              foreground: 0xFF1C232C,
              background: 0xFFF4F1E8,
            ),
          ),
          (
            variant: 'dither_bayer',
            build: () => _base().copyWith(
              dither: DitherKind.bayer4,
              foreground: 0xFFFFB000,
              background: 0xFF160F04,
            ),
          ),
        ];

    for (final ({String variant, AsciiSettings Function() build}) v
        in variants) {
      final AsciiSettings settings = v.build();
      // Skip presets the selected font cannot render at all (e.g. braille is
      // missing from every bundled TTF) instead of writing blank samples.
      final List<String> ramp = engine.resolveRamp(
        settings,
        engine.metricsFor(settings.font),
      );
      if (ramp.length < 2) {
        stderr.writeln(
          'SKIP ${subject.key}_${v.variant}: font ${settings.font} '
          'supports fewer than 2 characters of this set',
        );
        continue;
      }
      _write(engine, glyphs, source, subject.key, v.variant, settings, outDir);
      written += 2;
    }
    _contactSheet(outDir, subject.key);
  }

  // Reference charts prove the dark-to-light mapping visually.
  _write(
    engine,
    glyphs,
    gradientStrip(width: 800, height: 120),
    'reference',
    'gradient_default',
    _base(),
    outDir,
  );
  _write(
    engine,
    glyphs,
    checkerboard(size: 400, cells: 8),
    'reference',
    'checkerboard_default',
    _base(),
    outDir,
  );
  written += 4;

  stdout.writeln(
    'Wrote $written sample files (txt+png pairs) to ${outDir.path}',
  );
}

AsciiSettings _base() =>
    AsciiSettings(font: 'JetBrainsMono-Regular', columns: 120, fontSize: 6);

void _write(
  AsciiEngine engine,
  TtfGlyphSource glyphs,
  RgbImage source,
  String subject,
  String variant,
  AsciiSettings settings,
  Directory outDir,
) {
  final AsciiDocument doc = engine.render(source, settings);
  final String base = '${subject}_$variant';
  File('${outDir.path}/$base.txt')
      .writeAsStringSync(doc.toPlainText(), flush: true);
  File('${outDir.path}/$base.png')
      .writeAsBytesSync(doc.toPng(scale: 3, glyphs: glyphs), flush: true);
}

void _contactSheet(Directory asciiDir, String subject) {
  final List<img.Image> rows = <img.Image>[
    for (final String variant in _contactVariants)
      img.decodePng(
        File('${asciiDir.path}/${subject}_$variant.png').readAsBytesSync(),
      )!,
  ];
  const int gap = 20;
  int w = 0;
  int h = gap;
  for (final img.Image im in rows) {
    if (im.width > w) w = im.width;
    h += im.height + gap;
  }
  final img.Image canvas = img.Image(width: w, height: h, numChannels: 4);
  img.fill(canvas, color: img.ColorUint8.rgb(14, 17, 22));
  int y = gap;
  for (int i = 0; i < rows.length; i++) {
    final img.Image im = rows[i];
    img.drawString(
      canvas,
      _contactVariants[i],
      font: img.arial14,
      x: 8,
      y: (y - 18).clamp(0, h),
      color: img.ColorUint8.rgb(154, 167, 181),
    );
    img.compositeImage(
      canvas,
      im,
      dstX: 0,
      dstY: y,
      blend: img.BlendMode.direct,
    );
    y += im.height + gap;
  }
  File('${asciiDir.path}/contact_$subject.png')
      .writeAsBytesSync(img.encodePng(canvas), flush: true);
}

Map<String, FontMetrics> _loadMetrics(Directory root) {
  final File file = File('${root.path}/assets/font_metrics.json');
  if (!file.existsSync()) return const <String, FontMetrics>{};
  final Map<String, Object?> json =
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return <String, FontMetrics>{
    for (final Object? entry in json['fonts']! as List<Object?>)
      (entry! as Map<String, Object?>)['family']! as String:
          FontMetrics.fromJson(entry as Map<String, Object?>),
  };
}

Directory _findRepoRoot() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    if (File('${dir.path}/assets/font_metrics.json').existsSync() &&
        File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  stderr.writeln('Run this script from inside the SketchGlyph repo.');
  exit(1);
}
