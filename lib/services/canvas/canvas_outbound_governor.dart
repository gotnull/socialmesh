// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas outbound governor — sliding-window 250 B / 60 s budget
// shared across every canvas the local device drives.
//
// Spec: docs/canvas/CANVAS_V0_1.md §2 + invariant I2 (anti-starvation).
// This governor is strictly subordinate to the SIP rate limiter — it
// does not know about SIP, ProtocolService, transport, or any wire
// framing. Its sole job is to keep canvas traffic from monopolising
// the 1024 B / 60 s SIP budget by capping canvas's slice at 250 B.
//
// Accounting unit: **canvas payload bytes** (the buffers that come out
// of CanvasCodec). SIP frame wrapping overhead is the SIP limiter's
// concern. Documenting the unit here keeps the governor decoupled
// from wire framing and lets tests assert byte counts without knowing
// MRRP / SIP header sizes.
library;

import 'dart:collection';

import '../../core/logging.dart';

/// Sliding-window rate limiter for canvas-only outbound traffic.
///
/// Each accepted send appends a `(timestampMs, bytes)` entry to an
/// internal queue. On every check the queue is pruned of entries
/// older than the [window]; the remaining sum is compared against
/// [budgetBytes]. Time is provided via an injected `nowMs` callback so
/// tests can advance the clock deterministically.
class CanvasOutboundGovernor {
  /// Total canvas budget per window.
  static const int budgetBytes = 250;

  /// Sliding window length.
  static const Duration window = Duration(seconds: 60);

  final int Function() _nowMs;
  final Queue<_BudgetEvent> _events = Queue<_BudgetEvent>();

  CanvasOutboundGovernor({int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Drop entries that fell out of the trailing window.
  void _prune() {
    final cutoff = _nowMs() - window.inMilliseconds;
    while (_events.isNotEmpty && _events.first.atMs <= cutoff) {
      _events.removeFirst();
    }
  }

  int _usedBytes() {
    var total = 0;
    for (final event in _events) {
      total += event.bytes;
    }
    return total;
  }

  /// Reject inputs that cannot reach a valid `recordSend` regardless of
  /// state. Used as a defensive guard on every external entry point so
  /// callers cannot accidentally poison the queue with zero/negative or
  /// over-budget entries.
  static bool _isValidByteCount(int bytes) => bytes > 0 && bytes <= budgetBytes;

  /// Total budget bytes per window. Exposed for diagnostics.
  int get budgetBytesPerWindow => budgetBytes;

  /// Bytes still available in the current window. Never negative.
  int get remainingBytes {
    _prune();
    final remaining = budgetBytes - _usedBytes();
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether the current window has room for [bytes] more.
  ///
  /// Returns false for [bytes] <= 0 (caller programming error) and for
  /// [bytes] > [budgetBytes] (can never fit even on an empty window).
  /// Non-mutating: safe to call repeatedly during pre-flight checks.
  bool canSend(int bytes) {
    if (!_isValidByteCount(bytes)) return false;
    _prune();
    return _usedBytes() + bytes <= budgetBytes;
  }

  /// Record that [bytes] just went on the air. Caller MUST have first
  /// confirmed [canSend] returned true. Invalid counts are silently
  /// dropped (with a log) to prevent poisoning the window.
  void recordSend(int bytes) {
    if (!_isValidByteCount(bytes)) {
      AppLogging.meshCanvas(
        'governor recordSend ignored: invalid bytes=$bytes',
      );
      return;
    }
    _prune();
    _events.add(_BudgetEvent(atMs: _nowMs(), bytes: bytes));
    AppLogging.meshCanvas(
      'governor +${bytes}B '
      '(used=${_usedBytes()}/$budgetBytes, '
      'window=${window.inSeconds}s)',
    );
  }

  /// Atomic check + record. Returns true and consumes budget on
  /// success; returns false and leaves the window unchanged on denial.
  ///
  /// Use this when the caller can guarantee the bytes will actually
  /// hit the wire after the call. The coordinator's normal path uses
  /// the explicit [canSend] / [recordSend] pair because it must wait
  /// for the SIP gate before committing the spend.
  bool tryConsume(int bytes) {
    if (!canSend(bytes)) return false;
    recordSend(bytes);
    return true;
  }

  /// Number of accounted events currently in the window. Diagnostic
  /// hook for tests; not part of the production contract.
  int get debugEventCount {
    _prune();
    return _events.length;
  }
}

class _BudgetEvent {
  final int atMs;
  final int bytes;
  const _BudgetEvent({required this.atMs, required this.bytes});
}
