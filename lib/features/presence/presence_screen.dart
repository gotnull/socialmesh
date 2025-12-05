import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Presence status based on recent radio activity
enum PresenceStatus { active, idle, offline }

extension PresenceStatusExt on PresenceStatus {
  String get label {
    switch (this) {
      case PresenceStatus.active:
        return 'Active';
      case PresenceStatus.idle:
        return 'Idle';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }

  String get description {
    switch (this) {
      case PresenceStatus.active:
        return 'Heard within 2 minutes';
      case PresenceStatus.idle:
        return 'Heard within 15 minutes';
      case PresenceStatus.offline:
        return 'Not heard recently';
    }
  }

  Color get color {
    switch (this) {
      case PresenceStatus.active:
        return AppTheme.successGreen;
      case PresenceStatus.idle:
        return AppTheme.warningYellow;
      case PresenceStatus.offline:
        return AppTheme.textTertiary;
    }
  }

  IconData get icon {
    switch (this) {
      case PresenceStatus.active:
        return Icons.circle;
      case PresenceStatus.idle:
        return Icons.circle_outlined;
      case PresenceStatus.offline:
        return Icons.radio_button_unchecked;
    }
  }
}

/// Node with presence information
class NodePresence {
  final MeshNode node;
  final PresenceStatus status;
  final Duration? timeSinceLastHeard;
  final double? signalQuality; // 0.0 to 1.0

  NodePresence({
    required this.node,
    required this.status,
    this.timeSinceLastHeard,
    this.signalQuality,
  });

  static PresenceStatus calculateStatus(DateTime? lastHeard) {
    if (lastHeard == null) return PresenceStatus.offline;

    final diff = DateTime.now().difference(lastHeard);
    if (diff.inMinutes < 2) return PresenceStatus.active;
    if (diff.inMinutes < 15) return PresenceStatus.idle;
    return PresenceStatus.offline;
  }

