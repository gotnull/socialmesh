// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// CustomPainter for the MeshCanvas viewer surface.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §S0.ux.15 (the viewer must
// feel r/place-style, not a grid editor) and §S0.ux.16 (S7 critical
// acceptance — the canvas itself must read as a real artifact, not a
// sparse debug surface).
//
// What "real canvas" means visually in v0.1:
//   - The 128×128 surface has its OWN colour (slightly tonally
//     different from the app background) so the board edge is
//     visible even when no cells are painted.
//   - A 1.5pt soft ring frames the surface so the eye can locate
//     the bounds during pan.
//   - A 32-cell chunk lattice (4 × 4 chunks) draws faint hairlines.
//     The 32-cell spacing matches the wire-format tile boundaries
//     from CANVAS_V0_1.md §6.3/§6.4 — same units the receiver uses
//     for tile-aligned sync_request, so the lattice doubles as a
//     debugging affordance.
//   - Painted cells render on top of all chrome; the transparent
//     sentinel (palette index 0) skips so the surface colour shows
//     through.
//
// Repaint-cost note. The painter is wrapped in a `RepaintBoundary`
// by the viewer widget so Flutter caches the rasterised output to a
// GPU layer between frames. `shouldRepaint` returns false when the
// cells reference is identical AND geometry is unchanged, so pan/zoom
// gestures don't re-rasterise; only an actual cell mutation
// invalidates the cached layer. The chunk lattice + border draw is
// O(1) per repaint regardless of cell count.
library;

import 'package:flutter/material.dart';

import '../../../services/canvas/canvas_models.dart';

/// Chunk spacing (cells per chunk side). Matches the wire-format
/// tile boundary from CANVAS_V0_1.md §6.3 so the lattice maps
/// directly to sync_request rects.
const int _kChunkSizeCells = 32;

class CanvasGridPainter extends CustomPainter {
  /// All painted (non-default-colour) cells for the current canvas.
  /// MUST be a fresh list reference whenever the underlying state
  /// changes; the painter uses identity for repaint-skip decisions.
  final List<CanvasCell> cells;

  /// Indexed palette. `palette[cellRow.color]` resolves to the on-
  /// screen colour for that cell. Index 0 is treated as "transparent
  /// / unpainted" and is skipped — the surface colour shows through.
  final List<Color> palette;

  /// Side length (logical pixels) of one cell. The viewer sets this
  /// so each cell reads as a real pixel at the framed initial zoom.
  final double cellSize;

  /// Colour of the area surrounding the canvas surface (the viewport
  /// scroll-pan space). Painted under everything so over-pan reveals
  /// it rather than transparent void.
  final Color outsideColor;

  /// Colour of the canvas surface itself. Slightly tonally distinct
  /// from [outsideColor] so the board reads as a discrete artifact
  /// against the app chrome.
  final Color surfaceColor;

  /// Hairline tone for the 32-cell chunk lattice on the surface.
  final Color chunkLineColor;

  /// Soft ring stroke colour drawn around the entire surface.
  final Color borderColor;

  /// Width and height of the canvas in cells. v0.1 = 128 × 128.
  final int widthCells;
  final int heightCells;

  const CanvasGridPainter({
    required this.cells,
    required this.palette,
    required this.cellSize,
    required this.outsideColor,
    required this.surfaceColor,
    required this.chunkLineColor,
    required this.borderColor,
    this.widthCells = 128,
    this.heightCells = 128,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasW = widthCells * cellSize;
    final canvasH = heightCells * cellSize;
    final surfaceRect = Rect.fromLTWH(0, 0, canvasW, canvasH);

    // Layer 0: outside fill. Covers any geometry slop where
    // [size] is larger than the canvas rect (boundary margin).
    if (size.width > canvasW || size.height > canvasH) {
      canvas.drawRect(Offset.zero & size, Paint()..color = outsideColor);
    }

    // Layer 1: canvas surface fill — the board itself.
    canvas.drawRect(surfaceRect, Paint()..color = surfaceColor);

    // Layer 2: 32-cell chunk lattice. Subtle hairlines on the
    // surface only (not the surrounding margin). Vertical lines at
    // x = 32, 64, 96 cells; horizontal lines at y = 32, 64, 96.
    final chunkPaint = Paint()
      ..color = chunkLineColor
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    final chunkPx = _kChunkSizeCells * cellSize;
    for (var i = 1; i * _kChunkSizeCells < widthCells; i++) {
      final x = i * chunkPx;
      canvas.drawLine(Offset(x, 0), Offset(x, canvasH), chunkPaint);
    }
    for (var j = 1; j * _kChunkSizeCells < heightCells; j++) {
      final y = j * chunkPx;
      canvas.drawLine(Offset(0, y), Offset(canvasW, y), chunkPaint);
    }

    // Layer 3: painted cells. Re-use a single Paint and mutate its
    // colour to avoid per-cell allocation.
    final cellPaint = Paint();
    for (final cell in cells) {
      if (cell.color < 0 || cell.color >= palette.length) continue;
      final colour = palette[cell.color];
      if (colour.a == 0) continue; // transparent sentinel — skip
      cellPaint.color = colour;
      canvas.drawRect(
        Rect.fromLTWH(cell.x * cellSize, cell.y * cellSize, cellSize, cellSize),
        cellPaint,
      );
    }

    // Layer 4: surface border on top. Stays visible regardless of
    // cell density.
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(surfaceRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CanvasGridPainter old) {
    // Identity check on `cells` because the repository emits a fresh
    // list reference on every state change; deep-equality would be
    // O(n) and we'd run it on every pan/zoom frame.
    if (!identical(old.cells, cells)) return true;
    if (old.cellSize != cellSize) return true;
    if (old.outsideColor != outsideColor) return true;
    if (old.surfaceColor != surfaceColor) return true;
    if (old.chunkLineColor != chunkLineColor) return true;
    if (old.borderColor != borderColor) return true;
    if (old.widthCells != widthCells) return true;
    if (old.heightCells != heightCells) return true;
    if (!identical(old.palette, palette)) return true;
    return false;
  }
}
