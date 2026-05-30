// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared ambient backdrop for the Handshake onboarding flow.
//
// Draws a calm field of drifting nodes connected by faint signal lines, with
// one brighter "you" node pulsing near the centre. This is the common layer
// behind every onboarding page so the whole flow reads as one continuous
// living mesh rather than a sequence of separate slides.
//
// Motion is intentionally slow and low-density. The single controller pauses
// when the page is offscreen or when the OS requests reduced motion, and the
// painter is wrapped in a RepaintBoundary so it never invalidates the page
// content layered on top.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Ambient drifting-mesh backdrop. Place at the bottom of a Stack and layer
/// page content above it. [accent] tints the lines and the central node so the
/// backdrop can shift colour per page as the flow progresses.
class OnboardingBackdrop extends StatefulWidget {
  const OnboardingBackdrop({
    super.key,
    required this.accent,
    this.active = true,
    this.intensity = 1.0,
  });

  /// Accent colour for lines and the central node glow.
  final Color accent;

  /// When false the animation pauses (page offscreen). Saves battery on the
  /// pages the user is not currently looking at.
  final bool active;

  /// Scales motion amplitude and node brightness. The idle SIP-hub variant
  /// uses a lower value so the empty state feels calmer than the tour.
  final double intensity;

  @override
  State<OnboardingBackdrop> createState() => _OnboardingBackdropState();
}

class _OnboardingBackdropState extends State<OnboardingBackdrop>
    with SingleTickerProviderStateMixin {
  static const int _nodeCount = 18;
  static const Duration _period = Duration(seconds: 14);

  late final AnimationController _controller;
  late final List<_DriftNode> _nodes;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    final random = math.Random(7);
    _nodes = List.generate(_nodeCount, (i) {
      return _DriftNode(
        origin: Offset(random.nextDouble(), random.nextDouble()),
        phase: random.nextDouble() * math.pi * 2,
        speed: 0.7 + random.nextDouble() * 0.9,
        amplitude: 0.05 + random.nextDouble() * 0.09,
        radius: 1.4 + random.nextDouble() * 2.4,
        twinkleSpeed: 0.8 + random.nextDouble() * 1.4,
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
  void didUpdateWidget(OnboardingBackdrop old) {
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
    final base = context.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(widget.accent.withValues(alpha: 0.10), base),
            base,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.18), base),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _MeshPainter(
                nodes: _nodes,
                t: _reduceMotion ? 0.0 : _controller.value,
                accent: widget.accent,
                intensity: widget.intensity,
                reduceMotion: _reduceMotion,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _DriftNode {
  _DriftNode({
    required this.origin,
    required this.phase,
    required this.speed,
    required this.amplitude,
    required this.radius,
    required this.twinkleSpeed,
  });

  // Normalised (0..1) home position.
  final Offset origin;
  final double phase;
  final double speed;
  final double amplitude;
  final double radius;
  final double twinkleSpeed;
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.nodes,
    required this.t,
    required this.accent,
    required this.intensity,
    required this.reduceMotion,
  });

  final List<_DriftNode> nodes;
  final double t;
  final Color accent;
  final double intensity;
  final bool reduceMotion;

  // Connect nodes closer than this fraction of the diagonal.
  static const double _linkDistance = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = <Offset>[];
    for (final node in nodes) {
      // Figure-eight-ish drift: different frequencies on each axis read as
      // organic wandering rather than a flat orbit.
      final angle = node.phase + t * math.pi * 2 * node.speed;
      final dx = math.cos(angle) * node.amplitude * intensity;
      final dy =
          math.sin(angle * 1.6 + node.phase) * node.amplitude * intensity;
      positions.add(
        Offset(
          (node.origin.dx + dx).clamp(0.0, 1.0) * size.width,
          (node.origin.dy + dy).clamp(0.0, 1.0) * size.height,
        ),
      );
    }

    final diagonal = size.shortestSide;
    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        final d = (positions[i] - positions[j]).distance;
        final maxD = diagonal * _linkDistance;
        if (d > maxD) continue;
        final strength = (1 - d / maxD).clamp(0.0, 1.0);
        linkPaint.color = accent.withValues(alpha: 0.10 * strength * intensity);
        canvas.drawLine(positions[i], positions[j], linkPaint);
      }
    }

    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < positions.length; i++) {
      // Each node twinkles - size and brightness breathe at its own rate so
      // the field feels alive instead of a static dot grid.
      final twinkle = reduceMotion
          ? 0.6
          : 0.5 +
                math.sin(
                      t * math.pi * 2 * nodes[i].twinkleSpeed + nodes[i].phase,
                    ) *
                    0.5;
      nodePaint.color = accent.withValues(
        alpha: (0.14 + twinkle * 0.20) * intensity,
      );
      canvas.drawCircle(
        positions[i],
        nodes[i].radius * (0.75 + twinkle * 0.5),
        nodePaint,
      );
    }

    // The brighter "you" node breathes AND drifts in a slow loop near the
    // centre so it never reads as a fixed dot behind the content.
    final breathe = reduceMotion ? 0.6 : 0.5 + math.sin(t * math.pi * 2) * 0.5;
    final driftAngle = t * math.pi * 2;
    final driftRadius = reduceMotion ? 0.0 : size.shortestSide * 0.16;
    final centre = Offset(
      size.width * 0.5 + math.cos(driftAngle) * driftRadius,
      size.height * 0.5 + math.sin(driftAngle * 1.3) * driftRadius,
    );
    final glow = Paint()
      ..color = accent.withValues(alpha: (0.16 + breathe * 0.18) * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + breathe * 10);
    canvas.drawCircle(centre, 6 + breathe * 4, glow);
    canvas.drawCircle(
      centre,
      3.2,
      Paint()..color = accent.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.intensity != intensity ||
      old.reduceMotion != reduceMotion;
}
