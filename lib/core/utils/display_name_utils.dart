/// Utilities for user display name validation, normalization, and first-name extraction.
library;

class DisplayNameUtils {
  /// Checks whether a Unicode code point represents an emoji or pictorial symbol.
  static bool _isEmoji(int rune) {
    return (rune >= 0x1F600 && rune <= 0x1F64F) || // Emoticons
        (rune >= 0x1F300 && rune <= 0x1F5FF) || // Misc Symbols and Pictographs
        (rune >= 0x1F680 && rune <= 0x1F6FF) || // Transport and Map
        (rune >= 0x1F700 && rune <= 0x1F77F) || // Alchemical Symbols
        (rune >= 0x1F780 && rune <= 0x1F7FF) || // Geometric Shapes Extended
        (rune >= 0x1F800 && rune <= 0x1F8FF) || // Supplemental Arrows-C
        (rune >= 0x1F900 && rune <= 0x1F9FF) || // Supplemental Symbols and Pictographs
        (rune >= 0x1FA00 && rune <= 0x1FA6F) || // Chess Symbols
        (rune >= 0x1FA70 && rune <= 0x1FAFF) || // Symbols and Pictographs Extended-A
        (rune >= 0x2600 && rune <= 0x26FF) || // Misc Symbols (☀️, ☕, ⚡, ⚠️, etc.)
        (rune >= 0x2700 && rune <= 0x27BF) || // Dingbats (✨, ✂️, etc.)
        (rune >= 0xFE00 && rune <= 0xFE0F) || // Variation Selectors
        (rune >= 0x1F1E6 && rune <= 0x1F1FF) || // Regional Indicators / Flags
        (rune >= 0x1F191 && rune <= 0x1F251) || // Enclosed Ideographic Supplement
        (rune >= 0x2300 && rune <= 0x23FF) || // Misc Technical
        rune == 0x2B50; // Star
  }

  /// Checks whether a Unicode code point is an unprintable control character.
  static bool _isControlChar(int rune) {
    return (rune >= 0x0000 && rune <= 0x001F) || (rune >= 0x007F && rune <= 0x009F);
  }

  /// Checks whether a code point is a disallowed digit or symbol in names.
  static bool _isDisallowedSymbolOrDigit(int rune) {
    // Digits 0-9
    if (rune >= 0x30 && rune <= 0x39) return true;

    // Disallowed ASCII punctuation / operators
    const disallowedAscii = {
      0x21, // !
      0x22, // "
      0x23, // #
      0x24, // $
      0x25, // %
      0x26, // &
      0x28, // (
      0x29, // )
      0x2A, // *
      0x2B, // +
      0x2C, // ,
      0x2F, // /
      0x3A, // :
      0x3B, // ;
      0x3C, // <
      0x3D, // =
      0x3E, // >
      0x3F, // ?
      0x40, // @
      0x5B, // [
      0x5C, // \
      0x5D, // ]
      0x5E, // ^
      0x5F, // _
      0x60, // `
      0x7B, // {
      0x7C, // |
      0x7D, // }
      0x7E, // ~
    };
    return disallowedAscii.contains(rune);
  }

  /// Checks whether a code point represents a valid name character across
  /// supported international scripts (Latin, Indian scripts, Cyrillic, Greek, Arabic, CJK, etc.)
  /// or allowed name punctuation (space, period, apostrophe, hyphen, ZWJ, ZWNJ).
  static bool _isValidNameChar(int rune) {
    // Allowed name separators and punctuation
    if (rune == 0x20 || // Space
        rune == 0x2D || // Hyphen '-'
        rune == 0x27 || // Apostrophe '\''
        rune == 0x2E || // Period '.'
        rune == 0x200C || // ZWNJ
        rune == 0x200D) { // ZWJ
      return true;
    }

    // Latin Alphabets & Diacritics (A-Z, a-z, Extended-A, Extended-B, Additional)
    if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0x00C0 && rune <= 0x024F) ||
        (rune >= 0x1E00 && rune <= 0x1EFF)) {
      return true;
    }

    // Indian Scripts:
    // Devanagari (Hindi, Marathi, Sanskrit)
    if (rune >= 0x0900 && rune <= 0x097F) return true;
    // Bengali & Assamese
    if (rune >= 0x0980 && rune <= 0x09FF) return true;
    // Gurmukhi (Punjabi)
    if (rune >= 0x0A00 && rune <= 0x0A7F) return true;
    // Gujarati
    if (rune >= 0x0A80 && rune <= 0x0AFF) return true;
    // Oriya
    if (rune >= 0x0B00 && rune <= 0x0B7F) return true;
    // Tamil
    if (rune >= 0x0B80 && rune <= 0x0BFF) return true;
    // Telugu
    if (rune >= 0x0C00 && rune <= 0x0C7F) return true;
    // Kannada
    if (rune >= 0x0C80 && rune <= 0x0CFF) return true;
    // Malayalam
    if (rune >= 0x0D00 && rune <= 0x0D7F) return true;

    // Cyrillic (Russian, Ukrainian, etc.)
    if (rune >= 0x0400 && rune <= 0x04FF) return true;
    // Greek
    if (rune >= 0x0370 && rune <= 0x03FF) return true;
    // Arabic, Persian, Urdu
    if (rune >= 0x0600 && rune <= 0x06FF) return true;
    // CJK Unified Ideographs & Kana
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0xAC00 && rune <= 0xD7AF)) {
      return true;
    }

    return false;
  }

  /// Checks whether a code point is a letter (not punctuation or space).
  static bool _isLetter(int rune) {
    if (rune == 0x20 || rune == 0x2D || rune == 0x27 || rune == 0x2E) {
      return false;
    }
    return _isValidNameChar(rune);
  }

  /// Trims leading/trailing whitespace and collapses internal multiple spaces into single spaces.
  static String normalize(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Extracts the first name from a full display name.
  ///
  /// Examples:
  /// - "Shreyas Shigwan" -> "Shreyas"
  /// - "Aman Sharma" -> "Aman"
  /// - "Sachi Patel" -> "Sachi"
  /// - "Rohit" -> "Rohit"
  /// - "  श्रेयस   शिगवण " -> "श्रेयस"
  ///
  /// Preserves the user's intended capitalization and handles single words,
  /// multi-word names, and Unicode names safely.
  static String extractFirstName(String? displayName, {String fallback = 'User'}) {
    if (displayName == null) return fallback;
    final normalized = normalize(displayName);
    if (normalized.isEmpty) return fallback;

    final parts = normalized.split(' ');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first;
    }
    return fallback;
  }

  /// Validates a candidate display name.
  ///
  /// Returns `null` if the name is valid, or a user-facing error message describing the violation.
  static String? validate(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Display name cannot be empty.';
    }

    final normalized = normalize(name);

    if (normalized.length < 2) {
      return 'Display name must be at least 2 characters long.';
    }

    if (normalized.length > 50) {
      return 'Display name cannot exceed 50 characters.';
    }

    // Check individual runes
    bool hasLetter = false;
    for (final rune in name.runes) {
      if (_isControlChar(rune)) {
        return 'Display name contains invalid control characters.';
      }

      if (_isEmoji(rune)) {
        return 'Display name cannot contain emojis or symbols.';
      }

      if (_isDisallowedSymbolOrDigit(rune) || !_isValidNameChar(rune)) {
        return 'Display name can only contain letters, spaces, hyphens, periods, and apostrophes.';
      }

      if (_isLetter(rune)) {
        hasLetter = true;
      }
    }

    if (!hasLetter) {
      return 'Display name must contain at least one letter.';
    }

    return null;
  }
}
