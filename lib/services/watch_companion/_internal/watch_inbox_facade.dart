// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Protocol-neutral inbox-preview facade. Public watch_companion files
// MUST NOT import this file outside the snapshot composer.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/providers/app_providers.dart'
    show
        ActiveProtocol,
        activeProtocolProvider,
        messagesProvider,
        unreadMessagesCountProvider;
import 'package:socialmesh/providers/meshcore_message_providers.dart'
    show meshCoreConversationsProvider;
import 'package:socialmesh/models/mesh_models.dart' show Message;

import '../models/watch_companion_inbox_preview.dart';

/// Maximum number of inbox rows surfaced to the Watch. The composer
/// re-applies this cap as defence-in-depth.
const int kWatchInboxMaxRows = 5;

/// Collapses both protocols' message stores into one
/// [WatchCompanionInboxPreview]. Each protocol's "inbox" has a different
/// shape on the phone side:
///
/// - Meshtastic: a flat `List<Message>` in insertion order; the latest
///   five (`.reversed.take(5)`) match what `recent_messages_widget`
///   renders on the dashboard.
/// - MeshCore: a list of MeshCoreConversation (one row per peer or
///   channel) with `lastMessageText` + `lastMessageTime`; we surface
///   each conversation's latest message as one inbox row.
///
/// When no protocol is active, returns an empty preview. When a slice
/// provider is unavailable the composer catches and degrades the section.
final watchInboxFacadeProvider = Provider<WatchCompanionInboxPreview>((ref) {
  final activeProtocol = ref.watch(activeProtocolProvider);

  switch (activeProtocol) {
    case ActiveProtocol.none:
      return const WatchCompanionInboxPreview(
        unreadCount: 0,
        previews: <WatchCompanionInboxMessage>[],
      );

    case ActiveProtocol.meshtastic:
      final messages = ref.watch(messagesProvider);
      final unread = ref.watch(unreadMessagesCountProvider);

      final previews = messages.reversed
          .take(kWatchInboxMaxRows)
          .map(_meshtasticMessageToPreview)
          .toList(growable: false);

      return WatchCompanionInboxPreview(
        unreadCount: unread,
        previews: previews,
      );

    case ActiveProtocol.meshcore:
      final state = ref.watch(meshCoreConversationsProvider);

      // Conversations are not guaranteed to be sorted; sort by latest
      // message time descending so the Watch sees the freshest 5.
      final sorted = state.conversations.toList()
        ..sort((a, b) {
          final at = a.lastMessageTime?.millisecondsSinceEpoch ?? 0;
          final bt = b.lastMessageTime?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });

      final previews = sorted
          .take(kWatchInboxMaxRows)
          .map(
            (c) => WatchCompanionInboxMessage(
              id: c.id,
              sender: c.name,
              snippet: c.lastMessageText ?? '',
              timestampMs: c.lastMessageTime?.millisecondsSinceEpoch ?? 0,
              unread: c.unreadCount > 0,
              channelIndex: c.isChannel ? c.channelIndex : null,
            ),
          )
          .toList(growable: false);

      return WatchCompanionInboxPreview(
        unreadCount: state.totalUnreadCount,
        previews: previews,
      );
  }
});

WatchCompanionInboxMessage _meshtasticMessageToPreview(Message m) {
  return WatchCompanionInboxMessage(
    id: m.id,
    sender:
        m.senderLongName ??
        m.senderShortName ??
        '0x${m.from.toRadixString(16).toUpperCase().padLeft(8, '0')}',
    snippet: m.text,
    timestampMs: m.timestamp.millisecondsSinceEpoch,
    unread: m.received && !m.read,
    channelIndex: m.channel,
  );
}
