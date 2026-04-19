// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// LAN sync protocol v1 — message models for peer-to-peer mesh feed sync.
///
/// Wire format: line-delimited JSON over TCP. Each line is a JSON object
/// with a `type` field discriminating the message kind.
///
/// Protocol flow (after TCP connection established):
///
/// ```
/// Phase 1 — Hello:
///   INITIATOR → hello
///   RESPONDER → hello
///
/// Phase 2 — Initiator pulls from responder:
///   INITIATOR → syncRequest
///   RESPONDER → syncBatch (repeat while hasMore)
///   INITIATOR → syncAck (after each batch)
///
/// Phase 3 — Responder pulls from initiator:
///   RESPONDER → syncRequest
///   INITIATOR → syncBatch (repeat while hasMore)
///   RESPONDER → syncAck (after each batch)
///
/// Phase 4 — Close:
///   INITIATOR → close
/// ```
///
/// Invariants:
///   - Cursor advances ONLY after ack (sender side).
///   - Version mismatch → error + close.
///   - Malformed frames → error + close.
///   - Max [maxSessionRounds] batch round-trips per direction.
library;

import 'dart:convert';

/// Current protocol version. Increment on breaking changes.
const int lanSyncProtocolVersion = 1;

/// Maximum batch round-trips per direction before forced close.
const int maxSessionRounds = 10;

/// Overall session timeout.
const Duration lanSyncSessionTimeout = Duration(seconds: 30);

/// Per-message read timeout.
const Duration lanSyncMessageTimeout = Duration(seconds: 10);

/// Default sync port for mDNS advertisement.
const int lanSyncDefaultPort = 4480;

/// mDNS service type for Socialmesh peer sync.
///
/// Uses hyphen (not underscore) per RFC 6335 Section 5.1: service names
/// must contain only `[A-Za-z0-9-]`. Underscores are silently rejected
/// by Android NSD and iOS NWBrowser, preventing discovery.
const String lanSyncServiceType = '_socialmesh-sync._tcp';

// ---------------------------------------------------------------------------
// Message types
// ---------------------------------------------------------------------------

/// Discriminator for LAN sync protocol messages.
enum LanSyncMessageType { hello, syncRequest, syncBatch, syncAck, error, close }

// ---------------------------------------------------------------------------
// Base class
// ---------------------------------------------------------------------------

/// Base class for all LAN sync protocol messages.
sealed class LanSyncMessage {
  const LanSyncMessage();

  /// Message type discriminator.
  LanSyncMessageType get type;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson();

  /// Serialize to a single JSON line (no trailing newline).
  String toLine() => json.encode(toJson());

  /// Parse a JSON map into a typed [LanSyncMessage].
  ///
  /// Returns `null` if the type is unknown (forward compatibility).
  /// Throws [FormatException] if required fields are missing.
  static LanSyncMessage? parse(Map<String, dynamic> map) {
    final typeStr = map['type'] as String?;
    if (typeStr == null) return null;

    return switch (typeStr) {
      'hello' => LanSyncHello.fromJson(map),
      'syncRequest' => LanSyncRequest.fromJson(map),
      'syncBatch' => LanSyncBatch.fromJson(map),
      'syncAck' => LanSyncAck.fromJson(map),
      'error' => LanSyncError.fromJson(map),
      'close' => LanSyncClose.fromJson(map),
      _ => null,
    };
  }
}

// ---------------------------------------------------------------------------
// Hello
// ---------------------------------------------------------------------------

/// Handshake message exchanged at session start.
///
/// Both peers send a hello. The receiver validates [protocolVersion] and
/// rejects with an error if incompatible.
class LanSyncHello extends LanSyncMessage {
  const LanSyncHello({
    required this.protocolVersion,
    required this.peerId,
    required this.nodeNum,
    this.displayName,
    this.maxBatchSize = defaultBatchSize,
  });

  /// Default batch size.
  static const int defaultBatchSize = 50;

  @override
  LanSyncMessageType get type => LanSyncMessageType.hello;

  /// Protocol version (must match [lanSyncProtocolVersion]).
  final int protocolVersion;

  /// Stable peer identity — `!{nodeHex}` format (e.g. `!12345678`).
  final String peerId;

  /// Mesh node number.
  final int nodeNum;

  /// Human-readable display name (optional).
  final String? displayName;

  /// Maximum batch size this peer supports.
  final int maxBatchSize;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'hello',
    'protocolVersion': protocolVersion,
    'peerId': peerId,
    'nodeNum': nodeNum,
    if (displayName != null) 'displayName': displayName,
    'maxBatchSize': maxBatchSize,
  };

  factory LanSyncHello.fromJson(Map<String, dynamic> map) {
    return LanSyncHello(
      protocolVersion: map['protocolVersion'] as int? ?? 1,
      peerId: map['peerId'] as String? ?? '',
      nodeNum: map['nodeNum'] as int? ?? 0,
      displayName: map['displayName'] as String?,
      maxBatchSize: map['maxBatchSize'] as int? ?? 50,
    );
  }
}

