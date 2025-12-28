/**
 * Mesh Observer - Meshtastic MQTT Node Collector
 * 
 * This service connects to the Meshtastic public MQTT broker,
 * collects node position and telemetry data, and serves it via REST API.
 * 
 * Part of Socialmesh
 */

import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { MqttObserver } from './mqtt-observer';
import { NodeStore } from './node-store';

const PORT = parseInt(process.env.PORT || '3001', 10);
const MQTT_BROKER = process.env.MQTT_BROKER || 'mqtt://mqtt.meshtastic.org';
// Subscribe to encrypted + json topics (msh/# causes disconnects on public broker)
const MQTT_TOPICS = (process.env.MQTT_TOPICS || 'msh/+/2/e/#,msh/+/2/json/#').split(',');
const MQTT_USERNAME = process.env.MQTT_USERNAME || 'meshdev';
const MQTT_PASSWORD = process.env.MQTT_PASSWORD || 'large4cats';
const NODE_EXPIRY_HOURS = parseInt(process.env.NODE_EXPIRY_HOURS || '24', 10);
const NODE_PURGE_DAYS = parseInt(process.env.NODE_PURGE_DAYS || '30', 10);

const app = express();

// Security headers
app.use(helmet({
  contentSecurityPolicy: false, // Allow API responses
  crossOriginEmbedderPolicy: false,
}));

// Gzip compression for responses
app.use(compression());

// Trust proxy (Railway runs behind proxy)
app.set('trust proxy', 1);

app.use(cors());
app.use(express.json({ limit: '1mb' })); // Limit body size

// Rate limiting - 100 requests per minute per IP
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100, // 100 requests per minute
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
});
app.use(limiter);

