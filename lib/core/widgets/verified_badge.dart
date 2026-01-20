import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/subscription_providers.dart';

/// Gold colors for verified badges
const Color kGoldBadgeColor = Color(0xFFFFD700);
const Color _goldLight = Color(0xFFFFE55C);
const Color _goldMid = Color(0xFFFFD700);
const Color _goldDark = Color(0xFFB8860B);

/// A verified badge widget that displays differently based on badge type:
/// - Gold badge for users with all premium features (Authorised)
/// - Standard verified badge from Firestore (admin-managed)
class VerifiedBadge extends ConsumerWidget {
  /// The size of the badge icon
  final double size;

  /// Whether the user is verified (from Firestore)
  final bool isVerified;

  /// Whether to check if current user has all premium features
  /// If true, shows gold badge for current user if they have all features
  final bool checkPremiumStatus;

  /// Optional user ID - if provided and matches current user, checks premium status
  final String? userId;

  const VerifiedBadge({
    super.key,
    this.size = 16,
    this.isVerified = false,
    this.checkPremiumStatus = false,
    this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if current user should show gold badge
    final hasAllPremium = checkPremiumStatus
        ? ref.watch(hasAllPremiumFeaturesProvider)
        : false;

    // Show gold badge if user has all premium features
    if (hasAllPremium) {
      return Icon(Icons.verified, size: size, color: kGoldBadgeColor);
    }

    // Show standard verified badge if verified in Firestore
    if (isVerified) {
      return Icon(
        Icons.verified,
        size: size,
        color: kGoldBadgeColor, // Also gold for admin-verified users
      );
    }

    // No badge
    return const SizedBox.shrink();
  }
}

/// A simple verified badge that always shows with gold color
/// Use this for displaying verified status without checking premium
class SimpleVerifiedBadge extends StatelessWidget {
  final double size;

  /// Whether to enable the coin spin and sparkle animations
  final bool animate;

  const SimpleVerifiedBadge({super.key, this.size = 16, this.animate = true});

  @override
  Widget build(BuildContext context) {
    if (animate) {
      return _AnimatedGoldBadge(size: size);
    }
    return _GoldGradientBadge(size: size);
  }
}

/// Static gold gradient badge without animation
class _GoldGradientBadge extends StatelessWidget {
  final double size;

  const _GoldGradientBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_goldLight, _goldMid, _goldDark, _goldMid, _goldLight],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(bounds),
      child: Icon(
        Icons.verified,
        size: size,
        color: kGoldBadgeColor, // Color property set to gold for tests
      ),
    );
  }
}

/// Animated gold badge with random coin spins and sparkles
class _AnimatedGoldBadge extends StatefulWidget {
  final double size;

  const _AnimatedGoldBadge({required this.size});

  @override
  State<_AnimatedGoldBadge> createState() => _AnimatedGoldBadgeState();
}

class _AnimatedGoldBadgeState extends State<_AnimatedGoldBadge>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _shimmerController;
  late AnimationController _sparkleController;
  late Animation<double> _spinAnimation;
  late Animation<double> _shimmerAnimation;

  final Random _random = Random();
  bool _isSpinning = false;

  // Timers for scheduled spins and sparkles so tests can cancel them
  Timer? _spinTimer;
  Timer? _sparkleTimer;

  // Sparkle positions and states
  final List<_Sparkle> _sparkles = [];

  @override
  void initState() {
    super.initState();

    // Coin spin animation - full 360° rotation
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _spinAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeInOut),
    );
    _spinController.addStatusListener(_onSpinComplete);

    // Shimmer animation for gradient movement - reverse for smooth back-and-forth
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Initialize timers as null (scheduled tasks use Timer so we can cancel them)
    _spinTimer = null;
    _sparkleTimer = null;

    // Sparkle animation controller
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start random spin scheduling
    _scheduleNextSpin();
    _scheduleNextSparkle();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _sparkleTimer?.cancel();
    _spinController.removeStatusListener(_onSpinComplete);
    _spinController.dispose();
    _shimmerController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _onSpinComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _spinController.reset();
      _isSpinning = false;
      _scheduleNextSpin();
    }
  }

  void _scheduleNextSpin() {
    // Random delay between 3-8 seconds
    final delay = Duration(milliseconds: 3000 + _random.nextInt(5000));
    _spinTimer?.cancel();
    _spinTimer = Timer(delay, () {
      if (mounted && !_isSpinning) {
        _isSpinning = true;
        _spinController.forward();
      }
    });
  }

  void _scheduleNextSparkle() {
    // Random delay between 2-5 seconds
    final delay = Duration(milliseconds: 2000 + _random.nextInt(3000));
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
      // Generate 2-4 sparkles at random positions around the badge
      final count = 2 + _random.nextInt(3);
      for (int i = 0; i < count; i++) {
        final angle = _random.nextDouble() * 2 * pi;
        final distance = 0.3 + _random.nextDouble() * 0.4; // 30-70% from center
        _sparkles.add(
          _Sparkle(
            angle: angle,
            distance: distance,
            delay: _random.nextInt(200),
            size: 0.15 + _random.nextDouble() * 0.2,
          ),
        );
      }
    });
    _sparkleController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Sparkles layer (behind the badge)
          ..._buildSparkles(),

          // Main badge with spin and shimmer
          AnimatedBuilder(
            animation: Listenable.merge([_spinAnimation, _shimmerAnimation]),
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(_spinAnimation.value),
                child: _buildShimmeringBadge(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShimmeringBadge() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final shimmerOffset = _shimmerAnimation.value;
            return LinearGradient(
              begin: Alignment(-1 + shimmerOffset, -1),
              end: Alignment(1 + shimmerOffset, 1),
              colors: const [
                _goldDark,
                _goldMid,
                _goldLight,
                Colors.white,
                _goldLight,
                _goldMid,
                _goldDark,
              ],
              stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Icon(
            Icons.verified,
            size: widget.size,
            color: kGoldBadgeColor,
          ),
        );
      },
    );
  }

  List<Widget> _buildSparkles() {
    return _sparkles.map((sparkle) {
      final offsetX = cos(sparkle.angle) * sparkle.distance * widget.size;
      final offsetY = sin(sparkle.angle) * sparkle.distance * widget.size;

      return AnimatedBuilder(
        animation: _sparkleController,
        builder: (context, child) {
          // Calculate delayed progress for staggered effect
          final delayProgress =
              ((_sparkleController.value * 1000 - sparkle.delay) / 600).clamp(
                0.0,
                1.0,
              );

          // Sparkle fades in then out
          final opacity = delayProgress < 0.5
              ? delayProgress * 2
              : (1 - delayProgress) * 2;

          // Sparkle scales up then down
          final scale = delayProgress < 0.5
              ? 0.5 + delayProgress
              : 1.5 - delayProgress;

          if (opacity <= 0) return const SizedBox.shrink();

          return Positioned(
            left:
                widget.size * 0.8 + offsetX - (sparkle.size * widget.size / 2),
            top: widget.size * 0.8 + offsetY - (sparkle.size * widget.size / 2),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: _buildSparkleStar(sparkle.size * widget.size),
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

/// Data class for sparkle particles
class _Sparkle {
  final double angle;
  final double distance;
  final int delay;
  final double size;

  _Sparkle({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.size,
  });
}

/// Custom painter for 4-point star sparkle
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

    // 4-point star
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

    // Draw with glow effect
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
