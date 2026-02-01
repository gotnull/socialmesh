// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import '../../core/transport.dart';

/// Abstract transport interface for mesh protocol communication.
///
/// This interface abstracts the underlying transport layer (BLE, USB, etc.)
/// and provides a protocol-agnostic way to send and receive bytes.
/// Different mesh protocols (Meshtastic, MeshCore) can implement their
/// own transports that conform to this interface.
abstract class MeshTransport {
  /// Get the underlying transport type (BLE, USB).
  TransportType get transportType;

  /// Current connection state.
  DeviceConnectionState get connectionState;

  /// Stream of connection state changes.
  Stream<DeviceConnectionState> get connectionStateStream;

  /// Stream of received data chunks.
  ///
  /// Each chunk may contain partial or multiple protocol frames.
  /// The consumer is responsible for framing/deframing.
  Stream<List<int>> get dataStream;

  /// Whether currently connected.
  bool get isConnected => connectionState == DeviceConnectionState.connected;

  /// Connect to the device.
  Future<void> connect(DeviceInfo device);

  /// Disconnect from the device.
  Future<void> disconnect();

  /// Send raw bytes to the device.
  ///
  /// The implementation handles any transport-specific framing if needed.
  Future<void> sendBytes(List<int> data);

  /// Clean up resources.
  Future<void> dispose();
}

/// Extension to provide convenience methods on MeshTransport.
extension MeshTransportExtension on MeshTransport {
  /// Wait for a specific connection state with timeout.
  Future<bool> waitForState(
    DeviceConnectionState targetState, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (connectionState == targetState) return true;

    try {
      await connectionStateStream
          .firstWhere((s) => s == targetState)
          .timeout(
            timeout,
            onTimeout: () =>
                throw TimeoutException('Timeout waiting for $targetState'),
          );
      return true;
    } catch (_) {
      return false;
    }
  }
}
