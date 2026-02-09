// SPDX-License-Identifier: GPL-3.0-or-later

// Ember Effect — rising warm spark particles driven by patina and relay data.
//
// Embers rise gently from the bottom of the viewport, wandering
// horizontally with a sinusoidal oscillation and pulsing in brightness.
// The effect intensity is tied to average patina scores and the fraction
// of relay/router nodes in the mesh — a network with deeply documented,
// high-contribution nodes glows warmer.
//
// Visual characteristics:
//   - Small filled circles with a soft glow halo (ParticleShape.circle)
//   - Warm amber-orange-copper palette, low alpha
//   - Rise upward with gentle horizontal sinusoidal wander
//   - Brightness pulses via phase-offset sine wave
//   - Slower and more organic than rain — meditative, not urgent
//   - Particles spawn below the viewport and fade out near the top
//
// The ember effect is the most emotionally evocative of the four
// atmosphere effects. It conveys warmth, contribution, and the
// accumulated effort of mesh participants. A network full of
// well-documented relay nodes feels alive with quiet fire.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../atmosphere_config.dart';
import '../particle_system.dart';

/// Spawn strategy for ember particles.
///
/// Embers are small glowing circles that rise from the bottom of
/// the canvas with horizontal sinusoidal wander and brightness
/// pulsation. Spawn rate is proportional to intensity, which is
/// driven by the [AtmosphereDataAdapter] from patina scores and
/// relay node fraction.
class EmberSpawnStrategy extends ParticleSpawnStrategy {
  @override
  int get maxParticles => AtmosphereLimits.maxParticlesPerEffect;

  @override
  double get spawnInterval {
    if (intensity <= 0) return double.infinity;
    // Embers spawn less frequently than rain — they are sparse and
    // precious. At full intensity, one every ~120ms. At low intensity,
    // one every ~2s.
    final baseInterval = 0.12;
    return baseInterval / intensity.clamp(0.05, 1.0);
  }

  @override
  void initParticle(Particle p, Size canvasSize, bool isDark) {
    // Rise speed — embers float upward gently.
    final speed = randomRange(
      AtmosphereTiming.emberSpeedMin,
      AtmosphereTiming.emberSpeedMax,
    );

    // Lifetime determines how far the ember travels before fading.
    final lifetime = randomRange(
      AtmosphereTiming.emberLifetimeMin,
      AtmosphereTiming.emberLifetimeMax,
    );

    // Pick color from palette.
    final palette = isDark
        ? AtmosphereColors.emberDark
        : AtmosphereColors.emberLight;
    final baseColor = randomColor(palette);

    // Ember size — small core dot.
    final coreRadius = randomRange(1.0, 2.5);

    // Phase offset for sinusoidal wander and brightness pulse.
    // Each ember gets a unique phase so they don't oscillate in sync.
    final wanderPhase = rng.nextDouble() * math.pi * 2;

    // Spawn position — across the bottom edge with some horizontal spread.
    // Allow spawning slightly outside the horizontal bounds so embers
    // can drift in from the sides.
    final spawnMargin = canvasSize.width * 0.1;
    final spawnX =
        -spawnMargin + rng.nextDouble() * (canvasSize.width + spawnMargin * 2);

    p
      ..x = spawnX
      ..y = canvasSize.height + coreRadius + rng.nextDouble() * 10.0
      ..vx =
          0.0 // horizontal movement handled by wander in tick override
      ..vy =
          -speed // negative = upward
      ..lifetime = lifetime
      ..age = 0.0
      ..color = baseColor
      ..size = coreRadius
      ..size2 =
          0.0 // unused for circles
      ..shape = ParticleShape.circle
      ..phase = wanderPhase
      ..opacity = 1.0;
  }
}

/// CustomPainter specialised for ember particle rendering.
///
/// Extends rendering with ember-specific features:
///   - Sinusoidal horizontal wander applied per-frame
///   - Brightness pulsation via phase-offset sine wave
///   - Soft glow halo around each ember core
///   - Brighter core center for hot-spot effect
///
/// The painter modifies particle positions in-place during paint
/// for the horizontal wander effect. This is acceptable because
/// the particle pool is single-owner and paint is called once
/// per frame before any other reads.
class EmberPainter extends CustomPainter {
  /// The particle pool to render.
  final ParticlePool pool;

  /// Global intensity multiplier (0.0-1.0).
  final double intensity;

  /// Elapsed time in seconds, used for wander and pulse animation.
  final double elapsed;

