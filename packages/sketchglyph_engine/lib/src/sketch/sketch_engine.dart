/// Realistic sketch rendering engine.
///
/// Converts photographs into hand-drawn sketches with paper texture,
/// following local contour directions for hatching, and recording all
/// strokes for replay animation.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../color.dart';
import '../random.dart';
import '../resample.dart';

/// Sketch style presets.
enum SketchStyle {
  /// Hard graphite pencil, light lines.
  graphiteHb,

  /// Medium graphite pencil, balanced.
  graphite2b,

  /// Soft graphite pencil, dark and smudgy.
  graphite6b,

  /// Mechanical pencil, thin uniform lines.
  mechanicalPencil,

  /// Charcoal, very soft and wide strokes.
  charcoal,

  /// Blue ballpoint pen.
  ballpoint,

  /// Black fineliner/ink, crisp lines.
  fineliner,

  /// Coloured pencil, retains source colours.
  coloredPencil,

  /// Contour line art, outlines only.
  contourLineArt,

  /// Stipple/dotwork, tone from dot density.
  stipple,
}

/// Extension providing human-readable labels and stable IDs.
extension SketchStyleInfo on SketchStyle {
  /// Human-readable label.
  String get label => switch (this) {
    SketchStyle.graphiteHb => 'Graphite HB',
    SketchStyle.graphite2b => 'Graphite 2B',
    SketchStyle.graphite6b => 'Graphite 6B',
    SketchStyle.mechanicalPencil => 'Mechanical Pencil',
    SketchStyle.charcoal => 'Charcoal',
    SketchStyle.ballpoint => 'Ballpoint Pen',
    SketchStyle.fineliner => 'Fineliner',
    SketchStyle.coloredPencil => 'Colored Pencil',
    SketchStyle.contourLineArt => 'Contour Line Art',
    SketchStyle.stipple => 'Stipple',
  };

  /// Stable ID for persistence.
  String get id => switch (this) {
    SketchStyle.graphiteHb => 'graphite_hb',
    SketchStyle.graphite2b => 'graphite_2b',
    SketchStyle.graphite6b => 'graphite_6b',
    SketchStyle.mechanicalPencil => 'mechanical_pencil',
    SketchStyle.charcoal => 'charcoal',
    SketchStyle.ballpoint => 'ballpoint',
    SketchStyle.fineliner => 'fineliner',
    SketchStyle.coloredPencil => 'colored_pencil',
    SketchStyle.contourLineArt => 'contour_line_art',
    SketchStyle.stipple => 'stipple',
  };
}

/// Lookup a [SketchStyle] by its stable [id].
SketchStyle? sketchStyleById(String id) {
  for (final SketchStyle style in SketchStyle.values) {
    if (style.id == id) return style;
  }
  return null;
}

/// Paper type presets.
enum PaperType {
  /// White cartridge paper.
  whiteCartridge,

  /// Cream-toned paper.
  cream,

  /// Grey paper.
  grey,

  /// Kraft paper.
  kraft,

  /// Lined paper.
  lined,

  /// Grid paper.
  grid,
}

/// Extension providing paper metadata.
extension PaperTypeInfo on PaperType {
  /// Human-readable label.
  String get label => switch (this) {
    PaperType.whiteCartridge => 'White Cartridge',
    PaperType.cream => 'Cream',
    PaperType.grey => 'Grey',
    PaperType.kraft => 'Kraft',
    PaperType.lined => 'Lined',
    PaperType.grid => 'Grid',
  };

  /// Stable ID for persistence.
  String get id => switch (this) {
    PaperType.whiteCartridge => 'white_cartridge',
    PaperType.cream => 'cream',
    PaperType.grey => 'grey',
    PaperType.kraft => 'kraft',
    PaperType.lined => 'lined',
    PaperType.grid => 'grid',
  };

  /// Base paper colour as ARGB.
  int get baseArgb => switch (this) {
    PaperType.whiteCartridge => 0xFFF5F5F0,
    PaperType.cream => 0xFFF5E6D3,
    PaperType.grey => 0xFFD0D0D0,
    PaperType.kraft => 0xFFC4A57B,
    PaperType.lined => 0xFFF8F8F5,
    PaperType.grid => 0xFFF8F8F5,
  };
}

/// Lookup a [PaperType] by its stable [id].
PaperType? paperTypeById(String id) {
  for (final PaperType paper in PaperType.values) {
    if (paper.id == id) return paper;
  }
  return null;
}

/// Kind of stroke recorded.
enum StrokeKind {
  /// Line stroke.
  line,

  /// Dot.
  dot,

  /// Smudge.
  smudge,
}

/// A recorded stroke for replay.
class SketchStroke {
  /// Creates a stroke with the given parameters.
  SketchStroke({
    required this.points,
    required this.width,
    required this.alpha,
    required this.colorArgb,
    required this.kind,
  });

  /// Flattened point list [x0, y0, x1, y1, ...].
  final List<double> points;

  /// Stroke width in pixels.
  final double width;

  /// Stroke opacity 0..1.
  final double alpha;

  /// Stroke colour as ARGB.
  final int colorArgb;

  /// Kind of stroke.
  final StrokeKind kind;
}

/// Settings for the sketch renderer.
class SketchSettings {
  /// Creates sketch settings with the given parameters.
  SketchSettings({
    this.style = SketchStyle.graphite2b,
    this.paper = PaperType.whiteCartridge,
    this.detail = 1.0,
    this.lineWeight = 1.0,
    this.hatchDensity = 1.0,
    this.shading = 1.0,
    this.edgeStrength = 1.0,
    this.grain = 1.0,
    this.smudge = 1.0,
    this.inkFlow = 1.0,
    this.inkArgb = 0xFF2B2B2B,
    this.transparentBackground = false,
    this.longEdge = 1024,
    this.seed = 1,
  });

  /// Sketch style preset.
  final SketchStyle style;

  /// Paper type.
  final PaperType paper;

  /// Stroke count scale 0.5..2.
  final double detail;

