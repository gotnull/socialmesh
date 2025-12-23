import 'dart:math';

import 'package:flutter/material.dart';

/// Looping particle field animation with floating particles.
class ParticleFieldAnimation extends StatefulWidget {
  const ParticleFieldAnimation({super.key});

  @override
  State<ParticleFieldAnimation> createState() => _ParticleFieldAnimationState();
}

class _ParticleFieldAnimationState extends State<ParticleFieldAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();
  }

  void _generateParticles(Size size) {
    if (_initialized) return;

    const particleCount = 60;
    for (var i = 0; i < particleCount; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          vx: (_random.nextDouble() - 0.5) * 0.5,
          vy: -0.2 - _random.nextDouble() * 0.3,
          size: 1.0 + _random.nextDouble() * 3.0,
          alpha: 0.2 + _random.nextDouble() * 0.4,
          phase: _random.nextDouble(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _generateParticles(size);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ParticleFieldPainter(
                particles: _particles,
                progress: _controller.value,
                canvasSize: size,
              ),
              size: size,
            );
          },
        );
      },
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.phase,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final double alpha;
  final double phase;
}

class _ParticleFieldPainter extends CustomPainter {
  _ParticleFieldPainter({
    required this.particles,
    required this.progress,
    required this.canvasSize,
  });

  final List<_Particle> particles;
  final double progress;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    const accentColor = Color(0xFF00E5FF);
    const secondaryColor = Color(0xFF7C4DFF);

    for (final particle in particles) {
      final timeOffset = progress * 10000;
      var px = (particle.x + particle.vx * timeOffset) % canvasSize.width;
      var py = (particle.y + particle.vy * timeOffset) % canvasSize.height;
      if (py < 0) py += canvasSize.height;
      if (px < 0) px += canvasSize.width;

      final twinkle = sin((progress + particle.phase) * 2 * pi);
      final currentAlpha = particle.alpha * (0.6 + twinkle * 0.4);
      final currentSize = particle.size * (0.8 + twinkle * 0.2);

      final color = particle.phase > 0.5 ? accentColor : secondaryColor;

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: currentAlpha * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(px, py), currentSize + 3, glowPaint);

      // Core
      final corePaint = Paint()..color = color.withValues(alpha: currentAlpha);
      canvas.drawCircle(Offset(px, py), currentSize, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
