// SPDX-License-Identifier: GPL-3.0-or-later
/// Transport types supported by the app
enum TransportType { ble, usb }

/// Device information from scan results
class DeviceInfo {
  final String id;
  final String name;
  final TransportType type;
  final String? address;
  final int? rssi;

  /// BLE advertisement data: service UUIDs (lowercased)
  final List<String> serviceUuids;

  /// BLE advertisement data: manufacturer data (company ID -> payload bytes)
  final Map<int, List<int>> manufacturerData;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.rssi,
    this.serviceUuids = const [],
    this.manufacturerData = const {},
  });

  @override
  String toString() => 'DeviceInfo($name, $type, rssi: $rssi)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}

/// Connection state
enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Abstract transport interface
abstract class DeviceTransport {
  /// Get the transport type
  TransportType get type;

  /// Whether this transport requires packet framing
  /// BLE does NOT require framing (raw protobufs)
  /// Serial/USB DOES require framing (0x94, 0xC3, length, payload)
  bool get requiresFraming;

  /// Current connection state
  DeviceConnectionState get state;

  /// Stream of connection state changes
  Stream<DeviceConnectionState> get stateStream;

  /// Stream of received data
  Stream<List<int>> get dataStream;

  /// Scan for available devices
  ///
  /// [timeout] - How long to scan for devices
  /// [scanAll] - If true, scan for ALL BLE devices without service filtering.
  ///   Default (false) filters by known mesh protocol service UUIDs.
  ///   When true, returns all discovered devices with advertisement data.
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false});

  /// Connect to a device
  Future<void> connect(DeviceInfo device);

  /// Disconnect from the current device
  Future<void> disconnect();

  /// Send data to the device
  Future<void> send(List<int> data);

  /// Poll for data once (for transports that support active polling)
  Future<void> pollOnce();

  /// Enable notifications (BLE-specific, called after initial config download)
  Future<void> enableNotifications();

  /// Read current RSSI value (BLE-specific)
  /// Returns null if not supported or not connected
  Future<int?> readRssi();

  /// Get the BLE device model number from Device Information Service
  /// Returns null if not available (USB transport or not read yet)
  String? get bleModelNumber => null;

  /// Get the BLE manufacturer name from Device Information Service
  /// Returns null if not available (USB transport or not read yet)
  String? get bleManufacturerName => null;

  /// Dispose resources
  Future<void> dispose();

  /// Check if connected
  bool get isConnected => state == DeviceConnectionState.connected;
}
