// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../models/world_mesh_node.dart';
import '../../utils/snackbar.dart';
import '../../models/presence_confidence.dart';
import '../../utils/presence_utils.dart';

/// Screen for comparing two mesh nodes side by side
class NodeComparisonScreen extends StatelessWidget {
  final WorldMeshNode nodeA;
  final WorldMeshNode nodeB;

  const NodeComparisonScreen({
    super.key,
    required this.nodeA,
    required this.nodeB,
  });

  @override
  Widget build(BuildContext context) {
    return GlassScaffold.body(
      title: 'Compare Nodes',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Node headers
            _buildNodeHeaders(context),
            const SizedBox(height: 24),

            // Status comparison
            _buildSectionHeader(context, 'Status'),
            const SizedBox(height: 8),
            _buildStatusComparison(context),
            const SizedBox(height: 24),

            // Device info comparison
            _buildSectionHeader(context, 'Device Info'),
            const SizedBox(height: 8),
            _buildDeviceComparison(),
            const SizedBox(height: 24),

            // Metrics comparison
            _buildSectionHeader(context, 'Metrics'),
            const SizedBox(height: 8),
            _buildMetricsComparison(),
            const SizedBox(height: 24),

            // Network comparison
            _buildSectionHeader(context, 'Network'),
            const SizedBox(height: 8),
            _buildNetworkComparison(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeHeaders(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildNodeCard(context, nodeA, Colors.blue)),
        SizedBox(width: 12),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.card,
            shape: BoxShape.circle,
            border: Border.all(color: context.border),
          ),
          child: Center(
            child: Text(
              'VS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: context.textTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildNodeCard(context, nodeB, Colors.orange)),
      ],
    );
  }

  Widget _buildNodeCard(BuildContext context, WorldMeshNode node, Color color) {
    final nodeId = node.nodeNum.toRadixString(16).toUpperCase();
    final statusColor = _presenceColor(context, node.presenceConfidence);
    final statusIcon = _presenceIcon(node.presenceConfidence);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(height: 8),
          AutoScrollText(
            node.displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: '!$nodeId'));
              showSuccessSnackBar(context, 'Node ID copied');
            },
            child: Text(
              '!$nodeId',
              style: TextStyle(
                fontSize: 11,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStatusComparison(BuildContext context) {
    return _ComparisonTable(
      rows: [
        _ComparisonRow(
          label: 'Status',
          valueA: presenceStatusText(
            nodeA.presenceConfidence,
            _lastSeenAge(nodeA),
          ),
          valueB: presenceStatusText(
            nodeB.presenceConfidence,
            _lastSeenAge(nodeB),
          ),
          colorA: _getStatusColor(context, nodeA),
          colorB: _getStatusColor(context, nodeB),
        ),
        _ComparisonRow(label: 'Role', valueA: nodeA.role, valueB: nodeB.role),
      ],
    );
  }

  Widget _buildDeviceComparison() {
    return _ComparisonTable(
      rows: [
        _ComparisonRow(
          label: 'Hardware',
          valueA: nodeA.hwModel.isNotEmpty ? nodeA.hwModel : 'Unknown',
          valueB: nodeB.hwModel.isNotEmpty ? nodeB.hwModel : 'Unknown',
        ),
        if (nodeA.fwVersion != null || nodeB.fwVersion != null)
          _ComparisonRow(
            label: 'Firmware',
            valueA: nodeA.fwVersion ?? '--',
            valueB: nodeB.fwVersion ?? '--',
          ),
        if (nodeA.region != null || nodeB.region != null)
          _ComparisonRow(
            label: 'Region',
            valueA: nodeA.region ?? '--',
            valueB: nodeB.region ?? '--',
          ),
      ],
    );
  }

  Widget _buildMetricsComparison() {
    return _ComparisonTable(
      rows: [
        _ComparisonRow(
          label: 'Battery',
          valueA: _formatBattery(nodeA.batteryLevel),
          valueB: _formatBattery(nodeB.batteryLevel),
          colorA: _getBatteryColor(nodeA.batteryLevel),
          colorB: _getBatteryColor(nodeB.batteryLevel),
          winner: _compareBattery(nodeA.batteryLevel, nodeB.batteryLevel),
        ),
        if (nodeA.voltage != null || nodeB.voltage != null)
          _ComparisonRow(
            label: 'Voltage',
            valueA: nodeA.voltage != null
                ? '${nodeA.voltage!.toStringAsFixed(2)}V'
                : '--',
            valueB: nodeB.voltage != null
                ? '${nodeB.voltage!.toStringAsFixed(2)}V'
                : '--',
            winner: _compareValues(nodeA.voltage, nodeB.voltage),
          ),
        _ComparisonRow(
          label: 'Channel Util',
          valueA: nodeA.chUtil != null
              ? '${nodeA.chUtil!.toStringAsFixed(1)}%'
              : '--',
          valueB: nodeB.chUtil != null
              ? '${nodeB.chUtil!.toStringAsFixed(1)}%'
              : '--',
          // Lower is better for channel util
          winner: _compareValues(nodeB.chUtil, nodeA.chUtil),
        ),
        _ComparisonRow(
          label: 'Air Time TX',
          valueA: nodeA.airUtilTx != null
              ? '${nodeA.airUtilTx!.toStringAsFixed(1)}%'
              : '--',
          valueB: nodeB.airUtilTx != null
              ? '${nodeB.airUtilTx!.toStringAsFixed(1)}%'
              : '--',
        ),
        _ComparisonRow(
          label: 'Uptime',
          valueA: _formatUptime(nodeA.uptime),
          valueB: _formatUptime(nodeB.uptime),
          winner: _compareValues(
            nodeA.uptime?.toDouble(),
            nodeB.uptime?.toDouble(),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkComparison() {
    final neighborsA = nodeA.neighbors?.length ?? 0;
    final neighborsB = nodeB.neighbors?.length ?? 0;
    final gatewaysA = nodeA.seenBy.length;
    final gatewaysB = nodeB.seenBy.length;

    return _ComparisonTable(
      rows: [
        _ComparisonRow(
          label: 'Neighbors',
          valueA: '$neighborsA',
          valueB: '$neighborsB',
          winner: _compareInts(neighborsA, neighborsB),
        ),
        _ComparisonRow(
          label: 'Gateways',
          valueA: '$gatewaysA',
          valueB: '$gatewaysB',
          winner: _compareInts(gatewaysA, gatewaysB),
        ),
        if ((nodeA.latitude != 0 && nodeA.longitude != 0) ||
            (nodeB.latitude != 0 && nodeB.longitude != 0))
          _ComparisonRow(
            label: 'Has Location',
            valueA: nodeA.latitude != 0 ? 'Yes' : 'No',
            valueB: nodeB.latitude != 0 ? 'Yes' : 'No',
          ),
      ],
    );
  }

  Color _getStatusColor(BuildContext context, WorldMeshNode node) {
    return _presenceColor(context, node.presenceConfidence);
  }

  Color _presenceColor(BuildContext context, PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return AccentColors.green;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  IconData _presenceIcon(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return Icons.wifi;
      case PresenceConfidence.fading:
        return Icons.wifi_1_bar;
      case PresenceConfidence.stale:
        return Icons.wifi_off;
      case PresenceConfidence.unknown:
        return Icons.help_outline;
    }
  }

  Duration? _lastSeenAge(WorldMeshNode node) {
    final lastSeen = node.lastSeen;
    if (lastSeen == null) return null;
    return DateTime.now().difference(lastSeen);
  }

  String _formatBattery(int? level) {
    if (level == null) return '--';
    if (level > 100) return 'Charging';
    return '$level%';
  }

  Color? _getBatteryColor(int? level) {
    if (level == null) return null;
    if (level > 100) return AccentColors.green;
    if (level > 50) return AccentColors.green;
    if (level > 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  int? _compareBattery(int? a, int? b) {
    if (a == null && b == null) return null;
    if (a == null) return -1;
    if (b == null) return 1;
    // Charging (>100) is best
    if (a > 100 && b <= 100) return 1;
    if (b > 100 && a <= 100) return -1;
    if (a > b) return 1;
    if (b > a) return -1;
    return null;
  }

  int? _compareValues(double? a, double? b) {
    if (a == null && b == null) return null;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a > b) return 1;
    if (b > a) return -1;
    return null;
  }

  int? _compareInts(int a, int b) {
    if (a > b) return 1;
    if (b > a) return -1;
    return null;
  }

  String _formatUptime(int? seconds) {
    if (seconds == null) return '--';
    final duration = Duration(seconds: seconds);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _ComparisonRow {
  final String label;
  final String valueA;
  final String valueB;
  final Color? colorA;
  final Color? colorB;
  final int? winner; // 1 = A wins, -1 = B wins, null = tie/NA

  const _ComparisonRow({
    required this.label,
    required this.valueA,
    required this.valueB,
    this.colorA,
    this.colorB,
    this.winner,
  });
}

class _ComparisonTable extends StatelessWidget {
  final List<_ComparisonRow> rows;

  const _ComparisonTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _buildRow(context, rows[i]),
              if (i < rows.length - 1)
                Container(height: 1, color: context.border),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _ComparisonRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Value A
          Expanded(
            child: Row(
              children: [
                if (row.winner == 1)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AccentColors.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 10,
                      color: AccentColors.green,
                    ),
                  ),
                Expanded(
                  child: Text(
                    row.valueA,
                    style: TextStyle(
                      fontSize: 13,
                      color: row.colorA ?? Colors.white,
                      fontWeight: row.winner == 1
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Label (center)
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              row.label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.textTertiary),
            ),
          ),

          // Value B
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    row.valueB,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      color: row.colorB ?? Colors.white,
                      fontWeight: row.winner == -1
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (row.winner == -1)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AccentColors.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 10,
                      color: AccentColors.green,
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
