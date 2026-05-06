// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh sync session model — peer-to-peer sync over opportunistic transports.
///
/// A sync session encapsulates the state of an object exchange between two
/// SocialMesh peers over BLE or LAN. Sessions are explicit (not firehose),
/// bounded (max batch size), and cursor-based (resume where we left off).
library;

import '../mesh_feed/mesh_post.dart';

/// Sync session state machine.
enum SyncSessionState {
  /// Awaiting handshake.
  connecting,

  /// Exchanging object summaries.
  negotiating,

  /// Transferring objects.
  transferring,

  /// Session completed successfully.
  completed,

  /// Session failed or timed out.
  failed,

  /// Session cancelled by either side.
  cancelled,
}

/// Capabilities advertised during handshake.
class SyncCapabilities {
  const SyncCapabilities({
    this.protocolVersion = 1,
    this.supportsMeshPosts = true,
    this.supportsTrustEvidence = false,
    this.maxBatchSize = 50,
  });

  /// Protocol version for forward compatibility.
  final int protocolVersion;

  /// Whether this peer can sync MeshPost objects.
  final bool supportsMeshPosts;

  /// Whether this peer can sync trust evidence (future).
  final bool supportsTrustEvidence;

  /// Maximum number of objects per batch.
  final int maxBatchSize;

  /// Deserialise from a JSON-compatible map.
  factory SyncCapabilities.fromMap(Map<String, dynamic> m) {
    return SyncCapabilities(
      protocolVersion: m['v'] as int? ?? 1,
      supportsMeshPosts: m['posts'] as bool? ?? true,
      supportsTrustEvidence: m['trust'] as bool? ?? false,
      maxBatchSize: m['batch'] as int? ?? 50,
    );
  }

  /// Serialise to a JSON-compatible map.
  Map<String, dynamic> toMap() => {
    'v': protocolVersion,
    'posts': supportsMeshPosts,
    'trust': supportsTrustEvidence,
    'batch': maxBatchSize,
  };
}

/// Summary of an object for sync negotiation — only ID and timestamp,
/// no payload. Peers exchange summaries to determine what needs transfer.
class SyncObjectSummary {
  const SyncObjectSummary({required this.objectId, required this.createdAtMs});

  /// Canonical deterministic ID.
  final String objectId;

  /// Creation timestamp for cursor-based sync.
  final int createdAtMs;
}

/// A tracked sync session with a specific peer.
class MeshSyncSession {
  MeshSyncSession({
    required this.peerId,
    required this.peerNodeNum,
    required this.transport,
    this.peerDisplayName,
    this.peerCapabilities,
  }) : state = SyncSessionState.connecting,
       startedAt = DateTime.now(),
       objectsSent = 0,
       objectsReceived = 0;

  /// Peer identifier (stable `!{nodeHex}` format after hello exchange).
  String peerId;

  /// Peer mesh node number.
  final int peerNodeNum;

  /// Transport used for this session.
  final MeshTransportType transport;

  /// Peer display name if known.
  String? peerDisplayName;

  /// Negotiated peer capabilities.
  SyncCapabilities? peerCapabilities;

  /// Current session state.
  SyncSessionState state;

  /// When this session started.
  final DateTime startedAt;

  /// Objects transferred in this session.
  int objectsSent;
  int objectsReceived;

  /// Last error message if state is [SyncSessionState.failed].
  String? errorMessage;

  /// Duration of this session.
  Duration get duration => DateTime.now().difference(startedAt);

  /// Whether the session is still active.
  bool get isActive =>
      state == SyncSessionState.connecting ||
      state == SyncSessionState.negotiating ||
      state == SyncSessionState.transferring;
}