// Request logging
app.use((req: Request, _res: Response, next: NextFunction) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Initialize node store
const nodeStore = new NodeStore(NODE_EXPIRY_HOURS);

// Initialize MQTT observer with credentials (multiple topics)
const mqttObserver = new MqttObserver(
  MQTT_BROKER,
  MQTT_TOPICS,
  nodeStore,
  MQTT_USERNAME,
  MQTT_PASSWORD
);

// API Documentation (root endpoint)
app.get('/', (req, res) => {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Socialmesh API — Real-time Meshtastic Mesh Data</title>
  <meta name="description" content="Real-time Meshtastic mesh network data API. Access global node positions, telemetry, and network statistics.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-primary: #1F2633;
      --bg-secondary: #29303D;
      --bg-card: #29303D;
      --border-color: #414A5A;
      --accent-magenta: #E91E8C;
      --accent-purple: #8B5CF6;
      --accent-blue: #4F6AF6;
      --success: #4ADE80;
      --text-primary: #FFFFFF;
      --text-secondary: #D1D5DB;
      --text-muted: #9CA3AF;
      --gradient-brand: linear-gradient(135deg, #E91E8C 0%, #8B5CF6 50%, #4F6AF6 100%);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { 
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background: var(--bg-primary);
      color: var(--text-primary);
      min-height: 100vh;
      line-height: 1.6;
    }
    /* Animated mesh background */
    .mesh-bg {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: -1;
      overflow: hidden;
      background: var(--bg-primary);
    }
    .mesh-bg::before {
      content: '';
      position: absolute;
      top: -50%; left: -50%;
      width: 200%; height: 200%;
      background:
        radial-gradient(circle at 20% 20%, rgba(233, 30, 140, 0.15) 0%, transparent 40%),
        radial-gradient(circle at 80% 80%, rgba(139, 92, 246, 0.12) 0%, transparent 40%),
        radial-gradient(circle at 60% 30%, rgba(79, 106, 246, 0.1) 0%, transparent 35%);
      animation: meshFloat 25s ease-in-out infinite;
    }
    @keyframes meshFloat {
      0%, 100% { transform: translate(0, 0) rotate(0deg); }
      25% { transform: translate(3%, 2%) rotate(2deg); }
      50% { transform: translate(1%, -2%) rotate(-1deg); }
      75% { transform: translate(-2%, 1%) rotate(1deg); }
    }
    .grid-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: -1;
      background-image:
        linear-gradient(rgba(233, 30, 140, 0.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(233, 30, 140, 0.03) 1px, transparent 1px);
      background-size: 80px 80px;
      mask-image: radial-gradient(ellipse at center, black 0%, transparent 75%);
    }
    .container { max-width: 900px; margin: 0 auto; padding: 60px 24px; }
    .header { text-align: center; margin-bottom: 60px; }
    .logo { 
      display: inline-flex; 
      align-items: center; 
      gap: 16px; 
      margin-bottom: 24px;
      text-decoration: none;
    }
    .logo-icon {
      width: 56px; height: 56px;
      background: var(--gradient-brand);
      border-radius: 14px;
      display: flex; align-items: center; justify-content: center;
      font-size: 28px;
      box-shadow: 0 8px 32px rgba(233, 30, 140, 0.3);
    }
    .logo-text {
      font-family: 'JetBrains Mono', monospace;
      font-size: 28px;
      font-weight: 700;
      color: var(--text-primary);
    }
    h1 { 
      font-size: 3rem; 
      font-weight: 700;
      margin-bottom: 16px;
      letter-spacing: -1px;
    }
    .gradient-text {
      background: var(--gradient-brand);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .subtitle { 
      color: var(--text-secondary); 
      font-size: 1.1rem;
      max-width: 600px;
      margin: 0 auto 32px;
    }
    .status { 
      display: inline-flex; 
      align-items: center; 
      gap: 10px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      padding: 12px 24px;
      border-radius: 100px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 14px;
    }
    .status-dot { 
      width: 10px; height: 10px; 
      background: var(--success); 
      border-radius: 50%;
      box-shadow: 0 0 12px var(--success);
      animation: pulse 2s infinite;
    }
    @keyframes pulse { 
      0%, 100% { opacity: 1; box-shadow: 0 0 12px var(--success); } 
      50% { opacity: 0.7; box-shadow: 0 0 20px var(--success); } 
    }
    .endpoints { margin-bottom: 48px; }
    .section-title {
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 2px;
      color: var(--accent-magenta);
      margin-bottom: 24px;
    }
    .endpoint { 
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 16px;
      transition: all 0.3s ease;
    }
    .endpoint:hover {
      border-color: var(--accent-purple);
      box-shadow: 0 8px 32px rgba(139, 92, 246, 0.15);
      transform: translateY(-2px);
    }
    .endpoint-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
    .method { 
      background: var(--gradient-brand);
      color: white;
      font-family: 'JetBrains Mono', monospace;
      font-weight: 600;
      padding: 6px 14px;
      border-radius: 8px;
      font-size: 12px;
    }
    .path { 
      font-family: 'JetBrains Mono', monospace;
      color: var(--text-primary);
      font-size: 1rem;
      font-weight: 500;
    }
    .path a { 
      color: var(--text-primary); 
      text-decoration: none;
      transition: color 0.2s;
    }
    .path a:hover { color: var(--accent-magenta); }
    .desc { color: var(--text-secondary); font-size: 14px; line-height: 1.7; }
    .example { 
      background: var(--bg-primary);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 16px;
      margin-top: 16px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      overflow-x: auto;
    }
    .example-label { 
      color: var(--text-muted); 
      font-size: 11px; 
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 8px; 
    }
    .example code { color: var(--text-secondary); }
    .schema-section { margin-top: 48px; }
    .schema-code {
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 24px;
    }
    .schema-code pre {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      color: var(--text-secondary);
      line-height: 1.8;
      white-space: pre;
      overflow-x: auto;
    }
    .schema-code .comment { color: var(--text-muted); }
    .schema-code .key { color: var(--accent-magenta); }
    .schema-code .value { color: var(--accent-purple); }
    .schema-code .number { color: var(--accent-blue); }
    .footer { 
      text-align: center; 
      padding-top: 48px;
      border-top: 1px solid var(--border-color);
      color: var(--text-muted);
      font-size: 14px;
    }
    .footer a { 
      color: var(--accent-magenta); 
      text-decoration: none;
      transition: color 0.2s;
    }
    .footer a:hover { color: var(--accent-purple); }
    .footer-links { 
      display: flex; 
      justify-content: center; 
      gap: 24px; 
      margin-bottom: 16px;
    }
    .rate-limit {
      display: inline-block;
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      padding: 8px 16px;
      border-radius: 8px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      margin-top: 16px;
    }
  </style>
</head>
<body>
  <div class="mesh-bg"></div>
  <div class="grid-overlay"></div>
  
  <div class="container">
    <header class="header">
      <a href="https://socialmesh.app" class="logo">
        <div class="logo-icon">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
            <circle cx="12" cy="5" r="2"/>
            <circle cx="5" cy="19" r="2"/>
            <circle cx="19" cy="19" r="2"/>
            <line x1="12" y1="7" x2="5" y2="17"/>
            <line x1="12" y1="7" x2="19" y2="17"/>
            <line x1="5" y1="19" x2="19" y2="19"/>
          </svg>
        </div>
        <span class="logo-text">Socialmesh</span>
      </a>
      
      <h1>Mesh Network <span class="gradient-text">API</span></h1>
      <p class="subtitle">Real-time Meshtastic mesh network data from the global MQTT feed. Access node positions, telemetry, battery levels, and network topology.</p>
      
      <div class="status">
        <span class="status-dot"></span>
        <span>Live • ${nodeStore.getNodeCount()} nodes tracked</span>
      </div>
    </header>

    <section class="endpoints">
      <div class="section-title">Endpoints</div>
      
      <div class="endpoint">
        <div class="endpoint-header">
          <span class="method">GET</span>
          <span class="path"><a href="/health">/health</a></span>
        </div>
        <p class="desc">Health check endpoint. Returns service status, MQTT connection state, node count, memory usage, and uptime. Returns HTTP 503 if service is degraded.</p>
        <div class="example">
          <div class="example-label">Response</div>
          <code>{ "status": "ok", "mqttConnected": true, "nodeCount": ${nodeStore.getNodeCount()}, "uptime": ${Math.round(process.uptime())} }</code>
        </div>
      </div>

      <div class="endpoint">
        <div class="endpoint-header">
          <span class="method">GET</span>
          <span class="path"><a href="/api/nodes">/api/nodes</a></span>
        </div>
        <p class="desc">Get all tracked mesh nodes. Returns a map of node IDs to node objects containing position, telemetry, battery level, hardware info, neighbors, and more.</p>
        <div class="example">
          <div class="example-label">Response</div>
          <code>{ "3677891234": { "nodeNum": 3677891234, "longName": "Base Station", "latitude": 37.77, ... } }</code>
        </div>
      </div>

      <div class="endpoint">
        <div class="endpoint-header">
          <span class="method">GET</span>
          <span class="path">/api/node/:nodeNum</span>
        </div>
        <p class="desc">Get a single node by its numeric ID. Returns the full node object or HTTP 404 if not found.</p>
        <div class="example">
          <div class="example-label">Example</div>
          <code>GET /api/node/3677891234</code>
        </div>
      </div>

      <div class="endpoint">
        <div class="endpoint-header">
          <span class="method">GET</span>
          <span class="path"><a href="/api/stats">/api/stats</a></span>
        </div>
        <p class="desc">Get detailed statistics about MQTT message processing, decode success rates, and node update counts by type (position, telemetry, nodeinfo, etc).</p>
      </div>
    </section>

    <section class="schema-section">
      <div class="section-title">Node Schema</div>
      <div class="schema-code">
        <pre>{
  <span class="key">"nodeNum"</span>: <span class="number">3677891234</span>,       <span class="comment">// Unique node ID (from hardware)</span>
  <span class="key">"longName"</span>: <span class="value">"Base Station"</span>,  <span class="comment">// User-configured name</span>
  <span class="key">"shortName"</span>: <span class="value">"BASE"</span>,         <span class="comment">// 4-character identifier</span>
  <span class="key">"hwModel"</span>: <span class="value">"TBEAM"</span>,          <span class="comment">// Hardware model</span>
  <span class="key">"role"</span>: <span class="value">"ROUTER"</span>,            <span class="comment">// Node role (CLIENT, ROUTER, etc)</span>
  <span class="key">"latitude"</span>: <span class="number">37.7749</span>,         <span class="comment">// GPS latitude</span>
  <span class="key">"longitude"</span>: <span class="number">-122.4194</span>,      <span class="comment">// GPS longitude</span>
  <span class="key">"altitude"</span>: <span class="number">15</span>,              <span class="comment">// Altitude in meters</span>
  <span class="key">"batteryLevel"</span>: <span class="number">87</span>,          <span class="comment">// Battery percentage (0-100)</span>
  <span class="key">"voltage"</span>: <span class="number">4.1</span>,              <span class="comment">// Battery voltage</span>
  <span class="key">"chUtil"</span>: <span class="number">12.5</span>,              <span class="comment">// Channel utilization %</span>
  <span class="key">"airUtilTx"</span>: <span class="number">2.3</span>,            <span class="comment">// TX air time %</span>
  <span class="key">"temperature"</span>: <span class="number">23.5</span>,         <span class="comment">// Environment temperature °C</span>
  <span class="key">"region"</span>: <span class="value">"US"</span>,              <span class="comment">// LoRa region code</span>
  <span class="key">"modemPreset"</span>: <span class="value">"LongFast"</span>,   <span class="comment">// Modem configuration</span>
  <span class="key">"lastHeard"</span>: <span class="number">1735489234</span>,     <span class="comment">// Unix timestamp of last contact</span>
  <span class="key">"seenBy"</span>: { ... },           <span class="comment">// Gateways that received this node</span>
  <span class="key">"neighbors"</span>: { ... }         <span class="comment">// Nearby nodes with SNR values</span>
}</pre>
      </div>
    </section>

    <footer class="footer">
      <div class="footer-links">
        <a href="https://socialmesh.app">Socialmesh App</a>
        <a href="https://meshtastic.org">Meshtastic</a>
        <a href="https://github.com/gotnull/socialmesh">GitHub</a>
      </div>
      <p>Powered by the global Meshtastic MQTT network</p>
      <div class="rate-limit">Rate limit: 100 requests/minute per IP</div>
    </footer>
  </div>
</body>
</html>`;

  res.type('html').send(html);
});

// Health check endpoint (detailed)
app.get('/health', (req, res) => {
  const memUsage = process.memoryUsage();
  const mqttConnected = mqttObserver.isConnected();
  const nodeCount = nodeStore.getNodeCount();

  // Consider unhealthy if MQTT disconnected or memory > 500MB
  const isHealthy = mqttConnected && memUsage.heapUsed < 500 * 1024 * 1024;

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'ok' : 'degraded',
    mqttConnected,
    nodeCount,
    uptime: process.uptime(),
    memory: {
      heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB',
      heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024) + 'MB',
      rss: Math.round(memUsage.rss / 1024 / 1024) + 'MB',
    },
    version: process.env.npm_package_version || '1.0.0',
  });
});

// Get all nodes
app.get('/api/nodes', (req, res) => {
  res.json(nodeStore.getAllNodes());
});

// Get single node by nodeNum
app.get('/api/node/:nodeNum', (req, res) => {
  const nodeNum = parseInt(req.params.nodeNum, 10);
  if (isNaN(nodeNum)) {
    return res.status(400).json({ error: 'Invalid node number' });
  }

  const node = nodeStore.getNode(nodeNum);
  if (!node) {
    return res.status(404).json({ error: 'Node not found' });
  }

  res.json(node);
});

// Get statistics
app.get('/api/stats', (req, res) => {
  const decodeStats = mqttObserver.getStats();
  res.json({
    totalNodes: nodeStore.getNodeCount(),
    nodesWithPosition: nodeStore.getNodesWithPositionCount(),
    onlineNodes: nodeStore.getOnlineNodeCount(),
    messagesReceived: decodeStats.totalMessages,
    lastUpdate: nodeStore.getLastUpdateTime(),
    decode: {
      envelopesDecoded: decodeStats.envelopesDecoded,
      packetsWithFrom: decodeStats.packetsWithFrom,
      decryptedSuccess: decodeStats.decryptedSuccess,
      decryptedFailed: decodeStats.decryptedFailed,
      jsonMessages: decodeStats.jsonMessages,
    },
    updates: {
      position: decodeStats.positionUpdates,
      nodeinfo: decodeStats.nodeinfoUpdates,
      telemetry: decodeStats.telemetryUpdates,
      neighborinfo: decodeStats.neighborinfoUpdates,
      mapreport: decodeStats.mapreportUpdates,
      nodesCreated: decodeStats.nodesCreated,
    },
  });
});

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found' });
});

// Global error handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`Mesh Observer API listening on port ${PORT}`);
  console.log(`Connecting to MQTT broker: ${MQTT_BROKER}`);
  console.log(`Subscribing to topics: ${MQTT_TOPICS.join(', ')}`);

  // Start MQTT observer
  mqttObserver.connect();
});

// Periodic node purge (every 6 hours)
const purgeInterval = setInterval(() => {
  console.log(`Running node purge (removing nodes older than ${NODE_PURGE_DAYS} days)...`);
  const purged = nodeStore.purgeOldNodes(NODE_PURGE_DAYS);
  if (purged > 0) {
    console.log(`Purged ${purged} stale nodes`);
  }
}, 6 * 60 * 60 * 1000);

// Graceful shutdown
const shutdown = (signal: string) => {
  console.log(`Received ${signal}, shutting down gracefully...`);

  // Stop accepting new connections
  server.close(() => {
    console.log('HTTP server closed');
  });

  // Clear purge interval
  clearInterval(purgeInterval);

  // Disconnect MQTT and flush database
  mqttObserver.disconnect();
  nodeStore.dispose();

  console.log('Cleanup complete, exiting');
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Handle uncaught errors
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  shutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled rejection at:', promise, 'reason:', reason);
});
