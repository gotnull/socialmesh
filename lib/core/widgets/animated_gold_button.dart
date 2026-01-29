import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// An animated gold button with shimmer effect and sparkles, matching
/// the verified badge animation style.
class AnimatedGoldButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const AnimatedGoldButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<AnimatedGoldButton> createState() => _AnimatedGoldButtonState();
}

class _AnimatedGoldButtonState extends State<AnimatedGoldButton>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _sparkleController;
  late Animation<double> _shimmerAnimation;

  final Random _random = Random();
  Timer? _sparkleTimer;
  final List<_Sparkle> _sparkles = [];

  @override
  void initState() {
    super.initState();

    // Shimmer animation for gradient movement
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Sparkle animation controller
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scheduleNextSparkle();
  }

  @override
  void dispose() {
    _sparkleTimer?.cancel();
    _shimmerController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _scheduleNextSparkle() {
    final delay = Duration(milliseconds: 1500 + _random.nextInt(2500));
    _sparkleTimer?.cancel();
    _sparkleTimer = Timer(delay, () {
      if (mounted) {
        _triggerSparkles();
        _scheduleNextSparkle();
      }
    });
  }

  void _triggerSparkles() {
    setState(() {
      _sparkles.clear();
      final count = 3 + _random.nextInt(4);
      for (int i = 0; i < count; i++) {
        // Spread sparkles across the button
        final xPos = _random.nextDouble();
        final yPos = _random.nextDouble();
        _sparkles.add(
          _Sparkle(
            xPos: xPos,
            yPos: yPos,
            delay: _random.nextInt(300),
            size: 6 + _random.nextDouble() * 8,
          ),
        );
      }
    });
    _sparkleController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main button with shimmer
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + _shimmerAnimation.value, -1),
                    end: Alignment(1 + _shimmerAnimation.value, 1),
                    colors: [
                      AccentColors.goldBrown,
                      AccentColors.goldDarkGoldenrod,
                      AccentColors.goldMetallic,
                      AccentColors.goldMetallic
                          .withValues(alpha: 0.9), // Transparent shimmer
                      Colors.white.withValues(alpha: 0.6), // Transparent white
                      AccentColors.goldMetallic
                          .withValues(alpha: 0.9), // Transparent shimmer
                      AccentColors.goldMetallic,
                      AccentColors.goldDarkGoldenrod,
                      AccentColors.goldBrown,
                    ],
                    stops: const [
                      0.0,
                      0.15,
                      0.3,
                      0.4,
                      0.5,
                      0.6,
                      0.7,
                      0.85,
                      1.0,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AccentColors.goldMetallic.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  widget.isLoading ? 'Loading...' : widget.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D2600), // Dark brown for contrast on gold
                    shadows: [
                      Shadow(
                        color: Color(0x40FFFFFF),
                        offset: Offset(0, 1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Sparkles layer
          ..._buildSparkles(),
        ],
      ),
    );
  }

  List<Widget> _buildSparkles() {
    return _sparkles.map((sparkle) {
      return AnimatedBuilder(
        animation: _sparkleController,
        builder: (context, child) {
          final delayProgress =
              ((_sparkleController.value * 1000 - sparkle.delay) / 500).clamp(
                0.0,
                1.0,
              );

          final opacity = delayProgress < 0.5
              ? delayProgress * 2
              : (1 - delayProgress) * 2;

          final scale = delayProgress < 0.5
              ? 0.5 + delayProgress
              : 1.5 - delayProgress;

          if (opacity <= 0) return const SizedBox.shrink();

          return Positioned(
            left: sparkle.xPos * 100 - sparkle.size / 2,
            top: sparkle.yPos * 40 - sparkle.size / 2,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: _buildSparkleStar(sparkle.size),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildSparkleStar(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter(color: Colors.white)),
    );
  }
}

class _Sparkle {
  final double xPos;
  final double yPos;
  final int delay;
  final double size;

  _Sparkle({
    required this.xPos,
    required this.yPos,
    required this.delay,
    required this.size,
  });
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.3;

    for (int i = 0; i < 8; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * pi / 4) - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
