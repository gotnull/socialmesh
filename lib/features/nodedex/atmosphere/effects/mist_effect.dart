// SPDX-License-Identifier: GPL-3.0-or-later

// Mist Effect — drifting fog particles driven by sparse data regions.
//
// Mist manifests as soft, translucent blobs that drift slowly across
// the viewport. The effect intensity is tied to the fraction of nodes
// with sparse data — nodes classified as "ghost" or "unknown" traits,
// or nodes with very few encounters relative to their age. A mesh
// full of mystery produces thicker fog.
//
// Visual characteristics:
//   - Large soft radial gradient blobs (ParticleShape.blob)
//   - Very low alpha — more felt than seen
//   - Slow horizontal drift with slight vertical oscillation
//   - Blobs overlap to create organic fog density variations
//   - Larger blobs drift slower (atmospheric perspective)
//   - Particles spawn at random positions and drift off-screen
//
// Mist is the most ambient and least attention-grabbing of the four
// atmosphere effects. It creates a sense of the unknown — regions
// of the mesh that are not yet well-documented, nodes that flicker
// in and out of existence. The fog lifts as the user explores more
// of their mesh and accumulates richer data.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../atmosphere_config.dart';
import '../particle_system.dart';

/// Spawn strategy for mist particles.
///
/// Mist particles are large, soft, translucent blobs that drift
/// horizontally across the canvas. They spawn at random positions
/// (not just edges) and fade in/out over their lifetime. Spawn rate
/// is proportional to intensity, which is driven by the
/// [AtmosphereDataAdapter] from sparse data region metrics.
class MistSpawnStrategy extends ParticleSpawnStrategy {
  @override
  int get maxParticles => (AtmosphereLimits.maxParticlesPerEffect * 0.4).ceil();

  @override
  double get spawnInterval {
    if (intensity <= 0) return double.infinity;
    // Mist spawns very infrequently — large, long-lived blobs.
    // At full intensity, one every ~600ms. At low intensity, every ~4s.
    const baseInterval = 0.6;
    return baseInterval / intensity.clamp(0.05, 1.0);
  }

  @override
  void initParticle(Particle p, Size canvasSize, bool isDark) {
    // Blob radius — larger blobs create softer, more diffuse fog.
    final radius = randomRange(
      AtmosphereTiming.mistRadiusMin,
      AtmosphereTiming.mistRadiusMax,
    );

    // Normalised size factor (0.0 = smallest, 1.0 = largest).
    // Larger blobs drift slower for atmospheric perspective.
    final sizeFactor =
        (radius - AtmosphereTiming.mistRadiusMin) /
        (AtmosphereTiming.mistRadiusMax - AtmosphereTiming.mistRadiusMin);

    // Drift speed — inversely proportional to size.
    final speed = ui.lerpDouble(
      AtmosphereTiming.mistSpeedMax,
      AtmosphereTiming.mistSpeedMin,
      sizeFactor,
    )!;

    // Drift direction — randomly left or right.
    final direction = rng.nextBool() ? 1.0 : -1.0;

    // Lifetime — larger blobs live longer.
    final lifetime = ui.lerpDouble(
      AtmosphereTiming.mistLifetimeMin,
      AtmosphereTiming.mistLifetimeMax,
      sizeFactor,
    )!;

    // Pick color from palette.
    final palette = isDark
        ? AtmosphereColors.mistDark
        : AtmosphereColors.mistLight;
    final baseColor = randomColor(palette);

    // Spawn position — anywhere on the canvas, with preference for
    // the lower two-thirds where fog naturally accumulates.
    final spawnY = canvasSize.height * (0.2 + rng.nextDouble() * 0.8);

    // Horizontal spawn position — offset so blobs drift into view.
    double spawnX;
    if (direction > 0) {
      // Drifting right — spawn on the left edge or slightly off-screen.
      spawnX = -radius + rng.nextDouble() * canvasSize.width * 0.5;
    } else {
      // Drifting left — spawn on the right half or slightly off-screen.
      spawnX =
          canvasSize.width * 0.5 +
          rng.nextDouble() * (canvasSize.width * 0.5 + radius);
    }

    // Phase offset for vertical oscillation.
    final vertPhase = rng.nextDouble() * math.pi * 2;

    p
      ..x = spawnX
      ..y = spawnY
      ..vx = speed * direction
      ..vy =
          0.0 // vertical motion handled via sine oscillation in painter
      ..lifetime = lifetime
      ..age = 0.0
      ..color = baseColor
      ..size = radius
      ..size2 = 0.0
      ..shape = ParticleShape.blob
      ..phase = vertPhase
      ..opacity = 1.0;
  }
}

