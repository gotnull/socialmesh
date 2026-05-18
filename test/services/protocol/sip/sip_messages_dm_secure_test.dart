// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Phase 2 secure DM payload codec tests.
///
/// Verifies the wire-layout of the secure DM text / reaction envelopes
/// documented in `sip_messages_dm.dart`:
///
///   dmText     : timestamp_s(4) ‖ utf8_text
///   dmReaction : timestamp_s(4) ‖ emoji_index(1) ‖ target_ts(4)
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_dm.dart';

void main() {
  group('SipDmMessages.encodeSecureDmText', () {
    test('prepends BE u32 timestamp to the utf8 body', () {
      final bytes = SipDmMessages.encodeSecureDmText(
        text: 'hi',
        timestampS: 0x01020304,
      )!;
      expect(bytes.length, 4 + 2);
      expect(bytes.sublist(0, 4), Uint8List.fromList(<int>[1, 2, 3, 4]));
      // 'hi' = 0x68, 0x69
      expect(bytes[4], 0x68);
      expect(bytes[5], 0x69);
    });

    test('rejects empty text via encodeDm guard', () {
      expect(SipDmMessages.encodeSecureDmText(text: '', timestampS: 0), isNull);
    });

    test('rejects text over max bytes via encodeDm guard', () {
      final longText = 'A' * (SipDmConstants.maxDmTextBytes + 1);
      expect(
        SipDmMessages.encodeSecureDmText(text: longText, timestampS: 0),
        isNull,
      );
    });

    test('rejects out-of-range timestamp', () {
      expect(
        SipDmMessages.encodeSecureDmText(text: 'hi', timestampS: -1),
        isNull,
      );
      expect(
        SipDmMessages.encodeSecureDmText(text: 'hi', timestampS: 0x100000000),
        isNull,
      );
    });
  });

  group('SipDmMessages.decodeSecureDmText', () {
    test('round-trips encode output', () {
      const timestamp = 1776564325;
      const text = 'hello secure mesh ❤️';
      final encoded = SipDmMessages.encodeSecureDmText(
        text: text,
        timestampS: timestamp,
      )!;
      final decoded = SipDmMessages.decodeSecureDmText(encoded)!;
      expect(decoded.timestampS, timestamp);
      expect(decoded.message.text, text);
    });

    test('rejects too-short payload', () {
      expect(SipDmMessages.decodeSecureDmText(Uint8List(4)), isNull);
      expect(SipDmMessages.decodeSecureDmText(Uint8List(0)), isNull);
    });

    test('rejects invalid UTF-8 body', () {
      // timestamp + two invalid UTF-8 bytes
      final bad = Uint8List.fromList(<int>[0, 0, 0, 1, 0xFF, 0xFE]);
      expect(SipDmMessages.decodeSecureDmText(bad), isNull);
    });

    test('rejects body that sanitizes to empty (control chars only)', () {
      // timestamp + a single 0x00 byte — UTF-8 decodes to "\x00" which
      // sanitizeExternalText strips to "". decodeDm must reject so that
      // no blank-bodied SipDmMessage propagates downstream.
      final controlOnly = Uint8List.fromList(<int>[0, 0, 0, 1, 0x00]);
      expect(SipDmMessages.decodeSecureDmText(controlOnly), isNull);
    });

    test('rejects body that sanitizes to whitespace only', () {
      // timestamp + spaces + tab + newline. After sanitizer (which keeps
      // tab/newline) the result is whitespace-only; decodeDm must still
      // drop because the trimmed body is empty.
      final whitespaceOnly = Uint8List.fromList(<int>[
        0,
        0,
        0,
        1,
        0x20,
        0x09,
        0x0A,
        0x20,
      ]);
      expect(SipDmMessages.decodeSecureDmText(whitespaceOnly), isNull);
    });

    test('valid emoji body survives the sanitization guard', () {
      // 👋 = U+1F44B in UTF-8: F0 9F 91 8B
      final body = Uint8List.fromList(<int>[
        0,
        0,
        0,
        1,
        0xF0,
        0x9F,
        0x91,
        0x8B,
      ]);
      final decoded = SipDmMessages.decodeSecureDmText(body);
      expect(decoded, isNotNull);
      expect(decoded!.message.text, '👋');
    });
  });

  group('SipDmMessages.encodeSecureReaction', () {
    test('layout is exactly 9 bytes BE', () {
      final bytes = SipDmMessages.encodeSecureReaction(
        timestampS: 0x01020304,
        emojiIndex: 2,
        targetTimestampS: 0x0A0B0C0D,
      )!;
      expect(bytes.length, 9);
      expect(bytes.sublist(0, 4), Uint8List.fromList(<int>[1, 2, 3, 4]));
      expect(bytes[4], 2);
      expect(
        bytes.sublist(5, 9),
        Uint8List.fromList(<int>[0x0A, 0x0B, 0x0C, 0x0D]),
      );
    });

    test('rejects bad emoji index', () {
      expect(
        SipDmMessages.encodeSecureReaction(
          timestampS: 0,
          emojiIndex: -1,
          targetTimestampS: 0,
        ),
        isNull,
      );
      expect(
        SipDmMessages.encodeSecureReaction(
          timestampS: 0,
          emojiIndex: 7,
          targetTimestampS: 0,
        ),
        isNull,
      );
    });
  });

  group('SipDmMessages.decodeSecureReaction', () {
    test('round-trips encode output', () {
      final encoded = SipDmMessages.encodeSecureReaction(
        timestampS: 100,
        emojiIndex: 3,
        targetTimestampS: 42,
      )!;
      final decoded = SipDmMessages.decodeSecureReaction(encoded)!;
      expect(decoded.timestampS, 100);
      expect(decoded.reaction.emojiIndex, 3);
      expect(decoded.reaction.targetTimestampS, 42);
    });

    test('rejects wrong length', () {
      expect(SipDmMessages.decodeSecureReaction(Uint8List(8)), isNull);
      expect(SipDmMessages.decodeSecureReaction(Uint8List(10)), isNull);
    });

    test('rejects bad emoji index on decode', () {
      final bad = Uint8List.fromList(<int>[0, 0, 0, 1, 99, 0, 0, 0, 2]);
      expect(SipDmMessages.decodeSecureReaction(bad), isNull);
    });
  });
}
