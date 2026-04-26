// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Shared CustomPainter for SIP Ink sketches.
///
/// Used by both the live composer canvas and the inline message
/// bubble — same rendering, same scaling, same stroke caps.
library;

import 'package:flutter/material.dart';

import '../../../services/protocol/sip/sip_ink_payload.dart';

/// Renders a [SipInkSketch] into the available canvas size.
///
/// Strokes are drawn with rounded caps and joins for a soft, ink-like
/// feel. The painter scales canvas-space coordinates (0..canvasSize-1)
/// to the widget's pixel size on every paint, so it works at any
/// display dimension.
class SipInkPainter extends CustomPainter {
  /// The decoded sketch to render. Null means "render nothing".
  final SipInkSketch? sketch;

  /// In-progress raw stroke captured during a drag. Coordinates are in
  /// canvas space (0..canvasSize-1). Drawn on top of [sketch].
  final List<({double x, double y})>? activePoints;

  /// Width of the [activePoints] preview (only used when activePoints
  /// is non-null and has at least 2 entries).
  final int activeWidth;

  /// Canvas dimension that all stroke coordinates are relative to.
  final int canvasSize;

  /// Stroke colour — typically `context.textPrimary` for the composer
  /// and `context.accentColor` for outbound bubbles.
  final Color color;

  const SipInkPainter({
    required this.sketch,
    required this.canvasSize,
    required this.color,
    this.activePoints,
    this.activeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / canvasSize;
    final scaleY = size.height / canvasSize;
    // Use the smaller of the two scales for stroke width so circles
    // stay round on non-square paint regions.
    final widthScale = scaleX < scaleY ? scaleX : scaleY;

    if (sketch != null) {
      for (final stroke in sketch!.strokes) {
        _paintStroke(
          canvas,
          stroke.points
              .map((p) => Offset(p.x * scaleX, p.y * scaleY))
              .toList(growable: false),
          stroke.width.toDouble() * widthScale,
        );
      }
    }

    if (activePoints != null && activePoints!.length >= 2) {
      _paintStroke(
        canvas,
        activePoints!
            .map((p) => Offset(p.x * scaleX, p.y * scaleY))
            .toList(growable: false),
        activeWidth.toDouble() * widthScale,
      );
    }
  }

  void _paintStroke(Canvas canvas, List<Offset> offsets, double strokeWidth) {
    if (offsets.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..strokeWidth = strokeWidth;

    if (offsets.length == 1) {
      canvas.drawCircle(
        offsets.first,
        strokeWidth / 2.0,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SipInkPainter old) {
    return !identical(old.sketch, sketch) ||
        !identical(old.activePoints, activePoints) ||
        old.activeWidth != activeWidth ||
        old.canvasSize != canvasSize ||
        old.color != color;
  }
}
