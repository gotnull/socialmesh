// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../node_color.dart';
import '../theme.dart';

/// The node marker drawn on every map, for any protocol: a circle filled with
/// the node's identity colour and labelled with its short label. The own node
/// pulses; a stale node keeps its colour and shows a "?" badge so it never
/// ghosts away with age. [badge] sits top-right for anything a protocol needs
/// to add, such as a MeshCore contact's type.
///
/// Size comes from the parent (the map Marker's width and height).
class NodeCircleMarker extends StatefulWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final bool isStale;
  final bool pulse;
  final Widget? badge;

  const NodeCircleMarker({
    super.key,
    required this.color,
    required this.label,
    this.isSelected = false,
    this.isStale = false,
    this.pulse = false,
    this.badge,
  });

  @override
  State<NodeCircleMarker> createState() => _NodeCircleMarkerState();
}

class _NodeCircleMarkerState extends State<NodeCircleMarker>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat();
      _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeOut),
      );
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final labelColor = nodeContrastColor(color);

    final marker = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: widget.isSelected
            ? Border.all(
                color: Colors.white,
                width: 3,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : null,
        boxShadow: [
          // Coloured glow for selection emphasis.
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: widget.isSelected ? 12 : 6,
            spreadRadius: widget.isSelected ? 2 : 0,
          ),
          // Dark drop shadow defines the circle edge against same-toned map
          // terrain so the marker never blends into the background.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // FittedBox keeps long labels or wide grapheme clusters from
          // overflowing the circle.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: widget.isSelected ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  // Black-or-white by the fill's luminance so the label stays
                  // legible on any per-node colour.
                  color: labelColor,
                ),
              ),
            ),
          ),
          if (widget.badge != null)
            Positioned(top: 0, right: 0, child: widget.badge!),
          // Stale indicator (small question mark overlay).
          if (widget.isStale)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.card, width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!widget.pulse || _pulseAnimation == null) return marker;

    return AnimatedBuilder(
      animation: _pulseAnimation!,
      builder: (context, child) {
        final value = _pulseAnimation!.value;
        return CustomPaint(
          painter: _PulseRingPainter(color: color, progress: value),
          child: child,
        );
      },
      child: marker,
    );
  }
}

/// Expanding ring drawn behind the own-node marker to draw the eye to "you".
class _PulseRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _PulseRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 + 10;
    final radius = size.width / 2 + (maxRadius - size.width / 2) * progress;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5 * (1.0 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1.0 - progress);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
