// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Looping orbital rings animation with rotating ellipses.
class OrbitalRingsAnimation extends StatefulWidget {
  const OrbitalRingsAnimation({super.key});

  @override
  State<OrbitalRingsAnimation> createState() => _OrbitalRingsAnimationState();
}

class _OrbitalRingsAnimationState extends State<OrbitalRingsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
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
          painter: _OrbitalRingsPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _OrbitalRingsPainter extends CustomPainter {
  _OrbitalRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const accentColor = Color(0xFF00E5FF);
    const secondaryColor = Color(0xFF7C4DFF);

    final orbits = [
      _Orbit(
        radiusX: size.width * 0.35,
        radiusY: size.width * 0.12,
        tilt: 0.3,
        speed: 1.0,
      ),
      _Orbit(
        radiusX: size.width * 0.28,
        radiusY: size.width * 0.18,
        tilt: -0.5,
        speed: -0.7,
      ),
      _Orbit(
        radiusX: size.width * 0.22,
        radiusY: size.width * 0.08,
        tilt: 0.8,
        speed: 1.3,
      ),
    ];

    for (var i = 0; i < orbits.length; i++) {
      final orbit = orbits[i];
      final color = i.isEven ? accentColor : secondaryColor;
      final rotation = progress * 2 * pi * orbit.speed;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(orbit.tilt);

      // Draw orbit path
      final orbitPath = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: orbit.radiusX * 2,
            height: orbit.radiusY * 2,
          ),
        );

      final orbitPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(orbitPath, orbitPaint);

      // Draw orbiting object
      final objectAngle = rotation;
      final objectPos = Offset(
        cos(objectAngle) * orbit.radiusX,
        sin(objectAngle) * orbit.radiusY,
      );

      // Object glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(objectPos, 8, glowPaint);

      // Object trail
      for (var t = 1; t <= 5; t++) {
        final trailAngle = objectAngle - t * 0.15;
        final trailPos = Offset(
          cos(trailAngle) * orbit.radiusX,
          sin(trailAngle) * orbit.radiusY,
        );
        final trailPaint = Paint()
          ..color = color.withValues(alpha: 0.15 - t * 0.025);
        canvas.drawCircle(trailPos, 4 - t * 0.5, trailPaint);
      }

      // Object core
      final objectPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9),
            color,
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: objectPos, radius: 6));
      canvas.drawCircle(objectPos, 5, objectPaint);

      canvas.restore();
    }

    // Center core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.6),
          accentColor.withValues(alpha: 0.4),
          secondaryColor.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 30));
    canvas.drawCircle(center, 25, corePaint);

    // Center glow pulse
    final pulseAlpha = 0.2 + sin(progress * 4 * pi) * 0.1;
    final pulsePaint = Paint()
      ..color = accentColor.withValues(alpha: pulseAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, 35, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Orbit {
  const _Orbit({
    required this.radiusX,
    required this.radiusY,
    required this.tilt,
    required this.speed,
  });

  final double radiusX;
  final double radiusY;
  final double tilt;
  final double speed;
}
