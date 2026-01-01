import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ar_engine.dart';

/// Professional HUD-style AR overlay painter with sci-fi aesthetics
class ARHudPainter extends CustomPainter {
  final AROrientation orientation;
  final ARPosition? position;
  final List<ARWorldNode> nodes;
  final List<ARNodeCluster> clusters;
  final List<ARAlert> alerts;
  final ARWorldNode? selectedNode;
  final ARHudConfig config;
  final double animationValue;

  ARHudPainter({
    required this.orientation,
    this.position,
    required this.nodes,
    required this.clusters,
    required this.alerts,
    this.selectedNode,
    required this.config,
    this.animationValue = 0,
  });

  // Colors
  static const _primaryColor = Color(0xFF00E5FF); // Cyan
  static const _secondaryColor = Color(0xFF00FF88); // Green
  static const _warningColor = Color(0xFFFFAB00); // Amber
  static const _criticalColor = Color(0xFFFF1744); // Red
  static const _infoColor = Color(0xFF448AFF); // Blue
  static const _offlineColor = Color(0xFF757575); // Grey

  @override
  void paint(Canvas canvas, Size size) {
    if (config.showHorizon) {
      _drawHorizonLine(canvas, size);
    }

    if (config.showCompass) {
      _drawCompass(canvas, size);
    }

    if (config.showAltimeter) {
      _drawAltimeter(canvas, size);
    }

    // Draw clusters
    for (final cluster in clusters) {
      if (cluster.screenPosition.isInView) {
        _drawCluster(canvas, size, cluster);
      }
    }

    // Draw off-screen indicators
    for (final node in nodes) {
      if (!node.screenPosition.isInView && !_isInCluster(node)) {
        _drawOffscreenIndicator(canvas, size, node);
      }
    }

    // Draw visible nodes
    for (final node in nodes) {
      if (node.screenPosition.isInView && !_isInCluster(node)) {
        _drawNode(canvas, size, node, isSelected: node == selectedNode);
      }
    }

    // Draw alerts
    if (config.showAlerts && alerts.isNotEmpty) {
      _drawAlerts(canvas, size);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HORIZON LINE
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawHorizonLine(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final pitchOffset = orientation.pitch * (size.height / config.verticalFov);
    final horizonY = centerY + pitchOffset;

    // Skip if horizon is off screen
    if (horizonY < -100 || horizonY > size.height + 100) return;

    final paint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Main horizon line
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), paint);

    // Pitch ladder
    final ladderPaint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: _primaryColor.withValues(alpha: 0.7),
      fontSize: 10,
      fontFamily: 'monospace',
    );

    for (var pitch = -60; pitch <= 60; pitch += 10) {
      if (pitch == 0) continue;

      final y = horizonY - pitch * (size.height / config.verticalFov);
      if (y < 0 || y > size.height) continue;

      final lineWidth = pitch % 30 == 0 ? 80.0 : 40.0;
      final centerX = size.width / 2;

      // Draw pitch marks
      canvas.drawLine(
        Offset(centerX - lineWidth, y),
        Offset(centerX - 20, y),
        ladderPaint,
      );
      canvas.drawLine(
        Offset(centerX + 20, y),
        Offset(centerX + lineWidth, y),
        ladderPaint,
      );

      // Draw pitch labels
      final textPainter = TextPainter(
        text: TextSpan(text: '${pitch.abs()}°', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(centerX + lineWidth + 5, y - textPainter.height / 2),
      );
    }

    // Roll indicator
    _drawRollIndicator(canvas, size);
  }

  void _drawRollIndicator(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final topY = config.safeAreaTop + 50.0; // Below dynamic island
    final radius = 50.0;

    canvas.save();
    canvas.translate(centerX, topY);
    canvas.rotate(orientation.roll * math.pi / 180);

    // Arc background
    final arcPaint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      -math.pi * 0.8,
      math.pi * 0.6,
      false,
      arcPaint,
    );