// ---------------------------------------------------------------------------
// Sync Request
// ---------------------------------------------------------------------------

/// Request for a sync batch from the remote peer.
///
/// The receiver looks up the cursor for [requesterPeerId] and returns
/// posts after that cursor.
class LanSyncRequest extends LanSyncMessage {
  const LanSyncRequest({required this.requesterPeerId, this.maxBatchSize = 50});

  @override
  LanSyncMessageType get type => LanSyncMessageType.syncRequest;

  /// The peer ID of the requester (used for cursor lookup on sender side).
  final String requesterPeerId;

  /// Maximum posts to return in one batch.
  final int maxBatchSize;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'syncRequest',
    'requesterPeerId': requesterPeerId,
    'maxBatchSize': maxBatchSize,
  };

  factory LanSyncRequest.fromJson(Map<String, dynamic> map) {
    return LanSyncRequest(
      requesterPeerId: map['requesterPeerId'] as String? ?? '',
      maxBatchSize: map['maxBatchSize'] as int? ?? 50,
    );
  }
}

// ---------------------------------------------------------------------------
// Sync Batch
// ---------------------------------------------------------------------------

/// A batch of posts sent in response to a [LanSyncRequest].
///
/// Posts are serialized as `MeshPost.toRow()` maps. The [lastSeqInBatch]
/// is the sender's `local_seq` of the last post — opaque to the receiver,
/// echoed back in [LanSyncAck] so the sender can advance its cursor.
class LanSyncBatch extends LanSyncMessage {
  const LanSyncBatch({
    required this.posts,
    required this.lastSeqInBatch,
    required this.hasMore,
  });

  @override
  LanSyncMessageType get type => LanSyncMessageType.syncBatch;

  /// Serialized post rows (from `MeshPost.toRow()`).
  final List<Map<String, dynamic>> posts;

  /// The sender's `local_seq` of the last post in this batch.
  /// Null if the batch is empty.
  final int? lastSeqInBatch;

  /// Whether the sender has more posts after this batch.
  final bool hasMore;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'syncBatch',
    'posts': posts,
    'lastSeqInBatch': lastSeqInBatch,
    'hasMore': hasMore,
  };

  factory LanSyncBatch.fromJson(Map<String, dynamic> map) {
    final rawPosts = map['posts'] as List? ?? [];
    return LanSyncBatch(
      posts: rawPosts.cast<Map<String, dynamic>>(),
      lastSeqInBatch: map['lastSeqInBatch'] as int?,
      hasMore: map['hasMore'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Sync Ack
// ---------------------------------------------------------------------------

/// Acknowledgement of a received sync batch.
///
/// [ackedThroughSeq] echoes the [LanSyncBatch.lastSeqInBatch] value.
/// The sender uses this to advance its cursor via
/// `MeshSyncService.acknowledgeSyncBatch()`.
class LanSyncAck extends LanSyncMessage {
  const LanSyncAck({required this.ackedThroughSeq});

  @override
  LanSyncMessageType get type => LanSyncMessageType.syncAck;

  /// The `local_seq` value through which the receiver has ingested.
  final int ackedThroughSeq;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'syncAck',
    'ackedThroughSeq': ackedThroughSeq,
  };

  factory LanSyncAck.fromJson(Map<String, dynamic> map) {
    return LanSyncAck(ackedThroughSeq: map['ackedThroughSeq'] as int? ?? 0);
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

/// Error message — sent before closing on protocol violations.
class LanSyncError extends LanSyncMessage {
  const LanSyncError({required this.message, this.code});

  @override
  LanSyncMessageType get type => LanSyncMessageType.error;

  /// Human-readable error description.
  final String message;

  /// Optional error code for programmatic handling.
  final String? code;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'error',
    'message': message,
    if (code != null) 'code': code,
  };

  factory LanSyncError.fromJson(Map<String, dynamic> map) {
    return LanSyncError(
      message: map['message'] as String? ?? 'Unknown error',
      code: map['code'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Close
// ---------------------------------------------------------------------------

/// Clean session close.
class LanSyncClose extends LanSyncMessage {
  const LanSyncClose();

  @override
  LanSyncMessageType get type => LanSyncMessageType.close;

  @override
  Map<String, dynamic> toJson() => {'type': 'close'};

  factory LanSyncClose.fromJson(Map<String, dynamic> map) {
    return const LanSyncClose();
  }
}

// ---------------------------------------------------------------------------
// Peer identity helper
// ---------------------------------------------------------------------------

/// Build a stable peer ID from a Meshtastic node number.
///
/// Format: `!{hex}` — e.g. node 0x12345678 → `!12345678`.
/// This matches Meshtastic's node identity convention and is stable
/// across network changes (unlike `host:port`).
String buildLanSyncPeerId(int nodeNum) => '!${nodeNum.toRadixString(16)}';
