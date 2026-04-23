// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetRiveAdapter — the single translation layer between Socialmesh's
// procedural pet state (authoritative, device-local) and a Rive-backed
// presentation surface.
//
// Invariants:
//   - Procedural state (PetState, PetCareEngine, PetSigilGeometry) is
//     the source of truth. Rive is a presentation layer only.
//   - The adapter MUST be pure Dart with no `rive` import. This keeps
//     it testable without the Rive runtime and lets it ship ahead of
//     the package/asset landing.
//   - Inputs are flattened into primitive types (int / bool / double)
//     so a designer can route them to State Machine number/bool inputs
//     without reproducing seed math inside Rive.
//   - Seed-derived TRAITS are bucketed into small integer ranges here;
//     raw dnaSeed never crosses the Dart↔Rive boundary.
//
// Naming contract (designer-facing — these are the State Machine input
// names the .riv file MUST expose verbatim, or the adapter's apply step
// silently no-ops on missing ones):
//
//   Number inputs  :  stageIndex, branchIndex, moodIndex,
//                     symmetryClass, strandConfig, signatureRotationDeg,
//                     hygieneArtefactCount,
//                     vitality, buoyancy, auraIntensity
//   Bool inputs    :  isAsleep, isSick, isCalling, hasAnomaly
//   Triggers       :  hatchTrigger, actionTrigger

import 'package:flutter/foundation.dart';

import '../models/pet_config.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import '../widgets/pet_render_model.dart'
    show PetSigilGeometry, petBuoyancyScale, petAuraIntensityScale;

/// Flat primitive-only bundle fed into a Rive StateMachineController.
/// Constructed via [PetRiveAdapter.buildInputs]; applied via
/// [PetRiveStateMachineApplier] (which the Rive-runtime-using widget
/// owns).
@immutable
class PetRiveInputs {
  // --- Discrete enums (number inputs) ---
  final int stageIndex;
  final int branchIndex;
  final int moodIndex;

  // --- Flags (bool inputs) ---
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;

  // --- Analog modifiers in [0, 1] (number inputs) ---
  final double vitality;
  final double buoyancy;
  final double auraIntensity;

  // --- Small bounded counter (number input) ---
  final int hygieneArtefactCount;

  // --- Seed-derived trait buckets (number / bool inputs) ---
  final int symmetryClass; // 0..3  (5→0, 6→1, 7→2, 8→3)
  final int strandConfig; // 0..2  (monad/dyad/triad)
  final bool hasAnomaly;
  final int signatureRotationDeg; // 0..359

  const PetRiveInputs({
    required this.stageIndex,
    required this.branchIndex,
    required this.moodIndex,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.vitality,
    required this.buoyancy,
    required this.auraIntensity,
    required this.hygieneArtefactCount,
    required this.symmetryClass,
    required this.strandConfig,
    required this.hasAnomaly,
    required this.signatureRotationDeg,
  });

  /// "Full health baseline" default — used when raw stats aren't
  /// available (e.g. mini previews built from PetPublicState).
  static const PetRiveInputs healthyAdultSteady = PetRiveInputs(
    stageIndex: 3, // adult
    branchIndex: 2, // steady
    moodIndex: 0, // content
    isAsleep: false,
    isSick: false,
    isCalling: false,
    vitality: 1.0,
    buoyancy: 1.0,
    auraIntensity: 1.0,
    hygieneArtefactCount: 0,
    symmetryClass: 1, // hexagonal
    strandConfig: 1, // dyad
    hasAnomaly: false,
    signatureRotationDeg: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetRiveInputs &&
          stageIndex == other.stageIndex &&
          branchIndex == other.branchIndex &&
          moodIndex == other.moodIndex &&
          isAsleep == other.isAsleep &&
          isSick == other.isSick &&
          isCalling == other.isCalling &&
          vitality == other.vitality &&
          buoyancy == other.buoyancy &&
          auraIntensity == other.auraIntensity &&
          hygieneArtefactCount == other.hygieneArtefactCount &&
          symmetryClass == other.symmetryClass &&
          strandConfig == other.strandConfig &&
          hasAnomaly == other.hasAnomaly &&
          signatureRotationDeg == other.signatureRotationDeg;

  @override
  int get hashCode => Object.hash(
    stageIndex,
    branchIndex,
    moodIndex,
    isAsleep,
    isSick,
    isCalling,
    vitality,
    buoyancy,
    auraIntensity,
    hygieneArtefactCount,
    symmetryClass,
    strandConfig,
    hasAnomaly,
    signatureRotationDeg,
  );
}

/// Builds [PetRiveInputs] from authoritative pet state. Pure Dart — no
/// widget tree, no Rive runtime, no network. Fully testable.
class PetRiveAdapter {
  const PetRiveAdapter();

