/// App-side presets for ASCII rendering, color palettes, and fonts.
library;

import 'package:sketchglyph_engine/sketchglyph_engine.dart';

// Curated 70-level dense ramp mirroring the engine's "Dense 70-level" preset.
const String _kDense70 =
    r''' .'`^_,":;-i=+itI<>7?][}{1)(|\/TFJL7CVXZUNMKWS5Y3#RPGQBD2ZO098&%$@''';

// ---------------------------------------------------------------------------
// Named rendering presets
// ---------------------------------------------------------------------------

/// A named rendering preset that builds ready-to-use [AsciiSettings].
class AsciiPreset {
  /// Creates a preset.
  const AsciiPreset({
    required this.id,
    required this.label,
    required this.build,
  });

  /// Stable identifier.
  final String id;

  /// Human-readable label.
  final String label;

  /// Builds fresh settings for this preset.
  final AsciiSettings Function() build;

  /// All named presets shown in the UI, in display order.
  static const List<AsciiPreset> all = <AsciiPreset>[
    _terminal,
    _poster,
    _fineDetail,
    _stencil,
    _binaryCode,
    _handwrittenWord,
  ];

  // -- builders (static tear-offs are const-compatible) --------------------

  static AsciiSettings _buildTerminal() => AsciiSettings(
    font: 'JetBrainsMono-Regular',
    colorMode: ColorMode.mono,
    foreground: 0xFF33FF33,
    background: 0xFF0A0F0A,
  );

  static AsciiSettings _buildPoster() => AsciiSettings(
    font: 'JetBrainsMono-Regular',
    mode: AsciiMode.characterSet,
    characterSet: ' \u2591\u2592\u2593\u2588',
    contrast: 1.4,
    colorMode: ColorMode.gradient,
    gradientStart: 0xFFFF2FD6,
    gradientEnd: 0xFF4CC9F0,
    background: 0xFF0B0716,
  );

  static AsciiSettings _buildFineDetail() => AsciiSettings(
    font: 'JetBrainsMono-Regular',
    mode: AsciiMode.characterSet,
    characterSet: _kDense70,
    filter: GridFilter.lanczos,
    columns: 140,
  );

  static AsciiSettings _buildStencil() => AsciiSettings(
    font: 'JetBrainsMono-Regular',
    mode: AsciiMode.characterSet,
    characterSet: ' .oO8&%@',
    dither: DitherKind.floydSteinberg,
  );

  static AsciiSettings _buildBinaryCode() => AsciiSettings(
    font: 'JetBrainsMono-Regular',
    mode: AsciiMode.characterSet,
    characterSet: '01',
  );

  static AsciiSettings _buildHandwrittenWord() => AsciiSettings(
    font: 'JetBrainsMono-Regular',
    mode: AsciiMode.userString,
    userString: 'sketchglyph',
    userStringMode: UserStringMode.textFlow,
  );

  // -- instances -----------------------------------------------------------

  static const AsciiPreset _terminal = AsciiPreset(
    id: 'terminal',
    label: 'Terminal',
    build: _buildTerminal,
  );

  static const AsciiPreset _poster = AsciiPreset(
    id: 'poster',
    label: 'Poster',
    build: _buildPoster,
  );

  static const AsciiPreset _fineDetail = AsciiPreset(
    id: 'fine_detail',
    label: 'Fine Detail',
    build: _buildFineDetail,
  );

  static const AsciiPreset _stencil = AsciiPreset(
    id: 'stencil',
    label: 'Stencil',
    build: _buildStencil,
  );

  static const AsciiPreset _binaryCode = AsciiPreset(
    id: 'binary_code',
    label: 'Binary Code',
    build: _buildBinaryCode,
  );

  static const AsciiPreset _handwrittenWord = AsciiPreset(
    id: 'handwritten_word',
    label: 'Handwritten Word',
    build: _buildHandwrittenWord,
  );
}

// ---------------------------------------------------------------------------
// Character-set presets (AsciiMode.characterSet)
// ---------------------------------------------------------------------------

/// A named character-set preset for ART BY CHARACTER SET mode.
class CharSetPreset {
  /// Creates a preset.
  const CharSetPreset({
    required this.id,
    required this.label,
    required this.characters,
  });

  /// Stable identifier.
  final String id;

  /// Human-readable label.
  final String label;

