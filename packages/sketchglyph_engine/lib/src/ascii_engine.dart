/// The ASCII rendering engine: preprocessing, grid sampling, tone mapping and
/// text/HTML/PNG outputs. Pure Dart and fully deterministic.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'color.dart';
import 'glyph_metrics.dart';
import 'ramps.dart';
import 'resample.dart';
import 'text_renderer.dart';

/// How the grid resolution is chosen.
enum GridSizing {
  /// Fixed number of columns.
  columns,

  /// Fit the grid to a page box at a given font size.
  fitToPage,
}

/// Tone mapping strategy.
enum AsciiMode {
  /// Tuned built-in ramp.
  defaultRamp,

  /// A curated or custom character set, auto-sorted by measured density.
  characterSet,

  /// User-supplied string (text-flow or ramp sub-behaviour).
  userString,
}

/// Sub-behaviour for [AsciiMode.userString].
enum UserStringMode {
  /// The string repeats across the grid; brightness modulates size/weight/alpha.
  textFlow,

  /// Unique characters of the string become the tone ramp.
  ramp,
}

/// Colour handling for the output.
enum ColorMode {
  /// Single foreground colour.
  mono,

  /// Per-cell colour sampled from the source image.
  original,

  /// Ramp position interpolated across a gradient.
  gradient,
}

/// Available dithering algorithms.
enum DitherKind {
  /// No dithering.
  none,

  /// Error-diffused Floyd-Steinberg.
  floydSteinberg,

  /// Ordered 4x4 Bayer matrix.
  bayer4,
}

/// Resample filter selection exposed to settings.
enum GridFilter {
  /// Integral box average.
  box,

  /// Windowed-sinc Lanczos3.
  lanczos,
}

/// Errors surfaced by the engine for user-fixable input problems.
class AsciiSettingsException implements Exception {
  /// Creates an exception with a user-facing [message].
  const AsciiSettingsException(this.message, {this.field});

  /// Message suitable for direct display.
  final String message;

  /// Which control the message refers to, if known.
  final String? field;

  @override
  String toString() => 'AsciiSettingsException($field): $message';
}

/// Everything needed to render one ASCII image.
class AsciiSettings {
  /// Creates settings.
  AsciiSettings({
    this.mode = AsciiMode.defaultRamp,
    this.characterSet = kDefaultRamp,
    this.userString = '',
    this.userStringMode = UserStringMode.ramp,
    this.sizing = GridSizing.columns,
    this.columns = 100,
    this.pageSize = PageBox.a4,
    this.font = 'JetBrains Mono',
    this.fontSize = 8.0,
    this.lineHeight = 1.15,
    this.letterSpacing = 0.0,
    this.filter = GridFilter.box,
    this.contrast = 1.0,
    this.brightness = 0.0,
    this.gamma = 1.0,
    this.invert = false,
    this.sharpen = 0.0,
    this.edgeMode = false,
    this.dither = DitherKind.none,
    this.ditherStrength = 1.0,
    this.colorMode = ColorMode.mono,
    this.foreground = 0xFFE8ECF1,
    this.background = 0xFF0E1116,
    this.gradientStart = 0xFF8B7CFF,
    this.gradientEnd = 0xFF4CC9F0,
    this.workingLongEdge = 2048,
    int? seed,
  }) : seed = seed ?? 0 {
    _validate();
  }

  /// Tone mapping mode.
  final AsciiMode mode;

  /// Characters used by [AsciiMode.characterSet].
  final String characterSet;

  /// The user's string for [AsciiMode.userString].
  final String userString;

  /// Sub-behaviour for [AsciiMode.userString].
  final UserStringMode userStringMode;

  /// How grid size is derived.
  final GridSizing sizing;

  /// Column count when [sizing] is [GridSizing.columns].
  final int columns;

  /// Target box when [sizing] is [GridSizing.fitToPage].
  final PageBox pageSize;

  /// Font family used for metrics and raster output.
  final String font;

  /// Font size in points (1pt = 1/72 inch) for raster and fit-to-page.
  final double fontSize;

  /// Line height multiplier.
  final double lineHeight;

  /// Extra letter spacing in em.
  final double letterSpacing;