/// CustomPainter specialised for mist blob rendering.
///
/// Renders mist particles as large, soft radial gradient circles
/// with very low alpha. Each blob gets:
///   - A radial gradient from center color to transparent edge
///   - A subtle MaskFilter blur for softness
///   - Vertical sinusoidal oscillation for organic drift
///   - Extended fade-in (first 30%) and fade-out (last 40%)
///     for gradual appearance and disappearance
///
/// The mist painter uses wider lifecycle fades than the default
/// particle system to ensure blobs appear and disappear gradually,
/// preventing jarring pop-in of large translucent shapes.
class MistPainter extends CustomPainter {
  /// The particle pool to render.
  final ParticlePool pool;

  /// Global intensity multiplier (0.0-1.0).
  final double intensity;

  /// Elapsed time in seconds, used for vertical oscillation.
  final double elapsed;

  /// Cached paint object — reused every frame.
  final Paint _blobPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  MistPainter({required this.pool, this.intensity = 1.0, this.elapsed = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    for (final p in pool.particles) {
      if (!p.alive) continue;

      // Apply vertical sinusoidal oscillation.
      // Mist blobs gently bob up and down as they drift.
      final vertOscillation =
          math.sin(p.age * 0.4 * math.pi * 2 + p.phase) * (p.size * 0.15);

      final drawX = p.x;
      final drawY = p.y + vertOscillation;

      // Generous bounds check — blobs are large, so we use a wider margin.
      final margin = p.size * 1.5;
      if (drawX < -margin ||
          drawX > size.width + margin ||
          drawY < -margin ||
          drawY > size.height + margin) {
        continue;
      }

      // Extended lifecycle fade for mist — longer fade-in and fade-out
      // than default particles, so large blobs do not pop in or out.
      final progress = p.progress;
      double lifecycleFade;
      if (progress < 0.30) {
        // Slow fade-in over first 30% of lifetime.
        lifecycleFade = (progress / 0.30).clamp(0.0, 1.0);
        // Apply ease-in curve for smoother appearance.
        lifecycleFade = lifecycleFade * lifecycleFade;
      } else if (progress > 0.60) {
        // Slow fade-out over last 40% of lifetime.
        lifecycleFade = ((1.0 - progress) / 0.40).clamp(0.0, 1.0);
        // Apply ease-out curve for smoother disappearance.
        lifecycleFade = 1.0 - (1.0 - lifecycleFade) * (1.0 - lifecycleFade);
      } else {
        lifecycleFade = 1.0;
      }

      final effectiveAlpha =
          (p.color.a *
                  lifecycleFade *
                  intensity *
                  AtmosphereColors.mistMaxAlpha)
              .clamp(0.0, AtmosphereColors.mistMaxAlpha);

      if (effectiveAlpha < 0.002) continue;

      final center = Offset(drawX, drawY);

      // Render blob as radial gradient circle.
      // The gradient fades from the base color at center to fully
      // transparent at the edge, creating a soft cloud-like shape.
      final gradient = ui.Gradient.radial(
        center,
        p.size,
        [
          p.color.withValues(alpha: effectiveAlpha),
          p.color.withValues(alpha: effectiveAlpha * 0.5),
          p.color.withValues(alpha: effectiveAlpha * 0.15),
          p.color.withValues(alpha: 0.0),
        ],
        [0.0, 0.3, 0.7, 1.0],
      );

      _blobPaint
        ..shader = gradient
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.25);

      canvas.drawCircle(center, p.size, _blobPaint);
    }

    // Clean up shader and mask filter references.
    _blobPaint
      ..shader = null
      ..maskFilter = null;
  }

