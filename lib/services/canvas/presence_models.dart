// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas presence value types.
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §4.1.
//
// These types live separately from the cache implementation so the
// inbound handler (P4), the outbound emitter (P3), and the UI (P5)
// can all consume the shape without dragging in the cache map. The
// presence layer is in-memory only; nothing in this file touches
// sqflite, SharedPreferences, or the canvas.db schema.
library;

import 'package:flutter/foundation.dart';

import 'canvas_codec.dart' show PresenceState;

export 'canvas_codec.dart' show PresenceState;

/// Where a presence entry came from. Metadata only: source does NOT
/// participate in LWW comparison, downgrade-rejection, or TTL math.
enum PresenceSource {
  /// The local viewer's mount shortcut inserted this entry before the
  /// wire emit (CANVAS_PRESENCE_V0_1.md §4.4).
  self,

  /// An inbound presence frame from a peer produced this entry.
  radio,
}

/// One presence entry in the in-memory cache.
///
/// Immutable; mutations produce a fresh instance via the cache's
/// upsert path. `leaving` is never a stored state: it is a transient
/// eviction signal at the cache API level.
@immutable
class PresenceEntry {
  final int nodeNum;
  final int canvasLocalId;
  final int channelIndex;

  /// One of `viewing` / `active` / `painting`. The cache guarantees
  /// `leaving` is never present in a stored entry.
  final PresenceState state;

  /// `emit_ts` from the wire (Unix seconds). Used for LWW
  /// comparisons against later inbound frames.
  final int emitTsSec;

  /// When this device received the frame that produced this entry.
  /// Used as the recency tiebreaker and as the base for TTL math.
  final int lastSeenMs;

  /// Set to `lastSeenMs` when state is active or painting; null
  /// when state is viewing. Used by the UI to render "active 12 s
  /// ago" labels.
  final int? lastActivityMs;

  /// `lastSeenMs + ttlSeconds * 1000`. The GC sweep drops entries
  /// whose `expiresAtMs <= now`.
  final int expiresAtMs;

  final PresenceSource source;

  /// Optional NodeDex-resolved short name. The cache does NOT
  /// resolve this; provider/UI layers may populate it on display.
  /// Null when the node is unknown.
  final String? displayNameHint;

  const PresenceEntry({
    required this.nodeNum,
    required this.canvasLocalId,
    required this.channelIndex,
    required this.state,
    required this.emitTsSec,
    required this.lastSeenMs,
    this.lastActivityMs,
    required this.expiresAtMs,
    required this.source,
    this.displayNameHint,
  });

  /// State precedence: painting > active > viewing. The fallback
  /// for `leaving` is unreachable on a stored entry (the cache
  /// rejects `leaving` as a state value); the case exists to keep
  /// the switch exhaustive.
  int get statePrecedence => precedenceOf(state);

  bool isExpiredAt(int nowMs) => expiresAtMs <= nowMs;

  /// State precedence ordering used by both stored entries (instance
  /// getter) and incoming upsert candidates (no entry constructed
  /// yet at that point).
  static int precedenceOf(PresenceState s) {
    switch (s) {
      case PresenceState.painting:
        return 3;
      case PresenceState.active:
        return 2;
      case PresenceState.viewing:
        return 1;
      case PresenceState.leaving:
        return 0;
    }
  }
}
