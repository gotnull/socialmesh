import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing environment metrics history (temperature, humidity, etc.)
class EnvironmentMetricsLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const EnvironmentMetricsLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodeEnvironmentMetricsLogsProvider(nodeNum!))
        : ref.watch(environmentMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? 'All Nodes';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Environment Metrics',
          style: TextStyle(
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
                  return _buildEmptyState('No environment data recorded yet');
                }
                final sortedLogs = logs.reversed.toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedLogs.length,
                  itemBuilder: (context, index) {
                    return _EnvironmentMetricsCard(log: sortedLogs[index]);
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
            Icons.thermostat_outlined,
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

class _EnvironmentMetricsCard extends StatelessWidget {
  final EnvironmentMetricsLog log;

  const _EnvironmentMetricsCard({required this.log});

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
          Text(
            timeFormat.format(log.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),

          // Temperature and Humidity row
          if (log.temperature != null || log.humidity != null)
            Row(
              children: [
                if (log.temperature != null)
                  Expanded(
                    child: _EnvironmentTile(
                      icon: Icons.thermostat,
                      label: 'Temperature',
                      value: '${log.temperature!.toStringAsFixed(1)}°C',
                      color: _getTemperatureColor(log.temperature!),
                    ),
                  ),
                if (log.humidity != null)
                  Expanded(
                    child: _EnvironmentTile(
                      icon: Icons.water_drop,
                      label: 'Humidity',
                      value: '${log.humidity!.toStringAsFixed(0)}%',
                      color: AccentColors.blue,
                    ),
                  ),
              ],
            ),

          // Additional metrics
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (log.barometricPressure != null)
                _MetricChip(
                  label: 'Pressure',
                  value: '${log.barometricPressure!.toStringAsFixed(0)} hPa',
                  icon: Icons.speed,
                ),
              if (log.lux != null)
                _MetricChip(
                  label: 'Light',
                  value: '${log.lux!.toStringAsFixed(0)} lux',
                  icon: Icons.light_mode,
                ),
              if (log.iaq != null)
                _MetricChip(
                  label: 'Air Quality',
                  value: log.iaq!.toString(),
                  icon: Icons.air,
                ),
              if (log.windSpeed != null)
                _MetricChip(
                  label: 'Wind',
                  value: '${log.windSpeed!.toStringAsFixed(1)} m/s',
                  icon: Icons.wind_power,
                ),
              if (log.rainfall1h != null)
                _MetricChip(
                  label: 'Rain',
                  value: '${log.rainfall1h!.toStringAsFixed(1)} mm',
                  icon: Icons.water,
                ),
              if (log.soilMoisture != null)
                _MetricChip(
                  label: 'Soil',
                  value: '${log.soilMoisture!.toStringAsFixed(0)}%',
                  icon: Icons.grass,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 0) return AccentColors.blue;
    if (temp < 15) return AccentColors.teal;
    if (temp < 25) return AccentColors.green;
    if (temp < 35) return AccentColors.orange;
    return AppTheme.errorRed;
  }
}

class _EnvironmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _EnvironmentTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
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
        Icon(icon, size: 14, color: AccentColors.purple),
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
                fontSize: 13,
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
