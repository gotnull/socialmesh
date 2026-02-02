// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Represents a MeshCore channel/room.
///
/// In MeshCore, channels are shared communication spaces with a
/// shared encryption key.
@immutable
class MeshCoreChannel {
  /// Unique identifier (derived from key or user-defined).
  final String id;

  /// Channel display name.
  final String name;

  /// Encryption key (hex encoded).
  final String? key;

  /// Timestamp when channel was created/joined.
  final DateTime? joinedAt;

  /// Timestamp of last message in channel.
  final DateTime? lastMessage;

  /// Number of unread messages in this channel.
  final int unreadCount;

  /// Whether this channel is muted.
  final bool isMuted;

  /// Whether this is the default channel.
  final bool isDefault;

  const MeshCoreChannel({
    required this.id,
    required this.name,
    this.key,
    this.joinedAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isDefault = false,
  });

  /// Whether this channel has unread messages.
  bool get hasUnread => unreadCount > 0 && !isMuted;

  MeshCoreChannel copyWith({
    String? id,
    String? name,
    String? key,
    DateTime? joinedAt,
    DateTime? lastMessage,
    int? unreadCount,
    bool? isMuted,
    bool? isDefault,
  }) {
    return MeshCoreChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      joinedAt: joinedAt ?? this.joinedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreChannel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          key == other.key &&
          joinedAt == other.joinedAt &&
          lastMessage == other.lastMessage &&
          unreadCount == other.unreadCount &&
          isMuted == other.isMuted &&
          isDefault == other.isDefault;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    key,
    joinedAt,
    lastMessage,
    unreadCount,
    isMuted,
    isDefault,
  );
}
