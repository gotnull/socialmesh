// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// Applies an animated linear gradient mask to any child.
/// Set [animate] to false to keep a static gradient.
/// Set [enabled] to false to bypass the mask entirely.
class AnimatedGradientMask extends StatefulWidget {
  const AnimatedGradientMask({
    super.key,
    required this.child,
    required this.gradient,
    this.duration = const Duration(milliseconds: 2500),
    this.animate = true,
    this.enabled = true,
  });

  final Widget child;
  final LinearGradient gradient;
  final Duration duration;
  final bool animate;
  final bool enabled;

  @override
  State<AnimatedGradientMask> createState() => _AnimatedGradientMaskState();
}

class _AnimatedGradientMaskState extends State<AnimatedGradientMask>
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
  void didUpdateWidget(AnimatedGradientMask oldWidget) {
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
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              colors: widget.gradient.colors,
              stops: widget.gradient.stops,
              begin: widget.gradient.begin,
              end: widget.gradient.end,
              tileMode: TileMode.mirror,
              transform: _SlideGradientTransform(slide),
            ).createShader(rect);
          },
          child: child,
        );
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
