# Socialmesh

A **privacy-first social network** built on Meshtastic mesh radios. Communicate without internet - messages hop between nearby devices, creating a truly decentralized network.

## Feature Overview

| Category | Feature | Status | Description |
|----------|---------|--------|-------------|
| **Messaging** | Text Messages | ✅ | Send/receive messages over mesh |
| | Channel Support | ✅ | Multi-channel messaging |
| | Direct Messages | ✅ | Private node-to-node messages |
| | Quick Responses | ✅ | Pre-configured canned messages |
| | Message Search | ✅ | Search through message history |
| | Offline Queue | ✅ | Messages queued when disconnected |
| **Network** | Node Discovery | ✅ | Track all mesh nodes |
| | Traceroute | ✅ | Trace path to any node |
| | Network Topology | ✅ | Visual mesh network graph |
| | Signal Charts | ✅ | Real-time signal strength history |
| | Store & Forward | ✅ | Configure message store & forward |
| | Range Test | ✅ | Run and log range tests |
| **Map & Location** | Node Map | ✅ | View nodes on interactive map |
| | Waypoints | ✅ | Drop and share waypoints |
| | Location Sharing | ✅ | Share your position to mesh |
| | Offline Maps | 🔒 | Download maps for offline use |
| **Safety** | Emergency SOS | ✅ | One-tap emergency broadcast |
| | Geofence Alerts | ✅ | IFTTT alerts when nodes leave area |
| | Battery Alerts | ✅ | Low battery notifications |
| **Device Config** | LoRa Settings | ✅ | Region, modem preset, frequency |
| | Power Settings | ✅ | Sleep, shutdown, power saving |
| | Display Settings | ✅ | Screen timeout, brightness |
| | Position Settings | ✅ | GPS, smart position, intervals |
| | Bluetooth Settings | ✅ | Pairing mode, PIN, power |
| | Network/WiFi | ✅ | WiFi, Ethernet, NTP |
| | Security | ✅ | Admin key, managed mode |
| | Detection Sensor | ✅ | Configure motion/door sensors |
| **Audio** | Ringtone Library | ✅ | 7,000+ RTTTL ringtones |
| | Ringtone Preview | ✅ | Play before setting |
| | Custom Ringtones | ✅ | Create and save custom RTTTL |
| **Integrations** | IFTTT Webhooks | ✅ | Trigger automations |
| | MQTT | ✅ | Configure MQTT bridge |
| | QR Import | ✅ | Import channels via QR code |
| **Data** | Cloud Backup | 🔒 | Backup to cloud |
| | Export Messages | 🔒 | Export to PDF/CSV |

**Legend:** ✅ Available | 🔒 Premium Feature

## Features

### Social Features
- **Ephemeral Identity**: Auto-rotating anonymous identities that prevent tracking while preserving reputation
- **Hyperlocal Feed**: Discover content from your area that spreads organically through the mesh
- **Encrypted Communities**: Private groups with end-to-end encryption
- **Verified Friends**: Cryptographically verify trusted contacts

### Mesh Features
- **Multi-Transport Support**: Connect via Bluetooth Low Energy (BLE) or USB Serial
- **Device Scanner**: Discover and connect to Meshtastic devices
- **Real-time Messaging**: Send and receive text messages over the mesh network
- **Node Discovery**: Track and display all discovered mesh nodes
- **Node Map**: View node positions on an interactive map (for nodes with GPS)
- **Channel Management**: Import channel configurations via QR code

