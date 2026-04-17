// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart';

/// Animated tagline that cycles through different phrases with fade+slide
class AnimatedTagline extends StatefulWidget {
  final List<String> taglines;
  final TextStyle? textStyle;
  final TextAlign? textAlign;

  const AnimatedTagline({
    super.key,
    required this.taglines,
    this.textStyle,
    this.textAlign,
  });

  /// Duration each tagline is displayed
  static const displayDuration = Duration(seconds: 3);

  /// Duration of the fade/slide animation
  static const animationDuration = Duration(milliseconds: 400);

  @override
  State<AnimatedTagline> createState() => _AnimatedTaglineState();
}

class _AnimatedTaglineState extends State<AnimatedTagline>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentIndex = 0;
  bool _reduceMotion = false;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimatedTagline.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Start with the first tagline visible
    _controller.forward();

    // Start cycling
    _startCycling();
  }

  void _startCycling() {
    _cycleTimer?.cancel();
    if (_reduceMotion) return;
    _cycleTimer = Timer(AnimatedTagline.displayDuration, () {
      if (!mounted) return;
      if (_reduceMotion) return;
      _cycleToNext();
    });
  }

  Future<void> _cycleToNext() async {
    if (!mounted || _reduceMotion) return;

    // Fade out
    await _controller.reverse();
    if (!mounted || _reduceMotion) return;

    // Change text
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.taglines.length;
    });

    // Fade in
    await _controller.forward();
    if (!mounted || _reduceMotion) return;

    // Schedule next cycle
    _startCycling();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _controller.value = 1.0;
      _currentIndex = 0;
      return;
    }
    _controller.value = 1.0;
    _startCycling();
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.textStyle ??
        Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: context.textSecondary);
    if (_reduceMotion) {
      return Text(
        widget.taglines.first,
        style: style,
        textAlign: widget.textAlign,
      );
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Text(
          widget.taglines[_currentIndex],
          style: style,
          textAlign: widget.textAlign,
        ),
      ),
    );
  }
}
