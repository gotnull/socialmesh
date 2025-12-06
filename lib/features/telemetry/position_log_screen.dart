import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing position history log with map option
class PositionLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const PositionLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodePositionLogsProvider(nodeNum!))
        : ref.watch(positionLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? 'All Nodes';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Position History',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Show on Map',
            onPressed: () {
              // Navigate to map with positions
              Navigator.pushNamed(
                context,
                '/map',
                arguments: {'nodeNum': nodeNum, 'showTrail': true},
              );
            },
          ),
        ],
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
                  return _buildEmptyState('No positions recorded yet');
                }
                final sortedLogs = logs.reversed.toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedLogs.length,
                  itemBuilder: (context, index) {
                    return _PositionCard(
                      log: sortedLogs[index],
                      previousLog: index < sortedLogs.length - 1
                          ? sortedLogs[index + 1]
                          : null,
                    );
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
            Icons.location_off_outlined,
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

class _PositionCard extends StatelessWidget {
  final PositionLog log;
  final PositionLog? previousLog;

  const _PositionCard({required this.log, this.previousLog});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, h:mm a');
    final distance = previousLog != null
        ? _calculateDistance(log, previousLog!)
        : null;

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
              if (distance != null && distance > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AccentColors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDistance(distance),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AccentColors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Coordinates
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: AccentColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.latitude.toStringAsFixed(6)}, ${log.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Additional info
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (log.altitude != null)
                _InfoChip(
                  icon: Icons.terrain,
                  label: 'Altitude',
                  value: '${log.altitude}m',
                ),
              if (log.heading != null)
                _InfoChip(
                  icon: Icons.navigation,
                  label: 'Heading',
                  value: '${log.heading}°',
                ),
              if (log.speed != null)
                _InfoChip(
                  icon: Icons.speed,
                  label: 'Speed',
                  value: '${log.speed} m/s',
                ),
              if (log.satsInView != null)
                _InfoChip(
                  icon: Icons.satellite_alt,
                  label: 'Satellites',
                  value: '${log.satsInView}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateDistance(PositionLog a, PositionLog b) {
    // Haversine formula
    const r = 6371000.0; // Earth's radius in meters
    final lat1 = a.latitude * 3.141592653589793 / 180;
    final lat2 = b.latitude * 3.141592653589793 / 180;
    final dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180;
    final dLon = (b.longitude - a.longitude) * 3.141592653589793 / 180;

    final sinDLat = _sin(dLat / 2);
    final sinDLon = _sin(dLon / 2);

    final aCalc =
        sinDLat * sinDLat + _cos(lat1) * _cos(lat2) * sinDLon * sinDLon;
    final c = 2 * _atan2(_sqrt(aCalc), _sqrt(1 - aCalc));

    return r * c;
  }

  double _sin(double x) {
    double result = 0;
    double term = x;
    for (int n = 0; n < 10; n++) {
      result += term;
      term *= -x * x / ((2 * n + 2) * (2 * n + 3));
    }
    return result;
  }

  double _cos(double x) => _sin(x + 1.5707963267948966);

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  double _atan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atan(1 / x);
    }
    double result = 0;
    double term = x;
    for (int n = 0; n < 20; n++) {
      result += term / (2 * n + 1);
      term *= -x * x;
    }
    return result;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AccentColors.purple),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
