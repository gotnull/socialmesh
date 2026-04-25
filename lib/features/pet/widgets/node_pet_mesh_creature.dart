// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodePet 3D mesh creature renderer — pet-owned fork of the
// icosahedron-mesh visual foundation that powers Ico (advisor).
//
// This file deliberately CLONES the icosahedron geometry, projection,
// and depth-sorted face/edge/node painting from
// `lib/core/widgets/animated_mesh_node.dart` rather than importing it.
// The Ico advisor system must stay untouched; NodePet must look like a
// creature, not like Ico-recoloured. By owning its own copy of the
// math, NodePet can:
//
//   • deform each vertex per-seed so the silhouette becomes irregular
//     (Ico is always a perfect icosahedron)
//   • clamp tumble to a small Y-arc so the creature never turns its
//     back (Ico can full-spin)
//   • lock the face to screen-space instead of riding mesh nodes
//   • extrude antennae from upper vertices in 3D
//   • draw an internal sigil graph through the mesh
//   • compose pet-mood expression / posture / glow profiles
//
// What it inherits from the Ico foundation:
//   • 3D mesh presence (nodes + edges + optional faces)
//   • depth sorting → real layered look
//   • perspective projection → real depth, not fake 2.5D
//   • squash-stretch + breathing math
//
// What it adds on top:
//   • Seed-derived per-vertex radial deformation
//   • Front-facing "head vertex" used as the anchor for a screen-locked
//     face overlay (eyes + mouth)
//   • Eye tracking via Lissajous look-target wandering
//   • Natural variable-cadence blink scheduling
//   • Seed-derived antennae as 3D-extruded line segments + orb tips
//   • Seed-derived internal sigil graph (non-adjacent vertex pairs)
//   • Mood / branch / stage profile system

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pet_enums.dart';
import 'pet_render_model.dart' show PetRenderMode;

// ---------------------------------------------------------------------------
// 3D math (forked from animated_mesh_node.dart — kept pet-private)
// ---------------------------------------------------------------------------

@immutable
class _P3 {
  final double x;
  final double y;
  final double z;
  const _P3(this.x, this.y, this.z);

  _P3 rotateY(double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return _P3(x * c + z * s, y, -x * s + z * c);
  }

  _P3 rotateX(double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return _P3(x, y * c - z * s, y * s + z * c);
  }

  _P3 rotateZ(double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return _P3(x * c - y * s, x * s + y * c, z);
  }

  _P3 scaled(double sx, double sy, double sz) => _P3(x * sx, y * sy, z * sz);

  _P3 translate(double dx, double dy, double dz) => _P3(x + dx, y + dy, z + dz);

  Offset project(double size, double perspective, Offset center) {
    final scale = perspective / (perspective + z);
    return Offset(
      x * scale * size / 2 + center.dx,
      y * scale * size / 2 + center.dy,
    );
  }

  /// Returns the projection scale factor (1.0 = at z=0, larger = closer).
  double projectionScale(double perspective) => perspective / (perspective + z);
}

/// Murmur3 fmix32 finalizer. Same constants as
/// `paletteFromDnaSeed` so morphology + palette are bit-coherent.
int _mix(int seed) {
  int x = seed & 0xFFFFFFFF;
  x ^= (x >>> 16);
  x = (x * 0x85ebca6b) & 0xFFFFFFFF;
  x ^= (x >>> 13);
  x = (x * 0xc2b2ae35) & 0xFFFFFFFF;
  x ^= (x >>> 16);
  return x & 0xFFFFFFFF;
}

// ---------------------------------------------------------------------------
// Icosahedron geometry (forked from animated_mesh_node.dart — kept pet-private)
// ---------------------------------------------------------------------------

final double _phi = (1 + math.sqrt(5)) / 2;

/// Base 12-vertex icosahedron, normalised to a unit sphere then scaled.
/// Per-pet morphology stretches each vertex radially from this base.
final List<_P3> _baseVertices = (() {
  const scale = 0.42;
  final raw = <_P3>[
    _P3(-1, _phi, 0),
    _P3(1, _phi, 0),
    _P3(-1, -_phi, 0),
    _P3(1, -_phi, 0),
    _P3(0, -1, _phi),
    _P3(0, 1, _phi),
    _P3(0, -1, -_phi),
    _P3(0, 1, -_phi),
    _P3(_phi, 0, -1),
    _P3(_phi, 0, 1),
    _P3(-_phi, 0, -1),
    _P3(-_phi, 0, 1),
  ];
  return raw
      .map((v) {
        final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
        return _P3(v.x / len * scale, v.y / len * scale, v.z / len * scale);
      })
      .toList(growable: false);
})();

/// Icosahedron edge list — 30 edges, each vertex connects to 5 others.
const List<List<int>> _edges = [
  [0, 1],
  [0, 5],
  [0, 7],
  [0, 10],
  [0, 11],
  [1, 5],
  [1, 7],
  [1, 8],
  [1, 9],
  [5, 9],
  [5, 4],
  [5, 11],
  [9, 4],
  [9, 3],
  [9, 8],
  [4, 3],
  [4, 2],
  [4, 11],
  [3, 2],
  [3, 6],
  [3, 8],
  [2, 6],
  [2, 10],
  [2, 11],
  [6, 7],
  [6, 8],
  [6, 10],
  [7, 8],
  [7, 10],
  [10, 11],
];

/// Icosahedron triangular faces — 20 faces.
const List<List<int>> _faces = [
  [0, 1, 5],
  [0, 1, 7],
  [0, 5, 11],
  [0, 7, 10],
  [0, 10, 11],
  [1, 5, 9],
  [1, 7, 8],
  [1, 8, 9],
  [2, 3, 4],
  [2, 3, 6],
  [2, 4, 11],
  [2, 6, 10],
  [2, 10, 11],
  [3, 4, 9],
  [3, 6, 8],
  [3, 8, 9],
  [4, 5, 9],
  [4, 5, 11],
  [6, 7, 8],
  [6, 7, 10],
];

/// Front-facing upper vertex used as the anchor for the stable face
/// overlay. Vertex 5 is `(0, 1, _phi)` — top-front in the base
/// orientation. Face stays anchored to its projected position so the
/// creature reads as looking at the user.
const int _faceVertexIndex = 5;

/// Upper vertices used as antenna roots — sorted top-to-bottom in the
/// base orientation. Antennae extrude from one or more of these.
const List<int> _antennaRootVertices = [5, 1, 0, 11];

// ---------------------------------------------------------------------------
// Morphology — pure value object derived from (dnaSeed, branch, stage)
// ---------------------------------------------------------------------------

enum NodePetAntennaStyle { none, straight, curled, branched }

@immutable
class NodePetAntenna {
  /// Index into [_antennaRootVertices].
  final int rootIndex;

  /// Length factor relative to base mesh radius.
  final double length;

  /// Outward angular splay.
  final double splayAngle;

  final NodePetAntennaStyle style;

