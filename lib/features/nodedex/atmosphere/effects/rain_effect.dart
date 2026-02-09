// SPDX-License-Identifier: GPL-3.0-or-later

// Rain Effect — vertical streak particles driven by mesh activity.
//
// Rain density is tied to packet activity and node count. More active
// networks produce denser rainfall. The effect uses thin vertical
// streaks that fall with slight horizontal drift, creating an ambient
// sense of data flowing through the mesh.
//
// Visual characteristics:
//   - Thin vertical line segments (ParticleShape.streak)
//   - Cool blue-grey palette, very low alpha
//   - Slight horizontal drift for natural feel
//   - Speed varies per particle for depth layering
//   - Faster particles are slightly longer and brighter
//   - Particles spawn above the viewport and die below it
//
// The rain effect is the most data-responsive of the four atmosphere
// effects. At low activity it produces a gentle drizzle; at peak
// activity it becomes a steady shower (but never a downpour — the
// ceiling is calibrated to remain ambient).

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../atmosphere_config.dart';
import '../particle_system.dart';

/// Spawn strategy for rain particles.
///
/// Rain particles are vertical streaks that fall from the top of
/// the canvas to the bottom. Spawn rate is proportional to intensity,
/// which is driven by the [AtmosphereDataAdapter] from node count
/// and packet activity metrics.
class RainSpawnStrategy extends ParticleSpawnStrategy {
  @override
  int get maxParticles => AtmosphereLimits.maxParticlesPerEffect;

  @override
  void initParticle(Particle p, Size canvasSize, bool isDark) {
    // Randomise speed within range — faster particles appear closer.
    final speed = randomRange(
      AtmosphereTiming.rainSpeedMin,
      AtmosphereTiming.rainSpeedMax,
    );

    // Normalised speed factor (0.0 = slowest, 1.0 = fastest) for
    // depth-dependent sizing: faster streaks are longer and wider.
    final speedFactor =
        (speed - AtmosphereTiming.rainSpeedMin) /
        (AtmosphereTiming.rainSpeedMax - AtmosphereTiming.rainSpeedMin);

    // Streak length scales with speed.
    final streakLength = lerpDouble(
      AtmosphereTiming.rainLengthMin,
      AtmosphereTiming.rainLengthMax,
      speedFactor,
    )!;

    // Slight horizontal drift for natural feel.
    final drift = randomRange(
      AtmosphereTiming.rainDriftMin,
      AtmosphereTiming.rainDriftMax,
    );

    // Lifetime calculated so the particle traverses the full canvas
    // height plus streak length before dying. This ensures streaks
    // always exit the viewport naturally.
    final traverseDistance = canvasSize.height + streakLength + 20.0;
    final lifetime = traverseDistance / speed;

    // Pick color from palette.
    final palette = isDark
        ? AtmosphereColors.rainDark
        : AtmosphereColors.rainLight;
    final baseColor = randomColor(palette);

    // Faster streaks get slightly higher alpha for depth effect.
    final alphaBoost = speedFactor * 0.4;
    final adjustedAlpha =
        (baseColor.a + alphaBoost * AtmosphereColors.rainMaxAlpha).clamp(
          0.0,
          AtmosphereColors.rainMaxAlpha,
        );

    p
      ..x = rng.nextDouble() * canvasSize.width
      ..y = -streakLength - rng.nextDouble() * 20.0
      ..vx = drift
      ..vy = speed
      ..lifetime = lifetime
      ..age = 0.0
      ..color = baseColor.withValues(alpha: adjustedAlpha)
      ..size =
          lerpDouble(0.4, 0.8, speedFactor)! // stroke width
      ..size2 = streakLength
      ..shape = ParticleShape.streak
      ..phase = rng.nextDouble() * math.pi * 2
      ..opacity = 1.0;
  }
}

/// CustomPainter optimised for rain streak rendering.
///
/// Extends the base [ParticlePainter] with rain-specific optimisations:
///   - Skips the generic shape switch since all particles are streaks
///   - Uses a single pre-allocated Paint with round caps
///   - Applies a subtle length variation based on velocity
///
/// For most use cases the base [ParticlePainter] works fine. This
/// specialised painter is provided for constellation-screen usage
/// where rain may coexist with many other draw calls and every
/// microsecond counts.
class RainPainter extends CustomPainter {
  /// The particle pool to render.
  final ParticlePool pool;

  /// Global intensity multiplier (0.0-1.0).
  final double intensity;

  /// Cached paint object — reused every frame.
  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  RainPainter({required this.pool, this.intensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    for (final p in pool.particles) {
      if (!p.alive) continue;

      // Quick bounds check — skip particles fully outside viewport.
      if (p.y > size.height + p.size2 || p.y < -p.size2 - 10) continue;
      if (p.x < -10 || p.x > size.width + 10) continue;

      final effectiveAlpha = (p.color.a * p.opacity * intensity).clamp(
        0.0,
        1.0,
      );
      if (effectiveAlpha < 0.003) continue;

      _paint
        ..color = p.color.withValues(alpha: effectiveAlpha)
        ..strokeWidth = p.size;

      // Draw streak from current position downward by streak length.
      // Include a tiny horizontal component from drift velocity.
      final dx = p.vx * 0.015; // subtle angle
      canvas.drawLine(
        Offset(p.x, p.y),
        Offset(p.x + dx, p.y + p.size2),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(RainPainter oldDelegate) => true;
}