  /// Area-average kernel.
  final GridFilter filter;

  /// Linear-light contrast multiplier.
  final double contrast;

  /// Linear-light brightness offset.
  final double brightness;

  /// Gamma exponent applied to linear light; `1` is neutral, `< 1` brightens.
  final double gamma;

  /// Whether dark source pixels map to light characters.
  final bool invert;

  /// Unsharp amount, `0` disables.
  final double sharpen;

  /// Sobel edge mode using directional characters.
  final bool edgeMode;

  /// Dithering algorithm.
  final DitherKind dither;

  /// Dithering strength multiplier.
  final double ditherStrength;

  /// Colour handling.
  final ColorMode colorMode;

  /// Mono foreground, ARGB.
  final int foreground;

  /// Background, ARGB.
  final int background;

  /// Gradient start, ARGB.
  final int gradientStart;

  /// Gradient end, ARGB.
  final int gradientEnd;

  /// Long edge used for processing; originals are kept for export.
  final int workingLongEdge;

  /// Seed for any jitter; `0` means deterministic defaults.
  final int seed;

  /// Fewest characters across the grid.
  static const int minColumns = 40;

  /// Most characters across the grid.
  static const int maxColumns = 400;

  /// Longest character set accepted as a ramp.
  static const int maxRampLength = 256;

  void _validate() {
    if (columns < minColumns || columns > maxColumns) {
      throw AsciiSettingsException(
        'Columns must be between $minColumns and $maxColumns.',
        field: 'columns',
      );
    }
    if (fontSize <= 0 || fontSize > 200) {
      throw AsciiSettingsException(
        'Font size must be between 1 and 200pt.',
        field: 'fontSize',
      );
    }
    if (lineHeight < 0.5 || lineHeight > 4) {
      throw AsciiSettingsException(
        'Line height must be between 0.5 and 4.',
        field: 'lineHeight',
      );
    }
    if (gamma <= 0) {
      throw AsciiSettingsException('Gamma must be positive.', field: 'gamma');
    }
    if (mode == AsciiMode.characterSet) {
      final List<String> chars = _uniqueChars(characterSet);
      if (chars.length < 2) {
        throw AsciiSettingsException(
          'A character set needs at least two different characters.',
          field: 'characterSet',
        );
      }
      if (chars.length > maxRampLength) {
        throw AsciiSettingsException(
          'Character sets are limited to $maxRampLength characters.',
          field: 'characterSet',
        );
      }
    }
    if (mode == AsciiMode.userString) {
      if (userString.trim().isEmpty) {
        throw AsciiSettingsException(
          'Enter some text to use for the art.',
          field: 'userString',
        );
      }
      if (userString.runes.length > 4096) {
        throw AsciiSettingsException(
          'That text is too long (4096 max).',
          field: 'userString',
        );
      }
      final List<String> unique = _uniqueChars(userString);
      if (unique.every((String c) => c == ' ')) {
        throw AsciiSettingsException(
          'The text contains no visible characters.',
          field: 'userString',
        );
      }
      if (userStringMode == UserStringMode.ramp && unique.length < 2) {
        throw AsciiSettingsException(
          'Ramp mode needs at least two different characters in the text.',
          field: 'userString',
        );
      }
    }
  }

  static List<String> _uniqueChars(String s) {
    final Set<String> seen = <String>{};
    for (final int r in s.runes) {
      seen.add(String.fromCharCode(r));
    }
    return seen.toList()..sort();
  }

