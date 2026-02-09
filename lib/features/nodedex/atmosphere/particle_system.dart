// SPDX-License-Identifier: GPL-3.0-or-later

// Particle System — lightweight pooled particle engine for atmospheric effects.
//
// Architecture:
//   - Object pool eliminates GC pressure during animation loops
//   - Single CustomPainter renders all active particles per effect layer
//   - Particle lifecycle: spawn → alive → fade-out → dead → recycle
//   - Frame-budget monitoring auto-throttles spawn rate on slow devices
//   - All state is mutable-in-place for performance (no allocations per frame)
//
// This engine is intentionally minimal. It provides:
//   - Particle struct with position, velocity, lifetime, color, size
//   - Pool with acquire/release cycle
//   - Tick method that advances all particles and recycles dead ones
//   - Abstract spawn strategy (subclassed per effect type)
//   - CustomPainter base that renders particles as primitives
//
// No physics simulation, no collision detection, no spatial indexing.
// Atmospheric particles are simple and few enough that brute-force
// iteration at 60fps is well within budget.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'atmosphere_config.dart';

// =============================================================================
// Particle data structure
// =============================================================================

/// The visual shape used to render a particle.
enum ParticleShape {
  /// A filled circle (used for embers, starlight, mist blobs).
  circle,

  /// A vertical line segment (used for rain streaks).
  streak,

  /// A soft radial gradient blob (used for mist).
  blob,
}

/// A single particle in the system.
///
/// All fields are mutable for in-place updates during the tick loop.
/// Particles are never individually allocated or freed — they live
/// in a pre-allocated pool and are recycled via [alive] flag.
class Particle {
  /// Whether this particle is currently active.
  bool alive = false;

  /// Current X position in logical pixels.
  double x = 0.0;

  /// Current Y position in logical pixels.
  double y = 0.0;

  /// Horizontal velocity (logical pixels per second).
  double vx = 0.0;

  /// Vertical velocity (logical pixels per second).
  double vy = 0.0;

  /// Total lifetime in seconds.
  double lifetime = 0.0;

  /// Time elapsed since spawn (seconds).
  double age = 0.0;

  /// Base color of this particle (includes alpha from palette).
  Color color = const Color(0x00000000);

  /// Radius or half-length depending on shape (logical pixels).
  double size = 1.0;

  /// Secondary size dimension (e.g. streak length for [ParticleShape.streak]).
  double size2 = 0.0;

  /// Visual shape for rendering.
  ParticleShape shape = ParticleShape.circle;

  /// Per-particle phase offset for oscillation effects (radians).
  /// Used by embers for horizontal wander and starlight for twinkle.
  double phase = 0.0;

  /// Opacity multiplier (0.0–1.0), layered on top of color alpha.
  /// Controlled by fade-in / fade-out curves.
  double opacity = 1.0;

  /// Normalized progress through lifetime (0.0 at spawn, 1.0 at death).
  double get progress => lifetime > 0 ? (age / lifetime).clamp(0.0, 1.0) : 1.0;

  /// Whether this particle has exceeded its lifetime.
  bool get isDead => age >= lifetime;

  /// Reset all fields to defaults for pool recycling.
  void reset() {
    alive = false;
    x = 0.0;
    y = 0.0;
    vx = 0.0;
    vy = 0.0;
    lifetime = 0.0;
    age = 0.0;
    color = const Color(0x00000000);
    size = 1.0;
    size2 = 0.0;
    shape = ParticleShape.circle;
    phase = 0.0;
    opacity = 1.0;
  }
}

// =============================================================================
// Particle pool
// =============================================================================

/// Pre-allocated pool of reusable [Particle] objects.
///
/// Eliminates allocation and GC overhead during animation.
/// Particles are acquired from the pool, used while alive,
/// then automatically recycled when dead.
class ParticlePool {
  /// All particles in the pool (pre-allocated).
  final List<Particle> _particles;

  /// Current count of alive particles.
  int _aliveCount = 0;

  /// Number of currently alive particles.
  int get aliveCount => _aliveCount;

