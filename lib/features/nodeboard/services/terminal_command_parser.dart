// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Parses terminal input strings into TerminalCommand + arguments.
// Pure function — no side effects, easily testable.

import '../models/nodeboard_enums.dart';

class ParsedCommand {
  final TerminalCommand command;
  final List<String> args;

  const ParsedCommand(this.command, [this.args = const []]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedCommand &&
          command == other.command &&
          _listEquals(args, other.args);

  @override
  int get hashCode => Object.hash(command, Object.hashAll(args));

  @override
  String toString() => 'ParsedCommand($command, $args)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

ParsedCommand parseTerminalCommand(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const ParsedCommand(TerminalCommand.unknown);

  final parts = trimmed.split(RegExp(r'\s+'));
  final cmd = parts[0].toUpperCase();
  final args = parts.length > 1 ? parts.sublist(1) : <String>[];

  return switch (cmd) {
    'HELP' || '?' => const ParsedCommand(TerminalCommand.help),
    'LIST' || 'LS' || 'DIR' => ParsedCommand(TerminalCommand.list, args),
    'OPEN' || 'READ' || 'VIEW' => ParsedCommand(TerminalCommand.open, args),
    'POST' || 'NEW' || 'WRITE' => ParsedCommand(TerminalCommand.post, args),
    'REPLY' || 'RE' => ParsedCommand(TerminalCommand.reply, args),
    'BACK' || 'B' || '..' => const ParsedCommand(TerminalCommand.back),
    'SECTIONS' || 'SEC' => const ParsedCommand(TerminalCommand.sections),
    'ABOUT' || 'INFO' => const ParsedCommand(TerminalCommand.about),
    'GUESTBOOK' || 'GB' => const ParsedCommand(TerminalCommand.guestbook),
    'QUIT' || 'EXIT' || 'Q' => const ParsedCommand(TerminalCommand.quit),
    _ => ParsedCommand(TerminalCommand.unknown, [trimmed]),
  };
}