  /// Copies with the given fields replaced.
  AsciiSettings copyWith({
    AsciiMode? mode,
    String? characterSet,
    String? userString,
    UserStringMode? userStringMode,
    GridSizing? sizing,
    int? columns,
    PageBox? pageSize,
    String? font,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    GridFilter? filter,
    double? contrast,
    double? brightness,
    double? gamma,
    bool? invert,
    double? sharpen,
    bool? edgeMode,
    DitherKind? dither,
    double? ditherStrength,
    ColorMode? colorMode,
    int? foreground,
    int? background,
    int? gradientStart,
    int? gradientEnd,
    int? workingLongEdge,
    int? seed,
  }) => AsciiSettings(
    mode: mode ?? this.mode,
    characterSet: characterSet ?? this.characterSet,
    userString: userString ?? this.userString,
    userStringMode: userStringMode ?? this.userStringMode,
    sizing: sizing ?? this.sizing,
    columns: columns ?? this.columns,
    pageSize: pageSize ?? this.pageSize,
    font: font ?? this.font,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    filter: filter ?? this.filter,
    contrast: contrast ?? this.contrast,
    brightness: brightness ?? this.brightness,
    gamma: gamma ?? this.gamma,
    invert: invert ?? this.invert,
    sharpen: sharpen ?? this.sharpen,
    edgeMode: edgeMode ?? this.edgeMode,
    dither: dither ?? this.dither,
    ditherStrength: ditherStrength ?? this.ditherStrength,
    colorMode: colorMode ?? this.colorMode,
    foreground: foreground ?? this.foreground,
    background: background ?? this.background,
    gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd,
    workingLongEdge: workingLongEdge ?? this.workingLongEdge,
    seed: seed ?? this.seed,
  );

  /// Serialises to JSON for persistence.
  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    'characterSet': characterSet,
    'userString': userString,
    'userStringMode': userStringMode.name,
    'sizing': sizing.name,
    'columns': columns,
    'pageSize': pageSize.toJson(),
    'font': font,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'letterSpacing': letterSpacing,
    'filter': filter.name,
    'contrast': contrast,
    'brightness': brightness,
    'gamma': gamma,
    'invert': invert,
    'sharpen': sharpen,
    'edgeMode': edgeMode,
    'dither': dither.name,
    'ditherStrength': ditherStrength,
    'colorMode': colorMode.name,
    'foreground': foreground,
    'background': background,
    'gradientStart': gradientStart,
    'gradientEnd': gradientEnd,
    'workingLongEdge': workingLongEdge,
    'seed': seed,
  };

  /// Reads back [toJson].
  factory AsciiSettings.fromJson(Map<String, Object?> json) => AsciiSettings(
    mode: AsciiMode.values.byName(json['mode'] as String? ?? 'defaultRamp'),
    characterSet: json['characterSet'] as String? ?? kDefaultRamp,
    userString: json['userString'] as String? ?? '',
    userStringMode: UserStringMode.values.byName(
      json['userStringMode'] as String? ?? 'ramp',
    ),
    sizing: GridSizing.values.byName(json['sizing'] as String? ?? 'columns'),
    columns: (json['columns'] as num?)?.toInt() ?? 100,
    pageSize: json['pageSize'] == null
        ? PageBox.a4
        : PageBox.fromJson(json['pageSize']! as Map<String, Object?>),
    font: json['font'] as String? ?? 'JetBrains Mono',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 8,
    lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.15,
    letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
    filter: GridFilter.values.byName(json['filter'] as String? ?? 'box'),
    contrast: (json['contrast'] as num?)?.toDouble() ?? 1,
    brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
    gamma: (json['gamma'] as num?)?.toDouble() ?? 1,
    invert: json['invert'] as bool? ?? false,
    sharpen: (json['sharpen'] as num?)?.toDouble() ?? 0,
    edgeMode: json['edgeMode'] as bool? ?? false,
    dither: DitherKind.values.byName(json['dither'] as String? ?? 'none'),
    ditherStrength: (json['ditherStrength'] as num?)?.toDouble() ?? 1,
    colorMode: ColorMode.values.byName(json['colorMode'] as String? ?? 'mono'),
    foreground: (json['foreground'] as num?)?.toInt() ?? 0xFFE8ECF1,
    background: (json['background'] as num?)?.toInt() ?? 0xFF0E1116,
    gradientStart: (json['gradientStart'] as num?)?.toInt() ?? 0xFF8B7CFF,
    gradientEnd: (json['gradientEnd'] as num?)?.toInt() ?? 0xFF4CC9F0,
    workingLongEdge: (json['workingLongEdge'] as num?)?.toInt() ?? 2048,
    seed: (json['seed'] as num?)?.toInt(),
  );
}

/// A page box in millimetres.
class PageBox {
  /// Creates a page box.
  const PageBox(this.widthMm, this.heightMm, {this.marginMm = 12});

