// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Public widget for morphing through a sequence of 3D mesh shapes. Wraps
// the painter + timeline + shape buffers behind a clean API:
//
//     MeshMorphWidget(
//       size: 372,
//       sequence: MeshMorphPresets.icosahedronJourney,
//     )
//
// Architecturally a sibling of `AnimatedMeshNode`. AnimatedMeshNode keeps
// rendering the static icosahedron splash logo; this widget is for use
// cases that want the animated rsvpnano-style shape morph (about/credits
// screens, splash variants, settings preview, debug toy, etc).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:socialmesh/core/logging.dart';

import 'mesh_morph_painter.dart';
import 'mesh_shape.dart';
import 'morph_timeline.dart';
import 'morph_presets.dart';

/// Tumble axis preset — same names as AnimatedMeshNode's so callers can
/// switch between the static logo and the morph widget without re-thinking
/// rotation behaviour.
enum MorphRotationStyle {
  /// Static — no rotation applied.
  none,

  /// Slow continuous Y-axis spin.
  spin,

  /// Multi-axis slow tumble — matches the SocialMesh splash logo feel.
  tumble,

  /// Faster Y spin with a slight X wobble — more "demo" energy.
  showcase,
}

class MeshMorphWidget extends StatefulWidget {
  /// Side length of the widget (square).
  final double size;

  /// The morph sequence to play. Loops automatically. Pick a built-in from
  /// [MeshMorphPresets] or hand-roll a [MorphTimeline].
  final MorphTimeline sequence;

  /// Number of points to feed the painter. Range is enforced [12, 216].
  final int pointCount;

  /// Whether to run the animation. Set false in tests / when off-screen
  /// to save battery.
  final bool animate;

  /// How (or whether) to spin the mesh while it morphs.
  final MorphRotationStyle rotationStyle;

  /// Manual rotation overrides, added to whatever [rotationStyle] produces.
  final double externalRotationX;
  final double externalRotationY;
  final double externalRotationZ;

  /// Fired when the timeline wraps back to keyframe 0 (one full cycle).
  final VoidCallback? onCycleComplete;

  /// Reports the active shape any time it changes.
  final ValueChanged<MeshShapeId>? onShapeChanged;

  const MeshMorphWidget({
    super.key,
    required this.size,
    required this.sequence,
    this.pointCount = 60,
    this.animate = true,
    this.rotationStyle = MorphRotationStyle.tumble,
    this.externalRotationX = 0,
    this.externalRotationY = 0,
    this.externalRotationZ = 0,
    this.onCycleComplete,
    this.onShapeChanged,
  });

  /// Convenience: build a widget pre-wired to one of the named presets.
  factory MeshMorphWidget.preset(
    MeshMorphPresetId id, {
    Key? key,
    required double size,
    int pointCount = 60,
    bool animate = true,
    MorphRotationStyle rotationStyle = MorphRotationStyle.tumble,
    VoidCallback? onCycleComplete,
    ValueChanged<MeshShapeId>? onShapeChanged,
  }) => MeshMorphWidget(
    key: key,
    size: size,
    sequence: MeshMorphPresets.byId(id),
    pointCount: pointCount,
    animate: animate,
    rotationStyle: rotationStyle,
    onCycleComplete: onCycleComplete,
    onShapeChanged: onShapeChanged,
  );

  @override
  State<MeshMorphWidget> createState() => _MeshMorphWidgetState();
}

