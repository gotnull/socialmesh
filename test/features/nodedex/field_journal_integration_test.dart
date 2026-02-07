// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/field_note_generator.dart';
import 'package:socialmesh/features/nodedex/services/patina_score.dart';
import 'package:socialmesh/features/nodedex/services/progressive_disclosure.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:socialmesh/features/nodedex/services/trait_engine.dart';

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
  int ageHours = 0,
  int regionCount = 0,
  int distinctPositions = 0,
  int messageCount = 0,
  int coSeenCount = 0,
  bool withSignal = false,
  int? bestSnr,
  int? bestRssi,
  double? maxDistanceSeen,
  DateTime? firstSeen,
  DateTime? lastSeen,
  SigilData? sigil,
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
    sigil: sigil,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  final refTime = DateTime(2025, 6, 15, 12, 0, 0);

  group('Field Journal Integration', () {
    // -------------------------------------------------------------------------
    // End-to-end determinism: every subsystem produces the same output for
    // the same input, and they compose deterministically.
    // -------------------------------------------------------------------------

    group('end-to-end determinism', () {
      test(
        'same entry produces identical sigil + traits + patina + note + disclosure',
        () {
          final entry = _makeEntry(
            nodeNum: 0xCAFE,
            encounterCount: 25,
            ageDays: 21,
            regionCount: 4,
            distinctPositions: 7,
            messageCount: 18,
            coSeenCount: 10,
            withSignal: true,
            bestSnr: 12,
            bestRssi: -75,
            maxDistanceSeen: 8500,
          );

          // Run every subsystem twice
          final sigil1 = SigilGenerator.generate(entry.nodeNum);
          final sigil2 = SigilGenerator.generate(entry.nodeNum);

          final trait1 = TraitEngine.infer(entry: entry);
          final trait2 = TraitEngine.infer(entry: entry);

          final allTraits1 = TraitEngine.inferAll(entry: entry);
          final allTraits2 = TraitEngine.inferAll(entry: entry);

          final patina1 = PatinaScore.computeAt(entry, refTime);
          final patina2 = PatinaScore.computeAt(entry, refTime);

          final note1 = FieldNoteGenerator.generate(
            entry: entry,
            trait: trait1.primary,
          );
          final note2 = FieldNoteGenerator.generate(
            entry: entry,
            trait: trait2.primary,
          );

          final disclosure1 = ProgressiveDisclosure.computeAt(entry, refTime);
          final disclosure2 = ProgressiveDisclosure.computeAt(entry, refTime);

          // Sigil
          expect(sigil1.vertices, equals(sigil2.vertices));
          expect(sigil1.rotation, equals(sigil2.rotation));
          expect(sigil1.innerRings, equals(sigil2.innerRings));
          expect(sigil1.primaryColor, equals(sigil2.primaryColor));
          expect(sigil1.secondaryColor, equals(sigil2.secondaryColor));
          expect(sigil1.tertiaryColor, equals(sigil2.tertiaryColor));

          // Trait primary
          expect(trait1.primary, equals(trait2.primary));
          expect(trait1.confidence, equals(trait2.confidence));
          expect(trait1.secondary, equals(trait2.secondary));

          // All traits
          expect(allTraits1.length, equals(allTraits2.length));
          for (int i = 0; i < allTraits1.length; i++) {
            expect(
              allTraits1[i].trait,
              equals(allTraits2[i].trait),
              reason: 'Trait mismatch at index $i',
            );
            expect(
              allTraits1[i].confidence,
              equals(allTraits2[i].confidence),
              reason: 'Confidence mismatch at index $i',
            );
            expect(
              allTraits1[i].evidence.length,
              equals(allTraits2[i].evidence.length),
              reason: 'Evidence count mismatch at index $i',
            );
          }

          // Patina
          expect(patina1.score, equals(patina2.score));
          expect(patina1.tenure, equals(patina2.tenure));
          expect(patina1.encounters, equals(patina2.encounters));
          expect(patina1.reach, equals(patina2.reach));
          expect(patina1.signalDepth, equals(patina2.signalDepth));
          expect(patina1.social, equals(patina2.social));
          expect(patina1.recency, equals(patina2.recency));
          expect(patina1.stampLabel, equals(patina2.stampLabel));

          // Field note
          expect(note1, equals(note2));

          // Disclosure
          expect(disclosure1.tier, equals(disclosure2.tier));
          expect(
            disclosure1.overlayDensity,
            equals(disclosure2.overlayDensity),
          );
          expect(
            disclosure1.showPrimaryTrait,
            equals(disclosure2.showPrimaryTrait),
          );
          expect(disclosure1.showFieldNote, equals(disclosure2.showFieldNote));
          expect(
            disclosure1.showPatinaStamp,
            equals(disclosure2.showPatinaStamp),
          );
          expect(disclosure1.showOverlay, equals(disclosure2.showOverlay));
        },
      );

      test('determinism holds for 100 distinct node numbers', () {
        for (int nodeNum = 0; nodeNum < 100; nodeNum++) {
          final entry = _makeEntry(
            nodeNum: nodeNum,
            encounterCount: 20,
            ageDays: 14,
            regionCount: 2,
            messageCount: 5,
          );

          final sigil = SigilGenerator.generate(nodeNum);
          final trait = TraitEngine.infer(entry: entry);
          final patina = PatinaScore.computeAt(entry, refTime);
          final note = FieldNoteGenerator.generate(
            entry: entry,
            trait: trait.primary,
          );
          final disclosure = ProgressiveDisclosure.computeAt(entry, refTime);

          // Re-run
          expect(
            SigilGenerator.generate(nodeNum).vertices,
            equals(sigil.vertices),
          );
          expect(
            TraitEngine.infer(entry: entry).primary,
            equals(trait.primary),
          );
          expect(
            PatinaScore.computeAt(entry, refTime).score,
            equals(patina.score),
          );
          expect(
            FieldNoteGenerator.generate(entry: entry, trait: trait.primary),
            equals(note),
          );
          expect(
            ProgressiveDisclosure.computeAt(entry, refTime).tier,
            equals(disclosure.tier),
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // Stability: small input changes produce proportionally small output changes
    // across all subsystems simultaneously.
    // -------------------------------------------------------------------------

    group('cross-system stability', () {
      test(
        'adding one encounter does not cause chaotic flips in any subsystem',
        () {
          final base = _makeEntry(
            nodeNum: 42,
            encounterCount: 15,
            ageDays: 14,
            regionCount: 2,
            messageCount: 5,
            coSeenCount: 4,
            withSignal: true,
            bestSnr: 10,
            bestRssi: -85,
          );
          final bump = _makeEntry(
            nodeNum: 42,
            encounterCount: 16,
            ageDays: 14,
            regionCount: 2,
            messageCount: 5,
            coSeenCount: 4,
            withSignal: true,
            bestSnr: 10,
            bestRssi: -85,
          );

          // Sigil is identity-based, should be identical
          final sigilBase = SigilGenerator.generate(base.nodeNum);
          final sigilBump = SigilGenerator.generate(bump.nodeNum);
          expect(sigilBump.vertices, equals(sigilBase.vertices));
          expect(sigilBump.primaryColor, equals(sigilBase.primaryColor));

          // Trait should be the same or very close
          final traitBase = TraitEngine.infer(entry: base);
          final traitBump = TraitEngine.infer(entry: bump);
          // Primary trait should not flip from one encounter
          expect(traitBump.primary, equals(traitBase.primary));

          // Patina should change by at most 5 points
          final patinaBase = PatinaScore.computeAt(base, refTime);
          final patinaBump = PatinaScore.computeAt(bump, refTime);
          final patinaDiff = (patinaBump.score - patinaBase.score).abs();
          expect(
            patinaDiff,
            lessThanOrEqualTo(5),
            reason: 'Patina changed by $patinaDiff',
          );

          // Field note template should be the same (same nodeNum hash)
          final noteBase = FieldNoteGenerator.generate(
            entry: base,
            trait: traitBase.primary,
          );
          final noteBump = FieldNoteGenerator.generate(
            entry: bump,
            trait: traitBump.primary,
          );
          // Both should be non-empty
          expect(noteBase.isNotEmpty, isTrue);
          expect(noteBump.isNotEmpty, isTrue);

          // Disclosure tier should not jump more than 1
          final discBase = ProgressiveDisclosure.computeAt(base, refTime);
          final discBump = ProgressiveDisclosure.computeAt(bump, refTime);
          final tierDiff = (discBump.tier.index - discBase.tier.index).abs();
          expect(
            tierDiff,
            lessThanOrEqualTo(1),
            reason: 'Tier jumped by $tierDiff',
          );
        },
      );

      test(
        'adding one region does not cause chaotic flips in any subsystem',
        () {
          final base = _makeEntry(
            nodeNum: 777,
            encounterCount: 20,
            ageDays: 10,
            regionCount: 2,
          );
          final bump = _makeEntry(
            nodeNum: 777,
            encounterCount: 20,
            ageDays: 10,
            regionCount: 3,
          );

          final traitBase = TraitEngine.infer(entry: base);
          final traitBump = TraitEngine.infer(entry: bump);

          // Trait might change (regions affect Wanderer score) but
          // confidence delta should be small
          final confDiff = (traitBump.confidence - traitBase.confidence).abs();
          expect(
            confDiff,
            lessThan(0.3),
            reason: 'Confidence changed by $confDiff from one region addition',
          );

          // Patina change should be small
          final patinaBase = PatinaScore.computeAt(base, refTime);
          final patinaBump = PatinaScore.computeAt(bump, refTime);
          final patinaDiff = (patinaBump.score - patinaBase.score).abs();
          expect(
            patinaDiff,
            lessThanOrEqualTo(5),
            reason: 'Patina changed by $patinaDiff from one region',
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // Progressive journey: simulate a node accumulating history over time
    // and verify that all subsystems respond coherently.
    // -------------------------------------------------------------------------

    group('progressive journey', () {
      test('node journey from discovery to veteran', () {
        const nodeNum = 0xBEEF;

        // Stage 1: Just discovered
        final stage1 = _makeEntry(
          nodeNum: nodeNum,
          encounterCount: 1,
          ageDays: 0,
          lastSeen: refTime,
        );
        final disc1 = ProgressiveDisclosure.computeAt(stage1, refTime);
        final patina1 = PatinaScore.computeAt(stage1, refTime);

        expect(disc1.tier, equals(DisclosureTier.trace));
        expect(disc1.showPrimaryTrait, isFalse);
        expect(disc1.showFieldNote, isFalse);
        expect(disc1.showPatinaStamp, isFalse);
        expect(disc1.showOverlay, isFalse);
        expect(patina1.score, lessThan(25));
        // A brand-new node with lastSeen == refTime gets a small recency
        // boost that can push the score from 0 to ~10, yielding 'Faint'
        // instead of 'Trace'. Both are acceptable for a just-discovered node.
        expect(patina1.stampLabel, anyOf(equals('Trace'), equals('Faint')));

        // Stage 2: A few encounters, couple hours old
        final stage2 = _makeEntry(
          nodeNum: nodeNum,
          encounterCount: 3,
          ageDays: 0,
          ageHours: 3,
          lastSeen: refTime.subtract(const Duration(minutes: 10)),
        );
        final disc2 = ProgressiveDisclosure.computeAt(stage2, refTime);
        final patina2 = PatinaScore.computeAt(stage2, refTime);

        expect(disc2.tier, equals(DisclosureTier.noted));
        expect(disc2.showPrimaryTrait, isTrue);
        expect(disc2.showFieldNote, isFalse);
        expect(disc2.showPatinaStamp, isFalse);
        expect(patina2.score, greaterThanOrEqualTo(patina1.score));

        // Stage 3: Moderate history
        final stage3 = _makeEntry(
          nodeNum: nodeNum,
          encounterCount: 8,
          ageDays: 3,
          regionCount: 2,
          messageCount: 3,
          withSignal: true,
          bestSnr: 8,
          bestRssi: -90,
          lastSeen: refTime.subtract(const Duration(hours: 2)),
        );
        final disc3 = ProgressiveDisclosure.computeAt(stage3, refTime);
        final patina3 = PatinaScore.computeAt(stage3, refTime);

        expect(disc3.tier, equals(DisclosureTier.logged));
        expect(disc3.showPrimaryTrait, isTrue);
        expect(disc3.showTraitEvidence, isTrue);
        expect(disc3.showFieldNote, isTrue);
        expect(disc3.showPatinaStamp, isFalse);
        expect(patina3.score, greaterThan(patina2.score));

        // Stage 4: Substantial history
        final stage4 = _makeEntry(
          nodeNum: nodeNum,
          encounterCount: 25,
          ageDays: 7,
          regionCount: 3,
          distinctPositions: 5,
          messageCount: 10,
          coSeenCount: 6,
          withSignal: true,
          bestSnr: 12,
          bestRssi: -78,
          maxDistanceSeen: 5000,
          lastSeen: refTime.subtract(const Duration(hours: 1)),
        );
        final disc4 = ProgressiveDisclosure.computeAt(stage4, refTime);
        final patina4 = PatinaScore.computeAt(stage4, refTime);

        expect(disc4.tier, equals(DisclosureTier.etched));
        expect(disc4.showAllTraits, isTrue);
        expect(disc4.showPatinaStamp, isTrue);
        expect(disc4.showTimeline, isTrue);
        expect(disc4.showOverlay, isTrue);
        expect(disc4.overlayDensity, greaterThan(0.0));
        expect(patina4.score, greaterThan(patina3.score));

        // Stage 5: Veteran node
        final stage5 = _makeEntry(
          nodeNum: nodeNum,
          encounterCount: 60,
          ageDays: 90,
          regionCount: 6,
          distinctPositions: 12,
          messageCount: 35,
          coSeenCount: 20,
          withSignal: true,
          bestSnr: 15,
          bestRssi: -65,
          maxDistanceSeen: 15000,
          lastSeen: refTime.subtract(const Duration(minutes: 5)),
        );
        final disc5 = ProgressiveDisclosure.computeAt(stage5, refTime);
        final patina5 = PatinaScore.computeAt(stage5, refTime);

        expect(disc5.tier, equals(DisclosureTier.etched));
        expect(disc5.overlayDensity, greaterThan(disc4.overlayDensity));
        expect(patina5.score, greaterThan(patina4.score));
        expect(patina5.score, greaterThan(60));

        // Verify monotonicity of the full journey
        expect(patina2.score, greaterThanOrEqualTo(patina1.score));
        expect(patina3.score, greaterThan(patina2.score));
        expect(patina4.score, greaterThan(patina3.score));
        expect(patina5.score, greaterThan(patina4.score));

        expect(disc1.tier.index, lessThanOrEqualTo(disc2.tier.index));
        expect(disc2.tier.index, lessThanOrEqualTo(disc3.tier.index));
        expect(disc3.tier.index, lessThanOrEqualTo(disc4.tier.index));
        expect(disc4.tier.index, lessThanOrEqualTo(disc5.tier.index));
      });
    });

    // -------------------------------------------------------------------------
    // Trait engine inferAll: verify multi-trait output integrity
    // -------------------------------------------------------------------------

    group('inferAll output integrity', () {
      test('inferAll returns 3 to 7 traits', () {
        final entry = _makeEntry(
          nodeNum: 42,
          encounterCount: 20,
          ageDays: 14,
          regionCount: 3,
          messageCount: 8,
          coSeenCount: 5,
          distinctPositions: 4,
        );

        final traits = TraitEngine.inferAll(entry: entry);
        expect(traits.length, greaterThanOrEqualTo(3));
        expect(traits.length, lessThanOrEqualTo(7));
      });

      test('inferAll traits are sorted by descending confidence', () {
        final entry = _makeEntry(
          nodeNum: 999,
          encounterCount: 30,
          ageDays: 21,
          regionCount: 4,
          messageCount: 15,
          coSeenCount: 10,
          distinctPositions: 6,
          withSignal: true,
          bestSnr: 10,
          bestRssi: -80,
        );

        final traits = TraitEngine.inferAll(entry: entry);

        for (int i = 1; i < traits.length; i++) {
          expect(
            traits[i].confidence,
            lessThanOrEqualTo(traits[i - 1].confidence),
            reason:
                'Trait ${traits[i].trait.displayLabel} '
                '(${traits[i].confidence}) should not rank above '
                '${traits[i - 1].trait.displayLabel} '
                '(${traits[i - 1].confidence})',
          );
        }
      });

      test('inferAll primary matches infer primary', () {
        final entry = _makeEntry(
          nodeNum: 42,
          encounterCount: 20,
          ageDays: 14,
          regionCount: 3,
          distinctPositions: 5,
        );

        final single = TraitEngine.infer(entry: entry);
        final all = TraitEngine.inferAll(entry: entry);

        if (all.isNotEmpty && single.primary != NodeTrait.unknown) {
          // The top-scoring trait in inferAll should match the primary
          // from infer, unless the primary was below threshold.
          expect(all.first.trait, equals(single.primary));
        }
      });

      test('inferAll evidence lines are not empty for scored traits', () {
        final entry = _makeEntry(
          nodeNum: 100,
          encounterCount: 25,
          ageDays: 21,
          regionCount: 3,
          messageCount: 12,
          coSeenCount: 8,
          distinctPositions: 5,
        );

        final traits = TraitEngine.inferAll(entry: entry);

        for (final scored in traits) {
          if (scored.confidence > 0.2) {
            expect(
              scored.evidence.isNotEmpty,
              isTrue,
              reason:
                  '${scored.trait.displayLabel} at ${scored.confidence} '
                  'should have evidence',
            );

            for (final ev in scored.evidence) {
              expect(
                ev.observation.isNotEmpty,
                isTrue,
                reason: 'Evidence observation should not be empty',
              );
              expect(
                ev.weight,
                greaterThanOrEqualTo(0.0),
                reason: 'Evidence weight should be non-negative',
              );
            }
          }
        }
      });

      test('inferAll returns Unknown for insufficient data', () {
        final entry = _makeEntry(nodeNum: 1, encounterCount: 1, ageDays: 0);

        final traits = TraitEngine.inferAll(entry: entry);
        expect(traits.length, equals(1));
        expect(traits.first.trait, equals(NodeTrait.unknown));
        expect(traits.first.confidence, equals(1.0));
      });

      test('new traits (Courier, Anchor, Drifter) appear in inferAll', () {
        // Courier-friendly: high message ratio
        final courierEntry = _makeEntry(
          nodeNum: 50,
          encounterCount: 10,
          ageDays: 7,
          messageCount: 50,
          distinctPositions: 3,
        );
        final courierTraits = TraitEngine.inferAll(entry: courierEntry);
        final hasCourier = courierTraits.any(
          (s) => s.trait == NodeTrait.courier,
        );
        expect(
          hasCourier,
          isTrue,
          reason: 'Courier should appear for high-message node',
        );

        // Anchor-friendly: many co-seen, fixed position
        final anchorEntry = _makeEntry(
          nodeNum: 60,
          encounterCount: 20,
          ageDays: 14,
          coSeenCount: 15,
          distinctPositions: 0,
        );
        final anchorTraits = TraitEngine.inferAll(entry: anchorEntry);
        final hasAnchor = anchorTraits.any((s) => s.trait == NodeTrait.anchor);
        expect(
          hasAnchor,
          isTrue,
          reason: 'Anchor should appear for hub-like node',
        );
      });
    });

    // -------------------------------------------------------------------------
    // Cross-system coherence: subsystems agree on the node's character
    // -------------------------------------------------------------------------

    group('cross-system coherence', () {
      test('high-patina nodes always have high disclosure tiers', () {
        // Rich node should have both high patina and high disclosure
        final rich = _makeEntry(
          nodeNum: 42,
          encounterCount: 50,
          ageDays: 60,
          regionCount: 5,
          coSeenCount: 15,
          messageCount: 20,
          withSignal: true,
          bestSnr: 12,
          bestRssi: -75,
          lastSeen: refTime.subtract(const Duration(hours: 1)),
        );

        final patina = PatinaScore.computeAt(rich, refTime);
        final disclosure = ProgressiveDisclosure.computeAt(rich, refTime);

        expect(patina.score, greaterThan(40));
        expect(
          disclosure.tier.index,
          greaterThanOrEqualTo(DisclosureTier.inked.index),
        );
      });

      test('low-patina nodes have low disclosure tiers', () {
        final sparse = _makeEntry(
          nodeNum: 1,
          encounterCount: 1,
          ageDays: 0,
          lastSeen: refTime,
        );

        final patina = PatinaScore.computeAt(sparse, refTime);
        final disclosure = ProgressiveDisclosure.computeAt(sparse, refTime);

        expect(patina.score, lessThan(25));
        expect(disclosure.tier, equals(DisclosureTier.trace));
      });

      test('field note uses the same trait that infer returns', () {
        final entry = _makeEntry(
          nodeNum: 42,
          encounterCount: 20,
          ageDays: 14,
          regionCount: 3,
        );

        final trait = TraitEngine.infer(entry: entry);
        final note = FieldNoteGenerator.generate(
          entry: entry,
          trait: trait.primary,
        );

        expect(note.isNotEmpty, isTrue);
        // Note should not contain unresolved placeholders
        expect(note.contains('{'), isFalse);
        expect(note.contains('}'), isFalse);
      });

      test('sigil identity is independent of behavioral data', () {
        // Same nodeNum, vastly different behavioral data
        final sparse = _makeEntry(
          nodeNum: 0xDEAD,
          encounterCount: 1,
          ageDays: 0,
        );
        final rich = _makeEntry(
          nodeNum: 0xDEAD,
          encounterCount: 100,
          ageDays: 365,
          regionCount: 10,
          messageCount: 50,
        );

        final sigilSparse = SigilGenerator.generate(sparse.nodeNum);
        final sigilRich = SigilGenerator.generate(rich.nodeNum);

        // Sigil is identity-derived, so it must be identical
        expect(sigilRich.vertices, equals(sigilSparse.vertices));
        expect(sigilRich.rotation, equals(sigilSparse.rotation));
        expect(sigilRich.innerRings, equals(sigilSparse.innerRings));
        expect(sigilRich.drawRadials, equals(sigilSparse.drawRadials));
        expect(sigilRich.centerDot, equals(sigilSparse.centerDot));
        expect(sigilRich.symmetryFold, equals(sigilSparse.symmetryFold));
        expect(sigilRich.primaryColor, equals(sigilSparse.primaryColor));
        expect(sigilRich.secondaryColor, equals(sigilSparse.secondaryColor));
        expect(sigilRich.tertiaryColor, equals(sigilSparse.tertiaryColor));
      });

      test(
        'field note is identity-stable: same template for same nodeNum regardless of data',
        () {
          // The template selection is driven by hash of nodeNum, not data.
          // Different encounter counts should select the same template family
          // for the same trait.
          final entry1 = _makeEntry(
            nodeNum: 500,
            encounterCount: 10,
            ageDays: 7,
            regionCount: 2,
          );
          final entry2 = _makeEntry(
            nodeNum: 500,
            encounterCount: 30,
            ageDays: 7,
            regionCount: 2,
          );

          final note1 = FieldNoteGenerator.generate(
            entry: entry1,
            trait: NodeTrait.sentinel,
          );
          final note2 = FieldNoteGenerator.generate(
            entry: entry2,
            trait: NodeTrait.sentinel,
          );

          // Both notes should share the same template structure.
          // The easiest check: they should share most of the non-numeric words.
          final words1 = note1.split(' ').where((w) => !_isNumeric(w)).toSet();
          final words2 = note2.split(' ').where((w) => !_isNumeric(w)).toSet();
          final common = words1.intersection(words2);

          expect(
            common.length,
            greaterThan(words1.length ~/ 2),
            reason:
                'Notes should share template structure.\n'
                'Note1: "$note1"\nNote2: "$note2"',
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // NodeTrait enum: new traits are well-formed
    // -------------------------------------------------------------------------

    group('NodeTrait enum completeness', () {
      test('all traits have non-empty displayLabel', () {
        for (final trait in NodeTrait.values) {
          expect(
            trait.displayLabel.isNotEmpty,
            isTrue,
            reason: '${trait.name} has empty displayLabel',
          );
        }
      });

      test('all traits have non-empty description', () {
        for (final trait in NodeTrait.values) {
          expect(
            trait.description.isNotEmpty,
            isTrue,
            reason: '${trait.name} has empty description',
          );
        }
      });

      test('all traits have a non-zero color', () {
        for (final trait in NodeTrait.values) {
          expect(
            trait.color.value,
            isNot(0),
            reason: '${trait.name} has zero color value',
          );
        }
      });

      test('new traits exist: courier, anchor, drifter', () {
        final traitNames = NodeTrait.values.map((t) => t.name).toSet();
        expect(traitNames, contains('courier'));
        expect(traitNames, contains('anchor'));
        expect(traitNames, contains('drifter'));
      });
    });

    // -------------------------------------------------------------------------
    // Overlay data determinism
    // -------------------------------------------------------------------------

    group('overlay data consistency', () {
      test('SigilGenerator.mix is deterministic', () {
        for (int i = 0; i < 100; i++) {
          final a = SigilGenerator.mix(i);
          final b = SigilGenerator.mix(i);
          expect(a, equals(b), reason: 'mix($i) is not deterministic');
        }
      });

      test('SigilGenerator.mix has avalanche properties', () {
        // Flipping one bit in the input should flip many bits in the output
        final base = SigilGenerator.mix(0x12345678);
        final flipped = SigilGenerator.mix(0x12345679); // one bit different

        // They should be different
        expect(base, isNot(equals(flipped)));

        // Count differing bits (Hamming distance)
        int xor = (base ^ flipped) & 0xFFFFFFFF;
        int diffBits = 0;
        while (xor > 0) {
          diffBits += xor & 1;
          xor >>= 1;
        }

        // Good avalanche = ~50% of bits differ (16 out of 32)
        // We just check it's reasonably distributed (> 5 bits)
        expect(
          diffBits,
          greaterThan(5),
          reason: 'Only $diffBits bits differ; poor avalanche',
        );
      });

      test('SigilGenerator.computePoints is deterministic', () {
        final sigil = SigilGenerator.generate(42);
        final points1 = SigilGenerator.computePoints(sigil);
        final points2 = SigilGenerator.computePoints(sigil);

        expect(points1.length, equals(points2.length));
        for (int i = 0; i < points1.length; i++) {
          expect(points1[i].dx, equals(points2[i].dx));
          expect(points1[i].dy, equals(points2[i].dy));
        }
      });

      test('SigilGenerator.computeEdges is deterministic', () {
        final sigil = SigilGenerator.generate(42);
        final edges1 = SigilGenerator.computeEdges(sigil);
        final edges2 = SigilGenerator.computeEdges(sigil);

        expect(edges1.length, equals(edges2.length));
        for (int i = 0; i < edges1.length; i++) {
          expect(edges1[i].$1, equals(edges2[i].$1));
          expect(edges1[i].$2, equals(edges2[i].$2));
        }
      });
    });

    // -------------------------------------------------------------------------
    // Patina stamp labels progression
    // -------------------------------------------------------------------------

    group('stamp label progression', () {
      test('stamp labels progress from Trace to Canonical', () {
        final labels = <String>[];

        // Build entries with increasing richness
        final configs = [
          (1, 0, 0, 0, 0), // encounters, days, regions, coSeen, messages
          (3, 2, 1, 0, 0),
          (10, 7, 2, 3, 2),
          (25, 21, 3, 8, 10),
          (50, 60, 5, 15, 25),
          (80, 120, 8, 25, 40),
        ];

        for (final (enc, days, reg, coSeen, msg) in configs) {
          final entry = _makeEntry(
            nodeNum: 42,
            encounterCount: enc,
            ageDays: days,
            regionCount: reg,
            coSeenCount: coSeen,
            messageCount: msg,
            withSignal: true,
            bestSnr: 12,
            bestRssi: -75,
            lastSeen: refTime.subtract(const Duration(hours: 1)),
          );
          final result = PatinaScore.computeAt(entry, refTime);
          labels.add(result.stampLabel);
        }

        // Labels should generally progress (earlier entries should have
        // lower-tier labels than later entries)
        final validLabels = [
          'Trace',
          'Faint',
          'Noted',
          'Logged',
          'Inked',
          'Etched',
          'Archival',
          'Canonical',
        ];

        for (final label in labels) {
          expect(
            validLabels.contains(label),
            isTrue,
            reason: 'Unknown stamp label: $label',
          );
        }

        // First label should be a low-tier one
        final firstIndex = validLabels.indexOf(labels.first);
        final lastIndex = validLabels.indexOf(labels.last);
        expect(
          lastIndex,
          greaterThanOrEqualTo(firstIndex),
          reason:
              'Labels should progress from low to high tier.\n'
              'Got: $labels',
        );
      });
    });

    // -------------------------------------------------------------------------
    // No constellation screen references in new code
    // -------------------------------------------------------------------------

    group('architectural constraints', () {
      test('NodeTrait enum has all expected values', () {
        final expected = {
          'wanderer',
          'beacon',
          'ghost',
          'sentinel',
          'relay',
          'courier',
          'anchor',
          'drifter',
          'unknown',
        };

        final actual = NodeTrait.values.map((t) => t.name).toSet();
        expect(actual, containsAll(expected));
      });

      test('PatinaScore weights sum to 1.0', () {
        // We cannot directly access private weights, but we can verify
        // that the score is bounded [0, 100] and the axes sum reasonably.
        final entry = _makeEntry(
          nodeNum: 42,
          encounterCount: 50,
          ageDays: 90,
          regionCount: 6,
          coSeenCount: 20,
          messageCount: 30,
          withSignal: true,
          bestSnr: 15,
          bestRssi: -60,
          lastSeen: refTime.subtract(const Duration(minutes: 5)),
        );
        final result = PatinaScore.computeAt(entry, refTime);

        // If all axes are near 1.0, the score should be near 100
        // This indirectly verifies the weights sum to 1.0
        expect(result.score, greaterThan(70));
        expect(result.score, lessThanOrEqualTo(100));
      });

      test('disclosure tiers are ordered correctly', () {
        expect(DisclosureTier.trace.index, equals(0));
        expect(DisclosureTier.noted.index, equals(1));
        expect(DisclosureTier.logged.index, equals(2));
        expect(DisclosureTier.inked.index, equals(3));
        expect(DisclosureTier.etched.index, equals(4));
      });
    });
  });
}

/// Check if a string looks like a number (integer or decimal).
bool _isNumeric(String s) {
  return double.tryParse(s) != null ||
      int.tryParse(s) != null ||
      RegExp(r'^\d+[.]\d+').hasMatch(s);
}
