/// Flutter-side adapter between the UI and the pure-Dart ASCII engine.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

/// Error surfaced when the engine rejects settings or rendering fails.
class AsciiPreviewException implements Exception {
  /// Creates the exception.
  const AsciiPreviewException(this.message, {this.field});

  /// User-facing message.
  final String message;

  /// Which control the message refers to, if known.
  final String? field;

  @override
  String toString() => 'AsciiPreviewException($field): $message';
}

/// Raw input for a preview render.
class PreviewRequest {
  /// Creates a request.
  const PreviewRequest({
    required this.rgba,
    required this.width,
    required this.height,
    required this.settings,
  });

  /// Row-major RGBA bytes, length == width * height * 4.
  final Uint8List rgba;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Settings to render with.
  final AsciiSettings settings;
}

/// Output of a preview render.
class PreviewResult {
  /// Creates a result.
  const PreviewResult({
    required this.text,
    required this.cells,
    required this.colors,
    required this.columns,
    required this.rows,
    required this.foreground,
    required this.background,
    required this.cellWidthEm,
    required this.cellRatio,
  });

  /// Plain text output, newline separated.
  final String text;

  /// Row-major characters.
  final List<String> cells;

  /// Per-cell colours, ARGB.
  final List<int> colors;

  /// Grid width in characters.
  final int columns;

  /// Grid height in lines.
  final int rows;

  /// Mono foreground, ARGB.
  final int foreground;

  /// Background, ARGB.
  final int background;

  /// Width of one cell relative to the font em size.
  final double cellWidthEm;

  /// Cell aspect ratio (width / height) used by the preview layout.
  final double cellRatio;
}

/// Lazily-loaded, cached font metrics from the bundled JSON asset.
Future<Map<String, FontMetrics>>? _metricsCache;

/// Loads font metrics from the bundled JSON asset, cached.
Future<Map<String, FontMetrics>> loadMetricsFromAssetJson() {
  return _metricsCache ??= _loadMetricsOnce();
}

Future<Map<String, FontMetrics>> _loadMetricsOnce() async {
  final String json = await rootBundle.loadString('assets/font_metrics.json');
  final Map<String, Object?> decoded = jsonDecode(json) as Map<String, Object?>;
  final List<Object?> fonts = decoded['fonts'] as List<Object?>;
  final Map<String, FontMetrics> result = <String, FontMetrics>{};
  for (final Object? entry in fonts) {
    final Map<String, Object?> fontJson = entry! as Map<String, Object?>;
    final FontMetrics metrics = FontMetrics.fromJson(fontJson);
    result[metrics.family] = metrics;
  }
  return result;
}

/// Renders a preview entirely in a background isolate.
///
/// The [metricsJson] parameter is the raw decoded JSON map so it can cross
/// the isolate boundary as serialisable data.
Future<PreviewResult> renderPreview(PreviewRequest request) async {
  // Load metrics on the main isolate (assets require it), then pass the raw
  // JSON map to the worker.
  final Map<String, FontMetrics> metrics = await loadMetricsFromAssetJson();
  // Convert to serialisable form for the isolate.
  final Map<String, Map<String, Object?>> metricsJson =
      <String, Map<String, Object?>>{};
  for (final MapEntry<String, FontMetrics> e in metrics.entries) {
    metricsJson[e.key] = e.value.toJson();
  }
  try {
    return await Isolate.run<PreviewResult>(() {
      final Map<String, FontMetrics> rebuilt = <String, FontMetrics>{};
      for (final MapEntry<String, Map<String, Object?>> e
          in metricsJson.entries) {
        rebuilt[e.key] = FontMetrics.fromJson(e.value);
      }
      return _renderSync(request, rebuilt);
    });
  } on AsciiSettingsException catch (e) {
    throw AsciiPreviewException(e.message, field: e.field);
  } on AsciiPreviewException {
    rethrow;
  } on Object catch (e) {
    throw AsciiPreviewException('Rendering failed: $e');
  }
}

PreviewResult _renderSync(
  PreviewRequest request,
  Map<String, FontMetrics> metrics,
) {
  final AsciiEngine engine = AsciiEngine(metrics);
  final img.Image source = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: request.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final RgbImage rgb = RgbImage(source.width, source.height, hasAlpha: true);
  for (int y = 0; y < source.height; y++) {
    for (int x = 0; x < source.width; x++) {
      final img.Pixel p = source.getPixel(x, y);
      final int i = y * source.width + x;
      rgb.r[i] = p.r.clamp(0, 255).round();
      rgb.g[i] = p.g.clamp(0, 255).round();
      rgb.b[i] = p.b.clamp(0, 255).round();
      rgb.a[i] = p.a.clamp(0, 255).round();
    }
  }
  final AsciiDocument doc = engine.render(rgb, request.settings);
  final FontMetrics used = doc.metrics;
  final double cellWidthEm = used.advanceRatio;
  final double cellRatio =
      used.advanceRatio / (used.lineBoxRatio * request.settings.lineHeight);
  return PreviewResult(
    text: doc.toPlainText(),
    cells: doc.cells,
    colors: doc.colors,
    columns: doc.columns,
    rows: doc.rows,
    foreground: request.settings.foreground,
    background: request.settings.background,
    cellWidthEm: cellWidthEm,
    cellRatio: cellRatio,
  );
}
