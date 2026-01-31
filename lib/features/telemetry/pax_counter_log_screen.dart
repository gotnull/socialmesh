import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing PAX counter history (BLE/WiFi device counts)
class PaxCounterLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const PaxCounterLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodePaxCounterLogsProvider(nodeNum!))
        : ref.watch(paxCounterLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? 'All Nodes';

    return GlassScaffold(
      title: 'PAX Counter Log',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              nodeName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ),
        ),
        logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return SliverFillRemaining(
                child: _buildEmptyState(context, 'No PAX data recorded yet'),
              );
            }
            final sortedLogs = logs.reversed.toList();
            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _PaxCounterCard(log: sortedLogs[index]),
                  childCount: sortedLogs.length,
                ),
              ),
            );
          },
          loading: () =>
              const SliverFillRemaining(child: ScreenLoadingIndicator()),
          error: (e, _) =>
              SliverFillRemaining(child: Center(child: Text('Error: $e'))),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: context.textTertiary),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: context.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'PAX counter detects nearby devices',
            style: TextStyle(fontSize: 14, color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _PaxCounterCard extends StatelessWidget {
  final PaxCounterLog log;

  const _PaxCounterCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, h:mm a');
    final totalDevices = log.ble + log.wifi;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
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
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AccentColors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people,
                      size: 14,
                      color: AccentColors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalDevices',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AccentColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // BLE and WiFi counts
          Row(
            children: [
              Expanded(
                child: _DeviceCountTile(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  count: log.ble,
                  color: AccentColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DeviceCountTile(
                  icon: Icons.wifi,
                  label: 'WiFi',
                  count: log.wifi,
                  color: AccentColors.purple,
                ),
              ),
            ],
          ),

          // Uptime if available
          if (log.uptime > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Uptime: ${_formatUptime(log.uptime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
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

class _DeviceCountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _DeviceCountTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }
}
