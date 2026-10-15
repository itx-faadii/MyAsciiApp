/// Tests for ASCII string validation helpers.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sketchglyph/features/ascii/domain/ascii_string_validation.dart';

void main() {
  group('validateUserString', () {
    test('returns null for valid text with multiple unique chars', () {
      expect(validateUserString('hello world'), isNull);
    });

    test('rejects empty string', () {
      expect(validateUserString(''), 'Enter some text to use for the art.');
    });

    test('rejects whitespace-only string', () {
      expect(validateUserString('   '), 'Enter some text to use for the art.');
    });

    test('rejects emoji in common ranges', () {
      expect(
        validateUserString('hello \u{1F600}'),
        'Emoji aren\'t supported -- use letters, digits or symbols.',
      );
      expect(
        validateUserString('\u{2600}'),
        'Emoji aren\'t supported -- use letters, digits or symbols.',
      );
      expect(
        validateUserString('\u{FE0F}'),
        'Emoji aren\'t supported -- use letters, digits or symbols.',
      );
    });

    test('rejects text longer than 4096 characters', () {
      final String long = 'a' * 4097;
      expect(
        validateUserString(long),
        'That text is too long (4096 characters max).',
      );
    });

    test('accepts text exactly at 4096 limit', () {
      final String atLimit = 'ab' * 2048;
      expect(validateUserString(atLimit), isNull);
    });

    test('rejects text with no visible characters', () {
      expect(validateUserString('   '), 'Enter some text to use for the art.');
    });

    test('rejects ramp mode with only one unique visible char', () {
      expect(
        validateUserString('aaa'),
        'Ramp mode needs at least two different characters.',
      );
    });

    test('accepts two unique visible chars', () {
      expect(validateUserString('ab'), isNull);
    });
  });

  group('orderedChars', () {
    test('returns unique chars in first-seen order', () {
      expect(orderedChars('hello'), <String>['h', 'e', 'l', 'o']);
    });

    test('preserves order with duplicates', () {
      expect(orderedChars('aabbcc'), <String>['a', 'b', 'c']);
    });

    test('handles empty string', () {
      expect(orderedChars(''), isEmpty);
    });

    test('handles single character', () {
      expect(orderedChars('x'), <String>['x']);
    });
  });
}
