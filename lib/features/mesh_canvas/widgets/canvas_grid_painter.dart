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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../services/canvas/canvas_constants.dart';
import '../../../services/canvas/canvas_models.dart';

/// Chunk spacing (cells per chunk side). Matches the wire-format
/// tile boundary from CANVAS_V0_1.md §6.3 so the lattice maps
/// directly to sync_request rects.
const int _kChunkSizeCells = 32;

/// One cell mid-vanish: the cell was painted last build but is gone
/// (erased or overwritten) this build. The painter renders it with
/// a reverse easeInBack scale + linear alpha fade so the user sees
/// the pixel "pop out" instead of disappearing instantly. Carries a
/// snapshot of the cell's last-known color because the live
/// `cells` list no longer contains it.
class VanishingCell {
  final int x;
  final int y;
  final int color;
  final int startMs;

  const VanishingCell({
    required this.x,
    required this.y,
    required this.color,
    required this.startMs,
  });
}

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

  /// Cells with a pending outbound row in `pending_op`, packed as
  /// `y * widthCells + x`. These paint at reduced opacity so users
  /// see at a glance which paints are still in flight.
  ///
  /// Spec: CANVAS_TRANSMISSION_STATUS_V0_1.md §3.2.
  ///
  /// Empty (default) when the host viewport is local-scope OR the
  /// queue is empty. The set is read from
  /// `meshCanvasPendingCellsProvider` upstream.
  final Set<int> pendingCellIndices;

  /// Alpha multiplier applied to cells in [pendingCellIndices].
  /// Defaults to 0.55 per CANVAS_TRANSMISSION_STATUS_V0_1.md §3.2.
  /// Exposed for tests so they can assert the multiplier directly.
  final double pendingOpacityFactor;

  /// Optional per-cell arrival timestamp map (packed coord -> ms
  /// since epoch). Cells whose age is under [popDurationMs] render
  /// with a center-anchored scale + alpha pop-in. Cells missing
  /// from the map paint at full size + alpha. Null disables the
  /// animation entirely (used by tests + the local-scope viewer
  /// when the host has no arrival tracker).
  final Map<int, int>? cellArrivalMs;

  /// Optional list of cells currently popping OUT (erased on local
  /// or inbound from a peer). Each entry carries the cell's last-
  /// known color, packed coord, and the timestamp the vanish was
  /// observed. The painter renders them with a reverse easeInBack
  /// scale + linear alpha fade over [popDurationMs]. Entries older
  /// than the window are skipped (the viewer should evict them on
  /// its next diff but the painter is defensive).
  final List<VanishingCell>? vanishingCells;

  /// Pop-in/out animation duration in ms. 320ms is the easeOutBack
  /// sweet spot: snappy overshoot at ~80ms, fully settled by 320ms.
  final int popDurationMs;

  /// Tile indices (packed as `tileY * tilesPerRow + tileX`) that are
  /// currently receiving raw-band sync_responses from a peer. The
  /// painter draws a diagonal shimmer sweep across each rect so the
  /// user sees WHERE pixels are landing instead of just a generic
  /// "syncing" pill. Null or empty = no shimmer.
  final Set<int>? syncingTileIndices;

  /// Color of the shimmer sweep applied to syncing tiles. Defaults
  /// to white at low alpha so it reads as a pass of light over the
  /// tile regardless of the underlying cells.
  final Color shimmerColor;

  /// Shimmer sweep period in ms. One full diagonal traversal takes
  /// this long; the sweep then wraps and repeats while a tile is in
  /// [syncingTileIndices].
  final int shimmerPeriodMs;

  CanvasGridPainter({
    required this.cells,
    required this.palette,
    required this.cellSize,
    required this.outsideColor,
    required this.surfaceColor,
    required this.chunkLineColor,
    required this.borderColor,
    this.widthCells = CanvasGeometry.width,
    this.heightCells = CanvasGeometry.height,
    this.pendingCellIndices = const <int>{},
    this.pendingOpacityFactor = 0.55,
    this.cellArrivalMs,
    this.vanishingCells,
    this.popDurationMs = 320,
    this.syncingTileIndices,
    this.shimmerColor = const Color(0x33FFFFFF),
    this.shimmerPeriodMs = 1400,
    super.repaint,
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
    // colour to avoid per-cell allocation. Cells whose packed
    // coordinate is in [pendingCellIndices] paint at reduced opacity
    // so users see at a glance which paints are still in flight on
    // the mesh (CANVAS_TRANSMISSION_STATUS_V0_1.md §3.2).
    //
    // Pop-in animation: cells whose packed coord exists in
    // [cellArrivalMs] and whose age is under [popDurationMs] render
    // with a center-anchored easeOutBack scale (snappy overshoot at
    // ~80ms, fully settled by 320ms) and a linear alpha ramp over
    // the first 50% of the window. Older cells paint at full size +
    // alpha. Disabled entirely when [cellArrivalMs] is null.
    final cellPaint = Paint();
    final hasPending = pendingCellIndices.isNotEmpty;
    final arrivals = cellArrivalMs;
    final vanishing = vanishingCells;
    final animEnabled =
        (arrivals != null && arrivals.isNotEmpty) ||
        (vanishing != null && vanishing.isNotEmpty);
    final nowMs = animEnabled ? DateTime.now().millisecondsSinceEpoch : 0;
    for (final cell in cells) {
      if (cell.color < 0 || cell.color >= palette.length) continue;
      final colour = palette[cell.color];
      if (colour.a == 0) continue; // transparent sentinel: skip
      final key = cell.y * widthCells + cell.x;
      final isPending = hasPending && pendingCellIndices.contains(key);
      // Resolve pop-in animation state for this cell.
      double scale = 1.0;
      double alphaMul = 1.0;
      if (arrivals != null && arrivals.isNotEmpty) {
        final startMs = arrivals[key];
        if (startMs != null) {
          final age = nowMs - startMs;
          if (age < 0) {
            // Color-change stagger: arrival is scheduled to start
            // after the old color's vanish completes. Hide the new
            // color completely during the wait so the user sees the
            // old shrink to nothing FIRST, then the new pop in.
            scale = 0.0;
            alphaMul = 0.0;
          } else if (age < popDurationMs) {
            final t = age / popDurationMs;
            scale = _popInScale(t);
            // Alpha ramps in across the first 50% so the fade-in
            // matches the gentler scale curve.
            alphaMul = (t / 0.5).clamp(0.0, 1.0);
          }
        }
      }
      final effectiveAlpha = isPending
          ? colour.a * pendingOpacityFactor * alphaMul
          : colour.a * alphaMul;
      cellPaint.color = colour.withValues(alpha: effectiveAlpha);
      if (scale >= 1.0 && alphaMul >= 1.0) {
        // Hot path: settled cell. Same allocation profile as before
        // the animation feature landed.
        canvas.drawRect(
          Rect.fromLTWH(
            cell.x * cellSize,
            cell.y * cellSize,
            cellSize,
            cellSize,
          ),
          cellPaint,
        );
      } else {
        // Animating: center-anchored scaled rect.
        final cx = cell.x * cellSize + cellSize / 2;
        final cy = cell.y * cellSize + cellSize / 2;
        final half = (cellSize * scale) / 2;
        canvas.drawRect(
          Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
          cellPaint,
        );
      }
    }

    // Layer 3b: pop-out for vanishing cells. Cells that were painted
    // last build but are gone this build (erase, overwrite to
    // transparent, inbound LWW dispatch from a peer who cleared them)
    // render with a reverse easeInBack scale + linear alpha fade so
    // the user sees the pixel deflate instead of disappearing
    // instantly. Entries older than [popDurationMs] are skipped as
    // defense in depth (the viewer evicts them on its diff tick).
    if (vanishing != null && vanishing.isNotEmpty) {
      for (final v in vanishing) {
        if (v.color < 0 || v.color >= palette.length) continue;
        final colour = palette[v.color];
        if (colour.a == 0) continue;
        final age = nowMs - v.startMs;
        if (age < 0 || age >= popDurationMs) continue;
        final t = age / popDurationMs;
        final scale = _popOutScale(t);
        // Alpha decays linearly so the cell is mostly gone by the
        // time the scale collapse hits zero.
        final alphaMul = (1.0 - t).clamp(0.0, 1.0);
        cellPaint.color = colour.withValues(alpha: colour.a * alphaMul);
        final cx = v.x * cellSize + cellSize / 2;
        final cy = v.y * cellSize + cellSize / 2;
        final half = (cellSize * scale) / 2;
        canvas.drawRect(
          Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
          cellPaint,
        );
      }
    }

    // Layer 3c: shimmer overlay on syncing tiles. Diagonal gradient
    // sweep over each tile rect currently receiving raw-band
    // sync_responses. The sweep loops every [shimmerPeriodMs] so the
    // user sees WHERE pixels are landing instead of only a generic
    // "Receiving pixels" pill. Spec: CANVAS_SYNC_V0_1.md (S0.ux.30).
    final syncing = syncingTileIndices;
    if (syncing != null && syncing.isNotEmpty) {
      final liveNowMs = nowMs == 0
          ? DateTime.now().millisecondsSinceEpoch
          : nowMs;
      final phase = (liveNowMs % shimmerPeriodMs) / shimmerPeriodMs;
      final tilePx = CanvasGeometry.tileSize * cellSize;
      final transparentShimmer = shimmerColor.withValues(alpha: 0);
      for (final tileIdx in syncing) {
        final tileX = tileIdx % CanvasGeometry.tilesPerRow;
        final tileY = tileIdx ~/ CanvasGeometry.tilesPerRow;
        final tileLeft = tileX * tilePx;
        final tileTop = tileY * tilePx;
        final tileRect = Rect.fromLTWH(tileLeft, tileTop, tilePx, tilePx);
        // Diagonal sweep: band travels from top-left-off-tile to
        // bottom-right-off-tile. `phase` parameterises that travel.
        // Endpoints are computed in canvas-pixel space so the band
        // width is constant regardless of tile size.
        final bandWidth = tilePx * 0.6;
        final travel = -bandWidth + phase * (tilePx + 2 * bandWidth);
        final bandStart = Offset(tileLeft + travel, tileTop + travel);
        final bandEnd = Offset(
          tileLeft + travel + bandWidth,
          tileTop + travel + bandWidth,
        );
        final shimmer = Paint()
          ..shader = ui.Gradient.linear(
            bandStart,
            bandEnd,
            [transparentShimmer, shimmerColor, transparentShimmer],
            const [0.0, 0.5, 1.0],
          );
        canvas.save();
        canvas.clipRect(tileRect);
        canvas.drawRect(tileRect, shimmer);
        canvas.restore();
      }
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
    if (!identical(old.vanishingCells, vanishingCells)) return true;
    if (!identical(old.syncingTileIndices, syncingTileIndices)) return true;
    if (!identical(old.pendingCellIndices, pendingCellIndices)) return true;
    if (old.pendingOpacityFactor != pendingOpacityFactor) return true;
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

  /// Pop-IN scale curve: smooth grow with a hint of bounce so the
  /// cell lands with a little life. Two phases, peak at 1.15:
  ///   - 0..0.45: 0 -> 1.15 (eased grow with subtle overshoot)
  ///   - 0.45..1.00: 1.15 -> 1.0 (gentle settle)
  double _popInScale(double t) {
    if (t < 0.45) {
      final p = t / 0.45;
      final eased = Curves.easeOut.transform(p);
      return 1.15 * eased;
    }
    final p = (t - 0.45) / 0.55;
    final eased = Curves.easeInOut.transform(p);
    return 1.15 - 0.15 * eased; // 1.15 -> 1.00
  }

  /// Pop-OUT scale curve: very subtle puff then collapse. The hint
  /// of motion before the cell vanishes prevents it from reading as
  /// "snapped away":
  ///   - 0..0.20: 1.0 -> 1.05 (tiny swell)
  ///   - 0.20..1.00: 1.05 -> 0 (shrink, easeIn)
  double _popOutScale(double t) {
    if (t < 0.20) {
      final p = t / 0.20;
      final eased = Curves.easeOut.transform(p);
      return 1.0 + 0.05 * eased;
    }
    final p = (t - 0.20) / 0.80;
    final eased = Curves.easeIn.transform(p);
    return (1.05 * (1.0 - eased)).clamp(0.0, 1.05);
  }
}
