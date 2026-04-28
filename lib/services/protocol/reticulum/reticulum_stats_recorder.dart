// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:collection';

import 'reticulum_fragment_event.dart';
import 'reticulum_stats.dart';

/// Maintains [ReticulumStats] from a stream of fragment events.
///
/// Pure logic, no I/O. The owning provider is responsible for feeding
/// fragment events via [recordFragment] and for emitting snapshots via
/// the [stats] stream.
class ReticulumStatsRecorder {
  ReticulumStatsRecorder({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  final StreamController<ReticulumStats> _statsController =
      StreamController<ReticulumStats>.broadcast();

  final Set<int> _distinctSources = <int>{};

  /// Insertion-ordered map keyed by nodeId. Most-recently-seen entries
  /// are moved to the end on update; eviction drops from the head.
  final LinkedHashMap<int, _SourceState> _sources =
      LinkedHashMap<int, _SourceState>();

  /// Sliding-window timestamps in ms for [_recomputeFragmentsPerSecond].
  final Queue<int> _windowTimestampsMs = Queue<int>();

  ReticulumStats _state = ReticulumStats.empty;

  Stream<ReticulumStats> get stats => _statsController.stream;
  ReticulumStats get current => _state;

  void recordFragment(ReticulumFragmentEvent event) {
    final nowMs = _clock().millisecondsSinceEpoch;

    // Distinct sources.
    _distinctSources.add(event.fromNode);

    // Top-N LRU by recency.
    final existing = _sources.remove(event.fromNode);
    final updatedCount = (existing?.count ?? 0) + 1;
    _sources[event.fromNode] = _SourceState(
      count: updatedCount,
      lastSeenMs: event.timestampMs,
    );
    while (_sources.length > ReticulumStats.topSourcesLimit) {
      _sources.remove(_sources.keys.first);
    }

    // Rolling-window fragments/sec.
    _windowTimestampsMs.add(nowMs);
    _pruneWindow(nowMs);

    // Running mean of payload size.
    final newTotal = _state.totalFragments + 1;
    final newAvg =
        _state.avgFragmentSize +
        (event.payloadLen - _state.avgFragmentSize) / newTotal;

    _state = ReticulumStats(
      totalFragments: newTotal,
      lastSeenMs: event.timestampMs,
      topSources: _topSourcesByRecency(),
      avgFragmentSize: newAvg,
      fragmentsPerSecond: _computeFragmentsPerSecond(),
      distinctSourceCount: _distinctSources.length,
    );
    _statsController.add(_state);
  }

  /// Force a recompute of the rolling window without ingesting an event.
  /// Useful for UI refresh ticks so the rate decays toward zero when
  /// traffic stops.
  void tick() {
    final nowMs = _clock().millisecondsSinceEpoch;
    final beforeLen = _windowTimestampsMs.length;
    _pruneWindow(nowMs);
    if (_windowTimestampsMs.length == beforeLen) return;
    _state = _state.copyWith(fragmentsPerSecond: _computeFragmentsPerSecond());
    _statsController.add(_state);
  }

  void _pruneWindow(int nowMs) {
    final cutoff = nowMs - (ReticulumStats.rollingWindowSeconds * 1000);
    while (_windowTimestampsMs.isNotEmpty &&
        _windowTimestampsMs.first < cutoff) {
      _windowTimestampsMs.removeFirst();
    }
  }

  double _computeFragmentsPerSecond() {
    if (_windowTimestampsMs.isEmpty) return 0.0;
    return _windowTimestampsMs.length / ReticulumStats.rollingWindowSeconds;
  }

  List<ReticulumStatsSource> _topSourcesByRecency() {
    final entries = _sources.entries.toList();
    entries.sort((a, b) => b.value.lastSeenMs.compareTo(a.value.lastSeenMs));
    return entries
        .map(
          (e) => ReticulumStatsSource(
            nodeId: e.key,
            fragmentCount: e.value.count,
            lastSeenMs: e.value.lastSeenMs,
          ),
        )
        .toList(growable: false);
  }

  Future<void> dispose() async {
    await _statsController.close();
  }
}

class _SourceState {
  const _SourceState({required this.count, required this.lastSeenMs});
  final int count;
  final int lastSeenMs;
}
