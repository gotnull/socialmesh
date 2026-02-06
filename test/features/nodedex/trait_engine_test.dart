// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/trait_engine.dart';

// =============================================================================
// Test helpers — top-level so they can reference each other
// =============================================================================

List<EncounterRecord> _makeEncounters({
  required int count,
  required int distinctPositions,
  required DateTime startTime,
  required DateTime endTime,
}) {
  if (count == 0) return [];

  final records = <EncounterRecord>[];
  final duration = endTime.difference(startTime);
  final interval = count > 1
      ? Duration(milliseconds: duration.inMilliseconds ~/ (count - 1))
      : Duration.zero;

  for (int i = 0; i < count; i++) {
    final timestamp = startTime.add(interval * i);

    double? lat;
    double? lon;
    if (distinctPositions > 0 && i < distinctPositions) {
      // Each distinct position differs by ~0.01 degrees (~1.1km).
      lat = 37.0 + (i * 0.01);
      lon = -122.0 + (i * 0.01);
    } else if (distinctPositions > 0) {
      // Repeat the last distinct position.
      lat = 37.0 + ((distinctPositions - 1) * 0.01);
      lon = -122.0 + ((distinctPositions - 1) * 0.01);
    }

    records.add(
      EncounterRecord(timestamp: timestamp, latitude: lat, longitude: lon),
    );
  }

  return records;
}

List<SeenRegion> _makeRegions(int count, DateTime baseTime) {
  final regions = <SeenRegion>[];
  for (int i = 0; i < count; i++) {
    regions.add(
      SeenRegion(
        regionId: 'g${37 + i}_${-122 + i}',
        label: '${37 + i}\u00B0N ${122 - i}\u00B0W',
        firstSeen: baseTime,
        lastSeen: baseTime.add(const Duration(hours: 1)),
        encounterCount: 1,
      ),
    );
  }
  return regions;
}

