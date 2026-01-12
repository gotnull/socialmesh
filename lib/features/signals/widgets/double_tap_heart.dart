import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper that detects double-taps and shows a heart burst animation
class DoubleTapLikeWrapper extends StatefulWidget {
  const DoubleTapLikeWrapper({
    required this.child,
    required this.onDoubleTap,
    this.isLiked = false,
    super.key,
  });

  final Widget child;
  final VoidCallback onDoubleTap;
  final bool isLiked;

  @override
  State<DoubleTapLikeWrapper> createState() => _DoubleTapLikeWrapperState();
}

class _DoubleTapLikeWrapperState extends State<DoubleTapLikeWrapper> {
  final List<_HeartAnimationData> _hearts = [];
  int _heartId = 0;

  void _handleDoubleTap(TapDownDetails details) {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Call the callback
    widget.onDoubleTap();

    // Add heart animation at tap location
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);

    setState(() {
      _hearts.add(_HeartAnimationData(id: _heartId++, position: localPosition));
    });

    // Remove heart after animation completes
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _hearts.removeWhere((h) => h.id == _heartId - 1);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // Required for onDoubleTapDown to work
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          ..._hearts.map(
            (heart) => Positioned(
              left: heart.position.dx - 40,
              top: heart.position.dy - 40,
              child: _HeartBurst(key: ValueKey(heart.id)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartAnimationData {
  _HeartAnimationData({required this.id, required this.position});

  final int id;
  final Offset position;
}

/// The heart burst animation widget
class _HeartBurst extends StatefulWidget {
  const _HeartBurst({super.key});

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  final List<_ParticleHeart> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    // Generate particle hearts
    final random = Random();
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * pi + random.nextDouble() * 0.5;
      _particles.add(
        _ParticleHeart(
          angle: angle,
          distance: 30 + random.nextDouble() * 30,
          size: 12 + random.nextDouble() * 8,
          delay: random.nextDouble() * 0.2,
        ),
      );
    }

    _controller.forward();
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
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main heart with glow
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ),
              ),
              // Particle hearts
              ..._particles.map((particle) {
                final progress =
                    ((_controller.value - particle.delay) /
                            (1 - particle.delay))
                        .clamp(0.0, 1.0);
                final curve = Curves.easeOut.transform(progress);
                final opacity = (1 - progress).clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(
                    cos(particle.angle) * particle.distance * curve,
                    sin(particle.angle) * particle.distance * curve -
                        20 * curve,
                  ),
                  child: Opacity(
                    opacity: opacity * _opacityAnimation.value,
                    child: Icon(
                      Icons.favorite,
                      color: Colors.red.shade300,
                      size: particle.size,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _ParticleHeart {
  _ParticleHeart({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });

  final double angle;
  final double distance;
  final double size;
  final double delay;
}
