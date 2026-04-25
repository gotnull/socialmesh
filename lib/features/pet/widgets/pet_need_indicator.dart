// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetNeedIndicator — a floating hint above the pet that tells the user
// AT A GLANCE what it wants. Hungry → bowl, lonely → heart, sick →
// medical cross, bedtime → crescent moon, boredom → question mark.
// Hygiene is omitted (dirt artefacts already draw on the field).
//
// Visual language matches the MeshNodeBrain creature: a thin hexagonal
// wireframe with glowing edges and a single filled "node" dot, so the
// indicator reads as part of the same mesh graph as the pet itself
// rather than a glass UI sticker pasted over it.
//
// Pulse animation: edge glow + scale fade on a 1.2-second loop — enough
// to catch the eye without pulling focus off the creature.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/pet_enums.dart';

class PetNeedIndicator extends StatefulWidget {
  /// The active call reason. When null, the widget renders `SizedBox`
  /// and does not drive its controller — no animation cost at rest.
  final CallReason? reason;

  /// Creature size in logical pixels. Used to position the bubble
  /// above and slightly to the right of the creature so it reads as
  /// a thought bubble.
  final double creatureSize;

  const PetNeedIndicator({
    super.key,
    required this.reason,
    required this.creatureSize,
  });

  @override
  State<PetNeedIndicator> createState() => _PetNeedIndicatorState();
}

class _PetNeedIndicatorState extends State<PetNeedIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.reason != null) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PetNeedIndicator old) {
    super.didUpdateWidget(old);
    if (widget.reason != null && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (widget.reason == null && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.reason;
    if (reason == null) return const SizedBox.shrink();

    final data = _dataFor(reason);
    // Scale the hex marker with the creature — ~18% of creature size
    // keeps it proportional across hero (220+) and card (96) previews.
    final markerSize = (widget.creatureSize * 0.18).clamp(32.0, 56.0);
    // Position: above + right of creature, in the classic
    // thought-bubble slot. The creature is centered in a
    // `creatureSize × creatureSize` box, so we offset from that
    // origin.
    final offset = Offset(
      widget.creatureSize * 0.26,
      -widget.creatureSize * 0.34,
    );
    return Transform.translate(
      offset: offset,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          final scale = 0.95 + 0.06 * t;
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: markerSize,
              height: markerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(markerSize),
                    painter: _HexMarkerPainter(
                      color: data.color,
                      glow: 0.35 + 0.35 * t,
                    ),
                  ),
                  Icon(
                    data.icon,
                    size: markerSize * 0.42,
                    color: data.color.withValues(alpha: 0.95),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _NeedVisual _dataFor(CallReason reason) {
    switch (reason) {
      case CallReason.hungry:
        return _NeedVisual(Icons.restaurant, AccentColors.yellow);
      case CallReason.lonely:
        return _NeedVisual(Icons.favorite, AccentColors.pink);
      case CallReason.sick:
        return _NeedVisual(Icons.medical_services, AccentColors.red);
      case CallReason.hygiene:
        // Kept for completeness even though the caller usually passes
        // null for hygiene (dirt artefacts handle this visual channel).
        return _NeedVisual(Icons.cleaning_services, AccentColors.teal);
      case CallReason.bedtime:
        return _NeedVisual(Icons.nightlight_round, AccentColors.indigo);
      case CallReason.boredom:
        return _NeedVisual(Icons.sentiment_dissatisfied, AccentColors.lavender);
    }
  }
}

class _NeedVisual {
  final IconData icon;
  final Color color;
  const _NeedVisual(this.icon, this.color);
}

/// Thin hexagonal wireframe marker — mirrors the MeshNodeBrain creature's
/// visual vocabulary (wireframe edges + glowing accent nodes) so the
/// need hint reads as a sibling node in the same graph as the pet.
class _HexMarkerPainter extends CustomPainter {
  final Color color;
  final double glow;

  const _HexMarkerPainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * math.pi * 2 / 6) - math.pi / 2;
      final pt = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    // Soft fill so the icon reads against the creature's glow.
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.14);
    canvas.drawPath(path, fill);

    // Glow: stroke the edge twice — first a blurred wide pass, then
    // a crisp 1px pass — matching MeshNodeBrain's line treatment.
    final glowStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = color.withValues(alpha: glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    canvas.drawPath(path, glowStroke);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withValues(alpha: 0.95);
    canvas.drawPath(path, edge);

    // Single "node" dot at the top vertex — completes the mesh-graph
    // read (edges + node, like the creature's own wireframe).
    final topVertex = Offset(center.dx, center.dy - radius);
    canvas.drawCircle(
      topVertex,
      1.8,
      Paint()..color = color.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _HexMarkerPainter old) =>
      old.color != color || old.glow != glow;
}
