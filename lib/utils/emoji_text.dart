// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:characters/characters.dart';

// Emoji-only detection for chat-body rendering ("jumbomoji") and translation
// gating. Pure text logic, shared across both protocols — no Flutter, no theme.
//
// Single source of truth for which runes count as emoji. Keep the range table
// in this file only so emoji knowledge does not fragment across the codebase.

// Inclusive code-point ranges that count as part of an emoji presentation.
// Covers the emoji symbol blocks plus the modifiers that only appear inside
// emoji grapheme clusters: ZWJ (U+200D) joins sequences (👨‍👩‍👧‍👦), variation
// selectors (U+FE00-FE0F) force emoji presentation, the keycap combiner
// (U+20E3) builds 1️⃣, skin-tone modifiers (U+1F3FB-1F3FF) tint 👍🏽, regional
// indicators (U+1F1E6-1F1FF) pair into flags (🇩🇪), and tag characters
// (U+E0020-E007F) build subdivision flags.
const List<(int, int)> _emojiRuneRanges = [
  (0x200D, 0x200D), // ZWJ
  (0x20E3, 0x20E3), // combining enclosing keycap
  (0xFE00, 0xFE0F), // variation selectors
  (0xE0020, 0xE007F), // tag characters
  (0x2600, 0x26FF), // Misc Symbols
  (0x2700, 0x27BF), // Dingbats
  (0x1F1E6, 0x1F1FF), // Regional Indicators
  (0x1F300, 0x1F5FF), // Misc Symbols & Pictographs
  (0x1F600, 0x1F64F), // Emoticons
  (0x1F680, 0x1F6FF), // Transport & Map
  (0x1F3FB, 0x1F3FF), // Skin-tone modifiers
  (0x1F900, 0x1F9FF), // Supplemental Symbols & Pictographs
  (0x1FA00, 0x1FA6F), // Symbols & Pictographs Extended-A
  (0x1FA70, 0x1FAFF), // Symbols & Pictographs Extended-B
];

// Whether [rune] falls inside any emoji range.
bool _isEmojiRune(int rune) {
  for (final (lo, hi) in _emojiRuneRanges) {
    if (rune >= lo && rune <= hi) return true;
  }
  return false;
}

// Whether the grapheme [cluster] is an emoji. Conservative: every rune must be
// an emoji rune, so mixed clusters (e.g. a letter with a stray selector) are
// not treated as emoji and real text is never enlarged. Keycap sequences
// (1️⃣, #️⃣) are the one exception — their base is an ASCII digit / # / *, so
// they fail the all-runes check, but the keycap combiner U+20E3 occurs only in
// emoji and is enough to identify them.
bool _isEmojiCluster(String cluster) {
  final runes = cluster.runes;
  if (runes.isEmpty) return false;
  if (runes.contains(0x20E3)) return true; // keycap sequence
  return runes.every(_isEmojiRune);
}

/// Number of emoji in [text] if it is composed ENTIRELY of emoji (ignoring
/// whitespace between/around them); 0 otherwise (any non-emoji char, or empty).
///
/// Counts grapheme clusters, so ZWJ sequences (👨‍👩‍👧‍👦), flags (🇩🇪), keycaps
/// (1️⃣) and skin-tone modifiers (👍🏽) each count as one. Used to size emoji-only
/// chat bubbles (jumbomoji) and to gate translation of emoji-only messages.
int emojiOnlyCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  var count = 0;
  for (final cluster in trimmed.characters) {
    if (cluster.trim().isEmpty) continue; // whitespace between emoji
    if (!_isEmojiCluster(cluster)) return 0; // any non-emoji → not emoji-only
    count++;
  }
  return count;
}

/// Whether [text] renders as emoji only (no textual content).
bool isEmojiOnly(String text) => emojiOnlyCount(text) > 0;
