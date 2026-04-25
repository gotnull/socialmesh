// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodePet creature renderer — a self-contained, face-first procedural
// painter built specifically for the NodePet companion. Independent of
// the MeshNodeBrain / Ico advisor system; the two visual languages must
// not blur together.
//
// Composition (back to front):
//   1. Aura          — soft branch-tinted radial halo (mode-gated)
//   2. Shadow        — squashed ellipse anchoring the creature to a surface
//   3. Body          — soft seed-shaped silhouette with subtle gradient
//   4. Markings      — sigil-style dots / glyphs on the shell
//   5. Antennae      — 0..3 stalks with glowing orb tips
//   6. Face          — eyes + mouth, painted FLAT on the front; never
//                      tumbles, never rotates away (this is the
//                      emotional anchor and the single biggest readability
//                      win over the previous MeshNodeBrain hand-me-down)
//   7. Mood overlay  — Zzz, sweat, alert ring, sick glitch
//
// Determinism: morphology + palette are pure functions of `dnaSeed +
// branch + stage`. Same identity always renders the same creature.
//
// Animation budget: one [AnimationController]. Breath, idle bob,
// antenna sway, and blink scheduling all derive from its single phase
// value. No backdrop filters, no shaders.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet_enums.dart';
import 'pet_render_model.dart' show PetRenderMode;

// ---------------------------------------------------------------------------
// Morphology
// ---------------------------------------------------------------------------

/// Body silhouette family — seed-derived. All silhouettes are
/// soft / rounded / creature-like; no sharp polygons (those read as
/// debug visualisations, not living things).
enum NodePetBodyShape {
  /// Round droplet — top tapered, bottom rounded. The default friendly
  /// blob.
  droplet,

  /// Squat oval — wider than tall, calm and grounded.
  pebble,

  /// Tall oval — slightly elongated vertically, alert reading.
  capsule,

  /// Soft diamond — gentle four-point silhouette, more "spirit-like".
  diamond,

  /// Shell — rounded top, flat bottom; reads as a creature wearing a
  /// shell.
  shell,
}

/// Antenna shape family.
enum NodePetAntennaStyle { none, straight, curled, branched }

/// Mouth family — base shape before mood modulation.
enum NodePetMouthStyle { smileSoft, smileWide, neutral, smallO, dotMouth }

/// Marking pattern on the body shell.
enum NodePetMarkingPattern { none, dots, ring, glyph }

/// Side flourish (small fins / cheek puffs / no flourish).
enum NodePetSideFlourish { none, cheekDots, sideFins }

/// Deterministic morphology derived from a (dnaSeed, branch, stage)
/// triple. Pure value type — equality + hashCode rely on every field.
@immutable
class NodePetMorphology {
  final NodePetBodyShape body;
  final NodePetAntennaStyle antennae;

  /// Number of antennae actually drawn (1, 2, or 3) when [antennae] is
  /// not [NodePetAntennaStyle.none].
  final int antennaCount;

  final NodePetMouthStyle mouthStyle;
  final NodePetMarkingPattern markings;
  final NodePetSideFlourish sideFlourish;

  /// Eye spacing as a fraction of body half-width (0..1).
  final double eyeSpacing;

  /// Eye radius as a fraction of body half-height.
  final double eyeRadiusFactor;

  /// Mouth Y as a fraction of body half-height (positive = below centre).
  final double mouthYFactor;

  /// Body width / height ratio. ~1.0 = round; 1.2 wide pebble; 0.85 capsule.
  final double aspect;

  /// Marking count (dots / glyph elements). 0..6.
  final int markingCount;

  /// Tiny rotational offset for marking placement so two pets with
  /// otherwise-identical morphology read as visually distinct.
  final double markingRotation;

  const NodePetMorphology({
    required this.body,
    required this.antennae,
    required this.antennaCount,
    required this.mouthStyle,
    required this.markings,
    required this.sideFlourish,
    required this.eyeSpacing,
    required this.eyeRadiusFactor,
    required this.mouthYFactor,
    required this.aspect,
    required this.markingCount,
    required this.markingRotation,
  });

  /// Murmur3 fmix32 finalizer — same constants as the existing
  /// palette mixer in [pet_sigil_painter.dart]. Kept inline so this
  /// renderer stays self-contained.
  static int _mix(int seed) {
    int x = seed & 0xFFFFFFFF;
    x ^= (x >>> 16);
    x = (x * 0x85ebca6b) & 0xFFFFFFFF;
    x ^= (x >>> 13);
    x = (x * 0xc2b2ae35) & 0xFFFFFFFF;
    x ^= (x >>> 16);
    return x & 0xFFFFFFFF;
  }

