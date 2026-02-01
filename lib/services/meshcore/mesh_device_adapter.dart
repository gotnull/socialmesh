// SPDX-License-Identifier: GPL-3.0-or-later
import '../../models/mesh_device.dart';

/// Abstract adapter interface for mesh device protocol operations.
///
/// This interface defines the high-level operations that any mesh protocol
/// adapter must implement. It abstracts protocol-specific details and
/// provides a unified way to interact with mesh devices regardless of
/// the underlying protocol (Meshtastic, MeshCore, etc.).
///
/// The adapter sits on top of a transport layer and handles:
/// - Protocol identification
/// - Device info retrieval
/// - Basic communication (ping/pong)
abstract class MeshDeviceAdapter {
  /// The protocol type this adapter handles.
  MeshProtocolType get protocolType;

  /// Whether the adapter is currently connected and identified.
  bool get isReady;

  /// Current device info (null if not identified yet).
  MeshDeviceInfo? get deviceInfo;

  /// Identify the device and retrieve basic info.
  ///
  /// This performs any protocol-specific handshake needed to confirm
  /// the device is running the expected protocol and retrieves basic
  /// device information.
  ///
  /// Returns success with device info, or failure with an error type.
  /// If the device requires pairing/PIN, returns pairingRequired error.
  Future<MeshProtocolResult<MeshDeviceInfo>> identify();

  /// Send a ping and wait for response.
  ///
  /// This is used to verify bidirectional communication is working.
  /// Returns success with round-trip latency, or failure with error.
  Future<MeshProtocolResult<Duration>> ping();

  /// Disconnect from the device.
  Future<void> disconnect();

  /// Dispose resources.
  Future<void> dispose();
}

/// Factory for creating mesh device adapters.
///
/// This provides a way to create the appropriate adapter based on
/// detected protocol type.
abstract class MeshDeviceAdapterFactory {
  /// Create an adapter for the given protocol type.
  ///
  /// Returns null if the protocol type is not supported.
  MeshDeviceAdapter? createAdapter(MeshProtocolType protocolType);
}
