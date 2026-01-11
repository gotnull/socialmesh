import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:socialmesh/core/theme.dart';

/// Custom animation utilities that complement the `animations` package.
///
/// The `animations` package provides page transitions (OpenContainer, SharedAxis,
/// FadeThrough) which we use in animated_list_item.dart.
///
/// This file provides micro-interactions and UI animations:
/// - [BouncyTap] - Tactile tap feedback
/// - [PulseAnimation] - Attention-grabbing pulse
/// - [SpinAnimation] - Loading spinner
/// - [SlideInAnimation] / [ScaleInAnimation] - Entry animations
/// - [GlowAnimation] - Glowing effects
/// - [FloatAnimation] / [WaveAnimation] - Ambient motion
/// - [ShakeAnimation] - Error feedback
/// - [FlipAnimation] - Card flip
/// - [AnimatedProgressRing] - Progress indicator
/// - [AnimatedMorphIcon] - Icon transitions
/// - [AnimatedCounter] - Number animations
/// - [TypewriterText] - Text reveal
///
/// For skeleton loading states, use the `skeletonizer` package instead.

/// Bouncy scale animation on tap
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final bool enabled;
  final bool enable3DPress;
  final double tiltDegrees;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.enabled = true,
    this.enable3DPress = false,
    this.tiltDegrees = 3.0,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _tiltAnimation;
  Offset? _tapPosition;
  Size? _widgetSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _tiltAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled) {
      if (widget.enable3DPress) {
        _tapPosition = details.localPosition;
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        _widgetSize = box?.size;
      }
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enabled) {
      _controller.reverse();
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    if (widget.enabled) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      child: widget.enable3DPress
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                double rotateX = 0;
                double rotateY = 0;

                if (_tapPosition != null && _widgetSize != null) {
                  final centerX = _widgetSize!.width / 2;
                  final centerY = _widgetSize!.height / 2;
                  rotateY =
                      ((_tapPosition!.dx - centerX) / centerX) *
                      widget.tiltDegrees *
                      _tiltAnimation.value;
                  rotateX =
                      -((_tapPosition!.dy - centerY) / centerY) *
                      widget.tiltDegrees *
                      _tiltAnimation.value;
                }

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(rotateX * math.pi / 180)
                    ..rotateY(rotateY * math.pi / 180),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: widget.child,
            )
          : ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Pulse animation for attention-grabbing elements
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;
  final bool enabled;

  const PulseAnimation({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 1.05,
    this.duration = const Duration(milliseconds: 1000),
    this.enabled = true,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

/// Rotating animation for loading indicators
class SpinAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enabled;

  const SpinAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  @override
  State<SpinAnimation> createState() => _SpinAnimationState();
}

class _SpinAnimationState extends State<SpinAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(SpinAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

/// Slide and fade in animation
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;
  final Curve curve;

  const SlideInAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.2),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

/// Scale in animation with bounce
class ScaleInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const ScaleInAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.curve = Curves.elasticOut,
  });

  @override
  State<ScaleInAnimation> createState() => _ScaleInAnimationState();
}

class _ScaleInAnimationState extends State<ScaleInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Glow effect animation
class GlowAnimation extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minRadius;
  final double maxRadius;
  final Duration duration;
  final bool enabled;

  const GlowAnimation({
    super.key,
    required this.child,
    required this.glowColor,
    this.minRadius = 4,
    this.maxRadius = 12,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  @override
  State<GlowAnimation> createState() => _GlowAnimationState();
}

class _GlowAnimationState extends State<GlowAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: widget.minRadius,
      end: widget.maxRadius,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(GlowAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.5),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 4,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Staggered list animation helper
class StaggeredListBuilder extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Duration staggerDelay;
  final Duration itemDuration;
  final Curve curve;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const StaggeredListBuilder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.itemDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      physics: physics,
      padding: padding,
      itemBuilder: (context, index) {
        return SlideInAnimation(
          delay: Duration(
            milliseconds: (index.clamp(0, 10) * staggerDelay.inMilliseconds)
                .toInt(),
          ),
          duration: itemDuration,
          curve: curve,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// Floating animation for elements that should appear to float
class FloatAnimation extends StatefulWidget {
  final Widget child;
  final double floatHeight;
  final Duration duration;
  final bool enabled;

  const FloatAnimation({
    super.key,
    required this.child,
    this.floatHeight = 8,
    this.duration = const Duration(milliseconds: 2000),
    this.enabled = true,
  });

  @override
  State<FloatAnimation> createState() => _FloatAnimationState();
}

class _FloatAnimationState extends State<FloatAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: 0,
      end: widget.floatHeight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: widget.child,
        );
      },
    );
  }
}

