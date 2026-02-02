// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore message provider with real-time message handling.
//
// This provider:
// - Listens to incoming messages from MeshCore session
// - Persists messages to storage
// - Tracks unread counts
// - Provides conversation list and message history

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/meshcore_constants.dart';
import '../models/meshcore_contact.dart';
import '../services/meshcore/protocol/meshcore_frame.dart';
import '../services/meshcore/protocol/meshcore_session.dart';
import '../services/meshcore/storage/meshcore_message_store.dart';
import '../services/meshcore/storage/meshcore_contact_store.dart';
import 'meshcore_providers.dart';

// ---------------------------------------------------------------------------
// Message Models
// ---------------------------------------------------------------------------

/// A conversation (contact or channel) with message state.
class MeshCoreConversation {
  /// Conversation identifier (pubKeyHex for contacts, "channel_N" for channels).
  final String id;

  /// Display name.
  final String name;

  /// Whether this is a channel (vs contact).
  final bool isChannel;

  /// Channel index if this is a channel.
  final int? channelIndex;

  /// Contact if this is a contact conversation.
  final MeshCoreContact? contact;

  /// Last message text (preview).
  final String? lastMessageText;

  /// Last message timestamp.
  final DateTime? lastMessageTime;

  /// Unread message count.
  final int unreadCount;

  const MeshCoreConversation({
    required this.id,
    required this.name,
    required this.isChannel,
    this.channelIndex,
    this.contact,
    this.lastMessageText,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  MeshCoreConversation copyWith({
    String? lastMessageText,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return MeshCoreConversation(
      id: id,
      name: name,
      isChannel: isChannel,
      channelIndex: channelIndex,
      contact: contact,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// A message in a MeshCore conversation.
class MeshCoreMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isOutgoing;
  final MeshCoreMessageDeliveryStatus status;
  final Uint8List? senderKey;
  final String? senderName;
  final int? pathLength;

  const MeshCoreMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
    this.status = MeshCoreMessageDeliveryStatus.pending,
    this.senderKey,
    this.senderName,
    this.pathLength,
  });

  MeshCoreMessage copyWith({MeshCoreMessageDeliveryStatus? status}) {
    return MeshCoreMessage(
      id: id,
      text: text,
      timestamp: timestamp,
      isOutgoing: isOutgoing,
      status: status ?? this.status,
      senderKey: senderKey,
      senderName: senderName,
      pathLength: pathLength,
    );
  }
}

/// Message delivery status.
enum MeshCoreMessageDeliveryStatus { pending, sent, delivered, failed }

// ---------------------------------------------------------------------------
// Conversation List Provider
// ---------------------------------------------------------------------------

/// State for the conversation list.
class MeshCoreConversationsState {
  final List<MeshCoreConversation> conversations;
  final bool isLoading;
  final String? error;

  const MeshCoreConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  const MeshCoreConversationsState.initial()
    : conversations = const [],
      isLoading = false,
      error = null;

  MeshCoreConversationsState copyWith({
    List<MeshCoreConversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return MeshCoreConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Total unread count across all conversations.
  int get totalUnreadCount =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);
}

/// Notifier for MeshCore conversations.
class MeshCoreConversationsNotifier
    extends Notifier<MeshCoreConversationsState> {
  StreamSubscription<MeshCoreFrame>? _frameSubscription;
  final MeshCoreMessageStore _messageStore = MeshCoreMessageStore();
  final MeshCoreContactStore _contactStore = MeshCoreContactStore();

  @override
  MeshCoreConversationsState build() {
    // Subscribe to incoming messages when session is available
    final session = ref.watch(meshCoreSessionProvider);
    if (session != null && session.isActive) {
      _subscribeToMessages(session);
    }

    // Load initial conversations
    _loadConversations();

    ref.onDispose(() {
      _frameSubscription?.cancel();
    });

    return const MeshCoreConversationsState.initial();
  }

  void _subscribeToMessages(MeshCoreSession session) {
    _frameSubscription?.cancel();
    _frameSubscription = session.frameStream.listen(_handleFrame);
    AppLogging.protocol('MeshCore Conversations: Subscribed to frame stream');
  }

  void _handleFrame(MeshCoreFrame frame) {
    // Handle incoming messages
    if (frame.command == MeshCoreResponses.contactMsgRecv ||
        frame.command == MeshCoreResponses.contactMsgRecvV3) {
      _handleIncomingContactMessage(frame);
    } else if (frame.command == MeshCoreResponses.channelMsgRecv ||
        frame.command == MeshCoreResponses.channelMsgRecvV3) {
      _handleIncomingChannelMessage(frame);
    } else if (frame.command == MeshCorePushCodes.sendConfirmed) {
      _handleSendConfirmed(frame);
    }
  }

  void _handleIncomingContactMessage(MeshCoreFrame frame) {
    // Parse message from payload
    // Format: [senderPubKey: 32 bytes][timestamp: 4 bytes][flags: 1 byte][text...]
    if (frame.payload.length < 37) return;

    final senderKey = Uint8List.fromList(frame.payload.sublist(0, 32));
    final senderKeyHex = _bytesToHex(senderKey);
    final timestampRaw = _readUint32LE(frame.payload, 32);
    final text = _readCString(frame.payload, 37);

    final message = MeshCoreMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_$senderKeyHex',
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampRaw * 1000),
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: senderKey,
    );

    AppLogging.protocol(
      'MeshCore: Received contact message from $senderKeyHex: $text',
    );

    // Update conversation and increment unread
    _addMessageToConversation(senderKeyHex, message, incrementUnread: true);
  }

  void _handleIncomingChannelMessage(MeshCoreFrame frame) {
    // Parse channel message from payload
    // Format: [channelIdx: 1 byte][senderPubKey: 32 bytes][timestamp: 4 bytes][flags: 1 byte][text...]
    if (frame.payload.length < 38) return;

    final channelIndex = frame.payload[0];
    final senderKey = Uint8List.fromList(frame.payload.sublist(1, 33));
    final timestampRaw = _readUint32LE(frame.payload, 33);
    final text = _readCString(frame.payload, 38);

    final message = MeshCoreMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ch$channelIndex',
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampRaw * 1000),
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: senderKey,
    );

    AppLogging.protocol(
      'MeshCore: Received channel $channelIndex message: $text',
    );

    // Update conversation and increment unread
    _addMessageToConversation(
      'channel_$channelIndex',
      message,
      incrementUnread: true,
      isChannel: true,
      channelIndex: channelIndex,
    );
  }

