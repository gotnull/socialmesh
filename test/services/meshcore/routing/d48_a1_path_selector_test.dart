// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A1: pure `selectPathForAttempt` + weight helpers.
//
// Pinned invariants:
//   - empty history returns null.
//   - final attempt always returns null (flood fallback).
//   - single-path history returns its bytes on non-final attempts.
//   - higher composite score is picked first.
//   - tie-breaker is deterministic across input ordering.
//   - diversity window avoids re-picking recently selected paths.
//   - evicted (routeWeight <= 0) entries are skipped.
//   - weightAfterSuccess clamps to settings.maxRouteWeight.
//   - weightAfterFailure can return ≤ 0 (caller treats as eviction).

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
  );
}

final _settings = const MeshCoreAutoRouteSettings(enabled: true);

void main() {
  group('selectPathForAttempt - D48-A1', () {
    test('empty history returns null', () {
      final r = selectPathForAttempt(
        history: const [],
        attemptIndex: 0,
        maxAttempts: 3,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, isNull);
    });

    test('final attempt always returns null (flood fallback)', () {
      final r = selectPathForAttempt(
        history: [
          _entry(id: 'a', bytes: [0x11]),
        ],
        attemptIndex: 2,
        maxAttempts: 3,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, isNull);
    });

    test('single-path history returns its bytes on non-final attempts', () {
      final r = selectPathForAttempt(
        history: [
          _entry(id: 'a', bytes: [0x11, 0x22]),
        ],
        attemptIndex: 1,
        maxAttempts: 3,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, isNotNull);
      expect(r, equals([0x11, 0x22]));
    });

    test('higher composite score picked first', () {
      // Same recency; weight + reliability differ.
      final r = selectPathForAttempt(
        history: [
          _entry(
            id: 'low',
            bytes: [0x01],
            successCount: 0,
            failureCount: 3,
            routeWeight: 1.0,
          ),
          _entry(
            id: 'high',
            bytes: [0x02],
            successCount: 5,
            failureCount: 0,
            routeWeight: 5.0,
          ),
        ],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, equals([0x02]));
    });

    test('tie-breaker is deterministic across input ordering', () {
      // Two identical entries (same weight, same recency, same
      // counts), different bytes. Tiebreaker: shorter length wins,
      // then lexically smaller.
      final a = _entry(id: 'a', bytes: [0x99, 0x88], routeWeight: 3.0);
      final b = _entry(id: 'b', bytes: [0x10, 0x20], routeWeight: 3.0);
      final c = _entry(id: 'c', bytes: [0x05, 0x05, 0x05], routeWeight: 3.0);

      final r1 = selectPathForAttempt(
        history: [a, b, c],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      final r2 = selectPathForAttempt(
        history: [c, b, a],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      // Shorter (a/b are 2 bytes; c is 3) wins on tier 2. Among
      // the 2-byte entries, lex-smaller wins: 0x10 0x20 < 0x99 0x88.
      expect(r1, equals([0x10, 0x20]));
      expect(r2, equals([0x10, 0x20]));
    });

    test('diversity window avoids recently selected paths', () {
      final r = selectPathForAttempt(
        history: [
          _entry(id: 'a', bytes: [0x01], routeWeight: 5.0),
          _entry(id: 'b', bytes: [0x02], routeWeight: 4.0),
        ],
        attemptIndex: 2,
        maxAttempts: 5,
        recentSelections: [
          Uint8List.fromList([0x01]),
        ],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      // 0x01 is in the diversity window so 0x02 wins despite being
      // lower-weighted.
      expect(r, equals([0x02]));
    });

    test('evicted entries (routeWeight <= 0) are skipped', () {
      final r = selectPathForAttempt(
        history: [
          _entry(id: 'dead', bytes: [0x01], routeWeight: 0.0),
          _entry(id: 'live', bytes: [0x02], routeWeight: 3.0),
        ],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, equals([0x02]));
    });

    test('all entries dead returns null', () {
      final r = selectPathForAttempt(
        history: [
          _entry(id: 'a', bytes: [0x01], routeWeight: 0.0),
          _entry(id: 'b', bytes: [0x02], routeWeight: -0.5),
        ],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, isNull);
    });

    test('all entries in diversity window returns null', () {
      final r = selectPathForAttempt(
        history: [
          _entry(id: 'a', bytes: [0x01]),
          _entry(id: 'b', bytes: [0x02]),
        ],
        attemptIndex: 2,
        maxAttempts: 5,
        recentSelections: [
          Uint8List.fromList([0x01]),
          Uint8List.fromList([0x02]),
        ],
        settings: _settings,
        now: DateTime.utc(2026, 5, 14),
      );
      expect(r, isNull);
    });

    test('freshness decays over 7 days', () {
      final base = DateTime.utc(2026, 5, 14);
      final r = selectPathForAttempt(
        history: [
          _entry(
            id: 'fresh',
            bytes: [0x01],
            routeWeight: 3.0,
            successCount: 1,
            lastUsedAt: base,
          ),
          _entry(
            id: 'stale',
            bytes: [0x02],
            routeWeight: 3.0,
            successCount: 1,
            // 30 days old → freshness component is 0.
            lastUsedAt: base.subtract(const Duration(days: 30)),
          ),
        ],
        attemptIndex: 1,
        maxAttempts: 5,
        recentSelections: const [],
        settings: _settings,
        now: base,
      );
      expect(r, equals([0x01]));
    });
  });

  group('weightAfterSuccess - D48-A1', () {
    test('bumps by settings.routeWeightSuccessIncrement', () {
      expect(weightAfterSuccess(2.0, _settings), closeTo(2.5, 1e-9));
    });

    test('clamps to settings.maxRouteWeight', () {
      expect(
        weightAfterSuccess(4.9, _settings),
        closeTo(5.0, 1e-9),
        reason: '4.9 + 0.5 = 5.4 should clamp to default max 5.0',
      );
    });

    test('does not go negative on already-zero starting weight', () {
      expect(weightAfterSuccess(0.0, _settings), closeTo(0.5, 1e-9));
    });
  });

  group('weightAfterFailure - D48-A1', () {
    test('decrements by settings.routeWeightFailureDecrement', () {
      expect(weightAfterFailure(3.0, _settings), closeTo(2.8, 1e-9));
    });

    test('returns ≤ 0 to signal eviction', () {
      final r = weightAfterFailure(0.1, _settings);
      expect(r, lessThanOrEqualTo(0.0));
    });

    test('does not clamp the floor (caller treats as eviction signal)', () {
      // After multiple failures the value can go significantly
      // negative; that's fine.
      var w = 2.0;
      for (var i = 0; i < 20; i++) {
        w = weightAfterFailure(w, _settings);
      }
      expect(w, lessThan(0));
    });
  });
}
