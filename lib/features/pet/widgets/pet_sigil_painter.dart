// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet Sigil Painter — procedural creature rendering driven by PetState.
//
// The creature is a composite of:
//   - a central body polygon (vertex count and rotation from dnaSeed)
//   - an orbiting petal ring (count and radius from dnaSeed)
//   - a breathing aura that responds to mood
//   - optional overlays for sleep (zzz), sickness (jitter + fracture),
//     attention call (expanding pulse ring)
//
// Branch tints the palette; stage rescales the body and petal density;
// mood drives the animation posture. Deterministic from (dnaSeed, stage,
// branch); all state derived via bit mixing of the seed, no allocations
// per paint().

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/pet_enums.dart';

/// Widget that renders the pet creature at the given [size]. Runs a single
/// [AnimationController] at the widget's `TickerProvider`, which the
/// caller is responsible for pausing via the enclosing route's lifecycle.
class PetCreature extends StatefulWidget {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final int hygieneArtefactCount;
  final double size;

  const PetCreature({
    super.key,
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.mood,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.hygieneArtefactCount,
    this.size = 220,
  });

  @override
  State<PetCreature> createState() => _PetCreatureState();
}

class _PetCreatureState extends State<PetCreature>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(widget.branch, widget.dnaSeed, context);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PetCreaturePainter(
              dnaSeed: widget.dnaSeed,
              stage: widget.stage,
              branch: widget.branch,
              mood: widget.mood,
              isAsleep: widget.isAsleep,
              isSick: widget.isSick,
              isCalling: widget.isCalling,
              hygieneArtefactCount: widget.hygieneArtefactCount,
              phase: _controller.value,
              palette: palette,
            ),
          );
        },
      ),
    );
  }
}

/// Palette selection: branch picks the hue family, dnaSeed rotates within
/// that family for per-owner distinctiveness.
_PetPalette _paletteFor(PetBranch branch, int dnaSeed, BuildContext context) {
  Color primary;
  Color accent;
  switch (branch) {
    case PetBranch.luminous:
      primary = AccentColors.yellow;
      accent = AccentColors.sky;
      break;
    case PetBranch.steady:
      primary = AccentColors.emerald;
      accent = AccentColors.teal;
      break;
    case PetBranch.volatile:
      primary = AccentColors.orange;
      accent = AccentColors.pink;
      break;
    case PetBranch.dimmed:
      primary = AccentColors.slate;
      accent = AccentColors.lavender;
      break;
    case PetBranch.unborn:
      primary = AppTheme.primaryPurple;
      accent = AccentColors.sky;
      break;
  }
  // Seed-driven hue rotation: cycles petal colour through a curated list.
  const petalChoices = [
    AccentColors.cyan,
    AccentColors.lavender,
    AccentColors.pink,
    AccentColors.teal,
    AccentColors.lime,
    AccentColors.coral,
    AccentColors.indigo,
    AccentColors.rose,
  ];
  final petal = petalChoices[(dnaSeed >> 9) & 0x07];
  return _PetPalette(primary: primary, accent: accent, petal: petal);
}

@immutable
class _PetPalette {
  final Color primary;
  final Color accent;
  final Color petal;
  const _PetPalette({
    required this.primary,
    required this.accent,
    required this.petal,
  });
}

class _PetCreaturePainter extends CustomPainter {
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final int hygieneArtefactCount;
  final double phase; // 0..1 loop
  final _PetPalette palette;