  /// A4 portrait with 12mm margins.
  static const PageBox a4 = PageBox(210, 297);

  /// Letter portrait.
  static const PageBox letter = PageBox(215.9, 279.4);

  /// Square social preset.
  static const PageBox square = PageBox(135, 135, marginMm: 0);

  /// Width in millimetres.
  final double widthMm;

  /// Height in millimetres.
  final double heightMm;

  /// Page margin in millimetres.
  final double marginMm;

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
    'w': widthMm,
    'h': heightMm,
    'm': marginMm,
  };

  /// Reads [toJson].
  factory PageBox.fromJson(Map<String, Object?> json) => PageBox(
    (json['w'] as num).toDouble(),
    (json['h'] as num).toDouble(),
    marginMm: (json['m'] as num?)?.toDouble() ?? 12,
  );
}

/// A rendered ASCII document.
class AsciiDocument {
  /// Creates a document.
  AsciiDocument({
    required this.columns,
    required this.rows,
    required this.cells,
    required this.tones,
    required this.edgeDirections,
    required this.metrics,
    required this.settings,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  /// Grid width in characters.
  final int columns;

  /// Grid height in lines.
  final int rows;

  /// Row-major characters.
  final List<String> cells;

  /// Normalised tone per cell, `0` light .. `1` dark.
  final List<double> tones;

  /// Edge direction index per cell for [AsciiSettings.edgeMode] (`-1` = none).
  final List<int> edgeDirections;

  /// Font metrics the render used.
  final FontMetrics metrics;

  /// Settings the render used.
  final AsciiSettings settings;

  /// Working image width.
  final int sourceWidth;

  /// Working image height.
  final int sourceHeight;

  /// Plain text output, newline separated.
  String toPlainText() {
    final StringBuffer sb = StringBuffer();
    for (int y = 0; y < rows; y++) {
      sb.write(cells.sublist(y * columns, (y + 1) * columns).join());
      if (y != rows - 1) sb.write('\n');
    }
    return sb.toString();
  }

  /// Per-cell colours, ARGB, aligned with [cells].
  late final List<int> colors = _computeColors();

  List<int> _computeColors() {
    final AsciiSettings s = settings;
    final List<int> out = List<int>.filled(cells.length, s.foreground);
    switch (s.colorMode) {
      case ColorMode.mono:
        break;
      case ColorMode.gradient:
        for (int i = 0; i < out.length; i++) {
          out[i] = _lerpArgb(s.gradientStart, s.gradientEnd, tones[i]);
        }
      case ColorMode.original:
        for (int i = 0; i < out.length; i++) {
          out[i] = _lerpArgb(s.foreground, s.background, 1 - tones[i]);
        }
    }
    return out;
  }

  /// Self-contained HTML that reproduces the on-screen preview exactly.
  String toHtml({int? backgroundArgb}) {
    final int bg = backgroundArgb ?? settings.background;
    final StringBuffer sb = StringBuffer();
    sb.write(
      '<!DOCTYPE html><html><head><meta charset="utf-8">'
      '<title>SketchGlyph ASCII</title><style>',
    );
    sb.write(
      'body{margin:0;background:#'
      '${_hex(bg)};}pre{margin:0;font-family:"${settings.font}",monospace;'
      'font-size:${settings.fontSize}pt;line-height:${settings.lineHeight};'
      'letter-spacing:${settings.letterSpacing}em;',
    );
    sb.write('background:#${_hex(bg)};color:#${_hex(settings.foreground)};');
    sb.write('}</style></head><body><pre>');
    if (settings.colorMode == ColorMode.mono) {
      for (int y = 0; y < rows; y++) {
        sb.write(
          _escapeHtml(cells.sublist(y * columns, (y + 1) * columns).join()),
        );
        if (y != rows - 1) sb.write('\n');
      }
    } else {
      for (int y = 0; y < rows; y++) {
        int? runStart;
        for (int x = 0; x < columns; x++) {
          final int i = y * columns + x;
          final int argb = colors[i];
          if (runStart != argb) {
            if (runStart != null) sb.write('</span>');
            sb.write('<span style="color:#${_hex(argb)}">');
            runStart = argb;
          }
          sb.write(_escapeHtml(cells[i]));
        }
        sb.write('</span>\n');
      }
    }
    sb.write('</pre></body></html>');
    return sb.toString();
  }

  /// Rasterises the document to PNG.
  ///
  /// When [glyphs] is supplied the real glyph outlines are rendered, so the
  /// image uses exactly the same cell metrics as the on-screen preview. Without
  /// a glyph source the raster falls back to tone-sized ink squares, which keeps
  /// the PNG byte-identical for a given document in both cases.
  Uint8List toPng({
    double scale = 2.0,
    bool transparentBackground = false,
    GlyphSource? glyphs,
    int? backgroundArgb,
  }) => renderAsciiPng(
    this,
    scale: scale,
    transparentBackground: transparentBackground,
    glyphs: glyphs,
    backgroundArgb: backgroundArgb,
  );

  static String _hex(int argb) =>
      (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  static String _escapeHtml(String s) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(s);
}

int _lerpArgb(int a, int b, double t) {
  final double k = t.clamp(0.0, 1.0);
  int part(int shift) =>
      (((a >> shift) & 0xFF) +
              (((b >> shift) & 0xFF) - ((a >> shift) & 0xFF)) * k)
          .round()
          .clamp(0, 255);
  return (part(24) << 24) | (part(16) << 16) | (part(8) << 8) | part(0);
}

/// Directional characters for Sobel edge mode, indexed by quantised gradient
/// angle: 0 `/`, 1 `\`, 2 `|`, 3 `-`, 4 `_`, 5 `.`, 6 ` `, 7 `'`.
const List<String> kEdgeChars = <String>[
  '/',
  '\\',
  '|',
  '-',
  '_',
  '.',
  ' ',
  "'",
];

/// The ASCII engine.
class AsciiEngine {
  /// Creates an engine with measured font metrics keyed by family name.
  AsciiEngine(this.metricsByFont, {this.densityFallback = _codepointDensity});

  /// Measured metrics per bundled font family.
  final Map<String, FontMetrics> metricsByFont;

  /// Fallback density for characters missing from a metrics table.
  final double Function(String char) densityFallback;

  static double _codepointDensity(String char) =>
      char.codeUnitAt(0) == 0x20 ? 0.0 : 0.5;

  /// Metrics for [family], or synthetic fallback metrics so rendering never
  /// fails when a font table is missing.
  FontMetrics metricsFor(String family) {
    final FontMetrics? m = metricsByFont[family];
    if (m != null) return m;
    return FontMetrics(
      family: family,
      unitsPerEm: 1000,
      advance: 600,
      ascender: 750,
      descender: -250,
      densities: const <String, double>{},
      missingGlyphs: const <String>[],
    );
  }

  /// Rasterises [image] to a document.
  AsciiDocument render(RgbImage image, AsciiSettings settings) {
    final FontMetrics metrics = metricsFor(settings.font);
    final GrayImage gray = _preprocess(image, settings);

    final (int cols, int rows) = _gridFor(
      gray.width,
      gray.height,
      settings,
      metrics,
    );

    final List<double> luminance = areaAverage(
      gray,
      cols,
      rows,
      filter: settings.filter == GridFilter.box
          ? ResampleFilter.box
          : ResampleFilter.lanczos,
    );

    // Tones are stored as *darkness* (0 light .. 1 dark) so they index the ramp
    // directly: dark source areas get dense characters.
    final List<double> tones = _tones(luminance, settings, cols, rows);
    final List<String> ramp = resolveRamp(settings, metrics);
    final List<int> edge = settings.edgeMode
        ? _edgeDirections(gray, cols, rows)
        : List<int>.filled(tones.length, -1);

    final List<String> out = List<String>.filled(tones.length, ' ');
    for (int i = 0; i < tones.length; i++) {
      final int dir = edge[i];
      if (settings.edgeMode) {
        out[i] = dir < 0 ? ' ' : kEdgeChars[dir % kEdgeChars.length];
        continue;
      }
      if (settings.mode == AsciiMode.userString &&
          settings.userStringMode == UserStringMode.textFlow) {
        out[i] = _textFlowChar(settings, i);
      } else {
        out[i] = _mapToRamp(tones[i], ramp);
      }
    }

    return AsciiDocument(
      columns: cols,
      rows: rows,
      cells: out,
      tones: tones,
      edgeDirections: edge,
      metrics: metrics,
      settings: settings,
      sourceWidth: gray.width,
      sourceHeight: gray.height,
    );
  }

  /// The ramp actually used, always ordered by measured density.
  List<String> resolveRamp(AsciiSettings settings, FontMetrics metrics) {
    switch (settings.mode) {
      case AsciiMode.defaultRamp:
        return _sorted(kDefaultRamp, metrics, settings);
      case AsciiMode.characterSet:
        return _sorted(settings.characterSet, metrics, settings);
      case AsciiMode.userString:
        return _sorted(settings.userString, metrics, settings);
    }
  }

  List<String> _sorted(
    String chars,
    FontMetrics metrics,
    AsciiSettings settings,
  ) {
    final Iterable<String> raw = chars.runes.map(String.fromCharCode);
    final List<String> supported = <String>[
      for (final String c in raw)
        if (_isSupported(c, metrics)) c,
    ];
    if (supported.isEmpty) return <String>[' '];
    return buildRamp(supported, (String c) {
      final double? measured = metrics.densities[c];
      if (measured != null) return measured;
      // Space is always lightest; everything else falls back deterministically.
      return c == ' ' ? 0.0 : densityFallback(c);
    });
  }

  bool _isSupported(String c, FontMetrics metrics) {
    if (c == ' ') return true;
    if (metrics.densities.containsKey(c)) return true;
    // Characters outside the measured table are kept when the table is empty
    // (fallback metrics) so custom fonts still render.
    return metrics.densities.isEmpty;
  }

  String _textFlowChar(AsciiSettings settings, int index) {
    final List<int> runes = settings.userString.runes.toList();
    if (runes.isEmpty) return ' ';
    final int position = index % runes.length;
    return String.fromCharCode(runes[position]);
  }

  /// A text-flow document that also exposes per-cell weight/opacity.
  TextFlowResult renderTextFlow(RgbImage image, AsciiSettings settings) {
    final AsciiDocument doc = render(image, settings);
    final List<int> runes = settings.userString.runes.toList();
    final List<double> weights = <double>[];
    final List<double> opacities = <double>[];
    for (int i = 0; i < doc.tones.length; i++) {
      final double tone = doc.tones[i];
      weights.add(0.6 + tone * 1.8);
      opacities.add(0.15 + tone * 0.85);
    }
    return TextFlowResult(
      document: doc,
      sequenceLength: runes.length,
      weights: weights,
      opacities: opacities,
    );
  }

  GrayImage _preprocess(RgbImage image, AsciiSettings settings) {
    GrayImage gray = image.toGray();
    if (settings.workingLongEdge > 0) {
      gray = downscaleGray(gray, settings.workingLongEdge);
    }
    if (settings.sharpen > 0) {
      gray = sharpen(gray, amount: settings.sharpen);
    }
    final GrayImage adjusted = GrayImage(gray.width, gray.height);
    final List<int> lut = _toneLut(settings);
    for (int i = 0; i < gray.length; i++) {
      adjusted.pixels[i] = lut[gray.pixels[i]];
    }
    return adjusted;
  }

  List<int> _toneLut(AsciiSettings settings) {
    // Brightness/contrast/gamma in linear light. Invert is applied at the tone
    // stage instead, so it does not interact with dithering twice.
    final List<int> lut = List<int>.filled(256, 0);
    for (int v = 0; v < 256; v++) {
      double linear = grayToLinear[v];
      linear = (linear * settings.contrast + settings.brightness).clamp(0, 1);
      if (settings.gamma != 1) {
        // Values live in linear light, so the gamma exponent applies directly:
        // gamma < 1 brightens, gamma > 1 darkens.
        linear = math.pow(linear, settings.gamma).toDouble();
      }
      // Re-encode to sRGB so the buffer stays consistently encoded and the
      // later area-average pass is the only place linear light is recovered.
      lut[v] =
          linearToGray[(linear.clamp(0.0, 1.0) * 255).round().clamp(0, 255)];
    }
    return lut;
  }

  List<double> _tones(
    List<double> luminance,
    AsciiSettings settings,
    int cols,
    int rows,
  ) {
    // Tone is *darkness* in 0..1 so it indexes a light-to-dark ramp directly:
    // dark source areas get dense characters.
    final List<double> tones = List<double>.of(luminance, growable: false);
    for (int i = 0; i < tones.length; i++) {
      final double l = tones[i].clamp(0.0, 1.0);
      tones[i] = settings.invert ? l : 1.0 - l;
    }
    switch (settings.dither) {
      case DitherKind.none:
        break;
      case DitherKind.floydSteinberg:
        return _floydSteinberg(tones, settings, cols, rows);
      case DitherKind.bayer4:
        return _bayer(tones, settings, cols, rows);
    }
    return tones;
  }

  /// Quantises a tone to the ramp index.
  int rampIndex(double tone, int rampLength) {
    if (rampLength <= 1) return 0;
    return (tone.clamp(0.0, 1.0) * (rampLength - 1) + 0.5).floor().clamp(
      0,
      rampLength - 1,
    );
  }

  String _mapToRamp(double tone, List<String> ramp) =>
      ramp[rampIndex(tone, ramp.length)];

  List<double> _floydSteinberg(
    List<double> tones,
    AsciiSettings settings,
    int cols,
    int rows,
  ) {
    final List<String> ramp = resolveRamp(settings, metricsFor(settings.font));
    if (ramp.length <= 1) return tones;
    final List<double> src = List<double>.of(tones);
    final List<double> dst = List<double>.filled(tones.length, 0);
    final double s = settings.ditherStrength;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final int i = y * cols + x;
        final double old = src[i].clamp(0.0, 1.0);
        final int idx = rampIndex(old, ramp.length);
        final double quantised = idx / (ramp.length - 1);
        dst[i] = quantised;
        final double err = (old - quantised) * s;
        void push(int xx, int yy, double k) {
          if (xx < 0 || yy < 0 || xx >= cols || yy >= rows) return;
          src[yy * cols + xx] += err * k;
        }

        push(x + 1, y, 7 / 16);
        push(x - 1, y + 1, 3 / 16);
        push(x, y + 1, 5 / 16);
        push(x + 1, y + 1, 1 / 16);
      }
    }
    return dst;
  }

  List<double> _bayer(
    List<double> tones,
    AsciiSettings settings,
    int cols,
    int rows,
  ) {
    const List<List<int>> matrix = <List<int>>[
      <int>[0, 8, 2, 10],
      <int>[12, 4, 14, 6],
      <int>[3, 11, 1, 9],
      <int>[15, 7, 13, 5],
    ];
    final List<String> ramp = resolveRamp(settings, metricsFor(settings.font));
    if (ramp.length <= 1) return tones;
    final double step = 1 / (ramp.length - 1);
    final List<double> out = List<double>.filled(tones.length, 0);
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final int i = y * cols + x;
        final double threshold = (matrix[y % 4][x % 4] + 0.5) / 16 - 0.5;
        final double v = tones[i] + threshold * step * settings.ditherStrength;
        out[i] = rampIndex(v, ramp.length) * step;
      }
    }
    return out;
  }

  /// Cell width in millimetres for a given font size and tracking.
  static double cellWidthMm(AsciiSettings settings, FontMetrics metrics) =>
      settings.fontSize /
      72 *
      25.4 *
      metrics.advanceRatio *
      (1 + settings.letterSpacing);

  (int, int) _gridFor(
    int width,
    int height,
    AsciiSettings settings,
    FontMetrics metrics,
  ) {
    // A text cell is not square: its width is the advance and its height the
    // line advance. Grid rows must compensate, otherwise the result is
    // horizontally stretched.
    final double cellAspect =
        metrics.advanceRatio / (metrics.lineBoxRatio * settings.lineHeight);
    int cols;
    if (settings.sizing == GridSizing.fitToPage) {
      final PageBox p = settings.pageSize;
      final double printableMm = math.max(1, p.widthMm - 2 * p.marginMm);
      final double cellMm = cellWidthMm(settings, metrics);
      cols = (printableMm / cellMm).floor().clamp(
        AsciiSettings.minColumns,
        AsciiSettings.maxColumns,
      );
    } else {
      cols = settings.columns;
    }
    // Output aspect must match the source: (cols*cellW)/(rows*cellH)=w/h.
    final int rows = (cols * cellAspect * height / width).round().clamp(
      1,
      4096,
    );
    return (cols, rows);
  }

  List<int> _edgeDirections(GrayImage gray, int cols, int rows) {
    final List<int> out = List<int>.filled(cols * rows, -1);
    final double sx = gray.width / cols;
    final double sy = gray.height / rows;
    for (int cy = 0; cy < rows; cy++) {
      for (int cx = 0; cx < cols; cx++) {
        final int x = math.min(gray.width - 1, (cx * sx).round());
        final int y = math.min(gray.height - 1, (cy * sy).round());
        final int xm = math.max(0, x - 1);
        final int xp = math.min(gray.width - 1, x + 1);
        final int ym = math.max(0, y - 1);
        final int yp = math.min(gray.height - 1, y + 1);
        final double tl = gray.at(xm, ym).toDouble();
        final double t = gray.at(x, ym).toDouble();
        final double tr = gray.at(xp, ym).toDouble();
        final double l = gray.at(xm, y).toDouble();
        final double r = gray.at(xp, y).toDouble();
        final double bl = gray.at(xm, yp).toDouble();
        final double b = gray.at(x, yp).toDouble();
        final double br = gray.at(xp, yp).toDouble();
        final double gx = (tr + 2 * r + br) - (tl + 2 * l + bl);
        final double gy = (bl + 2 * b + br) - (tl + 2 * t + tr);
        final double mag = math.sqrt(gx * gx + gy * gy);
        if (mag < 24) continue;
        final double angle = math.atan2(gy, gx);
        // Gradient is perpendicular to the edge; quantise the *edge* direction
        // into 8 buckets.
        final double edgeAngle = angle + math.pi / 2;
        int bucket = ((edgeAngle / math.pi) * 4).round();
        bucket = ((bucket % 8) + 8) % 8;
        out[cy * cols + cx] = bucket;
      }
    }
    return out;
  }
}