/// Wave animation for group effects
class WaveAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double amplitude;
  final double frequency;

  const WaveAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
    this.amplitude = 4,
    this.frequency = 2,
  });

  @override
  State<WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<WaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
        final offset =
            math.sin(_controller.value * 2 * math.pi * widget.frequency) *
            widget.amplitude;
        return Transform.translate(
          offset: Offset(0, offset),
          child: widget.child,
        );
      },
    );
  }
}

/// Typewriter text animation
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 50),
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayText = '';
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _typeNextChar();
  }

  void _typeNextChar() {
    if (_charIndex < widget.text.length) {
      Future.delayed(widget.charDuration, () {
        if (mounted) {
          setState(() {
            _charIndex++;
            _displayText = widget.text.substring(0, _charIndex);
          });
          _typeNextChar();
        }
      });
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayText, style: widget.style);
  }
}

/// Animated counter for numbers - animates smoothly from previous value to new value
class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 800),
    this.style,
    this.prefix,
    this.suffix,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _previousValue;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _currentValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _currentValue;
      _currentValue = widget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayValue =
            (_previousValue +
                    (_currentValue - _previousValue) * _animation.value)
                .round();
        return Text(
          '${widget.prefix ?? ''}$displayValue${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

/// Shake animation for errors or attention
class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final bool shake;
  final Duration duration;
  final double shakeOffset;

  const ShakeAnimation({
    super.key,
    required this.child,
    this.shake = false,
    this.duration = const Duration(milliseconds: 500),
    this.shakeOffset = 10,
  });

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getShakeOffset(double progress) {
    return math.sin(progress * math.pi * 4) *
        widget.shakeOffset *
        (1 - progress);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_getShakeOffset(_animation.value), 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Flip animation for card-like transitions
class FlipAnimation extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool showBack;
  final Duration duration;

  const FlipAnimation({
    super.key,
    required this.front,
    required this.back,
    this.showBack = false,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FlipAnimation> createState() => _FlipAnimationState();
}

class _FlipAnimationState extends State<FlipAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.showBack) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(FlipAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack != oldWidget.showBack) {
      if (widget.showBack) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final isFront = _animation.value < 0.5;
        final rotation = _animation.value * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotation),
          child: isFront
              ? widget.front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: widget.back,
                ),
        );
      },
    );
  }
}

/// Progress ring animation
class AnimatedProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;
  final Duration duration;
  final Widget? child;

  const AnimatedProgressRing({
    super.key,
    required this.progress,
    this.size = 48,
    this.strokeWidth = 4,
    this.progressColor = const Color(0xFFE91E8C),
    this.backgroundColor = const Color(0xFF414A5A),
    this.duration = const Duration(milliseconds: 500),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _ProgressRingPainter(
                  progress: value,
                  strokeWidth: strokeWidth,
                  progressColor: progressColor,
                  backgroundColor: backgroundColor,
                ),
              ),
              if (child != null) child!,
            ],
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Animated icon that morphs between two icons
class AnimatedMorphIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Duration duration;

  const AnimatedMorphIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Icon(icon, key: ValueKey(icon), size: size, color: color),
    );
  }
}

