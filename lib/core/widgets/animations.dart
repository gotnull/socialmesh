import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bouncy scale animation on tap
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final bool enabled;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.enabled = true,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled) _controller.forward();
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
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Shimmer loading effect
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
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
              transform: _SlidingGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
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

/// Animated counter for numbers
class AnimatedCounter extends StatelessWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;

  const AnimatedCounter({
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
      builder: (context, value, child) {
        return Text('${prefix ?? ''}$value${suffix ?? ''}', style: style);
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
