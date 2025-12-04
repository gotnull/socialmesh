import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../models/mesh_models.dart';
import 'dashboard_widget.dart';

/// Nearby Nodes Widget - Shows closest nodes by signal strength
class NearbyNodesContent extends ConsumerWidget {
  const NearbyNodesContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Filter out our own node and sort by RSSI (strongest first)
    final nearbyNodes =
        nodes.values
            .where((n) => n.nodeNum != myNodeNum && n.rssi != null)
            .toList()
          ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));

    final topNodes = nearbyNodes.take(5).toList();

    if (topNodes.isEmpty) {
      return const WidgetEmptyState(
        icon: Icons.near_me,
        message: 'No nearby nodes detected',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: topNodes.length,
      separatorBuilder: (_, i) => Divider(
        height: 1,
        color: AppTheme.darkBorder.withValues(alpha: 0.5),
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final node = topNodes[index];
        return _NodeTile(node: node);
      },
    );
  }
}

class _NodeTile extends StatelessWidget {
  final MeshNode node;

  const _NodeTile({required this.node});

  @override
  Widget build(BuildContext context) {
    final rssi = node.rssi ?? -100;
    final signalColor = _getSignalColor(rssi);
    final lastSeen = node.lastHeard != null
        ? _formatLastSeen(node.lastHeard!)
        : 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Signal indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: signalColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.signal_cellular_alt, color: signalColor, size: 16),
                Text(
                  '$rssi',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: signalColor,
                    
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Node info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (node.isFavorite)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.star,
                          size: 12,
                          color: AppTheme.warningYellow,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        node.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (node.role != null) ...[
                      _RoleChip(role: node.role!),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      lastSeen,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                        
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Battery if available
          if (node.batteryLevel != null)
            _BatteryIndicator(level: node.batteryLevel!),
        ],
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -60) return AppTheme.primaryGreen;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  String _formatLastSeen(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final displayRole = role.replaceAll('_', ' ').toLowerCase();
    final isRouter = role.contains('ROUTER');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isRouter
            ? AppTheme.primaryGreen.withValues(alpha: 0.15)
            : AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isRouter
              ? AppTheme.primaryGreen.withValues(alpha: 0.3)
              : AppTheme.darkBorder,
        ),
      ),
      child: Text(
        displayRole,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isRouter ? AppTheme.primaryGreen : AppTheme.textTertiary,
          
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  final int level;

  const _BatteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level > 100
        ? AppTheme
              .primaryGreen // Charging
        : level >= 50
        ? AppTheme.primaryGreen
        : level >= 20
        ? AppTheme.warningYellow
        : AppTheme.errorRed;

    final icon = level > 100
        ? Icons.battery_charging_full
        : level >= 80
        ? Icons.battery_full
        : level >= 50
        ? Icons.battery_5_bar
        : level >= 20
        ? Icons.battery_3_bar
        : Icons.battery_alert;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        if (level <= 100)
          Text(
            '$level%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              
            ),
          ),
      ],
    );
  }
}
