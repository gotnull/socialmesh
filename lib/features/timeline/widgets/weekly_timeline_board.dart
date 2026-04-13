// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_avatar_stack.dart';
import '../domain/timeline_interaction.dart';
import '../domain/timeline_item.dart';
import '../providers/timeline_providers.dart';
import 'timeline_day_column.dart';
import 'timeline_time_grid.dart';

/// Segment for the time range selector.
enum TimelineSegment { today, week, month, year }

/// A production-grade, reusable weekly timeline board.
///
/// Renders a horizontal-scrollable, day-column-based schedule with:
/// - Left gutter time labels (00:00–23:00)
/// - Day columns with positioned event cards
/// - Current time red indicator line
/// - Collision-aware layout (overlapping events split horizontally)
/// - Header with title, filter button, and segment control
///
/// Usage:
/// ```dart
/// WeeklyTimelineBoard(
///   title: 'Projects',
///   items: items,
///   segment: TimelineSegment.week,
///   onSegmentChanged: (s) => setState(() => _segment = s),
///   interactionDelegate: myDelegate,
///   avatarResolver: (ids) => ids.map(nodeToAvatarItem).toList(),
/// )
/// ```
class WeeklyTimelineBoard extends ConsumerStatefulWidget {
  /// Header title displayed top-left.
  final String title;

  /// All timeline items to render.
  final List<TimelineItem> items;

  /// Currently active segment.
  final TimelineSegment segment;

  /// Called when the user taps a segment.
  final ValueChanged<TimelineSegment>? onSegmentChanged;

  /// Called when the filter button is tapped.
  final VoidCallback? onFilterTap;

  /// Interaction delegate for item tap/long-press.
  final TimelineInteractionDelegate? interactionDelegate;

  /// Resolves participant IDs into avatar stack items.
  final List<AvatarStackItem> Function(List<String> participantIds)?
  avatarResolver;

  /// Pixels per minute — controls vertical density.
  final double pixelsPerMinute;

  const WeeklyTimelineBoard({
    super.key,
    required this.title,
    required this.items,
    this.segment = TimelineSegment.week,
    this.onSegmentChanged,
    this.onFilterTap,
    this.interactionDelegate,
    this.avatarResolver,
    this.pixelsPerMinute = kTimelinePixelsPerMinute,
  });

  @override
  ConsumerState<WeeklyTimelineBoard> createState() =>
      _WeeklyTimelineBoardState();
}

class _WeeklyTimelineBoardState extends ConsumerState<WeeklyTimelineBoard> {
  late ScrollController _horizontalScroll;
  late ScrollController _verticalScroll;

  @override
  void initState() {
    super.initState();
    _horizontalScroll = ScrollController();
    _verticalScroll = ScrollController();

    // Scroll to current time on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final offset = (now.hour * 60 + now.minute) * widget.pixelsPerMinute;
    // Center the viewport around current time.
    final viewportHeight = _verticalScroll.position.viewportDimension;
    final target = (offset - viewportHeight / 3).clamp(
      0.0,
      _verticalScroll.position.maxScrollExtent,
    );
    _verticalScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(timelineNowProvider).value ?? DateTime.now();
    final totalHeight = 24 * 60 * widget.pixelsPerMinute;

    // Determine the days to show based on segment.
    final days = _daysForSegment(widget.segment, now);

    // Group items by day and compute layouts.
    final grouped = groupItemsByDay(widget.items);
    final dayLayouts = <DateTime, List<TimelineItemLayout>>{};
    for (final day in days) {
      final dayItems = grouped[day] ?? [];
      dayLayouts[day] = computeDayLayout(dayItems, widget.pixelsPerMinute);
    }

    final columnsWidth =
        days.length * (kTimelineDayColumnWidth + kTimelineDayColumnGap);
    final totalWidth = kTimelineGutterWidth + columnsWidth;

    return Column(
      children: [
        // Header
        _BoardHeader(
          title: widget.title,
          segment: widget.segment,
          onSegmentChanged: widget.onSegmentChanged,
          onFilterTap: widget.onFilterTap,
        ),

        const SizedBox(height: AppTheme.spacing8),

        // Body: time grid + day columns
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalScroll,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                height: totalHeight,
                child: Stack(
                  children: [
                    // Time grid (labels + lines)
                    TimelineTimeGrid(
                      totalHeight: totalHeight,
                      pixelsPerMinute: widget.pixelsPerMinute,
                      now: now,
                      totalWidth: totalWidth,
                    ),

                    // Day columns
                    Positioned(
                      top: 0,
                      left: kTimelineGutterWidth,
                      bottom: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final day in days) ...[
                            TimelineDayColumn(
                              date: day,
                              layouts: dayLayouts[day] ?? [],
                              isToday: _isSameDay(day, now),
                              totalHeight: totalHeight,
                              avatarResolver: widget.avatarResolver,
                              onItemTap: widget.interactionDelegate != null
                                  ? (item) => widget.interactionDelegate!
                                        .onItemTap(context, item)
                                  : null,
                              onItemLongPress:
                                  widget.interactionDelegate != null
                                  ? (item) => widget.interactionDelegate!
                                        .onItemLongPress(context, item)
                                  : null,
                            ),
                            if (day != days.last)
                              SizedBox(width: kTimelineDayColumnGap),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DateTime> _daysForSegment(TimelineSegment segment, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (segment) {
      TimelineSegment.today => [today],
      TimelineSegment.week => List.generate(
        7,
        (i) => weekStartFor(today).add(Duration(days: i)),
      ),
      TimelineSegment.month => List.generate(
        DateTime(today.year, today.month + 1, 0).day,
        (i) => DateTime(today.year, today.month, i + 1),
      ),
      TimelineSegment.year => List.generate(
        12,
        (i) => DateTime(today.year, i + 1, 1),
      ),
    };
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Header row: title + filter button + segment control.
class _BoardHeader extends StatelessWidget {
  final String title;
  final TimelineSegment segment;
  final ValueChanged<TimelineSegment>? onSegmentChanged;
  final VoidCallback? onFilterTap;

  const _BoardHeader({
    required this.title,
    required this.segment,
    this.onSegmentChanged,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        children: [
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const Spacer(),

          // Filter button
          if (onFilterTap != null)
            _HeaderChip(
              icon: Icons.filter_list,
              label: l10n.timelineFilterLabel,
              onTap: onFilterTap!,
            ),

          const SizedBox(width: AppTheme.spacing8),

          // Segment control
          Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            padding: const EdgeInsets.all(AppTheme.spacing2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: TimelineSegment.values.map((seg) {
                final isActive = seg == segment;
                final label = switch (seg) {
                  TimelineSegment.today => l10n.timelineToday,
                  TimelineSegment.week => l10n.timelineWeek,
                  TimelineSegment.month => l10n.timelineMonth,
                  TimelineSegment.year => l10n.timelineYear,
                };
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSegmentChanged?.call(seg);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12,
                      vertical: AppTheme.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? context.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isActive
                            ? context.textPrimary
                            : context.textTertiary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tappable chip used in the header (filter button).
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing6,
        ),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.textTertiary),
            const SizedBox(width: AppTheme.spacing4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
