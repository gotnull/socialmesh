// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Retro scanlines with CRT monitor effect.
class ScanlineAnimation extends StatefulWidget {
  const ScanlineAnimation({super.key});

  @override
  State<ScanlineAnimation> createState() => _ScanlineAnimationState();
}

class _ScanlineAnimationState extends State<ScanlineAnimation>
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
          painter: _ScanlinePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Background with color shift
    final bgHue = (progress * 60) % 360;
    final bgColor = HSVColor.fromAHSV(1.0, bgHue, 0.3, 0.1).toColor();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // Draw animated content behind scanlines
    _drawRetroContent(canvas, size, time);

    // CRT curvature effect (vignette)
    final vignettePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.7),
            ],
            stops: const [0.5, 0.8, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: size.width * 1.2,
              height: size.height * 1.2,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      vignettePaint,
    );

    // Scanlines
    const scanlineSpacing = 3.0;
    final scanlinePaint = Paint()..color = Colors.black.withValues(alpha: 0.3);

    for (var y = 0.0; y < size.height; y += scanlineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // Moving bright scanline
    final brightScanY = (progress * size.height * 2) % (size.height + 50) - 25;
    final brightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, brightScanY - 20, size.width, 40));
    canvas.drawRect(
      Rect.fromLTWH(0, brightScanY - 20, size.width, 40),
      brightPaint,
    );

    // RGB shift effect on edges
    final rgbShift = sin(time * 3) * 2;
    _drawRGBGhost(canvas, size, rgbShift);

    // Static noise
    final random = Random((progress * 1000).toInt());
    final noisePaint = Paint();
    for (var i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final alpha = random.nextDouble() * 0.1;
      noisePaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), noisePaint);
    }
  }

  void _drawRetroContent(Canvas canvas, Size size, double time) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Rotating geometric shapes
    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(time * 0.5);

    // Concentric squares
    for (var i = 5; i >= 0; i--) {
      final squareSize = 50.0 + i * 40;
      final hue = (i * 60 + progress * 360) % 360;
      final color = HSVColor.fromAHSV(0.8, hue, 0.8, 0.9).toColor();

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: squareSize,
          height: squareSize,
        ),
        paint,
      );
    }

    canvas.restore();

    // Bouncing text-like bars
    for (var row = 0; row < 5; row++) {
      final rowY = size.height * 0.2 + row * 50;
      final barCount = 8 + row * 2;
      final barWidth = size.width / barCount * 0.8;

      for (var i = 0; i < barCount; i++) {
        final barX = i * (size.width / barCount) + 10;
        final barHeight = 20 + sin(time * 3 + i * 0.5 + row) * 15;

        final hue = (i * 20 + row * 30 + progress * 180) % 360;
        final color = HSVColor.fromAHSV(0.9, hue, 0.7, 0.9).toColor();

        final barPaint = Paint()..color = color;
        canvas.drawRect(
          Rect.fromLTWH(barX, rowY - barHeight / 2, barWidth, barHeight),
          barPaint,
        );
      }
    }
  }

  void _drawRGBGhost(Canvas canvas, Size size, double shift) {
    // Red ghost on left
    final redPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.1)
      ..blendMode = BlendMode.screen;
    canvas.drawRect(
      Rect.fromLTWH(-shift, 0, size.width, size.height),
      redPaint,
    );

    // Blue ghost on right
    final bluePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.1)
      ..blendMode = BlendMode.screen;
    canvas.drawRect(
      Rect.fromLTWH(shift, 0, size.width, size.height),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
