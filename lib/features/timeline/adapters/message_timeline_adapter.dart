// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../models/mesh_models.dart';
import '../domain/timeline_item.dart';

/// Pixels-per-minute used by [MessageTimelineScreen] for the timeline board.
///
/// Higher than the default [kTimelinePixelsPerMinute] (1.2) because message
/// sessions are short (10–60 min) and need taller cards for text to be
/// visible. At 3.0, a 30-min minimum session produces a 90 px card.
const double kMessageTimelinePixelsPerMinute = 3.0;

/// Minimum gap between messages (in minutes) to start a new session.
const int _kSessionGapMinutes = 15;

/// Minimum session duration in minutes for rendering on the timeline.
///
/// At [kMessageTimelinePixelsPerMinute] = 3.0, this produces a 90 px card
/// which is tall enough for title + subtitle text.
const int _kMinSessionMinutes = 30;

/// Filter mode for timeline message projection.
enum MessageTimelineFilter {
  /// Show all message activity.
  all,

  /// Show only direct messages.
  directMessages,

  /// Show only channel messages.
  channels,
}

/// Transforms a flat list of [Message] objects into [TimelineItem] sessions
/// suitable for the weekly timeline board.
///
/// Messages are grouped into communication sessions — clusters of messages
/// within the same conversation (DM peer or channel) separated by at most
/// [_kSessionGapMinutes] of silence. Each session becomes one timeline item.
///
/// The adapter is stateless and pure — it takes inputs and returns outputs
/// without side effects.
class MessageTimelineAdapter {
  const MessageTimelineAdapter._();

  /// Projects [messages] into timeline items for the given [weekStart].
  ///
  /// [myNodeNum] is used to determine message direction and build titles.
  /// [nodeNames] maps node numbers to display names.
  /// [channelNames] maps channel indices to channel names.
  /// [filter] controls which message types are included.
  static List<TimelineItem> projectMessages({
    required List<Message> messages,
    required DateTime weekStart,
    required int myNodeNum,
    required Map<int, String> nodeNames,
    required Map<int, String> channelNames,
    MessageTimelineFilter filter = MessageTimelineFilter.all,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Filter messages to the visible week and exclude tapback reactions.
    final weekMessages = messages.where((m) {
      if (m.isCanonicalTapback) return false;
      if (m.timestamp.isBefore(weekStart)) return false;
      if (!m.timestamp.isBefore(weekEnd)) return false;

      return switch (filter) {
        MessageTimelineFilter.all => true,
        MessageTimelineFilter.directMessages => m.isDirect,
        MessageTimelineFilter.channels => m.isBroadcast,
      };
    }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (weekMessages.isEmpty) return const [];

    // Group messages by conversation key.
    final conversationGroups = <String, List<Message>>{};
    for (final msg in weekMessages) {
      final key = _conversationKey(msg, myNodeNum);
      (conversationGroups[key] ??= []).add(msg);
    }

    // Sessionize each conversation and build timeline items.
    final items = <TimelineItem>[];
    for (final entry in conversationGroups.entries) {
      final sessions = _sessionize(entry.value);
      for (final session in sessions) {
        items.add(
          _sessionToItem(
            conversationKey: entry.key,
            session: session,
            myNodeNum: myNodeNum,
            nodeNames: nodeNames,
            channelNames: channelNames,
          ),
        );
      }
    }

    return items;
  }

  /// Builds a stable conversation key from a message.
  static String _conversationKey(Message msg, int myNodeNum) {
    if (msg.isBroadcast) {
      return 'ch_${msg.channel}';
    }
    // For DMs, use the peer node number (the one that isn't us).
    final peer = msg.from == myNodeNum ? msg.to : msg.from;
    return 'dm_$peer';
  }

  /// Splits a sorted list of messages into sessions separated by gaps.
  static List<List<Message>> _sessionize(List<Message> messages) {
    if (messages.isEmpty) return const [];

    final sessions = <List<Message>>[];
    var currentSession = <Message>[messages.first];

    for (var i = 1; i < messages.length; i++) {
      final gap = messages[i].timestamp.difference(messages[i - 1].timestamp);
      if (gap.inMinutes > _kSessionGapMinutes) {
        sessions.add(currentSession);
        currentSession = <Message>[messages[i]];
      } else {
        currentSession.add(messages[i]);
      }
    }
    sessions.add(currentSession);

    return sessions;
  }

  /// Converts a message session into a [TimelineItem].
  static TimelineItem _sessionToItem({
    required String conversationKey,
    required List<Message> session,
    required int myNodeNum,
    required Map<int, String> nodeNames,
    required Map<int, String> channelNames,
  }) {
    final first = session.first;
    final last = session.last;

    final start = first.timestamp;
    var end = last.timestamp;

    // Ensure minimum visual duration for short bursts.
    if (end.difference(start).inMinutes < _kMinSessionMinutes) {
      end = start.add(const Duration(minutes: _kMinSessionMinutes));
    }

    // Build title and subtitle.
    final isChannel = first.isBroadcast;
    final String title;
    final String? subtitle;

    if (isChannel) {
      final chName = channelNames[first.channel] ?? 'Channel ${first.channel}';
      title = chName;
      subtitle = null;
    } else {
      final peer = first.from == myNodeNum ? first.to : first.from;
      final peerName =
          nodeNames[peer] ?? '!${peer.toRadixString(16).padLeft(8, '0')}';
      title = peerName;
      subtitle = null;
    }

    final participants = <String>{};
    if (isChannel) {
      for (final msg in session) {
        participants.add(msg.from.toString());
      }
      participants.remove(myNodeNum.toString());
    } else {
      final peer = first.from == myNodeNum ? first.to : first.from;
      if (peer != myNodeNum) {
        participants.add(peer.toString());
      }
    }

    // Determine priority from message activity density.
    final priority = _priorityForSession(session);

    // Build a stable deterministic ID.
    final id = '${conversationKey}_${start.millisecondsSinceEpoch}';

    return TimelineItem(
      id: id,
      start: start,
      end: end,
      title: title,
      subtitle: subtitle,
      priority: priority,
      participantIds: participants.toList(),
      messageIds: session.map((message) => message.id).toList(growable: false),
      messageCount: session.length,
      trackedDuration: last.timestamp.difference(start),
    );
  }

  /// Determines priority level from session message density.
  static TimelinePriority _priorityForSession(List<Message> session) {
    final count = session.length;
    if (count >= 20) return TimelinePriority.high;
    if (count >= 5) return TimelinePriority.medium;
    return TimelinePriority.low;
  }
}
