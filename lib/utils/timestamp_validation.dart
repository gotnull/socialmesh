// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Shared validation for node timestamps (e.g. lastHeard) before display.
///
/// Rejects timestamps that are clearly invalid — epoch zero, pre-2020,
/// or absurdly far in the future — so the UI can show a safe fallback
/// instead of a misleading date.
///
/// Constants mirror ProtocolService._minPlausibleEpoch / _maxFutureSlack.
abstract final class TimestampValidation {
  /// 2020-01-01 00:00:00 UTC — timestamps before this are treated as invalid.
  static const int minPlausibleEpochSeconds = 1577836800;

  /// Maximum allowed future skew: 24 hours (86 400 seconds).
  static const int maxFutureSkewSeconds = 86400;

  /// Whether [dateTime] falls within the plausible range.
  ///
  /// Valid when epoch seconds > 0, >= [minPlausibleEpochSeconds], and
  /// <= [referenceTime] + [maxFutureSkewSeconds].
  ///
  /// [referenceTime] defaults to [DateTime.now] when omitted.
  static bool isPlausible(DateTime? dateTime, {DateTime? referenceTime}) {
    if (dateTime == null) return false;
    final epochSeconds = dateTime.millisecondsSinceEpoch ~/ 1000;
    if (epochSeconds <= 0) return false;
    if (epochSeconds < minPlausibleEpochSeconds) return false;
    final nowSeconds =
        (referenceTime ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    if (epochSeconds > nowSeconds + maxFutureSkewSeconds) return false;
    return true;
  }

  /// Returns [dateTime] unchanged when plausible, or `null` otherwise.
  ///
  /// Convenience wrapper around [isPlausible] for use at display boundaries
  /// where a nullable DateTime triggers existing "Never" / "Unknown" fallbacks.
  static DateTime? validated(DateTime? dateTime, {DateTime? referenceTime}) {
    return isPlausible(dateTime, referenceTime: referenceTime)
        ? dateTime
        : null;
  }

  /// Whether a raw epoch-seconds value is plausible.
  ///
  /// Useful at the protocol ingestion layer where the timestamp has not yet
  /// been converted to a [DateTime].
  static bool isPlausibleEpochSeconds(
    int epochSeconds, {
    DateTime? referenceTime,
  }) {
    if (epochSeconds <= 0) return false;
    if (epochSeconds < minPlausibleEpochSeconds) return false;
    final nowSeconds =
        (referenceTime ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    if (epochSeconds > nowSeconds + maxFutureSkewSeconds) return false;
    return true;
  }
}
