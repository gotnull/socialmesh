// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:socialmesh/core/theme.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ar_engine.dart';
import '../ar_state.dart';

/// Compact radar widget showing nearby nodes in a circular view
/// Can be embedded in other screens (map, nodes list, etc.)
class ARMiniRadar extends ConsumerWidget {
  final double size;
  final double maxRange; // in meters
  final VoidCallback? onTap;
  final VoidCallback? onExpand;

  const ARMiniRadar({
    super.key,
    this.size = 150,
    this.maxRange = 5000,
    this.onTap,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arState = ref.watch(arStateProvider);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onExpand,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.8),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: _MiniRadarPainter(
              heading: arState.orientation.heading,
              nodes: arState.nodes,
              maxRange: maxRange,
            ),
            size: Size(size, size),
          ),
        ),
      ),
    );
  }
}

class _MiniRadarPainter extends CustomPainter {
  final double heading;
  final List<ARWorldNode> nodes;
  final double maxRange;

  _MiniRadarPainter({
    required this.heading,
    required this.nodes,
    required this.maxRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw range rings
    _drawRangeRings(canvas, center, radius);

    // Draw heading indicator
    _drawHeadingIndicator(canvas, center, radius);

    // Draw cardinal directions
    _drawCardinalDirections(canvas, center, radius);

    // Draw sweep effect
    _drawSweep(canvas, center, radius);

    // Draw nodes
    _drawNodes(canvas, center, radius);

    // Draw center dot (user position)
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF00FF88));

