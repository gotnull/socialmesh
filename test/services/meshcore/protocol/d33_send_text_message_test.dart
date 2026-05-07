// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D33 — `MeshCoreSession.sendTextMessage` integration tests.
//
// Pins the typed text-send wrapper that gates outbound text payloads
// via `MeshCoreSendRateLimiter` before consulting `sendAndWait`.
// What this file pins:
//
//   - Normal short messages still send and the firmware's OK code
//     resolves to `outcome = ok`.
//   - Rate-limit rejection produces `outcome = rateLimited` AND does
//     NOT consume budget tokens (the next attempt sees the same
//     pre-call remaining bytes).
//   - Rate-limit rejection happens BEFORE any wire send (transport
//     records nothing).
//   - Firmware response timeout produces `outcome = firmwareTimeout`.
//   - The wrapper rejects calls for non-text command codes so a
//     refactor that mis-routes can't bypass the limiter.
//   - Budget accounting includes the cmd byte (`payload.length + 1`),
//     matching the wire shape.

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
  bool connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => connected;

  void simulateOk() {
    final ok = MeshCoreFrame(
      command: MeshCoreResponses.ok,
      payload: Uint8List(0),
    );
    _rx.add(ok.toBytes());
  }

  void simulateSent() {
    // RESP_CODE_SENT (0x06) carries 9 bytes (expected_ack_hash +
    // est_time_to_send) — populate with placeholders the codec will
    // accept.
    final sent = MeshCoreFrame(
      command: MeshCoreResponses.sent,
      payload: Uint8List.fromList(List.filled(9, 0xCC)),
    );
    _rx.add(sent.toBytes());
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group('MeshCoreSession.sendTextMessage — happy paths', () {
    test('normal short channel send: rate limit allows, firmware OK '
        'resolves to ok', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      Future.microtask(() => transport.simulateOk());

      final result = await session.sendTextMessage(
        command: MeshCoreCommands.sendChannelTxtMsg,
        payload: Uint8List.fromList([
          0, 0, 0, 0, 0, 0, // header
          ...'hello'.codeUnits,
          0,
        ]),
        expectedResponse: MeshCoreResponses.ok,
      );

      expect(result.ok, isTrue);
      expect(result.firmwareTimeout, isFalse);
      expect(result.rateLimited, isFalse);
      expect(result.response, isNotNull);
      // Budget accounting: payload.length(12) + 1 cmd byte = 13.
      expect(session.sendRateLimiter.remainingBytes, 1024 - 13);
    });

    test('normal short contact send: firmware SENT resolves to ok', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      Future.microtask(() => transport.simulateSent());

      final result = await session.sendTextMessage(
        command: MeshCoreCommands.sendTxtMsg,
        payload: Uint8List.fromList([
          0, 0, 0, 0, 0, 0, // txt_type + attempt + ts
          ...List.filled(6, 0xAA), // recipient prefix
          ...'hi'.codeUnits,
          0,
        ]),
        expectedResponse: MeshCoreResponses.sent,
      );

      expect(result.ok, isTrue);
    });
  });

  group('MeshCoreSession.sendTextMessage — rate-limit rejection', () {
    test('over-budget request returns rateLimited and does NOT '
        'consume tokens or hit the wire', () async {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      // Tiny budget so we can fill it in one send.
      final limiter = MeshCoreSendRateLimiter(
        clock: clock.call,
        capacityBytes: 50,
        windowSeconds: 60,
      );
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport, sendRateLimiter: limiter);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      // First send: 30 bytes payload + 1 cmd = 31. Allowed.
      Future.microtask(() => transport.simulateOk());
      final r1 = await session.sendTextMessage(
        command: MeshCoreCommands.sendChannelTxtMsg,
        payload: Uint8List(30),
        expectedResponse: MeshCoreResponses.ok,
      );
      expect(r1.ok, isTrue);
      expect(limiter.remainingBytes, 19);

      // Second send: 30 bytes + 1 = 31. Over budget (only 19 left).
      // This should NOT hit the wire.
      final beforeSent = transport.sent.length;
      final r2 = await session.sendTextMessage(
        command: MeshCoreCommands.sendChannelTxtMsg,
        payload: Uint8List(30),
        expectedResponse: MeshCoreResponses.ok,
      );

      expect(r2.rateLimited, isTrue);
      expect(r2.ok, isFalse);
      expect(r2.firmwareTimeout, isFalse);
      expect(r2.nextSendIn, isNotNull);
      expect(r2.nextSendIn!.inMilliseconds, greaterThan(0));
      expect(
        r2.remainingBytes,
        19,
        reason: 'rejected request must NOT consume tokens',
      );
      expect(
        transport.sent.length,
        beforeSent,
        reason: 'rejected send must NOT touch the transport',
      );
    });

    test('after refill window the same payload succeeds', () async {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final limiter = MeshCoreSendRateLimiter(
        clock: clock.call,
        capacityBytes: 50,
        windowSeconds: 60,
      );
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport, sendRateLimiter: limiter);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      Future.microtask(() => transport.simulateOk());
      await session.sendTextMessage(
        command: MeshCoreCommands.sendChannelTxtMsg,
        payload: Uint8List(40),
        expectedResponse: MeshCoreResponses.ok,
      );
      // 9 bytes left.

      // Advance a full window so the bucket refills.
      clock.advance(const Duration(seconds: 60));

      Future.microtask(() => transport.simulateOk());
      final r2 = await session.sendTextMessage(
        command: MeshCoreCommands.sendChannelTxtMsg,
        payload: Uint8List(40),
        expectedResponse: MeshCoreResponses.ok,
      );
      expect(r2.ok, isTrue);
    });
  });

  group('MeshCoreSession.sendTextMessage — firmware timeout', () {
    test('when firmware never responds, outcome is firmwareTimeout '
        '(tokens consumed because the wire send did happen)', () async {
      // Deterministic clock so the 80 ms wall-time between budget
      // deduction and assertion doesn't accidentally refill a
      // byte and turn 1003 into 1004.
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final limiter = MeshCoreSendRateLimiter(clock: clock.call);
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport, sendRateLimiter: limiter);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      // Don't simulate any response; sendAndWait times out at the
      // requested duration.
      final result = await session.sendTextMessage(
        command: MeshCoreCommands.sendChannelTxtMsg,
        payload: Uint8List(20),
        expectedResponse: MeshCoreResponses.ok,
        timeout: const Duration(milliseconds: 80),
      );

      expect(result.firmwareTimeout, isTrue);
      expect(result.ok, isFalse);
      expect(result.rateLimited, isFalse);
      // Budget WAS deducted (the wire send went out, just no
      // response). 20 + 1 = 21 bytes consumed; clock didn't
      // advance so no refill noise.
      expect(session.sendRateLimiter.remainingBytes, 1024 - 21);
    });
  });

  group(
    'MeshCoreSession.sendTextMessage — guard against bypass via wrong cmd',
    () {
      test('non-text command codes throw ArgumentError', () async {
        final transport = _RecordingTransport();
        final session = MeshCoreSession(transport);
        addTearDown(() async {
          await session.dispose();
          await transport.dispose();
        });

        // setChannel (0x20) goes through the normal sendAndWait
        // path, not sendTextMessage. Routing it here would bypass
        // the limiter — guard with a thrown ArgumentError.
        expect(
          () => session.sendTextMessage(
            command: MeshCoreCommands.setChannel,
            payload: Uint8List(10),
            expectedResponse: MeshCoreResponses.ok,
          ),
          throwsArgumentError,
        );

        // The throw happens BEFORE the budget is touched so misuse
        // doesn't penalise legitimate text-send budget either.
        expect(session.sendRateLimiter.remainingBytes, 1024);
      });
    },
  );
}
