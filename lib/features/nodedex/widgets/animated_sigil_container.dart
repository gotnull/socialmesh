// SPDX-License-Identifier: GPL-3.0-or-later

// Animated Sigil Container — orchestrates multi-layer sigil animations.
//
// This widget manages multiple AnimationControllers to drive the
// AnimatedSigilPainter through its animation phases:
//
// Phase 1 — REVEAL (plays once on mount)
//   Edges draw on sequentially, vertex dots materialize, center dot
//   fades in last. Duration: ~1.8 seconds.
//
// Phase 2 — AMBIENT (loops after reveal completes)
//   - Slow rotation: outer ring rotates forward, inner rings
//     counter-rotate. Full cycle: ~25 seconds.
//   - Breathing pulse: vertex dots twinkle with staggered timing.
//     Cycle: ~3.5 seconds, reverses.
//   - Glow modulation: outer glow breathes in sync with pulse
//     but at a slightly different rate. Cycle: ~4 seconds.
//   - Edge tracer (optional): a bright signal dot traverses
//     all edges. Cycle: ~8 seconds.
//
// The widget respects reduced motion preferences via
// MediaQuery.disableAnimations. When reduced motion is active,
// the sigil renders fully revealed with no ambient animation.
//
// Usage:
// ```dart
// AnimatedSigilContainer(
//   nodeNum: entry.nodeNum,
//   size: 200,
//   showTracer: true,
//   trait: traitResult.primary,
// )
// ```

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/nodedex_entry.dart';
import '../models/sigil_evolution.dart';
import '../services/sigil_generator.dart';
import 'animated_sigil_painter.dart';

/// Animation mode for the container.
enum SigilAnimationMode {
  /// Full animation: reveal then ambient loops.
  full,

  /// Ambient only: skip reveal, start with fully visible sigil.
  ambientOnly,

  /// Reveal only: draw-on animation then stop.
  revealOnly,

  /// Static: no animation at all (equivalent to the basic SigilWidget).
  none,
}

/// Orchestrating widget that manages animation controllers and drives
/// [AnimatedSigilPainter] through reveal and ambient animation phases.
///
/// Accepts either a [SigilData] directly or a [nodeNum] to generate one.
/// All animation parameters are configurable and the widget handles
/// controller lifecycle, phase transitions, and reduced-motion support.
class AnimatedSigilContainer extends StatefulWidget {
  /// Pre-computed sigil data. If null, generated from [nodeNum].
  final SigilData? sigil;

  /// Node number for sigil generation. Ignored if [sigil] is provided.
  final int? nodeNum;

  /// Rendered size (width and height are equal).
  final double size;

  /// Animation mode controlling which phases run.
  final SigilAnimationMode mode;

  /// Whether to run the edge tracer animation during ambient phase.
  final bool showTracer;

  /// Whether to render the outer glow effect.
  final bool showGlow;

  /// Whether to render the circular border.
  final bool showBorder;

  /// Optional trait for the colored ring around the sigil.
  final NodeTrait? trait;

  /// Optional evolution state for visual maturity effects.
  /// If null, the sigil renders with default (seed-level) appearance.
  final SigilEvolution? evolution;

  /// Base opacity (0.0 → 1.0). Useful for cross-fading.
  final double opacity;

  /// Optional background color behind the sigil.
  final Color? backgroundColor;

  /// Callback fired when the reveal animation completes.
  final VoidCallback? onRevealComplete;

  /// Duration of the reveal (draw-on) animation.
  final Duration revealDuration;

  /// Duration of one full ambient rotation cycle.
  final Duration rotationDuration;

  /// Duration of one pulse/breathe cycle (reverses).
  final Duration pulseDuration;

  /// Duration of one glow breathe cycle (reverses).
  final Duration glowDuration;

  /// Duration of one full tracer traversal.
  final Duration tracerDuration;

