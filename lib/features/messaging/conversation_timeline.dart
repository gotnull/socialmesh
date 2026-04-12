// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mesh_models.dart';
import '../../models/tapback.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/message_database.dart';

class ConversationTimelineQuery {
  final int? channelIndex;
  final int? peerNodeNum;
  final int? myNodeNum;

  const ConversationTimelineQuery.channel({required this.channelIndex})
    : peerNodeNum = null,
      myNodeNum = null;

  const ConversationTimelineQuery.direct({
    required this.peerNodeNum,
    required this.myNodeNum,
  }) : channelIndex = null;

  bool get isChannel => channelIndex != null;

  @override
  bool operator ==(Object other) {
    return other is ConversationTimelineQuery &&
        other.channelIndex == channelIndex &&
        other.peerNodeNum == peerNodeNum &&
        other.myNodeNum == myNodeNum;
  }

  @override
  int get hashCode => Object.hash(channelIndex, peerNodeNum, myNodeNum);
}

class ConversationTimelineRow {
  final Message? message;
  final List<MessageTapback> tapbacks;
  final int? orphanReplyId;
  final DateTime sortTimestamp;

  const ConversationTimelineRow._({
    required this.message,
    required this.tapbacks,
    required this.orphanReplyId,
    required this.sortTimestamp,
  });

  factory ConversationTimelineRow.message({
    required Message message,
    List<MessageTapback> tapbacks = const [],
  }) {
    return ConversationTimelineRow._(
      message: message,
      tapbacks: tapbacks,
      orphanReplyId: null,
      sortTimestamp: message.timestamp,
    );
  }

  factory ConversationTimelineRow.orphan({
    required int replyId,
    required List<MessageTapback> tapbacks,
    required DateTime timestamp,
  }) {
    return ConversationTimelineRow._(
      message: null,
      tapbacks: tapbacks,
      orphanReplyId: replyId,
      sortTimestamp: timestamp,
    );
  }

  bool get isOrphanPlaceholder => message == null;

  String get key => message?.id ?? 'orphan:$orphanReplyId';
}

final conversationTimelineProvider =
    FutureProvider.family<
      List<ConversationTimelineRow>,
      ConversationTimelineQuery
    >((ref, query) async {
      ref.watch(messagesProvider);
      ref.watch(messageTimelineEpochProvider);

      final storage = await ref.watch(messageStorageProvider.future);
      final rawMessages = await _loadConversationMessages(storage, query);
      return buildConversationTimelineRows(rawMessages);
    });

Future<List<Message>> _loadConversationMessages(
  MessageDatabase storage,
  ConversationTimelineQuery query,
) async {
  if (query.channelIndex != null) {
    return storage.loadConversation(
      MessageDatabase.conversationKeyFromParams(channel: query.channelIndex),
    );
  }

  final peerNodeNum = query.peerNodeNum;
  if (peerNodeNum == null) return const [];

  final myNodeNum = query.myNodeNum;
  if (myNodeNum != null) {
    return storage.loadConversation(
      MessageDatabase.conversationKeyFromParams(
        nodeA: myNodeNum,
        nodeB: peerNodeNum,
      ),
    );
  }

  final messages = await storage.loadMessagesForNode(peerNodeNum);
  return messages.where((message) => message.isDirect).toList();
}

List<ConversationTimelineRow> buildConversationTimelineRows(
  List<Message> rawMessages,
) {
  final sortedMessages = [...rawMessages]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final parentMessages = sortedMessages
      .where((message) => !message.isCanonicalTapback)
      .toList();
  final parentsByPacketId = <int, Message>{
    for (final message in parentMessages)
      if (message.packetId != null) message.packetId!: message,
  };

  final groupedTapbacks = <int, List<MessageTapback>>{};
  final orphanTapbacks = <int, List<MessageTapback>>{};

  for (final message in sortedMessages.where(
    (message) => message.isCanonicalTapback,
  )) {
    final replyId = message.replyId!;
    final parent = parentsByPacketId[replyId];
    final tapback = MessageTapback(
      id: message.id,
      messageId: parent?.id ?? 'orphan:$replyId',
      fromNodeNum: message.from,
      emoji: message.text,
      timestamp: message.timestamp,
    );

    if (parent != null) {
      groupedTapbacks
          .putIfAbsent(replyId, () => <MessageTapback>[])
          .add(tapback);
    } else {
      orphanTapbacks
          .putIfAbsent(replyId, () => <MessageTapback>[])
          .add(tapback);
    }
  }

  final rows = <ConversationTimelineRow>[
    for (final message in parentMessages)
      ConversationTimelineRow.message(
        message: message,
        tapbacks: _sortTapbacks(groupedTapbacks[message.packetId] ?? const []),
      ),
    for (final entry in orphanTapbacks.entries)
      ConversationTimelineRow.orphan(
        replyId: entry.key,
        tapbacks: _sortTapbacks(entry.value),
        timestamp: entry.value.first.timestamp,
      ),
  ];

  rows.sort((a, b) {
    final timestampCompare = a.sortTimestamp.compareTo(b.sortTimestamp);
    if (timestampCompare != 0) return timestampCompare;
    if (a.isOrphanPlaceholder != b.isOrphanPlaceholder) {
      return a.isOrphanPlaceholder ? 1 : -1;
    }
    return a.key.compareTo(b.key);
  });

  return rows;
}

List<MessageTapback> _sortTapbacks(List<MessageTapback> tapbacks) {
  final sorted = [...tapbacks];
  sorted.sort((a, b) {
    final timestampCompare = a.timestamp.compareTo(b.timestamp);
    if (timestampCompare != 0) return timestampCompare;
    final nodeCompare = a.fromNodeNum.compareTo(b.fromNodeNum);
    if (nodeCompare != 0) return nodeCompare;
    return a.id.compareTo(b.id);
  });
  return sorted;
}
