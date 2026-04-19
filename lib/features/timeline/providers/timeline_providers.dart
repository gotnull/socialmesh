// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/timeline_item.dart';

/// Pixels per minute used for vertical positioning in the timeline grid.
const double kTimelinePixelsPerMinute = 1.2;

/// Width in logical pixels for each day column.
const double kTimelineDayColumnWidth = 220.0;

/// Gap between day columns.
const double kTimelineDayColumnGap = 12.0;

/// Width of the time gutter (left-side time labels).
const double kTimelineGutterWidth = 48.0;

/// Current time provider that updates every 30 seconds.
///
/// Used by the current-time indicator line. Provider-driven so the widget
/// tree never calls setState for clock ticks.
final timelineNowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  ).asBroadcastStream();
});

/// Computes the layout positions for a list of timeline items within one day.
///
/// Handles collision detection — overlapping events are split horizontally.
/// Returns pre-computed [TimelineItemLayout] with top/height/width fractions.
List<TimelineItemLayout> computeDayLayout(
  List<TimelineItem> items,
  double pixelsPerMinute,
) {
  if (items.isEmpty) return const [];

  // Sort by start time, then duration (longer first), then id for stability.
  final sorted = List<TimelineItem>.from(items)
    ..sort((a, b) {
      final startCmp = a.start.compareTo(b.start);
      if (startCmp != 0) return startCmp;
      final durCmp = b.durationMinutes.compareTo(a.durationMinutes);
      if (durCmp != 0) return durCmp;
      return a.id.compareTo(b.id);
    });

  // Collision groups: items that overlap in time share a group.
  final List<List<TimelineItem>> groups = [];
  List<TimelineItem> currentGroup = [sorted.first];

  for (var i = 1; i < sorted.length; i++) {
    final item = sorted[i];
    final groupEnd = currentGroup
        .map((e) => e.start.add(e.duration))
        .reduce((a, b) => a.isAfter(b) ? a : b);

    if (item.start.isBefore(groupEnd)) {
      currentGroup.add(item);
    } else {
      groups.add(currentGroup);
      currentGroup = [item];
    }
  }
  groups.add(currentGroup);

  // Assign columns within each group.
  final layouts = <TimelineItemLayout>[];

  for (final group in groups) {
    final columnCount = group.length;
    for (var col = 0; col < group.length; col++) {
      final item = group[col];
      layouts.add(
        TimelineItemLayout(
          item: item,
          top: item.startMinuteOfDay * pixelsPerMinute,
          height: item.durationMinutes * pixelsPerMinute,
          leftFraction: col / columnCount,
          widthFraction: 1.0 / columnCount,
        ),
      );
    }
  }

  return layouts;
}

/// Groups timeline items by their date (year + month + day).
Map<DateTime, List<TimelineItem>> groupItemsByDay(List<TimelineItem> items) {
  final map = <DateTime, List<TimelineItem>>{};
  for (final item in items) {
    final dayKey = DateTime(item.start.year, item.start.month, item.start.day);
    (map[dayKey] ??= []).add(item);
  }
  return map;
}

/// Returns the Monday of the week containing [date].
DateTime weekStartFor(DateTime date) {
  final weekday = date.weekday; // 1 = Monday
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}
