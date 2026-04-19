// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';

/// Priority level for timeline items, mapped to visual styling.
enum TimelinePriority { low, medium, high, done }

/// The feature context in which the timeline board is being displayed.
/// Controls which data sources feed items and what interactions are available.
enum TimelineContext { messages, channel, nodedex, map }

/// A single item rendered on the weekly timeline board.
///
/// This is a pure domain model — NO UI logic. All visual decisions
/// (color, position, size) are computed by the layout provider.
@immutable
class TimelineItem {
  final String id;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? subtitle;
  final TimelinePriority priority;
  final List<String> participantIds;
  final List<String> messageIds;
  final int messageCount;
  final Duration? trackedDuration;
  final bool isCompleted;
  final bool isBreak;

  const TimelineItem({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    this.subtitle,
    this.priority = TimelinePriority.low,
    this.participantIds = const [],
    this.messageIds = const [],
    this.messageCount = 0,
    this.trackedDuration,
    this.isCompleted = false,
    this.isBreak = false,
  });

  /// Duration of this item.
  Duration get duration => end.difference(start);

  /// Minutes from midnight for positioning.
  int get startMinuteOfDay => start.hour * 60 + start.minute;

  /// Duration in minutes for sizing.
  int get durationMinutes => duration.inMinutes;

  /// Whether this item has participant avatars to display.
  bool get hasParticipants => participantIds.isNotEmpty;

  TimelineItem copyWith({
    String? id,
    DateTime? start,
    DateTime? end,
    String? title,
    String? subtitle,
    TimelinePriority? priority,
    List<String>? participantIds,
    List<String>? messageIds,
    int? messageCount,
    Duration? trackedDuration,
    bool? isCompleted,
    bool? isBreak,
  }) {
    return TimelineItem(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      priority: priority ?? this.priority,
      participantIds: participantIds ?? this.participantIds,
      messageIds: messageIds ?? this.messageIds,
      messageCount: messageCount ?? this.messageCount,
      trackedDuration: trackedDuration ?? this.trackedDuration,
      isCompleted: isCompleted ?? this.isCompleted,
      isBreak: isBreak ?? this.isBreak,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Pre-computed layout position for a timeline item within its day column.
@immutable
class TimelineItemLayout {
  final TimelineItem item;
  final double top;
  final double height;
  final double leftFraction;
  final double widthFraction;

  const TimelineItemLayout({
    required this.item,
    required this.top,
    required this.height,
    this.leftFraction = 0.0,
    this.widthFraction = 1.0,
  });
}