### Technical Features
- **Secure Storage**: Encrypted storage for channel keys and sensitive data
- **Protocol Service**: Full Meshtastic protobuf packet handling with framing
- **State Management**: Reactive global state using Riverpod
- **Offline-First**: Works entirely without internet connectivity

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI LAYER                                │
│  Feed, Communities, Identity, Messaging, Nodes, Settings        │
└─────────────────────────┬───────────────────────────────────────┘
                          │ watches/reads
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RIVERPOD PROVIDERS                           │
│  feedPostsProvider, communitiesProvider, currentIdentityProvider│
│  messagesProvider, nodesProvider, channelsProvider              │
└─────────────────────────┬───────────────────────────────────────┘
                          │ uses
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SERVICES LAYER                             │
│  ProtocolService (Meshtastic), SocialMeshService, DatabaseService│
└─────────────────────────┬───────────────────────────────────────┘
                          │ communicates via
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TRANSPORT LAYER                              │
│  BleTransport (Bluetooth) / UsbTransport (Serial)               │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
                   [Meshtastic Radio]
```

### Project Structure

```
lib/
├── core/                    # Core abstractions and models
│   ├── transport.dart       # DeviceTransport interface
│   ├── identity.dart        # EphemeralIdentity model
│   ├── feed_models.dart     # FeedPost, Reaction models
│   ├── community_models.dart # Community, CommunityPost models
│   ├── crypto.dart          # Cryptographic utilities
│   └── theme.dart           # App theming
├── features/                # UI feature modules
│   ├── dashboard/           # Connection dashboard
│   ├── feed/                # Social feed
│   ├── communities/         # Community management
│   ├── identity/            # Identity management
│   ├── messaging/           # Direct messaging
│   ├── nodes/               # Mesh node discovery
│   ├── channels/            # Channel management
│   ├── scanner/             # Device scanner
│   ├── settings/            # App settings
│   ├── onboarding/          # First-time setup
│   └── navigation/          # Main navigation shell
├── generated/               # Generated protobuf code
│   └── meshtastic/          # Meshtastic protocol buffers
├── models/                  # Data models
│   ├── mesh_models.dart     # Message, MeshNode, ChannelConfig
│   └── device_error.dart    # Error models
├── providers/               # Riverpod providers
│   ├── app_providers.dart   # Device/network state
│   └── social_providers.dart # Social feature state
├── services/                # Business logic services
│   ├── protocol/            # Meshtastic protocol handling
│   ├── social/              # Social mesh protocol
│   ├── storage/             # Data persistence
│   └── transport/           # BLE/USB communication
├── widgets/                 # Reusable UI components
│   └── common_widgets.dart  # Shared widgets
├── utils/                   # Utility functions
└── main.dart                # App entry point

protos/                      # Protobuf definitions
└── meshtastic/
    ├── mesh.proto
    └── portnums.proto
```

### Data Storage

| Data | Storage | Service |
|------|---------|---------|
| Identities | SQLite | `DatabaseService` |
| Feed Posts | SQLite | `DatabaseService` |
| Communities | SQLite | `DatabaseService` |
| Verified Friends | SQLite | `DatabaseService` |
| Messages | SharedPreferences | `MessageStorageService` |
| Settings | SharedPreferences | `SettingsService` |
| Channel Keys | Secure Storage | `SecureStorageService` |

### Key Components

#### 1. Identity System (`lib/core/identity.dart`)

**EphemeralIdentity** provides anonymous, rotating identities:
- Cryptographic keypair (public/private)
- Auto-rotates every 24 hours to prevent tracking
- Avatar generated from identity seed
- Stored encrypted in SQLite

#### 2. Social Protocol (`lib/services/social/social_mesh_service.dart`)

Custom packet format for social features:
```
[Magic: 2 bytes "PF"] [Type: 1 byte] [Version: 1 byte] [Flags: 1 byte] [Length: 2 bytes] [Checksum: 1 byte] [Payload...]
```

**Packet Types:**
| Type | Code | Description |
|------|------|-------------|
| `feedPost` | 0x01 | New feed post |
| `feedPropagation` | 0x02 | Request to re-broadcast a post |
| `communityPost` | 0x03 | Post to a community |
| `communitySync` | 0x04 | Sync community state |
| `mediaChunk` | 0x05 | Chunked media data |
| `identityProof` | 0x06 | Verify identity |
| `friendRequest` | 0x07 | Friend request |
| `friendResponse` | 0x08 | Accept/reject friend |
| `heartbeat` | 0x09 | Presence announcement |

#### 3. Transport Layer

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

#### 4. Protocol Service (`lib/services/protocol/protocol_service.dart`)

**`ProtocolService`** handles Meshtastic protocol:
- **Packet Framing**: Uses `PacketFramer` to frame/deframe packets with magic bytes
- **Protobuf Encoding/Decoding**: Serializes/deserializes Meshtastic messages
- **Message Routing**: Manages message delivery and acknowledgments
- **Node Discovery**: Tracks mesh nodes and their metadata
- **Channel Configuration**: Manages channel settings

**Meshtastic Packet Format:**
```
[0x94, 0xC3, MSB(length), LSB(length), ...payload...]
```

#### 5. State Management (Riverpod)

**Core Providers:**
```dart
// App initialization
appInitProvider           → initializes DB, loads identity, auto-reconnects

