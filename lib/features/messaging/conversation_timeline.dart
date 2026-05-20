// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mesh_models.dart';
import '../../models/tapback.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/conversation_read_position.dart';
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

  String? get stableConversationKey {
    if (channelIndex != null) {
      return MessageDatabase.conversationKeyFromParams(channel: channelIndex);
    }
    if (myNodeNum == null || peerNodeNum == null) {
      return null;
    }
    return MessageDatabase.conversationKeyFromParams(
      nodeA: myNodeNum,
      nodeB: peerNodeNum,
    );
  }

  bool get hasStableConversationKey => stableConversationKey != null;

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

enum ConversationRestoreKind { latest, anchor, fallback }

class ConversationRestoreTarget {
  final ConversationRestoreKind kind;
  final String? messageId;
  final double alignment;
  final bool hasNewerMessages;

  const ConversationRestoreTarget.latest()
    : kind = ConversationRestoreKind.latest,
      messageId = null,
      alignment = 1.0,
      hasNewerMessages = false;

  const ConversationRestoreTarget.message({
    required this.kind,
    required this.messageId,
    required this.alignment,
    required this.hasNewerMessages,
  });

  bool get scrollsToMessage => messageId != null;
}

class ConversationTimelineState {
  final List<Message> rawMessages;
  final List<ConversationTimelineRow> rows;
  final ConversationReadPosition? savedPosition;
  final int totalMessageCount;
  final bool hasMoreOlder;
  final bool isLoadingOlder;

  const ConversationTimelineState({
    required this.rawMessages,
    required this.rows,
    required this.totalMessageCount,
    required this.hasMoreOlder,
    required this.isLoadingOlder,
    this.savedPosition,
  });

  ConversationTimelineState copyWith({
    List<Message>? rawMessages,
    List<ConversationTimelineRow>? rows,
    ConversationReadPosition? savedPosition,
    bool clearSavedPosition = false,
    int? totalMessageCount,
    bool? hasMoreOlder,
    bool? isLoadingOlder,
  }) {
    return ConversationTimelineState(
      rawMessages: rawMessages ?? this.rawMessages,
      rows: rows ?? this.rows,
      savedPosition: clearSavedPosition
          ? null
          : savedPosition ?? this.savedPosition,
      totalMessageCount: totalMessageCount ?? this.totalMessageCount,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    );
  }

  bool containsMessageId(String messageId) {
    return rawMessages.any((message) => message.id == messageId);
  }

  Message? messageById(String messageId) {
    for (final message in rawMessages) {
      if (message.id == messageId) {
        return message;
      }
    }
    return null;
  }

  Message? messageByPacketId(int packetId) {
    for (final message in rawMessages) {
      if (message.packetId == packetId) {
        return message;
      }
    }
    return null;
  }
}

class _ConversationTimelineSession {
  DateTime? oldestLoadedTimestamp;
  String? oldestLoadedMessageId;
  ConversationReadPosition? savedPosition;
}

