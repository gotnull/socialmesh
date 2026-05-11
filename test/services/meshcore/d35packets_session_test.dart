// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-PACKETS-A: `MeshCoreSession.getPacketsStats()` integration pins.
//
// Pinned invariants:
//   - Outbound bytes are exactly [0x38, 0x02] (CMD_GET_STATS +
//     STATS_TYPE_PACKETS).
//   - Round-trips a 30-byte PACKETS-subtype response into a typed
//     MeshCorePacketsStats.
//   - Returns null on firmware timeout.
//   - Returns null on a wrong-subtype response (RADIO body, CORE body).
//   - Repeated polls do NOT consume the D34a chat budget.
//   - getRadioStats + getCoreStats + getPacketsStats interleaved do
//     not confuse subtype responses (each helper rejects the others
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

/// PACKETS body (29 bytes: subtype byte + 7 u32 counters).
Uint8List _packetsBody({
  int rx = 1247,
  int tx = 892,
  int txFlood = 34,
  int txDirect = 858,
  int rxFlood = 412,
  int rxDirect = 830,
  int rxErr = 3,
}) {
  final body = Uint8List(29);
  final bd = ByteData.sublistView(body);
  body[0] = MeshCoreStatsType.packets;
  bd.setUint32(1, rx, Endian.little);
  bd.setUint32(5, tx, Endian.little);
  bd.setUint32(9, txFlood, Endian.little);
  bd.setUint32(13, txDirect, Endian.little);
  bd.setUint32(17, rxFlood, Endian.little);
  bd.setUint32(21, rxDirect, Endian.little);
  bd.setUint32(25, rxErr, Endian.little);
  return body;
}

/// RADIO body (13 bytes: subtype + RADIO fields).
Uint8List _radioBody() {
  final body = Uint8List(13);
  final bd = ByteData.sublistView(body);
  body[0] = MeshCoreStatsType.radio;
  bd.setInt16(1, -110, Endian.little);
  bd.setInt8(3, -83);
  bd.setInt8(4, 30);
  bd.setUint32(5, 1234, Endian.little);
  bd.setUint32(9, 5678, Endian.little);
  return body;
}

/// CORE body (10 bytes: subtype + CORE fields).
Uint8List _coreBody() {
  final body = Uint8List(10);
  final bd = ByteData.sublistView(body);
  body[0] = MeshCoreStatsType.core;
  bd.setUint16(1, 4012, Endian.little);
  bd.setUint32(3, 99, Endian.little);
  bd.setUint16(7, 0x0042, Endian.little);
  body[9] = 3;
  return body;
}

void main() {
  group('D35-PACKETS-A: getPacketsStats() integration', () {
    test('emits exactly [0x38, 0x02] (CMD_GET_STATS, STATS_TYPE_PACKETS) '
        'and parses a valid 30-byte response', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getPacketsStats();
      await Future<void>.delayed(Duration.zero);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _packetsBody(),
        ).toBytes(),
      );

      final stats = await fut;
      expect(stats, isNotNull);
      expect(stats!.packetsReceived, 1247);
      expect(stats.packetsSent, 892);
      expect(stats.sentFlood, 34);
      expect(stats.sentDirect, 858);
      expect(stats.recvFlood, 412);
      expect(stats.recvDirect, 830);
      expect(stats.recvErrors, 3);

      // Outbound wire bytes: opcode 0x38, payload 0x02.
      expect(tx.sent, isNotEmpty);
      final sentFrame = MeshCoreFrame.fromBytes(tx.sent.last);
      expect(sentFrame.command, MeshCoreCommands.getStats);
      expect(sentFrame.payload, equals(Uint8List.fromList([2])));
    });

    test('returns null on firmware timeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final stats = await session.getPacketsStats(
        timeout: const Duration(milliseconds: 100),
      );
      expect(stats, isNull);
    });

    test('returns null on wrong-subtype RADIO body', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getPacketsStats();
      await Future<void>.delayed(Duration.zero);

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
        reason: 'wrong subtype (RADIO) must not be parsed as PACKETS',
      );
    });

    test('returns null on wrong-subtype CORE body', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getPacketsStats();
      await Future<void>.delayed(Duration.zero);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(),
        ).toBytes(),
      );

      final stats = await fut;
      expect(
        stats,
        isNull,
        reason: 'wrong subtype (CORE) must not be parsed as PACKETS',
      );
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
        final fut = session.getPacketsStats();
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.stats,
            payload: _packetsBody(rx: i, tx: i),
          ).toBytes(),
        );
        await fut;
      }

      final snap = lim.snapshot();
      expect(
        snap.currentWindowSentBytes,
        0,
        reason:
            'getPacketsStats() must bypass the chat rate limiter; '
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

    test('D35-FIX-A: concurrent getPacketsStats() returns null without '
        'throwing StateError on the shared 0x18 response slot', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final first = session.getPacketsStats();
      await Future<void>.delayed(Duration.zero);

      final second = await session.getPacketsStats();
      expect(
        second,
        isNull,
        reason:
            'concurrent getPacketsStats() while a stats request is in '
            'flight must return null, not throw',
      );

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _packetsBody(),
        ).toBytes(),
      );
      final firstStats = await first;
      expect(firstStats, isNotNull);
    });

    test('D35-FIX-A: getPacketsStats() while getRadioStats() is in '
        'flight returns null without throwing', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final radioFut = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);

      final packetsResult = await session.getPacketsStats();
      expect(packetsResult, isNull);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _radioBody(),
        ).toBytes(),
      );
      final radioStats = await radioFut;
      expect(radioStats, isNotNull);
    });

    test('RADIO + CORE + PACKETS interleaved: each helper returns its '
        'own subtype data and rejects the others', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      // RADIO first.
      final radioFut = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _radioBody(),
        ).toBytes(),
      );
      final radioStats = await radioFut;
      expect(radioStats, isNotNull);
      expect(radioStats!.noiseFloorDbm, -110);

      // CORE next.
      final coreFut = session.getCoreStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(),
        ).toBytes(),
      );
      final coreStats = await coreFut;
      expect(coreStats, isNotNull);
      expect(coreStats!.uptime.inSeconds, 99);

      // PACKETS last.
      final packetsFut = session.getPacketsStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _packetsBody(rx: 1247, tx: 892),
        ).toBytes(),
      );
      final packetsStats = await packetsFut;
      expect(packetsStats, isNotNull);
      expect(packetsStats!.packetsReceived, 1247);
      expect(packetsStats.packetsSent, 892);
    });
  });
}
