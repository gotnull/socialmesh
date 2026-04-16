// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Canonical replicated mesh post — the atomic unit of the mesh feed.
///
/// Every [MeshPost] has a deterministic ID derived from its canonical material
/// (author node number, creation timestamp, and content). The same post
/// received via LoRa, BLE sync, or LAN sync always collapses to one stored
/// object.
///
/// Wire format (for LoRa propagation, portnum 264):
/// ```
/// [header:1] [createdAtSec:4] [flags:1] [contentLen:1] [content:0-200]
///
/// header: version(4 bits) | kind(4 bits) — kind = 0x0B (SM_FEED_POST)
/// flags:  ttlClass(3 bits) | propagationClass(2 bits) | reserved(3 bits)
/// ```
///
/// The author node number comes from the Meshtastic packet envelope `from`
/// field and is NOT duplicated inside the payload.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../utils/text_sanitizer.dart';

/// TTL class for mesh posts — longer-lived than ephemeral signals.
enum MeshPostTtl {
  /// 1 hour — quick local announcement.
  hours1(Duration(hours: 1)),

  /// 6 hours — short-lived post.
  hours6(Duration(hours: 6)),

  /// 24 hours — standard post (default).
  hours24(Duration(hours: 24)),

  /// 3 days — persistent announcement.
  days3(Duration(hours: 72)),

  /// 7 days — long-lived bulletin.
  days7(Duration(hours: 168));

  const MeshPostTtl(this.duration);

  /// Concrete duration for this TTL class.
  final Duration duration;

  /// Wire index (3 bits, 0–4).
  int get wireIndex => index;

  /// Parse from wire index, defaulting to [hours24] on unknown values.
  static MeshPostTtl fromWireIndex(int idx) {
    if (idx >= 0 && idx < values.length) return values[idx];
    return hours24;
  }
}

/// Propagation policy — controls how aggressively this post is forwarded.
enum MeshPostPropagation {
  /// Normal propagation — eligible for all transports.
  normal(0),

  /// Conservative — prefer opportunistic transports (BLE/WiFi), limited LoRa.
  conservative(1),

  /// Local only — never forwarded beyond direct peers.
  localOnly(2);

  const MeshPostPropagation(this.wireIndex);

  /// Wire index (2 bits, 0–2).
  final int wireIndex;

  /// Parse from wire index, defaulting to [normal] on unknown values.
  static MeshPostPropagation fromWireIndex(int idx) {
    if (idx >= 0 && idx < values.length) return values[idx];
    return normal;
  }
}

/// Transport via which a post was received.
enum MeshTransportType {
  /// LoRa radio — constrained, long-range.
  lora,

  /// BLE peer sync — opportunistic, short-range.
  blePeerSync,

  /// LAN/WiFi peer sync — opportunistic, high-bandwidth.
  lanPeerSync,

  /// Locally authored — created on this device.
  local,
}

/// Canonical mesh feed post.
///
/// Identity is deterministic: the same (authorNodeNum, createdAtMs, content)
/// triple always produces the same [id] via SHA-256 over canonical material.
class MeshPost {
  MeshPost({
    required this.authorNodeNum,
    required this.createdAtMs,
    required this.content,
    this.ttl = MeshPostTtl.hours24,
    this.propagation = MeshPostPropagation.normal,
    this.schemaVersion = 1,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    this.seenViaTransports = const {},
    this.hopCount,
    this.isLocal = false,
    this.trustScore,
    this.syncState = MeshPostSyncState.pending,
    this.localSeq,
    this.syncSeq,
    this.loraRebroadcastAtMs,
    this.updatedAtMs,
  }) : firstSeenAt = firstSeenAt ?? DateTime.now(),
       lastSeenAt = lastSeenAt ?? DateTime.now(),
       _id = _computeCanonicalId(authorNodeNum, createdAtMs, content);

  /// Deterministic canonical ID — hex-encoded SHA-256 prefix (32 chars = 16 bytes).
  String get id => _id;
  final String _id;

  /// Author mesh node number.
  final int authorNodeNum;

  /// Creation timestamp in milliseconds since epoch.
  final int createdAtMs;

  /// Post content text (UTF-8, max 200 bytes on LoRa).
  final String content;

  /// Time-to-live class controlling expiry.
  final MeshPostTtl ttl;

  /// Propagation policy.
  final MeshPostPropagation propagation;

  /// Schema version for forward compatibility.
  final int schemaVersion;

  /// When this post was first received/created locally.
  final DateTime firstSeenAt;

  /// When this post was most recently seen (any transport).
  final DateTime lastSeenAt;

  /// Set of transports via which this post has been received.
  final Set<MeshTransportType> seenViaTransports;

  /// Hop count from LoRa metadata, if available.
  final int? hopCount;

  /// Whether this post was authored locally on this device.
  final bool isLocal;

  /// Cached trust score of the author at ingest time.
  final double? trustScore;