  /// Cached paint objects — reused every frame.
  final Paint _glowPaint = Paint()..isAntiAlias = true;
  final Paint _corePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  EmberPainter({required this.pool, this.intensity = 1.0, this.elapsed = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    for (final p in pool.particles) {
      if (!p.alive) continue;

      // Apply sinusoidal horizontal wander.
      // The wander is computed from age + phase so each ember
      // traces its own unique path.
      final wanderX =
          math.sin(
            p.age * AtmosphereTiming.emberWanderFrequency * math.pi * 2 +
                p.phase,
          ) *
          AtmosphereTiming.emberWanderAmplitude;

      final drawX = p.x + wanderX;
      final drawY = p.y;

      // Quick bounds check.
      final margin = p.size * 4;
      if (drawX < -margin ||
          drawX > size.width + margin ||
          drawY < -margin ||
          drawY > size.height + margin) {
        continue;
      }

      // Brightness pulsation — sine wave modulates opacity.
      final pulseFactor =
          0.6 +
          0.4 *
              math.sin(
                p.age * AtmosphereTiming.emberPulseFrequency * math.pi * 2 +
                    p.phase * 1.7,
              );

      final effectiveAlpha = (p.color.a * p.opacity * intensity * pulseFactor)
          .clamp(0.0, 1.0);

      if (effectiveAlpha < 0.005) continue;

      final center = Offset(drawX, drawY);

      // Draw soft glow halo behind the core.
      final glowRadius = p.size * 3.0;
      final glowAlpha = (effectiveAlpha * AtmosphereColors.emberGlowMaxAlpha)
          .clamp(0.0, 1.0);

      if (glowAlpha > 0.003) {
        final glowGradient = ui.Gradient.radial(
          center,
          glowRadius,
          [
            p.color.withValues(alpha: glowAlpha),
            p.color.withValues(alpha: 0.0),
          ],
          [0.0, 1.0],
        );
        _glowPaint
          ..shader = glowGradient
          ..style = PaintingStyle.fill
          ..maskFilter = null;
        canvas.drawCircle(center, glowRadius, _glowPaint);
        _glowPaint.shader = null;
      }

      // Draw ember core — slightly brighter than the base color.
      final coreAlpha = (effectiveAlpha * AtmosphereColors.emberCoreBrightness)
          .clamp(0.0, 1.0);
      _corePaint.color = p.color.withValues(alpha: coreAlpha);
      canvas.drawCircle(center, p.size, _corePaint);

      // Tiny bright center dot for hot-spot effect on larger embers.
      if (p.size > 1.5) {
        final hotspotAlpha = (coreAlpha * 1.3).clamp(0.0, 1.0);
        _corePaint.color = _brighten(
          p.color,
          0.3,
        ).withValues(alpha: hotspotAlpha);
        canvas.drawCircle(center, p.size * 0.35, _corePaint);
      }
    }
  }

  /// Brighten a color by blending it toward white.
  Color _brighten(Color color, double amount) {
    final r = (color.r + (1.0 - color.r) * amount).clamp(0.0, 1.0);
    final g = (color.g + (1.0 - color.g) * amount).clamp(0.0, 1.0);
    final b = (color.b + (1.0 - color.b) * amount).clamp(0.0, 1.0);
    return Color.from(alpha: color.a, red: r, green: g, blue: b);
  }

  @override
  bool shouldRepaint(EmberPainter oldDelegate) => true;
}

/// Animated atmosphere layer specialised for ember effects.
///
/// Wraps [AtmosphereLayer] behaviour with ember-specific rendering
/// that includes horizontal wander and brightness pulsation driven
/// by elapsed time. The wander is applied during paint rather than
/// in the tick loop so that the base particle position (used for
/// bounds checking) stays on the simple vertical trajectory.
class EmberLayer extends StatefulWidget {
  /// Effect intensity (0.0-1.0). Controls spawn rate and visual density.
  final double intensity;

  /// Whether the effect is currently active.
  final bool enabled;

  const EmberLayer({super.key, this.intensity = 0.5, this.enabled = true});

  @override
  State<EmberLayer> createState() => _EmberLayerState();
}

class _EmberLayerState extends State<EmberLayer>
    with SingleTickerProviderStateMixin {
  late final ParticlePool _pool;
  late final EmberSpawnStrategy _strategy;
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
    _strategy = EmberSpawnStrategy();
    _pool = ParticlePool(capacity: _strategy.maxParticles);
    _ticker = createTicker(_onTick);
    _updateTickerState();
  }

  @override
  void didUpdateWidget(EmberLayer oldWidget) {
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
          painter: EmberPainter(
            pool: _pool,
            intensity: widget.intensity * _throttle,
            elapsed: _totalElapsed,
          ),
        ),
      ),
    );
  }
}
