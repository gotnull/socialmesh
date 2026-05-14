// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Debug-only metrics for SM binary protocol observability.
///
/// These counters are lightweight and only meaningful during development
/// and debugging. They are NOT persisted and reset on app restart.
///
/// Guard logging behind `assert(() { ... ; return true; }())` or
/// `kDebugMode` checks so release builds tree-shake the overhead.
library;

/// Lightweight metric counters for SM binary protocol.
///
/// All fields are simple ints with zero overhead when not read.
class SmMetrics {
  int _binaryPacketsReceived = 0;
  int _decodeNullCount = 0;

  /// Per-portnum decode failures.
  final Map<int, int> _decodeNullByPortnum = {};

  /// Record that a binary SM packet was received.
  void recordBinaryPacketReceived() => _binaryPacketsReceived++;

  /// Record that a decode returned null for the given portnum.
  void recordDecodeNull(int portnum) {
    _decodeNullCount++;
    _decodeNullByPortnum[portnum] = (_decodeNullByPortnum[portnum] ?? 0) + 1;
  }

  /// Total binary packets received.
  int get binaryPacketsReceived => _binaryPacketsReceived;

  /// Total decode failures.
  int get decodeNullCount => _decodeNullCount;

  /// Decode failures by portnum.
  Map<int, int> get decodeNullByPortnum =>
      Map.unmodifiable(_decodeNullByPortnum);

  /// Reset all counters.
  void reset() {
    _binaryPacketsReceived = 0;
    _decodeNullCount = 0;
    _decodeNullByPortnum.clear();
  }

  @override
  String toString() =>
      'SmMetrics(binary=$_binaryPacketsReceived, '
      'decodeNull=$_decodeNullCount, ' // lint-allow: hardcoded-string
      'nullByPort=$_decodeNullByPortnum)'; // lint-allow: hardcoded-string
}
