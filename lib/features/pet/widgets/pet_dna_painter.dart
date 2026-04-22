// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetDnaPainter — alien genome-artifact renderer for the DNA Viewer.
//
// Design intent (see docs/pet/NODE_PET_SYSTEM.md §10.2):
//   - Sigil spine / gene relic / ritual artifact, NOT a chart.
//   - Thick segmented strands with seed-derived width irregularity.
//   - Glyph bonds (not plain rungs) connecting strand pairs via the
//     central spine.
//   - Core is suspended inside the structure via radiating support
//     arms — structurally integrated, not pasted on.
//   - Restrained atmosphere — radial haze, containment pillars,
//     dark-chamber ambience. Tables support, not compete.
//   - 2.5D only; no real 3D; deterministic under (dnaSeed, stage,
//     branch).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet_enums.dart';
import 'pet_dna_geometry.dart';
import 'pet_render_model.dart' show PetRenderPalette;

class PetDnaPainter extends CustomPainter {
  final PetDnaGeometry geometry;
  final PetRenderPalette palette;

  /// Continuous animation phase [0, 1). Wraps.
  final double phase;

  /// Optional user-scrub offset in radians.
  final double userSpin;

  const PetDnaPainter({
    required this.geometry,
    required this.palette,
    required this.phase,
    this.userSpin = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);
    final radius = minSide * geometry.radiusFactor;
    final halfSpan = size.height * geometry.verticalSpanFactor * 0.5;
    final phaseRot = phase * math.pi * 2 + userSpin;

    _drawChamber(canvas, size, center, minSide, halfSpan);
    _drawContainmentPillars(canvas, center, radius, halfSpan);
    _drawSpine(canvas, center, halfSpan);

    // Back pass — strands + bonds on the far side.
    _drawStrandsPass(
      canvas,
      center,
      radius,
      halfSpan,
      phaseRot,
      isBackPass: true,
    );
    _drawBondsPass(
      canvas,
      center,
      radius,
      halfSpan,
      phaseRot,
      isBackPass: true,
    );

    _drawCoreSupportArms(canvas, center, radius, halfSpan, phaseRot);
    _drawCoreGlyph(canvas, center, minSide);

    // Front pass — strands + bonds on the near side, crisp.
    _drawBondsPass(
      canvas,
      center,
      radius,
      halfSpan,
      phaseRot,
      isBackPass: false,
    );
    _drawStrandsPass(
      canvas,
      center,
      radius,
      halfSpan,
      phaseRot,
      isBackPass: false,
    );

    _drawMutationNodes(canvas, center, radius, halfSpan, phaseRot);
    _drawRuneMarkers(canvas, center, radius, halfSpan);
  }

