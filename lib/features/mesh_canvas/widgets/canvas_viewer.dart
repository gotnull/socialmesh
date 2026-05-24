// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// lint-allow: haptic-feedback — the viewer is a pure render+gesture
// surface; haptics are gated by the host screen via
// `ref.haptics.toggle()` (which respects the user's settings) on the
// `onTapPaint` callback. Triggering `HapticFeedback.lightImpact()`
// inline here would bypass that user preference and produce a
// double-pulse alongside the host's own haptic call.

// r/place-style interactive viewer for a MeshCanvas.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §S0.ux.15 (pan, pinch zoom,
// tap-to-paint, long-press-inspect) and §S0.ux.16 (S7 critical
// acceptance — MUST feel r/place-style; a grid editor / list / table
// is a FAILED S7).
//
// Initial-camera contract (set in `initState`, recomputed when the
// viewport size changes):
//   - The 128 × 128 surface is scale-fit to ~80% of the smaller
//     viewport axis so the whole board is visible immediately with a
//     visible margin of "outside" all around. Users see the board's
//     identity at a glance instead of staring at a random region.
//   - The canvas is centred in the viewport.
//   - `minScale` lets users zoom out far enough to see the surface
//     and its surroundings clearly; `maxScale` lets a single cell
//     fill ~10% of the viewport for finger-precise painting.
//
// Gesture model. The viewer wraps a `CustomPaint` of the canvas
// surface in a `GestureDetector` that is itself the child of an
// `InteractiveViewer`. Local positions inside the GestureDetector are
// in the un-transformed cell-pixel coordinate space, so the
// `dx / cellSize` floor gives the cell column directly; no inverse-
// matrix math is needed on every tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../services/canvas/canvas_constants.dart';
import '../../../services/canvas/canvas_models.dart';
import 'canvas_grid_painter.dart';

/// Pop-in animation window for freshly-arrived cells. Matches the
/// painter's default [CanvasGridPainter.popDurationMs] and is used by
/// the viewer to know how long to keep the ticker active after the
/// last cell arrival.
const Duration _kPopInDuration = Duration(milliseconds: 320);

/// Default per-cell side length in logical pixels.
///
/// 8 was picked after S7.A's first sim verify showed 4pt cells read
/// as "scattered debug dots" rather than "pixels on a board". With
/// 8pt cells the 128 × 128 canvas is 1024 × 1024 logical points;
/// the initial framed scale (~0.4 on a typical phone) shrinks that
/// to a comfortably-sized board with all cells visible AND each
/// painted cell rendering as a clear ~3pt square at default zoom
/// (jumping to ~24pt at max zoom — finger-friendly).
const double _kDefaultCellSize = 8.0;

/// Minimum scale. MUST stay at or below the smallest plausible
/// initial-framed scale: a 128 x 8 = 1024pt canvas fit to 82% of a
/// 360pt-wide phone needs ~0.29. Picking 0.25 leaves a little
/// breathing room so the framed scale is comfortably inside the
/// allowed range. If minScale > the framed scale, InteractiveViewer
/// silently refuses all pan/zoom gestures (the matrix is in an
/// invalid state) — that broke S7.A sim-verification once and is
/// regression-pinned in canvas_viewer_test ("framed fit honours
/// minScale").
const double _kMinScale = 0.25;
const double _kMaxScale = 24.0;

/// Boundary margin around the canvas. MUST be effectively unbounded:
/// any finite margin clamps the pan-pose check that InteractiveViewer
/// runs on every gesture frame, which manifests as "stuck at max
/// zoom, can only move vertically, can't pinch out." The earlier
/// "feels like the whole screen moves" complaint is solved by giving
/// the host CustomScrollView NeverScrollableScrollPhysics (the strip
/// + chrome stay still regardless of the viewer's pan pose) — NOT by
/// tightening this value. With `infinity` margin + minScale=0.25, the
/// canvas always renders at >=~250pt and can never lock up.
const EdgeInsets _kBoundaryMargin = EdgeInsets.all(double.infinity);