  /// Characters from light to dark (engine re-sorts by measured density).
  final String characters;

  /// All character-set presets shown in the UI, in display order.
  static const List<CharSetPreset> charSets = <CharSetPreset>[
    CharSetPreset(id: 'classic', label: 'Classic', characters: kDefaultRamp),
    CharSetPreset(id: 'full_ascii', label: 'Full ASCII', characters: _kDense70),
    CharSetPreset(
      id: 'blocks',
      label: 'Blocks',
      characters: ' \u2591\u2592\u2593\u2588',
    ),
    CharSetPreset(id: 'minimal', label: 'Minimal', characters: ' .#@'),
    CharSetPreset(id: 'binary', label: 'Binary', characters: '01'),
    CharSetPreset(
      id: 'braille',
      label: 'Braille',
      characters: ' \u2840\u2864\u28C6\u28F6\u28FF',
    ),
    CharSetPreset(id: 'letters', label: 'Letters', characters: ' .oO8&%@'),
    CharSetPreset(id: 'numbers', label: 'Numbers', characters: '0123456789'),
  ];
}

// ---------------------------------------------------------------------------
// Color palette presets (independent of the app theme)
// ---------------------------------------------------------------------------

/// A named color palette for ASCII preview and export.
class PalettePreset {
  /// Creates a palette preset.
  const PalettePreset({
    required this.id,
    required this.label,
    required this.foreground,
    required this.background,
    required this.gradientStart,
    required this.gradientEnd,
  });

  /// Stable identifier.
  final String id;

  /// Human-readable label.
  final String label;

  /// Mono foreground, ARGB.
  final int foreground;

  /// Background, ARGB.
  final int background;

  /// Gradient start, ARGB.
  final int gradientStart;

  /// Gradient end, ARGB.
  final int gradientEnd;

  /// All palette presets shown in the UI, in display order.
  static const List<PalettePreset> palettes = <PalettePreset>[
    PalettePreset(
      id: 'terminal_green',
      label: 'Terminal Green',
      foreground: 0xFF33FF33,
      background: 0xFF0A0F0A,
      gradientStart: 0xFF33FF33,
      gradientEnd: 0xFF33FF33,
    ),
    PalettePreset(
      id: 'amber_monitor',
      label: 'Amber Monitor',
      foreground: 0xFFFFB000,
      background: 0xFF160F04,
      gradientStart: 0xFFFFB000,
      gradientEnd: 0xFFFFB000,
    ),
    PalettePreset(
      id: 'paper_ink',
      label: 'Paper Ink',
      foreground: 0xFF1C232C,
      background: 0xFFF4F1E8,
      gradientStart: 0xFF1C232C,
      gradientEnd: 0xFF1C232C,
    ),
    PalettePreset(
      id: 'neon',
      label: 'Neon',
      foreground: 0xFFFF2FD6,
      background: 0xFF0B0716,
      gradientStart: 0xFFFF2FD6,
      gradientEnd: 0xFF4CC9F0,
    ),
    PalettePreset(
      id: 'matrix',
      label: 'Matrix',
      foreground: 0xFF00FF66,
      background: 0xFF000800,
      gradientStart: 0xFF00FF66,
      gradientEnd: 0xFF00FF66,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Bundled font options
// ---------------------------------------------------------------------------

/// A font available for ASCII rendering.
class FontOption {
  /// Creates a font option.
  const FontOption({
    required this.id,
    required this.engineFamily,
    required this.assetPath,
  });

  /// Stable identifier.
  final String id;

  /// Family name as keyed in `assets/font_metrics.json`.
  final String engineFamily;

  /// Asset path for the TTF/OTF file.
  final String assetPath;

  /// All bundled fonts shown in the UI, in display order.
  static const List<FontOption> bundled = <FontOption>[
    FontOption(
      id: 'jetbrains_mono',
      engineFamily: 'JetBrainsMono-Regular',
      assetPath: 'assets/fonts/JetBrainsMono-Regular.ttf',
    ),
    FontOption(
      id: 'courier_prime',
      engineFamily: 'Courier Prime',
      assetPath: 'assets/fonts/Courier Prime.ttf',
    ),
    FontOption(
      id: 'ibm_plex_mono',
      engineFamily: 'IBM Plex Mono',
      assetPath: 'assets/fonts/IBM Plex Mono.ttf',
    ),
  ];
}
