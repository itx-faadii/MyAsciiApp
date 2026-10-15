/// High-level rendering service with preview clamping and full-res support.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import 'ascii_job.dart' as job;

/// Maximum columns used for low-resolution previews.
const int kPreviewMaxColumns = 140;

/// Working long edge used for low-resolution previews.
const int kPreviewLongEdge = 1024;

/// Service that wraps [job.renderPreview] with preview clamping and full-res
/// rendering.
class AsciiRendererService {
  /// Creates a renderer service.
  const AsciiRendererService();

  /// Renders a preview. When [lowRes] is true, columns are clamped to 140 and
  /// the working long edge is set to 1024.
  Future<job.PreviewResult> renderPreview(
    Uint8List rgba,
    int width,
    int height,
    AsciiSettings settings, {
    bool lowRes = true,
  }) {
    final AsciiSettings effective = lowRes
        ? settings.copyWith(
            columns: settings.columns > kPreviewMaxColumns
                ? kPreviewMaxColumns
                : settings.columns,
            workingLongEdge: kPreviewLongEdge,
          )
        : settings;
    return job.renderPreview(
      job.PreviewRequest(
        rgba: rgba,
        width: width,
        height: height,
        settings: effective,
      ),
    );
  }

  /// Renders a full-resolution document.
  Future<AsciiDocument> renderFull(
    Uint8List rgba,
    int width,
    int height,
    AsciiSettings settings,
  ) async {
    final Map<String, FontMetrics> metrics = await job
        .loadMetricsFromAssetJson();
    final Map<String, Map<String, Object?>> metricsJson =
        <String, Map<String, Object?>>{};
    for (final MapEntry<String, FontMetrics> e in metrics.entries) {
      metricsJson[e.key] = e.value.toJson();
    }
    final _FullRenderData data = _renderFullSync(
      rgba,
      width,
      height,
      settings,
      metricsJson,
    );
    // Reconstruct the document from serialisable data.
    final Map<String, FontMetrics> rebuilt = <String, FontMetrics>{};
    for (final MapEntry<String, Map<String, Object?>> e
        in metricsJson.entries) {
      rebuilt[e.key] = FontMetrics.fromJson(e.value);
    }
    final FontMetrics usedMetrics =
        rebuilt[settings.font] ??
        FontMetrics(
          family: settings.font,
          unitsPerEm: 1000,
          advance: 600,
          ascender: 750,
          descender: -250,
          densities: const <String, double>{},
        );
    return AsciiDocument(
      columns: data.columns,
      rows: data.rows,
      cells: data.cells,
      tones: data.tones,
      edgeDirections: data.edgeDirections,
      metrics: usedMetrics,
      settings: settings,
      sourceWidth: width,
      sourceHeight: height,
    );
  }
}

/// Serialisable wrapper for full-render results.
class _FullRenderData {
  const _FullRenderData({
    required this.columns,
    required this.rows,
    required this.cells,
    required this.tones,
    required this.edgeDirections,
  });

  final int columns;
  final int rows;
  final List<String> cells;
  final List<double> tones;
  final List<int> edgeDirections;
}

_FullRenderData _renderFullSync(
  Uint8List rgba,
  int width,
  int height,
  AsciiSettings settings,
  Map<String, Map<String, Object?>> metricsJson,
) {
  final Map<String, FontMetrics> metrics = <String, FontMetrics>{};
  for (final MapEntry<String, Map<String, Object?>> e in metricsJson.entries) {
    metrics[e.key] = FontMetrics.fromJson(e.value);
  }
  final AsciiEngine engine = AsciiEngine(metrics);
  final img.Image source = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
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
  final AsciiDocument doc = engine.render(rgb, settings);
  return _FullRenderData(
    columns: doc.columns,
    rows: doc.rows,
    cells: doc.cells,
    tones: doc.tones,
    edgeDirections: doc.edgeDirections,
  );
}
