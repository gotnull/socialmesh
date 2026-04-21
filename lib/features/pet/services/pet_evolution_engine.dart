// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetEvolutionEngine — pure functions that decide when a pet advances to the
// next stage and (at the adolescent→adult boundary) which branch it takes.
//
// Branch rules are deliberately simple and explainable from code — no RPG
// stat soup. Three dimensions ride over adolescent stage accumulators:
// mistakes, surges, attentionScore. Four buckets: Luminous, Steady,
// Volatile, Dimmed.

import '../models/care_accumulators.dart';
import '../models/pet_config.dart';
import '../models/pet_enums.dart';

class PetEvolutionEngine {
  final PetConfig config;

  const PetEvolutionEngine({required this.config});

  /// Duration the pet should remain in [stage] before auto-advancing.
  /// Dormant is indefinite — returns null.
  Duration? durationFor(PetStage stage) {
    switch (stage) {
      case PetStage.egg:
        return config.eggDuration;
      case PetStage.juvenile:
        return config.juvenileDuration;
      case PetStage.adolescent:
        return config.adolescentDuration;
      case PetStage.adult:
        return config.adultDuration;
      case PetStage.elder:
        return config.elderDuration;
      case PetStage.dormant:
        return null;
    }
  }

  /// True if [stage] has been active for longer than its configured duration.
  bool shouldAdvance({
    required PetStage stage,
    required DateTime stageStartedAt,
    required DateTime now,
  }) {
    final d = durationFor(stage);
    if (d == null) return false;
    return !now.isBefore(stageStartedAt.add(d));
  }

  /// Next stage in the linear progression. Dormant is terminal (returns
  /// dormant); re-sigilling is a separate user action that replaces state.
  PetStage nextStage(PetStage current) {
    switch (current) {
      case PetStage.egg:
        return PetStage.juvenile;
      case PetStage.juvenile:
        return PetStage.adolescent;
      case PetStage.adolescent:
        return PetStage.adult;
      case PetStage.adult:
        return PetStage.elder;
      case PetStage.elder:
        return PetStage.dormant;
      case PetStage.dormant:
        return PetStage.dormant;
    }
  }

  /// Branch selection at the adolescent→adult transition.
  ///
  /// Rules (evaluated in order):
  ///   1. mistakes ≤ luminousMaxMistakes AND attentionScore ≥ luminousMin
  ///        → Luminous
  ///   2. surges ≥ volatileMinSurges → Volatile (high-surge profiles are
  ///        energetic but unstable; outrank Steady even at low mistakes)
  ///   3. mistakes ≤ steadyMaxMistakes → Steady
  ///   4. otherwise → Dimmed (neglect path)
  ///
  /// Applied only when transitioning INTO adult (from adolescent). Other
  /// transitions preserve the existing branch.
  PetBranch selectBranchForAdult(CareAccumulators acc) {
    if (acc.mistakes <= config.luminousMaxMistakes &&
        acc.attentionScore >= config.luminousMinAttentionScore) {
      return PetBranch.luminous;
    }
    if (acc.surges >= config.volatileMinSurges) {
      return PetBranch.volatile;
    }
    if (acc.mistakes <= config.steadyMaxMistakes) {
      return PetBranch.steady;
    }
    return PetBranch.dimmed;
  }

  /// Resolve the branch for a given stage transition. Most transitions keep
  /// the current branch; adolescent→adult is the sole branching moment;
  /// egg→juvenile initialises to [PetBranch.unborn] (the "no branch yet"
  /// sentinel resolves to Steady by default so the juvenile renders as a
  /// neutral form until adult-resolution).
  PetBranch resolveBranch({
    required PetStage from,
    required PetStage to,
    required PetBranch current,
    required CareAccumulators acc,
  }) {
    if (from == PetStage.egg && to == PetStage.juvenile) {
      return PetBranch.steady; // neutral baseline
    }
    if (from == PetStage.adolescent && to == PetStage.adult) {
      return selectBranchForAdult(acc);
    }
    return current;
  }
}
