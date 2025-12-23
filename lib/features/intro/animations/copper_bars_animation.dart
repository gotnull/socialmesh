import 'dart:math';

import 'package:flutter/material.dart';

/// Amiga copper bars effect - horizontal gradient bars.
class CopperBarsAnimation extends StatefulWidget {
  const CopperBarsAnimation({super.key});

  @override
  State<CopperBarsAnimation> createState() => _CopperBarsAnimationState();
}

class _CopperBarsAnimationState extends State<CopperBarsAnimation>
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
          painter: _CopperBarsPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CopperBarsPainter extends CustomPainter {
  _CopperBarsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Draw scanlines background
    for (var y = 0.0; y < size.height; y += 2) {
      final paint = Paint()..color = const Color(0xFF0A0A0A);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }

    // Multiple copper bar groups
    const barGroups = 5;
    for (var g = 0; g < barGroups; g++) {
      final groupPhase = g * 1.2;
      final baseY =
          size.height * 0.2 +
          sin(time * 0.8 + groupPhase) * size.height * 0.15 +
          g * (size.height * 0.15);

      // Each bar has metallic gradient
      const barLines = 20;
      for (var i = 0; i < barLines; i++) {
        final y = baseY + i;
        if (y < 0 || y > size.height) continue;

        // Metallic shading - bright in center, dark at edges
        final shade = sin(i / barLines * pi);
        final hue = (g * 60 + progress * 120) % 360;

        final color = HSVColor.fromAHSV(
          1.0,
          hue,
          0.6 - shade * 0.4,
          shade * 0.8 + 0.2,
        ).toColor();

        final paint = Paint()..color = color;
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
      }

      // Highlight line
      final highlightY = baseY + barLines * 0.3;
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRect(
        Rect.fromLTWH(0, highlightY, size.width, 2),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CopperBarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
