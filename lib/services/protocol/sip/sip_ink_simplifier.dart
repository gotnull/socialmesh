// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP Ink v1 stroke simplifier: deterministic point reduction.
///
/// Pipeline:
/// ```
///   raw points -> quantise to canvas grid -> drop duplicates ->
///   Ramer-Douglas-Peucker -> per-stroke downsample ->
///   enforce delta range -> validate via encoder
/// ```
///
/// The simplifier is purely numerical: same input, same output every
/// time. No randomness, no float accumulation past the integer canvas
/// grid. RDP tolerance starts at [_initialEpsilon] and grows by
/// [_epsilonGrowth] until the encoded payload fits the airtime budget
/// or the cap [_maxEpsilon] is reached.
library;

import 'dart:math' as math;

import '../../../core/logging.dart';
import 'sip_ink_constants.dart';
import 'sip_ink_encoder.dart';
import 'sip_ink_payload.dart';

/// A raw stroke captured from gesture input. Coordinates are floats so
/// the simplifier owns the quantisation step.
class SipInkRawStroke {
  /// Width [1..4].
  final int width;

  /// Raw points in canvas coordinate space (floats accepted).
  final List<({double x, double y})> points;

  const SipInkRawStroke({required this.width, required this.points});
}

/// Why simplification failed.
enum SipInkSimplifyError {
  /// No strokes survived dedup, or every stroke collapsed to fewer than
  /// [SipInkConstants.minPointsPerStroke] points.
  empty,

  /// More strokes than [SipInkConstants.maxStrokes] were submitted.
  tooManyStrokes,

  /// Could not fit the input within budget even at the maximum
  /// tolerance. The composer must block the send and let the user
  /// reduce the sketch.
  budgetExceeded,
}

/// Result of [SipInkSimplifier.simplify].
class SipInkSimplifyResult {
  final SipInkSketch? sketch;
  final SipInkSimplifyError? error;

  const SipInkSimplifyResult._({this.sketch, this.error});

  factory SipInkSimplifyResult.ok(SipInkSketch s) =>
      SipInkSimplifyResult._(sketch: s);

  factory SipInkSimplifyResult.fail(SipInkSimplifyError e) =>
      SipInkSimplifyResult._(error: e);

  bool get isOk => sketch != null;
}

/// Deterministic simplifier for raw stroke input.
abstract final class SipInkSimplifier {
  static const double _initialEpsilon = 0.5;
  static const double _epsilonGrowth = 1.5;
  static const double _maxEpsilon = 16.0;

  /// Reduce [rawStrokes] to an encodable [SipInkSketch].
  static SipInkSimplifyResult simplify({
    required List<SipInkRawStroke> rawStrokes,
    required int canvasSize,
  }) {
    if (rawStrokes.isEmpty) {
      return SipInkSimplifyResult.fail(SipInkSimplifyError.empty);
    }
    if (rawStrokes.length > SipInkConstants.maxStrokes) {
      return SipInkSimplifyResult.fail(SipInkSimplifyError.tooManyStrokes);
    }

    var epsilon = _initialEpsilon;

    while (epsilon <= _maxEpsilon) {
      final strokes = <SipInkStroke>[];
      var totalPoints = 0;
      var allInBudget = true;

      for (final raw in rawStrokes) {
        final quantised = raw.points
            .map(
              (p) => SipInkPoint(
                p.x.clamp(0.0, (canvasSize - 1).toDouble()).round(),
                p.y.clamp(0.0, (canvasSize - 1).toDouble()).round(),
              ),
            )
            .toList(growable: false);

        final dedup = _dedup(quantised);
        if (dedup.length < SipInkConstants.minPointsPerStroke) continue;

        var simplified = _rdp(dedup, epsilon);

        // Per-stroke downsample first, then delta-range enforcement.
        // Downsample can produce neighbouring points further apart than
        // the delta range allows; enforceDeltaRange repairs that by
        // inserting integer midpoints.
        final perStrokeCap =
            SipInkConstants.maxTotalPoints - (totalPoints + strokes.length);
        if (simplified.length > SipInkConstants.maxTotalPoints) {
          simplified = _downsample(simplified, SipInkConstants.maxTotalPoints);
        }
        simplified = _enforceDeltaRange(simplified);

        if (simplified.length < SipInkConstants.minPointsPerStroke) continue;

        // If after midpoint inflation we still have no headroom, mark
        // for retry at higher epsilon rather than silently truncating.
        if (simplified.length > perStrokeCap) {
          allInBudget = false;
          break;
        }

        strokes.add(SipInkStroke(width: raw.width, points: simplified));
        totalPoints += simplified.length;
      }

      if (strokes.isEmpty) {
        return SipInkSimplifyResult.fail(SipInkSimplifyError.empty);
      }

      if (!allInBudget ||
          strokes.length > SipInkConstants.maxStrokes ||
          totalPoints > SipInkConstants.maxTotalPoints) {
        epsilon *= _epsilonGrowth;
        continue;
      }

      final sketch = SipInkSketch(canvasSize: canvasSize, strokes: strokes);
      final encoded = SipInkEncoder.encode(sketch);
      if (encoded.isOk) {
        AppLogging.sipInk(
          'simplify_ok eps=${epsilon.toStringAsFixed(2)} '
          'strokes=${strokes.length} points=$totalPoints '
          'bytes=${encoded.bytes!.length}',
        );
        return SipInkSimplifyResult.ok(sketch);
      }
      AppLogging.sipInk(
        'simplify_retry eps=${epsilon.toStringAsFixed(2)} '
        'reason=${encoded.error?.name}',
      );
      epsilon *= _epsilonGrowth;
    }

    AppLogging.sipInk(
      'simplify_failed reason=budget_exceeded final_eps=${epsilon.toStringAsFixed(2)}',
    );
    return SipInkSimplifyResult.fail(SipInkSimplifyError.budgetExceeded);
  }

