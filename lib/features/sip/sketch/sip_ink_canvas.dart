// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Interactive drawing surface for the SIP Ink composer.
///
/// Captures pan gestures, maps screen pixels to canvas-space integer
/// coordinates, and reports finalized strokes back to the parent.
/// Live in-progress strokes are rendered via [SipInkPainter].
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/protocol/sip/sip_ink_payload.dart';
import '../../../services/protocol/sip/sip_ink_simplifier.dart';
import 'sip_ink_painter.dart';

/// Interactive ink-drawing canvas.
class SipInkCanvas extends StatefulWidget {
  /// Finalised strokes already drawn this session.
  final List<SipInkRawStroke> strokes;

  /// Canvas dimension (matches the wire-level canvas size — typically
  /// 64).
  final int canvasSize;

  /// Width to use when starting a new stroke.
  final int strokeWidth;

  /// Whether new gestures are accepted. Set false while the parent is
  /// in a "send in progress" state to prevent racing strokes.
  final bool enabled;

  /// Called when a stroke ends with at least 2 distinct points.
  final void Function(SipInkRawStroke stroke) onStrokeFinished;

  const SipInkCanvas({
    super.key,
    required this.strokes,
    required this.onStrokeFinished,
    required this.canvasSize,
    this.strokeWidth = 2,
    this.enabled = true,
  });

  @override
  State<SipInkCanvas> createState() => _SipInkCanvasState();
}

class _SipInkCanvasState extends State<SipInkCanvas> {
  /// In-progress stroke: floats in canvas-space (0..canvasSize-1).
  List<({double x, double y})>? _activePoints;

  ({double x, double y})? _toCanvas(Offset local, Size widgetSize) {
    if (widgetSize.width <= 0 || widgetSize.height <= 0) return null;
    final cx = (local.dx / widgetSize.width) * widget.canvasSize;
    final cy = (local.dy / widgetSize.height) * widget.canvasSize;
    return (
      x: cx.clamp(0.0, (widget.canvasSize - 1).toDouble()),
      y: cy.clamp(0.0, (widget.canvasSize - 1).toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Force a square canvas — non-square would distort strokes.
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final size = Size(side, side);
        return SizedBox(
          width: side,
          height: side,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: widget.enabled
                ? (details) {
                    final p = _toCanvas(details.localPosition, size);
                    if (p == null) return;
                    setState(() => _activePoints = [p]);
                  }
                : null,
            onPanUpdate: widget.enabled
                ? (details) {
                    if (_activePoints == null) return;
                    final p = _toCanvas(details.localPosition, size);
                    if (p == null) return;
                    setState(() => _activePoints = [..._activePoints!, p]);
                  }
                : null,
            onPanEnd: widget.enabled
                ? (_) {
                    final pts = _activePoints;
                    if (pts != null && pts.length >= 2) {
                      widget.onStrokeFinished(
                        SipInkRawStroke(width: widget.strokeWidth, points: pts),
                      );
                    }
                    setState(() => _activePoints = null);
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                child: CustomPaint(
                  painter: SipInkPainter(
                    sketch: SipInkSketch(
                      canvasSize: widget.canvasSize,
                      strokes: _toRenderedStrokes(widget.strokes),
                    ),
                    canvasSize: widget.canvasSize,
                    color: context.textPrimary,
                    activePoints: _activePoints,
                    activeWidth: widget.strokeWidth,
                  ),
                  size: size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Quick-and-dirty quantisation of raw float strokes into a sketch
  /// for live preview. Bypasses the simplifier to avoid lag during
  /// drawing — the simplifier runs on send and on counter updates.
  List<SipInkStroke> _toRenderedStrokes(List<SipInkRawStroke> raws) {
    final out = <SipInkStroke>[];
    for (final raw in raws) {
      if (raw.points.length < 2) continue;
      final pts = raw.points
          .map(
            (p) => SipInkPoint(
              p.x.clamp(0.0, (widget.canvasSize - 1).toDouble()).round(),
              p.y.clamp(0.0, (widget.canvasSize - 1).toDouble()).round(),
            ),
          )
          .toList(growable: false);
      out.add(SipInkStroke(width: raw.width, points: pts));
    }
    return out;
  }
}
