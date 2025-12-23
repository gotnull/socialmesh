import 'dart:math';

import 'package:flutter/material.dart';

/// Bacterial colony growth simulation.
class BacteriaColonyAnimation extends StatefulWidget {
  const BacteriaColonyAnimation({super.key});

  @override
  State<BacteriaColonyAnimation> createState() =>
      _BacteriaColonyAnimationState();
}

class _BacteriaColonyAnimationState extends State<BacteriaColonyAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Bacterium> _bacteria = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
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
          painter: _BacteriaColonyPainter(_controller.value, _bacteria, (b) {
            if (!_initialized) {
              _bacteria.addAll(b);
              _initialized = true;
            }
          }),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Bacterium {
  _Bacterium(this.x, this.y, this.angle, this.hue, this.generation);

  double x, y, angle;
  double length = 5;
  double targetLength = 15 + Random().nextDouble() * 10;
  final double hue;
  final int generation;
  bool divided = false;
  double wigglePhase = Random().nextDouble() * 2 * pi;
}

class _BacteriaColonyPainter extends CustomPainter {
  _BacteriaColonyPainter(this.progress, this.bacteria, this.onInit);

  final double progress;
  final List<_Bacterium> bacteria;
  final Function(List<_Bacterium>) onInit;

  @override
  void paint(Canvas canvas, Size size) {
    // Petri dish background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF8F4E8),
    );

    // Agar texture
    final agarRandom = Random(33);
    for (var i = 0; i < 100; i++) {
      canvas.drawCircle(
        Offset(
          agarRandom.nextDouble() * size.width,
          agarRandom.nextDouble() * size.height,
        ),
        20 + agarRandom.nextDouble() * 40,
        Paint()..color = const Color(0xFFF0EBD8).withValues(alpha: 0.3),
      );
    }

    // Initialize bacteria if empty
    if (bacteria.isEmpty) {
      final initial = <_Bacterium>[];
      for (var i = 0; i < 5; i++) {
        initial.add(
          _Bacterium(
            size.width / 2 + (Random().nextDouble() - 0.5) * 50,
            size.height / 2 + (Random().nextDouble() - 0.5) * 50,
            Random().nextDouble() * 2 * pi,
            120 + Random().nextDouble() * 60,
            0,
          ),
        );
      }
      onInit(initial);
      return;
    }

    // Update and grow bacteria
    final toAdd = <_Bacterium>[];

    for (final b in bacteria) {
      // Wiggle
      b.wigglePhase += 0.1;
      b.angle += sin(b.wigglePhase) * 0.02;

      // Grow
      if (b.length < b.targetLength) {
        b.length += 0.15;
      } else if (!b.divided && bacteria.length < 300) {
        // Divide
        b.divided = true;
        b.length = b.targetLength * 0.5;
        b.targetLength = 15 + Random().nextDouble() * 10;

        final newAngle = b.angle + (Random().nextDouble() - 0.5) * 0.8;
        toAdd.add(
          _Bacterium(
            b.x + cos(b.angle) * b.length * 0.5,
            b.y + sin(b.angle) * b.length * 0.5,
            newAngle,
            (b.hue + Random().nextDouble() * 20 - 10).clamp(100, 200),
            b.generation + 1,
          ),
        );
      }

      // Slight drift
      b.x += cos(b.angle) * 0.1;
      b.y += sin(b.angle) * 0.1;

      // Keep in bounds
      b.x = b.x.clamp(20, size.width - 20);
      b.y = b.y.clamp(20, size.height - 20);
    }

    bacteria.addAll(toAdd);

    // Draw bacteria
    for (final b in bacteria) {
      final color = HSVColor.fromAHSV(1.0, b.hue, 0.6, 0.7).toColor();

      // Cell body (capsule shape)
      final startX = b.x - cos(b.angle) * b.length / 2;
      final startY = b.y - sin(b.angle) * b.length / 2;
      final endX = b.x + cos(b.angle) * b.length / 2;
      final endY = b.y + sin(b.angle) * b.length / 2;

      // Main body
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..color = color
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );

      // Membrane highlight
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );

      // Internal structure hint
      canvas.drawLine(
        Offset(startX + cos(b.angle) * 2, startY + sin(b.angle) * 2),
        Offset(endX - cos(b.angle) * 2, endY - sin(b.angle) * 2),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Petri dish rim
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      min(size.width, size.height) * 0.45,
      Paint()
        ..color = const Color(0xFFE0D8C8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
  }

  @override
  bool shouldRepaint(covariant _BacteriaColonyPainter oldDelegate) => true;
}