    // Draw field of view indicator
    _drawFovIndicator(canvas, center, radius);
  }

  void _drawRangeRings(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw 3 range rings
    for (var i = 1; i <= 3; i++) {
      final ringRadius = radius * i / 3;
      canvas.drawCircle(center, ringRadius, paint);
    }
  }

  void _drawHeadingIndicator(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    // North indicator at top (accounting for heading rotation)
    final northAngle = -heading * math.pi / 180 - math.pi / 2;
    final indicatorDistance = radius - 8;
    final indicatorPos = Offset(
      center.dx + math.cos(northAngle) * indicatorDistance,
      center.dy + math.sin(northAngle) * indicatorDistance,
    );

    // Draw triangle pointing outward
    final path = Path();
    final size = 6.0;
    path.moveTo(
      indicatorPos.dx + math.cos(northAngle) * size,
      indicatorPos.dy + math.sin(northAngle) * size,
    );
    path.lineTo(
      indicatorPos.dx + math.cos(northAngle + 2.5) * size,
      indicatorPos.dy + math.sin(northAngle + 2.5) * size,
    );
    path.lineTo(
      indicatorPos.dx + math.cos(northAngle - 2.5) * size,
      indicatorPos.dy + math.sin(northAngle - 2.5) * size,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawCardinalDirections(Canvas canvas, Offset center, double radius) {
    final textStyle = TextStyle(
      color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
      fontSize: 8,
      fontWeight: FontWeight.bold,
      fontFamily: AppTheme.fontFamily,
    );

    final directions = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final angle = -heading * math.pi / 180 + i * math.pi / 2 - math.pi / 2;
      final pos = Offset(
        center.dx + math.cos(angle) * (radius - 20),
        center.dy + math.sin(angle) * (radius - 20),
      );

      final textPainter = TextPainter(
        text: TextSpan(text: directions[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }
  }

  void _drawSweep(Canvas canvas, Offset center, double radius) {
    // Rotating sweep line (could be animated)
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Draw sweep sector
    final sweepAngle = math.pi / 4; // 45 degrees
    final startAngle = -math.pi / 2; // Start from top

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      true,
      sweepPaint,
    );
  }

  void _drawFovIndicator(Canvas canvas, Offset center, double radius) {
    // Field of view lines (60 degrees)
    final fovAngle = 30 * math.pi / 180; // Half of 60 degrees
    final startAngle = -math.pi / 2; // Pointing up (forward direction)

    final paint = Paint()
      ..color = const Color(0xFF00FF88).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Left FOV line
    canvas.drawLine(
      center,
      Offset(
        center.dx + math.cos(startAngle - fovAngle) * radius,
        center.dy + math.sin(startAngle - fovAngle) * radius,
      ),
      paint,
    );

    // Right FOV line
    canvas.drawLine(
      center,
      Offset(
        center.dx + math.cos(startAngle + fovAngle) * radius,
        center.dy + math.sin(startAngle + fovAngle) * radius,
      ),
      paint,
    );
  }

  void _drawNodes(Canvas canvas, Offset center, double radius) {
    for (final node in nodes) {
      final distance = node.worldPosition.distance;
      if (distance > maxRange) continue;

      // Calculate position on radar
      // Bearing is relative to north, we need to account for current heading
      final relativeBearing = node.worldPosition.bearing - heading;
      final angle = relativeBearing * math.pi / 180 - math.pi / 2;

      // Scale distance to fit radar
      final scaledDistance = (distance / maxRange) * radius;

      final nodePos = Offset(
        center.dx + math.cos(angle) * scaledDistance,
        center.dy + math.sin(angle) * scaledDistance,
      );

      // Get node color based on threat level
      final color = _getNodeColor(node.threatLevel);

      // Draw node glow
      canvas.drawCircle(
        nodePos,
        6,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Draw node dot
      canvas.drawCircle(nodePos, 3, Paint()..color = color);

      // Pulse animation for new or warning nodes
      if (node.isNew || node.threatLevel == ARThreatLevel.warning) {
        canvas.drawCircle(
          nodePos,
          5,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  Color _getNodeColor(ARThreatLevel level) {
    switch (level) {
      case ARThreatLevel.normal:
        return const Color(0xFF00E5FF);
      case ARThreatLevel.info:
        return const Color(0xFF00FF88);
      case ARThreatLevel.warning:
        return const Color(0xFFFFAB00);
      case ARThreatLevel.critical:
        return const Color(0xFFFF1744);
      case ARThreatLevel.offline:
        return const Color(0xFF757575);
    }
  }

  @override
  bool shouldRepaint(_MiniRadarPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.nodes != nodes ||
        oldDelegate.maxRange != maxRange;
  }
}

/// Animated mini radar with sweep effect
class ARAnimatedMiniRadar extends ConsumerStatefulWidget {
  final double size;
  final double maxRange;
  final VoidCallback? onTap;
  final VoidCallback? onExpand;

  const ARAnimatedMiniRadar({
    super.key,
    this.size = 150,
    this.maxRange = 5000,
    this.onTap,
    this.onExpand,
  });

  @override
  ConsumerState<ARAnimatedMiniRadar> createState() =>
      _ARAnimatedMiniRadarState();
}

class _ARAnimatedMiniRadarState extends ConsumerState<ARAnimatedMiniRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arState = ref.watch(arStateProvider);

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onExpand,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.8),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: AnimatedBuilder(
            animation: _sweepController,
            builder: (context, _) {
              return CustomPaint(
                painter: _AnimatedMiniRadarPainter(
                  heading: arState.orientation.heading,
                  nodes: arState.nodes,
                  maxRange: widget.maxRange,
                  sweepAngle: _sweepController.value * 2 * math.pi,
                ),
                size: Size(widget.size, widget.size),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedMiniRadarPainter extends CustomPainter {
  final double heading;
  final List<ARWorldNode> nodes;
  final double maxRange;
  final double sweepAngle;

  _AnimatedMiniRadarPainter({
    required this.heading,
    required this.nodes,
    required this.maxRange,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw range rings
    final ringPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, ringPaint);
    }

    // Draw animated sweep
    final sweepGradient = SweepGradient(
      startAngle: sweepAngle - math.pi / 2,
      endAngle: sweepAngle - math.pi / 2 + math.pi / 3,
      colors: [
        const Color(0xFF00E5FF).withValues(alpha: 0.4),
        Colors.transparent,
      ],
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = sweepGradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        ),
    );

    // Draw trailing fade
    for (var i = 1; i <= 5; i++) {
      final trailAngle = sweepAngle - (i * math.pi / 20);
      final opacity = (1 - i / 5) * 0.2;

      final trailEnd = Offset(
        center.dx + math.cos(trailAngle - math.pi / 2) * radius,
        center.dy + math.sin(trailAngle - math.pi / 2) * radius,
      );

      canvas.drawLine(
        center,
        trailEnd,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: opacity)
          ..strokeWidth = 1,
      );
    }

    // Draw sweep line
    final sweepEnd = Offset(
      center.dx + math.cos(sweepAngle - math.pi / 2) * radius,
      center.dy + math.sin(sweepAngle - math.pi / 2) * radius,
    );

    canvas.drawLine(
      center,
      sweepEnd,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
        ..strokeWidth = 1.5,
    );

    // Draw nodes
    for (final node in nodes) {
      final distance = node.worldPosition.distance;
      if (distance > maxRange) continue;

      final relativeBearing = node.worldPosition.bearing - heading;
      final angle = relativeBearing * math.pi / 180 - math.pi / 2;
      final scaledDistance = (distance / maxRange) * radius;

      final nodePos = Offset(
        center.dx + math.cos(angle) * scaledDistance,
        center.dy + math.sin(angle) * scaledDistance,
      );

      final color = _getNodeColor(node.threatLevel);

      // Highlight nodes recently swept
      var angleDiff = (sweepAngle - math.pi / 2 - angle) % (2 * math.pi);
      if (angleDiff < 0) angleDiff += 2 * math.pi;

      final recentlySweped = angleDiff < math.pi / 2;
      final intensity = recentlySweped ? (1 - angleDiff / (math.pi / 2)) : 0.5;

      // Glow effect
      canvas.drawCircle(
        nodePos,
        6,
        Paint()
          ..color = color.withValues(alpha: 0.3 * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Node dot
      canvas.drawCircle(
        nodePos,
        3,
        Paint()..color = color.withValues(alpha: 0.5 + 0.5 * intensity),
      );
    }

    // Draw center dot
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF00FF88));

    // Draw N indicator
    final northAngle = -heading * math.pi / 180 - math.pi / 2;
    final northPos = Offset(
      center.dx + math.cos(northAngle) * (radius - 12),
      center.dy + math.sin(northAngle) * (radius - 12),
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        northPos.dx - textPainter.width / 2,
        northPos.dy - textPainter.height / 2,
      ),
    );
  }

  Color _getNodeColor(ARThreatLevel level) {
    switch (level) {
      case ARThreatLevel.normal:
        return const Color(0xFF00E5FF);
      case ARThreatLevel.info:
        return const Color(0xFF00FF88);
      case ARThreatLevel.warning:
        return const Color(0xFFFFAB00);
      case ARThreatLevel.critical:
        return const Color(0xFFFF1744);
      case ARThreatLevel.offline:
        return const Color(0xFF757575);
    }
  }

  @override
  bool shouldRepaint(_AnimatedMiniRadarPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}
