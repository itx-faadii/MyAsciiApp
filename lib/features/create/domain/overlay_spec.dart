/// Overlay (caption / watermark) specification — Phase 6.
///
/// The spec is serialisable to/from JSON so it can live on the create session
/// and later be persisted with projects. Rendering into the exported image
/// happens in Phase 7; this file only defines the data model.
library;

import 'dart:convert';

/// Where an overlay is anchored on the canvas.
enum OverlayPosition {
  /// Top-left corner.
  topLeft,

  /// Top-centre.
  topCenter,

  /// Top-right corner.
  topRight,

  /// Centre of the canvas.
  center,

  /// Bottom-left corner.
  bottomLeft,

  /// Bottom-centre.
  bottomCenter,

  /// Bottom-right corner.
  bottomRight,
}

/// Caption and/or watermark overlay specification.
///
/// Disabled by default per product rules.
class OverlaySpec {
  /// Creates a spec.
  const OverlaySpec({
    this.caption,
    this.watermark,
    this.position = OverlayPosition.bottomRight,
    this.opacity = 1.0,
    this.enabled = false,
  });

  /// Optional caption text rendered onto the image.
  final String? caption;

  /// Optional watermark text rendered onto the image.
  final String? watermark;

  /// Anchor position on the canvas.
  final OverlayPosition position;

  /// Opacity in 0..1.
  final double opacity;

  /// Whether the overlay is active. OFF by default.
  final bool enabled;

  /// Copy with replacements.
  OverlaySpec copyWith({
    String? caption,
    String? watermark,
    OverlayPosition? position,
    double? opacity,
    bool? enabled,
    bool clearCaption = false,
    bool clearWatermark = false,
  }) => OverlaySpec(
    caption: clearCaption ? null : (caption ?? this.caption),
    watermark: clearWatermark ? null : (watermark ?? this.watermark),
    position: position ?? this.position,
    opacity: opacity ?? this.opacity,
    enabled: enabled ?? this.enabled,
  );

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (caption != null) 'caption': caption,
    if (watermark != null) 'watermark': watermark,
    'position': position.name,
    'opacity': opacity,
    'enabled': enabled,
  };

  /// Deserialises from a JSON map. Returns a default spec on null/empty input.
  factory OverlaySpec.fromJson(Map<String, dynamic> json) {
    final String? posName = json['position'] as String?;
    final OverlayPosition pos = OverlayPosition.values.firstWhere(
      (OverlayPosition p) => p.name == posName,
      orElse: () => OverlayPosition.bottomRight,
    );
    return OverlaySpec(
      caption: json['caption'] as String?,
      watermark: json['watermark'] as String?,
      position: pos,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  /// Round-trip via a JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Parse from a JSON string. Returns a default spec on invalid input.
  factory OverlaySpec.fromJsonString(String source) {
    try {
      return OverlaySpec.fromJson(jsonDecode(source) as Map<String, dynamic>);
    } on Object {
      return const OverlaySpec();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OverlaySpec &&
      other.caption == caption &&
      other.watermark == watermark &&
      other.position == position &&
      other.opacity == opacity &&
      other.enabled == enabled;

  @override
  int get hashCode =>
      Object.hash(caption, watermark, position, opacity, enabled);
}
