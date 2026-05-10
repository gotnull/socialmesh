// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-A - `meshCoreRadioStatsProvider` regression pins.
//
// Pinned invariants:
//   - Empty (disconnected) snapshot when no MeshCore session is set.
//   - When a live session is overridden in, `refreshNow()` issues a
//     `getRadioStats` round-trip and the snapshot's `latest` matches
//     the parsed payload.
//   - Stale flag: an in-memory snapshot whose `fetchedAt` is older
//     than the staleness threshold reports `isStaleAt(now) == true`
//     via the notifier helper, and a fresh fetch clears the flag.
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
    // Auto-respond with a canned RADIO payload every time the test
    // session sends a CMD_GET_STATS request, so refreshNow()
    // resolves quickly without explicit injection per call.
    final frame = MeshCoreFrame.fromBytes(data);
    if (frame.command == MeshCoreCommands.getStats) {
      // Build a synthetic response.
      final body = Uint8List(13);
      body[0] = 1; // STATS_TYPE_RADIO
      // noise=-100, rssi=-80, snrQ=20, txSecs=42, rxSecs=84
      final bd = ByteData.sublistView(body);
      bd.setInt16(1, -100, Endian.little);
      bd.setInt8(3, -80);
      bd.setInt8(4, 20);
      bd.setUint32(5, 42, Endian.little);
      bd.setUint32(9, 84, Endian.little);
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

  group('meshCoreRadioStatsProvider - D35-A', () {
    test('returns disconnected snapshot when no session is connected', () {
      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final snap = container.read(meshCoreRadioStatsProvider);
      expect(snap.isConnected, isFalse);
      expect(snap.latest, isNull);
      expect(snap.isStale, isFalse);
    });

    test('refreshNow() fetches a snapshot from the live session and '
        'isStale flips to false on success', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      // Subscribing kicks off the build() path which schedules an
      // initial microtask fetch - read once, then drive refreshNow.
      container.read(meshCoreRadioStatsProvider);
      await container.read(meshCoreRadioStatsProvider.notifier).refreshNow();

      final snap = container.read(meshCoreRadioStatsProvider);
      expect(snap.isConnected, isTrue);
      expect(snap.latest, isNotNull);
      expect(snap.latest!.noiseFloorDbm, -100);
      expect(snap.latest!.lastRssiDbm, -80);
      expect(snap.latest!.lastSnrQuarter, 20);
      expect(snap.latest!.txAirtime.inSeconds, 42);
      expect(snap.latest!.rxAirtime.inSeconds, 84);
      expect(snap.isStale, isFalse);
    });

    test('isStaleAt(now) returns true when latest.fetchedAt is older '
        'than the 5 s threshold', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(meshCoreRadioStatsProvider);
      await container.read(meshCoreRadioStatsProvider.notifier).refreshNow();

      final notifier = container.read(meshCoreRadioStatsProvider.notifier);
      final fetchedAt = container
          .read(meshCoreRadioStatsProvider)
          .latest!
          .fetchedAt;
      // 4 s after fetch → not stale.
      expect(
        notifier.isStaleAt(fetchedAt.add(const Duration(seconds: 4))),
        isFalse,
      );
      // 6 s after fetch → stale.
      expect(
        notifier.isStaleAt(fetchedAt.add(const Duration(seconds: 6))),
        isTrue,
      );
    });

    test('disconnected → snapshot collapses to disconnected on session '
        'override-back-to-null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final container = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(meshCoreRadioStatsProvider);
      await container.read(meshCoreRadioStatsProvider.notifier).refreshNow();
      expect(container.read(meshCoreRadioStatsProvider).isConnected, isTrue);

      // Swap the override to null - provider rebuild kicks the
      // disconnected branch.
      container.dispose();

      final disconnected = ProviderContainer(
        overrides: [meshCoreSessionProvider.overrideWithValue(null)],
      );
      addTearDown(disconnected.dispose);
      final snap = disconnected.read(meshCoreRadioStatsProvider);
      expect(snap.isConnected, isFalse);
      expect(snap.latest, isNull);
    });
  });
}
