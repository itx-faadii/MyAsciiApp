/// Glyph rasterisation used to measure *real* ink density per character.
library;

import 'dart:math' as math;

import 'ttf.dart';

/// A character's measured metrics in font units and its normalised ink density.
class GlyphMeasurement {
  /// Creates a measurement record.
  const GlyphMeasurement({
    required this.char,
    required this.density,
    required this.advance,
    required this.hasGlyph,
  });

  /// The character measured.
  final String char;

  /// Ink coverage of the character cell in `[0, 1]`.
  final double density;

  /// Advance width in font units.
  final int advance;

  /// Whether the font actually contains a glyph for [char].
  final bool hasGlyph;

  /// Serialises for the JSON asset.
  Map<String, Object?> toJson() => <String, Object?>{
    'c': char,
    'd': double.parse(density.toStringAsFixed(5)),
    'a': advance,
    'g': hasGlyph ? 1 : 0,
  };

  /// Reads back a serialised record.
  factory GlyphMeasurement.fromJson(Map<String, Object?> json) =>
      GlyphMeasurement(
        char: json['c'] as String,
        density: (json['d'] as num).toDouble(),
        advance: (json['a'] as num).toInt(),
        hasGlyph: (json['g'] as num).toInt() == 1,
      );
}

/// Monospace cell metrics measured from a real font.
class FontMetrics {
  /// Creates font metrics.
  const FontMetrics({
    required this.family,
    required this.unitsPerEm,
    required this.advance,
    required this.ascender,
    required this.descender,
    required this.densities,
    this.missingGlyphs = const <String>[],
  });

  /// Font family name as embedded in the file.
  final String family;

  /// Design units per em.
  final int unitsPerEm;

  /// Advance width of the nominal glyph in design units.
  final int advance;

  /// Ascender in design units.
  final int ascender;

  /// Descender in design units.
  final int descender;

  /// Measured ink density per character, keyed by the character itself.
  final Map<String, double> densities;

  /// Characters the measured font could not draw.
  final List<String> missingGlyphs;

  /// Advance width as a fraction of the em square (monospace cell width).
  double get advanceRatio => advance / unitsPerEm;

  /// Nominal line box (ascender - descender) as a fraction of the em.
  double get lineBoxRatio => lineBoxHeight / unitsPerEm;

  /// Vertical extent actually covered by the cell, in design units.
  double get lineBoxHeight => (ascender - descender).toDouble();

  /// Width of one text cell relative to one em of the font size.
  double get cellWidth => advanceRatio;

  /// Height of one text cell relative to one em, at line height 1.0.
  double get cellHeight => lineBoxRatio;

  /// Serialises for the JSON asset.
  Map<String, Object?> toJson() => <String, Object?>{
    'family': family,
    'unitsPerEm': unitsPerEm,
    'advance': advance,
    'ascender': ascender,
    'descender': descender,
    'missing': missingGlyphs,
    'glyphs': <Map<String, Object?>>[
      for (final MapEntry<String, double> e in densities.entries)
        GlyphMeasurement(
          char: e.key,
          density: e.value,
          advance: advance,
          hasGlyph: true,
        ).toJson(),
    ],
  };

  /// Reads back a serialised record.
  factory FontMetrics.fromJson(Map<String, Object?> json) {
    final Map<String, double> densities = <String, double>{};
    for (final Object? raw in (json['glyphs'] as List<Object?>)) {
      final GlyphMeasurement m = GlyphMeasurement.fromJson(
        (raw as Map<String, Object?>),
      );
      densities[m.char] = m.density;
    }
    return FontMetrics(
      family: json['family'] as String,
      unitsPerEm: (json['unitsPerEm'] as num).toInt(),
      advance: (json['advance'] as num).toInt(),
      ascender: (json['ascender'] as num).toInt(),
      descender: (json['descender'] as num).toInt(),
      densities: densities,
      missingGlyphs: <String>[
        for (final Object? c
            in (json['missing'] as List<Object?>? ?? <Object?>[]))
          c as String,
      ],
    );
  }
}

