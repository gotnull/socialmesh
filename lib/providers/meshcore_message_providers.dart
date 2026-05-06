// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore message provider with real-time message handling.
//
// This provider:
// - Listens to incoming messages from MeshCore session
// - Persists messages to storage
// - Tracks unread counts
// - Provides conversation list and message history

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/meshcore_constants.dart';
import '../features/meshcore/parsers/meshcore_message_frame_parser.dart';
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

/// Resolve the full-pubKey conversation id for an inbound frame's
/// 6-byte sender prefix (12 lowercase hex chars from
/// [MeshCoreContactMessageFrame.senderPrefixHex]). Returns the matching
/// conversation's id (full hex pubkey) when a known contact has been
/// discovered, or `null` when no contact in [conversations] starts with
/// the prefix. Channel conversations are ignored.
///
/// Visible for testing so the prefix-to-conversation routing rule is
/// regression-pinned independently of the Riverpod state machinery.
@visibleForTesting
String? meshCoreConversationIdForSenderPrefix(
  Iterable<MeshCoreConversation> conversations,
  String senderPrefixHex,
) {
  if (senderPrefixHex.length != 12) return null;
  final needle = senderPrefixHex.toLowerCase();
  for (final c in conversations) {
    if (c.isChannel) continue;
    if (c.id.toLowerCase().startsWith(needle)) return c.id;
  }
  return null;
}

