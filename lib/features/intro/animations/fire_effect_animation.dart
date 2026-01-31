// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Classic demoscene fire effect with rising flames.
class FireEffectAnimation extends StatefulWidget {
  const FireEffectAnimation({super.key});

  @override
  State<FireEffectAnimation> createState() => _FireEffectAnimationState();
}

class _FireEffectAnimationState extends State<FireEffectAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<List<double>>? _fireBuffer;
  final Random _random = Random();
  int _bufferWidth = 0;
  int _bufferHeight = 0;

  // Classic fire palette
  static const List<Color> _firePalette = [
    Color(0xFF000000),
    Color(0xFF1F0707),
    Color(0xFF2F0F07),
    Color(0xFF470F07),
    Color(0xFF571707),
    Color(0xFF671F07),
    Color(0xFF772707),
    Color(0xFF8F2F07),
    Color(0xFF9F2F07),
    Color(0xFFAF3F07),
    Color(0xFFBF4707),
    Color(0xFFC74707),
    Color(0xFFDF4F07),
    Color(0xFFDF5707),
    Color(0xFFDF5707),
    Color(0xFFD75F07),
    Color(0xFFD76707),
    Color(0xFFD76F0F),
    Color(0xFFCF770F),
    Color(0xFFCF7F0F),
    Color(0xFFCF8717),
    Color(0xFFC78717),
    Color(0xFFC78F17),
    Color(0xFFC7971F),
    Color(0xFFBF9F1F),
    Color(0xFFBF9F1F),
    Color(0xFFBFA727),
    Color(0xFFBFA727),
    Color(0xFFBFAF2F),
    Color(0xFFB7AF2F),
    Color(0xFFB7B72F),
    Color(0xFFB7B737),
    Color(0xFFCFCF6F),
    Color(0xFFDFDF9F),
    Color(0xFFEFEFC7),
    Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();
  }

  void _initBuffer(Size size) {
    final width = (size.width / 4).ceil();
    final height = (size.height / 4).ceil();

    if (_bufferWidth != width || _bufferHeight != height) {
      _bufferWidth = width;
      _bufferHeight = height;
      _fireBuffer = List.generate(
        height,
        (_) => List.generate(width, (_) => 0.0),
      );
    }
  }

  void _updateFire() {
    if (_fireBuffer == null) return;

    // Set random heat sources at bottom
    for (var x = 0; x < _bufferWidth; x++) {
      _fireBuffer![_bufferHeight - 1][x] = _random.nextDouble() * 35;
    }

    // Propagate fire upward
    for (var y = 0; y < _bufferHeight - 1; y++) {
      for (var x = 0; x < _bufferWidth; x++) {
        final left = x > 0 ? _fireBuffer![y + 1][x - 1] : 0.0;
        final center = _fireBuffer![y + 1][x];
        final right = x < _bufferWidth - 1 ? _fireBuffer![y + 1][x + 1] : 0.0;
        final below = y < _bufferHeight - 2 ? _fireBuffer![y + 2][x] : center;

        final newVal =
            ((left + center + right + below) / 4.0) -
            0.3 -
            _random.nextDouble() * 0.5;
        _fireBuffer![y][x] = max(0, newVal);
      }
    }
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
        _initBuffer(size);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            _updateFire();
            return CustomPaint(
              painter: _FireEffectPainter(
                buffer: _fireBuffer!,
                palette: _firePalette,
              ),
              size: size,
            );
          },
        );
      },
    );
  }
}

class _FireEffectPainter extends CustomPainter {
  _FireEffectPainter({required this.buffer, required this.palette});

  final List<List<double>> buffer;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / buffer[0].length;
    final cellHeight = size.height / buffer.length;

    for (var y = 0; y < buffer.length; y++) {
      for (var x = 0; x < buffer[y].length; x++) {
        final value = buffer[y][x].clamp(0.0, palette.length - 1.0).toInt();
        final color = palette[value];

        final paint = Paint()..color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth + 1,
            cellHeight + 1,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireEffectPainter oldDelegate) => true;
}
