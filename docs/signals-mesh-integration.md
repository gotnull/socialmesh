# Signals Mesh Integration

This document describes the mesh broadcast and protocol wiring for the Signals feature (ephemeral posts).

## Overview

Signals use the Meshtastic `PRIVATE_APP` portnum (256) to broadcast ephemeral content over the mesh network. The implementation follows a mesh-first architecture where signals are stored locally first, then broadcast over mesh, with optional Firebase sync for authenticated users.

## Architecture

### Key Components

| Layer | File | Responsibility |
|-------|------|----------------|
| Protocol | `lib/services/protocol/protocol_service.dart` | `MeshSignalPacket` parsing, `sendSignal()`, `_handleSignalMessage()`, `signalStream` |
| Service | `lib/services/signal_service.dart` | SQLite storage, duplicate detection, `onBroadcastSignal` callback, expiry prevention |
| Provider | `lib/providers/signal_providers.dart` | Wires `onBroadcastSignal`, subscribes to `signalStream`, lifecycle cleanup |

### Wire Format

Signals are transmitted as JSON payloads over `PRIVATE_APP` (portnum 256):

```json
{
  "content": "Hello mesh!",
  "ttl": 60,
  "lat": 37.7749,
  "lng": -122.4194,
  "imgUrl": "https://..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | string | Yes | Signal text content (max 280 chars) |
| `ttl` | int | Yes | Time-to-live in minutes |
| `lat` | double | No | Latitude coordinate |
| `lng` | double | No | Longitude coordinate |
| `imgUrl` | string | No | Cloud image URL (after upload) |

### Payload Size Guard

**Critical**: 180 chars ≠ 180 bytes. Emojis and special characters inflate UTF-8 size significantly.

- **Max payload**: 200 bytes (UTF-8 encoded JSON)
- **Behavior**: `sendSignal()` throws `ArgumentError` if exceeded
- **Logging**: `📡 Signals: Signal payload too large: N bytes (max 200)`

This prevents radio-level fragmentation or silent packet drops.

### MeshSignalPacket Class

Located in `protocol_service.dart`:

```dart
class MeshSignalPacket {
  final int senderNodeId;
  final String? signalId;  // null for legacy signals (pre-v1)
  final String content;
  final int ttlMinutes;
  final double? latitude;
  final double? longitude;
  final DateTime receivedAt;

  bool get isLegacy => signalId == null;

  factory MeshSignalPacket.fromPayload(int senderNodeId, List<int> payload);
  List<int> toPayload();
}
```

### JSON Payload Format (v1)

Uses compressed keys to minimize payload size:

```json
{
  "id": "<uuid>",    // Signal ID (required for cloud sync)
  "c": "...",        // content
  "t": 60,           // ttl (minutes)
  "la": 37.7749,     // latitude (optional)
  "ln": -122.4194    // longitude (optional)
}
```

**Legacy format** (no `id` field) is still parsed but treated as local-only.

### Deterministic Matching

The `id` field is the single source of truth for joining:
- **Firestore document**: `posts/{id}`
- **Storage path**: `signals/{userId}/{id}.jpg`
- **Responses**: `responses/{id}/items/{responseId}`

No content-based or time-based heuristic matching.

## End-to-End Flow

### 1. CREATE (User creates a signal)

```
SignalFeedNotifier.createSignal()
  └─► SignalService.createSignal()
        │
        ├─► [1a] Generate UUID, calculate expiresAt
        │   AppLogging.signals('Creating signal: id=..., ttl=60m')
        │
        ├─► [1b] _saveSignalToDb(signal)
        │   └─► SQLite INSERT into 'signals' table
        │
        ├─► [1c] If authenticated & not expired:
        │   └─► _saveSignalToFirebase(signal)
        │       └─► Firestore posts/{id}.set()
        │
        └─► [1d] onBroadcastSignal callback (wired by provider)
              └─► ProtocolService.sendSignal(signalId: id, ...)
                    │
                    ├─► MeshSignalPacket.toPayload() → JSON with id
                    │
                    ├─► Build pb.MeshPacket
                    │   • portnum = PRIVATE_APP (256)
                    │   • to = 0xFFFFFFFF (broadcast)
                    │   • payload = JSON bytes
                    │
                    └─► _transport.send(_prepareForSend(bytes))
```
```

### 2. BROADCAST (Packet travels over mesh)

```
Local Device Radio TX
  └─► LoRa packet with:
        • PortNum: PRIVATE_APP (256)
        • Payload: JSON {"content":"Hello mesh!", "ttl":60}
        • Broadcast address: 0xFFFFFFFF

      ↓ ↓ ↓ (over-the-air) ↓ ↓ ↓

Remote Device(s) Radio RX
```

