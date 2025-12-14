import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../models/world_mesh_node.dart';
import '../node_analytics_screen.dart';

/// Computed intelligence derived from WorldMeshNode data (meshmap.net snapshot)
class NodeIntelligenceData {
  final double healthScore; // 0-1 based on battery, uptime, last seen
  final double connectivityScore; // 0-1 based on neighbors, gateways
  final String mobilityClass; // Stationary, Mobile, Unknown
  final int neighborCount;
  final int gatewayCount;
  final String activityLevel; // Hot, Active, Quiet, Cold
  final double? channelUtilization;

  NodeIntelligenceData({
    required this.healthScore,
    required this.connectivityScore,
    required this.mobilityClass,
    required this.neighborCount,
    required this.gatewayCount,
    required this.activityLevel,
    this.channelUtilization,
  });

  /// Compute intelligence from WorldMeshNode data
  factory NodeIntelligenceData.fromNode(WorldMeshNode node) {
    // Health Score: based on battery, voltage, uptime, recency
    double health = 0;
    int healthFactors = 0;

    // Battery factor
    if (node.batteryLevel != null) {
      if (node.batteryLevel! > 100) {
        health += 1.0; // Plugged in = perfect
      } else {
        health += node.batteryLevel! / 100.0;
      }
      healthFactors++;
    }

    // Voltage factor (3.0V = dead, 4.2V = full for LiPo)
    if (node.voltage != null) {
      health += ((node.voltage! - 3.0) / 1.2).clamp(0.0, 1.0);
      healthFactors++;
    }

    // Recency factor
    if (node.isOnline) {
      health += 1.0;
      healthFactors++;
    } else if (node.isIdle) {
      health += 0.5;
      healthFactors++;
    } else {
      health += 0.1;
      healthFactors++;
    }

    // Uptime factor (longer uptime = more stable)
    if (node.uptime != null) {
      // Uptime > 24h gets full score, scales down from there
      health += (node.uptime! / 86400.0).clamp(0.0, 1.0);
      healthFactors++;
    }

    final healthScore = healthFactors > 0 ? health / healthFactors : 0.5;

    // Connectivity Score: neighbors + gateways
    final neighborCount = node.neighbors?.length ?? 0;
    final gatewayCount = node.seenBy.length;

    double connectivity = 0;
    // Neighbors: 5+ is excellent
    connectivity += (neighborCount / 5.0).clamp(0.0, 1.0) * 0.5;
    // Gateways: 3+ is excellent
    connectivity += (gatewayCount / 3.0).clamp(0.0, 1.0) * 0.5;

    // Mobility classification
    String mobility = 'Unknown';
    if (node.role.toLowerCase().contains('router') ||
        node.role.toLowerCase().contains('repeater')) {
      mobility = 'Infrastructure';
    } else if (node.role.toLowerCase().contains('client')) {
      mobility = 'Mobile';
    } else if (node.role.toLowerCase().contains('tracker')) {
      mobility = 'Tracker';
    } else if (node.altitude != null && node.altitude! > 100) {
      mobility = 'Elevated';
    } else {
      mobility = 'Stationary';
    }

    // Activity level based on channel utilization and air time
    String activity = 'Unknown';
    final chUtil = node.chUtil;
    final airUtil = node.airUtilTx;

    if (chUtil != null || airUtil != null) {
      final avgUtil = ((chUtil ?? 0) + (airUtil ?? 0)) / 2;
      if (avgUtil > 50) {
        activity = 'Hot';
      } else if (avgUtil > 20) {
        activity = 'Active';
      } else if (avgUtil > 5) {
        activity = 'Quiet';
      } else {
        activity = 'Cold';
      }
    } else if (node.isOnline) {
      activity = 'Active';
    } else if (node.isIdle) {
      activity = 'Quiet';
    } else {
      activity = 'Cold';
    }

    return NodeIntelligenceData(
      healthScore: healthScore,
      connectivityScore: connectivity,
      mobilityClass: mobility,
      neighborCount: neighborCount,
      gatewayCount: gatewayCount,
      activityLevel: activity,
      channelUtilization: chUtil,
    );
  }
}

/// A futuristic panel displaying computed mesh intelligence for a node
class NodeIntelligencePanel extends StatelessWidget {
  final WorldMeshNode node;
  final VoidCallback? onShowOnMap;

  const NodeIntelligencePanel({
    super.key,
    required this.node,
    this.onShowOnMap,
  });