  /// Maximum pool capacity.
  int get capacity => _particles.length;

  /// Whether the pool has room for more particles.
  bool get hasCapacity => _aliveCount < _particles.length;

  /// Read-only view of all particles (including dead ones).
  /// Renderers should check [Particle.alive] before drawing.
  List<Particle> get particles => _particles;

  /// Create a pool with [capacity] pre-allocated particles.
  ParticlePool({int capacity = AtmosphereLimits.particlePoolSize})
    : _particles = List<Particle>.generate(capacity, (_) => Particle());

  /// Acquire a dead particle from the pool and mark it alive.
  ///
  /// Returns null if the pool is full (all particles are alive).
  /// The caller is responsible for initializing the particle's
  /// position, velocity, color, etc. after acquisition.
  Particle? acquire() {
    for (final p in _particles) {
      if (!p.alive) {
        p.alive = true;
        _aliveCount++;
        return p;
      }
    }
    return null;
  }

  /// Release a particle back to the pool.
  void release(Particle p) {
    if (p.alive) {
      p.reset();
      _aliveCount--;
    }
  }

  /// Advance all alive particles by [dt] seconds.
  ///
  /// Updates position based on velocity, increments age, applies
  /// fade curves, and automatically recycles dead particles.
  void tick(double dt) {
    _aliveCount = 0;
    for (final p in _particles) {
      if (!p.alive) continue;

      // Advance age.
      p.age += dt;

      // Kill expired particles.
      if (p.isDead) {
        p.reset();
        continue;
      }

      // Update position.
      p.x += p.vx * dt;
      p.y += p.vy * dt;

      // Compute opacity from lifecycle (fade in first 15%, fade out last 25%).
      final progress = p.progress;
      if (progress < 0.15) {
        p.opacity = (progress / 0.15).clamp(0.0, 1.0);
      } else if (progress > 0.75) {
        p.opacity = ((1.0 - progress) / 0.25).clamp(0.0, 1.0);
      } else {
        p.opacity = 1.0;
      }

      _aliveCount++;
    }
  }

  /// Kill all particles and reset the pool.
  void clear() {
    for (final p in _particles) {
      p.reset();
    }
    _aliveCount = 0;
  }
}

// =============================================================================
// Spawn strategy
// =============================================================================

/// Abstract interface for particle spawn behavior.
///
/// Each atmospheric effect (rain, embers, mist, starlight) implements
/// this to control how and when new particles are created.
abstract class ParticleSpawnStrategy {
  /// Random number generator shared across all strategies.
  final math.Random rng = math.Random();

  /// The effect-specific particle cap.
  int get maxParticles;

  /// Current intensity (0.0–1.0), controls spawn rate and density.
  double intensity = 0.0;

  /// Accumulated time since last spawn (seconds).
  double _spawnAccumulator = 0.0;

  /// Spawn interval in seconds, derived from intensity.
  double get spawnInterval {
    if (intensity <= 0) return double.infinity;
    // Higher intensity = shorter interval = more particles.
    // At intensity 1.0, spawn every ~50ms. At 0.1, every ~500ms.
    final baseInterval = AtmosphereLimits.minSpawnIntervalMs / 1000.0;
    return baseInterval / intensity.clamp(0.05, 1.0);
  }

  /// Number of particles to spawn per burst.
  /// Most effects spawn 1 at a time; mist may spawn 1-2.
  int get burstCount => 1;

  /// Initialize a newly acquired particle with effect-specific properties.
  ///
  /// [canvasSize] is the current render area. The strategy should set
  /// the particle's position, velocity, color, size, shape, lifetime,
  /// and phase offset.
  void initParticle(Particle p, Size canvasSize, bool isDark);

