// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Radar sweep visual used by the discovery onboarding page and reused as the
// ambient layer behind the SIP-hub "waiting for nearby peers" empty state.
//
// Draws concentric range rings, a slow rotating sweep wedge, and a handful of
// synthetic discovery blips that brighten as the sweep passes over them. The
// blips are ambient atmosphere only: they are never real peers and carry no
// labels, so an empty mesh still feels alive without implying contacts exist.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A calm radar sweep. Place inside a sized box or as a Stack background.
class RadarSweep extends StatefulWidget {
  const RadarSweep({
    super.key,
    required this.accent,
    this.active = true,
    this.intensity = 1.0,
  });

  final Color accent;
  final bool active;

  /// Scales blip brightness and ring opacity. The empty-state variant uses a
  /// lower value so it reads quieter than the onboarding tour.
  final double intensity;

  @override
  State<RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<RadarSweep>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(seconds: 6);

  late final AnimationController _controller;
  late final List<_Blip> _blips;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    final random = math.Random(11);
    _blips = List.generate(5, (i) {
      return _Blip(
        angle: random.nextDouble() * math.pi * 2,
        radius: 0.35 + random.nextDouble() * 0.5,
        size: 2.2 + random.nextDouble() * 2.4,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncMotion();
  }

  @override
  void didUpdateWidget(RadarSweep old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _syncMotion();
  }

  void _syncMotion() {
    if (widget.active && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RadarPainter(
              t: _reduceMotion ? 0.0 : _controller.value,
              accent: widget.accent,
              blips: _blips,
              intensity: widget.intensity,
              reduceMotion: _reduceMotion,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Blip {
  _Blip({required this.angle, required this.radius, required this.size});

  final double angle;
  final double radius;
  final double size;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.t,
    required this.accent,
    required this.blips,
    required this.intensity,
    required this.reduceMotion,
  });

  final double t;
  final Color accent;
  final List<_Blip> blips;
  final double intensity;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;

    // Range rings.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 1; i <= 3; i++) {
      ringPaint.color = accent.withValues(alpha: 0.10 * intensity);
      canvas.drawCircle(centre, maxRadius * (i / 3), ringPaint);
    }

    // Rotating sweep wedge.
    final sweepAngle = t * math.pi * 2;
    final sweepRect = Rect.fromCircle(center: centre, radius: maxRadius);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + math.pi / 2,
        colors: [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.18 * intensity),
        ],
        transform: GradientRotation(0),
      ).createShader(sweepRect);
    if (!reduceMotion) {
      canvas.drawCircle(centre, maxRadius, sweepPaint);
    }

    // Synthetic discovery blips. Brighten as the sweep passes their angle.
    final blipPaint = Paint()..style = PaintingStyle.fill;
    for (final blip in blips) {
      // Distance (0..1) from the leading edge of the sweep to the blip angle.
      final delta = ((blip.angle - sweepAngle) % (math.pi * 2)) / (math.pi * 2);
      final freshness = reduceMotion ? 0.5 : (1 - delta).clamp(0.0, 1.0);
      final pos =
          centre +
          Offset(math.cos(blip.angle), math.sin(blip.angle)) *
              (maxRadius * blip.radius);
      blipPaint.color = accent.withValues(
        alpha: (0.15 + freshness * 0.5) * intensity,
      );
      canvas.drawCircle(pos, blip.size * (0.7 + freshness * 0.6), blipPaint);
    }

    // Centre node.
    canvas.drawCircle(
      centre,
      3.0,
      Paint()..color = accent.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.intensity != intensity ||
      old.reduceMotion != reduceMotion;
}
