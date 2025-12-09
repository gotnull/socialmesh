import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing air quality metrics history
class AirQualityLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const AirQualityLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodeAirQualityMetricsLogsProvider(nodeNum!))
        : ref.watch(airQualityMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? 'All Nodes';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Air Quality Log',
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
      body: SafeArea(
        child: Column(
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
                    return _buildEmptyState('No air quality data recorded yet');
                  }
                  final sortedLogs = logs.reversed.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedLogs.length,
                    itemBuilder: (context, index) {
                      return _AirQualityCard(log: sortedLogs[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.air, size: 64, color: Colors.white.withValues(alpha: 0.3)),
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

class _AirQualityCard extends StatelessWidget {
  final AirQualityMetricsLog log;

  const _AirQualityCard({required this.log});

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
              if (log.pm25Standard != null)
                _AqiIndicator(pm25: log.pm25Standard!),
            ],
          ),
          const SizedBox(height: 16),

          // PM values
          Text(
            'Particulate Matter (Standard)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (log.pm10Standard != null)
                Expanded(
                  child: _PmTile(label: 'PM1.0', value: log.pm10Standard!),
                ),
              if (log.pm25Standard != null)
                Expanded(
                  child: _PmTile(
                    label: 'PM2.5',
                    value: log.pm25Standard!,
                    highlight: true,
                  ),
                ),
              if (log.pm100Standard != null)
                Expanded(
                  child: _PmTile(label: 'PM10', value: log.pm100Standard!),
                ),
            ],
          ),

          // Environmental PM
          if (log.pm10Environmental != null ||
              log.pm25Environmental != null) ...[
            const SizedBox(height: 12),
            Text(
              'Particulate Matter (Environmental)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (log.pm10Environmental != null)
                  Expanded(
                    child: _PmTile(
                      label: 'PM1.0',
                      value: log.pm10Environmental!,
                    ),
                  ),
                if (log.pm25Environmental != null)
                  Expanded(
                    child: _PmTile(
                      label: 'PM2.5',
                      value: log.pm25Environmental!,
                    ),
                  ),
                if (log.pm100Environmental != null)
                  Expanded(
                    child: _PmTile(
                      label: 'PM10',
                      value: log.pm100Environmental!,
                    ),
                  ),
              ],
            ),
          ],

          // Particle counts
          if (log.particles03um != null || log.particles05um != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Text(
              'Particle Counts (per 0.1L)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (log.particles03um != null)
                  _ParticleChip(label: '>0.3µm', count: log.particles03um!),
                if (log.particles05um != null)
                  _ParticleChip(label: '>0.5µm', count: log.particles05um!),
                if (log.particles10um != null)
                  _ParticleChip(label: '>1.0µm', count: log.particles10um!),
                if (log.particles25um != null)
                  _ParticleChip(label: '>2.5µm', count: log.particles25um!),
                if (log.particles50um != null)
                  _ParticleChip(label: '>5.0µm', count: log.particles50um!),
                if (log.particles100um != null)
                  _ParticleChip(label: '>10µm', count: log.particles100um!),
              ],
            ),
          ],

          // CO2
          if (log.co2 != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            _Co2Indicator(ppm: log.co2!),
          ],
        ],
      ),
    );
  }
}

class _AqiIndicator extends StatelessWidget {
  final int pm25;

  const _AqiIndicator({required this.pm25});

  Color _getAqiColor() {
    if (pm25 <= 12) return AccentColors.green;
    if (pm25 <= 35) return AppTheme.warningYellow;
    if (pm25 <= 55) return AccentColors.orange;
    if (pm25 <= 150) return AppTheme.errorRed;
    return const Color(0xFF8B008B); // Purple for hazardous
  }

  String _getAqiLabel() {
    if (pm25 <= 12) return 'Good';
    if (pm25 <= 35) return 'Moderate';
    if (pm25 <= 55) return 'Unhealthy (S)';
    if (pm25 <= 150) return 'Unhealthy';
    return 'Hazardous';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getAqiColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getAqiLabel(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PmTile extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;

  const _PmTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlight
            ? AccentColors.teal.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: AccentColors.teal.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: highlight ? AccentColors.teal : Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            'µg/m³',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticleChip extends StatelessWidget {
  final String label;
  final int count;

  const _ParticleChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _Co2Indicator extends StatelessWidget {
  final int ppm;

  const _Co2Indicator({required this.ppm});

  Color _getCo2Color() {
    if (ppm < 800) return AccentColors.green;
    if (ppm < 1000) return AppTheme.warningYellow;
    if (ppm < 2000) return AccentColors.orange;
    return AppTheme.errorRed;
  }

  String _getCo2Label() {
    if (ppm < 800) return 'Excellent';
    if (ppm < 1000) return 'Good';
    if (ppm < 2000) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCo2Color();
    return Row(
      children: [
        Icon(Icons.co2, color: color, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$ppm ppm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              'CO₂ - ${_getCo2Label()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