  /// Sync eligibility state.
  final MeshPostSyncState syncState;

  /// Monotonic local sequence — assigned by the database on insert/update.
  /// Used for deterministic, clock-skew-safe sync cursor ordering.
  final int? localSeq;

  /// Monotonic sync sequence — assigned only on INSERT (new content).
  /// Metadata-only merges do NOT bump this. Used for outbound sync cursor.
  final int? syncSeq;

  /// Milliseconds since epoch when this post was rebroadcast over LoRa
  /// from this device. Null means not yet rebroadcast.
  final int? loraRebroadcastAtMs;

  /// Milliseconds since epoch when this row was last locally modified.
  /// Tracks local DB mutation time (distinct from authored createdAtMs
  /// and network lastSeenAt).
  final int? updatedAtMs;

  /// Computed expiry time.
  DateTime get expiresAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs).add(ttl.duration);

  /// Whether this post has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Compute the deterministic canonical ID from author, timestamp, and content.
  ///
  /// Canonical serialization:
  ///   - authorNodeNum as 4-byte little-endian
  ///   - createdAtMs as 8-byte little-endian
  ///   - content as UTF-8 bytes
  /// Result: first 16 bytes of SHA-256 as 32-char hex string.
  static String _computeCanonicalId(
    int authorNodeNum,
    int createdAtMs,
    String content,
  ) {
    final buffer = BytesBuilder(copy: false);

    // Author node number — 4 bytes LE
    final nodeBytes = Uint8List(4);
    final nodeData = ByteData.sublistView(nodeBytes);
    nodeData.setUint32(0, authorNodeNum, Endian.little);
    buffer.add(nodeBytes);

    // Creation timestamp — 8 bytes LE
    final tsBytes = Uint8List(8);
    final tsData = ByteData.sublistView(tsBytes);
    tsData.setInt64(0, createdAtMs, Endian.little);
    buffer.add(tsBytes);

    // Content — UTF-8
    buffer.add(utf8.encode(content));

    final hash = sha256.convert(buffer.toBytes());
    // First 16 bytes → 32 hex chars
    return hash.bytes
        .take(16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Recreate a [MeshPost] with a known ID (e.g. from database load).
  MeshPost._fromDb({
    required String id,
    required this.authorNodeNum,
    required this.createdAtMs,
    required this.content,
    required this.ttl,
    required this.propagation,
    required this.schemaVersion,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.seenViaTransports,
    this.hopCount,
    required this.isLocal,
    this.trustScore,
    required this.syncState,
    this.localSeq,
    this.syncSeq,
    this.loraRebroadcastAtMs,
    this.updatedAtMs,
  }) : _id = id;

  /// Create from database row.
  factory MeshPost.fromRow(Map<String, dynamic> row) {
    final transports = <MeshTransportType>{};
    final transportJson = row['seen_via_transports'] as String? ?? '[]';
    for (final t in (json.decode(transportJson) as List)) {
      final name = t as String;
      for (final mt in MeshTransportType.values) {
        if (mt.name == name) transports.add(mt);
      }
    }

    return MeshPost._fromDb(
      id: row['id'] as String,
      authorNodeNum: row['author_node_num'] as int,
      createdAtMs: row['created_at_ms'] as int,
      content: row['content'] as String,
      ttl: MeshPostTtl.fromWireIndex(row['ttl_class'] as int? ?? 2),
      propagation: MeshPostPropagation.fromWireIndex(
        row['propagation_class'] as int? ?? 0,
      ),
      schemaVersion: row['schema_version'] as int? ?? 1,
      firstSeenAt: DateTime.fromMillisecondsSinceEpoch(
        row['first_seen_at_ms'] as int,
      ),
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
        row['last_seen_at_ms'] as int,
      ),
      seenViaTransports: transports,
      hopCount: row['hop_count'] as int?,
      isLocal: (row['is_local'] as int? ?? 0) == 1,
      trustScore: row['trust_score'] as double?,
      syncState: MeshPostSyncState.fromValue(row['sync_state'] as int? ?? 0),
      localSeq: row['local_seq'] as int?,
      syncSeq: row['sync_seq'] as int?,
      loraRebroadcastAtMs: row['lora_rebroadcast_at_ms'] as int?,
      updatedAtMs: row['updated_at_ms'] as int?,
    );
  }

  /// Convert to database row.
  Map<String, dynamic> toRow() => {
    'id': id,
    'author_node_num': authorNodeNum,
    'created_at_ms': createdAtMs,
    'content': content,
    'ttl_class': ttl.wireIndex,
    'propagation_class': propagation.wireIndex,
    'schema_version': schemaVersion,
    'expires_at_ms': expiresAt.millisecondsSinceEpoch,
    'first_seen_at_ms': firstSeenAt.millisecondsSinceEpoch,
    'last_seen_at_ms': lastSeenAt.millisecondsSinceEpoch,
    'seen_via_transports': json.encode(
      seenViaTransports.map((t) => t.name).toList(),
    ),
    'hop_count': hopCount,
    'is_local': isLocal ? 1 : 0,
    'trust_score': trustScore,
    'sync_state': syncState.value,
    'local_seq': localSeq,
    'sync_seq': syncSeq,
    'lora_rebroadcast_at_ms': loraRebroadcastAtMs,
    'updated_at_ms': updatedAtMs,
  };

  /// Create a copy with updated fields.
  MeshPost copyWith({
    MeshPostTtl? ttl,
    MeshPostPropagation? propagation,
    DateTime? lastSeenAt,
    Set<MeshTransportType>? seenViaTransports,
    int? hopCount,
    double? trustScore,
    MeshPostSyncState? syncState,
    int? localSeq,
    int? syncSeq,
    int? loraRebroadcastAtMs,
    int? updatedAtMs,
  }) {
    return MeshPost._fromDb(
      id: _id,
      authorNodeNum: authorNodeNum,
      createdAtMs: createdAtMs,
      content: content,
      ttl: ttl ?? this.ttl,
      propagation: propagation ?? this.propagation,
      schemaVersion: schemaVersion,
      firstSeenAt: firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      seenViaTransports: seenViaTransports ?? this.seenViaTransports,
      hopCount: hopCount ?? this.hopCount,
      isLocal: isLocal,
      trustScore: trustScore ?? this.trustScore,
      syncState: syncState ?? this.syncState,
      localSeq: localSeq ?? this.localSeq,
      syncSeq: syncSeq ?? this.syncSeq,
      loraRebroadcastAtMs: loraRebroadcastAtMs ?? this.loraRebroadcastAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  /// Encode for LoRa wire (portnum 264).
  ///
  /// Returns null if content exceeds LoRa budget (200 bytes UTF-8).
  /// Author node number is NOT included — it comes from the Meshtastic
  /// packet envelope `from` field.
  Uint8List? encodeForLora() {
    final contentBytes = utf8.encode(content);
    if (contentBytes.length > 200) return null;

    // Header: version(0) | kind(0x0B)
    final header = 0x0B;

    // Flags: ttl(3) | propagation(2) | reserved(3)
    final flags =
        (ttl.wireIndex & 0x07) | ((propagation.wireIndex & 0x03) << 3);

    // Created at — seconds since epoch, 4 bytes BE
    final createdAtSec = createdAtMs ~/ 1000;

    final size = 1 + 4 + 1 + 1 + contentBytes.length;
    final result = Uint8List(size);
    final data = ByteData.sublistView(result);
    var offset = 0;

    result[offset++] = header;
    data.setUint32(offset, createdAtSec, Endian.big);
    offset += 4;
    result[offset++] = flags;
    result[offset++] = contentBytes.length;
    result.setRange(offset, offset + contentBytes.length, contentBytes);

    return result;
  }

  /// Decode from LoRa wire payload.
  ///
  /// [authorNodeNum] must be supplied from the Meshtastic packet envelope.
  static MeshPost? decodeFromLora(Uint8List data, int authorNodeNum) {
    if (data.length < 7) return null;

    final header = data[0];
    final version = (header >> 4) & 0x0F;
    final kind = header & 0x0F;
    if (kind != 0x0B) return null;
    if (version > 1) return null; // Forward compat: accept 0 and 1

    final bd = ByteData.sublistView(data);
    var offset = 1;

    final createdAtSec = bd.getUint32(offset, Endian.big);
    offset += 4;

    final flags = data[offset++];
    final ttlIndex = flags & 0x07;
    final propagationIndex = (flags >> 3) & 0x03;

    final contentLen = data[offset++];
    if (offset + contentLen > data.length) return null;

    final contentBytes = data.sublist(offset, offset + contentLen);
    final content = sanitizeExternalText(
      utf8.decode(contentBytes, allowMalformed: true),
    );

    final createdAtMs = createdAtSec * 1000;

    return MeshPost(
      authorNodeNum: authorNodeNum,
      createdAtMs: createdAtMs,
      content: content,
      ttl: MeshPostTtl.fromWireIndex(ttlIndex),
      propagation: MeshPostPropagation.fromWireIndex(propagationIndex),
      seenViaTransports: {MeshTransportType.lora},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MeshPost && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MeshPost($id, node=$authorNodeNum, '
      '${content.length > 30 ? '${content.substring(0, 30)}...' : content})';
}

/// Sync eligibility state for cross-transport propagation.
enum MeshPostSyncState {
  /// Eligible for sync to peers.
  pending(0),

  /// Already synced to at least one peer.
  synced(1),

  /// Expired — no longer eligible for propagation.
  expired(2);

  const MeshPostSyncState(this.value);

  /// The stored integer value for this state.
  final int value;

  /// Parse from stored value.
  static MeshPostSyncState fromValue(int v) {
    for (final s in values) {
      if (s.value == v) return s;
    }
    return pending;
  }
}
