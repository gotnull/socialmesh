// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-B-A: `MeshCoreSession.getCoreStats()` integration pins.
//
// Pinned invariants:
//   - Outbound bytes are exactly [0x38, 0x00] (CMD_GET_STATS +
//     STATS_TYPE_CORE).
//   - Round-trips an 11-byte CORE-subtype response into a typed
//     MeshCoreCoreStats.
//   - Returns null on firmware timeout.
//   - Returns null on a wrong-subtype response.
//   - Repeated polls do NOT consume the D34a chat budget.
//   - getRadioStats and getCoreStats interleaved do not confuse
//     subtype responses (each parser rejects the other's payload
//     by length + subtype discriminator).

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

/// Build a CORE-subtype stats response body (10 bytes - the 11-byte
/// payload minus the response code which the frame layer carries).
Uint8List _coreBody({
  int batteryMv = 4012,
  int uptimeSecs = 3661,
  int errorFlags = 0x0042,
  int queueLen = 7,
}) {
  final body = Uint8List(10);
  final bd = ByteData.sublistView(body);
  body[0] = 0; // STATS_TYPE_CORE
  bd.setUint16(1, batteryMv, Endian.little);
  bd.setUint32(3, uptimeSecs, Endian.little);
  bd.setUint16(7, errorFlags, Endian.little);
  body[9] = queueLen;
  return body;
}

/// Build a RADIO-subtype stats response body (13 bytes minus the
/// response code carried by the frame layer).
Uint8List _radioBody({
  int noise = -110,
  int rssi = -83,
  int snrQuarter = 30,
  int txSecs = 1234,
  int rxSecs = 5678,
}) {
  final body = Uint8List(13);
  final bd = ByteData.sublistView(body);
  body[0] = 1; // STATS_TYPE_RADIO
  bd.setInt16(1, noise, Endian.little);
  bd.setInt8(3, rssi);
  bd.setInt8(4, snrQuarter);
  bd.setUint32(5, txSecs, Endian.little);
  bd.setUint32(9, rxSecs, Endian.little);
  return body;
}

void main() {
  group('D35-B-A: getCoreStats() integration', () {
    test('emits exactly [0x38, 0x00] (CMD_GET_STATS, STATS_TYPE_CORE) '
        'and parses a valid 11-byte response', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getCoreStats();
      // Yield once so the outbound frame lands in transport.sent
      // before we inject the response.
      await Future<void>.delayed(Duration.zero);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(
            batteryMv: 4012,
            uptimeSecs: 3661,
            errorFlags: 0x0042,
            queueLen: 7,
          ),
        ).toBytes(),
      );

      final stats = await fut;
      expect(stats, isNotNull);
      expect(stats!.batteryMillivolts, 4012);
      expect(stats.uptime, const Duration(seconds: 3661));
      expect(stats.errorFlags, 0x0042);
      expect(stats.queueLength, 7);

      // Outbound wire bytes: opcode 0x38, payload 0x00.
      expect(tx.sent, isNotEmpty);
      final sentFrame = MeshCoreFrame.fromBytes(tx.sent.last);
      expect(sentFrame.command, MeshCoreCommands.getStats);
      expect(sentFrame.payload, equals(Uint8List.fromList([0])));
    });

    test('returns null on firmware timeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final stats = await session.getCoreStats(
        timeout: const Duration(milliseconds: 100),
      );
      expect(stats, isNull);
    });

    test(
      'returns null on wrong-subtype response (RADIO subtype echo)',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final fut = session.getCoreStats();
        await Future<void>.delayed(Duration.zero);

        // Inject a RADIO-shaped response (13-byte body, subtype byte = 1).
        // The parser must reject by length: CORE expects a 10-byte body.
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.stats,
            payload: _radioBody(),
          ).toBytes(),
        );

        final stats = await fut;
        expect(
          stats,
          isNull,
          reason: 'wrong subtype (RADIO) must not be parsed as CORE stats',
        );
      },
    );

    test('repeated polls do NOT consume the D34a chat budget - '
        'ChatTrafficSnapshot.currentWindowSentBytes stays 0', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);
      addTearDown(session.dispose);

      // Drive 3 successful polls.
      for (int i = 0; i < 3; i++) {
        final fut = session.getCoreStats();
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.stats,
            payload: _coreBody(uptimeSecs: i, queueLen: i),
          ).toBytes(),
        );
        await fut;
      }

      final snap = lim.snapshot();
      expect(
        snap.currentWindowSentBytes,
        0,
        reason:
            'getCoreStats() must bypass the chat rate limiter; '
            'the window-sent counter must remain at zero across polls',
      );
      expect(
        snap.remainingBytes,
        snap.windowCapacityBytes,
        reason: 'token bucket headroom must be untouched',
      );
      for (final k in MeshCoreSendKind.values) {
        expect(snap.sendCountByKind[k], 0, reason: 'send count for $k');
      }
    });

    test('RADIO + CORE interleaved: each helper returns its own subtype '
        'data and rejects the other', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      // Sequential RADIO, then CORE - each request awaited fully so
      // the single-flight-per-response-code discipline is exercised.
      final radioFut = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _radioBody(noise: -100, rssi: -75, snrQuarter: 24),
        ).toBytes(),
      );
      final radioStats = await radioFut;
      expect(radioStats, isNotNull);
      expect(radioStats!.noiseFloorDbm, -100);
      expect(radioStats.lastRssiDbm, -75);

      final coreFut = session.getCoreStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(uptimeSecs: 99, queueLen: 3),
        ).toBytes(),
      );
      final coreStats = await coreFut;
      expect(coreStats, isNotNull);
      expect(coreStats!.uptime.inSeconds, 99);
      expect(coreStats.queueLength, 3);
    });
  });
}
