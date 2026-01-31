// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Ferrofluid-like magnetic particles responding to invisible fields.
class FerrofluidAnimation extends StatefulWidget {
  const FerrofluidAnimation({super.key});

  @override
  State<FerrofluidAnimation> createState() => _FerrofluidAnimationState();
}

class _FerrofluidAnimationState extends State<FerrofluidAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
          painter: _FerrofluidPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FerrofluidPainter extends CustomPainter {
  _FerrofluidPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    // Dark metallic background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151518), Color(0xFF0a0a0c), Color(0xFF151518)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Magnetic field poles
    final poles = [
      (x: cx + cos(time) * 100, y: cy + sin(time * 0.7) * 80, strength: 1.0),
      (
        x: cx + cos(time * 1.3 + 2) * 120,
        y: cy + sin(time + 1) * 90,
        strength: 0.8,
      ),
      (
        x: cx + cos(time * 0.8 + 4) * 80,
        y: cy + sin(time * 1.2 + 3) * 70,
        strength: 0.6,
      ),
    ];

    // Draw ferrofluid spikes
    for (var ring = 0; ring < 8; ring++) {
      final ringRadius = 30.0 + ring * 25;

      for (var spike = 0; spike < 24 + ring * 4; spike++) {
        final baseAngle = spike * 2 * pi / (24 + ring * 4);
        final baseX = cx + cos(baseAngle) * ringRadius;
        final baseY = cy + sin(baseAngle) * ringRadius;

        // Calculate magnetic influence
        var totalForceX = 0.0;
        var totalForceY = 0.0;
        var totalStrength = 0.0;

        for (final pole in poles) {
          final dx = pole.x - baseX;
          final dy = pole.y - baseY;
          final dist = sqrt(dx * dx + dy * dy) + 1;
          final force = pole.strength * 5000 / (dist * dist);

          totalForceX += dx / dist * force;
          totalForceY += dy / dist * force;
          totalStrength += force;
        }

        // Spike length based on field strength
        final spikeLength = min(40.0, totalStrength * 0.5 + 5);
        final spikeAngle = atan2(totalForceY, totalForceX);

        // Spike tip
        final tipX = baseX + cos(spikeAngle) * spikeLength;
        final tipY = baseY + sin(spikeAngle) * spikeLength;

        // Draw spike as triangle
        final perpAngle = spikeAngle + pi / 2;
        final baseWidth = 3.0 + spikeLength * 0.1;

        final path = Path()
          ..moveTo(
            baseX + cos(perpAngle) * baseWidth,
            baseY + sin(perpAngle) * baseWidth,
          )
          ..lineTo(tipX, tipY)
          ..lineTo(
            baseX - cos(perpAngle) * baseWidth,
            baseY - sin(perpAngle) * baseWidth,
          )
          ..close();

        // Metallic gradient
        final brightness = 0.3 + (spikeLength / 40) * 0.5;
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(60, 60, 70, brightness),
                Color.fromRGBO(30, 30, 35, brightness),
                Color.fromRGBO(50, 50, 60, brightness),
              ],
            ).createShader(path.getBounds()),
        );

        // Highlight edge
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    // Central pool
    final poolPath = Path();
    for (var angle = 0.0; angle < 2 * pi; angle += 0.05) {
      final noise = sin(angle * 12 + time * 3) * 5;
      final r = 25 + noise;
      final x = cx + cos(angle) * r;
      final y = cy + sin(angle) * r;

      if (angle == 0) {
        poolPath.moveTo(x, y);
      } else {
        poolPath.lineTo(x, y);
      }
    }
    poolPath.close();

    canvas.drawPath(
      poolPath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF404050),
            const Color(0xFF252530),
            const Color(0xFF151518),
          ],
        ).createShader(poolPath.getBounds()),
    );

    // Reflection highlights
    canvas.drawCircle(
      Offset(cx - 8, cy - 8),
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
  }

  @override
  bool shouldRepaint(covariant _FerrofluidPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
