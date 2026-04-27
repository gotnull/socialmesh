// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// International Morse code table for the SIP Signal v1 Morse mode.
///
/// Supported characters:
///   - A-Z (uppercase)
///   - 0-9
///   - space (word gap)
///   - punctuation: `.`, `,`, `?`, `!`, `/`, `@`
///
/// Anything else is rejected at encode time with
/// [SipSignalDecodeError.unsupportedMorseChar] so we never ship a
/// pattern the receiver can't reproduce.
abstract final class MorseTable {
  /// Single-character → dot/dash sequence using `.` and `-`.
  /// Space is special-cased by the renderer (word gap, not a
  /// dot/dash sequence).
  static const Map<String, String> charToCode = {
    'A': '.-',
    'B': '-...',
    'C': '-.-.',
    'D': '-..',
    'E': '.',
    'F': '..-.',
    'G': '--.',
    'H': '....',
    'I': '..',
    'J': '.---',
    'K': '-.-',
    'L': '.-..',
    'M': '--',
    'N': '-.',
    'O': '---',
    'P': '.--.',
    'Q': '--.-',
    'R': '.-.',
    'S': '...',
    'T': '-',
    'U': '..-',
    'V': '...-',
    'W': '.--',
    'X': '-..-',
    'Y': '-.--',
    'Z': '--..',
    '0': '-----',
    '1': '.----',
    '2': '..---',
    '3': '...--',
    '4': '....-',
    '5': '.....',
    '6': '-....',
    '7': '--...',
    '8': '---..',
    '9': '----.',
    '.': '.-.-.-',
    ',': '--..--',
    '?': '..--..',
    '!': '-.-.--',
    '/': '-..-.',
    '@': '.--.-.',
  };

  /// Reverse of [charToCode] — built lazily on first access.
  ///
  /// Used by the tap-Morse input surface to decode a token like
  /// `"..."` back to the letter `"S"` while the user is composing.
  /// Returns null when the token is not in the table.
  ///
  /// The table values are unique by construction (international Morse
  /// is bijective on the supported alphabet) so a flat reverse map is
  /// safe and O(1).
  static String? letterForToken(String token) {
    final inverse = _inverseTable;
    return inverse[token];
  }

  static Map<String, String>? _inverseCache;
  static Map<String, String> get _inverseTable {
    final cached = _inverseCache;
    if (cached != null) return cached;
    final built = <String, String>{};
    for (final entry in charToCode.entries) {
      built[entry.value] = entry.key;
    }
    return _inverseCache = Map.unmodifiable(built);
  }

  /// Returns true iff every char in [text] (ignoring spaces, after
  /// uppercasing) is supported by the table.
  static bool isEncodable(String text) {
    for (final ch in text.toUpperCase().split('')) {
      if (ch == ' ') continue;
      if (!charToCode.containsKey(ch)) return false;
    }
    return true;
  }