  @override
  bool shouldRepaint(MistPainter oldDelegate) => true;
}

/// Animated atmosphere layer specialised for mist effects.
///
/// Wraps particle lifecycle management with mist-specific rendering
/// that includes vertical oscillation and extended lifecycle fades.
/// Mist uses fewer particles than other effects but each particle
/// covers a larger area and lives longer, creating a sense of
/// ambient fog rather than individual droplets.
class MistLayer extends StatefulWidget {
  /// Effect intensity (0.0-1.0). Controls spawn rate and blob density.
  final double intensity;

  /// Whether the effect is currently active.
  final bool enabled;

  const MistLayer({super.key, this.intensity = 0.5, this.enabled = true});

  @override
  State<MistLayer> createState() => _MistLayerState();
}

class _MistLayerState extends State<MistLayer>
    with SingleTickerProviderStateMixin {
  late final ParticlePool _pool;
  late final MistSpawnStrategy _strategy;
  late final Ticker _ticker;

  bool _tickerActive = false;
  bool _reduceMotion = false;
  Duration _lastElapsed = Duration.zero;
  double _totalElapsed = 0.0;

  /// Consecutive slow frame counter for auto-throttle.
  int _slowFrameCount = 0;

  /// Auto-throttle multiplier.
  double _throttle = 1.0;

  @override
  void initState() {
    super.initState();
    _strategy = MistSpawnStrategy();
    _pool = ParticlePool(capacity: _strategy.maxParticles);
    _ticker = createTicker(_onTick);
    _updateTickerState();
  }

  @override
  void didUpdateWidget(MistLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _strategy.intensity = widget.intensity * _throttle;

    if (widget.enabled != oldWidget.enabled) {
      if (!widget.enabled) {
        _strategy.resetAccumulator();
      }
      _updateTickerState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _updateTickerState();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pool.clear();
    super.dispose();
  }

  void _updateTickerState() {
    final shouldRun = widget.enabled && !_reduceMotion;
    if (shouldRun && !_tickerActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
      _tickerActive = true;
    } else if (!shouldRun && _tickerActive) {
      _ticker.stop();
      _tickerActive = false;
      _pool.clear();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    final clampedDt = dt.clamp(0.0, 0.05);
    _totalElapsed += clampedDt;

    // Frame budget monitoring.
    final frameMs = clampedDt * 1000.0;
    if (frameMs > AtmosphereLimits.targetFrameMs) {
      _slowFrameCount++;
      if (_slowFrameCount >= AtmosphereLimits.slowFrameThreshold) {
        _throttle = (_throttle * 0.8).clamp(0.2, 1.0);
        _slowFrameCount = 0;
      }
    } else {
      _slowFrameCount = 0;
      _throttle = (_throttle + 0.01).clamp(0.2, 1.0);
    }

    _strategy.intensity = widget.intensity * _throttle;

    // Spawn new particles.
    if (widget.enabled && widget.intensity > 0) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        _strategy.trySpawn(_pool, clampedDt, renderBox.size, isDark);
      }
    }

    // Advance all particles.
    _pool.tick(clampedDt);

    // Stop ticker if disabled and all particles are dead.
    if (!widget.enabled && _pool.aliveCount == 0 && _tickerActive) {
      _ticker.stop();
      _tickerActive = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return const SizedBox.expand();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: MistPainter(
            pool: _pool,
            intensity: widget.intensity * _throttle,
            elapsed: _totalElapsed,
          ),
        ),
      ),
    );
  }
}
