// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Lightweight preset identifier for NodeBoard terminal mode.
//
// The terminal is rendered in Socialmesh's standard premium theme
// (GlassScaffold, context.accentColor, context.card, etc.) — there is
// no per-preset palette overriding the app theme. A preset is kept
// only to drive optional retro flourishes: the prompt glyph and an
// ASCII header template supplied by the backend.

enum TerminalPreset {
  classicGreen,
  amberTerminal,
  cyberBlue,
  wasteland,
  fireAnsi;

  static TerminalPreset fromId(String? id) => switch (id) {
    'classic_green' => TerminalPreset.classicGreen,
    'amber_terminal' => TerminalPreset.amberTerminal,
    'cyber_blue' => TerminalPreset.cyberBlue,
    'wasteland' => TerminalPreset.wasteland,
    'fire_ansi' => TerminalPreset.fireAnsi,
    _ => TerminalPreset.classicGreen,
  };

  String get id => switch (this) {
    TerminalPreset.classicGreen => 'classic_green',
    TerminalPreset.amberTerminal => 'amber_terminal',
    TerminalPreset.cyberBlue => 'cyber_blue',
    TerminalPreset.wasteland => 'wasteland',
    TerminalPreset.fireAnsi => 'fire_ansi',
  };

  String get displayName => switch (this) {
    TerminalPreset.classicGreen => 'Classic Green',
    TerminalPreset.amberTerminal => 'Amber Terminal',
    TerminalPreset.cyberBlue => 'Cyber Blue',
    TerminalPreset.wasteland => 'Wasteland',
    TerminalPreset.fireAnsi => 'Fire ANSI',
  };

  /// The prompt glyph used in terminal output lines and the command
  /// input prefix. Kept modest (one character) so Socialmesh accent
  /// colours drive visual identity, not giant retro characters.
  String get promptGlyph => switch (this) {
    TerminalPreset.classicGreen => '>',
    TerminalPreset.amberTerminal => '>',
    TerminalPreset.cyberBlue => r'$',
    TerminalPreset.wasteland => '#',
    TerminalPreset.fireAnsi => '>',
  };
}
