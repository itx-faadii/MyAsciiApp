// Sketch engine public API contract.
//
// Both engines live in `packages/sketchglyph_engine` as PURE Dart (no Flutter
// imports, no `dart:io` in library code, no network). The Flutter app codes
// against exactly these symbols.
//
// lib/src/sketch/sketch_engine.dart must expose:
//
//   enum SketchStyle {
//     graphiteHb, graphite2b, graphite6b, mechanicalPencil, charcoal,
//     ballpoint, fineliner, coloredPencil, contourLineArt, stipple,
//   }
//
//   extension SketchStyleInfo on SketchStyle {
//     String get label;      // human readable, no emoji
//     String get id;         // stable id for persistence
//   }
//   SketchStyle? sketchStyleById(String id);
//
//   enum PaperType {
//     whiteCartridge, cream, grey, kraft, lined, grid,
//   }
//   extension PaperTypeInfo on PaperType {
//     String get label;
//     String get id;
//     int    get baseArgb;   // paper colour
//   }
//   PaperType? paperTypeById(String id);
//
//   enum StrokeKind { line, dot, smudge }
//
//   class SketchStroke {
//     List<double> get points;   // flattened [x0,y0,x1,y1,...] image pixels
//     double get width;
//     double get alpha;          // 0..1
//     int    get colorArgb;
//     StrokeKind get kind;
//   }
//
//   class SketchSettings {
//     SketchSettings({
//       SketchStyle style = SketchStyle.graphite2b,
//       PaperType paper = PaperType.whiteCartridge,
//       double detail = 1.0,          // 0.5..2  stroke count scale
//       double lineWeight = 1.0,      // 0.3..3
//       double hatchDensity = 1.0,    // 0.3..2.5
//       double shading = 1.0,         // 0..2 overall tone strength
//       double edgeStrength = 1.0,    // 0..3
//       double grain = 1.0,           // 0..2 paper tooth
//       double smudge = 1.0,          // 0..2 charcoal smearing
//       double inkFlow = 1.0,         // 0..2 ballpoint unevenness
//       int    inkArgb = 0xFF2B2B2B,  // pencil/ink colour
//       bool   transparentBackground = false,
//       int    longEdge = 1024,       // working size
//       int    seed = 1,
//     });
//     Map<String, Object?> toJson();
//     factory SketchSettings.fromJson(Map<String, Object?> json);
//     SketchSettings copyWith({...});
//   }
//
//   class SketchResult {
//     RgbImage get image;              // composited paper + graphite, 8-bit
//     List<SketchStroke> get strokes;  // recorded, in draw order, for replay
//     int get width;
//     int get height;
//     Uint8List get pngBytes;          // encoded PNG of `image`
//   }
//
//   class SketchEngine {
//     /// Pure entry point: deterministic for identical (image, settings).
///    static SketchResult render(RgbImage source, SketchSettings settings,
//        {void Function(double progress)? onProgress});
//   }
//
// Determinism: no `Random()` without a seed, no map iteration order dependence,
// no time/locale dependence. Same seed + same input bytes => identical PNG.
