// SPDX-License-Identifier: GPL-3.0-or-later

// Starlight Effect — ambient twinkling background particles.
//
// Starlight is the most subtle and ever-present of the four atmosphere
// effects. Small luminous points appear at random positions across the
// viewport and gently twinkle (oscillate in brightness) before fading
// away. Unlike rain and embers which have directional motion, starlight
// particles are stationary — they shimmer in place like distant stars.
//
// Visual characteristics:
//   - Tiny filled circles (ParticleShape.circle), 0.5–2.0dp radius
//   - Pale blue-white palette on dark, muted grey on light
//   - No translational motion — particles stay where they spawn
//   - Brightness oscillates via phase-offset sine wave (twinkle)
//   - Long lifetime with very gradual fade-in and fade-out
//   - Spawn anywhere on the canvas with uniform distribution
//
// Starlight intensity is the least data-responsive of the four effects.
// It provides a gentle ambient baseline that is always subtly present
// when the atmosphere system is enabled, regardless of mesh activity.
// The intensity scales mildly with total node count — a richer mesh
// has a slightly more populated starfield.
//
// Design intent: the starlight layer establishes the "space" feeling
// of the constellation view. Even with zero mesh activity, the canvas
// should not feel dead — tiny points of light breathe quietly in the
// background, suggesting latent potential.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../atmosphere_config.dart';
import '../particle_system.dart';

/// Spawn strategy for starlight particles.
///
/// Starlight particles are tiny circles that appear at random positions
/// and twinkle in place without moving. They have long lifetimes and
/// very gradual fade curves. Spawn rate is proportional to intensity,
/// which is driven by a gentle ambient baseline plus a mild contribution
/// from total node count.
class StarlightSpawnStrategy extends ParticleSpawnStrategy {
  @override
  int get maxParticles => AtmosphereLimits.maxParticlesPerEffect;

  @override
  double get spawnInterval {
    if (intensity <= 0) return double.infinity;
    // Starlight spawns at a moderate rate — enough to maintain a
    // gentle field of twinkling points without overcrowding.
    // At full intensity, one every ~200ms. At low intensity, every ~3s.
    const baseInterval = 0.2;
    return baseInterval / intensity.clamp(0.05, 1.0);
  }

  @override
  void initParticle(Particle p, Size canvasSize, bool isDark) {
    // Star radius — tiny points of light.
    final radius = randomRange(
      AtmosphereTiming.starlightRadiusMin,
      AtmosphereTiming.starlightRadiusMax,
    );

    // Lifetime — starlight particles live longer than others
    // to maintain a stable, calm field.
    final lifetime = randomRange(
      AtmosphereTiming.starlightLifetimeMin,
      AtmosphereTiming.starlightLifetimeMax,
    );

    // Pick color from palette.
    final palette = isDark
        ? AtmosphereColors.starlightDark
        : AtmosphereColors.starlightLight;
    final baseColor = randomColor(palette);

    // Twinkle phase — each star gets a unique phase offset so they
    // do not all pulse in unison.
    final twinklePhase = rng.nextDouble() * math.pi * 2;

    // Spawn position — uniformly distributed across the entire canvas.
    // Stars can appear anywhere, unlike rain (top) or embers (bottom).
    final spawnX = rng.nextDouble() * canvasSize.width;
    final spawnY = rng.nextDouble() * canvasSize.height;

    p
      ..x = spawnX
      ..y = spawnY
      ..vx =
          0.0 // stationary — no translational motion
      ..vy = 0.0
      ..lifetime = lifetime
      ..age = 0.0
      ..color = baseColor
      ..size = radius
      ..size2 = 0.0
      ..shape = ParticleShape.circle
      ..phase = twinklePhase
      ..opacity = 1.0;
  }
}

/// CustomPainter specialised for starlight particle rendering.
///
/// Extends rendering with starlight-specific features:
///   - Brightness twinkle via phase-offset sine wave
///   - Larger stars get a faint glow halo
///   - Extended fade curves (40% fade-in, 40% fade-out) for calm pacing
///   - No motion — particles are drawn at their spawn position
///
/// The twinkle animation creates the impression of distant stars
/// breathing in and out of visibility. The effect is intentionally
/// irregular because each star has a unique phase offset and the
/// twinkle frequency has a per-particle randomised component baked
/// into the phase value.
class StarlightPainter extends CustomPainter {
  /// The particle pool to render.
  final ParticlePool pool;

  /// Global intensity multiplier (0.0-1.0).
  final double intensity;

  /// Elapsed time in seconds, used for twinkle animation.
  final double elapsed;

  /// Cached paint objects — reused every frame.
  final Paint _starPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  final Paint _glowPaint = Paint()..isAntiAlias = true;