  /// Per-antenna sway phase offset (0..2π) so antennae move
  /// independently — never robotic-synchronous.
  final double swayPhase;

  const NodePetAntenna({
    required this.rootIndex,
    required this.length,
    required this.splayAngle,
    required this.style,
    required this.swayPhase,
  });
}

@immutable
class NodePetMorphology {
  /// Per-vertex radial scale multipliers (0.78..1.30). Length 12.
  /// Drives the seed-irregular silhouette — the foundation of "this
  /// pet does not look like any other pet".
  final List<double> vertexRadii;

  /// Lopsidedness factor — additional X-axis scale on the right
  /// hemisphere only (left side keeps 1.0). 0.88..1.18. Guarantees
  /// asymmetry that no mascot has.
  final double lopsidedness;

  /// Y-stretch factor for upper vertices (head extension).
  final double headStretch;

  /// Antennae list. Empty for egg / unborn.
  final List<NodePetAntenna> antennae;

  /// Internal sigil edge list — non-adjacent vertex index pairs that
  /// the painter draws as faint inner lines. THE socialmesh-native
  /// differentiator — internal graph visible through the mesh body.
  final List<(int, int)> sigilEdges;

  /// Eye spacing as a fraction of the projected head circle radius.
  final double eyeSpacing;

  /// Eye radius as a fraction of the projected head circle radius.
  final double eyeRadius;

  /// Pupil shape variant.
  final NodePetPupilShape pupilShape;

  /// Mouth Y offset as a fraction of the projected head circle radius
  /// (positive = below head centre).
  final double mouthYFactor;

  /// Mouth width as a fraction of the projected head circle radius.
  final double mouthWidth;

  const NodePetMorphology({
    required this.vertexRadii,
    required this.lopsidedness,
    required this.headStretch,
    required this.antennae,
    required this.sigilEdges,
    required this.eyeSpacing,
    required this.eyeRadius,
    required this.pupilShape,
    required this.mouthYFactor,
    required this.mouthWidth,
  });

  factory NodePetMorphology.from({
    required int dnaSeed,
    required PetBranch branch,
    required PetStage stage,
  }) {
    final m = _mix(dnaSeed);
    final m2 = _mix(dnaSeed ^ 0x9E3779B1);

    // Per-vertex radial scales. Branch sets the noise band.
    final (lo, hi) = switch (branch) {
      PetBranch.luminous => (0.95, 1.25),
      PetBranch.steady => (0.92, 1.10),
      PetBranch.volatile => (0.78, 1.30),
      PetBranch.dimmed => (0.85, 1.05),
      PetBranch.unborn => (0.90, 1.10),
    };
    final radii = <double>[];
    for (var i = 0; i < 12; i++) {
      final bits = ((m >>> (i % 16)) ^ (m2 >>> ((i + 5) % 16))) & 0xFF;
      final t = bits / 255.0;
      radii.add(lo + (hi - lo) * t);
    }

    // Egg + dormant collapse vertices toward the centre.
    if (stage == PetStage.egg) {
      for (var i = 0; i < radii.length; i++) {
        radii[i] *= 0.55;
      }
    } else if (stage == PetStage.dormant) {
      for (var i = 0; i < radii.length; i++) {
        radii[i] *= 0.78;
      }
    } else if (stage == PetStage.juvenile) {
      for (var i = 0; i < radii.length; i++) {
        radii[i] *= 0.85;
      }
    }

    // Lopsidedness — right hemisphere bias only.
    final lopJitter = ((m >>> 11) & 0x1F) / 31.0;
    final lopsidedness = 0.88 + 0.30 * lopJitter;

    // Head stretch (upper vertices Y-elongation).
    final headJitter = ((m >>> 17) & 0x0F) / 15.0;
    final headStretch = 1.05 + 0.25 * headJitter;

    // Antennae — egg / unborn / dormant get none.
    final antennae = <NodePetAntenna>[];
    if (stage != PetStage.egg &&
        stage != PetStage.dormant &&
        branch != PetBranch.unborn) {
      final styleRoll = (m >>> 19) & 0x07;
      final style = switch (styleRoll) {
        0 || 1 => NodePetAntennaStyle.none,
        2 || 3 => NodePetAntennaStyle.straight,
        4 || 5 => NodePetAntennaStyle.curled,
        _ => NodePetAntennaStyle.branched,
      };
      if (style != NodePetAntennaStyle.none) {
        final countRoll = (m >>> 22) & 0x0F;
        // 1 antenna common, 2 most common, 3 rare (volatile only).
        int count;
        if (branch == PetBranch.volatile && countRoll == 0) {
          count = 3;
        } else if (countRoll < 6) {
          count = 1;
        } else {
          count = 2;
        }
        // Juvenile: cap at 1.
        if (stage == PetStage.juvenile && count > 1) count = 1;

        // Distribute antennae across upper vertices. Use seed bits to
        // pick distinct root indices (no two antennae share a root).
        final usedRoots = <int>{};
        for (var i = 0; i < count; i++) {
          int root;
          for (var attempt = 0; attempt < 6; attempt++) {
            final r =
                ((m >>> (i * 4 + attempt)) & 0x03) %
                _antennaRootVertices.length;
            if (!usedRoots.contains(r)) {
              root = r;
              usedRoots.add(r);
              break;
            }
            root = (i + attempt) % _antennaRootVertices.length;
            if (!usedRoots.contains(root)) {
              usedRoots.add(root);
              break;
            }
          }
          root = usedRoots.last;
          final lengthBits = ((m2 >>> (i * 5)) & 0x1F) / 31.0;
          final length = 0.55 + 0.55 * lengthBits;
          final splayBits = ((m2 >>> (i * 5 + 7)) & 0x1F) / 31.0;
          final splayAngle = (splayBits - 0.5) * 0.7;
          final swayPhase =
              ((m2 >>> (i * 3 + 13)) & 0xFF) / 255.0 * math.pi * 2;
          antennae.add(
            NodePetAntenna(
              rootIndex: root,
              length: length,
              splayAngle: splayAngle,
              style: style,
              swayPhase: swayPhase,
            ),
          );
        }
      }
    }

    // Internal sigil edges. Pick 2..4 non-adjacent vertex pairs from a
    // seed-shuffled candidate list.
    final sigilEdges = <(int, int)>[];
    if (stage != PetStage.egg && branch != PetBranch.unborn) {
      // Candidate pool: pairs that are NOT in the icosahedron edge
      // list (i.e. the pair is "internal" — a chord across the mesh).
      final adjacentSet = <int>{};
      for (final e in _edges) {
        adjacentSet.add(e[0] * 12 + e[1]);
        adjacentSet.add(e[1] * 12 + e[0]);
      }
      final candidates = <(int, int)>[];
      for (var a = 0; a < 12; a++) {
        for (var b = a + 1; b < 12; b++) {
          if (adjacentSet.contains(a * 12 + b)) continue;
          candidates.add((a, b));
        }
      }
      // Seed-shuffle: pick top-N by hashed score.
      final scored = candidates.map((p) {
        final score = _mix(dnaSeed ^ (p.$1 * 31 + p.$2 * 17));
        return (p, score);
      }).toList()..sort((a, b) => a.$2.compareTo(b.$2));
      final countRoll = (m >>> 25) & 0x07;
      final n = 2 + (countRoll % 3); // 2..4
      for (var i = 0; i < n && i < scored.length; i++) {
        sigilEdges.add(scored[i].$1);
      }
    }

    // Face proportions.
    final eyeSpacingJitter = ((m2 >>> 3) & 0x0F) / 15.0;
    final eyeSpacing = (0.36 + 0.18 * eyeSpacingJitter).clamp(0.36, 0.54);
    final eyeRadiusJitter = ((m2 >>> 11) & 0x0F) / 15.0;
    final eyeRadius = (0.16 + 0.08 * eyeRadiusJitter).clamp(0.16, 0.24);

    final pupilRoll = (m2 >>> 18) & 0x07;
    final pupilShape = switch (pupilRoll) {
      0 || 1 || 2 || 3 => NodePetPupilShape.round,
      4 => NodePetPupilShape.verticalSlit,
      5 => NodePetPupilShape.horizontalBar,
      _ => NodePetPupilShape.diamond,
    };

    final mouthYJitter = ((m2 >>> 22) & 0x0F) / 15.0;
    final mouthYFactor = (0.42 + 0.18 * mouthYJitter).clamp(0.42, 0.60);
    final mouthWidthJitter = ((m2 >>> 27) & 0x0F) / 15.0;
    final mouthWidth = (0.34 + 0.20 * mouthWidthJitter).clamp(0.34, 0.54);

    return NodePetMorphology(
      vertexRadii: List.unmodifiable(radii),
      lopsidedness: lopsidedness,
      headStretch: headStretch,
      antennae: List.unmodifiable(antennae),
      sigilEdges: List.unmodifiable(sigilEdges),
      eyeSpacing: eyeSpacing,
      eyeRadius: eyeRadius,
      pupilShape: pupilShape,
      mouthYFactor: mouthYFactor,
      mouthWidth: mouthWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NodePetMorphology &&
          _listEq(vertexRadii, other.vertexRadii) &&
          lopsidedness == other.lopsidedness &&
          headStretch == other.headStretch &&
          antennae.length == other.antennae.length &&
          sigilEdges.length == other.sigilEdges.length &&
          eyeSpacing == other.eyeSpacing &&
          eyeRadius == other.eyeRadius &&
          pupilShape == other.pupilShape &&
          mouthYFactor == other.mouthYFactor &&
          mouthWidth == other.mouthWidth);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(vertexRadii),
    lopsidedness,
    headStretch,
    antennae.length,
    sigilEdges.length,
    eyeSpacing,
    eyeRadius,
    pupilShape,
    mouthYFactor,
    mouthWidth,
  );

