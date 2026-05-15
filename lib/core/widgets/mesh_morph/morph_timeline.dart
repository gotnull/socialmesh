// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Dart port of rsvpnano's Timeline.cpp. A MorphTimeline is an ordered list
// of keyframes — each keyframe holds a shape for `hold` ms, then morphs
// into the next keyframe over `morph` ms. The sampler maps a wall-clock
// elapsed value onto the timeline and returns:
//   - which shape is the "from"
//   - which shape is the "to"
//   - whether we're holding or morphing
//   - eased interpolation t in [0..1]
//
// The painter uses the sample to pick which two shape buffers to blend
// per-point.

import 'mesh_shape.dart';

/// How morph progress is shaped from 0 → 1.
enum EaseCurve {
  /// Identity — t passes through unchanged.
  linear,

  /// Cubic smoothstep: t·t·(3 − 2t). Soft start, soft end.
  smoothStep,

  /// Quintic smootherstep: 6t⁵ − 15t⁴ + 10t³. Even softer; nice for hero
  /// keyframes where you want a slow "settling" feel.
  smootherStep,

  /// easeOutCubic: 1 − (1−t)³. Fast start, soft end — good for "arrival"
  /// transitions into the final hero shape (e.g. icosahedron).
  easeOutCubic,
}

/// Per-point morph style. Linear is the default; future entries can vary
/// the blend per-point for explode / spiral / dissolve effects.
enum MorphStyle {
  linear,
  // explode, spiral, axisSweep, noiseDissolve, collapseToCenter — TBD.
}

/// One slot in the morph timeline. Holds a shape for `hold`, then morphs
/// to the next keyframe's shape over `morph`. Both durations support
/// per-keyframe overrides so a hero shape can dwell longer than fillers.
class MorphKeyframe {
  final MeshShapeId shape;
  final Duration hold;
  final Duration morph;
  final EaseCurve ease;
  final MorphStyle style;
  // Optional override for whether to render edges during this keyframe's
  // hold. Defaults to "auto": follow whatever the shape's `edges` getter
  // says (null → no edges).
  final bool? showEdgesOverride;

  const MorphKeyframe({
    required this.shape,
    this.hold = const Duration(seconds: 4),
    this.morph = const Duration(seconds: 1),
    this.ease = EaseCurve.smoothStep,
    this.style = MorphStyle.linear,
    this.showEdgesOverride,
  });
}

/// Snapshot the timeline returns each tick. Drives the painter.
class TimelineSample {
  final MeshShapeId from;
  final MeshShapeId to;
  final bool inMorph;
  final double rawT; // 0..1 raw morph progress, 0 outside morph window
  final double easedT; // same range, after ease curve applied
  final MorphStyle style;
  final bool drawEdges; // whether the painter should draw connecting lines

  const TimelineSample({
    required this.from,
    required this.to,
    required this.inMorph,
    required this.rawT,
    required this.easedT,
    required this.style,
    required this.drawEdges,
  });

  /// Convenience for callers that only care about the "current" shape (for
  /// titles, accessibility labels, telemetry). During hold this returns
  /// `from`; during morph it returns whichever side is more than 50%
  /// dominant.
  MeshShapeId get current => !inMorph || easedT < 0.5 ? from : to;
}

/// Whole timeline. Loops automatically — past the last keyframe's morph
/// it wraps to the first keyframe.
class MorphTimeline {
  final List<MorphKeyframe> keyframes;

  /// Optional human-readable id so UIs can offer presets by name without
  /// passing around the keyframe list.
  final String? presetId;

  const MorphTimeline(this.keyframes, {this.presetId});

  /// Total length of one cycle. Useful for progress indicators.
  Duration get cycleLength {
    var total = Duration.zero;
    for (final kf in keyframes) {
      total += kf.hold + kf.morph;
    }
    return total;
  }

  /// Map an elapsed duration onto the timeline. Wraps cyclically.
  TimelineSample sample(Duration elapsed) {
    if (keyframes.isEmpty) {
      return const TimelineSample(
        from: MeshShapeId.cube,
        to: MeshShapeId.cube,
        inMorph: false,
        rawT: 0,
        easedT: 0,
        style: MorphStyle.linear,
        drawEdges: false,
      );
    }
    final cycleMs = cycleLength.inMicroseconds;
    final t = cycleMs == 0 ? 0 : (elapsed.inMicroseconds % cycleMs);
    int cursorMicro = 0;
    for (int k = 0; k < keyframes.length; k++) {
      final kf = keyframes[k];
      final holdEnd = cursorMicro + kf.hold.inMicroseconds;
      final morphEnd = holdEnd + kf.morph.inMicroseconds;
      if (t < morphEnd) {
        final nextKf = keyframes[(k + 1) % keyframes.length];
        final inMorph = t >= holdEnd && kf.morph.inMicroseconds > 0;
        final raw = inMorph ? (t - holdEnd) / kf.morph.inMicroseconds : 0.0;
        final eased = _applyEase(kf.ease, raw);
        final drawEdges = _resolveEdgesFlag(kf, nextKf, inMorph, eased);
        return TimelineSample(
          from: kf.shape,
          to: nextKf.shape,
          inMorph: inMorph,
          rawT: raw,
          easedT: eased,
          style: kf.style,
          drawEdges: drawEdges,
        );
      }
      cursorMicro = morphEnd;
    }
    // Unreachable — cycle math above guarantees we always return inside the
    // loop — but the analyzer wants a fallback path.
    final last = keyframes.last;
    return TimelineSample(
      from: last.shape,
      to: last.shape,
      inMorph: false,
      rawT: 0,
      easedT: 0,
      style: last.style,
      drawEdges: _hasEdges(last),
    );
  }

  // Edges follow the "from" shape during hold (so they appear/disappear
  // as the shape lands), and fade to the "to" shape's edges during morph.
  // Caller decides whether to render — for now the painter just toggles
  // on/off; smooth edge crossfades can be added later if visually wanted.
  bool _resolveEdgesFlag(
    MorphKeyframe kf,
    MorphKeyframe next,
    bool inMorph,
    double easedT,
  ) {
    final fromHas = _hasEdges(kf);
    final toHas = _hasEdges(next);
    if (!inMorph) return fromHas;
    // During morph: switch over at the midpoint so the user sees a clean
    // edge-on/off transition rather than two flickering layers.
    return easedT < 0.5 ? fromHas : toHas;
  }

  bool _hasEdges(MorphKeyframe kf) {
    if (kf.showEdgesOverride != null) return kf.showEdgesOverride!;
    return shapeById(kf.shape).edges != null;
  }

  static double _applyEase(EaseCurve ease, double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    switch (ease) {
      case EaseCurve.linear:
        return t;
      case EaseCurve.smoothStep:
        return t * t * (3 - 2 * t);
      case EaseCurve.smootherStep:
        return t * t * t * (t * (t * 6 - 15) + 10);
      case EaseCurve.easeOutCubic:
        final inv = 1 - t;
        return 1 - inv * inv * inv;
    }
  }
}

/// Per-point morph blend. Future MorphStyle variants would hook in here.
Point3D blendPoint(
  MorphStyle style,
  Point3D from,
  Point3D to,
  double t, {
  int pointIndex = 0,
  int seed = 0,
}) {
  switch (style) {
    case MorphStyle.linear:
      return from.lerp(to, t);
  }
}
