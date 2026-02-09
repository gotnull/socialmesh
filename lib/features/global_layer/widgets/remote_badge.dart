// SPDX-License-Identifier: GPL-3.0-or-later

/// Remote Badge — compact indicator for nodes discovered via the
/// Global Layer MQTT broker.
///
/// This widget displays a small "Remote" or "Mixed" badge next to
/// node names in the NodeDex list and detail screens. It adapts to
/// the [NodeDiscoverySource] to show the appropriate label and color.
///
/// Usage:
/// ```dart
/// RemoteBadge(source: NodeDiscoverySource.remote)
/// RemoteBadge.fromNodeNum(ref: ref, nodeNum: 12345)
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_remote_sighting.dart';
import '../../../core/theme.dart';
import '../../../providers/mqtt_nodedex_providers.dart';

/// Compact badge indicating a node's discovery source.
///
/// Shows nothing for [NodeDiscoverySource.local] nodes (the default).
/// Shows a tinted pill badge for [NodeDiscoverySource.remote] and
/// [NodeDiscoverySource.mixed] nodes.
class RemoteBadge extends StatelessWidget {
  /// The discovery source to display.
  final NodeDiscoverySource source;

  /// Optional size variant. When true, uses a smaller font and padding
  /// suitable for inline display next to hex IDs.
  final bool compact;

  const RemoteBadge({super.key, required this.source, this.compact = false});

  /// Creates a [RemoteBadge] that watches the discovery source provider
  /// for the given [nodeNum].
  ///
  /// This is a convenience constructor for use inside [ConsumerWidget]
  /// or [ConsumerStatefulWidget] build methods where a [WidgetRef] is
  /// available.
  ///
  /// Returns [SizedBox.shrink] if the node is local-only.
  static Widget fromNodeNum({
    required WidgetRef ref,
    required int nodeNum,
    bool compact = false,
  }) {
    final isRemote = ref.watch(isRemoteNodeProvider(nodeNum));
    if (!isRemote) return const SizedBox.shrink();

    final source = ref.watch(nodeDiscoverySourceProvider(nodeNum));
    if (source == NodeDiscoverySource.local) return const SizedBox.shrink();

    return RemoteBadge(source: source, compact: compact);
  }

  @override
  Widget build(BuildContext context) {
    // Local nodes do not show a badge.
    if (source == NodeDiscoverySource.local) return const SizedBox.shrink();

    final (label, color) = switch (source) {
      NodeDiscoverySource.remote => ('Remote', _remoteColor),
      NodeDiscoverySource.mixed => ('Mixed', _mixedColor),
      NodeDiscoverySource.local => ('', Colors.transparent),
    };

    final fontSize = compact ? 8.0 : 9.0;
    final horizontalPadding = compact ? 5.0 : 7.0;
    final verticalPadding = compact ? 1.5 : 2.5;
    final iconSize = compact ? 8.0 : 10.0;

    return Tooltip(
      message: source.description,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              source == NodeDiscoverySource.remote
                  ? Icons.cloud_outlined
                  : Icons.sync_alt,
              size: iconSize,
              color: color,
            ),
            SizedBox(width: compact ? 2 : 3),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: AppTheme.fontFamily,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Teal-ish blue for remote-only nodes — visually distinct from
  /// the green "online" indicator and the purple accent.
  static const Color _remoteColor = Color(0xFF38BDF8);

  /// Amber for mixed-source nodes — signals dual discovery without
  /// alarm. Distinct from warning yellow by being slightly cooler.
  static const Color _mixedColor = Color(0xFFFBBF24);
}

/// A larger badge variant for the NodeDex detail screen header.
///
/// Shows the full discovery source label with a description subtitle
/// and the broker/topic context when available.
class RemoteSourceBadge extends ConsumerWidget {
  /// The node number to look up discovery source for.
  final int nodeNum;

  const RemoteSourceBadge({super.key, required this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRemote = ref.watch(isRemoteNodeProvider(nodeNum));
    if (!isRemote) return const SizedBox.shrink();

    final source = ref.watch(nodeDiscoverySourceProvider(nodeNum));
    if (source == NodeDiscoverySource.local) return const SizedBox.shrink();

    final sightings = ref.watch(remoteSightingsProvider);
    final latestSighting = sightings.lastWhere(
      (s) => s.nodeNum == nodeNum,
      orElse: () => RemoteSighting(
        nodeNum: nodeNum,
        timestamp: DateTime.now(),
        topic: '',
        brokerUri: '',
      ),
    );

    final (label, color, icon) = switch (source) {
      NodeDiscoverySource.remote => (
        'Remote Discovery',
        RemoteBadge._remoteColor,
        Icons.cloud_outlined,
      ),
      NodeDiscoverySource.mixed => (
        'Local + Remote',
        RemoteBadge._mixedColor,
        Icons.sync_alt,
      ),
      NodeDiscoverySource.local => ('', Colors.transparent, Icons.cell_tower),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              if (latestSighting.topic.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'via ${latestSighting.topic}',
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.7),
                    fontFamily: AppTheme.fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
