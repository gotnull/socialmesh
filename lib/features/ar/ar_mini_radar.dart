import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ar_models.dart';
import 'ar_providers.dart';

/// A compact radar widget showing nearby nodes
/// Can be embedded in other screens as a quick overview
class ARMiniRadar extends ConsumerStatefulWidget {
  final double size;
  final double maxRange; // meters
  final VoidCallback? onTap;
  final bool showCompass;

  const ARMiniRadar({
    super.key,
    this.size = 150,
    this.maxRange = 10000, // 10km default
    this.onTap,
    this.showCompass = true,
  });

  @override
  ConsumerState<ARMiniRadar> createState() => _ARMiniRadarState();
}

class _ARMiniRadarState extends ConsumerState<ARMiniRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arState = ref.watch(arViewProvider);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.8),
          border: Border.all(
            color: Colors.cyan.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: _MiniRadarPainter(
              nodes: arState.arNodes,
              heading: arState.orientation.heading,
              maxRange: widget.maxRange,
              scanAnimation: _scanController,
              showCompass: widget.showCompass,
            ),
            size: Size(widget.size, widget.size),
          ),
        ),
      ),
    );
  }
}

class _MiniRadarPainter extends CustomPainter {
  final List<ARNode> nodes;
  final double heading;
  final double maxRange;
  final Animation<double> scanAnimation;
  final bool showCompass;

  _MiniRadarPainter({
    required this.nodes,
    required this.heading,
    required this.maxRange,
    required this.scanAnimation,
    required this.showCompass,
  }) : super(repaint: scanAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw range rings
    _drawRangeRings(canvas, center, radius);

    // Draw crosshairs
    _drawCrosshairs(canvas, center, radius);

    // Draw compass directions
    if (showCompass) {
      _drawCompassDirections(canvas, center, radius);
    }

    // Draw scan sweep
    _drawScanSweep(canvas, center, radius);

    // Draw nodes
    _drawNodes(canvas, center, radius);

    // Draw center point (you)
    _drawCenterPoint(canvas, center);
  }

