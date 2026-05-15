// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A2: matches inbound `PUSH_CODE_SEND_CONFIRMED 0x82` frames to
// outstanding sender-side waiters by ack-hash. Used by the auto-route
// orchestrator to decide whether an attempt was peer-delivered or
// timed out.
//
// Wire layout (after stripping the 0x82 opcode byte from the frame):
//   payload[0..4] = ack_hash (u32 LE)
//   payload[4..8] = trip_time_ms (u32 LE)
//
// Note the sync `RESP_CODE_SENT 0x06` ack has a different layout
// (leading is_flood byte). The router only consumes 0x82; the sync
// ack is handled by `MeshCoreSession.sendAndWait`.

import 'dart:async';
import 'dart:typed_data';

import '../../../core/meshcore_constants.dart';
import '../protocol/meshcore_frame.dart';

/// D48-A2: outcome of a single delivery wait.
class MeshCoreSendConfirmationOutcome {
  /// `true` if a matching 0x82 arrived within the timeout.
  final bool delivered;

  /// Round-trip time as reported by the firmware. `null` on timeout.
  final Duration? tripTime;

  const MeshCoreSendConfirmationOutcome({
    required this.delivered,
    this.tripTime,
  });

  const MeshCoreSendConfirmationOutcome.timedOut()
    : delivered = false,
      tripTime = null;
}

/// D48-A2: routes 0x82 frames to per-ack-hash waiters.
///
/// One instance is owned by `meshCoreSendConfirmationRouterProvider`
/// for the lifetime of an active MeshCore session. The orchestrator
/// (or any future feature, e.g. read receipts) calls
/// [waitForDelivery] before issuing the send wire-frame and awaits
/// the returned future.
class MeshCoreSendConfirmationRouter {
  MeshCoreSendConfirmationRouter({required Stream<MeshCoreFrame> frameStream}) {
    _sub = frameStream.listen(_onFrame);
  }

  late final StreamSubscription<MeshCoreFrame> _sub;
  final Map<int, _Waiter> _waiters = <int, _Waiter>{};
  bool _disposed = false;

  /// Register a waiter for [ackHash] and return a future that
  /// completes with:
  ///   - `delivered: true` if a matching 0x82 push arrives within
  ///     [timeout],
  ///   - `delivered: false` on timeout.
  ///
  /// Re-registering the same hash while a prior waiter is pending
  /// completes the prior one as `delivered: false` (the orchestrator
  /// loop guarantees per-hash uniqueness; the override is defensive).
  Future<MeshCoreSendConfirmationOutcome> waitForDelivery({
    required int ackHash,
    required Duration timeout,
  }) {
    final masked = ackHash & 0xFFFFFFFF;
    final existing = _waiters.remove(masked);
    if (existing != null && !existing.completer.isCompleted) {
      existing.timer?.cancel();
      existing.completer.complete(
        const MeshCoreSendConfirmationOutcome.timedOut(),
      );
    }
    if (_disposed) {
      return Future<MeshCoreSendConfirmationOutcome>.value(
        const MeshCoreSendConfirmationOutcome.timedOut(),
      );
    }
    final completer = Completer<MeshCoreSendConfirmationOutcome>();
    Timer? timer;
    timer = Timer(timeout, () {
      final w = _waiters.remove(masked);
      if (w != null && !w.completer.isCompleted) {
        w.completer.complete(const MeshCoreSendConfirmationOutcome.timedOut());
      }
    });
    _waiters[masked] = _Waiter(completer: completer, timer: timer);
    return completer.future;
  }

  void _onFrame(MeshCoreFrame frame) {
    if (frame.command != MeshCorePushCodes.sendConfirmed) return;
    if (frame.payload.length < 8) return;
    final bd = ByteData.sublistView(frame.payload);
    final ackHash = bd.getUint32(0, Endian.little);
    final tripMs = bd.getUint32(4, Endian.little);
    final waiter = _waiters.remove(ackHash);
    if (waiter == null) return;
    waiter.timer?.cancel();
    if (waiter.completer.isCompleted) return;
    waiter.completer.complete(
      MeshCoreSendConfirmationOutcome(
        delivered: true,
        tripTime: Duration(milliseconds: tripMs),
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub.cancel();
    for (final w in _waiters.values) {
      w.timer?.cancel();
      if (!w.completer.isCompleted) {
        w.completer.complete(const MeshCoreSendConfirmationOutcome.timedOut());
      }
    }
    _waiters.clear();
  }
}

class _Waiter {
  final Completer<MeshCoreSendConfirmationOutcome> completer;
  Timer? timer;
  _Waiter({required this.completer, required this.timer});
}
