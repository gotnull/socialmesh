// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCoreSendRateLimiter — D33 P2 prerequisite.
//
// Token-bucket rate limiter for outbound MeshCore text frames. Mirrors
// the SIP rate limiter's proportional-refill shape but is simpler: no
// congestion heuristic, no app-resume tracking, no per-frame-type
// distinction. The single bucket gates every `CMD_SEND_TXT_MSG` and
// `CMD_SEND_CHANNEL_TXT_MSG` payload from the host so reply traffic
// (D33), reaction traffic (D34, deferred), and ordinary text sends
// compete fairly for the same budget.
//
// Why now: D33 introduces replies that ride inside MeshCore text
// bodies as larger payloads (envelope + fallback + body). Without a
// rate limiter, a busy reply user can saturate the radio's outbound
// queue and starve plain-text DMs. The plan calls for 1024 B / 60 s
// to mirror SIP's budget; D33 retro will tune in a follow-up if
// real-world airtime telemetry shows the limit is too tight or loose.
//
// Scope:
//   - Counts host -> firmware text payload bytes (the `payload` arg
//     to `sendAndWait` for the SET_TXT / SET_CHANNEL_TXT codes).
//   - Does NOT count framing overhead (codec adds ~3-4 B) — the
//     budget is set with this offset folded in already.
//   - Does NOT count non-text commands (advertise, get_channel,
//     etc.). Those are infrequent and don't compete for the airtime
//     of human-readable messages.

import '../../core/logging.dart';

/// Default budget: 1024 bytes per 60 seconds, mirroring `SipRateLimiter`.
class MeshCoreSendRateLimiterConstants {
  MeshCoreSendRateLimiterConstants._();

  /// Window size in seconds.
  static const int windowSeconds = 60;

  /// Total byte capacity per window.
  static const int budgetBytesPerWindow = 1024;

  /// D34a: how many recently-closed 60-s windows are kept in memory for
  /// the rolling-average computation surfaced in the Tools diagnostics
  /// card. The active (still-filling) window is tracked separately.
  static const int recentWindowsKept = 10;
}

/// D34a: kind tags used to attribute outbound text bytes for the
/// chat-traffic measurement layer.
///
/// The `reaction*` values are reserved-only — D34a does NOT implement
/// reactions. They exist so the future D34b reactions slice does not
/// have to rename buckets, and so regression tests can pin that the
/// names round-trip without populating their counters.
enum MeshCoreSendKind {
  plainContact,
  plainChannel,
  replyContact,
  replyChannel,
  reactionContact,
  reactionChannel,
}

extension MeshCoreSendKindLog on MeshCoreSendKind {
  /// Stable wire-safe label used in `event=text.send.*` log lines.
  /// Matches the enum identifier — never the user-facing label.
  String get logTag => name;
}

/// Outcome of a `tryAcquire` call. Allows the UI / send pipeline to
/// distinguish "send accepted" from "send rejected" with explicit
/// remaining-budget context for UI countdowns.
class MeshCoreRateLimiterDecision {
  /// True when the requested bytes were within budget AND deducted.
  /// False when the request would have exceeded the cap; nothing was
  /// deducted and the caller must not send.
  final bool allowed;

  /// Bytes remaining in the current window AFTER the (allowed or
  /// rejected) request was evaluated. UI shows this as a "you can
  /// still send N bytes" hint.
  final int remainingBytes;

  /// How long until the bucket has at least the rejected request's
  /// bytes available. Zero when [allowed] is true. UI shows this as
  /// a "try in Ns" countdown when [allowed] is false.
  final Duration nextSendIn;

  const MeshCoreRateLimiterDecision({
    required this.allowed,
    required this.remainingBytes,
    required this.nextSendIn,
  });
}

/// D34a: immutable snapshot of the chat-traffic counters surfaced to
/// the Tools diagnostics card and the `meshCoreChatTrafficProvider`.
///
/// Privacy: contains only counts, byte totals, kind tags, and
/// timestamps. No payload content, pubkey, channel name, MMF, or
/// envelope bytes are ever stored here.
class ChatTrafficSnapshot {
  /// Bytes successfully sent in the currently-filling window. Equal to
  /// `currentWindowSentBytes`; surfaced under both names because the
  /// progress bar reads `usedBytes / capacityBytes`.
  final int currentWindowUsedBytes;

  /// Window capacity (matches the rate limiter budget — 1024 B by
  /// default).
  final int windowCapacityBytes;

  /// Token-bucket headroom from the live rate limiter. The send-side
  /// rejection happens when `attemptBytes > remainingBytes`.
  final int remainingBytes;

  /// Bytes sent (allowed) in the current window. Same value as
  /// [currentWindowUsedBytes].
  final int currentWindowSentBytes;

