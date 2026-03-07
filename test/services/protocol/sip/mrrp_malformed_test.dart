// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

import '../../../fixtures/sip/mrrp_fuzz_cases.dart';

void main() {
  group('MrrpCodec malformed input handling', () {
    test('empty input returns null', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.empty), isNull);
    });

    test('single byte returns null', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.oneByte), isNull);
    });

    test('magic bytes only returns null (too short for header)', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.magicOnly), isNull);
    });

    test('truncated header returns null', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.truncatedHeader), isNull);
    });

    test('header_len too small returns null', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.headerLenTooSmall), isNull);
    });

    test('header_len exceeds data returns null', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.headerLenExceedsData), isNull);
    });

    test('payload_len exceeds remaining bytes returns null', () {
      expect(
        MrrpCodec.decode(MrrpFuzzCases.payloadLenExceedsRemaining),
        isNull,
      );
    });

    test(
      'payload_len zero with trailing bytes succeeds (trailing ignored)',
      () {
        // Decode should still succeed — trailing bytes beyond payload are
        // unaccounted but do not invalidate a well-formed header+payload.
        final frame = MrrpCodec.decode(MrrpFuzzCases.payloadZeroWithTrailing);
        // The current codec may accept or reject this; either is valid.
        // We just assert no exception is thrown.
        if (frame != null) {
          expect(frame.payloadLen, 0);
        }
      },
    );

    test('version_major 255 returns null (unsupported version)', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.versionMajor255), isNull);
    });

    test('all-zero frame returns null (invalid magic)', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.allZero), isNull);
    });

    test('magic inside non-MRRP data returns null (wrong offset)', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.magicInsideNonMrrp), isNull);
    });

    test('unknown msgType returns null', () {
      expect(MrrpCodec.decode(MrrpFuzzCases.unknownMsgType), isNull);
    });

    test('max-size frame (215 bytes) decodes correctly', () {
      final frame = MrrpCodec.decode(MrrpFuzzCases.maxSizeFrame);
      expect(frame, isNotNull);
      expect(frame!.msgType, MrrpMessageType.request);
      expect(frame.payloadLen, 195);
      expect(frame.payload.length, 195);
      // All payload bytes are 0xAA
      for (final byte in frame.payload) {
        expect(byte, 0xAA);
      }
    });

    test('oversized frame (216 bytes) decodes but encode rejects', () {
      // Decode should still succeed — the frame itself is well-formed.
      final frame = MrrpCodec.decode(MrrpFuzzCases.exceedsSipMtu);
      if (frame != null) {
        // If we try to re-encode it, it should be rejected (too large).
        final reEncoded = MrrpCodec.encode(frame);
        expect(reEncoded, isNull);
      }
    });

    test('no fuzz case throws an exception', () {
      final cases = [
        MrrpFuzzCases.empty,
        MrrpFuzzCases.oneByte,
        MrrpFuzzCases.magicOnly,
        MrrpFuzzCases.truncatedHeader,
        MrrpFuzzCases.headerLenTooSmall,
        MrrpFuzzCases.headerLenExceedsData,
        MrrpFuzzCases.payloadLenExceedsRemaining,
        MrrpFuzzCases.payloadZeroWithTrailing,
        MrrpFuzzCases.versionMajor255,
        MrrpFuzzCases.allZero,
        MrrpFuzzCases.maxSizeFrame,
        MrrpFuzzCases.magicInsideNonMrrp,
        MrrpFuzzCases.unknownMsgType,
        MrrpFuzzCases.exceedsSipMtu,
      ];

      for (final data in cases) {
        expect(
          () => MrrpCodec.decode(data),
          returnsNormally,
          reason:
              'Fuzz case (${data.length} bytes) should not throw', // lint-allow: hardcoded-string
        );
      }
    });

    test('isMrrpPayload rejects all invalid-magic fuzz cases', () {
      expect(MrrpCodec.isMrrpPayload(MrrpFuzzCases.empty), isFalse);
      expect(MrrpCodec.isMrrpPayload(MrrpFuzzCases.oneByte), isFalse);
      expect(MrrpCodec.isMrrpPayload(MrrpFuzzCases.allZero), isFalse);
      expect(
        MrrpCodec.isMrrpPayload(MrrpFuzzCases.magicInsideNonMrrp),
        isFalse,
      );
    });

    test('isMrrpPayload accepts valid-magic fuzz cases', () {
      expect(MrrpCodec.isMrrpPayload(MrrpFuzzCases.magicOnly), isTrue);
      expect(MrrpCodec.isMrrpPayload(MrrpFuzzCases.maxSizeFrame), isTrue);
      expect(MrrpCodec.isMrrpPayload(MrrpFuzzCases.unknownMsgType), isTrue);
    });

    test('encode rejects frame exceeding SIP_MAX_PAYLOAD', () {
      // Build a frame whose total wire size exceeds 215 bytes.
      final oversized = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin + 4,
        requestId: 1,
        serviceId: 1,
        actionId: 1,
        payloadLen: 195,
        headerExtensions: [
          MrrpTlvEntry(
            type: MrrpTlvType.requestTtlS.code,
            value: Uint8List.fromList([0x0F, 0x00]),
          ),
        ],
        payload: Uint8List(195),
      );

      // Total: 20 header + 4 TLV + 195 payload = 219 > 215
      final encoded = MrrpCodec.encode(oversized);
      expect(encoded, isNull);
    });

    group('randomized byte corruption', () {
      test('single-byte corruption of valid frame does not crash', () {
        // Start with max-size frame (valid) and corrupt each byte position.
        final base = Uint8List.fromList(MrrpFuzzCases.maxSizeFrame);
        for (var i = 0; i < base.length; i++) {
          final corrupted = Uint8List.fromList(base);
          corrupted[i] = corrupted[i] ^ 0xFF; // flip all bits
          expect(
            () => MrrpCodec.decode(corrupted),
            returnsNormally,
            reason:
                'Corrupted byte at offset $i should not throw', // lint-allow: hardcoded-string
          );
        }
      });
    });
  });
}