/// A themed switch that uses the app's accent color.
/// Works correctly on both iOS (CupertinoSwitch) and Android (Material Switch).
class ThemedSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const ThemedSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: SemanticColors.onAccent,
      activeTrackColor: accentColor,
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade700,
    );
  }
}

// ============================================================================
// PREMIUM ANIMATION UTILITIES
// ============================================================================

/// Professional animation curves for premium feel
class AppCurves {
  /// Smooth deceleration - great for entrances
  static const Curve smooth = Curves.easeOutCubic;

  /// Snappy response - great for taps/interactions
  static const Curve snappy = Curves.easeOutBack;

  /// Bouncy - great for success states
  static const Curve bouncy = Curves.elasticOut;

  /// Spring-like - great for dialogs/sheets
  static const Curve spring = Curves.easeOutQuart;

  /// Subtle overshoot - professional entrance
  static const Curve overshoot = Curves.easeOutBack;
}

/// Standard animation durations for consistency
class AppDurations {
  /// Quick micro-interactions (50-100ms)
  static const Duration quick = Duration(milliseconds: 100);

  /// Standard transitions (200-300ms)
  static const Duration standard = Duration(milliseconds: 250);

  /// Medium transitions (300-400ms)
  static const Duration medium = Duration(milliseconds: 350);

  /// Slow, emphasized transitions (400-500ms)
  static const Duration slow = Duration(milliseconds: 450);

  /// Page transitions
  static const Duration page = Duration(milliseconds: 300);

  /// Stagger delay between items
  static const Duration stagger = Duration(milliseconds: 50);
}

/// Staggered list animation - items animate in sequence
class StaggeredListAnimation extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration itemDuration;
  final Duration staggerDelay;
  final Offset beginOffset;

  const StaggeredListAnimation({
    super.key,
    required this.index,
    required this.child,
    this.itemDuration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.beginOffset = const Offset(0, 0.1),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: itemDuration,
      curve: AppCurves.smooth,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(
            beginOffset.dx * (1 - value) * 50,
            beginOffset.dy * (1 - value) * 50,
          ),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

/// Smooth fade scale transition for dialogs and overlays
class FadeScaleIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginScale;
  final Curve curve;

  const FadeScaleIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.beginScale = 0.95,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeScaleIn> createState() => _FadeScaleInState();
}

class _FadeScaleInState extends State<FadeScaleIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}

/// Animated shimmer effect for loading states
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF29303D),
    this.highlightColor = const Color(0xFF414A5A),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Smooth counter animation for numbers
class AnimatedNumber extends StatelessWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 500),
    this.style,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: AppCurves.smooth,
      builder: (context, animatedValue, child) {
        return Text(
          '${prefix ?? ''}$animatedValue${suffix ?? ''}',
          style: style,
        );
      },
    );
  }
}

/// Ripple effect animation (expands from center)
class RippleAnimation extends StatefulWidget {
  final Widget child;
  final Color color;
  final Duration duration;
  final bool enabled;

  const RippleAnimation({
    super.key,
    required this.child,
    this.color = const Color(0x3DFFFFFF), // SemanticColors.glow equivalent
    this.duration = const Duration(milliseconds: 600),
    this.enabled = true,
  });

