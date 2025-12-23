import 'dart:math';

import 'package:flutter/material.dart';

/// Elegant starfield with minimal fighter craft.
class SpaceBattleAnimation extends StatefulWidget {
  const SpaceBattleAnimation({super.key});

  @override
  State<SpaceBattleAnimation> createState() => _SpaceBattleAnimationState();
}

class _SpaceBattleAnimationState extends State<SpaceBattleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Star> _stars;
  late List<_Fighter> _fighters;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    final r = Random(42);
    _stars = List.generate(100, (i) => _Star(r));
    _fighters = List.generate(4, (i) => _Fighter(r, i));
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
          painter: _SpaceBattlePainter(_controller.value, _stars, _fighters),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Star {
  _Star(Random r) {
    x = r.nextDouble();
    y = r.nextDouble();
    z = r.nextDouble();
    brightness = 0.3 + r.nextDouble() * 0.7;
  }

  late double x, y, z, brightness;
}

class _Fighter {
  _Fighter(Random r, int index) {
    startX = r.nextDouble();
    startY = r.nextDouble();
    speed = 0.1 + r.nextDouble() * 0.15;
    size = 3 + r.nextDouble() * 2;
    delay = index * 0.2;
    angle = r.nextDouble() * pi * 2;
  }

  late double startX, startY, speed, size, delay, angle;
}

class _SpaceBattlePainter extends CustomPainter {
  _SpaceBattlePainter(this.progress, this.stars, this.fighters);

  final double progress;
  final List<_Star> stars;
  final List<_Fighter> fighters;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    // Space background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color(0xFF0a0a18),
            const Color(0xFF050510),
            const Color(0xFF020208),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Nebula hint
    canvas.drawCircle(
      Offset(cx + 100, cy - 80),
      200,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF301040).withValues(alpha: 0.15),
                const Color(0xFF102040).withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(cx + 100, cy - 80), radius: 200),
            ),
    );

    // Starfield with parallax
    for (final star in stars) {
      final z = ((star.z + progress * 0.5) % 1.0);
      final starScale = 1 - z;

      final starX = cx + (star.x - 0.5) * size.width * 1.5 * starScale;
      final starY = cy + (star.y - 0.5) * size.height * 1.5 * starScale;

      if (starX < 0 || starX > size.width || starY < 0 || starY > size.height) {
        continue;
      }

      final twinkle = sin(time * 3 + star.x * 10) * 0.2 + 0.8;
      final alpha = star.brightness * twinkle * (1 - z * 0.5);

      // Subtle color tint
      final hue = (star.x * 60 + star.y * 60) % 60 + 200;
      final starColor = HSVColor.fromAHSV(
        alpha.clamp(0.1, 0.8),
        hue,
        0.2,
        1.0,
      ).toColor();

      canvas.drawCircle(
        Offset(starX, starY),
        0.5 + starScale * 1.5,
        Paint()..color = starColor,
      );
    }

    // Distant planet
    final planetX = size.width * 0.15;
    final planetY = size.height * 0.25;
    canvas.drawCircle(
      Offset(planetX, planetY),
      40,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                const Color(0xFF405060),
                const Color(0xFF203040),
                const Color(0xFF101520),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(planetX, planetY), radius: 40),
            ),
    );

    // Planet ring
    canvas.save();
    canvas.translate(planetX, planetY);
    canvas.scale(1.0, 0.3);
    canvas.drawCircle(
      Offset.zero,
      55,
      Paint()
        ..color = const Color(0xFF606080).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.restore();

    // Fighters
    for (final fighter in fighters) {
      final fighterProgress = (progress * 2 + fighter.delay) % 1.0;
      final fighterAngle = fighter.angle + sin(time * 2 + fighter.delay) * 0.2;

      final pathX = fighter.startX + cos(fighterAngle) * fighterProgress;
      final pathY = fighter.startY + sin(fighterAngle) * fighterProgress * 0.5;

      final fx = pathX * size.width;
      final fy = pathY * size.height;

      if (fx < -50 ||
          fx > size.width + 50 ||
          fy < -50 ||
          fy > size.height + 50) {
        continue;
      }

      // Fighter shape (simple triangle)
      final path = Path();
      final fSize = fighter.size;
      final cosA = cos(fighterAngle);
      final sinA = sin(fighterAngle);

      path.moveTo(fx + cosA * fSize * 2, fy + sinA * fSize * 2);
      path.lineTo(
        fx - cosA * fSize - sinA * fSize,
        fy - sinA * fSize + cosA * fSize,
      );
      path.lineTo(
        fx - cosA * fSize + sinA * fSize,
        fy - sinA * fSize - cosA * fSize,
      );
      path.close();

      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF90a0b0).withValues(alpha: 0.8),
      );

      // Engine glow
      canvas.drawCircle(
        Offset(fx - cosA * fSize, fy - sinA * fSize),
        fSize * 0.6,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  const Color(0xFF60a0ff).withValues(alpha: 0.6),
                  const Color(0xFF3060a0).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(fx - cosA * fSize, fy - sinA * fSize),
                  radius: fSize * 0.6,
                ),
              ),
      );
    }

    // Subtle laser streaks
    final laserRandom = Random((progress * 10).floor());
    if (laserRandom.nextDouble() > 0.6) {
      final lx1 = laserRandom.nextDouble() * size.width;
      final ly1 = laserRandom.nextDouble() * size.height;
      final lAngle = laserRandom.nextDouble() * pi * 2;
      final lLength = 30 + laserRandom.nextDouble() * 50;

      final colors = [const Color(0xFFff3030), const Color(0xFF30ff30)];
      final lColor = colors[laserRandom.nextInt(colors.length)];

      canvas.drawLine(
        Offset(lx1, ly1),
        Offset(lx1 + cos(lAngle) * lLength, ly1 + sin(lAngle) * lLength),
        Paint()
          ..color = lColor.withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpaceBattlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
