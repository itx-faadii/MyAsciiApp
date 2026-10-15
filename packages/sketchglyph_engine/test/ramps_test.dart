/// Tests for character ramp building and preset management.
///
/// Validates ramp construction, density sorting, deduplication,
/// and preset lookup functionality.
library;

import 'package:sketchglyph_engine/sketchglyph_engine.dart';
import 'package:test/test.dart';

void main() {
  group('buildRamp', () {
    test('sorts by density ascending', () {
      final List<String> ramp = buildRamp(<String>['@', '.', ' ', '#'], (
        String c,
      ) {
        if (c == ' ') return 0.0;
        if (c == '.') return 0.1;
        if (c == '#') return 0.5;
        if (c == '@') return 0.8;
        return 0.0;
      });

      expect(ramp, <String>[' ', '.', '#', '@']);
    });

    test('deduplicates characters', () {
      final List<String> ramp = buildRamp(<String>[
        'a',
        'a',
        'b',
        'b',
        'c',
      ], (String c) => c.codeUnitAt(0).toDouble());

      expect(ramp.length, 3);
      expect(ramp.toSet().length, 3);
    });

    test('stable sort on equal density uses codepoint order', () {
      final List<String> ramp = buildRamp(
        <String>['c', 'a', 'b'],
        (String c) => 0.5, // All same density
      );

      // Should be sorted by codepoint: 'a' < 'b' < 'c'
      expect(ramp, <String>['a', 'b', 'c']);
    });

    test('single character returns as-is', () {
      final List<String> ramp = buildRamp(<String>['x'], (String c) => 0.5);

      expect(ramp, <String>['x']);
    });

    test('empty input returns empty list', () {
      final List<String> ramp = buildRamp(<String>[], (String c) => 0.5);

      expect(ramp, isEmpty);
    });

    test('handles unicode characters', () {
      final List<String> ramp = buildRamp(<String>['█', '▓', '▒', '░'], (
        String c,
      ) {
        if (c == '░') return 0.25;
        if (c == '▒') return 0.5;
        if (c == '▓') return 0.75;
        if (c == '█') return 1.0;
        return 0.0;
      });

      expect(ramp, <String>['░', '▒', '▓', '█']);
    });

    test('preserves all unique characters', () {
      final List<String> input = <String>[
        ' ',
        '.',
        ':',
        '-',
        '=',
        '+',
        '*',
        '#',
        '%',
        '@',
      ];
      final List<String> ramp = buildRamp(
        input,
        (String c) => c.codeUnitAt(0).toDouble() / 255.0,
      );

      expect(ramp.length, input.length);
      expect(ramp.toSet().length, input.length);
    });
  });

  group('splitSupported', () {
    test('partitions into supported and missing', () {
      final (:List<String> usable, :List<String> missing) = splitSupported(
        <String>['a', 'b', 'c', 'd'],
        (String c) => c != 'b' && c != 'd',
      );

      expect(usable, <String>['a', 'c']);
      expect(missing, <String>['b', 'd']);
    });

    test('all supported returns empty missing', () {
      final (:List<String> usable, :List<String> missing) = splitSupported(
        <String>['a', 'b', 'c'],
        (String c) => true,
      );

      expect(usable, <String>['a', 'b', 'c']);
      expect(missing, isEmpty);
    });

    test('none supported returns empty usable', () {
      final (:List<String> usable, :List<String> missing) = splitSupported(
        <String>['a', 'b', 'c'],
        (String c) => false,
      );

      expect(usable, isEmpty);
      expect(missing, <String>['a', 'b', 'c']);
    });

    test('empty input returns empty lists', () {
      final (:List<String> usable, :List<String> missing) = splitSupported(
        <String>[],
        (String c) => true,
      );

      expect(usable, isEmpty);
      expect(missing, isEmpty);
    });

    test('preserves order', () {
      final (:List<String> usable, :List<String> missing) = splitSupported(
        <String>['z', 'a', 'm', 'b'],
        (String c) => c.codeUnitAt(0) < 100, // 'a' and 'b'
      );

      expect(usable, <String>['a', 'b']);
      expect(missing, <String>['z', 'm']);
    });
  });

  group('RampPresets', () {
    test('all returns non-empty list', () {
      final List<RampPreset> presets = RampPresets.all;
      expect(presets, isNotEmpty);
    });

    test('all presets have unique ids', () {
      final List<RampPreset> presets = RampPresets.all;
      final Set<String> ids = presets.map((RampPreset p) => p.id).toSet();
      expect(ids.length, presets.length);
    });

    test('all presets have non-empty labels', () {
      for (final RampPreset preset in RampPresets.all) {
        expect(preset.label, isNotEmpty);
      }
    });

    test('all presets have at least 2 unique characters', () {
      for (final RampPreset preset in RampPresets.all) {
        final Set<String> unique = preset.characters.split('').toSet();
        expect(
          unique.length,
          greaterThanOrEqualTo(2),
          reason: 'Preset ${preset.id} should have at least 2 unique chars',
        );
      }
    });

    test('byId returns correct preset', () {
      final RampPreset? classic = RampPresets.byId('classic');
      expect(classic, isNotNull);
      expect(classic!.id, 'classic');
      expect(classic.label, 'Classic');
    });

    test('byId returns null for unknown id', () {
      final RampPreset? unknown = RampPresets.byId('nonexistent');
      expect(unknown, isNull);
    });

    test('byId finds all presets', () {
      for (final RampPreset preset in RampPresets.all) {
        final RampPreset? found = RampPresets.byId(preset.id);
        expect(found, isNotNull);
        expect(found!.id, preset.id);
        expect(found.label, preset.label);
        expect(found.characters, preset.characters);
      }
    });

    test('classic preset has expected characters', () {
      final RampPreset? classic = RampPresets.byId('classic');
      expect(classic, isNotNull);
      expect(classic!.characters, contains('.'));
      expect(classic.characters, contains('@'));
    });

    test('blocks preset contains block characters', () {
      final RampPreset? blocks = RampPresets.byId('blocks');
      expect(blocks, isNotNull);
      expect(blocks!.characters, contains('█'));
    });

    test('binary preset has exactly 2 characters', () {
      final RampPreset? binary = RampPresets.byId('binary');
      expect(binary, isNotNull);
      final Set<String> unique = binary!.characters.split('').toSet();
      expect(unique.length, 2);
    });
  });

  group('kDefaultRamp', () {
    test('is non-empty', () {
      expect(kDefaultRamp, isNotEmpty);
    });

    test('contains space as lightest character', () {
      expect(kDefaultRamp, contains(' '));
    });

    test('contains dense characters', () {
      expect(kDefaultRamp, contains('@'));
      expect(kDefaultRamp, contains('#'));
    });

    test('has at least 10 unique characters', () {
      final Set<String> unique = kDefaultRamp.split('').toSet();
      expect(unique.length, greaterThanOrEqualTo(10));
    });
  });

  group('RampPreset', () {
    test('stores id, label, and characters', () {
      const RampPreset preset = RampPreset(
        id: 'test',
        label: 'Test Preset',
        characters: 'abc',
      );

      expect(preset.id, 'test');
      expect(preset.label, 'Test Preset');
      expect(preset.characters, 'abc');
    });

    test('characters can contain unicode', () {
      const RampPreset preset = RampPreset(
        id: 'unicode',
        label: 'Unicode',
        characters: '░▒▓█',
      );

      expect(preset.characters.length, 4);
      expect(preset.characters, contains('█'));
    });
  });
}
