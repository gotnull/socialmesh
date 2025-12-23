import 'dart:math';

import 'package:flutter/material.dart';

/// Sine wave interference / oscilloscope animation.
class OscilloscopeAnimation extends StatefulWidget {
  const OscilloscopeAnimation({super.key});

  @override
  State<OscilloscopeAnimation> createState() => _OscilloscopeAnimationState();
}

class _OscilloscopeAnimationState extends State<OscilloscopeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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
          painter: _OscilloscopePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _OscilloscopePainter extends CustomPainter {
  _OscilloscopePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final time = progress * 2 * pi;
    final amplitude = size.height * 0.3;

    // Dark background with grid
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF001100),
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF003300)
      ..strokeWidth = 1;

    // Vertical grid
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal grid
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Center lines (brighter)
    final centerLinePaint = Paint()
      ..color = const Color(0xFF004400)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerLinePaint,
    );

    // Multiple waveforms
    final waveforms = [
      (
        freq: 2.0,
        phase: time,
        color: const Color(0xFF00FF00),
        amplitude: amplitude,
      ),
      (
        freq: 3.0,
        phase: time * 1.5,
        color: const Color(0xFF00FFFF),
        amplitude: amplitude * 0.7,
      ),
      (
        freq: 5.0,
        phase: time * 2,
        color: const Color(0xFFFF00FF),
        amplitude: amplitude * 0.4,
      ),
    ];

    for (final wave in waveforms) {
      final path = Path();

      for (var x = 0.0; x <= size.width; x += 2) {
        final normalizedX = x / size.width;

        // Complex waveform with harmonics
        var y =
            sin(normalizedX * wave.freq * 2 * pi + wave.phase) * wave.amplitude;

        // Add harmonics
        y +=
            sin(normalizedX * wave.freq * 4 * pi + wave.phase * 1.5) *
            wave.amplitude *
            0.3;
        y +=
            sin(normalizedX * wave.freq * 6 * pi + wave.phase * 2) *
            wave.amplitude *
            0.15;

        // Amplitude modulation
        final envelope = sin(normalizedX * pi);
        y *= envelope;

        final screenY = centerY + y;

        if (x == 0) {
          path.moveTo(x, screenY);
        } else {
          path.lineTo(x, screenY);
        }
      }

      // Glow effect
      final glowPaint = Paint()
        ..color = wave.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, glowPaint);

      // Main line
      final paint = Paint()
        ..color = wave.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
    }

    // Phosphor afterglow effect - draw faded previous frames
    for (var i = 1; i <= 3; i++) {
      final pastTime = time - i * 0.1;
      final alpha = 0.15 - i * 0.04;

      final path = Path();
      for (var x = 0.0; x <= size.width; x += 4) {
        final normalizedX = x / size.width;
        var y = sin(normalizedX * 2 * 2 * pi + pastTime) * amplitude;
        y += sin(normalizedX * 4 * pi + pastTime * 1.5) * amplitude * 0.3;
        final envelope = sin(normalizedX * pi);
        y *= envelope;

        final screenY = centerY + y;

        if (x == 0) {
          path.moveTo(x, screenY);
        } else {
          path.lineTo(x, screenY);
        }
      }

      final trailPaint = Paint()
        ..color = const Color(0xFF00FF00).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, trailPaint);
    }

    // Scanning dot at current position
    final dotX = (progress * size.width) % size.width;
    final normalizedDotX = dotX / size.width;
    var dotY = sin(normalizedDotX * 2 * 2 * pi + time) * amplitude;
    dotY += sin(normalizedDotX * 4 * pi + time * 1.5) * amplitude * 0.3;
    final envelope = sin(normalizedDotX * pi);
    dotY *= envelope;

    final dotPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(dotX, centerY + dotY), 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OscilloscopePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
