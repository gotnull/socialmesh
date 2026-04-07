// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Co-Seen Network Card — premium social context card for node detail.
//
// Displays an animated avatar cluster of co-seen peers in the top-right
// of a card, with a title, subtitle, and optional "view all" CTA.
// This card is placed in the upper content area of the node detail
// screen to communicate social graph context at a glance.
//
// Architecture:
// - nodeDexCoSeenCardProvider: prepares the view model (item count,
//   top peer names, avatar stack items)
// - CoSeenNetworkCard: renders the card with AnimatedAvatarStack
//
// The card renders as SizedBox.shrink when the node has no co-seen peers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_avatar_stack.dart';
import '../../../providers/accessibility_providers.dart';
import 'nodedex_avatar_stack.dart';

/// View model for the co-seen network card on the node detail screen.
@immutable
class CoSeenCardViewModel {
  /// Total number of co-seen peers (not capped by maxVisible).
  final int totalCount;

  /// Prepared avatar stack items for the cluster.
  final List<AvatarStackItem> avatarItems;

  const CoSeenCardViewModel({
    required this.totalCount,
    required this.avatarItems,
  });
}

/// Provider that builds the [CoSeenCardViewModel] for a given node.
///
/// Delegates item selection/ordering to [nodeDexAvatarStackProvider]
/// and adds the total co-seen count for the subtitle.
final nodeDexCoSeenCardProvider = Provider.family<CoSeenCardViewModel?, int>((
  ref,
  nodeNum,
) {
  final items = ref.watch(nodeDexAvatarStackProvider(nodeNum));
  if (items.isEmpty) return null;

  return CoSeenCardViewModel(totalCount: items.length, avatarItems: items);
});

/// Premium co-seen network card for the node detail screen.
///
/// Layout:
/// ```
/// ┌────────────────────────────────────────────────┐
/// │  CO-SEEN NETWORK       [animated avatar stack] │
/// │                                                │
/// │  3 nodes commonly seen with this node          │
/// │                                      View all ▸│
/// └────────────────────────────────────────────────┘
/// ```
///
/// The animated avatar cluster sits in the top-right, anchored to the
/// card header line. The title and subtitle occupy the left side.
/// An optional "View all" CTA scrolls to the full co-seen links section.
///
/// Renders [SizedBox.shrink] if the node has no co-seen peers.
class CoSeenNetworkCard extends ConsumerWidget {
  /// The node number to show co-seen data for.
  final int nodeNum;

  /// Callback when "View all" is tapped. Typically scrolls to the
  /// co-seen links section further down the detail screen.
  final VoidCallback? onViewAll;

  /// Callback when the card or avatar cluster is tapped.
  /// Shows the co-seen list sheet.
  final VoidCallback? onTap;

  const CoSeenNetworkCard({
    super.key,
    required this.nodeNum,
    this.onViewAll,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(nodeDexCoSeenCardProvider(nodeNum));
    if (viewModel == null) return const SizedBox.shrink();

    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    final items = viewModel.avatarItems;

    return GestureDetector(
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: context.border.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: title left, avatar stack right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + icon
                Icon(Icons.hub_outlined, size: 16, color: context.textTertiary),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.l10n.nodedexCoSeenCardTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.textTertiary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                // Animated avatar cluster — top-right anchored
                AnimatedAvatarStack(
                  items: items,
                  maxVisible: AvatarStackDefaults.maxVisible,
                  avatarSize: AvatarStackDefaults.avatarSize,
                  animationEnabled: !reduceMotion,
                  semanticLabel: context.l10n.avatarStackCoSeenLabel(
                    viewModel.totalCount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            // Subtitle — peer count description
            Text(
              context.l10n.nodedexCoSeenCardSubtitle(viewModel.totalCount),
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                height: 1.3,
              ),
            ),
            // "View all" CTA
            if (onViewAll != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onViewAll!();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.nodedexCoSeenCardViewAll,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: context.accentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