  /// Build morphology for the given identity.
  ///
  /// Stage and branch only modulate a handful of traits — body silhouette
  /// and core proportions remain stable across stages so the user reads
  /// "same pet, just older". Branch picks side-flourish style and
  /// modulates antenna boldness; stage gates how many flourishes appear.
  factory NodePetMorphology.from({
    required int dnaSeed,
    required PetBranch branch,
    required PetStage stage,
  }) {
    final m = _mix(dnaSeed);

    // Body shape bucket — 5 silhouettes, picked by 3 bits of the mixed
    // seed (8 buckets → 5 shapes, with droplet/pebble slightly more
    // common for friendlier average reading).
    final shapeRoll = (m >>> 3) & 0x07;
    final body = switch (shapeRoll) {
      0 || 1 => NodePetBodyShape.droplet,
      2 || 3 => NodePetBodyShape.pebble,
      4 => NodePetBodyShape.capsule,
      5 => NodePetBodyShape.diamond,
      _ => NodePetBodyShape.shell,
    };

    // Aspect ratio per shape, with ±5% per-seed jitter so two droplets
    // are subtly different shapes.
    final aspectJitter = (((m >>> 7) & 0x1F) / 31.0 - 0.5) * 0.10; // ±5%
    final aspectBase = switch (body) {
      NodePetBodyShape.droplet => 1.00,
      NodePetBodyShape.pebble => 1.18,
      NodePetBodyShape.capsule => 0.86,
      NodePetBodyShape.diamond => 0.96,
      NodePetBodyShape.shell => 1.10,
    };
    final aspect = (aspectBase + aspectJitter).clamp(0.80, 1.30);

    // Antenna style — egg has none; otherwise seed-driven.
    NodePetAntennaStyle antennae;
    int antennaCount;
    if (stage == PetStage.egg || branch == PetBranch.unborn) {
      antennae = NodePetAntennaStyle.none;
      antennaCount = 0;
    } else {
      final antennaRoll = (m >>> 12) & 0x07;
      antennae = switch (antennaRoll) {
        0 || 1 => NodePetAntennaStyle.none,
        2 || 3 => NodePetAntennaStyle.straight,
        4 || 5 => NodePetAntennaStyle.curled,
        _ => NodePetAntennaStyle.branched,
      };
      // Count: 1 or 2 most common, 3 rare (volatile branch only).
      final countRoll = (m >>> 18) & 0x0F;
      if (antennae == NodePetAntennaStyle.none) {
        antennaCount = 0;
      } else if (branch == PetBranch.volatile && countRoll == 0) {
        antennaCount = 3;
      } else {
        antennaCount = (countRoll & 0x01) == 0 ? 2 : 1;
      }
    }

    // Mouth style.
    final mouthRoll = (m >>> 21) & 0x07;
    final mouthStyle = switch (mouthRoll) {
      0 || 1 || 2 => NodePetMouthStyle.smileSoft,
      3 => NodePetMouthStyle.smileWide,
      4 => NodePetMouthStyle.neutral,
      5 => NodePetMouthStyle.smallO,
      _ => NodePetMouthStyle.dotMouth,
    };

    // Markings — egg shows none; juveniles show fewer.
    NodePetMarkingPattern markings;
    int markingCount;
    if (stage == PetStage.egg) {
      markings = NodePetMarkingPattern.none;
      markingCount = 0;
    } else {
      final markRoll = (m >>> 25) & 0x07;
      markings = switch (markRoll) {
        0 => NodePetMarkingPattern.none,
        1 || 2 || 3 => NodePetMarkingPattern.dots,
        4 || 5 => NodePetMarkingPattern.ring,
        _ => NodePetMarkingPattern.glyph,
      };
      final countRoll = ((m >>> 28) & 0x07);
      // Stage gates count: juvenile gets fewer; adult/elder full.
      final stageGate = switch (stage) {
        PetStage.juvenile => 2,
        PetStage.adolescent => 4,
        _ => 6,
      };
      markingCount = markings == NodePetMarkingPattern.none
          ? 0
          : (countRoll % stageGate) + 1;
    }

    // Side flourish — gentle "cheek dots" or small fins on the sides.
    NodePetSideFlourish sideFlourish;
    if (stage == PetStage.egg || stage == PetStage.dormant) {
      sideFlourish = NodePetSideFlourish.none;
    } else {
      final flourishRoll = (m >>> 4) & 0x03;
      sideFlourish = switch (flourishRoll) {
        0 => NodePetSideFlourish.none,
        1 || 2 => NodePetSideFlourish.cheekDots,
        _ => NodePetSideFlourish.sideFins,
      };
    }

    // Face proportions — eye spacing and size jitter per seed.
    final eyeSpacingJitter = ((m >>> 9) & 0x0F) / 15.0; // 0..1
    final eyeSpacing = (0.34 + 0.16 * eyeSpacingJitter).clamp(0.34, 0.50);
    final eyeSizeJitter = ((m >>> 14) & 0x0F) / 15.0;
    final eyeRadiusFactor = (0.13 + 0.06 * eyeSizeJitter).clamp(0.13, 0.19);

    final mouthYJitter = ((m >>> 19) & 0x0F) / 15.0;
    final mouthYFactor = (0.34 + 0.10 * mouthYJitter).clamp(0.34, 0.44);

    final markingRotation = (((m >>> 16) & 0xFF) / 255.0) * math.pi * 2;

    return NodePetMorphology(
      body: body,
      antennae: antennae,
      antennaCount: antennaCount,
      mouthStyle: mouthStyle,
      markings: markings,
      sideFlourish: sideFlourish,
      eyeSpacing: eyeSpacing,
      eyeRadiusFactor: eyeRadiusFactor,
      mouthYFactor: mouthYFactor,
      aspect: aspect,
      markingCount: markingCount,
      markingRotation: markingRotation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NodePetMorphology &&
          body == other.body &&
          antennae == other.antennae &&
          antennaCount == other.antennaCount &&
          mouthStyle == other.mouthStyle &&
          markings == other.markings &&
          sideFlourish == other.sideFlourish &&
          eyeSpacing == other.eyeSpacing &&
          eyeRadiusFactor == other.eyeRadiusFactor &&
          mouthYFactor == other.mouthYFactor &&
          aspect == other.aspect &&
          markingCount == other.markingCount &&
          markingRotation == other.markingRotation);

  @override
  int get hashCode => Object.hash(
    body,
    antennae,
    antennaCount,
    mouthStyle,
    markings,
    sideFlourish,
    eyeSpacing,
    eyeRadiusFactor,
    mouthYFactor,
    aspect,
    markingCount,
    markingRotation,
  );
}

// ---------------------------------------------------------------------------
// Expression
// ---------------------------------------------------------------------------

/// Eye shape for the current frame's expression.
enum NodePetEyeShape { open, halfClosed, closedSleeping, wideAlert, sickAsymm }

/// Mouth shape for the current frame's expression.
enum NodePetMouthShape {
  smile,
  smallSmile,
  neutral,
  frown,
  smallO,
  flat,
  sickWobble,
}

/// Aura / overlay style for ambient mood signals.
enum NodePetAuraStyle { none, calm, alertPulse, sickGlitch, sleeping, dormant }

/// Pose / posture nudges driven by mood. All values are multipliers
/// applied to the renderer's base motion.
@immutable
class NodePetExpression {
  final NodePetEyeShape eyes;
  final NodePetMouthShape mouth;
  final NodePetAuraStyle aura;

