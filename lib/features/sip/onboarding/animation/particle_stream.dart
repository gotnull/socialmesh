// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Private-messaging visual for the onboarding flow.
//
// A line of plain glyphs on the left dissolves into a stream of glowing
// particles that drift right and gather into a lock. It says, without words,
// "what you type becomes private" - the literal copy stays jargon-free.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Animated plaintext-to-encrypted particle stream ending in a lock.
class ParticleStream extends StatefulWidget {
  const ParticleStream({super.key, required this.accent, this.active = true});

  final Color accent;
  final bool active;

  @override
  State<ParticleStream> createState() => _ParticleStreamState();
}

class _ParticleStreamState extends State<ParticleStream>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(seconds: 5);
  static const int _particleCount = 22;

  late final AnimationController _controller;
  late final List<_Particle> _particles;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    final random = math.Random(23);
    _particles = List.generate(_particleCount, (i) {
      return _Particle(
        startFraction: random.nextDouble(),
        yJitter: (random.nextDouble() - 0.5) * 0.5,
        size: 1.8 + random.nextDouble() * 2.4,
        speed: 0.8 + random.nextDouble() * 0.5,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncMotion();
  }

  @override
  void didUpdateWidget(ParticleStream old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _syncMotion();
  }

  void _syncMotion() {
    if (widget.active && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    t: _reduceMotion ? 0.5 : _controller.value,
                    accent: widget.accent,
                    particles: _particles,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
          // Lock target on the right edge of the stream.
          Align(
            alignment: const Alignment(0.82, 0),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.card,
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.lock_outline, size: 24, color: widget.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.startFraction,
    required this.yJitter,
    required this.size,
    required this.speed,
  });

  final double startFraction;
  final double yJitter;
  final double size;
  final double speed;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.t,
    required this.accent,
    required this.particles,
  });

  final double t;
  final Color accent;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    // Stream runs from ~12% to ~80% of the width (lock sits at 82%).
    final startX = size.width * 0.12;
    final endX = size.width * 0.78;
    final span = endX - startX;

    for (final p in particles) {
      var progress = (p.startFraction + t * p.speed) % 1.0;
      final x = startX + span * progress;
      final y = midY + p.yJitter * size.height * 0.4 * (1 - progress);

      // Near the left the particle is a crisp glyph (plaintext); as it travels
      // right it loosens into a soft glowing dot (private).
      if (progress < 0.18) {
        final glyphAlpha = (1 - progress / 0.18).clamp(0.0, 1.0);
        final paint = Paint()
          ..color = accent.withValues(alpha: 0.5 * glyphAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        final r = Rect.fromCenter(
          center: Offset(x, y),
          width: p.size * 1.8,
          height: p.size * 1.8,
        );
        canvas.drawRect(r, paint);
      } else {
        final fade = progress > 0.85 ? (1 - progress) / 0.15 : 1.0;
        final glow = Paint()
          ..color = accent.withValues(alpha: 0.6 * fade.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(x, y), p.size, glow);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.t != t || old.accent != accent;
}
