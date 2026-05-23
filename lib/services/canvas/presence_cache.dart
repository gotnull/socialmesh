// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// In-memory presence cache for MeshCanvas.
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §4.
//
// Invariants this file owns:
//   - Presence lives only in this map. No sqflite write, no
//     SharedPreferences write, no disk write. Killing and relaunching
//     the app starts with an empty cache. (Invariant P1.)
//   - Presence apply does not touch cell, applied_op, pending_op,
//     global_digest, tile_digests, or canvas rows. This file does
//     NOT import the repository. (Invariant P2.)
//   - Cap of 256 entries per canvasLocalId; on overflow the oldest
//     `lastSeenMs` entry for that canvas is evicted.
//   - Scope is exact: `(canvasLocalId, channelIndex, nodeNum)` is
//     the full key. A canvasLocalId reused across channel rebinds
//     does NOT collide.
//
// What this file does NOT do (out of P2 scope):
//   - No Timer.periodic. Callers drive `sweepExpired` explicitly.
//     The provider layer (P3 onward) owns the periodic sweep so
//     test setup/teardown stays deterministic.
//   - No emitter logic. No handler wiring. No UI invalidation hook.
library;

import 'dart:async';

import '../../core/logging.dart';
import 'canvas_constants.dart';
import 'presence_models.dart';

/// LWW-style in-memory presence cache. One instance per app process;
/// the provider layer holds the singleton.
class PresenceCache {
  /// Soft cap per canvas. Exists purely as a memory safety net
  /// against grief frames; comfortably above realistic mesh density.
  static const int maxEntriesPerCanvas = 256;

  // Outer: canvasLocalId -> bucket of entries.
  // Inner key: `(channelIndex, nodeNum)` record. channelIndex is
  // part of the lookup key so a canvasLocalId reused across channel
  // rebinds does not collide (CANVAS_PRESENCE_V0_1.md §4.2).
  final Map<int, Map<({int channelIndex, int nodeNum}), PresenceEntry>>
  _buckets = {};

  /// Broadcast stream of canvasLocalIds whose buckets just mutated.
  /// Provider layer subscribes to drive UI invalidation in O(1) per
  /// frame — without it, the UI would either poll on a timer or
  /// require an external invalidation hook on every emit/inbound
  /// path, which we already proved fragile during S8.
  final StreamController<int> _changeController =
      StreamController<int>.broadcast();

  /// Subscribe to per-canvas mutation events. Each event is a
  /// `canvasLocalId` that just had an entry inserted, refreshed, or
  /// evicted. Late subscribers do NOT receive backfill (broadcast
  /// stream semantics) — that is fine; providers reconcile by reading
  /// `entriesForCanvas` on each event.
  Stream<int> get changeStream => _changeController.stream;

  bool _disposed = false;