  static bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum NodePetPupilShape { round, verticalSlit, horizontalBar, diamond }

// ---------------------------------------------------------------------------
// Expression — pure value object derived from (mood + flags + stage)
// ---------------------------------------------------------------------------

enum NodePetEyeShape { open, halfClosed, closedSleeping, wideAlert, sickAsymm }

enum NodePetMouthShape {
  smile,
  smallSmile,
  neutral,
  frown,
  smallO,
  flat,
  sickWobble,
}

enum NodePetAuraStyle { none, calm, alertPulse, sickGlitch, sleeping, dormant }

@immutable
class NodePetExpression {
  final NodePetEyeShape eyes;
  final NodePetMouthShape mouth;
  final NodePetAuraStyle aura;

  /// Body Y translation as fraction of mesh radius. Negative = lifted.
  final double postureY;

  /// Body forward lean (Z-translation). Positive = closer to camera.
  final double leanZ;

  /// Multiplier on idle breath amplitude.
  final double breathScale;

  /// Multiplier on idle bounce amplitude.
  final double bounceScale;

  /// Edge electricity intensity for sick state.
  final double edgeElectricity;

  /// Whether to schedule natural blinking.
  final bool blinks;

  /// Whether the face overlay is hidden (egg / dormant).
  final bool faceHidden;

  /// Whether the body is fully scale-up alert (calling).
  final bool alertScaleUp;

  const NodePetExpression({
    required this.eyes,
    required this.mouth,
    required this.aura,
    required this.postureY,
    required this.leanZ,
    required this.breathScale,
    required this.bounceScale,
    required this.edgeElectricity,
    required this.blinks,
    required this.faceHidden,
    required this.alertScaleUp,
  });

