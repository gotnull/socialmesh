// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_meetup.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

/// Deterministic random for repeatable tests.
class _FakeRandom implements Random {
  int _counter = 0;

  @override
  int nextInt(int max) => (_counter++) % max;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}

MrrpFrame _makeRequest({
  required int actionId,
  Uint8List? payload,
  int requestId = 0x0001,
}) {
  final p = payload ?? Uint8List(0);
  return MrrpFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: MrrpMessageType.request,
    flags: 0,
    headerLen: 20,
    requestId: requestId,
    serviceId: MrrpServiceId.meetupV1,
    actionId: actionId,
    payloadLen: p.length,
    payload: p,
  );
}

void main() {
  late MrrpServiceMeetup handler;
  late DateTime fakeNow;

  setUp(() {
    fakeNow = DateTime(2025, 7, 1, 12, 0, 0);
    handler = MrrpServiceMeetup(random: _FakeRandom(), clock: () => fakeNow);
  });

  test('serviceId and supportedActions', () {
    expect(handler.serviceId, MrrpServiceId.meetupV1);
    expect(handler.supportedActions, contains(MeetupAction.create));
    expect(handler.supportedActions, contains(MeetupAction.accept));
    expect(handler.supportedActions, contains(MeetupAction.cancel));
    expect(handler.supportedActions, contains(MeetupAction.inspect));
  });

  group('create', () {
    test('creates token successfully', () async {
      // intent=social(2), ttl=600s.
      final payload = Uint8List(3);
      payload[0] = MeetupIntentType.social.code;
      ByteData.sublistView(payload).setUint16(1, 600, Endian.little);

      final request = _makeRequest(
        actionId: MeetupAction.create,
        payload: payload,
      );
      final response = await handler.handleRequest(request, 0xABCD);

      expect(response.msgType, MrrpMessageType.response);
      expect(response.requestId, 0x0001);
      expect(response.payloadLen, 13);

      // Parse response: token_id(8) + state(1) + intent(1) + ttl_s(2) + party_count(1).
      expect(response.payload[8], MeetupTokenState.pending.code);
      expect(response.payload[9], MeetupIntentType.social.code);
      final ttl = ByteData.sublistView(
        response.payload,
      ).getUint16(10, Endian.little);
      expect(ttl, 600);
      expect(response.payload[12], 1); // party_count starts at 1
    });

    test('max 8 active meetups returns BUSY', () async {
      final payload = Uint8List(3);
      payload[0] = 0;
      ByteData.sublistView(payload).setUint16(1, 600, Endian.little);

      // Create 8 tokens.
      for (var i = 0; i < 8; i++) {
        final request = _makeRequest(
          actionId: MeetupAction.create,
          payload: payload,
          requestId: i,
        );
        final response = await handler.handleRequest(request, 0xABCD);
        expect(response.msgType, MrrpMessageType.response);
      }

      // 9th should return BUSY.
      final request = _makeRequest(
        actionId: MeetupAction.create,
        payload: payload,
        requestId: 99,
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.busy.code);
    });

    test('TTL clamped to max 3600s', () async {
      final payload = Uint8List(3);
      payload[0] = 0;
      // Request 10000s - should be clamped to 3600.
      ByteData.sublistView(payload).setUint16(1, 10000, Endian.little);

      final request = _makeRequest(
        actionId: MeetupAction.create,
        payload: payload,
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);
      final ttl = ByteData.sublistView(
        response.payload,
      ).getUint16(10, Endian.little);
      expect(ttl, 3600);
    });
  });

  group('accept', () {
    late Uint8List tokenId;

    setUp(() async {
      // Create a token first.
      final payload = Uint8List(3);
      payload[0] = 0;
      ByteData.sublistView(payload).setUint16(1, 600, Endian.little);

      final request = _makeRequest(
        actionId: MeetupAction.create,
        payload: payload,
      );
      final response = await handler.handleRequest(request, 0xABCD);
      tokenId = Uint8List.fromList(response.payload.sublist(0, 8));
    });

    test('accept increments party count', () async {
      final request = _makeRequest(
        actionId: MeetupAction.accept,
        payload: tokenId,
        requestId: 0x0002,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payload[8], MeetupTokenState.accepted.code);
      expect(response.payload[12], 2); // party_count = 2
    });

    test('accept non-existent token returns NOT_FOUND', () async {
      final fakeToken = Uint8List.fromList([
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
      ]);
      final request = _makeRequest(
        actionId: MeetupAction.accept,
        payload: fakeToken,
        requestId: 0x0002,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.notFound.code);
    });

    test('accept expired token returns EXPIRED', () async {
      // Advance clock past TTL.
      fakeNow = fakeNow.add(const Duration(seconds: 601));
      final request = _makeRequest(
        actionId: MeetupAction.accept,
        payload: tokenId,
        requestId: 0x0002,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.expired.code);
    });

    test('accept with too-short payload returns INVALID', () async {
      final request = _makeRequest(
        actionId: MeetupAction.accept,
        payload: Uint8List.fromList([0x01, 0x02]),
        requestId: 0x0002,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.invalid.code);
    });
  });

  group('cancel', () {
    late Uint8List tokenId;

    setUp(() async {
      final payload = Uint8List(3);
      payload[0] = 0;
      ByteData.sublistView(payload).setUint16(1, 600, Endian.little);

      final request = _makeRequest(
        actionId: MeetupAction.create,
        payload: payload,
      );
      final response = await handler.handleRequest(request, 0xABCD);
      tokenId = Uint8List.fromList(response.payload.sublist(0, 8));
    });

    test('cancel marks token as cancelled', () async {
      final request = _makeRequest(
        actionId: MeetupAction.cancel,
        payload: tokenId,
        requestId: 0x0003,
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payload[8], MeetupTokenState.cancelled.code);
    });

    test('accept after cancel returns EXPIRED', () async {
      // Cancel first.
      final cancelReq = _makeRequest(
        actionId: MeetupAction.cancel,
        payload: tokenId,
        requestId: 0x0003,
      );
      await handler.handleRequest(cancelReq, 0xABCD);

      // Accept should fail.
      final acceptReq = _makeRequest(
        actionId: MeetupAction.accept,
        payload: tokenId,
        requestId: 0x0004,
      );
      final response = await handler.handleRequest(acceptReq, 0xBEEF);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.expired.code);
    });
  });

  group('inspect', () {
    late Uint8List tokenId;

    setUp(() async {
      final payload = Uint8List(3);
      payload[0] = MeetupIntentType.emergency.code;
      ByteData.sublistView(payload).setUint16(1, 300, Endian.little);

      final request = _makeRequest(
        actionId: MeetupAction.create,
        payload: payload,
      );
      final response = await handler.handleRequest(request, 0xABCD);
      tokenId = Uint8List.fromList(response.payload.sublist(0, 8));
    });

    test('inspect returns current token state', () async {
      final request = _makeRequest(
        actionId: MeetupAction.inspect,
        payload: tokenId,
        requestId: 0x0005,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payload[8], MeetupTokenState.pending.code);
      expect(response.payload[9], MeetupIntentType.emergency.code);
      expect(response.payload[12], 1);
    });

    test('inspect expired token shows expired state', () async {
      fakeNow = fakeNow.add(const Duration(seconds: 301));
      final request = _makeRequest(
        actionId: MeetupAction.inspect,
        payload: tokenId,
        requestId: 0x0005,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payload[8], MeetupTokenState.expired.code);
    });
  });
}