  static double? calculateSignalQuality(MeshNode node) {
    final snr = node.snr;
    if (snr == null) return null;

    // SNR ranges from about -20 to +10 dB for LoRa
    // Map to 0.0-1.0 scale
    final normalized = (snr + 20) / 30;
    return normalized.clamp(0.0, 1.0);
  }
}

/// Provider for node presence data
final nodePresenceProvider = Provider<List<NodePresence>>((ref) {
  final nodes = ref.watch(nodesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  return nodes.values.where((node) => node.nodeNum != myNodeNum).map((node) {
    final status = NodePresence.calculateStatus(node.lastHeard);
    final timeSince = node.lastHeard != null
        ? DateTime.now().difference(node.lastHeard!)
        : null;
    final signalQuality = NodePresence.calculateSignalQuality(node);

    return NodePresence(
      node: node,
      status: status,
      timeSinceLastHeard: timeSince,
      signalQuality: signalQuality,
    );
  }).toList()..sort((a, b) {
    // Sort by status (active first), then by time since last heard
    final statusCompare = a.status.index.compareTo(b.status.index);
    if (statusCompare != 0) return statusCompare;

    final aTime = a.timeSinceLastHeard?.inSeconds ?? double.maxFinite.toInt();
    final bTime = b.timeSinceLastHeard?.inSeconds ?? double.maxFinite.toInt();
    return aTime.compareTo(bTime);
  });
});

/// Summary counts for presence
final presenceSummaryProvider = Provider<Map<PresenceStatus, int>>((ref) {
  final presences = ref.watch(nodePresenceProvider);
  final counts = <PresenceStatus, int>{
    PresenceStatus.active: 0,
    PresenceStatus.idle: 0,
    PresenceStatus.offline: 0,
  };

  for (final presence in presences) {
    counts[presence.status] = (counts[presence.status] ?? 0) + 1;
  }

  return counts;
});

class PresenceScreen extends ConsumerStatefulWidget {
  const PresenceScreen({super.key});

  @override
  ConsumerState<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends ConsumerState<PresenceScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every 30 seconds to update presence states
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presences = ref.watch(nodePresenceProvider);
    final summary = ref.watch(presenceSummaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Presence'),
      ),
      body: presences.isEmpty
          ? _buildEmptyState(theme)
          : CustomScrollView(
              slivers: [
                // Summary section
                SliverToBoxAdapter(child: _buildSummarySection(theme, summary)),
                // Activity chart
                SliverToBoxAdapter(
                  child: _buildActivityChart(theme, presences),
                ),
                // Node list header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'All Nodes',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Node list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildPresenceCard(theme, presences[index]),
                    childCount: presences.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No nodes discovered',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nodes will appear here as they are discovered',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    ThemeData theme,
    Map<PresenceStatus, int> summary,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: PresenceStatus.values.map((status) {
          final count = summary[status] ?? 0;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                right: status != PresenceStatus.offline ? 12 : 0,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status.color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: status.color.withAlpha(77)),
              ),
              child: Column(
                children: [
                  Icon(status.icon, color: status.color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    count.toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityChart(ThemeData theme, List<NodePresence> presences) {
    // Build a simple activity visualization
    final activePresences = presences
        .where((p) => p.status != PresenceStatus.offline)
        .toList();

    if (activePresences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.show_chart,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: _ActivityTimeline(presences: activePresences),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: AppTheme.successGreen, label: '< 2 min'),
                const SizedBox(width: 24),
                _LegendItem(color: AppTheme.warningYellow, label: '2-15 min'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceCard(ThemeData theme, NodePresence presence) {
    final node = presence.node;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getAvatarColor(node),
              child: Text(
                _getInitials(node),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: presence.status.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.darkSurface, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          node.displayName,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  presence.status.icon,
                  size: 12,
                  color: presence.status.color,
                ),
                const SizedBox(width: 4),
                Text(
                  presence.status.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: presence.status.color,
                  ),
                ),
                if (presence.timeSinceLastHeard != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• ${_formatTimeSince(presence.timeSinceLastHeard!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
            if (presence.signalQuality != null) ...[
              const SizedBox(height: 8),
              _SignalQualityBar(quality: presence.signalQuality!),
            ],
          ],
        ),
        trailing: presence.node.role != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withAlpha(51),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  presence.node.role!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Color _getAvatarColor(MeshNode node) {
    if (node.avatarColor != null) {
      return Color(node.avatarColor!);
    }
    // Generate consistent color from node number
    final colors = [
      context.accentColor,
      AppTheme.primaryPurple,
      AppTheme.primaryBlue,
      AppTheme.accentOrange,
      AppTheme.successGreen,
    ];
    return colors[node.nodeNum % colors.length];
  }

  String _getInitials(MeshNode node) {
    final name = node.shortName ?? node.longName;
    if (name == null || name.isEmpty) {
      return '?';
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  String _formatTimeSince(Duration duration) {
    if (duration.inMinutes < 1) return 'just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    return '${duration.inDays}d ago';
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }
}

class _SignalQualityBar extends StatelessWidget {
  final double quality;

  const _SignalQualityBar({required this.quality});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.signal_cellular_alt,
          size: 12,
          color: AppTheme.textTertiary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: quality,
              minHeight: 4,
              backgroundColor: AppTheme.darkBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                quality > 0.6
                    ? AppTheme.successGreen
                    : quality > 0.3
                    ? AppTheme.warningYellow
                    : AppTheme.errorRed,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(quality * 100).toInt()}%',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final List<NodePresence> presences;

  const _ActivityTimeline({required this.presences});

  @override
  Widget build(BuildContext context) {
    // Create a timeline showing when nodes were last heard
    // Group into time buckets: <1min, 1-2min, 2-5min, 5-10min, 10-15min
    final buckets = <int, List<NodePresence>>{};
    for (var i = 0; i < 5; i++) {
      buckets[i] = [];
    }

    for (final presence in presences) {
      final minutes = presence.timeSinceLastHeard?.inMinutes ?? 999;
      int bucket;
      if (minutes < 1) {
        bucket = 0;
      } else if (minutes < 2) {
        bucket = 1;
      } else if (minutes < 5) {
        bucket = 2;
      } else if (minutes < 10) {
        bucket = 3;
      } else {
        bucket = 4;
      }
      buckets[bucket]!.add(presence);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        final count = buckets[index]!.length;
        final maxCount = presences.length.clamp(1, 10);
        final height = count > 0
            ? (count / maxCount * 48).clamp(8.0, 48.0)
            : 4.0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (count > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      count.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getBucketColor(index),
                      ),
                    ),
                  ),
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: _getBucketColor(
                      index,
                    ).withAlpha(count > 0 ? 200 : 51),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Color _getBucketColor(int bucket) {
    if (bucket < 2) return AppTheme.successGreen;
    if (bucket < 4) return AppTheme.warningYellow;
    return AppTheme.textTertiary;
  }
}
