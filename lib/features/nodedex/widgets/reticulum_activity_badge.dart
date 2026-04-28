// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../providers/reticulum_providers.dart';

/// Compact "RNS" badge shown beside a node's identifier whenever that
/// node has recently emitted port-76 (`RETICULUM_TUNNEL_APP`) fragments.
///
/// Drop-in for NodeDex node tiles. Renders nothing when the node has no
/// recent fragment activity, so it costs zero pixels in the common case.
class ReticulumActivityBadge extends ConsumerWidget {
  const ReticulumActivityBadge({super.key, required this.nodeNum});

  final int nodeNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(reticulumStatsProvider);
    final hit = stats.topSources.where((s) => s.nodeId == nodeNum).toList();
    if (hit.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.podcasts, size: 10, color: context.accentColor),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            context.l10n.nodeDexRnsActivityBadge,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.accentColor,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail-row helper for the NodeDex node detail screen. Renders an
/// info-table-style row with the lifetime fragment count + last-seen
/// timestamp for this node, or `SizedBox.shrink` if we have no data.
class ReticulumActivityDetail extends ConsumerWidget {
  const ReticulumActivityDetail({super.key, required this.nodeNum});

  final int nodeNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(reticulumStatsProvider);
    final hit = stats.topSources.where((s) => s.nodeId == nodeNum).toList();
    if (hit.isEmpty) return const SizedBox.shrink();
    final source = hit.first;
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(
      source.lastSeenMs,
    ).toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.podcasts, size: 14, color: context.accentColor),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  context.l10n.nodeDexRnsActivityCount,
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${source.fragmentCount}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  context.l10n.nodeDexRnsActivityLastSeen,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
                const Spacer(),
                Text(
                  lastSeen.toIso8601String(),
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