  /// Vertical body offset as fraction of body height. Negative = lifted
  /// (hopeful / alert), positive = drooped (sad / sick).
  final double postureOffset;

  /// Body tilt in radians. Small (-0.08..0.08) — readable lean without
  /// breaking the front-facing face.
  final double tiltRadians;

  /// Multiplier on idle breath amplitude.
  final double breathScale;

  /// Multiplier on idle bounce amplitude.
  final double bounceScale;

  /// Whether eye blinking should be scheduled. False when sleeping or
  /// dormant.
  final bool blinks;

  /// Whether the face is hidden entirely (egg / dormant).
  final bool faceHidden;

  const NodePetExpression({
    required this.eyes,
    required this.mouth,
    required this.aura,
    required this.postureOffset,
    required this.tiltRadians,
    required this.breathScale,
    required this.bounceScale,
    required this.blinks,
    required this.faceHidden,
  });

  /// Map pet state to expression. Priority order:
  /// stage(egg/dormant) → asleep → sick → calling → mood.
  factory NodePetExpression.from({
    required PetMood mood,
    required PetStage stage,
    required PetBranch branch,
    required bool isAsleep,
    required bool isSick,
    required bool isCalling,
    required NodePetMorphology morphology,
  }) {
    if (stage == PetStage.egg) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.closedSleeping,
        mouth: NodePetMouthShape.flat,
        aura: NodePetAuraStyle.dormant,
        postureOffset: 0,
        tiltRadians: 0,
        breathScale: 1.0,
        bounceScale: 0.0,
        blinks: false,
        faceHidden: true,
      );
    }
    if (stage == PetStage.dormant) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.closedSleeping,
        mouth: NodePetMouthShape.flat,
        aura: NodePetAuraStyle.dormant,
        postureOffset: 0.04,
        tiltRadians: 0,
        breathScale: 0.5,
        bounceScale: 0.0,
        blinks: false,
        faceHidden: true,
      );
    }
    if (isAsleep) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.closedSleeping,
        mouth: NodePetMouthShape.smallSmile,
        aura: NodePetAuraStyle.sleeping,
        postureOffset: 0.02,
        tiltRadians: 0,
        breathScale: 0.6,
        bounceScale: 0.3,
        blinks: false,
        faceHidden: false,
      );
    }
    if (isSick) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.sickAsymm,
        mouth: NodePetMouthShape.sickWobble,
        aura: NodePetAuraStyle.sickGlitch,
        postureOffset: 0.05,
        tiltRadians: -0.04,
        breathScale: 0.7,
        bounceScale: 0.5,
        blinks: true,
        faceHidden: false,
      );
    }
    if (isCalling) {
      return const NodePetExpression(
        eyes: NodePetEyeShape.wideAlert,
        mouth: NodePetMouthShape.smallO,
        aura: NodePetAuraStyle.alertPulse,
        postureOffset: -0.03,
        tiltRadians: 0,
        breathScale: 1.4,
        bounceScale: 1.5,
        blinks: true,
        faceHidden: false,
      );
    }
    // Mood-class branch.
    switch (mood) {
      case PetMood.content:
        return NodePetExpression(
          eyes: NodePetEyeShape.open,
          mouth: morphology.mouthStyle == NodePetMouthStyle.dotMouth
              ? NodePetMouthShape.smallSmile
              : NodePetMouthShape.smile,
          aura: NodePetAuraStyle.calm,
          postureOffset: 0,
          tiltRadians: 0,
          breathScale: 1.0,
          bounceScale: 1.0,
          blinks: true,
          faceHidden: false,
        );
      case PetMood.hungry:
        return const NodePetExpression(
          eyes: NodePetEyeShape.halfClosed,
          mouth: NodePetMouthShape.smallO,
          aura: NodePetAuraStyle.calm,
          postureOffset: 0.02,
          tiltRadians: -0.03,
          breathScale: 0.85,
          bounceScale: 0.6,
          blinks: true,
          faceHidden: false,
        );
      case PetMood.sad:
        return const NodePetExpression(
          eyes: NodePetEyeShape.halfClosed,
          mouth: NodePetMouthShape.frown,
          aura: NodePetAuraStyle.calm,
          postureOffset: 0.05,
          tiltRadians: 0.02,
          breathScale: 0.75,
          bounceScale: 0.4,
          blinks: true,
          faceHidden: false,
        );
      case PetMood.sick:
        return const NodePetExpression(
          eyes: NodePetEyeShape.sickAsymm,
          mouth: NodePetMouthShape.sickWobble,
          aura: NodePetAuraStyle.sickGlitch,
          postureOffset: 0.05,
          tiltRadians: -0.04,
          breathScale: 0.7,
          bounceScale: 0.5,
          blinks: true,
          faceHidden: false,
        );
      case PetMood.sleeping:
        return const NodePetExpression(
          eyes: NodePetEyeShape.closedSleeping,
          mouth: NodePetMouthShape.smallSmile,
          aura: NodePetAuraStyle.sleeping,
          postureOffset: 0.02,
          tiltRadians: 0,
          breathScale: 0.6,
          bounceScale: 0.3,
          blinks: false,
          faceHidden: false,
        );
      case PetMood.calling:
        return const NodePetExpression(
          eyes: NodePetEyeShape.wideAlert,
          mouth: NodePetMouthShape.smallO,
          aura: NodePetAuraStyle.alertPulse,
          postureOffset: -0.03,
          tiltRadians: 0,
          breathScale: 1.4,
          bounceScale: 1.5,
          blinks: true,
          faceHidden: false,
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
          postureOffset == other.postureOffset &&
          tiltRadians == other.tiltRadians &&
          breathScale == other.breathScale &&
          bounceScale == other.bounceScale &&
          blinks == other.blinks &&
          faceHidden == other.faceHidden);

  @override
  int get hashCode => Object.hash(
    eyes,
    mouth,
    aura,
    postureOffset,
    tiltRadians,
    breathScale,
    bounceScale,
    blinks,
    faceHidden,
  );
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// The new NodePet creature renderer. Self-contained — owns its own
/// animation controller, paints directly via [CustomPaint], no
/// dependency on MeshNodeBrain / Ico.
class NodePetCreature extends StatefulWidget {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final double size;
  final PetRenderMode mode;

  /// Three-colour palette derived from dnaSeed + branch. Caller computes
  /// it (typically via the existing `paletteFromDnaSeed` helper) so the
  /// renderer stays purely presentational.
  final List<Color> palette;

  /// Vitality scalar in [0, 1] — softly modulates breath / glow within
  /// the active mood bucket. Defaults to full vitality.
  final double vitality;

  /// Tap callback. When non-null, the creature reacts with a brief
  /// scale-up bounce and forwards the tap.
  final VoidCallback? onTap;

  const NodePetCreature({
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
  State<NodePetCreature> createState() => _NodePetCreatureState();
}

class _NodePetCreatureState extends State<NodePetCreature>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;

  /// Phase value at which the next blink starts. Updated after each
  /// blink so the cadence varies and reads natural.
  double _nextBlinkPhase = 0.18;

  /// Whether a blink is currently in progress.
  bool _blinking = false;

  /// Phase value at which the current blink began.
  double _blinkStartPhase = 0.0;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _phase.addListener(_advanceBlink);
  }

  void _advanceBlink() {
    if (!mounted) return;
    final p = _phase.value;
    if (_blinking) {
      // Blink lasts ~140ms on a 6s loop → ~0.023 phase.
      if (p - _blinkStartPhase > 0.025 || p < _blinkStartPhase) {
        _blinking = false;
        // Schedule next blink 2.5–4.5s away.
        final jitter =
            ((widget.dnaSeed >> _phase.value.floor() & 0xFF) / 255.0);
        final gapPhase = 0.42 + 0.33 * jitter;
        _nextBlinkPhase = (p + gapPhase) % 1.0;
      }
    } else if (p >= _nextBlinkPhase &&
        p < _nextBlinkPhase + 0.02 &&
        widget.mode == PetRenderMode.home) {
      _blinking = true;
      _blinkStartPhase = p;
    }
  }

  @override
  void dispose() {
    _phase.removeListener(_advanceBlink);
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
      morphology: morphology,
    );
    final stageScale = _stageScale(widget.stage);

    Widget canvas = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _phase,
        builder: (context, _) {
          return CustomPaint(
            painter: _NodePetPainter(
              morphology: morphology,
              expression: expression,
              palette: widget.palette,
              stage: widget.stage,
              branch: widget.branch,
              mode: widget.mode,
              phase: _phase.value,
              stageScale: stageScale,
              vitality: widget.vitality.clamp(0.0, 1.0),
              isBlinking: _blinking,
              blinkProgress: _blinking
                  ? ((_phase.value - _blinkStartPhase).abs() / 0.025).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0,
            ),
          );
        },
      ),
    );

    if (widget.onTap != null) {
      canvas = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: canvas,
      );
    }
    return canvas;
  }
}

