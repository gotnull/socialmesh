// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../models/mesh_models.dart';
import '../../utils/text_sanitizer.dart';

/// Pure builders for the CarPlay shared-container payloads.
///
/// These produce the `recent_messages.json` and `peers.json` schemas consumed
/// by the SiriKit Intents extension (see
/// `docs/engineering/CARPLAY_COMMUNICATION_V0_1.md` section 4). They are pure
/// functions of their inputs so they can be unit-tested without providers,
/// platform channels, or a running engine.
///
/// v0.1 scope: direct-message peers only. Broadcast / channel messages are not
/// mirrored yet (tracked as a section 10 open question). The caller logs when
/// channel traffic is skipped so the limitation is visible, not silent.
class CarPlayPayloadBuilder {
  /// Maximum messages mirrored per conversation. Keeps the shared file small;
  /// the extension only needs recent context for Siri read-back.
  static const int maxPerConversation = 20;

  /// Maximum conversations mirrored, most-recently-active first.
  static const int maxConversations = 30;

  /// Build the `recent_messages.json` payload from direct-message history.
  ///
  /// [messages] is the full in-memory message list; broadcast messages are
  /// skipped. [nodes] supplies display names. [myNodeNum] identifies the local
  /// node so `sentByMe` and peer resolution are correct. [nowMs] is injected
  /// for deterministic tests (the live caller passes wall-clock millis).
  static Map<String, dynamic> buildRecentMessages({
    required List<Message> messages,
    required Map<int, MeshNode> nodes,
    required int myNodeNum,
    required int nowMs,
  }) {
    // Group DM messages by the peer node (the non-local party).
    final byPeer = <int, List<Message>>{};
    for (final m in messages) {
      if (m.isBroadcast) continue;
      final peer = m.from == myNodeNum ? m.to : m.from;
      if (peer == myNodeNum || peer == 0 || peer == 0xFFFFFFFF) continue;
      (byPeer[peer] ??= <Message>[]).add(m);
    }

    // Order conversations by their most-recent message, newest first.
    final peerIds = byPeer.keys.toList()
      ..sort((a, b) {
        final aLast = _lastTs(byPeer[a]!);
        final bLast = _lastTs(byPeer[b]!);
        return bLast.compareTo(aLast);
      });

    final conversations = <Map<String, dynamic>>[];
    for (final peer in peerIds.take(maxConversations)) {
      final msgs = byPeer[peer]!
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      // Keep only the newest window, preserving chronological order.
      final window = msgs.length > maxPerConversation
          ? msgs.sublist(msgs.length - maxPerConversation)
          : msgs;

      conversations.add({
        'peerId': peer.toString(),
        'displayName': _displayName(nodes[peer], peer),
        'messages': [
          for (final m in window)
            {
              'id': m.id,
              'text': sanitizeExternalText(m.text),
              'sentByMe': m.from == myNodeNum,
              'tsMs': m.timestamp.millisecondsSinceEpoch,
              // Our own sends are implicitly read; inbound uses the durable
              // read flag (set when the user opens the conversation).
              'read': m.from == myNodeNum || m.read,
            },
        ],
      });
    }

    return {'version': 1, 'updatedAtMs': nowMs, 'conversations': conversations};
  }

  /// Build the `peers.json` payload: resolvable DM recipients for Siri to match
  /// against (`send a message to <name>`). Excludes the local node and any node
  /// without a usable name.
  static Map<String, dynamic> buildPeers({
    required Map<int, MeshNode> nodes,
    required int myNodeNum,
  }) {
    final peers = <Map<String, dynamic>>[];
    for (final entry in nodes.entries) {
      final nodeNum = entry.key;
      if (nodeNum == myNodeNum || nodeNum == 0 || nodeNum == 0xFFFFFFFF) {
        continue;
      }
      final name = _namedOrNull(entry.value);
      if (name == null) continue;
      peers.add({'peerId': nodeNum.toString(), 'displayName': name});
    }
    return {'version': 1, 'peers': peers};
  }

  static int _lastTs(List<Message> msgs) {
    var latest = 0;
    for (final m in msgs) {
      final ts = m.timestamp.millisecondsSinceEpoch;
      if (ts > latest) latest = ts;
    }
    return latest;
  }

  /// Display name with a stable fallback so a conversation is never nameless.
  static String _displayName(MeshNode? node, int nodeNum) {
    return _namedOrNull(node) ?? 'Node ${_hex(nodeNum)}';
  }

  /// Sanitized longName/shortName, or null when the node has no usable name.
  static String? _namedOrNull(MeshNode? node) {
    if (node == null) return null;
    final long = node.longName?.trim();
    if (long != null && long.isNotEmpty) return sanitizeExternalText(long);
    final short = node.shortName?.trim();
    if (short != null && short.isNotEmpty) return sanitizeExternalText(short);
    return null;
  }

  static String _hex(int nodeNum) =>
      '!${nodeNum.toRadixString(16).padLeft(8, '0')}';
}
