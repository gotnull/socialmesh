// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Per-peer × per-kind token-bucket rate limiter for private DMs.
///
/// This is the soft, peer-scoped layer that lives ABOVE the global
/// [SipRateLimiter] in the send-time gate stack. It exists to make
/// abuse hard to scale per peer (e.g. one node trying to spam a user
/// is locally throttled even if the global airtime budget has room).
///
/// Order of gates at every send (text, sketch, reaction, typing):
///   1. hard safety gate          (block?)
///   2. peer capability gate      (existing)
///   3. session state gate        (existing)
///   4. per-peer rate gate        ← THIS layer
///   5. global SipRateLimiter     (existing — authoritative airtime)
///   6. send
///
/// The per-peer limiter NEVER bypasses the global limiter. The global
/// is the spec-bound airtime authority.
///
/// Policy (from the T+S brief, with one approved deviation):
///   - text DM:    6 / 60s, burst 3
///   - sketch:     2 / 60s, burst 1   (deviation: brief said 3; ink
///                                     fills the global budget faster
///                                     than text, so burst stays at 1)
///   - reaction:   6 / 60s, burst 3
///   - typing:     not gated here — already 1/10s internally in
///                                     `SipDmManager.buildTypingIndicator`.
///
/// Idle eviction: a peer's bucket is dropped after 5 minutes of no
/// activity to keep the map bounded on populated meshes.
library;

import '../../../core/logging.dart';

/// Send kind tracked by the limiter. Each kind has its own bucket
/// per peer.
enum PeerRateKind { text, sketch, reaction }

/// Tunable policy. Values are ms-based so tests can drive the clock.
class PeerRatePolicy {
  /// Refill window in ms. Default 60s.
  final int windowMs;

  /// Sustained allowance per [windowMs] for text DMs.
  final int textPerWindow;

  /// Burst capacity for text DMs.
  final int textBurst;

  /// Sustained allowance per [windowMs] for sketches.
  final int sketchPerWindow;

  /// Burst capacity for sketches. **1 by design** — see file header.
  final int sketchBurst;

  /// Sustained allowance per [windowMs] for reactions.
  final int reactionPerWindow;

  /// Burst capacity for reactions.
  final int reactionBurst;

  /// Idle bucket eviction interval (ms). After this much inactivity
  /// for a peer × kind, the bucket is dropped.
  final int idleEvictionMs;

  const PeerRatePolicy({
    this.windowMs = 60 * 1000,
    this.textPerWindow = 6,
    this.textBurst = 3,
    this.sketchPerWindow = 2,
    this.sketchBurst = 1,
    this.reactionPerWindow = 6,
    this.reactionBurst = 3,
    this.idleEvictionMs = 5 * 60 * 1000,
  });

  static const PeerRatePolicy defaultPolicy = PeerRatePolicy();

  int capacityFor(PeerRateKind kind) {
    switch (kind) {
      case PeerRateKind.text:
        return textBurst;
      case PeerRateKind.sketch:
        return sketchBurst;
      case PeerRateKind.reaction:
        return reactionBurst;
    }
  }

  /// Refill rate in tokens per ms (fractional).
  double refillRatePerMs(PeerRateKind kind) {
    final perWindow = switch (kind) {
      PeerRateKind.text => textPerWindow,
      PeerRateKind.sketch => sketchPerWindow,
      PeerRateKind.reaction => reactionPerWindow,
    };
    return perWindow / windowMs;
  }
}

/// One peer × kind bucket. Uses a fractional token count for
/// proportional refill so a 60s window with 6 tokens isn't quantised
/// to "6 tokens jump in at the boundary."
class _Bucket {
  /// Current available tokens (fractional).
  double tokens;

  /// Last time tokens were refilled, in ms.
  int lastRefillMs;

  /// Last time the bucket was touched (for idle eviction).
  int lastActivityMs;

  _Bucket({
    required this.tokens,
    required this.lastRefillMs,
    required this.lastActivityMs,
  });
}

/// Per-peer × per-kind token-bucket limiter.
///
/// Thread model: same as `SipRateLimiter` — Dart isolate-local, no
/// concurrency. All methods are sync.
class PeerRateLimiter {
  final PeerRatePolicy policy;
  final int Function() _clock;

  /// Maps `(peerNodeId, kind)` → bucket. Implemented as a nested
  /// map to keep diagnostics simple.
  final Map<int, Map<PeerRateKind, _Bucket>> _buckets = {};

