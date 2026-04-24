// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodePet creature renderer — a thin presentational wrapper over the
// shared [MeshNodeBrain] (the icosahedron mesh creature used by the
// onboarding advisor). This was previously a bespoke 2.5D painter with
// hexagonal body + petal orbit; we now reuse the mesh creature system
// so NodePet inherits the full mood library, expressive face, ghost-
// personality deformation, and effect catalogue for free.
//
// Per-pet uniqueness is derived from the DNA seed via a Murmur3-style
// bit mixer, projected into an HSL triad. Stage and branch modulate
// size, glow intensity, line thickness, node size, and face opacity.
// Pet flags (asleep/sick/calling) and [PetMood] collapse into a single
// [MeshBrainMood] that drives all animation and expression.
//
// The file path and public API are preserved: call sites construct
// [PetCreature] with the same constructor, and [PetRenderMode] is
// re-exported from pet_render_model.dart.

import 'package:flutter/material.dart';

import '../../onboarding/widgets/mesh_node_brain.dart';
import '../models/pet_enums.dart';
import 'pet_render_model.dart';

export 'pet_render_model.dart' show PetRenderMode;

/// Renders the NodePet creature at a given size, driven entirely by
/// pet state. Stateless: all animation lives in [MeshNodeBrain].
class PetCreature extends StatelessWidget {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;

  /// Still in the public API so care-action wiring doesn't break, but
  /// the creature doesn't render hygiene splats on the body anymore —
  /// the status banner above the pet communicates "needs Clean" via
  /// text + pulsing button instead of ambient visual noise.
  final int hygieneArtefactCount;

  final double size;

  /// Renderer profile — scales which depth layers, flourishes, and
  /// interactive features are enabled. home = full, card = compact,
  /// tiny = face-less dot for NodeDex row previews.
  final PetRenderMode mode;

  /// Optional raw stat values (0..[statMax]) — subtle modulation of
  /// glow intensity within each mood bucket. When null, full vitality
  /// is assumed (used for mini previews built from PetPublicState
  /// which only carries the derived mood class).
  final int? energy;
  final int? moodStat;
  final int? stability;
  final int statMax;

  /// Optional tap callback — forwarded to the underlying MeshNodeBrain.
  final VoidCallback? onTap;

  /// Pin the face forward so NodePet reads as a creature looking at
  /// the user rather than a tumbling icosahedron. Default true —
  /// overridable so the debug scrubber can show the tumble.
  final bool preferFrontFace;

