// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet renderer mode + deterministic geometry model.
//
// The pet uses ONE layered painter scaled by [PetRenderMode]. The same
// painter backs tiny NodeDex-row previews, card-sized companion
// renderings, and the owner home screen — by reading the mode flag the
// painter decides which depth layers to include and how rich the motion
// may be.
//
// [PetSigilGeometry] is the per-creature precomputed shape pack. Because
// geometry depends only on `(dnaSeed, stage, branch)` we cache it in a
// tiny LRU so repeated paints (especially for the home screen's 10 Hz
// animation ticker and NodeDex list scrolling) never recompute the same
// trig / bit mixing. The cache hot path is one Map lookup.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../models/pet_enums.dart';

/// Rendering mode — governs which depth layers and motion flourishes the
/// painter produces. One painter scales across all three.
enum PetRenderMode {
  /// NodeDex row / avatar miniature (~32 px). Minimal layers, no
  /// interactive parallax, no scanlines, no petal orbit, no front shards.
  /// Preserves back plane + off-center body so depth still reads.
  tiny,

  /// Companion card / detail tile (~64–96 px). All baseline layers + front
  /// shards + soft pseudo-lighting. No interactive parallax.
  card,

  /// Owner home screen (~220–320 px). Full treatment — all layers, scanlines,
  /// edge highlights, interactive touch parallax supported.
  home,
}

/// Seed-derived palette for a pet. Independent of mode — the painter dims
/// or tints at render time via alpha/opacity, not via palette variants.
@immutable
class PetRenderPalette {
  final Color primary;
  final Color accent;
  final Color petal;

  const PetRenderPalette({
    required this.primary,
    required this.accent,
    required this.petal,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PetRenderPalette &&
          primary == other.primary &&
          accent == other.accent &&
          petal == other.petal);

  @override
  int get hashCode => Object.hash(primary, accent, petal);
}

/// Precomputed deterministic geometry for a pet. Keyed by
/// `(dnaSeed, stage, branch)`. Contains everything the painter needs to
/// render a creature without redoing bit-mix / trig work each frame.
@immutable
class PetSigilGeometry {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;

  /// Unit-angle list for the core body polygon — length [coreVertexCount].
  final List<double> coreAngles;

  /// Base angles for the petal orbit — length [petalCount].
  final List<double> petalAngles;

  /// Seed-rotated global orientation for the body polygon.
  final double bodyRotation;

  final int coreVertexCount;
  final int petalCount;

  final PetRenderPalette palette;

  const PetSigilGeometry._({
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.coreAngles,
    required this.petalAngles,
    required this.bodyRotation,
    required this.coreVertexCount,
    required this.petalCount,
    required this.palette,
  });

  /// Build (or fetch from cache) the geometry for the given identity.
  /// Allocation-free on cache hit.
  factory PetSigilGeometry.forIdentity({
    required int dnaSeed,
    required PetStage stage,
    required PetBranch branch,
  }) {
    return _PetGeometryCache.instance.getOrCompute(
      dnaSeed: dnaSeed,
      stage: stage,
      branch: branch,
    );
  }

  /// Compact key useful for tests / debug / custom painter shouldRepaint
  /// checks. Same `(seed, stage, branch)` → identical key.
  int get renderKey => Object.hash(dnaSeed, stage.index, branch.index);
}

/// Everything a single paint() needs beyond the geometry: mode, animation
/// phase, and state flags. Lightweight value type; constructing one per
/// paint is cheap.
@immutable
class PetRenderContext {
  final PetRenderMode mode;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final int hygieneArtefactCount;

  /// Continuous animation phase in [0, 1). Wraps.
  final double phase;

  /// Normalized interactive parallax offset in [-1, 1] per axis. Zero
  /// outside [PetRenderMode.home] or when no touch is active.
  final Offset parallaxNormalized;

  /// Normalized raw stat values in [0, 1]. OPTIONAL — these drive a
  /// subtle secondary modulation of breath amplitude, idle drift
  /// buoyancy, branch-aura intensity, and wobble-flourish amplitude
  /// WITHIN the active mood bucket. The primary visual contract remains
  /// [mood] + the flag set; raw stats never push the visual across a
  /// mood-class boundary (see `petBreathAmplitude` bucket-preservation
  /// tests).
  ///
  /// Default: 1.0 (full health baseline). Callers that don't have raw
  /// stats (e.g. mini previews built from [PetPublicState], which only
  /// carries the derived mood class) keep the baseline look.
  final double energyNorm;
  final double moodStatNorm;
  final double stabilityNorm;

