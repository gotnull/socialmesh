// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// lint-allow: hardcoded-color — this file IS the palette source of
// truth. The 64 Color() literals below are not decorative chrome that
// should route through AppTheme / AccentColors; they are the wire-
// format palette identified by `palette_id = 1` in CANVAS_V0_1.md §11.
// Mutating any of them is a spec break, not a styling change.

// Canonical SocialMesh canvas palette for MeshCanvas v0.1.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §11 "Palette" and §S0.ux.15.
// 64 entries indexed 0..63. Index 0 is the "default / unpainted"
// sentinel — receivers render it as fully transparent so the screen
// background shows through. Indices 1..63 are 63 curated colours.
//
// Changing any of these values is a spec break: the wire format
// allocates 6 bits for the palette index (top 2 bits reserved), and
// the canonical state encoding (§7) hashes the index byte directly.
// Future palette families add a new `palette_id` rather than mutating
// `palette_id = 1`.
//
// S7 status: the palette is canonical and consumed by the viewer.
// Per S7.A scope, only the first 8 colours are surfaced via the
// bottom strip; the full 64-entry sheet lands in S7.B.
library;

import 'package:flutter/material.dart';

abstract final class SocialMeshPalette {
  /// Identifier emitted in `canvas_info` responses. v0.1 receivers
  /// MUST reject any inbound op carrying a different palette_id (spec
  /// invariant I4).
  static const int paletteId = 1;

  /// Index used by the codec to mean "unpainted / default colour".
  /// Renders as fully transparent.
  static const int defaultIndex = 0;

  /// Inclusive upper bound for the low 6 bits of the colour byte.
  static const int maxIndex = 63;

  /// 64 colours. Index 0 is transparent (the rendering sentinel);
  /// 1..63 are curated palette entries grouped by hue family for
  /// quick mental access in the future full palette sheet.
  static const List<Color> colors = <Color>[
    // 0..0 — sentinel
    Color(0x00000000), // 0 transparent / unpainted
    // 1..8 — neutrals + black/white spine
    Color(0xFFFFFFFF), // 1 white
    Color(0xFFE5E7EB), // 2 fog
    Color(0xFFD1D5DB), // 3 light grey
    Color(0xFF9CA3AF), // 4 grey
    Color(0xFF6B7280), // 5 slate
    Color(0xFF374151), // 6 dark slate
    Color(0xFF1F2937), // 7 graphite
    Color(0xFF000000), // 8 black
    // 9..15 — reds
    Color(0xFFFFC1B4), // 9 blush
    Color(0xFFFF7373), // 10 coral
    Color(0xFFFF4D4D), // 11 red
    Color(0xFFE11D48), // 12 crimson
    Color(0xFFB91C1C), // 13 brick
    Color(0xFF7F1D1D), // 14 maroon
    Color(0xFF4C0519), // 15 oxblood
    // 16..22 — oranges + browns
    Color(0xFFFFD7B5), // 16 peach
    Color(0xFFFFAA66), // 17 apricot
    Color(0xFFFF8A1F), // 18 orange
    Color(0xFFEA580C), // 19 burnt orange
    Color(0xFFB45309), // 20 amber-bark
    Color(0xFF7C2D12), // 21 chestnut
    Color(0xFF44260B), // 22 espresso
    // 23..29 — yellows + olives
    Color(0xFFFFF3B0), // 23 vanilla
    Color(0xFFFFE066), // 24 cream
    Color(0xFFFACC15), // 25 yellow
    Color(0xFFEAB308), // 26 gold
    Color(0xFFA16207), // 27 mustard
    Color(0xFF65A30D), // 28 olive
    Color(0xFF3F6212), // 29 deep olive
    // 30..36 — greens
    Color(0xFFBBF7D0), // 30 mint
    Color(0xFF86EFAC), // 31 spring
    Color(0xFF22C55E), // 32 green
    Color(0xFF16A34A), // 33 emerald
    Color(0xFF15803D), // 34 forest
    Color(0xFF166534), // 35 pine
    Color(0xFF14532D), // 36 deep forest
    // 37..43 — teals + cyans
    Color(0xFFA5F3FC), // 37 ice
    Color(0xFF67E8F9), // 38 sky
    Color(0xFF06B6D4), // 39 cyan
    Color(0xFF0891B2), // 40 teal
    Color(0xFF0E7490), // 41 deep teal
    Color(0xFF155E75), // 42 lagoon
    Color(0xFF164E63), // 43 trench
    // 44..50 — blues
    Color(0xFFBFDBFE), // 44 powder
    Color(0xFF93C5FD), // 45 sky blue
    Color(0xFF60A5FA), // 46 azure
    Color(0xFF3B82F6), // 47 blue
    Color(0xFF1D4ED8), // 48 royal
    Color(0xFF1E3A8A), // 49 navy
    Color(0xFF172554), // 50 midnight
    // 51..57 — violets + magentas
    Color(0xFFDDD6FE), // 51 lilac
    Color(0xFFA78BFA), // 52 lavender
    Color(0xFF8B5CF6), // 53 purple
    Color(0xFF6D28D9), // 54 indigo
    Color(0xFF4C1D95), // 55 deep violet
    Color(0xFFD946EF), // 56 magenta
    Color(0xFFA21CAF), // 57 plum
    // 58..63 — pinks + bright accents (the "graffiti" tail)
    Color(0xFFFBCFE8), // 58 rose
    Color(0xFFF472B6), // 59 hot pink
    Color(0xFFEC4899), // 60 pink
    Color(0xFF00FF87), // 61 fluoro green
    Color(0xFFFF005C), // 62 fluoro pink
    Color(0xFFFFD700), // 63 gold accent
  ];