  static List<SipInkPoint> _dedup(List<SipInkPoint> points) {
    if (points.isEmpty) return points;
    final out = <SipInkPoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      if (points[i] != out.last) out.add(points[i]);
    }
    return out;
  }

  /// Iterative Ramer-Douglas-Peucker. First and last points are
  /// preserved unconditionally.
  static List<SipInkPoint> _rdp(List<SipInkPoint> points, double epsilon) {
    if (points.length < 3) return List.of(points);
    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    final stack = <(int, int)>[(0, points.length - 1)];
    while (stack.isNotEmpty) {
      final segment = stack.removeLast();
      final start = segment.$1;
      final end = segment.$2;
      if (end - start < 2) continue;
      var maxDist = -1.0;
      var maxIdx = -1;
      final a = points[start];
      final b = points[end];
      for (var i = start + 1; i < end; i++) {
        final d = _perpDist(points[i], a, b);
        if (d > maxDist) {
          maxDist = d;
          maxIdx = i;
        }
      }
      if (maxDist > epsilon && maxIdx > 0) {
        keep[maxIdx] = true;
        stack.add((start, maxIdx));
        stack.add((maxIdx, end));
      }
    }

    final out = <SipInkPoint>[];
    for (var i = 0; i < points.length; i++) {
      if (keep[i]) out.add(points[i]);
    }
    return out;
  }

  static double _perpDist(SipInkPoint p, SipInkPoint a, SipInkPoint b) {
    final dx = (b.x - a.x).toDouble();
    final dy = (b.y - a.y).toDouble();
    if (dx == 0 && dy == 0) {
      final ex = (p.x - a.x).toDouble();
      final ey = (p.y - a.y).toDouble();
      return math.sqrt(ex * ex + ey * ey);
    }
    final num = (dy * p.x - dx * p.y + b.x * a.y - b.y * a.x).abs().toDouble();
    final denom = math.sqrt(dx * dx + dy * dy);
    return num / denom;
  }

  /// Insert integer midpoints between any pair whose delta exceeds the
  /// `[-8..+7]` packing range. Recursive bisection guarantees every
  /// consecutive pair in the output sequence has both deltas in range.
  /// Midpoints use truncated integer division (towards zero) so the
  /// transformation is platform-deterministic.
  static List<SipInkPoint> _enforceDeltaRange(List<SipInkPoint> points) {
    if (points.length < 2) return points;
    final out = <SipInkPoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      _bisectInto(out, out.last, points[i]);
    }
    return out;
  }

  static void _bisectInto(List<SipInkPoint> out, SipInkPoint a, SipInkPoint b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    if (dx >= SipInkConstants.deltaMin &&
        dx <= SipInkConstants.deltaMax &&
        dy >= SipInkConstants.deltaMin &&
        dy <= SipInkConstants.deltaMax) {
      out.add(b);
      return;
    }
    final mid = SipInkPoint(a.x + (dx ~/ 2), a.y + (dy ~/ 2));
    // Both deltas in [-1..1] would have taken the early-return; if we
    // somehow land here with mid == a, clamp to avoid an infinite
    // recursion. Defence-in-depth, not a reachable code path.
    if (mid == a) {
      final cx = a.x + dx.clamp(-1, 1);
      final cy = a.y + dy.clamp(-1, 1);
      out.add(SipInkPoint(cx, cy));
      return;
    }
    _bisectInto(out, a, mid);
    _bisectInto(out, mid, b);
  }

  /// Uniformly downsample to [maxPoints] while keeping endpoints.
  static List<SipInkPoint> _downsample(
    List<SipInkPoint> points,
    int maxPoints,
  ) {
    if (points.length <= maxPoints) return points;
    final out = <SipInkPoint>[];
    final step = (points.length - 1) / (maxPoints - 1);
    for (var i = 0; i < maxPoints; i++) {
      final idx = (i * step).round().clamp(0, points.length - 1);
      out.add(points[idx]);
    }
    return out;
  }
}
