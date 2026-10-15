/// ASCII preview renderer: draws per-cell glyphs via [CustomPaint] with
/// per-row same-colour runs batched into a single [TextPainter] each.
/// Wrapped in [InteractiveViewer] for pinch-zoom and pan.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/image/image_pipeline.dart';
import '../../../core/theme/tokens.dart';
import '../domain/ascii_job.dart';

/// Maps engine font IDs to Flutter font family names.
String _mapEngineFontToFlutter(String engineFont) {
  switch (engineFont) {
    case 'JetBrainsMono-Regular':
      return 'JetBrains Mono';
    case 'IBM Plex Mono':
      return 'IBM Plex Mono';
    case 'Courier Prime':
      return 'Courier Prime';
    default:
      return engineFont;
  }
}

/// Renders a [PreviewResult] as a zoomable/pannable ASCII grid.
class AsciiPreview extends StatelessWidget {
  /// Creates an ASCII preview.
  const AsciiPreview({
    super.key,
    required this.preview,
    this.interactive = true,
    this.fontSizePx = 10,
    this.lineHeight = 1.15,
    this.letterSpacing = 0.0,
    this.fontFamily = 'JetBrainsMono-Regular',
  });

  /// The rendered preview to display.
  final PreviewResult preview;

  /// Whether pinch-zoom and pan are enabled.
  final bool interactive;

  /// Font size in logical pixels for the preview.
  final double fontSizePx;

  /// Line height multiplier.
  final double lineHeight;

  /// Extra letter spacing in em.
  final double letterSpacing;

  /// Engine font ID (will be mapped to Flutter family name internally).
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;
    final String flutterFont = _mapEngineFontToFlutter(fontFamily);

    // Measure a reference monospace cell.
    final TextPainter ref = TextPainter(
      text: TextSpan(
        text: 'M',
        style: TextStyle(
          fontFamily: flutterFont,
          fontSize: fontSizePx,
          letterSpacing: letterSpacing * fontSizePx,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double cellWidth = ref.width;
    final double cellHeight = fontSizePx * lineHeight;
    ref.dispose();

    final Size size = Size(
      cellWidth * preview.columns,
      cellHeight * preview.rows,
    );

    Widget canvas = ClipRRect(
      borderRadius: Radii.control,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          size: size,
          painter: _AsciiPainter(
            preview: preview,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            fontFamily: flutterFont,
            fontSizePx: fontSizePx,
            letterSpacingPx: letterSpacing * fontSizePx,
          ),
        ),
      ),
    );

    if (interactive) {
      canvas = InteractiveViewer(
        minScale: 0.4,
        maxScale: 8,
        boundaryMargin: const EdgeInsets.all(48),
        child: canvas,
      );
    }

    return ColoredBox(color: tokens.paperDesk, child: canvas);
  }
}

class _AsciiPainter extends CustomPainter {
  _AsciiPainter({
    required this.preview,
    required this.cellWidth,
    required this.cellHeight,
    required this.fontFamily,
    required this.fontSizePx,
    required this.letterSpacingPx,
  });

  final PreviewResult preview;
  final double cellWidth;
  final double cellHeight;
  final String fontFamily;
  final double fontSizePx;
  final double letterSpacingPx;

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(preview.background),
    );

    // Per-row, group contiguous same-colour runs into one TextPainter.
    for (int y = 0; y < preview.rows; y++) {
      final double rowY = y * cellHeight;
      int x = 0;
      while (x < preview.columns) {
        final int colorArgb = preview.colors[y * preview.columns + x];
        int runEnd = x + 1;
        while (runEnd < preview.columns &&
            preview.colors[y * preview.columns + runEnd] == colorArgb) {
          runEnd++;
        }
        final String runText = preview.cells
            .sublist(y * preview.columns + x, y * preview.columns + runEnd)
            .join();
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: runText,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSizePx,
              color: Color(colorArgb),
              letterSpacing: letterSpacingPx,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        tp.paint(canvas, Offset(x * cellWidth, rowY));
        tp.dispose();
        x = runEnd;
      }
    }
  }

  @override
  bool shouldRepaint(_AsciiPainter old) =>
      old.preview != preview ||
      old.cellWidth != cellWidth ||
      old.cellHeight != cellHeight ||
      old.fontSizePx != fontSizePx;
}

/// Renders a [SourceImage] as raw RGBA pixels via a [CustomPaint].
class SourceImageView extends StatelessWidget {
  /// Creates a source image view.
  const SourceImageView({super.key, required this.source});

  /// The source image to display.
  final SourceImage source;

  @override
  Widget build(BuildContext context) {
    return _PixelCanvas(
      width: source.width,
      height: source.height,
      rgba: source.rgba,
    );
  }
}

class _PixelCanvas extends StatelessWidget {
  const _PixelCanvas({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width.toDouble(), height.toDouble()),
      painter: _PixelPainter(width: width, height: height, rgba: rgba),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int i = (y * width + x) * 4;
        paint.color = Color.fromARGB(
          rgba[i + 3],
          rgba[i],
          rgba[i + 1],
          rgba[i + 2],
        );
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.width != width || old.height != height || old.rgba != rgba;
}

/// A shimmer skeleton shown while the first render is in progress.
class ShimmerSkeleton extends StatefulWidget {
  /// Creates a shimmer skeleton.
  const ShimmerSkeleton({super.key, this.height = 300});

  /// Height of the skeleton area.
  final double height;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;
    return ClipRRect(
      borderRadius: Radii.control,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          final double opacity =
              0.3 + 0.4 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
          return DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surfaceHigh.withValues(alpha: opacity),
              borderRadius: Radii.control,
              border: Border.all(color: tokens.outline),
            ),
            child: SizedBox(height: widget.height),
          );
        },
      ),
    );
  }
}
