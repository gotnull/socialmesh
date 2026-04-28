// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment_event.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_stats.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_stats_recorder.dart';

void main() {
  group('ReticulumStatsRecorder', () {
    test('starts at empty state', () {
      final recorder = ReticulumStatsRecorder();
      addTearDown(recorder.dispose);
      expect(recorder.current.totalFragments, 0);
      expect(recorder.current.lastSeenMs, isNull);
      expect(recorder.current.distinctSourceCount, 0);
    });

    test('increments counters and tracks distinct sources', () {
      final recorder = ReticulumStatsRecorder();
      addTearDown(recorder.dispose);
      recorder.recordFragment(_event(fromNode: 1, payloadLen: 10));
      recorder.recordFragment(_event(fromNode: 2, payloadLen: 20));
      recorder.recordFragment(_event(fromNode: 1, payloadLen: 12));
      expect(recorder.current.totalFragments, 3);
      expect(recorder.current.distinctSourceCount, 2);
      expect(recorder.current.lastSeenMs, isNotNull);
    });

    test('running mean of payload size matches arithmetic mean', () {
      final recorder = ReticulumStatsRecorder();
      addTearDown(recorder.dispose);
      const sizes = [4, 8, 12, 16];
      for (final s in sizes) {
        recorder.recordFragment(_event(fromNode: 1, payloadLen: s));
      }
      final expected = sizes.reduce((a, b) => a + b) / sizes.length;
      expect(recorder.current.avgFragmentSize, closeTo(expected, 0.0001));
    });

    test('top-N LRU evicts beyond the limit', () {
      final recorder = ReticulumStatsRecorder();
      addTearDown(recorder.dispose);
      for (var i = 0; i < ReticulumStats.topSourcesLimit + 5; i++) {
        recorder.recordFragment(_event(fromNode: i, payloadLen: 1));
      }
      expect(
        recorder.current.topSources.length,
        ReticulumStats.topSourcesLimit,
      );
      // The earliest sources should have been evicted; the most recent
      // (highest IDs) should be present.
      final ids = recorder.current.topSources.map((s) => s.nodeId).toSet();
      expect(ids, contains(ReticulumStats.topSourcesLimit + 4));
      expect(ids, isNot(contains(0)));
    });

    test('topSources are ordered by recency descending', () {
      final recorder = ReticulumStatsRecorder();
      addTearDown(recorder.dispose);
      recorder.recordFragment(
        _event(fromNode: 1, timestampMs: 100, payloadLen: 1),
      );
      recorder.recordFragment(
        _event(fromNode: 2, timestampMs: 200, payloadLen: 1),
      );
      recorder.recordFragment(
        _event(fromNode: 3, timestampMs: 150, payloadLen: 1),
      );
      // Bump 1 to be most recent.
      recorder.recordFragment(
        _event(fromNode: 1, timestampMs: 300, payloadLen: 1),
      );
      final order = recorder.current.topSources
          .map((s) => s.nodeId)
          .toList(growable: false);
      expect(order, [1, 2, 3]);
    });

    test('source fragmentCount accumulates per source', () {
      final recorder = ReticulumStatsRecorder();
      addTearDown(recorder.dispose);
      for (var i = 0; i < 5; i++) {
        recorder.recordFragment(
          _event(fromNode: 7, timestampMs: 100 + i, payloadLen: 1),
        );
      }
      final source = recorder.current.topSources.firstWhere(
        (s) => s.nodeId == 7,
      );
      expect(source.fragmentCount, 5);
    });

    test('rolling window prunes outside 60 s', () {
      var nowMs = 1000;
      final recorder = ReticulumStatsRecorder(
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      addTearDown(recorder.dispose);
      // 5 fragments within window.
      for (var i = 0; i < 5; i++) {
        recorder.recordFragment(_event(fromNode: 1, payloadLen: 1));
        nowMs += 1000;
      }
      expect(recorder.current.fragmentsPerSecond, closeTo(5 / 60.0, 0.001));

      // Advance well past 60 s and tick — window should empty out.
      nowMs += 120_000;
      recorder.tick();
      expect(recorder.current.fragmentsPerSecond, 0.0);
    });
  });
}

ReticulumFragmentEvent _event({
  required int fromNode,
  required int payloadLen,
  int? timestampMs,
}) {
  return ReticulumFragmentEvent(
    timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    fromNode: fromNode,
    toNode: 0xFFFFFFFF,
    packetId: 0,
    channel: 0,
    rssi: null,
    snr: null,
    payload: Uint8List(payloadLen),
  );
}
