// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Subtle biomechanical texture with organic movement.
class XenomorphAnimation extends StatefulWidget {
  const XenomorphAnimation({super.key});

  @override
  State<XenomorphAnimation> createState() => _XenomorphAnimationState();
}

class _XenomorphAnimationState extends State<XenomorphAnimation>
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
          painter: _XenomorphPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _XenomorphPainter extends CustomPainter {
  _XenomorphPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    // Dark organic background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color(0xFF0a0a0f),
            const Color(0xFF050508),
            const Color(0xFF020204),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Biomechanical ribbing
    for (var i = 0; i < 12; i++) {
      final ribProgress = (i / 12 + progress * 0.3) % 1.0;
      final ribY = -50 + ribProgress * (size.height + 100);
      final ribAlpha = (0.3 * sin(ribProgress * pi)).clamp(0.05, 0.3);

      // Main rib curve
      final path = Path();
      path.moveTo(0, ribY);

      for (var x = 0.0; x <= size.width; x += 10) {
        final wave = sin(x * 0.02 + time + i) * 15;
        final y = ribY + wave;
        path.lineTo(x, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF303040).withValues(alpha: ribAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + sin(ribProgress * pi) * 3,
      );

      // Secondary detail
      final detailPath = Path();
      detailPath.moveTo(0, ribY + 8);

      for (var x = 0.0; x <= size.width; x += 10) {
        final wave = sin(x * 0.02 + time + i + 0.5) * 12;
        final y = ribY + 8 + wave;
        detailPath.lineTo(x, y);
      }

      canvas.drawPath(
        detailPath,
        Paint()
          ..color = const Color(0xFF252530).withValues(alpha: ribAlpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Organic nodules
    final nodeRandom = Random(77);
    for (var i = 0; i < 25; i++) {
      final nodeX = nodeRandom.nextDouble() * size.width;
      final nodeY = nodeRandom.nextDouble() * size.height;
      final nodeSize = 8 + nodeRandom.nextDouble() * 15;
      final nodePulse = sin(time * 2 + i * 0.7) * 0.3 + 0.7;

      // Outer glow
      canvas.drawCircle(
        Offset(nodeX, nodeY),
        nodeSize * nodePulse,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  const Color(0xFF202030).withValues(alpha: 0.4),
                  const Color(0xFF151520).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(nodeX, nodeY), radius: nodeSize),
              ),
      );

      // Core
      canvas.drawCircle(
        Offset(nodeX, nodeY),
        nodeSize * 0.3 * nodePulse,
        Paint()
          ..color = const Color(0xFF404050).withValues(alpha: 0.5 * nodePulse),
      );
    }

    // Central creature silhouette hint
    final silhouettePath = Path();
    final headY = cy - 50 + sin(time) * 10;

    // Elongated head shape
    silhouettePath.moveTo(cx, headY - 60);
    silhouettePath.quadraticBezierTo(cx + 25, headY - 40, cx + 20, headY);
    silhouettePath.quadraticBezierTo(cx + 15, headY + 30, cx, headY + 50);
    silhouettePath.quadraticBezierTo(cx - 15, headY + 30, cx - 20, headY);
    silhouettePath.quadraticBezierTo(cx - 25, headY - 40, cx, headY - 60);
    silhouettePath.close();

    canvas.drawPath(
      silhouettePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.5),
          colors: [
            const Color(0xFF151520),
            const Color(0xFF0a0a0f),
            const Color(0xFF050508),
          ],
        ).createShader(silhouettePath.getBounds()),
    );

    // Subtle highlight edge
    canvas.drawPath(
      silhouettePath,
      Paint()
        ..color = const Color(0xFF303040).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Teeth hint
    for (var i = 0; i < 6; i++) {
      final toothX = cx - 12 + i * 5;
      final toothY = headY + 40 + sin(time * 3 + i) * 2;
      final toothHeight = 8 + sin(time * 2 + i * 0.5) * 2;

      canvas.drawLine(
        Offset(toothX, toothY),
        Offset(toothX, toothY + toothHeight),
        Paint()
          ..color = const Color(0xFF505060).withValues(alpha: 0.4)
          ..strokeWidth = 1.5,
      );
    }

    // Dripping effect
    for (var i = 0; i < 5; i++) {
      final dripX = cx - 20 + i * 10 + sin(time + i) * 3;
      final dripProgress = (progress * 2 + i * 0.15) % 1.0;
      final dripY = headY + 50 + dripProgress * 100;
      final dripAlpha = (1 - dripProgress) * 0.4;

      if (dripAlpha > 0.05) {
        canvas.drawCircle(
          Offset(dripX, dripY),
          2 + (1 - dripProgress) * 2,
          Paint()..color = const Color(0xFF40a060).withValues(alpha: dripAlpha),
        );

        // Drip trail
        canvas.drawLine(
          Offset(dripX, dripY - 15),
          Offset(dripX, dripY),
          Paint()
            ..color = const Color(0xFF40a060).withValues(alpha: dripAlpha * 0.5)
            ..strokeWidth = 1,
        );
      }
    }

    // Atmospheric mist
    for (var i = 0; i < 5; i++) {
      final mistX = (i / 5) * size.width;
      final mistY = size.height * 0.7 + sin(time * 0.5 + i) * 30;

      canvas.drawCircle(
        Offset(mistX, mistY),
        100,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  const Color(0xFF203030).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(mistX, mistY), radius: 100),
              ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _XenomorphPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