  void _handleSendConfirmed(MeshCoreFrame frame) {
    // Handle delivery confirmation
    // Payload contains the message hash/ID that was confirmed
    AppLogging.protocol('MeshCore: Message delivery confirmed');
    // Mark matching pending messages as delivered
    _markPendingAsDelivered();
  }

  Future<void> _loadConversations() async {
    state = state.copyWith(isLoading: true);

    try {
      await _messageStore.init();
      await _contactStore.init();

      // Load contacts to build conversation list
      final contacts = await _contactStore.loadContacts();
      final conversations = <MeshCoreConversation>[];

      for (final contact in contacts) {
        final messages = await _messageStore.loadContactMessages(
          contact.publicKeyHex,
        );
        final lastMessage = messages.isNotEmpty ? messages.last : null;
        final unread = await _contactStore.getUnreadCount(contact.publicKeyHex);

        conversations.add(
          MeshCoreConversation(
            id: contact.publicKeyHex,
            name: contact.name,
            isChannel: false,
            contact: contact,
            lastMessageText: lastMessage?.text,
            lastMessageTime: lastMessage?.timestamp,
            unreadCount: unread,
          ),
        );
      }

      // Sort by last message time
      conversations.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      state = MeshCoreConversationsState(conversations: conversations);
    } catch (e) {
      AppLogging.storage('MeshCore: Error loading conversations: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _addMessageToConversation(
    String conversationId,
    MeshCoreMessage message, {
    bool incrementUnread = false,
    bool isChannel = false,
    int? channelIndex,
  }) {
    final updated = List<MeshCoreConversation>.from(state.conversations);
    final index = updated.indexWhere((c) => c.id == conversationId);

    if (index >= 0) {
      final existing = updated[index];
      updated[index] = existing.copyWith(
        lastMessageText: message.text,
        lastMessageTime: message.timestamp,
        unreadCount: incrementUnread
            ? existing.unreadCount + 1
            : existing.unreadCount,
      );
    } else {
      // Create new conversation
      updated.add(
        MeshCoreConversation(
          id: conversationId,
          name: isChannel ? 'Channel $channelIndex' : conversationId,
          isChannel: isChannel,
          channelIndex: channelIndex,
          lastMessageText: message.text,
          lastMessageTime: message.timestamp,
          unreadCount: incrementUnread ? 1 : 0,
        ),
      );
    }

    // Re-sort by time
    updated.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    state = state.copyWith(conversations: updated);

    // Update unread count in storage
    if (incrementUnread && !isChannel) {
      _contactStore.incrementUnreadCount(conversationId);
    }
  }

  void _markPendingAsDelivered() {
    // Mark the most recent pending outgoing message as delivered
    // Full implementation would use message IDs to match specific messages
  }

  /// Clear unread count for a conversation.
  Future<void> markAsRead(String conversationId) async {
    final updated = List<MeshCoreConversation>.from(state.conversations);
    final index = updated.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      updated[index] = updated[index].copyWith(unreadCount: 0);
      state = state.copyWith(conversations: updated);
      await _contactStore.clearUnreadCount(conversationId);
    }
  }

  /// Refresh conversation list.
  Future<void> refresh() async {
    await _loadConversations();
  }

  // Helpers
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static int _readUint32LE(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  static String _readCString(Uint8List data, int offset) {
    final chars = <int>[];
    for (int i = offset; i < data.length && data[i] != 0; i++) {
      chars.add(data[i]);
    }
    return String.fromCharCodes(chars);
  }
}

final meshCoreConversationsProvider =
    NotifierProvider<MeshCoreConversationsNotifier, MeshCoreConversationsState>(
      MeshCoreConversationsNotifier.new,
    );

// ---------------------------------------------------------------------------
// Message History Provider (per conversation)
// ---------------------------------------------------------------------------

/// State for a single conversation's message history.
class MeshCoreMessageHistoryState {
  final List<MeshCoreMessage> messages;
  final bool isLoading;
  final String? error;

  const MeshCoreMessageHistoryState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  const MeshCoreMessageHistoryState.initial()
    : messages = const [],
      isLoading = false,
      error = null;

  MeshCoreMessageHistoryState copyWith({
    List<MeshCoreMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return MeshCoreMessageHistoryState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Parameters for message history provider.
class MessageHistoryParams {
  final String conversationId;
  final bool isChannel;

  const MessageHistoryParams({
    required this.conversationId,
    required this.isChannel,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageHistoryParams &&
          conversationId == other.conversationId &&
          isChannel == other.isChannel;

  @override
  int get hashCode => Object.hash(conversationId, isChannel);
}

/// Provider for message history of a specific conversation.
///
/// Usage:
/// ```dart
/// final messages = ref.watch(
///   meshCoreMessageHistoryProvider(
///     MessageHistoryParams(conversationId: contact.publicKeyHex, isChannel: false),
///   ),
/// );
/// ```
final meshCoreMessageHistoryProvider =
    FutureProvider.family<MeshCoreMessageHistoryState, MessageHistoryParams>((
      ref,
      params,
    ) async {
      final store = MeshCoreMessageStore();
      await store.init();

      try {
        final storedMessages = params.isChannel
            ? await store.loadChannelMessages(
                int.parse(params.conversationId.replaceFirst('channel_', '')),
              )
            : await store.loadContactMessages(params.conversationId);

        final messages = storedMessages.map((stored) {
          return MeshCoreMessage(
            id: stored.id,
            text: stored.text,
            timestamp: stored.timestamp,
            isOutgoing: stored.isOutgoing,
            status: _convertStatus(stored.status),
            senderKey: stored.senderKey,
            pathLength: stored.pathLength,
          );
        }).toList();

        return MeshCoreMessageHistoryState(messages: messages);
      } catch (e) {
        return MeshCoreMessageHistoryState(error: e.toString());
      }
    });

MeshCoreMessageDeliveryStatus _convertStatus(
  MeshCoreMessageStatus storedStatus,
) {
  return switch (storedStatus) {
    MeshCoreMessageStatus.pending => MeshCoreMessageDeliveryStatus.pending,
    MeshCoreMessageStatus.sent => MeshCoreMessageDeliveryStatus.sent,
    MeshCoreMessageStatus.delivered => MeshCoreMessageDeliveryStatus.delivered,
    MeshCoreMessageStatus.failed => MeshCoreMessageDeliveryStatus.failed,
  };
}