    // Roll marks
    final markPaint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var angle = -60; angle <= 60; angle += 10) {
      final radians = (angle - 90) * math.pi / 180;
      final inner = angle % 30 == 0 ? radius - 12 : radius - 8;
      canvas.drawLine(
        Offset(math.cos(radians) * inner, math.sin(radians) * inner),
        Offset(math.cos(radians) * radius, math.sin(radians) * radius),
        markPaint,
      );
    }

    canvas.restore();

    // Fixed triangle indicator
    final indicatorPaint = Paint()
      ..color = _primaryColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(centerX, topY - radius + 15)
      ..lineTo(centerX - 6, topY - radius + 5)
      ..lineTo(centerX + 6, topY - radius + 5)
      ..close();

    canvas.drawPath(path, indicatorPaint);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPASS
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawCompass(Canvas canvas, Size size) {
    final compassY = config.safeAreaTop + 110.0; // Below roll indicator
    final compassWidth = size.width * 0.7;
    final centerX = size.width / 2;
    final left = centerX - compassWidth / 2;
    final right = centerX + compassWidth / 2;

    // Background bar
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, compassY - 20, right, compassY + 20),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, compassY - 20, right, compassY + 20),
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // Clip to compass area
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(left + 5, compassY - 18, right - 5, compassY + 18),
    );

    // Draw compass tape
    final degreesPerPixel = 180 / compassWidth; // 180° visible
    final heading = orientation.heading;

    final textStyle = TextStyle(
      color: _primaryColor,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );

    final smallTextStyle = TextStyle(
      color: _primaryColor.withValues(alpha: 0.6),
      fontSize: 9,
      fontFamily: 'monospace',
    );

    for (
      var deg = heading.floor() - 100;
      deg <= heading.floor() + 100;
      deg += 5
    ) {
      var normalizedDeg = deg % 360;
      if (normalizedDeg < 0) normalizedDeg += 360;

      final pixelOffset = (deg - heading) / degreesPerPixel;
      final x = centerX + pixelOffset;

      if (x < left + 5 || x > right - 5) continue;

      // Draw tick
      final tickPaint = Paint()
        ..color = normalizedDeg % 30 == 0
            ? _primaryColor.withValues(alpha: 0.8)
            : _primaryColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final tickHeight = normalizedDeg % 30 == 0 ? 8.0 : 4.0;

      canvas.drawLine(
        Offset(x, compassY + 15),
        Offset(x, compassY + 15 - tickHeight),
        tickPaint,
      );

      // Draw labels
      if (normalizedDeg % 30 == 0) {
        String label;
        switch (normalizedDeg) {
          case 0:
            label = 'N';
            break;
          case 90:
            label = 'E';
            break;
          case 180:
            label = 'S';
            break;
          case 270:
            label = 'W';
            break;
          default:
            label = normalizedDeg.toString();
        }

        final isCardinal = normalizedDeg % 90 == 0;
        final style = isCardinal ? textStyle : smallTextStyle;

        final textPainter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, compassY - 12),
        );
      }
    }

    canvas.restore();

    // Center indicator triangle
    final trianglePaint = Paint()
      ..color = _primaryColor
      ..style = PaintingStyle.fill;

    final trianglePath = Path()
      ..moveTo(centerX, compassY + 18)
      ..lineTo(centerX - 5, compassY + 25)
      ..lineTo(centerX + 5, compassY + 25)
      ..close();

    canvas.drawPath(trianglePath, trianglePaint);

    // Current heading text
    final headingText = '${heading.round().toString().padLeft(3, '0')}°';
    final headingPainter = TextPainter(
      text: TextSpan(
        text: headingText,
        style: TextStyle(
          color: _primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Heading readout background
    final headingBgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, compassY + 38),
        width: headingPainter.width + 16,
        height: 22,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      headingBgRect,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawRRect(headingBgRect, borderPaint);

    headingPainter.paint(
      canvas,
      Offset(centerX - headingPainter.width / 2, compassY + 28),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALTIMETER
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawAltimeter(Canvas canvas, Size size) {
    if (position == null) return;

    final altitude = position!.altitude;
    final x = size.width - 50;
    final centerY = size.height / 2;
    final height = 200.0;

    // Background
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          x - 20,
          centerY - height / 2,
          x + 20,
          centerY + height / 2,
        ),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = _primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          x - 20,
          centerY - height / 2,
          x + 20,
          centerY + height / 2,
        ),
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // Scale
    final metersPerPixel = 100.0 / height; // Show 100m range
    final textStyle = TextStyle(
      color: _primaryColor.withValues(alpha: 0.7),
      fontSize: 8,
      fontFamily: 'monospace',
    );

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        x - 18,
        centerY - height / 2 + 2,
        x + 18,
        centerY + height / 2 - 2,
      ),
    );

    for (
      var alt = altitude.floor() - 60;
      alt <= altitude.floor() + 60;
      alt += 10
    ) {
      final pixelOffset = (altitude - alt) / metersPerPixel;
      final y = centerY + pixelOffset;

      if (y < centerY - height / 2 || y > centerY + height / 2) continue;

      // Draw tick
      final tickPaint = Paint()
        ..color = alt % 50 == 0
            ? _primaryColor.withValues(alpha: 0.8)
            : _primaryColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final tickWidth = alt % 50 == 0 ? 8.0 : 4.0;

      canvas.drawLine(
        Offset(x - 18, y),
        Offset(x - 18 + tickWidth, y),
        tickPaint,
      );

      // Labels for every 50m
      if (alt % 50 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(text: '${alt}m', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(x - 5, y - textPainter.height / 2));
      }
    }

    canvas.restore();

    // Center indicator
    final indicatorPaint = Paint()
      ..color = _secondaryColor
      ..style = PaintingStyle.fill;

    final indicatorPath = Path()
      ..moveTo(x - 18, centerY)
      ..lineTo(x - 28, centerY - 5)
      ..lineTo(x - 28, centerY + 5)
      ..close();

    canvas.drawPath(indicatorPath, indicatorPaint);

    // ALT label
    final altLabel = TextPainter(
      text: TextSpan(
        text: 'ALT',
        style: TextStyle(
          color: _primaryColor.withValues(alpha: 0.6),
          fontSize: 8,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    altLabel.paint(
      canvas,
      Offset(x - altLabel.width / 2, centerY - height / 2 - 12),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CROSSHAIR
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // NODE RENDERING
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawNode(
    Canvas canvas,
    Size size,
    ARWorldNode node, {
    bool isSelected = false,
  }) {
    final pos = node.screenPosition.toPixels(size.width, size.height);
    final nodeSize = node.screenPosition.size;
    final opacity = node.screenPosition.opacity;

    // Get color based on threat level
    final baseColor = _getThreatColor(node.threatLevel);
    final color = baseColor.withValues(alpha: opacity);

    // Simple filled circle marker
    final markerRadius = isSelected ? nodeSize * 0.4 : nodeSize * 0.3;
    canvas.drawCircle(pos, markerRadius, Paint()..color = color);

    // Selection ring
    if (isSelected) {
      canvas.drawCircle(
        pos,
        markerRadius + 4,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Distance text
    final distText = _formatDistance(node.worldPosition.distance);
    final distPainter = TextPainter(
      text: TextSpan(
        text: distText,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    distPainter.paint(
      canvas,
      Offset(pos.dx - distPainter.width / 2, pos.dy + markerRadius + 4),
    );

    // Node name (if selected or close)
    if (isSelected || node.worldPosition.distance < 500) {
      final name = node.node.shortName ?? node.node.longName ?? 'Unknown';
      final namePainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: color,
            fontSize: isSelected ? 12 : 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Background for name
      final nameRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pos.dx, pos.dy - markerRadius - 12),
          width: namePainter.width + 8,
          height: namePainter.height + 4,
        ),
        const Radius.circular(3),
      );

      canvas.drawRRect(
        nameRect,
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );

      namePainter.paint(
        canvas,
        Offset(pos.dx - namePainter.width / 2, pos.dy - markerRadius - 14),
      );
    }

    // Low battery indicator (small icon, not elaborate)
    if (node.node.batteryLevel != null && node.node.batteryLevel! < 20) {
      final batteryColor = node.node.batteryLevel! < 10
          ? _criticalColor
          : _warningColor;
      canvas.drawCircle(
        Offset(pos.dx + markerRadius + 6, pos.dy - markerRadius),
        4,
        Paint()..color = batteryColor,
      );
    }
  }

  Color _getThreatColor(ARThreatLevel level) {
    switch (level) {
      case ARThreatLevel.normal:
        return _primaryColor;
      case ARThreatLevel.info:
        return _secondaryColor;
      case ARThreatLevel.warning:
        return _warningColor;
      case ARThreatLevel.critical:
        return _criticalColor;
      case ARThreatLevel.offline:
        return _offlineColor;
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLUSTERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawCluster(Canvas canvas, Size size, ARNodeCluster cluster) {
    final pos = cluster.screenPosition.toPixels(size.width, size.height);
    final clusterSize = 50.0;

    // Animated pulsing ring
    final pulseRadius =
        clusterSize * 0.5 + math.sin(animationValue * math.pi * 2) * 5;

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = _primaryColor.withValues(alpha: 0.3);

    canvas.drawCircle(pos, pulseRadius, glowPaint);

    // Outer ring
    canvas.drawCircle(
      pos,
      clusterSize * 0.45,
      Paint()
        ..color = _primaryColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner dots arranged in circle
    final dotCount = math.min(cluster.count, 6);
    for (var i = 0; i < dotCount; i++) {
      final angle = (i * 360 / dotCount - 90) * math.pi / 180;
      final dotPos = Offset(
        pos.dx + math.cos(angle) * clusterSize * 0.25,
        pos.dy + math.sin(angle) * clusterSize * 0.25,
      );
      canvas.drawCircle(dotPos, 3, Paint()..color = _primaryColor);
    }

    // Count in center
    final countText = cluster.count.toString();
    final countPainter = TextPainter(
      text: TextSpan(
        text: countText,
        style: const TextStyle(
          color: _primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    countPainter.paint(
      canvas,
      Offset(pos.dx - countPainter.width / 2, pos.dy - countPainter.height / 2),
    );

    // Distance below
    final avgDist =
        cluster.nodes
            .map((n) => n.worldPosition.distance)
            .reduce((a, b) => a + b) /
        cluster.count;
    final distText = _formatDistance(avgDist);
    final distPainter = TextPainter(
      text: TextSpan(
        text: distText,
        style: TextStyle(
          color: _primaryColor.withValues(alpha: 0.8),
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    distPainter.paint(
      canvas,
      Offset(pos.dx - distPainter.width / 2, pos.dy + clusterSize * 0.5 + 4),
    );
  }

  bool _isInCluster(ARWorldNode node) {
    for (final cluster in clusters) {
      if (cluster.nodes.contains(node)) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFF-SCREEN INDICATORS
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawOffscreenIndicator(Canvas canvas, Size size, ARWorldNode node) {
    final screen = node.screenPosition;
    final color = _getThreatColor(node.threatLevel).withValues(alpha: 0.8);

    final marginTop = config.safeAreaTop + 60.0; // Below roll indicator
    final marginBottom = config.safeAreaBottom + 80.0; // Above toolbar
    const marginSide = 30.0;
    const indicatorSize = 20.0;

    Offset position;
    double rotation;

    if (screen.isOnLeft) {
      final y = (size.height / 2 + screen.normalizedY * size.height / 2).clamp(
        marginTop,
        size.height - marginBottom,
      );
      position = Offset(marginSide, y);
      rotation = -math.pi / 2; // Point left
    } else if (screen.isOnRight) {
      final y = (size.height / 2 + screen.normalizedY * size.height / 2).clamp(
        marginTop,
        size.height - marginBottom,
      );
      position = Offset(size.width - marginSide, y);
      rotation = math.pi / 2; // Point right
    } else if (screen.isAbove) {
      final x = (size.width / 2 + screen.normalizedX * size.width / 2).clamp(
        marginSide,
        size.width - marginSide,
      );
      position = Offset(x, marginTop);
      rotation = 0; // Point up
    } else {
      final x = (size.width / 2 + screen.normalizedX * size.width / 2).clamp(
        marginSide,
        size.width - marginSide,
      );
      position = Offset(x, size.height - marginBottom);
      rotation = math.pi; // Point down
    }

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    // Draw arrow
    final arrowPath = Path()
      ..moveTo(0, -indicatorSize / 2)
      ..lineTo(-indicatorSize / 3, indicatorSize / 4)
      ..lineTo(0, 0)
      ..lineTo(indicatorSize / 3, indicatorSize / 4)
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    canvas.restore();

    // Distance text
    final dist = _formatDistance(node.worldPosition.distance);
    final distPainter = TextPainter(
      text: TextSpan(
        text: dist,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Position distance text based on arrow direction
    Offset textOffset;
    if (screen.isOnLeft) {
      textOffset = Offset(
        position.dx + 15,
        position.dy - distPainter.height / 2,
      );
    } else if (screen.isOnRight) {
      textOffset = Offset(
        position.dx - 15 - distPainter.width,
        position.dy - distPainter.height / 2,
      );
    } else if (screen.isAbove) {
      textOffset = Offset(
        position.dx - distPainter.width / 2,
        position.dy + 15,
      );
    } else {
      textOffset = Offset(
        position.dx - distPainter.width / 2,
        position.dy - 20,
      );
    }

    distPainter.paint(canvas, textOffset);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALERTS
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawAlerts(Canvas canvas, Size size) {
    final alertsToShow = alerts.take(3).toList();
    final startY = config.safeAreaTop + 170.0; // Below compass
    const alertHeight = 30.0;
    const padding = 16.0;

    for (var i = 0; i < alertsToShow.length; i++) {
      final alert = alertsToShow[i];
      final y = startY + i * (alertHeight + 5);

      final color = switch (alert.severity) {
        ARAlertSeverity.info => _infoColor,
        ARAlertSeverity.warning => _warningColor,
        ARAlertSeverity.critical => _criticalColor,
      };

      // Background
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, y, 200, alertHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(
        bgRect,
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );

      // Left accent bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(padding, y, 4, alertHeight),
          const Radius.circular(4),
        ),
        Paint()..color = color,
      );

      // Icon
      final iconPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      switch (alert.type) {
        case ARAlertType.newNode:
          // Plus icon
          canvas.drawLine(
            Offset(padding + 18, y + alertHeight / 2 - 5),
            Offset(padding + 18, y + alertHeight / 2 + 5),
            iconPaint,
          );
          canvas.drawLine(
            Offset(padding + 13, y + alertHeight / 2),
            Offset(padding + 23, y + alertHeight / 2),
            iconPaint,
          );
          break;
        case ARAlertType.nodeMoving:
          // Arrow icon
          canvas.drawLine(
            Offset(padding + 13, y + alertHeight / 2),
            Offset(padding + 23, y + alertHeight / 2),
            iconPaint,
          );
          canvas.drawLine(
            Offset(padding + 19, y + alertHeight / 2 - 4),
            Offset(padding + 23, y + alertHeight / 2),
            iconPaint,
          );
          canvas.drawLine(
            Offset(padding + 19, y + alertHeight / 2 + 4),
            Offset(padding + 23, y + alertHeight / 2),
            iconPaint,
          );
          break;
        case ARAlertType.lowBattery:
        case ARAlertType.nodeOffline:
        case ARAlertType.signalLost:
        case ARAlertType.signalRestored:
          // Warning triangle
          final trianglePath = Path()
            ..moveTo(padding + 18, y + 5)
            ..lineTo(padding + 10, y + alertHeight - 5)
            ..lineTo(padding + 26, y + alertHeight - 5)
            ..close();
          canvas.drawPath(trianglePath, iconPaint);
          break;
      }

      // Message text
      final textPainter = TextPainter(
        text: TextSpan(
          text: alert.message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(padding + 35, y + (alertHeight - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(ARHudPainter oldDelegate) {
    return oldDelegate.orientation != orientation ||
        oldDelegate.position != position ||
        oldDelegate.nodes != nodes ||
        oldDelegate.selectedNode != selectedNode ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.alerts != alerts;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

class ARHudConfig {
  final bool showHorizon;
  final bool showCompass;
  final bool showAltimeter;
  final bool showAlerts;
  final double horizontalFov;
  final double verticalFov;
  final double safeAreaTop;
  final double safeAreaBottom;

  const ARHudConfig({
    this.showHorizon = false,
    this.showCompass = true,
    this.showAltimeter = false,
    this.showAlerts = true,
    this.horizontalFov = 60,
    this.verticalFov = 90,
    this.safeAreaTop = 0,
    this.safeAreaBottom = 0,
  });

  /// Tactical mode - compass and alerts
  static const tactical = ARHudConfig();

  /// Explorer mode - same as tactical
  static const explorer = ARHudConfig();

  /// Minimal mode - just compass and nodes
  static const minimal = ARHudConfig(showAlerts: false);

  ARHudConfig copyWith({
    bool? showHorizon,
    bool? showCompass,
    bool? showAltimeter,
    bool? showAlerts,
    double? horizontalFov,
    double? verticalFov,
    double? safeAreaTop,
    double? safeAreaBottom,
  }) {
    return ARHudConfig(
      showHorizon: showHorizon ?? this.showHorizon,
      showCompass: showCompass ?? this.showCompass,
      showAltimeter: showAltimeter ?? this.showAltimeter,
      showAlerts: showAlerts ?? this.showAlerts,
      horizontalFov: horizontalFov ?? this.horizontalFov,
      verticalFov: verticalFov ?? this.verticalFov,
      safeAreaTop: safeAreaTop ?? this.safeAreaTop,
      safeAreaBottom: safeAreaBottom ?? this.safeAreaBottom,
    );
  }
}
