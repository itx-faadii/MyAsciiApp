/// Validation helpers for user-supplied strings in ASCII rendering.
library;

/// Validates a user string for ASCII rendering.
///
/// Returns `null` if valid, otherwise a user-facing error message.
String? validateUserString(String raw) {
  if (raw.trim().isEmpty) {
    return 'Enter some text to use for the art.';
  }

  // Check for emoji in common ranges.
  for (final int rune in raw.runes) {
    if (_isEmoji(rune)) {
      return 'Emoji aren\'t supported -- use letters, digits or symbols.';
    }
  }

  if (raw.runes.length > 4096) {
    return 'That text is too long (4096 characters max).';
  }

  // Check for visible (non-space) characters.
  bool hasVisible = false;
  for (final int rune in raw.runes) {
    final String char = String.fromCharCode(rune);
    if (char.trim().isNotEmpty) {
      hasVisible = true;
      break;
    }
  }

  if (!hasVisible) {
    return 'The text contains no visible characters.';
  }

  // Count unique visible characters for ramp mode.
  final Set<String> uniqueVisible = <String>{};
  for (final int rune in raw.runes) {
    final String char = String.fromCharCode(rune);
    if (char.trim().isNotEmpty) {
      uniqueVisible.add(char);
    }
  }

  if (uniqueVisible.length < 2) {
    return 'Ramp mode needs at least two different characters.';
  }

  return null;
}

/// Returns unique characters from [s] in first-seen order.
List<String> orderedChars(String s) {
  final List<String> result = <String>[];
  final Set<String> seen = <String>{};
  for (final int rune in s.runes) {
    final String char = String.fromCharCode(rune);
    if (seen.add(char)) {
      result.add(char);
    }
  }
  return result;
}

/// Checks if a rune is in common emoji ranges.
bool _isEmoji(int rune) {
  // Common emoji ranges.
  if (rune >= 0x1F000 && rune <= 0x1FAFF) return true;
  if (rune >= 0x2600 && rune <= 0x27BF) return true;
  if (rune == 0xFE0F) return true;
  if (rune >= 0x1F1E6 && rune <= 0x1F1FF) return true;
  if (rune >= 0x2B00 && rune <= 0x2BFF) return true;
  return false;
}
