// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'reticulum_fragment_event.dart';

typedef ReticulumEncounterRecorder =
    void Function(int nodeId, DateTime timestamp);

/// Idempotency-guarded NodeDex encounter recorder for port-76 fragment
/// activity.
///
/// Mirrors the dedup window used by the existing message-driven NodeDex
/// hook — a single inbound fragment can be observed multiple times via
/// rebroadcast routing, and we don't want each replay to count as a
/// separate encounter.
class ReticulumNodeDexBridge {
  ReticulumNodeDexBridge({
    required this.recordEncounter,
    this.dedupWindow = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Callback invoked when a fragment passes the dedup window. Wired by
  /// the provider layer to `nodeDexProvider.notifier.recordEncounter`.
  final ReticulumEncounterRecorder recordEncounter;

  /// How long to suppress duplicate hits for the same fragment-key.
  final Duration dedupWindow;

  final DateTime Function() _clock;
  final Map<String, DateTime> _hookKeys = <String, DateTime>{};

  /// Number of cached dedup keys (exposed for tests).
  int get cachedKeyCount => _hookKeys.length;

  void onFragment(ReticulumFragmentEvent event) {
    final key = keyForEvent(event);
    final now = _clock();
    final priorAt = _hookKeys[key];
    if (priorAt != null && now.difference(priorAt) <= dedupWindow) {
      return;
    }
    _hookKeys[key] = now;
    _hookKeys.removeWhere((_, ts) => now.difference(ts) > dedupWindow);

    final eventTime = DateTime.fromMillisecondsSinceEpoch(event.timestampMs);
    recordEncounter(event.fromNode, eventTime);
  }

  /// Pure key derivation — exposed for tests.
  static String keyForEvent(ReticulumFragmentEvent event) {
    if (event.packetId != 0) {
      return 'pid:${event.fromNode}:${event.packetId}';
    }
    final prefixLen = event.payloadLen < 16 ? event.payloadLen : 16;
    final hex = StringBuffer();
    for (var i = 0; i < prefixLen; i++) {
      hex.write(event.payload[i].toRadixString(16).padLeft(2, '0'));
    }
    return 'sig:${event.fromNode}:$hex';
  }
}
