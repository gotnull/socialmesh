// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Activity section widget for Mesh Explorer.
///
/// Renders recent nearby service activity as a compact, ambient list
/// of events. Each item shows an icon, title, subtitle, and relative
/// freshness timestamp. Tapping an item opens the related service
/// detail if appropriate.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../models/nearby_activity.dart';

/// Displays recent nearby activity in a compact card list.
///
/// Expects items already sorted newest first and capped by the provider.
class MeshExplorerActivitySection extends StatelessWidget {
  /// Recent activity items to display.
  final List<NearbyActivity> activities;

  /// Callback when an activity item is tapped.
  final void Function(NearbyActivity activity)? onTap;

  const MeshExplorerActivitySection({
    super.key,
    required this.activities,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return _EmptyActivity();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          for (int i = 0; i < activities.length; i++) ...[
            _ActivityCard(activity: activities[i], onTap: onTap),
            if (i < activities.length - 1)
              const SizedBox(height: AppTheme.spacing4),
          ],
        ],
      ),
    );
  }
}

/// Empty state when no recent activity exists.
class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing16,
      ),
      child: Column(
        children: [
          Icon(
            Icons.bubble_chart_outlined,
            size: 36,
            color: context.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.nearbyActivityEmptyTitle,
            style: context.bodyStyle?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.nearbyActivityEmptyBody,
            style: context.bodySmallStyle?.copyWith(
              color: context.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A single activity card.
class _ActivityCard extends StatelessWidget {
  final NearbyActivity activity;
  final void Function(NearbyActivity activity)? onTap;

  const _ActivityCard({required this.activity, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!(activity);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            // Service icon — subtle tinted background
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Icon(
                activity.icon,
                size: 18,
                color: context.accentColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: context.bodyStyle?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    activity.subtitle,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppTheme.spacing8),

            // Relative freshness
            Text(
              _relativeFreshness(activity.occurredAt),
              style: context.captionStyle?.copyWith(
                color: context.textTertiary.withValues(alpha: 0.7),
              ),
            ),

            // Tap affordance
            if (onTap != null) ...[
              const SizedBox(width: AppTheme.spacing4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: context.textTertiary.withValues(alpha: 0.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns a concise relative time string.
  static String _relativeFreshness(DateTime occurredAt) {
    final diff = DateTime.now().difference(occurredAt);
    if (diff.inSeconds < 60) {
      return 'now'; // lint-allow: hardcoded-string
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m'; // lint-allow: hardcoded-string
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h'; // lint-allow: hardcoded-string
    }
    return '${diff.inDays}d'; // lint-allow: hardcoded-string
  }
}
