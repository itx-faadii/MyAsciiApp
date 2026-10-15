/// Sketch rendering job that crosses isolate boundaries.
library;

import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../core/image/image_pipeline.dart';

/// A request to render a sketch, carrying only serialisable fields.
class SketchRequest {
  /// Creates a request.
  const SketchRequest({required this.source, required this.settings});

  /// Source image (RGBA bytes, crosses isolate boundaries).
  final SourceImage source;

  /// Sketch settings (plain fields, crosses isolate boundaries).
  final SketchSettings settings;
}

/// The result of a sketch render, carrying only serialisable fields.
class SketchRender {
  /// Creates a render result.
  const SketchRender({
    required this.pngBytes,
    required this.width,
    required this.height,
    required this.strokeCount,
  });

  /// Encoded PNG bytes.
  final Uint8List pngBytes;

  /// Output width.
  final int width;

  /// Output height.
  final int height;

  /// Number of recorded strokes.
  final int strokeCount;
}

/// Thrown when the sketch engine fails.
class SketchRenderException implements Exception {
  /// Creates the exception.
  const SketchRenderException(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'SketchRenderException: $message';
}

/// Renders a sketch in a background isolate.
Future<SketchRender> renderSketch(SketchRequest request) async {
  try {
    return await Isolate.run(() {
      final SourceImage src = request.source;
      final SketchSettings settings = request.settings;

      // Convert SourceImage (RGBA bytes) to RgbImage (planar).
      final RgbImage rgb = RgbImage(src.width, src.height, hasAlpha: true);
      final img.Image image = img.Image.fromBytes(
        width: src.width,
        height: src.height,
        bytes: src.rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      for (int y = 0; y < src.height; y++) {
        for (int x = 0; x < src.width; x++) {
          final img.Pixel p = image.getPixel(x, y);
          final int i = y * src.width + x;
          rgb.r[i] = p.r.clamp(0, 255).round();
          rgb.g[i] = p.g.clamp(0, 255).round();
          rgb.b[i] = p.b.clamp(0, 255).round();
          rgb.a[i] = p.a.clamp(0, 255).round();
        }
      }

      final SketchResult result = SketchEngine.render(rgb, settings);
      return SketchRender(
        pngBytes: result.pngBytes,
        width: result.width,
        height: result.height,
        strokeCount: result.strokes.length,
      );
    });
  } on SketchRenderException {
    rethrow;
  } on Object catch (e) {
    throw SketchRenderException('Rendering failed: $e');
  }
}
