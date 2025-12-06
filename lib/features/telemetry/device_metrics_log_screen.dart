import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing device metrics history (battery, voltage, etc.)
class DeviceMetricsLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const DeviceMetricsLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodeDeviceMetricsLogsProvider(nodeNum!))
        : ref.watch(deviceMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? 'All Nodes';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          'Device Metrics',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              nodeName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return _buildEmptyState('No device metrics recorded yet');
                }
                // Show newest first
                final sortedLogs = logs.reversed.toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedLogs.length,
                  itemBuilder: (context, index) {
                    return _DeviceMetricsCard(log: sortedLogs[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.memory_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceMetricsCard extends StatelessWidget {
  final DeviceMetricsLog log;

  const _DeviceMetricsCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeFormat.format(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              if (log.batteryLevel != null)
                _BatteryIndicator(level: log.batteryLevel!),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              if (log.batteryLevel != null)
                _MetricChip(
                  label: 'Battery',
                  value: '${log.batteryLevel}%',
                  icon: Icons.battery_full,
                ),
              if (log.voltage != null)
                _MetricChip(
                  label: 'Voltage',
                  value: '${log.voltage!.toStringAsFixed(2)}V',
                  icon: Icons.electric_bolt,
                ),
              if (log.channelUtilization != null)
                _MetricChip(
                  label: 'Ch. Util',
                  value: '${log.channelUtilization!.toStringAsFixed(1)}%',
                  icon: Icons.signal_cellular_alt,
                ),
              if (log.airUtilTx != null)
                _MetricChip(
                  label: 'Air Util TX',
                  value: '${log.airUtilTx!.toStringAsFixed(1)}%',
                  icon: Icons.wifi,
                ),
              if (log.uptimeSeconds != null)
                _MetricChip(
                  label: 'Uptime',
                  value: _formatUptime(log.uptimeSeconds!),
                  icon: Icons.timer_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) {
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    }
    return '${seconds ~/ 86400}d ${(seconds % 86400) ~/ 3600}h';
  }
}

class _BatteryIndicator extends StatelessWidget {
  final int level;

  const _BatteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (level > 100) {
      color = AccentColors.green; // Charging
    } else if (level >= 50) {
      color = AccentColors.green;
    } else if (level >= 20) {
      color = AppTheme.warningYellow;
    } else {
      color = AppTheme.errorRed;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          level > 100 ? Icons.battery_charging_full : Icons.battery_full,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${level > 100 ? 100 : level}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AccentColors.blue),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
