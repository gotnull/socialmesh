import 'dart:math';

import 'package:flutter/material.dart';

/// Sine wave ocean/waveform animation.
class WaveformAnimation extends StatefulWidget {
  const WaveformAnimation({super.key});

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
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
          painter: _WaveformPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final time = progress * 2 * pi;

    // Multiple wave layers
    final waves = [
      (
        amplitude: size.height * 0.15,
        frequency: 2.0,
        speed: 1.0,
        color: const Color(0xFF0044FF),
        offset: 0.0,
      ),
      (
        amplitude: size.height * 0.12,
        frequency: 3.0,
        speed: 1.5,
        color: const Color(0xFF0088FF),
        offset: size.height * 0.05,
      ),
      (
        amplitude: size.height * 0.1,
        frequency: 4.0,
        speed: 2.0,
        color: const Color(0xFF00CCFF),
        offset: size.height * 0.1,
      ),
      (
        amplitude: size.height * 0.08,
        frequency: 5.0,
        speed: 2.5,
        color: const Color(0xFF00FFFF),
        offset: size.height * 0.15,
      ),
    ];

    // Draw waves from back to front
    for (final wave in waves.reversed) {
      final path = Path();
      path.moveTo(0, size.height);

      // Bottom of wave
      for (var x = 0.0; x <= size.width; x += 2) {
        final normalizedX = x / size.width;
        final y =
            centerY +
            wave.offset +
            sin(normalizedX * wave.frequency * 2 * pi + time * wave.speed) *
                wave.amplitude +
            sin(
                  normalizedX * wave.frequency * 1.5 * 2 * pi +
                      time * wave.speed * 0.7,
                ) *
                wave.amplitude *
                0.3;

        if (x == 0) {
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      path.lineTo(size.width, size.height);
      path.close();

      // Fill gradient
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            wave.color.withValues(alpha: 0.6),
            wave.color.withValues(alpha: 0.2),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(path, fillPaint);

      // Draw wave line on top
      final linePath = Path();
      for (var x = 0.0; x <= size.width; x += 2) {
        final normalizedX = x / size.width;
        final y =
            centerY +
            wave.offset +
            sin(normalizedX * wave.frequency * 2 * pi + time * wave.speed) *
                wave.amplitude +
            sin(
                  normalizedX * wave.frequency * 1.5 * 2 * pi +
                      time * wave.speed * 0.7,
                ) *
                wave.amplitude *
                0.3;

        if (x == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }
      }

      // Glow
      final glowPaint = Paint()
        ..color = wave.color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(linePath, glowPaint);

      // Line
      final linePaint = Paint()
        ..color = wave.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(linePath, linePaint);
    }

    // Particles floating on waves
    for (var i = 0; i < 15; i++) {
      final particleX = (i / 15 + progress * 0.2) % 1.0 * size.width;
      final normalizedX = particleX / size.width;
      final particleY =
          centerY +
          sin(normalizedX * 2 * 2 * pi + time) * size.height * 0.15 -
          10;

      final particlePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(particleX, particleY), 4, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
