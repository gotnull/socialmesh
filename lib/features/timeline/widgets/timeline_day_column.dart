// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animated_avatar_stack.dart';
import '../domain/timeline_item.dart';
import '../providers/timeline_providers.dart';
import 'timeline_event_card.dart';

/// Renders a single day column in the weekly timeline board.
///
/// Contains a sticky header (day abbreviation + date) and a vertically
/// scrollable stack of positioned event cards.
class TimelineDayColumn extends StatelessWidget {
  final DateTime date;
  final List<TimelineItemLayout> layouts;
  final bool isToday;
  final double totalHeight;
  final double columnWidth;
  final List<AvatarStackItem> Function(List<String> ids)? avatarResolver;
  final void Function(TimelineItem item)? onItemTap;
  final void Function(TimelineItem item)? onItemLongPress;

  const TimelineDayColumn({
    super.key,
    required this.date,
    required this.layouts,
    required this.isToday,
    required this.totalHeight,
    this.columnWidth = kTimelineDayColumnWidth,
    this.avatarResolver,
    this.onItemTap,
    this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columnWidth,
      child: Column(
        children: [
          _DayHeader(date: date, isToday: isToday),
          Expanded(
            child: _DayBody(
              layouts: layouts,
              totalHeight: totalHeight,
              columnWidth: columnWidth,
              avatarResolver: avatarResolver,
              onItemTap: onItemTap,
              onItemLongPress: onItemLongPress,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky day header: "MON\n18" format.
class _DayHeader extends StatelessWidget {
  final DateTime date;
  final bool isToday;

  const _DayHeader({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final dayAbbr = DateFormat.E(
      Localizations.localeOf(context).toString(),
    ).format(date).toUpperCase();
    final dayNum = date.day.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      decoration: BoxDecoration(
        border: isToday
            ? Border(
                bottom: BorderSide(color: AppTheme.primaryPurple, width: 2),
              )
            : null,
      ),
      child: Column(
        children: [
          Text(
            dayAbbr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isToday ? AppTheme.primaryPurple : context.textTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Container(
            width: AppTheme.spacing28,
            height: 28,
            decoration: isToday
                ? BoxDecoration(
                    color: AppTheme.primaryPurple,
                    shape: BoxShape.circle,
                  )
                : null,
            alignment: Alignment.center,
            child: Text(
              dayNum,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isToday ? SemanticColors.onAccent : context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrollable body of a day column with positioned event cards.
class _DayBody extends StatelessWidget {
  final List<TimelineItemLayout> layouts;
  final double totalHeight;
  final double columnWidth;
  final List<AvatarStackItem> Function(List<String> ids)? avatarResolver;
  final void Function(TimelineItem item)? onItemTap;
  final void Function(TimelineItem item)? onItemLongPress;

  const _DayBody({
    required this.layouts,
    required this.totalHeight,
    required this.columnWidth,
    this.avatarResolver,
    this.onItemTap,
    this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Card padding within the column.
    const cardPadding = 4.0;
    final usableWidth = columnWidth - (cardPadding * 2);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Subtle vertical column background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: context.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
            ),
          ),

          // Event cards
          for (final layout in layouts)
            Positioned(
              top: layout.top,
              left: cardPadding + (layout.leftFraction * usableWidth),
              width: layout.widthFraction * usableWidth,
              height: layout.height.clamp(24.0, double.infinity),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: TimelineEventCard(
                  item: layout.item,
                  participantAvatars:
                      avatarResolver?.call(layout.item.participantIds) ?? [],
                  height: layout.height.clamp(24.0, double.infinity),
                  onTap: onItemTap != null
                      ? () => onItemTap!(layout.item)
                      : null,
                  onLongPress: onItemLongPress != null
                      ? () => onItemLongPress!(layout.item)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
