// SPDX-License-Identifier: GPL-3.0-or-later

/// Utility helpers for routing decoded SM packets into the app's
/// existing domain pipelines.
///
/// These are pure functions with no side effects. The actual routing
/// (feeding into streams, updating stores) lives in the caller
/// (typically ProtocolService).
library;

import 'sm_constants.dart';
import 'sm_signal.dart';

/// Conversion helpers for SM packet routing.
abstract final class SmPacketRouter {
  /// Signal ID prefix for SM binary signal IDs.
  ///
  /// Legacy signals use UUID v4 strings (e.g., "a1b2c3d4-...").
  /// SM binary signals use "sm-" + 16-char hex (e.g., "sm-00a1b2c3d4e5f6a7").
  /// This prefix enables cross-format dedupe during dual-send.
  static const String signalIdPrefix = 'sm-';

  /// Convert an SM binary signal ID (uint64) to a string for storage.
  ///
  /// Uses zero-padded hex encoding with "sm-" prefix to distinguish
  /// from legacy UUID-format signal IDs. Handles negative Dart int
  /// values correctly (bit 63 set → unsigned interpretation).
  static String signalIdToString(int signalId) {
    // Split into two 32-bit halves for correct unsigned hex conversion.
    // Dart's toRadixString on negative ints produces "-..." which we avoid.
    final hi = (signalId >>> 32) & 0xFFFFFFFF;
    final lo = signalId & 0xFFFFFFFF;
    final hiHex = hi.toRadixString(16).padLeft(8, '0');
    final loHex = lo.toRadixString(16).padLeft(8, '0');
    return '$signalIdPrefix$hiHex$loHex';
  }

  /// Parse an SM signal ID string back to uint64.
  ///
  /// Returns null if the string is not an SM signal ID (e.g., legacy UUID).
  static int? signalIdFromString(String id) {
    if (!id.startsWith(signalIdPrefix)) return null;
    final hex = id.substring(signalIdPrefix.length);
    if (hex.length != 16) return null;
    final hi = int.tryParse(hex.substring(0, 8), radix: 16);
    final lo = int.tryParse(hex.substring(8, 16), radix: 16);
    if (hi == null || lo == null) return null;
    return (hi << 32) | lo;
  }

  /// Whether a signal ID string is from the SM binary protocol.
  static bool isSmSignalId(String id) => id.startsWith(signalIdPrefix);

  /// Convert [SmSignalTtl] to minutes (int).
  static int ttlToMinutes(SmSignalTtl ttl) {
    return smSignalTtlToDuration(ttl).inMinutes;
  }

  /// Find the closest [SmSignalTtl] for a given duration in minutes.
  ///
  /// Used when converting legacy TTL (arbitrary int minutes) to the
  /// binary enum. Picks the smallest TTL that is >= the requested value.
  static SmSignalTtl ttlFromMinutes(int minutes) {
    if (minutes <= 15) return SmSignalTtl.minutes15;
    if (minutes <= 30) return SmSignalTtl.minutes30;
    if (minutes <= 60) return SmSignalTtl.hour1;
    if (minutes <= 360) return SmSignalTtl.hours6;
    return SmSignalTtl.hours24;
  }
}

/// Per-node rate limiter for SM_IDENTITY requests.
///
/// Ensures we don't flood the mesh with identity requests to the same
/// node. Uses an injectable clock for deterministic testing.
class SmIdentityRateLimiter {
  final Map<int, DateTime> _lastRequest = {};
  final DateTime Function() _clock;

  SmIdentityRateLimiter({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Whether enough time has passed to send another identity request
  /// to [nodeNum].
  bool canRequest(int nodeNum) {
    final last = _lastRequest[nodeNum];
    if (last == null) return true;
    return _clock().difference(last) >= SmRateLimit.identityRequestInterval;
  }

  /// Record that an identity request was sent to [nodeNum].
  void recordRequest(int nodeNum) {
    _lastRequest[nodeNum] = _clock();
  }

  /// Remaining cooldown before another request to [nodeNum] is allowed.
  Duration cooldownRemaining(int nodeNum) {
    final last = _lastRequest[nodeNum];
    if (last == null) return Duration.zero;
    final elapsed = _clock().difference(last);
    final remaining = SmRateLimit.identityRequestInterval - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Reset all per-node rate limit state.
  void reset() => _lastRequest.clear();
}
