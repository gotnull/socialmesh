# Architecture

Socialmesh is a Flutter mobile app (iOS/Android) that communicates with Meshtastic radios over BLE and USB. The app is fully functional offline; cloud features are optional.

## License

This mobile application is licensed under GPL-3.0-or-later. Backend services are proprietary and not included in this repository.

## High-Level Structure

```
lib/
├── core/              # Transport abstraction, theme, shared widgets
├── features/          # UI feature modules (32+ screens)
├── generated/         # Meshtastic protobufs (generated code)
├── models/            # Domain models
├── providers/         # Riverpod state management
├── services/          # Business logic and integrations
└── utils/             # Utilities
```

## Transport Layer

Radio communication is abstracted through `DeviceTransport` in `lib/core/transport.dart`:

- **BLE** — `lib/services/transport/ble_transport.dart` — Raw protobuf packets
- **USB** — `lib/services/transport/usb_transport.dart` — Requires packet framing

The `requiresFraming` property determines whether packets need 0x94/0xC3 framing (USB) or are sent raw (BLE).

## Protocol Layer

`lib/services/protocol/protocol_service.dart` handles all Meshtastic protocol logic:

- Parses incoming protobufs from `lib/generated/meshtastic/*.pb.dart`
- Manages configuration streams (LoRa, position, Bluetooth, etc.)
- Emits typed events via stream controllers
- Handles packet deduplication and routing

## State Management

Riverpod 3.x providers in `lib/providers/` expose reactive state to the UI:

- `app_providers.dart` — Core mesh state (nodes, messages, channels)
- `connection_providers.dart` — Device connection state
- `subscription_providers.dart` — Premium feature entitlements

## Feature Modules

Each feature in `lib/features/` is self-contained:

| Module         | Purpose                      |
| -------------- | ---------------------------- |
| `messaging/`   | Channel and direct messages  |
| `nodes/`       | Node discovery and details   |
| `map/`         | Node map with waypoints      |
| `device/`      | Device configuration screens |
| `automations/` | Automation rules engine      |
| `signals/`     | Ephemeral mesh posts         |
| `settings/`    | App and account settings     |

## Data Flow

```
Radio (BLE/USB)
    ↓
DeviceTransport (raw bytes)
    ↓
PacketFramer (USB only)
    ↓
ProtocolService (protobuf parsing)
    ↓
Stream Controllers
    ↓
Riverpod Providers
    ↓
UI (ref.watch)
```

## Cloud Services (Optional)

Firebase integration is optional. Without configuration, the app falls back to local-only mode:

- **Firestore** — Profile sync, shared links, social features
- **Cloud Functions** — Push notifications, content moderation
- **Analytics/Crashlytics** — Telemetry (disabled without config)

Cloud services are accessed through service classes in `lib/services/` that gracefully degrade when unavailable.

## Backend Boundary

Backend services, cloud functions, and APIs are **not part of this repository**. See [BACKEND.md](BACKEND.md) for details on which features require backend access.