  const PetCreature({
    super.key,
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.mood,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.hygieneArtefactCount,
    this.size = 220,
    this.mode = PetRenderMode.home,
    this.energy,
    this.moodStat,
    this.stability,
    this.statMax = 10,
    this.onTap,
    this.preferFrontFace = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = paletteFromDnaSeed(dnaSeed, branch);
    final brainMood = mapPetMood(
      mood: mood,
      stage: stage,
      isAsleep: isAsleep,
      isSick: isSick,
      isCalling: isCalling,
    );
    final stageScale = _stageScale(stage);
    final vitality = _vitality(energy, moodStat, stability, statMax);
    final isEgg = stage == PetStage.egg;
    final isDormant = stage == PetStage.dormant;

    return MeshNodeBrain(
      size: size * stageScale,
      mood: brainMood,
      colors: palette,
      glowIntensity: _glowIntensity(stage, branch, vitality),
      lineThickness: _lineThickness(stage, branch),
      nodeSize: _nodeSize(stage),
      interactive: !isAsleep && !isEgg && !isDormant,
      onTap: onTap,
      showThoughtParticles: _showThoughtParticles(
        mode,
        stage,
        isAsleep,
        isSick,
      ),
      showExpression: !isEgg && !isDormant && mode != PetRenderMode.tiny,
      showFaces: !isEgg && mode == PetRenderMode.home,
      faceOpacity: _faceOpacity(stage, branch, mode),
      sciFiGlitch: isSick,
      // Keep the pet feeling alive between mood changes — only on the
      // home hero, where the creature is large enough for a blink to
      // register. Tiny NodeDex previews and card-mode companions stay
      // quiet (per-instance timer overhead × N node rows would add up).
      enableIdleBlink: mode == PetRenderMode.home,
      preferFrontFace: preferFrontFace,
    );
  }
}

/// Murmur3 fmix32 finalizer — scrambles bits so adjacent DNA seeds
/// produce visibly different palettes. The constants are the standard
/// Murmur3 mix constants.
int _murmurFinalize(int seed) {
  int x = seed & 0xFFFFFFFF;
  x ^= (x >>> 16);
  x = (x * 0x85ebca6b) & 0xFFFFFFFF;
  x ^= (x >>> 13);
  x = (x * 0xc2b2ae35) & 0xFFFFFFFF;
  x ^= (x >>> 16);
  return x & 0xFFFFFFFF;
}

/// Derives a 3-colour palette (primary / secondary / accent) from the
/// pet's DNA seed, with branch-driven saturation and lightness tuning.
///
/// Deterministic: identical (seed, branch) always produces identical
/// colours. Public for test visibility.
@visibleForTesting
List<Color> paletteFromDnaSeed(int dnaSeed, PetBranch branch) {
  final mixed = _murmurFinalize(dnaSeed);
  final baseHue = (mixed & 0xFFFF) / 0xFFFF * 360.0;
  final (sat, light) = switch (branch) {
    PetBranch.luminous => (0.82, 0.62),
    PetBranch.steady => (0.72, 0.55),
    PetBranch.volatile => (0.88, 0.50),
    PetBranch.dimmed => (0.45, 0.42),
    PetBranch.unborn => (0.55, 0.48),
  };
  return [
    HSLColor.fromAHSL(1.0, baseHue, sat, light).toColor(),
    HSLColor.fromAHSL(
      1.0,
      (baseHue + 36) % 360,
      sat * 0.95,
      (light - 0.05).clamp(0.0, 1.0),
    ).toColor(),
    HSLColor.fromAHSL(
      1.0,
      (baseHue + 200) % 360,
      sat * 0.85,
      (light - 0.08).clamp(0.0, 1.0),
    ).toColor(),
  ];
}

/// Collapses a pet's mood + state flags into a single [MeshBrainMood].
///
/// Priority order (highest first): egg → dormant → asleep → sick →
/// calling → PetMood. Public for test visibility.
@visibleForTesting
MeshBrainMood mapPetMood({
  required PetMood mood,
  required PetStage stage,
  required bool isAsleep,
  required bool isSick,
  required bool isCalling,
}) {
  if (stage == PetStage.egg) return MeshBrainMood.dormant;
  if (stage == PetStage.dormant) return MeshBrainMood.dormant;
  if (isAsleep) return MeshBrainMood.dormant;
  if (isSick) return MeshBrainMood.glitching;
  if (isCalling) return MeshBrainMood.alert;
  return switch (mood) {
    PetMood.content => MeshBrainMood.happy,
    PetMood.hungry => MeshBrainMood.hopeful,
    PetMood.sad => MeshBrainMood.sad,
    PetMood.sick => MeshBrainMood.glitching,
    PetMood.sleeping => MeshBrainMood.dormant,
    PetMood.calling => MeshBrainMood.alert,
  };
}

double _stageScale(PetStage stage) => switch (stage) {
  PetStage.egg => 0.55,
  PetStage.juvenile => 0.72,
  PetStage.adolescent => 0.85,
  PetStage.adult => 1.0,
  PetStage.elder => 1.0,
  PetStage.dormant => 0.78,
};

double _glowIntensity(PetStage stage, PetBranch branch, double vitality) {
  final stageBase = switch (stage) {
    PetStage.egg => 0.45,
    PetStage.juvenile => 0.70,
    PetStage.adolescent => 0.85,
    PetStage.adult => 1.00,
    PetStage.elder => 0.90,
    PetStage.dormant => 0.35,
  };
  final branchMult = switch (branch) {
    PetBranch.luminous => 1.15,
    PetBranch.steady => 1.00,
    PetBranch.volatile => 1.10,
    PetBranch.dimmed => 0.75,
    PetBranch.unborn => 0.90,
  };
  // Vitality (0..1) nudges glow by ±15%.
  return (stageBase * branchMult * (0.85 + 0.3 * vitality)).clamp(0.2, 1.5);
}

double _lineThickness(PetStage stage, PetBranch branch) {
  final stageBase = switch (stage) {
    PetStage.egg => 0.45,
    PetStage.juvenile => 0.55,
    PetStage.adolescent => 0.65,
    PetStage.adult => 0.75,
    PetStage.elder => 0.70,
    PetStage.dormant => 0.50,
  };
  final branchAdd = switch (branch) {
    PetBranch.luminous => 0.05,
    PetBranch.steady => 0.0,
    PetBranch.volatile => 0.10,
    PetBranch.dimmed => -0.10,
    PetBranch.unborn => 0.0,
  };
  return (stageBase + branchAdd).clamp(0.2, 1.2);
}

double _nodeSize(PetStage stage) => switch (stage) {
  PetStage.egg => 0.70,
  PetStage.juvenile => 0.80,
  PetStage.adolescent => 0.90,
  PetStage.adult => 0.95,
  PetStage.elder => 0.85,
  PetStage.dormant => 0.70,
};

double _faceOpacity(PetStage stage, PetBranch branch, PetRenderMode mode) {
  if (mode == PetRenderMode.tiny) return 0.0;
  if (stage == PetStage.egg || stage == PetStage.dormant) return 0.0;
  return switch (branch) {
    PetBranch.luminous => 0.18,
    PetBranch.steady => 0.12,
    PetBranch.volatile => 0.22,
    PetBranch.dimmed => 0.08,
    PetBranch.unborn => 0.10,
  };
}

bool _showThoughtParticles(
  PetRenderMode mode,
  PetStage stage,
  bool isAsleep,
  bool isSick,
) {
  if (mode == PetRenderMode.tiny) return false;
  if (isAsleep) return false;
  if (isSick) return true;
  return stage != PetStage.egg && stage != PetStage.dormant;
}

double _vitality(int? energy, int? moodStat, int? stability, int statMax) {
  if (statMax <= 0) return 1.0;
  if (energy == null && moodStat == null && stability == null) return 1.0;
  final sum =
      (energy ?? statMax) + (moodStat ?? statMax) + (stability ?? statMax);
  return (sum / (statMax * 3.0)).clamp(0.0, 1.0);
}
