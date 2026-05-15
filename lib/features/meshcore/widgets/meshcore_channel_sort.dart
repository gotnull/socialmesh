// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q4: pure channel-list sort logic.
//
// The user-selected `MeshCoreChannelSortMode` decides how the
// channels-screen renders the list:
//   - `manual`: legacy D37-C behavior (firmware slot order +
//     user-applied reorder). The sort helper returns the input list
//     verbatim and the screen leaves reorder drag handles enabled.
//   - `aToZ`: case-insensitive `displayName` ascending.
//   - `latest`: most-recent activity first, ties broken by slot
//     index ascending. Channels with no recorded activity (null
//     `lastMessageTime`) land at the bottom, also tie-broken by
//     slot index.
//   - `unread`: highest unread count first, ties broken by
//     `lastMessageTime` desc, then slot index.
//
// Conversation lookups (`lastMessageTime`, `unreadCount`) come in as
// maps keyed by channel slot index. The screen builds them once from
// `meshCoreConversationsProvider`; the helper stays pure so it can
// be tested without Riverpod.

import '../../../models/meshcore_channel.dart';

enum MeshCoreChannelSortMode { manual, aToZ, latest, unread }

/// Returns a new list of [channels] reordered per [mode]. The input
/// list is never mutated.
List<MeshCoreChannel> sortChannels(
  List<MeshCoreChannel> channels, {
  required MeshCoreChannelSortMode mode,
  Map<int, DateTime?>? byIndexLastMessageTime,
  Map<int, int>? byIndexUnreadCount,
}) {
  if (mode == MeshCoreChannelSortMode.manual) {
    return List<MeshCoreChannel>.of(channels);
  }
  final out = List<MeshCoreChannel>.of(channels);
  switch (mode) {
    case MeshCoreChannelSortMode.manual:
      return out;
    case MeshCoreChannelSortMode.aToZ:
      out.sort((a, b) {
        final cmp = a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
        if (cmp != 0) return cmp;
        return a.index.compareTo(b.index);
      });
      return out;
    case MeshCoreChannelSortMode.latest:
      out.sort((a, b) {
        final aTs = byIndexLastMessageTime?[a.index];
        final bTs = byIndexLastMessageTime?[b.index];
        if (aTs == null && bTs == null) return a.index.compareTo(b.index);
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        final cmp = bTs.compareTo(aTs);
        if (cmp != 0) return cmp;
        return a.index.compareTo(b.index);
      });
      return out;
    case MeshCoreChannelSortMode.unread:
      out.sort((a, b) {
        final aU = byIndexUnreadCount?[a.index] ?? 0;
        final bU = byIndexUnreadCount?[b.index] ?? 0;
        if (aU != bU) return bU.compareTo(aU);
        final aTs = byIndexLastMessageTime?[a.index];
        final bTs = byIndexLastMessageTime?[b.index];
        if (aTs != null && bTs != null) {
          final cmp = bTs.compareTo(aTs);
          if (cmp != 0) return cmp;
        } else if (aTs == null && bTs != null) {
          return 1;
        } else if (bTs == null && aTs != null) {
          return -1;
        }
        return a.index.compareTo(b.index);
      });
      return out;
  }
}
