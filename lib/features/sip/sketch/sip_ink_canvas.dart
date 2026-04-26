// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Drawing surface for the SIP Ink composer.
///
/// Stateless w.r.t. stroke buffers — the parent owns the active /
/// committed / overflow point lists and feeds them in via props.
/// Gestures bubble up via [onStrokeStart], [onStrokeUpdate], and
/// [onStrokeEnd]. The canvas only handles screen→canvas-space
/// conversion and the painter wiring.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/protocol/sip/sip_ink_payload.dart';
import 'sip_ink_painter.dart';

class SipInkCanvas extends StatelessWidget {
  /// Live simplified sketch. Includes both the finalised draft and
  /// the committed prefix of any in-progress stroke — i.e. exactly
  /// what would travel on the wire if the user stopped drawing right
  /// now. WYSIWYG: the user sees the real wire-truth, not the raw
  /// finger trace.
  final SipInkSketch? simplifiedSketch;

  /// Overflow tail of the active in-progress stroke (drawn but won't
  /// be sent). Raw float points so the cue stays smooth even though
  /// the committed portion is already simplified. Empty when the
  /// stroke fits the budget.
  final List<({double x, double y})> activeOverflow;

  /// True while the user is over-budget. Tints the canvas border red
  /// and switches the surrounding hint copy.
  final bool isOverBudget;

  /// Wire-level canvas dimension (matches the spec — typically 64).
  final int canvasSize;

  /// Width to use when starting a new stroke.
  final int strokeWidth;

  /// Whether new gestures are accepted.
  final bool enabled;

  final void Function(({double x, double y}) point) onStrokeStart;
  final void Function(({double x, double y}) point) onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  const SipInkCanvas({
    super.key,
    required this.simplifiedSketch,
    required this.activeOverflow,
    required this.isOverBudget,
    required this.canvasSize,
    required this.strokeWidth,
    required this.enabled,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  ({double x, double y})? _toCanvas(Offset local, Size widgetSize) {
    if (widgetSize.width <= 0 || widgetSize.height <= 0) return null;
    final cx = (local.dx / widgetSize.width) * canvasSize;
    final cy = (local.dy / widgetSize.height) * canvasSize;
    return (
      x: cx.clamp(0.0, (canvasSize - 1).toDouble()),
      y: cy.clamp(0.0, (canvasSize - 1).toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final size = Size(side, side);
        final overflowColor = Theme.of(context).colorScheme.error;
        final borderColor = isOverBudget
            ? overflowColor.withValues(alpha: 0.7)
            : context.border.withValues(alpha: 0.5);

        return SizedBox(
          width: side,
          height: side,
          child: Listener(
            // Raw pointer events instead of GestureDetector pan
            // recognisers — a single tap (no movement) needs to land
            // a dot, which onPanStart alone doesn't reliably catch
            // because of gesture-arena resolution. Listener fires
            // pointerDown/Move/Up regardless and never competes for
            // the arena, so taps and drags both work.
            onPointerDown: enabled
                ? (event) {
                    final p = _toCanvas(event.localPosition, size);
                    if (p == null) return;
                    onStrokeStart(p);
                  }
                : null,
            onPointerMove: enabled
                ? (event) {
                    final p = _toCanvas(event.localPosition, size);
                    if (p == null) return;
                    onStrokeUpdate(p);
                  }
                : null,
            onPointerUp: enabled ? (_) => onStrokeEnd() : null,
            onPointerCancel: enabled ? (_) => onStrokeEnd() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(
                  color: borderColor,
                  width: isOverBudget ? 1.5 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                child: CustomPaint(
                  painter: SipInkPainter(
                    // Paint the simplified (sendable) state directly —
                    // not the raw finger trace. This is the WYSIWYG
                    // promise: the user sees what would go on the
                    // wire, including how aggressive the simplifier
                    // had to get to fit the budget.
                    sketch: simplifiedSketch,
                    canvasSize: canvasSize,
                    color: context.textPrimary,
                    overflowColor: overflowColor.withValues(alpha: 0.7),
                    activeOverflowPoints: activeOverflow.isEmpty
                        ? null
                        : activeOverflow,
                    activeWidth: strokeWidth,
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
}
