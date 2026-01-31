// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Crystal growth simulation.
class CrystalGrowthAnimation extends StatefulWidget {
  const CrystalGrowthAnimation({super.key});

  @override
  State<CrystalGrowthAnimation> createState() => _CrystalGrowthAnimationState();
}

class _CrystalGrowthAnimationState extends State<CrystalGrowthAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
          painter: _CrystalGrowthPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CrystalGrowthPainter extends CustomPainter {
  _CrystalGrowthPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    // Dark solution background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1a1825),
            const Color(0xFF0f0d15),
            const Color(0xFF080610),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Crystal clusters
    final clusters = [
      (x: cx, y: cy, scale: 1.0, hue: 280.0),
      (x: cx - 100, y: cy + 80, scale: 0.6, hue: 260.0),
      (x: cx + 120, y: cy - 60, scale: 0.5, hue: 300.0),
      (x: cx - 80, y: cy - 100, scale: 0.4, hue: 240.0),
    ];

    for (final cluster in clusters) {
      _drawCrystalCluster(
        canvas,
        cluster.x,
        cluster.y,
        cluster.scale,
        cluster.hue,
        time,
        progress,
      );
    }

    // Floating particles (molecules in solution)
    final particleRandom = Random(55);
    for (var i = 0; i < 50; i++) {
      final px = particleRandom.nextDouble() * size.width;
      final py = particleRandom.nextDouble() * size.height;
      final drift = sin(time * 2 + i) * 3;

      canvas.drawCircle(
        Offset(px + drift, py + drift * 0.5),
        1 + particleRandom.nextDouble(),
        Paint()..color = const Color(0xFF8060a0).withValues(alpha: 0.3),
      );
    }
  }

  void _drawCrystalCluster(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    double baseHue,
    double time,
    double progress,
  ) {
    final random = Random((cx * cy).toInt());
    final crystalCount = 5 + random.nextInt(4);

    for (var c = 0; c < crystalCount; c++) {
      final angle = c * 2 * pi / crystalCount + random.nextDouble() * 0.3;
      final length = (40 + random.nextDouble() * 60) * scale * progress;
      final width = (8 + random.nextDouble() * 12) * scale;

      _drawCrystal(
        canvas,
        cx,
        cy,
        angle,
        length,
        width,
        baseHue + random.nextDouble() * 40 - 20,
        time,
      );
    }
  }

  void _drawCrystal(
    Canvas canvas,
    double cx,
    double cy,
    double angle,
    double length,
    double width,
    double hue,
    double time,
  ) {
    final tipX = cx + cos(angle) * length;
    final tipY = cy + sin(angle) * length;

    final perpAngle = angle + pi / 2;
    final halfWidth = width / 2;

    // Crystal body (hexagonal prism simplified to diamond)
    final path = Path();

    // Base
    path.moveTo(
      cx + cos(perpAngle) * halfWidth,
      cy + sin(perpAngle) * halfWidth,
    );

    // Side to tip
    path.lineTo(tipX, tipY);

    // Other side back to base
    path.lineTo(
      cx - cos(perpAngle) * halfWidth,
      cy - sin(perpAngle) * halfWidth,
    );

    path.close();

    // Crystal color with transparency
    final baseColor = HSVColor.fromAHSV(1.0, hue, 0.4, 0.7).toColor();

    // Main body
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.6),
            baseColor.withValues(alpha: 0.3),
            baseColor.withValues(alpha: 0.5),
          ],
        ).createShader(path.getBounds()),
    );

    // Facet lines
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Internal refraction line
    canvas.drawLine(
      Offset(cx, cy),
      Offset(tipX, tipY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1,
    );

    // Highlight facet
    final highlightPath = Path();
    highlightPath.moveTo(cx, cy);
    highlightPath.lineTo(
      cx + cos(perpAngle) * halfWidth * 0.5,
      cy + sin(perpAngle) * halfWidth * 0.5,
    );
    highlightPath.lineTo(
      cx + cos(angle) * length * 0.7 + cos(perpAngle) * halfWidth * 0.2,
      cy + sin(angle) * length * 0.7 + sin(perpAngle) * halfWidth * 0.2,
    );
    highlightPath.close();

    canvas.drawPath(
      highlightPath,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // Sparkle at tip
    final sparkle = (sin(time * 3 + angle * 5) + 1) / 2;
    if (sparkle > 0.7) {
      canvas.drawCircle(
        Offset(tipX, tipY),
        2 + sparkle * 2,
        Paint()..color = Colors.white.withValues(alpha: sparkle * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrystalGrowthPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
