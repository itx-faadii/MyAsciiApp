/// Canvas format presets and crop-rect math — Phase 6.
library;

import 'dart:math' as math;

import '../../../core/image/image_pipeline.dart';

/// An aspect-ratio preset for the crop editor.
class AspectRatioPreset {
  /// Creates a preset.
  const AspectRatioPreset({required this.id, required this.label, this.ratio});

  /// Stable identifier.
  final String id;

  /// Human-readable label.
  final String label;

  /// Width / height. Null for free-form or custom ratios.
  final double? ratio;
}

/// Built-in presets shown in the crop UI.
const List<AspectRatioPreset> kCropPresets = <AspectRatioPreset>[
  AspectRatioPreset(id: 'free', label: 'Free'),
  AspectRatioPreset(id: '1:1', label: '1:1', ratio: 1.0),
  AspectRatioPreset(id: '4:5', label: '4:5', ratio: 4.0 / 5.0),
  AspectRatioPreset(id: '9:16', label: '9:16', ratio: 9.0 / 16.0),
  AspectRatioPreset(id: '16:9', label: '16:9', ratio: 16.0 / 9.0),
  AspectRatioPreset(id: 'a4', label: 'A4', ratio: 210.0 / 297.0),
];

/// A4 portrait ratio (210 x 297 mm).
const double kA4Ratio = 210.0 / 297.0;

/// Computes the largest centred crop rectangle inside [imageWidth] x
/// [imageHeight] that satisfies [preset].
///
/// - Free / null ratio: returns the full frame.
/// - Custom ratio <= 0: treated as free.
/// - The result is always at least 1 x 1 and clamped to the image bounds.
/// - For portrait ratios on landscape images (or vice-versa) the rect is
///   centred and scaled to fit.
RectInt cropRectFor(
  AspectRatioPreset preset, {
  required int imageWidth,
  required int imageHeight,
  double? customRatio,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return const RectInt(0, 0, 1, 1);
  }

  double? ratio = preset.ratio;
  if (preset.id == 'custom') {
    ratio = (customRatio != null && customRatio > 0) ? customRatio : null;
  }
  if (ratio == null || ratio <= 0 || preset.id == 'free') {
    return RectInt(0, 0, imageWidth, imageHeight);
  }

  final double imageRatio = imageWidth / imageHeight;
  int cropW;
  int cropH;
  if (imageRatio > ratio) {
    // Image is wider than target: constrain by height.
    cropH = imageHeight;
    cropW = math.max(1, (cropH * ratio).round());
  } else {
    // Image is taller than target: constrain by width.
    cropW = imageWidth;
    cropH = math.max(1, (cropW / ratio).round());
  }
  cropW = math.min(cropW, imageWidth);
  cropH = math.min(cropH, imageHeight);
  final int left = math.max(0, (imageWidth - cropW) ~/ 2);
  final int top = math.max(0, (imageHeight - cropH) ~/ 2);
  return RectInt(left, top, cropW, cropH);
}
