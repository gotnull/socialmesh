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
    // Draw horizon line (tactical mode)
    if (config.showHorizon) {
      _drawHorizonLine(canvas, size);
    }

    // Draw compass (tactical/explorer) or compact heading (minimal)
    if (config.showCompass) {
      _drawCompass(canvas, size);
    } else if (config.compactHeading) {
      _drawCompactHeading(canvas, size);
    }

    // Draw altimeter (tactical mode)
    if (config.showAltimeter) {
      _drawAltimeter(canvas, size);
    }

    // Draw distance rings (tactical mode)
    if (config.showDistanceRings) {
      _drawDistanceRings(canvas, size);
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

    // Draw alerts (tactical/explorer mode)
    if (config.showAlerts && alerts.isNotEmpty) {
      _drawAlerts(canvas, size);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPACT HEADING (MINIMAL MODE)
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawCompactHeading(Canvas canvas, Size size) {
    final heading = orientation.heading;
    final headingText = '${heading.round().toString().padLeft(3, '0')}°';

    // Get cardinal direction
    String cardinal;
    if (heading < 22.5 || heading >= 337.5) {
      cardinal = 'N';
    } else if (heading < 67.5) {
      cardinal = 'NE';
    } else if (heading < 112.5) {
      cardinal = 'E';
    } else if (heading < 157.5) {
      cardinal = 'SE';
    } else if (heading < 202.5) {
      cardinal = 'S';
    } else if (heading < 247.5) {
      cardinal = 'SW';
    } else if (heading < 292.5) {
      cardinal = 'W';
    } else {
      cardinal = 'NW';
    }

    // Position in top-right corner
    final x = size.width - 70;
    final y = config.safeAreaTop + 60;

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 60, 40),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black.withValues(alpha: 0.5 * config.opacity),
    );
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = _primaryColor.withValues(alpha: 0.3 * config.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Heading text
    final headingPainter = TextPainter(
      text: TextSpan(
        text: headingText,
        style: TextStyle(
          color: _primaryColor.withValues(alpha: config.opacity),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    headingPainter.paint(
      canvas,
      Offset(x + 30 - headingPainter.width / 2, y + 4),
    );

    // Cardinal direction
    final cardinalPainter = TextPainter(
      text: TextSpan(
        text: cardinal,
        style: TextStyle(
          color: _primaryColor.withValues(alpha: config.opacity * 0.7),
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    cardinalPainter.paint(
      canvas,
      Offset(x + 30 - cardinalPainter.width / 2, y + 22),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISTANCE RINGS (TACTICAL MODE)
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawDistanceRings(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = size.width * 0.4;

    // Draw concentric rings at different distances
    final distances = [100, 500, 1000, 5000]; // meters

    for (var i = 0; i < distances.length; i++) {
      final distance = distances[i];
      final radius = maxRadius * (i + 1) / distances.length;
      final alpha = 0.1 - i * 0.02;

      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        Paint()
          ..color = _primaryColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );

      // Distance label
      final label = distance >= 1000 ? '${distance ~/ 1000}km' : '${distance}m';
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: _primaryColor.withValues(alpha: alpha + 0.1),
            fontSize: 8,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(centerX + radius + 4, centerY - labelPainter.height / 2),
      );
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
    // Position well below Dynamic Island (island is ~35pt tall + safe area)
    final topY = config.safeAreaTop + 80.0;
    final radius = 40.0; // Slightly smaller to fit better

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
    // Position below Dynamic Island + status badges (approx 140pt for island + badges)
    final compassY = config.safeAreaTop + 150.0;
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
  // ALTIMETER - Aviation style: fixed indicator, scrolling tape
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawAltimeter(Canvas canvas, Size size) {
    if (position == null) return;

    final altitude = position!.altitude;
    final x = size.width - 50;
    final centerY = size.height / 2;
    final height = 200.0;
    final top = centerY - height / 2;
    final bottom = centerY + height / 2;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 30, top, x + 30, bottom),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 30, top, x + 30, bottom),
        const Radius.circular(6),
      ),
      Paint()
        ..color = _primaryColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Clip for scrolling tape
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 28, top + 2, x + 28, bottom - 2),
        const Radius.circular(4),
      ),
    );

    // Scrolling tape - numbers move, indicator stays at center
    final pixelsPerMeter = 2.0; // 2 pixels per meter

    // Draw altitude markers that scroll
    final startAlt =
        ((altitude - height / pixelsPerMeter / 2) / 20).floor() * 20;
    final endAlt = ((altitude + height / pixelsPerMeter / 2) / 20).ceil() * 20;

    for (var alt = startAlt; alt <= endAlt; alt += 20) {
      // Y position relative to center (current altitude = centerY)
      final y = centerY - (alt - altitude) * pixelsPerMeter;

      if (y < top - 20 || y > bottom + 20) continue;

      final isMajor = alt % 100 == 0;

      // Tick marks on left side
      final tickWidth = isMajor ? 10.0 : 5.0;
      canvas.drawLine(
        Offset(x - 28, y),
        Offset(x - 28 + tickWidth, y),
        Paint()
          ..color = _primaryColor.withValues(alpha: isMajor ? 0.8 : 0.4)
          ..strokeWidth = isMajor ? 1.5 : 1.0,
      );

      // Altitude labels
      final label = '${alt}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: _primaryColor.withValues(alpha: isMajor ? 1.0 : 0.6),
            fontSize: isMajor ? 11 : 9,
            fontFamily: 'monospace',
            fontWeight: isMajor ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x - 15, y - textPainter.height / 2));
    }

    canvas.restore();

    // Fixed center indicator (green arrow pointing to current value)
    final indicatorPaint = Paint()
      ..color = _secondaryColor
      ..style = PaintingStyle.fill;

    // Left arrow
    canvas.drawPath(
      Path()
        ..moveTo(x - 30, centerY)
        ..lineTo(x - 38, centerY - 8)
        ..lineTo(x - 38, centerY + 8)
        ..close(),
      indicatorPaint,
    );

    // Horizontal line at center
    canvas.drawLine(
      Offset(x - 30, centerY),
      Offset(x - 18, centerY),
      Paint()
        ..color = _secondaryColor
        ..strokeWidth = 2,
    );

    // Current altitude readout box (fixed position, left of scale)
    final altText = '${altitude.round()}m';
    final altPainter = TextPainter(
      text: TextSpan(
        text: altText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxWidth = altPainter.width + 12;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x - 38 - boxWidth / 2 - 4, centerY),
        width: boxWidth,
        height: 22,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(boxRect, Paint()..color = _secondaryColor);
    canvas.drawRRect(
      boxRect,
      Paint()
        ..color = _secondaryColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    altPainter.paint(
      canvas,
      Offset(
        x - 38 - boxWidth / 2 - 4 - altPainter.width / 2,
        centerY - altPainter.height / 2,
      ),
    );

    // ALT label at top
    final altLabel = TextPainter(
      text: TextSpan(
        text: 'ALT',
        style: TextStyle(
          color: _primaryColor.withValues(alpha: 0.7),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    altLabel.paint(canvas, Offset(x - altLabel.width / 2, top - 16));
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
    final baseNodeSize = node.screenPosition.size * config.markerScale;
    final opacity = node.screenPosition.opacity * config.opacity;

    // Get color based on threat level and signal strength
    final baseColor = config.showSignalStrength
        ? _getSignalColor(node.signalQuality)
        : _getThreatColor(node.threatLevel);
    final color = baseColor.withValues(alpha: opacity);

    // Draw movement trail if enabled and node has track
    if (config.showTrails && node.track.length > 1) {
      _drawNodeTrail(canvas, size, node, color);
    }

    // Marker size based on config
    final markerRadius = isSelected ? baseNodeSize * 0.4 : baseNodeSize * 0.3;

    // Draw glow effect for explorer mode (larger markers)
    if (config.markerScale > 1.0) {
      final glowPaint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.withValues(alpha: opacity * 0.4);
      canvas.drawCircle(pos, markerRadius + 4, glowPaint);
    }

    // Main marker
    canvas.drawCircle(pos, markerRadius, Paint()..color = color);

    // Selection ring with animation
    if (isSelected) {
      final pulseRadius =
          markerRadius + 4 + math.sin(animationValue * math.pi * 2) * 2;
      canvas.drawCircle(
        pos,
        pulseRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Second outer ring for emphasis
      canvas.drawCircle(
        pos,
        pulseRadius + 8,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Signal strength indicator (small arc around marker)
    if (config.showSignalStrength && !isSelected) {
      _drawSignalIndicator(
        canvas,
        pos,
        markerRadius,
        node.signalQuality,
        opacity,
      );
    }

    // Distance text (if enabled)
    if (config.showNodeDistance) {
      final distText = _formatDistance(node.worldPosition.distance);
      final distPainter = TextPainter(
        text: TextSpan(
          text: distText,
          style: TextStyle(
            color: color,
            fontSize: 10 * config.markerScale,
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
    }

    // Node name (if enabled, or always show when selected)
    final showName = config.showNodeNames || isSelected;
    if (showName && (isSelected || node.worldPosition.distance < 1000)) {
      final name = node.node.shortName ?? node.node.longName ?? 'Unknown';
      final namePainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: color,
            fontSize: (isSelected ? 12 : 10) * config.markerScale,
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

    // Moving indicator (animated arrows for nodes in motion)
    if (node.isMoving && config.showTrails) {
      _drawMovingIndicator(canvas, pos, markerRadius, node, color);
    }
  }

  /// Draw signal strength indicator arc around marker
  void _drawSignalIndicator(
    Canvas canvas,
    Offset pos,
    double radius,
    double signalQuality,
    double opacity,
  ) {
    final color = _getSignalColor(
      signalQuality,
    ).withValues(alpha: opacity * 0.8);
    final arcRadius = radius + 6;
    final sweepAngle =
        signalQuality * math.pi * 1.5; // 0-270 degrees based on quality

    canvas.drawArc(
      Rect.fromCircle(center: pos, radius: arcRadius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draw movement trail behind a node
  void _drawNodeTrail(
    Canvas canvas,
    Size size,
    ARWorldNode node,
    Color baseColor,
  ) {
    if (node.track.length < 2) return;

    // Only draw recent track points (last 8)
    final recentTrack = node.track.length > 8
        ? node.track.sublist(node.track.length - 8)
        : node.track;

    // Get current node screen position
    final currentPos = node.screenPosition.toPixels(size.width, size.height);

    // Draw trail segments with fading effect
    final path = Path();
    path.moveTo(currentPos.dx, currentPos.dy);

    // Calculate velocity direction for trail offset
    final velMagnitude = node.velocity.length;
    if (velMagnitude < 0.1) return; // No trail for stationary nodes

    // Normalize velocity direction
    final velDirX = node.velocity.x / velMagnitude;
    final velDirY = node.velocity.y / velMagnitude;

    // Draw trail points extending backward from current position
    for (var i = recentTrack.length - 1; i >= 0; i--) {
      final age = recentTrack.length - 1 - i;
      final trailLength = (age + 1) * 6.0 * config.markerScale;

      // Trail point in opposite direction of velocity
      final trailX = currentPos.dx - velDirX * trailLength;
      final trailY = currentPos.dy + velDirY * trailLength;

      path.lineTo(trailX, trailY);
    }

    // Draw trail with gradient-like fading using multiple strokes
    for (var layer = 3; layer >= 0; layer--) {
      final alpha = (0.4 - layer * 0.1) * config.opacity;
      final width = (4 - layer) * 0.8;

      canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Draw small dots along the trail for emphasis
    for (var i = 1; i <= 4; i++) {
      final dotProgress = i / 5.0;
      final dotX =
          currentPos.dx - velDirX * dotProgress * 30 * config.markerScale;
      final dotY =
          currentPos.dy + velDirY * dotProgress * 30 * config.markerScale;
      final dotAlpha = (1.0 - dotProgress) * 0.5 * config.opacity;
      final dotRadius = (3 - i * 0.5) * config.markerScale * 0.5;

      canvas.drawCircle(
        Offset(dotX, dotY),
        dotRadius,
        Paint()..color = baseColor.withValues(alpha: dotAlpha),
      );
    }
  }

  /// Draw animated indicator for moving nodes
  void _drawMovingIndicator(
    Canvas canvas,
    Offset pos,
    double radius,
    ARWorldNode node,
    Color color,
  ) {
    // Draw small direction chevrons
    final angle = math.atan2(node.velocity.y, node.velocity.x);
    final indicatorDist = radius + 12;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // Animated chevrons
    final chevronOffset = (animationValue * 6).toInt();
    for (var i = 0; i < 2; i++) {
      final dist = indicatorDist + i * 6 + chevronOffset;
      final alpha = 0.8 - i * 0.3;

      final chevronPath = Path()
        ..moveTo(dist, -3)
        ..lineTo(dist + 4, 0)
        ..lineTo(dist, 3);

      canvas.drawPath(
        chevronPath,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
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

  /// Get color based on signal quality (0-1)
  Color _getSignalColor(double quality) {
    if (quality >= 0.8) return _secondaryColor; // Excellent - green
    if (quality >= 0.6) return _primaryColor; // Good - cyan
    if (quality >= 0.4) return _warningColor; // Fair - amber
    return _criticalColor; // Poor - red
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
  final bool showNodeNames;
  final bool showNodeDistance;
  final bool showSignalStrength;
  final bool showTrails;
  final bool showDistanceRings;
  final bool compactHeading;
  final double markerScale;
  final double opacity;
  final double horizontalFov;
  final double verticalFov;
  final double safeAreaTop;
  final double safeAreaBottom;

  const ARHudConfig({
    this.showHorizon = false,
    this.showCompass = true,
    this.showAltimeter = false,
    this.showAlerts = true,
    this.showNodeNames = true,
    this.showNodeDistance = true,
    this.showSignalStrength = false,
    this.showTrails = false,
    this.showDistanceRings = false,
    this.compactHeading = false,
    this.markerScale = 1.0,
    this.opacity = 1.0,
    this.horizontalFov = 60,
    this.verticalFov = 90,
    this.safeAreaTop = 0,
    this.safeAreaBottom = 0,
  });

  /// Tactical mode - Full HUD with all tactical features
  /// - Complete compass tape with heading
  /// - Horizon line with pitch ladder
  /// - Altimeter scale
  /// - All node info with signal strength
  /// - Alert system
  /// - Distance rings on radar
  static const tactical = ARHudConfig(
    showHorizon: true,
    showCompass: true,
    showAltimeter: true,
    showAlerts: true,
    showNodeNames: true,
    showNodeDistance: true,
    showSignalStrength: true,
    showTrails: false,
    showDistanceRings: true,
    compactHeading: false,
    markerScale: 1.0,
    opacity: 1.0,
  );

  /// Explorer mode - Simplified navigation-focused HUD
  /// - No horizon/pitch (cleaner view)
  /// - Simple compass card (not tape)
  /// - No altimeter
  /// - Large markers with names
  /// - Color-coded signal strength
  /// - Movement trails for nodes
  /// - POI-style markers
  static const explorer = ARHudConfig(
    showHorizon: false,
    showCompass: true,
    showAltimeter: false,
    showAlerts: true,
    showNodeNames: true,
    showNodeDistance: true,
    showSignalStrength: true,
    showTrails: true,
    showDistanceRings: false,
    compactHeading: false,
    markerScale: 1.3,
    opacity: 1.0,
  );

  /// Minimal mode - Clean distraction-free view
  /// - No compass tape (small corner heading only)
  /// - No horizon/altimeter
  /// - Simple dot markers
  /// - Distance only (no names unless selected)
  /// - No alerts
  /// - Translucent overlay
  static const minimal = ARHudConfig(
    showHorizon: false,
    showCompass: false,
    showAltimeter: false,
    showAlerts: false,
    showNodeNames: false,
    showNodeDistance: true,
    showSignalStrength: false,
    showTrails: false,
    showDistanceRings: false,
    compactHeading: true,
    markerScale: 0.7,
    opacity: 0.8,
  );

  ARHudConfig copyWith({
    bool? showHorizon,
    bool? showCompass,
    bool? showAltimeter,
    bool? showAlerts,
    bool? showNodeNames,
    bool? showNodeDistance,
    bool? showSignalStrength,
    bool? showTrails,
    bool? showDistanceRings,
    bool? compactHeading,
    double? markerScale,
    double? opacity,
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
      showNodeNames: showNodeNames ?? this.showNodeNames,
      showNodeDistance: showNodeDistance ?? this.showNodeDistance,
      showSignalStrength: showSignalStrength ?? this.showSignalStrength,
      showTrails: showTrails ?? this.showTrails,
      showDistanceRings: showDistanceRings ?? this.showDistanceRings,
      compactHeading: compactHeading ?? this.compactHeading,
      markerScale: markerScale ?? this.markerScale,
      opacity: opacity ?? this.opacity,
      horizontalFov: horizontalFov ?? this.horizontalFov,
      verticalFov: verticalFov ?? this.verticalFov,
      safeAreaTop: safeAreaTop ?? this.safeAreaTop,
      safeAreaBottom: safeAreaBottom ?? this.safeAreaBottom,
    );
  }
}
