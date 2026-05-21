// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'watch_companion_canned_messages.dart';
import 'watch_companion_capabilities.dart';
import 'watch_companion_channel_preview.dart';
import 'watch_companion_connection_state.dart';
import 'watch_companion_inbox_preview.dart';
import 'watch_companion_node_preview.dart';

/// Top-level snapshot pushed from phone to Watch over WatchConnectivity.
///
/// The snapshot composer enforces an emission throttle so this object lands
/// at most once every 1500 ms on the Watch side; staleness is judged from
/// [generatedAt] against the receive timestamp on the Watch.
class WatchCompanionSnapshot {
  const WatchCompanionSnapshot({
    required this.generatedAt,
    required this.connection,
    required this.inbox,
    required this.nodes,
    required this.channels,
    required this.cannedMessages,
    required this.capabilities,
  });

  static const int wireVersion = 1;

  /// Milliseconds since epoch. The Watch flags the snapshot as stale once
  /// `now - lastReceivedAt > 30 s` (the receive timestamp is captured
  /// Watch-side; [generatedAt] is the phone's clock).
  final int generatedAt;

  final WatchCompanionConnectionState connection;
  final WatchCompanionInboxPreview inbox;
  final List<WatchCompanionNodePreview> nodes;
  final List<WatchCompanionChannelPreview> channels;
  final List<WatchCompanionCannedMessage> cannedMessages;
  final WatchCompanionCapabilities capabilities;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': wireVersion,
    'generatedAt': generatedAt,
    'connection': connection.toJson(),
    'inbox': inbox.toJson(),
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'channels': channels.map((c) => c.toJson()).toList(),
    'cannedMessages': cannedMessages.map((m) => m.toJson()).toList(),
    'capabilities': capabilities.toJson(),
  };

  factory WatchCompanionSnapshot.fromJson(Map<String, dynamic> json) {
    final v = json['version'];
    if (v != wireVersion) {
      throw FormatException(
        'WatchCompanionSnapshot wire-version mismatch: expected '
        '$wireVersion, got $v',
      );
    }
    return WatchCompanionSnapshot(
      generatedAt: json['generatedAt'] as int,
      connection: WatchCompanionConnectionState.fromJson(
        json['connection'] as Map<String, dynamic>,
      ),
      inbox: WatchCompanionInboxPreview.fromJson(
        json['inbox'] as Map<String, dynamic>,
      ),
      nodes: (json['nodes'] as List<dynamic>)
          .map(
            (e) =>
                WatchCompanionNodePreview.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      channels: (json['channels'] as List<dynamic>)
          .map(
            (e) => WatchCompanionChannelPreview.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      cannedMessages: (json['cannedMessages'] as List<dynamic>)
          .map(
            (e) =>
                WatchCompanionCannedMessage.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      capabilities: WatchCompanionCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchCompanionSnapshot) return false;
    if (other.generatedAt != generatedAt) return false;
    if (other.connection != connection) return false;
    if (other.inbox != inbox) return false;
    if (other.capabilities != capabilities) return false;
    if (other.nodes.length != nodes.length) return false;
    for (var i = 0; i < nodes.length; i++) {
      if (other.nodes[i] != nodes[i]) return false;
    }
    if (other.channels.length != channels.length) return false;
    for (var i = 0; i < channels.length; i++) {
      if (other.channels[i] != channels[i]) return false;
    }
    if (other.cannedMessages.length != cannedMessages.length) return false;
    for (var i = 0; i < cannedMessages.length; i++) {
      if (other.cannedMessages[i] != cannedMessages[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    generatedAt,
    connection,
    inbox,
    capabilities,
    Object.hashAll(nodes),
    Object.hashAll(channels),
    Object.hashAll(cannedMessages),
  );

  @override
  String toString() =>
      'WatchCompanionSnapshot(gen: $generatedAt, '
      'conn: ${connection.status}, inbox: ${inbox.previews.length}, '
      'nodes: ${nodes.length}, channels: ${channels.length})';
}