  @override
  State<RippleAnimation> createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<RippleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(RippleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(
            progress: _controller.value,
            color: widget.color,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.6;

    final paint = Paint()
      ..color = color.withAlpha(((1 - progress) * 255 * 0.5).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, maxRadius * progress, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Hero-like shared element transition helper
class SharedElement extends StatelessWidget {
  final String tag;
  final Widget child;
  final bool enabled;

  const SharedElement({
    super.key,
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Hero(
      tag: tag,
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Material(
                  color: Colors.transparent,
                  child: toHeroContext.widget,
                );
              },
            );
          },
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

// ============================================================================
// 3D ANIMATIONS - Premium card and list effects
// ============================================================================

/// 3D flip card animation - flips on X or Y axis
class Flip3DCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool showBack;
  final Duration duration;
  final Axis axis;
  final VoidCallback? onFlip;

  const Flip3DCard({
    super.key,
    required this.front,
    required this.back,
    this.showBack = false,
    this.duration = const Duration(milliseconds: 500),
    this.axis = Axis.vertical,
    this.onFlip,
  });

  @override
  State<Flip3DCard> createState() => _Flip3DCardState();
}

class _Flip3DCardState extends State<Flip3DCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _showFront = !widget.showBack;
    if (widget.showBack) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(Flip3DCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack != oldWidget.showBack) {
      if (widget.showBack) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * math.pi;
        final isFront = angle < math.pi / 2;

        // Update which side to show at the midpoint
        if (isFront != _showFront) {
          _showFront = isFront;
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateX(widget.axis == Axis.horizontal ? angle : 0)
            ..rotateY(widget.axis == Axis.vertical ? angle : 0),
          child: _showFront
              ? widget.front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateX(widget.axis == Axis.horizontal ? math.pi : 0)
                    ..rotateY(widget.axis == Axis.vertical ? math.pi : 0),
                  child: widget.back,
                ),
        );
      },
    );
  }
}

/// 3D tilt effect on hover/touch - gives depth to cards
class Tilt3DEffect extends StatefulWidget {
  final Widget child;
  final double maxTilt;
  final double perspective;
  final Duration duration;
  final bool enableTouch;

  const Tilt3DEffect({
    super.key,
    required this.child,
    this.maxTilt = 10.0,
    this.perspective = 0.002,
    this.duration = const Duration(milliseconds: 150),
    this.enableTouch = true,
  });

  @override
  State<Tilt3DEffect> createState() => _Tilt3DEffectState();
}

class _Tilt3DEffectState extends State<Tilt3DEffect> {
  double _rotateX = 0;
  double _rotateY = 0;

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!widget.enableTouch) return;
    setState(() {
      final x = details.localPosition.dx;
      final y = details.localPosition.dy;
      final centerX = constraints.maxWidth / 2;
      final centerY = constraints.maxHeight / 2;

      _rotateY = ((x - centerX) / centerX) * widget.maxTilt;
      _rotateX = -((y - centerY) / centerY) * widget.maxTilt;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) => _onPanUpdate(details, constraints),
          onPanEnd: _onPanEnd,
          child: AnimatedContainer(
            duration: widget.duration,
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..setEntry(3, 2, widget.perspective)
              ..rotateX(_rotateX * math.pi / 180)
              ..rotateY(_rotateY * math.pi / 180),
            transformAlignment: Alignment.center,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// 3D carousel-style row animation - items rotate in on Y axis
class Rotate3DListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;
  final double rotationAngle;
  final Curve curve;

  const Rotate3DListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.staggerDelay = const Duration(milliseconds: 80),
    this.rotationAngle = 90,
    this.curve = Curves.easeOutBack,
  });

  @override
  State<Rotate3DListItem> createState() => _Rotate3DListItemState();
}

class _Rotate3DListItemState extends State<Rotate3DListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _rotationAnimation = Tween<double>(
      begin: widget.rotationAngle,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future.delayed(widget.staggerDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
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
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_rotationAnimation.value * math.pi / 180)
            ..setTranslationRaw(_slideAnimation.value, 0, 0),
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}

/// 3D cube transition - rotates content like a cube
class Cube3DTransition extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration staggerDelay;

  const Cube3DTransition({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 700),
    this.staggerDelay = const Duration(milliseconds: 100),
  });

  @override
  State<Cube3DTransition> createState() => _Cube3DTransitionState();
}

class _Cube3DTransitionState extends State<Cube3DTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _rotateAnimation = Tween<double>(
      begin: -90,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );

    Future.delayed(widget.staggerDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
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
        return Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(_rotateAnimation.value * math.pi / 180),
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}

