# Socialmesh

A Meshtastic companion app for iOS and Android. Connect to your mesh radio, exchange messages, track nearby nodes, and configure your device — all without internet.

**Signals** — Leave short, ephemeral traces for people nearby. Signals expire automatically and never leave the mesh. No followers. No likes. Just presence.

## Features

### 📡 Messaging
- **Channel Messaging** — Send and receive on multiple channels
- **Direct Messages** — Private node-to-node communication
- **Quick Responses** — Pre-configured canned messages for fast replies
- **Message Search** — Find messages across all conversations
- **Offline Queue** — Messages queued when disconnected, sent when reconnected

### 🌐 Network & Nodes
- **Node Discovery** — See all nodes on your mesh with signal strength, battery, and location
- **Network Topology** — Visual graph showing how nodes connect to each other
- **Traceroute** — Trace the path packets take to reach any node
- **Signal History** — Charts showing SNR and RSSI over time
- **Favorites** — Pin important nodes for quick access

### 🗺️ Maps & Location
- **Node Map** — Interactive map showing all nodes with GPS
- **Waypoints** — Drop, share, and navigate to waypoints
- **Location Sharing** — Broadcast your position to the mesh
- **Multiple Map Styles** — Street, satellite, and terrain views

### ⚙️ Device Configuration
- **LoRa Settings** — Region, modem preset, hop limit, frequency slot
- **Power Management** — Sleep mode, shutdown timeout, power saving
- **Position Settings** — GPS mode, broadcast interval, smart position
- **Bluetooth** — Pairing mode, PIN code, power settings
- **Network** — WiFi, Ethernet, MQTT bridge configuration
- **Display** — Screen timeout, brightness, flip screen, OLED burn-in
- **Detection Sensor** — Motion and door sensor configuration
- **Canned Messages** — Configure quick response messages on device

### 🔊 Audio
- **Ringtone Library** — Browse 7,000+ RTTTL ringtones organized by category
- **Preview & Set** — Listen before sending to your device
- **Custom Ringtones** — Create and save your own RTTTL compositions

### 🔗 Integrations
- **IFTTT Webhooks** — Trigger automations on node events and geofence alerts
- **MQTT** — Configure MQTT bridge for internet uplink
- **QR Codes** — Import/export channels and share node info via QR

### ��️ Safety
- **Emergency SOS** — One-tap emergency broadcast with optional GPS
- **Geofence Alerts** — Get notified when nodes leave a defined area
- **Battery Alerts** — Low battery notifications for tracked nodes

## Tech Stack

- **Flutter** — Cross-platform UI framework
- **Riverpod** — Reactive state management  
- **Protocol Buffers** — Meshtastic protocol implementation
- **SQLite** — Local data persistence
- **Firebase** — Analytics and crash reporting

## Development

### Prerequisites

- Flutter SDK 3.10+
- Xcode (for iOS)
- Android Studio (for Android)
- Protocol Buffers compiler (`brew install protobuf`)

### Setup

```bash
# Install dependencies
flutter pub get

# Generate protobuf code
./scripts/generate_protos.sh

# Run on device
flutter run
```

### Project Structure

```
lib/
├── core/           # Theme, widgets, constants
├── features/       # Feature modules (messaging, nodes, map, settings, etc.)
├── generated/      # Generated protobuf code
├── models/         # Data models
├── providers/      # Riverpod providers
├── services/       # Business logic (protocol, storage, transport)
└── utils/          # Utilities and helpers
```

## URL Scheme

Socialmesh registers the `socialmesh://` URL scheme:

- `socialmesh://channel/<base64>` — Import channel configuration
- `socialmesh://node/<base64>` — Import node information

## License

This mobile application is licensed under the **GNU General Public License v3.0** (GPL-3.0-or-later).

You are free to use, modify, and distribute this software under the terms of the GPL-3.0. See the [LICENSE](LICENSE) file for details.

### Scope

- **Mobile app (this repository):** GPL-3.0 — source code is provided here.
- **Backend services, cloud functions, and APIs:** Proprietary and not included in this repository.

The source distribution requirement of GPL-3.0 is satisfied by this public repository.

### Third-Party Notices

See [NOTICE.md](NOTICE.md) for attribution of third-party components including Meshtastic protobufs.
