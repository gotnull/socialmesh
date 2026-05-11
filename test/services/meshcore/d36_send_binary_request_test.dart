// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D36-A: `MeshCoreSession.sendBinaryRequest()` integration pins.
//
// Pinned invariants:
//   - Outbound wire bytes are exactly
//     [0x32][32 B recipientPubKey][requestBytes...].
//   - Tag is parsed from `RESP_CODE_SENT` payload offsets [2..6].
//   - A matching `PUSH_CODE_BINARY_RESPONSE` returns the body from
//     offset 6 onward.
//   - A non-matching tag is ignored; the helper keeps waiting.
//   - Timeout returns null.
//   - Wrong recipient pubkey length throws ArgumentError BEFORE
//     anything hits the wire.
//   - A second concurrent call (single-flight) returns null without
//     sending any bytes.
//   - The helper does NOT consume the D34a chat budget.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => _connected;

  void inject(Uint8List bytes) {
    _rx.add(bytes);
  }

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

Uint8List _pubkey(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => seed + i));

/// Build a synthetic `RESP_CODE_SENT` payload (9 bytes after the 0x06
/// opcode):
///   payload[0]    = route_type
///   payload[1..5] = tag (u32 LE)
///   payload[5..9] = est_timeout_ms (u32 LE)
Uint8List _sentPayload({
  int routeType = 0,
  required int tag,
  int estTimeoutMs = 1500,
}) {
  final body = Uint8List(9);
  final bd = ByteData.sublistView(body);
  body[0] = routeType;
  bd.setUint32(1, tag, Endian.little);
  bd.setUint32(5, estTimeoutMs, Endian.little);
  return body;
}

/// Build a synthetic `PUSH_CODE_BINARY_RESPONSE` payload. Push frame
/// payload layout: [reserved:u8][tag:u32 LE][response_data...].
Uint8List _pushPayload({required int tag, required Uint8List responseData}) {
  final body = Uint8List(5 + responseData.length);
  body[0] = 0; // reserved
  final bd = ByteData.sublistView(body);
  bd.setUint32(1, tag, Endian.little);
  body.setRange(5, 5 + responseData.length, responseData);
  return body;
}

