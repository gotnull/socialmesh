// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Subtle cyberpunk rain scene with minimal neon.
class BladeRunnerAnimation extends StatefulWidget {
  const BladeRunnerAnimation({super.key});

  @override
  State<BladeRunnerAnimation> createState() => _BladeRunnerAnimationState();
}

class _BladeRunnerAnimationState extends State<BladeRunnerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Raindrop> _raindrops;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _raindrops = List.generate(60, (i) => _Raindrop(Random(i)));
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
          painter: _BladeRunnerPainter(_controller.value, _raindrops),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Raindrop {
  _Raindrop(Random r) {
    x = r.nextDouble();
    y = r.nextDouble();
    speed = 0.3 + r.nextDouble() * 0.5;
    length = 10 + r.nextDouble() * 20;
    alpha = 0.2 + r.nextDouble() * 0.3;
  }

  late double x, y, speed, length, alpha;
}

class _BladeRunnerPainter extends CustomPainter {
  _BladeRunnerPainter(this.progress, this.raindrops);

  final double progress;
  final List<_Raindrop> raindrops;

  @override
  void paint(Canvas canvas, Size size) {
    // Dark city background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050510), Color(0xFF101020), Color(0xFF151525)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Distant cityscape silhouette
    _drawCityscape(canvas, size);

    // Neon reflections in fog
    _drawNeonGlow(canvas, size);

    // Rain
    for (final drop in raindrops) {
      final dropY = ((drop.y + progress * drop.speed * 3) % 1.2) - 0.1;
      final dropX = drop.x * size.width;
      final startY = dropY * size.height;
      final endY = startY + drop.length;

      canvas.drawLine(
        Offset(dropX, startY),
        Offset(dropX, endY),
        Paint()
          ..color = const Color(0xFF8090b0).withValues(alpha: drop.alpha)
          ..strokeWidth = 1,
      );
    }

    // Atmospheric fog layers
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                const Color(0xFF102030).withValues(alpha: 0.3),
              ],
            ).createShader(
              Rect.fromLTWH(
                0,
                size.height * 0.6,
                size.width,
                size.height * 0.4,
              ),
            ),
    );

    // Ground reflections
    _drawGroundReflections(canvas, size);
  }

  void _drawCityscape(Canvas canvas, Size size) {
    final buildingRandom = Random(12);
    final buildings = <Rect>[];

    var x = 0.0;
    while (x < size.width) {
      final width = 20 + buildingRandom.nextDouble() * 40;
      final height = 100 + buildingRandom.nextDouble() * 200;
      final y = size.height * 0.5 - height + buildingRandom.nextDouble() * 50;

      buildings.add(Rect.fromLTWH(x, y, width, size.height - y));
      x += width + buildingRandom.nextDouble() * 10;
    }

    // Draw buildings
    for (var i = 0; i < buildings.length; i++) {
      final b = buildings[i];
      final darkness = 0.05 + buildingRandom.nextDouble() * 0.1;

      canvas.drawRect(
        b,
        Paint()..color = Color.fromRGBO(20, 25, 40, darkness + 0.8),
      );

      // Windows
      final windowRandom = Random(i * 100);
      for (var wy = b.top + 10; wy < b.bottom - 20; wy += 12) {
        for (var wx = b.left + 5; wx < b.right - 5; wx += 8) {
          if (windowRandom.nextDouble() > 0.7) {
            final lit = windowRandom.nextDouble() > 0.5;
            final windowColor = lit
                ? HSVColor.fromAHSV(
                    0.5 + windowRandom.nextDouble() * 0.3,
                    40 + windowRandom.nextDouble() * 20,
                    0.6,
                    0.8,
                  ).toColor()
                : const Color(0xFF101520);

            canvas.drawRect(
              Rect.fromLTWH(wx, wy, 3, 5),
              Paint()..color = windowColor,
            );
          }
        }
      }
    }
  }

  void _drawNeonGlow(Canvas canvas, Size size) {
    // Subtle neon accent
    final neonPositions = [
      (x: size.width * 0.2, color: const Color(0xFFff3060)),
      (x: size.width * 0.5, color: const Color(0xFF30a0ff)),
      (x: size.width * 0.8, color: const Color(0xFFa030ff)),
    ];

    for (final neon in neonPositions) {
      canvas.drawRect(
        Rect.fromLTWH(neon.x - 40, size.height * 0.35, 80, 5),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              neon.color.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(neon.x - 40, size.height * 0.35, 80, 5)),
      );

      // Glow
      canvas.drawCircle(
        Offset(neon.x, size.height * 0.37),
        50,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  neon.color.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(neon.x, size.height * 0.37),
                  radius: 50,
                ),
              ),
      );
    }
  }

  void _drawGroundReflections(Canvas canvas, Size size) {
    final groundY = size.height * 0.85;

    // Wet ground base
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = const Color(0xFF0a0a15),
    );

    // Reflection streaks
    final reflectRandom = Random(33);
    for (var i = 0; i < 30; i++) {
      final rx = reflectRandom.nextDouble() * size.width;
      final ry = groundY + reflectRandom.nextDouble() * (size.height - groundY);
      final rWidth = 20 + reflectRandom.nextDouble() * 60;

      final colors = [
        const Color(0xFFff3060),
        const Color(0xFF30a0ff),
        const Color(0xFFa030ff),
      ];
      final color = colors[reflectRandom.nextInt(colors.length)];

      canvas.drawLine(
        Offset(rx, ry),
        Offset(rx + rWidth, ry),
        Paint()
          ..color = color.withValues(
            alpha: 0.1 + reflectRandom.nextDouble() * 0.15,
          )
          ..strokeWidth = 1 + reflectRandom.nextDouble() * 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BladeRunnerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
