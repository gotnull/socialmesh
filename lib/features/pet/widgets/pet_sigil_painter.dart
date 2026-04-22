// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet Sigil Painter — layered 2.5D renderer.
//
// The creature is a layered 2D composition staged to read as having
// depth without ever running a real 3D pipeline. Bottom-to-top layer
// order (each layer gates on [PetRenderMode] via [PetRenderContext]):
//
//   1. Ambient field      — halo + optional scanlines (home only)
//   2. Calling pulse      — attention-call ring ripple
//   3. Back plane         — silhouette of the core body, offset + dim,
//                           drawn larger — sells depth via drop shadow
//   4. Branch aura        — adult-onwards ambient effect
//   5. Hygiene artefacts  — stale-field marks behind the body
//   6. Petal orbit        — polygon of drifting accent dots
//   7. Core body          — primary polygon with off-center pseudo-light
//   8. Body highlight arc — thin upper-left specular edge (home only)
//   9. Face               — eyes + mouth
//  10. Zzz / Dormant veil — state overlays
//
// Parallax model:
//   - Every layer gets a phase-driven micro-drift. The back plane drifts
//     in counter-phase to the core, so the two extremes read as
//     counter-moving, which the brain interprets as depth.
//   - In [PetRenderMode.home] a normalized touch-parallax offset (-1..1
//     per axis) is piped through the painter. Amplitude scales with
//     layer depth (back × 0.4, core × 1.0, petal × 1.25) so the user
//     feels like they're looking into a tiny pocket dimension.
//
// Determinism: every visual element is derived either from the cached
// [PetSigilGeometry] (seed-stable) or from the [phase] / touch inputs.
// No per-paint PRNG, no system entropy.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../models/pet_enums.dart';
import 'pet_render_model.dart';

export 'pet_render_model.dart' show PetRenderMode;

/// Types of flourish the pet can spontaneously perform — a full Y-axis
/// spin, or a damped bottom-pivot wobble. Scheduled by
/// [_scheduleNextFlourish] and applied via [Transform] in the build.
enum _FlourishKind { spin, wobble }

/// Body-scale multiplier per life stage. Shared between the creature
/// painter and the static backdrop painter (which needs it to size the
/// ground-shadow ellipse without rotating with the creature).
double _stageScaleFor(PetStage s) {
  switch (s) {
    case PetStage.egg:
      return 0.65;
    case PetStage.juvenile:
      return 0.75;
    case PetStage.adolescent:
      return 0.9;
    case PetStage.adult:
      return 1.0;
    case PetStage.elder:
      return 0.95;
    case PetStage.dormant:
      return 0.7;
  }
}

/// Faint horizontal scanline grain — "pocket-space ambience". Drawn by
/// the static backdrop painter so it doesn't rotate with the creature.
void _drawScanlinesOnto(Canvas canvas, Size size) {
  final paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.035)
    ..strokeWidth = 1.0;
  const step = 6.0;
  for (var y = 0.0; y < size.height; y += step) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

/// Squashed ground-shadow ellipse anchoring the creature to a surface.
/// Sits on the static backdrop painter so it stays put when the
/// creature wobbles / spins — the ground doesn't rock with the pet.
void _drawGroundShadowOnto(Canvas canvas, Offset c, double r) {
  final groundCenter = Offset(c.dx + r * 0.08, c.dy + r * 0.95);
  final groundRect = Rect.fromCenter(
    center: groundCenter,
    width: r * 1.7,
    height: r * 0.34,
  );
  final groundPaint = Paint()
    ..shader = RadialGradient(
      colors: [
        Colors.black.withValues(alpha: 0.38),
        Colors.black.withValues(alpha: 0.0),
      ],
    ).createShader(groundRect)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
  canvas.drawOval(groundRect, groundPaint);
}

/// Static backdrop for the pet — scanlines + ground shadow. Painted
/// under the creature in the widget tree, OUTSIDE the wobble/spin/
/// squish transforms, so these "world" elements never follow the
/// creature's rocking motion.
class _PetBackdropPainter extends CustomPainter {
  final PetRenderMode mode;
  final PetStage stage;

  const _PetBackdropPainter({required this.mode, required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);
    final baseRadius = minSide * 0.28 * _stageScaleFor(stage);
    if (mode == PetRenderMode.home) {
      _drawScanlinesOnto(canvas, size);
    }
    if (mode != PetRenderMode.tiny) {
      _drawGroundShadowOnto(canvas, center, baseRadius);
    }
  }

  @override
  bool shouldRepaint(covariant _PetBackdropPainter old) =>
      old.mode != mode || old.stage != stage;
}

/// How long a tap burst lingers on-screen before fading out completely.
const Duration _kTapReactionDuration = Duration(milliseconds: 520);

/// How long the squish-pulse runs when the user taps the creature.
const Duration _kTapPulseDuration = Duration(milliseconds: 220);

/// One-shot "something-happened-here" visual effect. Lightweight value
/// type; the painter reads [position] in PetCreature-local coordinates
/// and animates a particle burst + expanding ring whose progress is
/// derived from `DateTime.now().difference(startAt)`.
///
/// Used both for user taps (full-strength, [intensity] = 1.0) and for
/// autonomous mood-driven self-reactions where [intensity] varies:
///   - excited (calling):   ~1.25 — big happy flourish
///   - content:             ~0.95 — relaxed sparkle
///   - sad / hungry:        ~0.55 — subdued shimmer
///   - sick / egg:          ~0.45 — tiny queasy/stirring puff
///   - asleep:              ~0.35 — dream-like whisper
@immutable
class _TapReaction {
  final Offset position;
  final DateTime startAt;
  final int index; // varies the seed angle per tap so adjacent taps don't
  // burst with identical particle rotation.
  final double intensity;
  // True only when the reaction originated from a real user tap. The
  // expanding ring component is gated on this so auto-reactions emit
  // sparkles without the iOS-ripple circle that reads as "I was touched".
  final bool isTap;
  const _TapReaction({
    required this.position,
    required this.startAt,
    required this.index,
    this.intensity = 1.0,
    this.isTap = false,
  });
}

/// Widget that renders the pet creature at the given [size]. Runs a
/// single [AnimationController] for the continuous idle loop; in
/// [PetRenderMode.home] it also tracks touch position to drive
/// interactive parallax.
class PetCreature extends StatefulWidget {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final int hygieneArtefactCount;
  final double size;

  /// Renderer profile — scales which depth layers, motion flourishes,
  /// and interactive features are enabled. Defaults to [PetRenderMode.home]
  /// so existing call sites that haven't opted in get the full richer
  /// treatment; NodeDex previews and companion cards explicitly set
  /// [PetRenderMode.tiny] / [PetRenderMode.card].
  final PetRenderMode mode;