  factory NodePetExpression.from({
    required PetMood mood,
    required PetStage stage,
    required PetBranch branch,
    required bool isAsleep,
    required bool isSick,
    required bool isCalling,
  }) {
    if (stage == PetStage.egg) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.closedSleeping,
        mouth: NodePetMouthShape.flat,
        aura: NodePetAuraStyle.dormant,
        postureY: 0,
        leanZ: 0,
        breathScale: 1.0,
        bounceScale: 0.0,
        edgeElectricity: 0.0,
        blinks: false,
        faceHidden: true,
        alertScaleUp: false,
      );
    }
    if (stage == PetStage.dormant) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.closedSleeping,
        mouth: NodePetMouthShape.flat,
        aura: NodePetAuraStyle.dormant,
        postureY: 0.05,
        leanZ: 0,
        breathScale: 0.4,
        bounceScale: 0.0,
        edgeElectricity: 0.0,
        blinks: false,
        faceHidden: true,
        alertScaleUp: false,
      );
    }
    if (isAsleep) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.closedSleeping,
        mouth: NodePetMouthShape.smallSmile,
        aura: NodePetAuraStyle.sleeping,
        postureY: 0.04,
        leanZ: 0,
        breathScale: 0.55,
        bounceScale: 0.25,
        edgeElectricity: 0.0,
        blinks: false,
        faceHidden: false,
        alertScaleUp: false,
      );
    }
    if (isSick) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.sickAsymm,
        mouth: NodePetMouthShape.sickWobble,
        aura: NodePetAuraStyle.sickGlitch,
        postureY: 0.06,
        leanZ: -0.05,
        breathScale: 0.7,
        bounceScale: 0.5,
        edgeElectricity: 0.85,
        blinks: true,
        faceHidden: false,
        alertScaleUp: false,
      );
    }
    if (isCalling) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.wideAlert,
        mouth: NodePetMouthShape.smallO,
        aura: NodePetAuraStyle.alertPulse,
        postureY: -0.05,
        leanZ: 0.18,
        breathScale: 1.4,
        bounceScale: 1.6,
        edgeElectricity: 0.0,
        blinks: true,
        faceHidden: false,
        alertScaleUp: true,
      );
    }
    switch (mood) {
      case PetMood.content:
        return const NodePetExpression(
          eyes: NodePetEyeShape.open,
          mouth: NodePetMouthShape.smile,
          aura: NodePetAuraStyle.calm,
          postureY: 0,
          leanZ: 0,
          breathScale: 1.0,
          bounceScale: 1.0,
          edgeElectricity: 0.0,
          blinks: true,
          faceHidden: false,
          alertScaleUp: false,
        );
      case PetMood.hungry:
        return const NodePetExpression(
          eyes: NodePetEyeShape.halfClosed,
          mouth: NodePetMouthShape.smallO,
          aura: NodePetAuraStyle.calm,
          postureY: 0.03,
          leanZ: 0,
          breathScale: 0.85,
          bounceScale: 0.55,
          edgeElectricity: 0.0,
          blinks: true,
          faceHidden: false,
          alertScaleUp: false,
        );
      case PetMood.sad:
        return const NodePetExpression(
          eyes: NodePetEyeShape.halfClosed,
          mouth: NodePetMouthShape.frown,
          aura: NodePetAuraStyle.calm,
          postureY: 0.07,
          leanZ: -0.04,
          breathScale: 0.7,
          bounceScale: 0.35,
          edgeElectricity: 0.0,
          blinks: true,
          faceHidden: false,
          alertScaleUp: false,
        );
      case PetMood.sick:
        return const NodePetExpression(
          eyes: NodePetEyeShape.sickAsymm,
          mouth: NodePetMouthShape.sickWobble,
          aura: NodePetAuraStyle.sickGlitch,
          postureY: 0.06,
          leanZ: -0.05,
          breathScale: 0.7,
          bounceScale: 0.5,
          edgeElectricity: 0.85,
          blinks: true,
          faceHidden: false,
          alertScaleUp: false,
        );
      case PetMood.sleeping:
        return const NodePetExpression(
          eyes: NodePetEyeShape.closedSleeping,
          mouth: NodePetMouthShape.smallSmile,
          aura: NodePetAuraStyle.sleeping,
          postureY: 0.04,
          leanZ: 0,
          breathScale: 0.55,
          bounceScale: 0.25,
          edgeElectricity: 0.0,
          blinks: false,
          faceHidden: false,
          alertScaleUp: false,
        );
      case PetMood.calling:
        return const NodePetExpression(
          eyes: NodePetEyeShape.wideAlert,
          mouth: NodePetMouthShape.smallO,
          aura: NodePetAuraStyle.alertPulse,
          postureY: -0.05,
          leanZ: 0.18,
          breathScale: 1.4,
          bounceScale: 1.6,
          edgeElectricity: 0.0,
          blinks: true,
          faceHidden: false,
          alertScaleUp: true,
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NodePetExpression &&
          eyes == other.eyes &&
          mouth == other.mouth &&
          aura == other.aura &&
          postureY == other.postureY &&
          leanZ == other.leanZ &&
          breathScale == other.breathScale &&
          bounceScale == other.bounceScale &&
          edgeElectricity == other.edgeElectricity &&
          blinks == other.blinks &&
          faceHidden == other.faceHidden &&
          alertScaleUp == other.alertScaleUp);

  @override
  int get hashCode => Object.hash(
    eyes,
    mouth,
    aura,
    postureY,
    leanZ,
    breathScale,
    bounceScale,
    edgeElectricity,
    blinks,
    faceHidden,
    alertScaleUp,
  );
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class NodePetMeshCreature extends StatefulWidget {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final double size;
  final PetRenderMode mode;

  /// Three-colour palette derived from dnaSeed + branch.
  final List<Color> palette;

  /// Vitality scalar in [0,1].
  final double vitality;

  /// Optional tap callback.
  final VoidCallback? onTap;

  const NodePetMeshCreature({
    super.key,
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.mood,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.size,
    required this.palette,
    this.mode = PetRenderMode.home,
    this.vitality = 1.0,
    this.onTap,
  });

  @override
  State<NodePetMeshCreature> createState() => _NodePetMeshCreatureState();
}

class _NodePetMeshCreatureState extends State<NodePetMeshCreature>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;
  final _Random _rng = _Random();

  // Blink state.
  double _nextBlinkPhase = 0.18;
  bool _blinking = false;
  double _blinkStart = 0.0;
  bool _doubleBlinkPending = false;

  // Eye-tracking: target offset wanders via a Lissajous-style sum.
  double _lookX = 0;
  double _lookY = 0;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _phase.addListener(_tick);
    _rng.seed(widget.dnaSeed ^ 0xA5A5A5A5);
  }

  @override
  void didUpdateWidget(covariant NodePetMeshCreature old) {
    super.didUpdateWidget(old);
    if (old.dnaSeed != widget.dnaSeed) {
      _rng.seed(widget.dnaSeed ^ 0xA5A5A5A5);
    }
  }

  void _tick() {
    if (!mounted) return;
    final p = _phase.value;

    // Blink scheduling.
    if (_blinking) {
      // Blink lasts ~150ms on an 8s loop ≈ 0.019 phase.
      final dur = 0.019;
      if ((p - _blinkStart).abs() > dur || p < _blinkStart) {
        _blinking = false;
        if (_doubleBlinkPending) {
          // Schedule the second blink ~180ms later.
          _doubleBlinkPending = false;
          _nextBlinkPhase = (p + 0.022) % 1.0;
        } else {
          // Variable gap 2.5..6s → 0.31..0.75 phase.
          final gap = 0.31 + 0.44 * _rng.nextDouble();
          _nextBlinkPhase = (p + gap) % 1.0;
        }
      }
    } else if (widget.mode == PetRenderMode.home &&
        p >= _nextBlinkPhase &&
        p < _nextBlinkPhase + 0.02) {
      _blinking = true;
      _blinkStart = p;
      // ~15% chance this becomes a double-blink.
      _doubleBlinkPending = _rng.nextDouble() < 0.15;
    }

    // Eye-look wandering — Lissajous so it never settles into a
    // periodic loop. Tau-rates are incommensurate.
    final tau = p * math.pi * 2;
    _lookX =
        math.sin(tau * 0.31 + 0.7) * 0.55 + math.sin(tau * 0.13 + 1.4) * 0.35;
    _lookY =
        math.sin(tau * 0.21 + 0.2) * 0.40 + math.cos(tau * 0.11 + 2.1) * 0.30;
  }

  @override
  void dispose() {
    _phase.removeListener(_tick);
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final morphology = NodePetMorphology.from(
      dnaSeed: widget.dnaSeed,
      branch: widget.branch,
      stage: widget.stage,
    );
    final expression = NodePetExpression.from(
      mood: widget.mood,
      stage: widget.stage,
      branch: widget.branch,
      isAsleep: widget.isAsleep,
      isSick: widget.isSick,
      isCalling: widget.isCalling,
    );

    Widget canvas = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _phase,
        builder: (context, _) {
          return CustomPaint(
            painter: _NodePetMeshPainter(
              morphology: morphology,
              expression: expression,
              palette: widget.palette,
              stage: widget.stage,
              branch: widget.branch,
              mode: widget.mode,
              phase: _phase.value,
              vitality: widget.vitality.clamp(0.0, 1.0),
              isBlinking: _blinking,
              blinkProgress: _blinking
                  ? ((_phase.value - _blinkStart).abs() / 0.019).clamp(0.0, 1.0)
                  : 0.0,
              lookOffset: Offset(_lookX, _lookY),
              dnaSeed: widget.dnaSeed,
            ),
          );
        },
      ),
    );

    if (widget.onTap != null) {
      canvas = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap!();
        },
        child: canvas,
      );
    }
    return canvas;
  }
}