  /// Upsert presence for `(canvasLocalId, channelIndex, nodeNum)`.
  ///
  /// Returns `true` when the cache mutated (insert, update, or
  /// evict via `leaving`). Returns `false` on a no-op (older
  /// emit_ts, rejected downgrade, defensive guard, leaving on a
  /// non-existent entry).
  ///
  /// [state] of [PresenceState.leaving] evicts the matching entry
  /// and returns `true` iff an entry was removed; `leaving` is
  /// never stored.
  bool upsert({
    required int nodeNum,
    required int canvasLocalId,
    required int channelIndex,
    required PresenceState state,
    required int emitTsSec,
    required int ttlSeconds,
    required PresenceSource source,
    required int nowMs,
    String? displayNameHint,
  }) {
    // P2 §6: P1 codec already enforces the ttl bounds, but this is
    // the second gate so the cache stays safe even if a future
    // caller bypasses the codec.
    if (ttlSeconds < CanvasPresenceLimits.ttlSecondsMin ||
        ttlSeconds > CanvasPresenceLimits.ttlSecondsMax) {
      AppLogging.meshCanvas(
        'presence upsert rejected: ttl=$ttlSeconds out of '
        '[${CanvasPresenceLimits.ttlSecondsMin}, '
        '${CanvasPresenceLimits.ttlSecondsMax}]',
      );
      return false;
    }

    final key = (channelIndex: channelIndex, nodeNum: nodeNum);

    if (state == PresenceState.leaving) {
      final bucket = _buckets[canvasLocalId];
      if (bucket == null) return false;
      final removed = bucket.remove(key);
      if (bucket.isEmpty) _buckets.remove(canvasLocalId);
      if (removed != null) {
        AppLogging.meshCanvas(
          'presence evict canvas=$canvasLocalId channel=$channelIndex '
          'node=0x${nodeNum.toRadixString(16)} (leaving frame)',
        );
        _emitChange(canvasLocalId);
      }
      return removed != null;
    }

    final bucket = _buckets.putIfAbsent(canvasLocalId, () => {});
    final existing = bucket[key];

    if (existing != null && !existing.isExpiredAt(nowMs)) {
      // Hardening: a self-source entry is the local user's own view of
      // themselves on this canvas. While it is unexpired, no inbound
      // radio frame is permitted to mutate it. This blocks a remote
      // echo / spoof from downgrading or otherwise rewriting the
      // local viewer's state. Self can always refresh self; only
      // radio-over-self is blocked.
      if (existing.source == PresenceSource.self &&
          source == PresenceSource.radio) {
        AppLogging.meshCanvas(
          'presence drop: self entry protected from radio overwrite '
          'canvas=$canvasLocalId node=0x${nodeNum.toRadixString(16)}',
        );
        return false;
      }

      if (emitTsSec < existing.emitTsSec) {
        AppLogging.meshCanvas(
          'presence drop: stale emit_ts $emitTsSec < ${existing.emitTsSec} '
          'canvas=$canvasLocalId node=0x${nodeNum.toRadixString(16)}',
        );
        return false;
      }

      final incomingPrec = PresenceEntry.precedenceOf(state);
      if (incomingPrec < existing.statePrecedence) {
        AppLogging.meshCanvas(
          'presence drop: downgrade rejected '
          'canvas=$canvasLocalId node=0x${nodeNum.toRadixString(16)} '
          'existing=${existing.state.name} incoming=${state.name}',
        );
        return false;
      }
    }

    // Cap enforcement applies only to truly new keys. Overwrites
    // of existing entries pass through without counting.
    if (existing == null && bucket.length >= maxEntriesPerCanvas) {
      _evictOldestIn(canvasLocalId, bucket);
    }

    final lastActivityMs =
        (state == PresenceState.active || state == PresenceState.painting)
        ? nowMs
        : null;

    final next = PresenceEntry(
      nodeNum: nodeNum,
      canvasLocalId: canvasLocalId,
      channelIndex: channelIndex,
      state: state,
      emitTsSec: emitTsSec,
      lastSeenMs: nowMs,
      lastActivityMs: lastActivityMs,
      expiresAtMs: nowMs + ttlSeconds * 1000,
      source: source,
      displayNameHint: displayNameHint,
    );
    bucket[key] = next;
    AppLogging.meshCanvas(
      'presence ${existing == null ? "insert" : "update"} '
      'canvas=$canvasLocalId channel=$channelIndex '
      'node=0x${nodeNum.toRadixString(16)} state=${state.name} '
      'source=${source.name}',
    );
    _emitChange(canvasLocalId);
    return true;
  }

  /// Direct eviction by key. Returns `true` if an entry was removed.
  bool evict({
    required int canvasLocalId,
    required int channelIndex,
    required int nodeNum,
  }) {
    final bucket = _buckets[canvasLocalId];
    if (bucket == null) return false;
    final removed = bucket.remove((
      channelIndex: channelIndex,
      nodeNum: nodeNum,
    ));
    if (bucket.isEmpty) _buckets.remove(canvasLocalId);
    if (removed != null) _emitChange(canvasLocalId);
    return removed != null;
  }

  /// Read a single entry by full key. Returns null when no entry
  /// exists. Returns the entry regardless of expiry; callers MUST
  /// check `isExpiredAt(nowMs)` when freshness matters.
  ///
  /// Used by the emit coordinator to pick the heartbeat state from
  /// live local cache (CANVAS_PRESENCE_V0_1.md §3.1).
  PresenceEntry? entryFor({
    required int canvasLocalId,
    required int channelIndex,
    required int nodeNum,
  }) {
    final bucket = _buckets[canvasLocalId];
    if (bucket == null) return null;
    return bucket[(channelIndex: channelIndex, nodeNum: nodeNum)];
  }

