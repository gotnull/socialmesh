// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D41-A: `MeshCoreSession.requestTelemetry()` + the telemetry branch
// of `sendBinaryRequest()` (`expectedResponseCode == 0x8B`).
//
// Pinned invariants:
//   - Outbound wire bytes are exactly
//     `[CMD_SEND_BINARY_REQ 0x32][32 B pubkey][0x03][0x00]`.
//   - On `RESP_CODE_SENT` ack + `PUSH_CODE_TELEMETRY_RESPONSE 0x8B`,
//     the helper returns a parsed `MeshCoreTelemetryResponse` with the
//     LPP readings in wire order.
//   - The 0x8B push correlates by 6-byte pubkey PREFIX (NOT by tag).
//   - A wrong-prefix 0x8B push is ignored; the helper keeps waiting.
//   - A 0x8C (generic binary) push must NOT satisfy a 0x8B-expecting
//     wait, and vice versa - the two correlation paths do not bleed.
//   - No SENT ack -> helper returns null without hanging.
//   - SENT ack + no push within timeout -> helper returns null.
//   - Wrong-length pubkey throws ArgumentError before any wire bytes.
//   - Single-flight: a second concurrent `requestTelemetry` returns
//     null without sending bytes.
//   - The helper does NOT consume the D34a chat rate-limiter budget
//     (telemetry shares D36-A's reserved binary-request lane).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_cayenne_lpp.dart';
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
    Uint8List.fromList(List.generate(32, (i) => (seed + i) & 0xFF));

// `RESP_CODE_SENT 0x06` payload (9 B after opcode):
//   [route_type:u8][tag:u32 LE][est_timeout_ms:u32 LE]
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

// `PUSH_CODE_TELEMETRY_RESPONSE 0x8B` payload layout (after opcode):
//   [reserved:u8][pubkey_prefix:6 B][cayenne_lpp_tlv:...]
Uint8List _telemetryPushPayload({
  required Uint8List pubKeyPrefix6,
  required Uint8List lppBody,
}) {
  if (pubKeyPrefix6.length != 6) {
    throw ArgumentError('pubKeyPrefix6 must be 6 bytes');
  }
  final body = Uint8List(1 + 6 + lppBody.length);
  body[0] = 0; // reserved
  body.setRange(1, 7, pubKeyPrefix6);
  body.setRange(7, 7 + lppBody.length, lppBody);
  return body;
}

// `PUSH_CODE_BINARY_RESPONSE 0x8C` payload layout (after opcode):
//   [reserved:u8][tag:u32 LE][response_data:...]
Uint8List _binaryPushPayload({
  required int tag,
  required Uint8List responseData,
}) {
  final body = Uint8List(5 + responseData.length);
  body[0] = 0;
  final bd = ByteData.sublistView(body);
  bd.setUint32(1, tag, Endian.little);
  body.setRange(5, 5 + responseData.length, responseData);
  return body;
}

// Voltage 4.05 V on channel 1: [1][116][0x01][0x95].
Uint8List _voltage405LppBody() => Uint8List.fromList([1, 116, 0x01, 0x95]);