  /// Bytes attempted but rejected by the rate limiter in the current
  /// window. Does NOT consume the token bucket — this is purely a
  /// counter for diagnostics.
  final int currentWindowRejectedBytes;

  /// Per-kind counts of successful sends in the current window.
  /// Always contains every [MeshCoreSendKind] entry (zero-valued when
  /// the bucket is empty).
  final Map<MeshCoreSendKind, int> sendCountByKind;

  /// Per-kind counts of rejected sends in the current window.
  final Map<MeshCoreSendKind, int> rejectedCountByKind;

  /// Largest `currentWindowSentBytes` value ever observed during the
  /// lifetime of the underlying limiter (i.e. since session start).
  /// Reset by [MeshCoreSendRateLimiter.reset].
  final int peakWindowUsage;

  /// Mean of the `sentBytes` values across the last
  /// [MeshCoreSendRateLimiterConstants.recentWindowsKept] closed
  /// windows. Returns 0 when no closed windows have rolled yet.
  final double rollingAverageBytes;

  /// Wall-clock time the active 60-s window began. The Tools card
  /// uses this to render "this minute starts at HH:MM:SS".
  final DateTime windowStart;

  /// Wall-clock time of the most recent rejection observed, or null
  /// if no rejection has occurred since the limiter was constructed.
  final DateTime? lastRejection;

  const ChatTrafficSnapshot({
    required this.currentWindowUsedBytes,
    required this.windowCapacityBytes,
    required this.remainingBytes,
    required this.currentWindowSentBytes,
    required this.currentWindowRejectedBytes,
    required this.sendCountByKind,
    required this.rejectedCountByKind,
    required this.peakWindowUsage,
    required this.rollingAverageBytes,
    required this.windowStart,
    required this.lastRejection,
  });

  /// Empty snapshot used by the provider when no MeshCore session is
  /// live. Renders the "No active MeshCore session" placeholder.
  factory ChatTrafficSnapshot.empty(DateTime now) {
    return ChatTrafficSnapshot(
      currentWindowUsedBytes: 0,
      windowCapacityBytes:
          MeshCoreSendRateLimiterConstants.budgetBytesPerWindow,
      remainingBytes: MeshCoreSendRateLimiterConstants.budgetBytesPerWindow,
      currentWindowSentBytes: 0,
      currentWindowRejectedBytes: 0,
      sendCountByKind: _zeroCounts(),
      rejectedCountByKind: _zeroCounts(),
      peakWindowUsage: 0,
      rollingAverageBytes: 0.0,
      windowStart: now,
      lastRejection: null,
    );
  }

  /// True when the snapshot has zero send / rejected activity. Used by
  /// the Tools card to short-circuit the kind-row rendering.
  bool get isIdle =>
      currentWindowSentBytes == 0 &&
      currentWindowRejectedBytes == 0 &&
      peakWindowUsage == 0;

  static Map<MeshCoreSendKind, int> _zeroCounts() {
    return <MeshCoreSendKind, int>{
      for (final k in MeshCoreSendKind.values) k: 0,
    };
  }
}

/// Token-bucket rate limiter for outbound MeshCore text payloads.
///
/// Single instance per [MeshCoreSession]. Threading: not thread-safe
/// by design; assumed to be called from the dart UI isolate.
///
/// Test seam: pass [clock] to inject a deterministic time source.
/// Default is [DateTime.now].
class MeshCoreSendRateLimiter {
  final DateTime Function() _clock;
  final int _capacity;
  final int _windowMs;

  /// Remaining byte tokens. Refilled proportionally on each call.
  int _remainingBytes;

  /// Wall-clock time of the last refill, in millis since epoch.
  int _lastRefillMs;

  /// D34a: start of the active measurement window in millis since
  /// epoch. Rotates every [_windowMs] independent of the token-bucket
  /// refill cadence.
  int _windowStartMs;

  /// D34a: per-kind sent/rejected accumulators for the active window.
  final Map<MeshCoreSendKind, int> _sendCounts =
      ChatTrafficSnapshot._zeroCounts();
  final Map<MeshCoreSendKind, int> _rejectedCounts =
      ChatTrafficSnapshot._zeroCounts();
  int _windowSentBytes = 0;
  int _windowRejectedBytes = 0;

  /// D34a: sent-byte totals for the last
  /// [MeshCoreSendRateLimiterConstants.recentWindowsKept] closed
  /// windows. Oldest first; capped via FIFO.
  final List<int> _recentClosedWindowBytes = <int>[];

  /// D34a: largest observed `_windowSentBytes` during this limiter's
  /// lifetime.
  int _peakWindowUsage = 0;

  /// D34a: wall-clock of the most recent rejection, or null.
  int? _lastRejectionMs;