  /// Line weight scale 0.3..3.
  final double lineWeight;

  /// Hatching density 0.3..2.5.
  final double hatchDensity;

  /// Overall tone strength 0..2.
  final double shading;

  /// Edge detection strength 0..3.
  final double edgeStrength;

  /// Paper tooth 0..2.
  final double grain;

  /// Charcoal smearing 0..2.
  final double smudge;

  /// Ballpoint unevenness 0..2.
  final double inkFlow;

  /// Pencil/ink colour as ARGB.
  final int inkArgb;

  /// Whether to skip paper fill and keep alpha in ink.
  final bool transparentBackground;

  /// Working size (long edge in pixels).
  final int longEdge;

  /// Random seed for determinism.
  final int seed;

  /// Serialises to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'style': style.id,
    'paper': paper.id,
    'detail': detail,
    'lineWeight': lineWeight,
    'hatchDensity': hatchDensity,
    'shading': shading,
    'edgeStrength': edgeStrength,
    'grain': grain,
    'smudge': smudge,
    'inkFlow': inkFlow,
    'inkArgb': inkArgb,
    'transparentBackground': transparentBackground,
    'longEdge': longEdge,
    'seed': seed,
  };

  /// Deserialises from JSON.
  factory SketchSettings.fromJson(Map<String, Object?> json) {
    return SketchSettings(
      style: sketchStyleById(json['style'] as String) ?? SketchStyle.graphite2b,
      paper: paperTypeById(json['paper'] as String) ?? PaperType.whiteCartridge,
      detail: (json['detail'] as num).toDouble(),
      lineWeight: (json['lineWeight'] as num).toDouble(),
      hatchDensity: (json['hatchDensity'] as num).toDouble(),
      shading: (json['shading'] as num).toDouble(),
      edgeStrength: (json['edgeStrength'] as num).toDouble(),
      grain: (json['grain'] as num).toDouble(),
      smudge: (json['smudge'] as num).toDouble(),
      inkFlow: (json['inkFlow'] as num).toDouble(),
      inkArgb: json['inkArgb'] as int,
      transparentBackground: json['transparentBackground'] as bool,
      longEdge: json['longEdge'] as int,
      seed: json['seed'] as int,
    );
  }

  /// Returns a copy with the given fields replaced.
  SketchSettings copyWith({
    SketchStyle? style,
    PaperType? paper,
    double? detail,
    double? lineWeight,
    double? hatchDensity,
    double? shading,
    double? edgeStrength,
    double? grain,
    double? smudge,
    double? inkFlow,
    int? inkArgb,
    bool? transparentBackground,
    int? longEdge,
    int? seed,
  }) {
    return SketchSettings(
      style: style ?? this.style,
      paper: paper ?? this.paper,
      detail: detail ?? this.detail,
      lineWeight: lineWeight ?? this.lineWeight,
      hatchDensity: hatchDensity ?? this.hatchDensity,
      shading: shading ?? this.shading,
      edgeStrength: edgeStrength ?? this.edgeStrength,
      grain: grain ?? this.grain,
      smudge: smudge ?? this.smudge,
      inkFlow: inkFlow ?? this.inkFlow,
      inkArgb: inkArgb ?? this.inkArgb,
      transparentBackground:
          transparentBackground ?? this.transparentBackground,
      longEdge: longEdge ?? this.longEdge,
      seed: seed ?? this.seed,
    );
  }
}

/// Result of a sketch render.
class SketchResult {
  /// Creates a result with the given image and strokes.
  SketchResult({required this.image, required this.strokes});

  /// Composited paper + graphite image.
  final RgbImage image;

  /// Recorded strokes in draw order.
  final List<SketchStroke> strokes;

  /// Image width.
  int get width => image.width;

  /// Image height.
  int get height => image.height;

  /// Encoded PNG bytes.
  Uint8List get pngBytes {
    final img.Image canvas = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 4,
    );
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final int i = y * image.width + x;
        canvas.setPixelRgba(
          x,
          y,
          image.r[i],
          image.g[i],
          image.b[i],
          image.a[i],
        );
      }
    }
    return Uint8List.fromList(img.encodePng(canvas));
  }
}

/// The sketch rendering engine.
class SketchEngine {
  /// Renders a sketch from the given [source] image with [settings].
  ///
  /// Deterministic: identical (source bytes, settings) produce identical output.
  static SketchResult render(
    RgbImage source,
    SketchSettings settings, {
    void Function(double progress)? onProgress,
  }) {
    final _SketchContext ctx = _SketchContext(source, settings);
    return ctx.render(onProgress: onProgress);
  }
}

class _SketchContext {
  _SketchContext(this.source, this.settings)
    : rng = SeededRandom(settings.seed),
      noise = ValueNoise2D(settings.seed, cell: 8.0);

  final RgbImage source;
  final SketchSettings settings;
  final SeededRandom rng;
  final ValueNoise2D noise;

  late int workWidth;
  late int workHeight;
  late GrayImage gray;
  late GrayImage edges;
  late List<double> orientationField;
  final List<SketchStroke> strokes = <SketchStroke>[];

