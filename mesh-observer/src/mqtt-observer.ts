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

      // Extract region and modemPreset from topic
      // Topic format: msh/{region}/2/json/{modemPreset}/!{nodeId}
      const topicParts = topic.split('/');
      if (topicParts.length >= 5) {
        const region = topicParts[1];
        const modemPreset = topicParts[4];
        if (region && region !== '+' && region !== '#') {
          update.region = region;
        }
        if (modemPreset && modemPreset !== '+' && modemPreset !== '#' && !modemPreset.startsWith('!')) {
          update.modemPreset = modemPreset;
        }
      }

      // Handle based on message type
      if (json.type === 'nodeinfo' && json.payload) {
        const p = json.payload;
        if (p.longname) update.longName = p.longname;
        if (p.shortname) update.shortName = p.shortname;
        if (p.hardware) update.hwModel = this.hwModelNumToString(p.hardware);
        // Role can be in payload as 'role' (string or number)
        if (p.role !== undefined) {
          update.role = typeof p.role === 'string' ? p.role : this.roleNumToString(p.role);
        }
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

  /**
   * Convert role number to string
   */
  private roleNumToString(num: number): string {
    const roles: Record<number, string> = {
      0: 'CLIENT',
      1: 'CLIENT_MUTE',
      2: 'ROUTER',
      3: 'ROUTER_CLIENT',
      4: 'REPEATER',
      5: 'TRACKER',
      6: 'SENSOR',
      7: 'TAK',
      8: 'CLIENT_HIDDEN',
      9: 'LOST_AND_FOUND',
      10: 'TAK_TRACKER',
      11: 'ROUTER_LATE',
      12: 'UNSET',
    };
    return roles[num] || `ROLE_${num}`;
  }

  /**
   * Convert hardware model number to string
   */
  private hwModelNumToString(num: number | string): string {
    if (typeof num === 'string') return num;
    // Handle potential float values
    const intNum = Math.round(num);
    const models: Record<number, string> = {
      0: 'UNSET',
      1: 'TLORA_V2',
      2: 'TLORA_V1',
      3: 'TLORA_V2_1_1P6',
      4: 'TBEAM',
      5: 'HELTEC_V2_0',
      6: 'TBEAM_V0P7',
      7: 'T_ECHO',
      8: 'TLORA_V1_1P3',
      9: 'RAK4631',
      10: 'HELTEC_V2_1',
      11: 'HELTEC_V1',
      12: 'LILYGO_TBEAM_S3_CORE',
      13: 'RAK11200',
      14: 'NANO_G1',
      15: 'TLORA_V2_1_1P8',
      16: 'TLORA_T3_S3',
      17: 'NANO_G1_EXPLORER',
      18: 'NANO_G2_ULTRA',
      19: 'LORA_TYPE',
      20: 'WIPHONE',
      21: 'WIO_WM1110',
      22: 'RAK2560',
      23: 'HELTEC_HRU_3601',
      24: 'STATION_G1',
      25: 'RAK11310',
      26: 'SENSELORA_RP2040',
      27: 'SENSELORA_S3',
      28: 'CANARYONE',
      29: 'RP2040_LORA',
      30: 'STATION_G2',
      31: 'LORA_RELAY_V1',
      32: 'NRF52840DK',
      33: 'PPR',
      34: 'GENIEBLOCKS',
      35: 'NRF52_UNKNOWN',
      36: 'PORTDUINO',
      37: 'ANDROID_SIM',
      38: 'DIY_V1',
      39: 'NRF52840_PCA10059',
      40: 'DR_DEV',
      41: 'M5STACK',
      42: 'HELTEC_V3',
      43: 'HELTEC_WSL_V3',
      44: 'BETAFPV_2400_TX',
      45: 'BETAFPV_900_NANO_TX',
      46: 'RPI_PICO',
      47: 'HELTEC_WIRELESS_TRACKER',
      48: 'HELTEC_WIRELESS_PAPER',
      49: 'T_DECK',
      50: 'T_WATCH_S3',
      51: 'PICOMPUTER_S3',
      52: 'HELTEC_HT62',
      53: 'EBYTE_ESP32_S3',
      54: 'ESP32_S3_PICO',
      55: 'CHATTER_2',
      56: 'HELTEC_WIRELESS_PAPER_V1_0',
      57: 'HELTEC_WIRELESS_TRACKER_V1_0',
      58: 'UNPHONE',
      59: 'TD_LORAC',
      60: 'CDEBYTE_EORA_S3',
      61: 'TWC_MESH_V4',
      62: 'NRF52_PROMICRO_DIY',
      63: 'RADIOMASTER_900_BANDIT_NANO',
      64: 'HELTEC_CAPSULE_SENSOR_V3',
      65: 'HELTEC_VISION_MASTER_T190',
      66: 'HELTEC_VISION_MASTER_E213',
      67: 'HELTEC_VISION_MASTER_E290',
      68: 'HELTEC_MESH_NODE_T114',
      69: 'SENSECAP_INDICATOR',
      70: 'TRACKER_T1000_E',
      71: 'RAK3172',
      72: 'WIO_E5',
      73: 'RADIOMASTER_900_BANDIT',
      74: 'ME25LS01_4Y10TD',
      75: 'RP2040_FEATHER_RFM95',
      76: 'M5STACK_COREBASIC',
      77: 'M5STACK_CORE2',
      78: 'TLORA_C6',
      79: 'SEEED_XIAO_S3',
      80: 'MS_S24',
      81: 'MS24_MINI',
      82: 'WISMESH_TAP',
      83: 'PRIVATE_HW_OLD',
      84: 'RPI_PICO2',
      85: 'MESHLINK',
      86: 'MESHLINK_MINI',
      87: 'WISMESH_POCKET',
      88: 'WISMESH_STICK',
      89: 'EBP_NOMAD',
      90: 'HELTEC_LITE_V3',
      110: 'RASPIAUDIO_MINIA',
      255: 'PRIVATE_HW',
    };
    return models[intNum] || `HW_${intNum}`;
  }
}
