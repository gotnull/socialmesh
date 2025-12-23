import 'dart:math';

import 'package:flutter/material.dart';

/// Modern thermal imaging with clean gradients.
class PredatorThermalAnimation extends StatefulWidget {
  const PredatorThermalAnimation({super.key});

  @override
  State<PredatorThermalAnimation> createState() =>
      _PredatorThermalAnimationState();
}

class _PredatorThermalAnimationState extends State<PredatorThermalAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
          painter: _PredatorThermalPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PredatorThermalPainter extends CustomPainter {
  _PredatorThermalPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Deep cold background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF08080c),
    );

    // Ambient cold areas
    final random = Random(42);
    for (var i = 0; i < 6; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final r = 100 + random.nextDouble() * 150;

      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF152535).withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }

    // Heat sources with smooth organic movement
    final sources = [
      (
        baseX: size.width * 0.35,
        baseY: size.height * 0.4,
        heat: 0.95,
        size: 50.0,
      ),
      (
        baseX: size.width * 0.6,
        baseY: size.height * 0.5,
        heat: 0.8,
        size: 40.0,
      ),
      (
        baseX: size.width * 0.45,
        baseY: size.height * 0.7,
        heat: 0.55,
        size: 35.0,
      ),
    ];

    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      final x = s.baseX + sin(time * 0.4 + i) * 25;
      final y = s.baseY + cos(time * 0.3 + i * 1.5) * 20;

      // Multiple smooth layers
      for (var layer = 4; layer >= 0; layer--) {
        final layerSize = s.size * (1 + layer * 0.5);
        final layerHeat = s.heat * (1 - layer * 0.15);
        final color = _getHeatColor(layerHeat);

        canvas.drawCircle(
          Offset(x, y),
          layerSize,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.7 - layer * 0.12),
                    color.withValues(alpha: 0.0),
                  ],
                ).createShader(
                  Rect.fromCircle(center: Offset(x, y), radius: layerSize),
                ),
        );
      }
    }

    // Subtle scanning line
    final scanY = (progress * 1.5 % 1.0) * size.height;
    final scanGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        const Color(0xFF3060a0).withValues(alpha: 0.08),
        Colors.transparent,
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 40, size.width, 80),
      Paint()
        ..shader = scanGradient.createShader(
          Rect.fromLTWH(0, scanY - 40, size.width, 80),
        ),
    );

    // Minimal corner markers
    final markerColor = const Color(0xFF4080c0).withValues(alpha: 0.35);
    final markerPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const m = 20.0;
    const s = 15.0;

    canvas.drawLine(Offset(m, m), Offset(m + s, m), markerPaint);
    canvas.drawLine(Offset(m, m), Offset(m, m + s), markerPaint);

    canvas.drawLine(
      Offset(size.width - m, m),
      Offset(size.width - m - s, m),
      markerPaint,
    );
    canvas.drawLine(
      Offset(size.width - m, m),
      Offset(size.width - m, m + s),
      markerPaint,
    );

    canvas.drawLine(
      Offset(m, size.height - m),
      Offset(m + s, size.height - m),
      markerPaint,
    );
    canvas.drawLine(
      Offset(m, size.height - m),
      Offset(m, size.height - m - s),
      markerPaint,
    );

    canvas.drawLine(
      Offset(size.width - m, size.height - m),
      Offset(size.width - m - s, size.height - m),
      markerPaint,
    );
    canvas.drawLine(
      Offset(size.width - m, size.height - m),
      Offset(size.width - m, size.height - m - s),
      markerPaint,
    );
  }

  Color _getHeatColor(double t) {
    // Clean thermal gradient: indigo -> purple -> coral -> amber -> cream
    const colors = [
      Color(0xFF1a2540),
      Color(0xFF4a3070),
      Color(0xFFa04070),
      Color(0xFFe07050),
      Color(0xFFf0c060),
      Color(0xFFfff0d0),
    ];

    final scaledT = t * (colors.length - 1);
    final index = scaledT.floor().clamp(0, colors.length - 2);
    final blend = scaledT - index;

    return Color.lerp(colors[index], colors[index + 1], blend)!;
  }

  @override
  bool shouldRepaint(covariant _PredatorThermalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
