/// Horizontal carousel of sketch style cards.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../../core/theme/tokens.dart';

/// A horizontal scrollable carousel of [SketchStyle] cards.
class StyleCarousel extends StatelessWidget {
  /// Creates the carousel.
  const StyleCarousel({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Currently selected style.
  final SketchStyle selected;

  /// Called when a style is tapped.
  final ValueChanged<SketchStyle> onChanged;

  static const double _cardWidth = 104;
  static const double _cardHeight = 120;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AccentTokens accent = theme.extension<AccentTokens>()!;
    final SurfaceTokens surface = theme.extension<SurfaceTokens>()!;

    return SizedBox(
      height: _cardHeight + Spacing.sm * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: SketchStyle.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final SketchStyle style = SketchStyle.values[index];
          final bool isSelected = style == selected;
          return _StyleCard(
            style: style,
            selected: isSelected,
            onTap: () => onChanged(style),
            gradient: accent.heroGradient,
            outline: surface.outline,
            glow: surface.glow,
          );
        },
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
    required this.gradient,
    required this.outline,
    required this.glow,
  });

  final SketchStyle style;
  final bool selected;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Color outline;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget card = GestureDetector(
      onTap: onTap,
      child: Container(
        width: StyleCarousel._cardWidth,
        height: StyleCarousel._cardHeight,
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: Radii.control,
        ),
        child: Column(
          children: <Widget>[
            SizedBox(
              width: 56,
              height: 40,
              child: CustomPaint(painter: _HatchPreviewPainter(style)),
            ),
            const SizedBox(height: Spacing.xs),
            Icon(_iconFor(style), size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: Spacing.xs),
            Text(
              style.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );

    if (selected) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: Radii.control,
          gradient: gradient,
          boxShadow: <BoxShadow>[
            BoxShadow(color: glow.withValues(alpha: 0.5), blurRadius: 12),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: card,
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.control,
        border: Border.all(color: outline),
      ),
      child: card,
    );
  }

  IconData _iconFor(SketchStyle style) {
    // Using lucide icons — no emoji.
    return switch (style) {
      SketchStyle.graphiteHb ||
      SketchStyle.graphite2b ||
      SketchStyle.graphite6b => LucideIcons.pencil,
      SketchStyle.mechanicalPencil => LucideIcons.penTool,
      SketchStyle.charcoal => LucideIcons.brush,
      SketchStyle.ballpoint => LucideIcons.pen,
      SketchStyle.fineliner => LucideIcons.feather,
      SketchStyle.coloredPencil => LucideIcons.palette,
      SketchStyle.contourLineArt => LucideIcons.waves,
      SketchStyle.stipple => LucideIcons.circleDot,
    };
  }
}

class _HatchPreviewPainter extends CustomPainter {
  _HatchPreviewPainter(this.style);

  final SketchStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (style) {
      case SketchStyle.graphiteHb:
        paint.color = const Color(0xFF888888);
        paint.strokeWidth = 0.6;
        for (double y = 4; y < size.height; y += 6) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case SketchStyle.graphite2b:
        paint.color = const Color(0xFF555555);
        paint.strokeWidth = 1.0;
        for (double y = 3; y < size.height; y += 5) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case SketchStyle.graphite6b:
        paint.color = const Color(0xFF333333);
        paint.strokeWidth = 1.6;
        for (double y = 2; y < size.height; y += 4) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case SketchStyle.mechanicalPencil:
        paint.color = const Color(0xFF444444);
        paint.strokeWidth = 0.4;
        for (double y = 2; y < size.height; y += 3) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case SketchStyle.charcoal:
        paint.color = const Color(0xFF222222);
        paint.strokeWidth = 2.5;
        for (double y = 0; y < size.height; y += 6) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y + 2), paint);
        }
      case SketchStyle.ballpoint:
        paint.color = const Color(0xFF1F3A93);
        paint.strokeWidth = 0.8;
        for (double y = 3; y < size.height; y += 5) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        for (double x = 4; x < size.width; x += 8) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
      case SketchStyle.fineliner:
        paint.color = const Color(0xFF111111);
        paint.strokeWidth = 0.5;
        for (double y = 2; y < size.height; y += 4) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case SketchStyle.coloredPencil:
        paint.color = const Color(0xFFCC6644);
        paint.strokeWidth = 1.2;
        for (double y = 3; y < size.height; y += 5) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        paint.color = const Color(0xFF44AA66);
        for (double y = 5; y < size.height; y += 7) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case SketchStyle.contourLineArt:
        paint.color = const Color(0xFF222222);
        paint.strokeWidth = 0.8;
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          math.min(size.width, size.height) / 3,
          paint,
        );
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          math.min(size.width, size.height) / 6,
          paint,
        );
      case SketchStyle.stipple:
        paint.color = const Color(0xFF111111);
        paint.style = PaintingStyle.fill;
        final math.Random rng = math.Random(42);
        for (int i = 0; i < 30; i++) {
          final double dx = rng.nextDouble() * size.width;
          final double dy = rng.nextDouble() * size.height;
          canvas.drawCircle(Offset(dx, dy), 0.8, paint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPreviewPainter old) => old.style != style;
}
