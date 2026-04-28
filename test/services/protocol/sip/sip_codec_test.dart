// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

import '../../../fixtures/sip/sip_fuzz_cases.dart';
import '../../../fixtures/sip/sip_test_vectors.dart';

void main() {
  group('SipCodec', () {
    group('isSipPayload', () {
      test('returns true for valid SIP magic bytes', () {
        expect(SipCodec.isSipPayload(SipTestVectors.capBeacon), isTrue);
        expect(SipCodec.isSipPayload(SipTestVectors.rollcallReq), isTrue);
      });

      test('returns false for non-SIP payloads', () {
        expect(SipCodec.isSipPayload(Uint8List(0)), isFalse);
        expect(SipCodec.isSipPayload(Uint8List.fromList([0x53])), isFalse);
        expect(
          SipCodec.isSipPayload(Uint8List.fromList([0xDE, 0xAD])),
          isFalse,
        );
      });
    });

    group('generateNonce', () {
      test('returns non-negative values', () {
        for (var i = 0; i < 100; i++) {
          expect(SipCodec.generateNonce(), greaterThanOrEqualTo(0));
        }
      });

      test('returns different values (probabilistic)', () {
        final nonces = <int>{};
        for (var i = 0; i < 100; i++) {
          nonces.add(SipCodec.generateNonce());
        }
        // Should have significant diversity.
        expect(nonces.length, greaterThan(90));
      });
    });

    group('encode/decode round-trip', () {
      test('round-trips a minimal frame (ROLLCALL_REQ, empty payload)', () {
        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.rollcallReq,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: 0x01020304,
          timestampS: 1000,
          payloadLen: 0,
          payload: Uint8List(0),
        );

        final encoded = SipCodec.encode(frame);
        expect(encoded, isNotNull);
        expect(encoded!.length, equals(SipConstants.sipWrapperMin));

        final decoded = SipCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.versionMajor, equals(0));
        expect(decoded.versionMinor, equals(1));
        expect(decoded.msgType, equals(SipMessageType.rollcallReq));
        expect(decoded.flags, equals(0));
        expect(decoded.headerLen, equals(SipConstants.sipWrapperMin));
        expect(decoded.sessionId, equals(0));
        expect(decoded.nonce, equals(0x01020304));
        expect(decoded.timestampS, equals(1000));
        expect(decoded.payloadLen, equals(0));
        expect(decoded.payload, isEmpty);
      });

      test('round-trips a frame with payload', () {
        final payload = Uint8List.fromList([
          0x0B,
          0x00,
          0x01,
          0x01,
          0xD7,
          0x00,
          0x0A,
          0x00,
          0x00,
          0x00,
        ]);
        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.capBeacon,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: 0xDEADBEEF,
          timestampS: 1698765432,
          payloadLen: payload.length,
          payload: payload,
        );

        final encoded = SipCodec.encode(frame);
        expect(encoded, isNotNull);
        expect(encoded!.length, equals(SipConstants.sipWrapperMin + 10));

        final decoded = SipCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.msgType, equals(SipMessageType.capBeacon));
        expect(decoded.nonce, equals(0xDEADBEEF));
        expect(decoded.timestampS, equals(1698765432));
        expect(decoded.payloadLen, equals(10));
        expect(decoded.payload, equals(payload));
      });

      test('round-trips max-size frame (237 bytes)', () {
        final payload = Uint8List(SipConstants.sipMaxPayload);
        for (var i = 0; i < payload.length; i++) {
          payload[i] = i & 0xFF;
        }
        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.capBeacon,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0x12345678,
          nonce: 0xABCDEF01,
          timestampS: 0,
          payloadLen: payload.length,
          payload: payload,
        );

        final encoded = SipCodec.encode(frame);
        expect(encoded, isNotNull);
        expect(encoded!.length, equals(SipConstants.sipMtuApp));

        final decoded = SipCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.payloadLen, equals(SipConstants.sipMaxPayload));
        expect(decoded.payload, equals(payload));
      });

      test('round-trips frame with TLV header extension', () {
        final pubkeyHint = Uint8List.fromList([
          0xA1,
          0xB2,
          0xC3,
          0xD4,
          0xE5,
          0xF6,
          0x07,
          0x18,
        ]);
        final extensions = [
          SipTlvEntry(
            type: SipTlvType.senderPubkeyHint.code,
            value: pubkeyHint,
          ),
        ];
        // header_len = 22 + 2 (TLV type+len) + 8 (value) = 32
        final headerLen = SipConstants.sipWrapperMin + 2 + 8;
        final payload = Uint8List.fromList([0x01, 0x02, 0x03]);
        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.idClaim,
          flags: SipFlags.hasHeaderExt,
          headerLen: headerLen,
          sessionId: 0,
          nonce: 0x11223344,
          timestampS: 0,
          payloadLen: payload.length,
          headerExtensions: extensions,
          payload: payload,
        );

        final encoded = SipCodec.encode(frame);
        expect(encoded, isNotNull);
        expect(encoded!.length, equals(headerLen + payload.length));

        final decoded = SipCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.headerExtensions.length, equals(1));
        expect(
          decoded.headerExtensions[0].type,
          equals(SipTlvType.senderPubkeyHint.code),
        );
        expect(decoded.headerExtensions[0].value, equals(pubkeyHint));
        expect(decoded.payload, equals(payload));
      });
    });

    group('decode test vectors', () {
      test('decodes CAP_BEACON correctly', () {
        final frame = SipCodec.decode(SipTestVectors.capBeacon);
        expect(frame, isNotNull);
        expect(
          frame!.versionMajor,
          equals(SipTestVectors.capBeaconFields.versionMajor),
        );
        expect(
          frame.versionMinor,
          equals(SipTestVectors.capBeaconFields.versionMinor),
        );
        expect(frame.msgType, equals(SipMessageType.capBeacon));
        expect(frame.flags, equals(SipTestVectors.capBeaconFields.flags));
        expect(
          frame.headerLen,
          equals(SipTestVectors.capBeaconFields.headerLen),
        );
        expect(
          frame.sessionId,
          equals(SipTestVectors.capBeaconFields.sessionId),
        );
        expect(frame.nonce, equals(SipTestVectors.capBeaconFields.nonce));
        expect(
          frame.timestampS,
          equals(SipTestVectors.capBeaconFields.timestampS),
        );
        expect(
          frame.payloadLen,
          equals(SipTestVectors.capBeaconFields.payloadLen),
        );
      });

      test('decodes ROLLCALL_REQ correctly', () {
        final frame = SipCodec.decode(SipTestVectors.rollcallReq);
        expect(frame, isNotNull);
        expect(frame!.msgType, equals(SipMessageType.rollcallReq));
        expect(frame.flags, equals(0));
        expect(frame.payloadLen, equals(0));
        expect(frame.payload, isEmpty);
      });

      test('decodes ROLLCALL_RESP correctly', () {
        final frame = SipCodec.decode(SipTestVectors.rollcallResp);
        expect(frame, isNotNull);
        expect(frame!.msgType, equals(SipMessageType.rollcallResp));
        expect(frame.flags, equals(SipFlags.isResponse));
        expect(frame.payloadLen, equals(10));
      });

      test('decodes ERROR frame correctly', () {
        final frame = SipCodec.decode(SipTestVectors.error);
        expect(frame, isNotNull);
        expect(frame!.msgType, equals(SipMessageType.error));
        expect(frame.flags, equals(SipFlags.isResponse));
        expect(frame.payloadLen, equals(3));
        expect(frame.payload[0], equals(SipTestVectors.errorFields.errorCode));
        expect(frame.payload[1], equals(SipTestVectors.errorFields.refMsgType));
        expect(frame.payload[2], equals(SipTestVectors.errorFields.detail));
      });

      test('decodes HS_ACCEPT correctly', () {
        final frame = SipCodec.decode(SipTestVectors.hsAccept);
        expect(frame, isNotNull);
        expect(frame!.msgType, equals(SipMessageType.hsAccept));
        expect(frame.flags, equals(SipFlags.isResponse));
        expect(frame.payloadLen, equals(13));
      });

      test('decodes TX_CHUNK correctly', () {
        final frame = SipCodec.decode(SipTestVectors.txChunkMinimal);
        expect(frame, isNotNull);
        expect(frame!.msgType, equals(SipMessageType.txChunk));
        expect(frame.sessionId, equals(0x12345678));
        expect(frame.payloadLen, equals(8));
      });

      test('decodes TX_ACK correctly', () {
        final frame = SipCodec.decode(SipTestVectors.txAck);
        expect(frame, isNotNull);
        expect(frame!.msgType, equals(SipMessageType.txAck));
        expect(frame.sessionId, equals(0x12345678));
      });

      test('decodes DM_MSG correctly', () {
        final frame = SipCodec.decode(SipTestVectors.dmMsg);
        expect(frame, isNotNull);
        expect(frame!.msgType, equals(SipMessageType.dmMsg));
        expect(frame.sessionId, equals(SipTestVectors.dmMsgFields.sessionId));
        expect(frame.payloadLen, equals(SipTestVectors.dmMsgFields.payloadLen));
        // Payload should be "Hello" in UTF-8.
        expect(String.fromCharCodes(frame.payload), equals('Hello'));
      });
    });

    group('decode fuzz cases', () {
      test('handles empty input gracefully', () {
        expect(SipCodec.decode(SipFuzzCases.empty), isNull);
      });

      test('handles single byte gracefully', () {
        expect(SipCodec.decode(SipFuzzCases.oneByte), isNull);
      });

      test('handles magic-only (2 bytes) gracefully', () {
        expect(SipCodec.decode(SipFuzzCases.magicOnly), isNull);
      });

      test('handles invalid magic bytes', () {
        expect(SipCodec.decode(SipFuzzCases.invalidMagic), isNull);
      });

      test('handles truncated header', () {
        expect(SipCodec.decode(SipFuzzCases.truncatedHeader), isNull);
      });

      test('handles header_len < 22', () {
        expect(SipCodec.decode(SipFuzzCases.headerLenTooSmall), isNull);
      });

      test('handles header_len > data length', () {
        expect(SipCodec.decode(SipFuzzCases.headerLenExceedsData), isNull);
      });

      test('handles payload_len > remaining bytes', () {
        expect(
          SipCodec.decode(SipFuzzCases.payloadLenExceedsRemaining),
          isNull,
        );
      });

      test('handles trailing bytes after payload (accepts valid portion)', () {
        // The frame is valid (22 bytes, payload_len=0), trailing bytes ignored.
        // decode uses headerLen + payloadLen, so the trailing bytes are not read.
        final frame = SipCodec.decode(SipFuzzCases.trailingBytesAfterPayload);
        expect(frame, isNotNull);
        expect(frame!.payloadLen, equals(0));
      });

      test('handles version_major=255 (unsupported)', () {
        expect(SipCodec.decode(SipFuzzCases.versionMajor255), isNull);
      });

      test('handles all-zero frame', () {
        // All-zero frame has magic 0x0000 (wrong), so should fail.
        expect(SipCodec.decode(SipFuzzCases.allZero), isNull);
      });

      test('handles max-size frame (237 bytes)', () {
        final frame = SipCodec.decode(SipFuzzCases.maxSize);
        expect(frame, isNotNull);
        expect(frame!.payloadLen, equals(SipConstants.sipMaxPayload));
      });

      test('handles frame exceeding MTU (238 bytes)', () {
        expect(SipCodec.decode(SipFuzzCases.exceedsMtu), isNull);
      });

      test('handles unknown msg_type', () {
        expect(SipCodec.decode(SipFuzzCases.unknownMsgType), isNull);
      });

      test('handles random bytes', () {
        expect(SipCodec.decode(SipFuzzCases.randomBytes), isNull);
      });
    });

    group('encode validation', () {
      test('rejects frame exceeding MTU', () {
        final payload = Uint8List(SipConstants.sipMaxPayload + 1);
        final frame = SipFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: SipMessageType.capBeacon,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: 0,
          timestampS: 0,
          payloadLen: payload.length,
          payload: payload,
        );
        expect(SipCodec.encode(frame), isNull);
      });
    });

    group('buildError', () {
      test('creates a valid ERROR frame', () {
        final errorFrame = SipCodec.buildError(
          errorCode: SipErrorCode.unsupportedVersion,
          refMsgType: SipMessageType.capBeacon.code,
        );
        expect(errorFrame.msgType, equals(SipMessageType.error));
        expect(errorFrame.flags, equals(SipFlags.isResponse));
        expect(errorFrame.payloadLen, equals(3));
        expect(
          errorFrame.payload[0],
          equals(SipErrorCode.unsupportedVersion.code),
        );
        expect(errorFrame.payload[1], equals(SipMessageType.capBeacon.code));

        // Round-trip the error frame.
        final encoded = SipCodec.encode(errorFrame);
        expect(encoded, isNotNull);
        final decoded = SipCodec.decode(encoded!);
        expect(decoded, isNotNull);
        expect(decoded!.msgType, equals(SipMessageType.error));
      });
    });

    group('version negotiation', () {
      test('accepts version 0.0', () {
        final data = Uint8List.fromList(SipTestVectors.rollcallReq);
        data[2] = 0; // major
        data[3] = 0; // minor
        expect(SipCodec.decode(data), isNotNull);
      });

      test('accepts version 0.1', () {
        expect(SipCodec.decode(SipTestVectors.rollcallReq), isNotNull);
      });

      test('accepts version 0.2 (future minor)', () {
        final data = Uint8List.fromList(SipTestVectors.rollcallReq);
        data[3] = 2; // minor = 2
        expect(SipCodec.decode(data), isNotNull);
      });

      test('rejects version 1.0 (future major)', () {
        final data = Uint8List.fromList(SipTestVectors.rollcallReq);
        data[2] = 1; // major = 1
        expect(SipCodec.decode(data), isNull);
      });
    });

    group('constants validation', () {
      test('SIP_MTU_APP matches SmPayloadLimit.loraMtu', () {
        expect(SipConstants.sipMtuApp, equals(237));
      });

      test('SIP_CHUNK_SIZE is computed correctly', () {
        expect(SipConstants.sipChunkSize, equals(207));
        expect(
          SipConstants.sipChunkSize,
          equals(
            SipConstants.sipMtuApp -
                SipConstants.sipWrapperMin -
                SipConstants.sipTxChunkHeader,
          ),
        );
      });

      test('SIP_MAX_PAYLOAD is computed correctly', () {
        expect(SipConstants.sipMaxPayload, equals(215));
        expect(
          SipConstants.sipMaxPayload,
          equals(SipConstants.sipMtuApp - SipConstants.sipWrapperMin),
        );
      });

      test('SIP_MAX_SIGNED_PAYLOAD is computed correctly', () {
        expect(SipConstants.sipMaxSignedPayload, equals(149));
      });
    });
  });
}
