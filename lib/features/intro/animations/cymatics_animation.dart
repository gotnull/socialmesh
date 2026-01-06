import 'package:socialmesh/core/theme.dart';
import 'dart:math';

import 'package:flutter/material.dart';

/// Cymatics - sound visualized as sand patterns on vibrating plate.
class CymaticsAnimation extends StatefulWidget {
  const CymaticsAnimation({super.key});

  @override
  State<CymaticsAnimation> createState() => _CymaticsAnimationState();
}

class _CymaticsAnimationState extends State<CymaticsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
          painter: _CymaticsPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CymaticsPainter extends CustomPainter {
  _CymaticsPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = min(size.width, size.height) * 0.45;

    // Metal plate background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2a2a2a),
            const Color(0xFF1a1a1a),
            const Color(0xFF0f0f0f),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Frequency changes over time
    final freq = 3 + (sin(progress * 2 * pi) * 2 + 2).round();
    final freq2 = 4 + (cos(progress * 2 * pi * 0.7) * 2 + 2).round();
    final phase = progress * 2 * pi * 3;

    // Calculate nodal lines (where sand accumulates)
    final sandParticles = <Offset>[];
    final random = Random(42);

    for (var i = 0; i < 3000; i++) {
      final px = random.nextDouble() * size.width;
      final py = random.nextDouble() * size.height;

      final dx = px - cx;
      final dy = py - cy;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist > maxR) continue;

      // Chladni plate equation: cos(n*pi*x/L)*cos(m*pi*y/L) - cos(m*pi*x/L)*cos(n*pi*y/L)
      final normX = (px - cx) / maxR;
      final normY = (py - cy) / maxR;

      final wave1 = cos(freq * pi * normX) * cos(freq2 * pi * normY);
      final wave2 = cos(freq2 * pi * normX) * cos(freq * pi * normY);
      final amplitude = (wave1 - wave2).abs();

      // Sand accumulates at nodes (low amplitude)
      if (amplitude < 0.15) {
        sandParticles.add(Offset(px, py));
      }
    }

    // Draw sand particles
    for (final p in sandParticles) {
      final dx = p.dx - cx;
      final dy = p.dy - cy;
      final dist = sqrt(dx * dx + dy * dy);

      // Slight movement from vibration
      final vibration = sin(phase + dist * 0.1) * 0.5;
      final particleSize = 1.0 + random.nextDouble() * 1.5;

      canvas.drawCircle(
        Offset(p.dx + vibration, p.dy + vibration),
        particleSize,
        Paint()..color = const Color(0xFFD4C4A0).withValues(alpha: 0.8),
      );
    }

    // Plate edge
    canvas.drawCircle(
      Offset(cx, cy),
      maxR,
      Paint()
        ..color = const Color(0xFF404040)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Center mount point
    canvas.drawCircle(
      Offset(cx, cy),
      8,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF505050), const Color(0xFF303030)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 8)),
    );

    // Frequency indicator
    final freqText = '${freq}x$freq2';
    final textPainter = TextPainter(
      text: TextSpan(
        text: freqText,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 14,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(20, size.height - 30));
  }

  @override
  bool shouldRepaint(covariant _CymaticsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
