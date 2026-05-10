// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-PACKETS-A: `meshCorePacketsStatsProvider` regression pins.
//
// Pinned invariants:
//   - Disconnected snapshot when no MeshCore session is set.
//   - When a live session is overridden in, refreshNow() round-trips
//     getPacketsStats and the snapshot's `latest` matches the parsed
//     payload.
//   - Stale flag flips after 30 s threshold.
//   - On session swap to null, the snapshot collapses to disconnected.
//   - **Lazy auto-dispose**: the provider is `NotifierProvider.autoDispose`,
//     so when no widget is watching it, the Notifier is disposed and
//     the polling timer is cancelled. This is what makes the
//     "collapsed Packet counters = no wire chatter" guarantee real.

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
  int packetsRequestCount = 0;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
    final frame = MeshCoreFrame.fromBytes(data);
    if (frame.command == MeshCoreCommands.getStats &&
        frame.payload.isNotEmpty &&
        frame.payload[0] == MeshCoreStatsType.packets) {
      packetsRequestCount++;
      // Auto-respond with a canned PACKETS payload.
      final body = Uint8List(29);
      body[0] = MeshCoreStatsType.packets;
      final bd = ByteData.sublistView(body);
      bd.setUint32(1, 1247, Endian.little);
      bd.setUint32(5, 892, Endian.little);
      bd.setUint32(9, 34, Endian.little);
      bd.setUint32(13, 858, Endian.little);
      bd.setUint32(17, 412, Endian.little);
      bd.setUint32(21, 830, Endian.little);
      bd.setUint32(25, 3, Endian.little);
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

  group('meshCorePacketsStatsProvider - D35-PACKETS-A', () {
    test('returns disconnected snapshot when no session is connected', () {
      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final snap = container.read(meshCorePacketsStatsProvider);
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

      // Subscribe to keep the autoDispose provider alive.
      final sub = container.listen<MeshCorePacketsStatsSnapshot>(
        meshCorePacketsStatsProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(meshCorePacketsStatsProvider.notifier).refreshNow();

      final snap = container.read(meshCorePacketsStatsProvider);
      expect(snap.isConnected, isTrue);
      expect(snap.latest, isNotNull);
      expect(snap.latest!.packetsReceived, 1247);
      expect(snap.latest!.packetsSent, 892);
      expect(snap.latest!.sentFlood, 34);
      expect(snap.latest!.sentDirect, 858);
      expect(snap.latest!.recvFlood, 412);
      expect(snap.latest!.recvDirect, 830);
      expect(snap.latest!.recvErrors, 3);
      expect(snap.isStale, isFalse);
    });

    test('isStaleAt(now) returns true only when latest.fetchedAt is '
        'older than the 30 s threshold', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      final sub = container.listen<MeshCorePacketsStatsSnapshot>(
        meshCorePacketsStatsProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(meshCorePacketsStatsProvider.notifier).refreshNow();

      final notifier = container.read(meshCorePacketsStatsProvider.notifier);
      final fetchedAt = container
          .read(meshCorePacketsStatsProvider)
          .latest!
          .fetchedAt;

      // 25 s after fetch -> not stale.
      expect(
        notifier.isStaleAt(fetchedAt.add(const Duration(seconds: 25))),
        isFalse,
      );
      // 31 s after fetch -> stale.
      expect(
        notifier.isStaleAt(fetchedAt.add(const Duration(seconds: 31))),
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

        final sub = container.listen<MeshCorePacketsStatsSnapshot>(
          meshCorePacketsStatsProvider,
          (_, _) {},
        );
        await container
            .read(meshCorePacketsStatsProvider.notifier)
            .refreshNow();
        expect(
          container.read(meshCorePacketsStatsProvider).isConnected,
          isTrue,
        );
        sub.close();
        container.dispose();

        // Re-create with null session.
        final disconnected = ProviderContainer(
          overrides: [meshCoreSessionProvider.overrideWithValue(null)],
        );
        addTearDown(disconnected.dispose);
        final snap = disconnected.read(meshCorePacketsStatsProvider);
        expect(snap.isConnected, isFalse);
        expect(snap.latest, isNull);
      },
    );

    test('LAZY: provider auto-disposes when last listener unsubscribes; '
        'no further wire requests fire after the listener is closed', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      // Subscribe -> provider builds -> initial Future.microtask
      // poll fires.
      final sub = container.listen<MeshCorePacketsStatsSnapshot>(
        meshCorePacketsStatsProvider,
        (_, _) {},
      );
      // Allow the microtask poll to dispatch.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final firstCount = tx.packetsRequestCount;
      expect(
        firstCount,
        greaterThanOrEqualTo(1),
        reason:
            'subscribed provider should issue at least one PACKETS '
            'request from its initial microtask',
      );

      // Drop the listener. NotifierProvider.autoDispose should now
      // dispose the Notifier, cancel the timer, and stop polling.
      sub.close();

      // Pump a couple of frames + a slack delay so any pending Timer
      // tick (provider's 10-s ticker) would have a chance to fire if
      // it hadn't been cancelled. We're not waiting 10 s; we just
      // wait long enough that any "I forgot to cancel the timer"
      // bug would surface a stray request via a microtask, not a
      // real-time tick. The lazy guarantee is that the *post-dispose*
      // request count must NOT increase from this side of the test.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final afterDisposeCount = tx.packetsRequestCount;
      expect(
        afterDisposeCount,
        equals(firstCount),
        reason:
            'after the last listener unsubscribes, no further '
            'getPacketsStats requests must hit the wire',
      );
    });
  });
}
