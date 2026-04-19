// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

void main() {
  group('MRRP multi-step service flows (codec level)', () {
    // -----------------------------------------------------------------------
    // Discovery → Directory → Profile request flow
    // -----------------------------------------------------------------------
    group('discovery → directory → profile request', () {
      test('SERVICE_ADVERT encodes with service descriptors', () {
        // Peer advertises meetup.v1 + profile.v1.
        final payload = Uint8List.fromList([
          0x02, // service_count = 2
          // meetup.v1 descriptor (10 bytes min)
          0x01, 0x00, 0x00, 0x00, // service_id = 0x00000001
          0x00, // service_type = app
          0x00, 0x01, // version 0.1
          0x0C, 0x00, // flags: request+response
          0x00, // metadata_len = 0
          // profile.v1 descriptor
          0x02, 0x00, 0x00, 0x00, // service_id = 0x00000002
          0x00, // service_type = app
          0x00, 0x01, // version 0.1
          0x0C, 0x00, // flags: request+response
          0x00, // metadata_len = 0
        ]);

        final advert = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.serviceAdvert,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0,
          serviceId: 0,
          actionId: 0,
          payloadLen: payload.length,
          payload: payload,
        );

        final encoded = MrrpCodec.encode(advert);
        expect(encoded, isNotNull);

        final decoded = MrrpCodec.decode(encoded!);
        expect(decoded, isNotNull);
        expect(decoded!.msgType, MrrpMessageType.serviceAdvert);
        expect(decoded.payload[0], 2); // 2 services
      });

      test('SERVICE_DIR_REQ → SERVICE_DIR_RESP preserves request_id', () {
        const reqId = 0x0042;

        // Directory request.
        final dirReq = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.serviceDirReq,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: reqId,
          serviceId: 0,
          actionId: 0,
          payloadLen: 0,
          payload: Uint8List(0),
        );

        final encodedReq = MrrpCodec.encode(dirReq);
        expect(encodedReq, isNotNull);

        // Directory response with one service.
        final dirPayload = Uint8List.fromList([
          0x01, // service_count = 1
          0x02, 0x00, 0x00, 0x00, // profile.v1
          0x00, 0x00, 0x01, 0x0C, 0x00, 0x00,
        ]);

        final dirResp = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.serviceDirResp,
          flags: MrrpFlags.isResponse,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: reqId,
          serviceId: 0,
          actionId: 0,
          payloadLen: dirPayload.length,
          payload: dirPayload,
        );

        final encodedResp = MrrpCodec.encode(dirResp);
        expect(encodedResp, isNotNull);

        // Verify request_id correlation.
        final decodedReq = MrrpCodec.decode(encodedReq!);
        final decodedResp = MrrpCodec.decode(encodedResp!);
        expect(decodedReq!.requestId, reqId);
        expect(decodedResp!.requestId, reqId);
        expect(decodedResp.isResponse, isTrue);
      });

      test('profile.v1 getSummary REQUEST → RESPONSE round-trip', () {
        const reqId = 0x0043;

        final request = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: reqId,
          serviceId: MrrpServiceId.profileV1,
          actionId: ProfileAction.getSummary,
          payloadLen: 0,
          payload: Uint8List(0),
        );

        final response = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.response,
          flags: MrrpFlags.isResponse,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: reqId,
          serviceId: MrrpServiceId.profileV1,
          actionId: ProfileAction.getSummary,
          payloadLen: 8,
          payload: Uint8List.fromList([
            0x01,
            0x02,
            0x03,
            0x04,
            0x05,
            0x06,
            0x07,
            0x08,
          ]),
        );

        final encReq = MrrpCodec.encode(request);
        final encResp = MrrpCodec.encode(response);
        expect(encReq, isNotNull);
        expect(encResp, isNotNull);

        final decReq = MrrpCodec.decode(encReq!);
        final decResp = MrrpCodec.decode(encResp!);
        expect(decReq!.serviceId, MrrpServiceId.profileV1);
        expect(decResp!.serviceId, MrrpServiceId.profileV1);
        expect(decReq.actionId, ProfileAction.getSummary);
        expect(decResp.actionId, ProfileAction.getSummary);
        expect(decResp.requestId, decReq.requestId);
      });
    });

    // -----------------------------------------------------------------------
    // Meetup create → accept → inspect → cancel flow
    // -----------------------------------------------------------------------
    group('meetup flow: create → accept → inspect → cancel', () {
      test('meetup.create REQUEST encodes correctly', () {
        final payload = Uint8List.fromList([
          0x01, // intent_type = emergency
          0x00, 0x3C, // ttl_seconds = 60 (BE for payload)
          0x41, 0x42, 0x43, 0x44, // token: "ABCD"
        ]);

        final request = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x0100,
          serviceId: MrrpServiceId.meetupV1,
          actionId: MeetupAction.create,
          payloadLen: payload.length,
          payload: payload,
        );

        final encoded = MrrpCodec.encode(request);
        expect(encoded, isNotNull);

        final decoded = MrrpCodec.decode(encoded!);
        expect(decoded!.serviceId, MrrpServiceId.meetupV1);
        expect(decoded.actionId, MeetupAction.create);
        expect(decoded.payload, payload);
      });

      test('meetup.accept REQUEST preserves request context', () {
        final request = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x0101,
          serviceId: MrrpServiceId.meetupV1,
          actionId: MeetupAction.accept,
          payloadLen: 4,
          payload: Uint8List.fromList([0x41, 0x42, 0x43, 0x44]),
        );

        final encoded = MrrpCodec.encode(request)!;
        final decoded = MrrpCodec.decode(encoded)!;
        expect(decoded.actionId, MeetupAction.accept);
        expect(decoded.requestId, 0x0101);
      });

      test('meetup.cancel terminates session', () {
        final cancel = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.cancel,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x0100,
          serviceId: MrrpServiceId.meetupV1,
          actionId: MeetupAction.cancel,
          payloadLen: 0,
          payload: Uint8List(0),
        );

        final encoded = MrrpCodec.encode(cancel)!;
        final decoded = MrrpCodec.decode(encoded)!;
        expect(decoded.msgType, MrrpMessageType.cancel);
        expect(decoded.serviceId, MrrpServiceId.meetupV1);
        expect(decoded.actionId, MeetupAction.cancel);
      });
    });

    // -----------------------------------------------------------------------
    // Board post → list → get_post flow
    // -----------------------------------------------------------------------
    group('board flow: post → list → get_post', () {
      test('board.postShort REQUEST with message payload', () {
        final message = Uint8List.fromList(
          'Hello mesh!'.codeUnits, // lint-allow: hardcoded-string
        );

        final request = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x0200,
          serviceId: MrrpServiceId.boardV1,
          actionId: BoardAction.postShort,
          payloadLen: message.length,
          payload: message,
        );

        final encoded = MrrpCodec.encode(request)!;
        final decoded = MrrpCodec.decode(encoded)!;
        expect(decoded.serviceId, MrrpServiceId.boardV1);
        expect(decoded.actionId, BoardAction.postShort);
        expect(decoded.payload, message);
      });

      test('board.listRecent returns list payload', () {
        // Simulated response: 3 post stubs (just IDs for brevity).
        final listPayload = Uint8List.fromList([
          0x03, // count
          0x01, 0x00, 0x00, 0x00, // post_id 1
          0x02, 0x00, 0x00, 0x00, // post_id 2
          0x03, 0x00, 0x00, 0x00, // post_id 3
        ]);

        final response = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.response,
          flags: MrrpFlags.isResponse,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x0201,
          serviceId: MrrpServiceId.boardV1,
          actionId: BoardAction.listRecent,
          payloadLen: listPayload.length,
          payload: listPayload,
        );

        final encoded = MrrpCodec.encode(response)!;
        final decoded = MrrpCodec.decode(encoded)!;
        expect(decoded.isResponse, isTrue);
        expect(decoded.payload[0], 3);
      });

      test('board.getPost returns full post content', () {
        final postContent = Uint8List.fromList([
          0x01, 0x00, 0x00, 0x00, // post_id
          ...('Test post'.codeUnits), // lint-allow: hardcoded-string
        ]);

        final response = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.response,
          flags: MrrpFlags.isResponse,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0x0202,
          serviceId: MrrpServiceId.boardV1,
          actionId: BoardAction.getPost,
          payloadLen: postContent.length,
          payload: postContent,
        );

        final encoded = MrrpCodec.encode(response)!;
        final decoded = MrrpCodec.decode(encoded)!;
        expect(decoded.actionId, BoardAction.getPost);
        expect(decoded.payload, postContent);
      });
    });

    // -----------------------------------------------------------------------
    // Error flow: REQUEST → ERROR with status code
    // -----------------------------------------------------------------------
    group('error flows', () {
      test('NOT_FOUND error preserves status in TLV', () {
        final error = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.error,
          flags: MrrpFlags.isResponse | MrrpFlags.isError,
          headerLen: MrrpConstants.mrrpHeaderMin + 3,
          requestId: 0x0300,
          serviceId: MrrpServiceId.meetupV1,
          actionId: MeetupAction.inspect,
          payloadLen: 0,
          headerExtensions: [
            MrrpTlvEntry(
              type: MrrpTlvType.statusCode.code,
              value: Uint8List.fromList([MrrpStatusCode.notFound.code]),
            ),
          ],
          payload: Uint8List(0),
        );

        final encoded = MrrpCodec.encode(error)!;
        final decoded = MrrpCodec.decode(encoded)!;
        expect(decoded.isError, isTrue);
        expect(decoded.isResponse, isTrue);

        final statusTlv = decoded.findExtension(MrrpTlvType.statusCode);
        expect(statusTlv, isNotNull);
        expect(
          MrrpStatusCode.fromCode(statusTlv!.value[0]),
          MrrpStatusCode.notFound,
        );
      });

      test('all status codes round-trip through ERROR frame', () {
        for (final status in MrrpStatusCode.values) {
          if (status == MrrpStatusCode.ok) continue; // ok is not an error

          final error = MrrpFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: MrrpMessageType.error,
            flags: MrrpFlags.isResponse | MrrpFlags.isError,
            headerLen: MrrpConstants.mrrpHeaderMin + 3,
            requestId: status.code + 0x1000,
            serviceId: MrrpServiceId.echoTest,
            actionId: EchoAction.echo,
            payloadLen: 0,
            headerExtensions: [
              MrrpTlvEntry(
                type: MrrpTlvType.statusCode.code,
                value: Uint8List.fromList([status.code]),
              ),
            ],
            payload: Uint8List(0),
          );

          final encoded = MrrpCodec.encode(error);
          expect(
            encoded,
            isNotNull,
            reason: '${status.name} should encode',
          ); // lint-allow: hardcoded-string

          final decoded = MrrpCodec.decode(encoded!);
          expect(
            decoded,
            isNotNull,
            reason: '${status.name} should decode',
          ); // lint-allow: hardcoded-string

          final tlv = decoded!.findExtension(MrrpTlvType.statusCode);
          expect(
            MrrpStatusCode.fromCode(tlv!.value[0]),
            status,
            reason:
                '${status.name} should survive round-trip', // lint-allow: hardcoded-string
          );
        }
      });
    });

    // -----------------------------------------------------------------------
    // TLV extensions in request context
    // -----------------------------------------------------------------------
    group('TLV header extensions in requests', () {
      test('request with TTL and pubkey hint', () {
        final ttlBytes = Uint8List(2);
        ByteData.sublistView(ttlBytes).setUint16(0, 30, Endian.little);

        final pubkeyHint = Uint8List.fromList([
          0x01,
          0x02,
          0x03,
          0x04,
          0x05,
          0x06,
          0x07,
          0x08,
        ]);

        // Two TLVs: requestTtlS (4 bytes) + pubkeyHint (10 bytes) = 14
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin + 14,
          requestId: 0x0400,
          serviceId: MrrpServiceId.profileV1,
          actionId: ProfileAction.getSummary,
          payloadLen: 0,
          headerExtensions: [
            MrrpTlvEntry(type: MrrpTlvType.requestTtlS.code, value: ttlBytes),
            MrrpTlvEntry(
              type: MrrpTlvType.senderPubkeyHint.code,
              value: pubkeyHint,
            ),
          ],
          payload: Uint8List(0),
        );

        final encoded = MrrpCodec.encode(frame);
        expect(encoded, isNotNull);

        final decoded = MrrpCodec.decode(encoded!);
        expect(decoded, isNotNull);
        expect(decoded!.headerExtensions.length, 2);

        final ttl = decoded.findExtension(MrrpTlvType.requestTtlS);
        expect(ttl, isNotNull);
        expect(
          ByteData.sublistView(ttl!.value).getUint16(0, Endian.little),
          30,
        );

        final pk = decoded.findExtension(MrrpTlvType.senderPubkeyHint);
        expect(pk, isNotNull);
        expect(pk!.value, pubkeyHint);
      });

      test('request with session tag hint', () {
        final sessionTag = Uint8List(4);
        ByteData.sublistView(
          sessionTag,
        ).setUint32(0, 0xDEADBEEF, Endian.little);

        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin + 6, // TLV: 1+1+4
          requestId: 0x0401,
          serviceId: MrrpServiceId.echoTest,
          actionId: EchoAction.echo,
          payloadLen: 0,
          headerExtensions: [
            MrrpTlvEntry(
              type: MrrpTlvType.sessionTagHint.code,
              value: sessionTag,
            ),
          ],
          payload: Uint8List(0),
        );

        final encoded = MrrpCodec.encode(frame)!;
        final decoded = MrrpCodec.decode(encoded)!;

        final tag = decoded.findExtension(MrrpTlvType.sessionTagHint);
        expect(tag, isNotNull);
        expect(
          ByteData.sublistView(tag!.value).getUint32(0, Endian.little),
          0xDEADBEEF,
        );
      });
    });

    // -----------------------------------------------------------------------
    // Service ID name resolution
    // -----------------------------------------------------------------------
    group('MrrpServiceId name resolution', () {
      test('known services resolve to human-readable names', () {
        expect(
          MrrpServiceId.nameOf(MrrpServiceId.meetupV1),
          'meetup.v1',
        ); // lint-allow: hardcoded-string
        expect(
          MrrpServiceId.nameOf(MrrpServiceId.profileV1),
          'profile.v1',
        ); // lint-allow: hardcoded-string
        expect(
          MrrpServiceId.nameOf(MrrpServiceId.boardV1),
          'board.v1',
        ); // lint-allow: hardcoded-string
        expect(
          MrrpServiceId.nameOf(MrrpServiceId.echoTest),
          'echo.test',
        ); // lint-allow: hardcoded-string
      });

      test('unknown service ID formats as hex', () {
        final name = MrrpServiceId.nameOf(0xDEADBEEF);
        expect(name, '0xdeadbeef'); // lint-allow: hardcoded-string
      });
    });
  });
}
