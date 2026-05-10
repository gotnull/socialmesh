// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-B-A: `meshCoreCoreStatsProvider` regression pins.
//
// Pinned invariants:
//   - Empty (disconnected) snapshot when no MeshCore session is set.
//   - When a live session is overridden in, refreshNow() issues a
//     getCoreStats round-trip and the snapshot's `latest` matches
//     the parsed payload.
//   - Stale flag: an in-memory snapshot whose `fetchedAt` is older
//     than the 15 s threshold reports `isStaleAt(now) == true`.
//   - On session swap to null, the snapshot collapses to disconnected.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
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
    final frame = MeshCoreFrame.fromBytes(data);
    if (frame.command == MeshCoreCommands.getStats &&
        frame.payload.isNotEmpty &&
        frame.payload[0] == MeshCoreStatsType.core) {
      // Auto-respond with a canned CORE payload.
      final body = Uint8List(10);
      body[0] = MeshCoreStatsType.core;
      final bd = ByteData.sublistView(body);
      bd.setUint16(1, 4012, Endian.little); // batt mV
      bd.setUint32(3, 99, Endian.little); // uptime
      bd.setUint16(7, 0x0042, Endian.little); // err flags
      body[9] = 3; // queue
      _rx.add(
        MeshCoreFrame(
          command: MeshCoreResponses.stats,
          payload: body,
        ).toBytes(),
      );
    }
  }

  @override
  bool get isConnected => _connected;

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('meshCoreCoreStatsProvider - D35-B-A', () {
    test('returns disconnected snapshot when no session is connected', () {
      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final snap = container.read(meshCoreCoreStatsProvider);
      expect(snap.isConnected, isFalse);
      expect(snap.latest, isNull);
      expect(snap.isStale, isFalse);
    });

    test('refreshNow() fetches a snapshot from the live session and '
        'isStale stays false on success', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(meshCoreCoreStatsProvider);
      await container.read(meshCoreCoreStatsProvider.notifier).refreshNow();

      final snap = container.read(meshCoreCoreStatsProvider);
      expect(snap.isConnected, isTrue);
      expect(snap.latest, isNotNull);
      expect(snap.latest!.batteryMillivolts, 4012);
      expect(snap.latest!.uptime.inSeconds, 99);
      expect(snap.latest!.errorFlags, 0x0042);
      expect(snap.latest!.queueLength, 3);
      expect(snap.isStale, isFalse);
    });

    test('isStaleAt(now) returns true only when latest.fetchedAt is older '
        'than the 15 s threshold', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(meshCoreCoreStatsProvider);
      await container.read(meshCoreCoreStatsProvider.notifier).refreshNow();

      final notifier = container.read(meshCoreCoreStatsProvider.notifier);
      final fetchedAt = container
          .read(meshCoreCoreStatsProvider)
          .latest!
          .fetchedAt;
      // 14 s -> not stale.
      expect(
        notifier.isStaleAt(fetchedAt.add(const Duration(seconds: 14))),
        isFalse,
      );
      // 16 s -> stale.
      expect(
        notifier.isStaleAt(fetchedAt.add(const Duration(seconds: 16))),
        isTrue,
      );
    });

    test(
      'snapshot collapses to disconnected on session override-to-null',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final container = ProviderContainer(
          overrides: [meshCoreSessionProvider.overrideWithValue(session)],
        );
        addTearDown(container.dispose);

        container.read(meshCoreCoreStatsProvider);
        await container.read(meshCoreCoreStatsProvider.notifier).refreshNow();
        expect(container.read(meshCoreCoreStatsProvider).isConnected, isTrue);

        container.dispose();

        final disconnected = ProviderContainer(
          overrides: [meshCoreSessionProvider.overrideWithValue(null)],
        );
        addTearDown(disconnected.dispose);
        final snap = disconnected.read(meshCoreCoreStatsProvider);
        expect(snap.isConnected, isFalse);
        expect(snap.latest, isNull);
      },
    );
  });
}
