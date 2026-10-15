/// Phase 2: image input pipeline — decode, orient, downscale, transform.
///
/// All heavy work runs in a background isolate via [Isolate.run]; the UI
/// thread only ever sees finished results or failures.
library;

import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A decoded, orientation-corrected image kept as raw RGBA bytes so it can
/// cross isolate boundaries cheaply.
class SourceImage {
  /// Creates a source image.
  const SourceImage({
    required this.width,
    required this.height,
    required this.rgba,
    required this.originalWidth,
    required this.originalHeight,
  });

  /// Decoded (possibly downscaled) width.
  final int width;

  /// Decoded (possibly downscaled) height.
  final int height;

  /// Row-major RGBA bytes, length == width * height * 4.
  final Uint8List rgba;

  /// Width of the original file before downscaling.
  final int originalWidth;

  /// Height of the original file before downscaling.
  final int originalHeight;

  /// True when the working copy is smaller than the file on disk.
  bool get isDownscaled => width != originalWidth || height != originalHeight;

  /// Aspect ratio after all geometry transforms.
  double get aspect => height == 0 ? 1 : width / height;

  /// Copy with replacements.
  SourceImage copy({int? width, int? height, Uint8List? rgba}) => SourceImage(
    width: width ?? this.width,
    height: height ?? this.height,
    rgba: rgba ?? this.rgba,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
  );
}

/// Transformations applied in the crop/rotate editor.
enum ImageTransform {
  /// No change.
  none,

  /// Rotate 90° clockwise.
  rotate90,

  /// Rotate 180°.
  rotate180,

  /// Rotate 90° counter-clockwise.
  rotate270,

  /// Mirror horizontally.
  flipHorizontal,

  /// Mirror vertically.
  flipVertical,
}

/// User-facing failure reason for an import.
enum ImageFailure {
  /// Bytes could not be decoded by any supported codec.
  unsupportedFormat,

  /// Decoding threw (corrupted data, truncated file).
  corrupted,

  /// Image exceeded the safety limit for pixel count.
  tooLarge,

  /// The decode ran out of memory.
  outOfMemory,
}

/// Thrown by the pipeline with a user-presentable cause.
class ImagePipelineException implements Exception {
  /// Creates the exception.
  const ImagePipelineException(this.failure, this.message);

  /// Machine-readable reason.
  final ImageFailure failure;

  /// Human-readable message (localised by callers where possible).
  final String message;

  @override
  String toString() => 'ImagePipelineException($failure): $message';
}

/// Hard ceiling on decoded pixels (~48 MP) to survive malicious/huge files.
const int kMaxSourcePixels = 48000000;

/// Default working-size cap on the long edge.
const int kDefaultWorkingLongEdge = 2048;

/// Decodes [bytes] (PNG/JPG/WEBP/BMP/GIF), bakes EXIF orientation, and
/// downscales to at most [workingLongEdge] on the long edge with area
/// averaging. Runs in a background isolate.
Future<SourceImage> decodeAndPrepare(
  Uint8List bytes, {
  int workingLongEdge = kDefaultWorkingLongEdge,
}) async {
  try {
    return await Isolate.run(() => _decodeSync(bytes, workingLongEdge));
  } on ImagePipelineException {
    rethrow;
  } on Object {
    throw const ImagePipelineException(
      ImageFailure.outOfMemory,
      'The image is too large to process on this device.',
    );
  }
}

/// True for JPEG files missing their EOI (FFD9) terminator — i.e. truncated
/// or corrupted streams the decoder would otherwise happily render in part.
bool _isTruncatedJpeg(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return false;
  for (int i = bytes.length - 2; i >= 0; i--) {
    if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) return false;
  }
  return true;
}

