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
       _lastRefillMs = (clock ?? DateTime.now).call().millisecondsSinceEpoch;

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
  }
}
