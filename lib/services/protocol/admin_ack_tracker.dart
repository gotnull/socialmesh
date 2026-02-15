// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import 'admin_target.dart';

/// Result of an admin ACK wait.
///
/// Returned when the firmware sends a routing message (ACK or error) for a
/// tracked packet, or when the wait is cancelled/timed out.
sealed class AdminAckResult {
  const AdminAckResult._();

  /// The remote device acknowledged the admin packet successfully.
  const factory AdminAckResult.acked() = AdminAckSuccess;

  /// The remote device (or mesh routing) returned an error.
  const factory AdminAckResult.failed(RoutingError error) = AdminAckFailure;

  /// No response was received within the timeout.
  const factory AdminAckResult.timedOut() = AdminAckTimeout;

  /// The wait was cancelled (e.g. disconnect, dispose).
  const factory AdminAckResult.cancelled() = AdminAckCancelled;

  /// Whether the packet was acknowledged successfully.
  bool get isSuccess;
}

/// Successful ACK from the remote device.
final class AdminAckSuccess extends AdminAckResult {
  const AdminAckSuccess() : super._();

  @override
  bool get isSuccess => true;

  @override
  String toString() => 'AdminAckResult.acked()';
}

/// Error response from the mesh or remote device.
final class AdminAckFailure extends AdminAckResult {
  /// The routing error that caused the failure.
  final RoutingError error;

  const AdminAckFailure(this.error) : super._();

  @override
  bool get isSuccess => false;

  @override
  String toString() => 'AdminAckResult.failed(${error.name})';
}

/// No response received within the configured timeout.
final class AdminAckTimeout extends AdminAckResult {
  const AdminAckTimeout() : super._();

  @override
  bool get isSuccess => false;

  @override
  String toString() => 'AdminAckResult.timedOut()';
}

/// Wait was cancelled due to disconnect or dispose.
final class AdminAckCancelled extends AdminAckResult {
  const AdminAckCancelled() : super._();

  @override
  bool get isSuccess => false;

  @override
  String toString() => 'AdminAckResult.cancelled()';
}

/// Internal state for a pending remote admin ACK wait.
class _PendingAdminAck {
  final Completer<AdminAckResult> completer;
  final RemoteAdminTarget target;

  _PendingAdminAck({required this.completer, required this.target});
}

/// Tracks outgoing remote admin packets and correlates them with ACK
/// responses from the firmware's routing layer.
///
/// Local admin packets MUST NOT be registered here -- they are processed
/// synchronously by the firmware and never produce routing ACKs. The API
/// enforces this by requiring [RemoteAdminTarget] at registration time.
///
/// Usage:
/// ```dart
/// // Fire-and-forget (best-effort):
/// await transport.send(packet);
///
/// // Confirmed mode (await ACK):
/// tracker.registerRemoteAdmin(packetId, target);
/// await transport.send(packet);
/// final result = await tracker.awaitAck(
///   packetId,
///   timeout: const Duration(seconds: 30),
/// );
/// ```
class AdminAckTracker {
  /// Default timeout for awaiting a remote admin ACK.
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Pending ACK entries keyed by packet ID.
  final Map<int, _PendingAdminAck> _pending = {};

  /// Register a remote admin packet for ACK tracking.
  ///
  /// Only [RemoteAdminTarget] is accepted -- local admin packets never
  /// produce routing ACKs and must not be registered.
  ///
  /// Returns the [packetId] for chaining convenience.
  ///
  /// Throws [StateError] if a packet with the same ID is already pending
  /// (indicates a packet ID collision or double-registration).
  int registerRemoteAdmin(int packetId, RemoteAdminTarget target) {
    if (_pending.containsKey(packetId)) {
      throw StateError(
        'AdminAckTracker: packet $packetId is already pending. '
        'Did you register the same packet twice?',
      );
    }
    _pending[packetId] = _PendingAdminAck(
      completer: Completer<AdminAckResult>(),
      target: target,
    );
    AppLogging.protocol(
      'AdminAckTracker: registered packet $packetId -> '
      '${target.nodeNum.toRadixString(16)} for ACK tracking '
      '(${_pending.length} pending)',
    );
    return packetId;
  }

  /// Await acknowledgement for a previously registered packet.
  ///
  /// Returns [AdminAckResult.timedOut] if no response arrives within
  /// [timeout]. Callers should handle all four result variants.
  ///
  /// If [packetId] was never registered, returns [AdminAckResult.timedOut]
  /// immediately.
  Future<AdminAckResult> awaitAck(
    int packetId, {
    Duration timeout = defaultTimeout,
  }) async {
    final entry = _pending[packetId];
    if (entry == null) {
      AppLogging.protocol(
        'AdminAckTracker: awaitAck called for unregistered packet $packetId',
      );
      return const AdminAckResult.timedOut();
    }

    try {
      return await entry.completer.future.timeout(
        timeout,
        onTimeout: () {
          _pending.remove(packetId);
          AppLogging.protocol(
            'AdminAckTracker: packet $packetId timed out after '
            '${timeout.inSeconds}s (${_pending.length} still pending)',
          );
          return const AdminAckResult.timedOut();
        },
      );
    } catch (e) {
      _pending.remove(packetId);
      AppLogging.protocol(
        'AdminAckTracker: error awaiting packet $packetId: $e',
      );
      return const AdminAckResult.timedOut();
    }
  }

  /// Called by the protocol service when a routing message (ACK/error)
  /// arrives for a packet we may be tracking.
  ///
  /// Correlation is strict: the [packetId] must match a pending entry.
  /// If the [packetId] is not in our pending map, this is a no-op
  /// (the ACK is for a user message or a best-effort admin packet).
  void onDeliveryUpdate(MessageDeliveryUpdate update) {
    final entry = _pending.remove(update.packetId);
    if (entry == null) return;

    if (update.isSuccess) {
      AppLogging.protocol(
        'AdminAckTracker: packet ${update.packetId} acknowledged',
      );
      entry.completer.complete(const AdminAckResult.acked());
    } else {
      final error = update.error ?? RoutingError.noResponse;
      AppLogging.protocol(
        'AdminAckTracker: packet ${update.packetId} failed: ${error.name}',
      );
      entry.completer.complete(AdminAckResult.failed(error));
    }
  }

  /// Whether a packet is currently being tracked.
  bool isTracking(int packetId) => _pending.containsKey(packetId);

  /// Number of packets currently awaiting ACK.
  int get pendingCount => _pending.length;

  /// Cancel all pending ACK waits. Called on disconnect/dispose.
  ///
  /// All pending awaiters complete with [AdminAckResult.cancelled],
  /// which is semantically distinct from [AdminAckResult.timedOut] --
  /// cancelled means the connection was deliberately torn down, not
  /// that the remote device failed to respond.
  void cancelAll() {
    for (final entry in _pending.values) {
      if (!entry.completer.isCompleted) {
        entry.completer.complete(const AdminAckResult.cancelled());
      }
    }
    _pending.clear();
    AppLogging.protocol('AdminAckTracker: cancelled all pending ACK waits');
  }

  /// Remove a specific pending entry without completing it.
  /// Used when a send fails before the packet reaches the BLE stack.
  void unregister(int packetId) {
    final entry = _pending.remove(packetId);
    if (entry != null && !entry.completer.isCompleted) {
      entry.completer.complete(const AdminAckResult.cancelled());
    }
  }
}
