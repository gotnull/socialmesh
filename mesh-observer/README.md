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
| `MQTT_USERNAME` | `meshdev` | MQTT username |
| `MQTT_PASSWORD` | `large4cats` | MQTT password |
| `MQTT_TOPICS` | `msh/+/2/e/#,msh/+/2/json/#` | MQTT topic patterns |
| `NODE_EXPIRY_HOURS` | `24` | Hours before nodes are considered stale |

## Cloud Deployment

### Railway (Recommended - $5-20/month)

1. **Install Railway CLI:**
   ```bash
   npm install -g @railway/cli
   railway login
   ```

2. **Deploy from mesh-observer directory:**
   ```bash
   cd mesh-observer
   railway init
   railway up
   ```

3. **Add persistent volume for SQLite:**
   - Go to Railway dashboard → Your project → Settings
   - Add a Volume, mount path: `/app/data`

4. **Get your URL:**
   - Railway provides a URL like `mesh-observer-xxx.up.railway.app`
   - Update your DNS: `api.socialmesh.app` → Railway URL

### Fly.io (Alternative - $5-15/month)

1. **Install Fly CLI:**
   ```bash
   curl -L https://fly.io/install.sh | sh
   fly auth login
   ```

2. **Create fly.toml:**
   ```toml
   app = "socialmesh-mesh-observer"
   primary_region = "sjc"
   
   [build]
     dockerfile = "Dockerfile"
   
   [http_service]
     internal_port = 3001
     force_https = true
   
   [mounts]
     source = "mesh_data"
     destination = "/app/data"
   ```

3. **Deploy:**
   ```bash
   cd mesh-observer
   fly launch --no-deploy
   fly volumes create mesh_data --size 1
   fly deploy
   ```

### Update DNS

After deployment, update your DNS:
- `api.socialmesh.app` CNAME → `your-railway-url.up.railway.app`

Or update `.env` in the Flutter app:
```
WORLD_MESH_API_URL=https://your-deployed-url.up.railway.app
```

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