/// 3D perspective slide - items slide in with depth perspective
class Perspective3DSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;
  final SlideDirection direction;
  final bool enabled;

  const Perspective3DSlide({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.staggerDelay = const Duration(milliseconds: 60),
    this.direction = SlideDirection.left,
    this.enabled = true,
  });

  @override
  State<Perspective3DSlide> createState() => _Perspective3DSlideState();
}

enum SlideDirection { left, right, top, bottom }

class _Perspective3DSlideState extends State<Perspective3DSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _perspectiveAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final slideStart = switch (widget.direction) {
      SlideDirection.left => -100.0,
      SlideDirection.right => 100.0,
      SlideDirection.top => -100.0,
      SlideDirection.bottom => 100.0,
    };

    _slideAnimation = Tween<double>(
      begin: slideStart,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _perspectiveAnimation = Tween<double>(
      begin: 0.3,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.7, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    if (widget.enabled) {
      Future.delayed(widget.staggerDelay * widget.index, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isHorizontal =
            widget.direction == SlideDirection.left ||
            widget.direction == SlideDirection.right;

        final tx = isHorizontal ? _slideAnimation.value : 0.0;
        final ty = isHorizontal ? 0.0 : _slideAnimation.value;
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..setTranslationRaw(tx, ty, 0)
              ..rotateY(isHorizontal ? _perspectiveAnimation.value : 0)
              ..rotateX(isHorizontal ? 0 : _perspectiveAnimation.value),
            child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
          ),
        );
      },
    );
  }
}

/// Stacked cards animation - cards stack and fan out
class StackedCards3D extends StatefulWidget {
  final List<Widget> cards;
  final int visibleCards;
  final double cardSpacing;
  final double rotationAngle;
  final Duration animationDuration;

  const StackedCards3D({
    super.key,
    required this.cards,
    this.visibleCards = 3,
    this.cardSpacing = 20,
    this.rotationAngle = 5,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<StackedCards3D> createState() => _StackedCards3DState();
}

class _StackedCards3DState extends State<StackedCards3D> {
  int _currentIndex = 0;

  void _nextCard() {
    if (_currentIndex < widget.cards.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          _nextCard();
        } else if (details.primaryVelocity! > 0) {
          _previousCard();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(
          math.min(widget.visibleCards, widget.cards.length - _currentIndex),
          (index) {
            final cardIndex = _currentIndex + index;
            final reversedIndex = widget.visibleCards - 1 - index;

            final s = 1 - (reversedIndex * 0.05);
            return Transform.scale(
              scale: s,
              child: AnimatedContainer(
                duration: widget.animationDuration,
                curve: Curves.easeOutBack,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..setTranslationRaw(0, reversedIndex * widget.cardSpacing, 0)
                  ..rotateZ(
                    reversedIndex * widget.rotationAngle * math.pi / 180,
                  ),
                child: widget.cards[cardIndex],
              ),
            );
          },
        ).reversed.toList(),
      ),
    );
  }
}

/// Parallax 3D effect - layers move at different speeds
class Parallax3DEffect extends StatefulWidget {
  final Widget child;
  final double intensity;
  final bool enableGyroscope;

  const Parallax3DEffect({
    super.key,
    required this.child,
    this.intensity = 20.0,
    this.enableGyroscope = false,
  });

  @override
  State<Parallax3DEffect> createState() => _Parallax3DEffectState();
}

class _Parallax3DEffectState extends State<Parallax3DEffect> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _offset = Offset(
            (event.position.dx - size.width / 2) / size.width,
            (event.position.dy - size.height / 2) / size.height,
          );
        });
      },
      onExit: (_) => setState(() => _offset = Offset.zero),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(_offset.dx * 0.1)
          ..rotateX(-_offset.dy * 0.1)
          ..setTranslationRaw(
            _offset.dx * widget.intensity,
            _offset.dy * widget.intensity,
            0,
          ),
        child: widget.child,
      ),
    );
  }
}

/// Door opening animation - swings open like a door
class Door3DAnimation extends StatefulWidget {
  final Widget child;
  final bool isOpen;
  final Duration duration;
  final double openAngle;
  final Alignment pivot;

