// SPDX-License-Identifier: GPL-3.0-or-later

// Mesh 3D Stats Card
//
// A compact summary card displayed above the 3D viewport showing key mesh
// metrics at a glance: total nodes, active count, GPS count, average SNR,
// and channel utilization. Follows the NodeDex _CompactStat visual pattern
// with glass-style card background and consistent typography.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/presence_providers.dart';

// ---------------------------------------------------------------------------
// Mesh3DStats — computed summary data for the stats card
// ---------------------------------------------------------------------------

/// Pre-computed statistics for the Mesh 3D stats card.
///
/// The main screen computes this from the current node map and passes it
/// down to avoid repeated iteration inside the card widget.
class Mesh3DStats {
  final int totalNodes;
  final int activeNodes;
  final int gpsNodes;
  final double? avgSnr;
  final double? channelUtil;

  const Mesh3DStats({
    required this.totalNodes,
    required this.activeNodes,
    required this.gpsNodes,
    this.avgSnr,
    this.channelUtil,
  });

  /// Compute stats from a node map and presence data.
  factory Mesh3DStats.fromNodes({
    required Map<int, MeshNode> nodes,
    required Map<int, NodePresence> presenceMap,
    double? channelUtil,
  }) {
    int active = 0;
    int gps = 0;
    double snrSum = 0;
    int snrCount = 0;

    for (final node in nodes.values) {
      final presence = presenceConfidenceFor(presenceMap, node);
      if (presence.isActive) active++;
      if (node.latitude != null &&
          node.longitude != null &&
          node.latitude != 0 &&
          node.longitude != 0) {
        gps++;
      }
      if (node.snr != null) {
        snrSum += node.snr!;
        snrCount++;
      }
    }

    return Mesh3DStats(
      totalNodes: nodes.length,
      activeNodes: active,
      gpsNodes: gps,
      avgSnr: snrCount > 0 ? snrSum / snrCount : null,
      channelUtil: channelUtil,
    );
  }
}

// ---------------------------------------------------------------------------
// Mesh3DStatsCard widget
// ---------------------------------------------------------------------------

/// A compact, glass-styled stats card that summarises the current mesh state.
///
/// Designed to sit between the filter chip row and the 3D viewport. Uses the
/// same visual language as NodeDex's stats card: horizontal row of icon + value
/// pairs inside a translucent card with subtle border.
class Mesh3DStatsCard extends StatelessWidget {
  final Mesh3DStats stats;

  const Mesh3DStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.card.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.border.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                _CompactStat(
                  icon: Icons.hub,
                  value: stats.totalNodes.toString(),
                  label: 'Total',
                  color: context.accentColor,
                ),
                _separator(context),
                _CompactStat(
                  icon: Icons.wifi,
                  value: stats.activeNodes.toString(),
                  label: 'Active',
                  color: AppTheme.successGreen,
                ),
                _separator(context),
                _CompactStat(
                  icon: Icons.gps_fixed,
                  value: stats.gpsNodes.toString(),
                  label: 'GPS',
                  color: AccentColors.cyan,
                ),
                if (stats.avgSnr != null) ...[
                  _separator(context),
                  _CompactStat(
                    icon: Icons.signal_cellular_alt,
                    value: '${stats.avgSnr!.toStringAsFixed(1)}dB',
                    label: 'SNR',
                    color: _snrColor(stats.avgSnr!),
                  ),
                ],
                if (stats.channelUtil != null) ...[
                  _separator(context),
                  _CompactStat(
                    icon: Icons.stacked_bar_chart,
                    value: '${stats.channelUtil!.toStringAsFixed(0)}%',
                    label: 'Ch Util',
                    color: _channelUtilColor(stats.channelUtil!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _separator(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: context.border.withValues(alpha: 0.15),
    );
  }

  Color _snrColor(double snr) {
    if (snr >= 5) return AppTheme.successGreen;
    if (snr >= 0) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  Color _channelUtilColor(double util) {
    if (util < 25) return AppTheme.successGreen;
    if (util < 50) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

// ---------------------------------------------------------------------------
// _CompactStat — individual metric display
// ---------------------------------------------------------------------------

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
