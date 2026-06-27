// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Per-peer direction-of-contact summary derived from the DM history:
// whether a node has messaged me and whether I have messaged it. Lets
// surfaces outside the messaging feature (e.g. the map node filter) gate
// on conversation direction without importing the messaging feature or
// scanning the message list themselves. Recomputes only when the message
// list or own node number changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mesh_models.dart';
import 'app_providers.dart';

/// Whether a peer node has inbound and/or outbound direct messages in
/// history. [messagedMe] is true when the peer sent me at least one DM;
/// [iMessaged] is true when I sent the peer at least one DM.
class DmContactDirection {
  final bool messagedMe;
  final bool iMessaged;

  const DmContactDirection({this.messagedMe = false, this.iMessaged = false});
}

/// Pure derivation of per-peer contact direction from the message list.
///
/// Mirrors the direct-message scoping rules of the messaging summaries:
/// tapback reactions are metadata, not messages, and broadcasts are not
/// conversations, so both are skipped.
Map<int, DmContactDirection> computeDmContactDirection(
  List<Message> messages,
  int? myNodeNum,
) {
  final result = <int, DmContactDirection>{};
  for (final message in messages) {
    if (message.isCanonicalTapback) continue;
    if (!message.isDirect) continue;
    final otherNode = message.from == myNodeNum ? message.to : message.from;
    final inbound = message.from == otherNode;
    final existing = result[otherNode];
    result[otherNode] = DmContactDirection(
      messagedMe: (existing?.messagedMe ?? false) || inbound,
      iMessaged: (existing?.iMessaged ?? false) || !inbound,
    );
  }
  return result;
}

/// Contact direction keyed by peer node number, recomputed only when the
/// message list or own node number changes.
final dmContactDirectionProvider = Provider<Map<int, DmContactDirection>>((
  ref,
) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  return computeDmContactDirection(messages, myNodeNum);
});