  const PetRenderContext({
    required this.mode,
    required this.stage,
    required this.branch,
    required this.mood,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.hygieneArtefactCount,
    required this.phase,
    this.parallaxNormalized = Offset.zero,
    this.energyNorm = 1.0,
    this.moodStatNorm = 1.0,
    this.stabilityNorm = 1.0,
  });

  /// Composite health scalar in [0, 1] — mean of the three stat norms.
  /// The painter feeds this into breath / buoyancy / wobble modulation
  /// helpers so their per-mood baselines are nudged slightly up (high
  /// vitality) or down (low vitality) without crossing bucket lines.
  double get vitality =>
      ((energyNorm + moodStatNorm + stabilityNorm) / 3).clamp(0.0, 1.0);

  /// Whether the given conceptual layer is enabled for the current mode.
  /// Kept as a small switch so the painter's per-layer guards stay
  /// readable and the mode→layer policy is centralised.
  bool includesScanlines() => mode == PetRenderMode.home;
  bool includesBackPlane() => mode != PetRenderMode.tiny;
  bool includesPetalOrbit() => mode != PetRenderMode.tiny;
  bool includesBranchAura() => mode != PetRenderMode.tiny;
  bool includesBodyHighlightArc() => mode == PetRenderMode.home;
  bool includesInteractiveParallax() => mode == PetRenderMode.home;
  bool includesOffCenterBodyLight() => mode != PetRenderMode.tiny;
}

// ---------------------------------------------------------------------------
// Raw-stat modulation helpers
// ---------------------------------------------------------------------------
//
// Pure functions — free-standing so they're testable without constructing
// a painter. The painter delegates to them so modulation policy lives in
// exactly one place.
//
// Range discipline: every helper is designed so the modulation band of
// one mood never overlaps the modulation band of an adjacent mood. The
// primary visual contract (PetMood bucket → recognisable motion signature)
// must survive any combination of raw stat values; modulation only
// supplies within-bucket nuance.

/// Per-mood/per-stage baseline breath amplitude. Egg stage overrides
/// mood with a dedicated baseline (the shell pulses regardless of what
/// mood the inner creature is in).
double _moodBaseBreath(PetMood mood, PetStage stage) {
  if (stage == PetStage.egg) return 0.10;
  switch (mood) {
    case PetMood.sleeping:
      return 0.04;
    case PetMood.content:
      return 0.06;
    case PetMood.calling:
      return 0.12;
    case PetMood.hungry:
    case PetMood.sad:
      return 0.03;
    case PetMood.sick:
      return 0.02;
  }
}

/// Breath amplitude with vitality modulation. Band is 0.90× (vitality=0)
/// to 1.10× (vitality=1) of the mood baseline — deliberately tight. The
/// ±10% band is the widest value for which the closest baseline gap
/// (hungry/sad=0.03 → sleeping=0.04) is still strictly preserved at
/// extremal vitality. A wider band would let a max-stat hungry pet
/// out-breathe a min-stat sleeping pet, which breaks the mood contract.
double petBreathAmplitude(PetMood mood, PetStage stage, double vitality) {
  final base = _moodBaseBreath(mood, stage);
  final v = vitality.clamp(0.0, 1.0);
  return base * (0.90 + 0.20 * v);
}

/// Idle-drift amplitude multiplier. Healthier pets bob a little more in
/// their idle float; tired pets barely stir. Band 0.80..1.15.
double petBuoyancyScale(double vitality) {
  return 0.80 + 0.35 * vitality.clamp(0.0, 1.0);
}

/// Branch-aura alpha multiplier driven by stability only. An unstable
/// pet's aura reads dimmer and less confident; a rock-stable pet's aura
/// edges brighter. Band 0.75..1.10.
double petAuraIntensityScale(double stabilityNorm) {
  return 0.75 + 0.35 * stabilityNorm.clamp(0.0, 1.0);
}

/// Wobble-flourish peak-angle multiplier. Very subtle band (0.85..1.05)
/// — the wobble is already state-gated at the scheduler level; this
/// only modulates peak amplitude within "the pet decided to wobble".
double petWobbleAmplitudeScale(double vitality) {
  return 0.85 + 0.20 * vitality.clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Geometry cache
// ---------------------------------------------------------------------------

/// Tiny LRU keyed on `(seed, stage, branch)`. Capacity chosen to cover
/// the worst observable concurrent render count (one home creature,
/// one companion card, plus ~10 NodeDex list rows visible at once) with
/// a little headroom.
class _PetGeometryCache {
  static final _PetGeometryCache instance = _PetGeometryCache._();
  _PetGeometryCache._();

  static const int _capacity = 24;
  final LinkedHashMap<int, PetSigilGeometry> _entries =
      LinkedHashMap<int, PetSigilGeometry>();

  PetSigilGeometry getOrCompute({
    required int dnaSeed,
    required PetStage stage,
    required PetBranch branch,
  }) {
    final key = Object.hash(dnaSeed, stage.index, branch.index);
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit; // re-insert at tail (most-recent)
      return hit;
    }
    final computed = _compute(dnaSeed: dnaSeed, stage: stage, branch: branch);
    _entries[key] = computed;
    if (_entries.length > _capacity) {
      _entries.remove(_entries.keys.first);
    }
    AppLogging.pet(
      'PetGeometryCache: miss seed=0x${dnaSeed.toRadixString(16)} '
      'stage=${stage.name} branch=${branch.name} size=${_entries.length}',
    );
    return computed;
  }

  @visibleForTesting
  void clearForTest() => _entries.clear();

  @visibleForTesting
  int get sizeForTest => _entries.length;

  PetSigilGeometry _compute({
    required int dnaSeed,
    required PetStage stage,
    required PetBranch branch,
  }) {
    // Seed-derived scalars.
    final coreVertexCount = 5 + ((dnaSeed >> 3) & 0x03); // 5..8
    final petalCount = 3 + ((dnaSeed >> 17) & 0x07); // 3..10
    final bodyRotation = ((dnaSeed >> 13) & 0xFFFF) / 0xFFFF * math.pi * 2;

    // Core angles — evenly distributed ring, pre-offset by -π/2 so the
    // first vertex sits at the top. Keeps downstream trig simple.
    final coreAngles = List<double>.generate(
      coreVertexCount,
      (i) => bodyRotation + (i * math.pi * 2 / coreVertexCount) - math.pi / 2,
      growable: false,
    );

    final petalAngles = List<double>.generate(
      petalCount,
      (i) => bodyRotation + (i * math.pi * 2 / petalCount),
      growable: false,
    );

    final palette = _buildPalette(dnaSeed: dnaSeed, branch: branch);

    return PetSigilGeometry._(
      dnaSeed: dnaSeed,
      stage: stage,
      branch: branch,
      coreAngles: coreAngles,
      petalAngles: petalAngles,
      bodyRotation: bodyRotation,
      coreVertexCount: coreVertexCount,
      petalCount: petalCount,
      palette: palette,
    );
  }

  PetRenderPalette _buildPalette({
    required int dnaSeed,
    required PetBranch branch,
  }) {
    late Color primary;
    late Color accent;
    switch (branch) {
      case PetBranch.luminous:
        primary = AccentColors.yellow;
        accent = AccentColors.sky;
      case PetBranch.steady:
        primary = AccentColors.emerald;
        accent = AccentColors.teal;
      case PetBranch.volatile:
        primary = AccentColors.orange;
        accent = AccentColors.pink;
      case PetBranch.dimmed:
        primary = AccentColors.slate;
        accent = AccentColors.lavender;
      case PetBranch.unborn:
        primary = AppTheme.primaryPurple;
        accent = AccentColors.sky;
    }
    const petalChoices = [
      AccentColors.cyan,
      AccentColors.lavender,
      AccentColors.pink,
      AccentColors.teal,
      AccentColors.lime,
      AccentColors.coral,
      AccentColors.indigo,
      AccentColors.rose,
    ];
    final petal = petalChoices[(dnaSeed >> 9) & 0x07];
    return PetRenderPalette(primary: primary, accent: accent, petal: petal);
  }
}