void main() {
  group('D36-A: sendBinaryRequest() integration', () {
    test(
      'outbound wire is exactly [0x32][32 B pubkey][requestBytes]',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        const tag = 0xDEADBEEF;
        final pubKey = _pubkey(1);
        final reqBytes = Uint8List.fromList([
          0x06,
          0x00,
          0x0F,
          0x00,
          0x00,
          0x00,
          0x04,
        ]);

        final fut = session.sendBinaryRequest(
          recipientPubKey: pubKey,
          requestBytes: reqBytes,
        );

        await Future<void>.delayed(Duration.zero);

        // Inject the SENT ack so the helper extracts the tag.
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.sent,
            payload: _sentPayload(tag: tag),
          ).toBytes(),
        );
        await Future<void>.delayed(Duration.zero);

        // Inject the matching push.
        tx.inject(
          MeshCoreFrame(
            command: MeshCorePushCodes.binaryResponse,
            payload: _pushPayload(
              tag: tag,
              responseData: Uint8List.fromList([0xAA, 0xBB, 0xCC]),
            ),
          ).toBytes(),
        );

        final response = await fut;
        expect(response, equals(Uint8List.fromList([0xAA, 0xBB, 0xCC])));

        // Outbound frame check.
        expect(tx.sent, isNotEmpty);
        final sentFrame = MeshCoreFrame.fromBytes(tx.sent.first);
        expect(sentFrame.command, MeshCoreCommands.sendBinaryReq);
        expect(sentFrame.payload.length, 32 + reqBytes.length);
        expect(sentFrame.payload.sublist(0, 32), equals(pubKey));
        expect(sentFrame.payload.sublist(32), equals(reqBytes));
      },
    );

    test('non-matching tag in PUSH_CODE_BINARY_RESPONSE is ignored', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendBinaryRequest(
        recipientPubKey: _pubkey(1),
        requestBytes: Uint8List.fromList([0x06]),
      );

      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.sent,
          payload: _sentPayload(tag: 0xAAAA0001),
        ).toBytes(),
      );
      await Future<void>.delayed(Duration.zero);

      // Wrong-tag push: should NOT complete the future.
      tx.inject(
        MeshCoreFrame(
          command: MeshCorePushCodes.binaryResponse,
          payload: _pushPayload(
            tag: 0xBBBB0002, // different tag
            responseData: Uint8List.fromList([0x11, 0x22]),
          ),
        ).toBytes(),
      );
      await Future<void>.delayed(Duration.zero);

      // Correct-tag push: should complete.
      tx.inject(
        MeshCoreFrame(
          command: MeshCorePushCodes.binaryResponse,
          payload: _pushPayload(
            tag: 0xAAAA0001,
            responseData: Uint8List.fromList([0x42]),
          ),
        ).toBytes(),
      );

      final response = await fut;
      expect(response, equals(Uint8List.fromList([0x42])));
    });

    test('returns null when no SENT ack arrives', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final response = await session.sendBinaryRequest(
        recipientPubKey: _pubkey(1),
        requestBytes: Uint8List.fromList([0x06]),
        timeout: const Duration(milliseconds: 200),
      );
      expect(response, isNull);
    });

    test('returns null when SENT ack lands but push never arrives', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendBinaryRequest(
        recipientPubKey: _pubkey(1),
        requestBytes: Uint8List.fromList([0x06]),
        timeout: const Duration(milliseconds: 200),
      );

      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.sent,
          payload: _sentPayload(tag: 0x12345678),
        ).toBytes(),
      );

      // No push - timeout fires.
      final response = await fut;
      expect(response, isNull);
    });

    test('throws ArgumentError for wrong-length recipient pubkey', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(
        () => session.sendBinaryRequest(
          recipientPubKey: Uint8List(31),
          requestBytes: Uint8List.fromList([0x06]),
        ),
        throwsArgumentError,
      );
      expect(
        tx.sent,
        isEmpty,
        reason: 'wrong-length pubkey must reject BEFORE wire bytes are sent',
      );
    });

    test('single-flight: second concurrent call returns null without '
        'sending', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      // First call: in flight (no SENT ack yet).
      final fut1 = session.sendBinaryRequest(
        recipientPubKey: _pubkey(1),
        requestBytes: Uint8List.fromList([0x06]),
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tx.sent, hasLength(1));

      // Second call while the first is still pending.
      final fut2 = session.sendBinaryRequest(
        recipientPubKey: _pubkey(2),
        requestBytes: Uint8List.fromList([0x06]),
      );
      final response2 = await fut2;
      expect(response2, isNull, reason: 'single-flight guard rejects');
      expect(
        tx.sent,
        hasLength(1),
        reason: 'rejected call must not send anything on the wire',
      );

      // Let the first call time out and confirm the guard releases.
      await fut1;

      // After release, a fresh call goes through.
      final fut3 = session.sendBinaryRequest(
        recipientPubKey: _pubkey(3),
        requestBytes: Uint8List.fromList([0x06]),
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tx.sent, hasLength(2), reason: 'second call after release');
      await fut3;
    });

    test('repeated polls do NOT consume the D34a chat budget', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);
      addTearDown(session.dispose);

      for (var i = 0; i < 3; i++) {
        final fut = session.sendBinaryRequest(
          recipientPubKey: _pubkey(1),
          requestBytes: Uint8List.fromList([0x06]),
        );
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.sent,
            payload: _sentPayload(tag: i + 1),
          ).toBytes(),
        );
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCorePushCodes.binaryResponse,
            payload: _pushPayload(
              tag: i + 1,
              responseData: Uint8List.fromList([i]),
            ),
          ).toBytes(),
        );
        final response = await fut;
        expect(response, isNotNull);
      }

      final snap = lim.snapshot();
      expect(
        snap.currentWindowSentBytes,
        0,
        reason: 'sendBinaryRequest() must bypass the chat rate limiter',
      );
      expect(snap.remainingBytes, snap.windowCapacityBytes);
      for (final k in MeshCoreSendKind.values) {
        expect(snap.sendCountByKind[k], 0);
      }
    });
  });
}