  StarlightPainter({
    required this.pool,
    this.intensity = 1.0,
    this.elapsed = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    for (final p in pool.particles) {
      if (!p.alive) continue;

      // Stars are stationary — no bounds check needed beyond canvas.
      if (p.x < -p.size || p.x > size.width + p.size) continue;
      if (p.y < -p.size || p.y > size.height + p.size) continue;

      // Extended lifecycle fade — starlight uses slower fade-in and
      // fade-out than the default 15%/25% to feel calmer and more
      // ambient. Stars should materialise and dissolve gently.
      final progress = p.progress;
      double lifecycleFade;
      if (progress < 0.40) {
        // Slow fade-in over first 40% of lifetime.
        final t = (progress / 0.40).clamp(0.0, 1.0);
        // Ease-in-out curve for smooth appearance.
        lifecycleFade = t * t * (3.0 - 2.0 * t);
      } else if (progress > 0.60) {
        // Slow fade-out over last 40% of lifetime.
        final t = ((1.0 - progress) / 0.40).clamp(0.0, 1.0);
        lifecycleFade = t * t * (3.0 - 2.0 * t);
      } else {
        lifecycleFade = 1.0;
      }

      // Twinkle — sine-wave brightness oscillation.
      // The twinkle produces a gentle pulsation between ~30% and 100%
      // of the star's maximum brightness, creating a breathing effect.
      final twinkle =
          0.3 +
          0.7 *
              ((math.sin(
                        p.age *
                                AtmosphereTiming.starlightTwinkleFrequency *
                                math.pi *
                                2 +
                            p.phase,
                      ) +
                      1.0) /
                  2.0);

      final effectiveAlpha =
          (p.color.a *
                  lifecycleFade *
                  twinkle *
                  intensity *
                  AtmosphereColors.starlightMaxAlpha)
              .clamp(0.0, AtmosphereColors.starlightMaxAlpha);

      if (effectiveAlpha < 0.003) continue;

      final center = Offset(p.x, p.y);

      // Draw faint glow halo for larger stars.
      // Only stars above 1.2dp radius get a halo — tiny stars are
      // just points of light without any bloom.
      if (p.size > 1.2) {
        final glowRadius = p.size * 3.5;
        final glowAlpha = (effectiveAlpha * 0.3).clamp(0.0, 1.0);

        if (glowAlpha > 0.002) {
          _glowPaint
            ..shader = _radialGlow(center, glowRadius, p.color, glowAlpha)
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          canvas.drawCircle(center, glowRadius, _glowPaint);
          _glowPaint.shader = null;
        }
      }

      // Draw star core.
      _starPaint.color = p.color.withValues(alpha: effectiveAlpha);
      canvas.drawCircle(center, p.size, _starPaint);

      // Tiny bright center point for stars above 1.5dp.
      // Creates a subtle hot-center effect like a real star.
      if (p.size > 1.5) {
        final hotAlpha = (effectiveAlpha * 1.5).clamp(0.0, 1.0);
        _starPaint.color = _brighten(p.color, 0.4).withValues(alpha: hotAlpha);
        canvas.drawCircle(center, p.size * 0.3, _starPaint);
      }
    }
  }

  /// Create a radial gradient for the star glow halo.
  Shader _radialGlow(Offset center, double radius, Color color, double alpha) {
    return RadialGradient(
      colors: [
        color.withValues(alpha: alpha),
        color.withValues(alpha: alpha * 0.3),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
  }

  /// Brighten a color by blending it toward white.
  Color _brighten(Color color, double amount) {
    final r = (color.r + (1.0 - color.r) * amount).clamp(0.0, 1.0);
    final g = (color.g + (1.0 - color.g) * amount).clamp(0.0, 1.0);
    final b = (color.b + (1.0 - color.b) * amount).clamp(0.0, 1.0);
    return Color.from(alpha: color.a, red: r, green: g, blue: b);
  }

  @override
  bool shouldRepaint(StarlightPainter oldDelegate) => true;
}

/// Animated atmosphere layer specialised for starlight effects.
///
/// Manages a particle pool of twinkling star points with no
/// translational motion. Stars shimmer in place via brightness
/// oscillation and appear/disappear with extended fade curves.
///
/// Unlike other atmosphere layers, starlight particles are stationary
/// and do not need position updates. The tick loop only advances age,
/// manages lifecycle, and spawns new stars to replace faded ones.
class StarlightLayer extends StatefulWidget {
  /// Effect intensity (0.0-1.0). Controls spawn rate and star density.
  final double intensity;

  /// Whether the effect is currently active.
  final bool enabled;

  const StarlightLayer({super.key, this.intensity = 0.5, this.enabled = true});

  @override
  State<StarlightLayer> createState() => _StarlightLayerState();
}

class _StarlightLayerState extends State<StarlightLayer>
    with SingleTickerProviderStateMixin {
  late final ParticlePool _pool;
  late final StarlightSpawnStrategy _strategy;
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
    _strategy = StarlightSpawnStrategy();
    _pool = ParticlePool(capacity: _strategy.maxParticles);
    _ticker = createTicker(_onTick);
    _updateTickerState();
  }

  @override
  void didUpdateWidget(StarlightLayer oldWidget) {
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
    // Starlight particles have zero velocity, so the pool tick only
    // advances age and manages lifecycle (fade-in/fade-out/death).
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
          painter: StarlightPainter(
            pool: _pool,
            intensity: widget.intensity * _throttle,
            elapsed: _totalElapsed,
          ),
        ),
      ),
    );
  }
}