  SketchResult render({void Function(double progress)? onProgress}) {
    // Downscale to working size.
    final int longEdge = math.max(source.width, source.height);
    final double scale = settings.longEdge / longEdge;
    workWidth = math.max(1, (source.width * scale).round());
    workHeight = math.max(1, (source.height * scale).round());

    // Convert to grayscale at working size.
    final GrayImage srcGray = source.toGray();
    gray = _resampleGray(srcGray, workWidth, workHeight);

    onProgress?.call(0.1);

    // Detect edges.
    edges = _detectEdges(gray, settings.edgeStrength);

    onProgress?.call(0.3);

    // Estimate local orientation field.
    orientationField = _estimateOrientation(gray);

    onProgress?.call(0.5);

    // Prepare output canvas with paper.
    final RgbImage output = RgbImage(
      workWidth,
      workHeight,
      hasAlpha: settings.transparentBackground,
    );
    if (settings.transparentBackground) {
      // Start with fully transparent canvas.
      for (int i = 0; i < output.length; i++) {
        output.a[i] = 0;
      }
    } else {
      _fillPaper(output);
    }

    onProgress?.call(0.6);

    // Render based on style.
    switch (settings.style) {
      case SketchStyle.graphiteHb:
      case SketchStyle.graphite2b:
      case SketchStyle.graphite6b:
        _renderGraphite(output);
      case SketchStyle.mechanicalPencil:
        _renderMechanicalPencil(output);
      case SketchStyle.charcoal:
        _renderCharcoal(output);
      case SketchStyle.ballpoint:
        _renderBallpoint(output);
      case SketchStyle.fineliner:
        _renderFineliner(output);
      case SketchStyle.coloredPencil:
        _renderColoredPencil(output);
      case SketchStyle.contourLineArt:
        _renderContourLineArt(output);
      case SketchStyle.stipple:
        _renderStipple(output);
    }

    onProgress?.call(0.9);

    // Apply paper grain.
    if (!settings.transparentBackground) {
      _applyPaperGrain(output);
    }

    onProgress?.call(1.0);

    return SketchResult(image: output, strokes: strokes);
  }

  GrayImage _resampleGray(GrayImage src, int dstW, int dstH) {
    final List<double> cells = areaAverage(src, dstW, dstH);
    final GrayImage out = GrayImage(dstW, dstH);
    for (int i = 0; i < cells.length; i++) {
      out.pixels[i] = (cells[i] * 255).round().clamp(0, 255);
    }
    return out;
  }

  GrayImage _detectEdges(GrayImage src, double strength) {
    // XDoG (extended Difference of Gaussians).
    final double sigma1 = 0.5;
    final double sigma2 = sigma1 * 1.6;
    final double tau = 0.98;
    final double phi = 0.01 * strength;

    final GrayImage g1 = gaussianBlur(src, sigma1);
    final GrayImage g2 = gaussianBlur(src, sigma2);

    final GrayImage dog = GrayImage(src.width, src.height);
    for (int i = 0; i < src.length; i++) {
      final double d = g1.pixels[i] - tau * g2.pixels[i];
      final double tanhValue = _tanh(d * 2);
      dog.pixels[i] = (d > phi ? 255 : (1 + tanhValue).clamp(0.0, 1.0) * 255)
          .round()
          .clamp(0, 255);
    }

    // Invert so edges are dark.
    final GrayImage inverted = GrayImage(src.width, src.height);
    for (int i = 0; i < dog.length; i++) {
      inverted.pixels[i] = 255 - dog.pixels[i];
    }

    return inverted;
  }

  double _tanh(double x) {
    final double exp2x = math.exp(2 * x);
    return (exp2x - 1) / (exp2x + 1);
  }

  // Binodal (pi-periodic) orientation field stored as double angles in
  // [-pi, pi), sampled by _getOrientation via shortest-arc bilinear
  // interpolation.
  static const int _orientationCell = 16;