  /// Called each frame to potentially spawn new particles.
  ///
  /// Returns the number of particles spawned this frame.
  int trySpawn(ParticlePool pool, double dt, Size canvasSize, bool isDark) {
    if (intensity <= 0) return 0;

    _spawnAccumulator += dt;
    int spawned = 0;

    while (_spawnAccumulator >= spawnInterval) {
      _spawnAccumulator -= spawnInterval;

      // Respect per-effect cap.
      if (pool.aliveCount >= maxParticles) break;

      // Respect global cap.
      if (pool.aliveCount >= AtmosphereLimits.maxParticlesGlobal) break;

      for (int i = 0; i < burstCount; i++) {
        final p = pool.acquire();
        if (p == null) break;
        initParticle(p, canvasSize, isDark);
        spawned++;
      }
    }

    return spawned;
  }

  /// Reset spawn accumulator (e.g. when effect is toggled off then on).
  void resetAccumulator() {
    _spawnAccumulator = 0.0;
  }

  /// Linearly interpolate between [a] and [b] by random factor.
  double randomRange(double a, double b) {
    return a + rng.nextDouble() * (b - a);
  }

  /// Pick a random color from a list.
  Color randomColor(List<Color> palette) {
    return palette[rng.nextInt(palette.length)];
  }
}

// =============================================================================
// Particle painter
// =============================================================================

/// CustomPainter that renders all alive particles from a pool.
///
/// Supports three particle shapes:
///   - [ParticleShape.circle]: filled circle with optional glow
///   - [ParticleShape.streak]: vertical line segment (rain)
///   - [ParticleShape.blob]: soft radial gradient (mist)
///
/// Paint objects are pre-allocated and reused across frames.
class ParticlePainter extends CustomPainter {
  /// The particle pool to render.
  final ParticlePool pool;

  /// Global intensity multiplier (0.0–1.0).
  /// Applied on top of individual particle opacity.
  final double intensity;

  /// Cached paint for circles and streaks.
  final Paint _paint = Paint()..isAntiAlias = true;

  ParticlePainter({required this.pool, this.intensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    for (final p in pool.particles) {
      if (!p.alive) continue;

      // Skip particles outside the visible area (with margin).
      if (p.x < -p.size * 2 ||
          p.x > size.width + p.size * 2 ||
          p.y < -p.size * 2 - p.size2 ||
          p.y > size.height + p.size * 2 + p.size2) {
        continue;
      }

      final effectiveAlpha = (p.color.a * p.opacity * intensity).clamp(
        0.0,
        1.0,
      );

      if (effectiveAlpha < 0.005) continue;

      final drawColor = p.color.withValues(alpha: effectiveAlpha);

      switch (p.shape) {
        case ParticleShape.circle:
          _paint
            ..color = drawColor
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          canvas.drawCircle(Offset(p.x, p.y), p.size, _paint);

        case ParticleShape.streak:
          _paint
            ..color = drawColor
            ..strokeWidth = p.size
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke
            ..maskFilter = null;
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(p.x + p.vx * 0.02, p.y + p.size2),
            _paint,
          );

        case ParticleShape.blob:
          final gradient = ui.Gradient.radial(
            Offset(p.x, p.y),
            p.size,
            [drawColor, drawColor.withValues(alpha: 0.0)],
            [0.0, 1.0],
          );
          _paint
            ..shader = gradient
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.3);
          canvas.drawCircle(Offset(p.x, p.y), p.size, _paint);
          _paint
            ..shader = null
            ..maskFilter = null;
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    // Always repaint — particles move every frame.
    return true;
  }
}

// =============================================================================
// Atmosphere layer widget
// =============================================================================

/// A single animated particle effect layer.
///
/// Manages a [ParticlePool], a [ParticleSpawnStrategy], and a [Ticker]
/// to drive continuous animation. Renders via [ParticlePainter].
///
/// This widget is designed to be stacked behind content with
/// [IgnorePointer] so it never intercepts touch events.
///
/// Usage:
/// ```dart
/// AtmosphereLayer(
///   strategy: RainSpawnStrategy(),
///   intensity: 0.5,
///   enabled: true,
/// )
/// ```
class AtmosphereLayer extends StatefulWidget {
  /// The spawn strategy that controls particle behavior.
  final ParticleSpawnStrategy strategy;

