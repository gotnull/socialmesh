import 'dart:math';

import 'package:flutter/material.dart';

/// Holographic interference pattern animation.
class HologramAnimation extends StatefulWidget {
  const HologramAnimation({super.key});

  @override
  State<HologramAnimation> createState() => _HologramAnimationState();
}

class _HologramAnimationState extends State<HologramAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
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
          painter: _HologramPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HologramPainter extends CustomPainter {
  _HologramPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final time = progress * 2 * pi;

    // Dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF001111),
    );

    // Holographic scan lines
    final scanY = (progress * size.height * 1.5) % (size.height + 100) - 50;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF00FFFF).withValues(alpha: 0.1),
          const Color(0xFF00FFFF).withValues(alpha: 0.3),
          const Color(0xFF00FFFF).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 30, size.width, 60));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 30, size.width, 60), scanPaint);

    // Horizontal interference lines
    for (var y = 0.0; y < size.height; y += 4) {
      final intensity = sin(y * 0.1 + time * 5) * 0.5 + 0.5;
      final linePaint = Paint()
        ..color = const Color(0xFF00FFFF).withValues(alpha: intensity * 0.1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Central holographic shape - rotating geometric form
    canvas.save();
    canvas.translate(centerX, centerY);

    // Multiple rotating wireframe shapes
    for (var shape = 0; shape < 3; shape++) {
      final shapeSize = (size.width * 0.25) * (1 - shape * 0.2);
      final rotation = time * (shape % 2 == 0 ? 1 : -1) + shape * pi / 3;
      final verticalOffset = sin(time * 2 + shape) * 20;

      canvas.save();
      canvas.translate(0, verticalOffset);
      canvas.rotate(rotation);

      // Draw icosahedron-like wireframe
      _drawWireframeShape(canvas, shapeSize, time, shape);

      canvas.restore();
    }

    canvas.restore();

    // Glitch effect - random horizontal shifts
    final random = Random((progress * 100).toInt());
    for (var i = 0; i < 5; i++) {
      if (random.nextDouble() > 0.7) {
        final glitchY = random.nextDouble() * size.height;
        final glitchHeight = 5 + random.nextDouble() * 20;
        final glitchShift = (random.nextDouble() - 0.5) * 30;

        final glitchPaint = Paint()
          ..color = const Color(0xFF00FFFF).withValues(alpha: 0.3)
          ..blendMode = BlendMode.screen;

        canvas.drawRect(
          Rect.fromLTWH(glitchShift, glitchY, size.width, glitchHeight),
          glitchPaint,
        );
      }
    }

    // Edge chromatic aberration
    final leftEdge = Paint()
      ..color = Colors.red.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawRect(Rect.fromLTWH(-10, 0, 40, size.height), leftEdge);

    final rightEdge = Paint()
      ..color = Colors.blue.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 30, 0, 40, size.height),
      rightEdge,
    );
  }

  void _drawWireframeShape(Canvas canvas, double size, double time, int index) {
    final hue = (index * 120 + progress * 180) % 360;
    final color = HSVColor.fromAHSV(0.9, hue, 0.5, 1.0).toColor();

    // Generate vertices for a complex shape
    final vertices = <Offset>[];
    const sides = 8;

    for (var i = 0; i < sides; i++) {
      final angle = (i / sides) * 2 * pi;
      final wobble = sin(angle * 3 + time * 2) * size * 0.1;
      vertices.add(
        Offset(cos(angle) * (size + wobble), sin(angle) * (size + wobble)),
      );
    }

    // Draw edges
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Connect all vertices
    for (var i = 0; i < vertices.length; i++) {
      for (var j = i + 1; j < vertices.length; j++) {
        // Skip some connections for visual interest
        if ((i + j) % 3 == 0) continue;

        canvas.drawLine(vertices[i], vertices[j], glowPaint);
        canvas.drawLine(vertices[i], vertices[j], paint);
      }
    }

    // Draw vertices as points
    for (final v in vertices) {
      final pointPaint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(v, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HologramPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
