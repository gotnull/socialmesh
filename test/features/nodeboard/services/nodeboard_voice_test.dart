// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/services/nodeboard_voice.dart';

void main() {
  group('BoardTone.fromThemeId', () {
    test('classic_green → hacker', () {
      expect(BoardTone.fromThemeId('classic_green'), BoardTone.hacker);
    });

    test('amber_terminal → hacker', () {
      expect(BoardTone.fromThemeId('amber_terminal'), BoardTone.hacker);
    });

    test('cyber_blue → corporate', () {
      expect(BoardTone.fromThemeId('cyber_blue'), BoardTone.corporate);
    });

    test('wasteland → wasteland', () {
      expect(BoardTone.fromThemeId('wasteland'), BoardTone.wasteland);
    });

    test('fire_ansi → chaotic', () {
      expect(BoardTone.fromThemeId('fire_ansi'), BoardTone.chaotic);
    });

    test('null → neutral', () {
      expect(BoardTone.fromThemeId(null), BoardTone.neutral);
    });

    test('unknown id → neutral', () {
      expect(BoardTone.fromThemeId('made_up_id'), BoardTone.neutral);
    });
  });

  group('NodeBoardVoice.handshake', () {
    test('always returns exactly 4 lines', () {
      for (final tone in BoardTone.values) {
        final v = NodeBoardVoice(tone: tone);
        final lines = v.handshake(nodeHex: '!9C3A29A9', sysop: 'gotnull');
        expect(
          lines.length,
          4,
          reason: 'tone=$tone should produce 4 handshake beats',
        );
      }
    });

    test('embeds nodeHex and sysop into handshake lines', () {
      for (final tone in BoardTone.values) {
        final lines = NodeBoardVoice(
          tone: tone,
        ).handshake(nodeHex: '!ABC123', sysop: 'distortion');
        final joined = lines.join('\n');
        expect(
          joined.contains('!ABC123'),
          isTrue,
          reason: 'tone=$tone must include node hex',
        );
        expect(
          joined.contains('distortion'),
          isTrue,
          reason: 'tone=$tone must include sysop name',
        );
      }
    });

    test('different tones produce different handshake openers', () {
      final hacker = NodeBoardVoice(
        tone: BoardTone.hacker,
      ).handshake(nodeHex: '!X', sysop: 'y').first;
      final wasteland = NodeBoardVoice(
        tone: BoardTone.wasteland,
      ).handshake(nodeHex: '!X', sysop: 'y').first;
      final chaotic = NodeBoardVoice(
        tone: BoardTone.chaotic,
      ).handshake(nodeHex: '!X', sysop: 'y').first;
      expect(hacker, isNot(equals(wasteland)));
      expect(hacker, isNot(equals(chaotic)));
      expect(wasteland, isNot(equals(chaotic)));
    });
  });

  group('NodeBoardVoice deterministic variant pick', () {
    test('same (tone, seed) gives same phrase on repeat calls', () {
      final v = NodeBoardVoice(tone: BoardTone.hacker, seed: 42);
      expect(v.postedThread(), v.postedThread());
      expect(v.welcomeHint(), v.welcomeHint());
      expect(v.emptyThreadsTitle(), v.emptyThreadsTitle());
    });

    test('different seeds can produce different phrases (when options exist)', () {
      final tone = BoardTone.hacker;
      final posts = <String>{
        for (var seed = 0; seed < 50; seed++)
          NodeBoardVoice(tone: tone, seed: seed).postedThread(),
      };
      expect(posts.length, greaterThan(1));
    });
  });

  group('NodeBoardVoice.activityLabel', () {
    test('each tone produces a non-empty label', () {
      for (final tone in BoardTone.values) {
        expect(NodeBoardVoice(tone: tone).activityLabel, isNotEmpty);
      }
    });

    test('different tones use different activity labels', () {
      final labels = <String>{
        for (final tone in BoardTone.values)
          NodeBoardVoice(tone: tone).activityLabel.toLowerCase(),
      };
      // At least 4 of the 6 tones should be textually distinct (some may
      // overlap — e.g. neutral vs corporate both speak plainly).
      expect(labels.length, greaterThanOrEqualTo(4));
    });
  });

  group('NodeBoardVoice errors', () {
    test('outOfRange carries kind + index into phrasing', () {
      for (final tone in BoardTone.values) {
        final msg = NodeBoardVoice(tone: tone).outOfRange('SECTION', 7);
        expect(msg.contains('SECTION') || msg.contains('section'), isTrue);
        expect(msg.contains('7'), isTrue);
      }
    });

    test('unknownCommand echoes the raw input', () {
      for (final tone in BoardTone.values) {
        final msg = NodeBoardVoice(tone: tone).unknownCommand('FROBNICATE');
        expect(
          msg.contains('FROBNICATE') || msg.contains('frobnicate'),
          isTrue,
          reason: 'tone=$tone must echo the raw command text',
        );
      }
    });
  });

  group('NodeBoardVoice empty states', () {
    test('empty thread title + subtitle are both non-empty per tone', () {
      for (final tone in BoardTone.values) {
        final v = NodeBoardVoice(tone: tone);
        expect(v.emptyThreadsTitle(), isNotEmpty);
        expect(v.emptyThreadsSubtitle(), isNotEmpty);
        expect(v.emptyGuestbookTitle(), isNotEmpty);
        expect(v.emptyGuestbookSubtitle(), isNotEmpty);
      }
    });

    test('neutral and hacker empty titles are textually distinct', () {
      expect(
        NodeBoardVoice(tone: BoardTone.neutral).emptyThreadsTitle(),
        isNot(equals(NodeBoardVoice(tone: BoardTone.hacker).emptyThreadsTitle())),
      );
    });
  });

  group('formatNodeBoardRelativeTime', () {
    test('null → NEVER', () {
      expect(formatNodeBoardRelativeTime(null), 'NEVER');
    });

    test('very recent → just now', () {
      final when = DateTime.now().subtract(const Duration(seconds: 5));
      expect(formatNodeBoardRelativeTime(when), 'just now');
    });

    test('minutes', () {
      final when = DateTime.now().subtract(const Duration(minutes: 12));
      expect(formatNodeBoardRelativeTime(when), '12m ago');
    });

    test('hours', () {
      final when = DateTime.now().subtract(const Duration(hours: 5));
      expect(formatNodeBoardRelativeTime(when), '5h ago');
    });

    test('days', () {
      final when = DateTime.now().subtract(const Duration(days: 3));
      expect(formatNodeBoardRelativeTime(when), '3d ago');
    });

    test('months', () {
      final when = DateTime.now().subtract(const Duration(days: 95));
      expect(formatNodeBoardRelativeTime(when), '3mo ago');
    });

    test('years', () {
      final when = DateTime.now().subtract(const Duration(days: 800));
      expect(formatNodeBoardRelativeTime(when), '2y ago');
    });
  });
}
