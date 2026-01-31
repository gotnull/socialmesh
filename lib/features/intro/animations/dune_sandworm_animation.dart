// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Elegant desert landscape with subtle sandworm motion.
class DuneSandwormAnimation extends StatefulWidget {
  const DuneSandwormAnimation({super.key});

  @override
  State<DuneSandwormAnimation> createState() => _DuneSandwormAnimationState();
}

class _DuneSandwormAnimationState extends State<DuneSandwormAnimation>
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
          painter: _DuneSandwormPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _DuneSandwormPainter extends CustomPainter {
  _DuneSandwormPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Sky gradient - warm dusk
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1020),
            Color(0xFF402030),
            Color(0xFF804020),
            Color(0xFFc08040),
          ],
          stops: [0.0, 0.3, 0.6, 0.85],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Twin moons
    final moon1x = size.width * 0.3;
    final moon1y = size.height * 0.15;
    canvas.drawCircle(
      Offset(moon1x, moon1y),
      20,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.9),
                const Color(0xFFffe0c0).withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(moon1x, moon1y), radius: 30),
            ),
    );

    final moon2x = size.width * 0.75;
    final moon2y = size.height * 0.22;
    canvas.drawCircle(
      Offset(moon2x, moon2y),
      14,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFffa080).withValues(alpha: 0.8),
                const Color(0xFFff8060).withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(moon2x, moon2y), radius: 22),
            ),
    );

    // Stars
    final starRandom = Random(77);
    for (var i = 0; i < 40; i++) {
      if (starRandom.nextDouble() > 0.3) {
        final sx = starRandom.nextDouble() * size.width;
        final sy = starRandom.nextDouble() * size.height * 0.4;
        final twinkle = sin(time * 3 + i) * 0.2 + 0.6;

        canvas.drawCircle(
          Offset(sx, sy),
          0.5 + starRandom.nextDouble() * 0.5,
          Paint()..color = Colors.white.withValues(alpha: twinkle * 0.4),
        );
      }
    }

    // Dune layers
    final horizonY = size.height * 0.5;
    _drawDuneLayer(canvas, size, horizonY, 0.2, const Color(0xFF603020), time);
    _drawDuneLayer(
      canvas,
      size,
      horizonY + 40,
      0.4,
      const Color(0xFF804030),
      time * 0.8,
    );
    _drawDuneLayer(
      canvas,
      size,
      horizonY + 90,
      0.6,
      const Color(0xFFa05040),
      time * 0.6,
    );

    // Sandworm emerging
    final wormPhase = (progress * 2) % 1.0;
    final wormVisible = wormPhase < 0.5;

    if (wormVisible) {
      final wormX = size.width * 0.6;
      final baseY = horizonY + 60;
      final emergeAmount = sin(wormPhase * pi);

      // Worm segments
      for (var i = 0; i < 6; i++) {
        final segmentDelay = i * 0.05;
        final segmentEmerge = (emergeAmount - segmentDelay).clamp(0.0, 1.0);

        if (segmentEmerge > 0) {
          final segY = baseY - segmentEmerge * 100 + i * 15;
          final segSize = 25 - i * 3.0;
          final segX = wormX + sin(time * 2 + i * 0.5) * 10;

          // Segment body
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(segX, segY),
              width: segSize,
              height: segSize * 1.5,
            ),
            Paint()
              ..shader =
                  RadialGradient(
                    colors: [
                      const Color(0xFFd0a080),
                      const Color(0xFF906050),
                      const Color(0xFF604030),
                    ],
                  ).createShader(
                    Rect.fromCenter(
                      center: Offset(segX, segY),
                      width: segSize,
                      height: segSize * 1.5,
                    ),
                  ),
          );

          // Texture lines
          if (i < 3) {
            for (var j = 0; j < 3; j++) {
              canvas.drawLine(
                Offset(
                  segX - segSize * 0.3 + j * segSize * 0.3,
                  segY - segSize * 0.3,
                ),
                Offset(
                  segX - segSize * 0.3 + j * segSize * 0.3,
                  segY + segSize * 0.5,
                ),
                Paint()
                  ..color = const Color(0xFF402020).withValues(alpha: 0.4)
                  ..strokeWidth = 1,
              );
            }
          }
        }
      }

      // Sand spray
      final sprayRandom = Random(42);
      for (var i = 0; i < 20; i++) {
        final sprayX = wormX + sprayRandom.nextDouble() * 80 - 40;
        final sprayHeight = emergeAmount * (30 + sprayRandom.nextDouble() * 40);
        final sprayY = baseY - sprayHeight;
        final sprayAlpha = emergeAmount * 0.4 * (1 - sprayHeight / 70);

        canvas.drawCircle(
          Offset(sprayX, sprayY),
          1 + sprayRandom.nextDouble() * 2,
          Paint()
            ..color = const Color(
              0xFFd0a060,
            ).withValues(alpha: sprayAlpha.clamp(0.0, 0.4)),
        );
      }
    }

    // Foreground dune
    _drawDuneLayer(
      canvas,
      size,
      horizonY + 150,
      0.9,
      const Color(0xFFb06050),
      time * 0.4,
    );

    // Atmospheric haze
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFc08040).withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
            ),
    );
  }

  void _drawDuneLayer(
    Canvas canvas,
    Size size,
    double baseY,
    double parallax,
    Color color,
    double time,
  ) {
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, baseY);

    for (var x = 0.0; x <= size.width; x += 5) {
      final wave1 = sin(x * 0.01 + time * parallax) * 20;
      final wave2 = sin(x * 0.02 + time * parallax * 0.5) * 10;
      final y = baseY + wave1 + wave2;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = color);

    // Subtle highlight
    final highlightPath = Path();
    highlightPath.moveTo(0, baseY);

    for (var x = 0.0; x <= size.width; x += 5) {
      final wave1 = sin(x * 0.01 + time * parallax) * 20;
      final wave2 = sin(x * 0.02 + time * parallax * 0.5) * 10;
      final y = baseY + wave1 + wave2;
      highlightPath.lineTo(x, y);
    }

    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _DuneSandwormPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
