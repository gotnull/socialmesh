// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:characters/characters.dart';

/// Grapheme-aware text measurement and safe truncation utilities.
///
/// Standard [String.length] counts UTF-16 code units, which means emoji like
/// 👨‍👩‍👧‍👦 (family) can report length 11 despite being a single visible
/// character. These utilities use [Characters] (grapheme clusters) so that
/// limits and truncations always align with what users see on screen.

/// Count the number of visible grapheme clusters in [text].
int graphemeLength(String text) => text.characters.length;

/// Return the number of bytes [text] occupies when encoded as UTF-8.
///
/// This is the metric that matters for payload-size constraints like the
/// APNs 4 096-byte limit.
int utf8ByteLength(String text) => utf8.encode(text).length;

/// Truncate [text] to at most [maxGraphemes] visible grapheme clusters.
///
/// If truncation occurs, [suffix] (default "…") is appended. The final
/// grapheme length will be at most `maxGraphemes` (suffix included).
///
/// The function never splits a grapheme cluster, so emoji and combined
/// glyphs remain intact.
///
/// If [maxGraphemes] is less than the suffix length the suffix itself is
/// returned truncated to [maxGraphemes].
String safeTruncateGraphemes(
  String text,
  int maxGraphemes, {
  String suffix = '…',
}) {
  final chars = text.characters;
  if (chars.length <= maxGraphemes) return text;

  final suffixChars = suffix.characters;
  if (maxGraphemes <= suffixChars.length) {
    return suffixChars.take(maxGraphemes).string;
  }

  final keepCount = maxGraphemes - suffixChars.length;
  return '${chars.take(keepCount).string}$suffix';
}

/// Truncate [text] so that its UTF-8 byte representation does not exceed
/// [maxBytes]. The [suffix] is appended when truncation occurs and its byte
/// cost is included in the budget.
///
/// Grapheme-cluster boundaries are respected: the function removes whole
/// grapheme clusters from the end until the result fits.
String safeTruncateBytes(String text, int maxBytes, {String suffix = '…'}) {
  if (utf8ByteLength(text) <= maxBytes) return text;

  final suffixBytes = utf8ByteLength(suffix);
  if (maxBytes <= suffixBytes) {
    // Edge case: not even the suffix fits. Return what we can.
    final chars = suffix.characters;
    var result = '';
    for (final ch in chars) {
      final candidate = result + ch;
      if (utf8ByteLength(candidate) > maxBytes) break;
      result = candidate;
    }
    return result;
  }

  final budget = maxBytes - suffixBytes;
  final chars = text.characters;
  var result = '';
  for (final ch in chars) {
    final candidate = result + ch;
    if (utf8ByteLength(candidate) > budget) break;
    result = candidate;
  }
  return '$result$suffix';
}

/// Truncate [text] at a word boundary if possible, falling back to a
/// grapheme-cluster boundary otherwise.
///
/// Prefers breaking at the last space before [maxGraphemes]. If no suitable
/// space is found in the second half of the allowed range, falls back to
/// [safeTruncateGraphemes].
String safeTruncateAtWord(
  String text,
  int maxGraphemes, {
  String suffix = '…',
}) {
  final chars = text.characters;
  if (chars.length <= maxGraphemes) return text;

  final suffixLen = suffix.characters.length;
  if (maxGraphemes <= suffixLen) {
    return safeTruncateGraphemes(text, maxGraphemes, suffix: suffix);
  }

  final keepCount = maxGraphemes - suffixLen;
  final prefix = chars.take(keepCount).string;

  // Try to find a word boundary (space) in the second half
  final halfPoint = prefix.length ~/ 2;
  final lastSpace = prefix.lastIndexOf(' ');

  if (lastSpace > halfPoint) {
    return '${prefix.substring(0, lastSpace)}$suffix';
  }

  // No good word boundary - hard cut at grapheme boundary
  return '$prefix$suffix';
}
