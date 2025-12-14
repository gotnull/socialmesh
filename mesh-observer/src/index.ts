/**
 * Mesh Observer - Meshtastic MQTT Node Collector
 * 
 * This service connects to the Meshtastic public MQTT broker,
 * collects node position and telemetry data, and serves it via REST API.
 * 
 * Part of Socialmesh
 */

import express from 'express';
import cors from 'cors';
import { MqttObserver } from './mqtt-observer';
import { NodeStore } from './node-store';

const PORT = parseInt(process.env.PORT || '3001', 10);
const MQTT_BROKER = process.env.MQTT_BROKER || 'mqtt://mqtt.meshtastic.org';
// Subscribe to encrypted + json topics (msh/# causes disconnects on public broker)
const MQTT_TOPICS = (process.env.MQTT_TOPICS || 'msh/+/2/e/#,msh/+/2/json/#').split(',');
const MQTT_USERNAME = process.env.MQTT_USERNAME || 'meshdev';
const MQTT_PASSWORD = process.env.MQTT_PASSWORD || 'large4cats';
const NODE_EXPIRY_HOURS = parseInt(process.env.NODE_EXPIRY_HOURS || '24', 10);

const app = express();
app.use(cors());
app.use(express.json());

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

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    mqttConnected: mqttObserver.isConnected(),
    nodeCount: nodeStore.getNodeCount(),
    uptime: process.uptime(),
  });
});

// Get all nodes
app.get('/nodes.json', (req, res) => {
  res.json(nodeStore.getAllNodes());
});

// Get single node by nodeNum
app.get('/node/:nodeNum', (req, res) => {
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
app.get('/stats', (req, res) => {
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
app.listen(PORT, () => {
  console.log(`Mesh Observer API listening on port ${PORT}`);
  console.log(`Connecting to MQTT broker: ${MQTT_BROKER}`);
  console.log(`Subscribing to topics: ${MQTT_TOPICS.join(', ')}`);

  // Start MQTT observer
  mqttObserver.connect();
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down...');
  mqttObserver.disconnect();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down...');
  mqttObserver.disconnect();
  process.exit(0);
});
