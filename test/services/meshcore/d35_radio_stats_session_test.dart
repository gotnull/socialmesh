// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-A - `MeshCoreSession.getRadioStats()` integration pins.
//
// Pinned invariants:
//   - Outbound bytes are exactly [0x38, 0x01] (CMD_GET_STATS +
//     STATS_TYPE_RADIO).
//   - Round-trips a 14-byte RADIO-subtype response into a typed
//     MeshCoreRadioStats.
//   - Returns null on firmware timeout (no plumbing of TimeoutException
//     into the UI).
//   - Repeated polls do NOT consume the D34a chat budget (the rate
//     limiter's window-sent counter must NOT increment).

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

/// Build a 14-byte RADIO stats payload (resp_code + subtype + 12 B body).
Uint8List _radioPayload({
  int noise = -110,
  int rssi = -83,
  int snrQuarter = 30,
  int txSecs = 1234,
  int rxSecs = 5678,
}) {
  final bytes = Uint8List(14);
  final bd = ByteData.sublistView(bytes);
  bytes[0] = 0x18; // RESP_CODE_STATS
  bytes[1] = 1; // STATS_TYPE_RADIO
  bd.setInt16(2, noise, Endian.little);
  bd.setInt8(4, rssi);
  bd.setInt8(5, snrQuarter);
  bd.setUint32(6, txSecs, Endian.little);
  bd.setUint32(10, rxSecs, Endian.little);
  return bytes;
}

void main() {
  group('D35-A - getRadioStats() integration', () {
    test('emits exactly [0x38, 0x01] (CMD_GET_STATS, STATS_TYPE_RADIO) '
        'and parses a valid 14-byte response', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getRadioStats();
      // Yield once so the outbound frame lands in transport.sent
      // before we inject the response.
      await Future<void>.delayed(Duration.zero);

      // Inject the 14-byte response as a wire-encoded MeshCoreFrame:
      // command byte 0x18, payload = subtype + 12 B body (13 B total).
      final body = _radioPayload(
        noise: -110,
        rssi: -83,
        snrQuarter: 30,
        txSecs: 1234,
        rxSecs: 5678,
      ).sublist(1); // strip the resp_code byte (frame.command carries it)
      final responseFrame = MeshCoreFrame(
        command: MeshCoreResponses.stats,
        payload: body,
      );
      tx.inject(responseFrame.toBytes());

      final stats = await fut;
      expect(stats, isNotNull);
      expect(stats!.noiseFloorDbm, -110);
      expect(stats.lastRssiDbm, -83);
      expect(stats.lastSnrQuarter, 30);
      expect(stats.snrDb, 7.5);
      expect(stats.txAirtime, const Duration(seconds: 1234));
      expect(stats.rxAirtime, const Duration(seconds: 5678));

      // Outbound wire bytes: opcode 0x38, payload 0x01.
      expect(tx.sent, isNotEmpty);
      final sentFrame = MeshCoreFrame.fromBytes(tx.sent.last);
      expect(sentFrame.command, MeshCoreCommands.getStats);
      expect(sentFrame.payload, equals(Uint8List.fromList([1])));
    });

    test('returns null on firmware timeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final stats = await session.getRadioStats(
        timeout: const Duration(milliseconds: 100),
      );
      expect(stats, isNull);
    });

    test(
      'returns null on wrong-subtype response (CORE subtype echo)',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final fut = session.getRadioStats();
        await Future<void>.delayed(Duration.zero);

        // Inject a CORE-subtype response (subtype byte = 0). Body length
        // matches a CORE frame (~9 bytes: u16 mV + u32 uptime + u16 errs
        // + u8 queue) - but our parser only requires byte[1]==1 to
        // accept, so any non-1 subtype must produce null.
        final body = Uint8List(13)..[0] = 0; // subtype = CORE
        final responseFrame = MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: body,
        );
        tx.inject(responseFrame.toBytes());

        final stats = await fut;
        expect(
          stats,
          isNull,
          reason: 'wrong subtype must not be parsed as RADIO stats',
        );
      },
    );

    test('D35-FIX-A: concurrent getRadioStats() returns null without '
        'throwing StateError on the shared 0x18 response slot', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      // First call: register the waiter for response 0x18 but do not
      // resolve it yet.
      final first = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);

      // Second call while the first is still in flight. Without the
      // session-level guard this would throw
      // `StateError: Single-flight violation: waiter already registered
      // for 0x18` because both calls target the same response code.
      final second = await session.getRadioStats();
      expect(
        second,
        isNull,
        reason:
            'concurrent getRadioStats() while a stats request is in '
            'flight must return null, not throw or queue',
      );

      // Resolve the first call so the test does not leak.
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _radioPayload().sublist(1),
        ).toBytes(),
      );
      final firstStats = await first;
      expect(firstStats, isNotNull);

      // After the first resolves, the guard clears and a fresh poll
      // succeeds.
      final third = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _radioPayload(noise: -90).sublist(1),
        ).toBytes(),
      );
      final thirdStats = await third;
      expect(thirdStats, isNotNull);
      expect(thirdStats!.noiseFloorDbm, -90);
    });

    test('repeated polls do NOT consume the D34a chat budget - '
        'ChatTrafficSnapshot.currentWindowSentBytes stays 0', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);
      addTearDown(session.dispose);

      // Drive 3 successful polls.
      for (int i = 0; i < 3; i++) {
        final fut = session.getRadioStats();
        await Future<void>.delayed(Duration.zero);
        final body = _radioPayload(txSecs: i, rxSecs: i * 2).sublist(1);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.stats,
            payload: body,
          ).toBytes(),
        );
        await fut;
      }

      final snap = lim.snapshot();
      expect(
        snap.currentWindowSentBytes,
        0,
        reason:
            'getRadioStats() must bypass the chat rate limiter; '
            'the window-sent counter must remain at zero across polls',
      );
      expect(
        snap.remainingBytes,
        snap.windowCapacityBytes,
        reason: 'token bucket headroom must be untouched',
      );
      // Per-kind counters all stay at zero.
      for (final k in MeshCoreSendKind.values) {
        expect(snap.sendCountByKind[k], 0, reason: 'send count for $k');
      }
    });
  });
}
