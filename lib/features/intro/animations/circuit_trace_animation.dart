// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Looping circuit board trace animation with flowing data paths.
class CircuitTraceAnimation extends StatefulWidget {
  const CircuitTraceAnimation({super.key});

  @override
  State<CircuitTraceAnimation> createState() => _CircuitTraceAnimationState();
}

class _CircuitTraceAnimationState extends State<CircuitTraceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_CircuitPath> _paths = [];
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

  void _generatePaths(Size size) {
    if (_initialized) return;

    const pathCount = 12;
    for (var i = 0; i < pathCount; i++) {
      final points = <Offset>[];
      var current = Offset(
        _random.nextDouble() * size.width,
        _random.nextDouble() * size.height,
      );
      points.add(current);

      final segmentCount = 4 + _random.nextInt(4);
      for (var j = 0; j < segmentCount; j++) {
        final direction = _random.nextInt(4);
        final length = 40.0 + _random.nextDouble() * 80;
        final offset = switch (direction) {
          0 => Offset(length, 0),
          1 => Offset(-length, 0),
          2 => Offset(0, length),
          _ => Offset(0, -length),
        };
        current = current + offset;
        points.add(current);
      }

      _paths.add(
        _CircuitPath(
          points: points,
          phase: _random.nextDouble(),
          width: 1.0 + _random.nextDouble() * 1.5,
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
        _generatePaths(size);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _CircuitTracePainter(
                paths: _paths,
                progress: _controller.value,
              ),
              size: size,
            );
          },
        );
      },
    );
  }
}

class _CircuitPath {
  _CircuitPath({
    required this.points,
    required this.phase,
    required this.width,
  });

  final List<Offset> points;
  final double phase;
  final double width;
}

class _CircuitTracePainter extends CustomPainter {
  _CircuitTracePainter({required this.paths, required this.progress});

  final List<_CircuitPath> paths;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const accentColor = Color(0xFF00E5FF);
    const dimColor = Color(0xFF1A3A4A);

    for (final pathData in paths) {
      if (pathData.points.length < 2) continue;

      final path = Path()..moveTo(pathData.points[0].dx, pathData.points[0].dy);
      for (var i = 1; i < pathData.points.length; i++) {
        path.lineTo(pathData.points[i].dx, pathData.points[i].dy);
      }

      // Background trace
      final bgPaint = Paint()
        ..color = dimColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pathData.width;
      canvas.drawPath(path, bgPaint);

      // Animated flow
      final flowProgress = (progress + pathData.phase) % 1.0;
      final metrics = path.computeMetrics().first;
      final flowLength = metrics.length * 0.3;
      final flowStart = flowProgress * metrics.length;

      final extractPath = metrics.extractPath(
        flowStart,
        (flowStart + flowLength).clamp(0, metrics.length),
      );

      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pathData.width + 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(extractPath, glowPaint);

      final flowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pathData.width
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(extractPath, flowPaint);

      // Node dots at corners
      for (final point in pathData.points) {
        final nodePaint = Paint()..color = accentColor.withValues(alpha: 0.4);
        canvas.drawCircle(point, 2, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitTracePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
