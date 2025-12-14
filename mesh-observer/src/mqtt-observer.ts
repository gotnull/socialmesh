/**
 * MQTT Observer - Connects to Meshtastic MQTT and processes messages
 * 
 * The Meshtastic public MQTT broker publishes encrypted packets.
 * Topic format: msh/{region}/2/e/{channel}/{gateway_id}
 * JSON format: msh/{region}/2/json/{channel}/{gateway_id}
 * 
 * Messages are protobuf-encoded ServiceEnvelope containing:
 * - packet: MeshPacket with encrypted or plaintext payload
 * - channelId: Channel name
 * - gatewayId: ID of the gateway that forwarded the packet
 */

import mqtt, { MqttClient, IClientOptions } from 'mqtt';
import { NodeStore, MeshNode } from './node-store';
import { MeshtasticDecoder, DecodedPayload } from './decoder';

// Stats for debugging decode success/failure
interface DecodeStats {
  totalMessages: number;
  envelopesDecoded: number;
  packetsWithFrom: number;
  decryptedSuccess: number;
  decryptedFailed: number;
  jsonMessages: number;
  positionUpdates: number;
  nodeinfoUpdates: number;
  telemetryUpdates: number;
  neighborinfoUpdates: number;
  mapreportUpdates: number;
  nodesCreated: number;
}

export class MqttObserver {
  private client: MqttClient | null = null;
  private connected: boolean = false;
  private decoder: MeshtasticDecoder;
  private username?: string;
  private password?: string;
  private stats: DecodeStats = {
    totalMessages: 0,
    envelopesDecoded: 0,
    packetsWithFrom: 0,
    decryptedSuccess: 0,
    decryptedFailed: 0,
    jsonMessages: 0,
    positionUpdates: 0,
    nodeinfoUpdates: 0,
    telemetryUpdates: 0,
    neighborinfoUpdates: 0,
    mapreportUpdates: 0,
    nodesCreated: 0,
  };
  private lastLogTime: number = 0;

  constructor(
    private brokerUrl: string,
    private topics: string[],
    private nodeStore: NodeStore,
    username?: string,
    password?: string
  ) {
    this.decoder = new MeshtasticDecoder();
    this.username = username;
    this.password = password;
  }

  /**
   * Connect to MQTT broker
   */
  connect(): void {
    const options: IClientOptions = {
      clientId: `mesh-observer-${Math.random().toString(16).substring(2, 10)}`,
      clean: true,
      connectTimeout: 30000,
      reconnectPeriod: 5000,
      username: this.username,
      password: this.password,
    };

    console.log(`Connecting to MQTT broker: ${this.brokerUrl}`);
    this.client = mqtt.connect(this.brokerUrl, options);

    this.client.on('connect', () => {
      console.log('Connected to MQTT broker');
      this.connected = true;

      // Subscribe to all configured topics
      for (const topic of this.topics) {
        console.log(`Subscribing to topic: ${topic}`);
        this.client?.subscribe(topic, { qos: 0 }, (err) => {
          if (err) {
            console.error(`Failed to subscribe to ${topic}:`, err);
          } else {
            console.log(`Subscribed to ${topic}`);
          }
        });
      }
    });

    this.client.on('message', (topic, message) => {
      this.handleMessage(topic, message);
    });

    this.client.on('error', (err) => {
      console.error('MQTT error:', err);
    });

    this.client.on('close', () => {
      console.log('MQTT connection closed');
      this.connected = false;
    });

    this.client.on('reconnect', () => {
      console.log('Reconnecting to MQTT broker...');
    });
  }

  /**
   * Handle incoming MQTT message
   */
  private handleMessage(topic: string, message: Buffer): void {
    this.stats.totalMessages++;

    // Log stats every 30 seconds
    const now = Date.now();
    if (now - this.lastLogTime > 30000) {
      this.logStats();
      this.lastLogTime = now;
    }

    try {
      // Check if JSON topic
      if (topic.includes('/json/')) {
        this.handleJsonMessage(topic, message);
        return;
      }

      // Handle protobuf message
      this.handleProtobufMessage(topic, message);
    } catch (err) {
      // Silently ignore decode errors - many messages are encrypted with custom keys
    }
  }

