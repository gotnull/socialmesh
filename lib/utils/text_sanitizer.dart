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

/// Whether [codePoint] is a Unicode scalar value safe to render as text.
///
/// Returns false for UTF-16 surrogate halves (0xD800-0xDFFF) and for values
/// outside the Unicode range (negative or above U+10FFFF). Passing such a
/// value to [String.fromCharCodes] yields a malformed UTF-16 string, and
/// Flutter's native paragraph builder then throws a fatal "string is not
/// well-formed UTF-16" during layout. Untrusted single-scalar fields (e.g. a
/// mesh waypoint's `icon`) must be checked with this before being rendered.
bool isValidUnicodeScalar(int codePoint) {
  if (codePoint < 0 || codePoint > 0x10FFFF) return false;
  if (_isHighSurrogate(codePoint) || _isLowSurrogate(codePoint)) return false;
  return true;
}

/// Full sanitization for external/untrusted text before UI rendering.
///
/// Repairs unpaired UTF-16 surrogates and removes null bytes and
/// control characters that crash Flutter's native paragraph builder on iOS.
/// Safe characters (tab, newline, carriage return) are preserved. Normal emoji,
/// multilingual text, and combining characters pass through unchanged.
String sanitizeExternalText(String input) =>
    sanitizeExternalTextWithStats(input).text;

/// Counts of the sanitization repairs performed on a single input string.
///
/// Used by receive paths to emit privacy-safe diagnostic logs (no payload
/// content, just the shape of the repair) when a sanitized result ends up
/// empty and the wire packet is therefore dropped.
class SanitizationStats {
  /// C0/C1 control characters stripped (null, 0x01-0x08, 0x0B-0x0C, 0x0E-0x1F,
  /// DEL, 0x80-0x9F). Tab / LF / CR are not counted as they are preserved.
  final int controlsStripped;

  /// Orphan UTF-16 surrogate halves replaced with U+FFFD.
  final int surrogateRepairs;

  const SanitizationStats({
    required this.controlsStripped,
    required this.surrogateRepairs,
  });

  bool get hadAnyRepair => controlsStripped > 0 || surrogateRepairs > 0;
}

/// Result of [sanitizeExternalTextWithStats]: the sanitized string plus the
/// counts of repairs performed on the way.
class SanitizedTextResult {
  final String text;
  final SanitizationStats stats;

  const SanitizedTextResult({required this.text, required this.stats});
}

/// Same behaviour as [sanitizeExternalText] but also reports repair counts.
///
/// Prefer the plain [sanitizeExternalText] when stats aren't needed. Receive
/// paths use this overload so they can emit a `reason=sanitized_empty
/// ctrl=\u2026 surrogate_repairs=\u2026` diagnostic when a packet's payload sanitises
/// to an empty body and gets dropped.
SanitizedTextResult sanitizeExternalTextWithStats(String input) {
  if (input.isEmpty) {
    return const SanitizedTextResult(
      text: '',
      stats: SanitizationStats(controlsStripped: 0, surrogateRepairs: 0),
    );
  }

  final codeUnits = input.codeUnits;
  var controlsStripped = 0;
  var surrogateRepairs = 0;
  final buffer = StringBuffer();

  for (var i = 0; i < codeUnits.length; i++) {
    final unit = codeUnits[i];

    if (_isUnsafeControl(unit)) {
      controlsStripped++;
      continue;
    }

    if (_isHighSurrogate(unit)) {
      if (i + 1 < codeUnits.length && _isLowSurrogate(codeUnits[i + 1])) {
        buffer.writeCharCode(unit);
        buffer.writeCharCode(codeUnits[i + 1]);
        i++;
      } else {
        surrogateRepairs++;
        buffer.write('\uFFFD');
      }
      continue;
    }
    if (_isLowSurrogate(unit)) {
      surrogateRepairs++;
      buffer.write('\uFFFD');
      continue;
    }

    buffer.writeCharCode(unit);
  }

  final hadInvalid = controlsStripped > 0 || surrogateRepairs > 0;
  return SanitizedTextResult(
    text: hadInvalid ? buffer.toString() : input,
    stats: SanitizationStats(
      controlsStripped: controlsStripped,
      surrogateRepairs: surrogateRepairs,
    ),
  );
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

/// Render-boundary safe avatar/marker initials from an untrusted name.
///
/// Sanitizes [input] first (repairing unpaired UTF-16 surrogates and stripping
/// control characters that crash Flutter's paragraph builder), then takes at
/// most [count] grapheme clusters and uppercases the result. Returns an empty
/// string when [input] is null, empty, or sanitizes to nothing — callers can
/// fall back to a placeholder rather than rendering malformed text.
///
/// Use this at every place that derives avatar/marker initials from a peer- or
/// cloud-controlled name (e.g. `node.shortName`). Plain truncation helpers
/// ([safeTruncate], `.characters.first`) do NOT strip surrogates, so a lone
/// surrogate in the source still reaches the paragraph builder and throws.
String safeInitials(String? input, int count) {
  if (input == null || input.isEmpty || count <= 0) return '';
  final sanitized = sanitizeExternalText(input);
  if (sanitized.isEmpty) return '';
  return sanitized.characters.take(count).string.toUpperCase();
}
