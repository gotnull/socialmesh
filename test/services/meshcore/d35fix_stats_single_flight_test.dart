// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-FIX-A: session-level single-flight guard across all
// `CMD_GET_STATS` subtypes (RADIO, CORE, PACKETS).
//
// Background: RADIO (1 Hz), CORE (0.2 Hz), and PACKETS (lazy) all
// hit `MeshCoreCommands.getStats` (0x38) and expect the shared
// `MeshCoreResponses.stats` (0x18) response opcode. The session's
// `_pendingResponses` registry enforces single-flight per response
// code, so concurrent helpers used to race on slot 0x18 and throw
// `StateError: Single-flight violation: waiter already registered
// for 0x18`. This crash showed up in Crashlytics from production
// pollers stacked on a `Timer.periodic` cadence.
//
// Pinned invariants (this file):
//   - For every ordered pair (A, B) in {RADIO, CORE, PACKETS}, calling
//     B while A is in flight returns null and does NOT throw.
//   - After A resolves, the guard clears and a fresh B succeeds.
//   - The 2nd concurrent call does not consume the chat budget (it
//     never reaches the wire, the rate limiter is untouched).

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

Uint8List _packetsBody() {
  final body = Uint8List(29);
  final bd = ByteData.sublistView(body);
  body[0] = MeshCoreStatsType.packets;
  bd.setUint32(1, 1247, Endian.little);
  bd.setUint32(5, 892, Endian.little);
  bd.setUint32(9, 34, Endian.little);
  bd.setUint32(13, 858, Endian.little);
  bd.setUint32(17, 412, Endian.little);
  bd.setUint32(21, 830, Endian.little);
  bd.setUint32(25, 3, Endian.little);
  return body;
}

void main() {
  group('D35-FIX-A: stats single-flight cross-subtype', () {
    test('RADIO in flight, CORE arrives: CORE returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final radioFut = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);
      final outboundBefore = tx.sent.length;

      final core = await session.getCoreStats();
      expect(core, isNull);
      expect(
        tx.sent.length,
        outboundBefore,
        reason: 'second helper must NOT have hit the wire',
      );

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _radioBody(),
        ).toBytes(),
      );
      expect(await radioFut, isNotNull);
    });

    test('RADIO in flight, PACKETS arrives: PACKETS returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final radioFut = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);

      final packets = await session.getPacketsStats();
      expect(packets, isNull);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _radioBody(),
        ).toBytes(),
      );
      expect(await radioFut, isNotNull);
    });

    test('CORE in flight, RADIO arrives: RADIO returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final coreFut = session.getCoreStats();
      await Future<void>.delayed(Duration.zero);

      final radio = await session.getRadioStats();
      expect(radio, isNull);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(),
        ).toBytes(),
      );
      expect(await coreFut, isNotNull);
    });

    test('CORE in flight, PACKETS arrives: PACKETS returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final coreFut = session.getCoreStats();
      await Future<void>.delayed(Duration.zero);

      final packets = await session.getPacketsStats();
      expect(packets, isNull);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(),
        ).toBytes(),
      );
      expect(await coreFut, isNotNull);
    });

    test('PACKETS in flight, RADIO arrives: RADIO returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final packetsFut = session.getPacketsStats();
      await Future<void>.delayed(Duration.zero);

      final radio = await session.getRadioStats();
      expect(radio, isNull);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _packetsBody(),
        ).toBytes(),
      );
      expect(await packetsFut, isNotNull);
    });

    test('PACKETS in flight, CORE arrives: CORE returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final packetsFut = session.getPacketsStats();
      await Future<void>.delayed(Duration.zero);

      final core = await session.getCoreStats();
      expect(core, isNull);

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _packetsBody(),
        ).toBytes(),
      );
      expect(await packetsFut, isNotNull);
    });

    test(
      'skipped second helper does not consume the D34a chat budget',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final lim = MeshCoreSendRateLimiter();
        final session = MeshCoreSession(tx, sendRateLimiter: lim);
        addTearDown(session.dispose);

        final radioFut = session.getRadioStats();
        await Future<void>.delayed(Duration.zero);

        // 4 skipped concurrent helpers across the 3 subtypes.
        expect(await session.getCoreStats(), isNull);
        expect(await session.getPacketsStats(), isNull);
        expect(await session.getRadioStats(), isNull);
        expect(await session.getCoreStats(), isNull);

        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.stats,
            payload: _radioBody(),
          ).toBytes(),
        );
        expect(await radioFut, isNotNull);

        final snap = lim.snapshot();
        expect(snap.currentWindowSentBytes, 0);
        expect(snap.remainingBytes, snap.windowCapacityBytes);
      },
    );

    test('after the first helper resolves, a fresh helper succeeds '
        '(guard releases via finally even on a wrong-subtype null)', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      // 1) RADIO call resolves with a wrong-subtype CORE body, returns
      //    null. The guard must still clear because of the finally.
      final wrongFut = session.getRadioStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(),
        ).toBytes(),
      );
      expect(await wrongFut, isNull);

      // 2) A fresh CORE call must NOT see the guard still latched.
      final coreFut = session.getCoreStats();
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: _coreBody(),
        ).toBytes(),
      );
      final coreStats = await coreFut;
      expect(
        coreStats,
        isNotNull,
        reason:
            'guard must be released via the finally block even when the '
            'first helper returned null from a wrong-subtype response',
      );
    });
  });
}