SourceImage _decodeSync(Uint8List bytes, int workingLongEdge) {
  if (_isTruncatedJpeg(bytes)) {
    throw const ImagePipelineException(
      ImageFailure.corrupted,
      'That file looks incomplete or damaged.',
    );
  }
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    throw const ImagePipelineException(
      ImageFailure.corrupted,
      'This file could not be read as an image.',
    );
  }
  if (decoded == null) {
    throw const ImagePipelineException(
      ImageFailure.unsupportedFormat,
      'Unsupported file type. Use JPG, PNG or WEBP.',
    );
  }
  if (decoded.width * decoded.height > kMaxSourcePixels) {
    throw const ImagePipelineException(
      ImageFailure.tooLarge,
      'That image is too large to open (over 48 megapixels).',
    );
  }
  final img.Image upright = img.bakeOrientation(decoded);
  final int longEdge = upright.width > upright.height
      ? upright.width
      : upright.height;
  img.Image work = upright;
  if (longEdge > workingLongEdge) {
    final double scale = workingLongEdge / longEdge;
    work = img.copyResize(
      upright,
      width: (upright.width * scale).round().clamp(1, 1 << 20),
      height: (upright.height * scale).round().clamp(1, 1 << 20),
      interpolation: img.Interpolation.average,
    );
  }
  final img.Image rgba = work.convert(numChannels: 4);
  return SourceImage(
    width: rgba.width,
    height: rgba.height,
    rgba: rgba.getBytes(order: img.ChannelOrder.rgba),
    originalWidth: upright.width,
    originalHeight: upright.height,
  );
}

/// Applies editor transforms (rotate/flip) to a [SourceImage] off the UI
/// thread.
Future<SourceImage> applyTransform(
  SourceImage source,
  ImageTransform transform,
) async {
  if (transform == ImageTransform.none) return source;
  return Isolate.run(() {
    img.Image image = img.Image.fromBytes(
      width: source.width,
      height: source.height,
      bytes: source.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    switch (transform) {
      case ImageTransform.none:
        break;
      case ImageTransform.rotate90:
        image = img.copyRotate(image, angle: 90);
      case ImageTransform.rotate180:
        image = img.copyRotate(image, angle: 180);
      case ImageTransform.rotate270:
        image = img.copyRotate(image, angle: -90);
      case ImageTransform.flipHorizontal:
        image = img.flipHorizontal(img.Image.from(image));
      case ImageTransform.flipVertical:
        image = img.flipVertical(img.Image.from(image));
    }
    return SourceImage(
      width: image.width,
      height: image.height,
      rgba: image.getBytes(order: img.ChannelOrder.rgba),
      originalWidth: source.originalWidth,
      originalHeight: source.originalHeight,
    );
  });
}

/// Crops [source] to the given rectangle in *current pixel* coordinates,
/// clamped to the image bounds.
Future<SourceImage> cropImage(SourceImage source, RectInt rect) async {
  final RectInt clamped = rect.clampedTo(source.width, source.height);
  if (clamped.width == source.width && clamped.height == source.height) {
    return source;
  }
  return Isolate.run(() {
    final img.Image image = img.Image.fromBytes(
      width: source.width,
      height: source.height,
      bytes: source.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final img.Image cropped = img.copyCrop(
      image,
      x: clamped.left,
      y: clamped.top,
      width: clamped.width,
      height: clamped.height,
    );
    return SourceImage(
      width: cropped.width,
      height: cropped.height,
      rgba: cropped.getBytes(order: img.ChannelOrder.rgba),
      originalWidth: source.originalWidth,
      originalHeight: source.originalHeight,
    );
  });
}

/// Integer rectangle used by the crop editor.
@immutable
class RectInt {
  /// Creates a rectangle.
  const RectInt(this.left, this.top, this.width, this.height);

  /// Left edge.
  final int left;

  /// Top edge.
  final int top;

  /// Width.
  final int width;

  /// Height.
  final int height;

  /// Clamp into an image of the given size, keeping at least 1px.
  RectInt clampedTo(int imageWidth, int imageHeight) {
    final int l = left.clamp(0, imageWidth - 1);
    final int t = top.clamp(0, imageHeight - 1);
    final int w = width.clamp(1, imageWidth - l);
    final int h = height.clamp(1, imageHeight - t);
    return RectInt(l, t, w, h);
  }

  @override
  bool operator ==(Object other) =>
      other is RectInt &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}
