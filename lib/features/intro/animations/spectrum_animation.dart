import 'dart:math';

import 'package:flutter/material.dart';

/// Classic audio spectrum visualizer animation.
class SpectrumAnimation extends StatefulWidget {
  const SpectrumAnimation({super.key});

  @override
  State<SpectrumAnimation> createState() => _SpectrumAnimationState();
}

class _SpectrumAnimationState extends State<SpectrumAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
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
          painter: _SpectrumPainter(
            time: DateTime.now().millisecondsSinceEpoch,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.time});

  final int time;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barCount = 64;
    final barWidth = size.width / barCount * 0.8;
    final barGap = size.width / barCount * 0.2;
    final maxBarHeight = size.height * 0.4;

    final progress = (time % 10000) / 10000.0;
    final animTime = progress * 2 * pi;

    // Generate fake spectrum data
    for (var i = 0; i < barCount; i++) {
      final normalizedI = i / barCount;

      // Create interesting wave patterns
      final wave1 = sin(normalizedI * 4 * pi + animTime * 3) * 0.3;
      final wave2 = sin(normalizedI * 8 * pi + animTime * 5) * 0.2;
      final wave3 = cos(normalizedI * 2 * pi + animTime * 2) * 0.25;
      final bass = (i < barCount * 0.2) ? sin(animTime * 4) * 0.3 : 0.0;
      final treble = (i > barCount * 0.7)
          ? sin(animTime * 6 + i * 0.1) * 0.2
          : 0.0;

      var height = (0.3 + wave1 + wave2 + wave3 + bass + treble).clamp(
        0.1,
        1.0,
      );

      // Add some randomness for realism
      final noise = sin(i * 123.456 + animTime * 10) * 0.1;
      height = (height + noise).clamp(0.1, 1.0);

      final barHeight = height * maxBarHeight;
      final x = i * (barWidth + barGap) + barGap / 2;

      // Color gradient based on height and position
      final hue = (normalizedI * 120 + progress * 360 + height * 60) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();

      // Draw bar from center (both up and down)
      final topY = centerY - barHeight;

      // Top bar glow
      final topGlowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.8)],
        ).createShader(Rect.fromLTWH(x, topY, barWidth, barHeight))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, topY, barWidth + 4, barHeight),
          const Radius.circular(2),
        ),
        topGlowPaint,
      );

      // Top bar
      final topPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color.withValues(alpha: 0.6), color],
        ).createShader(Rect.fromLTWH(x, topY, barWidth, barHeight));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topY, barWidth, barHeight),
          const Radius.circular(2),
        ),
        topPaint,
      );

      // Bottom bar (mirrored)
      final bottomPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.2)],
        ).createShader(Rect.fromLTWH(x, centerY, barWidth, barHeight));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY, barWidth, barHeight),
          const Radius.circular(2),
        ),
        bottomPaint,
      );

      // Peak indicator
      final peakY = topY - 5;
      final peakPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
      canvas.drawRect(Rect.fromLTWH(x, peakY, barWidth, 3), peakPaint);
    }

    // Center line glow
    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