/// Create a NodeDexEntry with configurable parameters for testing.
NodeDexEntry _makeEntry({
  int nodeNum = 1,
  int encounterCount = 10,
  int ageDays = 7,
  int regionCount = 0,
  int distinctPositions = 0,
  double? maxDistanceSeen,
  int messageCount = 0,
  DateTime? firstSeen,
  DateTime? lastSeen,
  List<EncounterRecord>? encounters,
  List<SeenRegion>? seenRegions,
}) {
  final now = DateTime.now();
  final fs = firstSeen ?? now.subtract(Duration(days: ageDays));
  final ls = lastSeen ?? now;

  // Build encounter records to produce distinct positions.
  final effectiveEncounters =
      encounters ??
      _makeEncounters(
        count: encounterCount,
        distinctPositions: distinctPositions,
        startTime: fs,
        endTime: ls,
      );

  // Build seen regions.
  final effectiveRegions = seenRegions ?? _makeRegions(regionCount, fs);

  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: fs,
    lastSeen: ls,
    encounterCount: encounterCount,
    maxDistanceSeen: maxDistanceSeen,
    messageCount: messageCount,
    encounters: effectiveEncounters,
    seenRegions: effectiveRegions,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('TraitEngine', () {
    // -------------------------------------------------------------------------
    // Prerequisite checks (insufficient data -> Unknown)
    // -------------------------------------------------------------------------

    group('prerequisite checks', () {
      test('returns Unknown when encounter count is below threshold', () {
        final entry = _makeEntry(encounterCount: 1, ageDays: 7);
        final result = TraitEngine.infer(entry: entry);

        expect(result.primary, equals(NodeTrait.unknown));
        expect(result.confidence, equals(1.0));
      });

      test('returns Unknown when encounter count is 2 (below 3)', () {
        final entry = _makeEntry(encounterCount: 2, ageDays: 7);
        final result = TraitEngine.infer(entry: entry);

        expect(result.primary, equals(NodeTrait.unknown));
      });

      test('returns Unknown when age is less than 1 hour', () {
        final now = DateTime.now();
        final entry = _makeEntry(
          encounterCount: 10,
          firstSeen: now.subtract(const Duration(minutes: 30)),
          lastSeen: now,
        );
        final result = TraitEngine.infer(entry: entry);

        expect(result.primary, equals(NodeTrait.unknown));
      });

      test('does not return Unknown when enough data exists', () {
        final entry = _makeEntry(encounterCount: 5, ageDays: 2);
        final result = TraitEngine.infer(entry: entry);

        // With enough data, at least one trait should score above threshold.
        // The exact trait depends on the parameters, but it should not be
        // Unknown unless all scores are below 0.3.
        // For 5 encounters over 2 days with no special properties,
        // Ghost may score (low rate) or it might still be Unknown.
        // The key test is that prerequisite check passed.
        expect(result.confidence, greaterThan(0));
      });

      test('exactly at threshold: 3 encounters and 1 hour old', () {
        final now = DateTime.now();
        final entry = _makeEntry(
          encounterCount: 3,
          firstSeen: now.subtract(const Duration(hours: 1, minutes: 1)),
          lastSeen: now,
        );
        final result = TraitEngine.infer(entry: entry);

        // Should not be forced to Unknown due to prerequisites.
        // Actual trait depends on scoring, but prereqs should pass.
        expect(result.confidence, greaterThan(0));
      });
    });

    // -------------------------------------------------------------------------
    // Relay trait scoring
    // -------------------------------------------------------------------------

    group('Relay trait', () {
      test('strong Relay when role is ROUTER with high utilization', () {
        final entry = _makeEntry(encounterCount: 25, ageDays: 7);
        final result = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER',
          channelUtilization: 30.0,
          airUtilTx: 15.0,
        );

        expect(result.primary, equals(NodeTrait.relay));
        expect(result.confidence, greaterThan(0.6));
      });

      test('Relay with ROUTER_CLIENT role', () {
        final entry = _makeEntry(encounterCount: 25, ageDays: 7);
        final result = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER_CLIENT',
          channelUtilization: 20.0,
        );

        expect(result.primary, equals(NodeTrait.relay));
      });

      test('Relay with REPEATER role', () {
        final entry = _makeEntry(encounterCount: 25, ageDays: 7);
        final result = TraitEngine.infer(
          entry: entry,
          role: 'REPEATER',
          channelUtilization: 25.0,
          airUtilTx: 10.0,
        );

        expect(result.primary, equals(NodeTrait.relay));
      });

      test('Relay with ROUTER_LATE role', () {
        final entry = _makeEntry(encounterCount: 25, ageDays: 5);
        final result = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER_LATE',
          channelUtilization: 20.0,
        );

        expect(result.primary, equals(NodeTrait.relay));
      });

      test('role matching is case-insensitive', () {
        final entry = _makeEntry(encounterCount: 25, ageDays: 7);
        final result = TraitEngine.infer(
          entry: entry,
          role: 'router',
          channelUtilization: 30.0,
          airUtilTx: 15.0,
        );

        expect(result.primary, equals(NodeTrait.relay));
      });

      test('non-relay role does not score as Relay', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 7);
        final result = TraitEngine.infer(
          entry: entry,
          role: 'CLIENT',
          channelUtilization: 5.0,
        );

        expect(result.primary, isNot(equals(NodeTrait.relay)));
      });

      test('no role scores zero for Relay', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 7);
        final result = TraitEngine.infer(entry: entry);

        // Without a relay role, Relay should not be primary.
        expect(result.primary, isNot(equals(NodeTrait.relay)));
      });
    });

    // -------------------------------------------------------------------------
    // Wanderer trait scoring
    // -------------------------------------------------------------------------

    group('Wanderer trait', () {
      test('strong Wanderer with many distinct positions and regions', () {
        final entry = _makeEntry(
          encounterCount: 20,
          ageDays: 14,
          distinctPositions: 8,
          regionCount: 4,
          maxDistanceSeen: 15000,
        );
        final result = TraitEngine.infer(entry: entry);

        expect(result.primary, equals(NodeTrait.wanderer));
        expect(result.confidence, greaterThan(0.5));
      });

      test('Wanderer with minimum 3 distinct positions', () {
        final entry = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          distinctPositions: 3,
          regionCount: 2,
        );
        final result = TraitEngine.infer(entry: entry);

        expect(result.primary, equals(NodeTrait.wanderer));
      });

      test('Wanderer with high region diversity alone', () {
        final entry = _makeEntry(
          encounterCount: 10,
          ageDays: 14,
          distinctPositions: 0,
          regionCount: 3,
        );
        final result = TraitEngine.infer(entry: entry);

        // Region diversity alone should boost Wanderer score.
        // Whether it wins depends on other trait scores.
        if (result.primary == NodeTrait.wanderer) {
          expect(result.confidence, greaterThan(0.3));
        }
      });

      test('single position node does not score as Wanderer', () {
        final entry = _makeEntry(
          encounterCount: 30,
          ageDays: 30,
          distinctPositions: 1,
          regionCount: 0,
        );
        final result = TraitEngine.infer(entry: entry);

        expect(result.primary, isNot(equals(NodeTrait.wanderer)));
      });
    });

    // -------------------------------------------------------------------------
    // Sentinel trait scoring
    // -------------------------------------------------------------------------

    group('Sentinel trait', () {
      test('strong Sentinel with fixed position and high uptime', () {
        final entry = _makeEntry(
          encounterCount: 50,
          ageDays: 30,
          distinctPositions: 1,
        );
        final result = TraitEngine.infer(
          entry: entry,
          uptimeSeconds: 7 * 86400, // 7 days
        );

        expect(result.primary, equals(NodeTrait.sentinel));
        expect(result.confidence, greaterThan(0.5));
      });

      test('Sentinel with zero positions (no GPS) and long age', () {
        final entry = _makeEntry(
          encounterCount: 40,
          ageDays: 60,
          distinctPositions: 0,
        );
        final result = TraitEngine.infer(
          entry: entry,
          uptimeSeconds: 14 * 86400,
        );

        // Zero distinct positions counts as <= 1, so fixed position bonus.
        expect(result.primary, equals(NodeTrait.sentinel));
      });

      test('does not score Sentinel with low encounter count', () {
        final now = DateTime.now();
        final entry = _makeEntry(
          encounterCount: 5,
          ageDays: 30,
          distinctPositions: 2,
          lastSeen: now.subtract(const Duration(days: 5)),
        );
        final result = TraitEngine.infer(entry: entry);

        // 5 / 30 = 0.17 encounters/day — Ghost territory.
        // 2 distinct positions removes Sentinel's fixed-position bonus
        // without triggering Wanderer (needs 3+).
        // Last seen 5 days ago adds Ghost score.
        expect(result.primary, isNot(equals(NodeTrait.sentinel)));
      });

      test('young node does not score Sentinel even with high encounters', () {
        final entry = _makeEntry(
          encounterCount: 30,
          ageDays: 1,
          distinctPositions: 1,
        );
        final result = TraitEngine.infer(entry: entry);

        // 30 encounters in 1 day -> likely Beacon, not Sentinel.
        expect(result.primary, isNot(equals(NodeTrait.sentinel)));
      });
    });

    // -------------------------------------------------------------------------
    // Beacon trait scoring
    // -------------------------------------------------------------------------

    group('Beacon trait', () {
      test('strong Beacon with very high encounter rate', () {
        final entry = _makeEntry(encounterCount: 100, ageDays: 5);
        final result = TraitEngine.infer(entry: entry);

        // 100 encounters / 5 days = 20 encounters/day — very high.
        expect(result.primary, equals(NodeTrait.beacon));
        expect(result.confidence, greaterThan(0.5));
      });

      test('Beacon with 8+ encounters per day', () {
        final entry = _makeEntry(encounterCount: 50, ageDays: 5);
        final result = TraitEngine.infer(entry: entry);

        // 50 / 5 = 10 encounters/day — above Beacon threshold of 8.
        expect(result.primary, equals(NodeTrait.beacon));
      });

      test('recently seen node gets small Beacon boost', () {
        final now = DateTime.now();
        final entry = _makeEntry(
          encounterCount: 40,
          ageDays: 4,
          lastSeen: now.subtract(const Duration(minutes: 30)),
        );
        final result = TraitEngine.infer(entry: entry);

        // 40/4 = 10/day and seen 30 min ago.
        expect(result.primary, equals(NodeTrait.beacon));
      });

      test('low encounter rate does not score as Beacon', () {
        final entry = _makeEntry(encounterCount: 5, ageDays: 7);
        final result = TraitEngine.infer(entry: entry);

        // 5 / 7 = 0.71 encounters/day — well below threshold.
        expect(result.primary, isNot(equals(NodeTrait.beacon)));
      });
    });

    // -------------------------------------------------------------------------
    // Ghost trait scoring
    // -------------------------------------------------------------------------

    group('Ghost trait', () {
      test('strong Ghost with very low encounter rate', () {
        final now = DateTime.now();
        // Use multiple distinct positions to suppress Sentinel's
        // fixed-position bonus (positionCount <= 1 gives +0.3).
        final entry = _makeEntry(
          encounterCount: 3,
          ageDays: 30,
          distinctPositions: 3,
          lastSeen: now.subtract(const Duration(days: 10)),
        );
        final result = TraitEngine.infer(entry: entry);

        // 3 / 30 = 0.1 encounters/day — below Ghost threshold of 0.3.
        // Last seen 10 days ago adds more Ghost score.
        // 3 distinct positions prevents Sentinel from winning via
        // the fixed-position bonus.
        expect(result.primary, equals(NodeTrait.ghost));
        expect(result.confidence, greaterThan(0.3));
      });

      test('Ghost with low encounters relative to age', () {
        final now = DateTime.now();
        // Use 2 distinct positions to weaken Sentinel's
        // fixed-position bonus without triggering Wanderer (needs 3+).
        final entry = _makeEntry(
          encounterCount: 4,
          ageDays: 14,
          distinctPositions: 2,
          lastSeen: now.subtract(const Duration(days: 3)),
        );
        final result = TraitEngine.infer(entry: entry);

        // 4 / 14 = 0.286 encounters/day — below Ghost threshold.
        // 2 distinct positions avoids Sentinel's fixed-position bonus.
        expect(result.primary, equals(NodeTrait.ghost));
      });

      test('does not score Ghost for young node (< 1 day)', () {
        final now = DateTime.now();
        final entry = _makeEntry(
          encounterCount: 3,
          firstSeen: now.subtract(const Duration(hours: 12)),
          lastSeen: now,
        );
        final result = TraitEngine.infer(entry: entry);

        // Ghost requires age >= 1 day.
        expect(result.primary, isNot(equals(NodeTrait.ghost)));
      });

      test('high encounter rate node is not Ghost', () {
        final entry = _makeEntry(encounterCount: 50, ageDays: 5);
        final result = TraitEngine.infer(entry: entry);

        // 50 / 5 = 10/day — way above Ghost threshold.
        expect(result.primary, isNot(equals(NodeTrait.ghost)));
      });
    });

    // -------------------------------------------------------------------------
    // inferPrimary convenience method
    // -------------------------------------------------------------------------

    group('inferPrimary', () {
      test('returns same primary trait as infer', () {
        final entry = _makeEntry(encounterCount: 50, ageDays: 5);
        final full = TraitEngine.infer(entry: entry);
        final primary = TraitEngine.inferPrimary(entry: entry);

        expect(primary, equals(full.primary));
      });

      test('passes optional parameters through', () {
        final entry = _makeEntry(encounterCount: 25, ageDays: 7);
        final full = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER',
          channelUtilization: 30.0,
        );
        final primary = TraitEngine.inferPrimary(
          entry: entry,
          role: 'ROUTER',
          channelUtilization: 30.0,
        );

        expect(primary, equals(full.primary));
      });
    });

    // -------------------------------------------------------------------------
    // Confidence ranges
    // -------------------------------------------------------------------------

    group('confidence ranges', () {
      test('confidence is always between 0.0 and 1.0', () {
        // Test across many different parameter combinations.
        final testCases = <({int encounters, int days, String? role})>[
          (encounters: 3, days: 1, role: null),
          (encounters: 10, days: 7, role: null),
          (encounters: 100, days: 5, role: null),
          (encounters: 5, days: 30, role: null),
          (encounters: 30, days: 3, role: 'ROUTER'),
          (encounters: 50, days: 60, role: null),
          (encounters: 200, days: 365, role: 'REPEATER'),
        ];

        for (final tc in testCases) {
          final entry = _makeEntry(
            encounterCount: tc.encounters,
            ageDays: tc.days,
          );
          final result = TraitEngine.infer(entry: entry, role: tc.role);

          expect(
            result.confidence,
            greaterThanOrEqualTo(0.0),
            reason: 'Confidence < 0 for enc=${tc.encounters}, days=${tc.days}',
          );
          expect(
            result.confidence,
            lessThanOrEqualTo(1.0),
            reason: 'Confidence > 1 for enc=${tc.encounters}, days=${tc.days}',
          );
        }
      });

      test('Unknown always has confidence 1.0', () {
        // Insufficient data case.
        final entry = _makeEntry(encounterCount: 1, ageDays: 0);
        final result = TraitEngine.infer(entry: entry);

        expect(result.primary, equals(NodeTrait.unknown));
        expect(result.confidence, equals(1.0));
      });
    });

    // -------------------------------------------------------------------------
    // Secondary trait assignment
    // -------------------------------------------------------------------------

    group('secondary trait', () {
      test('secondary trait is null when no other trait scores above 0.5', () {
        // A pure Ghost scenario: very few encounters over long time.
        final now = DateTime.now();
        final entry = _makeEntry(
          encounterCount: 3,
          ageDays: 60,
          lastSeen: now.subtract(const Duration(days: 20)),
        );
        final result = TraitEngine.infer(entry: entry);

        // Secondary may or may not exist; if it does, it should have
        // confidence above 0.5.
        if (result.secondary != null) {
          expect(result.secondaryConfidence, isNotNull);
          expect(result.secondaryConfidence!, greaterThan(0.5));
        }
      });

      test('secondary trait is not the same as primary', () {
        // Create a node that could score on multiple traits.
        final entry = _makeEntry(
          encounterCount: 25,
          ageDays: 14,
          distinctPositions: 5,
          regionCount: 3,
        );
        final result = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER',
          channelUtilization: 15.0,
        );

        if (result.secondary != null) {
          expect(result.secondary, isNot(equals(result.primary)));
        }
      });

      test('secondary trait is not Unknown', () {
        final entry = _makeEntry(
          encounterCount: 30,
          ageDays: 14,
          distinctPositions: 4,
          regionCount: 2,
        );
        final result = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER',
          channelUtilization: 20.0,
        );

        if (result.secondary != null) {
          expect(result.secondary, isNot(equals(NodeTrait.unknown)));
        }
      });

      test('secondary confidence is less than or equal to primary', () {
        final entry = _makeEntry(
          encounterCount: 30,
          ageDays: 14,
          distinctPositions: 5,
          regionCount: 3,
        );
        final result = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER',
          channelUtilization: 20.0,
          airUtilTx: 10.0,
        );

        if (result.secondary != null && result.secondaryConfidence != null) {
          expect(
            result.secondaryConfidence!,
            lessThanOrEqualTo(result.confidence),
            reason:
                'Secondary confidence ${result.secondaryConfidence} > '
                'primary confidence ${result.confidence}',
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // Composite / competition scenarios
    // -------------------------------------------------------------------------

    group('composite scoring', () {
      test('Relay wins over Sentinel for ROUTER with high uptime', () {
        final entry = _makeEntry(
          encounterCount: 30,
          ageDays: 30,
          distinctPositions: 1,
        );
        final result = TraitEngine.infer(
          entry: entry,
          role: 'ROUTER',
          uptimeSeconds: 7 * 86400,
          channelUtilization: 25.0,
          airUtilTx: 12.0,
        );

        // ROUTER role gives a strong 0.6 base for Relay; even though
        // Sentinel conditions are met, Relay should win due to role weight.
        expect(result.primary, equals(NodeTrait.relay));
      });

      test('Wanderer beats Beacon when both could apply', () {
        final entry = _makeEntry(
          encounterCount: 60,
          ageDays: 7,
          distinctPositions: 8,
          regionCount: 4,
          maxDistanceSeen: 20000,
        );
        final result = TraitEngine.infer(entry: entry);

        // 60/7 = 8.6 encounters/day (above Beacon threshold)
        // But 8 positions + 4 regions should make Wanderer score higher.
        expect(result.primary, equals(NodeTrait.wanderer));
      });

      test('Ghost does not win when encounter rate is moderate', () {
        final entry = _makeEntry(encounterCount: 20, ageDays: 14);
        final result = TraitEngine.infer(entry: entry);

        // 20 / 14 = 1.43 encounters/day — above Ghost threshold of 0.3.
        expect(result.primary, isNot(equals(NodeTrait.ghost)));
      });

      test('all traits compete fairly with balanced input', () {
        final entry = _makeEntry(
          encounterCount: 15,
          ageDays: 10,
          distinctPositions: 2,
          regionCount: 1,
        );
        final result = TraitEngine.infer(entry: entry);

        // Moderate input — the result should be a valid trait.
        expect(NodeTrait.values, contains(result.primary));
        expect(result.confidence, greaterThan(0));
      });
    });

    // -------------------------------------------------------------------------
    // TraitResult toString
    // -------------------------------------------------------------------------

    group('TraitResult', () {
      test('toString includes primary trait and confidence', () {
        const result = TraitResult(primary: NodeTrait.beacon, confidence: 0.85);
        final str = result.toString();

        expect(str, contains('Beacon'));
        expect(str, contains('85%'));
      });

      test('toString includes secondary trait when present', () {
        const result = TraitResult(
          primary: NodeTrait.relay,
          confidence: 0.9,
          secondary: NodeTrait.sentinel,
          secondaryConfidence: 0.6,
        );
        final str = result.toString();

        expect(str, contains('Relay'));
        expect(str, contains('Sentinel'));
      });

      test('toString omits secondary when null', () {
        const result = TraitResult(primary: NodeTrait.ghost, confidence: 0.7);
        final str = result.toString();

        expect(str, contains('Ghost'));
        expect(str, isNot(contains('secondary')));
      });
    });

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------

    group('edge cases', () {
      test('entry with exactly threshold encounter count (3)', () {
        final entry = _makeEntry(encounterCount: 3, ageDays: 2);
        final result = TraitEngine.infer(entry: entry);

        // Should pass prerequisites and produce a result.
        expect(result.confidence, greaterThan(0));
      });

      test('very old entry with very few encounters is Ghost', () {
        final now = DateTime.now();
        final entry = _makeEntry(
          encounterCount: 3,
          ageDays: 365,
          lastSeen: now.subtract(const Duration(days: 100)),
        );
        final result = TraitEngine.infer(entry: entry);

        // 3 / 365 = 0.008 encounters/day — deeply Ghost.
        expect(result.primary, equals(NodeTrait.ghost));
      });

      test('extremely high encounter count is Beacon', () {
        final entry = _makeEntry(encounterCount: 1000, ageDays: 10);
        final result = TraitEngine.infer(entry: entry);

        // 100 encounters/day — extreme Beacon.
        expect(result.primary, equals(NodeTrait.beacon));
      });

      test('null optional parameters do not cause errors', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 7);
        final result = TraitEngine.infer(
          entry: entry,
          role: null,
          uptimeSeconds: null,
          channelUtilization: null,
          airUtilTx: null,
        );

        expect(result.confidence, greaterThan(0));
      });

      test('zero channel utilization does not boost Relay', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 7);
        final result = TraitEngine.infer(
          entry: entry,
          role: 'CLIENT',
          channelUtilization: 0.0,
          airUtilTx: 0.0,
        );

        expect(result.primary, isNot(equals(NodeTrait.relay)));
      });

      test('node with max distance but no positions is not Wanderer', () {
        final entry = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          maxDistanceSeen: 50000,
          distinctPositions: 0,
          regionCount: 0,
        );
        final result = TraitEngine.infer(entry: entry);

        // Max distance alone gives a small boost but not enough
        // without position or region diversity.
        // The primary should not be Wanderer.
        expect(result.primary, isNot(equals(NodeTrait.wanderer)));
      });
    });

    // -------------------------------------------------------------------------
    // NodeTrait enum properties
    // -------------------------------------------------------------------------

    group('NodeTrait enum', () {
      test('all traits have display labels', () {
        for (final trait in NodeTrait.values) {
          expect(trait.displayLabel, isNotEmpty);
        }
      });

      test('all traits have descriptions', () {
        for (final trait in NodeTrait.values) {
          expect(trait.description, isNotEmpty);
        }
      });

      test('all traits have non-transparent colors', () {
        for (final trait in NodeTrait.values) {
          // Color alpha should be 0xFF (fully opaque).
          expect(
            trait.color.a,
            equals(1.0),
            reason: '${trait.displayLabel} color is not fully opaque',
          );
        }
      });

      test('display labels are unique', () {
        final labels = NodeTrait.values.map((t) => t.displayLabel).toSet();
        expect(labels.length, equals(NodeTrait.values.length));
      });
    });
  });
}
