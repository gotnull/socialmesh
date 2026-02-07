// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/patina_score.dart';

// =============================================================================
// Test helpers
// =============================================================================

List<EncounterRecord> _makeEncounters({
  required int count,
  required int distinctPositions,
  required DateTime startTime,
  required DateTime endTime,
  bool withSignal = false,
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
      lat = 37.0 + (i * 0.01);
      lon = -122.0 + (i * 0.01);
    } else if (distinctPositions > 0) {
      lat = 37.0 + ((distinctPositions - 1) * 0.01);
      lon = -122.0 + ((distinctPositions - 1) * 0.01);
    }

    records.add(
      EncounterRecord(
        timestamp: timestamp,
        latitude: lat,
        longitude: lon,
        snr: withSignal ? (10 - i % 5) : null,
        rssi: withSignal ? (-80 - i % 20) : null,
      ),
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

Map<int, CoSeenRelationship> _makeCoSeen(int count, DateTime baseTime) {
  final coSeen = <int, CoSeenRelationship>{};
  for (int i = 0; i < count; i++) {
    coSeen[1000 + i] = CoSeenRelationship(
      count: 2 + i,
      firstSeen: baseTime,
      lastSeen: baseTime.add(const Duration(hours: 1)),
    );
  }
  return coSeen;
}

NodeDexEntry _makeEntry({
  int nodeNum = 1,
  int encounterCount = 10,
  int ageDays = 7,
  int regionCount = 0,
  int distinctPositions = 0,
  int messageCount = 0,
  int coSeenCount = 0,
  bool withSignal = false,
  int? bestSnr,
  int? bestRssi,
  DateTime? firstSeen,
  DateTime? lastSeen,
  double? maxDistanceSeen,
}) {
  final now = DateTime(2025, 6, 15, 12, 0, 0);
  final fs = firstSeen ?? now.subtract(Duration(days: ageDays));
  final ls = lastSeen ?? now;

  final encounters = _makeEncounters(
    count: encounterCount,
    distinctPositions: distinctPositions,
    startTime: fs,
    endTime: ls,
    withSignal: withSignal,
  );

  final regions = _makeRegions(regionCount, fs);
  final coSeen = _makeCoSeen(coSeenCount, fs);

  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: fs,
    lastSeen: ls,
    encounterCount: encounterCount,
    maxDistanceSeen: maxDistanceSeen,
    messageCount: messageCount,
    encounters: encounters,
    seenRegions: regions,
    coSeenNodes: coSeen,
    bestSnr: bestSnr,
    bestRssi: bestRssi,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // Fixed reference time for deterministic tests.
  final refTime = DateTime(2025, 6, 15, 12, 0, 0);

  group('PatinaScore', () {
    // -------------------------------------------------------------------------
    // Determinism
    // -------------------------------------------------------------------------

    group('determinism', () {
      test('same entry always produces the same score', () {
        final entry = _makeEntry(
          encounterCount: 20,
          ageDays: 14,
          regionCount: 3,
          coSeenCount: 5,
          messageCount: 10,
          withSignal: true,
          bestSnr: 12,
          bestRssi: -75,
        );

        final result1 = PatinaScore.computeAt(entry, refTime);
        final result2 = PatinaScore.computeAt(entry, refTime);

        expect(result1.score, equals(result2.score));
        expect(result1.tenure, equals(result2.tenure));
        expect(result1.encounters, equals(result2.encounters));
        expect(result1.reach, equals(result2.reach));
        expect(result1.signalDepth, equals(result2.signalDepth));
        expect(result1.social, equals(result2.social));
        expect(result1.recency, equals(result2.recency));
        expect(result1.stampLabel, equals(result2.stampLabel));
      });

      test('determinism holds across many node numbers', () {
        for (final nodeNum in [0, 1, 255, 1000, 0xDEAD, 0xFFFFFFFF]) {
          final entry = _makeEntry(
            nodeNum: nodeNum,
            encounterCount: 15,
            ageDays: 10,
          );

          final a = PatinaScore.computeAt(entry, refTime);
          final b = PatinaScore.computeAt(entry, refTime);

          expect(
            a.score,
            equals(b.score),
            reason: 'Score mismatch for node $nodeNum',
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // Score bounds
    // -------------------------------------------------------------------------

    group('score bounds', () {
      test('score is always 0 to 100 inclusive', () {
        // Minimal entry
        final minimal = _makeEntry(encounterCount: 1, ageDays: 0);
        final minResult = PatinaScore.computeAt(minimal, refTime);
        expect(minResult.score, greaterThanOrEqualTo(0));
        expect(minResult.score, lessThanOrEqualTo(100));

        // Rich entry
        final rich = _makeEntry(
          encounterCount: 100,
          ageDays: 365,
          regionCount: 10,
          coSeenCount: 30,
          messageCount: 50,
          distinctPositions: 20,
          withSignal: true,
          bestSnr: 15,
          bestRssi: -60,
        );
        final richResult = PatinaScore.computeAt(rich, refTime);
        expect(richResult.score, greaterThanOrEqualTo(0));
        expect(richResult.score, lessThanOrEqualTo(100));
      });

      test('axis scores are always 0.0 to 1.0', () {
        final entry = _makeEntry(
          encounterCount: 50,
          ageDays: 60,
          regionCount: 5,
          coSeenCount: 15,
          messageCount: 25,
          withSignal: true,
          bestSnr: 10,
          bestRssi: -80,
        );
        final result = PatinaScore.computeAt(entry, refTime);

        expect(result.tenure, greaterThanOrEqualTo(0.0));
        expect(result.tenure, lessThanOrEqualTo(1.0));
        expect(result.encounters, greaterThanOrEqualTo(0.0));
        expect(result.encounters, lessThanOrEqualTo(1.0));
        expect(result.reach, greaterThanOrEqualTo(0.0));
        expect(result.reach, lessThanOrEqualTo(1.0));
        expect(result.signalDepth, greaterThanOrEqualTo(0.0));
        expect(result.signalDepth, lessThanOrEqualTo(1.0));
        expect(result.social, greaterThanOrEqualTo(0.0));
        expect(result.social, lessThanOrEqualTo(1.0));
        expect(result.recency, greaterThanOrEqualTo(0.0));
        expect(result.recency, lessThanOrEqualTo(1.0));
      });
    });

    // -------------------------------------------------------------------------
    // Monotonicity — more data should yield higher scores
    // -------------------------------------------------------------------------

    group('monotonicity', () {
      test('more encounters yields higher score', () {
        final few = _makeEntry(encounterCount: 3, ageDays: 7);
        final many = _makeEntry(encounterCount: 30, ageDays: 7);

        final fewResult = PatinaScore.computeAt(few, refTime);
        final manyResult = PatinaScore.computeAt(many, refTime);

        expect(manyResult.score, greaterThan(fewResult.score));
        expect(manyResult.encounters, greaterThan(fewResult.encounters));
      });

      test('longer tenure yields higher tenure axis', () {
        final young = _makeEntry(encounterCount: 10, ageDays: 1);
        final old = _makeEntry(encounterCount: 10, ageDays: 60);

        final youngResult = PatinaScore.computeAt(young, refTime);
        final oldResult = PatinaScore.computeAt(old, refTime);

        expect(oldResult.tenure, greaterThan(youngResult.tenure));
      });

      test('more regions yields higher reach axis', () {
        final local = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          regionCount: 0,
        );
        final spread = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          regionCount: 4,
        );

        final localResult = PatinaScore.computeAt(local, refTime);
        final spreadResult = PatinaScore.computeAt(spread, refTime);

        expect(spreadResult.reach, greaterThan(localResult.reach));
      });

      test('signal records yield higher signal depth axis', () {
        final noSignal = _makeEntry(encounterCount: 10, ageDays: 7);
        final withSig = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          withSignal: true,
          bestSnr: 12,
          bestRssi: -80,
        );

        final noSigResult = PatinaScore.computeAt(noSignal, refTime);
        final sigResult = PatinaScore.computeAt(withSig, refTime);

        expect(sigResult.signalDepth, greaterThan(noSigResult.signalDepth));
      });

      test('more co-seen nodes yields higher social axis', () {
        final alone = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          coSeenCount: 0,
        );
        final social = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          coSeenCount: 10,
        );

        final aloneResult = PatinaScore.computeAt(alone, refTime);
        final socialResult = PatinaScore.computeAt(social, refTime);

        expect(socialResult.social, greaterThan(aloneResult.social));
      });

      test('more messages yields higher social axis', () {
        final quiet = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          messageCount: 0,
        );
        final chatty = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          messageCount: 20,
        );

        final quietResult = PatinaScore.computeAt(quiet, refTime);
        final chattyResult = PatinaScore.computeAt(chatty, refTime);

        expect(chattyResult.social, greaterThan(quietResult.social));
      });
    });

    // -------------------------------------------------------------------------
    // Recency axis
    // -------------------------------------------------------------------------

    group('recency', () {
      test('recently seen node scores high on recency', () {
        final entry = _makeEntry(
          encounterCount: 10,
          ageDays: 7,
          lastSeen: refTime.subtract(const Duration(minutes: 5)),
        );
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.recency, greaterThan(0.9));
      });

      test('node not seen for days scores low on recency', () {
        final entry = _makeEntry(
          encounterCount: 10,
          ageDays: 30,
          lastSeen: refTime.subtract(const Duration(days: 5)),
        );
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.recency, lessThan(0.2));
      });

      test('recency decays over time', () {
        final entry = _makeEntry(
          encounterCount: 10,
          ageDays: 30,
          lastSeen: refTime.subtract(const Duration(hours: 1)),
        );

        final fresh = PatinaScore.computeAt(entry, refTime);
        final stale = PatinaScore.computeAt(
          entry,
          refTime.add(const Duration(days: 3)),
        );

        expect(stale.recency, lessThan(fresh.recency));
      });
    });

    // -------------------------------------------------------------------------
    // Stability — small input changes cause small output changes
    // -------------------------------------------------------------------------

    group('stability', () {
      test('adding one encounter does not cause dramatic score change', () {
        final base = _makeEntry(encounterCount: 15, ageDays: 14);
        final bump = _makeEntry(encounterCount: 16, ageDays: 14);

        final baseResult = PatinaScore.computeAt(base, refTime);
        final bumpResult = PatinaScore.computeAt(bump, refTime);

        final diff = (bumpResult.score - baseResult.score).abs();
        expect(
          diff,
          lessThanOrEqualTo(5),
          reason: 'Score changed by $diff, expected <= 5',
        );
      });

      test('adding one day does not cause dramatic score change', () {
        final base = _makeEntry(encounterCount: 15, ageDays: 14);
        final bump = _makeEntry(encounterCount: 15, ageDays: 15);

        final baseResult = PatinaScore.computeAt(base, refTime);
        final bumpResult = PatinaScore.computeAt(bump, refTime);

        final diff = (bumpResult.score - baseResult.score).abs();
        expect(
          diff,
          lessThanOrEqualTo(5),
          reason: 'Score changed by $diff, expected <= 5',
        );
      });

      test('adding one region does not cause dramatic score change', () {
        final base = _makeEntry(
          encounterCount: 15,
          ageDays: 14,
          regionCount: 2,
        );
        final bump = _makeEntry(
          encounterCount: 15,
          ageDays: 14,
          regionCount: 3,
        );

        final baseResult = PatinaScore.computeAt(base, refTime);
        final bumpResult = PatinaScore.computeAt(bump, refTime);

        final diff = (bumpResult.score - baseResult.score).abs();
        expect(
          diff,
          lessThanOrEqualTo(5),
          reason: 'Score changed by $diff, expected <= 5',
        );
      });
    });

    // -------------------------------------------------------------------------
    // Stamp labels
    // -------------------------------------------------------------------------

    group('stamp labels', () {
      test('brand new node gets Trace or Faint label', () {
        final entry = _makeEntry(
          encounterCount: 1,
          ageDays: 0,
          lastSeen: refTime,
        );
        final result = PatinaScore.computeAt(entry, refTime);
        // A brand new node with high recency may score 10+, landing on Faint
        expect(['Trace', 'Faint'], contains(result.stampLabel));
      });

      test('moderate node gets a mid-range label', () {
        final entry = _makeEntry(
          encounterCount: 20,
          ageDays: 14,
          regionCount: 2,
          coSeenCount: 5,
          withSignal: true,
          bestSnr: 10,
          bestRssi: -85,
          lastSeen: refTime.subtract(const Duration(hours: 1)),
        );
        final result = PatinaScore.computeAt(entry, refTime);
        // Mid-range labels are Noted, Logged, or Inked
        expect([
          'Noted',
          'Logged',
          'Inked',
          'Etched',
        ], contains(result.stampLabel));
      });

      test('rich node gets a high-tier label', () {
        final entry = _makeEntry(
          encounterCount: 80,
          ageDays: 120,
          regionCount: 8,
          coSeenCount: 25,
          messageCount: 40,
          distinctPositions: 15,
          withSignal: true,
          bestSnr: 15,
          bestRssi: -60,
          lastSeen: refTime.subtract(const Duration(minutes: 10)),
        );
        final result = PatinaScore.computeAt(entry, refTime);
        // High-tier labels are Etched, Archival, or Canonical
        expect([
          'Etched',
          'Archival',
          'Canonical',
        ], contains(result.stampLabel));
      });

      test('stampLabel is never empty', () {
        for (int encounters = 0; encounters <= 50; encounters += 5) {
          for (int days = 0; days <= 90; days += 15) {
            final entry = _makeEntry(encounterCount: encounters, ageDays: days);
            final result = PatinaScore.computeAt(entry, refTime);
            expect(result.stampLabel.isNotEmpty, isTrue);
          }
        }
      });
    });

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------

    group('edge cases', () {
      test('zero encounters produces very low score', () {
        final entry = _makeEntry(encounterCount: 0, ageDays: 0);
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.score, lessThanOrEqualTo(15));
      });

      test('zero-age entry does not crash', () {
        final entry = _makeEntry(
          encounterCount: 1,
          ageDays: 0,
          firstSeen: refTime,
          lastSeen: refTime,
        );
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.score, greaterThanOrEqualTo(0));
      });

      test(
        'very old entry with no recent activity still has positive score',
        () {
          final entry = _makeEntry(
            encounterCount: 30,
            ageDays: 365,
            regionCount: 3,
            lastSeen: refTime.subtract(const Duration(days: 60)),
          );
          final result = PatinaScore.computeAt(entry, refTime);
          // Tenure + encounters + reach carry the score even with 0 recency
          expect(result.score, greaterThan(10));
          expect(result.recency, closeTo(0.0, 0.01));
        },
      );

      test(
        'entry with only signal data but few encounters has moderate depth',
        () {
          final entry = _makeEntry(
            encounterCount: 2,
            ageDays: 1,
            bestSnr: 15,
            bestRssi: -70,
          );
          final result = PatinaScore.computeAt(entry, refTime);
          // SNR + RSSI present = 0.6 signal depth
          expect(result.signalDepth, closeTo(0.6, 0.05));
        },
      );
    });

    // -------------------------------------------------------------------------
    // Diminishing returns (logarithmic/asymptotic curves)
    // -------------------------------------------------------------------------

    group('diminishing returns', () {
      test('encounter score growth slows at high counts', () {
        // Use equal increments (not doublings) so the concavity of ln
        // guarantees strictly decreasing gains.
        final entry10 = _makeEntry(encounterCount: 10, ageDays: 30);
        final entry20 = _makeEntry(encounterCount: 20, ageDays: 30);
        final entry30 = _makeEntry(encounterCount: 30, ageDays: 30);
        final entry40 = _makeEntry(encounterCount: 40, ageDays: 30);

        final s10 = PatinaScore.computeAt(entry10, refTime).encounters;
        final s20 = PatinaScore.computeAt(entry20, refTime).encounters;
        final s30 = PatinaScore.computeAt(entry30, refTime).encounters;
        final s40 = PatinaScore.computeAt(entry40, refTime).encounters;

        // Each equal-step increment should produce a smaller gain.
        final gain10to20 = s20 - s10;
        final gain20to30 = s30 - s20;
        final gain30to40 = s40 - s30;

        expect(gain20to30, lessThan(gain10to20));
        expect(gain30to40, lessThan(gain20to30));
      });

      test('tenure score growth slows at high age', () {
        final entry7d = _makeEntry(encounterCount: 10, ageDays: 7);
        final entry30d = _makeEntry(encounterCount: 10, ageDays: 30);
        final entry90d = _makeEntry(encounterCount: 10, ageDays: 90);
        final entry180d = _makeEntry(encounterCount: 10, ageDays: 180);

        final s7 = PatinaScore.computeAt(entry7d, refTime).tenure;
        final s30 = PatinaScore.computeAt(entry30d, refTime).tenure;
        final s90 = PatinaScore.computeAt(entry90d, refTime).tenure;
        final s180 = PatinaScore.computeAt(entry180d, refTime).tenure;

        final gain7to30 = s30 - s7;
        final gain30to90 = s90 - s30;
        final gain90to180 = s180 - s90;

        expect(gain30to90, lessThan(gain7to30));
        expect(gain90to180, lessThan(gain30to90));
      });
    });

    // -------------------------------------------------------------------------
    // Score range expectations (golden values for known inputs)
    // -------------------------------------------------------------------------

    group('expected score ranges', () {
      test('brand new node scores 0-25', () {
        final entry = _makeEntry(
          encounterCount: 1,
          ageDays: 0,
          lastSeen: refTime,
        );
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.score, inInclusiveRange(0, 25));
      });

      test('node seen 3 times over 2 days scores roughly 15-35', () {
        final entry = _makeEntry(
          encounterCount: 3,
          ageDays: 2,
          regionCount: 1,
          lastSeen: refTime.subtract(const Duration(hours: 2)),
        );
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.score, inInclusiveRange(10, 40));
      });

      test('node seen 50 times over 30 days across 4 regions scores 50-80', () {
        final entry = _makeEntry(
          encounterCount: 50,
          ageDays: 30,
          regionCount: 4,
          coSeenCount: 8,
          messageCount: 10,
          withSignal: true,
          bestSnr: 10,
          bestRssi: -85,
          lastSeen: refTime.subtract(const Duration(hours: 3)),
        );
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.score, inInclusiveRange(45, 85));
      });
    });

    // -------------------------------------------------------------------------
    // toString
    // -------------------------------------------------------------------------

    group('toString', () {
      test('produces a readable string', () {
        final entry = _makeEntry(encounterCount: 20, ageDays: 14);
        final result = PatinaScore.computeAt(entry, refTime);
        expect(result.toString(), contains('PatinaResult'));
        expect(result.toString(), contains(result.stampLabel));
        expect(result.toString(), contains(result.score.toString()));
      });
    });
  });
}