/// Text-flow render extras: per-cell weight and opacity for the UI to draw.
class TextFlowResult {
  /// Creates a result.
  TextFlowResult({
    required this.document,
    required this.sequenceLength,
    required this.weights,
    required this.opacities,
  });

  /// The document with repeating characters.
  final AsciiDocument document;

  /// Number of characters in the user's string.
  final int sequenceLength;

  /// Per-cell relative weight/size multiplier.
  final List<double> weights;

  /// Per-cell opacity in `[0, 1]`.
  final List<double> opacities;
}

/// Decodes bytes into a planar [RgbImage]; throws on unsupported input.
///
/// EXIF orientation is baked into the pixel data so downstream code never has
/// to care about it.
RgbImage decodeImageBytes(Uint8List bytes) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw AsciiSettingsException(
      'This file could not be read as an image.',
      field: 'source',
    );
  }
  final img.Image upright = img.bakeOrientation(decoded);
  final img.Image rgba = upright.convert(numChannels: 4);
  final RgbImage out = RgbImage(rgba.width, rgba.height, hasAlpha: true);
  for (int y = 0; y < rgba.height; y++) {
    for (int x = 0; x < rgba.width; x++) {
      final img.Pixel p = rgba.getPixel(x, y);
      final int i = y * rgba.width + x;
      out.r[i] = p.r.clamp(0, 255).round();
      out.g[i] = p.g.clamp(0, 255).round();
      out.b[i] = p.b.clamp(0, 255).round();
      out.a[i] = p.a.clamp(0, 255).round();
    }
  }
  return out;
}

/// Re-encodes a planar [RgbImage] as PNG bytes (used by samples and export).
Uint8List encodePngBytes(RgbImage image, {int? backgroundArgb}) {
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
        image.hasAlpha ? image.a[i] : 255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}