  /// Effect intensity (0.0–1.0). Controls spawn rate and visual density.
  final double intensity;

  /// Whether the effect is currently active. When false, existing
  /// particles finish their lifecycle but no new ones spawn.
  final bool enabled;

  /// Maximum particles for this layer (overrides strategy default
  /// when pool is created).
  final int? maxParticles;

  const AtmosphereLayer({
    super.key,
    required this.strategy,
    this.intensity = 0.5,
    this.enabled = true,
    this.maxParticles,
  });

  @override
  State<AtmosphereLayer> createState() => _AtmosphereLayerState();
}

class _AtmosphereLayerState extends State<AtmosphereLayer>
    with SingleTickerProviderStateMixin {
  late final ParticlePool _pool;
  late final Ticker _ticker;

  /// Tracks whether the ticker is currently active.
  bool _tickerActive = false;

  /// Tracks consecutive slow frames for auto-throttle.
  int _slowFrameCount = 0;

  /// Auto-throttle multiplier (1.0 = full, reduces on slow frames).
  double _throttle = 1.0;

  /// Whether reduced motion is requested by the OS.
  bool _reduceMotion = false;

  /// Previous tick timestamp for delta-time calculation.
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pool = ParticlePool(
      capacity: widget.maxParticles ?? widget.strategy.maxParticles,
    );
    _ticker = createTicker(_onTick);
    _updateTickerState();
  }

  @override
  void didUpdateWidget(AtmosphereLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.strategy.intensity = widget.intensity * _throttle;

    if (widget.enabled != oldWidget.enabled) {
      if (!widget.enabled) {
        widget.strategy.resetAccumulator();
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
    // Compute delta time in seconds.
    final dt = _lastElapsed == Duration.zero
        ? 0.016 // Assume ~60fps for first frame.
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    // Clamp dt to prevent spiral-of-death on background resume.
    final clampedDt = dt.clamp(0.0, 0.05);

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
      // Gradually restore throttle.
      _throttle = (_throttle + 0.01).clamp(0.2, 1.0);
    }

    // Update strategy intensity.
    widget.strategy.intensity = widget.intensity * _throttle;

    // Spawn new particles (only if enabled).
    if (widget.enabled && widget.intensity > 0) {
      final canvasSize = _currentSize;
      if (canvasSize != null && canvasSize.width > 0 && canvasSize.height > 0) {
        final isDark = _isDarkMode;
        widget.strategy.trySpawn(_pool, clampedDt, canvasSize, isDark);
      }
    }

    // Advance all particles.
    _pool.tick(clampedDt);

    // Stop ticker if disabled and all particles are dead.
    if (!widget.enabled && _pool.aliveCount == 0 && _tickerActive) {
      _ticker.stop();
      _tickerActive = false;
    }

    // Request repaint.
    if (mounted) {
      setState(() {});
    }
  }

  /// Current canvas size (from LayoutBuilder or context).
  Size? get _currentSize {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.hasSize == true ? renderBox!.size : null;
  }

  /// Whether the current theme is dark mode.
  bool get _isDarkMode {
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    // When reduce-motion is active, render nothing.
    if (_reduceMotion) return const SizedBox.expand();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: ParticlePainter(
            pool: _pool,
            intensity: widget.intensity * _throttle,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Multi-layer atmosphere stack
// =============================================================================

/// Combines multiple [AtmosphereLayer]s into a single overlay stack.
///
/// Designed to be placed behind content in a [Stack]. All layers
/// share the same coordinate space and are rendered in order
/// (back to front).
///
/// ```dart
/// Stack(
///   children: [
///     AtmosphereStack(layers: [...]),
///     // Your content here
///   ],
/// )
/// ```
class AtmosphereStack extends StatelessWidget {
  /// The atmosphere layers to render, from back to front.
  final List<AtmosphereLayer> layers;

  const AtmosphereStack({super.key, required this.layers});

  @override
  Widget build(BuildContext context) {
    if (layers.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: layers),
    );
  }
}