/// Tiny xorshift32 PRNG — used only for non-deterministic blink jitter.
/// Determinism for visuals is supplied by Murmur3 + dnaSeed; this class
/// is for "feel alive" timing variation only.
class _Random {
  int _state = 1;
  void seed(int s) {
    _state = (s == 0) ? 1 : (s & 0xFFFFFFFF);
  }

  int _next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >>> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  double nextDouble() => _next() / 0xFFFFFFFF;
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _NodePetMeshPainter extends CustomPainter {
  final NodePetMorphology morphology;
  final NodePetExpression expression;
  final List<Color> palette;
  final PetStage stage;
  final PetBranch branch;
  final PetRenderMode mode;
  final double phase;
  final double vitality;
  final bool isBlinking;
  final double blinkProgress;
  final Offset lookOffset;
  final int dnaSeed;

  _NodePetMeshPainter({
    required this.morphology,
    required this.expression,
    required this.palette,
    required this.stage,
    required this.branch,
    required this.mode,
    required this.phase,
    required this.vitality,
    required this.isBlinking,
    required this.blinkProgress,
    required this.lookOffset,
    required this.dnaSeed,
  });

  Color get _primary => palette[0];
  Color get _secondary => palette.length > 1 ? palette[1] : palette[0];
  Color get _accent => palette.length > 2 ? palette[2] : palette[0];

  static const double _perspective = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final tau = phase * math.pi * 2;
    final minSide = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    // Mode-specific overall scale. The painter's geometry is normalised
    // to a unit-radius mesh (≈ 0.42 base), and we project at minSide.
    final modeScale = switch (mode) {
      PetRenderMode.home => 1.00,
      PetRenderMode.card => 0.92,
      PetRenderMode.tiny => 0.86,
    };

    // 1. Compute body posture.
    // Restricted Y-tumble: ±0.18 rad on a slow oscillation. NodePet
    // never turns its back. Z-tilt at incommensurate frequency.
    final tumbleY = math.sin(tau * 0.35) * 0.18;
    final tilt = math.sin(tau * 0.19 + 0.7) * 0.06;

    // Squash-stretch breathing — the animator's "alive" trick.
    // Inhale: wider+shorter. Exhale: taller+narrower. Volume preserved.
    final breath =
        math.sin(tau) * 0.07 * expression.breathScale * (0.85 + 0.3 * vitality);
    final yScale = 1.0 + breath;
    final xzScale = 1.0 / math.sqrt(yScale.abs().clamp(0.01, 10.0));

    // Calling-mode alert pop.
    final alertPop = expression.alertScaleUp ? 1.08 : 1.0;

    // Idle bob + posture.
    final bob =
        math.sin(tau * 1.05 + 0.4) *
        minSide *
        0.012 *
        expression.bounceScale *
        (0.85 + 0.3 * vitality);
    final postureBob = expression.postureY * minSide * 0.10;
    final bodyCenter = Offset(center.dx, center.dy + bob + postureBob);

    // Sick frame jitter — sub-pixel offset every frame.
    final sickJitter = expression.edgeElectricity > 0
        ? Offset(
            math.sin(tau * 17 + dnaSeed) * 1.2 * expression.edgeElectricity,
            math.cos(tau * 19 + dnaSeed) * 1.0 * expression.edgeElectricity,
          )
        : Offset.zero;

    // 2. Transform vertices: deform → tilt → tumble → lean → project.
    final transformed = <_P3>[];
    final projected = <Offset>[];
    final headStretch = morphology.headStretch;

    for (var i = 0; i < _baseVertices.length; i++) {
      final base = _baseVertices[i];
      final radial = morphology.vertexRadii[i];

      // Radial scale.
      var p = _P3(base.x * radial, base.y * radial, base.z * radial);

      // Lopsidedness — right hemisphere only.
      if (p.x > 0) {
        p = _P3(p.x * morphology.lopsidedness, p.y, p.z);
      }

      // Head stretch — upper vertices Y-elongated.
      if (p.y < -0.05) {
        p = _P3(p.x, p.y * headStretch, p.z);
      }

      // Squash-stretch.
      p = p.scaled(xzScale, yScale, xzScale);

      // Alert scale-up.
      if (alertPop != 1.0) {
        p = p.scaled(alertPop, alertPop, alertPop);
      }

      // Tilt + restricted tumble.
      p = p.rotateZ(tilt);
      p = p.rotateY(tumbleY);

      // Forward lean (calling/sick) — z-translate.
      if (expression.leanZ != 0) {
        p = p.translate(0, 0, expression.leanZ * 0.1);
      }

      // Mode + global scale.
      p = p.scaled(modeScale, modeScale, modeScale);

      transformed.add(p);
      projected.add(p.project(minSide, _perspective, bodyCenter) + sickJitter);
    }

    // 3. Body aura.
    if (mode != PetRenderMode.tiny) {
      _paintAura(canvas, bodyCenter, minSide, tau);
    }

    // 4. Calling pulse rings.
    if (expression.aura == NodePetAuraStyle.alertPulse &&
        mode != PetRenderMode.tiny) {
      _paintAlertRings(canvas, bodyCenter, minSide);
    }

    // 5. Faces (depth-sorted) — thin filled triangles for branch +
    // stage. Skip in tiny.
    if (mode != PetRenderMode.tiny) {
      _paintFaces(canvas, transformed, projected);
    }

    // 6. Internal sigil graph — visible chord lines through the mesh.
    // Depth-sorted with edges so the painter feels coherent.
    if (mode != PetRenderMode.tiny && morphology.sigilEdges.isNotEmpty) {
      _paintSigilEdges(canvas, transformed, projected);
    }

    // 7. Edges + nodes.
    _paintEdges(canvas, transformed, projected);
    _paintNodes(canvas, transformed, projected);

    // 8. Antennae — extruded from upper vertices.
    if (mode != PetRenderMode.tiny && morphology.antennae.isNotEmpty) {
      _paintAntennae(canvas, transformed, projected, tau);
    }

    // 9. Stable face overlay — ALWAYS facing the user, anchored at the
    // projected position of the head vertex but rendered in screen
    // space. The mesh body tumbles behind it.
    if (!expression.faceHidden) {
      _paintFace(canvas, projected, transformed, minSide, tau);
    }

    // 10. Mood-overlay sky layer (Z's, sleep glyphs, dormant veil).
    _paintMoodOverlay(canvas, size, bodyCenter, minSide, tau);
  }

  // ---- Aura ------------------------------------------------------------

