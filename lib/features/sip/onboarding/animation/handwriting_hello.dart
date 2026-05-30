// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Self-writing "hello mesh" shown in the sketch onboarding pad while it is
// empty. Renders the Caveat cursive typeface and reveals it left-to-right with
// a soft gradient edge, like a hand writing the word, then holds and gently
// loops. Invites the user to draw their own stroke over it.
//
// Honours reduced-motion by showing the finished word.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';

/// Animated cursive "hello mesh" reveal.
class HandwritingHello extends StatefulWidget {
  const HandwritingHello({super.key, required this.accent, this.active = true});

  final Color accent;
  final bool active;

  @override
  State<HandwritingHello> createState() => _HandwritingHelloState();
}

class _HandwritingHelloState extends State<HandwritingHello>
    with SingleTickerProviderStateMixin {
  // write (0..0.5) → hold (0.5..0.9) → ease for the loop seam (0.9..1.0).
  static const Duration _period = Duration(milliseconds: 5000);

  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMotion();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncMotion();
  }

  @override
  void didUpdateWidget(HandwritingHello old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _syncMotion();
  }

  void _syncMotion() {
    if (widget.active && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
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
    final gradient = AccentColors.gradientFor(widget.accent);
    final textStyle = GoogleFonts.caveat(
      fontSize: 64,
      fontWeight: FontWeight.w600,
      height: 1.0,
      // Colour is supplied by the gradient ShaderMask; white keeps the glyph
      // fully opaque so the mask shows through cleanly.
      color: Colors.white,
    );

    return RepaintBoundary(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _reduceMotion ? 1.0 : _controller.value;
            // Reveal fraction: writes across the first half, then holds full.
            final reveal = _reduceMotion ? 1.0 : (t / 0.5).clamp(0.0, 1.0);
            return ShaderMask(
              shaderCallback: (bounds) {
                // Gradient ink across the whole word.
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: gradient,
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: _WriteOnReveal(
                reveal: reveal,
                child: Text(
                  'hello mesh',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Clips its child to a left-to-right fraction with a soft feathered edge so
/// the word appears to be written in rather than hard-wiped.
class _WriteOnReveal extends StatelessWidget {
  const _WriteOnReveal({required this.reveal, required this.child});

  /// 0..1 fraction of the width revealed from the left.
  final double reveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reveal >= 1.0) return child;
    return ShaderMask(
      shaderCallback: (bounds) {
        // Opaque up to the reveal edge, with a short feather, then transparent.
        final edge = reveal.clamp(0.0, 1.0);
        const feather = 0.06;
        final start = (edge - feather).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, start, edge.clamp(0.0001, 1.0)],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