// Identity & Social
currentIdentityProvider   → your ephemeral identity
feedPostsProvider         → list of feed posts
communitiesProvider       → list of communities
verifiedFriendsProvider   → your verified friends

// Device/Network
transportProvider         → BLE or USB transport
protocolServiceProvider   → Meshtastic protocol handler
connectionStateProvider   → connected/disconnected status
connectedDeviceProvider   → currently connected device

// Mesh Data
nodesProvider            → mesh nodes discovered
channelsProvider         → Meshtastic channels
messagesProvider         → text messages
myNodeNumProvider        → your node number

// Settings
settingsServiceProvider   → app settings (auto-reconnect, last device, etc.)
```

## How It Works

### Posting to Feed

1. User taps "Post" in Feed screen
2. `feedPostsProvider.notifier.createPost()` is called
3. Creates `FeedPost` with current identity as author
4. Saves to SQLite via `DatabaseService`
5. Broadcasts over mesh via `SocialMeshService.broadcastFeedPost()`
6. Other devices receive and store the post locally

### Receiving Posts Over Mesh

1. Radio receives data → `BleTransport.dataStream` emits bytes
2. `ProtocolService` processes Meshtastic packet
3. If social packet, `SocialMeshService.processIncomingData()` parses it
4. Deserializes to `FeedPost`, checks expiry
5. Emits on `newPosts` stream
6. UI updates via provider

### Identity Rotation

1. Identity created with 24-hour validity
2. Timer schedules rotation check
3. When expired, `rotateIdentity()` generates new keypair
4. Old identity archived, new one becomes active
5. Reputation transfers via cryptographic proof

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
- `sqflite`: SQLite database

### UI/UX
- `flutter_map`: Interactive maps
- `mobile_scanner`: QR code scanning
- `intl`: Date/time formatting

## Key Files Reference

| Purpose | File |
|---------|------|
| App entry & routing | `lib/main.dart` |
| Device/network providers | `lib/providers/app_providers.dart` |
| Social feature providers | `lib/providers/social_providers.dart` |
| Identity model | `lib/core/identity.dart` |
| Feed model | `lib/core/feed_models.dart` |
| Community model | `lib/core/community_models.dart` |
| SQLite database | `lib/services/storage/database_service.dart` |
| Settings storage | `lib/services/storage/storage_service.dart` |
| BLE communication | `lib/services/transport/ble_transport.dart` |
| Meshtastic protocol | `lib/services/protocol/protocol_service.dart` |
| Social mesh protocol | `lib/services/social/social_mesh_service.dart` |

## Future Enhancements

- [ ] Media attachments (images chunked over mesh)
- [ ] Location-based post filtering
- [ ] Community invitations via QR
- [ ] Message reactions and replies
- [ ] Push notifications
- [ ] Background mesh service
- [ ] Mesh statistics and analytics
- [ ] Route tracing visualization

## License

[Specify your license here]

## Credits

Built using:
- [Flutter](https://flutter.dev/)
- [Meshtastic](https://meshtastic.org/)
- [Protocol Buffers](https://protobuf.dev/)
