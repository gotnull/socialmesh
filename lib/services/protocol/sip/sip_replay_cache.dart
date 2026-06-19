// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// LRU nonce replay cache with pubkey-aware keying.
///
/// Prevents replay attacks by tracking recently seen (nonce, timestamp)
/// pairs. Keys are either pubkey-based (when identity is known) or
/// (node_id, msg_type)-based (for anonymous peers).
library;

import 'dart:collection';
import 'dart:typed_data';

import 'sip_constants.dart';

/// A single replay cache entry recording a seen nonce and its timestamp.
class _ReplayCacheEntry {
  final int nonce;
  final int timestampS;
  final int insertedAtMs;

  _ReplayCacheEntry({required this.nonce, required this.timestampS})
    : insertedAtMs = DateTime.now().millisecondsSinceEpoch;

  bool get isExpired {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ageMs = nowMs - insertedAtMs;
    return ageMs > SipConstants.replayCacheTtlS * 1000;
  }
}

/// Key for the replay cache when identity is unknown.
///
/// Uses (node_id, msg_type) as the cache key.
class _AnonymousKey {
  final int nodeId;
  final int msgType;

  const _AnonymousKey(this.nodeId, this.msgType);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AnonymousKey &&
          nodeId == other.nodeId &&
          msgType == other.msgType;

  @override
  int get hashCode => Object.hash(nodeId, msgType);

  @override
  String toString() =>
      'AnonymousKey(node=0x${nodeId.toRadixString(16)}, type=0x${msgType.toRadixString(16)})';
}

/// LRU nonce replay cache for SIP frame deduplication.
///
/// Each cache key maintains a bounded list of (nonce, timestamp) pairs.
/// When a key exceeds [SipConstants.replayCacheSize] entries, the oldest
/// (LRU) entry is evicted. Entries older than [SipConstants.replayCacheTtl]
/// are pruned on access.
class SipReplayCache {
  /// Cache buckets keyed by either a pubkey hash string or an _AnonymousKey.
  final LinkedHashMap<Object, List<_ReplayCacheEntry>> _buckets =
      LinkedHashMap<Object, List<_ReplayCacheEntry>>();

  /// Maximum buckets (one per peer). Excess buckets are LRU-evicted.
  final int _maxBuckets;

  /// Maximum entries per bucket.
  final int _maxEntriesPerBucket;

  SipReplayCache({
    this._maxBuckets = SipConstants.maxTrackedPeers,
    this._maxEntriesPerBucket = SipConstants.replayCacheSize,
  });

  /// Check if a nonce has been seen recently for the given key context.
  ///
  /// [pubkeyHint]: first 8 bytes of the sender's pubkey, if known.
  /// [nodeId]: Meshtastic node ID (used when pubkey is unknown).
  /// [msgType]: message type code.
  /// [nonce]: the nonce to check.
  ///
  /// Returns true if this is a replay (nonce already seen).
  bool isReplay({
    Uint8List? pubkeyHint,
    required int nodeId,
    required int msgType,
    required int nonce,
  }) {
    final key = _makeKey(
      pubkeyHint: pubkeyHint,
      nodeId: nodeId,
      msgType: msgType,
    );
    final bucket = _buckets[key];
    if (bucket == null) return false;

    // Prune expired entries on access.
    bucket.removeWhere((e) => e.isExpired);

    return bucket.any((e) => e.nonce == nonce);
  }

  /// Record a nonce as seen for the given key context.
  ///
  /// This should be called after successfully processing a frame.
  void recordNonce({
    Uint8List? pubkeyHint,
    required int nodeId,
    required int msgType,
    required int nonce,
    required int timestampS,
  }) {
    final key = _makeKey(
      pubkeyHint: pubkeyHint,
      nodeId: nodeId,
      msgType: msgType,
    );

    // Ensure bucket exists and is accessed (LRU: move to end).
    var bucket = _buckets.remove(key);
    bucket ??= [];
    _buckets[key] = bucket;

    // Prune expired entries.
    bucket.removeWhere((e) => e.isExpired);

    // Check for duplicate nonce (idempotent recording).
    if (bucket.any((e) => e.nonce == nonce)) return;

    // Add new entry.
    bucket.add(_ReplayCacheEntry(nonce: nonce, timestampS: timestampS));

    // Enforce per-bucket limit (LRU: remove oldest).
    while (bucket.length > _maxEntriesPerBucket) {
      bucket.removeAt(0);
    }

    // Enforce global bucket limit (LRU: remove oldest bucket).
    while (_buckets.length > _maxBuckets) {
      _buckets.remove(_buckets.keys.first);
    }
  }

  /// Migrate entries from anonymous key to pubkey-based key.
  ///
  /// Called when a node's pubkey becomes known via verified ID_CLAIM.
  /// Entries under (node_id, msg_type) are moved to (pubkey_hash).
  void upgradeToPublicKey({
    required int nodeId,
    required Uint8List pubkeyHint,
  }) {
    final pubkeyKey = _pubkeyKeyString(pubkeyHint);
    var pubkeyBucket = _buckets.remove(pubkeyKey);
    pubkeyBucket ??= [];

    // Find and merge all anonymous buckets for this node.
    final keysToRemove = <Object>[];
    for (final entry in _buckets.entries) {
      if (entry.key is _AnonymousKey &&
          (entry.key as _AnonymousKey).nodeId == nodeId) {
        pubkeyBucket.addAll(entry.value);
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _buckets.remove(key);
    }

    // Deduplicate by nonce and enforce limits.
    final seen = <int>{};
    pubkeyBucket.removeWhere((e) => e.isExpired || !seen.add(e.nonce));
    while (pubkeyBucket.length > _maxEntriesPerBucket) {
      pubkeyBucket.removeAt(0);
    }

    _buckets[pubkeyKey] = pubkeyBucket;
  }

  /// Clear all cached nonces.
  void clear() => _buckets.clear();

  /// Total number of tracked peers (cache keys).
  int get peerCount => _buckets.length;

  /// Total number of cached nonces across all peers.
  int get totalEntries =>
      _buckets.values.fold(0, (sum, bucket) => sum + bucket.length);

  Object _makeKey({
    Uint8List? pubkeyHint,
    required int nodeId,
    required int msgType,
  }) {
    if (pubkeyHint != null && pubkeyHint.length >= 8) {
      return _pubkeyKeyString(pubkeyHint);
    }
    return _AnonymousKey(nodeId, msgType);
  }

  String _pubkeyKeyString(Uint8List hint) {
    final sb = StringBuffer('pk:');
    final len = hint.length < 8 ? hint.length : 8;
    for (var i = 0; i < len; i++) {
      sb.write(hint[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
