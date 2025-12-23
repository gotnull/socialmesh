import 'dart:math';

import 'package:flutter/material.dart';

/// Gravitational lensing with light bending around mass.
class GravityLensAnimation extends StatefulWidget {
  const GravityLensAnimation({super.key});

  @override
  State<GravityLensAnimation> createState() => _GravityLensAnimationState();
}

class _GravityLensAnimationState extends State<GravityLensAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
      builder: (context, child) {
        return CustomPaint(
          painter: _GravityLensPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GravityLensPainter extends CustomPainter {
  _GravityLensPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    // Deep space
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF020205),
    );

    // Background galaxy being lensed
    final galaxyAngle = time * 0.1;
    final galaxyX = cx + cos(galaxyAngle) * 300;
    final galaxyY = cy + sin(galaxyAngle) * 200;

    // Draw lensed light rays
    for (var ray = 0; ray < 60; ray++) {
      final rayAngle = ray * 2 * pi / 60;
      final startX = galaxyX + cos(rayAngle) * 400;
      final startY = galaxyY + sin(rayAngle) * 400;

      // Trace ray path bending around mass
      final path = Path();
      path.moveTo(startX, startY);

      var px = startX;
      var py = startY;
      var vx = (cx - startX) * 0.02;
      var vy = (cy - startY) * 0.02;

      for (var step = 0; step < 100; step++) {
        final dx = cx - px;
        final dy = cy - py;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < 30) break;

        // Gravitational deflection
        final force = 8000 / (dist * dist);
        vx += dx / dist * force * 0.001;
        vy += dy / dist * force * 0.001;

        px += vx;
        py += vy;

        path.lineTo(px, py);

        if (px < -50 ||
            px > size.width + 50 ||
            py < -50 ||
            py > size.height + 50) {
          break;
        }
      }

      // Color based on source position
      final hue = (rayAngle * 180 / pi + time * 30) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.5, 0.8).toColor();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Einstein ring
    final ringRadius = 60.0;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(cx, cy),
        ringRadius + i * 3,
        Paint()
          ..color = const Color(0xFFffa060).withValues(alpha: 0.3 - i * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 - i * 0.5,
      );
    }

    // Central mass (invisible but shown as dark disk)
    canvas.drawCircle(
      Offset(cx, cy),
      25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black,
            Colors.black,
            const Color(0xFF101020).withValues(alpha: 0.5),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 25)),
    );

    // Background stars (some distorted near center)
    final starRandom = Random(42);
    for (var i = 0; i < 150; i++) {
      var sx = starRandom.nextDouble() * size.width;
      var sy = starRandom.nextDouble() * size.height;

      // Lensing distortion for stars near center
      final dx = sx - cx;
      final dy = sy - cy;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist < 200 && dist > 30) {
        final angle = atan2(dy, dx);
        final lensStrength = 1500 / (dist * dist);
        sx = cx + cos(angle) * (dist + lensStrength * 50);
        sy = cy + sin(angle) * (dist + lensStrength * 50);
      }

      if (dist < 30) continue;

      final twinkle = sin(time * 3 + i) * 0.2 + 0.8;
      canvas.drawCircle(
        Offset(sx, sy),
        0.5 + starRandom.nextDouble(),
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.5),
      );
    }

    // Lensed galaxy arcs
    for (var arc = 0; arc < 4; arc++) {
      final arcAngle = arc * pi / 2 + time * 0.2;
      final arcPath = Path();

      for (var t = -0.4; t <= 0.4; t += 0.02) {
        final r = ringRadius + sin(t * 5 + time) * 5;
        final a = arcAngle + t;
        final x = cx + cos(a) * r;
        final y = cy + sin(a) * r;

        if (t == -0.4) {
          arcPath.moveTo(x, y);
        } else {
          arcPath.lineTo(x, y);
        }
      }

      canvas.drawPath(
        arcPath,
        Paint()
          ..color = const Color(0xFF80a0ff).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GravityLensPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
