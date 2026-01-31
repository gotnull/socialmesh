// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Pulsating concentric circles like a speaker or sonar.
class PulseWaveAnimation extends StatefulWidget {
  const PulseWaveAnimation({super.key});

  @override
  State<PulseWaveAnimation> createState() => _PulseWaveAnimationState();
}

class _PulseWaveAnimationState extends State<PulseWaveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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
          painter: _PulseWavePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PulseWavePainter extends CustomPainter {
  _PulseWavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = sqrt(centerX * centerX + centerY * centerY);

    // Multiple pulse sources
    final sources = [
      (x: centerX, y: centerY, phase: 0.0, color: const Color(0xFF00FFFF)),
      (
        x: size.width * 0.2,
        y: size.height * 0.3,
        phase: 0.33,
        color: const Color(0xFFFF00FF),
      ),
      (
        x: size.width * 0.8,
        y: size.height * 0.7,
        phase: 0.66,
        color: const Color(0xFFFFFF00),
      ),
    ];

    for (final source in sources) {
      const waveCount = 8;

      for (var i = 0; i < waveCount; i++) {
        final waveProgress = (progress + source.phase + i / waveCount) % 1.0;
        final radius = waveProgress * maxRadius * 1.2;
        final alpha = (1 - waveProgress).clamp(0.0, 0.6);

        if (alpha <= 0) continue;

        // Wave thickness varies
        final thickness = 3 + sin(waveProgress * pi) * 4;

        // Glow
        final glowPaint = Paint()
          ..color = source.color.withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness + 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(source.x, source.y), radius, glowPaint);

        // Main ring
        final paint = Paint()
          ..color = source.color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness;
        canvas.drawCircle(Offset(source.x, source.y), radius, paint);
      }

      // Source point glow
      final sourceGlow = Paint()
        ..shader =
            RadialGradient(
              colors: [
                source.color.withValues(alpha: 0.8),
                source.color.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(source.x, source.y), radius: 30),
            );
      canvas.drawCircle(Offset(source.x, source.y), 30, sourceGlow);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
