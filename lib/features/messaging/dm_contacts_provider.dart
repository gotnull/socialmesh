// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Memoized DM contact summaries (last message, unread count, sender
// identity hints) per peer node. The messaging screen watches four
// providers; deriving this map in a provider of its own means the
// O(allMessages) scan reruns only when messagesProvider actually emits,
// not on every node or presence tick.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Summary of the DM conversation with one peer node.
class DmContactInfo {
  final String? lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? senderDisplayName;
  final String? senderShortName;
  final int? senderAvatarColor;

  DmContactInfo({
    this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.senderDisplayName,
    this.senderShortName,
    this.senderAvatarColor,
  });
}

/// Pure derivation of per-peer DM summaries from the message list.
///
/// Newest message wins the preview; unread counts accumulate for
/// received-and-unread messages from the peer. Tapback reactions are
/// metadata, not messages, and are skipped. Identity hints come from the
/// newest message the peer sent: an outgoing message carries the sending
/// radio's own name, which is not the peer's.
Map<int, DmContactInfo> computeDmContactInfo(
  List<Message> messages,
  int? myNodeNum,
) {
  final dmInfoByNode = <int, DmContactInfo>{};
  final identityByNode = <int, Message>{};
  for (final message in messages) {
    if (message.isCanonicalTapback) continue;
    if (!message.isDirect) continue;
    final otherNode = message.dmPeerFor(myNodeNum);
    final existing = dmInfoByNode[otherNode];
    final isUnread =
        message.received && message.from == otherNode && !message.read;
    final knownIdentity = identityByNode[otherNode];
    if (message.from == otherNode &&
        (knownIdentity == null ||
            message.timestamp.isAfter(knownIdentity.timestamp))) {
      identityByNode[otherNode] = message;
    }
    final identity = identityByNode[otherNode];

    final isNewer =
        existing == null || message.timestamp.isAfter(existing.lastMessageTime);
    if (!isNewer && !isUnread && identity == knownIdentity) continue;
    dmInfoByNode[otherNode] = DmContactInfo(
      lastMessage: isNewer ? message.text : existing.lastMessage,
      lastMessageTime: isNewer ? message.timestamp : existing.lastMessageTime,
      unreadCount: (existing?.unreadCount ?? 0) + (isUnread ? 1 : 0),
      senderDisplayName: identity?.senderDisplayName,
      senderShortName: identity?.senderShortName,
      senderAvatarColor: identity?.senderAvatarColor,
    );
  }
  return dmInfoByNode;
}

/// DM summaries keyed by peer node number, recomputed only when the
/// message list or own node number changes.
final dmContactInfoProvider = Provider<Map<int, DmContactInfo>>((ref) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  if (AppLogging.messagesLoggingEnabled) {
    AppLogging.messages(
      'event=messaging.dmInfo.recompute messages=${messages.length}',
    );
  }
  return computeDmContactInfo(messages, myNodeNum);
});
