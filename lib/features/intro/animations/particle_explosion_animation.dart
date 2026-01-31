// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Particle explosion/implosion animation.
class ParticleExplosionAnimation extends StatefulWidget {
  const ParticleExplosionAnimation({super.key});

  @override
  State<ParticleExplosionAnimation> createState() =>
      _ParticleExplosionAnimationState();
}

class _ParticleExplosionAnimationState extends State<ParticleExplosionAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  void _initParticles(Size size) {
    if (_initialized) return;
    final random = Random();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (var i = 0; i < 200; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 50 + random.nextDouble() * 200;
      final size = 2 + random.nextDouble() * 6;

      _particles.add(
        _Particle(
          angle: angle,
          speed: speed,
          size: size,
          hue: random.nextDouble() * 360,
          startX: centerX,
          startY: centerY,
        ),
      );
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticleExplosionPainter(
            progress: _controller.value,
            particles: _particles,
            onInit: _initParticles,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.hue,
    required this.startX,
    required this.startY,
  });

  final double angle;
  final double speed;
  final double size;
  final double hue;
  final double startX;
  final double startY;
}

class _ParticleExplosionPainter extends CustomPainter {
  _ParticleExplosionPainter({
    required this.progress,
    required this.particles,
    required this.onInit,
  });

  final double progress;
  final List<_Particle> particles;
  final void Function(Size) onInit;

  @override
  void paint(Canvas canvas, Size size) {
    onInit(size);

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Explosion/implosion cycle
    // 0-0.5: explosion, 0.5-1: implosion
    final cycleProgress = progress * 2;
    final isExploding = cycleProgress < 1;
    final phaseProgress = isExploding ? cycleProgress : 2 - cycleProgress;

    // Eased progress for smoother motion
    final easedProgress = _easeOutQuad(phaseProgress);

    // Central glow (inverse of explosion)
    final coreSize = isExploding
        ? (1 - easedProgress) * 80 + 20
        : easedProgress * 80 + 20;
    final corePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(
                alpha: isExploding ? 1 - easedProgress : easedProgress,
              ),
              const Color(0xFFFFAA00).withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: coreSize),
          );
    canvas.drawCircle(Offset(centerX, centerY), coreSize, corePaint);

    // Draw particles
    for (final p in particles) {
      final distance = p.speed * easedProgress;
      final x = centerX + cos(p.angle) * distance;
      final y = centerY + sin(p.angle) * distance;

      // Skip if off screen
      if (x < -10 || x > size.width + 10 || y < -10 || y > size.height + 10) {
        continue;
      }

      // Fade based on distance
      final maxDist =
          sqrt(size.width * size.width + size.height * size.height) / 2;
      final alpha = (1 - distance / maxDist).clamp(0.0, 1.0);

      // Color shifts during animation
      final hue = (p.hue + progress * 180) % 360;
      final color = HSVColor.fromAHSV(alpha, hue, 0.8, 1.0).toColor();

      // Particle trail
      if (easedProgress > 0.1) {
        final trailLength = min(distance * 0.3, 30.0);
        final trailEndX = x - cos(p.angle) * trailLength;
        final trailEndY = y - sin(p.angle) * trailLength;

        final trailPaint = Paint()
          ..shader = LinearGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(
                Rect.fromPoints(Offset(x, y), Offset(trailEndX, trailEndY)),
              )
          ..strokeWidth = p.size * 0.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x, y), Offset(trailEndX, trailEndY), trailPaint);
      }

      // Particle glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size);
      canvas.drawCircle(Offset(x, y), p.size * 1.5, glowPaint);

      // Particle core
      final particlePaint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), p.size * 0.5, particlePaint);
    }

    // Shockwave ring during explosion
    if (isExploding && easedProgress > 0.1 && easedProgress < 0.8) {
      final ringRadius = easedProgress * size.width * 0.6;
      final ringAlpha = (1 - easedProgress) * 0.5;

      final ringPaint = Paint()
        ..color = const Color(0xFFFFAA00).withValues(alpha: ringAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(centerX, centerY), ringRadius, ringPaint);
    }
  }

  double _easeOutQuad(double t) => 1 - (1 - t) * (1 - t);

  @override
  bool shouldRepaint(covariant _ParticleExplosionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
