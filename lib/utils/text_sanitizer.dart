// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:characters/characters.dart';

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

/// Whether [codeUnit] is a C0/C1 control character unsafe for text rendering.
///
/// Keeps tab (0x09), newline (0x0A), and carriage return (0x0D) which are
/// safe in Flutter paragraph layout. Strips null (0x00), other C0 controls
/// (0x01-0x08, 0x0B-0x0C, 0x0E-0x1F), DEL (0x7F), and C1 controls
/// (0x80-0x9F) which can crash iOS paragraph building.
bool _isUnsafeControl(int codeUnit) {
  if (codeUnit == 0x00) return true;
  if (codeUnit >= 0x01 && codeUnit <= 0x08) return true;
  if (codeUnit == 0x0B || codeUnit == 0x0C) return true;
  if (codeUnit >= 0x0E && codeUnit <= 0x1F) return true;
  if (codeUnit == 0x7F) return true;
  if (codeUnit >= 0x80 && codeUnit <= 0x9F) return true;
  return false;
}

/// Full sanitization for external/untrusted text before UI rendering.
///
/// Repairs unpaired UTF-16 surrogates and removes null bytes and
/// control characters that crash Flutter's native paragraph builder on iOS.
/// Safe characters (tab, newline, carriage return) are preserved. Normal emoji,
/// multilingual text, and combining characters pass through unchanged.
String sanitizeExternalText(String input) {
  if (input.isEmpty) return input;

  final codeUnits = input.codeUnits;
  var hadInvalid = false;
  final buffer = StringBuffer();

  for (var i = 0; i < codeUnits.length; i++) {
    final unit = codeUnits[i];

    // Strip unsafe control characters.
    if (_isUnsafeControl(unit)) {
      hadInvalid = true;
      continue;
    }

    // Fix unpaired surrogates.
    if (_isHighSurrogate(unit)) {
      if (i + 1 < codeUnits.length && _isLowSurrogate(codeUnits[i + 1])) {
        buffer.writeCharCode(unit);
        buffer.writeCharCode(codeUnits[i + 1]);
        i++;
      } else {
        hadInvalid = true;
        buffer.write('\uFFFD');
      }
      continue;
    }
    if (_isLowSurrogate(unit)) {
      hadInvalid = true;
      buffer.write('\uFFFD');
      continue;
    }

    buffer.writeCharCode(unit);
  }

  return hadInvalid ? buffer.toString() : input;
}

/// Code-unit truncation that avoids splitting UTF-16 surrogate pairs.
///
/// Truncates [input] to at most [maxCodeUnits] code units. If the cut would
/// land between a high and low surrogate, backs off by one to keep the pair
/// intact. Use this at data boundaries where the length constraint is in
/// code units, not visible characters.
String safeTruncateCodeUnits(String input, int maxCodeUnits) {
  if (input.length <= maxCodeUnits) return input;
  if (maxCodeUnits <= 0) return '';
  final truncated = input.substring(0, maxCodeUnits);
  if (_isHighSurrogate(truncated.codeUnits.last)) {
    return truncated.substring(0, maxCodeUnits - 1);
  }
  return truncated;
}

/// Grapheme-safe truncation that never splits emoji or combining characters.
///
/// Returns at most [maxLength] visible grapheme clusters from [input].
/// No suffix is appended — use this at data boundaries where the exact
/// length constraint matters (e.g., protocol field size limits).
String safeTruncate(String input, int maxLength) {
  if (input.isEmpty || maxLength <= 0) return '';
  final chars = input.characters;
  if (chars.length <= maxLength) return input;
  return chars.take(maxLength).string;
}

/// Grapheme-safe substring that never splits emoji or combining characters.
///
/// Returns at most [maxLength] visible grapheme clusters from [input],
/// appending '…' if truncation occurred. Uses [Characters] from
/// `package:characters` to respect grapheme cluster boundaries.
/// Use this for UI display where the ellipsis signals truncation to the user.
String safeSubstring(String input, int maxLength) {
  if (input.isEmpty || maxLength <= 0) return '';
  final chars = input.characters;
  if (chars.length <= maxLength) return input;
  return '${chars.take(maxLength).string}…';
}
