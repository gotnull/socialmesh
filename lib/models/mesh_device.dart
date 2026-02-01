// SPDX-License-Identifier: GPL-3.0-or-later

// Protocol-agnostic mesh device models.
//
// These models provide a unified interface for different mesh protocols
// (Meshtastic, MeshCore, etc.) without exposing protocol-specific details
// to the UI layer.

/// Supported mesh protocol types.
enum MeshProtocolType {
  /// Meshtastic protocol (protobufs over BLE/Serial)
  meshtastic,

  /// MeshCore protocol
  meshcore,

  /// Unknown protocol (detection in progress)
  unknown,
}

extension MeshProtocolTypeExtension on MeshProtocolType {
  /// Human-readable display name for the protocol
  String get displayName {
    switch (this) {
      case MeshProtocolType.meshtastic:
        return 'Meshtastic';
      case MeshProtocolType.meshcore:
        return 'MeshCore';
      case MeshProtocolType.unknown:
        return 'Unknown';
    }
  }
}

/// Protocol-agnostic device information.
///
/// This model represents basic device identity information that is common
/// across all supported mesh protocols. UI components should use this
/// instead of protocol-specific models.
class MeshDeviceInfo {
  /// The mesh protocol this device uses
  final MeshProtocolType protocolType;

  /// Human-readable device name for display
  final String displayName;

  /// Protocol-specific node identifier (may be null during initial connection)
  final String? nodeId;

  /// Firmware/protocol version string
  final String? firmwareVersion;

  /// Hardware model or variant
  final String? hardwareModel;

  /// Battery percentage (0-100), null if unknown
  final int? batteryPercentage;

  /// Battery voltage in millivolts, null if unknown
  final int? batteryVoltageMillivolts;

  const MeshDeviceInfo({
    required this.protocolType,
    required this.displayName,
    this.nodeId,
    this.firmwareVersion,
    this.hardwareModel,
    this.batteryPercentage,
    this.batteryVoltageMillivolts,
  });

  MeshDeviceInfo copyWith({
    MeshProtocolType? protocolType,
    String? displayName,
    String? nodeId,
    String? firmwareVersion,
    String? hardwareModel,
    int? batteryPercentage,
    int? batteryVoltageMillivolts,
  }) {
    return MeshDeviceInfo(
      protocolType: protocolType ?? this.protocolType,
      displayName: displayName ?? this.displayName,
      nodeId: nodeId ?? this.nodeId,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareModel: hardwareModel ?? this.hardwareModel,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      batteryVoltageMillivolts:
          batteryVoltageMillivolts ?? this.batteryVoltageMillivolts,
    );
  }

  @override
  String toString() =>
      'MeshDeviceInfo($protocolType, $displayName, node: $nodeId, fw: $firmwareVersion)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshDeviceInfo &&
          runtimeType == other.runtimeType &&
          protocolType == other.protocolType &&
          displayName == other.displayName &&
          nodeId == other.nodeId &&
          firmwareVersion == other.firmwareVersion &&
          hardwareModel == other.hardwareModel &&
          batteryPercentage == other.batteryPercentage &&
          batteryVoltageMillivolts == other.batteryVoltageMillivolts;

  @override
  int get hashCode =>
      protocolType.hashCode ^
      displayName.hashCode ^
      nodeId.hashCode ^
      firmwareVersion.hashCode ^
      hardwareModel.hashCode ^
      batteryPercentage.hashCode ^
      batteryVoltageMillivolts.hashCode;
}

/// Protocol-agnostic connection state for mesh devices.
///
/// Provides a unified view of connection state regardless of underlying
/// transport or protocol.
enum MeshConnectionState {
  /// Not connected to any device
  disconnected,

  /// Actively scanning for devices
  scanning,

  /// Transport connection in progress
  connecting,

  /// Connected, protocol identification in progress
  identifying,

  /// Fully connected and protocol identified
  connected,

  /// Disconnection in progress
  disconnecting,

  /// Connection error occurred
  error,
}

extension MeshConnectionStateExtension on MeshConnectionState {
  /// Whether this state represents an active connection
  bool get isConnected => this == MeshConnectionState.connected;

  /// Whether a connection attempt is in progress
  bool get isConnecting =>
      this == MeshConnectionState.connecting ||
      this == MeshConnectionState.identifying;

  /// Human-readable description of the state
  String get description {
    switch (this) {
      case MeshConnectionState.disconnected:
        return 'Disconnected';
      case MeshConnectionState.scanning:
        return 'Scanning...';
      case MeshConnectionState.connecting:
        return 'Connecting...';
      case MeshConnectionState.identifying:
        return 'Identifying protocol...';
      case MeshConnectionState.connected:
        return 'Connected';
      case MeshConnectionState.disconnecting:
        return 'Disconnecting...';
      case MeshConnectionState.error:
        return 'Error';
    }
  }
}

/// Error types specific to mesh protocol operations.
enum MeshProtocolError {
  /// Device requires PIN/pairing that isn't completed
  pairingRequired,

  /// Connection timeout
  timeout,

  /// Protocol identification failed
  identificationFailed,

  /// Communication error during operation
  communicationError,

  /// Device rejected the request
  requestRejected,

  /// Unsupported protocol version
  unsupportedVersion,

  /// Device is missing required characteristics/services
  unsupportedDevice,
}

/// Extension providing user-friendly error messages for protocol errors.
extension MeshProtocolErrorMessages on MeshProtocolError {
  /// Returns a user-friendly message for this error.
  String get userMessage {
    switch (this) {
      case MeshProtocolError.pairingRequired:
        return 'Pairing required. The default PIN may be shown on the device '
            'display, or try 123456.';
      case MeshProtocolError.timeout:
        return 'Connection timed out. Make sure the device is powered on and '
            'nearby.';
      case MeshProtocolError.identificationFailed:
        return 'Failed to identify the device. It may be running incompatible '
            'firmware.';
      case MeshProtocolError.communicationError:
        return 'Communication error. Try moving closer to the device.';
      case MeshProtocolError.requestRejected:
        return 'The device rejected the request.';
      case MeshProtocolError.unsupportedVersion:
        return 'The device firmware version is not supported.';
      case MeshProtocolError.unsupportedDevice:
        return 'This device is missing required BLE characteristics. '
            'It may not be compatible.';
    }
  }

  /// Returns a short title for this error.
  String get title {
    switch (this) {
      case MeshProtocolError.pairingRequired:
        return 'Pairing Required';
      case MeshProtocolError.timeout:
        return 'Timeout';
      case MeshProtocolError.identificationFailed:
        return 'Identification Failed';
      case MeshProtocolError.communicationError:
        return 'Communication Error';
      case MeshProtocolError.requestRejected:
        return 'Request Rejected';
      case MeshProtocolError.unsupportedVersion:
        return 'Unsupported Version';
      case MeshProtocolError.unsupportedDevice:
        return 'Unsupported Device';
    }
  }
}

/// Result of a protocol operation that may fail.
class MeshProtocolResult<T> {
  final T? value;
  final MeshProtocolError? error;
  final String? errorMessage;

  const MeshProtocolResult.success(this.value)
    : error = null,
      errorMessage = null;

  const MeshProtocolResult.failure(this.error, [this.errorMessage])
    : value = null;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  /// Returns the value or throws if this is a failure
  T get valueOrThrow {
    if (value == null) {
      throw StateError(
        'MeshProtocolResult is a failure: $error - $errorMessage',
      );
    }
    return value!;
  }

  @override
  String toString() => isSuccess
      ? 'MeshProtocolResult.success($value)'
      : 'MeshProtocolResult.failure($error: $errorMessage)';
}
