/// SketchGlyph engines: ASCII art and realistic sketch rendering.
///
/// Pure Dart, no Flutter, deterministic, offline.
library;

export 'src/ascii_engine.dart'
    show
        AsciiEngine,
        AsciiSettings,
        AsciiDocument,
        AsciiMode,
        UserStringMode,
        GridSizing,
        GridFilter,
        ColorMode,
        DitherKind,
        PageBox,
        TextFlowResult,
        AsciiSettingsException,
        decodeImageBytes,
        encodePngBytes,
        kEdgeChars;
export 'src/color.dart'
    show
        GrayImage,
        RgbImage,
        srgbToLinear,
        linearToSrgb,
        grayToLinear,
        linearToGray,
        kRec709Red,
        kRec709Green,
        kRec709Blue;
export 'src/glyph_metrics.dart'
    show
        FontMetrics,
        GlyphBitmap,
        GlyphMeasurement,
        measureGlyphDensity,
        measureRamp,
        rasteriseGlyph;
export 'src/ramps.dart'
    show RampPreset, RampPresets, kDefaultRamp, buildRamp, splitSupported;
export 'src/random.dart' show SeededRandom, ValueNoise2D, splitMix64;
export 'src/resample.dart'
    show ResampleFilter, areaAverage, gaussianBlur, sharpen, downscaleGray;
export 'src/sketch/sketch_engine.dart'
    show
        SketchEngine,
        SketchSettings,
        SketchStyle,
        SketchStyleInfo,
        sketchStyleById,
        PaperType,
        PaperTypeInfo,
        paperTypeById,
        SketchResult,
        SketchStroke,
        StrokeKind;
export 'src/synthetic.dart'
    show
        syntheticPortrait,
        syntheticLandscape,
        syntheticObject,
        gradientStrip,
        checkerboard;
export 'src/text_renderer.dart'
    show GlyphSource, TtfGlyphSource, AsciiCellGeometry, renderAsciiPng;
export 'src/ttf.dart' show TtfFont;