  /// OPTIONAL raw stat values (0..[statMax]) used for subtle
  /// within-mood-bucket modulation of breath / buoyancy / aura / wobble.
  /// When null, the renderer falls back to a full-health baseline —
  /// which is what mini previews built from [PetPublicState] want, since
  /// that wire format only carries the derived mood class.
  final int? energy;
  final int? moodStat;
  final int? stability;
  final int statMax;

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
  });

  @override
  State<PetCreature> createState() => _PetCreatureState();
}

class _PetCreatureState extends State<PetCreature>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  /// Squish-pulse controller — fires on tap. Drives a brief scale
  /// 1.0 → 0.94 → 1.0 bounce so the creature feels squishy under touch.
  late final AnimationController _tapPulseController;
  late final Animation<double> _tapPulse;

  /// Target normalized parallax (-1..1 per axis) driven by touch. Only
  /// meaningful in [PetRenderMode.home].
  final ValueNotifier<Offset> _parallaxTarget = ValueNotifier(Offset.zero);

  /// Smoothed parallax — lerped each frame toward [_parallaxTarget]. We
  /// mutate this inside the AnimatedBuilder builder; the lerp rate is
  /// tuned to look like a light spring (no visible overshoot).
  Offset _parallaxCurrent = Offset.zero;

  /// Active tap / auto bursts. Bounded to a small MRU window — the
  /// painter filters out anything already past its 520 ms lifespan, and
  /// we cap the list so a mashing user can't grow it without bound.
  final List<_TapReaction> _tapReactions = [];
  int _nextTapIndex = 0;

  // --- Vitality modulation inputs ------------------------------------
  //
  // Normalised [0, 1] views of the raw stat props (or 1.0 — full health
  // — when the caller didn't supply a value). These feed the free
  // modulation helpers in pet_render_model.dart and the wobble
  // transform applied in build().
  double get _energyNorm => widget.energy == null
      ? 1.0
      : (widget.energy! / widget.statMax).clamp(0.0, 1.0);
  double get _moodStatNorm => widget.moodStat == null
      ? 1.0
      : (widget.moodStat! / widget.statMax).clamp(0.0, 1.0);
  double get _stabilityNorm => widget.stability == null
      ? 1.0
      : (widget.stability! / widget.statMax).clamp(0.0, 1.0);
  double get _vitality => (_energyNorm + _moodStatNorm + _stabilityNorm) / 3;

  /// Scheduler for autonomous mood-driven self-reactions. Fires at a
  /// random delay inside a mood-dependent window; reschedules itself on
  /// each tick. Null when the current state emits no auto-reactions
  /// (dormant stage, tiny render mode).
  Timer? _autoReactionTimer;
  final math.Random _autoRandom = math.Random();

  /// Flourish scheduler — picks between a 3D Y-axis spin and a bottom-
  /// pivot wobble at rare intervals. Independent of the sparkle
  /// scheduler so a single roll doesn't collide both effects.
  Timer? _flourishTimer;

  /// 3D-ish Y-axis spin (full 360° with perspective). Rare — reads as
  /// a playful "show off" gesture. Never runs while sick / asleep / egg.
  late final AnimationController _spinController;

  /// Damped side-to-side rotation around the bottom-center of the
  /// creature. Reads as a sway or a stir (for eggs). More common than
  /// the spin.
  late final AnimationController _wobbleController;

  late final Listenable _combined;

  @override
  void initState() {
    super.initState();
    // 5 s main cycle. The previous 8 s made everything breathe so
    // slowly the creature read as static between beats; 5 s gives a
    // visible idle tempo without being frantic. Per-layer multipliers
    // inside the painter desync breath / orbit / drift from each other
    // so the motion doesn't look robotically locked.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _tapPulseController = AnimationController(
      vsync: this,
      duration: _kTapPulseDuration,
    );
    // Squish → bounce-back envelope: down 40 % of the run, back up 60 %.
    // No overshoot so the creature doesn't jelly-wobble.
    _tapPulse =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 60),
        ]).animate(
          CurvedAnimation(
            parent: _tapPulseController,
            curve: Curves.easeOutCubic,
          ),
        );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _combined = Listenable.merge([
      _controller,
      _parallaxTarget,
      _tapPulseController,
      _spinController,
      _wobbleController,
    ]);
    _scheduleNextAutoReaction();
    _scheduleNextFlourish();
  }

  @override
  void dispose() {
    _autoReactionTimer?.cancel();
    _flourishTimer?.cancel();
    _controller.dispose();
    _tapPulseController.dispose();
    _spinController.dispose();
    _wobbleController.dispose();
    _parallaxTarget.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PetCreature old) {
    super.didUpdateWidget(old);
    // If anything affecting the mood window changed, cancel the pending
    // tick and re-roll with the new window immediately. Without this a
    // pet that just fell sick would still emit one last content-mood
    // happy sparkle before the sickness kicked in.
    if (old.mood != widget.mood ||
        old.isAsleep != widget.isAsleep ||
        old.isSick != widget.isSick ||
        old.isCalling != widget.isCalling ||
        old.stage != widget.stage ||
        old.mode != widget.mode) {
      _scheduleNextAutoReaction();
      _scheduleNextFlourish();
    }
  }

  // --- Interactive parallax ------------------------------------------

  void _applyParallaxFromGlobal(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return;
    _parallaxTarget.value = Offset(
      ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
      ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  void _releaseParallax() {
    _parallaxTarget.value = Offset.zero;
  }

  /// Full tap-down handler: parallax nudge + haptic + squish + particle
  /// burst. Only fires on discrete taps (not pan), so dragging the pet
  /// around stays quiet.
  void _handleTapDown(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Parallax nudge (same behaviour as before).
    _parallaxTarget.value = Offset(
      ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
      ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
    );

    // 2. Haptic — a light tap pulse to confirm the hit.
    unawaited(HapticFeedback.lightImpact());

    // 3. Squish pulse.
    _tapPulseController.forward(from: 0);

    // 4. Particle burst at the tap point.
    _tapReactions.add(
      _TapReaction(
        position: local,
        startAt: DateTime.now(),
        index: _nextTapIndex++,
        isTap: true,
      ),
    );
    // MRU cap — keep at most 6 concurrent bursts.
    if (_tapReactions.length > 6) {
      _tapReactions.removeRange(0, _tapReactions.length - 6);
    }
    // No setState needed — the main controller ticks every frame while
    // it's repeating, which drives the AnimatedBuilder below, which
    // picks up the new reaction on the next paint.
  }

  // --- Autonomous self-reactions -------------------------------------

  /// Pick the next random delay from the current mood's window and arm
  /// a one-shot timer. On fire, spawn a reaction and reschedule — so
  /// the cadence stays organic (not a fixed heartbeat) and the stream
  /// is naturally self-correcting when state changes.
  void _scheduleNextAutoReaction() {
    _autoReactionTimer?.cancel();
    // Tiny / card modes stay quiet — previews shouldn't constantly
    // sparkle next to every NodeDex row, and a companion card isn't
    // the focus of attention.
    if (widget.mode != PetRenderMode.home) return;
    final window = _autoReactionWindow();
    if (window == null) return;
    final (minMs, maxMs) = window;
    final delay = minMs + _autoRandom.nextInt(maxMs - minMs);
    _autoReactionTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _fireAutoReaction();
      _scheduleNextAutoReaction();
    });
  }

  /// Mood-driven delay window in milliseconds, or null when the current
  /// state emits no auto-reactions. Returned as (min, max) — the
  /// scheduler rolls a uniform random inside the range each cycle so
  /// the pet never feels clocklike.
  (int, int)? _autoReactionWindow() {
    if (widget.stage == PetStage.dormant) return null;
    if (widget.isAsleep) return (30000, 60000);
    if (widget.stage == PetStage.egg) return (6000, 12000);
    if (widget.isSick) return (18000, 35000);
    if (widget.isCalling) return (3500, 8000);
    switch (widget.mood) {
      case PetMood.content:
        return (5000, 11000);
      case PetMood.calling:
        return (3500, 8000);
      case PetMood.hungry:
      case PetMood.sad:
        return (13000, 26000);
      case PetMood.sick:
        return (18000, 35000);
      case PetMood.sleeping:
        return (30000, 60000);
    }
  }

  /// Visual loudness of the auto-reaction for the current state. 1.0 is
  /// the user-tap baseline; higher = bigger/brighter, lower = softer.
  double _autoReactionIntensity() {
    if (widget.stage == PetStage.dormant) return 0;
    if (widget.isAsleep) return 0.35;
    if (widget.stage == PetStage.egg) return 0.55;
    if (widget.isSick) return 0.45;
    if (widget.isCalling) return 1.25;
    switch (widget.mood) {
      case PetMood.content:
        return 0.95;
      case PetMood.calling:
        return 1.25;
      case PetMood.hungry:
      case PetMood.sad:
        return 0.55;
      case PetMood.sick:
        return 0.45;
      case PetMood.sleeping:
        return 0.35;
    }
  }

  void _fireAutoReaction() {
    final intensity = _autoReactionIntensity();
    if (intensity <= 0) return;

    // Random position within the creature's body circle. Slightly
    // inset from the edge so reactions don't float in dead space.
    final size = widget.size;
    final center = Offset(size / 2, size / 2);
    final bodyRadius = size * 0.30;
    final angle = _autoRandom.nextDouble() * math.pi * 2;
    final dist = _autoRandom.nextDouble() * bodyRadius * 0.9;
    final position =
        center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);

    _tapReactions.add(
      _TapReaction(
        position: position,
        startAt: DateTime.now(),
        index: _nextTapIndex++,
        intensity: intensity,
      ),
    );
    if (_tapReactions.length > 6) {
      _tapReactions.removeRange(0, _tapReactions.length - 6);
    }
  }

  // --- Flourishes: spin + wobble -------------------------------------
  //
  // The auto-reaction scheduler emits particle bursts. This second
  // scheduler runs on its own slower cadence and picks between a full
  // 360° Y-axis spin (rare, showy) and a damped bottom-pivot sway
  // (common, stirring/swaying). Kept deliberately sparse — cute beats
  // constant.

  void _scheduleNextFlourish() {
    _flourishTimer?.cancel();
    if (widget.mode != PetRenderMode.home) return;
    final window = _flourishWindow();
    if (window == null) return;
    final (minMs, maxMs) = window;
    final delay = minMs + _autoRandom.nextInt(maxMs - minMs);
    _flourishTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _performFlourish();
      _scheduleNextFlourish();
    });
  }

  /// Delay window for the next flourish in milliseconds. Deliberately
  /// slower than the sparkle scheduler so these feel like special
  /// moments, not tics. Null = no flourishes in this state.
  (int, int)? _flourishWindow() {
    if (widget.stage == PetStage.dormant) return null;
    if (widget.isAsleep) return null;
    if (widget.isSick) return (25000, 50000);
    if (widget.stage == PetStage.egg) return (10000, 20000);
    if (widget.isCalling) return (8000, 15000);
    switch (widget.mood) {
      case PetMood.content:
        return (12000, 22000);
      case PetMood.calling:
        return (8000, 15000);
      case PetMood.hungry:
      case PetMood.sad:
        return (20000, 40000);
      case PetMood.sick:
        return (25000, 50000);
      case PetMood.sleeping:
        return null;
    }
  }

  void _performFlourish() {
    // Egg / sick / subdued states can only wobble — spins are for
    // confident creatures showing off, not for someone nauseous.
    final canSpin =
        !widget.isSick &&
        widget.stage != PetStage.egg &&
        !widget.isAsleep &&
        widget.mood != PetMood.hungry &&
        widget.mood != PetMood.sad;
    // 30% spin, 70% wobble when both are available — keeps spins rare
    // enough to feel special.
    final kind = canSpin && _autoRandom.nextDouble() < 0.3
        ? _FlourishKind.spin
        : _FlourishKind.wobble;
    switch (kind) {
      case _FlourishKind.spin:
        if (_spinController.isAnimating) return;
        _spinController.forward(from: 0);
      case _FlourishKind.wobble:
        if (_wobbleController.isAnimating) return;
        _wobbleController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.mode == PetRenderMode.home;

    Widget canvas = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _combined,
        builder: (context, _) {
          // Smooth parallax toward the target every frame. Lerp factor
          // tuned for a gentle spring-back on release; higher = snappier.
          const lerp = 0.18;
          _parallaxCurrent = Offset.lerp(
            _parallaxCurrent,
            _parallaxTarget.value,
            lerp,
          )!;
          final geometry = PetSigilGeometry.forIdentity(
            dnaSeed: widget.dnaSeed,
            stage: widget.stage,
            branch: widget.branch,
          );
          final renderContext = PetRenderContext(
            mode: widget.mode,
            stage: widget.stage,
            branch: widget.branch,
            mood: widget.mood,
            isAsleep: widget.isAsleep,
            isSick: widget.isSick,
            isCalling: widget.isCalling,
            hygieneArtefactCount: widget.hygieneArtefactCount,
            phase: _controller.value,
            parallaxNormalized: interactive ? _parallaxCurrent : Offset.zero,
            energyNorm: _energyNorm,
            moodStatNorm: _moodStatNorm,
            stabilityNorm: _stabilityNorm,
          );
          // Filter out expired tap bursts each frame — the painter
          // receives only the currently-alive ones, and the source list
          // only grows when new taps arrive (MRU cap handles rollover).
          final now = DateTime.now();
          final liveReactions = _tapReactions
              .where((r) => now.difference(r.startAt) < _kTapReactionDuration)
              .toList(growable: false);
          // Build the creature painter core first …
          Widget creature = CustomPaint(
            painter: _PetCreaturePainter(
              context: renderContext,
              geometry: geometry,
              tapReactions: liveReactions,
              tapReactionDuration: _kTapReactionDuration,
            ),
            size: Size.square(widget.size),
          );
          // … tap squish (existing).
          creature = Transform.scale(scale: _tapPulse.value, child: creature);
          // … damped bottom-pivot wobble. Envelope is
          // sin(2π·2.5·t)·(1−t): 2.5 oscillations over the run with
          // amplitude decaying to 0 at the end, so it closes cleanly
          // with no snap-back.
          final wobbleT = _wobbleController.value;
          if (wobbleT > 0 && wobbleT < 1) {
            // Peak is ±10° × wobble-amplitude-scale (vitality band
            // 0.85..1.05). Stays within mood-bucket feel.
            final wobbleAngle =
                math.sin(wobbleT * math.pi * 2 * 2.5) *
                (1 - wobbleT) *
                0.18 *
                petWobbleAmplitudeScale(_vitality);
            creature = Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.rotationZ(wobbleAngle),
              child: creature,
            );
          }
          // … 3D Y-axis spin. Perspective (setEntry 3,2) gives the
          // rotation visible depth instead of a flat X-mirror.
          final spinT = _spinController.value;
          if (spinT > 0 && spinT < 1) {
            final eased = Curves.easeInOutCubic.transform(spinT);
            final spinAngle = eased * math.pi * 2;
            creature = Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(spinAngle),
              child: creature,
            );
          }
          // Stack: static backdrop (scanlines + ground shadow) under
          // the transformed creature. The backdrop sits outside every
          // transform in `creature`, so it stays put when the pet
          // squishes / wobbles / spins — the "world behind the pet"
          // doesn't rock with the pet.
          return RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PetBackdropPainter(
                      mode: widget.mode,
                      stage: widget.stage,
                    ),
                    size: Size.square(widget.size),
                  ),
                ),
                creature,
              ],
            ),
          );
        },
      ),
    );

    if (interactive) {
      canvas = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _handleTapDown(d.globalPosition),
        onTapUp: (_) => _releaseParallax(),
        onTapCancel: _releaseParallax,
        onPanStart: (d) => _applyParallaxFromGlobal(d.globalPosition),
        onPanUpdate: (d) => _applyParallaxFromGlobal(d.globalPosition),
        onPanEnd: (_) => _releaseParallax(),
        onPanCancel: _releaseParallax,
        child: canvas,
      );
    }

    return canvas;
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