  MeshCoreSendRateLimiter({
    DateTime Function()? clock,
    int? capacityBytes,
    int? windowSeconds,
  }) : _clock = clock ?? DateTime.now,
       _capacity =
           capacityBytes ??
           MeshCoreSendRateLimiterConstants.budgetBytesPerWindow,
       _windowMs =
           (windowSeconds ?? MeshCoreSendRateLimiterConstants.windowSeconds) *
           1000,
       _remainingBytes =
           capacityBytes ??
           MeshCoreSendRateLimiterConstants.budgetBytesPerWindow,
       _lastRefillMs = (clock ?? DateTime.now).call().millisecondsSinceEpoch,
       _windowStartMs = (clock ?? DateTime.now).call().millisecondsSinceEpoch;

  /// Total budget capacity.
  int get capacity => _capacity;

  /// Window length in milliseconds.
  int get windowMs => _windowMs;

  /// Bytes remaining in the current window after an implicit refill.
  /// Cheap to call repeatedly; no side effects beyond the refill.
  int get remainingBytes {
    _refill();
    return _remainingBytes;
  }

  /// Fraction of budget used in the current window.
  /// 0.0 = full bucket, 1.0 = empty.
  double get usageFraction {
    _refill();
    return 1.0 - (_remainingBytes / _capacity);
  }

  /// Refill tokens proportionally to elapsed time since the last
  /// check. The bucket holds `_capacity` tokens that drain on `tryAcquire`
  /// and refill at a rate of `_capacity / _windowMs` per millisecond.
  void _refill() {
    final nowMs = _clock().millisecondsSinceEpoch;
    final elapsedMs = nowMs - _lastRefillMs;
    if (elapsedMs <= 0) return;

    final refillBytes = (_capacity * elapsedMs ~/ _windowMs);
    if (refillBytes > 0) {
      _remainingBytes = (_remainingBytes + refillBytes).clamp(0, _capacity);
      _lastRefillMs = nowMs;
    }
  }

  /// Try to acquire [bytes] tokens.
  ///
  /// On success: deducts the bytes and returns
  /// `allowed = true`, `remainingBytes = post-deduction`,
  /// `nextSendIn = Duration.zero`.
  ///
  /// On failure (would exceed capacity): does NOT deduct;
  /// returns `allowed = false`, `remainingBytes = pre-call`,
  /// `nextSendIn = how long until the bucket holds enough tokens to
  /// satisfy this request`. UI uses `nextSendIn` to show a
  /// retry-in-Ns countdown.
  ///
  /// Negative or zero [bytes] always succeed and deduct nothing.
  MeshCoreRateLimiterDecision tryAcquire(int bytes) {
    _refill();

    if (bytes <= 0) {
      return MeshCoreRateLimiterDecision(
        allowed: true,
        remainingBytes: _remainingBytes,
        nextSendIn: Duration.zero,
      );
    }

    if (bytes > _capacity) {
      // Request larger than the entire bucket can ever hold.
      // Reject permanently; UI must truncate the payload before retry.
      AppLogging.meshcore(
        'event=send.rate_limit.over_capacity '
        'requested=$bytes capacity=$_capacity',
        error: true,
      );
      return MeshCoreRateLimiterDecision(
        allowed: false,
        remainingBytes: _remainingBytes,
        // Bucket can never fulfil this; tell the UI "infinite wait"
        // so it surfaces a different message ("message too large").
        nextSendIn: Duration(milliseconds: _windowMs),
      );
    }

    if (bytes <= _remainingBytes) {
      _remainingBytes -= bytes;
      return MeshCoreRateLimiterDecision(
        allowed: true,
        remainingBytes: _remainingBytes,
        nextSendIn: Duration.zero,
      );
    }

    // Not enough tokens. Compute how long until enough refill.
    final shortfallBytes = bytes - _remainingBytes;
    final refillRateBytesPerMs = _capacity / _windowMs;
    final waitMs = (shortfallBytes / refillRateBytesPerMs).ceil();
    AppLogging.meshcore(
      'event=send.rate_limit.deferred '
      'requested=$bytes remaining=$_remainingBytes wait_ms=$waitMs',
    );
    return MeshCoreRateLimiterDecision(
      allowed: false,
      remainingBytes: _remainingBytes,
      nextSendIn: Duration(milliseconds: waitMs),
    );
  }

  /// Reset the bucket to full capacity, e.g. on disconnect/reconnect.
  /// Production code rarely calls this; useful in tests.
  void reset() {
    _remainingBytes = _capacity;
    _lastRefillMs = _clock().millisecondsSinceEpoch;
    _windowStartMs = _lastRefillMs;
    _windowSentBytes = 0;
    _windowRejectedBytes = 0;
    for (final k in MeshCoreSendKind.values) {
      _sendCounts[k] = 0;
      _rejectedCounts[k] = 0;
    }
    _recentClosedWindowBytes.clear();
    _peakWindowUsage = 0;
    _lastRejectionMs = null;
  }

