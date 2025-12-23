import 'dart:math';

import 'package:flutter/material.dart';

/// Minimal, elegant radar sweep.
class AliensTrackerAnimation extends StatefulWidget {
  const AliensTrackerAnimation({super.key});

  @override
  State<AliensTrackerAnimation> createState() => _AliensTrackerAnimationState();
}

class _AliensTrackerAnimationState extends State<AliensTrackerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
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
          painter: _AliensTrackerPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _AliensTrackerPainter extends CustomPainter {
  _AliensTrackerPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(size.width, size.height) * 0.4;

    // Deep dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF040608),
    );

    // Accent color - modern teal
    const accent = Color(0xFF30d0a0);

    // Very subtle background grid
    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    for (var x = cx % 30; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = cy % 30; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Concentric rings - very thin
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * i / 4,
        Paint()
          ..color = accent.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    // Cross hairs
    canvas.drawLine(
      Offset(cx - radius, cy),
      Offset(cx + radius, cy),
      Paint()
        ..color = accent.withValues(alpha: 0.08)
        ..strokeWidth = 0.5,
    );
    canvas.drawLine(
      Offset(cx, cy - radius),
      Offset(cx, cy + radius),
      Paint()
        ..color = accent.withValues(alpha: 0.08)
        ..strokeWidth = 0.5,
    );

    // Sweep cone
    final sweepAngle = progress * 2 * pi;

    final sweepPath = Path();
    sweepPath.moveTo(cx, cy);
    for (var a = -0.25; a <= 0; a += 0.02) {
      final angle = sweepAngle + a;
      sweepPath.lineTo(cx + cos(angle) * radius, cy + sin(angle) * radius);
    }
    sweepPath.close();

    // Sweep gradient
    canvas.drawPath(
      sweepPath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.25),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
    );

    // Sweep line
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + cos(sweepAngle) * radius, cy + sin(sweepAngle) * radius),
      Paint()
        ..color = accent.withValues(alpha: 0.7)
        ..strokeWidth = 1.5,
    );

    // Contacts
    final contacts = [
      (angle: 0.6, dist: 0.7),
      (angle: 2.2, dist: 0.5),
      (angle: 3.8, dist: 0.85),
      (angle: 5.0, dist: 0.4),
    ];

    for (final c in contacts) {
      var angleDiff = (sweepAngle - c.angle) % (2 * pi);
      if (angleDiff < 0) angleDiff += 2 * pi;

      final fade = (1 - angleDiff / (2 * pi)).clamp(0.0, 1.0);
      final alpha = pow(fade, 0.5) * 0.9;

      if (alpha < 0.05) continue;

      final bx = cx + cos(c.angle) * radius * c.dist;
      final by = cy + sin(c.angle) * radius * c.dist;

      // Soft glow
      canvas.drawCircle(
        Offset(bx, by),
        8,
        Paint()..color = accent.withValues(alpha: alpha * 0.3),
      );
      // Core
      canvas.drawCircle(
        Offset(bx, by),
        3,
        Paint()..color = accent.withValues(alpha: alpha),
      );
    }

    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      3,
      Paint()..color = accent.withValues(alpha: 0.9),
    );

    // Outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = accent.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _AliensTrackerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
