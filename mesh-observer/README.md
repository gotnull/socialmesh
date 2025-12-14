# Mesh Observer

A self-hosted Meshtastic mesh network observer that connects to MQTT and serves node data via REST API.

## Overview

This service connects to the public Meshtastic MQTT broker (or your own) and collects node data including:

- **Position** - GPS coordinates, altitude
- **Node Info** - Long/short names, hardware model, role
- **Telemetry** - Battery level, voltage, channel utilization, air time
- **Neighbor Info** - Connected neighbors and SNR values
- **Map Reports** - Firmware version, region, modem preset

The data is served via a simple REST API.

## Quick Start

### Using Docker Compose (Recommended)

```bash
cd mesh-observer
docker-compose up -d
```

### Using Docker

```bash
docker build -t mesh-observer .
docker run -p 3001:3001 mesh-observer
```

### Manual Setup

```bash
npm install
npm run build
npm start
```

## API Endpoints

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "uptime": 12345,
  "mqtt": "connected"
}
```

### GET /nodes.json
Returns all nodes seen in the configured time window.

**Response:**
```json
{
  "nodes": [
    {
      "nodeNum": 123456789,
      "nodeId": "!075bcd15",
      "longName": "My Node",
      "shortName": "MN",
      "latitude": 37.7749,
      "longitude": -122.4194,
      "altitude": 10,
      "lastSeen": "2024-01-15T10:30:00.000Z",
      "batteryLevel": 100,
      "voltage": 4.2,
      "channelUtilization": 5.5,
      "airUtilTx": 1.2,
      "hwModel": "TBEAM",
      "role": "ROUTER",
      "region": "US",
      "modemPreset": "LONG_FAST",
      "fwVersion": "2.3.0",
      "neighbors": [...]
    }
  ],
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

### GET /node/:nodeNum
Get a specific node by node number.

**Response:**
```json
{
  "nodeNum": 123456789,
  "nodeId": "!075bcd15",
  "longName": "My Node",
  ...
}
```

### GET /stats
Returns statistics about the observer.

**Response:**
```json
{
  "totalNodes": 1234,
  "messagesReceived": 56789,
  "uptimeSeconds": 3600
}
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3001` | HTTP server port |
| `MQTT_BROKER` | `mqtt://mqtt.meshtastic.org` | MQTT broker URL |
| `MQTT_USERNAME` | (empty) | MQTT username (optional) |
| `MQTT_PASSWORD` | (empty) | MQTT password (optional) |
| `MQTT_TOPIC` | `msh/+/2/e/#` | MQTT topic pattern |
| `NODE_EXPIRY_HOURS` | `24` | Hours before nodes are considered stale |

## How It Works

1. **MQTT Connection** - Connects to the Meshtastic MQTT broker
2. **Message Parsing** - Decodes ServiceEnvelope protobuf messages
3. **Decryption** - Decrypts payloads using the default key (AQ==)
4. **Storage** - Stores node data in memory with timestamps
5. **Cleanup** - Removes stale nodes older than `NODE_EXPIRY_HOURS`
6. **API** - Serves collected data via REST endpoints

## Meshtastic MQTT Topics

The default topic pattern `msh/+/2/e/#` matches:
- `msh` - Meshtastic namespace
- `+` - Any region (US, EU, etc.)
- `2` - Protocol version 2
- `e` - Encrypted messages
- `#` - All channels and gateways

Messages on the public MQTT are typically encrypted with the default key.

## Private MQTT Setup

To use your own MQTT broker:

1. Set up an MQTT broker (Mosquitto, etc.)
2. Configure your Meshtastic nodes to use your broker
3. Update the environment variables:

```yaml
environment:
  - MQTT_BROKER=mqtt://your-broker:1883
  - MQTT_USERNAME=your-user
  - MQTT_PASSWORD=your-password
```

## Flutter App Integration

Update your Flutter app to use your self-hosted observer:

```dart
// In world_mesh_map_provider.dart or config
static const String meshApiUrl = 'http://your-server:3001';

Future<List<WorldMeshNode>> fetchNodes() async {
  final response = await http.get(Uri.parse('$meshApiUrl/nodes.json'));
  // ... parse response
}
```

## License

This project is part of the Socialmesh app.

## Credits

- [Meshtastic](https://meshtastic.org/) - The mesh networking protocol
