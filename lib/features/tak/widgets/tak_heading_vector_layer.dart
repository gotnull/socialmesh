// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/logging.dart';
import '../models/tak_event.dart';
import '../utils/cot_affiliation.dart';

/// Renders directional heading arrows for TAK entities that have a valid
/// [TakEvent.course] and non-zero [TakEvent.speed].
///
/// Arrows are drawn in screen space using [CustomPaint]. Length scales
/// proportionally with speed, clamped to [_minLength]–[_maxLength].
class TakHeadingVectorLayer extends StatelessWidget {
  /// TAK events to consider for heading vectors.
  final List<TakEvent> events;

  /// Minimum arrow length in logical pixels.
  static const double _minLength = 20;

  /// Maximum arrow length in logical pixels.
  static const double _maxLength = 60;

  /// Speed (m/s) that maps to [_maxLength]. Anything faster caps at max.
  static const double _maxSpeed = 100;

  const TakHeadingVectorLayer({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    // Filter to entities with non-null course AND non-zero speed
    final movingEvents = events.where((e) {
      if (e.course == null) return false;
      if (e.speed == null || e.speed == 0.0) return false;
      if (e.lat == 0.0 && e.lon == 0.0) return false;
      return true;
    }).toList();

    if (movingEvents.isEmpty) return const SizedBox.shrink();

    AppLogging.tak(
      'HeadingVectorLayer: drawing ${movingEvents.length} vectors '
      '(of ${events.length} visible entities)',
    );

    final camera = MapCamera.of(context);

    return CustomPaint(
      size: Size.infinite,
      painter: _HeadingVectorPainter(events: movingEvents, camera: camera),
    );
  }
}

class _HeadingVectorPainter extends CustomPainter {
  final List<TakEvent> events;
  final MapCamera camera;

  _HeadingVectorPainter({required this.events, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    for (final event in events) {
      final course = event.course!;
      final speed = event.speed!;
      final affiliation = parseAffiliation(event.type);
      final color = affiliation.color.withValues(alpha: 0.8);

      // Compute arrow length proportional to speed
      final speedRatio = (speed / TakHeadingVectorLayer._maxSpeed).clamp(
        0.0,
        1.0,
      );
      final length =
          TakHeadingVectorLayer._minLength +
          speedRatio *
              (TakHeadingVectorLayer._maxLength -
                  TakHeadingVectorLayer._minLength);

      // Project entity position to screen coordinates
      final screenOffset = camera.latLngToScreenOffset(
        LatLng(event.lat, event.lon),
      );
      final startX = screenOffset.dx;
      final startY = screenOffset.dy;

      // Compute arrow endpoint using course (0 = north/up)
      // Screen Y axis increases downward, so minus for northward
      final courseRad = course * math.pi / 180;
      final endX = startX + length * math.sin(courseRad);
      final endY = startY - length * math.cos(courseRad);

      // Draw the line
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), linePaint);

      // Draw filled arrow tip (small triangle, 6px wide, 8px tall)
      _drawArrowTip(canvas, color, endX, endY, courseRad);
    }
  }

  void _drawArrowTip(
    Canvas canvas,
    Color color,
    double tipX,
    double tipY,
    double courseRad,
  ) {
    const halfWidth = 3.0; // 6px wide / 2
    const tipHeight = 8.0;

    final tipPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Triangle points relative to the tip, then rotated
    // The tip point is at (tipX, tipY)
    // Base points are tipHeight back along the course direction
    final baseX = tipX - tipHeight * math.sin(courseRad);
    final baseY = tipY + tipHeight * math.cos(courseRad);

    // Perpendicular offset for the two base corners
    final perpX = halfWidth * math.cos(courseRad);
    final perpY = halfWidth * math.sin(courseRad);

    final path = ui.Path()
      ..moveTo(tipX, tipY)
      ..lineTo(baseX + perpX, baseY + perpY)
      ..lineTo(baseX - perpX, baseY - perpY)
      ..close();

    canvas.drawPath(path, tipPaint);
  }

  @override
  bool shouldRepaint(_HeadingVectorPainter oldDelegate) {
    return oldDelegate.events != events || oldDelegate.camera != camera;
  }
}