  void _paintAura(Canvas canvas, Offset c, double minSide, double tau) {
    final pulse = 0.5 + 0.5 * math.sin(tau);
    final r = minSide * 0.46;
    final intensity = switch (expression.aura) {
      NodePetAuraStyle.alertPulse => 0.30 + 0.18 * pulse,
      NodePetAuraStyle.calm => 0.16 + 0.06 * pulse,
      NodePetAuraStyle.sleeping => 0.10,
      NodePetAuraStyle.sickGlitch => 0.18 + 0.10 * pulse,
      NodePetAuraStyle.dormant => 0.06,
      NodePetAuraStyle.none => 0.10,
    };
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _primary.withValues(alpha: intensity),
          _primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  void _paintAlertRings(Canvas canvas, Offset c, double minSide) {
    final maxR = minSide * 0.40;
    for (var i = 0; i < 2; i++) {
      final t = (phase + i * 0.5) % 1.0;
      final r = maxR * (0.55 + t * 0.85);
      final alpha = (1.0 - t) * 0.50;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _primary.withValues(alpha: alpha);
      canvas.drawCircle(c, r, paint);
    }
  }

  // ---- Faces -----------------------------------------------------------

  void _paintFaces(
    Canvas canvas,
    List<_P3> transformed,
    List<Offset> projected,
  ) {
    final faceOpacity = switch (stage) {
      PetStage.elder => 0.40,
      PetStage.adult => 0.28,
      _ => 0.18,
    };
    final facesWithDepth = <(int, double)>[];
    for (var i = 0; i < _faces.length; i++) {
      final f = _faces[i];
      final avgZ =
          (transformed[f[0]].z + transformed[f[1]].z + transformed[f[2]].z) / 3;
      facesWithDepth.add((i, avgZ));
    }
    facesWithDepth.sort((a, b) => b.$2.compareTo(a.$2)); // back→front

    for (final entry in facesWithDepth) {
      final f = _faces[entry.$1];
      final z = entry.$2;
      // Front-facing fade — front faces (z < 0) get more alpha.
      final frontness = (1.0 - (z + 0.2).clamp(-0.5, 0.5)).clamp(0.0, 1.0);
      // Per-face golden-ratio phase shimmer.
      final shimmer =
          0.5 + 0.5 * math.sin(phase * math.pi * 2 * 0.6 + entry.$1 * 1.618);
      final alpha = faceOpacity * frontness * (0.55 + 0.45 * shimmer);
      if (alpha < 0.02) continue;

      final path = Path()
        ..moveTo(projected[f[0]].dx, projected[f[0]].dy)
        ..lineTo(projected[f[1]].dx, projected[f[1]].dy)
        ..lineTo(projected[f[2]].dx, projected[f[2]].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = _primary.withValues(alpha: alpha));
    }
  }

  // ---- Edges -----------------------------------------------------------

  void _paintEdges(
    Canvas canvas,
    List<_P3> transformed,
    List<Offset> projected,
  ) {
    final edgesWithDepth = <(int, double)>[];
    for (var i = 0; i < _edges.length; i++) {
      final e = _edges[i];
      final avgZ = (transformed[e[0]].z + transformed[e[1]].z) / 2;
      edgesWithDepth.add((i, avgZ));
    }
    edgesWithDepth.sort((a, b) => b.$2.compareTo(a.$2));

    final lineWidthBase = mode == PetRenderMode.tiny ? 1.0 : 1.4;
    final glowWidth = mode == PetRenderMode.tiny ? 2.4 : 3.6;

    for (final entry in edgesWithDepth) {
      final e = _edges[entry.$1];
      final z = entry.$2;
      // Front-facing fade.
      final frontness = (1.0 - (z + 0.2).clamp(-0.5, 0.5)).clamp(0.15, 1.0);

      var p1 = projected[e[0]];
      var p2 = projected[e[1]];

      // Sick-state edge electricity — perpendicular jitter on each
      // endpoint, fast frequency.
      if (expression.edgeElectricity > 0) {
        final tau = phase * math.pi * 2;
        final jit =
            expression.edgeElectricity *
            (mode == PetRenderMode.home ? 1.4 : 0.8);
        final dx = math.sin(tau * 23 + entry.$1) * jit;
        final dy = math.cos(tau * 27 + entry.$1) * jit;
        p1 = p1.translate(dx, dy);
        p2 = p2.translate(-dx, -dy);
      }

      // Glow halo.
      if (mode != PetRenderMode.tiny) {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..strokeWidth = glowWidth
            ..strokeCap = StrokeCap.round
            ..color = _accent.withValues(alpha: 0.18 * frontness)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
      }

      // Crisp edge.
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = lineWidthBase
          ..strokeCap = StrokeCap.round
          ..color = _accent.withValues(alpha: 0.65 * frontness),
      );
    }
  }

  // ---- Nodes -----------------------------------------------------------

  void _paintNodes(
    Canvas canvas,
    List<_P3> transformed,
    List<Offset> projected,
  ) {
    final nodeR = mode == PetRenderMode.tiny ? 1.4 : 2.6;
    for (var i = 0; i < projected.length; i++) {
      final z = transformed[i].z;
      final frontness = (1.0 - (z + 0.2).clamp(-0.5, 0.5)).clamp(0.2, 1.0);
      final pos = projected[i];
      // Glow.
      if (mode != PetRenderMode.tiny) {
        canvas.drawCircle(
          pos,
          nodeR * 1.7,
          Paint()
            ..color = _primary.withValues(alpha: 0.50 * frontness)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
        );
      }
      canvas.drawCircle(
        pos,
        nodeR,
        Paint()..color = _primary.withValues(alpha: 0.95 * frontness),
      );
    }
  }

  // ---- Sigil chords ----------------------------------------------------

  void _paintSigilEdges(
    Canvas canvas,
    List<_P3> transformed,
    List<Offset> projected,
  ) {
    // Internal chords through the mesh — the socialmesh-native
    // identity beat. Drawn at low alpha so the body still reads as
    // a coherent mesh, but visible enough that users see the
    // creature is "constructed" from a graph.
    for (final pair in morphology.sigilEdges) {
      final z = (transformed[pair.$1].z + transformed[pair.$2].z) / 2;
      final frontness = (1.0 - (z + 0.2).clamp(-0.5, 0.5)).clamp(0.15, 1.0);
      canvas.drawLine(
        projected[pair.$1],
        projected[pair.$2],
        Paint()
          ..strokeWidth = 0.8
          ..color = _secondary.withValues(alpha: 0.32 * frontness),
      );
    }
  }

  // ---- Antennae --------------------------------------------------------

