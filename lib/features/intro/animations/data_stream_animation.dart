import 'dart:math';

import 'package:flutter/material.dart';

/// Looping data stream animation with falling binary/hex characters.
class DataStreamAnimation extends StatefulWidget {
  const DataStreamAnimation({super.key});

  @override
  State<DataStreamAnimation> createState() => _DataStreamAnimationState();
}

class _DataStreamAnimationState extends State<DataStreamAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_DataColumn> _columns = [];
  final Random _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  void _generateColumns(Size size) {
    if (_initialized) return;

    const columnWidth = 25.0;
    final columnCount = (size.width / columnWidth).ceil();

    for (var i = 0; i < columnCount; i++) {
      _columns.add(
        _DataColumn(
          x: i * columnWidth + columnWidth / 2,
          speed: 0.3 + _random.nextDouble() * 0.7,
          phase: _random.nextDouble(),
          length: 8 + _random.nextInt(12),
          chars: List.generate(20, (_) => _randomChar()),
        ),
      );
    }

    _initialized = true;
  }

  String _randomChar() {
    const chars = '01アイウエオカキクケコ@#\$%&*';
    return chars[_random.nextInt(chars.length)];
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
        _generateColumns(size);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _DataStreamPainter(
                columns: _columns,
                progress: _controller.value,
                canvasSize: size,
              ),
              size: size,
            );
          },
        );
      },
    );
  }
}

class _DataColumn {
  _DataColumn({
    required this.x,
    required this.speed,
    required this.phase,
    required this.length,
    required this.chars,
  });

  final double x;
  final double speed;
  final double phase;
  final int length;
  final List<String> chars;
}

class _DataStreamPainter extends CustomPainter {
  _DataStreamPainter({
    required this.columns,
    required this.progress,
    required this.canvasSize,
  });

  final List<_DataColumn> columns;
  final double progress;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    const accentColor = Color(0xFF00E5FF);
    const charHeight = 18.0;

    for (final column in columns) {
      final streamProgress = (progress * column.speed + column.phase) % 1.0;
      final headY =
          streamProgress * (canvasSize.height + column.length * charHeight);

      for (var i = 0; i < column.length; i++) {
        final charY = headY - i * charHeight;
        if (charY < -charHeight || charY > canvasSize.height + charHeight) {
          continue;
        }

        final fadeProgress = i / column.length;
        final alpha = (1.0 - fadeProgress) * 0.6;

        if (alpha > 0.05) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: column.chars[i % column.chars.length],
              style: TextStyle(
                color: i == 0
                    ? Colors.white.withValues(alpha: 0.9)
                    : accentColor.withValues(alpha: alpha),
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          // Glow for head
          if (i == 0) {
            final glowPaint = Paint()
              ..color = accentColor.withValues(alpha: 0.4)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
            canvas.drawCircle(Offset(column.x, charY), 10, glowPaint);
          }

          textPainter.paint(
            canvas,
            Offset(
              column.x - textPainter.width / 2,
              charY - textPainter.height / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DataStreamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
