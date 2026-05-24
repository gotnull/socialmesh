// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// lint-allow: hardcoded-color — the thumbnail mirrors the live
// canvas viewer's surface/lattice/ring palette one-to-one so a
// dormant channel card and the eventual painted board read as the
// same artifact. Theming would break that visual identity.

// Mini canvas preview for the Mesh tab's channel canvas card.
//
// Renders ONE canvas's contents as a square thumbnail with the same
// surface tone, 32-cell chunk lattice, and border ring as the live
// viewer (CanvasGridPainter). When the channel is dormant — no
// painted cells yet — the thumbnail shows a single faint seed dot
// in the centre, suggesting "the first paint goes here." When cells
// exist, they render scaled to thumbnail space so the user gets a
// real glimpse of the channel's collaborative state without opening
// the viewer.
//
// IA invariant: this widget is MESH-ONLY. The local sandbox does
// not get a thumbnail card; the Local tab renders the viewport
// directly. Reusing this thumbnail for local would re-introduce the
// "Local Device Canvas" framing leak the dev rejected.
library;

import 'package:flutter/material.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../services/canvas/canvas_constants.dart';
import '../../../services/canvas/canvas_models.dart';

/// Visual constants borrowed from the live canvas viewer so a card
/// thumbnail and the actual canvas read as the same artifact.
const Color _surfaceColor = Color(0xFF161A22);
const Color _outsideColor = Color(0xFF0B0D11);
const Color _chunkLineColor = Color(0x14FFFFFF);
const Color _ringColor = Color(0x66FFFFFF);

/// Faint pulse marker shown at the centre of a dormant channel
/// thumbnail. Communicates "first paint goes here" without being a
/// loud call-to-action.
const Color _dormantSeedColor = Color(0x33FFFFFF);

class ChannelCanvasThumbnail extends StatelessWidget {
  /// Painted cells to render at thumbnail scale. Pass empty list for
  /// dormant channels — the thumbnail will draw a seed marker instead.
  final List<CanvasCell> cells;

  /// Whether to render the dormant seed dot. Caller decides — usually
  /// `cells.isEmpty` but the caller might suppress the marker (e.g.
  /// while loading cells from the repository).
  final bool isDormant;

  /// Logical-pixel side length. 96pt reads as a board-shaped preview
  /// without dominating the card row.
  final double size;

  const ChannelCanvasThumbnail({
    super.key,
    required this.cells,
    required this.isDormant,
    this.size = 96,
  });

  /// Corner radius applied to the outer clip AND the inner surface
  /// ring. Picked to sit between the surrounding card radius (16) and
  /// the previous sharp 8 — close enough to the card that the corners
  /// stop reading as a mismatch.
  static const double _thumbnailCornerRadius = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_thumbnailCornerRadius),
        child: CustomPaint(
          painter: _ChannelCanvasThumbnailPainter(
            cells: cells,
            isDormant: isDormant,
            cornerRadius: _thumbnailCornerRadius,
          ),
          size: Size(size, size),
        ),
      ),
    );
  }
}

class _ChannelCanvasThumbnailPainter extends CustomPainter {
  final List<CanvasCell> cells;
  final bool isDormant;
  final double cornerRadius;

  _ChannelCanvasThumbnailPainter({
    required this.cells,
    required this.isDormant,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Layer 0: outer pane (slightly darker than the surface, mirrors
    // the viewer's layered background). The outer ClipRRect already
    // rounds the visible corners, so this fill can stay a plain rect.
    canvas.drawRect(Offset.zero & size, Paint()..color = _outsideColor);

    // Layer 1: canvas surface. Inset slightly so the ring is visible
    // around the whole board. Drawn as an RRect with a slightly tighter
    // radius than the outer clip so the inner surface and the outer
    // chrome both look rounded in concert.
    const inset = 2.0;
    final surfaceRect = Rect.fromLTWH(
      inset,
      inset,
      w - inset * 2,
      h - inset * 2,
    );
    final surfaceRadius = Radius.circular(
      (cornerRadius - inset).clamp(0, cornerRadius),
    );
    final surfaceRRect = RRect.fromRectAndRadius(surfaceRect, surfaceRadius);
    canvas.drawRRect(surfaceRRect, Paint()..color = _surfaceColor);

    // Layer 2: 32-cell chunk lattice. Three lines per axis at
    // 1/4-board intervals. Mirrors the viewer.
    final chunkPaint = Paint()
      ..color = _chunkLineColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 3; i++) {
      final t = i / 4.0;
      final x = surfaceRect.left + surfaceRect.width * t;
      final y = surfaceRect.top + surfaceRect.height * t;
      canvas.drawLine(
        Offset(x, surfaceRect.top),
        Offset(x, surfaceRect.bottom),
        chunkPaint,
      );
      canvas.drawLine(
        Offset(surfaceRect.left, y),
        Offset(surfaceRect.right, y),
        chunkPaint,
      );
    }

    // Layer 3: painted cells, scaled to thumbnail space. Drop
    // index-0 (transparent / unpainted sentinel) and any out-of-
    // range palette indices.
    //
    // Visual treatment for dense canvases: each cell renders with a
    // tiny inset so adjacent painted cells show a faint gap rather
    // than smearing into a solid block, and at 0.78 alpha so the
    // dominant colours blend toward a softer palette instead of full
    // chromatic noise. Sparse canvases still read cleanly because
    // isolated cells sit on the dark surface and the inset is below
    // 1pt at thumbnail scale.
    if (cells.isNotEmpty) {
      final cellScale = surfaceRect.width / CanvasGeometry.width;
      // Cells are at minimum 1px so they actually paint at thumbnail
      // scale (a 96pt thumbnail of a 64-cell board gives ~1.4 logical
      // px per cell — sub-pixel rendering would lose them).
      final cellPx = cellScale < 1 ? 1.0 : cellScale;
      // Inset = 15% of cell size, capped so we never invert the rect
      // on very small cellPx values.
      final inset = (cellPx * 0.15).clamp(0.0, cellPx / 3);
      final drawPx = cellPx - inset * 2;
      final cellPaint = Paint();
      for (final cell in cells) {
        if (cell.color <= 0) continue;
        if (cell.color >= SocialMeshPalette.colors.length) continue;
        final colour = SocialMeshPalette.colors[cell.color];
        if (colour.a == 0) continue;
        cellPaint.color = colour.withValues(alpha: colour.a * 0.78);
        canvas.drawRect(
          Rect.fromLTWH(
            surfaceRect.left + cell.x * cellScale + inset,
            surfaceRect.top + cell.y * cellScale + inset,
            drawPx,
            drawPx,
          ),
          cellPaint,
        );
      }
    }

    // Layer 4: dormant seed marker. A faint 3pt dot in the centre of
    // the board, telling the user "this is where the first pixel
    // could go." Only rendered when the channel really has no cells
    // — never co-occurs with painted cells.
    if (isDormant) {
      final center = surfaceRect.center;
      canvas.drawCircle(center, 3, Paint()..color = _dormantSeedColor);
    }

    // Layer 5: surface border ring on top. Same tone as the viewer.
    // Drawn as an RRect matching the inner surface so the corners
    // don't read as a square frame inside the rounded clip.
    final ringPaint = Paint()
      ..color = _ringColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(surfaceRRect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _ChannelCanvasThumbnailPainter old) {
    if (old.isDormant != isDormant) return true;
    if (!identical(old.cells, cells)) return true;
    return false;
  }
}