  void _drawRangeRings(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw 3 range rings
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, ringPaint);
    }
  }

  void _drawCrosshairs(Canvas canvas, Offset center, double radius) {
    final crossPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      crossPaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      crossPaint,
    );
  }

  void _drawCompassDirections(Canvas canvas, Offset center, double radius) {
    final textStyle = TextStyle(
      color: Colors.cyan.withValues(alpha: 0.5),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    // Rotate based on heading so N is always up
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    // Draw N, E, S, W
    _drawDirectionLabel(canvas, center, radius, 'N', 0, textStyle);
    _drawDirectionLabel(canvas, center, radius, 'E', 90, textStyle);
    _drawDirectionLabel(canvas, center, radius, 'S', 180, textStyle);
    _drawDirectionLabel(canvas, center, radius, 'W', 270, textStyle);

    canvas.restore();
  }

  void _drawDirectionLabel(
    Canvas canvas,
    Offset center,
    double radius,
    String label,
    double angle,
    TextStyle style,
  ) {
    final rad = angle * math.pi / 180;
    final offset = Offset(
      center.dx + (radius - 12) * math.sin(rad),
      center.dy - (radius - 12) * math.cos(rad),
    );

    final textSpan = TextSpan(text: label, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        offset.dx - textPainter.width / 2,
        offset.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawScanSweep(Canvas canvas, Offset center, double radius) {
    final sweepAngle = scanAnimation.value * 2 * math.pi;

    // Draw gradient sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        colors: [Colors.transparent, Colors.cyan.withValues(alpha: 0.3)],
        stops: const [0.0, 1.0],
        transform: GradientRotation(sweepAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Draw scan line
    final linePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final endPoint = Offset(
      center.dx + radius * math.cos(sweepAngle - math.pi / 2),
      center.dy + radius * math.sin(sweepAngle - math.pi / 2),
    );

    canvas.drawLine(center, endPoint, linePaint);
  }

  void _drawNodes(Canvas canvas, Offset center, double radius) {
    for (final node in nodes) {
      // Skip nodes beyond range
      if (node.distance > maxRange) continue;

      // Calculate position on radar
      // Bearing is from north, adjust for heading
      final adjustedBearing = node.bearing - heading;
      final rad = adjustedBearing * math.pi / 180;

      // Distance as fraction of max range
      final distFraction = (node.distance / maxRange).clamp(0.0, 1.0);
      final nodeRadius = radius * distFraction;

      final nodePos = Offset(
        center.dx + nodeRadius * math.sin(rad),
        center.dy - nodeRadius * math.cos(rad),
      );

      // Node color based on status
      Color nodeColor = Colors.green;
      if (node.node.lastHeard != null) {
        final age = DateTime.now().difference(node.node.lastHeard!);
        if (age.inMinutes > 30) {
          nodeColor = Colors.red.withValues(alpha: 0.7);
        } else if (age.inMinutes > 5) {
          nodeColor = Colors.orange;
        }
      }

      // Draw glow
      final glowPaint = Paint()
        ..color = nodeColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(nodePos, 6, glowPaint);

      // Draw node point
      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(nodePos, 4, nodePaint);
    }
  }

  void _drawCenterPoint(Canvas canvas, Offset center) {
    // Glow
    final glowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, 8, glowPaint);

    // Center dot
    final centerPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPaint);

    // Triangle indicating forward
    final trianglePath = Path()
      ..moveTo(center.dx, center.dy - 8)
      ..lineTo(center.dx + 4, center.dy - 2)
      ..lineTo(center.dx - 4, center.dy - 2)
      ..close();

    canvas.drawPath(trianglePath, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniRadarPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.heading != heading ||
        oldDelegate.maxRange != maxRange;
  }
}

/// Full-screen radar widget for dedicated radar view
class ARFullRadar extends ConsumerWidget {
  const ARFullRadar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arState = ref.watch(arViewProvider);
    final stats = ref.watch(arStatsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'RADAR',
          style: TextStyle(
            color: Colors.cyan,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Column(
        children: [
          // Large radar
          Expanded(
            flex: 3,
            child: Center(
              child: ARMiniRadar(
                size: MediaQuery.of(context).size.width - 64,
                maxRange: arState.config.maxDisplayDistance,
                showCompass: true,
              ),
            ),
          ),

          // Node list
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: arState.arNodes.length,
                itemBuilder: (context, index) {
                  final arNode = arState.arNodes[index];
                  return _RadarNodeListItem(arNode: arNode);
                },
              ),
            ),
          ),

          // Stats bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  icon: Icons.radar,
                  label: 'Nodes',
                  value: '${stats.totalNodes}',
                ),
                _StatChip(
                  icon: Icons.near_me,
                  label: 'Nearest',
                  value: stats.totalNodes > 0
                      ? _formatDistance(stats.nearestDistance)
                      : '--',
                ),
                _StatChip(
                  icon: Icons.explore,
                  label: 'Heading',
                  value: '${arState.orientation.heading.round()}°',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }
}

class _RadarNodeListItem extends StatelessWidget {
  final ARNode arNode;

  const _RadarNodeListItem({required this.arNode});

  @override
  Widget build(BuildContext context) {
    final node = arNode.node;

    Color statusColor = Colors.green;
    if (node.lastHeard != null) {
      final age = DateTime.now().difference(node.lastHeard!);
      if (age.inMinutes > 30) {
        statusColor = Colors.red.withValues(alpha: 0.7);
      } else if (age.inMinutes > 5) {
        statusColor = Colors.orange;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              node.shortName ?? node.longName ?? '????',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            arNode.formattedDistance,
            style: TextStyle(
              color: Colors.cyan.withValues(alpha: 0.8),
              fontFamily: 'JetBrainsMono',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            arNode.compassDirection,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.cyan.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
