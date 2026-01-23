import 'package:flutter/material.dart';

/// Animated linear gradient background for containers/buttons.
/// Set [animate] to false for a static gradient.
/// Set [enabled] to false to return [child] without gradient.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    super.key,
    required this.gradient,
    required this.child,
    this.duration = const Duration(milliseconds: 2500),
    this.animate = true,
    this.enabled = true,
    this.borderRadius,
  });

  final LinearGradient gradient;
  final Widget child;
  final Duration duration;
  final bool animate;
  final bool enabled;
  final BorderRadius? borderRadius;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.animate && widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    final shouldAnimate = widget.animate && widget.enabled;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
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
        final slide = widget.animate ? (_controller.value * 2) - 1.0 : 0.0;
        final decoration = BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradient.colors,
            stops: widget.gradient.stops,
            begin: widget.gradient.begin,
            end: widget.gradient.end,
            tileMode: TileMode.mirror,
            transform: _SlideGradientTransform(slide),
          ),
          borderRadius: widget.borderRadius,
        );
        return DecoratedBox(decoration: decoration, child: child);
      },
      child: widget.child,
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * slidePercent,
      0,
      0,
    );
  }
}
