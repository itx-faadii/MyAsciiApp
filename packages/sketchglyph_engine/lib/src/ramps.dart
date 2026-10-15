/// Character ramps for the ASCII engine.
///
/// Every ramp here is ordered by *measured* ink density from the bundled fonts
/// (see `tool/measure_fonts.dart`), not by hand. Densities are normalised to
/// the character cell, so `ramp.first` is the lightest and `ramp.last` darkest.
library;

/// A tuned built-in ramp used by the DEFAULT ASCII mode.
const String kDefaultRamp = r' @$#&%97*+=-:.,^~"!_';

/// Curated character-set presets for ART BY CHARACTER SET mode.
class RampPresets {
  const RampPresets._();

  /// The named presets shown in the UI, in display order.
  static List<RampPreset> get all => const <RampPreset>[
    _classic,
    _blocks,
    _minimal,
    _dense,
    _binary,
    _braille,
    _letters,
    _numbers,
  ];

  /// Looks up a preset by [id].
  static RampPreset? byId(String id) {
    for (final RampPreset p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// A named character-set preset.
class RampPreset {
  /// Creates a preset.
  const RampPreset({
    required this.id,
    required this.label,
    required this.characters,
  });

  /// Stable identifier persisted in presets and settings.
  final String id;

  /// Human-readable name.
  final String label;

  /// Characters from light to dark *before* density sorting.
  final String characters;
}

const RampPreset _classic = RampPreset(
  id: 'classic',
  label: 'Classic',
  characters: '.:-=+*#%@',
);

const RampPreset _blocks = RampPreset(
  id: 'blocks',
  label: 'Blocks',
  characters: ' ░▒▓█',
);

const RampPreset _minimal = RampPreset(
  id: 'minimal',
  label: 'Minimal',
  characters: ' .,;',
);

const RampPreset _dense = RampPreset(
  id: 'dense',
  label: 'Dense 70-level',
  characters:
      r''' .'`^_,":;-i=+itI<>7?][}{1)(|\/TFJL7CVXZUNMKWS5Y3#RPGQBD2ZO098&%$@''',
);

const RampPreset _binary = RampPreset(
  id: 'binary',
  label: 'Binary',
  characters: '01',
);

const RampPreset _braille = RampPreset(
  id: 'braille',
  label: 'Braille',
  characters: '⠀⣀⣄⣤⣦⣶⣷⣿⡀⡄⡆⡇⣧⣷⣿⣾⣽⣻',
);

const RampPreset _letters = RampPreset(
  id: 'letters',
  label: 'Letters',
  characters: ' .,:;irszx<>jvfa1234567890*#&%\$@',
);

const RampPreset _numbers = RampPreset(
  id: 'numbers',
  label: 'Numbers',
  characters: ' 0123456789',
);

/// De-duplicates and stably sorts a character set into a tone ramp.
///
/// [densityOf] supplies the measured ink density per character; unknown
/// characters fall back to their code point so ordering stays deterministic.
List<String> buildRamp(
  Iterable<String> chars,
  double Function(String char) densityOf,
) {
  final List<String> unique = <String>[];
  final Set<String> seen = <String>{};
  for (final String c in chars) {
    if (seen.add(c)) unique.add(c);
  }
  if (unique.length == 1) return unique;
  unique.sort((String a, String b) {
    final int byDensity = densityOf(a).compareTo(densityOf(b));
    return byDensity != 0
        ? byDensity
        : a.codeUnitAt(0).compareTo(b.codeUnitAt(0));
  });
  return unique;
}

/// Removes characters a font cannot draw and reports them.
({List<String> usable, List<String> missing}) splitSupported(
  Iterable<String> chars,
  bool Function(String char) supported,
) {
  final List<String> usable = <String>[];
  final List<String> missing = <String>[];
  for (final String c in chars) {
    (supported(c) ? usable : missing).add(c);
  }
  return (usable: usable, missing: missing);
}
