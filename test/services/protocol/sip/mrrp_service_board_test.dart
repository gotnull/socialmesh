// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_board.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

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
    serviceId: MrrpServiceId.boardV1,
    actionId: actionId,
    payloadLen: p.length,
    payload: p,
  );
}

Uint8List _makePostPayload(String text, {int ttlS = 3600}) {
  final textBytes = text.codeUnits;
  final payload = Uint8List(2 + textBytes.length);
  ByteData.sublistView(payload).setUint16(0, ttlS, Endian.little);
  payload.setRange(2, 2 + textBytes.length, textBytes);
  return payload;
}

void main() {
  late MrrpServiceBoard handler;
  late DateTime fakeNow;

  setUp(() {
    fakeNow = DateTime(2025, 7, 1, 12, 0, 0);
    handler = MrrpServiceBoard(clock: () => fakeNow);
  });

  test('serviceId and supportedActions', () {
    expect(handler.serviceId, MrrpServiceId.boardV1);
    expect(handler.supportedActions, contains(BoardAction.listRecent));
    expect(handler.supportedActions, contains(BoardAction.postShort));
    expect(handler.supportedActions, contains(BoardAction.getPost));
  });

  group('post_short', () {
    test('stores post and returns post_id', () async {
      final request = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload(
          'Hello mesh!',
        ), // lint-allow: hardcoded-string
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payloadLen, 4);

      final postId = ByteData.sublistView(
        response.payload,
      ).getUint32(0, Endian.little);
      expect(postId, greaterThan(0));
      expect(handler.postCount, 1);
    });

    test('text too short returns INVALID', () async {
      // Empty text (only TTL bytes).
      final request = _makeRequest(
        actionId: BoardAction.postShort,
        payload: Uint8List(2), // ttl_s only, no text
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.invalid.code);
    });

    test('text too long returns INVALID', () async {
      final request = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('A' * 81), // lint-allow: hardcoded-string
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.invalid.code);
    });

    test('rate limit: 1 post per 60s per peer', () async {
      // First post succeeds.
      final req1 = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('Post 1'), // lint-allow: hardcoded-string
        requestId: 1,
      );
      final resp1 = await handler.handleRequest(req1, 0xABCD);
      expect(resp1.msgType, MrrpMessageType.response);

      // Second post 30s later - rejected.
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      final req2 = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('Post 2'), // lint-allow: hardcoded-string
        requestId: 2,
      );
      final resp2 = await handler.handleRequest(req2, 0xABCD);
      expect(resp2.msgType, MrrpMessageType.error);
      expect(resp2.payload[0], MrrpStatusCode.rateLimited.code);

      // Third post 61s later - allowed.
      fakeNow = fakeNow.add(const Duration(seconds: 31));
      final req3 = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('Post 3'), // lint-allow: hardcoded-string
        requestId: 3,
      );
      final resp3 = await handler.handleRequest(req3, 0xABCD);
      expect(resp3.msgType, MrrpMessageType.response);
    });

    test('different peers are rate-limited independently', () async {
      final req1 = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('A post'), // lint-allow: hardcoded-string
        requestId: 1,
      );
      await handler.handleRequest(req1, 0xABCD);

      // Different peer can post immediately.
      final req2 = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload(
          'Another post',
        ), // lint-allow: hardcoded-string
        requestId: 2,
      );
      final resp2 = await handler.handleRequest(req2, 0xBEEF);
      expect(resp2.msgType, MrrpMessageType.response);
    });

    test('max 16 posts evicts oldest', () async {
      for (var i = 0; i < 16; i++) {
        // Advance clock to bypass rate limit.
        fakeNow = fakeNow.add(const Duration(seconds: 61));
        final req = _makeRequest(
          actionId: BoardAction.postShort,
          payload: _makePostPayload('Post $i'), // lint-allow: hardcoded-string
          requestId: i,
        );
        final resp = await handler.handleRequest(req, 0xABCD);
        expect(resp.msgType, MrrpMessageType.response);
      }
      expect(handler.postCount, 16);

      // 17th post evicts oldest.
      fakeNow = fakeNow.add(const Duration(seconds: 61));
      final req17 = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('Post 17'), // lint-allow: hardcoded-string
        requestId: 17,
      );
      final resp17 = await handler.handleRequest(req17, 0xABCD);
      expect(resp17.msgType, MrrpMessageType.response);
      expect(handler.postCount, 16);
    });
  });

  group('get_post', () {
    late int postId;

    setUp(() async {
      final request = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('Test post'), // lint-allow: hardcoded-string
      );
      final response = await handler.handleRequest(request, 0xABCD);
      postId = ByteData.sublistView(
        response.payload,
      ).getUint32(0, Endian.little);
    });

    test('returns post by ID', () async {
      final payload = Uint8List(4);
      ByteData.sublistView(payload).setUint32(0, postId, Endian.little);

      final request = _makeRequest(
        actionId: BoardAction.getPost,
        payload: payload,
        requestId: 0x0002,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.response);

      // Parse: post_id(4) + author_node_id(4) + text_len(1) + text.
      final bd = ByteData.sublistView(response.payload);
      expect(bd.getUint32(0, Endian.little), postId);
      expect(bd.getUint32(4, Endian.little), 0xABCD);
      final textLen = response.payload[8];
      final text = String.fromCharCodes(
        response.payload.sublist(9, 9 + textLen),
      );
      expect(text, 'Test post'); // lint-allow: hardcoded-string
    });

    test('non-existent post returns NOT_FOUND', () async {
      final payload = Uint8List(4);
      ByteData.sublistView(payload).setUint32(0, 0xDEAD, Endian.little);

      final request = _makeRequest(
        actionId: BoardAction.getPost,
        payload: payload,
        requestId: 0x0002,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.notFound.code);
    });

    test('expired post returns NOT_FOUND', () async {
      // Advance clock past TTL.
      fakeNow = fakeNow.add(const Duration(seconds: 3601));
      final payload = Uint8List(4);
      ByteData.sublistView(payload).setUint32(0, postId, Endian.little);

      final request = _makeRequest(
        actionId: BoardAction.getPost,
        payload: payload,
        requestId: 0x0002,
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.notFound.code);
    });
  });

  group('list_recent', () {
    test('returns recent posts sorted by time', () async {
      // Create 3 posts.
      for (var i = 0; i < 3; i++) {
        fakeNow = fakeNow.add(const Duration(seconds: 61));
        final req = _makeRequest(
          actionId: BoardAction.postShort,
          payload: _makePostPayload('Post $i'), // lint-allow: hardcoded-string
          requestId: i + 10,
        );
        await handler.handleRequest(req, 0xABCD);
      }

      final request = _makeRequest(
        actionId: BoardAction.listRecent,
        payload: Uint8List.fromList([0]), // all
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payload[0], 3); // 3 posts
    });

    test('empty board returns 0 posts', () async {
      final request = _makeRequest(
        actionId: BoardAction.listRecent,
        payload: Uint8List.fromList([0]),
      );
      final response = await handler.handleRequest(request, 0xBEEF);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payload[0], 0);
    });

    test('since_hours filter works', () async {
      // Create a post.
      final req = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('Old post'), // lint-allow: hardcoded-string
      );
      await handler.handleRequest(req, 0xABCD);

      // Advance 3 hours.
      fakeNow = fakeNow.add(const Duration(hours: 3));

      // Create another post.
      final req2 = _makeRequest(
        actionId: BoardAction.postShort,
        payload: _makePostPayload('New post'), // lint-allow: hardcoded-string
        requestId: 2,
      );
      await handler.handleRequest(req2, 0xABCD);

      // List posts from last 1 hour - should only get the new one.
      final listReq = _makeRequest(
        actionId: BoardAction.listRecent,
        payload: Uint8List.fromList([1]), // since 1 hour
        requestId: 3,
      );
      final response = await handler.handleRequest(listReq, 0xBEEF);
      expect(response.payload[0], 1);
    });
  });

  test('payloads fit within MRRP_MAX_PAYLOAD', () async {
    final req = _makeRequest(
      actionId: BoardAction.postShort,
      payload: _makePostPayload('A' * 80), // lint-allow: hardcoded-string
    );
    final response = await handler.handleRequest(req, 0xABCD);
    expect(response.payloadLen, lessThanOrEqualTo(195));
  });
}
