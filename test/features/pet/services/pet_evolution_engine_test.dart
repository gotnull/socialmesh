// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/care_accumulators.dart';
import 'package:socialmesh/features/pet/models/pet_config.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/services/pet_evolution_engine.dart';

void main() {
  const config = PetConfig();
  const engine = PetEvolutionEngine(config: config);

  group('PetEvolutionEngine stage progression', () {
    test('egg → juvenile → adolescent → adult → elder → dormant', () {
      expect(engine.nextStage(PetStage.egg), PetStage.juvenile);
      expect(engine.nextStage(PetStage.juvenile), PetStage.adolescent);
      expect(engine.nextStage(PetStage.adolescent), PetStage.adult);
      expect(engine.nextStage(PetStage.adult), PetStage.elder);
      expect(engine.nextStage(PetStage.elder), PetStage.dormant);
    });

    test('dormant is terminal', () {
      expect(engine.nextStage(PetStage.dormant), PetStage.dormant);
    });

    test('shouldAdvance respects configured stage duration', () {
      final now = DateTime(2026, 1, 1, 12);
      final justStarted = now;
      final aWhileAgo = now.subtract(const Duration(days: 10));

      expect(
        engine.shouldAdvance(
          stage: PetStage.juvenile,
          stageStartedAt: justStarted,
          now: now,
        ),
        isFalse,
      );
      expect(
        engine.shouldAdvance(
          stage: PetStage.juvenile,
          stageStartedAt: aWhileAgo,
          now: now,
        ),
        isTrue,
      );
    });

    test('dormant never advances by time', () {
      final now = DateTime(2026, 1, 1);
      expect(
        engine.shouldAdvance(
          stage: PetStage.dormant,
          stageStartedAt: now.subtract(const Duration(days: 365)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('PetEvolutionEngine adult branch selection', () {
    test('pristine care → Luminous', () {
      const acc = CareAccumulators(
        mistakes: 0,
        surges: 0,
        answeredCalls: 5,
        totalCalls: 5,
      );
      expect(engine.selectBranchForAdult(acc), PetBranch.luminous);
    });

    test('moderate care with no surges → Steady', () {
      const acc = CareAccumulators(
        mistakes: 4,
        surges: 1,
        answeredCalls: 3,
        totalCalls: 6,
      );
      expect(engine.selectBranchForAdult(acc), PetBranch.steady);
    });

    test('high-surge profile → Volatile (outranks Steady)', () {
      const acc = CareAccumulators(
        mistakes: 3,
        surges: 10,
        answeredCalls: 4,
        totalCalls: 5,
      );
      expect(engine.selectBranchForAdult(acc), PetBranch.volatile);
    });

    test('heavy neglect → Dimmed', () {
      const acc = CareAccumulators(
        mistakes: 20,
        surges: 0,
        answeredCalls: 0,
        totalCalls: 10,
      );
      expect(engine.selectBranchForAdult(acc), PetBranch.dimmed);
    });

    test('boundary: luminousMaxMistakes inclusive', () {
      final atBoundary = CareAccumulators(
        mistakes: config.luminousMaxMistakes,
        surges: 0,
        answeredCalls: 10,
        totalCalls: 10,
      );
      expect(engine.selectBranchForAdult(atBoundary), PetBranch.luminous);
    });

    test('boundary: attentionScore below Luminous min demotes to Steady', () {
      final lowAttention = CareAccumulators(
        mistakes: 0,
        surges: 0,
        answeredCalls: 3,
        totalCalls: 10, // 0.3 < 0.7
      );
      expect(engine.selectBranchForAdult(lowAttention), PetBranch.steady);
    });
  });

  group('PetEvolutionEngine resolveBranch', () {
    test('egg → juvenile seeds neutral Steady baseline', () {
      expect(
        engine.resolveBranch(
          from: PetStage.egg,
          to: PetStage.juvenile,
          current: PetBranch.unborn,
          acc: const CareAccumulators.empty(),
        ),
        PetBranch.steady,
      );
    });

    test('adolescent → adult resolves via accumulators', () {
      const pristine = CareAccumulators(
        mistakes: 0,
        surges: 0,
        answeredCalls: 10,
        totalCalls: 10,
      );
      expect(
        engine.resolveBranch(
          from: PetStage.adolescent,
          to: PetStage.adult,
          current: PetBranch.steady,
          acc: pristine,
        ),
        PetBranch.luminous,
      );
    });

    test('adult → elder preserves current branch', () {
      expect(
        engine.resolveBranch(
          from: PetStage.adult,
          to: PetStage.elder,
          current: PetBranch.volatile,
          acc: const CareAccumulators.empty(),
        ),
        PetBranch.volatile,
      );
    });

    test('elder → dormant preserves current branch', () {
      expect(
        engine.resolveBranch(
          from: PetStage.elder,
          to: PetStage.dormant,
          current: PetBranch.luminous,
          acc: const CareAccumulators.empty(),
        ),
        PetBranch.luminous,
      );
    });
  });
}
