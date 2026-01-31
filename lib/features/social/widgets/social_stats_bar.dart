// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A bar displaying social stats (followers, following, posts).
///
/// Tappable sections navigate to respective detail screens.
class SocialStatsBar extends StatelessWidget {
  const SocialStatsBar({
    super.key,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    this.onFollowersTap,
    this.onFollowingTap,
    this.onPostsTap,
    this.compact = false,
  });

  final int followerCount;
  final int followingCount;
  final int postCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onPostsTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CompactStat(count: postCount, label: 'Posts', onTap: onPostsTap),
          const SizedBox(width: 24),
          _CompactStat(
            count: followerCount,
            label: 'Followers',
            onTap: onFollowersTap,
          ),
          const SizedBox(width: 24),
          _CompactStat(
            count: followingCount,
            label: 'Following',
            onTap: onFollowingTap,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(count: postCount, label: 'Posts', onTap: onPostsTap),
          _StatItem(
            count: followerCount,
            label: 'Followers',
            onTap: onFollowersTap,
          ),
          _StatItem(
            count: followingCount,
            label: 'Following',
            onTap: onFollowingTap,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.count, required this.label, this.onTap});

  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatCount(count),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({required this.count, required this.label, this.onTap});

  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatCount(count),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

/// Format large counts with K/M suffixes
String _formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 10000) {
    return '${(count / 1000).toStringAsFixed(0)}K';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return NumberFormat.decimalPattern().format(count);
}
