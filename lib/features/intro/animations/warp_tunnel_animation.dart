import 'dart:math';

import 'package:flutter/material.dart';

/// Looping warp tunnel animation with perspective lines flying past.
class WarpTunnelAnimation extends StatefulWidget {
  const WarpTunnelAnimation({super.key});

  @override
  State<WarpTunnelAnimation> createState() => _WarpTunnelAnimationState();
}

class _WarpTunnelAnimationState extends State<WarpTunnelAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_WarpLine> _lines = [];
  final Random _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  void _generateLines() {
    if (_initialized) return;

    const lineCount = 80;
    for (var i = 0; i < lineCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      _lines.add(
        _WarpLine(
          angle: angle,
          distance: _random.nextDouble(),
          speed: 0.5 + _random.nextDouble() * 0.5,
          length: 0.05 + _random.nextDouble() * 0.15,
          width: 1.0 + _random.nextDouble() * 2.0,
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
    _generateLines();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _WarpTunnelPainter(
            lines: _lines,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _WarpLine {
  _WarpLine({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.length,
    required this.width,
  });

  final double angle;
  final double distance;
  final double speed;
  final double length;
  final double width;
}

class _WarpTunnelPainter extends CustomPainter {
  _WarpTunnelPainter({required this.lines, required this.progress});

  final List<_WarpLine> lines;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.7;
    const accentColor = Color(0xFF00E5FF);
    const secondaryColor = Color(0xFF7C4DFF);

    for (final line in lines) {
      final currentDistance = (line.distance + progress * line.speed) % 1.0;
      final startRadius = currentDistance * maxRadius;
      final endRadius =
          (currentDistance + line.length).clamp(0.0, 1.0) * maxRadius;

      if (startRadius < 5) continue;

      final startPoint =
          center +
          Offset(cos(line.angle) * startRadius, sin(line.angle) * startRadius);
      final endPoint =
          center +
          Offset(cos(line.angle) * endRadius, sin(line.angle) * endRadius);

      // Alpha based on distance (brighter when closer/larger)
      final alpha = currentDistance * 0.5;
      final color = line.angle > pi ? accentColor : secondaryColor;

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.3)
        ..strokeWidth = line.width + 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(startPoint, endPoint, glowPaint);

      // Core line
      final linePaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = line.width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(startPoint, endPoint, linePaint);
    }

    // Center glow
    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.3),
          accentColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 60));
    canvas.drawCircle(center, 50, centerGlow);
  }

  @override
  bool shouldRepaint(covariant _WarpTunnelPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
