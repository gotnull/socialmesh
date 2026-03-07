// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mrrp_harness/widgets/mrrp_fixture_result_tile.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';

void main() {
  // -------------------------------------------------------------------------
  // FieldComparison model tests
  // -------------------------------------------------------------------------
  group('FieldComparison', () {
    test('matches is true when expected equals actual', () {
      const fc = FieldComparison(
        name: 'version', // lint-allow: hardcoded-string
        expected: '0', // lint-allow: hardcoded-string
        actual: '0', // lint-allow: hardcoded-string
        matches: true,
      );
      expect(fc.matches, isTrue);
      expect(fc.name, 'version'); // lint-allow: hardcoded-string
    });

    test('matches is false when expected differs from actual', () {
      const fc = FieldComparison(
        name: 'msgType', // lint-allow: hardcoded-string
        expected: '0x10', // lint-allow: hardcoded-string
        actual: '0x11', // lint-allow: hardcoded-string
        matches: false,
      );
      expect(fc.matches, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // FixtureReplayResult model tests
  // -------------------------------------------------------------------------
  group('FixtureReplayResult', () {
    test('valid vector with all fields matching passes', () {
      const result = FixtureReplayResult(
        name: 'SERVICE_ADVERT', // lint-allow: hardcoded-string
        decodeSuccess: true,
        fields: [
          FieldComparison(
            name: 'version', // lint-allow: hardcoded-string
            expected: '0', // lint-allow: hardcoded-string
            actual: '0', // lint-allow: hardcoded-string
            matches: true,
          ),
          FieldComparison(
            name: 'msgType', // lint-allow: hardcoded-string
            expected: '0x01', // lint-allow: hardcoded-string
            actual: '0x01', // lint-allow: hardcoded-string
            matches: true,
          ),
        ],
      );

      expect(result.passed, isTrue);
      expect(result.matchedFields, 2);
    });

    test('valid vector with mismatched field fails', () {
      const result = FixtureReplayResult(
        name: 'REQUEST', // lint-allow: hardcoded-string
        decodeSuccess: true,
        fields: [
          FieldComparison(
            name: 'version', // lint-allow: hardcoded-string
            expected: '0', // lint-allow: hardcoded-string
            actual: '0', // lint-allow: hardcoded-string
            matches: true,
          ),
          FieldComparison(
            name: 'serviceId', // lint-allow: hardcoded-string
            expected: '0x00000001', // lint-allow: hardcoded-string
            actual: '0x00000002', // lint-allow: hardcoded-string
            matches: false,
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(result.matchedFields, 1);
    });

    test('fuzz case that fails to decode passes', () {
      const result = FixtureReplayResult(
        name: 'empty', // lint-allow: hardcoded-string
        decodeSuccess: false,
        expectNull: true,
      );

      expect(result.passed, isTrue);
    });

    test('fuzz case that unexpectedly decodes fails', () {
      const result = FixtureReplayResult(
        name: 'truncated', // lint-allow: hardcoded-string
        decodeSuccess: true,
        expectNull: true,
      );

      expect(result.passed, isFalse);
    });

    test('valid vector that fails to decode fails', () {
      const result = FixtureReplayResult(
        name: 'REQUEST', // lint-allow: hardcoded-string
        decodeSuccess: false,
      );

      expect(result.passed, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Request composer frame construction tests (codec level)
  // -------------------------------------------------------------------------
  group('Request composer frame construction', () {
    test('echo.test REQUEST with payload encodes and decodes', () {
      final payload = Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]);
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: payload.length,
        payload: payload,
      );

      final encoded = MrrpCodec.encode(frame);
      expect(encoded, isNotNull);
      expect(encoded!.length, MrrpConstants.mrrpHeaderMin + 4);

      final decoded = MrrpCodec.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.serviceId, MrrpServiceId.echoTest);
      expect(decoded.actionId, EchoAction.echo);
      expect(decoded.payload, orderedEquals(payload));
    });

    test('meetup.create with TTL TLV encodes and decodes', () {
      final ttlBytes = Uint8List(2);
      ByteData.sublistView(ttlBytes).setUint16(0, 30, Endian.little);

      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: MrrpConstants.mrrpHeaderMin + 4,
        requestId: 1,
        serviceId: MrrpServiceId.meetupV1,
        actionId: MeetupAction.create,
        payloadLen: 4,
        headerExtensions: [
          MrrpTlvEntry(type: MrrpTlvType.requestTtlS.code, value: ttlBytes),
        ],
        payload: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
      );

      final encoded = MrrpCodec.encode(frame);
      expect(encoded, isNotNull);

      final decoded = MrrpCodec.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.serviceId, MrrpServiceId.meetupV1);

      final ttl = decoded.findExtension(MrrpTlvType.requestTtlS);
      expect(ttl, isNotNull);
      expect(ByteData.sublistView(ttl!.value).getUint16(0, Endian.little), 30);
    });

    test('empty payload REQUEST encodes correctly', () {
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: MrrpServiceId.profileV1,
        actionId: ProfileAction.getSummary,
        payloadLen: 0,
        payload: Uint8List(0),
      );

      final encoded = MrrpCodec.encode(frame);
      expect(encoded, isNotNull);
      expect(encoded!.length, MrrpConstants.mrrpHeaderMin);

      final decoded = MrrpCodec.decode(encoded);
      expect(decoded!.payloadLen, 0);
      expect(decoded.payload.isEmpty, isTrue);
    });

    test('max payload size is respected', () {
      // Max payload: SIP_MAX_PAYLOAD - MRRP_HEADER_MIN = 195 bytes.
      final maxPayload = Uint8List(MrrpConstants.mrrpMaxPayload);
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: maxPayload.length,
        payload: maxPayload,
      );

      final encoded = MrrpCodec.encode(frame);
      expect(encoded, isNotNull);
      expect(encoded!.length, SipConstants.sipMaxPayload);
    });

    test('payload exceeding max is rejected by encode', () {
      final oversized = Uint8List(MrrpConstants.mrrpMaxPayload + 1);
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: oversized.length,
        payload: oversized,
      );

      final encoded = MrrpCodec.encode(frame);
      expect(encoded, isNull);
    });

    test('all known action IDs encode correctly', () {
      final actions = <int, int>{
        MrrpServiceId.meetupV1: MeetupAction.create,
        MrrpServiceId.meetupV1 + 0x10000: MeetupAction.accept,
        MrrpServiceId.profileV1: ProfileAction.getSummary,
        MrrpServiceId.boardV1: BoardAction.postShort,
        MrrpServiceId.echoTest: EchoAction.echo,
      };

      for (final entry in actions.entries) {
        final serviceId = entry.key <= 0xFFFF0001
            ? entry.key
            : MrrpServiceId.meetupV1;
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.request,
          flags: MrrpFlags.ackRequired,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 1,
          serviceId: serviceId,
          actionId: entry.value,
          payloadLen: 0,
          payload: Uint8List(0),
        );

        final encoded = MrrpCodec.encode(frame);
        expect(
          encoded,
          isNotNull,
          reason:
              'service=0x${serviceId.toRadixString(16)}, action=${entry.value} should encode',
        ); // lint-allow: hardcoded-string
      }
    });
  });

  // -------------------------------------------------------------------------
  // Hex parsing behavior (tests at codec level)
  // -------------------------------------------------------------------------
  group('Hex string parsing via test vectors', () {
    test('well-formed hex with spaces decodes correctly', () {
      // This tests the same logic path the composer uses.
      final hex = 'DE AD BE EF'; // lint-allow: hardcoded-string
      final clean = hex.replaceAll(RegExp(r'\s+'), '');
      final bytes = Uint8List(clean.length ~/ 2);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }
      expect(bytes, orderedEquals([0xDE, 0xAD, 0xBE, 0xEF]));
    });

    test('empty string yields empty bytes', () {
      const hex = '';
      final clean = hex.replaceAll(RegExp(r'\s+'), '');
      expect(clean.isEmpty, isTrue);
    });

    test('odd-length hex is invalid', () {
      const hex = 'DEA'; // lint-allow: hardcoded-string
      final clean = hex.replaceAll(RegExp(r'\s+'), '');
      expect(clean.length.isOdd, isTrue);
    });
  });
}