  /**
   * Handle JSON formatted message
   */
  private handleJsonMessage(topic: string, message: Buffer): void {
    this.stats.jsonMessages++;

    try {
      const json = JSON.parse(message.toString('utf8'));

      // JSON messages have a different structure
      // They contain: type, payload, sender, channel, etc.
      const nodeNum = this.parseNodeId(json.sender || json.from);
      if (!nodeNum) return;

      const update: Partial<MeshNode> = {};

      // Handle based on message type
      if (json.type === 'nodeinfo' && json.payload) {
        const p = json.payload;
        if (p.longname) update.longName = p.longname;
        if (p.shortname) update.shortName = p.shortname;
        if (p.hardware) update.hwModel = p.hardware;
        this.stats.nodeinfoUpdates++;
      } else if (json.type === 'position' && json.payload) {
        const p = json.payload;
        if (p.latitude_i !== undefined) update.latitude = p.latitude_i;
        if (p.longitude_i !== undefined) update.longitude = p.longitude_i;
        if (p.altitude !== undefined) update.altitude = p.altitude;
        this.stats.positionUpdates++;
      } else if (json.type === 'telemetry' && json.payload) {
        const dm = json.payload.device_metrics || json.payload;
        if (dm.battery_level !== undefined) update.batteryLevel = dm.battery_level;
        if (dm.voltage !== undefined) update.voltage = dm.voltage;
        if (dm.channel_utilization !== undefined) update.chUtil = dm.channel_utilization;
        if (dm.air_util_tx !== undefined) update.airUtilTx = dm.air_util_tx;
        this.stats.telemetryUpdates++;
      }

      if (Object.keys(update).length > 0) {
        const prevCount = this.nodeStore.getNodeCount();
        this.nodeStore.updateNode(nodeNum, update, topic);
        if (this.nodeStore.getNodeCount() > prevCount) {
          this.stats.nodesCreated++;
          console.log(`✨ New node from JSON: ${nodeNum.toString(16)} (${update.shortName || update.longName || 'unknown'})`);
        }
      }
    } catch (err) {
      // Invalid JSON - ignore
    }
  }

  /**
   * Handle protobuf formatted message
   */
  private handleProtobufMessage(topic: string, message: Buffer): void {
    // Parse the ServiceEnvelope
    const envelope = this.decoder.decodeServiceEnvelope(message);
    if (!envelope) return;
    this.stats.envelopesDecoded++;

    const { packet } = envelope;
    if (!packet) return;

    // Extract sender node info
    const fromNode = packet.from;
    if (!fromNode) return;
    this.stats.packetsWithFrom++;

    // Try to decode the payload based on port number
    const decoded = this.decoder.decodePayload(packet);
    if (!decoded) {
      this.stats.decryptedFailed++;
      return;
    }
    this.stats.decryptedSuccess++;

    // Update node store based on decoded data
    this.updateNodeFromDecoded(fromNode, decoded, topic);
  }

  /**
   * Parse node ID from various formats
   */
  private parseNodeId(id: string | number | undefined): number | null {
    if (!id) return null;
    if (typeof id === 'number') return id;

    // Handle !hexid format
    if (id.startsWith('!')) {
      return parseInt(id.substring(1), 16);
    }
    // Try parsing as hex
    const num = parseInt(id, 16);
    if (!isNaN(num)) return num;

    return null;
  }

