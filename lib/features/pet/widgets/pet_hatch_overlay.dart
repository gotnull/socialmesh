// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetHatchOverlay — 2-second one-shot animation layered over the pet
// creature at hatch or evolution moments.
//
// Phases (normalized 0..1 over the controller's duration):
//   0.00 – 0.30  shell crack: thin radial fracture lines grow out from
//                the center, brightening the body outline.
//   0.30 – 0.60  burst: an expanding bright ring of seed-derived glyph
//                pips, fading as they radiate outward.
//   0.60 – 1.00  reveal: a soft radial flash that eases out, leaving
//                the resolved creature visible underneath.
//
// The overlay paints absolutely nothing once the controller completes
// and [onComplete] has fired — the parent is expected to remove the
// widget from the tree after that.
//
// Determinism & allocations: all positions derive from the [dnaSeed]
// via simple bit mixing. The painter allocates nothing in its paint()
// hot path beyond a single Paint object per stroke kind.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class PetHatchOverlay extends StatefulWidget {
  /// Full 32-bit seed — drives crack angles and pip positions so the
  /// animation feels specific to this pet.
  final int dnaSeed;

  /// The outer canvas size. Match the [PetCreature] it overlays.
  final double size;

  /// Tint for the glyph pips + flash ring. Typically the pet's branch
  /// primary colour; defaults to the theme accent.
  final Color? accent;

  /// Total duration of the sequence. Default 2s.
  final Duration duration;

  /// Called once the animation completes. The parent should then remove
  /// the overlay from the tree so the controller disposes.
  final VoidCallback onComplete;

  const PetHatchOverlay({
    super.key,
    required this.dnaSeed,
    required this.size,
    required this.onComplete,
    this.accent,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<PetHatchOverlay> createState() => _PetHatchOverlayState();
}

class _PetHatchOverlayState extends State<PetHatchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completedFired) {
        _completedFired = true;
        widget.onComplete();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? context.accentColor;
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => CustomPaint(
            painter: _HatchPainter(
              phase: _controller.value,
              dnaSeed: widget.dnaSeed,
              accent: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  final double phase; // 0..1
  final int dnaSeed;
  final Color accent;

  _HatchPainter({
    required this.phase,
    required this.dnaSeed,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);
    final radius = minSide * 0.28 * 0.65; // match egg body radius

    if (phase <= 0.30) {
      _drawCracks(canvas, center, radius, phase / 0.30);
    } else if (phase <= 0.60) {
      final subPhase = (phase - 0.30) / 0.30;
      _drawCracks(canvas, center, radius, 1.0);
      _drawBurst(canvas, center, minSide, subPhase);
    } else {
      final subPhase = (phase - 0.60) / 0.40;
      _drawFlash(canvas, center, minSide, subPhase);
    }
  }

  /// Thin radial fracture lines radiating from the egg body's perimeter.
  /// Seed-derived angles keep the crack pattern stable per-pet.
  void _drawCracks(Canvas canvas, Offset center, double bodyRadius, double t) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const crackCount = 5;
    final lengthGain = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final outerR = bodyRadius + (bodyRadius * 0.7 * lengthGain);
    for (var i = 0; i < crackCount; i++) {
      final h = dnaSeed ^ (i * 0x9E3779B1);
      final angle = ((h & 0xFFFF) / 0xFFFF) * math.pi * 2;
      final innerR = bodyRadius * 0.4;
      final start = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );
      canvas.drawLine(start, end, paint);
    }
  }

  /// Expanding ring of small seed-derived pips. Fade as they travel
  /// outward; no allocation in the hot loop.
  void _drawBurst(Canvas canvas, Offset center, double minSide, double t) {
    final eased = Curves.easeOutQuart.transform(t.clamp(0.0, 1.0));
    final ringR = minSide * (0.18 + 0.30 * eased);
    final pipAlpha = 1.0 - eased;
    final pipFill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.9 * pipAlpha);
    final pipGlow = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.7 * pipAlpha);
    const pipCount = 12;
    for (var i = 0; i < pipCount; i++) {
      final h = dnaSeed ^ (i * 0x85EBCA77);
      final baseAngle = i * math.pi * 2 / pipCount;
      final wobble = ((h & 0xFF) / 0xFF - 0.5) * 0.3;
      final angle = baseAngle + wobble;
      final pip = Offset(
        center.dx + math.cos(angle) * ringR,
        center.dy + math.sin(angle) * ringR,
      );
      canvas.drawCircle(pip, 2.6, pipFill);
      canvas.drawCircle(pip, 1.2, pipGlow);
    }
  }

  /// Soft radial flash that fades out, revealing the resolved creature.
  void _drawFlash(Canvas canvas, Offset center, double minSide, double t) {
    final eased = Curves.easeInCubic.transform(t.clamp(0.0, 1.0));
    final alpha = 1.0 - eased;
    if (alpha <= 0.01) return;
    final r = minSide * 0.55;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.55 * alpha),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, paint);
  }

  @override
  bool shouldRepaint(covariant _HatchPainter old) =>
      old.phase != phase || old.dnaSeed != dnaSeed || old.accent != accent;
}
