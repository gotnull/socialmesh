// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/presence_providers.dart';
import '../../utils/presence_utils.dart';

class PresenceScreen extends ConsumerStatefulWidget {
  const PresenceScreen({super.key});

  @override
  ConsumerState<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends ConsumerState<PresenceScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presences = ref.watch(presenceListProvider);
    final summary = ref.watch(presenceSummaryProvider);

    return HelpTourController(
      topicId: 'presence_overview',
      stepKeys: const {},
      child: GlassScaffold(
        title: 'Presence',
        actions: [IcoHelpAppBarButton(topicId: 'presence_overview')],
        slivers: presences.isEmpty
            ? [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(theme),
                ),
              ]
            : [
                // Summary section
                SliverToBoxAdapter(
                  child: _buildSummarySection(context, theme, summary),
                ),
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
                        color: context.textSecondary,
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
              color: context.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.people_outline,
              size: 40,
              color: context.textTertiary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No nodes discovered',
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Nodes will appear here as they are discovered',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    ThemeData theme,
    Map<PresenceConfidence, int> summary,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: PresenceConfidence.values.asMap().entries.map((entry) {
          final status = entry.value;
          final index = entry.key;
          final count = summary[status] ?? 0;
          final color = _statusColor(status);
          final isLast = index == PresenceConfidence.values.length - 1;
          return Expanded(
            child: Container(
              height: 130,
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(77)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon(status), color: color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    count.toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
        .where((p) => p.confidence != PresenceConfidence.unknown)
        .toList();

    if (activePresences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: context.textSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: context.textSecondary,
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
                _LegendItem(color: AppTheme.warningYellow, label: '2-10 min'),
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
        color: context.surface,
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
                style: TextStyle(
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
                  color: _statusColor(presence.confidence),
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          node.displayName,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _statusIcon(presence.confidence),
                  size: 12,
                  color: _statusColor(presence.confidence),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: kPresenceInferenceTooltip,
                  child: Text(
                    presenceStatusText(
                      presence.confidence,
                      presence.timeSinceLastHeard,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _statusColor(presence.confidence),
                    ),
                  ),
                ),
                if (presence.timeSinceLastHeard != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• ${_formatTimeSince(presence.timeSinceLastHeard!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
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

  Color _statusColor(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return AppTheme.successGreen;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  IconData _statusIcon(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return Icons.circle;
      case PresenceConfidence.fading:
        return Icons.circle_outlined;
      case PresenceConfidence.stale:
        return Icons.radio_button_unchecked;
      case PresenceConfidence.unknown:
        return Icons.help_outline;
    }
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
        SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
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
        Icon(Icons.signal_cellular_alt, size: 12, color: context.textTertiary),
        SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: quality,
              minHeight: 4,
              backgroundColor: context.border,
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
        SizedBox(width: 8),
        Text(
          '${(quality * 100).toInt()}%',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
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
                        color: _getBucketColor(context, index),
                      ),
                    ),
                  ),
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: _getBucketColor(
                      context,
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

  Color _getBucketColor(BuildContext context, int bucket) {
    if (bucket < 2) return AppTheme.successGreen;
    if (bucket < 4) return AppTheme.warningYellow;
    return context.textTertiary;
  }
}