  /**
   * Update node store from decoded message
   */
  private updateNodeFromDecoded(
    nodeNum: number,
    decoded: DecodedPayload,
    topic: string
  ): void {
    const update: Partial<MeshNode> = {};

    switch (decoded.type) {
      case 'position':
        if (decoded.data.latitudeI !== undefined) {
          update.latitude = decoded.data.latitudeI;
        }
        if (decoded.data.longitudeI !== undefined) {
          update.longitude = decoded.data.longitudeI;
        }
        if (decoded.data.altitude !== undefined) {
          update.altitude = decoded.data.altitude;
        }
        if (decoded.data.precision !== undefined) {
          update.precision = decoded.data.precision;
        }
        this.stats.positionUpdates++;
        break;

      case 'nodeinfo':
        if (decoded.data.user) {
          const user = decoded.data.user;
          if (user.longName) update.longName = user.longName;
          if (user.shortName) update.shortName = user.shortName;
          if (user.hwModel) update.hwModel = user.hwModel;
          if (user.role) update.role = user.role;
        }
        this.stats.nodeinfoUpdates++;
        break;

      case 'telemetry':
        if (decoded.data.deviceMetrics) {
          const dm = decoded.data.deviceMetrics;
          if (dm.batteryLevel !== undefined) update.batteryLevel = dm.batteryLevel;
          if (dm.voltage !== undefined) update.voltage = dm.voltage;
          if (dm.channelUtilization !== undefined) update.chUtil = dm.channelUtilization;
          if (dm.airUtilTx !== undefined) update.airUtilTx = dm.airUtilTx;
          if (dm.uptimeSeconds !== undefined) update.uptime = dm.uptimeSeconds;
          update.lastDeviceMetrics = Math.floor(Date.now() / 1000);
        }
        if (decoded.data.environmentMetrics) {
          const em = decoded.data.environmentMetrics;
          if (em.temperature !== undefined) update.temperature = em.temperature;
          if (em.relativeHumidity !== undefined) update.relativeHumidity = em.relativeHumidity;
          if (em.barometricPressure !== undefined) update.barometricPressure = em.barometricPressure;
          if (em.lux !== undefined) update.lux = em.lux;
          if (em.windDirection !== undefined) update.windDirection = em.windDirection;
          if (em.windSpeed !== undefined) update.windSpeed = em.windSpeed;
          if (em.windGust !== undefined) update.windGust = em.windGust;
          if (em.radiation !== undefined) update.radiation = em.radiation;
          if (em.rainfall1h !== undefined) update.rainfall1 = em.rainfall1h;
          if (em.rainfall24h !== undefined) update.rainfall24 = em.rainfall24h;
          update.lastEnvironmentMetrics = Math.floor(Date.now() / 1000);
        }
        this.stats.telemetryUpdates++;
        break;

      case 'neighborinfo':
        if (decoded.data.neighbors) {
          update.neighbors = {};
          for (const neighbor of decoded.data.neighbors) {
            if (neighbor.nodeId) {
              update.neighbors[neighbor.nodeId.toString(16)] = {
                snr: neighbor.snr,
                updated: Math.floor(Date.now() / 1000),
              };
            }
          }
        }
        this.stats.neighborinfoUpdates++;
        break;

      case 'mapreport':
        if (decoded.data.longName) update.longName = decoded.data.longName;
        if (decoded.data.shortName) update.shortName = decoded.data.shortName;
        if (decoded.data.hwModel) update.hwModel = decoded.data.hwModel;
        if (decoded.data.role) update.role = decoded.data.role;
        if (decoded.data.fwVersion) update.fwVersion = decoded.data.fwVersion;
        if (decoded.data.region) update.region = decoded.data.region;
        if (decoded.data.modemPreset) update.modemPreset = decoded.data.modemPreset;
        if (decoded.data.hasDefaultChannel !== undefined) update.hasDefaultCh = decoded.data.hasDefaultChannel;
        if (decoded.data.onlineLocalNodes !== undefined) update.onlineLocalNodes = decoded.data.onlineLocalNodes;
        update.lastMapReport = Math.floor(Date.now() / 1000);
        this.stats.mapreportUpdates++;
        break;
    }

    // Only update if we have something meaningful
    if (Object.keys(update).length > 0) {
      const prevCount = this.nodeStore.getNodeCount();
      this.nodeStore.updateNode(nodeNum, update, topic);
      if (this.nodeStore.getNodeCount() > prevCount) {
        this.stats.nodesCreated++;
        console.log(`✨ New node: ${nodeNum.toString(16)} - ${decoded.type} (${update.shortName || update.longName || 'unknown'})`);
      }
    }
  }

  /**
   * Log decode stats
   */
  private logStats(): void {
    const s = this.stats;
    console.log(`📊 Stats: msgs=${s.totalMessages} envelopes=${s.envelopesDecoded} packets=${s.packetsWithFrom} decoded=${s.decryptedSuccess} failed=${s.decryptedFailed} json=${s.jsonMessages}`);
    console.log(`   Updates: position=${s.positionUpdates} nodeinfo=${s.nodeinfoUpdates} telemetry=${s.telemetryUpdates} neighbors=${s.neighborinfoUpdates} mapreport=${s.mapreportUpdates}`);
    console.log(`   Nodes: total=${this.nodeStore.getNodeCount()} new=${s.nodesCreated}`);
  }

  /**
   * Check if connected
   */
  isConnected(): boolean {
    return this.connected;
  }

  /**
   * Get message count
   */
  getMessageCount(): number {
    return this.stats.totalMessages;
  }

  /**
   * Get detailed stats
   */
  getStats(): DecodeStats {
    return { ...this.stats };
  }

  /**
   * Disconnect from broker
   */
  disconnect(): void {
    this.client?.end();
    this.connected = false;
  }
}
