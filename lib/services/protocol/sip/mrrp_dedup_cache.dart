// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP duplicate request suppression and response cache.
///
/// Provides two bounded, TTL-evicting LRU caches:
///
/// 1. **Request dedup cache**: Keyed by (pubkey_hint, session_tag, request_id).
///    Prevents the same request from being re-processed. If a cached response
///    is available, it is replayed instead of re-executing the handler.
///
/// 2. **Response dedup cache**: Keyed by request_id. Prevents duplicate
///    RESPONSE frames from firing the callback twice at the dispatcher level.
library;

import 'dart:collection';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_types.dart';

/// Key for the request dedup cache.
class MrrpDedupKey {
  /// First 8 bytes of sender's Ed25519 pubkey (from TLV hint or node ID).
  final int pubkeyHint;

  /// SIP session_tag (from TLV hint or default 0).
  final int sessionTag;

  /// MRRP request_id.
  final int requestId;

  const MrrpDedupKey({
    required this.pubkeyHint,
    required this.sessionTag,
    required this.requestId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MrrpDedupKey &&
          other.pubkeyHint == pubkeyHint &&
          other.sessionTag == sessionTag &&
          other.requestId == requestId;

  @override
  int get hashCode => Object.hash(pubkeyHint, sessionTag, requestId);

  @override
  String toString() =>
      'MrrpDedupKey(peer=${pubkeyHint.toRadixString(16)}, '
      'session=${sessionTag.toRadixString(16)}, '
      'reqId=0x${requestId.toRadixString(16)})';
}

/// An entry in the dedup cache, optionally containing a cached response.
class _DedupEntry {
  final DateTime insertedAt;
  MrrpFrame? cachedResponse;

  _DedupEntry({required this.insertedAt});

  bool get isExpired =>
      DateTime.now().difference(insertedAt).inSeconds >
      MrrpConstants.mrrpDedupCacheTtlS;
}

/// An entry in the response dedup cache.
class _ResponseEntry {
  final DateTime insertedAt;

  _ResponseEntry({required this.insertedAt});

  bool get isExpired =>
      DateTime.now().difference(insertedAt).inSeconds >
      MrrpConstants.mrrpResponseCacheTtlS;
}

/// MRRP duplicate request suppression and response cache.
class MrrpDedupCache {
  /// Request dedup cache: keyed by (pubkey_hint, session_tag, request_id).
  final LinkedHashMap<MrrpDedupKey, _DedupEntry> _requestCache =
      LinkedHashMap<MrrpDedupKey, _DedupEntry>();

  /// Response dedup cache: keyed by request_id.
  final LinkedHashMap<int, _ResponseEntry> _responseCache =
      LinkedHashMap<int, _ResponseEntry>();

  // ---------------------------------------------------------------------------
  // Request dedup
  // ---------------------------------------------------------------------------

  /// Check if a request has been seen before.
  ///
  /// Returns the cached response if available (for replay), or `true` if
  /// the request is a duplicate but no response is cached yet, or `null`
  /// if this is a new request.
  MrrpFrame? checkAndRecordRequest(MrrpDedupKey key) {
    _purgeExpiredRequests();

    final existing = _requestCache[key];
    if (existing != null && !existing.isExpired) {
      if (existing.cachedResponse != null) {
        AppLogging.mrrp(
          'MRRP_DEDUP: REQUEST req_id=0x${key.requestId.toRadixString(16)} '
          'from peer=${key.pubkeyHint.toRadixString(16)} '
          '-> DUPLICATE, replaying cached response', // lint-allow: hardcoded-string
        );
        return existing.cachedResponse;
      }
      AppLogging.mrrp(
        'MRRP_DEDUP: REQUEST req_id=0x${key.requestId.toRadixString(16)} '
        'from peer=${key.pubkeyHint.toRadixString(16)} '
        '-> DUPLICATE, no cached response', // lint-allow: hardcoded-string
      );
      return null;
    }

    // New request — record it.
    _evictIfNeeded(_requestCache, MrrpConstants.mrrpDedupCacheSize);
    _requestCache[key] = _DedupEntry(insertedAt: DateTime.now());

    AppLogging.mrrp(
      'MRRP_DEDUP: REQUEST req_id=0x${key.requestId.toRadixString(16)} '
      'from peer=${key.pubkeyHint.toRadixString(16)} '
      '-> first seen, processing', // lint-allow: hardcoded-string
    );

    return null;
  }

  /// Whether a request key is a known duplicate.
  bool isDuplicate(MrrpDedupKey key) {
    final existing = _requestCache[key];
    return existing != null && !existing.isExpired;
  }

  /// Store a response for a previously recorded request (for future replay).
  void cacheResponse(MrrpDedupKey key, MrrpFrame response) {
    final entry = _requestCache[key];
    if (entry != null) {
      entry.cachedResponse = response;
    }
  }

  // ---------------------------------------------------------------------------
  // Response dedup (outbound response tracking)
  // ---------------------------------------------------------------------------

  /// Check if a response with this request_id has already been seen.
  ///
  /// Returns true if this is the first time (should process).
  /// Returns false if this is a duplicate (should suppress).
  bool checkAndRecordResponse(int requestId) {
    _purgeExpiredResponses();

    final existing = _responseCache[requestId];
    if (existing != null && !existing.isExpired) {
      AppLogging.mrrp(
        'MRRP_DEDUP: RESPONSE req_id=0x${requestId.toRadixString(16)} '
        '-> DUPLICATE, suppressed', // lint-allow: hardcoded-string
      );
      return false;
    }

    _evictIfNeeded(_responseCache, MrrpConstants.mrrpResponseCacheSize);
    _responseCache[requestId] = _ResponseEntry(insertedAt: DateTime.now());

    AppLogging.mrrp(
      'MRRP_DEDUP: RESPONSE req_id=0x${requestId.toRadixString(16)} '
      '-> first seen', // lint-allow: hardcoded-string
    );

    return true;
  }

  // ---------------------------------------------------------------------------
  // Cache metrics
  // ---------------------------------------------------------------------------

  /// Number of entries in the request dedup cache.
  int get requestCacheSize => _requestCache.length;

  /// Number of entries in the response dedup cache.
  int get responseCacheSize => _responseCache.length;

  /// Clear all caches.
  void clear() {
    _requestCache.clear();
    _responseCache.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _purgeExpiredRequests() {
    _requestCache.removeWhere((_, v) => v.isExpired);
  }

  void _purgeExpiredResponses() {
    _responseCache.removeWhere((_, v) => v.isExpired);
  }

  void _evictIfNeeded<K>(LinkedHashMap<K, dynamic> cache, int maxSize) {
    while (cache.length >= maxSize) {
      cache.remove(cache.keys.first);
    }
  }
}

/// Helper to build a [MrrpDedupKey] from an inbound MRRP frame.
///
/// Extracts pubkey_hint and session_tag from TLV extensions if present,
/// otherwise falls back to the sender node ID.
MrrpDedupKey buildDedupKey(MrrpFrame frame, int senderNodeId) {
  int pubkeyHint = senderNodeId;
  int sessionTag = 0;

  final pubkeyTlv = frame.findExtension(MrrpTlvType.senderPubkeyHint);
  if (pubkeyTlv != null && pubkeyTlv.value.length >= 4) {
    pubkeyHint = ByteData.sublistView(
      pubkeyTlv.value,
    ).getUint32(0, Endian.little);
  }

  final sessionTlv = frame.findExtension(MrrpTlvType.sessionTagHint);
  if (sessionTlv != null && sessionTlv.value.length >= 4) {
    sessionTag = ByteData.sublistView(
      sessionTlv.value,
    ).getUint32(0, Endian.little);
  }

  return MrrpDedupKey(
    pubkeyHint: pubkeyHint,
    sessionTag: sessionTag,
    requestId: frame.requestId,
  );
}
