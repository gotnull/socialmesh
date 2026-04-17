// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/models/terminal_preset.dart';

void main() {
  group('TerminalPreset.fromId', () {
    test('maps each known id to the right preset', () {
      expect(TerminalPreset.fromId('classic_green'), TerminalPreset.classicGreen);
      expect(TerminalPreset.fromId('amber_terminal'), TerminalPreset.amberTerminal);
      expect(TerminalPreset.fromId('cyber_blue'), TerminalPreset.cyberBlue);
      expect(TerminalPreset.fromId('wasteland'), TerminalPreset.wasteland);
      expect(TerminalPreset.fromId('fire_ansi'), TerminalPreset.fireAnsi);
    });

    test('defaults to classicGreen for unknown / null id', () {
      expect(TerminalPreset.fromId(null), TerminalPreset.classicGreen);
      expect(TerminalPreset.fromId(''), TerminalPreset.classicGreen);
      expect(TerminalPreset.fromId('garbage'), TerminalPreset.classicGreen);
    });

    test('id round-trips for every preset', () {
      for (final p in TerminalPreset.values) {
        expect(TerminalPreset.fromId(p.id), p);
      }
    });
  });

  group('display + prompt', () {
    test('every preset has a non-empty displayName', () {
      for (final p in TerminalPreset.values) {
        expect(p.displayName.isNotEmpty, true);
      }
    });

    test('every preset has a single-character promptGlyph', () {
      for (final p in TerminalPreset.values) {
        expect(p.promptGlyph.isNotEmpty, true);
        expect(p.promptGlyph.length, 1);
      }
    });

    test('cyberBlue uses a shell-style prompt', () {
      expect(TerminalPreset.cyberBlue.promptGlyph, r'$');
    });

    test('wasteland uses a root-style prompt', () {
      expect(TerminalPreset.wasteland.promptGlyph, '#');
    });
  });
}
