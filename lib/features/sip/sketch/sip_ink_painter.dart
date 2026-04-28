// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Shared CustomPainter for SIP Ink sketches.
///
/// Used by both the live composer canvas and the inline message
/// bubble — same rendering, same scaling, same stroke caps. The
/// composer additionally feeds in an "in-budget" active stroke and an
/// optional overflow tail that is rendered as a dashed cue to signal
/// "drawn but won't be sent".
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/protocol/sip/sip_ink_payload.dart';

/// Renders a [SipInkSketch] plus optional in-progress active and
/// overflow tails into the available paint area.
class SipInkPainter extends CustomPainter {
  /// Decoded sketch — committed strokes that will be sent. Null = none.
  final SipInkSketch? sketch;

  /// Committed prefix of the in-progress stroke. Same colour as the
  /// rest of the sketch.
  final List<({double x, double y})>? activePoints;

  /// Overflow tail of the in-progress stroke (the portion that doesn't
  /// fit the airtime budget). Drawn as a dashed line in
  /// [overflowColor]. The first overflow point should be the same
  /// canvas-space position as the last committed point so the visual
  /// stays connected.
  final List<({double x, double y})>? activeOverflowPoints;

  /// Width of in-progress stroke previews.
  final int activeWidth;

  /// Canvas dimension that all stroke coordinates are relative to.
  final int canvasSize;

  /// Stroke colour for committed content.
  final Color color;

  /// Stroke colour for overflow (over-budget) content.
  final Color overflowColor;

  const SipInkPainter({
    required this.sketch,
    required this.canvasSize,
    required this.color,
    required this.overflowColor,
    this.activePoints,
    this.activeOverflowPoints,
    this.activeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / canvasSize;
    final scaleY = size.height / canvasSize;
    final widthScale = scaleX < scaleY ? scaleX : scaleY;

    if (sketch != null) {
      for (final stroke in sketch!.strokes) {
        _paintStroke(
          canvas,
          stroke.points
              .map((p) => Offset(p.x * scaleX, p.y * scaleY))
              .toList(growable: false),
          stroke.width.toDouble() * widthScale,
          color,
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
        color,
      );
    }

    if (activeOverflowPoints != null && activeOverflowPoints!.length >= 2) {
      _paintDashedStroke(
        canvas,
        activeOverflowPoints!
            .map((p) => Offset(p.x * scaleX, p.y * scaleY))
            .toList(growable: false),
        activeWidth.toDouble() * widthScale,
        overflowColor,
      );
    }
  }

  void _paintStroke(
    Canvas canvas,
    List<Offset> offsets,
    double strokeWidth,
    Color paintColor,
  ) {
    if (offsets.isEmpty) return;
    final paint = Paint()
      ..color = paintColor
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

  /// Renders a dashed line through [offsets]. Dash + gap lengths scale
  /// with [strokeWidth] so the cue stays visually consistent across
  /// different canvas sizes.
  void _paintDashedStroke(
    Canvas canvas,
    List<Offset> offsets,
    double strokeWidth,
    Color paintColor,
  ) {
    if (offsets.length < 2) return;
    final paint = Paint()
      ..color = paintColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..strokeWidth = strokeWidth;

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    final dashLen = math.max(3.0, strokeWidth * 1.6);
    final gapLen = math.max(2.5, strokeWidth * 1.2);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SipInkPainter old) {
    return !identical(old.sketch, sketch) ||
        !identical(old.activePoints, activePoints) ||
        !identical(old.activeOverflowPoints, activeOverflowPoints) ||
        old.activeWidth != activeWidth ||
        old.canvasSize != canvasSize ||
        old.color != color ||
        old.overflowColor != overflowColor;
  }
}