  // ------------------------------------------------------------------
  // Atmosphere: chamber haze. A soft radial wash in the branch palette
  // that gives the structure a contained "cradle-space" feel, plus a
  // subtle darkening at the edges.
  void _drawChamber(
    Canvas canvas,
    Size size,
    Offset center,
    double minSide,
    double halfSpan,
  ) {
    // Branch-tinted glow, warmest near the core.
    final hazeRect = Rect.fromCircle(center: center, radius: minSide * 0.55);
    final hazePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.primary.withValues(alpha: 0.18),
          palette.primary.withValues(alpha: 0.04),
          palette.primary.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(hazeRect);
    canvas.drawRect(Offset.zero & size, hazePaint);

    // Chamber floor — soft darkening at bottom for depth weight.
    final floorRect = Rect.fromLTRB(
      0,
      center.dy + halfSpan * 0.6,
      size.width,
      size.height,
    );
    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.25),
        ],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, floorPaint);
  }

  // ------------------------------------------------------------------
  // Containment pillars — two faint vertical lines with gradient fade
  // flanking the structure. Reads as "this is held inside something".
  void _drawContainmentPillars(
    Canvas canvas,
    Offset center,
    double radius,
    double halfSpan,
  ) {
    final pillarX = radius * 1.35;
    for (final side in const [-1.0, 1.0]) {
      final x = center.dx + side * pillarX;
      final rect = Rect.fromLTRB(
        x - 0.5,
        center.dy - halfSpan,
        x + 0.5,
        center.dy + halfSpan,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  // ------------------------------------------------------------------
  // Central spine — subtle, vertical axis. Slightly brighter at core
  // height to imply the core sits ON it.
  void _drawSpine(Canvas canvas, Offset center, double halfSpan) {
    final rect = Rect.fromLTRB(
      center.dx - 0.5,
      center.dy - halfSpan,
      center.dx + 0.5,
      center.dy + halfSpan,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  // ------------------------------------------------------------------
  // Strand rails — trapezoidal segments, width-jittered from the seed.
  // Back pass uses dimmer fill + muted edge; front pass uses bright
  // fill + sharp outline. This is the primary depth cue.
  void _drawStrandsPass(
    Canvas canvas,
    Offset center,
    double radius,
    double halfSpan,
    double phaseRot, {
    required bool isBackPass,
  }) {
    final anchors = geometry.anchors;
    final strandCount = geometry.strandCount;
    final seed = geometry.dnaSeed;

    // Per-segment width perturbation — seed-stable, gives organic
    // irregularity. Width band: 0.75× .. 1.25× of the base.
    final baseWidth = (radius * 0.065).clamp(5.0, 12.0);

    for (var s = 0; s < strandCount; s++) {
      final strandPhase = s * (math.pi * 2 / strandCount);

      // Pre-compute endpoint positions + depth per anchor for this strand.
      final pts = List<Offset>.generate(anchors.length, (i) {
        final angle = anchors[i].angleA + strandPhase + phaseRot;
        return Offset(
          center.dx + math.cos(angle) * radius,
          center.dy - halfSpan + anchors[i].t * halfSpan * 2,
        );
      });
      final sins = List<double>.generate(anchors.length, (i) {
        return math.sin(anchors[i].angleA + strandPhase + phaseRot);
      });

      for (var i = 0; i < anchors.length - 1; i++) {
        final avgSin = (sins[i] + sins[i + 1]) * 0.5;
        final segmentIsFront = avgSin >= 0;
        final drawInThisPass = isBackPass ? !segmentIsFront : segmentIsFront;
        if (!drawInThisPass) continue;

        // Seed-jittered width — per (strand, segment).
        final jitter = ((seed >> ((i + s * 3) & 31)) & 0x0F) / 15.0;
        final widthA = baseWidth * (0.80 + 0.40 * jitter);
        final jitterB = ((seed >> ((i + 1 + s * 3) & 31)) & 0x0F) / 15.0;
        final widthB = baseWidth * (0.80 + 0.40 * jitterB);

        final path = _buildSegmentPath(pts[i], pts[i + 1], widthA, widthB);

        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = isBackPass
              ? palette.primary.withValues(alpha: 0.35)
              : palette.primary.withValues(alpha: 0.92);
        canvas.drawPath(path, fillPaint);

        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = isBackPass ? 0.8 : 1.3
          ..color = isBackPass
              ? palette.accent.withValues(alpha: 0.28)
              : palette.accent.withValues(alpha: 0.85);
        canvas.drawPath(path, edgePaint);
      }
    }
  }

  /// Build a trapezoidal ribbon from A to B with per-end widths.
  /// Width is applied perpendicular to the segment axis.
  Path _buildSegmentPath(Offset a, Offset b, double widthA, double widthB) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.0001) return Path();
    final nx = -dy / len;
    final ny = dx / len;
    final aL = Offset(a.dx + nx * widthA / 2, a.dy + ny * widthA / 2);
    final aR = Offset(a.dx - nx * widthA / 2, a.dy - ny * widthA / 2);
    final bR = Offset(b.dx - nx * widthB / 2, b.dy - ny * widthB / 2);
    final bL = Offset(b.dx + nx * widthB / 2, b.dy + ny * widthB / 2);
    return Path()
      ..moveTo(aL.dx, aL.dy)
      ..lineTo(aR.dx, aR.dy)
      ..lineTo(bR.dx, bR.dy)
      ..lineTo(bL.dx, bL.dy)
      ..close();
  }

  // ------------------------------------------------------------------
  // Glyph bonds — where a plain rung would be, we instead draw an
  // angled ligament arm on each side plus a central diamond/rune glyph
  // at the spine. Splits at the spine so each half picks its pass.
  //
  // Structure:
  //   strand-A end ─◇ (glyph arm) ─╮
  //                                ◆ (central rune at spine)
  //   strand-B end ─◇ (glyph arm) ─╯
  //
  // Only 2-strand helices get bonds (1- and 3-strand don't pair cleanly).
  void _drawBondsPass(
    Canvas canvas,
    Offset center,
    double radius,
    double halfSpan,
    double phaseRot, {
    required bool isBackPass,
  }) {
    if (geometry.strandCount != 2) return;
    final anchors = geometry.anchors;

    final armPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = isBackPass ? 1.2 : 1.8
      ..color = Colors.white.withValues(alpha: isBackPass ? 0.28 : 0.68);
    final glyphFill = Paint()
      ..style = PaintingStyle.fill
      ..color = palette.accent.withValues(alpha: isBackPass ? 0.35 : 0.95);
    final glyphStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: isBackPass ? 0.25 : 0.70);

    final centralGlyphFill = Paint()
      ..style = PaintingStyle.fill
      ..color = palette.primary.withValues(alpha: isBackPass ? 0.35 : 0.95);
    final centralGlyphStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = palette.accent.withValues(alpha: isBackPass ? 0.30 : 0.90);

    for (var i = 0; i < anchors.length; i++) {
      if (!anchors[i].hasRung) continue;
      final a = anchors[i];

      final angleA = a.angleA + phaseRot;
      final angleB = angleA + math.pi;
      final xA = center.dx + math.cos(angleA) * radius;
      final xB = center.dx + math.cos(angleB) * radius;
      final y = center.dy - halfSpan + a.t * halfSpan * 2;
      final frontA = math.sin(angleA) >= 0;
      final frontB = math.sin(angleB) >= 0;

      // Central rune — small diamond at the spine. We draw ONE of its
      // halves per pass so it reads as threaded.
      final runeSize = radius * 0.06;
      final centralDiamond = Path()
        ..moveTo(center.dx, y - runeSize)
        ..lineTo(center.dx + runeSize * 0.55, y)
        ..lineTo(center.dx, y + runeSize)
        ..lineTo(center.dx - runeSize * 0.55, y)
        ..close();
      canvas.drawPath(centralDiamond, centralGlyphFill);
      canvas.drawPath(centralDiamond, centralGlyphStroke);

      // Arm A — angled ligament from strand endpoint to central rune
      // with a mid-kink for machine-organic feel.
      void drawArm(double xEnd, Offset endPt, double sign) {
        // Kink halfway, pushed slightly vertical.
        final midX = (xEnd + center.dx) * 0.5;
        final midY = y + sign * runeSize * 0.4;
        final armPath = Path()
          ..moveTo(xEnd, y)
          ..lineTo(midX, midY)
          ..lineTo(center.dx + sign * runeSize * 0.55, y);
        canvas.drawPath(armPath, armPaint);

        // Small glyph at the strand end — diamond bead.
        final beadSize = radius * 0.028;
        final beadPath = Path()
          ..moveTo(xEnd, endPt.dy - beadSize)
          ..lineTo(xEnd + beadSize * 0.6, endPt.dy)
          ..lineTo(xEnd, endPt.dy + beadSize)
          ..lineTo(xEnd - beadSize * 0.6, endPt.dy)
          ..close();
        canvas.drawPath(beadPath, glyphFill);
        canvas.drawPath(beadPath, glyphStroke);
      }

      if (frontA == !isBackPass) {
        drawArm(xA, Offset(xA, y), -1.0);
      }
      if (frontB == !isBackPass) {
        drawArm(xB, Offset(xB, y), 1.0);
      }
    }
  }

  // ------------------------------------------------------------------
  // Core support arms — thin lines radiating from the core to nearby
  // helix anchor points, visually anchoring the core INSIDE the
  // structure rather than floating on top of it.
  void _drawCoreSupportArms(
    Canvas canvas,
    Offset center,
    double radius,
    double halfSpan,
    double phaseRot,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = palette.accent.withValues(alpha: 0.38);

    // Pick 4 support arms, targeting anchors that are roughly equator
    // -level (close to center vertically) so the arms aren't too long.
    final anchors = geometry.anchors;
    final equatorIndex = (anchors.length / 2).floor();
    final candidateOffsets = const [-3, -1, 1, 3];
    final coreEdgeR = radius * 0.20; // reach from core centre outward

    for (final off in candidateOffsets) {
      final idx = (equatorIndex + off).clamp(0, anchors.length - 1);
      final a = anchors[idx];
      // Two strand endpoints for this anchor.
      for (final strandPhase in const [0.0, math.pi]) {
        final angle = a.angleA + strandPhase + phaseRot;
        final endPt = Offset(
          center.dx + math.cos(angle) * radius * 0.70,
          center.dy - halfSpan + a.t * halfSpan * 2,
        );
        // Start just outside the core glyph edge.
        final startAngle = math.atan2(
          endPt.dy - center.dy,
          endPt.dx - center.dx,
        );
        final startPt = Offset(
          center.dx + math.cos(startAngle) * coreEdgeR,
          center.dy + math.sin(startAngle) * coreEdgeR,
        );
        canvas.drawLine(startPt, endPt, paint);
      }
    }
  }

  // ------------------------------------------------------------------
  // Core genome glyph — large, integrated, glowing. This is the
  // creature's "identity sigil" at the centre of the artifact.
  void _drawCoreGlyph(Canvas canvas, Offset center, double minSide) {
    final angles = geometry.coreGlyphAngles;
    if (angles.isEmpty) return;

    // Bigger than the old version (0.065 → 0.11). Also rendered with
    // an outer glow ring, inner inscription, and bright edges.
    final coreR = minSide * 0.11;

    // Outer glow — large soft disc.
    final glowRect = Rect.fromCircle(center: center, radius: coreR * 2.2);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.primary.withValues(alpha: 0.55),
          palette.primary.withValues(alpha: 0.08),
          palette.primary.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(glowRect);
    canvas.drawCircle(center, coreR * 2.2, glowPaint);

    // Main polygon.
    final outerPath = _polygonPath(center, angles, coreR);
    final mainFill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 1.1,
        colors: [
          _brighten(palette.primary, 0.30).withValues(alpha: 0.98),
          palette.primary.withValues(alpha: 0.92),
          palette.accent.withValues(alpha: 0.55),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreR));
    canvas.drawPath(outerPath, mainFill);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = palette.accent.withValues(alpha: 0.90);
    canvas.drawPath(outerPath, outline);

    // Inner inscription — smaller concentric polygon, rotated, provides
    // structural etching on the core.
    final innerR = coreR * 0.52;
    final rotatedAngles = angles
        .map((a) => a + math.pi / angles.length)
        .toList(growable: false);
    final innerPath = _polygonPath(center, rotatedAngles, innerR);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawPath(innerPath, innerPaint);

    // Seed mark — tiny filled pip at exact centre.
    final centrePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(center, 2.4, centrePaint);
  }

  Path _polygonPath(Offset c, List<double> angles, double r) {
    final path = Path();
    for (var i = 0; i < angles.length; i++) {
      final pt = Offset(
        c.dx + math.cos(angles[i]) * r,
        c.dy + math.sin(angles[i]) * r,
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  Color _brighten(Color base, double t) {
    final r = (base.r * 255 + (255 - base.r * 255) * t).round().clamp(0, 255);
    final g = (base.g * 255 + (255 - base.g * 255) * t).round().clamp(0, 255);
    final b = (base.b * 255 + (255 - base.b * 255) * t).round().clamp(0, 255);
    return Color.fromARGB((base.a * 255).round(), r, g, b);
  }

  // ------------------------------------------------------------------
  // Mutation nodes — larger accent-palette gems at seed-specific
  // anchor positions. Gives each DNA an identifiable "signature
  // mutation" position.
  void _drawMutationNodes(
    Canvas canvas,
    Offset center,
    double radius,
    double halfSpan,
    double phaseRot,
  ) {
    final anchors = geometry.anchors;
    final seed = geometry.dnaSeed;

    // Pick ~2-3 mutation positions deterministically. Bitmask:
    // anchor index i is a mutation if bit `(i * 7) mod 30` is set
    // AND the 3-stride filter hits.
    for (var i = 2; i < anchors.length - 2; i++) {
      final bit = ((seed >> ((i * 7) & 29)) & 0x01) == 1;
      final stride = (i - 2) % 5 == 0;
      if (!(bit && stride)) continue;

      final a = anchors[i];
      // Place the mutation on the more-front strand at this anchor.
      final angleA = a.angleA + phaseRot;
      final angleB = angleA + math.pi;
      final useA = math.sin(angleA) >= math.sin(angleB);
      final angle = useA ? angleA : angleB;
      final pt = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy - halfSpan + a.t * halfSpan * 2,
      );

      // Hexagonal gem.
      final r = radius * 0.04;
      final gem = Path();
      for (var k = 0; k < 6; k++) {
        final a2 = k * math.pi / 3;
        final x = pt.dx + math.cos(a2) * r;
        final y = pt.dy + math.sin(a2) * r;
        if (k == 0) {
          gem.moveTo(x, y);
        } else {
          gem.lineTo(x, y);
        }
      }
      gem.close();

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = palette.petal.withValues(alpha: 0.95);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawPath(gem, fill);
      canvas.drawPath(gem, stroke);
    }
  }

  // ------------------------------------------------------------------
  // Rune markers along the spine — fixed inscriptions, not
  // phase-rotated. Tightened visual style: small chevron pair instead
  // of plain crosses.
  void _drawRuneMarkers(
    Canvas canvas,
    Offset center,
    double radius,
    double halfSpan,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = palette.accent.withValues(alpha: 0.60);

    final markerOffset = radius * 1.22;
    for (var i = 0; i < geometry.anchors.length; i++) {
      final a = geometry.anchors[i];
      if (!a.hasRuneMarker) continue;
      final side = (i.isEven) ? -1.0 : 1.0;
      final cx = center.dx + side * markerOffset;
      final cy = center.dy - halfSpan + a.t * halfSpan * 2;
      // Chevron pair pointing inward.
      const armLen = 4.0;
      const gap = 2.2;
      final dir = -side; // point toward centre
      final path = Path()
        ..moveTo(cx - dir * armLen, cy - armLen)
        ..lineTo(cx, cy)
        ..lineTo(cx - dir * armLen, cy + armLen)
        ..moveTo(cx - dir * (armLen + gap), cy - armLen)
        ..lineTo(cx - dir * gap, cy)
        ..lineTo(cx - dir * (armLen + gap), cy + armLen);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PetDnaPainter old) {
    return old.geometry.renderKey != geometry.renderKey ||
        old.phase != phase ||
        old.userSpin != userSpin ||
        old.palette != palette;
  }
}

/// Short label rendered over the painter — e.g. "luminous · adult".
/// Not drawn by the painter itself; UI layer places it above/below.
String petDnaStageBranchLabel(PetStage stage, PetBranch branch) {
  return '${branch.name} · ${stage.name}';
}