  /// Construct a new limiter.
  ///
  /// [clock] returns wall-clock ms. Default `DateTime.now`.
  PeerRateLimiter({
    this.policy = PeerRatePolicy.defaultPolicy,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// True when [peerNodeId] is allowed to send [kind] right now.
  /// This is a non-mutating check — call [recordSend] after the gate
  /// passes to actually deduct a token.
  bool canSend(int peerNodeId, PeerRateKind kind) {
    final bucket = _refilledBucket(peerNodeId, kind);
    return bucket.tokens >= 1.0;
  }

  /// Deduct one token for [peerNodeId] × [kind]. Caller MUST have
  /// observed `canSend == true` first; this method does NOT re-check
  /// (that's the SipRateLimiter pattern too — `canSend` then
  /// `recordSend`).
  void recordSend(int peerNodeId, PeerRateKind kind) {
    final bucket = _refilledBucket(peerNodeId, kind);
    bucket.tokens = (bucket.tokens - 1.0).clamp(
      0.0,
      policy.capacityFor(kind).toDouble(),
    );
    bucket.lastActivityMs = _clock();
  }

  /// Diagnostic — count of tracked peer × kind buckets.
  int get bucketCount {
    var n = 0;
    for (final m in _buckets.values) {
      n += m.length;
    }
    return n;
  }

  /// Diagnostic — current token count for a peer × kind. Returns the
  /// capacity when no bucket has been allocated yet.
  double tokensFor(int peerNodeId, PeerRateKind kind) {
    final m = _buckets[peerNodeId];
    final b = m == null ? null : m[kind];
    if (b == null) return policy.capacityFor(kind).toDouble();
    final now = _clock();
    return _refillTokens(b, kind, now);
  }

  /// Drop all state for a peer. Used when a session is removed or
  /// the peer is unblocked-then-reblocked-quickly.
  void resetPeer(int peerNodeId) {
    _buckets.remove(peerNodeId);
  }

  /// Reset every bucket. Diagnostics / test-tear-down.
  void resetAll() {
    _buckets.clear();
  }

  /// Drop buckets that have been idle longer than
  /// [PeerRatePolicy.idleEvictionMs]. Caller should invoke this
  /// periodically (or on every `canSend`) — to keep things simple,
  /// we run it inline on every `_refilledBucket` call.
  void _evictIdleLocked(int now) {
    final toRemove = <(int, PeerRateKind)>[];
    for (final entry in _buckets.entries) {
      for (final inner in entry.value.entries) {
        if (now - inner.value.lastActivityMs > policy.idleEvictionMs) {
          toRemove.add((entry.key, inner.key));
        }
      }
    }
    for (final pair in toRemove) {
      final m = _buckets[pair.$1];
      if (m == null) continue;
      m.remove(pair.$2);
      if (m.isEmpty) _buckets.remove(pair.$1);
    }
  }

  _Bucket _refilledBucket(int peerNodeId, PeerRateKind kind) {
    final now = _clock();
    _evictIdleLocked(now);
    final inner = _buckets.putIfAbsent(peerNodeId, () => {});
    final b = inner.putIfAbsent(
      kind,
      () => _Bucket(
        tokens: policy.capacityFor(kind).toDouble(),
        lastRefillMs: now,
        lastActivityMs: now,
      ),
    );
    final refilled = _refillTokens(b, kind, now);
    b.tokens = refilled;
    b.lastRefillMs = now;
    return b;
  }

  /// Compute the refilled token count for a bucket without mutating
  /// it. Used both by the actual refill path and by `tokensFor` for
  /// diagnostics.
  double _refillTokens(_Bucket b, PeerRateKind kind, int now) {
    final elapsed = now - b.lastRefillMs;
    if (elapsed <= 0) return b.tokens;
    final cap = policy.capacityFor(kind).toDouble();
    final refill = elapsed * policy.refillRatePerMs(kind);
    return (b.tokens + refill).clamp(0.0, cap);
  }
}

/// Convenience extension for callers that want one-shot semantics
/// instead of `canSend` + `recordSend`. Returns true and deducts on
/// success; returns false (and logs an info-level rate-hit event)
/// on miss.
extension PeerRateLimiterTry on PeerRateLimiter {
  bool tryAcquire(int peerNodeId, PeerRateKind kind) {
    if (!canSend(peerNodeId, kind)) {
      AppLogging.sip(
        'SIP_PEER_RATE: hit peer=0x${peerNodeId.toRadixString(16)} '
        'kind=${kind.name}',
      );
      return false;
    }
    recordSend(peerNodeId, kind);
    return true;
  }
}