  void _paintAntennae(
    Canvas canvas,
    List<_P3> transformed,
    List<Offset> projected,
    double tau,
  ) {
    for (final ant in morphology.antennae) {
      final root = _antennaRootVertices[ant.rootIndex];
      final rootP = transformed[root];
      // Extrude outward in the same direction as the root vertex,
      // with seed splay applied.
      final dirLen = math.sqrt(
        rootP.x * rootP.x + rootP.y * rootP.y + rootP.z * rootP.z,
      );
      if (dirLen <= 0) continue;
      final dx = rootP.x / dirLen;
      final dy = rootP.y / dirLen;
      final dz = rootP.z / dirLen;

      // Sway — per-antenna phase, short amplitude.
      final sway = math.sin(tau * 0.9 + ant.swayPhase) * 0.025;

      // Tip in 3D body-space, with splay rotation in XZ.
      final reach = ant.length * 0.42;
      final cosS = math.cos(ant.splayAngle);
      final sinS = math.sin(ant.splayAngle);
      final tip3 = _P3(
        rootP.x + (dx * cosS + dz * sinS) * reach + sway,
        rootP.y + dy * reach,
        rootP.z + (-dx * sinS + dz * cosS) * reach,
      );

      final rootProj = projected[root];
      final tipProj = tip3.project(
        // Use same minSide via the saved transformed projection center.
        // Recover by using the projected[root] location; we just need a
        // consistent projection base. The base mesh uses minSide /
        // perspective; recomputing by fetching painter-local minSide is
        // simplest:
        _projectionMinSide(projected),
        _perspective,
        _projectionCenter(projected),
      );

      // Style-specific stroke.
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = _secondary.withValues(alpha: 0.85);

      switch (ant.style) {
        case NodePetAntennaStyle.none:
          continue;
        case NodePetAntennaStyle.straight:
          canvas.drawLine(rootProj, tipProj, paint);
        case NodePetAntennaStyle.curled:
          final ctrl = Offset(
            (rootProj.dx + tipProj.dx) / 2 + (tipProj.dx - rootProj.dx) * 0.5,
            (rootProj.dy + tipProj.dy) / 2 - 6,
          );
          final path = Path()
            ..moveTo(rootProj.dx, rootProj.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, tipProj.dx, tipProj.dy);
          canvas.drawPath(path, paint);
        case NodePetAntennaStyle.branched:
          canvas.drawLine(rootProj, tipProj, paint);
          // Two short branches at the tip.
          final branchLen = 6.0;
          canvas.drawLine(
            tipProj,
            Offset(tipProj.dx - branchLen, tipProj.dy - branchLen),
            paint,
          );
          canvas.drawLine(
            tipProj,
            Offset(tipProj.dx + branchLen, tipProj.dy - branchLen),
            paint,
          );
      }

      // Glowing orb tip.
      canvas.drawCircle(
        tipProj,
        4.0,
        Paint()
          ..color = _accent.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        tipProj,
        2.4,
        Paint()..color = _accent.withValues(alpha: 0.95),
      );
    }
  }

