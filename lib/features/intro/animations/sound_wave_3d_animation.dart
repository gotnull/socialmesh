// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Sound waves visualized in 3D space.
class SoundWave3DAnimation extends StatefulWidget {
  const SoundWave3DAnimation({super.key});

  @override
  State<SoundWave3DAnimation> createState() => _SoundWave3DAnimationState();
}

class _SoundWave3DAnimationState extends State<SoundWave3DAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
          painter: _SoundWave3DPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SoundWave3DPainter extends CustomPainter {
  _SoundWave3DPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    // Gradient background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0a0a12), Color(0xFF101018), Color(0xFF0a0a12)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Sound source indicator
    canvas.drawCircle(
      Offset(cx * 0.3, cy),
      8,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF60a0ff),
                const Color(0xFF3060a0),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(cx * 0.3, cy), radius: 15),
            ),
    );

    // Pulsing glow
    final pulse = sin(time * 4) * 0.3 + 0.7;
    canvas.drawCircle(
      Offset(cx * 0.3, cy),
      20 * pulse,
      Paint()
        ..color = const Color(0xFF60a0ff).withValues(alpha: 0.2 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // 3D wave rings
    for (var ring = 0; ring < 12; ring++) {
      final ringProgress = (progress + ring / 12) % 1.0;
      final ringRadius = 30 + ringProgress * 300;
      final alpha = (1 - ringProgress) * 0.6;

      if (alpha < 0.05) continue;

      // Draw elliptical ring (3D perspective)
      final perspectiveFactor = 0.4; // Flatten for 3D look
      final rotationAngle = time * 0.3;

      final path = Path();
      for (var angle = 0.0; angle <= 2 * pi; angle += 0.05) {
        // Apply 3D rotation
        var x = cos(angle) * ringRadius;
        var y = sin(angle) * ringRadius * perspectiveFactor;

        // Rotate around Y axis
        final cosR = cos(rotationAngle);
        final sinR = sin(rotationAngle);
        final x2 = x * cosR;
        final z = x * sinR;

        // Project with depth
        final scale = 200 / (200 + z);
        final px = cx * 0.3 + x2 * scale;
        final py = cy + y * scale;

        if (angle == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();

      // Wave color based on frequency
      final hue = 200 + ring * 10.0;
      final color = HSVColor.fromAHSV(alpha, hue, 0.6, 0.9).toColor();

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - ringProgress * 0.5),
      );
    }

    // Waveform line
    final waveformPath = Path();
    for (var x = cx * 0.3; x < size.width; x += 2) {
      final distFromSource = x - cx * 0.3;
      final wavePhase = distFromSource * 0.03 - time * 3;
      final amplitude = 30 * exp(-distFromSource * 0.003);
      final y = cy + sin(wavePhase) * amplitude;

      if (x == cx * 0.3) {
        waveformPath.moveTo(x, y);
      } else {
        waveformPath.lineTo(x, y);
      }
    }

    canvas.drawPath(
      waveformPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF60a0ff).withValues(alpha: 0.8),
            const Color(0xFF60a0ff).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(cx * 0.3, cy - 50, size.width, 100))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Frequency spectrum bars
    final barCount = 32;
    final barWidth = size.width * 0.6 / barCount;
    final barStartX = size.width * 0.35;

    for (var i = 0; i < barCount; i++) {
      final freq = i / barCount;
      final amplitude = sin(time * 4 + freq * pi * 2) * 0.5 + 0.5;
      final barHeight = amplitude * 60 * (1 - freq * 0.5);

      final x = barStartX + i * barWidth;

      canvas.drawRect(
        Rect.fromLTWH(x, size.height - 30 - barHeight, barWidth - 1, barHeight),
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF3060a0),
                  const Color(0xFF60a0ff).withValues(alpha: amplitude),
                ],
              ).createShader(
                Rect.fromLTWH(
                  x,
                  size.height - 30 - barHeight,
                  barWidth,
                  barHeight,
                ),
              ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWave3DPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