/// 32-bit FNV-1a hash of a UTF-8 string, returned as 8 lowercase hex
/// chars. Fast, stable, no crypto dependency. Used by D19's
/// deterministic message-id scheme so the same inbound frame always
/// produces the same id and `MeshCoreMessageStore.add*Message`'s
/// indexWhere-by-id dedupe behaviour acts as a duplicate guard for
/// free.
///
/// Public so the chat widget can derive identical ids for in-memory
/// bubbles and have them merge cleanly with the persisted entry on
/// next chat reload. Not cryptographic; do not use for security
/// boundaries.
String meshCoreFnv1a32Hex(String input) {
  const prime = 0x01000193;
  const offset = 0x811c9dc5;
  var hash = offset;
  for (final byte in utf8.encode(input)) {
    hash = (hash ^ byte) & 0xffffffff;
    hash = (hash * prime) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Deterministic id for an inbound channel message. Same channel,
/// same firmware-supplied timestamp, same text => same id => the
/// store's add-then-update-by-id path collapses retries / re-flooded
/// duplicates into a single entry.
String meshCoreInboundChannelMessageId({
  required int channelIndex,
  required DateTime timestamp,
  required String text,
}) {
  final tsKey = timestamp.millisecondsSinceEpoch ~/ 1000;
  return 'mc_in_ch_${channelIndex}_${tsKey}_${meshCoreFnv1a32Hex(text)}';
}

/// Deterministic id for an inbound contact message. Same sender prefix,
/// same firmware-supplied timestamp, same text => same id.
String meshCoreInboundContactMessageId({
  required String senderPrefixHex,
  required DateTime timestamp,
  required String text,
}) {
  final tsKey = timestamp.millisecondsSinceEpoch ~/ 1000;
  return 'mc_in_ct_${senderPrefixHex.toLowerCase()}_${tsKey}_'
      '${meshCoreFnv1a32Hex(text)}';
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
    // D17.A: provider routes inbound frames to the canonical D12
    // parser, removing the pre-D12 broken hand-parser that silently
    // dropped V3 frames at `<37`/`<38` length guards and assumed a
    // fictional 32-byte sender pubkey layout that firmware never
    // sends. The chat screen and the conversations provider now
    // agree on frame layout because they share the same parser.
    if (frame.command == MeshCoreResponses.contactMsgRecv ||
        frame.command == MeshCoreResponses.contactMsgRecvV3) {
      _handleIncomingContactMessage(frame);
    } else if (frame.command == MeshCoreResponses.channelMsgRecv ||
        frame.command == MeshCoreResponses.channelMsgRecvV3) {
      _handleIncomingChannelMessage(frame);
    } else if (frame.command == MeshCorePushCodes.sendConfirmed) {
      _handleSendConfirmed(frame);
    } else if (frame.command == MeshCorePushCodes.msgWaiting) {
      // D18: this was the load-bearing missing handler. Firmware
      // does NOT push received message frames to the companion
      // automatically. It writes them to an offline queue and emits
      // a one-byte `PUSH_CODE_MSG_WAITING` (0x83) tickle. The app
      // must respond with `CMD_SYNC_NEXT_MESSAGE` to drain the queue.
      // Without this handler every inbound message stayed on the
      // firmware screen but never surfaced to the app, regardless
      // of D12/D17.A parser correctness or RF settings.
      // See `MeshCore/examples/companion_radio/MyMesh.cpp:459, 562`.
      _handleMsgWaiting(frame);
    } else if (frame.command == MeshCorePushCodes.advert ||
        frame.command == MeshCorePushCodes.newAdvert) {
      // D17.C: peer name propagation. Firmware emits 0x80 / 0x8A
      // when an existing or new contact's advert is heard. Without
      // an app-side handler these were silently ignored, leaving
      // contact list names stale until the user manually tapped
      // "Refresh Contacts". Refetching is the simplest correct fix
      // (works for both push variants); a more targeted update via
      // `CMD_GET_CONTACT_BY_KEY` would also work but is deferred.
      _handleAdvertPush(frame);
    }
  }

  void _handleMsgWaiting(MeshCoreFrame frame) {
    // Send CMD_SYNC_NEXT_MESSAGE (0x0A) to firmware. The response
    // will be either:
    //   - a full RESP_CODE_*_MSG_RECV[_V3] frame, which our existing
    //     `_handleFrame` chain parses + persists, OR
    //   - RESP_CODE_NO_MORE_MESSAGES (0x0A, 1 byte) which we ignore.
    // Either way the firmware queue advances by one entry per tickle.
    // Multiple tickles arrive when multiple messages are queued; each
    // independently triggers one drain. We do not loop here because
    // each firmware queue entry generates its own tickle, so a single
    // sync per tickle is the firmware-intended cadence.
    AppLogging.meshcore(
      'event=msg_waiting.observed code=0x83 size=${frame.payload.length}',
    );
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      AppLogging.meshcore(
        'event=msg_waiting.drain.skipped reason=no_active_session',
        error: true,
      );
      return;
    }
    AppLogging.meshcore('event=msg_waiting.drain.requested');
    Future.microtask(() async {
      try {
        await session.sendCommand(MeshCoreCommands.syncNextMessage);
      } catch (e) {
        AppLogging.meshcore(
          'event=msg_waiting.drain.failed reason=${e.runtimeType}',
          error: true,
        );
      }
    });
  }

  void _handleIncomingContactMessage(MeshCoreFrame frame) {
    final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
    if (!result.ok) {
      AppLogging.meshcore(
        'event=message.parse.rejected scope=contact source=conversations '
        'code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} reason=${result.rejectReason}',
        error: true,
      );
      return;
    }
    final parsed = result.value!;

    // Resolve the 6-byte firmware-supplied sender prefix to the
    // matching conversation. Conversation IDs are full pubKeyHex (64
    // chars), so a prefix-startsWith match against the live
    // conversation list is the right shape. If no contact has been
    // discovered yet we fall back to the prefix itself as the
    // conversation id; a later contacts.fetch will correctly merge it.
    final senderPrefix = parsed.senderPrefixHex;
    // First try the conversations provider's own list (built from
    // `_contactStore`). If that misses, fall back to the firmware-
    // fetched contacts in `meshCoreContactsProvider`. The two stores
    // are separate: contacts shown in the UI come from the firmware
    // fetch, but `_contactStore` only contains contacts that were
    // explicitly saved client-side. Without this fallback, every
    // first-time inbound contact message is orphaned. (D19.A live
    // bridge test caught this: sim Contacts tile rendered "Unknown"
    // for the iPhone radio, but `state.conversations` was empty so
    // persistence was being skipped.)
    String? matchedId = meshCoreConversationIdForSenderPrefix(
      state.conversations,
      senderPrefix,
    );
    Uint8List? fullSenderKey;
    String? senderName;
    if (matchedId != null) {
      final matched = state.conversations.firstWhere((c) => c.id == matchedId);
      fullSenderKey = matched.contact?.publicKey;
      senderName = matched.contact?.name;
    } else {
      final contactsState = ref.read(meshCoreContactsProvider);
      for (final c in contactsState.contacts) {
        if (c.publicKeyHex.toLowerCase().startsWith(senderPrefix)) {
          matchedId = c.publicKeyHex;
          fullSenderKey = c.publicKey;
          senderName = c.name;
          break;
        }
      }
    }
    final String conversationId = matchedId ?? senderPrefix;

    final stableId = meshCoreInboundContactMessageId(
      senderPrefixHex: senderPrefix,
      timestamp: parsed.timestamp,
      text: parsed.text,
    );

    final message = MeshCoreMessage(
      id: stableId,
      text: parsed.text,
      timestamp: parsed.timestamp,
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: fullSenderKey,
      senderName: senderName,
      pathLength: parsed.pathLen,
    );

    AppLogging.meshcore(
      'event=message.received scope=contact source=conversations '
      'protocol=${parsed.protocol.name} '
      'sender_prefix=$senderPrefix size=${parsed.text.length}',
    );

    // D19.A: persist inbound contact messages so the chat surfaces
    // them on next open. Skip when no matching contact has been
    // discovered yet (orphan path); a later `contacts.fetch` triggered
    // by the advert push will populate the contact, and the next
    // inbound message persists correctly. Persistence runs off-frame
    // so it does not block the broadcast stream listener.
    if (matchedId != null) {
      final persistKey = matchedId;
      Future.microtask(() async {
        try {
          await _messageStore.init();
          await _messageStore.addContactMessage(
            persistKey,
            MeshCoreStoredMessage(
              id: stableId,
              senderKey: fullSenderKey ?? Uint8List(32),
              text: parsed.text,
              timestamp: parsed.timestamp,
              isOutgoing: false,
              status: MeshCoreMessageStatus.delivered,
              pathLength: parsed.pathLen,
              isChannelMessage: false,
            ),
          );
          AppLogging.meshcore(
            'event=message.persisted scope=contact size=${parsed.text.length}',
          );
        } catch (e) {
          AppLogging.meshcore(
            'event=message.persist.failed scope=contact '
            'reason=${e.runtimeType}',
            error: true,
          );
        }
      });
    } else {
      AppLogging.meshcore(
        'event=message.persist.skipped scope=contact '
        'reason=no_matching_contact sender_prefix=$senderPrefix',
      );
    }

    _addMessageToConversation(conversationId, message, incrementUnread: true);
  }

  void _handleIncomingChannelMessage(MeshCoreFrame frame) {
    final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
    if (!result.ok) {
      AppLogging.meshcore(
        'event=message.parse.rejected scope=channel source=conversations '
        'code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} reason=${result.rejectReason}',
        error: true,
      );
      return;
    }
    final parsed = result.value!;

    final stableId = meshCoreInboundChannelMessageId(
      channelIndex: parsed.channelIndex,
      timestamp: parsed.timestamp,
      text: parsed.text,
    );

    final message = MeshCoreMessage(
      id: stableId,
      text: parsed.text,
      timestamp: parsed.timestamp,
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      // Channel messages carry no sender identity in firmware.
      senderKey: null,
      pathLength: parsed.pathLen,
    );

    AppLogging.meshcore(
      'event=message.received scope=channel source=conversations '
      'protocol=${parsed.protocol.name} '
      'channel=${parsed.channelIndex} size=${parsed.text.length}',
    );

    // D19.A: persist inbound channel messages so the chat surfaces
    // them on next open. Channel slot is fixed wire information so
    // there is no orphan-skip path here. Re-flooded duplicates with
    // identical (channel, timestamp, text) collapse into one stored
    // entry via the deterministic id + store's add-by-id update.
    Future.microtask(() async {
      try {
        await _messageStore.init();
        await _messageStore.addChannelMessage(
          parsed.channelIndex,
          MeshCoreStoredMessage(
            id: stableId,
            senderKey: Uint8List(0),
            text: parsed.text,
            timestamp: parsed.timestamp,
            isOutgoing: false,
            status: MeshCoreMessageStatus.delivered,
            pathLength: parsed.pathLen,
            isChannelMessage: true,
            channelIndex: parsed.channelIndex,
          ),
        );
        AppLogging.meshcore(
          'event=message.persisted scope=channel '
          'channel=${parsed.channelIndex} size=${parsed.text.length}',
        );
      } catch (e) {
        AppLogging.meshcore(
          'event=message.persist.failed scope=channel '
          'reason=${e.runtimeType}',
          error: true,
        );
      }
    });

    _addMessageToConversation(
      'channel_${parsed.channelIndex}',
      message,
      incrementUnread: true,
      isChannel: true,
      channelIndex: parsed.channelIndex,
    );
  }

  void _handleSendConfirmed(MeshCoreFrame frame) {
    AppLogging.meshcore(
      'event=push.observed scope=conversations code=0x82 '
      'name=send_confirmed',
    );
    _markPendingAsDelivered();
  }

  void _handleAdvertPush(MeshCoreFrame frame) {
    // D17.C: a peer's contact entry on firmware was just updated
    // (renamed, path changed, freshly heard). Refetch contacts so
    // the conversations list picks up the new name. Lossless fallback
    // to the manual "Refresh Contacts" action that was previously the
    // only path.
    final isNew = frame.command == MeshCorePushCodes.newAdvert;
    AppLogging.meshcore(
      'event=advert.observed code=0x'
      '${frame.command.toRadixString(16).padLeft(2, '0')} '
      'new=$isNew size=${frame.payload.length}',
    );
    // Trigger a contacts refresh on the global contacts notifier.
    // Use Future.microtask so we don't block the frame stream listener.
    Future.microtask(() {
      try {
        ref.read(meshCoreContactsProvider.notifier).refresh();
      } catch (e) {
        AppLogging.meshcore(
          'event=advert.refresh.failed reason=${e.runtimeType}',
          error: true,
        );
      }
    });
    // Reload our own conversation list off the same refresh so the
    // updated contact name surfaces in the conversations provider too.
    Future.microtask(_loadConversations);
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
      AppLogging.meshcore(
        'event=provider.error scope=conversations.load reason=${e.runtimeType}',
        error: true,
      );
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
        AppLogging.meshcore(
          'event=provider.error scope=history.load '
          'isChannel=${params.isChannel} reason=${e.runtimeType}',
          error: true,
        );
        return MeshCoreMessageHistoryState(error: e.toString());
      }
    });

MeshCoreMessageDeliveryStatus _convertStatus(
  MeshCoreMessageStatus storedStatus,
) {
  switch (storedStatus) {
    case MeshCoreMessageStatus.pending:
      return MeshCoreMessageDeliveryStatus.pending;
    case MeshCoreMessageStatus.sent:
      return MeshCoreMessageDeliveryStatus.sent;
    case MeshCoreMessageStatus.delivered:
      return MeshCoreMessageDeliveryStatus.delivered;
    case MeshCoreMessageStatus.failed:
      return MeshCoreMessageDeliveryStatus.failed;
  }
}