  List<double> _estimateOrientation(GrayImage src) {
    // Structure tensor for local orientation. The gradient products are
    // Gaussian-smoothed before cell aggregation so neighboring cells share
    // overlapping support; hard box sums made hatch direction jump in
    // visible 16px blocks.
    final int w = src.width;
    final int h = src.height;
    final List<double> jxx = List<double>.filled(w * h, 0);
    final List<double> jxy = List<double>.filled(w * h, 0);
    final List<double> jyy = List<double>.filled(w * h, 0);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double gx = (src.at(x + 1, y) - src.at(x - 1, y)).toDouble() / 2;
        final double gy = (src.at(x, y + 1) - src.at(x, y - 1)).toDouble() / 2;
        final int i = y * w + x;
        jxx[i] = gx * gx;
        jxy[i] = gx * gy;
        jyy[i] = gy * gy;
      }
    }

    _boxBlurPair(jxx, w, h);
    _boxBlurPair(jxy, w, h);
    _boxBlurPair(jyy, w, h);

    final int cellSize = _orientationCell;
    final int cols = (w / cellSize).ceil();
    final int rows = (h / cellSize).ceil();
    final List<double> orientations = List<double>.filled(cols * rows, 0);

    for (int cy = 0; cy < rows; cy++) {
      final int y0 = cy * cellSize;
      final int y1 = math.min(y0 + cellSize, h);
      for (int cx = 0; cx < cols; cx++) {
        final int x0 = cx * cellSize;
        final int x1 = math.min(x0 + cellSize, w);

        double sxx = 0, sxy = 0, syy = 0;
        for (int y = y0; y < y1; y++) {
          final int row = y * w;
          for (int x = x0; x < x1; x++) {
            final int i = row + x;
            sxx += jxx[i];
            sxy += jxy[i];
            syy += jyy[i];
          }
        }

        // Store the double angle so interpolation can blend across the
        // pi-periodic seam via shortest arc. Hatch = angle/2 + pi/2.
        orientations[cy * cols + cx] = math.atan2(2 * sxy, sxx - syy);
      }
    }

    return orientations;
  }

  // Two-pass separable box blur (radius 8) along one axis then the other;
  // applying it twice approximates a Gaussian for smoothing purposes.
  void _boxBlurPair(List<double> values, int w, int h) {
    _boxBlurH(values, w, h, 8);
    _boxBlurH(values, w, h, 8);
    _boxBlurV(values, w, h, 8);
    _boxBlurV(values, w, h, 8);
  }

  void _boxBlurH(List<double> values, int w, int h, int radius) {
    final List<double> out = List<double>.filled(values.length, 0);
    for (int y = 0; y < h; y++) {
      final int row = y * w;
      for (int x = 0; x < w; x++) {
        final int a = math.max(0, x - radius);
        final int b = math.min(w - 1, x + radius);
        double sum = 0;
        for (int i = a; i <= b; i++) {
          sum += values[row + i];
        }
        out[row + x] = sum / (b - a + 1);
      }
    }
    values.setAll(0, out);
  }

  void _boxBlurV(List<double> values, int w, int h, int radius) {
    final List<double> out = List<double>.filled(values.length, 0);
    for (int y = 0; y < h; y++) {
      final int a = math.max(0, y - radius);
      final int b = math.min(h - 1, y + radius);
      final double inv = 1 / (b - a + 1);
      for (int x = 0; x < w; x++) {
        double sum = 0;
        for (int i = a; i <= b; i++) {
          sum += values[i * w + x];
        }
        out[y * w + x] = sum * inv;
      }
    }
    values.setAll(0, out);
  }

  double _getOrientation(int x, int y) {
    final int cellSize = _orientationCell;
    final int cols = (workWidth / cellSize).ceil();
    final int rows = (workHeight / cellSize).ceil();

    // Bilinear sample at cell centers; blend the shortest arc so a field
    // value of ~0 and ~pi interpolates through ~pi/2, not through pi.
    final double gx = (x + 0.5) / cellSize - 0.5;
    final double gy = (y + 0.5) / cellSize - 0.5;
    final int x0 = gx.floor().clamp(0, cols - 1);
    final int y0 = gy.floor().clamp(0, rows - 1);
    final int x1 = math.min(x0 + 1, cols - 1);
    final int y1 = math.min(y0 + 1, rows - 1);
    final double tx = (gx - x0).clamp(0.0, 1.0);
    final double ty = (gy - y0).clamp(0.0, 1.0);

    final double a00 = orientationField[y0 * cols + x0];
    final double a10 = orientationField[y0 * cols + x1];
    final double a01 = orientationField[y1 * cols + x0];
    final double a11 = orientationField[y1 * cols + x1];

    final double r0 = a00 + _shortestArc(a10 - a00) * tx;
    double r1 = a01 + _shortestArc(a11 - a01) * tx;
    double d = _shortestArc(r1 - r0);
    if (d > math.pi) {
      d -= 2 * math.pi;
    } else if (d < -math.pi) {
      d += 2 * math.pi;
    }
    r1 = r0 + d;
    return (r0 + d * ty) / 2 + math.pi / 2;
  }

  double _shortestArc(double delta) {
    double d = delta;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return d;
  }

  void _fillPaper(RgbImage output) {
    final int paperArgb = settings.paper.baseArgb;
    final int pr = (paperArgb >> 16) & 0xFF;
    final int pg = (paperArgb >> 8) & 0xFF;
    final int pb = paperArgb & 0xFF;

    for (int i = 0; i < output.length; i++) {
      output.r[i] = pr;
      output.g[i] = pg;
      output.b[i] = pb;
      output.a[i] = 255;
    }

    // Draw rules for lined/grid paper.
    if (settings.paper == PaperType.lined) {
      _drawLinedRules(output);
    } else if (settings.paper == PaperType.grid) {
      _drawGridRules(output);
    }
  }

  void _drawLinedRules(RgbImage output) {
    final int lineSpacing = 32;
    final int ruleColor = 0xCC;
    for (int y = lineSpacing; y < output.height; y += lineSpacing) {
      for (int x = 0; x < output.width; x++) {
        final int i = y * output.width + x;
        output.r[i] = ruleColor;
        output.g[i] = ruleColor;
        output.b[i] = ruleColor;
      }
    }
  }

  void _drawGridRules(RgbImage output) {
    final int gridSize = 32;
    final int ruleColor = 0xCC;
    for (int y = 0; y < output.height; y += gridSize) {
      for (int x = 0; x < output.width; x++) {
        final int i = y * output.width + x;
        output.r[i] = ruleColor;
        output.g[i] = ruleColor;
        output.b[i] = ruleColor;
      }
    }
    for (int x = 0; x < output.width; x += gridSize) {
      for (int y = 0; y < output.height; y++) {
        final int i = y * output.width + x;
        output.r[i] = ruleColor;
        output.g[i] = ruleColor;
        output.b[i] = ruleColor;
      }
    }
  }

  void _renderGraphite(RgbImage output) {
    final double hardness = switch (settings.style) {
      SketchStyle.graphiteHb => 0.3,
      SketchStyle.graphite2b => 0.6,
      SketchStyle.graphite6b => 1.0,
      _ => 0.6,
    };

    final double baseWidth = 1.5 + hardness * 2.0;
    final double baseAlpha = 0.15 + hardness * 0.25;
    final int inkR = (settings.inkArgb >> 16) & 0xFF;
    final int inkG = (settings.inkArgb >> 8) & 0xFF;
    final int inkB = settings.inkArgb & 0xFF;

    // Draw edge lines.
    _drawEdgeLines(
      output,
      baseWidth * settings.lineWeight,
      baseAlpha * (0.8 + hardness * 0.4),
      inkR,
      inkG,
      inkB,
    );

    // Hatch for tone.
    _hatchForTone(
      output,
      baseWidth * 0.8,
      baseAlpha * 0.6,
      inkR,
      inkG,
      inkB,
      crossHatch: hardness > 0.5,
    );

    // Smudge for soft graphite.
    if (hardness > 0.7) {
      _applySmudge(output, settings.smudge * hardness);
    }
  }

  void _renderMechanicalPencil(RgbImage output) {
    const double width = 0.8;
    const double alpha = 0.25;
    final int inkR = (settings.inkArgb >> 16) & 0xFF;
    final int inkG = (settings.inkArgb >> 8) & 0xFF;
    final int inkB = settings.inkArgb & 0xFF;

    _drawEdgeLines(
      output,
      width * settings.lineWeight,
      alpha,
      inkR,
      inkG,
      inkB,
    );
    _hatchForTone(
      output,
      width * 0.6,
      alpha * 0.5,
      inkR,
      inkG,
      inkB,
      crossHatch: false,
      fine: true,
    );
  }

  void _renderCharcoal(RgbImage output) {
    const double width = 4.0;
    const double alpha = 0.4;
    final int inkR = (settings.inkArgb >> 16) & 0xFF;
    final int inkG = (settings.inkArgb >> 8) & 0xFF;
    final int inkB = settings.inkArgb & 0xFF;

    _drawEdgeLines(
      output,
      width * settings.lineWeight,
      alpha,
      inkR,
      inkG,
      inkB,
      wobble: 2.0,
    );
    _hatchForTone(
      output,
      width * 1.5,
      alpha * 0.8,
      inkR,
      inkG,
      inkB,
      crossHatch: true,
      wobble: 1.5,
    );
    _applySmudge(output, settings.smudge * 1.5);
  }

  void _renderBallpoint(RgbImage output) {
    const double width = 1.2;
    final int inkR = 0x1E;
    final int inkG = 0x3A;
    final int inkB = 0x8C;

    _drawEdgeLines(
      output,
      width * settings.lineWeight,
      0.7,
      inkR,
      inkG,
      inkB,
      uneven: true,
    );
    _hatchForTone(
      output,
      width * 0.8,
      0.5,
      inkR,
      inkG,
      inkB,
      crossHatch: true,
      uneven: true,
    );
  }

  void _renderFineliner(RgbImage output) {
    const double width = 0.9;
    const double alpha = 0.7;
    final int inkR = (settings.inkArgb >> 16) & 0xFF;
    final int inkG = (settings.inkArgb >> 8) & 0xFF;
    final int inkB = settings.inkArgb & 0xFF;

    _drawEdgeLines(
      output,
      width * settings.lineWeight,
      alpha,
      inkR,
      inkG,
      inkB,
      crisp: true,
    );
    _stippleForTone(output, alpha * 0.4, inkR, inkG, inkB);
  }

  void _renderColoredPencil(RgbImage output) {
    final double width = 1.8;
    final double alpha = 0.3;

    _drawEdgeLinesColored(output, width * settings.lineWeight, alpha);
    _hatchForToneColored(output, width * 0.9, alpha * 0.6, crossHatch: true);
  }

  void _renderContourLineArt(RgbImage output) {
    final int inkR = (settings.inkArgb >> 16) & 0xFF;
    final int inkG = (settings.inkArgb >> 8) & 0xFF;
    final int inkB = settings.inkArgb & 0xFF;

    _drawEdgeLines(
      output,
      1.2 * settings.lineWeight,
      0.6,
      inkR,
      inkG,
      inkB,
      crisp: true,
    );
  }

  void _renderStipple(RgbImage output) {
    final int inkR = (settings.inkArgb >> 16) & 0xFF;
    final int inkG = (settings.inkArgb >> 8) & 0xFF;
    final int inkB = settings.inkArgb & 0xFF;

    _stippleForTone(output, 0.5, inkR, inkG, inkB, dense: true);
  }

  void _drawEdgeLines(
    RgbImage output,
    double width,
    double alpha,
    int inkR,
    int inkG,
    int inkB, {
    double wobble = 0.5,
    bool crisp = false,
    bool uneven = false,
  }) {
    final int threshold = (255 * 0.7).round();
    final int step = 3;

    for (int y = 0; y < edges.height; y += step) {
      for (int x = 0; x < edges.width; x += step) {
        if (edges.at(x, y) < threshold) continue;

        // Trace short stroke along edge.
        final List<double> points = <double>[];
        double px = x.toDouble();
        double py = y.toDouble();
        final int len = 8 + rng.intRange(0, 8);

        for (int i = 0; i < len; i++) {
          points.add(px);
          points.add(py);

          final double angle = _getOrientation(px.round(), py.round());
          final double w = crisp ? 0 : noise.fbm(px * 0.1, py * 0.1) * wobble;
          final double flowUneven = uneven
              ? 0.5 + rng.nextDouble() * settings.inkFlow
              : 1.0;

          px += math.cos(angle + w) * 1.5;
          py += math.sin(angle + w) * 1.5;

          if (px < 0 || px >= edges.width || py < 0 || py >= edges.height) {
            break;
          }

          // Pressure taper.
          final double t = i / len;
          final double pressure = math.sin(t * math.pi) * flowUneven;
          final double localWidth = width * (0.3 + pressure * 0.7);
          final double localAlpha = alpha * (0.3 + pressure * 0.7);

          final double prevX = points.length >= 4
              ? points[points.length - 4]
              : px;
          final double prevY = points.length >= 4
              ? points[points.length - 3]
              : py;
          _drawLineSegment(
            output,
            prevX,
            prevY,
            px,
            py,
            localWidth,
            localAlpha,
            inkR: inkR,
            inkG: inkG,
            inkB: inkB,
          );
        }

        if (points.length >= 4) {
          strokes.add(
            SketchStroke(
              points: points,
              width: width,
              alpha: alpha,
              colorArgb: (0xFF << 24) | (inkR << 16) | (inkG << 8) | inkB,
              kind: StrokeKind.line,
            ),
          );
        }

        if (strokes.length > 60000) return;
      }
    }
  }

  void _drawEdgeLinesColored(
    RgbImage output,
    double width,
    double alpha, {
    double wobble = 0.5,
  }) {
    final int threshold = (255 * 0.7).round();
    final int step = 3;

    for (int y = 0; y < edges.height; y += step) {
      for (int x = 0; x < edges.width; x += step) {
        if (edges.at(x, y) < threshold) continue;

        final List<double> points = <double>[];
        double px = x.toDouble();
        double py = y.toDouble();
        final int len = 8 + rng.intRange(0, 8);

        for (int i = 0; i < len; i++) {
          points.add(px);
          points.add(py);

          final double angle = _getOrientation(px.round(), py.round());
          final double w = noise.fbm(px * 0.1, py * 0.1) * wobble;

          px += math.cos(angle + w) * 1.5;
          py += math.sin(angle + w) * 1.5;

          if (px < 0 || px >= edges.width || py < 0 || py >= edges.height) {
            break;
          }

          final int srcIdx = py.round() * source.width + px.round();
          final int srcR = source.r[srcIdx.clamp(0, source.length - 1)];
          final int srcG = source.g[srcIdx.clamp(0, source.length - 1)];
          final int srcB = source.b[srcIdx.clamp(0, source.length - 1)];

          final double t = i / len;
          final double pressure = math.sin(t * math.pi);
          final double localWidth = width * (0.3 + pressure * 0.7);
          final double localAlpha = alpha * (0.3 + pressure * 0.7);

          final double prevX = points.length >= 4
              ? points[points.length - 4]
              : px;
          final double prevY = points.length >= 4
              ? points[points.length - 3]
              : py;
          _drawLineSegment(
            output,
            prevX,
            prevY,
            px,
            py,
            localWidth,
            localAlpha,
            inkR: srcR,
            inkG: srcG,
            inkB: srcB,
          );
        }

        if (points.length >= 4) {
          final int midIdx = (py.round() * source.width + px.round()).clamp(
            0,
            source.length - 1,
          );
          strokes.add(
            SketchStroke(
              points: points,
              width: width,
              alpha: alpha,
              colorArgb:
                  (0xFF << 24) |
                  (source.r[midIdx] << 16) |
                  (source.g[midIdx] << 8) |
                  source.b[midIdx],
              kind: StrokeKind.line,
            ),
          );
        }

        if (strokes.length > 60000) return;
      }
    }
  }

  void _hatchForTone(
    RgbImage output,
    double width,
    double alpha,
    int inkR,
    int inkG,
    int inkB, {
    bool crossHatch = false,
    bool fine = false,
    double wobble = 0.3,
    bool uneven = false,
  }) {
    final int cellSize = 16;
    final int cols = (workWidth / cellSize).ceil();
    final int rows = (workHeight / cellSize).ceil();
    final double density = settings.hatchDensity * settings.shading;

    for (int cy = 0; cy < rows; cy++) {
      for (int cx = 0; cx < cols; cx++) {
        final int x0 = cx * cellSize;
        final int y0 = cy * cellSize;
        final int x1 = math.min(x0 + cellSize, workWidth);
        final int y1 = math.min(y0 + cellSize, workHeight);

        // Average tone in cell.
        double tone = 0;
        int count = 0;
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            tone += 255 - gray.at(x, y);
            count++;
          }
        }
        tone = count > 0 ? tone / count / 255 : 0;

        if (tone < 0.1) continue;

        final double angle = _getOrientation(
          x0 + cellSize ~/ 2,
          y0 + cellSize ~/ 2,
        );
        final int numLines = (density * tone * (fine ? 8 : 5)).round();
        final double spacing = cellSize / (numLines + 1);

        for (int i = 0; i < numLines; i++) {
          final double offset = (i + 1) * spacing;
          final double cx0 = x0 + math.cos(angle + math.pi / 2) * offset;
          final double cy0 = y0 + math.sin(angle + math.pi / 2) * offset;
          final double flowUneven = uneven
              ? 0.5 + rng.nextDouble() * settings.inkFlow
              : 1.0;

          // Trace through the orientation field so lines flow across cell
          // boundaries instead of stopping at the 16px grid.
          _traceHatchLine(
            output,
            cx0 + rng.nextDouble() * 2 - 1,
            cy0 + rng.nextDouble() * 2 - 1,
            cellSize * 2.0,
            width,
            alpha * tone * flowUneven * 0.95,
            inkR,
            inkG,
            inkB,
            wobble: wobble,
            seedTone: tone,
          );

          if (strokes.length > 60000) return;
        }

        // Cross-hatching.
        if (crossHatch && tone > 0.4) {
          final double crossAngle = angle + math.pi / 4;
          final int crossLines = (density * tone * 3).round();
          final double crossSpacing = cellSize / (crossLines + 1);

          for (int i = 0; i < crossLines; i++) {
            final double offset = (i + 1) * crossSpacing;
            final double cx0 = x0 + math.cos(crossAngle + math.pi / 2) * offset;
            final double cy0 = y0 + math.sin(crossAngle + math.pi / 2) * offset;

            _traceHatchLine(
              output,
              cx0 + rng.nextDouble() * 2 - 1,
              cy0 + rng.nextDouble() * 2 - 1,
              cellSize * 2.0,
              width,
              alpha * tone * 0.7 * 0.95,
              inkR,
              inkG,
              inkB,
              wobble: wobble,
              directionOffset: math.pi / 4,
              seedTone: tone,
            );

            if (strokes.length > 60000) return;
          }
        }
      }
    }
  }

  // Draw a hatch line by walking the orientation field; alpha follows the
  // local tone so strokes fade out before spilling into highlights.
  void _traceHatchLine(
    RgbImage output,
    double sx,
    double sy,
    double len,
    double width,
    double baseAlpha,
    int inkR,
    int inkG,
    int inkB, {
    double wobble = 0.3,
    double directionOffset = 0,
    required double seedTone,
  }) {
    const double step = 2.0;
    // Vary the length and slide the start backwards along the flow so
    // neighbouring cells overlap and stroke ends never line up into a
    // visible grid seam.
    final double actualLen = len * (0.7 + rng.nextDouble() * 0.8);
    final int n = (actualLen / step).round();
    final int back = (n * (0.15 + rng.nextDouble() * 0.5)).round();

    double px = sx;
    double py = sy;
    for (int i = 0; i < back; i++) {
      final double dir =
          _getOrientation(px.round(), py.round()) + directionOffset + math.pi;
      final double nx = px + math.cos(dir) * step;
      final double ny = py + math.sin(dir) * step;
      if (nx < 0 || nx >= workWidth || ny < 0 || ny >= workHeight) break;
      px = nx;
      py = ny;
    }

    final List<double> points = <double>[px, py];
    for (int i = 0; i < n; i++) {
      final double t = _toneAt(px, py);
      if (t < 0.06) break;
      final double dir =
          _getOrientation(px.round(), py.round()) +
          directionOffset +
          noise.fbm(px * 0.05, py * 0.05) * wobble;
      final double nx = px + math.cos(dir) * step;
      final double ny = py + math.sin(dir) * step;
      if (nx < 0 || nx >= workWidth || ny < 0 || ny >= workHeight) break;

      final double progress = i / math.max(n - 1, 1);
      final double taper = math.sin(progress * math.pi) * 0.7 + 0.3;
      _drawLineSegment(
        output,
        px,
        py,
        nx,
        ny,
        width,
        baseAlpha * taper * (t / math.max(seedTone, 0.001)).clamp(0.0, 1.0),
        inkR: inkR,
        inkG: inkG,
        inkB: inkB,
      );
      points.add(nx);
      points.add(ny);
      px = nx;
      py = ny;
    }

    if (points.length < 4) return;
    strokes.add(
      SketchStroke(
        points: points,
        width: width,
        alpha: baseAlpha,
        colorArgb: (0xFF << 24) | (inkR << 16) | (inkG << 8) | inkB,
        kind: StrokeKind.line,
      ),
    );
  }

  double _toneAt(double x, double y) {
    final double fx = x.clamp(0, workWidth - 1.0);
    final double fy = y.clamp(0, workHeight - 1.0);
    final int x0 = fx.floor();
    final int y0 = fy.floor();
    final int x1 = math.min(x0 + 1, workWidth - 1);
    final int y1 = math.min(y0 + 1, workHeight - 1);
    final double tx = fx - x0;
    final double ty = fy - y0;
    final double a = gray.at(x0, y0).toDouble();
    final double b = gray.at(x1, y0).toDouble();
    final double c = gray.at(x0, y1).toDouble();
    final double d = gray.at(x1, y1).toDouble();
    final double v = (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty;
    return (255 - v) / 255;
  }

  void _hatchForToneColored(
    RgbImage output,
    double width,
    double alpha, {
    bool crossHatch = false,
  }) {
    final int cellSize = 16;
    final int cols = (workWidth / cellSize).ceil();
    final int rows = (workHeight / cellSize).ceil();
    final double density = settings.hatchDensity * settings.shading;

    for (int cy = 0; cy < rows; cy++) {
      for (int cx = 0; cx < cols; cx++) {
        final int x0 = cx * cellSize;
        final int y0 = cy * cellSize;
        final int x1 = math.min(x0 + cellSize, workWidth);
        final int y1 = math.min(y0 + cellSize, workHeight);

        double tone = 0;
        int count = 0;
        int srcR = 0, srcG = 0, srcB = 0;
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            tone += 255 - gray.at(x, y);
            final int srcIdx = (y * source.width + x).clamp(
              0,
              source.length - 1,
            );
            srcR += source.r[srcIdx];
            srcG += source.g[srcIdx];
            srcB += source.b[srcIdx];
            count++;
          }
        }
        if (count == 0) continue;
        tone = tone / count / 255;
        srcR = (srcR / count).round();
        srcG = (srcG / count).round();
        srcB = (srcB / count).round();

        if (tone < 0.1) continue;

        final double angle = _getOrientation(
          x0 + cellSize ~/ 2,
          y0 + cellSize ~/ 2,
        );
        final int numLines = (density * tone * 5).round();
        final double spacing = cellSize / (numLines + 1);

        for (int i = 0; i < numLines; i++) {
          final double offset = (i + 1) * spacing;
          final double cx0 = x0 + math.cos(angle + math.pi / 2) * offset;
          final double cy0 = y0 + math.sin(angle + math.pi / 2) * offset;

          _traceHatchLine(
            output,
            cx0 + rng.nextDouble() * 2 - 1,
            cy0 + rng.nextDouble() * 2 - 1,
            cellSize * 2.0,
            width,
            alpha * tone * 0.95,
            srcR,
            srcG,
            srcB,
            wobble: 0.3,
            seedTone: tone,
          );

          if (strokes.length > 60000) return;
        }

        if (crossHatch && tone > 0.4) {
          final double crossAngle = angle + math.pi / 4;
          final int crossLines = (density * tone * 3).round();
          final double crossSpacing = cellSize / (crossLines + 1);

          for (int i = 0; i < crossLines; i++) {
            final double offset = (i + 1) * crossSpacing;
            final double cx0 = x0 + math.cos(crossAngle + math.pi / 2) * offset;
            final double cy0 = y0 + math.sin(crossAngle + math.pi / 2) * offset;

            _traceHatchLine(
              output,
              cx0 + rng.nextDouble() * 2 - 1,
              cy0 + rng.nextDouble() * 2 - 1,
              cellSize * 2.0,
              width,
              alpha * tone * 0.7 * 0.95,
              srcR,
              srcG,
              srcB,
              wobble: 0.3,
              directionOffset: math.pi / 4,
              seedTone: tone,
            );

            if (strokes.length > 60000) return;
          }
        }
      }
    }
  }

  void _stippleForTone(
    RgbImage output,
    double alpha,
    int inkR,
    int inkG,
    int inkB, {
    bool dense = false,
  }) {
    final int cellSize = 8;
    final int cols = (workWidth / cellSize).ceil();
    final int rows = (workHeight / cellSize).ceil();
    final double density =
        settings.hatchDensity * settings.shading * (dense ? 2.0 : 1.0);

    for (int cy = 0; cy < rows; cy++) {
      for (int cx = 0; cx < cols; cx++) {
        final int x0 = cx * cellSize;
        final int y0 = cy * cellSize;
        final int x1 = math.min(x0 + cellSize, workWidth);
        final int y1 = math.min(y0 + cellSize, workHeight);

        double tone = 0;
        int count = 0;
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            tone += 255 - gray.at(x, y);
            count++;
          }
        }
        tone = count > 0 ? tone / count / 255 : 0;

        if (tone < 0.1) continue;

        final int numDots = (density * tone * 12).round();
        for (int i = 0; i < numDots; i++) {
          final double dx = x0 + rng.nextDouble() * cellSize;
          final double dy = y0 + rng.nextDouble() * cellSize;
          final double size = 0.5 + rng.nextDouble() * 1.5 * tone;

          _drawDot(output, dx, dy, size, alpha * tone, inkR, inkG, inkB);

          strokes.add(
            SketchStroke(
              points: <double>[dx, dy],
              width: size,
              alpha: alpha * tone,
              colorArgb: (0xFF << 24) | (inkR << 16) | (inkG << 8) | inkB,
              kind: StrokeKind.dot,
            ),
          );

          if (strokes.length > 60000) return;
        }
      }
    }
  }

  void _applySmudge(RgbImage output, double strength) {
    if (strength <= 0) return;

    final int radius = (strength * 3).round().clamp(1, 5);
    final List<int> tempR = List<int>.of(output.r);
    final List<int> tempG = List<int>.of(output.g);
    final List<int> tempB = List<int>.of(output.b);

    for (int y = radius; y < output.height - radius; y++) {
      for (int x = radius; x < output.width - radius; x++) {
        final int i = y * output.width + x;
        final int paperR = (settings.paper.baseArgb >> 16) & 0xFF;
        final int paperG = (settings.paper.baseArgb >> 8) & 0xFF;
        final int paperB = settings.paper.baseArgb & 0xFF;

        // Only smudge dark pixels (ink).
        final double inkAmount =
            1 - (tempR[i] + tempG[i] + tempB[i]) / (3 * 255);
        if (inkAmount < 0.1) continue;

        double sumR = 0, sumG = 0, sumB = 0;
        int count = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final int j = (y + dy) * output.width + (x + dx);
            sumR += tempR[j];
            sumG += tempG[j];
            sumB += tempB[j];
            count++;
          }
        }

        final double blend = strength * 0.3 * inkAmount;
        output.r[i] = (tempR[i] * (1 - blend) + (sumR / count) * blend)
            .round()
            .clamp(0, 255);
        output.g[i] = (tempG[i] * (1 - blend) + (sumG / count) * blend)
            .round()
            .clamp(0, 255);
        output.b[i] = (tempB[i] * (1 - blend) + (sumB / count) * blend)
            .round()
            .clamp(0, 255);

        // Blend toward paper in highlights.
        if (inkAmount < 0.3) {
          final double paperBlend = (0.3 - inkAmount) * strength * 0.2;
          output.r[i] = (output.r[i] * (1 - paperBlend) + paperR * paperBlend)
              .round()
              .clamp(0, 255);
          output.g[i] = (output.g[i] * (1 - paperBlend) + paperG * paperBlend)
              .round()
              .clamp(0, 255);
          output.b[i] = (output.b[i] * (1 - paperBlend) + paperB * paperBlend)
              .round()
              .clamp(0, 255);
        }
      }
    }

    // Record smudge strokes.
    for (int i = 0; i < 100; i++) {
      final double x = rng.nextDouble() * output.width;
      final double y = rng.nextDouble() * output.height;
      strokes.add(
        SketchStroke(
          points: <double>[x, y, x + rng.signed() * 20, y + rng.signed() * 20],
          width: radius * 2.0,
          alpha: strength * 0.2,
          colorArgb: settings.inkArgb,
          kind: StrokeKind.smudge,
        ),
      );
    }
  }

  void _applyPaperGrain(RgbImage output) {
    if (settings.grain <= 0) return;

    for (int y = 0; y < output.height; y++) {
      for (int x = 0; x < output.width; x++) {
        final int i = y * output.width + x;
        final double n = noise.fbm(x * 0.3, y * 0.3, octaves: 3);
        final double grain = (n - 0.5) * 30 * settings.grain;

        output.r[i] = (output.r[i] + grain).round().clamp(0, 255);
        output.g[i] = (output.g[i] + grain).round().clamp(0, 255);
        output.b[i] = (output.b[i] + grain).round().clamp(0, 255);
      }
    }
  }

  void _drawLineSegment(
    RgbImage output,
    double x0,
    double y0,
    double x1,
    double y1,
    double width,
    double alpha, {
    required int inkR,
    required int inkG,
    required int inkB,
  }) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.5) return;

    final int steps = (len * 2).round().clamp(1, 50);
    final double radius = width / 2;

    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double x = x0 + dx * t;
      final double y = y0 + dy * t;

      _drawSoftCircle(output, x, y, radius, alpha, inkR, inkG, inkB);
    }
  }

  void _drawSoftCircle(
    RgbImage output,
    double cx,
    double cy,
    double radius,
    double alpha,
    int inkR,
    int inkG,
    int inkB,
  ) {
    final int x0 = (cx - radius - 1).floor().clamp(0, output.width - 1);
    final int y0 = (cy - radius - 1).floor().clamp(0, output.height - 1);
    final int x1 = (cx + radius + 1).ceil().clamp(0, output.width - 1);
    final int y1 = (cy + radius + 1).ceil().clamp(0, output.height - 1);

    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        final double dx = x - cx;
        final double dy = y - cy;
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist > radius) continue;

        final double falloff = 1 - dist / radius;
        final double blend = alpha * falloff * falloff;

        final int i = y * output.width + x;
        output.r[i] = (output.r[i] * (1 - blend) + inkR * blend).round().clamp(
          0,
          255,
        );
        output.g[i] = (output.g[i] * (1 - blend) + inkG * blend).round().clamp(
          0,
          255,
        );
        output.b[i] = (output.b[i] * (1 - blend) + inkB * blend).round().clamp(
          0,
          255,
        );
        if (output.hasAlpha) {
          output.a[i] = math.max(
            output.a[i],
            (blend * 255).round().clamp(0, 255),
          );
        }
      }
    }
  }

  void _drawDot(
    RgbImage output,
    double cx,
    double cy,
    double radius,
    double alpha,
    int inkR,
    int inkG,
    int inkB,
  ) {
    _drawSoftCircle(output, cx, cy, radius, alpha, inkR, inkG, inkB);
  }
}