class ConversationTimelineController
    extends
        Notifier<
          Map<ConversationTimelineQuery, AsyncValue<ConversationTimelineState>>
        > {
  static const int initialWindowMessageCount = 80;
  static const int olderPageMessageCount = 80;

  final Map<ConversationTimelineQuery, _ConversationTimelineSession> _sessions =
      {};

  @override
  Map<ConversationTimelineQuery, AsyncValue<ConversationTimelineState>>
  build() {
    ref.listen(messagesProvider, (previous, next) {
      unawaited(_refreshAllInitializedQueries());
    });
    ref.listen(messageTimelineEpochProvider, (previous, next) {
      unawaited(_refreshAllInitializedQueries());
    });
    ref.onDispose(_sessions.clear);
    return {};
  }

  Future<void> ensureInitialized(ConversationTimelineQuery query) async {
    final current = state[query];
    if (current?.hasValue == true || current?.isLoading == true) {
      return;
    }

    _setQueryState(query, const AsyncValue.loading());
    try {
      final loaded = await _loadState(query);
      _setQueryState(query, AsyncValue.data(loaded));
    } catch (error, stackTrace) {
      _setQueryState(query, AsyncValue.error(error, stackTrace));
    }
  }

  Future<int> loadOlder(ConversationTimelineQuery query) async {
    await ensureInitialized(query);
    final current = _queryValue(query);
    if (!query.hasStableConversationKey ||
        current == null ||
        current.isLoadingOlder ||
        !current.hasMoreOlder) {
      return 0;
    }

    final session = _sessions.putIfAbsent(
      query,
      _ConversationTimelineSession.new,
    );
    final beforeTimestamp = session.oldestLoadedTimestamp;
    final beforeMessageId = session.oldestLoadedMessageId;
    if (beforeTimestamp == null || beforeMessageId == null) {
      return 0;
    }

    _setQueryState(
      query,
      AsyncValue.data(current.copyWith(isLoadingOlder: true)),
    );

    try {
      final storage = await ref.read(messageStorageProvider.future);
      final olderPage = await storage.loadConversationOlderPage(
        query.stableConversationKey!,
        beforeTimestamp: beforeTimestamp,
        beforeMessageId: beforeMessageId,
        limit: olderPageMessageCount,
      );
      if (olderPage.isEmpty) {
        _setQueryState(
          query,
          AsyncValue.data(
            current.copyWith(hasMoreOlder: false, isLoadingOlder: false),
          ),
        );
        return 0;
      }

      session.oldestLoadedTimestamp = olderPage.first.timestamp;
      session.oldestLoadedMessageId = olderPage.first.id;

      final refreshed = await _loadState(query);
      _setQueryState(query, AsyncValue.data(refreshed));
      return olderPage.length;
    } catch (error, stackTrace) {
      _setQueryState(query, AsyncValue.error(error, stackTrace));
      rethrow;
    }
  }

  Future<void> saveReadPosition(
    ConversationTimelineQuery query,
    ConversationReadPosition position,
  ) async {
    if (!query.hasStableConversationKey) {
      return;
    }

    final storage = await ref.read(messageStorageProvider.future);
    await storage.saveConversationReadPosition(position);

    final session = _sessions.putIfAbsent(
      query,
      _ConversationTimelineSession.new,
    );
    session.savedPosition = position;

    final current = _queryValue(query);
    if (current != null) {
      _setQueryState(
        query,
        AsyncValue.data(current.copyWith(savedPosition: position)),
      );
    }
  }

  Future<bool> ensureMessageLoaded(
    ConversationTimelineQuery query,
    String messageId,
  ) async {
    return _ensureMessageMatching(
      query,
      (timelineState) => timelineState.containsMessageId(messageId),
    );
  }

  Future<String?> ensureMessageWithPacketIdLoaded(
    ConversationTimelineQuery query,
    int packetId,
  ) async {
    final found = await _ensureMessageMatching(
      query,
      (timelineState) => timelineState.messageByPacketId(packetId) != null,
    );
    if (!found) return null;
    return _queryValue(query)?.messageByPacketId(packetId)?.id;
  }

  Future<ConversationRestoreTarget> resolveInitialRestoreTarget(
    ConversationTimelineQuery query,
  ) async {
    await ensureInitialized(query);
    var timelineState = _queryValue(query);
    if (timelineState == null || timelineState.rawMessages.isEmpty) {
      return const ConversationRestoreTarget.latest();
    }

    final savedPosition = timelineState.savedPosition;
    if (savedPosition == null || savedPosition.wasNearLatest) {
      return const ConversationRestoreTarget.latest();
    }

    final found = await ensureMessageLoaded(
      query,
      savedPosition.anchorMessageId,
    );
    timelineState = _queryValue(query) ?? timelineState;

    if (found) {
      return ConversationRestoreTarget.message(
        kind: ConversationRestoreKind.anchor,
        messageId: savedPosition.anchorMessageId,
        alignment: _sanitizeAlignment(savedPosition.anchorAlignment),
        hasNewerMessages: _hasNewerMessages(
          timelineState,
          savedPosition.anchorMessageId,
        ),
      );
    }

    final fallbackMessage = _findFallbackMessage(
      timelineState.rawMessages,
      savedPosition,
    );
    if (fallbackMessage == null) {
      return const ConversationRestoreTarget.latest();
    }

    return ConversationRestoreTarget.message(
      kind: ConversationRestoreKind.fallback,
      messageId: fallbackMessage.id,
      alignment: _sanitizeAlignment(savedPosition.anchorAlignment),
      hasNewerMessages: _hasNewerMessages(timelineState, fallbackMessage.id),
    );
  }

  Future<void> _refreshAllInitializedQueries() async {
    final initializedQueries = _sessions.keys.toList(growable: false);
    for (final query in initializedQueries) {
      await _refreshQuery(query);
    }
  }

  Future<void> _refreshQuery(ConversationTimelineQuery query) async {
    final current = _queryValue(query);
    if (current == null) return;

    try {
      final refreshed = await _loadState(
        query,
        isLoadingOlder: current.isLoadingOlder,
      );
      _setQueryState(query, AsyncValue.data(refreshed));
    } catch (error, stackTrace) {
      _setQueryState(query, AsyncValue.error(error, stackTrace));
    }
  }

  Future<ConversationTimelineState> _loadState(
    ConversationTimelineQuery query, {
    bool isLoadingOlder = false,
  }) async {
    final storage = await ref.read(messageStorageProvider.future);
    final session = _sessions.putIfAbsent(
      query,
      _ConversationTimelineSession.new,
    );

    if (query.hasStableConversationKey) {
      session.savedPosition ??= await storage.loadConversationReadPosition(
        query.stableConversationKey!,
      );
    }

    final totalMessageCount = query.hasStableConversationKey
        ? await storage.countConversationMessages(query.stableConversationKey!)
        : 0;

    List<Message> rawMessages;
    if (!query.hasStableConversationKey) {
      rawMessages = await _loadConversationWithoutStableKey(storage, query);
    } else {
      if (session.oldestLoadedTimestamp != null &&
          session.oldestLoadedMessageId != null) {
        rawMessages = await storage.loadConversationFromBoundary(
          query.stableConversationKey!,
          fromTimestamp: session.oldestLoadedTimestamp!,
          fromMessageId: session.oldestLoadedMessageId!,
        );
        if (rawMessages.isEmpty && totalMessageCount > 0) {
          rawMessages = await storage.loadConversationNewestWindow(
            query.stableConversationKey!,
            limit: initialWindowMessageCount,
          );
        }
      } else {
        rawMessages = await storage.loadConversationNewestWindow(
          query.stableConversationKey!,
          limit: initialWindowMessageCount,
        );
      }
    }

    if (rawMessages.isNotEmpty) {
      session.oldestLoadedTimestamp = rawMessages.first.timestamp;
      session.oldestLoadedMessageId = rawMessages.first.id;
    } else {
      session.oldestLoadedTimestamp = null;
      session.oldestLoadedMessageId = null;
    }

    return ConversationTimelineState(
      rawMessages: rawMessages,
      rows: buildConversationTimelineRows(rawMessages),
      savedPosition: session.savedPosition,
      totalMessageCount: totalMessageCount,
      hasMoreOlder:
          query.hasStableConversationKey &&
          rawMessages.length < totalMessageCount,
      isLoadingOlder: isLoadingOlder,
    );
  }

  Future<List<Message>> _loadConversationWithoutStableKey(
    MessageDatabase storage,
    ConversationTimelineQuery query,
  ) async {
    if (query.peerNodeNum == null) return const [];
    final messages = await storage.loadMessagesForNode(query.peerNodeNum!);
    return messages.where((message) => message.isDirect).toList();
  }

  Future<bool> _ensureMessageMatching(
    ConversationTimelineQuery query,
    bool Function(ConversationTimelineState timelineState) matches,
  ) async {
    await ensureInitialized(query);
    var timelineState = _queryValue(query);
    if (timelineState == null) return false;
    if (matches(timelineState)) return true;

    final maxPaginationLoads =
        (timelineState.totalMessageCount / olderPageMessageCount).ceil();
    for (
      var loadCount = 0;
      loadCount < maxPaginationLoads && (timelineState?.hasMoreOlder ?? false);
      loadCount++
    ) {
      final added = await loadOlder(query);
      timelineState = _queryValue(query);
      if (timelineState == null) return false;
      if (matches(timelineState)) return true;
      if (added == 0) break;
    }
    return timelineState != null && matches(timelineState);
  }

  void _setQueryState(
    ConversationTimelineQuery query,
    AsyncValue<ConversationTimelineState> value,
  ) {
    state = {...state, query: value};
  }

  ConversationTimelineState? _queryValue(ConversationTimelineQuery query) {
    return state[query]?.asData?.value;
  }

  double _sanitizeAlignment(double? alignment) {
    final value = alignment ?? 0.88;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  bool _hasNewerMessages(
    ConversationTimelineState timelineState,
    String restoredMessageId,
  ) {
    if (timelineState.rawMessages.isEmpty) return false;
    return timelineState.rawMessages.last.id != restoredMessageId;
  }

  Message? _findFallbackMessage(
    List<Message> rawMessages,
    ConversationReadPosition savedPosition,
  ) {
    if (rawMessages.isEmpty) return null;

    Message? lastAtOrBeforeAnchor;
    Message? firstAtOrAfterAnchor;
    for (final message in rawMessages) {
      final comparison = _compareSortKey(
        message.timestamp,
        message.id,
        savedPosition.anchorTimestamp,
        savedPosition.anchorMessageId,
      );
      if (comparison <= 0) {
        lastAtOrBeforeAnchor = message;
      }
      if (comparison >= 0 && firstAtOrAfterAnchor == null) {
        firstAtOrAfterAnchor = message;
      }
    }

    return lastAtOrBeforeAnchor ?? firstAtOrAfterAnchor ?? rawMessages.last;
  }

  int _compareSortKey(
    DateTime messageTimestamp,
    String messageId,
    DateTime anchorTimestamp,
    String anchorMessageId,
  ) {
    final timestampComparison = messageTimestamp.compareTo(anchorTimestamp);
    if (timestampComparison != 0) {
      return timestampComparison;
    }
    return messageId.compareTo(anchorMessageId);
  }
}

final conversationTimelineControllerProvider =
    NotifierProvider<
      ConversationTimelineController,
      Map<ConversationTimelineQuery, AsyncValue<ConversationTimelineState>>
    >(ConversationTimelineController.new);

final conversationTimelineStateProvider =
    Provider.family<
      AsyncValue<ConversationTimelineState>?,
      ConversationTimelineQuery
    >((ref, query) {
      final timelines = ref.watch(conversationTimelineControllerProvider);
      return timelines[query];
    });

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
    // Tiebreak by Meshtastic packetId numerically so the comparator does
    // not accidentally let outbound digit IDs ('1747654920123') sort
    // against inbound deterministic IDs ('pkt-<hex>-<hex>') via a string
    // compare — that path produced the user-reported "my message sorts
    // mid-list" symptom when timestamps collided. When only one side has
    // a packetId, the row with a real packet (settled outbound echo or
    // inbound) sorts after a still-pending outbound at the same
    // timestamp, matching user intent ("my just-sent message goes last").
    final aPacketId = a.message?.packetId;
    final bPacketId = b.message?.packetId;
    if (aPacketId != null && bPacketId != null) {
      final packetCompare = aPacketId.compareTo(bPacketId);
      if (packetCompare != 0) return packetCompare;
    } else if (aPacketId != null) {
      return -1;
    } else if (bPacketId != null) {
      return 1;
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
