// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Self-drawing "hello mesh" handwriting shown in the sketch onboarding pad
// while it is empty. The cursive path writes itself in with a gradient stroke,
// holds, fades, and loops - an Apple-style handwriting reveal that invites the
// user to draw their own stroke over it.
//
// The letterforms are hand-authored cubic beziers in a fixed design box and
// scaled to fit the pad. Honours reduced-motion by showing the finished word.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  // One full cycle: write (0..0.62), hold (0.62..0.86), fade (0.86..1.0).
  static const Duration _period = Duration(milliseconds: 5200);

  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    // Safety net: ensure the loop is running after first layout even if a
    // dependency change races the initial build.
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _reduceMotion ? 1.0 : _controller.value;
          // Draw-on: writes over the first 30% of the cycle, then holds the
          // full word for the long middle so a glance almost always catches
          // the complete handwriting. Reduced motion shows it fully drawn.
          final double drawT;
          if (_reduceMotion) {
            drawT = 1.0;
          } else if (t < 0.30) {
            drawT = t / 0.30;
          } else {
            drawT = 1.0;
          }
          // Opacity never drops to invisible — it breathes between a soft
          // floor and full so the word is always present, just lit gently at
          // the loop seam.
          final double opacity;
          if (_reduceMotion) {
            opacity = 0.8;
          } else if (t < 0.05) {
            opacity = 0.55 + (t / 0.05) * 0.45;
          } else if (t > 0.93) {
            opacity = 1.0 - ((t - 0.93) / 0.07) * 0.45;
          } else {
            opacity = 1.0;
          }
          return Opacity(
            opacity: opacity,
            child: CustomPaint(
              painter: _HandwritingPainter(
                progress: _reduceMotion ? 1.0 : drawT,
                accent: widget.accent,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _HandwritingPainter extends CustomPainter {
  _HandwritingPainter({required this.progress, required this.accent});

  /// 0..1 fraction of the word that has been written.
  final double progress;
  final Color accent;

  // Design box the letterforms are authored in.
  static const double _designW = 292;
  static const double _designH = 104;

  @override
  void paint(Canvas canvas, Size size) {
    final word = _buildWord();

    // Fit the design box into the available size with a small margin,
    // preserving aspect ratio and centring.
    const margin = 16.0;
    final scaleW = (size.width - margin * 2) / _designW;
    final scaleH = (size.height - margin * 2) / _designH;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    final drawW = _designW * scale;
    final drawH = _designH * scale;
    final dx = (size.width - drawW) / 2;
    final dy = (size.height - drawH) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    // Progressive reveal across all contours.
    final metrics = word.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * progress;
    final revealed = Path();
    for (final m in metrics) {
      if (remaining <= 0) break;
      final take = m.length < remaining ? m.length : remaining;
      revealed.addPath(m.extractPath(0, take), Offset.zero);
      remaining -= m.length;
    }

    final rect = Rect.fromLTWH(0, 0, _designW, _designH);

    // Faint full-word guide ("ghost"). Always drawn so the handwriting is
    // visible even at the very start of the reveal or if the ticker is slow
    // to spin up - the bright gradient ink then writes over it.
    final ghost = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.22);
    canvas.drawPath(word, ghost);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        rect.centerLeft,
        rect.centerRight,
        AccentColors.gradientFor(accent),
      );

    // Soft glow underlay for the premium, lit-ink feel.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(revealed, glow);
    canvas.drawPath(revealed, stroke);
    canvas.restore();
  }

  // Cursive lowercase "hello mesh". Two contours: "hello" and "mesh".
  Path _buildWord() {
    final p = Path();

    // ---- hello ----
    p.moveTo(8, 66);
    // h: ascender loop + stem + arch
    p.cubicTo(10, 30, 12, 14, 20, 14);
    p.cubicTo(27, 14, 25, 42, 22, 66);
    p.cubicTo(22, 46, 31, 38, 39, 43);
    p.cubicTo(45, 46, 43, 58, 43, 66);
    // e
    p.cubicTo(49, 67, 51, 52, 59, 50);
    p.cubicTo(67, 48, 65, 38, 57, 40);
    p.cubicTo(49, 42, 49, 61, 59, 63);
    p.cubicTo(65, 64, 69, 59, 71, 55);
    // l
    p.cubicTo(75, 49, 77, 20, 81, 15);
    p.cubicTo(87, 12, 85, 46, 83, 66);
    // l
    p.cubicTo(83, 67, 85, 67, 87, 64);
    p.cubicTo(91, 49, 95, 20, 99, 15);
    p.cubicTo(105, 12, 103, 46, 101, 66);
    // o
    p.cubicTo(101, 67, 103, 67, 105, 64);
    p.cubicTo(111, 53, 121, 47, 125, 53);
    p.cubicTo(129, 59, 123, 67, 115, 65);
    p.cubicTo(107, 63, 109, 53, 117, 51);
    p.cubicTo(123, 50, 127, 55, 130, 60);

    // ---- mesh ----
    p.moveTo(152, 66);
    // m: three humps
    p.cubicTo(152, 46, 158, 40, 162, 47);
    p.cubicTo(164, 51, 164, 59, 164, 66);
    p.cubicTo(164, 48, 170, 40, 176, 47);
    p.cubicTo(178, 51, 178, 59, 178, 66);
    p.cubicTo(178, 48, 184, 40, 190, 47);
    p.cubicTo(192, 51, 192, 59, 192, 66);
    // e
    p.cubicTo(198, 67, 200, 52, 208, 50);
    p.cubicTo(216, 48, 214, 38, 206, 40);
    p.cubicTo(198, 42, 198, 61, 208, 63);
    p.cubicTo(214, 64, 218, 59, 220, 55);
    // s
    p.cubicTo(225, 50, 233, 45, 235, 51);
    p.cubicTo(237, 56, 228, 55, 226, 52);
    p.cubicTo(222, 49, 224, 63, 233, 63);
    p.cubicTo(239, 63, 241, 59, 241, 57);
    // h: ascender stem + arch + exit flourish
    p.cubicTo(245, 50, 249, 20, 253, 15);
    p.cubicTo(259, 12, 257, 46, 255, 66);
    p.cubicTo(255, 48, 263, 40, 271, 46);
    p.cubicTo(275, 49, 273, 58, 273, 66);
    p.cubicTo(276, 70, 282, 68, 288, 60);

    return p;
  }

  @override
  bool shouldRepaint(_HandwritingPainter old) =>
      old.progress != progress || old.accent != accent;
}
