// SPDX-License-Identifier: GPL-3.0-or-later

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
  int _legacyPacketsReceived = 0;
  int _decodeNullCount = 0;
  int _dualSendCount = 0;

  /// Per-portnum decode failures.
  final Map<int, int> _decodeNullByPortnum = {};

  /// Record that a binary SM packet was received.
  void recordBinaryPacketReceived() => _binaryPacketsReceived++;

  /// Record that a legacy signal packet was received.
  void recordLegacyPacketReceived() => _legacyPacketsReceived++;

  /// Record that a decode returned null for the given portnum.
  void recordDecodeNull(int portnum) {
    _decodeNullCount++;
    _decodeNullByPortnum[portnum] = (_decodeNullByPortnum[portnum] ?? 0) + 1;
  }

  /// Record that a dual-send (binary + legacy) was performed.
  void recordDualSend() => _dualSendCount++;

  /// Total binary packets received.
  int get binaryPacketsReceived => _binaryPacketsReceived;

  /// Total legacy signal packets received.
  int get legacyPacketsReceived => _legacyPacketsReceived;

  /// Total decode failures.
  int get decodeNullCount => _decodeNullCount;

  /// Decode failures by portnum.
  Map<int, int> get decodeNullByPortnum =>
      Map.unmodifiable(_decodeNullByPortnum);

  /// Total dual-send operations.
  int get dualSendCount => _dualSendCount;

  /// Reset all counters.
  void reset() {
    _binaryPacketsReceived = 0;
    _legacyPacketsReceived = 0;
    _decodeNullCount = 0;
    _dualSendCount = 0;
    _decodeNullByPortnum.clear();
  }

  @override
  String toString() =>
      'SmMetrics(binary=$_binaryPacketsReceived, '
      'legacy=$_legacyPacketsReceived, '
      'decodeNull=$_decodeNullCount, '
      'dualSend=$_dualSendCount, '
      'nullByPort=$_decodeNullByPortnum)';
}
