// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/models/sigil_evolution.dart';

void main() {
  // ===========================================================================
  // Stage mapping from patinaScore
  // ===========================================================================

  group('SigilEvolution stage mapping', () {
    test('score 0 maps to seed', () {
      final evo = SigilEvolution.fromPatina(0);
      expect(evo.stage, equals(SigilStage.seed));
    });

    test('score 19 maps to seed', () {
      final evo = SigilEvolution.fromPatina(19);
      expect(evo.stage, equals(SigilStage.seed));
    });

    test('score 20 maps to marked', () {
      final evo = SigilEvolution.fromPatina(20);
      expect(evo.stage, equals(SigilStage.marked));
    });

    test('score 39 maps to marked', () {
      final evo = SigilEvolution.fromPatina(39);
      expect(evo.stage, equals(SigilStage.marked));
    });

    test('score 40 maps to inscribed', () {
      final evo = SigilEvolution.fromPatina(40);
      expect(evo.stage, equals(SigilStage.inscribed));
    });

    test('score 59 maps to inscribed', () {
      final evo = SigilEvolution.fromPatina(59);
      expect(evo.stage, equals(SigilStage.inscribed));
    });

    test('score 60 maps to heraldic', () {
      final evo = SigilEvolution.fromPatina(60);
      expect(evo.stage, equals(SigilStage.heraldic));
    });

    test('score 79 maps to heraldic', () {
      final evo = SigilEvolution.fromPatina(79);
      expect(evo.stage, equals(SigilStage.heraldic));
    });

    test('score 80 maps to legacy', () {
      final evo = SigilEvolution.fromPatina(80);
      expect(evo.stage, equals(SigilStage.legacy));
    });

    test('score 100 maps to legacy', () {
      final evo = SigilEvolution.fromPatina(100);
      expect(evo.stage, equals(SigilStage.legacy));
    });

    test('all boundary values map correctly', () {
      // Exhaustive boundary test.
      final expected = <int, SigilStage>{
        0: SigilStage.seed,
        1: SigilStage.seed,
        10: SigilStage.seed,
        19: SigilStage.seed,
        20: SigilStage.marked,
        25: SigilStage.marked,
        39: SigilStage.marked,
        40: SigilStage.inscribed,
        50: SigilStage.inscribed,
        59: SigilStage.inscribed,
        60: SigilStage.heraldic,
        70: SigilStage.heraldic,
        79: SigilStage.heraldic,
        80: SigilStage.legacy,
        90: SigilStage.legacy,
        100: SigilStage.legacy,
      };

      for (final entry in expected.entries) {
        final evo = SigilEvolution.fromPatina(entry.key);
        expect(
          evo.stage,
          equals(entry.value),
          reason: 'patina ${entry.key} should map to ${entry.value}',
        );
      }
    });
  });

  // ===========================================================================
  // Detail tier
  // ===========================================================================

  group('SigilEvolution detailTier', () {
    test('seed has detailTier 0', () {
      final evo = SigilEvolution.fromPatina(10);
      expect(evo.detailTier, equals(0));
    });

    test('marked has detailTier 1', () {
      final evo = SigilEvolution.fromPatina(30);
      expect(evo.detailTier, equals(1));
    });

    test('inscribed has detailTier 2', () {
      final evo = SigilEvolution.fromPatina(50);
      expect(evo.detailTier, equals(2));
    });

    test('heraldic has detailTier 3', () {
      final evo = SigilEvolution.fromPatina(70);
      expect(evo.detailTier, equals(3));
    });

    test('legacy has detailTier 4', () {
      final evo = SigilEvolution.fromPatina(90);
      expect(evo.detailTier, equals(4));
    });

    test('detailTier mirrors stage index for all stages', () {
      for (final stage in SigilStage.values) {
        final score = stage.index * 20 + 5; // mid-range for each stage
        final evo = SigilEvolution.fromPatina(score);
        expect(
          evo.detailTier,
          equals(stage.index),
          reason: 'detailTier for ${stage.name} should be ${stage.index}',
        );
      }
    });
  });

  // ===========================================================================
  // lineWeightScale
  // ===========================================================================

  group('SigilEvolution lineWeightScale', () {
    test('seed has lineWeightScale 1.00', () {
      final evo = SigilEvolution.fromPatina(5);
      expect(evo.lineWeightScale, equals(1.00));
    });

    test('marked has lineWeightScale 1.05', () {
      final evo = SigilEvolution.fromPatina(25);
      expect(evo.lineWeightScale, equals(1.05));
    });

    test('inscribed has lineWeightScale 1.10', () {
      final evo = SigilEvolution.fromPatina(45);
      expect(evo.lineWeightScale, equals(1.10));
    });

    test('heraldic has lineWeightScale 1.15', () {
      final evo = SigilEvolution.fromPatina(65);
      expect(evo.lineWeightScale, equals(1.15));
    });

    test('legacy has lineWeightScale 1.20', () {
      final evo = SigilEvolution.fromPatina(85);
      expect(evo.lineWeightScale, equals(1.20));
    });

    test('lineWeightScale never exceeds 1.20', () {
      final evo = SigilEvolution.fromPatina(100);
      expect(evo.lineWeightScale, lessThanOrEqualTo(1.20));
    });

    test('lineWeightScale never goes below 1.00', () {
      final evo = SigilEvolution.fromPatina(0);
      expect(evo.lineWeightScale, greaterThanOrEqualTo(1.00));
    });

    test('lineWeightScale is monotonically non-decreasing with stage', () {
      double prev = 0.0;
      for (final stage in SigilStage.values) {
        final score = stage.index * 20 + 5;
        final evo = SigilEvolution.fromPatina(score);
        expect(
          evo.lineWeightScale,
          greaterThanOrEqualTo(prev),
          reason:
              'lineWeightScale for ${stage.name} should be >= previous stage',
        );
        prev = evo.lineWeightScale;
      }
    });
  });

  // ===========================================================================
  // toneScale
  // ===========================================================================

  group('SigilEvolution toneScale', () {
    test('seed has toneScale 1.00', () {
      final evo = SigilEvolution.fromPatina(5);
      expect(evo.toneScale, equals(1.00));
    });

    test('marked has toneScale 1.03', () {
      final evo = SigilEvolution.fromPatina(25);
      expect(evo.toneScale, equals(1.03));
    });

    test('inscribed has toneScale 1.06', () {
      final evo = SigilEvolution.fromPatina(45);
      expect(evo.toneScale, equals(1.06));
    });

    test('heraldic has toneScale 1.09', () {
      final evo = SigilEvolution.fromPatina(65);
      expect(evo.toneScale, equals(1.09));
    });

    test('legacy has toneScale 1.12', () {
      final evo = SigilEvolution.fromPatina(85);
      expect(evo.toneScale, equals(1.12));
    });

    test('toneScale never exceeds 1.12', () {
      final evo = SigilEvolution.fromPatina(100);
      expect(evo.toneScale, lessThanOrEqualTo(1.12));
    });

    test('toneScale never goes below 1.00', () {
      final evo = SigilEvolution.fromPatina(0);
      expect(evo.toneScale, greaterThanOrEqualTo(1.00));
    });

    test('toneScale is monotonically non-decreasing with stage', () {
      double prev = 0.0;
      for (final stage in SigilStage.values) {
        final score = stage.index * 20 + 5;
        final evo = SigilEvolution.fromPatina(score);
        expect(
          evo.toneScale,
          greaterThanOrEqualTo(prev),
          reason: 'toneScale for ${stage.name} should be >= previous stage',
        );
        prev = evo.toneScale;
      }
    });
  });

  // ===========================================================================
  // Determinism
  // ===========================================================================

  group('SigilEvolution determinism', () {
    test('same patinaScore always produces same evolution', () {
      for (int score = 0; score <= 100; score += 7) {
        final evo1 = SigilEvolution.fromPatina(score);
        final evo2 = SigilEvolution.fromPatina(score);
        expect(evo1.stage, equals(evo2.stage));
        expect(evo1.detailTier, equals(evo2.detailTier));
        expect(evo1.lineWeightScale, equals(evo2.lineWeightScale));
        expect(evo1.toneScale, equals(evo2.toneScale));
        expect(evo1.augments, equals(evo2.augments));
        expect(evo1.patinaScore, equals(evo2.patinaScore));
      }
    });

    test('same patinaScore + same trait produces identical evolution', () {
      for (final trait in NodeTrait.values) {
        final evo1 = SigilEvolution.fromPatina(62, trait: trait);
        final evo2 = SigilEvolution.fromPatina(62, trait: trait);
        expect(evo1, equals(evo2));
      }
    });

    test('same score with different trait produces same stage and tier', () {
      final evo1 = SigilEvolution.fromPatina(55, trait: NodeTrait.relay);
      final evo2 = SigilEvolution.fromPatina(55, trait: NodeTrait.wanderer);
      expect(evo1.stage, equals(evo2.stage));
      expect(evo1.detailTier, equals(evo2.detailTier));
      expect(evo1.lineWeightScale, equals(evo2.lineWeightScale));
      expect(evo1.toneScale, equals(evo2.toneScale));
      // Augments differ based on trait.
    });

    test('evolution stores the patinaScore it was created from', () {
      for (int score = 0; score <= 100; score += 10) {
        final evo = SigilEvolution.fromPatina(score);
        expect(evo.patinaScore, equals(score));
      }
    });
  });

  // ===========================================================================
  // Augments
  // ===========================================================================

  group('SigilEvolution augments', () {
    test('no augments below inscribed stage', () {
      // Seed (0-19) — no augments regardless of trait.
      for (int score = 0; score < 20; score += 5) {
        final evo = SigilEvolution.fromPatina(score, trait: NodeTrait.relay);
        expect(evo.augments, isEmpty, reason: 'seed should have no augments');
      }

      // Marked (20-39) — no augments regardless of trait.
      for (int score = 20; score < 40; score += 5) {
        final evo = SigilEvolution.fromPatina(score, trait: NodeTrait.wanderer);
        expect(evo.augments, isEmpty, reason: 'marked should have no augments');
      }
    });

    test('relay trait produces relayMark at inscribed+', () {
      final evo = SigilEvolution.fromPatina(50, trait: NodeTrait.relay);
      expect(evo.augments, contains(SigilAugment.relayMark));
    });

    test('wanderer trait produces wandererMark at inscribed+', () {
      final evo = SigilEvolution.fromPatina(50, trait: NodeTrait.wanderer);
      expect(evo.augments, contains(SigilAugment.wandererMark));
    });

    test('ghost trait produces ghostMark at inscribed+', () {
      final evo = SigilEvolution.fromPatina(50, trait: NodeTrait.ghost);
      expect(evo.augments, contains(SigilAugment.ghostMark));
    });

    test('only one augment per sigil', () {
      for (final trait in NodeTrait.values) {
        final evo = SigilEvolution.fromPatina(80, trait: trait);
        expect(
          evo.augments.length,
          lessThanOrEqualTo(1),
          reason: 'max one augment per sigil, trait: ${trait.name}',
        );
      }
    });

    test('non-augmented traits produce empty augments at high stages', () {
      final noAugmentTraits = [
        NodeTrait.beacon,
        NodeTrait.sentinel,
        NodeTrait.courier,
        NodeTrait.anchor,
        NodeTrait.drifter,
        NodeTrait.unknown,
      ];

      for (final trait in noAugmentTraits) {
        final evo = SigilEvolution.fromPatina(95, trait: trait);
        expect(
          evo.augments,
          isEmpty,
          reason: '${trait.name} should not produce augments',
        );
      }
    });

    test('no trait produces no augments even at legacy', () {
      final evo = SigilEvolution.fromPatina(95);
      expect(evo.augments, isEmpty);
    });

    test('augments appear at inscribed (40+) and persist through legacy', () {
      // Verify augments at each stage from inscribed up.
      for (int score in [40, 50, 60, 70, 80, 90, 100]) {
        final evo = SigilEvolution.fromPatina(score, trait: NodeTrait.relay);
        expect(
          evo.augments,
          isNotEmpty,
          reason: 'relay augment should appear at score $score',
        );
      }
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('SigilEvolution edge cases', () {
    test('negative score is clamped to 0 (seed)', () {
      final evo = SigilEvolution.fromPatina(-10);
      expect(evo.stage, equals(SigilStage.seed));
      expect(evo.patinaScore, equals(0));
      expect(evo.detailTier, equals(0));
    });

    test('score above 100 is clamped to 100 (legacy)', () {
      final evo = SigilEvolution.fromPatina(150);
      expect(evo.stage, equals(SigilStage.legacy));
      expect(evo.patinaScore, equals(100));
      expect(evo.detailTier, equals(4));
    });

    test('score exactly at each boundary transitions correctly', () {
      // Test the exact boundary values.
      expect(SigilEvolution.fromPatina(19).stage, equals(SigilStage.seed));
      expect(SigilEvolution.fromPatina(20).stage, equals(SigilStage.marked));
      expect(SigilEvolution.fromPatina(39).stage, equals(SigilStage.marked));
      expect(SigilEvolution.fromPatina(40).stage, equals(SigilStage.inscribed));
      expect(SigilEvolution.fromPatina(59).stage, equals(SigilStage.inscribed));
      expect(SigilEvolution.fromPatina(60).stage, equals(SigilStage.heraldic));
      expect(SigilEvolution.fromPatina(79).stage, equals(SigilStage.heraldic));
      expect(SigilEvolution.fromPatina(80).stage, equals(SigilStage.legacy));
    });

    test('every integer score from 0 to 100 produces a valid evolution', () {
      for (int score = 0; score <= 100; score++) {
        final evo = SigilEvolution.fromPatina(score);
        expect(evo.stage, isNotNull);
        expect(evo.patinaScore, equals(score));
        expect(evo.detailTier, inInclusiveRange(0, 4));
        expect(evo.lineWeightScale, inInclusiveRange(1.00, 1.20));
        expect(evo.toneScale, inInclusiveRange(1.00, 1.12));
        expect(evo.augments, isNotNull);
      }
    });
  });

  // ===========================================================================
  // Equality and hashCode
  // ===========================================================================

  group('SigilEvolution equality', () {
    test('two evolutions with same inputs are equal', () {
      final evo1 = SigilEvolution.fromPatina(55, trait: NodeTrait.relay);
      final evo2 = SigilEvolution.fromPatina(55, trait: NodeTrait.relay);
      expect(evo1, equals(evo2));
      expect(evo1.hashCode, equals(evo2.hashCode));
    });

    test('evolutions with different scores are not equal', () {
      final evo1 = SigilEvolution.fromPatina(55);
      final evo2 = SigilEvolution.fromPatina(56);
      expect(evo1, isNot(equals(evo2)));
    });

    test(
      'evolutions with different traits are not equal if augments differ',
      () {
        final evo1 = SigilEvolution.fromPatina(55, trait: NodeTrait.relay);
        final evo2 = SigilEvolution.fromPatina(55, trait: NodeTrait.wanderer);
        expect(evo1, isNot(equals(evo2)));
      },
    );

    test('evolutions with same score but non-augmented traits are equal', () {
      final evo1 = SigilEvolution.fromPatina(55, trait: NodeTrait.beacon);
      final evo2 = SigilEvolution.fromPatina(55, trait: NodeTrait.sentinel);
      // Both produce same stage, tier, scales, and empty augments.
      // But patinaScore differs? No, both are 55.
      expect(evo1, equals(evo2));
    });
  });

  // ===========================================================================
  // SigilStage enum
  // ===========================================================================

  group('SigilStage enum', () {
    test('has exactly 5 values', () {
      expect(SigilStage.values.length, equals(5));
    });

    test('values are in correct order', () {
      expect(SigilStage.seed.index, equals(0));
      expect(SigilStage.marked.index, equals(1));
      expect(SigilStage.inscribed.index, equals(2));
      expect(SigilStage.heraldic.index, equals(3));
      expect(SigilStage.legacy.index, equals(4));
    });

    test('all stages have non-empty display labels', () {
      for (final stage in SigilStage.values) {
        expect(
          stage.displayLabel.isNotEmpty,
          isTrue,
          reason: '${stage.name} should have a non-empty displayLabel',
        );
      }
    });

    test('display labels are unique', () {
      final labels = SigilStage.values.map((s) => s.displayLabel).toSet();
      expect(labels.length, equals(SigilStage.values.length));
    });
  });

  // ===========================================================================
  // SigilAugment enum
  // ===========================================================================

  group('SigilAugment enum', () {
    test('has exactly 3 values', () {
      expect(SigilAugment.values.length, equals(3));
    });

    test('contains expected augment types', () {
      expect(SigilAugment.values, contains(SigilAugment.relayMark));
      expect(SigilAugment.values, contains(SigilAugment.wandererMark));
      expect(SigilAugment.values, contains(SigilAugment.ghostMark));
    });
  });

  // ===========================================================================
  // toString
  // ===========================================================================

  group('SigilEvolution toString', () {
    test('produces a readable string', () {
      final evo = SigilEvolution.fromPatina(62, trait: NodeTrait.wanderer);
      final str = evo.toString();
      expect(str, contains('Heraldic'));
      expect(str, contains('62'));
      expect(str, contains('tier: 3'));
    });

    test('includes augments when present', () {
      final evo = SigilEvolution.fromPatina(62, trait: NodeTrait.relay);
      final str = evo.toString();
      expect(str, contains('augments'));
    });

    test('omits augments section when empty', () {
      final evo = SigilEvolution.fromPatina(62, trait: NodeTrait.beacon);
      final str = evo.toString();
      expect(str, isNot(contains('augments')));
    });
  });

  // ===========================================================================
  // Monotonicity across full range
  // ===========================================================================

  group('SigilEvolution monotonicity', () {
    test('stage index never decreases as score increases', () {
      int prevStageIndex = -1;
      for (int score = 0; score <= 100; score++) {
        final evo = SigilEvolution.fromPatina(score);
        expect(
          evo.stage.index,
          greaterThanOrEqualTo(prevStageIndex),
          reason: 'stage should not decrease at score $score',
        );
        prevStageIndex = evo.stage.index;
      }
    });

    test('detailTier never decreases as score increases', () {
      int prevTier = -1;
      for (int score = 0; score <= 100; score++) {
        final evo = SigilEvolution.fromPatina(score);
        expect(
          evo.detailTier,
          greaterThanOrEqualTo(prevTier),
          reason: 'detailTier should not decrease at score $score',
        );
        prevTier = evo.detailTier;
      }
    });

    test('lineWeightScale never decreases as score increases', () {
      double prevWeight = 0.0;
      for (int score = 0; score <= 100; score++) {
        final evo = SigilEvolution.fromPatina(score);
        expect(
          evo.lineWeightScale,
          greaterThanOrEqualTo(prevWeight),
          reason: 'lineWeightScale should not decrease at score $score',
        );
        prevWeight = evo.lineWeightScale;
      }
    });

    test('toneScale never decreases as score increases', () {
      double prevTone = 0.0;
      for (int score = 0; score <= 100; score++) {
        final evo = SigilEvolution.fromPatina(score);
        expect(
          evo.toneScale,
          greaterThanOrEqualTo(prevTone),
          reason: 'toneScale should not decrease at score $score',
        );
        prevTone = evo.toneScale;
      }
    });
  });

  // ===========================================================================
  // Const construction
  // ===========================================================================

  group('SigilEvolution const construction', () {
    test('can be created with const constructor', () {
      const evo = SigilEvolution(
        stage: SigilStage.seed,
        patinaScore: 0,
        detailTier: 0,
        lineWeightScale: 1.0,
        toneScale: 1.0,
      );
      expect(evo.stage, equals(SigilStage.seed));
      expect(evo.augments, isEmpty);
    });

    test('default augments is empty list', () {
      const evo = SigilEvolution(
        stage: SigilStage.legacy,
        patinaScore: 100,
        detailTier: 4,
        lineWeightScale: 1.20,
        toneScale: 1.12,
      );
      expect(evo.augments, isEmpty);
    });
  });
}
