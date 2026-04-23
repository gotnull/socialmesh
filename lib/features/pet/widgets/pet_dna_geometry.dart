// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetDnaGeometry — deterministic structural blueprint of a pet's dnaSeed,
// rendered in the dedicated DNA Viewer (NOT on the creature itself).
//
// The creature renderer expresses personality; the DNA Viewer is the
// genome artifact — legible, large, alien. They share the dnaSeed as
// source of truth but use different geometry models optimised for their
// respective readability goals.
//
// Everything here is pure + deterministic — same identity always
// produces the same blueprint. Lightweight to compute (no caching
// necessary at this scale).

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/pet_enums.dart';
import 'pet_render_model.dart' show PetSigilGeometry;

/// One vertical anchor position along the DNA spine. Strand A angle is
/// stored as an absolute radian; strand B sits at +π.
@immutable
class PetDnaAnchor {
  final double t; // normalized [0, 1] from top to bottom
  final double angleA; // radians
  final bool hasRung;
  final bool hasRuneMarker; // decorative side-glyph spawn
  const PetDnaAnchor({
    required this.t,
    required this.angleA,
    required this.hasRung,
    required this.hasRuneMarker,
  });
}

/// Seed-derived traits surfaced in the "Decoded" panel of the viewer.
/// Human-friendly names the UI can display directly.
@immutable
class PetDnaDecodedTraits {
  /// Core polygon vertex count → symmetry class label.
  final int symmetryVertexCount;

  /// Orbital complexity (petal count).
  final int orbitalComplexity;

  /// Resonance: number of full twist cycles. Higher = more kinetic.
  final int resonance;

  /// Strand configuration: 1 = monad, 2 = dyad, 3 = triad.
  final int strandCount;

  /// Number of discontinuous segments in the strand — volatility
  /// markers. 0 for stable branches.
  final int volatility;

  /// Whether a center-glyph anomaly bit is set in the seed.
  final bool anomaly;

  /// Body orientation offset in degrees [0, 360). Useful as a seed
  /// "signature rotation".
  final int signatureRotationDeg;

  const PetDnaDecodedTraits({
    required this.symmetryVertexCount,
    required this.orbitalComplexity,
    required this.resonance,
    required this.strandCount,
    required this.volatility,
    required this.anomaly,
    required this.signatureRotationDeg,
  });
}

/// Complete DNA Viewer geometry. Derived from the existing
/// [PetSigilGeometry] so the two stay in lockstep — what the viewer
/// visualises IS what the creature renderer consumes.
@immutable
class PetDnaGeometry {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;

  /// Anchors along the spine, ordered top → bottom. Length is the
  /// viewer's anchor count (distinct from the pet renderer's helix
  /// segment count).
  final List<PetDnaAnchor> anchors;

  /// Strand orbit radius as a fraction of canvas minSide. Viewer uses
  /// a roomier radius than the creature-renderer helix ever did.
  final double radiusFactor;

  /// Total vertical span as a fraction of canvas height.
  final double verticalSpanFactor;

  /// Integer twist count over the span — wrap-continuous.
  final int twistCycles;

  /// Strand count (1 / 2 / 3).
  final int strandCount;

  /// Core polygon vertex angles (same as PetSigilGeometry.coreAngles).
  /// Rendered as the "genome core" glyph at the DNA spine's centre.
  final List<double> coreGlyphAngles;

  /// Number of rune markers scattered down the spine at anchor points.
  final int runeMarkerCount;

  final PetDnaDecodedTraits decoded;

  const PetDnaGeometry._({
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.anchors,
    required this.radiusFactor,
    required this.verticalSpanFactor,
    required this.twistCycles,
    required this.strandCount,
    required this.coreGlyphAngles,
    required this.runeMarkerCount,
    required this.decoded,
  });

  /// Build the blueprint for the given identity. Pulls the precomputed
  /// [PetSigilGeometry] via the same cache the creature renderer uses,
  /// then derives viewer-specific anchor list on top.
  factory PetDnaGeometry.forIdentity({
    required int dnaSeed,
    required PetStage stage,
    required PetBranch branch,
  }) {
    final sigil = PetSigilGeometry.forIdentity(
      dnaSeed: dnaSeed,
      stage: stage,
      branch: branch,
    );
    return _build(dnaSeed: dnaSeed, stage: stage, branch: branch, sigil: sigil);
  }