/// Rasterises [codeUnit] into a grid of coverage values in `[0, 1]`.
///
/// Returns `null` when the font has no outline for the character. The grid is
/// [columns] x [rows] cells covering the layout box (advance x line box), using
/// the nonzero winding rule with [samplesPerAxis] supersampling per cell.
GlyphBitmap? rasteriseGlyph(
  TtfFont font,
  int codeUnit, {
  int columns = 12,
  int rows = 16,
  int samplesPerAxis = 2,
}) {
  final List<List<List<double>>>? contours = font.contoursFor(codeUnit);
  if (contours == null) return null;

  final double cellWidth = font.advanceFor(codeUnit).toDouble();
  final double cellHeight = font.lineBoxHeight.toDouble();
  if (cellWidth <= 0 || cellHeight <= 0) return null;

  final List<List<double>> polygons = <List<double>>[];
  for (final List<List<double>> contour in contours) {
    polygons.add(_flattenContour(contour, cellWidth / 48));
  }

  final List<double> coverage = List<double>.filled(columns * rows, 0);
  final int sub = math.max(1, samplesPerAxis);
  final double sampleStep = columns * sub.toDouble();
  for (int ry = 0; ry < rows; ry++) {
    // Font Y grows upward; row 0 is the top of the cell.
    final double fy = cellHeight * (1 - (ry + 0.5) / rows);
    final List<double> xs = <double>[];
    final List<double> windings = <double>[];
    for (final List<double> poly in polygons) {
      _collectCrossings(poly, fy, xs, windings);
    }
    if (xs.isEmpty) continue;
    final List<int> order = List<int>.generate(xs.length, (int i) => i)
      ..sort((int a, int b) => xs[a].compareTo(xs[b]));

    // Walk the scanline once, tracking the nonzero winding number between
    // consecutive crossings, and accumulate sample coverage per cell.
    int w = 0;
    int cursor = 0;
    double prevX = 0;
    for (final int idx in order) {
      final double crossX = xs[idx];
      if (w != 0) {
        // Samples strictly between prevX and crossX are inside the glyph.
        final int first = math.max(
          cursor,
          (prevX / cellWidth * sampleStep).ceil(),
        );
        final int last = math.min(
          sampleStep.toInt() - 1,
          (crossX / cellWidth * sampleStep).floor(),
        );
        for (int s = first; s <= last; s++) {
          coverage[ry * columns + (s ~/ sub).clamp(0, columns - 1)] += 1 / sub;
        }
      }
      w += windings[idx].toInt();
      prevX = crossX;
      cursor = math.max(cursor, (crossX / cellWidth * sampleStep).ceil());
    }
    if (w != 0) {
      final int first = cursor;
      for (int s = first; s < sampleStep; s++) {
        coverage[ry * columns + (s ~/ sub).clamp(0, columns - 1)] += 1 / sub;
      }
    }
  }
  return GlyphBitmap(columns, rows, coverage);
}

/// A supersampled glyph coverage grid.
class GlyphBitmap {
  /// Creates a bitmap.
  GlyphBitmap(this.columns, this.rows, this.coverage);

  /// Cells across.
  final int columns;

  /// Cells down.
  final int rows;

  /// Row-major coverage in `[0, 1]`.
  final List<double> coverage;

  /// Fraction of the layout box covered by ink.
  double get density {
    double sum = 0;
    for (final double v in coverage) {
      sum += v;
    }
    return sum / coverage.length;
  }
}

/// Rasterises `M` glyph into a [resolution]x[resolution] cell and returns the
/// fraction of the cell covered by ink, using the nonzero winding rule.
///
/// The cell matches the layout box (advance x line height), so densities are
/// comparable across characters and across fonts.
double measureGlyphDensity(TtfFont font, int codeUnit, {int resolution = 96}) {
  final GlyphBitmap? bitmap = rasteriseGlyph(
    font,
    codeUnit,
    columns: resolution,
    rows: resolution,
    samplesPerAxis: 1,
  );
  return bitmap?.density ?? 0;
}

