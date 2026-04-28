// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetDnaPainter — DNA Blueprint renderer for the DNA Viewer.
//
// Design intent:
//   - Proper double-helix archetype. Two intertwined cylindrical
//     strands with classic base-pair rungs — no ornamental "glyph
//     bonds", no ritual-artifact decoration.
//   - Seed-derived A/T/G/C base coloring per node. Every pet has a
//     deterministic unique sequence along its helix, and the four
//     base colors give the visual the liveliness a monotone helix
//     can never have.
//   - Depth-scaled bead nodes at every sample point are what sell
//     the 3D perspective — near beads larger than far beads, sorted
//     back-to-front so crossovers resolve naturally.
//   - Backbone rendered as thick round-capped stroked lines between
//     beads. Stroke width IS the tube diameter; no ribbon geometry,
//     no shaders. Technique borrowed from
//     Devkumar755/MyCodeDemos/dna_helix.dart as the user-requested
//     reference.
//   - No atmospheric clutter — soft branch-tinted radial backdrop
//     only. The old chamber haze, containment pillars, central
//     spine, core support arms, mutation nodes, and rune markers
//     were competing with the helix and have been removed.
//   - Sigil core glyph is preserved (identity representation) but
//     smaller and sandwiched at the depth=0 seam so half the helix
//     draws behind it and half in front.
//   - Deterministic under (dnaSeed, stage, branch, twistCycles).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet_base_allele.dart';
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
    canvas.clipRect(Offset.zero & size);

    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);
    // Helix dominates the frame. Tuned so the strand extent sits at
    // ~66% of minSide (enough room for thick strokes + depth-scaled
    // beads at the edges without clipping).
    final radius = minSide * 0.33;
    // Helix terminus now sits comfortably inside the canvas rather
    // than overshooting. Combined with the widened endFade below, the
    // strands dissolve into the backdrop instead of reading as a hard
    // clip against the top/bottom edges.
    final halfSpan = size.height * 0.48;
    final phaseRot = phase * math.pi * 2 + userSpin;

    _drawBackdrop(canvas, size, minSide);

    _drawHelix(
      canvas: canvas,
      center: center,
      radius: radius,
      halfSpan: halfSpan,
      phaseRot: phaseRot,
      minSide: minSide,
      drawCoreLayerCallback: () => _drawCoreGlyph(canvas, center, minSide),
    );
  }

  /// Soft radial branch-tinted backdrop. Replaces the old chamber
  /// haze + containment pillars + spine, which were three competing
  /// atmospheric layers. The helix is the subject now.
  void _drawBackdrop(Canvas canvas, Size size, double minSide) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: minSide * 0.6,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.primary.withValues(alpha: 0.14),
          palette.primary.withValues(alpha: 0.04),
          palette.primary.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  // ------------------------------------------------------------------
  // Helix — the premium double-helix render at the heart of the viewer.
  //
  // Previously this was split into two passes (_drawStrandsPass +
  // _drawBondsPass) with per-pass depth binary splits at the core
  // glyph. That produced: (a) a single strand for Monad pets, (b)
  // ornamental "glyph bonds" that didn't read as classic DNA rungs,
  // and (c) coarse polyline kinks at helix turnaround points.
  //
  // This rewrite:
  //   * Always renders at least 2 strands. The pet's decoded
  //     strand-config trait (Monad/Dyad/Triad) still shows in the
  //     Identity panel, but the viewer ALWAYS depicts the DNA
  //     archetype — a helix with ≥ 2 intertwined strands.
  //   * Bumps the visible twist count to at least 4 so the helix is
  //     unambiguous at a glance regardless of the pet's "resonance"
  //     trait (which can go as low as 2).
  //   * Extends the parametric t range past [0, 1] by 10% so strands
  //     run off-frame and clip at the canvas edge instead of
  //     tapering to a point mid-canvas. Requires [canvas.clipRect]
  //     in paint() to prevent bleed into neighbouring widgets.
  //   * Draws classic DNA rungs — thin depth-shaded perpendicular
  //     lines between adjacent strand samples at 3-per-twist cadence.
  //     Shader-free alpha by midpoint depth; readable and cheap.
  //   * Global painter's-algorithm z-sort across all strand micro-
  //     segments + all rungs. Crossovers (one strand passing in front
  //     of the other) are the natural outcome of depth-sorted draw
  //     order, not a special case.
  //   * Interleaves the core glyph + support arms at depth=0 via a
  //     callback, preserving the "helix wrapping the sigil" sandwich
  //     even though strand rendering is now unified.
  void _drawHelix({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double halfSpan,
    required double phaseRot,
    required double minSide,
    required VoidCallback drawCoreLayerCallback,
  }) {
    // Always 2-strand visual — Monad/Dyad/Triad lives in the decoded
    // panel, but the DNA Blueprint archetype is universally a helix.
    const visualStrandCount = 2;
    // 3 twist cycles — fewer than before so each twist has breathing
    // room and crossovers are unambiguous at a glance.
    const visualTwistCycles = 3;
    final baseAngle = geometry.anchors.first.angleA;

    // 14 samples per twist × 3 = 42 samples per strand. Dense enough
    // to read as a smooth helix, sparse enough that each bead is
    // visually distinct at its depth-scaled size.
    const samplesPerTwist = 14;
    const totalSamples = samplesPerTwist * visualTwistCycles;

    // Rendering proportions — thick, bold, dominant. These are the
    // bumps the user explicitly asked for over the previous slim
    // cord look.
    final backboneStrokeWidth = (radius * 0.075).clamp(7.0, 16.0);
    final baseNodeRadius = (radius * 0.065).clamp(6.0, 13.0);
    final rungStrokeWidth = (radius * 0.045).clamp(4.0, 8.0);

    // ---- Allele-driven color scheme --------------------------------
    //
    // Each sample carries an allele (Aurora/Tether/Gale/Calm) from the
    // pet's deterministic sequence. The allele's archetype color is
    // what colors that sample's bead AND one half of any rung at that
    // position. Complementary strand's sample carries the pairing
    // complement (A↔T, G↔C), giving two-tone rungs.
    //
    // Backbones use strand-specific distinctive colors derived from the
    // pet's dominant allele, so the two strands are never the same hue
    // and crossovers are instantly readable.
    final sequence = geometry.alleleSequence;
    final dominant = geometry.dominantAllele;

    // Strand 0 backbone = dominant allele's archetype color, boosted to
    // near-saturation for punch.
    final strand0Backbone = _deepen(dominant.archetypeColor, 0.20);
    // Strand 1 backbone = dominant's COMPLEMENT's archetype color. If
    // the pet is Aurora-dominant, strand 0 is yellow-gold and strand 1
    // is steady-emerald — always a high-contrast pair. This is also
    // what ties the viewer's visual identity to the pet's allele
    // profile: Gale-dominant pets look orange/lavender; Tether-
    // dominant pets look emerald/gold; etc.
    final strand1Backbone = _deepen(dominant.complement.archetypeColor, 0.20);
    final strandBackbones = <Color>[strand0Backbone, strand1Backbone];

    PetBaseAllele alleleAtIndex(int i) => sequence[i % sequence.length];

    // Weak perspective projection. Previously x was cos(angle)*radius
    // which is the orthographic side view of a cylinder — mathematically
    // a cylinder, so the result read as one. Treating sin(angle) as the
    // z depth (already computed for sort order) and dividing the x
    // coordinate by a focal-length ratio makes near-side samples spread
    // further from the central axis than far-side samples. Focal 3.5
    // gives nearest beads ~40% more spread than farthest — enough to
    // read as a genuine 3D molecule without cartoonish distortion.
    const perspectiveFocal = 3.5;

    // Sample both strands. Strand 0 carries the raw sequence allele;
    // strand 1 carries its complement (A↔T, G↔C).
    final samples =
        List<List<({Offset pt, double depth, PetBaseAllele allele})>>.generate(
          visualStrandCount,
          (_) => <({Offset pt, double depth, PetBaseAllele allele})>[],
        );
    for (var i = 0; i <= totalSamples; i++) {
      final t = i / totalSamples;
      final a0 = alleleAtIndex(i);
      final a1 = a0.complement;
      for (var s = 0; s < visualStrandCount; s++) {
        final strandPhase = s * math.pi; // 180° offset for classic pair
        final angle =
            baseAngle +
            t * visualTwistCycles * math.pi * 2 +
            strandPhase +
            phaseRot;
        final z = math.sin(angle);
        final pScale = perspectiveFocal / (perspectiveFocal - z);
        samples[s].add((
          pt: Offset(
            center.dx + math.cos(angle) * radius * pScale,
            center.dy - halfSpan + t * halfSpan * 2,
          ),
          depth: z,
          allele: s == 0 ? a0 : a1,
        ));
      }
    }

    // End-fade factor per sample index — alpha tapers smoothly to 0
    // over the outermost ~20% of samples at each end. The wider window
    // (was ~8%) lets the strand visibly dissolve into the backdrop
    // instead of popping at 90% alpha right at the canvas edge.
    double endFade(int i) {
      final frac = i / totalSamples;
      final fade = math.min(
        math.min(1.0, frac * 5.0),
        math.min(1.0, (1.0 - frac) * 5.0),
      );
      return fade.clamp(0.0, 1.0);
    }

    // Build z-sorted draw ops. Three kinds:
    //   1. Backbone segment — a round-capped stroked line between
    //      consecutive samples on the same strand. The stroke width
    //      IS the tube diameter; no ribbon geometry, no shader.
    //   2. Rung — a stroked line between the two strands' samples at
    //      every other index. Depth-alpha shaded.
    //   3. Node bead — a filled circle at each sample, depth-scaled
    //      (near beads bigger than far beads) which is what sells the
    //      perspective / "round tube" illusion.
    final ops = <({double depth, VoidCallback draw})>[];

    // Backbones — round-capped stroked lines between consecutive
    // samples on each strand. Each strand wears its own distinctive
    // color (dominant-allele and its complement) so crossovers are
    // immediately readable. Hard back/front alpha contrast: back
    // strand at ~0.40 with desaturation toward dark neutral, front
    // strand at full saturation + alpha 1.0.
    for (var s = 0; s < visualStrandCount; s++) {
      final strand = samples[s];
      final strandColor = strandBackbones[s];
      for (var i = 0; i < strand.length - 1; i++) {
        final a = strand[i];
        final b = strand[i + 1];
        final avgDepth = (a.depth + b.depth) * 0.5;
        final fade = (endFade(i) + endFade(i + 1)) * 0.5;
        ops.add((
          depth: avgDepth,
          draw: () {
            final depthNorm = (avgDepth + 1.0) * 0.5; // 0..1 back..front
            // Hard contrast curve: back 0.40 alpha, front 1.0.
            final alpha = ((0.40 + 0.60 * depthNorm) * fade).clamp(0.0, 1.0);
            // Desaturate-to-dark for back-facing segments. At the very
            // back (depth = -1) the strand appears 30% toward black;
            // at the front (depth = +1) it's at full chroma.
            final drawColor = Color.lerp(
              Colors.black,
              strandColor,
              0.35 + 0.65 * depthNorm,
            )!;
            final paint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = backboneStrokeWidth
              ..color = drawColor.withValues(alpha: alpha);
            canvas.drawLine(a.pt, b.pt, paint);
          },
        ));
      }
    }

    // Rungs — every other sample, TWO-TONE by allele pair. Each half
    // of the rung is the archetype color of that strand's allele, so
    // every rung literally reads as "aurora↔tether" or "gale↔calm".
    //
    // Rungs also fade to alpha 0 near the canvas center via a radial
    // smoothstep. The Rive pet creature overlays the viewer at that
    // exact spot, and rungs passing through its silhouette flickered
    // against its animated edges. The fade window is tuned to the
    // core glyph radius: rungs stay fully opaque beyond ~0.15 × minSide
    // from center and dissolve cleanly inside the pet's halo.
    final coreClearInner = minSide * 0.08;
    final coreClearOuter = minSide * 0.15;
    for (var i = 1; i < samples[0].length; i += 2) {
      final a = samples[0][i];
      final b = samples[1][i];
      final midDepth = (a.depth + b.depth) * 0.5;
      final fade = endFade(i);
      final mid = Offset.lerp(a.pt, b.pt, 0.5)!;
      final clearFade = _smoothstep(
        coreClearInner,
        coreClearOuter,
        (mid - center).distance,
      );
      // Width-based fade. As the helix rotates through its edge-on
      // position, both strand samples pass through the vertical
      // centerline and the rung collapses to near-zero horizontal
      // extent. Without this, the rung's two stroke caps overlap into
      // a short blob that visually detaches from the beads and reads
      // as a floating tail. Fade rung alpha to 0 when the endpoints
      // are within ~stroke-width of each other; full alpha beyond 2×
      // stroke width.
      final rungSpan = (a.pt.dx - b.pt.dx).abs();
      final widthFade = _smoothstep(
        rungStrokeWidth * 0.6,
        rungStrokeWidth * 2.0,
        rungSpan,
      );
      ops.add((
        depth: midDepth,
        draw: () {
          final midBright = (midDepth + 1.0) * 0.5;
          final alpha =
              ((0.70 + 0.30 * midBright) * fade * clearFade * widthFade).clamp(
                0.0,
                1.0,
              );
          // Butt caps (not round) — round caps extend past the bead
          // endpoint by half the stroke width, which was reading as a
          // stub poking out of the bead. Butt terminates flush.
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = rungStrokeWidth;
          canvas.drawLine(
            a.pt,
            mid,
            paint..color = a.allele.archetypeColor.withValues(alpha: alpha),
          );
          canvas.drawLine(
            mid,
            b.pt,
            paint..color = b.allele.archetypeColor.withValues(alpha: alpha),
          );
        },
      ));
    }

    // Node beads — every OTHER sample (rung cadence), every strand.
    // Density halved from "every sample" so adjacent same-strand beads
    // are no longer 7px apart in y with wildly different depths —
    // that configuration guaranteed visible z-sort swaps as the helix
    // rotated. Rung endpoints now land exactly on beads (DNA-accurate
    // base-pair nucleotides), and the remaining swaps are spaced far
    // enough apart that they read as gentle orbit motion rather than
    // pop-flickering.
    //
    // Scale 0.35..1.25 and alpha 0.10..1.0 — back beads are genuinely
    // dust-mote faint; their sort-order flips are invisible because
    // they're barely there. White rim + dark halo are gated to the
    // front half only (decorPulse) so back beads don't carry 20% of
    // extra visual weight from decoration the alpha can't suppress.
    for (var s = 0; s < visualStrandCount; s++) {
      for (var i = 1; i < samples[s].length; i += 2) {
        final sample = samples[s][i];
        final fade = endFade(i);
        ops.add((
          depth: sample.depth,
          draw: () {
            final depthNorm = (sample.depth + 1.0) * 0.5;
            final scale = 0.35 + 0.90 * depthNorm; // 0.35..1.25
            final nodeR = baseNodeRadius * scale;
            final alpha = ((0.10 + 0.90 * depthNorm) * fade).clamp(0.0, 1.0);
            final beadColor = sample.allele.archetypeColor;
            // Decoration (rim + halo) fades in only for front-half
            // beads. Back beads are bare colored dots — no rim, no
            // halo — so their depth-sort order is visually irrelevant.
            final decorPulse = _smoothstep(0.40, 0.75, depthNorm);
            if (decorPulse > 0) {
              canvas.drawCircle(
                sample.pt,
                nodeR + 1.5,
                Paint()
                  ..style = PaintingStyle.fill
                  ..color = Colors.black.withValues(
                    alpha: (alpha * 0.35 * decorPulse).clamp(0.0, 1.0),
                  ),
              );
            }
            canvas.drawCircle(
              sample.pt,
              nodeR,
              Paint()
                ..style = PaintingStyle.fill
                ..color = beadColor.withValues(alpha: alpha),
            );
            if (decorPulse > 0) {
              canvas.drawCircle(
                sample.pt,
                nodeR,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4
                  ..color = Colors.white.withValues(
                    alpha: (alpha * 0.85 * decorPulse).clamp(0.0, 1.0),
                  ),
              );
            }
          },
        ));
      }
    }

    ops.sort((a, b) => a.depth.compareTo(b.depth));

    // Interleave the core layer at the depth=0 seam — back-facing
    // helix elements draw first, then the sigil core, then front-
    // facing elements on top.
    var coreDrawn = false;
    for (final op in ops) {
      if (!coreDrawn && op.depth >= 0) {
        drawCoreLayerCallback();
        coreDrawn = true;
      }
      op.draw();
    }
    if (!coreDrawn) drawCoreLayerCallback();
  }

  // ------------------------------------------------------------------
  // Core genome glyph — the pet's identity sigil. Smaller than before
  // so it reads as a jewel inside the helix rather than competing
  // with it.
  // creature's "identity sigil" at the centre of the artifact.
  void _drawCoreGlyph(Canvas canvas, Offset center, double minSide) {
    final angles = geometry.coreGlyphAngles;
    if (angles.isEmpty) return;

    // Bigger than the old version (0.065 → 0.11). Also rendered with
    // an outer glow ring, inner inscription, and bright edges.
    // Smaller than before (was 0.11) — the helix is the subject now,
    // and the sigil sits inside it as a jewel, not a competing disc.
    final coreR = minSide * 0.07;

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

  /// Hermite smoothstep in [edge0, edge1]. Returns a value in [0, 1]
  /// with zero first-derivative at both endpoints — the classic
  /// GLSL smoothstep. Used for the rung clear-zone around the pet so
  /// the fade reads as a soft dissolve rather than a linear ramp.
  double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  /// Deepen a color toward saturation by lerping it slightly toward a
  /// pure-chroma version of itself. Used on strand backbones so the
  /// allele archetype colors read as bold, not pastel.
  Color _deepen(Color base, double t) {
    final r = (base.r * 255 * (1 - t * 0.2)).round().clamp(0, 255);
    final g = (base.g * 255 * (1 - t * 0.2)).round().clamp(0, 255);
    final b = (base.b * 255 * (1 - t * 0.2)).round().clamp(0, 255);
    return Color.fromARGB((base.a * 255).round(), r, g, b);
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
