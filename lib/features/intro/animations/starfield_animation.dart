import 'dart:math';

import 'package:flutter/material.dart';

/// Classic 3D starfield effect flying through space.
class StarfieldAnimation extends StatefulWidget {
  const StarfieldAnimation({super.key});

  @override
  State<StarfieldAnimation> createState() => _StarfieldAnimationState();
}

class _StarfieldAnimationState extends State<StarfieldAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Star> _stars = [];
  final Random _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();
  }

  void _initStars(Size size) {
    if (_initialized) return;

    const starCount = 200;
    for (var i = 0; i < starCount; i++) {
      _stars.add(
        _Star(
          x: (_random.nextDouble() - 0.5) * size.width * 3,
          y: (_random.nextDouble() - 0.5) * size.height * 3,
          z: _random.nextDouble() * 1000,
        ),
      );
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _initStars(size);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Update star positions
            for (final star in _stars) {
              star.z -= 8;
              if (star.z <= 0) {
                star.x = (_random.nextDouble() - 0.5) * size.width * 3;
                star.y = (_random.nextDouble() - 0.5) * size.height * 3;
                star.z = 1000;
              }
            }

            return CustomPaint(
              painter: _StarfieldPainter(stars: _stars, canvasSize: size),
              size: size,
            );
          },
        );
      },
    );
  }
}

class _Star {
  _Star({required this.x, required this.y, required this.z});

  double x;
  double y;
  double z;
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.stars, required this.canvasSize});

  final List<_Star> stars;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    // Sort by z for proper depth
    final sortedStars = List<_Star>.from(stars)
      ..sort((a, b) => b.z.compareTo(a.z));

    for (final star in sortedStars) {
      if (star.z <= 0) continue;

      // 3D projection
      final sx = centerX + (star.x / star.z) * 300;
      final sy = centerY + (star.y / star.z) * 300;

      // Previous position for trail
      final prevZ = star.z + 15;
      final psx = centerX + (star.x / prevZ) * 300;
      final psy = centerY + (star.y / prevZ) * 300;

      // Size and brightness based on depth
      final brightness = (1 - star.z / 1000).clamp(0.0, 1.0);
      final starSize = (1 - star.z / 1000) * 3 + 0.5;

      // Draw trail
      final trailPaint = Paint()
        ..color = Colors.white.withValues(alpha: brightness * 0.5)
        ..strokeWidth = starSize * 0.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(psx, psy), Offset(sx, sy), trailPaint);

      // Draw star
      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: brightness);
      canvas.drawCircle(Offset(sx, sy), starSize, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => true;
}
