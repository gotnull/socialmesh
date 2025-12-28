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
app.use(cors());
app.use(express.json());

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