/// Flattens a closed TrueType contour into a dense polyline.
///
/// Points carry an on-curve flag. A single off-curve point is the control of a
/// quadratic segment ending at the next on-curve point; two consecutive
/// off-curve points use the TrueType convention of an implied on-curve midpoint
/// between them. Curves are sampled adaptively so round glyphs (`o`, `@`)
/// measure their real area instead of a chord approximation.
List<double> _flattenContour(List<List<double>> contour, double tolerance) {
  final int n = contour.length;
  if (n < 2) return <double>[];

  // Rotate so the contour starts on an on-curve point.
  int start = 0;
  while (start < n && contour[start][2] < 0.5) {
    start++;
  }
  if (start == n) start = 0; // degenerate: all off-curve

  final List<double> out = <double>[];
  final double startX = contour[start][0];
  final double startY = contour[start][1];
  out
    ..add(startX)
    ..add(startY);

  double px = startX;
  double py = startY;
  for (int step = 1; step < n; step++) {
    final List<double> p = contour[(start + step) % n];
    final bool onCurve = p[2] > 0.5;
    if (onCurve) {
      _lineTo(out, px, py, p[0], p[1], tolerance);
      out
        ..add(p[0])
        ..add(p[1]);
      px = p[0];
      py = p[1];
      continue;
    }
    // Off-curve control point: resolve the true endpoint.
    final List<double> next = contour[(start + step + 1) % n];
    final bool nextOff = step + 1 < n && next[2] < 0.5;
    final double ex = nextOff ? (p[0] + next[0]) / 2 : next[0];
    final double ey = nextOff ? (p[1] + next[1]) / 2 : next[1];
    _quadTo(out, px, py, p[0], p[1], ex, ey, tolerance);
    out
      ..add(ex)
      ..add(ey);
    px = ex;
    py = ey;
  }
  if (px != startX || py != startY) {
    _lineTo(out, px, py, startX, startY, tolerance);
    out
      ..add(startX)
      ..add(startY);
  }
  return out;
}

void _lineTo(
  List<double> out,
  double x0,
  double y0,
  double x1,
  double y1,
  double tol,
) {
  final double dx = x1 - x0;
  final double dy = y1 - y0;
  final int steps = math.max(1, (math.sqrt(dx * dx + dy * dy) / tol).ceil());
  for (int s = 1; s < steps; s++) {
    final double t = s / steps;
    out
      ..add(x0 + dx * t)
      ..add(y0 + dy * t);
  }
}

void _quadTo(
  List<double> out,
  double x0,
  double y0,
  double cx,
  double cy,
  double x1,
  double y1,
  double tol,
) {
  // Subdivide until every control polygon leg is under the tolerance.
  final double flat =
      math.sqrt((cx - x0) * (cx - x0) + (cy - y0) * (cy - y0)) +
      math.sqrt((x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy));
  final int steps = math.min(4096, math.max(2, (flat / tol).ceil()));
  for (int s = 1; s < steps; s++) {
    final double t = s / steps;
    final double mt = 1 - t;
    out
      ..add(mt * mt * x0 + 2 * mt * t * cx + t * t * x1)
      ..add(mt * mt * y0 + 2 * mt * t * cy + t * t * y1);
  }
}

void _collectCrossings(
  List<double> poly,
  double y,
  List<double> xs,
  List<double> windings,
) {
  final int n = poly.length ~/ 2;
  for (int i = 0; i < n; i++) {
    final int j = (i + 1) % n;
    final double x0 = poly[i * 2];
    final double y0 = poly[i * 2 + 1];
    final double x1 = poly[j * 2];
    final double y1 = poly[j * 2 + 1];
    if (y0 == y1) continue;
    final bool straddles = (y0 <= y && y1 > y) || (y1 <= y && y0 > y);
    if (!straddles) continue;
    final double t = (y - y0) / (y1 - y0);
    xs.add(x0 + (x1 - x0) * t);
    windings.add(y1 > y0 ? 1 : -1);
  }
}

/// Measures every character in [chars] against [font].
List<GlyphMeasurement> measureRamp(
  TtfFont font,
  Iterable<String> chars, {
  int resolution = 96,
}) {
  return <GlyphMeasurement>[
    for (final String c in chars)
      GlyphMeasurement(
        char: c,
        density: measureGlyphDensity(
          font,
          c.codeUnitAt(0),
          resolution: resolution,
        ),
        advance: font.advanceFor(c.codeUnitAt(0)),
        hasGlyph: font.hasGlyphFor(c.codeUnitAt(0)),
      ),
  ];
}
