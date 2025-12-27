import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';
import '../../../providers/app_providers.dart';

/// Mesh Health Widget - Overall mesh network health metrics
class MeshHealthContent extends ConsumerWidget {
  const MeshHealthContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final rssiAsync = ref.watch(currentRssiProvider);
    final channelUtilAsync = ref.watch(currentChannelUtilProvider);

    final isConnected = connectionStateAsync.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    final rssi = rssiAsync.value;
    final channelUtil = channelUtilAsync.value;

    // Calculate health score (0-100)
    final healthScore = _calculateHealthScore(
      isConnected: isConnected,
      nodeCount: nodes.length,
      rssi: rssi,
      channelUtil: channelUtil,
    );

    final healthStatus = _getHealthStatus(healthScore);
    final healthColor = _getHealthColor(healthScore);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Health score circle
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: context.border,
                    valueColor: AlwaysStoppedAnimation(
                      context.border.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: healthScore / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(healthColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Score text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${healthScore.round()}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: healthColor,
                      ),
                    ),
                    Text(
                      healthStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: healthColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Health factors
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HealthFactor(
                icon: Icons.link,
                label: 'Connection',
                status: isConnected ? 'Online' : 'Offline',
                isGood: isConnected,
              ),
              _HealthFactor(
                icon: Icons.people,
                label: 'Nodes',
                status: '${nodes.length}',
                isGood: nodes.length > 1,
              ),
              _HealthFactor(
                icon: Icons.signal_cellular_alt,
                label: 'Signal',
                status: rssi != null ? '${rssi}dBm' : '--',
                isGood: rssi != null && rssi >= -75,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateHealthScore({
    required bool isConnected,
    required int nodeCount,
    required int? rssi,
    required double? channelUtil,
  }) {
    if (!isConnected) return 0;

    double score = 50; // Base score for being connected

    // Node count bonus (up to 20 points)
    if (nodeCount > 1) {
      score += (nodeCount - 1).clamp(0, 10) * 2;
    }

    // Signal strength bonus (up to 20 points)
    if (rssi != null) {
      if (rssi >= -50) {
        score += 20;
      } else if (rssi >= -60) {
        score += 15;
      } else if (rssi >= -70) {
        score += 10;
      } else if (rssi >= -80) {
        score += 5;
      }
    }

    // Channel utilization (up to 10 points, lower is better)
    if (channelUtil != null) {
      if (channelUtil <= 25) {
        score += 10;
      } else if (channelUtil <= 50) {
        score += 5;
      }
    }

    return score.clamp(0, 100);
  }

  String _getHealthStatus(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score > 0) return 'Poor';
    return 'Offline';
  }

  Color _getHealthColor(double score) {
    if (score >= 70) return AccentColors.green;
    if (score >= 40) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

class _HealthFactor extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool isGood;

  const _HealthFactor({
    required this.icon,
    required this.label,
    required this.status,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: isGood ? context.accentColor : context.textTertiary,
        ),
        SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isGood ? Colors.white : context.textSecondary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.textTertiary),
        ),
      ],
    );
  }
}
