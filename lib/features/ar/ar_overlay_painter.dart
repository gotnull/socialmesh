import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ar_models.dart';

/// Custom painter for AR overlay elements
class AROverlayPainter extends CustomPainter {
  final List<ARNode> nodes;
  final ARDeviceOrientation orientation;
  final ARConfig config;
  final ARNode? selectedNode;
  final void Function(ARNode)? onNodeTap;

  // Store painted node positions for hit testing
  final List<_PaintedNode> _paintedNodes = [];

  AROverlayPainter({
    required this.nodes,
    required this.orientation,
    required this.config,
    this.selectedNode,
    this.onNodeTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintedNodes.clear();

    // Paint each node
    for (final arNode in nodes) {
      final pos = arNode.toScreenPosition(
        deviceHeading: orientation.heading,
        devicePitch: orientation.pitch,
        deviceRoll: orientation.roll,
        fovHorizontal: config.horizontalFov,
        fovVertical: config.verticalFov,
        screenWidth: size.width,
        screenHeight: size.height,
      );

      if (pos == null) continue;

      if (pos.isInView) {
        _paintNode(canvas, arNode, pos, size);
      } else if (config.showOffscreenIndicators) {
        _paintOffscreenIndicator(canvas, arNode, pos, size);
      }
    }

    // Paint compass
    _paintCompass(canvas, size);

    // Paint horizon line
    _paintHorizon(canvas, size);
  }

  void _paintNode(
    Canvas canvas,
    ARNode arNode,
    ARScreenPosition pos,
    Size size,
  ) {
    final isSelected = selectedNode?.node.nodeNum == arNode.node.nodeNum;
    final node = arNode.node;

    // Node color based on status
    Color nodeColor;
    if (node.lastHeard != null) {
      final age = DateTime.now().difference(node.lastHeard!);
      if (age.inMinutes < 5) {
        nodeColor = Colors.green;
      } else if (age.inMinutes < 30) {
        nodeColor = Colors.orange;
      } else {
        nodeColor = Colors.red.withValues(alpha: 0.7);
      }
    } else {
      nodeColor = Colors.grey;
    }

    // Glow effect
    final glowPaint = Paint()
      ..color = nodeColor.withValues(alpha: 0.3 * pos.opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(Offset(pos.x, pos.y), pos.size * 0.8, glowPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = nodeColor.withValues(alpha: pos.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 4 : 2;

    canvas.drawCircle(Offset(pos.x, pos.y), pos.size / 2, ringPaint);

    // Inner fill
    final fillPaint = Paint()
      ..color = nodeColor.withValues(alpha: 0.2 * pos.opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(pos.x, pos.y), pos.size / 2 - 2, fillPaint);

    // Signal strength indicator
    if (config.showSignalStrength) {
      _paintSignalBars(
        canvas,
        Offset(pos.x + pos.size / 2 + 5, pos.y - pos.size / 4),
        arNode.signalQuality,
        pos.opacity,
      );
    }

    // Node name
    final name = node.shortName ?? node.longName ?? '????';
    final nameStyle = TextStyle(
      color: Colors.white.withValues(alpha: pos.opacity),
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
      ],
    );

    final nameSpan = TextSpan(text: name, style: nameStyle);
    final namePainter = TextPainter(
      text: nameSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    namePainter.paint(
      canvas,
      Offset(pos.x - namePainter.width / 2, pos.y + pos.size / 2 + 5),
    );

    // Distance label
    if (config.showDistanceLabels) {
      final distStyle = TextStyle(
        color: Colors.white70.withValues(alpha: pos.opacity),
        fontSize: 11,
      );

      final distSpan = TextSpan(
        text: '${arNode.formattedDistance} ${arNode.compassDirection}',
        style: distStyle,
      );
      final distPainter = TextPainter(
        text: distSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      distPainter.paint(
        canvas,
        Offset(pos.x - distPainter.width / 2, pos.y + pos.size / 2 + 22),
      );
    }

    // Store for hit testing
    _paintedNodes.add(
      _PaintedNode(
        arNode: arNode,
        rect: Rect.fromCircle(
          center: Offset(pos.x, pos.y),
          radius: pos.size / 2 + 10,
        ),
      ),
    );

    // Selection indicator
    if (isSelected) {
      final selectPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset(pos.x, pos.y), pos.size / 2 + 8, selectPaint);

      // Animated ring (would need animation controller)
      final animPaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawCircle(Offset(pos.x, pos.y), pos.size / 2 + 15, animPaint);
    }
  }

  void _paintSignalBars(
    Canvas canvas,
    Offset position,
    double quality,
    double opacity,
  ) {
    final barCount = 4;
    final barWidth = 3.0;
    final barSpacing = 2.0;
    final maxHeight = 16.0;

    for (var i = 0; i < barCount; i++) {
      final barHeight = maxHeight * (i + 1) / barCount;
      final isActive = quality >= (i + 1) / barCount;

      final paint = Paint()
        ..color = isActive
            ? _getSignalColor(quality).withValues(alpha: opacity)
            : Colors.grey.withValues(alpha: 0.3 * opacity)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(
        position.dx + i * (barWidth + barSpacing),
        position.dy + (maxHeight - barHeight),
        barWidth,
        barHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
    }
  }

  Color _getSignalColor(double quality) {
    if (quality >= 0.7) return Colors.green;
    if (quality >= 0.4) return Colors.orange;
    return Colors.red;
  }

  void _paintOffscreenIndicator(
    Canvas canvas,
    ARNode arNode,
    ARScreenPosition pos,
    Size size,
  ) {
    final edgePadding = 50.0;
    final indicatorSize = 30.0;

    double x, y;
    double rotation;

    if (pos.isOnLeft) {
      x = edgePadding;
      y = size.height / 2;
      rotation = -math.pi / 2; // Point left
    } else {
      x = size.width - edgePadding;
      y = size.height / 2;
      rotation = math.pi / 2; // Point right
    }

    // Draw arrow
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotation);

    final arrowPath = Path()
      ..moveTo(0, -indicatorSize / 2)
      ..lineTo(indicatorSize / 2, indicatorSize / 2)
      ..lineTo(-indicatorSize / 2, indicatorSize / 2)
      ..close();

    final arrowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);

    canvas.restore();

    // Draw node name next to arrow
    final name = arNode.node.shortName ?? '????';
    final nameStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.8),
      fontSize: 12,
      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
    );

    final nameSpan = TextSpan(text: name, style: nameStyle);
    final namePainter = TextPainter(
      text: nameSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final nameX = pos.isOnLeft
        ? x + indicatorSize / 2 + 5
        : x - indicatorSize / 2 - namePainter.width - 5;

    namePainter.paint(canvas, Offset(nameX, y - namePainter.height / 2));

    // Distance
    final distStyle = TextStyle(color: Colors.white54, fontSize: 10);

    final distSpan = TextSpan(text: arNode.formattedDistance, style: distStyle);
    final distPainter = TextPainter(
      text: distSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    distPainter.paint(canvas, Offset(nameX, y + namePainter.height / 2 + 2));
  }

  void _paintCompass(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final topY = 140.0; // Below app bar
    final radius = 30.0;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, topY), radius + 5, bgPaint);

    // Compass ring
    final ringPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(centerX, topY), radius, ringPaint);

    // Direction indicator (rotates opposite to heading)
    canvas.save();
    canvas.translate(centerX, topY);
    canvas.rotate(-orientation.heading * math.pi / 180);

    // North indicator
    final northPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final northPath = Path()
      ..moveTo(0, -radius + 5)
      ..lineTo(5, -radius + 15)
      ..lineTo(-5, -radius + 15)
      ..close();

    canvas.drawPath(northPath, northPaint);

    // South indicator
    final southPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final southPath = Path()
      ..moveTo(0, radius - 5)
      ..lineTo(5, radius - 15)
      ..lineTo(-5, radius - 15)
      ..close();

    canvas.drawPath(southPath, southPaint);

    canvas.restore();

    // Heading text
    final headingText = '${orientation.heading.round()}°';
    final headingStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final headingSpan = TextSpan(text: headingText, style: headingStyle);
    final headingPainter = TextPainter(
      text: headingSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    headingPainter.paint(
      canvas,
      Offset(
        centerX - headingPainter.width / 2,
        topY - headingPainter.height / 2,
      ),
    );
  }

  void _paintHorizon(Canvas canvas, Size size) {
    // Calculate horizon position based on pitch
    final horizonY =
        size.height / 2 - (orientation.pitch / 45) * (size.height / 4);

    // Don't draw if horizon is off screen
    if (horizonY < 0 || horizonY > size.height) return;

    final horizonPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    const dashWidth = 10.0;
    const dashSpace = 5.0;
    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, horizonY),
        Offset(startX + dashWidth, horizonY),
        horizonPaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  /// Find node at tap position
  ARNode? nodeAtPosition(Offset position) {
    for (final painted in _paintedNodes.reversed) {
      if (painted.rect.contains(position)) {
        return painted.arNode;
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant AROverlayPainter oldDelegate) {
    return oldDelegate.orientation != orientation ||
        oldDelegate.nodes != nodes ||
        oldDelegate.selectedNode != selectedNode ||
        oldDelegate.config != config;
  }
}

class _PaintedNode {
  final ARNode arNode;
  final Rect rect;

  const _PaintedNode({required this.arNode, required this.rect});
}

/// Widget that wraps the painter and handles tap detection
class AROverlay extends StatefulWidget {
  final List<ARNode> nodes;
  final ARDeviceOrientation orientation;
  final ARConfig config;
  final ARNode? selectedNode;
  final void Function(ARNode)? onNodeTap;

  const AROverlay({
    super.key,
    required this.nodes,
    required this.orientation,
    required this.config,
    this.selectedNode,
    this.onNodeTap,
  });

  @override
  State<AROverlay> createState() => _AROverlayState();
}

class _AROverlayState extends State<AROverlay> {
  AROverlayPainter? _painter;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTap,
      child: CustomPaint(
        painter: _painter = AROverlayPainter(
          nodes: widget.nodes,
          orientation: widget.orientation,
          config: widget.config,
          selectedNode: widget.selectedNode,
          onNodeTap: widget.onNodeTap,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    final node = _painter?.nodeAtPosition(details.localPosition);
    if (node != null && widget.onNodeTap != null) {
      widget.onNodeTap!(node);
    }
  }
}
