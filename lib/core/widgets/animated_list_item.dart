import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// A wrapper that animates list items with staggered fade and slide animations
class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;
  final Curve curve;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate stagger delay based on index (cap at 10 items for performance)
    final delay = Duration(
      milliseconds: (index.clamp(0, 10) * staggerDelay.inMilliseconds),
    );

    return _StaggeredFadeSlide(
      delay: delay,
      duration: duration,
      curve: curve,
      child: child,
    );
  }
}

class _StaggeredFadeSlide extends StatefulWidget {
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const _StaggeredFadeSlide({
    required this.delay,
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  State<_StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<_StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
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

/// Animated container that expands to a detail screen using shared axis transition
class AnimatedOpenContainer extends StatelessWidget {
  final Widget closedBuilder;
  final Widget Function(BuildContext, VoidCallback) openBuilder;
  final Color? closedColor;
  final ShapeBorder? closedShape;
  final double closedElevation;
  final Duration transitionDuration;
  final ContainerTransitionType transitionType;

  const AnimatedOpenContainer({
    super.key,
    required this.closedBuilder,
    required this.openBuilder,
    this.closedColor,
    this.closedShape,
    this.closedElevation = 0,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.transitionType = ContainerTransitionType.fadeThrough,
  });

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      transitionDuration: transitionDuration,
      transitionType: transitionType,
      closedColor: closedColor ?? Colors.transparent,
      closedElevation: closedElevation,
      closedShape:
          closedShape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      openColor: Colors.transparent,
      openElevation: 0,
      closedBuilder: (context, openContainer) {
        return GestureDetector(onTap: openContainer, child: closedBuilder);
      },
      openBuilder: openBuilder,
    );
  }
}

/// Page route with shared axis transition
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SharedAxisTransitionType transitionType;

  SharedAxisPageRoute({
    required this.page,
    this.transitionType = SharedAxisTransitionType.horizontal,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return SharedAxisTransition(
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             transitionType: transitionType,
             child: child,
           );
         },
         transitionDuration: const Duration(milliseconds: 300),
         reverseTransitionDuration: const Duration(milliseconds: 250),
       );
}

/// Page route with fade through transition
class FadeThroughPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeThroughPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      );
}