class _MeshMorphWidgetState extends State<MeshMorphWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  // Two pre-allocated shape buffers + the per-frame blend buffer. Reused
  // across frames; the painter mutates them in place and we never new
  // List<Point3D> on the hot path.
  late List<Point3D> _bufferFrom;
  late List<Point3D> _bufferTo;
  late List<Point3D> _bufferBlended;
  MeshShapeId? _bufferFromShape;
  MeshShapeId? _bufferToShape;

  MeshShapeId? _lastReportedShape;

  late int _clampedPointCount;

  // Throttle counters so the diagnostic log only emits once per second
  // rather than every animation frame.
  int _lastLoggedSecond = -1;
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _clampedPointCount = widget.pointCount.clamp(12, 216);
    _allocateBuffers();
    _ticker = createTicker(_onTick)..start();
    AppLogging.adminDiag(
      'MeshMorph init: points=$_clampedPointCount '
      'keyframes=${widget.sequence.keyframes.length} '
      'cycle=${widget.sequence.cycleLength.inMilliseconds}ms '
      'animate=${widget.animate} rotation=${widget.rotationStyle.name} '
      'tickerActive=${_ticker.isActive} tickerMuted=${_ticker.muted}',
    );
  }

  @override
  void didUpdateWidget(MeshMorphWidget old) {
    super.didUpdateWidget(old);
    final newCount = widget.pointCount.clamp(12, 216);
    if (newCount != _clampedPointCount) {
      AppLogging.adminDiag(
        'MeshMorph reconfigure: pointCount $_clampedPointCount -> $newCount',
      );
      _clampedPointCount = newCount;
      _allocateBuffers();
    }
    if (widget.animate != old.animate) {
      AppLogging.adminDiag(
        'MeshMorph animate toggled: ${old.animate} -> ${widget.animate}',
      );
      if (widget.animate && !_ticker.isActive) {
        _ticker.start();
      } else if (!widget.animate && _ticker.isActive) {
        _ticker.stop();
      }
    }
    if (!identical(widget.sequence, old.sequence)) {
      AppLogging.adminDiag(
        'MeshMorph sequence swapped: '
        'cycle=${widget.sequence.cycleLength.inMilliseconds}ms '
        'keyframes=${widget.sequence.keyframes.length}',
      );
    }
    if (widget.rotationStyle != old.rotationStyle) {
      AppLogging.adminDiag(
        'MeshMorph rotation swapped: '
        '${old.rotationStyle.name} -> ${widget.rotationStyle.name}',
      );
    }
  }

  @override
  void dispose() {
    AppLogging.adminDiag(
      'MeshMorph dispose: ticks=$_tickCount '
      'finalElapsedMs=${_elapsed.inMilliseconds}',
    );
    _ticker.dispose();
    super.dispose();
  }

  void _allocateBuffers() {
    _bufferFrom = List<Point3D>.filled(
      _clampedPointCount,
      const Point3D(0, 0, 0),
    );
    _bufferTo = List<Point3D>.filled(
      _clampedPointCount,
      const Point3D(0, 0, 0),
    );
    _bufferBlended = List<Point3D>.filled(
      _clampedPointCount,
      const Point3D(0, 0, 0),
    );
    _bufferFromShape = null;
    _bufferToShape = null;
  }

  void _onTick(Duration t) {
    if (!widget.animate) return;
    _tickCount++;
    // Detect cycle wrap — fire onCycleComplete when we cross back to t=0
    // (within one frame of duration).
    final cycle = widget.sequence.cycleLength;
    if (cycle > Duration.zero) {
      final prev = _elapsed.inMicroseconds % cycle.inMicroseconds;
      _elapsed = t;
      final next = _elapsed.inMicroseconds % cycle.inMicroseconds;
      if (next < prev) {
        widget.onCycleComplete?.call();
      }
    } else {
      _elapsed = t;
    }
    final secondsBucket = _elapsed.inSeconds;
    if (secondsBucket != _lastLoggedSecond) {
      _lastLoggedSecond = secondsBucket;
      final sample = widget.sequence.sample(_elapsed);
      final rot = _resolveRotation();
      AppLogging.adminDiag(
        'MeshMorph tick: t=${_elapsed.inMilliseconds}ms ticks=$_tickCount '
        'from=${sample.from.name} to=${sample.to.name} '
        'inMorph=${sample.inMorph} easedT=${sample.easedT.toStringAsFixed(3)} '
        'rotX=${rot.x.toStringAsFixed(2)} '
        'rotY=${rot.y.toStringAsFixed(2)} '
        'rotZ=${rot.z.toStringAsFixed(2)}',
      );
    }
    setState(() {}); // repaint
  }

  // Lazy fill: only regenerate a shape's buffer if the timeline asks for
  // a different shape than what's currently cached. Cheap when the
  // timeline stays in a hold; small one-time cost on shape advance.
  void _ensureShapeBuffer(
    MeshShapeId id,
    List<Point3D> buf,
    void Function(MeshShapeId) cache,
  ) {
    final cached = identical(buf, _bufferFrom)
        ? _bufferFromShape
        : _bufferToShape;
    if (cached == id) return;
    shapeById(id).fill(buf);
    cache(id);
  }

  /// Compute rotation angles for this frame based on rotationStyle +
  /// external overrides.
  ({double x, double y, double z}) _resolveRotation() {
    if (!widget.animate || widget.rotationStyle == MorphRotationStyle.none) {
      return (
        x: widget.externalRotationX,
        y: widget.externalRotationY,
        z: widget.externalRotationZ,
      );
    }
    final s = _elapsed.inMilliseconds / 1000.0;
    switch (widget.rotationStyle) {
      case MorphRotationStyle.none:
        return (
          x: widget.externalRotationX,
          y: widget.externalRotationY,
          z: widget.externalRotationZ,
        );
      case MorphRotationStyle.spin:
        return (
          x: widget.externalRotationX,
          y: widget.externalRotationY + s * 0.6,
          z: widget.externalRotationZ,
        );
      case MorphRotationStyle.tumble:
        return (
          x: widget.externalRotationX + s * 0.25,
          y: widget.externalRotationY + s * 0.4,
          z: widget.externalRotationZ + s * 0.10,
        );
      case MorphRotationStyle.showcase:
        return (
          x: widget.externalRotationX + math.sin(s * 0.6) * 0.35,
          y: widget.externalRotationY + s * 0.9,
          z: widget.externalRotationZ,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sample = widget.sequence.sample(_elapsed);

    // Refill source / target buffers only when the shape identity changes.
    _ensureShapeBuffer(sample.from, _bufferFrom, (id) => _bufferFromShape = id);
    _ensureShapeBuffer(sample.to, _bufferTo, (id) => _bufferToShape = id);

    // Blend into _bufferBlended in place.
    final blended = _bufferBlended;
    final from = _bufferFrom;
    final to = _bufferTo;
    final t = sample.easedT;
    if (!sample.inMorph || t <= 0) {
      for (int i = 0; i < blended.length; i++) {
        blended[i] = from[i];
      }
    } else if (t >= 1) {
      for (int i = 0; i < blended.length; i++) {
        blended[i] = to[i];
      }
    } else {
      for (int i = 0; i < blended.length; i++) {
        blended[i] = blendPoint(sample.style, from[i], to[i], t, pointIndex: i);
      }
    }

    // Fire onShapeChanged when the visible shape rolls over.
    final currentShape = sample.current;
    if (_lastReportedShape != currentShape) {
      _lastReportedShape = currentShape;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onShapeChanged?.call(currentShape);
      });
    }

    final rot = _resolveRotation();

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: MeshMorphPainter(
          blended: blended,
          rotationX: rot.x,
          rotationY: rot.y,
          rotationZ: rot.z,
        ),
      ),
    );
  }
}
