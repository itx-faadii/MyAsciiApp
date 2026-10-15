/// Phase 6: canvas crop-rect math tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sketchglyph/core/image/image_pipeline.dart';
import 'package:sketchglyph/features/create/domain/canvas_format.dart';

AspectRatioPreset _custom() =>
    const AspectRatioPreset(id: 'custom', label: 'Custom');

void main() {
  group('kCropPresets', () {
    test('contains the documented ids in order', () {
      expect(kCropPresets.map((AspectRatioPreset p) => p.id).toList(), <String>[
        'free',
        '1:1',
        '4:5',
        '9:16',
        '16:9',
        'a4',
      ]);
    });

    test('ids and labels are unique', () {
      expect(
        kCropPresets.map((AspectRatioPreset p) => p.id).toSet().length,
        kCropPresets.length,
      );
      expect(
        kCropPresets.map((AspectRatioPreset p) => p.label).toSet().length,
        kCropPresets.length,
      );
    });

    test('only free has a null ratio', () {
      for (final AspectRatioPreset p in kCropPresets) {
        if (p.id == 'free') {
          expect(p.ratio, isNull);
        } else {
          expect(p.ratio, isNotNull);
          expect(p.ratio, greaterThan(0));
        }
      }
    });
  });

  group('cropRectFor degenerate inputs', () {
    test('zero or negative dimensions collapse to a 1x1 rect', () {
      for (final (int w, int h) in <(int, int)>[
        (0, 10),
        (10, 0),
        (-5, 7),
        (3, -1),
      ]) {
        expect(
          cropRectFor(kCropPresets[1], imageWidth: w, imageHeight: h),
          const RectInt(0, 0, 1, 1),
        );
      }
    });

    test('free preset always returns the full frame', () {
      final RectInt r = cropRectFor(
        kCropPresets.first,
        imageWidth: 123,
        imageHeight: 456,
      );
      expect(r, const RectInt(0, 0, 123, 456));
    });

    test('free ignores a supplied custom ratio', () {
      final RectInt r = cropRectFor(
        kCropPresets.first,
        imageWidth: 100,
        imageHeight: 50,
        customRatio: 2.5,
      );
      expect(r, const RectInt(0, 0, 100, 50));
    });

    test(
      'custom preset with null, zero, or negative ratio behaves as free',
      () {
        for (final double? ratio in <double?>[null, 0, -1.5]) {
          final RectInt r = cropRectFor(
            _custom(),
            imageWidth: 80,
            imageHeight: 60,
            customRatio: ratio,
          );
          expect(r, const RectInt(0, 0, 80, 60));
        }
      },
    );

    test('named presets ignore customRatio', () {
      final RectInt r = cropRectFor(
        kCropPresets[1], // 1:1
        imageWidth: 100,
        imageHeight: 50,
        customRatio: 3.0,
      );
      expect(r, const RectInt(25, 0, 50, 50));
    });
  });

  group('cropRectFor centred largest-fit math', () {
    test('1:1 on landscape centres horizontally', () {
      final RectInt r = cropRectFor(
        kCropPresets[1],
        imageWidth: 100,
        imageHeight: 50,
      );
      expect(r, const RectInt(25, 0, 50, 50));
    });

    test('1:1 on portrait centres vertically', () {
      final RectInt r = cropRectFor(
        kCropPresets[1],
        imageWidth: 50,
        imageHeight: 100,
      );
      expect(r, const RectInt(0, 25, 50, 50));
    });

    test('4:5 on square crops width', () {
      final RectInt r = cropRectFor(
        kCropPresets[2],
        imageWidth: 100,
        imageHeight: 100,
      );
      expect(r, const RectInt(10, 0, 80, 100));
    });

    test('16:9 on a portrait 1080x1920 frame height-centres at 608', () {
      final RectInt r = cropRectFor(
        kCropPresets[4],
        imageWidth: 1080,
        imageHeight: 1920,
      );
      expect(r, const RectInt(0, 656, 1080, 608));
    });

    test('9:16 on its native portrait frame is a perfect fit', () {
      final RectInt r = cropRectFor(
        kCropPresets[3],
        imageWidth: 1080,
        imageHeight: 1920,
      );
      expect(r, const RectInt(0, 0, 1080, 1920));
    });

    test('a4 on landscape 3000x2000 crops the width', () {
      final RectInt r = cropRectFor(
        kCropPresets[5],
        imageWidth: 3000,
        imageHeight: 2000,
      );
      // 2000 * 210/297 = 1414.14 -> 1414, left = (3000 - 1414) ~/ 2 = 793.
      expect(r, const RectInt(793, 0, 1414, 2000));
    });

    test('custom ratio 2.0 on 100x100 crops height', () {
      final RectInt r = cropRectFor(
        _custom(),
        imageWidth: 100,
        imageHeight: 100,
        customRatio: 2.0,
      );
      expect(r, const RectInt(0, 25, 100, 50));
    });

    test('extreme aspect on a 1px axis never drops below 1x1', () {
      final RectInt tall = cropRectFor(
        kCropPresets[4], // 16:9
        imageWidth: 1,
        imageHeight: 1000,
      );
      expect(tall, const RectInt(0, 499, 1, 1));

      final RectInt wide = cropRectFor(
        kCropPresets[3], // 9:16
        imageWidth: 1000,
        imageHeight: 1,
      );
      expect(wide, const RectInt(499, 0, 1, 1));
    });

    test('matching ratio keeps the full frame', () {
      final RectInt r = cropRectFor(
        kCropPresets[4],
        imageWidth: 160,
        imageHeight: 90,
      );
      expect(r, const RectInt(0, 0, 160, 90));
    });
  });

  group('cropRectFor invariants', () {
    test(
      'rect is always in-bounds, >= 1x1, and matches the requested ratio',
      () {
        final List<(int, int)> sizes = <(int, int)>[
          (100, 100),
          (160, 90),
          (90, 160),
          (4000, 3000),
          (12, 4000),
          (4000, 12),
          (1, 1),
          (3, 7),
        ];
        for (final AspectRatioPreset p in kCropPresets.skip(1)) {
          for (final (int w, int h) in sizes) {
            final RectInt r = cropRectFor(p, imageWidth: w, imageHeight: h);
            expect(r.width, greaterThanOrEqualTo(1), reason: '${p.id} $w x $h');
            expect(r.height, greaterThanOrEqualTo(1));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.top, greaterThanOrEqualTo(0));
            expect(r.left + r.width, lessThanOrEqualTo(w));
            expect(r.top + r.height, lessThanOrEqualTo(h));
            if (w > 4 && h > 4) {
              // Rounding tolerance scales with the smallest crop edge.
              final double tolerance = 1.0 / r.height + 1.0 / r.width;
              expect(
                (r.width / r.height - p.ratio!).abs(),
                lessThan(tolerance + 0.01),
                reason: '${p.id} on $w x $h gave ${r.width}x${r.height}',
              );
            }
          }
        }
      },
    );

    test('the crop is centred on both axes when it does not fill one', () {
      final RectInt r = cropRectFor(
        kCropPresets[1],
        imageWidth: 101,
        imageHeight: 50,
      );
      expect(r.width, 50);
      expect(r.height, 50);
      // (101 - 50) ~/ 2 = 25; the leftover sits on the right.
      expect(r.left, 25);
      expect(101 - (r.left + r.width), 26);
    });
  });

  group('RectInt.clampedTo', () {
    test('fully inside rects are untouched', () {
      const RectInt r = RectInt(5, 5, 10, 10);
      expect(r.clampedTo(100, 100), r);
    });

    test('overruns clamp width and height to the bounds', () {
      final RectInt r = const RectInt(90, 90, 50, 50).clampedTo(100, 100);
      expect(r, const RectInt(90, 90, 10, 10));
    });

    test('negative offsets clamp to the origin', () {
      final RectInt r = const RectInt(-10, -5, 50, 40).clampedTo(100, 100);
      expect(r.left, 0);
      expect(r.top, 0);
    });

    test('results never drop below 1x1', () {
      final RectInt r = const RectInt(200, 200, 10, 10).clampedTo(100, 100);
      expect(r.width, greaterThanOrEqualTo(1));
      expect(r.height, greaterThanOrEqualTo(1));
    });
  });
}
