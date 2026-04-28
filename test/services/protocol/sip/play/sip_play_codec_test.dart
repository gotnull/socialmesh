// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Wire-format tests for the SIP Play v1 envelope codec. These pin
/// the byte layout from the spec — any future change here must bump
/// `SipPlayConstants.envelopeTypeAndVersionV1` first.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_constants.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_payload.dart';

void main() {
  group('SipPlayCodec.encode', () {
    test('emits the locked 6-byte header before any game payload', () {
      final envelope = SipPlayEnvelope(
        typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
        gameTypeCode: SipPlayGameType.ticTacToe.code,
        instanceId: 0xABCD,
        action: SipPlayAction.move,
        seq: 0x07,
        gamePayload: Uint8List.fromList([0x14]),
      );
      final bytes = SipPlayCodec.encode(envelope)!;

      // Header (6 bytes) + game payload (1 byte) = 7 bytes total —
      // matches the spec's "~7 bytes before SIP framing" budget for
      // a TTT move.
      expect(bytes.length, equals(7));
      expect(bytes[0], equals(0x11)); // typeAndVersion
      expect(bytes[1], equals(0x01)); // gameType TTT
      expect(bytes[2], equals(0xAB)); // instanceId hi (big-endian)
      expect(bytes[3], equals(0xCD)); // instanceId lo
      expect(bytes[4], equals(0x03)); // action move
      expect(bytes[5], equals(0x07)); // seq
      expect(bytes[6], equals(0x14)); // game payload
    });

    test(
      'encodes empty game payload for offer / accept / decline / resign',
      () {
        for (final action in [
          SipPlayAction.offer,
          SipPlayAction.accept,
          SipPlayAction.decline,
          SipPlayAction.resign,
        ]) {
          final envelope = SipPlayEnvelope(
            typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
            gameTypeCode: SipPlayGameType.ticTacToe.code,
            instanceId: 0x0001,
            action: action,
            seq: 0,
            gamePayload: Uint8List(0),
          );
          final bytes = SipPlayCodec.encode(envelope)!;
          expect(bytes.length, equals(SipPlayConstants.envelopeHeaderBytes));
        }
      },
    );

    test('rejects an envelope larger than the framework ceiling', () {
      // Build an envelope whose game payload pushes total beyond 64B.
      final huge = Uint8List(SipPlayConstants.maxEnvelopeBytes);
      final envelope = SipPlayEnvelope(
        typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
        gameTypeCode: 0x99,
        instanceId: 0,
        action: SipPlayAction.move,
        seq: 0,
        gamePayload: huge,
      );
      expect(SipPlayCodec.encode(envelope), isNull);
    });

    test('rejects out-of-range seq', () {
      final envelope = SipPlayEnvelope(
        typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
        gameTypeCode: 1,
        instanceId: 0,
        action: SipPlayAction.move,
        seq: 0x100, // u8 overflow
        gamePayload: Uint8List(0),
      );
      expect(SipPlayCodec.encode(envelope), isNull);
    });

    test('rejects out-of-range instanceId', () {
      final envelope = SipPlayEnvelope(
        typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
        gameTypeCode: 1,
        instanceId: 0x10000,
        action: SipPlayAction.offer,
        seq: 0,
        gamePayload: Uint8List(0),
      );
      expect(SipPlayCodec.encode(envelope), isNull);
    });
  });

  group('SipPlayCodec.decode', () {
    test('round-trips a TTT move envelope byte-for-byte', () {
      final src = SipPlayEnvelope(
        typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
        gameTypeCode: SipPlayGameType.ticTacToe.code,
        instanceId: 0x0042,
        action: SipPlayAction.move,
        seq: 5,
        gamePayload: Uint8List.fromList([0x04]),
      );
      final bytes = SipPlayCodec.encode(src)!;
      final result = SipPlayCodec.decode(bytes);
      expect(result.isOk, isTrue);
      final back = result.envelope!;
      expect(back.typeAndVersion, equals(src.typeAndVersion));
      expect(back.gameTypeCode, equals(src.gameTypeCode));
      expect(back.instanceId, equals(src.instanceId));
      expect(back.action, equals(src.action));
      expect(back.seq, equals(src.seq));
      expect(back.gamePayload, equals(src.gamePayload));
    });

    test('drops envelope shorter than the header', () {
      final result = SipPlayCodec.decode(Uint8List.fromList([0x11, 0x01]));
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipPlayDecodeError.truncatedHeader));
    });

    test('drops envelope larger than the framework ceiling', () {
      final result = SipPlayCodec.decode(
        Uint8List(SipPlayConstants.maxEnvelopeBytes + 1),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipPlayDecodeError.payloadTooLarge));
    });

    test('drops envelope with wrong typeAndVersion sentinel', () {
      final bytes = Uint8List.fromList([
        0x22, // not 0x11
        0x01, 0x00, 0x01, 0x03, 0x00,
      ]);
      final result = SipPlayCodec.decode(bytes);
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipPlayDecodeError.unsupportedVersion));
    });

    test('drops envelope with unknown action code', () {
      final bytes = Uint8List.fromList([
        0x11,
        0x01,
        0x00, 0x01,
        0x77, // unknown action
        0x00,
      ]);
      final result = SipPlayCodec.decode(bytes);
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipPlayDecodeError.unknownAction));
    });

    test('decodes envelope with unknown game type successfully (caller '
        'renders unsupported fallback)', () {
      // The codec deliberately accepts unknown game types so the
      // engine can branch into the safe fallback rather than treating
      // unknown games as a wire-level error.
      final bytes = Uint8List.fromList([
        0x11,
        0xFE, // unknown game type
        0x00, 0x01,
        0x00, // offer
        0x00,
      ]);
      final result = SipPlayCodec.decode(bytes);
      expect(result.isOk, isTrue);
      expect(result.envelope!.gameTypeCode, equals(0xFE));
      expect(result.envelope!.knownGameType, isNull);
    });

    test('never throws on random garbage input (drop+log only)', () {
      // Programmatic spread of garbage byte sequences. Confirms the
      // codec is fuzz-safe at every boundary.
      final cases = <Uint8List>[
        Uint8List(0),
        Uint8List.fromList([0]),
        Uint8List.fromList([0, 0, 0, 0, 0, 0]),
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
        Uint8List.fromList([0x11, 0x99, 0x12, 0x34, 0xFF, 0x00]),
      ];
      for (final bytes in cases) {
        final result = SipPlayCodec.decode(bytes);
        // Either ok (e.g. unknown game type) or fail with a typed
        // error — never an exception.
        expect(result.error == null || result.envelope == null, isTrue);
      }
    });
  });
}
