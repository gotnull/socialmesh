import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing detection sensor history
class DetectionSensorLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const DetectionSensorLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodeDetectionSensorLogsProvider(nodeNum!))
        : ref.watch(detectionSensorLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? 'All Nodes';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Detection Sensor Log',
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
                  return _buildEmptyState('No sensor events recorded yet');
                }
                final sortedLogs = logs.reversed.toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedLogs.length,
                  itemBuilder: (context, index) {
                    return _DetectionSensorCard(log: sortedLogs[index]);
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
            Icons.sensors_outlined,
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
          const SizedBox(height: 8),
          Text(
            'Detection sensors report motion and presence',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionSensorCard extends StatelessWidget {
  final DetectionSensorLog log;

  const _DetectionSensorCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: log.detected
            ? Border.all(color: AccentColors.orange.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Detection indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: log.detected
                  ? AccentColors.orange.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              log.detected ? Icons.sensors : Icons.sensors_off,
              color: log.detected ? AccentColors.orange : Colors.white38,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log.name.isNotEmpty ? log.name : 'Detection Sensor',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    _DetectionBadge(detected: log.detected),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(log.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionBadge extends StatelessWidget {
  final bool detected;

  const _DetectionBadge({required this.detected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: detected
            ? AccentColors.orange.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        detected ? 'DETECTED' : 'Clear',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: detected ? AccentColors.orange : Colors.white54,
        ),
      ),
    );
  }
}
