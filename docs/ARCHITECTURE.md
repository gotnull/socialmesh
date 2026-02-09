# Architecture

Socialmesh is a Flutter mobile app (iOS/Android) that communicates with Meshtastic radios over BLE and USB. The app is fully functional offline; cloud features are optional.

## License

This mobile application is licensed under GPL-3.0-or-later. Backend services are proprietary and not included in this repository.

## High-Level Structure

```
lib/
├── core/              # Transport abstraction, theme, shared widgets, safety utilities
├── features/          # UI feature modules
├── generated/         # Meshtastic protobufs (generated code)
├── models/            # Domain models
├── providers/         # Riverpod state management
├── services/          # Business logic and integrations
└── utils/             # Utilities and helpers
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
- `signal_providers.dart` — Signals (ephemeral mesh content)
- `activity_providers.dart` — Activity timeline state
- `presence_providers.dart` — Node presence tracking

Only Riverpod 3.x APIs are used. StateNotifier, StateNotifierProvider, StateProvider, and ChangeNotifierProvider are banned.

## Feature Modules

Each feature in `lib/features/` is self-contained:

| Module           | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| `automations/`   | Rule-based event automation engine                   |
| `channels/`      | Channel management                                   |
| `dashboard/`     | Custom widget dashboard                              |
| `device/`        | Device configuration screens                         |
| `globe/`         | 3D globe visualization                               |
| `map/`           | Interactive node map with waypoints                  |
| `mesh3d/`        | 3D mesh network topology view                        |
| `mesh_health/`   | Network health analytics dashboard                   |
| `messaging/`     | Channel and direct messages                          |
| `nodedex/`       | Mesh field journal (sigils, traits, patina, co-seen) |
| `nodes/`         | Node discovery and details                           |
| `presence/`      | Node presence tracking                               |
| `profile/`       | User profile management                              |
| `reachability/`  | Node reachability analysis                           |
| `routes/`        | Packet route analysis                                |
| `signals/`       | Ephemeral mesh-first content                         |
| `social/`        | Activity timeline and social profiles                |
| `settings/`      | App, account, and theme settings                     |
| `widget_builder/`| Custom dashboard widget editor and marketplace       |
| `world_mesh/`    | Global MQTT node map                                 |

## NodeDex Architecture

The NodeDex (`lib/features/nodedex/`) is the mesh field journal system. It is independent of the Nodes screen — it reads from node data but persists its own enrichment layer in SQLite.

### Data Model

`NodeDexEntry` (`models/nodedex_entry.dart`) tracks discovery history, encounter statistics, social tags, and the data needed to derive procedural identity. Each entry is keyed by node number.

### Services

| Service                    | Purpose                                                      |
| -------------------------- | ------------------------------------------------------------ |
| `sigil_generator.dart`     | Deterministic geometric identity from node number            |
| `trait_engine.dart`        | Passive personality trait inference from telemetry            |
| `patina_score.dart`        | Digital history score (0-100) across six weighted axes       |
| `field_note_generator.dart`| Deterministic field-journal-style observations               |
| `progressive_disclosure.dart` | Threshold-based visibility tiers for journal elements     |
| `nodedex_database.dart`    | SQLite persistence layer                                     |
| `nodedex_sqlite_store.dart`| Low-level SQLite operations                                  |
| `nodedex_sync_service.dart`| Cloud sync for NodeDex data                                  |

### Sigil Generation

Sigils are pure functions of the node number. The generator uses murmur3-style hash mixing to extract independent parameters (vertex count, rotation, inner rings, radial lines, color palette) from a single 32-bit integer. No randomness, no network calls, no side effects.

### Trait Inference

Traits are derived from observable data only — encounter patterns, position history, uptime, role, and activity frequency. The engine evaluates traits in priority order (Relay, Wanderer, Sentinel, Beacon, Ghost, Courier, Anchor, Drifter) and returns scored results with evidence lines.

### Sigil Evolution

Visual maturity is derived from the patina score, progressing through five stages (Seed, Marked, Inscribed, Heraldic, Legacy). Each stage adds subtle rendering detail — line weight, color depth, micro-etch density.

### Identity Resolution

`lib/utils/mesh_identity.dart` provides centralized identity helpers:

- Resolution chain: live mesh telemetry, then NodeDex cached name, then hex fallback
- All resolution is offline-first
- Telemetry counters track resolution source distribution

## Lifecycle Safety

All `ConsumerStatefulWidget` screens with async operations use `LifecycleSafeMixin` from `lib/core/safety/lifecycle_mixin.dart`. This provides:

- `safeSetState()` — guards against setState after dispose
- `safeNavigatorPop()` — guards against navigation after dispose
- `safeShowSnackBar()` — guards against snackbar after dispose
- `safePostFrame()` — guards against post-frame callbacks after dispose

Provider refs and context-dependent values must be captured before any `await`. Mounted checks are required after every `await`.

## Data Flow

```
Radio (BLE/USB)
    |
DeviceTransport (raw bytes)
    |
PacketFramer (USB only)
    |
ProtocolService (protobuf parsing)
    |
Stream Controllers
    |
Riverpod Providers
    |
UI (ref.watch)
```

## Local Storage

SQLite databases handle offline persistence:

- **NodeDex** — Discovered nodes, encounter history, social tags
- **Signals** — Ephemeral mesh content with TTL
- **Routes** — Discovered packet routes
- **Packet Dedup** — Prevents duplicate packet processing

## Cloud Services (Optional)

Firebase integration is optional. Without configuration, the app falls back to local-only mode:

- **Firestore** — Profile sync, shared links, social features
- **Cloud Functions** — Push notifications, content moderation
- **Analytics/Crashlytics** — Telemetry (disabled without config)

Cloud services are accessed through service classes in `lib/services/` that gracefully degrade when unavailable.

## Backend Boundary

Backend services, cloud functions, and APIs are **not part of this repository**. See [BACKEND.md](BACKEND.md) for details on which features require backend access.