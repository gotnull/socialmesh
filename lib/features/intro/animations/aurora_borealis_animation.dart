import 'dart:math';

import 'package:flutter/material.dart';

/// Aurora borealis with realistic curtain movement.
class AuroraBorealisAnimation extends StatefulWidget {
  const AuroraBorealisAnimation({super.key});

  @override
  State<AuroraBorealisAnimation> createState() =>
      _AuroraBorealisAnimationState();
}

class _AuroraBorealisAnimationState extends State<AuroraBorealisAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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
          painter: _AuroraBorealisPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _AuroraBorealisPainter extends CustomPainter {
  _AuroraBorealisPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Night sky gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000510),
            Color(0xFF051020),
            Color(0xFF0a1525),
            Color(0xFF101520),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Stars
    final starRandom = Random(88);
    for (var i = 0; i < 100; i++) {
      final sx = starRandom.nextDouble() * size.width;
      final sy = starRandom.nextDouble() * size.height * 0.7;
      final twinkle = sin(time * 2 + i) * 0.3 + 0.7;

      canvas.drawCircle(
        Offset(sx, sy),
        0.5 + starRandom.nextDouble(),
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.6),
      );
    }

    // Aurora curtains
    for (var curtain = 0; curtain < 5; curtain++) {
      _drawAuroraCurtain(
        canvas,
        size,
        time,
        curtain,
        0.15 + curtain * 0.12,
        HSVColor.fromAHSV(1.0, 120 + curtain * 30.0, 0.8, 0.9).toColor(),
      );
    }

    // Subtle mountain silhouette
    final mountainPath = Path();
    mountainPath.moveTo(0, size.height);

    final mountainRandom = Random(77);
    var mx = 0.0;
    while (mx < size.width) {
      final peakHeight =
          size.height * (0.75 + mountainRandom.nextDouble() * 0.15);
      final nextX = mx + 30 + mountainRandom.nextDouble() * 50;
      mountainPath.lineTo(mx + (nextX - mx) / 2, peakHeight);
      mountainPath.lineTo(nextX, size.height * 0.9);
      mx = nextX;
    }
    mountainPath.lineTo(size.width, size.height);
    mountainPath.close();

    canvas.drawPath(mountainPath, Paint()..color = const Color(0xFF050810));

    // Ground reflection hint
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.92, size.width, size.height * 0.08),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF20a060).withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(
                0,
                size.height * 0.92,
                size.width,
                size.height * 0.08,
              ),
            ),
    );
  }

  void _drawAuroraCurtain(
    Canvas canvas,
    Size size,
    double time,
    int index,
    double baseY,
    Color color,
  ) {
    final rayCount = 40;

    // Base line with wave
    final points = <Offset>[];
    for (var i = 0; i <= rayCount; i++) {
      final x = (i / rayCount) * size.width;
      final wave = sin(x * 0.02 + time * (1 + index * 0.2)) * 20;
      final wave2 = cos(x * 0.01 - time * 0.5) * 15;
      final y = size.height * baseY + wave + wave2;
      points.add(Offset(x, y));
    }

    // Draw vertical rays
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final rayHeight = 50 + sin(p.dx * 0.03 + time * 2 + index) * 30;
      final intensity = (sin(p.dx * 0.02 + time + index * 0.5) + 1) / 2;

      // Ray gradient
      canvas.drawLine(
        p,
        Offset(p.dx, p.dy - rayHeight * (1 + intensity)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              color.withValues(alpha: 0.4 * intensity),
              color.withValues(alpha: 0.2 * intensity),
              Colors.transparent,
            ],
          ).createShader(Rect.fromPoints(p, Offset(p.dx, p.dy - rayHeight * 2)))
          ..strokeWidth = size.width / rayCount * 1.2,
      );
    }

    // Glow layer
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraBorealisPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
