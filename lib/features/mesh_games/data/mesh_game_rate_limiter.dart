// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// In-memory per-peer rate limiter for mesh-game commands.
///
/// Enforces the "≤ 1 game command per 2 s per sender" rule from the
/// spec § 6.1 step 3. State is not persisted — a restart relaxes the
/// limiter, which is intentional and safe.
library;

/// Per-peer rate limiter with a fixed minimum interval between commands.
class MeshGameRateLimiter {
  final Duration minInterval;
  final DateTime Function() _clock;
  final Map<int, DateTime> _lastAccepted = {};

  MeshGameRateLimiter({
    this.minInterval = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Returns true if a command from [senderNodeId] is allowed right
  /// now. Side-effect: on success, records the acceptance.
  bool tryAcquire(int senderNodeId) {
    final now = _clock();
    final last = _lastAccepted[senderNodeId];
    if (last != null && now.difference(last) < minInterval) {
      return false;
    }
    _lastAccepted[senderNodeId] = now;
    return true;
  }

  /// Reset limiter state (for tests).
  void reset() => _lastAccepted.clear();
}
