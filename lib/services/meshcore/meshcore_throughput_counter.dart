// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:collection';

/// Row 50.b: per-session byte counters with a rolling-window rate for
/// the active MeshCore transport. Held at the module-singleton layer
/// (one MeshCore link per process), incremented at the single
/// transport-adapter chokepoint so BLE / USB / TCP all flow through
/// the same counter without per-transport plumbing.
///
/// Pure-Dart: no platform plugins, no Riverpod, no Flutter. The clock
/// is injectable for deterministic tests.
class MeshCoreThroughputSnapshot {
  final int bytesTx;
  final int bytesRx;

  /// Bytes-per-second over the last [MeshCoreThroughputCounter.windowSeconds]
  /// based on a sliding sample buffer. Resets to zero when no samples
  /// land inside the window.
  final double txBytesPerSecond;
  final double rxBytesPerSecond;

  /// Monotonic uptime of the current session in whole seconds. Resets
  /// on every [MeshCoreThroughputCounter.reset] (typically on transport
  /// disconnect).
  final int sessionSeconds;

  const MeshCoreThroughputSnapshot({
    required this.bytesTx,
    required this.bytesRx,
    required this.txBytesPerSecond,
    required this.rxBytesPerSecond,
    required this.sessionSeconds,
  });

  static const MeshCoreThroughputSnapshot zero = MeshCoreThroughputSnapshot(
    bytesTx: 0,
    bytesRx: 0,
    txBytesPerSecond: 0,
    rxBytesPerSecond: 0,
    sessionSeconds: 0,
  );

  bool get hasActivity => bytesTx > 0 || bytesRx > 0;
}

class _Sample {
  final DateTime at;
  final int bytes;
  const _Sample(this.at, this.bytes);
}

class MeshCoreThroughputCounter {
  /// Sliding-rate window. 10s gives enough averaging to smooth bursts
  /// without lagging the user's intuition of "current" throughput.
  final int windowSeconds;
  final DateTime Function() _now;
  final Queue<_Sample> _txSamples = Queue<_Sample>();
  final Queue<_Sample> _rxSamples = Queue<_Sample>();
  int _bytesTx = 0;
  int _bytesRx = 0;
  DateTime? _sessionStart;

  MeshCoreThroughputCounter({
    this.windowSeconds = 10,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  int get bytesTx => _bytesTx;
  int get bytesRx => _bytesRx;
  bool get hasSession => _sessionStart != null;

  void recordTx(int bytes) {
    if (bytes <= 0) return;
    _bytesTx += bytes;
    final now = _now();
    _sessionStart ??= now;
    _txSamples.add(_Sample(now, bytes));
    _trim(_txSamples, now);
  }

  void recordRx(int bytes) {
    if (bytes <= 0) return;
    _bytesRx += bytes;
    final now = _now();
    _sessionStart ??= now;
    _rxSamples.add(_Sample(now, bytes));
    _trim(_rxSamples, now);
  }

  /// Reset all state - call on transport disconnect so the counters
  /// represent "since current connect", matching how the Transport
  /// screen labels the data.
  void reset() {
    _bytesTx = 0;
    _bytesRx = 0;
    _txSamples.clear();
    _rxSamples.clear();
    _sessionStart = null;
  }

  MeshCoreThroughputSnapshot snapshot() {
    final now = _now();
    _trim(_txSamples, now);
    _trim(_rxSamples, now);
    final txRate = _rateBytesPerSecond(_txSamples, now);
    final rxRate = _rateBytesPerSecond(_rxSamples, now);
    final start = _sessionStart;
    final seconds = start == null ? 0 : now.difference(start).inSeconds;
    return MeshCoreThroughputSnapshot(
      bytesTx: _bytesTx,
      bytesRx: _bytesRx,
      txBytesPerSecond: txRate,
      rxBytesPerSecond: rxRate,
      sessionSeconds: seconds,
    );
  }

  void _trim(Queue<_Sample> q, DateTime now) {
    final cutoff = now.subtract(Duration(seconds: windowSeconds));
    while (q.isNotEmpty && q.first.at.isBefore(cutoff)) {
      q.removeFirst();
    }
  }

  double _rateBytesPerSecond(Queue<_Sample> q, DateTime now) {
    if (q.isEmpty) return 0;
    final cutoff = now.subtract(Duration(seconds: windowSeconds));
    var total = 0;
    for (final s in q) {
      if (s.at.isAfter(cutoff) || s.at.isAtSameMomentAs(cutoff)) {
        total += s.bytes;
      }
    }
    return total / windowSeconds;
  }
}
