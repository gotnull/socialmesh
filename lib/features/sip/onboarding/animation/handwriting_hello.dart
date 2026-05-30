// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Self-writing "hello mesh" shown in the sketch onboarding pad while it is
// empty. Renders the Caveat cursive typeface and reveals it left-to-right with
// a soft feathered edge, like a hand writing the word, then holds and gently
// loops.
//
// The Caveat font is fetched on first use via google_fonts. To avoid the
// fallback-font flash + reflow ("janky thing before it appears"), nothing is
// painted until the real font has loaded; it then fades in smoothly.
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
  // write (0..0.55) → hold → ease at the loop seam.
  static const Duration _period = Duration(milliseconds: 5400);

  late final AnimationController _controller;
  bool _reduceMotion = false;
  bool _fontReady = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    _loadFont();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMotion();
    });
  }

  // Resolve the Caveat font before painting so we never flash a fallback.
  Future<void> _loadFont() async {
    // Touch the style so google_fonts schedules the fetch, then await any
    // pending font loads. On cached runs this completes effectively instantly.
    GoogleFonts.caveat();
    try {
      await GoogleFonts.pendingFonts([GoogleFonts.caveat()]);
    } catch (_) {
      // Network unavailable (offline-first app): fall back to whatever
      // google_fonts resolves to rather than hiding the word forever.
    }
    if (!mounted) return;
    setState(() => _fontReady = true);
    _controller.forward(from: 0);
    _syncMotion();
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
    if (widget.active && !_reduceMotion && _fontReady) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (!widget.active) {
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
      fontSize: 66,
      fontWeight: FontWeight.w600,
      height: 1.0,
      color: Colors.white,
      letterSpacing: 0.5,
    );

    // Until the font is resolved, paint nothing - this removes the
    // fallback-font flash the user saw before the handwriting appeared.
    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: _fontReady ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _reduceMotion ? 1.0 : _controller.value;
              // Eased left-to-right write across the first 55% of the loop.
              final raw = (t / 0.55).clamp(0.0, 1.0);
              final reveal = _reduceMotion
                  ? 1.0
                  : Curves.easeInOutCubic.transform(raw);
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: gradient,
                ).createShader(bounds),
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
      ),
    );
  }
}

/// Clips its child to a left-to-right fraction with a soft feathered edge so
/// the word appears to flow in under a moving pen rather than hard-wiping.
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
        final edge = reveal.clamp(0.0, 1.0);
        // Wide, soft feather so letters fade up at the writing edge instead of
        // popping. The fully-opaque region trails well behind the edge.
        const feather = 0.16;
        final solid = (edge - feather).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.white,
            Colors.white,
            Color(0x66FFFFFF),
            Colors.transparent,
          ],
          stops: [
            0.0,
            solid,
            edge.clamp(0.0001, 1.0),
            (edge + feather * 0.5).clamp(0.0001, 1.0),
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
