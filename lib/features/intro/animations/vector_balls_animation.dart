import 'dart:math';

import 'package:flutter/material.dart';

/// Classic demoscene vector balls that morph to spell words.
class VectorBallsAnimation extends StatefulWidget {
  const VectorBallsAnimation({super.key});

  @override
  State<VectorBallsAnimation> createState() => _VectorBallsAnimationState();
}

class _VectorBallsAnimationState extends State<VectorBallsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Words to cycle through
  static const _words = ['MESH', 'RADIO', 'LINK', 'NODE', 'LORA'];
  int _wordIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16000),
    )..repeat();

    _controller.addListener(_checkWordChange);
  }

  void _checkWordChange() {
    // Change word every ~3 seconds
    final cyclePos = _controller.value * 5;
    final wordPhase = cyclePos.floor() % _words.length;
    if (wordPhase != _wordIndex) {
      setState(() => _wordIndex = wordPhase);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkWordChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _VectorBallsPainter(
            progress: _controller.value,
            word: _words[_wordIndex],
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

// Pixel font definitions (5x7 grid)
const Map<String, List<String>> _pixelFont = {
  'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  'C': ['01110', '10001', '10000', '10000', '10000', '10001', '01110'],
  'D': ['11100', '10010', '10001', '10001', '10001', '10010', '11100'],
  'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  'G': ['01110', '10001', '10000', '10111', '10001', '10001', '01110'],
  'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  'N': ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  'W': ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
  'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
};

class _Ball {
  _Ball(this.targetX, this.targetY, this.index);

  double x = 0;
  double y = 0;
  double z = 0;
  double targetX;
  double targetY;
  final int index;
  double velX = 0;
  double velY = 0;
  double velZ = 0;
}

class _VectorBallsPainter extends CustomPainter {
  _VectorBallsPainter({required this.progress, required this.word});

  final double progress;
  final String word;

  static List<_Ball>? _balls;
  static String? _lastWord;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;
    final ballRadius = min(size.width, size.height) * 0.025;

    // Generate target positions from word
    final targets = _getWordTargets(word, size);

    // Initialize or update balls
    if (_balls == null ||
        _lastWord != word ||
        _balls!.length != targets.length) {
      _initializeBalls(targets, size);
      _lastWord = word;
    }

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF101020), const Color(0xFF050510)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Update ball positions with physics
    final morphPhase = (progress * 5) % 1.0;
    final inText = morphPhase > 0.3 && morphPhase < 0.85;

    for (var i = 0; i < _balls!.length; i++) {
      final ball = _balls![i];
      final target = i < targets.length ? targets[i] : Offset(cx, cy);

      if (inText) {
        // Morph toward text position
        final dx = target.dx - ball.x;
        final dy = target.dy - ball.y;
        ball.velX += dx * 0.08;
        ball.velY += dy * 0.08;
        ball.velZ *= 0.9;
        ball.z += (0 - ball.z) * 0.1;
      } else {
        // Float in sphere formation
        final angle1 = time + i * 0.3;
        final angle2 = time * 0.7 + i * 0.2;
        final sphereR = min(size.width, size.height) * 0.3;

        final tx = cx + cos(angle1) * sin(angle2) * sphereR;
        final ty = cy + sin(angle1) * sin(angle2) * sphereR * 0.6;
        final tz = cos(angle2) * sphereR;

        ball.velX += (tx - ball.x) * 0.03;
        ball.velY += (ty - ball.y) * 0.03;
        ball.velZ += (tz - ball.z) * 0.03;
      }

      // Apply velocity with damping
      ball.velX *= 0.92;
      ball.velY *= 0.92;
      ball.velZ *= 0.92;

      ball.x += ball.velX;
      ball.y += ball.velY;
      ball.z += ball.velZ;
    }

    // Sort by Z
    final sortedBalls = List<_Ball>.from(_balls!)
      ..sort((a, b) => a.z.compareTo(b.z));

    // Draw balls
    for (final ball in sortedBalls) {
      final zNorm = (ball.z + 200) / 400;
      final scale = 0.5 + zNorm * 0.5;
      final r = ballRadius * scale;
      final brightness = zNorm.clamp(0.4, 1.0);

      // Color cycling
      final hue = (ball.index * 8 + progress * 360) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.7, brightness).toColor();

      // Shadow
      canvas.drawCircle(
        Offset(ball.x + r * 0.3, ball.y + r * 0.3),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.3 * brightness),
      );

      // Chrome ball
      canvas.drawCircle(
        Offset(ball.x, ball.y),
        r,
        Paint()
          ..shader =
              RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: [
                  Colors.white,
                  color,
                  color.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.4),
                ],
                stops: const [0.0, 0.25, 0.7, 1.0],
              ).createShader(
                Rect.fromCircle(center: Offset(ball.x, ball.y), radius: r),
              ),
      );

      // Specular
      canvas.drawCircle(
        Offset(ball.x - r * 0.3, ball.y - r * 0.3),
        r * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * brightness),
      );
    }

    // Scanline overlay
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = Colors.black.withValues(alpha: 0.1),
      );
    }
  }

  List<Offset> _getWordTargets(String word, Size size) {
    final targets = <Offset>[];
    const charWidth = 6.0;
    const charHeight = 8.0;
    final totalWidth = word.length * charWidth;
    final scale = min(size.width, size.height) * 0.08 / charWidth;

    final startX = size.width / 2 - (totalWidth * scale) / 2;
    final startY = size.height / 2 - (charHeight * scale) / 2;

    for (var c = 0; c < word.length; c++) {
      final char = word[c];
      final pattern = _pixelFont[char] ?? _pixelFont[' ']!;

      for (var row = 0; row < pattern.length; row++) {
        for (var col = 0; col < pattern[row].length; col++) {
          if (pattern[row][col] == '1') {
            final x = startX + (c * charWidth + col) * scale;
            final y = startY + row * scale;
            targets.add(Offset(x, y));
          }
        }
      }
    }

    return targets;
  }

  void _initializeBalls(List<Offset> targets, Size size) {
    final count = max(targets.length, 60);
    final random = Random(42);
    _balls = List.generate(count, (i) {
      final target = i < targets.length
          ? targets[i]
          : Offset(size.width / 2, size.height / 2);
      final ball = _Ball(target.dx, target.dy, i);

      // Start scattered
      ball.x = size.width * random.nextDouble();
      ball.y = size.height * random.nextDouble();
      ball.z = (random.nextDouble() - 0.5) * 200;

      return ball;
    });
  }

  @override
  bool shouldRepaint(covariant _VectorBallsPainter oldDelegate) => true;
}