/// Per-layer parallax amplitude multipliers. Back plane moves least,
/// petal ring moves most — the differential IS the depth illusion.
class _ParallaxDepth {
  static const double back = 0.4;
  static const double core = 1.0;
  static const double petal = 1.25;
}

/// Maximum pixel amplitude for interactive parallax, expressed as a
/// fraction of the canvas minSide. Small on purpose — the effect is
/// premium when subtle, tacky when pronounced.
const double _kInteractiveParallaxAmp = 0.04;

/// Baseline micro-drift amplitude (no user touch) as a fraction of the
/// canvas minSide. Tuned to be visible-but-not-distracting at the home
/// size (≈5 px at 220 px canvas); the previous 0.008 worked out to
/// ≈1.7 px which read as static on-device.
const double _kIdleDriftAmp = 0.022;

class _PetCreaturePainter extends CustomPainter {
  final PetRenderContext context;
  final PetSigilGeometry geometry;
  final List<_TapReaction> tapReactions;
  final Duration tapReactionDuration;

  _PetCreaturePainter({
    required this.context,
    required this.geometry,
    this.tapReactions = const [],
    this.tapReactionDuration = _kTapReactionDuration,
  });

  // Convenience aliases.
  PetStage get stage => context.stage;
  PetBranch get branch => context.branch;
  PetMood get mood => context.mood;
  bool get isAsleep => context.isAsleep;
  bool get isSick => context.isSick;
  bool get isCalling => context.isCalling;
  int get hygieneArtefactCount => context.hygieneArtefactCount;
  double get phase => context.phase;
  int get dnaSeed => geometry.dnaSeed;
  PetRenderPalette get palette => geometry.palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);

    final stageScale = _stageScale(stage);
    final baseRadius = minSide * 0.28 * stageScale;
    final auraRadius = minSide * 0.45 * stageScale;
    final petalOrbit = minSide * 0.36 * stageScale;

    final breath = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
    final breathGain = _breathingAmplitude();
    final effectiveBody = baseRadius * (1.0 + breath * breathGain);

    // Layer phase offsets — each layer's drift has its OWN phase shift
    // so peaks/valleys don't land on the same frame across layers. The
    // composition pulses polyrhythmically, breaking the "robotic
    // lockstep" read. Constant offsets preserve wrap continuity because
    // sin(2π·(1 + k)) == sin(2π·k) for any k.
    final backPhase = phase;
    final corePhase = (phase + 0.17) % 1.0;
    final petalPhase = (phase + 0.41) % 1.0;

    // Idle drift — a slow XY float applied to every layer with depth-
    // scaled amplitude. Back plane drifts opposite to the core for
    // counter-motion that reads as depth.
    final idleBackOffset = _idleDrift(backPhase, minSide, invertY: true);
    final idleCoreOffset = _idleDrift(corePhase, minSide);
    final idlePetalOffset = _idleDrift(petalPhase, minSide);

    // Interactive parallax — only non-zero in home mode with touch.
    final touch = context.parallaxNormalized;
    final maxInteractive = minSide * _kInteractiveParallaxAmp;
    final interactiveBack = touch * maxInteractive * _ParallaxDepth.back;
    final interactiveCore = touch * maxInteractive * _ParallaxDepth.core;
    final interactivePetal = touch * maxInteractive * _ParallaxDepth.petal;

    final backOffset = idleBackOffset + interactiveBack;
    final coreOffset = idleCoreOffset + interactiveCore;
    final petalOffset = idlePetalOffset + interactivePetal;

    // Egg-specific heartbeat rock — applied to the core-body transform
    // only (back plane stays still so the shell "shakes" relative to its
    // shadow).
    final isEgg = stage == PetStage.egg;
    final heartbeat = isEgg ? math.sin(phase * math.pi * 2 * 2.0) : 0.0;
    final eggBounce = isEgg ? heartbeat * minSide * 0.018 : 0.0;
    final eggTilt = isEgg ? heartbeat * 0.08 : 0.0;

    // ---- Layer 1: Ambient field -------------------------------------
    // Scanlines and the ground-shadow ellipse live on the static
    // `_PetBackdropPainter` (drawn below in the widget tree, outside
    // the wobble/spin transforms) so they don't rock with the
    // creature. The halo stays here because it's radially symmetric
    // and centered on the creature — rotation is visually invisible.
    _drawAmbientField(canvas, center, auraRadius, breath);

    // ---- Layer 2: Calling pulse -------------------------------------
    if (isCalling) {
      _drawCallingPulse(canvas, center, auraRadius, phase);
    }

    // ---- Layer 3: Back plane silhouette ------------------------------
    if (context.includesBackPlane()) {
      _drawBackPlane(canvas, center + backOffset, effectiveBody);
    }

    // ---- Layer 4: Branch aura ---------------------------------------
    if (context.includesBranchAura() &&
        (stage == PetStage.adult ||
            stage == PetStage.elder ||
            stage == PetStage.dormant)) {
      _drawBranchAura(canvas, center + coreOffset, auraRadius, phase);
    }

    // ---- Layer 5: Hygiene artefacts ---------------------------------
    _drawHygieneArtefacts(canvas, center + coreOffset, minSide);

    // ---- Layer 6a: Petal orbit (back half, behind body) -------------
    // Drawn outside the body transform so petals orbit independently of
    // the body's sickness jitter and egg rock.
    final petalAlpha = _petalAlpha();
    if (context.includesPetalOrbit()) {
      _drawPetalOrbit(
        canvas,
        center + petalOffset,
        petalOrbit,
        phase,
        alpha: petalAlpha,
        front: false,
      );
    }

    // Body transform — jitter on sickness + egg rock.
    final applyBodyTransform = isSick || isEgg;
    if (applyBodyTransform) {
      canvas.save();
      if (isSick) {
        final jitter = _jitter(phase);
        canvas.translate(jitter.dx, jitter.dy);
      }
      if (isEgg) {
        canvas.translate(0, eggBounce);
        canvas.translate(center.dx, center.dy);
        canvas.rotate(eggTilt);
        canvas.translate(-center.dx, -center.dy);
      }
    }

    // ---- Layer 7: Core body + pseudo-lighting -----------------------
    _drawCoreBody(canvas, center + coreOffset, effectiveBody);

    // ---- Layer 8: Body highlight arc --------------------------------
    if (context.includesBodyHighlightArc() && !isAsleep && !isEgg) {
      _drawBodyHighlightArc(canvas, center + coreOffset, effectiveBody);
    }

    // ---- Layer 9: Face ----------------------------------------------
    _drawFace(canvas, center + coreOffset, effectiveBody);

    if (applyBodyTransform) canvas.restore();

    // ---- Layer 6b: Petal orbit (front half, in front of body+face) --
    // The front pass carries the 3D read: large, opaque petals swinging
    // around the front of the silhouette, occluding its edge. Depth-
    // scaled size/alpha happens inside _drawPetalOrbit.
    if (context.includesPetalOrbit()) {
      _drawPetalOrbit(
        canvas,
        center + petalOffset,
        petalOrbit,
        phase,
        alpha: petalAlpha,
        front: true,
      );
    }

    // ---- Layer 10: Zzz / Dormant veil -------------------------------
    if (isAsleep || stage == PetStage.egg) {
      _drawZzz(canvas, center, minSide, phase);
    }
    if (stage == PetStage.dormant) {
      _drawDormantVeil(canvas, size);
    }

    // ---- Layer 11: Tap reaction bursts ------------------------------
    // Drawn last so sparkles sit on top of everything. Each burst is
    // self-contained (reads its own progress from DateTime) and is
    // culled upstream in the State before it reaches the painter.
    if (tapReactions.isNotEmpty) {
      final now = DateTime.now();
      for (final reaction in tapReactions) {
        _drawTapReaction(canvas, reaction, now, minSide);
      }
    }
  }

  // ---- Drift + shape helpers ----------------------------------------

  Offset _idleDrift(
    double layerPhase,
    double minSide, {
    bool invertX = false,
    bool invertY = false,
  }) {
    // Buoyancy modulation — within-mood secondary nudge driven by the
    // composite vitality scalar. Healthier pets bob more; fading pets
    // barely stir. Band 0.80..1.15.
    final amp = minSide * _kIdleDriftAmp * petBuoyancyScale(context.vitality);
    // Multi-frequency sinusoid — fundamental + integer harmonics so the
    // whole curve closes exactly at phase=1 (no wrap blip), but the sum
    // reads as organic non-clocklike wander instead of a pure ellipse.
    // The previous cos(t * 0.8) DIDN'T close: cos(1.6π) ≠ cos(0), which
    // produced a visible Y-jump every cycle. Harmonic constants are
    // integer multiples of the base freq so continuity holds.
    final t = layerPhase * math.pi * 2;
    final dx =
        amp *
        (math.sin(t) + 0.45 * math.sin(t * 2 + 1.1) + 0.25 * math.sin(t * 3));
    final dy =
        amp *
        (math.cos(t) +
            0.35 * math.cos(t * 2 - 0.8) +
            0.2 * math.cos(t * 3 + 0.4));
    return Offset(invertX ? -dx : dx, invertY ? -dy : dy);
  }

  double _stageScale(PetStage s) => _stageScaleFor(s);

  /// Breath amplitude, delegated to the pure modulation helper so the
  /// policy (per-mood baseline × vitality band) has a single canonical
  /// definition that tests can pin directly.
  double _breathingAmplitude() =>
      petBreathAmplitude(mood, stage, context.vitality);

  double _petalAlpha() {
    if (stage == PetStage.egg) return 0.0;
    if (stage == PetStage.dormant) return 0.2;
    if (isAsleep) return 0.35;
    switch (branch) {
      case PetBranch.luminous:
        return 0.95;
      case PetBranch.steady:
        return 0.75;
      case PetBranch.volatile:
        return 0.9;
      case PetBranch.dimmed:
        return 0.45;
      case PetBranch.unborn:
        return 0.6;
    }
  }

  Offset _jitter(double phase) {
    // Fast tremor (8 full cycles per 5 s ≈ 1.6 Hz shake). Both axes
    // use integer multiples of 2π so they close at the wrap — the
    // previous `cos(t * 1.3)` snapped Y by ~2 px every cycle.
    final t = phase * math.pi * 16;
    return Offset(math.sin(t) * 1.6, math.cos(t * 2) * 1.2);
  }

  /// Build a body polygon path at [r], centred on [c], using the cached
  /// unit-angles from [geometry]. Callers can reuse the returned Path
  /// (e.g. for the core body + its drop-shadow back plane).
  Path _bodyPath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < geometry.coreVertexCount; i++) {
      final angle = geometry.coreAngles[i];
      final pt = Offset(c.dx + math.cos(angle) * r, c.dy + math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  // ---- Draw helpers --------------------------------------------------

  void _drawAmbientField(Canvas canvas, Offset c, double r, double breath) {
    // Halo gradient — the creature's atmospheric aura.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.primary.withValues(alpha: 0.22 + 0.08 * breath),
          palette.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, glow);
  }

  void _drawCallingPulse(Canvas canvas, Offset c, double maxR, double phase) {
    for (var i = 0; i < 2; i++) {
      final t = (phase + i * 0.5) % 1.0;
      final r = maxR * (0.6 + t * 0.7);
      // Bell envelope so the ring fades in AND out each cycle — no
      // alpha/radius jump at the wrap point.
      final alpha = math.sin(math.pi * t) * 0.45;
      if (alpha <= 0.01) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = palette.primary.withValues(alpha: alpha);
      canvas.drawCircle(c, r, paint);
    }
  }

  /// Offset silhouette drop shadow — the creature's own shadow that
  /// follows it around (and rocks with it under wobble/spin, which is
  /// physically correct). The separate ground-shadow ellipse that
  /// anchors the creature to a surface lives on `_PetBackdropPainter`
  /// so it stays still when the creature rocks.
  void _drawBackPlane(Canvas canvas, Offset c, double r) {
    final shadowOffset = Offset(r * 0.20, r * 0.26);
    final shadowR = r * 1.10;
    final shadowCenter = c + shadowOffset;
    final path = _bodyPath(shadowCenter, shadowR);
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawPath(path, paint);
  }

  void _drawBranchAura(Canvas canvas, Offset c, double maxR, double phase) {
    if (isAsleep) return;
    // Stability-driven aura scaling — a rock-stable pet's aura reads
    // slightly brighter, a wobbling pet's aura dims. Multiplies every
    // alpha in this layer uniformly. Band 0.75..1.10.
    final aura = petAuraIntensityScale(context.stabilityNorm);
    switch (branch) {
      case PetBranch.luminous:
        final ringR = maxR * (0.88 + 0.08 * math.sin(phase * math.pi * 2));
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = palette.primary.withValues(
            alpha: (0.35 * aura).clamp(0.0, 1.0),
          );
        canvas.drawCircle(c, ringR, paint);
        final accent = Paint()
          ..style = PaintingStyle.fill
          ..color = AccentColors.yellow.withValues(
            alpha: (0.85 * aura).clamp(0.0, 1.0),
          );
        for (var i = 0; i < 4; i++) {
          // Full 2π rotation per cycle — previous 0.5π rotation caused a
          // visible 90° snap-back at the wrap point even though the 4
          // pip positions are symmetric.
          final angle = phase * math.pi * 2 + i * math.pi / 2;
          final pip = Offset(
            c.dx + math.cos(angle) * ringR,
            c.dy + math.sin(angle) * ringR,
          );
          canvas.drawCircle(pip, 1.8, accent);
        }
      case PetBranch.steady:
        for (var i = 0; i < 2; i++) {
          final t = (phase + i * 0.5) % 1.0;
          final r = maxR * (0.78 + 0.05 * math.sin(t * math.pi * 2));
          final alpha = (0.22 + 0.05 * math.cos(t * math.pi * 2)) * aura;
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = palette.primary.withValues(alpha: alpha.clamp(0.0, 1.0));
          canvas.drawCircle(c, r, paint);
        }
      case PetBranch.volatile:
        for (var i = 0; i < 3; i++) {
          final t = (phase + i * 0.33) % 1.0;
          // Bell envelope (continuous, no triangle-wrap blip).
          final bright = math.sin(math.pi * t);
          if (bright <= 0.05) continue;
          // Seed gives a per-spark starting offset; phase rotates it so
          // the spark slides around the rim instead of flashing in a
          // fixed position.
          final h = dnaSeed ^ (i * 0xC2B2AE35);
          final seedRot = ((h & 0xFFFF) / 0xFFFF) * math.pi * 2;
          final angle = seedRot + phase * math.pi * 2;
          final r1 = maxR * 0.82;
          final r2 = maxR * 0.98;
          final start = Offset(
            c.dx + math.cos(angle) * r1,
            c.dy + math.sin(angle) * r1,
          );
          final end = Offset(
            c.dx + math.cos(angle + 0.22) * r2,
            c.dy + math.sin(angle + 0.22) * r2,
          );
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = palette.primary.withValues(
              alpha: (0.75 * bright * aura).clamp(0.0, 1.0),
            );
          canvas.drawLine(start, end, paint);
        }
      case PetBranch.dimmed:
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AccentColors.slate.withValues(
            alpha: (0.22 * aura).clamp(0.0, 1.0),
          );
        canvas.drawCircle(c, maxR * 0.86, paint);
      case PetBranch.unborn:
        return;
    }
  }

  /// Petal orbit as a depth-scaled ring. Each petal's size and alpha
  /// scale with `(sin(theta) + 1)/2` — "front" petals (orbiting toward
  /// the viewer at the bottom of the circle) are ~3× larger and fully
  /// opaque; "back" petals are small and dim. This IS the 3D read; a
  /// flat equal-size ring looks like a 2D polygon.
  ///
  /// Called twice per paint with [front] = false (behind the body) then
  /// [front] = true (in front of the face). The connecting link ring
  /// is drawn on the back pass only so it sits behind the body.
  void _drawPetalOrbit(
    Canvas canvas,
    Offset c,
    double orbit,
    double phase, {
    required double alpha,
    required bool front,
  }) {
    if (alpha <= 0.0) return;
    final drift = phase * math.pi * 2;

    final positions = <Offset>[];
    final depths = <double>[];
    for (var i = 0; i < geometry.petalCount; i++) {
      final baseAngle = geometry.petalAngles[i];
      final theta = baseAngle + drift;
      final wobble = 1.0 + 0.04 * math.sin(phase * math.pi * 2 + i);
      positions.add(
        Offset(
          c.dx + math.cos(theta) * orbit * wobble,
          c.dy + math.sin(theta) * orbit * wobble,
        ),
      );
      // 0 at the top of the orbit (far from viewer), 1 at the bottom
      // (nearest). Sell depth by scaling petal size + alpha off this.
      depths.add((math.sin(theta) + 1) / 2);
    }

    // Link ring on the back pass only — subtle, behind body.
    if (!front) {
      final linkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = palette.accent.withValues(alpha: alpha * 0.35);
      for (var i = 0; i < positions.length; i++) {
        final a = positions[i];
        final b = positions[(i + 1) % positions.length];
        canvas.drawLine(a, b, linkPaint);
      }
    }

    final baseSize = math.max(1.4, orbit * 0.03);
    for (var i = 0; i < positions.length; i++) {
      final d = depths[i];
      final isFront = d > 0.5;
      if (isFront != front) continue;
      final petalSize = baseSize * (0.55 + 1.9 * d);
      final petalAlpha = alpha * (0.3 + 0.7 * d);
      final petalPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = palette.petal.withValues(alpha: petalAlpha);
      canvas.drawCircle(positions[i], petalSize, petalPaint);
    }
  }

  /// Core body with pseudo-lighting. When the mode supports off-center
  /// lighting the radial gradient focus is shifted toward the upper-left,
  /// producing a highlighted side and a shadowed side — reads as volume.
  /// In [PetRenderMode.tiny] we fall back to a centred gradient to keep
  /// small-scale rendering crisp.
  void _drawCoreBody(Canvas canvas, Offset c, double r) {
    final path = _bodyPath(c, r);

    // Fill — off-center radial gradient simulates a soft light source
    // from the upper-left.
    final rect = Rect.fromCircle(center: c, radius: r);
    final lightOffset = context.includesOffCenterBodyLight()
        ? Alignment(-0.45, -0.45)
        : Alignment.center;
    final fill = Paint()
      ..shader = RadialGradient(
        center: lightOffset,
        radius: 0.9,
        colors: [
          _brighten(palette.primary, 0.25).withValues(alpha: 0.98),
          palette.primary.withValues(alpha: 0.95),
          palette.accent.withValues(alpha: 0.55),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, fill);

    // Outline.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = palette.primary.withValues(alpha: 0.85);
    canvas.drawPath(path, outline);

    // Branch micro-etch.
    if (branch == PetBranch.luminous || branch == PetBranch.steady) {
      final etch = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = palette.accent.withValues(alpha: 0.5);
      for (var i = 0; i < geometry.coreVertexCount; i++) {
        if (i % 2 == 0) continue;
        final angle = geometry.coreAngles[i];
        final pt = Offset(
          c.dx + math.cos(angle) * r,
          c.dy + math.sin(angle) * r,
        );
        canvas.drawLine(c, pt, etch);
      }
    }
    // Elder crystalline frost ring.
    if (stage == PetStage.elder) {
      final frost = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = palette.accent.withValues(alpha: 0.7);
      canvas.drawCircle(c, r * 0.6, frost);
    }
  }

  /// Thin specular arc at the upper-left edge of the body polygon.
  /// Drawn as a clipped stroke along an inset body path segment so it
  /// hugs the true silhouette rather than a perfect circle.
  void _drawBodyHighlightArc(Canvas canvas, Offset c, double r) {
    canvas.save();
    // Clip to the body polygon so the highlight never bleeds outside.
    final clip = _bodyPath(c, r * 1.0);
    canvas.clipPath(clip);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..color = Colors.white.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    // Arc along the upper-left quadrant of an inset ellipse.
    final rect = Rect.fromCircle(center: c, radius: r * 0.92);
    const startAngle = math.pi * 1.05;
    const sweep = math.pi * 0.55;
    canvas.drawArc(rect, startAngle, sweep, false, paint);
    canvas.restore();
  }

  void _drawFace(Canvas canvas, Offset c, double r) {
    if (stage == PetStage.egg) return;
    // In tiny mode the face becomes a simpler two-dot glyph without the
    // mouth — preserves readability when rendered at ~32 px.
    final tiny = context.mode == PetRenderMode.tiny;
    final eyeOffsetX = r * 0.28;
    final eyeOffsetY = -r * 0.05;
    final eyeR = math.max(1.8, r * 0.08);
    final eyePaint = Paint()..color = _onCanvasText();

    if (isAsleep) {
      final closed = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _onCanvasText();
      final dx = eyeOffsetX;
      for (final sign in [-1.0, 1.0]) {
        final left = Offset(c.dx + sign * dx - eyeR, c.dy + eyeOffsetY);
        final right = Offset(c.dx + sign * dx + eyeR, c.dy + eyeOffsetY);
        final mid = Offset(
          (left.dx + right.dx) / 2,
          (left.dy + right.dy) / 2 + eyeR * 0.6,
        );
        final path = Path()
          ..moveTo(left.dx, left.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, right.dx, right.dy);
        canvas.drawPath(path, closed);
      }
    } else {
      canvas.drawCircle(
        Offset(c.dx - eyeOffsetX, c.dy + eyeOffsetY),
        eyeR,
        eyePaint,
      );
      canvas.drawCircle(
        Offset(c.dx + eyeOffsetX, c.dy + eyeOffsetY),
        eyeR,
        eyePaint,
      );
    }

    if (tiny) return;

    final mouthPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = _onCanvasText();
    final mx = c.dx;
    final my = c.dy + r * 0.28;
    final path = Path();
    switch (mood) {
      case PetMood.content:
      case PetMood.calling:
        path.moveTo(mx - r * 0.14, my);
        path.quadraticBezierTo(mx, my + r * 0.08, mx + r * 0.14, my);
      case PetMood.hungry:
      case PetMood.sad:
        path.moveTo(mx - r * 0.12, my + r * 0.04);
        path.quadraticBezierTo(mx, my - r * 0.05, mx + r * 0.12, my + r * 0.04);
      case PetMood.sick:
        path.moveTo(mx - r * 0.14, my);
        path.lineTo(mx - r * 0.06, my + r * 0.04);
        path.lineTo(mx + r * 0.02, my);
        path.lineTo(mx + r * 0.1, my + r * 0.04);
        path.lineTo(mx + r * 0.16, my);
      case PetMood.sleeping:
        path.moveTo(mx - r * 0.08, my);
        path.lineTo(mx + r * 0.08, my);
    }
    canvas.drawPath(path, mouthPaint);
  }

  void _drawZzz(Canvas canvas, Offset c, double minSide, double phase) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t = ((phase * 1.5) + i * 0.33) % 1.0;
      // Bell envelope — each glyph fades in AND out over its lifetime
      // so adjacent Zs overlap softly instead of popping in/out at the
      // wrap point.
      final env = math.sin(math.pi * t);
      if (env <= 0.02) continue;
      final x = c.dx + minSide * 0.22 + t * minSide * 0.06;
      final y = c.dy - minSide * 0.18 - t * minSide * 0.12;
      final s = minSide * 0.04 * (0.6 + 0.4 * env);
      final path = Path()
        ..moveTo(x - s, y - s)
        ..lineTo(x + s, y - s)
        ..lineTo(x - s, y + s)
        ..lineTo(x + s, y + s);
      canvas.drawPath(
        path,
        paint..color = _onCanvasText().withValues(alpha: 0.7 * env),
      );
    }
  }

  void _drawDormantVeil(Canvas canvas, Size size) {
    final veil = Paint()..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawRect(Offset.zero & size, veil);
  }

  void _drawHygieneArtefacts(Canvas canvas, Offset c, double minSide) {
    if (hygieneArtefactCount <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AccentColors.slate.withValues(alpha: 0.8);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = AccentColors.slate.withValues(alpha: 0.3);
    for (var i = 0; i < hygieneArtefactCount.clamp(0, 3); i++) {
      final h = dnaSeed ^ (i * 0x9E3779B1);
      final angle = (h & 0xFFFF) / 0xFFFF * math.pi * 2;
      final dist = minSide * (0.38 + ((h >> 16) & 0xFF) / 0xFF * 0.08);
      final p = Offset(
        c.dx + math.cos(angle) * dist,
        c.dy + math.sin(angle) * dist,
      );
      const r = 5.0;
      canvas.drawCircle(p, r, fill);
      canvas.drawCircle(p, r, paint);
      canvas.drawLine(
        Offset(p.dx - r * 0.5, p.dy),
        Offset(p.dx + r * 0.5, p.dy),
        paint,
      );
      canvas.drawLine(
        Offset(p.dx, p.dy - r * 0.5),
        Offset(p.dx, p.dy + r * 0.5),
        paint,
      );
    }
  }

  /// Draw one tap-burst at its current progress. Two components:
  ///   - An expanding ring stroke (iOS-ripple vibe) that zooms out.
  ///   - Eight accent-coloured sparkle dots radiating in all directions,
  ///     shrinking + fading as they fly outward.
  /// Both derive their progress from real time so that many concurrent
  /// bursts stay independent even if paints are delayed.
  void _drawTapReaction(
    Canvas canvas,
    _TapReaction reaction,
    DateTime now,
    double minSide,
  ) {
    final elapsedUs = now.difference(reaction.startAt).inMicroseconds;
    final durationUs = tapReactionDuration.inMicroseconds;
    if (durationUs <= 0) return;
    final t = (elapsedUs / durationUs).clamp(0.0, 1.0);
    if (t >= 1.0) return;

    // Ease-out-cubic so the burst shoots out fast then settles.
    final ease = 1.0 - math.pow(1.0 - t, 3).toDouble();
    final intensity = reaction.intensity;
    // Amplitude + sparkle size scale with the creature so tiny-mode
    // previews get subtle bursts and the home view gets real oomph;
    // intensity scales them further so an excited "calling" flourish
    // reads bigger than a sleepy dream-shimmer.
    final maxDist = minSide * 0.22 * intensity;

    // Ring is reserved for real user taps — auto-reactions emit sparkles
    // only, so the creature doesn't look like it's being poked by ghosts.
    if (reaction.isTap) {
      final ringAlpha = (1.0 - t).clamp(0.0, 1.0) * 0.75 * intensity;
      if (ringAlpha > 0.01) {
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: ringAlpha.clamp(0.0, 1.0));
        canvas.drawCircle(reaction.position, ease * maxDist * 0.75, ringPaint);
      }
    }

    // Sparkle burst — seed-rotated so adjacent bursts don't mirror.
    // Particle count scales with intensity so tired/quiet reactions are
    // noticeably sparser than excited ones.
    final n = intensity >= 1.0
        ? 8
        : intensity >= 0.6
        ? 6
        : 4;
    final seedAngle = (reaction.index * 0.41) % 1.0 * math.pi * 2;
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      final angle = seedAngle + i * math.pi * 2 / n;
      final dist = ease * maxDist;
      final pos = Offset(
        reaction.position.dx + math.cos(angle) * dist,
        reaction.position.dy + math.sin(angle) * dist,
      );
      final sparkSize = (minSide * 0.018) * intensity * (1.0 - t);
      if (sparkSize <= 0.2) continue;
      final sparkAlpha = (1.0 - t * t).clamp(0.0, 1.0);
      // Alternate palette.accent and palette.petal per particle for a
      // two-tone confetti feel.
      sparkPaint.color = (i % 2 == 0 ? palette.accent : palette.petal)
          .withValues(alpha: sparkAlpha);
      canvas.drawCircle(pos, sparkSize, sparkPaint);
    }
  }

  Color _onCanvasText() => Colors.white.withValues(alpha: 0.92);

  /// Lighten a colour toward white by [t] (0..1). Used for the body's
  /// off-center highlight stop without needing an extra palette entry.
  Color _brighten(Color base, double t) {
    final r = (base.r * 255 + (255 - base.r * 255) * t).round().clamp(0, 255);
    final g = (base.g * 255 + (255 - base.g * 255) * t).round().clamp(0, 255);
    final b = (base.b * 255 + (255 - base.b * 255) * t).round().clamp(0, 255);
    return Color.fromARGB((base.a * 255).round(), r, g, b);
  }

  @override
  bool shouldRepaint(covariant _PetCreaturePainter oldDelegate) {
    final oc = oldDelegate.context;
    final nc = context;
    return oldDelegate.geometry.renderKey != geometry.renderKey ||
        oc.mode != nc.mode ||
        oc.mood != nc.mood ||
        oc.isAsleep != nc.isAsleep ||
        oc.isSick != nc.isSick ||
        oc.isCalling != nc.isCalling ||
        oc.hygieneArtefactCount != nc.hygieneArtefactCount ||
        oc.phase != nc.phase ||
        oc.parallaxNormalized != nc.parallaxNormalized ||
        !identical(oldDelegate.tapReactions, tapReactions);
  }
}