  /// All entries for a canvas, sorted painting -> active -> viewing,
  /// then by `lastSeenMs` descending within state.
  List<PresenceEntry> entriesForCanvas(int canvasLocalId) {
    final bucket = _buckets[canvasLocalId];
    if (bucket == null || bucket.isEmpty) return const <PresenceEntry>[];
    final list = bucket.values.toList();
    list.sort((a, b) {
      final cmp = b.statePrecedence.compareTo(a.statePrecedence);
      if (cmp != 0) return cmp;
      return b.lastSeenMs.compareTo(a.lastSeenMs);
    });
    return List.unmodifiable(list);
  }

  /// Compact counts. Cheap selector for the overview card pill so
  /// the Mesh tab does not rebuild every card on every upsert.
  ({int total, int viewing, int active, int painting}) countsForCanvas(
    int canvasLocalId,
  ) {
    final bucket = _buckets[canvasLocalId];
    if (bucket == null) {
      return (total: 0, viewing: 0, active: 0, painting: 0);
    }
    var viewing = 0;
    var active = 0;
    var painting = 0;
    for (final e in bucket.values) {
      switch (e.state) {
        case PresenceState.viewing:
          viewing++;
        case PresenceState.active:
          active++;
        case PresenceState.painting:
          painting++;
        case PresenceState.leaving:
          break;
      }
    }
    return (
      total: viewing + active + painting,
      viewing: viewing,
      active: active,
      painting: painting,
    );
  }

  /// Remove entries whose `expiresAtMs <= nowMs`. Returns the count
  /// evicted. O(n) over the entire cache; n is bounded by the per-
  /// canvas cap times the canvas count (worst case 8 * 256 entries).
  int sweepExpired(int nowMs) {
    var removed = 0;
    final toDrop = <int>[];
    final mutatedCanvases = <int>{};
    for (final entry in _buckets.entries) {
      final canvasLocalId = entry.key;
      final bucket = entry.value;
      bucket.removeWhere((_, presence) {
        if (presence.isExpiredAt(nowMs)) {
          removed++;
          mutatedCanvases.add(canvasLocalId);
          return true;
        }
        return false;
      });
      if (bucket.isEmpty) toDrop.add(canvasLocalId);
    }
    for (final id in toDrop) {
      _buckets.remove(id);
    }
    if (removed > 0) {
      AppLogging.meshCanvas('presence sweep removed=$removed at nowMs=$nowMs');
      for (final id in mutatedCanvases) {
        _emitChange(id);
      }
    }
    return removed;
  }

  /// Wipes everything. Intended for app shutdown or test teardown.
  void clear() {
    final touched = _buckets.keys.toList();
    _buckets.clear();
    for (final id in touched) {
      _emitChange(id);
    }
  }

  /// Tear down the broadcast change stream. Idempotent. Called by
  /// `presenceCacheProvider.onDispose` at app shutdown / container
  /// teardown.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _buckets.clear();
    await _changeController.close();
  }

  void _emitChange(int canvasLocalId) {
    if (_disposed) return;
    if (_changeController.isClosed) return;
    _changeController.add(canvasLocalId);
  }

  /// Total entry count across all canvases. Test introspection only.
  int get debugEntryCount {
    var total = 0;
    for (final b in _buckets.values) {
      total += b.length;
    }
    return total;
  }

  /// Canvases that currently hold at least one entry. Test
  /// introspection only.
  Set<int> get debugTrackedCanvases => Set.unmodifiable(_buckets.keys);

  // ---------------------------------------------------------------------

  void _evictOldestIn(
    int canvasLocalId,
    Map<({int channelIndex, int nodeNum}), PresenceEntry> bucket,
  ) {
    var oldestKey = bucket.keys.first;
    var oldestMs = bucket[oldestKey]!.lastSeenMs;
    for (final mapEntry in bucket.entries) {
      if (mapEntry.value.lastSeenMs < oldestMs) {
        oldestKey = mapEntry.key;
        oldestMs = mapEntry.value.lastSeenMs;
      }
    }
    bucket.remove(oldestKey);
    AppLogging.meshCanvas(
      'presence cap reached on canvas=$canvasLocalId; evicted '
      'oldest node=0x${oldestKey.nodeNum.toRadixString(16)} '
      'channel=${oldestKey.channelIndex} lastSeenMs=$oldestMs',
    );
  }
}