### 3. RECEIVE (Remote device receives signal)

```
DeviceTransport.dataStream
  └─► ProtocolService._handleData()
        └─► _handleMeshPacket(packet)
              │
              ├─► [3a] Ignore own echo (packet.from == _myNodeNum)
              │
              └─► [3b] switch(portnum) → case PRIVATE_APP:
                    └─► _handleSignalMessage(packet, data)
                          │
                          ├─► MeshSignalPacket.fromPayload(senderNodeId, payload)
                          │
                          └─► _signalController.add(signalPacket)
                                │
                                └─► SignalFeedNotifier._signalSubscription
                                      └─► _handleIncomingMeshSignal(packet)
                                            │
                                            └─► addMeshSignal(...)
                                                  └─► SignalService.createSignalFromMesh()
                                                        │
                                                        ├─► Duplicate detection via packet hash
                                                        ├─► Record node proximity
                                                        └─► Save to SQLite
```

### 4. EXPIRE (Signal TTL expires)

```
[4a] Periodic Cleanup Timer (every 1 minute)
SignalFeedNotifier._cleanupTimer
  └─► SignalService.cleanupExpiredSignals()
        └─► DELETE FROM signals WHERE expiresAt < NOW()

[4b] App Resume Cleanup
SignalFeedNotifier.didChangeAppLifecycleState(resumed)
  └─► _cleanupExpired()

[4c] Firebase Upload Prevention
SignalService._saveSignalToFirebase(signal)
  └─► if (signal.isExpired) return; // Never uploads expired
```

## Duplicate Packet Handling

Mesh networks can deliver the same packet multiple times. Deduplication uses a hash-based approach:

1. **Hash Generation**: `$senderNodeId:$content:$ttlMinutes`
2. **Storage**: `seen_packets` SQLite table with 30-minute TTL
3. **Check**: `_hasSeenPacket(hash)` returns true if already processed

## Image Unlock Rules

Images are unlocked (viewable/uploadable) when:

1. **Auth Unlock**: User is authenticated, OR
2. **Proximity Unlock**: Sender node has been seen for ≥5 minutes within the last 15 minutes

```dart
class ImageUnlockRules {
  static const int proximityThresholdMinutes = 5;
  static const int proximityWindowMinutes = 15;
  static const int maxHopsForProximity = 2;
}
```

## Provider Wiring

`SignalFeedNotifier._wireMeshIntegration()` connects the layers:

```dart
void _wireMeshIntegration() {
  final service = ref.read(signalServiceProvider);
  final protocol = ref.read(protocolServiceProvider);

  // Outbound: Service → Protocol
  service.onBroadcastSignal = (content, ttl, lat, lng, imgUrl) async {
    return await protocol.sendSignal(...);
  };

  // Inbound: Protocol → Service
  _signalSubscription = protocol.signalStream.listen(
    _handleIncomingMeshSignal,
  );
}
```

## Debug Logging

Enable signal logging via environment variable:

```
SIGNALS_LOGGING_ENABLED=true
```

Log prefix: `📡 Signals:`

Key log points:
- Signal creation
- Mesh broadcast
- Mesh receipt
- Duplicate detection
- Expiry cleanup
- Firebase sync attempts

## SQLite Schema

### signals table
```sql
CREATE TABLE signals (
  id TEXT PRIMARY KEY,
  authorId TEXT NOT NULL,
  content TEXT NOT NULL,
  mediaUrls TEXT,
  locationLatitude REAL,
  locationLongitude REAL,
  locationName TEXT,
  createdAt INTEGER NOT NULL,
  expiresAt INTEGER,
  meshNodeId INTEGER,
  imageState TEXT NOT NULL,
  imageLocalPath TEXT,
  syncedToCloud INTEGER DEFAULT 0
);

CREATE INDEX idx_signals_expiresAt ON signals(expiresAt);
CREATE INDEX idx_signals_meshNodeId ON signals(meshNodeId);
```

### seen_packets table
```sql
CREATE TABLE seen_packets (
  packetHash TEXT PRIMARY KEY,
  receivedAt INTEGER NOT NULL
);

CREATE INDEX idx_seen_receivedAt ON seen_packets(receivedAt);
```

### node_proximity table
```sql
CREATE TABLE node_proximity (
  nodeId INTEGER NOT NULL,
  seenAt INTEGER NOT NULL,
  PRIMARY KEY (nodeId, seenAt)
);
```

## Remaining TODOs

1. **Hop Count Tracking**: `maxHopsForProximity=2` is defined but hop count is not yet tracked in protocol layer
2. **Cloud-to-Local Merge**: `fetchCloudSignals()` exists but not integrated into feed refresh
3. **TTL Remaining in Relayed Packets**: Consider including remaining TTL instead of original TTL when relaying
