// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_enums.dart';
import 'package:socialmesh/features/nodeboard/services/terminal_command_parser.dart';

void main() {
  group('parseTerminalCommand', () {
    test('HELP returns help command', () {
      expect(parseTerminalCommand('HELP').command, TerminalCommand.help);
      expect(parseTerminalCommand('help').command, TerminalCommand.help);
      expect(parseTerminalCommand('?').command, TerminalCommand.help);
    });

    test('LIST returns list command', () {
      expect(parseTerminalCommand('LIST').command, TerminalCommand.list);
      expect(parseTerminalCommand('ls').command, TerminalCommand.list);
      expect(parseTerminalCommand('DIR').command, TerminalCommand.list);
    });

    test('OPEN parses number argument', () {
      final parsed = parseTerminalCommand('OPEN 3');
      expect(parsed.command, TerminalCommand.open);
      expect(parsed.args, ['3']);
    });

    test('OPEN with text argument', () {
      final parsed = parseTerminalCommand('OPEN general');
      expect(parsed.command, TerminalCommand.open);
      expect(parsed.args, ['general']);
    });

    test('POST returns post command', () {
      expect(parseTerminalCommand('POST').command, TerminalCommand.post);
      expect(parseTerminalCommand('NEW').command, TerminalCommand.post);
      expect(parseTerminalCommand('WRITE').command, TerminalCommand.post);
    });

    test('REPLY returns reply command', () {
      expect(parseTerminalCommand('REPLY').command, TerminalCommand.reply);
      expect(parseTerminalCommand('RE').command, TerminalCommand.reply);
    });

    test('BACK returns back command', () {
      expect(parseTerminalCommand('BACK').command, TerminalCommand.back);
      expect(parseTerminalCommand('B').command, TerminalCommand.back);
      expect(parseTerminalCommand('..').command, TerminalCommand.back);
    });

    test('SECTIONS returns sections command', () {
      expect(
        parseTerminalCommand('SECTIONS').command,
        TerminalCommand.sections,
      );
      expect(parseTerminalCommand('SEC').command, TerminalCommand.sections);
    });

    test('ABOUT returns about command', () {
      expect(parseTerminalCommand('ABOUT').command, TerminalCommand.about);
      expect(parseTerminalCommand('INFO').command, TerminalCommand.about);
    });

    test('GUESTBOOK returns guestbook command', () {
      expect(
        parseTerminalCommand('GUESTBOOK').command,
        TerminalCommand.guestbook,
      );
      expect(parseTerminalCommand('GB').command, TerminalCommand.guestbook);
    });

    test('QUIT returns quit command', () {
      expect(parseTerminalCommand('QUIT').command, TerminalCommand.quit);
      expect(parseTerminalCommand('EXIT').command, TerminalCommand.quit);
      expect(parseTerminalCommand('Q').command, TerminalCommand.quit);
    });

    test('unknown command returns unknown', () {
      final parsed = parseTerminalCommand('FOOBAR');
      expect(parsed.command, TerminalCommand.unknown);
      expect(parsed.args, ['FOOBAR']);
    });

    test('empty string returns unknown', () {
      expect(parseTerminalCommand('').command, TerminalCommand.unknown);
      expect(parseTerminalCommand('   ').command, TerminalCommand.unknown);
    });

    test('case insensitive', () {
      expect(parseTerminalCommand('help').command, TerminalCommand.help);
      expect(parseTerminalCommand('HELP').command, TerminalCommand.help);
      expect(parseTerminalCommand('Help').command, TerminalCommand.help);
    });

    test('extra whitespace handled', () {
      final parsed = parseTerminalCommand('  OPEN   5  ');
      expect(parsed.command, TerminalCommand.open);
      expect(parsed.args, ['5']);
    });

    test('ParsedCommand equality', () {
      const a = ParsedCommand(TerminalCommand.open, ['3']);
      const b = ParsedCommand(TerminalCommand.open, ['3']);
      const c = ParsedCommand(TerminalCommand.open, ['4']);
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