/// Fraction of the smaller viewport axis the initial framed view
/// uses. 0.82 leaves visible margin on every side at first glance —
/// the eye locates the board edge immediately.
const double _kInitialFitFraction = 0.82;

class CanvasViewer extends StatefulWidget {
  /// Painted cells for the canvas currently being rendered. The
  /// repository emits a fresh list reference on every mutation so
  /// the underlying painter's identity-based repaint-skip works.
  final List<CanvasCell> cells;

  /// Indexed palette. The viewer hands it through to the painter and
  /// uses it to resolve the active swatch's preview colour for
  /// debug-overlay-style UI (none in S7.A).
  final List<Color> palette;

  /// Logical canvas dimensions in cells. v0.1: 128 × 128.
  final int widthCells;
  final int heightCells;

  /// Colour rendered in the boundary margin around the canvas
  /// surface — the "outside the board" space the user can pan into.
  final Color outsideColor;

  /// Colour of the canvas surface itself. MUST be tonally distinct
  /// from [outsideColor] so the board edge reads even when empty.
  final Color surfaceColor;

  /// Subtle hairline tone for the 32-cell chunk lattice.
  final Color chunkLineColor;

  /// Soft ring stroke colour drawn around the surface.
  final Color borderColor;

  /// Per-cell side length in logical pixels.
  final double cellSize;

  /// Cells with a pending outbound row in `pending_op`, packed as
  /// `y * widthCells + x`. The painter renders these at reduced
  /// opacity (CANVAS_TRANSMISSION_STATUS_V0_1.md §3.2). Empty for
  /// local-scope viewers — the host gates by scope upstream.
  final Set<int> pendingCellIndices;

  /// Tap-to-paint callback. Fires with `(x, y)` in canvas-cell
  /// coordinates (0..widthCells-1, 0..heightCells-1). Out-of-bounds
  /// taps are filtered before this callback runs.
  ///
  /// §S0.rate.10 cooldowns and §S0.rate.7 vs §S0.rate.8 (local vs
  /// mesh) policy decisions live in the caller, NOT in the viewer —
  /// the viewer's job is to surface raw cell intent.
  final void Function(int x, int y)? onTapPaint;

  /// Long-press-to-inspect callback. Fires with `(x, y)` in canvas-
  /// cell coordinates.
  final void Function(int x, int y)? onLongPressInspect;

  /// Test-only escape hatch. When true, [_applyInitialFraming] is a
  /// no-op and the viewer's transformation stays at identity so
  /// widget tests can tap at unscaled cell-pixel coordinates without
  /// re-deriving the framing transform on every assertion.
  @visibleForTesting
  final bool disableInitialFraming;

  const CanvasViewer({
    super.key,
    required this.cells,
    required this.palette,
    this.widthCells = CanvasGeometry.width,
    this.heightCells = CanvasGeometry.height,
    this.outsideColor = const Color(0xFF0B0D11),
    this.surfaceColor = const Color(0xFF161A22),
    this.chunkLineColor = const Color(0x14FFFFFF),
    this.borderColor = const Color(0x66FFFFFF),
    this.cellSize = _kDefaultCellSize,
    this.onTapPaint,
    this.onLongPressInspect,
    this.disableInitialFraming = false,
    this.pendingCellIndices = const <int>{},
  });

  @override
  State<CanvasViewer> createState() => _CanvasViewerState();
}