double _stageScale(PetStage stage) => switch (stage) {
  PetStage.egg => 0.62,
  PetStage.juvenile => 0.78,
  PetStage.adolescent => 0.90,
  PetStage.adult => 1.00,
  PetStage.elder => 0.96,
  PetStage.dormant => 0.80,
};

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _NodePetPainter extends CustomPainter {
  final NodePetMorphology morphology;
  final NodePetExpression expression;
  final List<Color> palette;
  final PetStage stage;
  final PetBranch branch;
  final PetRenderMode mode;
  final double phase; // 0..1
  final double stageScale;
  final double vitality;
  final bool isBlinking;
  final double blinkProgress; // 0..1

  _NodePetPainter({
    required this.morphology,
    required this.expression,
    required this.palette,
    required this.stage,
    required this.branch,
    required this.mode,
    required this.phase,
    required this.stageScale,
    required this.vitality,
    required this.isBlinking,
    required this.blinkProgress,
  });

  Color get _primary => palette[0];
  Color get _secondary => palette.length > 1 ? palette[1] : palette[0];
  Color get _accent => palette.length > 2 ? palette[2] : palette[0];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final minSide = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    // Body box: scaled by stage and (slightly) by mode so card/tiny
    // previews don't fight the surrounding chrome.
    final modeScale = switch (mode) {
      PetRenderMode.home => 1.0,
      PetRenderMode.card => 0.92,
      PetRenderMode.tiny => 0.84,
    };
    final bodyHeight = minSide * 0.62 * stageScale * modeScale;
    final bodyWidth = bodyHeight * morphology.aspect;

    // Idle motion: gentle vertical bob + breath in/out.
    final tau = phase * math.pi * 2;
    final breathMag = 0.022 * expression.breathScale * (0.85 + 0.3 * vitality);
    final breath = 1.0 + math.sin(tau) * breathMag;
    final bobMag =
        bodyHeight * 0.022 * expression.bounceScale * (0.85 + 0.3 * vitality);
    final bob = math.sin(tau + math.pi / 4) * bobMag;
    final postureBob = expression.postureOffset * bodyHeight;

    final bodyCenter = Offset(center.dx, center.dy + bob + postureBob);

    // Save into a tilt frame so eyes and mouth ride with the body but
    // never rotate independently of it (face-stable principle).
    canvas.save();
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    if (expression.tiltRadians.abs() > 0.001) {
      canvas.rotate(expression.tiltRadians * math.sin(tau * 0.5));
    }
    canvas.scale(breath);

    // 1. Aura (under body, after transform — wraps with the breath).
    if (mode != PetRenderMode.tiny) {
      _paintAura(canvas, bodyWidth, bodyHeight);
    }

    // 2. Shadow — squashed ellipse below the body, drawn in body-local
    // coords so it bobs with the creature but doesn't tilt with it
    // (subtle but helps the "anchored" feel).
    _paintShadow(canvas, bodyWidth, bodyHeight);

    // 3. Body silhouette.
    final bodyPath = _bodyPath(bodyWidth, bodyHeight);
    _paintBodyFill(canvas, bodyPath, bodyWidth, bodyHeight);

    // 4. Markings on the body shell.
    if (morphology.markings != NodePetMarkingPattern.none &&
        mode != PetRenderMode.tiny) {
      _paintMarkings(canvas, bodyWidth, bodyHeight);
    }

    // 5. Side flourish (cheek dots / fins) — skip in tiny.
    if (morphology.sideFlourish != NodePetSideFlourish.none &&
        mode != PetRenderMode.tiny) {
      _paintSideFlourish(canvas, bodyWidth, bodyHeight);
    }

    // 6. Antennae — drawn from top of body.
    if (morphology.antennae != NodePetAntennaStyle.none &&
        mode != PetRenderMode.tiny) {
      _paintAntennae(canvas, bodyWidth, bodyHeight);
    }

    // 7. Body outline (thin) — sells the silhouette against dark bg.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mode == PetRenderMode.tiny ? 1.2 : 1.6
      ..color = _accent.withValues(alpha: 0.55);
    canvas.drawPath(bodyPath, outline);

    // 8. FACE — eyes + mouth. Face-first principle: this is the last
    // body-anchored layer, so it sits on top of every other body
    // element. Tiny mode still paints simplified eyes (a creature
    // without eyes doesn't read as a creature).
    if (!expression.faceHidden) {
      _paintFace(canvas, bodyWidth, bodyHeight);
    }

    canvas.restore();

    // 9. Mood overlays (Z, alert ring, sparkles) — drawn in screen-space
    // so they don't tilt/breath with the body.
    _paintMoodOverlay(canvas, size, bodyCenter, bodyHeight);
  }

  // ---- Body path -------------------------------------------------------

  Path _bodyPath(double w, double h) {
    final hw = w / 2;
    final hh = h / 2;
    final path = Path();

    switch (morphology.body) {
      case NodePetBodyShape.droplet:
        // Top tapered, bottom rounded. Like a friendly raindrop on its
        // base.
        path.moveTo(0, -hh);
        path.cubicTo(hw * 0.95, -hh * 0.85, hw * 1.05, hh * 0.25, hw * 0.6, hh);
        path.cubicTo(
          hw * 0.25,
          hh * 1.05,
          -hw * 0.25,
          hh * 1.05,
          -hw * 0.6,
          hh,
        );
        path.cubicTo(-hw * 1.05, hh * 0.25, -hw * 0.95, -hh * 0.85, 0, -hh);
        path.close();
      case NodePetBodyShape.pebble:
        // Wide, low-slung oval.
        path.addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h));
      case NodePetBodyShape.capsule:
        // Tall round-cornered rectangle.
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            Radius.circular(hw * 0.95),
          ),
        );
      case NodePetBodyShape.diamond:
        // Soft 4-corner blob with rounded points.
        path.moveTo(0, -hh);
        path.cubicTo(hw * 0.55, -hh * 0.55, hw, -hh * 0.05, hw, 0);
        path.cubicTo(hw, hh * 0.55, hw * 0.55, hh, 0, hh);
        path.cubicTo(-hw * 0.55, hh, -hw, hh * 0.55, -hw, 0);
        path.cubicTo(-hw, -hh * 0.05, -hw * 0.55, -hh * 0.55, 0, -hh);
        path.close();
      case NodePetBodyShape.shell:
        // Rounded dome on top, flatter bottom.
        path.moveTo(-hw * 0.92, hh * 0.7);
        path.cubicTo(-hw, -hh * 0.4, -hw * 0.6, -hh, 0, -hh);
        path.cubicTo(hw * 0.6, -hh, hw, -hh * 0.4, hw * 0.92, hh * 0.7);
        path.cubicTo(hw * 0.85, hh, -hw * 0.85, hh, -hw * 0.92, hh * 0.7);
        path.close();
    }
    return path;
  }

  // ---- Body fill -------------------------------------------------------

  void _paintBodyFill(Canvas canvas, Path body, double w, double h) {
    // Subtle rim-darkening + top-light gradient → the body reads as
    // a dimensional creature, not a flat sticker.
    final rect = body.getBounds();
    final gradient = LinearGradient(
      begin: const Alignment(-0.2, -0.9),
      end: const Alignment(0.3, 1.0),
      colors: [
        Color.lerp(_primary, Colors.white, 0.18)!,
        _primary,
        Color.lerp(_primary, _accent, 0.25)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final fill = Paint()..shader = gradient.createShader(rect);
    canvas.drawPath(body, fill);

    // Inner soft shadow at bottom — sells volume.
    final shadow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.55),
        radius: 0.85,
        colors: [Colors.black.withValues(alpha: 0.18), Colors.transparent],
      ).createShader(rect)
      ..blendMode = BlendMode.srcATop;
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(body, shadow);
    canvas.restore();
  }

  // ---- Aura ------------------------------------------------------------

  void _paintAura(Canvas canvas, double w, double h) {
    final tau = phase * math.pi * 2;
    final pulse = 0.5 + 0.5 * math.sin(tau);
    final r = math.max(w, h) * 0.78;
    final intensity = switch (expression.aura) {
      NodePetAuraStyle.alertPulse => 0.30 + 0.18 * pulse,
      NodePetAuraStyle.calm => 0.16 + 0.06 * pulse,
      NodePetAuraStyle.sleeping => 0.12,
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
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawCircle(Offset.zero, r, paint);
  }

  // ---- Shadow ----------------------------------------------------------

  void _paintShadow(Canvas canvas, double w, double h) {
    final shadowRect = Rect.fromCenter(
      center: Offset(0, h * 0.52),
      width: w * 0.9,
      height: h * 0.16,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.black.withValues(alpha: 0.32), Colors.transparent],
      ).createShader(shadowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(shadowRect, paint);
  }

  // ---- Markings --------------------------------------------------------

  void _paintMarkings(Canvas canvas, double w, double h) {
    final hw = w / 2;
    final hh = h / 2;
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _accent.withValues(alpha: 0.7);

    switch (morphology.markings) {
      case NodePetMarkingPattern.none:
        return;
      case NodePetMarkingPattern.dots:
        // Small spots distributed around the upper-back of the shell.
        // We avoid the face area (top-front centre).
        for (var i = 0; i < morphology.markingCount; i++) {
          final angle =
              morphology.markingRotation + i * (math.pi * 2 / 6) + 0.4;
          final r = hw * 0.55;
          final pt = Offset(math.cos(angle) * r, math.sin(angle) * r * 0.85);
          // Skip dots that would land on the face area.
          if (pt.dy < -hh * 0.05 && pt.dx.abs() < hw * 0.5) continue;
          canvas.drawCircle(pt, 2.4, dotPaint);
        }
      case NodePetMarkingPattern.ring:
        // Thin sigil ring around the lower body.
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _accent.withValues(alpha: 0.55);
        final ringRect = Rect.fromCenter(
          center: Offset(0, hh * 0.35),
          width: w * 0.78,
          height: h * 0.22,
        );
        canvas.drawOval(ringRect, ringPaint);
        // Tiny orb ticks on the ring.
        for (var i = 0; i < morphology.markingCount; i++) {
          final t = i / morphology.markingCount;
          final angle = morphology.markingRotation + t * math.pi * 2;
          final pt = Offset(
            ringRect.center.dx + math.cos(angle) * ringRect.width / 2,
            ringRect.center.dy + math.sin(angle) * ringRect.height / 2,
          );
          canvas.drawCircle(pt, 1.6, dotPaint);
        }
      case NodePetMarkingPattern.glyph:
        // Vertical sigil glyph on the chest (below the face line).
        final glyphPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _accent.withValues(alpha: 0.7);
        final glyphCenter = Offset(0, hh * 0.45);
        final glyphR = hw * 0.18;
        // Vertical stroke + N horizontal rungs (count derived from
        // markingCount, capped at 3 so it stays a glyph not a ladder).
        canvas.drawLine(
          Offset(glyphCenter.dx, glyphCenter.dy - glyphR),
          Offset(glyphCenter.dx, glyphCenter.dy + glyphR),
          glyphPaint,
        );
        final rungs = morphology.markingCount.clamp(1, 3);
        for (var i = 0; i < rungs; i++) {
          final t = (i + 1) / (rungs + 1);
          final y = glyphCenter.dy - glyphR + 2 * glyphR * t;
          final wRung = glyphR * (1.0 - 0.25 * i);
          canvas.drawLine(
            Offset(glyphCenter.dx - wRung, y),
            Offset(glyphCenter.dx + wRung, y),
            glyphPaint,
          );
        }
    }
  }

  // ---- Side flourish ---------------------------------------------------

  void _paintSideFlourish(Canvas canvas, double w, double h) {
    final hw = w / 2;
    switch (morphology.sideFlourish) {
      case NodePetSideFlourish.none:
        return;
      case NodePetSideFlourish.cheekDots:
        // Two small accent puffs on the lower-side of the body.
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = _secondary.withValues(alpha: 0.55);
        for (final sign in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(sign * hw * 0.78, h * 0.05), 4.0, paint);
        }
      case NodePetSideFlourish.sideFins:
        // Small petal-shaped fins protruding from the sides.
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = _secondary.withValues(alpha: 0.55);
        for (final sign in [-1.0, 1.0]) {
          final path = Path();
          final tip = Offset(sign * hw * 1.18, h * 0.05);
          final base1 = Offset(sign * hw * 0.85, -h * 0.05);
          final base2 = Offset(sign * hw * 0.85, h * 0.18);
          path.moveTo(base1.dx, base1.dy);
          path.quadraticBezierTo(tip.dx, tip.dy, base2.dx, base2.dy);
          path.quadraticBezierTo(
            sign * hw * 0.95,
            h * 0.06,
            base1.dx,
            base1.dy,
          );
          canvas.drawPath(path, paint);
        }
    }
  }

  // ---- Antennae --------------------------------------------------------

  void _paintAntennae(Canvas canvas, double w, double h) {
    final hh = h / 2;
    final tau = phase * math.pi * 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _secondary.withValues(alpha: 0.85);
    final orb = Paint()
      ..style = PaintingStyle.fill
      ..color = _accent;

    final spacing = morphology.antennaCount == 1
        ? 0.0
        : (morphology.antennaCount == 2 ? 0.18 : 0.22);
    final centerOffsets = switch (morphology.antennaCount) {
      1 => const [0.0],
      2 => [-spacing, spacing],
      _ => [-spacing, 0.0, spacing],
    };

    for (var i = 0; i < centerOffsets.length; i++) {
      final xOffset = centerOffsets[i] * w / 2;
      final base = Offset(xOffset, -hh + 1.0);
      final swayPhase = tau + i * 0.7;
      final sway = math.sin(swayPhase) * h * 0.012;

      Path path;
      Offset tip;
      switch (morphology.antennae) {
        case NodePetAntennaStyle.none:
          return;
        case NodePetAntennaStyle.straight:
          tip = Offset(base.dx + sway, base.dy - h * 0.25);
          path = Path()
            ..moveTo(base.dx, base.dy)
            ..lineTo(tip.dx, tip.dy);
        case NodePetAntennaStyle.curled:
          tip = Offset(base.dx + h * 0.10 + sway, base.dy - h * 0.22);
          path = Path()
            ..moveTo(base.dx, base.dy)
            ..quadraticBezierTo(
              base.dx + sway * 2,
              base.dy - h * 0.15,
              tip.dx,
              tip.dy,
            );
        case NodePetAntennaStyle.branched:
          tip = Offset(base.dx + sway, base.dy - h * 0.26);
          path = Path()
            ..moveTo(base.dx, base.dy)
            ..lineTo(tip.dx, tip.dy);
          // Two branch tips.
          canvas.drawLine(
            tip,
            Offset(tip.dx - h * 0.06, tip.dy - h * 0.06),
            paint,
          );
          canvas.drawLine(
            tip,
            Offset(tip.dx + h * 0.06, tip.dy - h * 0.06),
            paint,
          );
      }
      canvas.drawPath(path, paint);
      canvas.drawCircle(tip, 2.6, orb);
      // Glow halo on the orb.
      canvas.drawCircle(
        tip,
        4.5,
        Paint()
          ..color = _accent.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ---- Face ------------------------------------------------------------

  void _paintFace(Canvas canvas, double w, double h) {
    final hw = w / 2;
    final hh = h / 2;
    // Eye centres: a little above body centre.
    final eyeY = -hh * 0.10;
    final eyeDx = morphology.eyeSpacing * hw;
    final baseEyeR = morphology.eyeRadiusFactor * hh;

    // For tiny mode, simplify face to a pair of dot eyes — face must
    // still survive but with minimal detail.
    final eyeR = mode == PetRenderMode.tiny
        ? math.max(1.6, baseEyeR * 0.65)
        : baseEyeR;

    _paintEyes(canvas, eyeDx, eyeY, eyeR);

    // Skip mouth in tiny — the eyes alone carry the read.
    if (mode == PetRenderMode.tiny) return;

    final mouthY = morphology.mouthYFactor * hh;
    _paintMouth(canvas, mouthY, hw, hh);
  }

  void _paintEyes(Canvas canvas, double eyeDx, double eyeY, double eyeR) {
    final whitesPaint = Paint()..color = const Color(0xFFFAF6E9);
    final pupilPaint = Paint()..color = const Color(0xFF12131A);
    final shinePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9);

    // Compute eye shape modifiers from expression.
    final eyes = expression.eyes;

    // Sick: asymmetric — one eye half-closed.
    final closedRatios = switch (eyes) {
      NodePetEyeShape.open => const [0.0, 0.0],
      NodePetEyeShape.halfClosed => const [0.5, 0.5],
      NodePetEyeShape.closedSleeping => const [1.0, 1.0],
      NodePetEyeShape.wideAlert => const [-0.15, -0.15],
      NodePetEyeShape.sickAsymm => const [0.2, 0.65],
    };

    // Apply natural blink — lerp toward fully-closed for the duration
    // of the blink.
    final blinkClose = isBlinking
        ? math.sin(blinkProgress * math.pi).clamp(0.0, 1.0)
        : 0.0;

    for (var i = 0; i < 2; i++) {
      final sign = i == 0 ? -1.0 : 1.0;
      final cx = sign * eyeDx;
      final cy = eyeY;
      final close = (closedRatios[i] + blinkClose).clamp(-0.15, 1.0);

      // Closed: a soft curved line.
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

      // Open / partially-closed: clip oval whites to a half-rect.
      final eyeRect = Rect.fromCircle(
        center: Offset(cx, cy),
        radius: eyeR * 1.05,
      );
      final pupilSize =
          eyeR * (eyes == NodePetEyeShape.wideAlert ? 0.65 : 0.55);
      final visibleH = eyeR * 2 * (1.0 - close);
      final clipRect = Rect.fromCenter(
        center: Offset(cx, cy + (eyeR - visibleH / 2) * 0.4),
        width: eyeR * 2.4,
        height: math.max(1.0, visibleH * 1.1),
      );
      canvas.save();
      canvas.clipRect(clipRect);

      // Whites.
      canvas.drawOval(eyeRect, whitesPaint);

      // Pupil — slight downward droop in sad/halfClosed for empathy.
      final pupilDy =
          (eyes == NodePetEyeShape.halfClosed ||
              eyes == NodePetEyeShape.sickAsymm)
          ? eyeR * 0.18
          : 0.0;
      canvas.drawCircle(Offset(cx, cy + pupilDy), pupilSize, pupilPaint);

      // Shine.
      canvas.drawCircle(
        Offset(cx - pupilSize * 0.32, cy - pupilSize * 0.35 + pupilDy),
        pupilSize * 0.32,
        shinePaint,
      );
      canvas.restore();

      // Eye outline (subtle) — gives the eye a "lid" line that holds
      // up against busy bodies.
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = _accent.withValues(alpha: 0.55);
      canvas.drawOval(eyeRect, outline);
    }
  }

  void _paintMouth(Canvas canvas, double mouthY, double hw, double hh) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF15171F);
    final shape = expression.mouth;
    final mw = hw * 0.34;

    switch (shape) {
      case NodePetMouthShape.smile:
        final path = Path()
          ..moveTo(-mw, mouthY)
          ..quadraticBezierTo(0, mouthY + hh * 0.10, mw, mouthY);
        canvas.drawPath(path, paint);
      case NodePetMouthShape.smallSmile:
        final path = Path()
          ..moveTo(-mw * 0.65, mouthY)
          ..quadraticBezierTo(0, mouthY + hh * 0.06, mw * 0.65, mouthY);
        canvas.drawPath(path, paint);
      case NodePetMouthShape.neutral:
        canvas.drawLine(
          Offset(-mw * 0.6, mouthY),
          Offset(mw * 0.6, mouthY),
          paint,
        );
      case NodePetMouthShape.frown:
        final path = Path()
          ..moveTo(-mw * 0.7, mouthY + hh * 0.05)
          ..quadraticBezierTo(
            0,
            mouthY - hh * 0.05,
            mw * 0.7,
            mouthY + hh * 0.05,
          );
        canvas.drawPath(path, paint);
      case NodePetMouthShape.smallO:
        canvas.drawCircle(
          Offset(0, mouthY),
          hh * 0.06,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = paint.color,
        );
      case NodePetMouthShape.flat:
        canvas.drawLine(
          Offset(-mw * 0.5, mouthY),
          Offset(mw * 0.5, mouthY),
          paint,
        );
      case NodePetMouthShape.sickWobble:
        final wobble = math.sin(phase * math.pi * 6) * 1.2;
        final path = Path()
          ..moveTo(-mw * 0.7, mouthY)
          ..lineTo(-mw * 0.3, mouthY + wobble)
          ..lineTo(0, mouthY - wobble)
          ..lineTo(mw * 0.3, mouthY + wobble)
          ..lineTo(mw * 0.7, mouthY);
        canvas.drawPath(path, paint);
    }
  }

  // ---- Mood overlays ---------------------------------------------------

  void _paintMoodOverlay(
    Canvas canvas,
    Size size,
    Offset bodyCenter,
    double bodyHeight,
  ) {
    switch (expression.aura) {
      case NodePetAuraStyle.alertPulse:
        // Expanding pulse rings around the body.
        if (mode == PetRenderMode.tiny) return;
        final maxR = bodyHeight * 0.85;
        for (var i = 0; i < 2; i++) {
          final t = (phase + i * 0.5) % 1.0;
          final r = maxR * (0.55 + t * 0.7);
          final alpha = (1.0 - t) * 0.45;
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _primary.withValues(alpha: alpha);
          canvas.drawCircle(bodyCenter, r, paint);
        }
      case NodePetAuraStyle.sleeping:
        if (mode == PetRenderMode.tiny) return;
        _paintZzz(canvas, bodyCenter, bodyHeight);
      case NodePetAuraStyle.sickGlitch:
        if (mode == PetRenderMode.tiny) return;
        _paintSickGlitch(canvas, bodyCenter, bodyHeight);
      case NodePetAuraStyle.dormant:
        // Faint static "ghost" — desaturated low-alpha veil.
        final paint = Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..blendMode = BlendMode.srcATop;
        canvas.drawRect(Offset.zero & size, paint);
      case NodePetAuraStyle.calm:
      case NodePetAuraStyle.none:
        break;
    }
  }

  void _paintZzz(Canvas canvas, Offset bodyCenter, double bodyHeight) {
    // Three Zzz climbing top-right.
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t = (phase + i * 0.33) % 1.0;
      final scale = 1.0 - 0.5 * t;
      final origin = Offset(
        bodyCenter.dx + bodyHeight * 0.32 + bodyHeight * 0.05 * t,
        bodyCenter.dy - bodyHeight * 0.42 - bodyHeight * 0.20 * t,
      );
      final s = bodyHeight * 0.06 * scale;
      final alpha = (1.0 - t) * 0.85;
      paint.color = Colors.white.withValues(alpha: alpha);
      // Draw a "Z" — top, diagonal, bottom.
      final p1 = origin;
      final p2 = origin.translate(s, 0);
      final p3 = origin.translate(0, s);
      final p4 = origin.translate(s, s);
      canvas.drawLine(p1, p2, paint);
      canvas.drawLine(p2, p3, paint);
      canvas.drawLine(p3, p4, paint);
    }
  }

  void _paintSickGlitch(Canvas canvas, Offset bodyCenter, double bodyHeight) {
    // Faint horizontal scan-glitch bars over the body region.
    final tau = phase * math.pi * 2;
    final paint = Paint()..color = _accent.withValues(alpha: 0.25);
    for (var i = 0; i < 3; i++) {
      final phaseOff = (phase + i * 0.13) % 1.0;
      final y = bodyCenter.dy - bodyHeight * 0.5 + bodyHeight * phaseOff;
      final w = bodyHeight * (0.45 + 0.35 * math.sin(tau + i));
      final rect = Rect.fromCenter(
        center: Offset(bodyCenter.dx, y),
        width: w,
        height: 1.6,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NodePetPainter old) =>
      old.phase != phase ||
      old.morphology != morphology ||
      old.expression != expression ||
      old.palette != palette ||
      old.mode != mode ||
      old.stage != stage ||
      old.branch != branch ||
      old.vitality != vitality ||
      old.isBlinking != isBlinking ||
      old.blinkProgress != blinkProgress;
}
