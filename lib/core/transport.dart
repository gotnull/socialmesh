/// Transport types supported by the app
enum TransportType { ble, usb }

/// Device information
class DeviceInfo {
  final String id;
  final String name;
  final TransportType type;
  final String? address;
  final int? rssi;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.rssi,
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
  Stream<DeviceInfo> scan({Duration? timeout});

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

  /// Dispose resources
  Future<void> dispose();

  /// Check if connected
  bool get isConnected => state == DeviceConnectionState.connected;
}