class _CanvasViewerState extends State<CanvasViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;

  /// Viewport size last seen by [_applyInitialFraming]. Used so we
  /// only re-frame on actual size changes (orientation flip, sheet
  /// open/close shrinking the screen, etc.), not on every build.
  Size? _lastFramedSize;

  /// Per-cell arrival timestamp map (packed coord -> ms since epoch).
  /// Passed to the painter so each freshly-arrived cell renders with
  /// a center-anchored easeOutBack pop-in over [_kPopInDuration].
  /// Cells present on first build are stamped in the past so they
  /// paint at their settled appearance immediately; cells diffed in
  /// on later builds get the current timestamp and animate.
  final Map<int, int> _cellArrivalMs = {};

  /// Packed-coord set of cells seen on the previous build, used to
  /// diff for new arrivals on the next build.
  Set<int> _lastSeenCellKeys = const {};

  /// Drives painter repaints during the animation window. The
  /// painter subscribes via its `repaint:` super-arg; mutating the
  /// notifier's value forces a frame without going through setState.
  final ValueNotifier<int> _animTick = ValueNotifier<int>(0);

  /// Ticker that pumps [_animTick] each frame while any cell is
  /// mid-animation. Stops itself when the newest arrival is older
  /// than [_kPopInDuration].
  late final Ticker _animTicker;

  /// Most recent cell arrival timestamp; the ticker uses it to know
  /// when to stop pumping frames.
  int _newestArrivalMs = 0;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _animTicker = createTicker(_onAnimTick);
    _seedArrivalsFromInitialCells();
  }

  void _seedArrivalsFromInitialCells() {
    // Initial cells are pre-existing state, not new arrivals. Stamp
    // them just past the animation window so they paint settled on
    // first frame. Subsequent arrivals diffed in didUpdateWidget
    // get a fresh `now` stamp and animate.
    final pastMs =
        DateTime.now().millisecondsSinceEpoch -
        _kPopInDuration.inMilliseconds -
        1;
    final keys = <int>{};
    for (final cell in widget.cells) {
      final key = cell.y * widget.widthCells + cell.x;
      _cellArrivalMs[key] = pastMs;
      keys.add(key);
    }
    _lastSeenCellKeys = keys;
  }

  @override
  void didUpdateWidget(CanvasViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cells reference identity changes whenever the repository emits
    // a new list (the same identity contract the painter relies on).
    if (!identical(oldWidget.cells, widget.cells)) {
      _diffCellsForArrivals();
    }
  }

  void _diffCellsForArrivals() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentKeys = <int>{};
    var hasNewCell = false;
    for (final cell in widget.cells) {
      final key = cell.y * widget.widthCells + cell.x;
      currentKeys.add(key);
      if (!_lastSeenCellKeys.contains(key)) {
        _cellArrivalMs[key] = nowMs;
        hasNewCell = true;
      }
    }
    // Evict arrival entries for cells that vanished (e.g. erased or
    // overwritten by a different colour) so the map stays bounded.
    _cellArrivalMs.removeWhere((key, _) => !currentKeys.contains(key));
    _lastSeenCellKeys = currentKeys;
    if (hasNewCell) {
      _newestArrivalMs = nowMs;
      if (!_animTicker.isActive) {
        _animTicker.start();
      }
    }
  }

  void _onAnimTick(Duration _) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _newestArrivalMs > _kPopInDuration.inMilliseconds) {
      // All cells have settled. Fire one final tick so the painter
      // draws the settled frame, then stop pumping.
      _animTick.value = nowMs;
      _animTicker.stop();
      return;
    }
    _animTick.value = nowMs;
  }

  @override
  void dispose() {
    _animTicker.dispose();
    _animTick.dispose();
    _transformController.dispose();
    super.dispose();
  }

  /// Set the initial transformation so the whole canvas is centred
  /// in [viewport] at a comfortable framed scale. No-op after the
  /// first call for a given viewport size — the user's zoom/pan
  /// gestures survive subsequent rebuilds.
  void _applyInitialFraming(Size viewport) {
    if (widget.disableInitialFraming) return;
    if (viewport.width <= 0 || viewport.height <= 0) return;
    if (_lastFramedSize == viewport) return;
    final canvasW = widget.widthCells * widget.cellSize;
    final canvasH = widget.heightCells * widget.cellSize;
    final rawFitScale =
        (viewport.shortestSide * _kInitialFitFraction) /
        (canvasW < canvasH ? canvasH : canvasW);
    // Defensive clamp. If the framed-fit scale falls outside
    // [_kMinScale, _kMaxScale] the InteractiveViewer's gesture
    // recogniser silently locks (its matrix is in an invalid state),
    // which manifests as "pan/zoom doesn't do anything." This caught
    // me once during S7.A interaction sim-verify when I'd raised
    // _kMinScale above the natural framed-fit value.
    final fitScale = rawFitScale.clamp(_kMinScale, _kMaxScale);
    final scaledW = canvasW * fitScale;
    final scaledH = canvasH * fitScale;
    final tx = (viewport.width - scaledW) / 2;
    final ty = (viewport.height - scaledH) / 2;
    _transformController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(fitScale);
    _lastFramedSize = viewport;
  }

  /// Map a `localPosition` from inside the GestureDetector (which is
  /// the InteractiveViewer's transformed child, so coordinates are
  /// already in cell-pixel space) to a cell `(x, y)` tuple. Returns
  /// null when the point falls outside the canvas grid.
  ({int x, int y})? _hitCell(Offset localPosition) {
    final x = (localPosition.dx / widget.cellSize).floor();
    final y = (localPosition.dy / widget.cellSize).floor();
    if (x < 0 || x >= widget.widthCells) return null;
    if (y < 0 || y >= widget.heightCells) return null;
    return (x: x, y: y);
  }

  @override
  Widget build(BuildContext context) {
    final canvasLogicalSize = Size(
      widget.widthCells * widget.cellSize,
      widget.heightCells * widget.cellSize,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Apply the framed initial camera ONCE per viewport size.
        // Doing this inside LayoutBuilder ensures we have a real
        // viewport before computing the transform. Wrapping in a
        // post-frame callback avoids mutating the controller during
        // layout. Gate the registration on the size actually changing
        // so we never schedule a callback that pumpAndSettle would
        // chase forever during widget tests.
        final viewport = constraints.biggest;
        if (!widget.disableInitialFraming && _lastFramedSize != viewport) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyInitialFraming(viewport);
          });
        }

        return InteractiveViewer(
          transformationController: _transformController,
          minScale: _kMinScale,
          maxScale: _kMaxScale,
          boundaryMargin: _kBoundaryMargin,
          // Constrained = false lets the child render at its
          // intrinsic size and the user pan/zoom freely — without it
          // the canvas would clamp to the viewport which kills the
          // r/place feel.
          constrained: false,
          panEnabled: true,
          scaleEnabled: true,
          child: SizedBox.fromSize(
            size: canvasLogicalSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.onTapPaint == null
                  ? null
                  : (details) {
                      final hit = _hitCell(details.localPosition);
                      if (hit == null) return;
                      widget.onTapPaint!(hit.x, hit.y);
                    },
              onLongPressStart: widget.onLongPressInspect == null
                  ? null
                  : (details) {
                      final hit = _hitCell(details.localPosition);
                      if (hit == null) return;
                      widget.onLongPressInspect!(hit.x, hit.y);
                    },
              child: RepaintBoundary(
                child: CustomPaint(
                  size: canvasLogicalSize,
                  isComplex: true,
                  willChange: false,
                  painter: CanvasGridPainter(
                    cells: widget.cells,
                    palette: widget.palette,
                    cellSize: widget.cellSize,
                    outsideColor: widget.outsideColor,
                    surfaceColor: widget.surfaceColor,
                    chunkLineColor: widget.chunkLineColor,
                    borderColor: widget.borderColor,
                    widthCells: widget.widthCells,
                    heightCells: widget.heightCells,
                    pendingCellIndices: widget.pendingCellIndices,
                    cellArrivalMs: _cellArrivalMs,
                    popDurationMs: _kPopInDuration.inMilliseconds,
                    repaint: _animTick,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
