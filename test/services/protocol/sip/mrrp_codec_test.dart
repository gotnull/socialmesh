// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';

import '../../../fixtures/sip/mrrp_fuzz_cases.dart';
import '../../../fixtures/sip/mrrp_test_vectors.dart';

void main() {
  group('MrrpCodec', () {
    group('isMrrpPayload', () {
      test('returns true for valid MRRP magic bytes', () {
        expect(MrrpCodec.isMrrpPayload(MrrpTestVectors.serviceAdvert), isTrue);
        expect(MrrpCodec.isMrrpPayload(MrrpTestVectors.request), isTrue);
        expect(MrrpCodec.isMrrpPayload(MrrpTestVectors.response), isTrue);
      });

      test('returns false for non-MRRP payloads', () {
        expect(MrrpCodec.isMrrpPayload(Uint8List(0)), isFalse);
        expect(MrrpCodec.isMrrpPayload(Uint8List.fromList([0x4D])), isFalse);
        expect(
          MrrpCodec.isMrrpPayload(Uint8List.fromList([0xDE, 0xAD])),
          isFalse,
        );
        // SIP magic bytes are not MRRP
        expect(
          MrrpCodec.isMrrpPayload(Uint8List.fromList([0x53, 0x4D])),
          isFalse,
        );
      });
    });

    group('decode test vectors', () {
      test('decodes SERVICE_ADVERT', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.serviceAdvert);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.serviceAdvertFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.flags, f.flags);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.serviceId, f.serviceId);
        expect(frame.actionId, f.actionId);
        expect(frame.payloadLen, f.payloadLen);
        // First byte of payload is service_count
        expect(frame.payload[0], f.serviceCount);
      });

      test('decodes SERVICE_DIR_REQ', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.serviceDirReq);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.serviceDirReqFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.flags, f.flags);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.serviceId, f.serviceId);
        expect(frame.actionId, f.actionId);
        expect(frame.payloadLen, f.payloadLen);
        expect(frame.ackRequired, isTrue);
      });

      test('decodes SERVICE_DIR_RESP', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.serviceDirResp);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.serviceDirRespFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.flags, f.flags);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.payloadLen, f.payloadLen);
        expect(frame.isResponse, isTrue);
        expect(frame.payload[0], f.serviceCount);
      });

      test('decodes REQUEST', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.request);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.requestFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.flags, f.flags);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.serviceId, f.serviceId);
        expect(frame.actionId, f.actionId);
        expect(frame.payloadLen, f.payloadLen);
        expect(frame.ackRequired, isTrue);
        // Payload: DE AD BE EF
        expect(frame.payload, orderedEquals([0xDE, 0xAD, 0xBE, 0xEF]));
      });

      test('decodes RESPONSE', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.response);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.responseFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.flags, f.flags);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.serviceId, f.serviceId);
        expect(frame.actionId, f.actionId);
        expect(frame.payloadLen, f.payloadLen);
        expect(frame.isResponse, isTrue);
        expect(frame.payload, orderedEquals([0xDE, 0xAD, 0xBE, 0xEF]));
      });

      test('decodes ERROR with TLV status_code', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.error);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.errorFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.flags, f.flags);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.payloadLen, f.payloadLen);
        expect(frame.isResponse, isTrue);
        expect(frame.isError, isTrue);
        // TLV: status_code
        expect(frame.headerExtensions.length, 1);
        final tlv = frame.findExtension(MrrpTlvType.statusCode);
        expect(tlv, isNotNull);
        expect(tlv!.value[0], f.statusCode);
      });

      test('decodes CANCEL', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.cancel);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.cancelFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.flags, f.flags);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.serviceId, f.serviceId);
        expect(frame.actionId, f.actionId);
        expect(frame.payloadLen, f.payloadLen);
      });

      test('decodes REQUEST with TLV header extension', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.requestWithTlv);
        expect(frame, isNotNull);
        final f = MrrpTestVectors.requestWithTlvFields;
        expect(frame!.versionMajor, f.versionMajor);
        expect(frame.versionMinor, f.versionMinor);
        expect(frame.msgType.code, f.msgTypeCode);
        expect(frame.headerLen, f.headerLen);
        expect(frame.requestId, f.requestId);
        expect(frame.serviceId, f.serviceId);
        expect(frame.actionId, f.actionId);
        expect(frame.payloadLen, f.payloadLen);
        expect(frame.headerExtensions.length, f.tlvCount);
        // Request TTL TLV
        final ttlTlv = frame.findExtension(MrrpTlvType.requestTtlS);
        expect(ttlTlv, isNotNull);
        final ttlValue = ByteData.sublistView(
          ttlTlv!.value,
        ).getUint16(0, Endian.little);
        expect(ttlValue, f.tlvRequestTtlS);
      });
    });

    group('encode/decode round-trip', () {
      test('minimal frame round-trips correctly', () {
        final original = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x1234,
          serviceId: MrrpServiceId.echoTest,
          actionId: EchoAction.echo,
          payloadLen: 4,
          payload: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
        );

        final encoded = MrrpCodec.encode(original);
        expect(encoded, isNotNull);
        expect(encoded!.length, MrrpConstants.mrrpHeaderMin + 4);

        final decoded = MrrpCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.versionMajor, original.versionMajor);
        expect(decoded.versionMinor, original.versionMinor);
        expect(decoded.msgType, original.msgType);
        expect(decoded.flags, original.flags);
        expect(decoded.requestId, original.requestId);
        expect(decoded.serviceId, original.serviceId);
        expect(decoded.actionId, original.actionId);
        expect(decoded.payloadLen, original.payloadLen);
        expect(decoded.payload, orderedEquals(original.payload));
      });

      test('frame with TLV extensions round-trips correctly', () {
        final ttlBytes = Uint8List(2);
        ByteData.sublistView(ttlBytes).setUint16(0, 15, Endian.little);

        final original = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen:
              MrrpConstants.mrrpHeaderMin + 4, // TLV: type(1)+len(1)+value(2)
          requestId: 0x07,
          serviceId: MrrpServiceId.meetupV1,
          actionId: MeetupAction.create,
          payloadLen: 0,
          headerExtensions: [
            MrrpTlvEntry(type: MrrpTlvType.requestTtlS.code, value: ttlBytes),
          ],
          payload: Uint8List(0),
        );

        final encoded = MrrpCodec.encode(original);
        expect(encoded, isNotNull);
        expect(encoded!.length, MrrpConstants.mrrpHeaderMin + 4);

        final decoded = MrrpCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.headerExtensions.length, 1);
        expect(
          decoded.headerExtensions.first.type,
          MrrpTlvType.requestTtlS.code,
        );
        final ttlValue = ByteData.sublistView(
          decoded.headerExtensions.first.value,
        ).getUint16(0, Endian.little);
        expect(ttlValue, 15);
      });

      test('empty payload round-trips correctly', () {
        final original = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.cancel,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x42,
          serviceId: MrrpServiceId.echoTest,
          actionId: EchoAction.echo,
          payloadLen: 0,
          payload: Uint8List(0),
        );

        final encoded = MrrpCodec.encode(original);
        expect(encoded, isNotNull);
        expect(encoded!.length, MrrpConstants.mrrpHeaderMin);

        final decoded = MrrpCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.payloadLen, 0);
        expect(decoded.payload.isEmpty, isTrue);
      });

      test('max-size payload round-trips correctly', () {
        final payload = Uint8List(MrrpConstants.mrrpMaxPayload);
        for (var i = 0; i < payload.length; i++) {
          payload[i] = i & 0xFF;
        }

        final original = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.response,
          flags: MrrpFlags.isResponse,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0xFFFF,
          serviceId: MrrpServiceId.boardV1,
          actionId: BoardAction.listRecent,
          payloadLen: payload.length,
          payload: payload,
        );

        final encoded = MrrpCodec.encode(original);
        expect(encoded, isNotNull);
        expect(encoded!.length, SipConstants.sipMaxPayload);

        final decoded = MrrpCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.payloadLen, MrrpConstants.mrrpMaxPayload);
        expect(decoded.payload, orderedEquals(payload));
      });

      test('all message types round-trip', () {
        for (final msgType in MrrpMessageType.values) {
          if (msgType == MrrpMessageType.eventReserved) continue;
          final frame = MrrpFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: msgType,
            flags: 0,
            headerLen: MrrpConstants.mrrpHeaderMin,
            requestId: msgType.code,
            serviceId: MrrpServiceId.echoTest,
            actionId: 0,
            payloadLen: 0,
            payload: Uint8List(0),
          );
          final encoded = MrrpCodec.encode(frame);
          expect(encoded, isNotNull, reason: 'encode ${msgType.name}');
          final decoded = MrrpCodec.decode(encoded!);
          expect(decoded, isNotNull, reason: 'decode ${msgType.name}');
          expect(decoded!.msgType, msgType, reason: 'type ${msgType.name}');
        }
      });
    });

    group('encode rejects oversized frames', () {
      test('rejects payload exceeding MRRP_MAX_PAYLOAD', () {
        final payload = Uint8List(MrrpConstants.mrrpMaxPayload + 1);
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 1,
          serviceId: 1,
          actionId: 1,
          payloadLen: payload.length,
          payload: payload,
        );
        expect(MrrpCodec.encode(frame), isNull);
      });
    });

    group('decode rejects invalid frames', () {
      test('rejects empty input', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.empty), isNull);
      });

      test('rejects single byte', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.oneByte), isNull);
      });

      test('rejects magic-only input', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.magicOnly), isNull);
      });

      test('rejects truncated header', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.truncatedHeader), isNull);
      });

      test('rejects header_len too small', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.headerLenTooSmall), isNull);
      });

      test('rejects header_len exceeds data', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.headerLenExceedsData), isNull);
      });

      test('rejects payload_len exceeds remaining', () {
        expect(
          MrrpCodec.decode(MrrpFuzzCases.payloadLenExceedsRemaining),
          isNull,
        );
      });

      test('rejects version_major 255', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.versionMajor255), isNull);
      });

      test('rejects all-zero frame (wrong magic)', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.allZero), isNull);
      });

      test('rejects magic in wrong position', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.magicInsideNonMrrp), isNull);
      });

      test('rejects unknown message type', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.unknownMsgType), isNull);
      });

      test('rejects frame exceeding SIP_MAX_PAYLOAD', () {
        expect(MrrpCodec.decode(MrrpFuzzCases.exceedsSipMtu), isNull);
      });

      test('decodes valid max-size frame', () {
        // This is a valid frame that fills SIP_MAX_PAYLOAD exactly
        final frame = MrrpCodec.decode(MrrpFuzzCases.maxSizeFrame);
        expect(frame, isNotNull);
        expect(frame!.payloadLen, MrrpConstants.mrrpMaxPayload);
      });

      test('handles payload_len=0 with trailing bytes gracefully', () {
        // The codec should still decode the frame; trailing bytes are ignored
        final frame = MrrpCodec.decode(MrrpFuzzCases.payloadZeroWithTrailing);
        expect(frame, isNotNull);
        expect(frame!.payloadLen, 0);
      });
    });

    group('version negotiation', () {
      test('accepts version_major=0 version_minor=1', () {
        final frame = MrrpCodec.decode(MrrpTestVectors.request);
        expect(frame, isNotNull);
        expect(frame!.versionMajor, 0);
        expect(frame.versionMinor, 1);
      });

      test('accepts higher minor version (forward compatible)', () {
        final data = Uint8List.fromList(MrrpTestVectors.request);
        data[3] = 5; // version_minor = 5
        final frame = MrrpCodec.decode(data);
        expect(frame, isNotNull);
        expect(frame!.versionMinor, 5);
      });

      test('rejects version_major > 0', () {
        final data = Uint8List.fromList(MrrpTestVectors.request);
        data[2] = 1; // version_major = 1
        expect(MrrpCodec.decode(data), isNull);
      });
    });

    group('constants validation', () {
      test('MRRP_MAX_PAYLOAD derived correctly', () {
        expect(
          MrrpConstants.mrrpMaxPayload,
          SipConstants.sipMaxPayload - MrrpConstants.mrrpHeaderMin,
        );
        expect(MrrpConstants.mrrpMaxPayload, 195);
      });

      test('MRRP header min is 20', () {
        expect(MrrpConstants.mrrpHeaderMin, 20);
      });
    });

    group('MrrpFrame', () {
      test('flag getters work correctly', () {
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.error,
          flags: MrrpFlags.isResponse | MrrpFlags.isError,
          headerLen: 20,
          requestId: 1,
          serviceId: 1,
          actionId: 1,
          payloadLen: 0,
          payload: Uint8List(0),
        );
        expect(frame.ackRequired, isFalse);
        expect(frame.isResponse, isTrue);
        expect(frame.isError, isTrue);
      });

      test('findExtension returns null when no extensions', () {
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: 20,
          requestId: 1,
          serviceId: 1,
          actionId: 1,
          payloadLen: 0,
          payload: Uint8List(0),
        );
        expect(frame.findExtension(MrrpTlvType.statusCode), isNull);
      });

      test('serviceName returns known names', () {
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: 20,
          requestId: 1,
          serviceId: MrrpServiceId.meetupV1,
          actionId: 1,
          payloadLen: 0,
          payload: Uint8List(0),
        );
        expect(frame.serviceName, 'meetup.v1');
      });

      test('toString includes key info', () {
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: 20,
          requestId: 0x42,
          serviceId: MrrpServiceId.echoTest,
          actionId: EchoAction.echo,
          payloadLen: 4,
          payload: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
        );
        final str = frame.toString();
        expect(str, contains('request'));
        expect(str, contains('echo.test'));
        expect(str, contains('4 B'));
      });
    });

    group('MrrpMessageType', () {
      test('fromCode returns correct types', () {
        expect(MrrpMessageType.fromCode(0x01), MrrpMessageType.serviceAdvert);
        expect(MrrpMessageType.fromCode(0x10), MrrpMessageType.request);
        expect(MrrpMessageType.fromCode(0x11), MrrpMessageType.response);
        expect(MrrpMessageType.fromCode(0x12), MrrpMessageType.error);
        expect(MrrpMessageType.fromCode(0x13), MrrpMessageType.cancel);
      });

      test('fromCode returns null for unknown codes', () {
        expect(MrrpMessageType.fromCode(0x00), isNull);
        expect(MrrpMessageType.fromCode(0xFF), isNull);
      });
    });

    group('MrrpStatusCode', () {
      test('fromCode returns correct codes', () {
        expect(MrrpStatusCode.fromCode(0), MrrpStatusCode.ok);
        expect(MrrpStatusCode.fromCode(1), MrrpStatusCode.notFound);
        expect(MrrpStatusCode.fromCode(4), MrrpStatusCode.timeout);
        expect(MrrpStatusCode.fromCode(7), MrrpStatusCode.rateLimited);
        expect(MrrpStatusCode.fromCode(10), MrrpStatusCode.internal);
      });

      test('fromCode returns null for unknown codes', () {
        expect(MrrpStatusCode.fromCode(11), isNull);
        expect(MrrpStatusCode.fromCode(255), isNull);
      });
    });

    group('MrrpTlvType', () {
      test('fromCode returns correct types', () {
        expect(MrrpTlvType.fromCode(0x01), MrrpTlvType.senderPubkeyHint);
        expect(MrrpTlvType.fromCode(0x02), MrrpTlvType.requestTtlS);
        expect(MrrpTlvType.fromCode(0x05), MrrpTlvType.statusCode);
      });

      test('fromCode returns null for unknown types', () {
        expect(MrrpTlvType.fromCode(0x00), isNull);
        expect(MrrpTlvType.fromCode(0xFF), isNull);
      });
    });

    group('MrrpServiceId', () {
      test('nameOf returns known names', () {
        expect(MrrpServiceId.nameOf(MrrpServiceId.meetupV1), 'meetup.v1');
        expect(MrrpServiceId.nameOf(MrrpServiceId.profileV1), 'profile.v1');
        expect(MrrpServiceId.nameOf(MrrpServiceId.boardV1), 'board.v1');
        expect(MrrpServiceId.nameOf(MrrpServiceId.echoTest), 'echo.test');
      });

      test('nameOf returns hex for unknown IDs', () {
        expect(MrrpServiceId.nameOf(0xDEAD0000), '0xdead0000');
      });
    });

    group('all fuzz cases handled gracefully', () {
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
          MrrpFuzzCases.magicInsideNonMrrp,
          MrrpFuzzCases.unknownMsgType,
          MrrpFuzzCases.exceedsSipMtu,
          MrrpFuzzCases.maxSizeFrame,
        ];
        for (final data in cases) {
          // Should not throw — only return null or a valid frame
          expect(() => MrrpCodec.decode(data), returnsNormally);
        }
      });
    });
  });
}
