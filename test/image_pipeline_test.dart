/// Phase 2: image input pipeline tests — orientation, downscale, failures.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sketchglyph/core/image/image_pipeline.dart';

/// 80x40 RGBA image with a distinctive pattern: left half red, right half blue.
img.Image _patternImage({int width = 80, int height = 40}) {
  final img.Image image = img.Image(
    width: width,
    height: height,
    numChannels: 4,
  );
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final bool left = x < width ~/ 2;
      image.setPixelRgba(
        x,
        y,
        left ? 255 : 10,
        left ? 0 : 10,
        left ? 0 : 255,
        255,
      );
    }
  }
  return image;
}

Uint8List _jpgWithOrientation(int orientation) {
  final img.Image image = _patternImage();
  final img.ExifData exif = img.ExifData();
  exif['ifd0'].orientation = orientation;
  image.exif = exif;
  return img.encodeJpg(image, quality: 90);
}

void main() {
  group('decodeAndPrepare', () {
    test('PNG decodes with identity orientation', () async {
      final Uint8List bytes = img.encodePng(_patternImage());
      final SourceImage source = await decodeAndPrepare(bytes);
      expect(source.width, 80);
      expect(source.height, 40);
      expect(source.rgba.length, 80 * 40 * 4);
    });

    test('EXIF orientation 6 (rotate 90 CW) bakes into pixels', () async {
      final Uint8List bytes = _jpgWithOrientation(6);
      final SourceImage source = await decodeAndPrepare(bytes);
      // 80x40 becomes 40x80 after a 90° clockwise rotation.
      expect(source.width, 40);
      expect(source.height, 80);
      // The red half (left in storage) rotates to the top half.
      int redAtTop = 0;
      for (int x = 0; x < source.width; x++) {
        final int i = x * 4;
        if (source.rgba[i] > 200) redAtTop++;
      }
      expect(redAtTop, source.width);
    });

    test('EXIF orientation 3 (rotate 180) flips both halves', () async {
      final Uint8List bytes = _jpgWithOrientation(3);
      final SourceImage source = await decodeAndPrepare(bytes);
      expect(source.width, 80);
      expect(source.height, 40);
      // Red half now on the right.
      final int i = 79 * 4;
      expect(source.rgba[i], greaterThan(200));
    });

    test('orientation 2 (horizontal flip) swaps halves', () async {
      final Uint8List bytes = _jpgWithOrientation(2);
      final SourceImage source = await decodeAndPrepare(bytes);
      expect(source.width, 80);
      final int leftPixel = 0;
      expect(source.rgba[leftPixel * 4], lessThan(100));
    });

    test('JPG round-trips through the pipeline', () async {
      final Uint8List bytes = img.encodeJpg(_patternImage(), quality: 90);
      final SourceImage source = await decodeAndPrepare(bytes);
      expect(source.width, greaterThan(70));
      expect(source.rgba.length, source.width * source.height * 4);
    });

    test('WEBP round-trips through the pipeline', () async {
      final Uint8List bytes = img.encodeWebP(_patternImage());
      final SourceImage source = await decodeAndPrepare(bytes);
      expect(source.width, 80);
    });

    test('downscales a large image to the working long edge', () async {
      final img.Image big = _patternImage(width: 4000, height: 2000);
      final Uint8List bytes = img.encodePng(big);
      final SourceImage source = await decodeAndPrepare(
        bytes,
        workingLongEdge: 1000,
      );
      expect(source.width, 1000);
      expect(source.height, 500);
      expect(source.isDownscaled, isTrue);
      expect(source.originalWidth, 4000);
    });

    test('keeps aspect ratio when downscaling portrait images', () async {
      final img.Image tall = _patternImage(width: 900, height: 3000);
      final Uint8List bytes = img.encodePng(tall);
      final SourceImage source = await decodeAndPrepare(
        bytes,
        workingLongEdge: 1500,
      );
      expect(source.height, 1500);
      expect(source.width, 450);
    });

    test('unsupported bytes fail with unsupportedFormat', () async {
      final Uint8List junk = Uint8List.fromList(
        'not an image at all'.codeUnits,
      );
      expect(
        () => decodeAndPrepare(junk),
        throwsA(
          isA<ImagePipelineException>().having(
            (ImagePipelineException e) => e.failure,
            'failure',
            ImageFailure.unsupportedFormat,
          ),
        ),
      );
    });

    test('truncated JPEG fails cleanly, not with a raw crash', () async {
      final Uint8List bytes = img.encodeJpg(
        _patternImage(width: 200, height: 200),
      );
      final Uint8List truncated = bytes.sublist(0, bytes.length ~/ 3);
      expect(
        () => decodeAndPrepare(truncated),
        throwsA(isA<ImagePipelineException>()),
      );
    });
  });

  group('transforms', () {
    test(
      'rotate90 swaps dimensions and moves the red half to the top',
      () async {
        final SourceImage source = await decodeAndPrepare(
          img.encodePng(_patternImage()),
        );
        final SourceImage rotated = await applyTransform(
          source,
          ImageTransform.rotate90,
        );
        expect(rotated.width, 40);
        expect(rotated.height, 80);
        for (int x = 0; x < rotated.width; x++) {
          expect(
            rotated.rgba[x * 4],
            greaterThan(200),
            reason: 'row 0 should be red',
          );
        }
      },
    );

    test('flipHorizontal mirrors the halves', () async {
      final SourceImage source = await decodeAndPrepare(
        img.encodePng(_patternImage()),
      );
      final SourceImage flipped = await applyTransform(
        source,
        ImageTransform.flipHorizontal,
      );
      expect(flipped.width, source.width);
      expect(flipped.rgba[(flipped.width - 1) * 4], greaterThan(200));
    });

    test('none is a no-op', () async {
      final SourceImage source = await decodeAndPrepare(
        img.encodePng(_patternImage()),
      );
      final SourceImage same = await applyTransform(
        source,
        ImageTransform.none,
      );
      expect(identical(same, source), isTrue);
    });

    test('crop clamps to bounds and extracts the requested rect', () async {
      final SourceImage source = await decodeAndPrepare(
        img.encodePng(_patternImage()),
      );
      final SourceImage cropped = await cropImage(
        source,
        RectInt(source.width - 10, 0, 500, 500),
      );
      expect(cropped.width, 10);
      expect(cropped.height, source.height);
      // Entirely blue region.
      expect(cropped.rgba[0], lessThan(100));
    });
  });

  group('RectInt', () {
    test('clampedTo keeps rectangles inside the image', () {
      const RectInt rect = RectInt(-20, 10, 500, 5);
      final RectInt clamped = rect.clampedTo(80, 40);
      expect(clamped.left, 0);
      expect(clamped.top, 10);
      expect(clamped.width, 80);
      expect(clamped.height, 5);
    });
  });
}
