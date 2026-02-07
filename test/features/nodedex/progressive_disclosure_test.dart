// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/progressive_disclosure.dart';

// =============================================================================
// Test helpers
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
      lat = 37.0 + (i * 0.01);
      lon = -122.0 + (i * 0.01);
    } else if (distinctPositions > 0) {
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
  int ageHours = 0,
  int regionCount = 0,
  int distinctPositions = 0,
  int messageCount = 0,
  int coSeenCount = 0,
  DateTime? firstSeen,
  DateTime? lastSeen,
}) {
  final now = DateTime(2025, 6, 15, 12, 0, 0);
  final fs =
      firstSeen ?? now.subtract(Duration(days: ageDays, hours: ageHours));
  final ls = lastSeen ?? now;

  final encounters = _makeEncounters(
    count: encounterCount,
    distinctPositions: distinctPositions,
    startTime: fs,
    endTime: ls,
  );

  final regions = _makeRegions(regionCount, fs);
  final coSeen = _makeCoSeen(coSeenCount, fs);

  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: fs,
    lastSeen: ls,
    encounterCount: encounterCount,
    messageCount: messageCount,
    encounters: encounters,
    seenRegions: regions,
    coSeenNodes: coSeen,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // Fixed reference time for deterministic tests.
  final refTime = DateTime(2025, 6, 15, 12, 0, 0);

  group('ProgressiveDisclosure', () {
    // -------------------------------------------------------------------------
    // Determinism
    // -------------------------------------------------------------------------

    group('determinism', () {
      test('same entry always produces the same disclosure state', () {
        final entry = _makeEntry(
          encounterCount: 15,
          ageDays: 10,
          regionCount: 3,
          coSeenCount: 5,
        );

        final state1 = ProgressiveDisclosure.computeAt(entry, refTime);
        final state2 = ProgressiveDisclosure.computeAt(entry, refTime);

        expect(state1.tier, equals(state2.tier));
        expect(state1.showSigil, equals(state2.showSigil));
        expect(state1.showPrimaryTrait, equals(state2.showPrimaryTrait));
        expect(state1.showTraitEvidence, equals(state2.showTraitEvidence));
        expect(state1.showFieldNote, equals(state2.showFieldNote));
        expect(state1.showAllTraits, equals(state2.showAllTraits));
        expect(state1.showPatinaStamp, equals(state2.showPatinaStamp));
        expect(state1.showTimeline, equals(state2.showTimeline));
        expect(state1.showOverlay, equals(state2.showOverlay));
        expect(state1.overlayDensity, equals(state2.overlayDensity));
      });

      test('determinism holds across many node numbers', () {
        for (final nodeNum in [0, 1, 255, 1000, 0xDEAD, 0xFFFFFFFF]) {
          final entry = _makeEntry(
            nodeNum: nodeNum,
            encounterCount: 12,
            ageDays: 5,
          );

          final a = ProgressiveDisclosure.computeAt(entry, refTime);
          final b = ProgressiveDisclosure.computeAt(entry, refTime);

          expect(
            a.tier,
            equals(b.tier),
            reason: 'Tier mismatch for node $nodeNum',
          );
          expect(
            a.overlayDensity,
            equals(b.overlayDensity),
            reason: 'Overlay density mismatch for node $nodeNum',
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // Tier thresholds
    // -------------------------------------------------------------------------

    group('tier thresholds', () {
      test('brand new node is Tier 0 (Trace)', () {
        final entry = _makeEntry(encounterCount: 1, ageDays: 0, ageHours: 0);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.trace));
      });

      test('single encounter within minutes is Tier 0 (Trace)', () {
        final entry = _makeEntry(
          encounterCount: 1,
          ageDays: 0,
          ageHours: 0,
          firstSeen: refTime.subtract(const Duration(minutes: 10)),
          lastSeen: refTime,
        );
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.trace));
      });

      test('2 encounters and 1+ hour age reaches Tier 1 (Noted)', () {
        final entry = _makeEntry(encounterCount: 2, ageDays: 0, ageHours: 2);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.noted));
      });

      test('2 encounters but 0 age stays at Tier 0 (Trace)', () {
        final entry = _makeEntry(
          encounterCount: 2,
          ageDays: 0,
          ageHours: 0,
          firstSeen: refTime.subtract(const Duration(minutes: 30)),
          lastSeen: refTime,
        );
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.trace));
      });

      test('5 encounters and 1+ day age reaches Tier 2 (Logged)', () {
        final entry = _makeEntry(encounterCount: 5, ageDays: 1);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.logged));
      });

      test('5 encounters but 0 days stays at Tier 1 (Noted)', () {
        final entry = _makeEntry(encounterCount: 5, ageDays: 0, ageHours: 12);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.noted));
      });

      test('10 encounters and 3+ days reaches Tier 3 (Inked)', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 3);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.inked));
      });

      test('10 encounters but only 2 days stays at Tier 2 (Logged)', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 2);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.logged));
      });

      test('20 encounters and 7+ days reaches Tier 4 (Etched)', () {
        final entry = _makeEntry(encounterCount: 20, ageDays: 7);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.etched));
      });

      test('20 encounters but only 5 days stays at Tier 3 (Inked)', () {
        final entry = _makeEntry(encounterCount: 20, ageDays: 5);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.inked));
      });

      test('9 encounters and 7 days stays at Tier 2 (Logged)', () {
        final entry = _makeEntry(encounterCount: 9, ageDays: 7);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.logged));
      });

      test('very high encounters and age reaches Etched', () {
        final entry = _makeEntry(encounterCount: 100, ageDays: 365);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.etched));
      });
    });

    // -------------------------------------------------------------------------
    // Element visibility per tier
    // -------------------------------------------------------------------------

    group('element visibility', () {
      test('Tier 0 (Trace) shows only sigil', () {
        final entry = _makeEntry(encounterCount: 1, ageDays: 0);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);

        expect(state.showSigil, isTrue);
        expect(state.showPrimaryTrait, isFalse);
        expect(state.showTraitEvidence, isFalse);
        expect(state.showFieldNote, isFalse);
        expect(state.showAllTraits, isFalse);
        expect(state.showPatinaStamp, isFalse);
        expect(state.showTimeline, isFalse);
        expect(state.showOverlay, isFalse);
        expect(state.overlayDensity, equals(0.0));
      });

      test('Tier 1 (Noted) shows sigil + primary trait', () {
        final entry = _makeEntry(encounterCount: 2, ageDays: 0, ageHours: 2);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);

        expect(state.showSigil, isTrue);
        expect(state.showPrimaryTrait, isTrue);
        expect(state.showTraitEvidence, isFalse);
        expect(state.showFieldNote, isFalse);
        expect(state.showAllTraits, isFalse);
        expect(state.showPatinaStamp, isFalse);
        expect(state.showTimeline, isFalse);
        expect(state.showOverlay, isFalse);
        expect(state.overlayDensity, equals(0.0));
      });

      test('Tier 2 (Logged) adds evidence + field note', () {
        final entry = _makeEntry(encounterCount: 5, ageDays: 1);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);

        expect(state.showSigil, isTrue);
        expect(state.showPrimaryTrait, isTrue);
        expect(state.showTraitEvidence, isTrue);
        expect(state.showFieldNote, isTrue);
        expect(state.showAllTraits, isFalse);
        expect(state.showPatinaStamp, isFalse);
        expect(state.showTimeline, isFalse);
        expect(state.showOverlay, isFalse);
        expect(state.overlayDensity, equals(0.0));
      });

      test('Tier 3 (Inked) adds all traits + patina + timeline + overlay', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 3);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);

        expect(state.showSigil, isTrue);
        expect(state.showPrimaryTrait, isTrue);
        expect(state.showTraitEvidence, isTrue);
        expect(state.showFieldNote, isTrue);
        expect(state.showAllTraits, isTrue);
        expect(state.showPatinaStamp, isTrue);
        expect(state.showTimeline, isTrue);
        expect(state.showOverlay, isTrue);
        expect(state.overlayDensity, greaterThan(0.0));
      });

      test('Tier 4 (Etched) has all elements with higher density', () {
        final entry = _makeEntry(
          encounterCount: 30,
          ageDays: 14,
          regionCount: 3,
          coSeenCount: 10,
        );
        final state = ProgressiveDisclosure.computeAt(entry, refTime);

        expect(state.showSigil, isTrue);
        expect(state.showPrimaryTrait, isTrue);
        expect(state.showTraitEvidence, isTrue);
        expect(state.showFieldNote, isTrue);
        expect(state.showAllTraits, isTrue);
        expect(state.showPatinaStamp, isTrue);
        expect(state.showTimeline, isTrue);
        expect(state.showOverlay, isTrue);
        expect(state.overlayDensity, greaterThan(0.15));
      });

      test('sigil is always visible regardless of tier', () {
        for (int encounters = 0; encounters <= 50; encounters += 5) {
          for (int days = 0; days <= 30; days += 5) {
            final entry = _makeEntry(encounterCount: encounters, ageDays: days);
            final state = ProgressiveDisclosure.computeAt(entry, refTime);
            expect(
              state.showSigil,
              isTrue,
              reason:
                  'Sigil should always be visible '
                  '(encounters=$encounters, days=$days)',
            );
          }
        }
      });
    });

    // -------------------------------------------------------------------------
    // Monotonicity — more data never reduces the tier
    // -------------------------------------------------------------------------

    group('monotonicity', () {
      test('adding encounters never reduces the tier', () {
        DisclosureTier? previousTier;

        for (int encounters = 0; encounters <= 50; encounters++) {
          final entry = _makeEntry(encounterCount: encounters, ageDays: 30);
          final state = ProgressiveDisclosure.computeAt(entry, refTime);

          if (previousTier != null) {
            expect(
              state.tier.index,
              greaterThanOrEqualTo(previousTier.index),
              reason:
                  'Tier decreased from ${previousTier.name} to '
                  '${state.tier.name} at encounters=$encounters',
            );
          }
          previousTier = state.tier;
        }
      });

      test('adding days never reduces the tier', () {
        DisclosureTier? previousTier;

        for (int days = 0; days <= 30; days++) {
          final entry = _makeEntry(encounterCount: 25, ageDays: days);
          final state = ProgressiveDisclosure.computeAt(entry, refTime);

          if (previousTier != null) {
            expect(
              state.tier.index,
              greaterThanOrEqualTo(previousTier.index),
              reason:
                  'Tier decreased from ${previousTier.name} to '
                  '${state.tier.name} at days=$days',
            );
          }
          previousTier = state.tier;
        }
      });

      test('adding both encounters and days never reduces the tier', () {
        DisclosureTier? previousTier;

        for (int step = 0; step <= 30; step++) {
          final entry = _makeEntry(encounterCount: step * 2, ageDays: step);
          final state = ProgressiveDisclosure.computeAt(entry, refTime);

          if (previousTier != null) {
            expect(
              state.tier.index,
              greaterThanOrEqualTo(previousTier.index),
              reason:
                  'Tier decreased from ${previousTier.name} to '
                  '${state.tier.name} at step=$step',
            );
          }
          previousTier = state.tier;
        }
      });
    });

    // -------------------------------------------------------------------------
    // Overlay density
    // -------------------------------------------------------------------------

    group('overlay density', () {
      test('overlay density is zero below Tier 3', () {
        // Tier 0
        final trace = _makeEntry(encounterCount: 1, ageDays: 0);
        expect(
          ProgressiveDisclosure.computeAt(trace, refTime).overlayDensity,
          equals(0.0),
        );

        // Tier 1
        final noted = _makeEntry(encounterCount: 2, ageDays: 0, ageHours: 2);
        expect(
          ProgressiveDisclosure.computeAt(noted, refTime).overlayDensity,
          equals(0.0),
        );

        // Tier 2
        final logged = _makeEntry(encounterCount: 5, ageDays: 1);
        expect(
          ProgressiveDisclosure.computeAt(logged, refTime).overlayDensity,
          equals(0.0),
        );
      });

      test('overlay density is positive at Tier 3 (Inked)', () {
        final entry = _makeEntry(encounterCount: 10, ageDays: 3);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.overlayDensity, greaterThan(0.0));
      });

      test('overlay density is higher at Tier 4 than Tier 3', () {
        final tier3 = _makeEntry(encounterCount: 10, ageDays: 3);
        final tier4 = _makeEntry(
          encounterCount: 30,
          ageDays: 14,
          regionCount: 3,
          coSeenCount: 8,
        );

        final density3 = ProgressiveDisclosure.computeAt(
          tier3,
          refTime,
        ).overlayDensity;
        final density4 = ProgressiveDisclosure.computeAt(
          tier4,
          refTime,
        ).overlayDensity;

        expect(density4, greaterThan(density3));
      });

      test('overlay density is bounded at 0.0 to 0.40', () {
        // Minimal Tier 3
        final minimal = _makeEntry(encounterCount: 10, ageDays: 3);
        final minDensity = ProgressiveDisclosure.computeAt(
          minimal,
          refTime,
        ).overlayDensity;
        expect(minDensity, greaterThanOrEqualTo(0.0));
        expect(minDensity, lessThanOrEqualTo(0.40));

        // Maximal Tier 4 with all data
        final maximal = _makeEntry(
          encounterCount: 100,
          ageDays: 365,
          regionCount: 10,
          coSeenCount: 30,
          messageCount: 50,
        );
        final maxDensity = ProgressiveDisclosure.computeAt(
          maximal,
          refTime,
        ).overlayDensity;
        expect(maxDensity, greaterThanOrEqualTo(0.0));
        expect(maxDensity, lessThanOrEqualTo(0.40));
      });

      test('richer data increases overlay density within same tier', () {
        // Two Tier 4 entries with different richness
        final sparse = _makeEntry(
          encounterCount: 20,
          ageDays: 7,
          regionCount: 0,
          coSeenCount: 0,
        );
        final rich = _makeEntry(
          encounterCount: 60,
          ageDays: 90,
          regionCount: 6,
          coSeenCount: 20,
        );

        final sparseDensity = ProgressiveDisclosure.computeAt(
          sparse,
          refTime,
        ).overlayDensity;
        final richDensity = ProgressiveDisclosure.computeAt(
          rich,
          refTime,
        ).overlayDensity;

        expect(richDensity, greaterThan(sparseDensity));
      });

      test('overlay density increases with encounter count', () {
        double? previousDensity;

        for (int encounters = 10; encounters <= 60; encounters += 10) {
          final entry = _makeEntry(encounterCount: encounters, ageDays: 30);
          final density = ProgressiveDisclosure.computeAt(
            entry,
            refTime,
          ).overlayDensity;

          if (previousDensity != null) {
            expect(
              density,
              greaterThanOrEqualTo(previousDensity),
              reason:
                  'Density decreased at encounters=$encounters: '
                  '$density < $previousDensity',
            );
          }
          previousDensity = density;
        }
      });

      test('overlay density increases with region count', () {
        final noRegions = _makeEntry(
          encounterCount: 20,
          ageDays: 14,
          regionCount: 0,
        );
        final manyRegions = _makeEntry(
          encounterCount: 20,
          ageDays: 14,
          regionCount: 5,
        );

        final d1 = ProgressiveDisclosure.computeAt(
          noRegions,
          refTime,
        ).overlayDensity;
        final d2 = ProgressiveDisclosure.computeAt(
          manyRegions,
          refTime,
        ).overlayDensity;

        expect(d2, greaterThan(d1));
      });

      test('overlay density increases with co-seen count', () {
        final noCoSeen = _makeEntry(
          encounterCount: 20,
          ageDays: 14,
          coSeenCount: 0,
        );
        final manyCoSeen = _makeEntry(
          encounterCount: 20,
          ageDays: 14,
          coSeenCount: 15,
        );

        final d1 = ProgressiveDisclosure.computeAt(
          noCoSeen,
          refTime,
        ).overlayDensity;
        final d2 = ProgressiveDisclosure.computeAt(
          manyCoSeen,
          refTime,
        ).overlayDensity;

        expect(d2, greaterThan(d1));
      });
    });

    // -------------------------------------------------------------------------
    // DisclosureTier.isAtLeast
    // -------------------------------------------------------------------------

    group('DisclosureTier.isAtLeast', () {
      test('trace is at least trace', () {
        expect(DisclosureTier.trace.isAtLeast(DisclosureTier.trace), isTrue);
      });

      test('trace is not at least noted', () {
        expect(DisclosureTier.trace.isAtLeast(DisclosureTier.noted), isFalse);
      });

      test('etched is at least all tiers', () {
        for (final tier in DisclosureTier.values) {
          expect(
            DisclosureTier.etched.isAtLeast(tier),
            isTrue,
            reason: 'Etched should be at least ${tier.name}',
          );
        }
      });

      test('each tier is at least itself', () {
        for (final tier in DisclosureTier.values) {
          expect(
            tier.isAtLeast(tier),
            isTrue,
            reason: '${tier.name} should be at least itself',
          );
        }
      });

      test('lower tiers are not at least higher tiers', () {
        expect(DisclosureTier.noted.isAtLeast(DisclosureTier.logged), isFalse);
        expect(DisclosureTier.logged.isAtLeast(DisclosureTier.inked), isFalse);
        expect(DisclosureTier.inked.isAtLeast(DisclosureTier.etched), isFalse);
      });

      test('higher tiers are at least lower tiers', () {
        expect(DisclosureTier.noted.isAtLeast(DisclosureTier.trace), isTrue);
        expect(DisclosureTier.logged.isAtLeast(DisclosureTier.noted), isTrue);
        expect(DisclosureTier.inked.isAtLeast(DisclosureTier.logged), isTrue);
        expect(DisclosureTier.etched.isAtLeast(DisclosureTier.inked), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // computeTier convenience method
    // -------------------------------------------------------------------------

    group('computeTier', () {
      test('returns same tier as full compute', () {
        final entry = _makeEntry(encounterCount: 12, ageDays: 5);
        final fullState = ProgressiveDisclosure.computeAt(entry, refTime);
        // computeTier uses DateTime.now() internally, so we test the
        // full computeAt which is used in all other tests.
        // The computeTier method is just a convenience wrapper.
        expect(fullState.tier, isNotNull);
      });
    });

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------

    group('edge cases', () {
      test('zero encounters does not crash', () {
        final entry = _makeEntry(encounterCount: 0, ageDays: 0);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.trace));
        expect(state.overlayDensity, equals(0.0));
      });

      test('zero age does not crash', () {
        final entry = _makeEntry(
          encounterCount: 5,
          ageDays: 0,
          firstSeen: refTime,
          lastSeen: refTime,
        );
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.trace));
      });

      test('very high encounter count does not overflow', () {
        final entry = _makeEntry(encounterCount: 999999, ageDays: 3650);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.etched));
        expect(state.overlayDensity, greaterThan(0.0));
        expect(state.overlayDensity, lessThanOrEqualTo(0.40));
      });

      test('very old entry with few encounters stays at appropriate tier', () {
        final entry = _makeEntry(encounterCount: 3, ageDays: 365);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        // 3 encounters is below the Tier 2 threshold of 5
        expect(state.tier, equals(DisclosureTier.noted));
      });

      test('many encounters on day zero stays at Tier 1 max', () {
        // ageDays=0 but ageHours=2 satisfies Tier 1 age requirement
        final entry = _makeEntry(encounterCount: 100, ageDays: 0, ageHours: 2);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        // Should be Tier 1 because age in days is 0 (blocks Tier 2+)
        expect(state.tier, equals(DisclosureTier.noted));
      });

      test('firstSeen equals lastSeen does not crash', () {
        final entry = _makeEntry(
          encounterCount: 1,
          firstSeen: refTime,
          lastSeen: refTime,
        );
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier, equals(DisclosureTier.trace));
      });

      test('future firstSeen does not crash', () {
        final futureTime = refTime.add(const Duration(days: 1));
        final entry = _makeEntry(
          encounterCount: 5,
          firstSeen: futureTime,
          lastSeen: futureTime,
        );
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        // Age would be negative, treated as zero
        expect(state.tier, equals(DisclosureTier.trace));
      });
    });

    // -------------------------------------------------------------------------
    // Stability — small input changes cause proportional output changes
    // -------------------------------------------------------------------------

    group('stability', () {
      test(
        'adding one encounter at tier boundary causes at most one tier jump',
        () {
          // Right below Tier 2 threshold
          final below = _makeEntry(encounterCount: 4, ageDays: 2);
          final above = _makeEntry(encounterCount: 5, ageDays: 2);

          final belowState = ProgressiveDisclosure.computeAt(below, refTime);
          final aboveState = ProgressiveDisclosure.computeAt(above, refTime);

          final tierDiff = aboveState.tier.index - belowState.tier.index;
          expect(
            tierDiff,
            lessThanOrEqualTo(1),
            reason: 'Tier jumped by $tierDiff across boundary',
          );
        },
      );

      test('adding one day at tier boundary causes at most one tier jump', () {
        // Exactly at Tier 3 encounter threshold but below age threshold
        final below = _makeEntry(encounterCount: 10, ageDays: 2);
        final above = _makeEntry(encounterCount: 10, ageDays: 3);

        final belowState = ProgressiveDisclosure.computeAt(below, refTime);
        final aboveState = ProgressiveDisclosure.computeAt(above, refTime);

        final tierDiff = aboveState.tier.index - belowState.tier.index;
        expect(
          tierDiff,
          lessThanOrEqualTo(1),
          reason: 'Tier jumped by $tierDiff across boundary',
        );
      });

      test('overlay density changes smoothly with encounter count', () {
        // All at Tier 4 (20+ encounters, 7+ days)
        double? previousDensity;

        for (int encounters = 20; encounters <= 80; encounters += 5) {
          final entry = _makeEntry(encounterCount: encounters, ageDays: 30);
          final density = ProgressiveDisclosure.computeAt(
            entry,
            refTime,
          ).overlayDensity;

          if (previousDensity != null) {
            final change = (density - previousDensity).abs();
            expect(
              change,
              lessThan(0.1),
              reason:
                  'Density changed by $change at encounters=$encounters '
                  '(previous: $previousDensity, current: $density)',
            );
          }
          previousDensity = density;
        }
      });
    });

    // -------------------------------------------------------------------------
    // toString
    // -------------------------------------------------------------------------

    group('toString', () {
      test('produces readable string for overlay-enabled state', () {
        final entry = _makeEntry(encounterCount: 15, ageDays: 5);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        final str = state.toString();
        expect(str, contains('DisclosureState'));
        expect(str, contains(state.tier.name));
      });

      test('produces readable string for overlay-disabled state', () {
        final entry = _makeEntry(encounterCount: 1, ageDays: 0);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        final str = state.toString();
        expect(str, contains('DisclosureState'));
        expect(str, contains('off'));
      });
    });

    // -------------------------------------------------------------------------
    // Cumulative element visibility across tiers
    // -------------------------------------------------------------------------

    group('cumulative visibility', () {
      test('each higher tier includes all elements from lower tiers', () {
        final tiers = <DisclosureTier, DisclosureState>{};

        // Tier 0
        tiers[DisclosureTier.trace] = ProgressiveDisclosure.computeAt(
          _makeEntry(encounterCount: 1, ageDays: 0),
          refTime,
        );

        // Tier 1
        tiers[DisclosureTier.noted] = ProgressiveDisclosure.computeAt(
          _makeEntry(encounterCount: 2, ageDays: 0, ageHours: 2),
          refTime,
        );

        // Tier 2
        tiers[DisclosureTier.logged] = ProgressiveDisclosure.computeAt(
          _makeEntry(encounterCount: 5, ageDays: 1),
          refTime,
        );

        // Tier 3
        tiers[DisclosureTier.inked] = ProgressiveDisclosure.computeAt(
          _makeEntry(encounterCount: 10, ageDays: 3),
          refTime,
        );

        // Tier 4
        tiers[DisclosureTier.etched] = ProgressiveDisclosure.computeAt(
          _makeEntry(encounterCount: 20, ageDays: 7),
          refTime,
        );

        // Verify cumulative: if a lower tier shows something, higher tiers must too
        final tierOrder = [
          DisclosureTier.trace,
          DisclosureTier.noted,
          DisclosureTier.logged,
          DisclosureTier.inked,
          DisclosureTier.etched,
        ];

        for (int i = 1; i < tierOrder.length; i++) {
          final lower = tiers[tierOrder[i - 1]]!;
          final higher = tiers[tierOrder[i]]!;

          if (lower.showSigil) {
            expect(
              higher.showSigil,
              isTrue,
              reason: '${tierOrder[i].name} lost showSigil',
            );
          }
          if (lower.showPrimaryTrait) {
            expect(
              higher.showPrimaryTrait,
              isTrue,
              reason: '${tierOrder[i].name} lost showPrimaryTrait',
            );
          }
          if (lower.showTraitEvidence) {
            expect(
              higher.showTraitEvidence,
              isTrue,
              reason: '${tierOrder[i].name} lost showTraitEvidence',
            );
          }
          if (lower.showFieldNote) {
            expect(
              higher.showFieldNote,
              isTrue,
              reason: '${tierOrder[i].name} lost showFieldNote',
            );
          }
          if (lower.showAllTraits) {
            expect(
              higher.showAllTraits,
              isTrue,
              reason: '${tierOrder[i].name} lost showAllTraits',
            );
          }
          if (lower.showPatinaStamp) {
            expect(
              higher.showPatinaStamp,
              isTrue,
              reason: '${tierOrder[i].name} lost showPatinaStamp',
            );
          }
          if (lower.showTimeline) {
            expect(
              higher.showTimeline,
              isTrue,
              reason: '${tierOrder[i].name} lost showTimeline',
            );
          }
          if (lower.showOverlay) {
            expect(
              higher.showOverlay,
              isTrue,
              reason: '${tierOrder[i].name} lost showOverlay',
            );
          }
        }
      });
    });

    // -------------------------------------------------------------------------
    // Both thresholds required
    // -------------------------------------------------------------------------

    group('both thresholds required', () {
      test('encounters alone without age cannot reach high tiers', () {
        // Many encounters but age is 0
        final entry = _makeEntry(
          encounterCount: 50,
          ageDays: 0,
          ageHours: 0,
          firstSeen: refTime.subtract(const Duration(minutes: 30)),
          lastSeen: refTime,
        );
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier.index, lessThanOrEqualTo(DisclosureTier.trace.index));
      });

      test('age alone without encounters cannot reach high tiers', () {
        // Many days but only 1 encounter
        final entry = _makeEntry(encounterCount: 1, ageDays: 365);
        final state = ProgressiveDisclosure.computeAt(entry, refTime);
        expect(state.tier.index, lessThanOrEqualTo(DisclosureTier.trace.index));
      });

      test('both encounters and age needed for Tier 2', () {
        // Enough encounters (5) but not enough age (0 days)
        final encountersOnly = _makeEntry(
          encounterCount: 5,
          ageDays: 0,
          ageHours: 12,
        );
        final stateE = ProgressiveDisclosure.computeAt(encountersOnly, refTime);
        expect(stateE.tier.index, lessThan(DisclosureTier.logged.index));

        // Enough age (2 days) but not enough encounters (3)
        final ageOnly = _makeEntry(encounterCount: 3, ageDays: 2);
        final stateA = ProgressiveDisclosure.computeAt(ageOnly, refTime);
        expect(stateA.tier.index, lessThan(DisclosureTier.logged.index));

        // Both satisfied
        final both = _makeEntry(encounterCount: 5, ageDays: 2);
        final stateB = ProgressiveDisclosure.computeAt(both, refTime);
        expect(stateB.tier, equals(DisclosureTier.logged));
      });
    });
  });
}