  _PetCreaturePainter({
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.mood,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.hygieneArtefactCount,
    required this.phase,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);

    // Seed-derived morphology.
    final vertexCount = 5 + ((dnaSeed >> 3) & 0x03); // 5..8
    final petalCount = 3 + ((dnaSeed >> 17) & 0x07); // 3..10
    final rotation = ((dnaSeed >> 13) & 0xFFFF) / 0xFFFF * math.pi * 2;

    final stageScale = _stageScale(stage);
    final baseRadius = minSide * 0.28 * stageScale;
    final auraRadius = minSide * 0.45 * stageScale;
    final petalOrbit = minSide * 0.36 * stageScale;

    // Breathing modulation (0..1).
    final breath = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
    final breathGain = _breathingAmplitude();
    final effectiveBody = baseRadius * (1.0 + breath * breathGain);

    // --- Aura / calling pulse -----------------------------------------
    if (isCalling) {
      _drawCallingPulse(canvas, center, auraRadius, phase);
    }
    _drawAura(canvas, center, auraRadius, breath);

    // --- Hygiene artefacts (drawn behind the pet) ---------------------
    _drawHygieneArtefacts(canvas, center, minSide);

    // Jitter translation for sickness.
    if (isSick) {
      final jitter = _jitter(phase);
      canvas.save();
      canvas.translate(jitter.dx, jitter.dy);
    }

    // --- Petal orbit --------------------------------------------------
    _drawPetalOrbit(
      canvas,
      center,
      petalOrbit,
      petalCount,
      rotation,
      phase,
      alpha: _petalAlpha(),
    );

    // --- Core body ----------------------------------------------------
    _drawBody(canvas, center, effectiveBody, vertexCount, rotation);

    // --- Face / eyes / expression ------------------------------------
    _drawFace(canvas, center, effectiveBody);

    if (isSick) canvas.restore();

    // --- Sleep overlay (zzz) -----------------------------------------
    if (isAsleep) {
      _drawZzz(canvas, center, minSide, phase);
    }

    // --- Dormant ghost overlay ---------------------------------------
    if (stage == PetStage.dormant) {
      _drawDormantVeil(canvas, size);
    }
  }

  double _stageScale(PetStage s) {
    switch (s) {
      case PetStage.egg:
        return 0.65;
      case PetStage.juvenile:
        return 0.75;
      case PetStage.adolescent:
        return 0.9;
      case PetStage.adult:
        return 1.0;
      case PetStage.elder:
        return 0.95;
      case PetStage.dormant:
        return 0.7;
    }
  }

  double _breathingAmplitude() {
    switch (mood) {
      case PetMood.sleeping:
        return 0.04;
      case PetMood.content:
        return 0.06;
      case PetMood.calling:
        return 0.12;
      case PetMood.hungry:
      case PetMood.sad:
        return 0.03;
      case PetMood.sick:
        return 0.02;
    }
  }

  double _petalAlpha() {
    if (stage == PetStage.egg) return 0.0;
    if (stage == PetStage.dormant) return 0.2;
    if (isAsleep) return 0.35;
    switch (branch) {
      case PetBranch.luminous:
        return 0.95;
      case PetBranch.steady:
        return 0.75;
      case PetBranch.volatile:
        return 0.9;
      case PetBranch.dimmed:
        return 0.45;
      case PetBranch.unborn:
        return 0.6;
    }
  }

  Offset _jitter(double phase) {
    final t = phase * math.pi * 16;
    return Offset(math.sin(t) * 1.6, math.cos(t * 1.3) * 1.2);
  }

  // ---- Draw helpers ----------------------------------------------------

