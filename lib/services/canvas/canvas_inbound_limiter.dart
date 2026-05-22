// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Per-sender sliding-window inbound limiter for canvas.v1 frames.
//
// Lives ONLY inside `MrrpServiceCanvas`. The global MRRP per-sender cap
// (`MrrpConstants.mrrpMaxInboundRequestsPerSenderPer60s`) is intentionally
// not changed — the global default stays conservative for every other
// service. The canvas decoder-side cap is service-private per
// CANVAS_V0_1.md §2.
//
// Keyed by Meshtastic `senderNodeId` because that field is set by the
// transport layer (radio-side metadata) and is harder to spoof than
// the `author_id` byte inside the canvas payload, which the sender
// controls. Picking the transport-side identity also lets us throttle
// abusive senders even when they rotate author_ids.
library;

import 'dart:collection';

/// Sliding-window per-sender counter. One instance per service handler.
class CanvasInboundLimiter {
  /// Default canvas-specific cap. CANVAS_V0_1.md §2 / plan §6.
  static const int defaultCapPerSenderPer60s = 12;

  /// Default sliding-window length. Matches the global SIP / MRRP
  /// budget window for consistency.
  static const Duration defaultWindow = Duration(seconds: 60);

  final int capPerSender;
  final Duration window;
  final int Function() _nowMs;

  /// Queue of recent admission timestamps per sender. Pruned lazily on
  /// every `allow` call.
  final Map<int, Queue<int>> _bySender = <int, Queue<int>>{};

  CanvasInboundLimiter({
    this.capPerSender = defaultCapPerSenderPer60s,
    this.window = defaultWindow,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Returns true if the [senderNodeId] is under the cap; records the
  /// timestamp on success. Returns false (and does NOT record) when the
  /// sender has already used [capPerSender] admissions inside the
  /// current sliding window.
  bool allow(int senderNodeId) {
    final now = _nowMs();
    final cutoff = now - window.inMilliseconds;
    final queue = _bySender.putIfAbsent(senderNodeId, () => Queue<int>());
    while (queue.isNotEmpty && queue.first <= cutoff) {
      queue.removeFirst();
    }
    if (queue.length >= capPerSender) return false;
    queue.add(now);
    return true;
  }

  /// Test seam — current count of admissions inside the window for
  /// [senderNodeId]. Returns 0 for senders we have never seen.
  int debugAdmissionsFor(int senderNodeId) {
    final queue = _bySender[senderNodeId];
    if (queue == null) return 0;
    final now = _nowMs();
    final cutoff = now - window.inMilliseconds;
    var count = 0;
    for (final t in queue) {
      if (t > cutoff) count++;
    }
    return count;
  }

  /// Test seam — number of senders currently tracked.
  int get debugTrackedSenders => _bySender.length;
}