  /// Human-readable names parallel to [colors]. Brand-style English
  /// for v0.1; locale variants land via ARB if/when we expose them.
  static const List<String> names = <String>[
    'Transparent',
    'White',
    'Fog',
    'Light grey',
    'Grey',
    'Slate',
    'Dark slate',
    'Graphite',
    'Black',
    'Blush',
    'Coral',
    'Red',
    'Crimson',
    'Brick',
    'Maroon',
    'Oxblood',
    'Peach',
    'Apricot',
    'Orange',
    'Burnt orange',
    'Amber bark',
    'Chestnut',
    'Espresso',
    'Vanilla',
    'Cream',
    'Yellow',
    'Gold',
    'Mustard',
    'Olive',
    'Deep olive',
    'Mint',
    'Spring',
    'Green',
    'Emerald',
    'Forest',
    'Pine',
    'Deep forest',
    'Ice',
    'Sky',
    'Cyan',
    'Teal',
    'Deep teal',
    'Lagoon',
    'Trench',
    'Powder',
    'Sky blue',
    'Azure',
    'Blue',
    'Royal',
    'Navy',
    'Midnight',
    'Lilac',
    'Lavender',
    'Purple',
    'Indigo',
    'Deep violet',
    'Magenta',
    'Plum',
    'Rose',
    'Hot pink',
    'Pink',
    'Fluoro green',
    'Fluoro pink',
    'Gold accent',
  ];

  /// Quick-access indices surfaced in the S7.A bottom strip. The full
  /// 64-colour sheet lands in S7.B. Index 0 (transparent) is included
  /// so users can erase pixels by tapping the swatch labelled "Erase"
  /// at the leftmost slot.
  static const List<int> quickStripIndices = <int>[
    0, // transparent (erase)
    8, // black
    1, // white
    11, // red
    18, // orange
    25, // yellow
    32, // green
    47, // blue
  ];

  /// Look up a colour by palette index. Returns [Colors.transparent]
  /// for out-of-range values rather than throwing — the renderer must
  /// remain crash-safe under any cell row from the wire.
  static Color colorOf(int index) {
    if (index < 0 || index >= colors.length) return const Color(0x00000000);
    return colors[index];
  }

  /// Look up a colour name by palette index. Out-of-range falls back
  /// to `"?"` so the inspector sheet never throws.
  static String nameOf(int index) {
    if (index < 0 || index >= names.length) return '?';
    return names[index];
  }
}