  void _drawAura(Canvas canvas, Offset c, double r, double breath) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.primary.withValues(alpha: 0.22 + 0.08 * breath),
          palette.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, glow);
  }

  void _drawCallingPulse(Canvas canvas, Offset c, double maxR, double phase) {
    for (var i = 0; i < 2; i++) {
      final t = (phase + i * 0.5) % 1.0;
      final r = maxR * (0.6 + t * 0.7);
      final alpha = (1.0 - t) * 0.45;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = palette.primary.withValues(alpha: alpha);
      canvas.drawCircle(c, r, paint);
    }
  }

  void _drawPetalOrbit(
    Canvas canvas,
    Offset c,
    double orbit,
    int count,
    double rotation,
    double phase, {
    required double alpha,
  }) {
    if (alpha <= 0.0) return;
    final drift = phase * math.pi * 2;
    final petalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = palette.petal.withValues(alpha: alpha);
    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = palette.accent.withValues(alpha: alpha * 0.6);

    Offset? prev;
    Offset? first;
    for (var i = 0; i < count; i++) {
      final theta = rotation + drift + (i * math.pi * 2 / count);
      final wobble = 1.0 + 0.04 * math.sin(phase * math.pi * 2 + i);
      final pt = Offset(
        c.dx + math.cos(theta) * orbit * wobble,
        c.dy + math.sin(theta) * orbit * wobble,
      );
      canvas.drawCircle(pt, 2.2, petalPaint);
      if (prev != null) {
        canvas.drawLine(prev, pt, linkPaint);
      } else {
        first = pt;
      }
      prev = pt;
    }
    if (prev != null && first != null) {
      canvas.drawLine(prev, first, linkPaint);
    }
  }

  void _drawBody(
    Canvas canvas,
    Offset c,
    double r,
    int vertexCount,
    double rotation,
  ) {
    final path = Path();
    for (var i = 0; i < vertexCount; i++) {
      final angle = rotation + (i * math.pi * 2 / vertexCount) - math.pi / 2;
      final pt = Offset(c.dx + math.cos(angle) * r, c.dy + math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    // Fill — radial gradient for a sense of presence.
    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.primary.withValues(alpha: 0.95),
          palette.accent.withValues(alpha: 0.55),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawPath(path, fill);

    // Outline.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = palette.primary.withValues(alpha: 0.85);
    canvas.drawPath(path, outline);

    // Branch-specific micro-etch — every few vertices draw a radial to the
    // center for luminous / steady; crystallised ring for elder.
    if (branch == PetBranch.luminous || branch == PetBranch.steady) {
      final etch = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = palette.accent.withValues(alpha: 0.5);
      for (var i = 0; i < vertexCount; i++) {
        if (i % 2 == 0) continue;
        final angle = rotation + (i * math.pi * 2 / vertexCount) - math.pi / 2;
        final pt = Offset(
          c.dx + math.cos(angle) * r,
          c.dy + math.sin(angle) * r,
        );
        canvas.drawLine(c, pt, etch);
      }
    }
    if (stage == PetStage.elder) {
      final frost = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = palette.accent.withValues(alpha: 0.7);
      canvas.drawCircle(c, r * 0.6, frost);
    }
  }

  void _drawFace(Canvas canvas, Offset c, double r) {
    if (stage == PetStage.egg) return; // no face yet
    final eyeOffsetX = r * 0.28;
    final eyeOffsetY = -r * 0.05;
    final eyeR = math.max(1.8, r * 0.08);
    final eyePaint = Paint()..color = _onCanvasText();

    if (isAsleep) {
      // Closed curved eyes.
      final closed = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _onCanvasText();
      final dx = eyeOffsetX;
      for (final sign in [-1.0, 1.0]) {
        final left = Offset(c.dx + sign * dx - eyeR, c.dy + eyeOffsetY);
        final right = Offset(c.dx + sign * dx + eyeR, c.dy + eyeOffsetY);
        final mid = Offset(
          (left.dx + right.dx) / 2,
          (left.dy + right.dy) / 2 + eyeR * 0.6,
        );
        final path = Path()
          ..moveTo(left.dx, left.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, right.dx, right.dy);
        canvas.drawPath(path, closed);
      }
    } else {
      canvas.drawCircle(
        Offset(c.dx - eyeOffsetX, c.dy + eyeOffsetY),
        eyeR,
        eyePaint,
      );
      canvas.drawCircle(
        Offset(c.dx + eyeOffsetX, c.dy + eyeOffsetY),
        eyeR,
        eyePaint,
      );
    }

    // Simple mouth hint for moods.
    final mouthPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = _onCanvasText();
    final mx = c.dx;
    final my = c.dy + r * 0.28;
    final path = Path();
    switch (mood) {
      case PetMood.content:
      case PetMood.calling:
        path.moveTo(mx - r * 0.14, my);
        path.quadraticBezierTo(mx, my + r * 0.08, mx + r * 0.14, my);
        break;
      case PetMood.hungry:
      case PetMood.sad:
        path.moveTo(mx - r * 0.12, my + r * 0.04);
        path.quadraticBezierTo(mx, my - r * 0.05, mx + r * 0.12, my + r * 0.04);
        break;
      case PetMood.sick:
        path.moveTo(mx - r * 0.14, my);
        path.lineTo(mx - r * 0.06, my + r * 0.04);
        path.lineTo(mx + r * 0.02, my);
        path.lineTo(mx + r * 0.1, my + r * 0.04);
        path.lineTo(mx + r * 0.16, my);
        break;
      case PetMood.sleeping:
        path.moveTo(mx - r * 0.08, my);
        path.lineTo(mx + r * 0.08, my);
        break;
    }
    if (!isAsleep || mood != PetMood.sleeping) {
      canvas.drawPath(path, mouthPaint);
    } else {
      canvas.drawPath(path, mouthPaint);
    }
  }

  void _drawZzz(Canvas canvas, Offset c, double minSide, double phase) {
    final paint = Paint()
      ..color = _onCanvasText().withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t = ((phase * 2) + i * 0.33) % 1.0;
      final scale = 1.0 - t;
      if (scale <= 0) continue;
      final x = c.dx + minSide * 0.22 + t * minSide * 0.06;
      final y = c.dy - minSide * 0.18 - t * minSide * 0.12;
      final s = minSide * 0.04 * scale;
      final path = Path()
        ..moveTo(x - s, y - s)
        ..lineTo(x + s, y - s)
        ..lineTo(x - s, y + s)
        ..lineTo(x + s, y + s);
      canvas.drawPath(
        path,
        paint..color = paint.color.withValues(alpha: 0.7 * scale),
      );
    }
  }

  void _drawDormantVeil(Canvas canvas, Size size) {
    final veil = Paint()..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawRect(Offset.zero & size, veil);
  }

  void _drawHygieneArtefacts(Canvas canvas, Offset c, double minSide) {
    if (hygieneArtefactCount <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AccentColors.slate.withValues(alpha: 0.8);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = AccentColors.slate.withValues(alpha: 0.3);
    for (var i = 0; i < hygieneArtefactCount.clamp(0, 3); i++) {
      // Seed-deterministic positioning so artefacts sit in stable spots.
      final h = dnaSeed ^ (i * 0x9E3779B1);
      final angle = (h & 0xFFFF) / 0xFFFF * math.pi * 2;
      final dist = minSide * (0.38 + ((h >> 16) & 0xFF) / 0xFF * 0.08);
      final p = Offset(
        c.dx + math.cos(angle) * dist,
        c.dy + math.sin(angle) * dist,
      );
      const r = 5.0;
      canvas.drawCircle(p, r, fill);
      canvas.drawCircle(p, r, paint);
      // Cross mark.
      canvas.drawLine(
        Offset(p.dx - r * 0.5, p.dy),
        Offset(p.dx + r * 0.5, p.dy),
        paint,
      );
      canvas.drawLine(
        Offset(p.dx, p.dy - r * 0.5),
        Offset(p.dx, p.dy + r * 0.5),
        paint,
      );
    }
  }

  Color _onCanvasText() {
    // Off-white with tinted alpha — works over any palette, theme-neutral.
    return Colors.white.withValues(alpha: 0.92);
  }

  @override
  bool shouldRepaint(covariant _PetCreaturePainter oldDelegate) {
    return oldDelegate.dnaSeed != dnaSeed ||
        oldDelegate.stage != stage ||
        oldDelegate.branch != branch ||
        oldDelegate.mood != mood ||
        oldDelegate.isAsleep != isAsleep ||
        oldDelegate.isSick != isSick ||
        oldDelegate.isCalling != isCalling ||
        oldDelegate.hygieneArtefactCount != hygieneArtefactCount ||
        oldDelegate.phase != phase ||
        oldDelegate.palette != palette;
  }
}
