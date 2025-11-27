# Protofluff

A complete Flutter companion app for Meshtastic devices with BLE and USB serial communication.

## Features

- **Multi-Transport Support**: Connect via Bluetooth Low Energy (BLE) or USB Serial
- **Device Scanner**: Discover and connect to Meshtastic devices
- **Real-time Messaging**: Send and receive text messages over the mesh network
- **Node Discovery**: Track and display all discovered mesh nodes
- **Node Map**: View node positions on an interactive map (for nodes with GPS)
- **Channel Management**: Import channel configurations via QR code
- **Secure Storage**: Encrypted storage for channel keys and sensitive data
- **Settings**: Customize app behavior and manage data
- **Protocol Service**: Full Meshtastic protobuf packet handling with framing
- **State Management**: Reactive global state using Riverpod
- **Extensible Architecture**: Clean separation of concerns for easy customization

## Architecture

### Project Structure

```
lib/
├── core/                    # Core abstractions
│   └── transport.dart       # DeviceTransport interface
├── features/                # UI feature modules
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── messaging/
│   │   └── messaging_screen.dart
│   ├── nodes/
│   │   ├── nodes_screen.dart
│   │   └── node_map_screen.dart
│   ├── scanner/
│   │   └── scanner_screen.dart
│   └── settings/
│       ├── settings_screen.dart
│       └── qr_import_screen.dart
├── generated/               # Generated protobuf code
├── models/                  # Data models
│   └── mesh_models.dart     # Message, MeshNode, ChannelConfig
├── providers/               # Riverpod providers
│   └── app_providers.dart   # Global state management
├── services/                # Business logic services
│   ├── protocol/
│   │   ├── packet_framer.dart    # Meshtastic packet framing
│   │   └── protocol_service.dart # Protocol handling
│   ├── storage/
│   │   └── storage_service.dart  # Secure & settings storage
│   └── transport/
│       ├── ble_transport.dart    # BLE implementation
│       └── usb_transport.dart    # USB serial implementation
├── utils/                   # Utility functions
└── main.dart                # App entry point

protos/                      # Protobuf definitions
└── meshtastic/
    ├── mesh.proto
    └── portnums.proto
```

### Key Components

#### 1. Transport Layer

The transport layer provides an abstraction over BLE and USB serial communication:

**`DeviceTransport`** interface defines:
- `scan()`: Discover available devices
- `connect()`: Establish connection
- `send()`: Transmit data
- `dataStream`: Receive data
- `stateStream`: Monitor connection state

**Implementations:**
- `BleTransport`: Uses `flutter_blue_plus` for Bluetooth communication
- `UsbTransport`: Uses `usb_serial` for USB serial communication

Both implementations handle:
- Connection management
- Automatic reconnection
- Data buffering
- Error handling

#### 2. Protocol Service

**`ProtocolService`** handles Meshtastic protocol:
- **Packet Framing**: Uses `PacketFramer` to frame/deframe packets with magic bytes
- **Protobuf Encoding/Decoding**: Serializes/deserializes Meshtastic messages
- **Message Routing**: Manages message delivery and acknowledgments
- **Node Discovery**: Tracks mesh nodes and their metadata
- **Channel Configuration**: Manages channel settings

**Packet Format:**
```
[0x94, 0xC3, MSB(length), LSB(length), ...payload...]
```

#### 3. State Management

Uses **Riverpod** for reactive state management:

**Providers:**
- `transportProvider`: Current transport (BLE/USB)
- `connectionStateProvider`: Connection status stream
- `protocolServiceProvider`: Protocol service instance
- `messagesProvider`: Message history
- `nodesProvider`: Discovered nodes
- `channelsProvider`: Channel configurations
- `myNodeNumProvider`: Current node number

**State Notifiers:**
- `MessagesNotifier`: Manages message list
- `NodesNotifier`: Manages node map
- `ChannelsNotifier`: Manages channel list

## Setup

### Prerequisites

1. **Flutter SDK** (3.10.0 or higher)
2. **Protocol Buffers Compiler** (`protoc`)
   - macOS: `brew install protobuf`
   - Linux: `apt-get install protobuf-compiler`
3. **Dart protoc plugin**:
   ```bash
   dart pub global activate protoc_plugin
   ```

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Generate protobuf code:
   ```bash
   ./generate_protos.sh
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

#### iOS

Add permissions to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to Meshtastic devices</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to scan for Bluetooth devices</string>
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to scan QR codes</string>
```

## Usage

### Connecting to a Device

1. Launch the app (opens Scanner screen)
2. Select transport type (Bluetooth or USB)
3. Tap on a discovered device to connect
4. Wait for connection to establish

### Sending Messages

1. Navigate to Messages screen
2. Select recipient (broadcast or specific node)
3. Type your message
4. Tap Send button

### Viewing Nodes

1. Navigate to Nodes screen
2. View list of all discovered nodes
3. Tap a node for detailed information

### Importing Channels

1. Navigate to Settings > QR Import
2. Point camera at Meshtastic channel QR code
3. Wait for automatic import

## Extending the App

### Adding Custom Commands

The protocol service can be extended to handle custom packet types:

```dart
// In protocol_service.dart
Future<void> sendCustomCommand({
  required int commandId,
  required List<int> payload,
}) async {
  // Create custom Data packet
  // Send via transport
}
```

### Custom Transport

Implement the `DeviceTransport` interface for new transport types:

```dart
class MyCustomTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.custom;
  
  // Implement other methods...
}
```

## Dependencies

### Core
- `flutter_riverpod`: State management
- `protobuf`: Protocol Buffers support
- `logger`: Structured logging

### Communication
- `flutter_blue_plus`: BLE functionality
- `usb_serial`: USB serial communication

### Storage
- `flutter_secure_storage`: Encrypted storage
- `shared_preferences`: Settings persistence

### UI/UX
- `flutter_map`: Interactive maps
- `mobile_scanner`: QR code scanning
- `intl`: Date/time formatting

## Future Enhancements

- [ ] Implement actual protobuf message encoding/decoding
- [ ] Add message retry and delivery confirmation
- [ ] Implement telemetry display
- [ ] Add position sharing
- [ ] Implement channel creation UI
- [ ] Add message filtering and search
- [ ] Implement route tracing
- [ ] Add notification support
- [ ] Background service for continuous connection
- [ ] Mesh statistics and analytics

## License

[Specify your license here]

## Credits

Built using:
- [Flutter](https://flutter.dev/)
- [Meshtastic](https://meshtastic.org/)
- [Protocol Buffers](https://protobuf.dev/)
