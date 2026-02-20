// SPDX-License-Identifier: GPL-3.0-or-later

// Node Summary Card — computed insight card for NodeDex detail.
//
// Displays time-of-day distribution as a horizontal bar,
// activity streak, busiest day, and a one-line summary sentence.
// Shows "Keep observing to build a profile" when data is sparse.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/node_summary_engine.dart';

/// Compact summary card showing computed insights about a node's
/// encounter patterns.
///
/// This widget receives a pre-computed [NodeSummary] and renders it
/// as a styled card with a horizontal time-distribution bar and
/// key statistics.
class NodeSummaryCard extends StatelessWidget {
  final NodeSummary summary;
  final Color accentColor;

  const NodeSummaryCard({
    super.key,
    required this.summary,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary text (always shown)
        Text(
          summary.summaryText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimary,
            height: 1.4,
          ),
        ),

        // Only show detailed stats when we have enough data.
        if (summary.hasEnoughData) ...[
          const SizedBox(height: 16),

          // Time-of-day distribution bar
          _TimeDistributionBar(
            distribution: summary.timeDistribution,
            accentColor: accentColor,
          ),
          const SizedBox(height: 16),

          // Stats row
          _StatsRow(summary: summary),
        ],
      ],
    );
  }
}

/// Horizontal stacked bar showing the time-of-day encounter distribution.
class _TimeDistributionBar extends StatelessWidget {
  final Map<TimeOfDayBucket, int> distribution;
  final Color accentColor;

  const _TimeDistributionBar({
    required this.distribution,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: TimeOfDayBucket.values.map((bucket) {
                final count = distribution[bucket] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                final fraction = count / total;
                return Expanded(
                  flex: (fraction * 1000).round(),
                  child: Container(color: _bucketColor(bucket)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: TimeOfDayBucket.values.map((bucket) {
            final count = distribution[bucket] ?? 0;
            return _LegendItem(
              label: bucket.label,
              count: count,
              color: _bucketColor(bucket),
              isActive: count > 0,
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _bucketColor(TimeOfDayBucket bucket) {
    return switch (bucket) {
      TimeOfDayBucket.dawn => AccentColors.orange,
      TimeOfDayBucket.midday => AccentColors.yellow,
      TimeOfDayBucket.evening => AccentColors.blue,
      TimeOfDayBucket.night => AccentColors.purple,
    };
  }
}

/// Small coloured dot + label for the time distribution legend.
class _LegendItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isActive;

  const _LegendItem({
    required this.label,
    required this.count,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isActive ? context.textSecondary : context.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11,
            color: textColor,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

/// Row of stat chips: streak, busiest day, active days.
class _StatsRow extends StatelessWidget {
  final NodeSummary summary;

  const _StatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final chips = <_StatChip>[];

    if (summary.currentStreak > 1) {
      chips.add(
        _StatChip(
          icon: Icons.local_fire_department_outlined,
          label: '${summary.currentStreak}-day streak',
        ),
      );
    }

    if (summary.busiestDayOfWeek != null) {
      chips.add(
        _StatChip(
          icon: Icons.calendar_today_outlined,
          label: 'Busiest ${_shortDayName(summary.busiestDayOfWeek!)}',
        ),
      );
    }

    if (summary.activeDaysLast14 > 0) {
      chips.add(
        _StatChip(
          icon: Icons.grid_view_outlined,
          label: '${summary.activeDaysLast14}/14 days',
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  String _shortDayName(int weekday) {
    return switch (weekday) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => '?',
    };
  }
}

/// Individual stat chip with icon and label.
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.border.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.border.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