  void _openAnalyticsScreen(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            NodeAnalyticsScreen(node: node, onShowOnMap: onShowOnMap),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final intelligence = NodeIntelligenceData.fromNode(node);
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => _openAnalyticsScreen(context),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              theme,
              Icons.psychology,
              'Mesh Intelligence',
              context,
            ),
            const SizedBox(height: 12),

            // Primary metrics row - Health & Connectivity
            Row(
              children: [
                Expanded(
                  child: _IntelligenceGauge(
                    label: 'Health',
                    value: intelligence.healthScore,
                    icon: Icons.favorite,
                    color: _getHealthColor(intelligence.healthScore),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IntelligenceGauge(
                    label: 'Connectivity',
                    value: intelligence.connectivityScore,
                    icon: Icons.hub,
                    color: _getConnectivityColor(
                      intelligence.connectivityScore,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Secondary metrics
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IntelligenceChip(
                  icon: _getMobilityIcon(intelligence.mobilityClass),
                  label: intelligence.mobilityClass,
                  color: _getMobilityColor(intelligence.mobilityClass),
                ),
                _IntelligenceChip(
                  icon: Icons.people,
                  label: '${intelligence.neighborCount} neighbors',
                  color: intelligence.neighborCount > 5
                      ? Colors.green
                      : intelligence.neighborCount > 0
                      ? Colors.amber
                      : Colors.grey,
                ),
                _IntelligenceChip(
                  icon: Icons.wifi_tethering,
                  label: '${intelligence.gatewayCount} gateways',
                  color: intelligence.gatewayCount > 2
                      ? Colors.green
                      : intelligence.gatewayCount > 0
                      ? Colors.amber
                      : Colors.grey,
                ),
                _ActivityChip(activity: intelligence.activityLevel),
              ],
            ),

            // Channel utilization bar if available
            if (intelligence.channelUtilization != null) ...[
              const SizedBox(height: 12),
              _ChannelUtilizationBar(
                utilization: intelligence.channelUtilization!,
                accentColor: accentColor,
              ),
            ],

            // Tap hint
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'Tap for deep analytics',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 14, color: accentColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    IconData icon,
    String title,
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'DERIVED',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getHealthColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.5) return Colors.amber;
    if (score >= 0.3) return Colors.orange;
    return Colors.red;
  }

  Color _getConnectivityColor(double score) {
    if (score >= 0.7) return Colors.green;
    if (score >= 0.4) return Colors.amber;
    return Colors.orange;
  }

  IconData _getMobilityIcon(String mobility) {
    switch (mobility) {
      case 'Infrastructure':
        return Icons.cell_tower;
      case 'Mobile':
        return Icons.smartphone;
      case 'Tracker':
        return Icons.gps_fixed;
      case 'Elevated':
        return Icons.terrain;
      case 'Stationary':
        return Icons.location_on;
      default:
        return Icons.help_outline;
    }
  }

  Color _getMobilityColor(String mobility) {
    switch (mobility) {
      case 'Infrastructure':
        return Colors.purple;
      case 'Mobile':
        return Colors.teal;
      case 'Tracker':
        return Colors.orange;
      case 'Elevated':
        return Colors.blue;
      case 'Stationary':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}

/// Circular gauge showing a 0-1 score with glow effect
class _IntelligenceGauge extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _IntelligenceGauge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CustomPaint(
              painter: _GaugePainter(value: value, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background arc
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Value arc with glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = math.pi * 1.5 * value;

    // Draw glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      sweepAngle,
      false,
      glowPaint,
    );

    // Draw value arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      value != oldDelegate.value || color != oldDelegate.color;
}

/// Compact chip showing a single intelligence metric
class _IntelligenceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _IntelligenceChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Activity level chip with color coding
class _ActivityChip extends StatelessWidget {
  final String activity;

  const _ActivityChip({required this.activity});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getActivityConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            activity,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _getActivityConfig() {
    switch (activity) {
      case 'Hot':
        return (Icons.local_fire_department, Colors.red);
      case 'Active':
        return (Icons.bolt, Colors.orange);
      case 'Quiet':
        return (Icons.nights_stay, Colors.blue);
      case 'Cold':
        return (Icons.ac_unit, Colors.blueGrey);
      default:
        return (Icons.help_outline, Colors.grey);
    }
  }
}

/// Channel utilization progress bar
class _ChannelUtilizationBar extends StatelessWidget {
  final double utilization;
  final Color accentColor;

  const _ChannelUtilizationBar({
    required this.utilization,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = utilization > 50
        ? Colors.red
        : utilization > 25
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.darkBorder.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Channel Utilization',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              Text(
                '${utilization.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: utilization / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
