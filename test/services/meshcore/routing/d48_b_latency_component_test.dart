// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-B: latency component of the composite path-selection score.
//
// Pinned invariants:
//   - `emaAvgTripTimeMs` on first sample (current == 0) returns the
//     sample verbatim.
//   - `emaAvgTripTimeMs` with negative sample is a no-op.
//   - `emaAvgTripTimeMs` blends at 0.7 / 0.3 toward the new sample.
//   - `latencyComponentForEntry` returns the neutral 0.5 for
//     entries with no sample yet (`avgTripTimeMs == 0`).
//   - linear decay from 1.0 (fast) to 0.0 (ceiling). Clamped past
//     ceiling.
//   - faster path wins when other components tie.
//   - JSON round-trip preserves `avgTripTimeMs`.
//   - legacy rows without the field hydrate to 0 (no regression).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_auto_route_settings.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_path_selector.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

MeshCorePathHistoryEntry _entry({
  required String id,
  required List<int> bytes,
  DateTime? lastUsedAt,
  int successCount = 0,
  int failureCount = 0,
  double routeWeight = 3.0,
  double avgTripTimeMs = 0.0,
}) {
  final now = DateTime.utc(2026, 5, 14);
  return MeshCorePathHistoryEntry(
    id: id,
    bytes: Uint8List.fromList(bytes),
    len: bytes.length,
    source: MeshCorePathSource.trace,
    createdAt: lastUsedAt ?? now,
    lastUsedAt: lastUsedAt ?? now,
    successCount: successCount,
    failureCount: failureCount,
    routeWeight: routeWeight,
    avgTripTimeMs: avgTripTimeMs,
  );
}

final _settings = const MeshCoreAutoRouteSettings(enabled: true);

void main() {
  group('emaAvgTripTimeMs - D48-B', () {
    test('first sample replaces verbatim (no warm-up distortion)', () {
      expect(emaAvgTripTimeMs(0, 500), closeTo(500, 1e-9));
    });

    test('negative or zero new sample is a no-op', () {
      expect(emaAvgTripTimeMs(400, 0), closeTo(400, 1e-9));
      expect(emaAvgTripTimeMs(400, -1), closeTo(400, 1e-9));
    });

    test('blends 0.7 old + 0.3 new', () {
      expect(emaAvgTripTimeMs(1000, 2000), closeTo(1300, 1e-9));
      expect(emaAvgTripTimeMs(1300, 2000), closeTo(1510, 1e-9));
    });

    test('three samples of a new RTT pull the average ~66% there', () {
      var avg = 1000.0;
      for (var i = 0; i < 3; i++) {
        avg = emaAvgTripTimeMs(avg, 5000.0);
      }
      // After 3 samples: 0.343 * 1000 + (1 - 0.343) * 5000 = 3631
      expect(avg, greaterThan(3500.0));
      expect(avg, lessThan(3800.0));
    });
  });

  group('latencyComponentForEntry - D48-B', () {
    test('no sample yet returns the neutral 0.5', () {
      final e = _entry(id: 'a', bytes: [0x01], avgTripTimeMs: 0.0);
      expect(
        latencyComponentForEntry(e),
        equals(kMeshCorePathLatencyNeutralScore),
      );
    });

    test('defensive negative also returns neutral', () {
      final e = _entry(id: 'a', bytes: [0x01], avgTripTimeMs: -100);
      expect(
        latencyComponentForEntry(e),
        equals(kMeshCorePathLatencyNeutralScore),
      );
    });

    test('linear decay from 1.0 at 0ms toward 0.0 at the ceiling', () {
      final fast = _entry(id: 'a', bytes: [0x01], avgTripTimeMs: 1000);
      final mid = _entry(id: 'b', bytes: [0x02], avgTripTimeMs: 5000);
      final slow = _entry(
        id: 'c',
        bytes: [0x03],
        avgTripTimeMs: kMeshCorePathLatencyCeilingMs - 1,
      );

      expect(latencyComponentForEntry(fast), closeTo(0.9, 1e-9));
      expect(latencyComponentForEntry(mid), closeTo(0.5, 1e-9));
      expect(latencyComponentForEntry(slow), greaterThan(0.0));
      expect(latencyComponentForEntry(slow), lessThan(0.001));
    });

    test('past the ceiling clamps to 0.0', () {
      final stuck = _entry(id: 'a', bytes: [0x01], avgTripTimeMs: 30000.0);
      expect(latencyComponentForEntry(stuck), equals(0.0));
    });
  });

  group('composite via selectPathForAttempt - D48-B', () {
    test('when all else is equal, faster path wins', () {
      final slow = _entry(
        id: 'slow',
        bytes: [0x01],
        successCount: 3,
        avgTripTimeMs: 8000,
      );
      final fast = _entry(
        id: 'fast',
        bytes: [0x02],
        successCount: 3,
        avgTripTimeMs: 500,
      );

      final r = selectPathForAttempt(
        history: [slow, fast],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, equals([0x02]));
    });

    test('a no-sample path is NOT penalized against a slow-but-measured one '
        'when everything else is equal: the neutral 0.5 sits above the '
        'slow path\'s score', () {
      // Both have identical success / weight / freshness; only the
      // measured RTT differs. The slow path's latency component is
      // 0.05 (≈ near ceiling), the unmeasured one's is 0.5 neutral.
      final measuredSlow = _entry(
        id: 'measured',
        bytes: [0x01],
        successCount: 5,
        avgTripTimeMs: 9500,
      );
      final unmeasured = _entry(
        id: 'unknown',
        bytes: [0x02],
        successCount: 5,
        avgTripTimeMs: 0,
      );

      final r = selectPathForAttempt(
        history: [measuredSlow, unmeasured],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, equals([0x02]));
    });
  });

  group('MeshCorePathHistoryEntry avgTripTimeMs schema - D48-B', () {
    test('default is 0', () {
      final e = MeshCorePathHistoryEntry(
        id: 'a',
        bytes: Uint8List.fromList([0x01]),
        len: 1,
        source: MeshCorePathSource.trace,
        createdAt: DateTime.utc(2026, 5, 14),
        lastUsedAt: DateTime.utc(2026, 5, 14),
      );
      expect(e.avgTripTimeMs, 0.0);
    });

    test('JSON round-trip preserves the value', () {
      final original = _entry(id: 'a', bytes: [0x10], avgTripTimeMs: 1234.5);
      final parsed = MeshCorePathHistoryEntry.fromJson(original.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.avgTripTimeMs, closeTo(1234.5, 1e-9));
    });

    test('legacy rows without the field hydrate to 0', () {
      final legacy = <String, Object?>{
        'id': 'legacy',
        'bytes': 'AQ==', // base64 of [0x01]
        'len': 1,
        'source': 'trace',
        'createdAt': DateTime.utc(2026, 5, 14).millisecondsSinceEpoch,
        'lastUsedAt': DateTime.utc(2026, 5, 14).millisecondsSinceEpoch,
        'successCount': 2,
        // No avgTripTimeMs key.
      };
      final parsed = MeshCorePathHistoryEntry.fromJson(legacy);
      expect(parsed, isNotNull);
      expect(parsed!.avgTripTimeMs, 0.0);
    });
  });
}