void main() {
  group('D41-A: requestTelemetry() integration', () {
    test('outbound wire is [0x32][32 B pubkey][0x03][0x00]', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      const tag = 0xCAFEF00D;
      final pubKey = _pubkey(0x10);

      final fut = session.requestTelemetry(pubKey);
      await Future<void>.delayed(Duration.zero);

      // Outbound frame is the CMD_SEND_BINARY_REQ wrapping
      // [pubkey][0x03][0x00].
      expect(tx.sent, hasLength(1));
      final sentFrame = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sentFrame.command, MeshCoreCommands.sendBinaryReq);
      expect(sentFrame.payload.length, 32 + 2);
      expect(sentFrame.payload.sublist(0, 32), equals(pubKey));
      expect(sentFrame.payload.sublist(32), equals([0x03, 0x00]));

      // Let the helper complete cleanly so the teardown doesn't hang on
      // its in-flight latch.
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.sent,
          payload: _sentPayload(tag: tag),
        ).toBytes(),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCorePushCodes.telemetryResponse,
          payload: _telemetryPushPayload(
            pubKeyPrefix6: pubKey.sublist(0, 6),
            lppBody: _voltage405LppBody(),
          ),
        ).toBytes(),
      );
      await fut;
    });

    test('ACK + matching 0x8B push returns parsed LPP readings', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final pubKey = _pubkey(0x20);
      final fut = session.requestTelemetry(pubKey);
      await Future<void>.delayed(Duration.zero);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.sent,
          payload: _sentPayload(tag: 0x00000001),
        ).toBytes(),
      );
      await Future<void>.delayed(Duration.zero);

      tx.inject(
        MeshCoreFrame(
          command: MeshCorePushCodes.telemetryResponse,
          payload: _telemetryPushPayload(
            pubKeyPrefix6: pubKey.sublist(0, 6),
            lppBody: _voltage405LppBody(),
          ),
        ).toBytes(),
      );

      final response = await fut;
      expect(response, isNotNull);
      expect(response!.readings, hasLength(1));
      final v = response.readings.single as MeshCoreTelemetryVoltage;
      expect(v.channel, 1);
      expect(v.volts, closeTo(4.05, 1e-9));
      expect(response.unknownTypes, isEmpty);
    });

    test('wrong-prefix 0x8B push is ignored; matching one completes', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final pubKey = _pubkey(0x30);
      final otherPubKeyPrefix = Uint8List.fromList([
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
      ]);

      final fut = session.requestTelemetry(pubKey);
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.sent,
          payload: _sentPayload(tag: 0x12345678),
        ).toBytes(),
      );
      await Future<void>.delayed(Duration.zero);

      // Wrong-prefix push: should NOT complete the future.
      tx.inject(
        MeshCoreFrame(
          command: MeshCorePushCodes.telemetryResponse,
          payload: _telemetryPushPayload(
            pubKeyPrefix6: otherPubKeyPrefix,
            lppBody: _voltage405LppBody(),
          ),
        ).toBytes(),
      );
      await Future<void>.delayed(Duration.zero);

      // Correct-prefix push: completes.
      tx.inject(
        MeshCoreFrame(
          command: MeshCorePushCodes.telemetryResponse,
          payload: _telemetryPushPayload(
            pubKeyPrefix6: pubKey.sublist(0, 6),
            lppBody: Uint8List.fromList([1, 116, 0x01, 0x95]),
          ),
        ).toBytes(),
      );

      final response = await fut;
      expect(response, isNotNull);
      expect(response!.readings, hasLength(1));
      expect(response.readings.single, isA<MeshCoreTelemetryVoltage>());
    });

    test('0x8C binary push must NOT satisfy a 0x8B-expecting wait', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final pubKey = _pubkey(0x40);
      final fut = session.requestTelemetry(
        pubKey,
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.sent,
          payload: _sentPayload(tag: 0x99999999),
        ).toBytes(),
      );
      await Future<void>.delayed(Duration.zero);

      // Wire opcode 0x8C with matching tag - the WRONG channel for
      // a telemetry-expecting helper.
      tx.inject(
        MeshCoreFrame(
          command: MeshCorePushCodes.binaryResponse,
          payload: _binaryPushPayload(
            tag: 0x99999999,
            responseData: _voltage405LppBody(),
          ),
        ).toBytes(),
      );

      final response = await fut;
      expect(
        response,
        isNull,
        reason: '0x8C must not be confused with 0x8B telemetry response',
      );
    });

    test(
      '0x8B push must NOT satisfy a generic 0x8C-expecting binary request',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final pubKey = _pubkey(0x50);

        // Use the generic helper directly to express the D36 contract.
        final fut = session.sendBinaryRequest(
          recipientPubKey: pubKey,
          requestBytes: Uint8List.fromList([0x06]),
          timeout: const Duration(milliseconds: 200),
        );
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.sent,
            payload: _sentPayload(tag: 0x11112222),
          ).toBytes(),
        );
        await Future<void>.delayed(Duration.zero);

        // Inject a 0x8B push that COULD parse as a tag-bearing payload
        // if the correlation logic were not strict. It must be ignored.
        tx.inject(
          MeshCoreFrame(
            command: MeshCorePushCodes.telemetryResponse,
            payload: _telemetryPushPayload(
              pubKeyPrefix6: pubKey.sublist(0, 6),
              lppBody: _voltage405LppBody(),
            ),
          ).toBytes(),
        );

        final response = await fut;
        expect(response, isNull, reason: '0x8B must not satisfy a 0x8C waiter');
      },
    );

    test('returns null when no SENT ack arrives', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final response = await session.requestTelemetry(
        _pubkey(0x60),
        timeout: const Duration(milliseconds: 200),
      );
      expect(response, isNull);
    });

    test('returns null when SENT lands but no 0x8B push arrives', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.requestTelemetry(
        _pubkey(0x70),
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.sent,
          payload: _sentPayload(tag: 0xDEADBEEF),
        ).toBytes(),
      );
      final response = await fut;
      expect(response, isNull);
    });

    test('throws ArgumentError for wrong-length pubkey', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(
        () => session.requestTelemetry(Uint8List(16)),
        throwsArgumentError,
      );
      expect(
        tx.sent,
        isEmpty,
        reason: 'wrong-length pubkey must reject BEFORE wire bytes are sent',
      );
    });

    test('single-flight: second concurrent telemetry returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut1 = session.requestTelemetry(
        _pubkey(0x80),
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tx.sent, hasLength(1));

      final fut2 = session.requestTelemetry(_pubkey(0x90));
      final response2 = await fut2;
      expect(response2, isNull, reason: 'single-flight rejects');
      expect(
        tx.sent,
        hasLength(1),
        reason: 'rejected telemetry call must not send bytes',
      );

      await fut1;
    });

    test('telemetry round-trips do NOT consume the D34a chat budget', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);
      addTearDown(session.dispose);

      final pubKey = _pubkey(0xA0);

      for (var i = 0; i < 3; i++) {
        final fut = session.requestTelemetry(pubKey);
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.sent,
            payload: _sentPayload(tag: 0x1000 + i),
          ).toBytes(),
        );
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCorePushCodes.telemetryResponse,
            payload: _telemetryPushPayload(
              pubKeyPrefix6: pubKey.sublist(0, 6),
              lppBody: _voltage405LppBody(),
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
        reason: 'requestTelemetry() must bypass the chat rate limiter',
      );
      expect(snap.remainingBytes, snap.windowCapacityBytes);
      for (final k in MeshCoreSendKind.values) {
        expect(snap.sendCountByKind[k], 0);
      }
    });
  });
}
