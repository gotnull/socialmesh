// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Looping glitch animation with scan lines and distortion effects.
class GlitchRevealAnimation extends StatefulWidget {
  const GlitchRevealAnimation({super.key});

  @override
  State<GlitchRevealAnimation> createState() => _GlitchRevealAnimationState();
}

class _GlitchRevealAnimationState extends State<GlitchRevealAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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
          painter: _GlitchRevealPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GlitchRevealPainter extends CustomPainter {
  _GlitchRevealPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const accentColor = Color(0xFF00E5FF);
    const glitchColor = Color(0xFFFF0080);
    const scanLineColor = Color(0xFF0A1A2A);

    // Scan lines
    const scanLineHeight = 3.0;
    for (var y = 0.0; y < size.height; y += scanLineHeight * 2) {
      final scanPaint = Paint()..color = scanLineColor.withValues(alpha: 0.15);
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, scanLineHeight),
        scanPaint,
      );
    }

    // Moving scan line
    final scanY = (progress * size.height * 1.5) % (size.height + 100) - 50;
    final scanGlow = Paint()
      ..color = accentColor.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(Rect.fromLTWH(0, scanY - 4, size.width, 8), scanGlow);
    final scanLine = Paint()..color = accentColor.withValues(alpha: 0.4);
    canvas.drawRect(Rect.fromLTWH(0, scanY, size.width, 2), scanLine);

    // Glitch blocks (random positions based on time)
    final glitchSeed = (progress * 10).floor();
    final glitchRandom = Random(glitchSeed);

    if (progress > 0.7 || (progress > 0.2 && progress < 0.3)) {
      for (var i = 0; i < 5; i++) {
        final blockY = glitchRandom.nextDouble() * size.height;
        final blockHeight = 2.0 + glitchRandom.nextDouble() * 8;
        final offsetX = (glitchRandom.nextDouble() - 0.5) * 30;

        // Cyan offset
        final cyanPaint = Paint()..color = accentColor.withValues(alpha: 0.3);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, blockY, size.width, blockHeight),
          cyanPaint,
        );

        // Magenta offset
        final magentaPaint = Paint()
          ..color = glitchColor.withValues(alpha: 0.2);
        canvas.drawRect(
          Rect.fromLTWH(-offsetX, blockY + 2, size.width, blockHeight),
          magentaPaint,
        );
      }
    }

    // Noise dots
    final noiseSeed = (progress * 30).floor();
    final noiseRandom = Random(noiseSeed);
    for (var i = 0; i < 50; i++) {
      final x = noiseRandom.nextDouble() * size.width;
      final y = noiseRandom.nextDouble() * size.height;
      final dotSize = 1.0 + noiseRandom.nextDouble() * 2;
      final alpha = noiseRandom.nextDouble() * 0.2;

      final dotPaint = Paint()..color = accentColor.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(x, y, dotSize, dotSize), dotPaint);
    }

    // Edge glow
    final edgeGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        accentColor.withValues(alpha: 0.1),
        accentColor.withValues(alpha: 0.0),
        accentColor.withValues(alpha: 0.0),
        accentColor.withValues(alpha: 0.1),
      ],
      stops: const [0.0, 0.1, 0.9, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final edgePaint = Paint()..shader = edgeGradient;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), edgePaint);
  }

  @override
  bool shouldRepaint(covariant _GlitchRevealPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