  const AnimatedSigilContainer({
    super.key,
    this.sigil,
    this.nodeNum,
    this.size = 120,
    this.mode = SigilAnimationMode.full,
    this.showTracer = false,
    this.showGlow = true,
    this.showBorder = false,
    this.trait,
    this.evolution,
    this.opacity = 1.0,
    this.backgroundColor,
    this.onRevealComplete,
    this.revealDuration = const Duration(milliseconds: 1000),
    this.rotationDuration = const Duration(milliseconds: 25000),
    this.pulseDuration = const Duration(milliseconds: 3500),
    this.glowDuration = const Duration(milliseconds: 4000),
    this.tracerDuration = const Duration(milliseconds: 8000),
  }) : assert(
         sigil != null || nodeNum != null,
         'Either sigil or nodeNum must be provided',
       );

  @override
  State<AnimatedSigilContainer> createState() => _AnimatedSigilContainerState();
}

class _AnimatedSigilContainerState extends State<AnimatedSigilContainer>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  /// Draw-on reveal animation (plays once, forward).
  AnimationController? _revealController;

  /// Continuous ambient rotation.
  AnimationController? _rotationController;

  /// Vertex dot pulse / breathe cycle (repeats with reverse).
  AnimationController? _pulseController;

  /// Glow intensity breathe cycle (repeats with reverse).
  AnimationController? _glowController;

  /// Edge tracer traversal (repeats, forward only).
  AnimationController? _tracerController;

  // ---------------------------------------------------------------------------
  // Derived animations
  // ---------------------------------------------------------------------------

  late Animation<double> _revealAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _tracerAnimation;

  /// Whether the ambient phase has started.
  bool _ambientStarted = false;

  /// Resolved sigil data.
  late SigilData _sigil;

  /// Whether animations are suppressed due to reduced motion or static mode.
  bool _reducedMotion = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _sigil = widget.sigil ?? SigilGenerator.generate(widget.nodeNum!);
    _initAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check reduced motion preference from platform.
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations != _reducedMotion) {
      _reducedMotion = disableAnimations;
      _syncAnimationState();
    }
  }

  @override
  void didUpdateWidget(AnimatedSigilContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Regenerate sigil if identity changed.
    final newSigil = widget.sigil ?? SigilGenerator.generate(widget.nodeNum!);
    final identityChanged =
        newSigil.vertices != _sigil.vertices ||
        newSigil.rotation != _sigil.rotation ||
        newSigil.innerRings != _sigil.innerRings ||
        newSigil.drawRadials != _sigil.drawRadials ||
        newSigil.centerDot != _sigil.centerDot ||
        newSigil.symmetryFold != _sigil.symmetryFold ||
        newSigil.primaryColor != _sigil.primaryColor;

    if (identityChanged) {
      _sigil = newSigil;
    }

    // Handle mode changes.
    if (widget.mode != oldWidget.mode) {
      _disposeControllers();
      _ambientStarted = false;
      _initAnimations();
    }

    // Handle tracer toggle.
    if (widget.showTracer != oldWidget.showTracer) {
      if (widget.showTracer && _ambientStarted && !_reducedMotion) {
        _startTracer();
      } else {
        _stopTracer();
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Animation setup
  // ---------------------------------------------------------------------------

  void _initAnimations() {
    final isStatic = widget.mode == SigilAnimationMode.none || _reducedMotion;

    if (isStatic) {
      _initStaticValues();
      return;
    }

    final hasReveal =
        widget.mode == SigilAnimationMode.full ||
        widget.mode == SigilAnimationMode.revealOnly;

    final hasAmbient =
        widget.mode == SigilAnimationMode.full ||
        widget.mode == SigilAnimationMode.ambientOnly;

    // --- Reveal ---
    if (hasReveal) {
      _revealController = AnimationController(
        vsync: this,
        duration: widget.revealDuration,
      );
      _revealAnimation = CurvedAnimation(
        parent: _revealController!,
        curve: Curves.easeOutCubic,
      );
      _revealController!.addStatusListener(_onRevealStatus);
    } else {
      _revealAnimation = const AlwaysStoppedAnimation(1.0);
    }

    // --- Ambient controllers (created but not started until reveal done) ---
    if (hasAmbient) {
      _rotationController = AnimationController(
        vsync: this,
        duration: widget.rotationDuration,
      );
      _rotationAnimation = Tween<double>(begin: 0.0, end: math.pi * 2.0)
          .animate(
            CurvedAnimation(parent: _rotationController!, curve: Curves.linear),
          );

      _pulseController = AnimationController(
        vsync: this,
        duration: widget.pulseDuration,
      );
      _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );

      _glowController = AnimationController(
        vsync: this,
        duration: widget.glowDuration,
      );
      _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );

      if (widget.showTracer) {
        _tracerController = AnimationController(
          vsync: this,
          duration: widget.tracerDuration,
        );
        _tracerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _tracerController!, curve: Curves.linear),
        );
      } else {
        _tracerAnimation = const AlwaysStoppedAnimation(-1.0);
      }
    } else {
      _rotationAnimation = const AlwaysStoppedAnimation(0.0);
      _pulseAnimation = const AlwaysStoppedAnimation(0.0);
      _glowAnimation = const AlwaysStoppedAnimation(0.5);
      _tracerAnimation = const AlwaysStoppedAnimation(-1.0);
    }

    // --- Start ---
    if (hasReveal) {
      _revealController!.forward();

      // If mode is ambientOnly, skip reveal (already handled above).
    }

    if (!hasReveal && hasAmbient) {
      // No reveal phase — start ambient immediately.
      _startAmbient();
    }
  }

  void _initStaticValues() {
    _revealAnimation = const AlwaysStoppedAnimation(1.0);
    _rotationAnimation = const AlwaysStoppedAnimation(0.0);
    _pulseAnimation = const AlwaysStoppedAnimation(0.0);
    _glowAnimation = const AlwaysStoppedAnimation(0.5);
    _tracerAnimation = const AlwaysStoppedAnimation(-1.0);
  }

  // ---------------------------------------------------------------------------
  // Phase transitions
  // ---------------------------------------------------------------------------

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onRevealComplete?.call();

      if (widget.mode == SigilAnimationMode.full) {
        _startAmbient();
      }
    }
  }

  void _startAmbient() {
    if (_ambientStarted || _reducedMotion) return;
    _ambientStarted = true;

    _rotationController?.repeat();
    _pulseController?.repeat(reverse: true);
    _glowController?.repeat(reverse: true);

    if (widget.showTracer) {
      _startTracer();
    }
  }

  void _startTracer() {
    if (_tracerController != null) {
      _tracerController!.repeat();
      return;
    }

    // Create tracer controller on demand if it wasn't created at init.
    _tracerController = AnimationController(
      vsync: this,
      duration: widget.tracerDuration,
    );
    _tracerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tracerController!, curve: Curves.linear),
    );
    _tracerController!.repeat();
  }

  void _stopTracer() {
    _tracerController?.stop();
    _tracerController?.dispose();
    _tracerController = null;
    _tracerAnimation = const AlwaysStoppedAnimation(-1.0);
  }

  /// Sync animation state after a reduced motion change.
  void _syncAnimationState() {
    if (_reducedMotion) {
      // Stop all animations and snap to final state.
      _revealController?.value = 1.0;
      _revealController?.stop();
      _rotationController?.stop();
      _pulseController?.stop();
      _glowController?.stop();
      _tracerController?.stop();
    } else if (_ambientStarted) {
      // Re-enable ambient animations.
      _rotationController?.repeat();
      _pulseController?.repeat(reverse: true);
      _glowController?.repeat(reverse: true);
      if (widget.showTracer) {
        _tracerController?.repeat();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void _disposeControllers() {
    _revealController?.removeStatusListener(_onRevealStatus);
    _revealController?.dispose();
    _revealController = null;

    _rotationController?.dispose();
    _rotationController = null;

    _pulseController?.dispose();
    _pulseController = null;

    _glowController?.dispose();
    _glowController = null;

    _tracerController?.dispose();
    _tracerController = null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Collect all active listenables for the AnimatedBuilder.
  Listenable _mergedListenable() {
    final listenables = <Listenable>[];

    if (_revealController != null) listenables.add(_revealController!);
    if (_rotationController != null) listenables.add(_rotationController!);
    if (_pulseController != null) listenables.add(_pulseController!);
    if (_glowController != null) listenables.add(_glowController!);
    if (_tracerController != null) listenables.add(_tracerController!);

    if (listenables.isEmpty) {
      // No active controllers — return a dummy listenable that never fires.
      return const _NeverListenable();
    }
    if (listenables.length == 1) return listenables.first;
    return Listenable.merge(listenables);
  }

  @override
  Widget build(BuildContext context) {
    final traitColor = widget.trait?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        widget.backgroundColor ??
        (isDark
            ? _sigil.primaryColor.withValues(alpha: 0.08)
            : _sigil.primaryColor.withValues(alpha: 0.05));

    final isAnimating =
        widget.mode != SigilAnimationMode.none && !_reducedMotion;

    // For static mode, render directly without AnimatedBuilder overhead.
    if (!isAnimating) {
      return _buildContainer(
        bgColor: bgColor,
        traitColor: traitColor,
        child: _buildPainter(
          revealProgress: 1.0,
          rotationDelta: 0.0,
          pulsePhase: 0.0,
          glowIntensity: widget.showGlow ? 0.5 : 0.0,
          tracePosition: -1.0,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _mergedListenable(),
      builder: (context, _) {
        return _buildContainer(
          bgColor: bgColor,
          traitColor: traitColor,
          child: _buildPainter(
            revealProgress: _revealAnimation.value,
            rotationDelta: _rotationAnimation.value,
            pulsePhase: _pulseAnimation.value,
            glowIntensity: widget.showGlow ? _glowAnimation.value : 0.0,
            tracePosition: _tracerAnimation.value,
          ),
        );
      },
    );
  }

  Widget _buildContainer({
    required Color bgColor,
    required Color? traitColor,
    required Widget child,
  }) {
    final size = widget.size;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: traitColor != null
            ? Border.all(color: traitColor.withValues(alpha: 0.5), width: 2.0)
            : Border.all(
                color: _sigil.primaryColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
        boxShadow: widget.showGlow
            ? [
                BoxShadow(
                  color: _sigil.primaryColor.withValues(
                    alpha:
                        0.15 +
                        0.1 *
                            (widget.mode != SigilAnimationMode.none &&
                                    !_reducedMotion
                                ? _glowAnimation.value
                                : 0.5),
                  ),
                  blurRadius: size * 0.25,
                  spreadRadius: size * 0.03,
                ),
              ]
            : null,
      ),
      child: Padding(padding: EdgeInsets.all(size * 0.18), child: child),
    );
  }

  Widget _buildPainter({
    required double revealProgress,
    required double rotationDelta,
    required double pulsePhase,
    required double glowIntensity,
    required double tracePosition,
  }) {
    final innerSize = widget.size * 0.64;

    return CustomPaint(
      size: Size(innerSize, innerSize),
      painter: AnimatedSigilPainter(
        sigil: _sigil,
        revealProgress: revealProgress,
        rotationDelta: rotationDelta,
        pulsePhase: pulsePhase,
        glowIntensity: glowIntensity,
        tracePosition: tracePosition,
        opacity: widget.opacity,
        showGlow: widget.showGlow,
        showBorder: widget.showBorder,
        evolution: widget.evolution,
      ),
    );
  }
}

// =============================================================================
// Utility
// =============================================================================

/// A [Listenable] that never notifies — used as a no-op when there are no
/// active animation controllers so we can still provide a non-null listenable
/// to AnimatedBuilder without allocating a real controller.
class _NeverListenable implements Listenable {
  const _NeverListenable();

  @override
  void addListener(VoidCallback listener) {
    // No-op: this listenable never fires.
  }

  @override
  void removeListener(VoidCallback listener) {
    // No-op.
  }
}
