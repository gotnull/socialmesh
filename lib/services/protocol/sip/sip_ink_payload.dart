// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP Ink v1 in-memory value types.
///
/// These are produced by [SipInkSimplifier] / [SipInkDecoder] and
/// consumed by [SipInkEncoder] / `SipInkPainter`. The wire format is
/// owned by `sip_ink_constants.dart` and the codec files.
library;

import 'sip_ink_constants.dart';

/// A single integer point on the sketch canvas.
///
/// Coordinates are 0-indexed. Both axes share the same range:
/// `0 <= x < canvasSize` and `0 <= y < canvasSize`.
class SipInkPoint {
  final int x;
  final int y;

  const SipInkPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SipInkPoint && other.x == x && other.y == y);

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'SipInkPoint($x,$y)';
}

/// A single stroke: an ordered list of points with a fixed width.
///
/// `points.length >= [SipInkConstants.minPointsPerStroke]`. Width is in
/// `[SipInkConstants.minStrokeWidth, SipInkConstants.maxStrokeWidth]`.
class SipInkStroke {
  final int width;
  final List<SipInkPoint> points;

  const SipInkStroke({required this.width, required this.points});
}

/// A decoded sketch ready to render or re-encode.
class SipInkSketch {
  /// Canvas dimension in pixels — either
  /// [SipInkConstants.canvas64] or [SipInkConstants.canvas128].
  final int canvasSize;

  /// Strokes in draw order. `1 <= strokes.length <=
  /// [SipInkConstants.maxStrokes]`.
  final List<SipInkStroke> strokes;

  const SipInkSketch({required this.canvasSize, required this.strokes});

  /// Total point count across all strokes.
  int get totalPointCount =>
      strokes.fold<int>(0, (acc, s) => acc + s.points.length);
}
