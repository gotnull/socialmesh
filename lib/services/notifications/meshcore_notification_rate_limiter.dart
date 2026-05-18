// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Row 11.b: per-category one-fire-per-window rate limiter for MeshCore
/// notification surfaces (adverts today; batch summary and future
/// signal types plug into the same primitive without API churn).
///
/// Distinct from `MeshCoreSendRateLimiter` (token-bucket over wire
/// airtime). This limiter is simpler: track the last fire timestamp
/// per category, reject if the next call is inside the cooldown.
///
/// Callers can override the cooldown per category so a high-frequency
/// signal (e.g. presence pings) can use a tighter window than a
/// low-frequency one (advert discovery).
class MeshCoreNotificationRateLimiter {
  final DateTime Function() _now;
  final Duration _defaultCooldown;
  final Map<String, DateTime> _lastFireAt = <String, DateTime>{};

  MeshCoreNotificationRateLimiter({
    DateTime Function()? clock,
    Duration defaultCooldown = const Duration(minutes: 5),
  }) : _now = clock ?? DateTime.now,
       _defaultCooldown = defaultCooldown;

  /// Attempt to fire a notification on the named [category].
  ///
  /// Returns `true` and stamps the clock when the cooldown has elapsed
  /// (or this is the first call for this category). Returns `false`
  /// when the previous fire is too recent. Pass [cooldown] to override
  /// the default window for this call.
  bool tryFire(String category, {Duration? cooldown}) {
    final now = _now();
    final last = _lastFireAt[category];
    final window = cooldown ?? _defaultCooldown;
    if (last != null && now.difference(last) < window) {
      return false;
    }
    _lastFireAt[category] = now;
    return true;
  }

  /// Forget the last-fire stamp for [category]. Mostly useful in
  /// tests; production code rarely needs to reset.
  void reset(String category) {
    _lastFireAt.remove(category);
  }

  /// Clear all categories. Test-only convenience.
  void clearAll() {
    _lastFireAt.clear();
  }
}
