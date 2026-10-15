/// Pure-Dart text rasteriser used for PNG export of ASCII documents and for
/// sample generation, so exports match the measured font metrics exactly.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'ascii_engine.dart';
import 'glyph_metrics.dart';
import 'ttf.dart';

/// Supplies rasterised glyph outlines for characters.
abstract class GlyphSource {
  /// Coverage grid for [char] at the requested cell size, or `null`.
  GlyphBitmap? bitmapFor(
    String char, {
    required int columns,
    required int rows,
  });
}

/// [GlyphSource] backed by a parsed [TtfFont].
class TtfGlyphSource implements GlyphSource {
  /// Creates a source.
  TtfGlyphSource(this.font);

  /// The font measured for densities.
  final TtfFont font;

  final Map<String, GlyphBitmap?> _cache = <String, GlyphBitmap?>{};

  @override
  GlyphBitmap? bitmapFor(
    String char, {
    required int columns,
    required int rows,
  }) {
    final String key = '$char:${columns}x$rows';
    if (_cache.containsKey(key)) return _cache[key];
    final GlyphBitmap? bitmap = char == ' '
        ? null
        : rasteriseGlyph(
            font,
            char.codeUnitAt(0),
            columns: columns,
            rows: rows,
            samplesPerAxis: 1,
          );
    _cache[key] = bitmap;
    return bitmap;
  }
}

/// Cell geometry shared by the preview and the raster.
class AsciiCellGeometry {
  /// Creates geometry in pixels for [dpi] pixels per inch.
  AsciiCellGeometry(this.settings, this.metrics, {this.dpi = 96});

  /// Settings that produced a document.
  final AsciiSettings settings;

  /// Font metrics used.
  final FontMetrics metrics;

  /// Raster resolution.
  final double dpi;

  /// Cell width in pixels.
  double get cellWidth =>
      settings.fontSize /
      72 *
      dpi *
      metrics.advanceRatio *
      (1 + settings.letterSpacing);

  /// Cell height in pixels.
  double get cellHeight =>
      settings.fontSize / 72 * dpi * metrics.lineBoxRatio * settings.lineHeight;
}

/// Renders [document] to PNG bytes.
Uint8List renderAsciiPng(
  AsciiDocument document, {
  double scale = 2.0,
  bool transparentBackground = false,
  GlyphSource? glyphs,
  int? backgroundArgb,
  double dpi = 96,
}) {
  final AsciiSettings settings = document.settings;
  final AsciiCellGeometry geo = AsciiCellGeometry(
    settings,
    document.metrics,
    dpi: dpi,
  );
  final int columns = math.max(1, (geo.cellWidth * scale).round());
  final int rows = math.max(1, (geo.cellHeight * scale).round());
  final int width = columns * document.columns;
  final int height = rows * document.rows;

  // RGBA8 buffer written directly for speed; handed to the encoder at the end.
  final Uint8List rgba = Uint8List(width * height * 4);
  final int bg = backgroundArgb ?? settings.background;
  final int bgA = transparentBackground ? 0 : (bg >> 24) & 0xFF;
  final int bgR = (bg >> 16) & 0xFF;
  final int bgG = (bg >> 8) & 0xFF;
  final int bgB = bg & 0xFF;
  for (int i = 0; i < width * height; i++) {
    final int o = i * 4;
    rgba[o] = bgR;
    rgba[o + 1] = bgG;
    rgba[o + 2] = bgB;
    rgba[o + 3] = bgA;
  }

  // Glyph coverage grid; at very small cell sizes there is not enough room to
  // draw a readable glyph, so those documents fall back to tone squares.
  final bool canDrawGlyphs = glyphs != null && columns >= 6 && rows >= 8;

  for (int y = 0; y < document.rows; y++) {
    for (int x = 0; x < document.columns; x++) {
      final int i = y * document.columns + x;
      final String char = document.cells[i];
      if (char == ' ') continue;
      final int argb = document.colors[i];
      final int a = (argb >> 24) & 0xFF;
      final int r = (argb >> 16) & 0xFF;
      final int g = (argb >> 8) & 0xFF;
      final int b = argb & 0xFF;
      final int ox = x * columns;
      final int oy = y * rows;

      if (canDrawGlyphs) {
        final GlyphBitmap? bitmap = glyphs.bitmapFor(
          char,
          columns: columns,
          rows: rows,
        );
        if (bitmap != null) {
          _blitCoverage(
            rgba,
            width,
            height,
            bitmap,
            ox,
            oy,
            columns,
            rows,
            r,
            g,
            b,
            a,
          );
          continue;
        }
      }
      // Fallback: a tone-sized square centred in the cell.
      final double tone = document.tones[i];
      final int half = math.max(1, (columns * 0.43 * tone).ceil());
      final int cx = ox + columns ~/ 2;
      final int cy = oy + rows ~/ 2;
      for (int py = cy - half; py <= cy + half; py++) {
        if (py < 0 || py >= height) continue;
        for (int px = cx - half; px <= cx + half; px++) {
          if (px < 0 || px >= width) continue;
          final int o = (py * width + px) * 4;
          rgba[o] = r;
          rgba[o + 1] = g;
          rgba[o + 2] = b;
          rgba[o + 3] = a;
        }
      }
    }
  }

  final img.Image canvas = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodePng(canvas));
}

void _blitCoverage(
  Uint8List rgba,
  int canvasWidth,
  int canvasHeight,
  GlyphBitmap bitmap,
  int ox,
  int oy,
  int columns,
  int rows,
  int r,
  int g,
  int b,
  int alpha,
) {
  for (int py = 0; py < rows; py++) {
    final int gy = (py * bitmap.rows / rows).floor();
    if (gy < 0 || gy >= bitmap.rows) continue;
    final int y = oy + py;
    if (y < 0 || y >= canvasHeight) continue;
    for (int px = 0; px < columns; px++) {
      final int gx = (px * bitmap.columns / columns).floor();
      if (gx < 0 || gx >= bitmap.columns) continue;
      final double coverage = bitmap.coverage[gy * bitmap.columns + gx];
      if (coverage <= 0.01) continue;
      final int x = ox + px;
      if (x < 0 || x >= canvasWidth) continue;
      final int o = (y * canvasWidth + x) * 4;
      // Source-over, with the glyph's own coverage as the alpha factor.
      final double sa = (alpha / 255) * coverage;
      final double da = (1 - sa) * (rgba[o + 3] / 255);
      final double outA = sa + da;
      if (outA <= 0) continue;
      int blend(int sc, int dc) =>
          ((sc * sa + dc * da) / outA).round().clamp(0, 255);
      rgba[o] = blend(r, rgba[o]);
      rgba[o + 1] = blend(g, rgba[o + 1]);
      rgba[o + 2] = blend(b, rgba[o + 2]);
      rgba[o + 3] = (outA * 255).round().clamp(0, 255);
    }
  }
}