  const Door3DAnimation({
    super.key,
    required this.child,
    this.isOpen = false,
    this.duration = const Duration(milliseconds: 500),
    this.openAngle = 90,
    this.pivot = Alignment.centerLeft,
  });

  @override
  State<Door3DAnimation> createState() => _Door3DAnimationState();
}

class _Door3DAnimationState extends State<Door3DAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: 0,
      end: widget.openAngle,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    if (widget.isOpen) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(Door3DAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      widget.isOpen ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform(
          alignment: widget.pivot,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(-_animation.value * math.pi / 180),
          child: widget.child,
        );
      },
    );
  }
}

/// Zoom blur effect - zooms in with motion blur effect
class ZoomBlur3D extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration staggerDelay;

  const ZoomBlur3D({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  @override
  State<ZoomBlur3D> createState() => _ZoomBlur3DState();
}

class _ZoomBlur3DState extends State<ZoomBlur3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scaleAnimation = Tween<double>(
      begin: 1.3,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.staggerDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}

/// Animated signal item with Apple TV-style entrance and refresh animations.
///
/// On initial appear: fade + slide up from bottom (staggered by index)
/// On refresh: randomly slide out left or right, then return from opposite direction
class AnimatedSignalItem extends StatefulWidget {
  const AnimatedSignalItem({
    super.key,
    required this.child,
    required this.index,
    this.isRefreshing = false,
    this.appearDuration = const Duration(milliseconds: 600),
    this.refreshDuration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 80),
  });

  final Widget child;
  final int index;
  final bool isRefreshing;
  final Duration appearDuration;
  final Duration refreshDuration;
  final Duration staggerDelay;

  @override
  State<AnimatedSignalItem> createState() => _AnimatedSignalItemState();
}

class _AnimatedSignalItemState extends State<AnimatedSignalItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _hasAppeared = false;
  bool _wasRefreshing = false;
  bool _slideFromLeft = false; // Track direction for refresh return

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.appearDuration,
    );

    _setupAppearAnimation();
    _startAppearAnimation();
  }

  void _setupAppearAnimation() {
    // Apple TV style: fade + slide up from bottom
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // Start below
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  void _setupRefreshOutAnimation(bool slideLeft) {
    _slideFromLeft = slideLeft;
    _controller.duration = widget.refreshDuration;

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(slideLeft ? -1.0 : 1.0, 0), // Slide out horizontally
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
  }

  void _setupRefreshInAnimation() {
    _controller.duration = widget.refreshDuration;

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // Return from opposite direction
    _slideAnimation = Tween<Offset>(
      begin: Offset(_slideFromLeft ? 1.0 : -1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  void _startAppearAnimation() {
    final delay = widget.staggerDelay * widget.index;
    Future.delayed(delay, () {
      if (mounted && !_hasAppeared) {
        _hasAppeared = true;
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedSignalItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect refresh state change
    if (widget.isRefreshing && !_wasRefreshing) {
      // Starting refresh - slide out randomly left or right
      _wasRefreshing = true;
      final slideLeft = math.Random().nextBool();
      _setupRefreshOutAnimation(slideLeft);
      _controller.forward(from: 0);
    } else if (!widget.isRefreshing && _wasRefreshing) {
      // Refresh ended - slide back in from opposite direction
      _wasRefreshing = false;

      // Wait for slide out to complete, then slide back in
      _controller.addStatusListener(_onRefreshOutComplete);
    }
  }

  void _onRefreshOutComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.removeStatusListener(_onRefreshOutComplete);
      _setupRefreshInAnimation();

      // Stagger the return animation
      final delay = widget.staggerDelay * widget.index;
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward(from: 0);
        }
      });
    }
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
        return Transform.translate(
          offset: Offset(
            _slideAnimation.value.dx * MediaQuery.of(context).size.width,
            _slideAnimation.value.dy * 100, // 100px vertical slide
          ),
          child: Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