  // ---------------------------------------------------------------------------
  // D34a: chat-traffic measurement layer
  // ---------------------------------------------------------------------------

  /// Rotate the active 60-s measurement window when wall-clock has
  /// crossed the next boundary. Closes the active window into the
  /// recent-windows ring, evicts past
  /// [MeshCoreSendRateLimiterConstants.recentWindowsKept], and resets
  /// the active per-kind accumulators. Idle windows close as zero-byte
  /// entries so the rolling average reflects real airtime.
  void _rotateWindowIfNeeded() {
    final nowMs = _clock().millisecondsSinceEpoch;
    var elapsed = nowMs - _windowStartMs;
    if (elapsed < _windowMs) return;

    while (elapsed >= _windowMs) {
      final closingBytes = _windowSentBytes;
      _recentClosedWindowBytes.add(closingBytes);
      while (_recentClosedWindowBytes.length >
          MeshCoreSendRateLimiterConstants.recentWindowsKept) {
        _recentClosedWindowBytes.removeAt(0);
      }
      if (closingBytes > _peakWindowUsage) {
        _peakWindowUsage = closingBytes;
      }
      AppLogging.meshcore(
        'event=text.send.window_reset peak_bytes=$_peakWindowUsage',
      );
      _windowSentBytes = 0;
      _windowRejectedBytes = 0;
      for (final k in MeshCoreSendKind.values) {
        _sendCounts[k] = 0;
        _rejectedCounts[k] = 0;
      }
      _windowStartMs += _windowMs;
      elapsed -= _windowMs;
    }
  }

  /// Record a send attempt against the measurement counters. Called by
  /// [MeshCoreSession.sendTextMessage] AFTER `tryAcquire` so the
  /// `allowed` flag faithfully reflects whether the bytes consumed the
  /// token bucket.
  ///
  /// Privacy: this method must only be passed counts and the kind. The
  /// caller must NEVER pass a payload, pubkey, or any envelope content
  /// — `bytes` is the post-envelope size already known to the limiter.
  void recordSend({
    required MeshCoreSendKind kind,
    required int bytes,
    required bool allowed,
  }) {
    _rotateWindowIfNeeded();
    if (bytes <= 0) return;
    if (allowed) {
      _windowSentBytes += bytes;
      _sendCounts[kind] = (_sendCounts[kind] ?? 0) + 1;
      if (_windowSentBytes > _peakWindowUsage) {
        _peakWindowUsage = _windowSentBytes;
      }
      AppLogging.meshcore(
        'event=text.send.recorded '
        'kind=${kind.logTag} '
        'bytes=$bytes '
        'win_used=$_windowSentBytes '
        'win_cap=$_capacity',
      );
    } else {
      _windowRejectedBytes += bytes;
      _rejectedCounts[kind] = (_rejectedCounts[kind] ?? 0) + 1;
      _lastRejectionMs = _clock().millisecondsSinceEpoch;
      // event=text.send.rate_limited is logged at the session
      // boundary (where the kind tag and remaining-bytes context
      // live). The counter side stays silent here to avoid double-
      // logging the same rejection event.
    }
  }

  /// Build an immutable [ChatTrafficSnapshot] from the current state.
  /// Lazily rotates closed windows so the snapshot's `windowStart`
  /// always reflects the active 60-s bucket.
  ChatTrafficSnapshot snapshot() {
    _rotateWindowIfNeeded();
    _refill();
    final avg = _recentClosedWindowBytes.isEmpty
        ? 0.0
        : _recentClosedWindowBytes.reduce((a, b) => a + b) /
              _recentClosedWindowBytes.length;
    return ChatTrafficSnapshot(
      currentWindowUsedBytes: _windowSentBytes,
      windowCapacityBytes: _capacity,
      remainingBytes: _remainingBytes,
      currentWindowSentBytes: _windowSentBytes,
      currentWindowRejectedBytes: _windowRejectedBytes,
      sendCountByKind: Map<MeshCoreSendKind, int>.unmodifiable(_sendCounts),
      rejectedCountByKind: Map<MeshCoreSendKind, int>.unmodifiable(
        _rejectedCounts,
      ),
      peakWindowUsage: _peakWindowUsage,
      rollingAverageBytes: avg,
      windowStart: DateTime.fromMillisecondsSinceEpoch(_windowStartMs),
      lastRejection: _lastRejectionMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(_lastRejectionMs!),
    );
  }
}
