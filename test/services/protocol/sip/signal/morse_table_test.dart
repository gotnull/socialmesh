// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the Morse table + timing schedule used by SIP Signal v1.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/signal/morse_table.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_constants.dart';

void main() {
  group('MorseTable.charToCode', () {
    test('every supported letter / digit has a code', () {
      const supported = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,?!/@';
      for (final ch in supported.split('')) {
        expect(
          MorseTable.charToCode.containsKey(ch),
          isTrue,
          reason: '$ch must be in the Morse table',
        );
      }
    });
  });

  group('MorseTable.isEncodable', () {
    test('uppercase + digits + spaces are encodable', () {
      expect(MorseTable.isEncodable('SOS'), isTrue);
      expect(MorseTable.isEncodable('HELLO WORLD'), isTrue);
      expect(MorseTable.isEncodable('OK 9000.'), isTrue);
    });

    test('mixed case treated as uppercase', () {
      expect(MorseTable.isEncodable('sos'), isTrue);
      expect(MorseTable.isEncodable('Hello'), isTrue);
    });

    test('unsupported characters reject', () {
      expect(MorseTable.isEncodable('A&B'), isFalse);
      expect(MorseTable.isEncodable('🚀'), isFalse);
      expect(MorseTable.isEncodable('OK\$'), isFalse);
    });
  });

  group('MorseTable.filtered', () {
    test('strips unsupported characters but preserves spaces', () {
      expect(MorseTable.filtered('OK & GO'), equals('OK  GO'));
    });

    test('leaves a fully-encodable string unchanged after upper-casing', () {
      expect(MorseTable.filtered('hello'), equals('HELLO'));
      expect(MorseTable.filtered('hello world'), equals('HELLO WORLD'));
    });

    test('empty input → empty output', () {
      expect(MorseTable.filtered(''), equals(''));
    });
  });

  group('MorseTable.render', () {
    test('SOS renders as ... --- ...', () {
      expect(MorseTable.render('SOS'), equals('... --- ...'));
    });

    test('HELLO WORLD renders with the canonical word separator', () {
      // Word separator is now MorseTable.wordSeparator (` · ` —
      // middle-dot, picked because U+00B7 doesn't collide with the
      // dot/dash alphabet and reads as a single visual token between
      // words).
      expect(
        MorseTable.render('HELLO WORLD'),
        equals(
          '.... . .-.. .-.. ---${MorseTable.wordSeparator}.-- --- .-. .-.. -..',
        ),
      );
    });

    test('round-trip: render → decode is lossless for the supported '
        'alphabet', () {
      const samples = ['SOS', 'HELLO WORLD', 'THE QUICK BROWN FOX', 'A B C'];
      for (final s in samples) {
        expect(
          MorseTable.decode(MorseTable.render(s)),
          equals(s),
          reason: 'render+decode must round-trip "$s"',
        );
      }
    });

    test('decode falls back to multi-space word boundaries (legacy input)', () {
      // Pre-canonical-separator builds rendered word gaps as `'   '`.
      // The decoder must still pick those up so legacy clipboards /
      // bridged peers continue to decode correctly.
      const legacy = '.... . .-.. .-.. ---   .-- --- .-. .-.. -..';
      expect(MorseTable.decode(legacy), equals('HELLO WORLD'));
    });

    test('decode handles continuous input via greedy longest-prefix', () {
      // No separators: decoder walks the longest matching prefix per
      // step. Spec acknowledges this is inherently lossy on ambiguous
      // input — `...---...` could be `SOS`, `V7`, `EE---...`, etc.
      // We just pin that the decoder produces a non-empty decode and
      // doesn't crash. Real users get separator-anchored decodes.
      final decoded = MorseTable.decode('...---...');
      expect(decoded, isNotEmpty);
      expect(decoded, isNot(contains('?')));
    });

    test('decode flags unknown tokens as ?', () {
      // The first token (`........`) is not in the table, so it
      // surfaces as `?`. The remainder still decodes cleanly.
      expect(MorseTable.decode('........ . .-..'), equals('?EL'));
    });

    test('numbers + punctuation', () {
      expect(MorseTable.render('SOS!'), equals('... --- ... -.-.--'));
      expect(MorseTable.render('123'), equals('.---- ..--- ...--'));
    });

    test('lowercase input renders identically to uppercase', () {
      expect(MorseTable.render('sos'), equals('... --- ...'));
    });
  });

  group('SipSignalConstants.unitMsForWpm', () {
    test('15 WPM → 80 ms per unit (standard)', () {
      expect(SipSignalConstants.unitMsForWpm(15), equals(80));
    });

    test('20 WPM → 60 ms per unit', () {
      expect(SipSignalConstants.unitMsForWpm(20), equals(60));
    });

    test('clamps below min', () {
      expect(
        SipSignalConstants.unitMsForWpm(1),
        equals(SipSignalConstants.unitMsForWpm(SipSignalConstants.minMorseWpm)),
      );
    });

    test('clamps above max', () {
      expect(
        SipSignalConstants.unitMsForWpm(99999),
        equals(SipSignalConstants.unitMsForWpm(SipSignalConstants.maxMorseWpm)),
      );
    });
  });

  group('morseTimingForText', () {
    test('SOS produces the canonical sequence with correct unit counts', () {
      // S = ... → 1 + gap1 + 1 + gap1 + 1
      // letter gap (3)
      // O = --- → 3 + gap1 + 3 + gap1 + 3
      // letter gap (3)
      // S = ... → 1 + gap1 + 1 + gap1 + 1
      final timing = morseTimingForText('SOS');
      // Tone-on counts (units) in order:
      final tones = timing
          .where((s) => s.kind == MorseStepKind.tone)
          .map((s) => s.units)
          .toList();
      expect(tones, equals([1, 1, 1, 3, 3, 3, 1, 1, 1]));
      // Inter-character gaps of 3 fall between each letter group.
      final gaps = timing
          .where((s) => s.kind == MorseStepKind.gap)
          .map((s) => s.units)
          .toList();
      // 6 intra-character (1-unit) gaps + 2 inter-character (3-unit)
      // gaps in 'SOS'.
      expect(gaps.where((u) => u == 1).length, equals(6));
      expect(gaps.where((u) => u == 3).length, equals(2));
    });

    test('multi-word text produces the 7-unit word gap', () {
      final timing = morseTimingForText('A B');
      final wordGaps = timing.where(
        (s) => s.kind == MorseStepKind.gap && s.units == 7,
      );
      expect(wordGaps.length, equals(1));
    });
  });
}