  /// Recover the projection minSide used during the body pass.
  /// Each projected vertex was computed at projection-center +
  /// (x_3d * scale * minSide / 2). We store nothing extra, so we infer
  /// by spread of the projected points. Cheap, robust enough for the
  /// antenna pass which only needs a consistent re-projection.
  double _projectionMinSide(List<Offset> projected) {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in projected) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return math.max(maxX - minX, maxY - minY);
  }

  Offset _projectionCenter(List<Offset> projected) {
    double sx = 0, sy = 0;
    for (final p in projected) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / projected.length, sy / projected.length);
  }

  // ---- Face overlay (screen-locked) -----------------------------------

  void _paintFace(
    Canvas canvas,
    List<Offset> projected,
    List<_P3> transformed,
    double minSide,
    double tau,
  ) {
    // Anchor at the projected position of the head vertex. Head
    // vertex is _faceVertexIndex (5) — the upper-front vertex in the
    // base orientation. As the body tumbles slightly the face follows
    // its projected location, but the face glyphs themselves are
    // drawn flat in screen-space — they never rotate.
    final headProj = projected[_faceVertexIndex];
    // Pull face slightly toward the body centre so it sits on the
    // "front" of the head, not floating off the apex.
    final bodyCenter = _projectionCenter(projected);
    final headCenter = Offset(
      headProj.dx + (bodyCenter.dx - headProj.dx) * 0.45,
      headProj.dy + (bodyCenter.dy - headProj.dy) * 0.55,
    );

    // Face circle radius — scales with projection of the head vertex.
    final headScale = transformed[_faceVertexIndex].projectionScale(
      _perspective,
    );
    final faceR = minSide * 0.20 * headScale;

    // Eyes.
    _paintEyes(canvas, headCenter, faceR);

    // Mouth (skip in tiny — eyes alone carry the read).
    if (mode != PetRenderMode.tiny) {
      _paintMouth(canvas, headCenter, faceR);
    }
  }

  void _paintEyes(Canvas canvas, Offset faceCenter, double faceR) {
    final eyeDx = morphology.eyeSpacing * faceR;
    final eyeR =
        morphology.eyeRadius *
        faceR *
        (mode == PetRenderMode.tiny ? 0.85 : 1.0);
    final eyeY = faceCenter.dy - faceR * 0.05;

    final whitesPaint = Paint()..color = const Color(0xFFFAF6E9);
    final pupilPaint = Paint()..color = const Color(0xFF12131A);
    final shinePaint = Paint()..color = const Color(0xFFFFFFFF);

    // Mood-driven close ratios (per eye, may be asymmetric).
    final closeRatios = switch (expression.eyes) {
      NodePetEyeShape.open => const [0.0, 0.0],
      NodePetEyeShape.halfClosed => const [0.5, 0.5],
      NodePetEyeShape.closedSleeping => const [1.0, 1.0],
      NodePetEyeShape.wideAlert => const [-0.18, -0.18],
      NodePetEyeShape.sickAsymm => const [0.15, 0.65],
    };

    // Natural blink — sine close curve.
    final blinkClose = isBlinking
        ? math.sin(blinkProgress * math.pi).clamp(0.0, 1.0)
        : 0.0;

    // Eye-tracking pupil offset — pupils follow the look target,
    // clamped within the eye whites. Mood modulates range/speed.
    final lookRange = switch (expression.eyes) {
      NodePetEyeShape.wideAlert => 0.45,
      NodePetEyeShape.open => 0.32,
      NodePetEyeShape.halfClosed => 0.18,
      NodePetEyeShape.sickAsymm => 0.55,
      NodePetEyeShape.closedSleeping => 0.0,
    };
    final pupilOffset = Offset(
      lookOffset.dx * eyeR * lookRange,
      lookOffset.dy * eyeR * lookRange * 0.7,
    );

    for (var i = 0; i < 2; i++) {
      final sign = i == 0 ? -1.0 : 1.0;
      final cx = faceCenter.dx + sign * eyeDx;
      final cy = eyeY;
      final close = (closeRatios[i] + blinkClose).clamp(-0.18, 1.0);

      // Closed: soft curved line.
      if (close >= 0.95) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = pupilPaint.color;
        final left = Offset(cx - eyeR, cy);
        final right = Offset(cx + eyeR, cy);
        final mid = Offset(cx, cy + eyeR * 0.55);
        final path = Path()
          ..moveTo(left.dx, left.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, right.dx, right.dy);
        canvas.drawPath(path, paint);
        continue;
      }

      // Whites + pupil + shine, clipped by close ratio.
      final eyeRect = Rect.fromCircle(center: Offset(cx, cy), radius: eyeR);
      final visibleH = eyeR * 2 * (1.0 - close);
      final clipRect = Rect.fromCenter(
        center: Offset(cx, cy + (eyeR - visibleH / 2) * 0.4),
        width: eyeR * 2.4,
        height: math.max(1.0, visibleH * 1.1),
      );
      canvas.save();
      canvas.clipRect(clipRect);
      canvas.drawOval(eyeRect, whitesPaint);

      // Pupil: shape varies per morphology.
      final pupilCenter = Offset(cx + pupilOffset.dx, cy + pupilOffset.dy);
      final pupilSize =
          eyeR * (expression.eyes == NodePetEyeShape.wideAlert ? 0.62 : 0.50);
      switch (morphology.pupilShape) {
        case NodePetPupilShape.round:
          canvas.drawCircle(pupilCenter, pupilSize, pupilPaint);
        case NodePetPupilShape.verticalSlit:
          canvas.drawOval(
            Rect.fromCenter(
              center: pupilCenter,
              width: pupilSize * 0.55,
              height: pupilSize * 1.6,
            ),
            pupilPaint,
          );
        case NodePetPupilShape.horizontalBar:
          canvas.drawOval(
            Rect.fromCenter(
              center: pupilCenter,
              width: pupilSize * 1.6,
              height: pupilSize * 0.55,
            ),
            pupilPaint,
          );
        case NodePetPupilShape.diamond:
          final p = Path()
            ..moveTo(pupilCenter.dx, pupilCenter.dy - pupilSize)
            ..lineTo(pupilCenter.dx + pupilSize, pupilCenter.dy)
            ..lineTo(pupilCenter.dx, pupilCenter.dy + pupilSize)
            ..lineTo(pupilCenter.dx - pupilSize, pupilCenter.dy)
            ..close();
          canvas.drawPath(p, pupilPaint);
      }

      // Shine — top-left highlight.
      canvas.drawCircle(
        Offset(
          pupilCenter.dx - pupilSize * 0.32,
          pupilCenter.dy - pupilSize * 0.36,
        ),
        pupilSize * 0.30,
        shinePaint,
      );

      canvas.restore();

      // Lid outline — sells the eye against a busy mesh background.
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = _accent.withValues(alpha: 0.65);
      canvas.drawOval(eyeRect, outline);
    }
  }

  void _paintMouth(Canvas canvas, Offset faceCenter, double faceR) {
    final mouthY = faceCenter.dy + morphology.mouthYFactor * faceR;
    final mw = morphology.mouthWidth * faceR * 0.8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF15171F);

    switch (expression.mouth) {
      case NodePetMouthShape.smile:
        final path = Path()
          ..moveTo(faceCenter.dx - mw, mouthY)
          ..quadraticBezierTo(
            faceCenter.dx,
            mouthY + faceR * 0.18,
            faceCenter.dx + mw,
            mouthY,
          );
        canvas.drawPath(path, paint);
      case NodePetMouthShape.smallSmile:
        final path = Path()
          ..moveTo(faceCenter.dx - mw * 0.65, mouthY)
          ..quadraticBezierTo(
            faceCenter.dx,
            mouthY + faceR * 0.10,
            faceCenter.dx + mw * 0.65,
            mouthY,
          );
        canvas.drawPath(path, paint);
      case NodePetMouthShape.neutral:
        canvas.drawLine(
          Offset(faceCenter.dx - mw * 0.6, mouthY),
          Offset(faceCenter.dx + mw * 0.6, mouthY),
          paint,
        );
      case NodePetMouthShape.frown:
        final path = Path()
          ..moveTo(faceCenter.dx - mw * 0.7, mouthY + faceR * 0.10)
          ..quadraticBezierTo(
            faceCenter.dx,
            mouthY - faceR * 0.10,
            faceCenter.dx + mw * 0.7,
            mouthY + faceR * 0.10,
          );
        canvas.drawPath(path, paint);
      case NodePetMouthShape.smallO:
        canvas.drawCircle(
          Offset(faceCenter.dx, mouthY),
          faceR * 0.10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = paint.color,
        );
      case NodePetMouthShape.flat:
        canvas.drawLine(
          Offset(faceCenter.dx - mw * 0.5, mouthY),
          Offset(faceCenter.dx + mw * 0.5, mouthY),
          paint,
        );
      case NodePetMouthShape.sickWobble:
        final tau = phase * math.pi * 2;
        final w = math.sin(tau * 5) * 1.3;
        final path = Path()
          ..moveTo(faceCenter.dx - mw * 0.7, mouthY)
          ..lineTo(faceCenter.dx - mw * 0.3, mouthY + w)
          ..lineTo(faceCenter.dx, mouthY - w)
          ..lineTo(faceCenter.dx + mw * 0.3, mouthY + w)
          ..lineTo(faceCenter.dx + mw * 0.7, mouthY);
        canvas.drawPath(path, paint);
    }
  }

  // ---- Mood overlay ----------------------------------------------------

  void _paintMoodOverlay(
    Canvas canvas,
    Size size,
    Offset bodyCenter,
    double minSide,
    double tau,
  ) {
    switch (expression.aura) {
      case NodePetAuraStyle.sleeping:
        if (mode == PetRenderMode.tiny) return;
        _paintZzz(canvas, bodyCenter, minSide);
      case NodePetAuraStyle.dormant:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.22)
            ..blendMode = BlendMode.srcATop,
        );
      case NodePetAuraStyle.alertPulse:
      case NodePetAuraStyle.calm:
      case NodePetAuraStyle.sickGlitch:
      case NodePetAuraStyle.none:
        break;
    }
  }

  void _paintZzz(Canvas canvas, Offset bodyCenter, double minSide) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t = (phase + i * 0.33) % 1.0;
      final scale = 1.0 - 0.5 * t;
      final origin = Offset(
        bodyCenter.dx + minSide * 0.20 + minSide * 0.04 * t,
        bodyCenter.dy - minSide * 0.28 - minSide * 0.16 * t,
      );
      final s = minSide * 0.05 * scale;
      paint.color = Colors.white.withValues(alpha: (1.0 - t) * 0.85);
      canvas.drawLine(origin, origin.translate(s, 0), paint);
      canvas.drawLine(origin.translate(s, 0), origin.translate(0, s), paint);
      canvas.drawLine(origin.translate(0, s), origin.translate(s, s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NodePetMeshPainter old) =>
      old.phase != phase ||
      old.morphology != morphology ||
      old.expression != expression ||
      old.palette != palette ||
      old.mode != mode ||
      old.stage != stage ||
      old.branch != branch ||
      old.vitality != vitality ||
      old.isBlinking != isBlinking ||
      old.blinkProgress != blinkProgress ||
      old.lookOffset != lookOffset;
}
