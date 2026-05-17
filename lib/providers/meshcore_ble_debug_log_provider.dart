// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q5: Riverpod 3.x bindings for the BLE debug log store. The
// store is a long-lived singleton (one buffer for the lifetime of
// the app) so the BLE transport can append to it from anywhere and
// the viewer screen can pull the live stream without losing entries
// during navigation.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/meshcore/diagnostics/meshcore_ble_debug_log_store.dart';

/// Singleton ring buffer. Kept alive for the lifetime of the app so
/// BLE events fired from `MeshCoreBleTransport` are captured even
/// when the viewer screen isn't mounted.
final meshCoreBleDebugLogStoreProvider = Provider<MeshCoreBleDebugLogStore>((
  ref,
) {
  final store = MeshCoreBleDebugLogStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Composite snapshot exposing both the entry list and the paused
/// flag in a single emission so the viewer can drive the entire UI
/// (list + chip + clear button) from one `ref.watch` call.
class MeshCoreBleDebugLogSnapshot {
  final List<MeshCoreBleDebugLogEntry> entries;
  final bool paused;

  const MeshCoreBleDebugLogSnapshot({
    required this.entries,
    required this.paused,
  });

  const MeshCoreBleDebugLogSnapshot.empty()
    : entries = const [],
      paused = false;
}

/// Reactive snapshot. The store's broadcast stream fires on every
/// mutation (append / clear / pause / resume), so re-watching here
/// gives the viewer everything it needs on each emission.
final meshCoreBleDebugLogSnapshotProvider =
    StreamProvider<MeshCoreBleDebugLogSnapshot>((ref) async* {
      final store = ref.watch(meshCoreBleDebugLogStoreProvider);
      // Seed the current state up-front so a fresh screen open
      // doesn't briefly show the empty placeholder while waiting
      // for the next event.
      yield MeshCoreBleDebugLogSnapshot(
        entries: store.snapshot(),
        paused: store.isPaused,
      );
      await for (final entries in store.stream) {
        yield MeshCoreBleDebugLogSnapshot(
          entries: entries,
          paused: store.isPaused,
        );
      }
    });
