// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Terminal hybrid-UX architecture tests.
//
// The notifier never uses error fields as control channels: every
// command resolution either mutates state via explicit methods or
// returns a typed [TerminalEffect] variant. These tests pin that
// architecture and the unified dispatch path (chip tap / typed input /
// tappable output all converge on the same execution behavior).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_enums.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_reply.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_section.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_thread.dart';
import 'package:socialmesh/features/nodeboard/providers/nodeboard_providers.dart';
import 'package:socialmesh/features/nodeboard/services/terminal_command_parser.dart';

NodeBoardSection _section(String id, String key, String title) {
  return NodeBoardSection(
    id: id,
    nodeBoardId: 'b1',
    key: key,
    title: title,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

NodeBoardThread _thread(String id, String title) {
  return NodeBoardThread(
    id: id,
    nodeBoardId: 'b1',
    sectionId: 's1',
    authorDisplayName: 'Tester',
    title: title,
    body: 'hello',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TerminalEffect _dispatch(TerminalStateNotifier notifier, String input) {
  return notifier.executeCommand(parseTerminalCommand(input));
}

void main() {
  late ProviderContainer container;
  late TerminalStateNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(terminalStateProvider.notifier);
  });

  tearDown(() => container.dispose());

  // ========================================================================
  // Initial state
  // ========================================================================

  group('Initial state', () {
    test('boardHome screen + root chips on first build', () {
      final state = container.read(terminalStateProvider);
      expect(state.currentScreen, TerminalScreen.boardHome);
      expect(state.outputBuffer, isEmpty);
      expect(state.chips.map((c) => c.command).toList(), [
        'SECTIONS',
        'GUESTBOOK',
        'ABOUT',
        'HELP',
        'QUIT',
      ]);
    });
  });

  // ========================================================================
  // Architecture: executeCommand returns typed TerminalEffect
  // ========================================================================

  group('executeCommand returns typed TerminalEffect', () {
    test('HELP → NoEffect, appends help output', () {
      final effect = _dispatch(notifier, 'HELP');
      expect(effect, isA<NoEffect>());
      final buf = container.read(terminalStateProvider).outputBuffer;
      expect(buf.first.text, 'Available commands:');
    });

    test('QUIT → QuitEffect (screen pops navigator)', () {
      expect(_dispatch(notifier, 'QUIT'), isA<QuitEffect>());
      expect(_dispatch(notifier, 'EXIT'), isA<QuitEffect>());
      expect(_dispatch(notifier, 'Q'), isA<QuitEffect>());
    });

    test('GUESTBOOK → OpenGuestbookEffect (screen resolves section)', () {
      final effect = _dispatch(notifier, 'GUESTBOOK');
      expect(effect, isA<OpenGuestbookEffect>());
      // Does NOT mutate section/screen state inline — that's the
      // screen's job after resolving the guestbook section key against
      // provider data.
      final state = container.read(terminalStateProvider);
      expect(state.currentScreen, TerminalScreen.boardHome);
    });

    test('POST without section → NoEffect + error line (no ComposeThread)', () {
      final effect = _dispatch(notifier, 'POST');
      expect(effect, isA<NoEffect>());
      final buf = container.read(terminalStateProvider).outputBuffer;
      // Voice layer — neutral tone defaults to "Open a SECTION first".
      // Assert behaviour (an error line mentioning "section" was emitted)
      // rather than an exact string so tone variants don't break this.
      expect(
        buf.any(
          (l) =>
              l.style == TerminalLineStyle.error &&
              l.text.toLowerCase().contains('section'),
        ),
        isTrue,
      );
    });

    test('POST inside a section → ComposeThreadEffect', () {
      notifier.renderThreads(_section('s1', 'general', 'General'), const []);
      final effect = _dispatch(notifier, 'POST');
      expect(effect, isA<ComposeThreadEffect>());
    });

    test('REPLY without thread → NoEffect + error line', () {
      final effect = _dispatch(notifier, 'REPLY');
      expect(effect, isA<NoEffect>());
      final buf = container.read(terminalStateProvider).outputBuffer;
      expect(
        buf.any(
          (l) =>
              l.style == TerminalLineStyle.error &&
              l.text.toLowerCase().contains('thread'),
        ),
        isTrue,
      );
    });

    test('REPLY inside a thread → ComposeReplyEffect', () {
      notifier.renderThread(_thread('t1', 'A'), const <NodeBoardReply>[]);
      final effect = _dispatch(notifier, 'REPLY');
      expect(effect, isA<ComposeReplyEffect>());
    });

    test('BACK → NoEffect and pops the screen stack', () {
      notifier.pushScreen(TerminalScreen.sectionList);
      final effect = _dispatch(notifier, 'BACK');
      expect(effect, isA<NoEffect>());
      expect(
        container.read(terminalStateProvider).currentScreen,
        TerminalScreen.boardHome,
      );
    });

    test('SECTIONS → NoEffect, pushes sectionList screen', () {
      final effect = _dispatch(notifier, 'SECTIONS');
      expect(effect, isA<NoEffect>());
      expect(
        container.read(terminalStateProvider).currentScreen,
        TerminalScreen.sectionList,
      );
    });

    test('unknown command → NoEffect + error output, no state change', () {
      final before = container.read(terminalStateProvider).currentScreen;
      final effect = _dispatch(notifier, 'FLARG');
      expect(effect, isA<NoEffect>());
      expect(container.read(terminalStateProvider).currentScreen, before);
      final buf = container.read(terminalStateProvider).outputBuffer;
      // Voice echoes the raw command + a HELP hint. Phrasing varies per
      // tone — just assert the raw command comes through and a HELP hint
      // exists somewhere on the buffer.
      expect(buf.any((l) => l.text.contains('FLARG')), isTrue);
      expect(buf.any((l) => l.text.toUpperCase().contains('HELP')), isTrue);
    });
  });

  // ========================================================================
  // OPEN effect carries typed index
  // ========================================================================

  group('OPEN returns typed OpenIndexEffect', () {
    test('OPEN 3 → OpenIndexEffect(3)', () {
      final effect = _dispatch(notifier, 'OPEN 3');
      expect(effect, isA<OpenIndexEffect>());
      expect((effect as OpenIndexEffect).index, 3);
    });

    test('OPEN with no arg → NoEffect + usage error', () {
      final effect = _dispatch(notifier, 'OPEN');
      expect(effect, isA<NoEffect>());
      final buf = container.read(terminalStateProvider).outputBuffer;
      // Voice uses the canonical "USAGE: OPEN <number>" phrasing.
      expect(
        buf.any((l) => l.text.toUpperCase().contains('USAGE: OPEN')),
        isTrue,
      );
    });

    test('OPEN with non-numeric arg → NoEffect + error', () {
      final effect = _dispatch(notifier, 'OPEN abc');
      expect(effect, isA<NoEffect>());
      final buf = container.read(terminalStateProvider).outputBuffer;
      expect(
        buf.any(
          (l) =>
              l.style == TerminalLineStyle.error &&
              l.text.toLowerCase().contains('invalid') &&
              l.text.contains('abc'),
        ),
        isTrue,
      );
    });

    test('OPEN 0 → NoEffect + error (indices are 1-based)', () {
      final effect = _dispatch(notifier, 'OPEN 0');
      expect(effect, isA<NoEffect>());
      final buf = container.read(terminalStateProvider).outputBuffer;
      expect(
        buf.any(
          (l) =>
              l.style == TerminalLineStyle.error &&
              l.text.toLowerCase().contains('invalid'),
        ),
        isTrue,
      );
    });

    test('OPEN never writes the index into error state', () {
      // Regression guard: the prior implementation used
      // state.lastError = 'OPEN:n' as a command-through-error channel.
      // That field no longer exists and must never return.
      _dispatch(notifier, 'OPEN 7');
      final state = container.read(terminalStateProvider);
      // State must not contain an `OPEN:` marker in any string field.
      final stateString = state.toString();
      expect(stateString.contains('OPEN:'), false);
    });
  });

  // ========================================================================
  // Unified dispatch: typed input, chip tap, output tap all use the
  // same executeCommand pipeline and produce identical results.
  // ========================================================================

  group('Unified dispatch path', () {
    test(
      'chip command "OPEN 2" and typed "OPEN 2" produce identical effect',
      () {
        // Typed input goes through parseTerminalCommand → executeCommand.
        final typed = _dispatch(notifier, 'OPEN 2');
        // Chip taps dispatch the chip's command through the exact same
        // call site in the screen — simulate by calling the same path.
        final chip = _dispatch(notifier, 'OPEN 2');
        expect(typed.runtimeType, chip.runtimeType);
        expect(
          (typed as OpenIndexEffect).index,
          (chip as OpenIndexEffect).index,
        );
      },
    );

    test(
      'output tap command (OPEN 1 on a section row) matches typed OPEN 1',
      () {
        // Tappable output rows carry a command string that is dispatched
        // via the same executeCommand pipeline. Confirm the effect is
        // identical to typing the string.
        const outputLine = TerminalOutputLine.tappable(
          text: 'General',
          tapCommand: 'OPEN 1',
          index: 1,
        );
        final fromTap = _dispatch(notifier, outputLine.tapCommand!);
        final fromType = _dispatch(notifier, 'OPEN 1');
        expect(fromTap.runtimeType, fromType.runtimeType);
        expect((fromTap as OpenIndexEffect).index, 1);
        expect((fromType as OpenIndexEffect).index, 1);
      },
    );

    test('every chip.command is a valid executeCommand input', () {
      // Walk through each screen's chip list and confirm every chip
      // command parses to something other than TerminalCommand.unknown.
      // This guarantees chip → command → effect never silently errors.
      final allChipCommands = <String>{};
      // boardHome chips
      for (final c in container.read(terminalStateProvider).chips) {
        allChipCommands.add(c.command);
      }
      // sectionList chips after renderSections
      notifier.renderSections([_section('s1', 'a', 'A')]);
      for (final c in container.read(terminalStateProvider).chips) {
        allChipCommands.add(c.command);
      }
      // threadList chips after renderThreads
      notifier.renderThreads(_section('s1', 'a', 'A'), [
        _thread('t1', 'first'),
      ]);
      for (final c in container.read(terminalStateProvider).chips) {
        allChipCommands.add(c.command);
      }
      // threadView chips after renderThread
      notifier.renderThread(_thread('t1', 'first'), const []);
      for (final c in container.read(terminalStateProvider).chips) {
        allChipCommands.add(c.command);
      }

      for (final cmd in allChipCommands) {
        final parsed = parseTerminalCommand(cmd);
        expect(
          parsed.command,
          isNot(TerminalCommand.unknown),
          reason: 'chip command "$cmd" must parse to a known command',
        );
      }
    });
  });

  // ========================================================================
  // TerminalState invariants
  // ========================================================================

  group('TerminalState invariants', () {
    test('has no lastError field (removed in architecture cleanup)', () {
      const state = TerminalState();
      // Reflective check: TerminalState should not expose lastError.
      // If anyone re-introduces it, toString() will leak it here.
      expect(state.toString().contains('lastError'), false);
    });

    test('renderError only appends to buffer, no control flow smuggling', () {
      notifier.renderError('oops');
      final state = container.read(terminalStateProvider);
      expect(state.outputBuffer.last.style, TerminalLineStyle.error);
      expect(state.outputBuffer.last.text, 'oops');
    });
  });

  // ========================================================================
  // Chip generation (context-aware)
  // ========================================================================

  group('Chip generation per screen', () {
    test('sectionList exposes BACK + OPEN n chips', () {
      notifier.renderSections([
        _section('s1', 'general', 'General'),
        _section('s2', 'announcements', 'Announcements'),
      ]);
      final cmds = container
          .read(terminalStateProvider)
          .chips
          .map((c) => c.command)
          .toList();
      expect(cmds, contains('BACK'));
      expect(cmds, contains('OPEN 1'));
      expect(cmds, contains('OPEN 2'));
      expect(cmds, contains('HELP'));
    });

    test('threadList exposes POST + numbered OPEN chips', () {
      notifier.renderThreads(_section('s1', 'general', 'General'), [
        _thread('t1', 'First'),
        _thread('t2', 'Second'),
      ]);
      final cmds = container
          .read(terminalStateProvider)
          .chips
          .map((c) => c.command)
          .toList();
      expect(cmds, contains('POST'));
      expect(cmds, contains('OPEN 1'));
      expect(cmds, contains('OPEN 2'));
    });

    test('threadView exposes REPLY + BACK', () {
      notifier.renderThread(_thread('t1', 'First'), const <NodeBoardReply>[]);
      final cmds = container
          .read(terminalStateProvider)
          .chips
          .map((c) => c.command)
          .toList();
      expect(cmds, contains('REPLY'));
      expect(cmds, contains('BACK'));
    });
  });

  // ========================================================================
  // Tappable output & chip action invariants
  // ========================================================================

  group('Output + chip data contracts', () {
    test('renderSections emits indexed tappable lines carrying OPEN n', () {
      notifier.renderSections([
        _section('s1', 'a', 'Alpha'),
        _section('s2', 'b', 'Beta'),
      ]);
      final buffer = container.read(terminalStateProvider).outputBuffer;
      final tappables = buffer
          .where((l) => l.tapCommand != null)
          .map((l) => l.tapCommand)
          .toList();
      expect(tappables, ['OPEN 1', 'OPEN 2']);
    });

    test('TerminalChipAction equality by label+command', () {
      const a = TerminalChipAction(label: 'HELP', command: 'HELP');
      const b = TerminalChipAction(label: 'HELP', command: 'HELP');
      const c = TerminalChipAction(label: 'BACK', command: 'BACK');
      expect(a, b);
      expect(a, isNot(c));
    });

    test('TerminalOutputLine.tappable carries index + tapCommand', () {
      const line = TerminalOutputLine.tappable(
        text: 'Section A',
        tapCommand: 'OPEN 1',
        index: 1,
      );
      expect(line.text, 'Section A');
      expect(line.tapCommand, 'OPEN 1');
      expect(line.index, 1);
    });

    test('TerminalOutputLine default ctor has no tap data', () {
      const line = TerminalOutputLine('plain');
      expect(line.tapCommand, isNull);
      expect(line.index, isNull);
    });
  });

  // ========================================================================
  // Screen transitions
  // ========================================================================

  group('Screen transitions via public methods', () {
    test('openSection advances to threadList with ids', () {
      notifier.openSection(sectionId: 'sec-1', sectionKey: 'general');
      final s = container.read(terminalStateProvider);
      expect(s.currentScreen, TerminalScreen.threadList);
      expect(s.currentSectionId, 'sec-1');
      expect(s.currentSectionKey, 'general');
    });

    test('openThread advances to threadView with threadId', () {
      notifier.openThread('thread-9');
      final s = container.read(terminalStateProvider);
      expect(s.currentScreen, TerminalScreen.threadView);
      expect(s.currentThreadId, 'thread-9');
    });

    test('popScreen from threadView clears currentThreadId', () {
      notifier.openSection(sectionId: 's1', sectionKey: 'general');
      notifier.openThread('t1');
      notifier.popScreen();
      final s = container.read(terminalStateProvider);
      expect(s.currentScreen, TerminalScreen.threadList);
      expect(s.currentThreadId, isNull);
    });

    test('popScreen from threadList clears section + thread ids', () {
      notifier.openSection(sectionId: 's1', sectionKey: 'general');
      notifier.popScreen();
      final s = container.read(terminalStateProvider);
      expect(s.currentScreen, TerminalScreen.boardHome);
      expect(s.currentSectionId, isNull);
      expect(s.currentSectionKey, isNull);
      expect(s.currentThreadId, isNull);
    });
  });
}
