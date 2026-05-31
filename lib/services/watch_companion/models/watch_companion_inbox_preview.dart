// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// One row in the Watch inbox preview.
///
/// Identifiers are wire-stable strings, not protocol-typed enums, so the
/// Watch surface stays protocol-neutral. The phone-side facade is the only
/// component that can resolve [id] back to a Meshtastic / MeshCore message.
class WatchCompanionInboxMessage {
  const WatchCompanionInboxMessage({
    required this.id,
    required this.sender,
    required this.snippet,
    required this.timestampMs,
    required this.unread,
    this.channelIndex,
    this.packetId,
  });

  final String id;
  final String sender;
  final String snippet;
  final int timestampMs;
  final bool unread;
  final int? channelIndex;

  /// Meshtastic packet id of this message (v2+), used phone-side to resolve a
  /// reply target. Null for MeshCore rows (no reply wire concept) — the Watch
  /// keys its reply affordance off this being null.
  final int? packetId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sender': sender,
    'snippet': snippet,
    'timestampMs': timestampMs,
    'unread': unread,
    'channelIndex': channelIndex,
    'packetId': packetId,
  };

  factory WatchCompanionInboxMessage.fromJson(Map<String, dynamic> json) {
    return WatchCompanionInboxMessage(
      id: json['id'] as String,
      sender: json['sender'] as String,
      snippet: json['snippet'] as String,
      timestampMs: json['timestampMs'] as int,
      unread: json['unread'] as bool,
      channelIndex: json['channelIndex'] as int?,
      packetId: json['packetId'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionInboxMessage &&
          other.id == id &&
          other.sender == sender &&
          other.snippet == snippet &&
          other.timestampMs == timestampMs &&
          other.unread == unread &&
          other.channelIndex == channelIndex &&
          other.packetId == packetId;

  @override
  int get hashCode => Object.hash(
    id,
    sender,
    snippet,
    timestampMs,
    unread,
    channelIndex,
    packetId,
  );

  @override
  String toString() =>
      'WatchCompanionInboxMessage(id: $id, sender: $sender, '
      'unread: $unread, ch: $channelIndex, pkt: $packetId)';
}

/// Inbox slice of a watch snapshot.
class WatchCompanionInboxPreview {
  const WatchCompanionInboxPreview({
    required this.unreadCount,
    required this.previews,
  });

  final int unreadCount;
  final List<WatchCompanionInboxMessage> previews;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'unreadCount': unreadCount,
    'previews': previews.map((m) => m.toJson()).toList(),
  };

  factory WatchCompanionInboxPreview.fromJson(Map<String, dynamic> json) {
    return WatchCompanionInboxPreview(
      unreadCount: json['unreadCount'] as int,
      previews: (json['previews'] as List<dynamic>)
          .map(
            (e) =>
                WatchCompanionInboxMessage.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchCompanionInboxPreview) return false;
    if (other.unreadCount != unreadCount) return false;
    if (other.previews.length != previews.length) return false;
    for (var i = 0; i < previews.length; i++) {
      if (other.previews[i] != previews[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(unreadCount, Object.hashAll(previews));

  @override
  String toString() =>
      'WatchCompanionInboxPreview(unread: $unreadCount, previews: ${previews.length})';
}
