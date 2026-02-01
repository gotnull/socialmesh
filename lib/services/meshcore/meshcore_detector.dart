// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/meshcore_constants.dart';
import '../../core/transport.dart';
import '../../models/mesh_device.dart';

/// Result of protocol detection for a scanned device.
class ProtocolDetectionResult {
  /// The detected protocol type.
  final MeshProtocolType protocolType;

  /// Confidence level of the detection (0.0 to 1.0).
  final double confidence;

  /// Reason for the detection result.
  final String reason;

  const ProtocolDetectionResult({
    required this.protocolType,
    required this.confidence,
    required this.reason,
  });

  @override
  String toString() =>
      'ProtocolDetectionResult($protocolType, confidence: $confidence, $reason)';
}

/// Detects mesh protocol type from BLE scan advertisement data.
///
/// This class analyzes BLE scan results to determine whether a device
/// is running Meshtastic, MeshCore, or an unknown protocol.
///
/// Detection is based on:
/// - Advertised service UUIDs
/// - Device name patterns
/// - Manufacturer data (if available)
///
/// The detector does NOT break existing Meshtastic detection - it adds
/// MeshCore detection as an additional check.
class MeshProtocolDetector {
  MeshProtocolDetector._();

  /// Meshtastic BLE service UUID.
  static const String _meshtasticServiceUuid =
      '6ba1b218-15a8-461f-9fa8-5dcae273eafd';

  /// Detect protocol type from device info and advertisement data.
  ///
  /// [device] - Basic device info from scan result.
  /// [advertisedServiceUuids] - List of service UUIDs from advertisement.
  /// [manufacturerData] - Optional manufacturer-specific data.
  static ProtocolDetectionResult detect({
    required DeviceInfo device,
    List<String> advertisedServiceUuids = const [],
    Map<int, List<int>>? manufacturerData,
  }) {
    // Check service UUIDs first (most reliable)
    final serviceUuidResult = _detectFromServiceUuids(advertisedServiceUuids);
    if (serviceUuidResult != null) {
      return serviceUuidResult;
    }

    // Check device name patterns
    final nameResult = _detectFromName(device.name);
    if (nameResult != null) {
      return nameResult;
    }

    // Check manufacturer data if available
    if (manufacturerData != null && manufacturerData.isNotEmpty) {
      final mfgResult = _detectFromManufacturerData(manufacturerData);
      if (mfgResult != null) {
        return mfgResult;
      }
    }

    // Unknown protocol
    return const ProtocolDetectionResult(
      protocolType: MeshProtocolType.unknown,
      confidence: 0.0,
      reason: 'No matching protocol identifiers',
    );
  }

  static ProtocolDetectionResult? _detectFromServiceUuids(
    List<String> serviceUuids,
  ) {
    final normalizedUuids = serviceUuids.map((u) => u.toLowerCase()).toList();

    // Check for MeshCore service UUID
    if (normalizedUuids.contains(MeshCoreBleUuids.serviceUuid.toLowerCase())) {
      return const ProtocolDetectionResult(
        protocolType: MeshProtocolType.meshcore,
        confidence: 1.0,
        reason: 'MeshCore service UUID advertised',
      );
    }

    // Check for Meshtastic service UUID
    if (normalizedUuids.contains(_meshtasticServiceUuid.toLowerCase())) {
      return const ProtocolDetectionResult(
        protocolType: MeshProtocolType.meshtastic,
        confidence: 1.0,
        reason: 'Meshtastic service UUID advertised',
      );
    }

    return null;
  }

  static ProtocolDetectionResult? _detectFromName(String? name) {
    if (name == null || name.isEmpty) return null;

    // Check MeshCore name patterns
    if (MeshCoreDevicePatterns.matchesDeviceName(name)) {
      return const ProtocolDetectionResult(
        protocolType: MeshProtocolType.meshcore,
        confidence: 0.8,
        reason: 'Device name matches MeshCore pattern',
      );
    }

    // Common Meshtastic name patterns
    final lowerName = name.toLowerCase();
    if (lowerName.contains('meshtastic') ||
        lowerName.startsWith('mesh-') ||
        _isMeshtasticNodeName(lowerName)) {
      return const ProtocolDetectionResult(
        protocolType: MeshProtocolType.meshtastic,
        confidence: 0.7,
        reason: 'Device name matches Meshtastic pattern',
      );
    }

    return null;
  }

  /// Check if name matches Meshtastic node naming pattern.
  ///
  /// Meshtastic nodes often have names like "Name XXXX" where XXXX is
  /// the last 4 hex digits of the node ID.
  static bool _isMeshtasticNodeName(String lowerName) {
    // Pattern: word(s) followed by 4 hex chars
    final pattern = RegExp(r'^[\w\s]+ [0-9a-f]{4}$');
    return pattern.hasMatch(lowerName);
  }

  static ProtocolDetectionResult? _detectFromManufacturerData(
    Map<int, List<int>> manufacturerData,
  ) {
    // MeshCore manufacturer ID (placeholder - update when documented)
    // const int meshCoreManufacturerId = 0xFFFF;

    // Meshtastic uses standard BLE without specific manufacturer ID
    // So we can't reliably detect from manufacturer data alone

    return null;
  }

  /// Check if a device appears to be a MeshCore device.
  ///
  /// Convenience method for quick checks during scanning.
  static bool isMeshCore({
    required DeviceInfo device,
    List<String> advertisedServiceUuids = const [],
  }) {
    final result = detect(
      device: device,
      advertisedServiceUuids: advertisedServiceUuids,
    );
    return result.protocolType == MeshProtocolType.meshcore;
  }

  /// Check if a device appears to be a Meshtastic device.
  ///
  /// Convenience method for quick checks during scanning.
  static bool isMeshtastic({
    required DeviceInfo device,
    List<String> advertisedServiceUuids = const [],
  }) {
    final result = detect(
      device: device,
      advertisedServiceUuids: advertisedServiceUuids,
    );
    return result.protocolType == MeshProtocolType.meshtastic;
  }
}

/// Extension on DeviceInfo for protocol detection.
extension DeviceInfoProtocolExtension on DeviceInfo {
  /// Detect the mesh protocol type for this device.
  ///
  /// Uses the device's name, service UUIDs, and manufacturer data
  /// captured during scanning for detection.
  ProtocolDetectionResult detectProtocol() {
    return MeshProtocolDetector.detect(
      device: this,
      advertisedServiceUuids: serviceUuids,
      manufacturerData: manufacturerData.isNotEmpty ? manufacturerData : null,
    );
  }
}
