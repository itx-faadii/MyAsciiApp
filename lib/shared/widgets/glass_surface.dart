/// Frosted-glass container that respects the reduce-blur setting.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// A translucent blurred panel. Falls back to a flat translucent surface when
/// [SurfaceTokens.useGlass] is off (reduce-blur setting or low-end fallback).
class GlassSurface extends StatelessWidget {
  /// Creates a glass panel.
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.borderRadius = Radii.card,
  });

  /// Content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Corner radius.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;
    final Color tint = tokens.surfaceTop.withValues(
      alpha: tokens.useGlass ? 0.72 : 0.96,
    );
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: borderRadius,
        border: Border.all(color: tokens.outline),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (tokens.useGlass) {
      panel = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tokens.glassSigma,
            sigmaY: tokens.glassSigma,
          ),
          child: panel,
        ),
      );
    }
    return panel;
  }
}
