// SPDX-License-Identifier: GPL-3.0-or-later
import '../../models/mesh_device.dart';
import '../protocol/protocol_service.dart';
import 'mesh_device_adapter.dart';

/// Meshtastic protocol adapter.
///
/// This is a thin shim that wraps the existing Meshtastic protocol service
/// to conform to the MeshDeviceAdapter interface. It does NOT reimplement
/// any Meshtastic logic - it simply delegates to the existing code.
///
/// The adapter allows the connection coordinator to treat Meshtastic devices
/// uniformly with MeshCore devices while maintaining the existing codebase.
class MeshtasticAdapter implements MeshDeviceAdapter {
  final ProtocolService _protocolService;
  MeshDeviceInfo? _deviceInfo;

  MeshtasticAdapter(this._protocolService);

  @override
  MeshProtocolType get protocolType => MeshProtocolType.meshtastic;

  @override
  bool get isReady => _protocolService.myNodeNum != null;

  @override
  MeshDeviceInfo? get deviceInfo => _deviceInfo;

  @override
  Future<MeshProtocolResult<MeshDeviceInfo>> identify() async {
    // For Meshtastic, identification happens during the normal protocol
    // startup. We wait for myNodeNum to be available.
    try {
      // Check if already identified
      if (_protocolService.myNodeNum != null) {
        _updateDeviceInfo();
        return MeshProtocolResult.success(_deviceInfo!);
      }

      // Wait for protocol to identify (with timeout)
      // Note: The actual protocol startup is handled by the existing code
      // in scanner_screen.dart and connection_providers.dart.
      // This adapter just provides a unified interface.

      // If we reach here, the protocol service should already be started
      // by the existing connection flow. We just extract the info.
      await Future.delayed(const Duration(milliseconds: 500));

      if (_protocolService.myNodeNum != null) {
        _updateDeviceInfo();
        return MeshProtocolResult.success(_deviceInfo!);
      }

      return const MeshProtocolResult.failure(
        MeshProtocolError.identificationFailed,
        'Meshtastic protocol not yet configured',
      );
    } catch (e) {
      return MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        e.toString(),
      );
    }
  }

  void _updateDeviceInfo() {
    final myNodeNum = _protocolService.myNodeNum;
    if (myNodeNum == null) {
      _deviceInfo = null;
      return;
    }

    // Get node info from the protocol service's nodes map
    final myNode = _protocolService.nodes[myNodeNum];
    final displayName =
        myNode?.longName ?? myNode?.shortName ?? 'Meshtastic Device';

    _deviceInfo = MeshDeviceInfo(
      protocolType: MeshProtocolType.meshtastic,
      displayName: displayName,
      nodeId: myNodeNum.toRadixString(16).toUpperCase(),
      firmwareVersion: myNode?.firmwareVersion,
      hardwareModel: myNode?.hardwareModel,
    );
  }

  @override
  Future<MeshProtocolResult<Duration>> ping() async {
    // Meshtastic doesn't have a direct ping command in the same way.
    // We could potentially use a traceroute or echo, but for Milestone 1
    // we return success if connected (proving BLE comms work).

    if (!isReady) {
      return const MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        'Not connected',
      );
    }

    // For Meshtastic, simply being connected and having config proves
    // bidirectional communication. Return a nominal latency.
    return const MeshProtocolResult.success(Duration(milliseconds: 50));
  }

  @override
  Future<void> disconnect() async {
    // Disconnect is handled by the existing transport/connection code.
    // The adapter doesn't own the protocol service lifecycle.
    _deviceInfo = null;
  }

  @override
  Future<void> dispose() async {
    _deviceInfo = null;
    // Don't dispose the protocol service - it's owned by providers
  }
}
