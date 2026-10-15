/// Curated sketch presets and ink colors.
library;

import 'package:sketchglyph_engine/sketchglyph_engine.dart';

/// A curated sketch preset combining style, paper, and tuning parameters.
class SketchPreset {
  /// Creates a preset.
  const SketchPreset({
    required this.id,
    required this.label,
    required this.style,
    required this.paper,
    required this.detail,
    required this.lineWeight,
    required this.hatchDensity,
    required this.shading,
    required this.edgeStrength,
    required this.grain,
    required this.smudge,
    required this.inkFlow,
    required this.inkArgb,
  });

  /// Stable ID for persistence.
  final String id;

  /// Human-readable label.
  final String label;

  /// Sketch style.
  final SketchStyle style;

  /// Paper type.
  final PaperType paper;

  /// Stroke count scale.
  final double detail;

  /// Line weight scale.
  final double lineWeight;

  /// Hatching density.
  final double hatchDensity;

  /// Overall tone strength.
  final double shading;

  /// Edge detection strength.
  final double edgeStrength;

  /// Paper tooth.
  final double grain;

  /// Charcoal smearing.
  final double smudge;

  /// Ballpoint unevenness.
  final double inkFlow;

  /// Ink colour as ARGB.
  final int inkArgb;

  /// Builds [SketchSettings] from this preset.
  SketchSettings toSettings({int seed = 1}) => SketchSettings(
    style: style,
    paper: paper,
    detail: detail,
    lineWeight: lineWeight,
    hatchDensity: hatchDensity,
    shading: shading,
    edgeStrength: edgeStrength,
    grain: grain,
    smudge: smudge,
    inkFlow: inkFlow,
    inkArgb: inkArgb,
    seed: seed,
  );

  /// Curated presets spanning media types.
  static const List<SketchPreset> all = <SketchPreset>[
    SketchPreset(
      id: 'study_hb',
      label: 'Study in HB',
      style: SketchStyle.graphiteHb,
      paper: PaperType.whiteCartridge,
      detail: 1.0,
      lineWeight: 0.8,
      hatchDensity: 0.9,
      shading: 0.9,
      edgeStrength: 1.0,
      grain: 1.0,
      smudge: 0.5,
      inkFlow: 1.0,
      inkArgb: 0xFF2B2B2B,
    ),
    SketchPreset(
      id: 'charcoal_portrait',
      label: 'Charcoal Portrait',
      style: SketchStyle.charcoal,
      paper: PaperType.cream,
      detail: 1.2,
      lineWeight: 1.4,
      hatchDensity: 1.3,
      shading: 1.3,
      edgeStrength: 0.9,
      grain: 1.2,
      smudge: 1.6,
      inkFlow: 1.0,
      inkArgb: 0xFF1A1A1A,
    ),
    SketchPreset(
      id: 'ink_fineliner',
      label: 'Ink Fineliner',
      style: SketchStyle.fineliner,
      paper: PaperType.whiteCartridge,
      detail: 1.1,
      lineWeight: 0.9,
      hatchDensity: 1.0,
      shading: 1.0,
      edgeStrength: 1.2,
      grain: 0.8,
      smudge: 0.0,
      inkFlow: 1.0,
      inkArgb: 0xFF111111,
    ),
    SketchPreset(
      id: 'ballpoint_notes',
      label: 'Ballpoint Notes',
      style: SketchStyle.ballpoint,
      paper: PaperType.lined,
      detail: 1.0,
      lineWeight: 1.0,
      hatchDensity: 1.1,
      shading: 1.0,
      edgeStrength: 1.0,
      grain: 1.0,
      smudge: 0.3,
      inkFlow: 1.3,
      inkArgb: 0xFF1F3A93,
    ),
    SketchPreset(
      id: 'dotwork',
      label: 'Dotwork',
      style: SketchStyle.stipple,
      paper: PaperType.whiteCartridge,
      detail: 1.3,
      lineWeight: 1.0,
      hatchDensity: 1.5,
      shading: 1.2,
      edgeStrength: 0.8,
      grain: 0.9,
      smudge: 0.0,
      inkFlow: 1.0,
      inkArgb: 0xFF111111,
    ),
    SketchPreset(
      id: 'colored_study',
      label: 'Colored Study',
      style: SketchStyle.coloredPencil,
      paper: PaperType.cream,
      detail: 1.1,
      lineWeight: 1.1,
      hatchDensity: 1.0,
      shading: 1.1,
      edgeStrength: 1.0,
      grain: 1.1,
      smudge: 0.4,
      inkFlow: 1.0,
      inkArgb: 0xFF000000,
    ),
  ];
}

/// Ink colour preset.
class InkColorPreset {
  /// Creates an ink preset.
  const InkColorPreset({
    required this.id,
    required this.label,
    required this.argb,
  });

  /// Stable ID.
  final String id;

  /// Human-readable label.
  final String label;

  /// Ink colour as ARGB.
  final int argb;

  /// Five ink presets.
  static const List<InkColorPreset> all = <InkColorPreset>[
    InkColorPreset(id: 'graphite', label: 'Graphite', argb: 0xFF2B2B2B),
    InkColorPreset(id: 'black_ink', label: 'Black Ink', argb: 0xFF111111),
    InkColorPreset(
      id: 'ballpoint_blue',
      label: 'Ballpoint Blue',
      argb: 0xFF1F3A93,
    ),
    InkColorPreset(id: 'sepia', label: 'Sepia', argb: 0xFF5B4230),
    InkColorPreset(id: 'crimson', label: 'Crimson', argb: 0xFF8E2A34),
  ];
}
