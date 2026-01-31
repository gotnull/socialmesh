// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:socialmesh/core/theme.dart';
import 'dart:math';

import 'package:flutter/material.dart';

/// Matrix-style digital rain effect.
class MatrixRainAnimation extends StatefulWidget {
  const MatrixRainAnimation({super.key});

  @override
  State<MatrixRainAnimation> createState() => _MatrixRainAnimationState();
}

class _MatrixRainAnimationState extends State<MatrixRainAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_RainColumn> _columns = [];
  final _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
  }

  void _initColumns(Size size) {
    if (_initialized) return;
    _columns.clear();

    const charWidth = 14.0;
    final columnCount = (size.width / charWidth).ceil();

    for (var i = 0; i < columnCount; i++) {
      _columns.add(
        _RainColumn(
          x: i * charWidth,
          speed: 2 + _random.nextDouble() * 4,
          length: 8 + _random.nextInt(20),
          y: _random.nextDouble() * size.height,
          chars: List.generate(
            30,
            (_) => String.fromCharCode(0x30A0 + _random.nextInt(96)),
          ),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _MatrixRainPainter(
            columns: _columns,
            onInit: _initColumns,
            random: _random,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RainColumn {
  _RainColumn({
    required this.x,
    required this.speed,
    required this.length,
    required this.y,
    required this.chars,
  });

  final double x;
  final double speed;
  final int length;
  double y;
  List<String> chars;
}

class _MatrixRainPainter extends CustomPainter {
  _MatrixRainPainter({
    required this.columns,
    required this.onInit,
    required this.random,
  });

  final List<_RainColumn> columns;
  final void Function(Size) onInit;
  final Random random;

  @override
  void paint(Canvas canvas, Size size) {
    onInit(size);

    const charHeight = 16.0;

    for (final col in columns) {
      // Update position
      col.y += col.speed;
      if (col.y > size.height + col.length * charHeight) {
        col.y = -col.length * charHeight;
        // Randomize characters
        for (var i = 0; i < col.chars.length; i++) {
          col.chars[i] = String.fromCharCode(0x30A0 + random.nextInt(96));
        }
      }

      // Occasionally change a random character
      if (random.nextDouble() < 0.1) {
        final idx = random.nextInt(col.chars.length);
        col.chars[idx] = String.fromCharCode(0x30A0 + random.nextInt(96));
      }

      // Draw characters
      for (var i = 0; i < col.length; i++) {
        final charY = col.y - i * charHeight;
        if (charY < -charHeight || charY > size.height + charHeight) continue;

        final progress = i / col.length;
        final alpha = (1 - progress).clamp(0.1, 1.0);

        Color color;
        if (i == 0) {
          // Head is bright white/green
          color = Colors.white;
        } else if (i < 3) {
          // Near head is bright green
          color = const Color(0xFF00FF00).withValues(alpha: alpha);
        } else {
          // Trail fades to darker green
          color = Color.lerp(
            const Color(0xFF00FF00),
            const Color(0xFF003300),
            progress,
          )!.withValues(alpha: alpha * 0.8);
        }

        final textPainter = TextPainter(
          text: TextSpan(
            text: col.chars[i % col.chars.length],
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontFamily: AppTheme.fontFamily,
              fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(col.x, charY));

        // Glow for head
        if (i == 0) {
          final glowPaint = Paint()
            ..color = const Color(0xFF00FF00).withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(Offset(col.x + 7, charY + 8), 10, glowPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRainPainter oldDelegate) => true;
}