  static PetDnaGeometry _build({
    required int dnaSeed,
    required PetStage stage,
    required PetBranch branch,
    required PetSigilGeometry sigil,
  }) {
    final helix = sigil.helix;

    // Anchor count — fixed at 18 for the viewer (denser than the
    // creature-renderer helix). Bounded + cheap.
    const anchorCount = 18;

    // Rune markers spawn at deterministic anchor positions from a
    // seed-derived bitmask — feels hand-placed but is stable.
    final runeMask = dnaSeed ^ (dnaSeed >> 11) ^ (dnaSeed << 3);
    var runeCount = 0;

    // Rung placement — 7 rungs evenly spaced (or scaled by presence
    // for stages that carry less structure).
    final rungCount = stage == PetStage.egg
        ? 0
        : stage == PetStage.juvenile
        ? 5
        : stage == PetStage.dormant
        ? 4
        : 7;

    // For triple and mono strand configurations, drop rungs (they
    // pair cleanly only on the common 2-strand form).
    final effectiveStrandCount = helix.enabled && helix.strandCount > 0
        ? helix.strandCount
        : 2;
    final effectiveRungCount = effectiveStrandCount == 2 ? rungCount : 0;

    // Radius — roomy. Body in viewer is ignored (nothing competes for
    // canvas space here), so we wrap 35..45 % of minSide.
    final radiusJitter = ((dnaSeed >> 5) & 0x1F) / 31.0;
    double radiusFactor;
    switch (branch) {
      case PetBranch.luminous:
        radiusFactor = 0.40 + 0.05 * radiusJitter;
        break;
      case PetBranch.steady:
        radiusFactor = 0.38 + 0.04 * radiusJitter;
        break;
      case PetBranch.volatile:
        radiusFactor = 0.36 + 0.08 * radiusJitter;
        break;
      case PetBranch.dimmed:
        radiusFactor = 0.34 + 0.04 * radiusJitter;
        break;
      case PetBranch.unborn:
        radiusFactor = 0.36;
        break;
    }

    // Vertical span for the viewer — tall, fills most of the canvas
    // because this IS the canvas's subject.
    final verticalSpanFactor = stage == PetStage.egg
        ? 0.60
        : stage == PetStage.juvenile
        ? 0.78
        : stage == PetStage.elder
        ? 0.92
        : stage == PetStage.dormant
        ? 0.65
        : 0.88;

    final twistCycles = helix.enabled && helix.twistCycles >= 1
        ? helix.twistCycles
        : 2;
    final baseAngle = helix.enabled
        ? helix.baseAngle
        : (((dnaSeed >> 19) & 0xFF) / 255.0) * math.pi * 2;

    // Build anchors.
    final anchors = <PetDnaAnchor>[];
    final rungStepEvery = effectiveRungCount == 0
        ? 9999
        : (anchorCount / effectiveRungCount).floor().clamp(1, anchorCount);
    for (var i = 0; i < anchorCount; i++) {
      final t = i / (anchorCount - 1);
      final angleA = baseAngle + t * twistCycles * math.pi * 2;
      final hasRung =
          effectiveRungCount > 0 &&
          i > 0 &&
          i < anchorCount - 1 &&
          (i % rungStepEvery == (rungStepEvery ~/ 2));
      final hasRuneMarker = (runeMask & (1 << (i % 30))) != 0 && i % 3 == 1;
      if (hasRuneMarker) runeCount += 1;
      anchors.add(
        PetDnaAnchor(
          t: t,
          angleA: angleA,
          hasRung: hasRung,
          hasRuneMarker: hasRuneMarker,
        ),
      );
    }

    // Decoded traits surfaced to the UI.
    final volatility = _popcount(helix.brokennessMask);
    final anomaly = ((dnaSeed >> 2) & 0x01) == 1;
    final signatureRotationDeg =
        (sigil.bodyRotation * 180 / math.pi).round() % 360;

    final decoded = PetDnaDecodedTraits(
      symmetryVertexCount: sigil.coreVertexCount,
      orbitalComplexity: sigil.petalCount,
      resonance: twistCycles,
      strandCount: effectiveStrandCount,
      volatility: volatility,
      anomaly: anomaly,
      signatureRotationDeg: signatureRotationDeg,
    );

    return PetDnaGeometry._(
      dnaSeed: dnaSeed,
      stage: stage,
      branch: branch,
      anchors: anchors,
      radiusFactor: radiusFactor,
      verticalSpanFactor: verticalSpanFactor,
      twistCycles: twistCycles,
      strandCount: effectiveStrandCount,
      coreGlyphAngles: List<double>.unmodifiable(sigil.coreAngles),
      runeMarkerCount: runeCount,
      decoded: decoded,
    );
  }

  /// Compact hash suitable for shouldRepaint short-circuits.
  int get renderKey => Object.hash(dnaSeed, stage.index, branch.index);
}

int _popcount(int v) {
  var x = v;
  var c = 0;
  while (x != 0) {
    c += x & 1;
    x >>= 1;
  }
  return c;
}

/// Human-friendly label for a symmetry class derived from core vertex
/// count. Exposed for the UI's decoded-trait panel.
String petDnaSymmetryClassLabel(int vertexCount) {
  switch (vertexCount) {
    case 5:
      return 'Pentagonal';
    case 6:
      return 'Hexagonal';
    case 7:
      return 'Heptagonal';
    case 8:
      return 'Octagonal';
    default:
      return vertexCount.toString();
  }
}

/// Strand-configuration label.
String petDnaStrandConfigLabel(int strandCount) {
  switch (strandCount) {
    case 1:
      return 'Monad';
    case 2:
      return 'Dyad';
    case 3:
      return 'Triad';
    default:
      return strandCount.toString();
  }
}