  PetRiveInputs buildInputs({
    required PetState state,
    required PetMood derivedMood,
    required PetConfig config,
  }) {
    final geometry = PetSigilGeometry.forIdentity(
      dnaSeed: state.dnaSeed,
      stage: state.stage,
      branch: state.branch,
    );
    final statMaxD = config.statMax.toDouble();
    final energyNorm = (state.energy / statMaxD).clamp(0.0, 1.0);
    final moodStatNorm = (state.mood / statMaxD).clamp(0.0, 1.0);
    final stabilityNorm = (state.stability / statMaxD).clamp(0.0, 1.0);
    final vitality = ((energyNorm + moodStatNorm + stabilityNorm) / 3.0).clamp(
      0.0,
      1.0,
    );

    // Buoyancy + aura-intensity reuse the same helpers the painter
    // uses so the Rive presentation stays numerically aligned with the
    // procedural one.
    final buoyancy = petBuoyancyScale(vitality);
    final auraIntensity = petAuraIntensityScale(stabilityNorm);

    // Normalise these into [0, 1] for Rive — the helpers return values
    // like 0.80..1.15 and 0.75..1.10; compress to a common axis.
    final buoyancyNorm = _inverseLerp(0.80, 1.15, buoyancy);
    final auraNorm = _inverseLerp(0.75, 1.10, auraIntensity);

    final helix = geometry.helix;
    final strandConfig = helix.enabled
        ? (helix.strandCount - 1).clamp(0, 2)
        : 1; // default dyad when no helix trait

    // Signature rotation in degrees (0..359) — same value the DNA
    // viewer surfaces.
    final signatureRotationDeg = (geometry.bodyRotation * 180 / 3.14159265)
        .round()
        .remainder(360);
    final signatureRotationDegPositive = signatureRotationDeg < 0
        ? signatureRotationDeg + 360
        : signatureRotationDeg;

    return PetRiveInputs(
      stageIndex: state.stage.index,
      branchIndex: state.branch.index,
      moodIndex: derivedMood.index,
      isAsleep: state.isAsleep,
      isSick: state.isSick,
      isCalling: state.activeCall != null,
      vitality: vitality,
      buoyancy: buoyancyNorm,
      auraIntensity: auraNorm,
      hygieneArtefactCount: state.hygieneArtefacts.length.clamp(0, 3),
      symmetryClass: _symmetryClassBucket(geometry.coreVertexCount),
      strandConfig: strandConfig,
      hasAnomaly: ((state.dnaSeed >> 2) & 0x01) == 1,
      signatureRotationDeg: signatureRotationDegPositive,
    );
  }

  /// Build inputs from the [PetRiveInputs.healthyAdultSteady] baseline
  /// — useful when only a [PetPublicState] summary is available (remote
  /// peer renders, companion card fallbacks).
  PetRiveInputs buildInputsFromPublicDefaults({
    required PetStage stage,
    required PetBranch branch,
    required PetMood mood,
    required bool isAsleep,
    required bool isSick,
    required bool isCalling,
    required int symmetryClass,
    required int strandConfig,
    required bool hasAnomaly,
  }) {
    return PetRiveInputs(
      stageIndex: stage.index,
      branchIndex: branch.index,
      moodIndex: mood.index,
      isAsleep: isAsleep,
      isSick: isSick,
      isCalling: isCalling,
      vitality: 1.0,
      buoyancy: 1.0,
      auraIntensity: 1.0,
      hygieneArtefactCount: 0,
      symmetryClass: symmetryClass,
      strandConfig: strandConfig,
      hasAnomaly: hasAnomaly,
      signatureRotationDeg: 0,
    );
  }
}

/// Maps `coreVertexCount` (5..8) to a small bucket the Rive file can
/// switch on without knowing the polygon count range.
int _symmetryClassBucket(int coreVertexCount) {
  switch (coreVertexCount) {
    case 5:
      return 0;
    case 6:
      return 1;
    case 7:
      return 2;
    case 8:
      return 3;
    default:
      return 1;
  }
}

/// Inverse lerp with clamping. Returns where [value] falls in [a, b]
/// normalised to [0, 1].
double _inverseLerp(double a, double b, double value) {
  if (b <= a) return 0.0;
  return ((value - a) / (b - a)).clamp(0.0, 1.0);
}