  /// Strip every unsupported character. Used for the live composer
  /// preview — the actual send rejects unsupported chars rather
  /// than silently dropping them.
  static String filtered(String text) {
    final upper = text.toUpperCase();
    final buf = StringBuffer();
    for (final ch in upper.split('')) {
      if (ch == ' ' || charToCode.containsKey(ch)) {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  /// Word-separator string used by [render] and the tap-Morse
  /// composer. Single source of truth so the live preview, the
  /// rendered receiver pattern, and the canonical [decode] all agree.
  ///
  /// The middle dot (U+00B7) is visually distinct from a Morse `.`
  /// (which encodes the letter E) and from a Morse `-` (T) — so the
  /// separator never collides with the alphabet. Spaces around it
  /// keep the displayed pattern readable on long messages.
  static const String wordSeparator = ' · ';

  /// Convert [text] → human-readable Morse string.
  /// - Letters separated by single space (` `).
  /// - Words separated by [wordSeparator] (` · `).
  ///
  /// Unsupported characters are passed through as `?` placeholders
  /// in the displayed pattern. The encoder rejects unsupported
  /// chars before sending so the receiver never has to interpret
  /// a `?`.
  static String render(String text) {
    final upper = text.toUpperCase();
    final words = upper.split(' ');
    final renderedWords = <String>[];
    for (final word in words) {
      if (word.isEmpty) continue;
      final letters = <String>[];
      for (final ch in word.split('')) {
        letters.add(charToCode[ch] ?? '?');
      }
      renderedWords.add(letters.join(' '));
    }
    return renderedWords.join(wordSeparator);
  }

  /// Canonical Morse → text decoder.
  ///
  /// Decoding rules (per v1 token-grouping spec):
  ///
  ///   1. **Explicit separators** — input contains ` / `: split on
  ///      that for words, then on single space for letters. Each
  ///      letter token is looked up via [letterForToken].
  ///   2. **Multi-space fallback** — input has no `/` but contains
  ///      ≥2 consecutive spaces: treat the multi-space run as a
  ///      word boundary.
  ///   3. **Single-space fallback** — input has only single spaces:
  ///      decode as a sequence of letters with no word boundaries.
  ///   4. **Continuous fallback** — input has no whitespace at all:
  ///      best-effort greedy decode (longest matching prefix from
  ///      the canonical table). Inherently lossy on ambiguous input;
  ///      surfaces unknown sub-strings as `?`.
  ///
  /// Tokens that don't resolve to a letter are emitted as `?` so the
  /// caller can flag them in UI without losing the rest of the
  /// decode.
  static String decode(String pattern) {
    if (pattern.isEmpty) return '';
    // Primary: the canonical middle-dot separator emitted by [render]
    // and the tap-Morse composer.
    if (pattern.contains(wordSeparator)) {
      return _decodeWithWordSeparator(pattern, wordSeparator);
    }
    // Robustness fallbacks for non-canonical inputs encountered in
    // copy/paste, legacy `   ` (3-space) renders, or `/`-style Morse
    // notation common in print.
    if (pattern.contains(' / ')) {
      return _decodeWithWordSeparator(pattern, ' / ');
    }
    if (RegExp(r' {2,}').hasMatch(pattern)) {
      // Collapse any 2+ space run to the canonical separator and
      // route through the same path.
      return _decodeWithWordSeparator(
        pattern.replaceAll(RegExp(r' {2,}'), wordSeparator),
        wordSeparator,
      );
    }
    if (pattern.contains(' ')) {
      return _decodeLetterOnly(pattern);
    }
    return _decodeGreedy(pattern);
  }

  static String _decodeWithWordSeparator(String pattern, String wordSep) {
    final words = pattern.split(wordSep);
    final out = StringBuffer();
    for (var w = 0; w < words.length; w += 1) {
      if (w > 0) out.write(' ');
      final word = words[w].trim();
      if (word.isEmpty) continue;
      for (final token in word.split(' ')) {
        if (token.isEmpty) continue;
        out.write(letterForToken(token) ?? '?');
      }
    }
    return out.toString();
  }

  static String _decodeLetterOnly(String pattern) {
    final out = StringBuffer();
    for (final token in pattern.split(' ')) {
      if (token.isEmpty) continue;
      out.write(letterForToken(token) ?? '?');
    }
    return out.toString();
  }

  static String _decodeGreedy(String pattern) {
    // Longest Morse code in the table is 6 symbols (punctuation).
    const maxTokenLen = 6;
    final out = StringBuffer();
    var rest = pattern;
    while (rest.isNotEmpty) {
      final cap = rest.length < maxTokenLen ? rest.length : maxTokenLen;
      String? hit;
      var hitLen = 0;
      for (var len = cap; len >= 1; len -= 1) {
        final prefix = rest.substring(0, len);
        final letter = letterForToken(prefix);
        if (letter != null) {
          hit = letter;
          hitLen = len;
          break;
        }
      }
      if (hit == null) {
        // No prefix matches at the current head — skip one symbol so
        // we don't loop forever on garbage. Surface the failure in UI
        // via the `?` placeholder.
        out.write('?');
        rest = rest.substring(1);
      } else {
        out.write(hit);
        rest = rest.substring(hitLen);
      }
    }
    return out.toString();
  }
}

/// One step in the timed Morse playback sequence emitted by
/// [morseTimingForText] — used by the synth to build a
/// gap/tone-on/tone-off schedule for one `text` at one WPM.
enum MorseStepKind {
  /// Tone-on for `units` units (1 = dot, 3 = dash).
  tone,

  /// Silence between units / letters / words.
  gap,
}

class MorseStep {
  final MorseStepKind kind;
  final int units;
  const MorseStep(this.kind, this.units);
}

/// Build a unit-timed schedule of tones + gaps for [text].
/// Standard timing:
///   - dot = 1 unit on
///   - dash = 3 units on
///   - intra-character gap = 1 unit
///   - inter-character gap = 3 units
///   - inter-word gap = 7 units
///
/// Unsupported characters are skipped (caller should validate via
/// [MorseTable.isEncodable] first — encoder enforces this).
List<MorseStep> morseTimingForText(String text) {
  final out = <MorseStep>[];
  final upper = text.toUpperCase();
  final words = upper.split(' ');

  for (var w = 0; w < words.length; w += 1) {
    if (w > 0) {
      // Inter-word gap.
      out.add(const MorseStep(MorseStepKind.gap, 7));
    }
    final word = words[w];
    final chars = word.split('');
    for (var c = 0; c < chars.length; c += 1) {
      if (c > 0) {
        // Inter-character gap.
        out.add(const MorseStep(MorseStepKind.gap, 3));
      }
      final code = MorseTable.charToCode[chars[c]];
      if (code == null) continue;
      for (var i = 0; i < code.length; i += 1) {
        if (i > 0) {
          // Intra-character gap.
          out.add(const MorseStep(MorseStepKind.gap, 1));
        }
        final symbol = code[i];
        out.add(MorseStep(MorseStepKind.tone, symbol == '-' ? 3 : 1));
      }
    }
  }

  return out;
}
