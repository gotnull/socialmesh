/**
 * Meshtastic Protocol Decoder
 * 
 * Decodes Meshtastic protobuf messages from MQTT.
 * Uses the official Meshtastic protobuf definitions.
 * 
 * Note: Messages on the public MQTT are typically encrypted with the
 * default key "AQ==" (base64 for 0x01). Only properly encrypted messages
 * with known keys can be decoded.
 */

import * as protobuf from 'protobufjs';
import * as crypto from 'crypto';
import * as path from 'path';

// Default Meshtastic encryption key (base64 "AQ==")
const DEFAULT_KEY = Buffer.from([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);

// Meshtastic port numbers
const PortNum = {
  UNKNOWN_APP: 0,
  TEXT_MESSAGE_APP: 1,
  REMOTE_HARDWARE_APP: 2,
  POSITION_APP: 3,
  NODEINFO_APP: 4,
  ROUTING_APP: 5,
  ADMIN_APP: 6,
  TEXT_MESSAGE_COMPRESSED_APP: 7,
  WAYPOINT_APP: 8,
  AUDIO_APP: 9,
  DETECTION_SENSOR_APP: 10,
  REPLY_APP: 32,
  IP_TUNNEL_APP: 33,
  PAXCOUNTER_APP: 34,
  SERIAL_APP: 64,
  STORE_FORWARD_APP: 65,
  RANGE_TEST_APP: 66,
  TELEMETRY_APP: 67,
  ZPS_APP: 68,
  SIMULATOR_APP: 69,
  TRACEROUTE_APP: 70,
  NEIGHBORINFO_APP: 71,
  ATAK_PLUGIN: 72,
  MAP_REPORT_APP: 73,
  PRIVATE_APP: 256,
  ATAK_FORWARDER: 257,
  MAX: 511,
};

export class MeshtasticDecoder {
  private root: protobuf.Root | null = null;
  private serviceEnvelopeType: protobuf.Type | null = null;
  private meshPacketType: protobuf.Type | null = null;
  private dataType: protobuf.Type | null = null;
  private positionType: protobuf.Type | null = null;
  private userType: protobuf.Type | null = null;
  private telemetryType: protobuf.Type | null = null;
  private neighborInfoType: protobuf.Type | null = null;
  private mapReportType: protobuf.Type | null = null;

  constructor() {
    this.loadProtos();
  }

  /**
   * Load protobuf definitions
   */
  private async loadProtos(): Promise<void> {
    try {
      // Try to load from protos directory
      const protoPath = path.join(__dirname, '..', 'protos', 'meshtastic');
      this.root = await protobuf.load([
        path.join(protoPath, 'mqtt.proto'),
        path.join(protoPath, 'mesh.proto'),
        path.join(protoPath, 'portnums.proto'),
        path.join(protoPath, 'telemetry.proto'),
      ]);

      this.serviceEnvelopeType = this.root.lookupType('meshtastic.ServiceEnvelope');
      this.meshPacketType = this.root.lookupType('meshtastic.MeshPacket');
      this.dataType = this.root.lookupType('meshtastic.Data');
      this.positionType = this.root.lookupType('meshtastic.Position');
      this.userType = this.root.lookupType('meshtastic.User');
      this.telemetryType = this.root.lookupType('meshtastic.Telemetry');
      this.neighborInfoType = this.root.lookupType('meshtastic.NeighborInfo');
      this.mapReportType = this.root.lookupType('meshtastic.MapReport');

      console.log('Protobuf definitions loaded successfully');
    } catch (err) {
      console.warn('Failed to load protobuf definitions, using manual parsing:', err);
      // Will fall back to manual parsing
    }
  }

  /**
   * Decode ServiceEnvelope from MQTT message
   */
  decodeServiceEnvelope(data: Buffer): ServiceEnvelope | null {
    if (!data || data.length === 0) return null;

    try {
      if (this.serviceEnvelopeType) {
        const decoded = this.serviceEnvelopeType.decode(data);
        return decoded as unknown as ServiceEnvelope;
      }

      // Manual parsing fallback
      return this.manualDecodeServiceEnvelope(data);
    } catch (err) {
      return null;
    }
  }

  /**
   * Manual decode ServiceEnvelope without protobuf definitions
   */
  private manualDecodeServiceEnvelope(data: Buffer): ServiceEnvelope | null {
    // Very basic protobuf parsing
    // Field 1: packet (MeshPacket)
    // Field 2: channelId (string)
    // Field 3: gatewayId (string)

    let offset = 0;
    const result: ServiceEnvelope = {};

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 2) { // Length-delimited
        let length = 0;
        let shift = 0;
        while (data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        length |= data[offset] << shift;
        offset++;

        const fieldData = data.slice(offset, offset + length);
        offset += length;

        switch (fieldNum) {
          case 1:
            result.packet = this.manualDecodeMeshPacket(fieldData);
            break;
          case 2:
            result.channelId = fieldData.toString('utf8');
            break;
          case 3:
            result.gatewayId = fieldData.toString('utf8');
            break;
        }
      } else {
        // Skip other wire types
        break;
      }
    }

    return result;
  }

  /**
   * Manual decode MeshPacket
   */
  private manualDecodeMeshPacket(data: Buffer): MeshPacket {
    const packet: MeshPacket = {};
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 0) { // Varint
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }

        switch (fieldNum) {
          case 1: packet.from = value >>> 0; break;
          case 2: packet.to = value >>> 0; break;
          case 6: packet.id = value >>> 0; break;
          case 10: packet.hopLimit = value; break;
        }
      } else if (wireType === 2) { // Length-delimited
        let length = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          length |= data[offset] << shift;
          offset++;
        }

        const fieldData = data.slice(offset, offset + length);
        offset += length;

        if (fieldNum === 3) {
          packet.encrypted = fieldData;
        } else if (fieldNum === 4) {
          packet.decoded = this.manualDecodeData(fieldData);
        }
      } else if (wireType === 5) { // 32-bit
        if (fieldNum === 11) {
          packet.rxTime = data.readUInt32LE(offset);
        }
        offset += 4;
      } else {
        break;
      }
    }

    return packet;
  }

  /**
   * Manual decode Data payload
   */
  private manualDecodeData(data: Buffer): DataPayload {
    const payload: DataPayload = { portnum: 0, payload: Buffer.alloc(0) };
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 0) { // Varint
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }

        if (fieldNum === 1) payload.portnum = value;
      } else if (wireType === 2) { // Length-delimited
        let length = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          length |= data[offset] << shift;
          offset++;
        }

        if (fieldNum === 2) {
          payload.payload = data.slice(offset, offset + length);
        }
        offset += length;
      } else {
        break;
      }
    }

    return payload;
  }

  /**
   * Decode payload based on port number
   */
  decodePayload(packet: MeshPacket): DecodedPayload | null {
    // Try to decrypt if encrypted
    if (packet.encrypted && packet.encrypted.length > 0) {
      const decrypted = this.decrypt(packet.encrypted, packet.from || 0, packet.id || 0);
      if (decrypted) {
        packet.decoded = this.manualDecodeData(decrypted);
      }
    }

    if (!packet.decoded) return null;

    const portnum = packet.decoded.portnum;
    const payload = packet.decoded.payload;

    if (!payload || payload.length === 0) return null;

    try {
      switch (portnum) {
        case PortNum.POSITION_APP:
          return {
            type: 'position',
            data: this.decodePosition(payload),
          };

        case PortNum.NODEINFO_APP:
          return {
            type: 'nodeinfo',
            data: this.decodeNodeInfo(payload),
          };

        case PortNum.TELEMETRY_APP:
          return {
            type: 'telemetry',
            data: this.decodeTelemetry(payload),
          };

        case PortNum.NEIGHBORINFO_APP:
          return {
            type: 'neighborinfo',
            data: this.decodeNeighborInfo(payload),
          };

        case PortNum.MAP_REPORT_APP:
          return {
            type: 'mapreport',
            data: this.decodeMapReport(payload),
          };

        default:
          return null;
      }
    } catch (err) {
      return null;
    }
  }

  /**
   * Decrypt encrypted payload using default key
   */
  private decrypt(encrypted: Buffer, fromNode: number, packetId: number): Buffer | null {
    try {
      // Nonce: 8 bytes packetId + 4 bytes fromNode + 4 zero bytes
      const nonce = Buffer.alloc(16);
      nonce.writeUInt32LE(packetId, 0);
      nonce.writeUInt32LE(fromNode, 8);

      // AES-128-CTR decryption
      const decipher = crypto.createDecipheriv('aes-128-ctr', DEFAULT_KEY, nonce);
      const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);

      return decrypted;
    } catch (err) {
      return null;
    }
  }

  /**
   * Decode Position message
   */
  private decodePosition(data: Buffer): any {
    if (this.positionType) {
      try {
        return this.positionType.decode(data);
      } catch { }
    }

    // Manual parsing
    const result: any = {};
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 5) { // 32-bit (sfixed32)
        const value = data.readInt32LE(offset);
        offset += 4;
        if (fieldNum === 1) result.latitudeI = value;
        else if (fieldNum === 2) result.longitudeI = value;
      } else if (wireType === 0) { // Varint
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }
        if (fieldNum === 3) result.altitude = value;
        else if (fieldNum === 12) result.precision = value;
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Decode NodeInfo/User message
   */
  private decodeNodeInfo(data: Buffer): any {
    // NodeInfo contains a User message
    const result: any = { user: {} };
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 2) {
        let length = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          length |= data[offset] << shift;
          offset++;
        }

        const fieldData = data.slice(offset, offset + length);
        offset += length;

        // User fields are strings
        if (fieldNum === 1) result.user.id = fieldData.toString('utf8');
        else if (fieldNum === 2) result.user.longName = fieldData.toString('utf8');
        else if (fieldNum === 3) result.user.shortName = fieldData.toString('utf8');
      } else if (wireType === 0) {
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }

        if (fieldNum === 6) result.user.hwModel = this.hwModelToString(value);
        else if (fieldNum === 7) result.user.role = this.roleToString(value);
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Decode Telemetry message
   */
  private decodeTelemetry(data: Buffer): any {
    const result: any = {};
    // Basic telemetry parsing - just extract device metrics
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 2 && fieldNum === 2) {
        // DeviceMetrics submessage
        let length = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          length |= data[offset] << shift;
          offset++;
        }

        result.deviceMetrics = this.decodeDeviceMetrics(data.slice(offset, offset + length));
        offset += length;
      } else if (wireType === 2 && fieldNum === 3) {
        // EnvironmentMetrics submessage
        let length = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          length |= data[offset] << shift;
          offset++;
        }

        result.environmentMetrics = this.decodeEnvironmentMetrics(data.slice(offset, offset + length));
        offset += length;
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Decode DeviceMetrics
   */
  private decodeDeviceMetrics(data: Buffer): any {
    const result: any = {};
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 0) {
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }

        if (fieldNum === 1) result.batteryLevel = value;
        else if (fieldNum === 4) result.uptimeSeconds = value;
      } else if (wireType === 5) {
        const value = data.readFloatLE(offset);
        offset += 4;
        if (fieldNum === 2) result.voltage = value;
        else if (fieldNum === 3) result.channelUtilization = value;
        else if (fieldNum === 5) result.airUtilTx = value;
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Decode EnvironmentMetrics
   */
  private decodeEnvironmentMetrics(data: Buffer): any {
    const result: any = {};
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 5) {
        const value = data.readFloatLE(offset);
        offset += 4;

        switch (fieldNum) {
          case 1: result.temperature = value; break;
          case 2: result.relativeHumidity = value; break;
          case 3: result.barometricPressure = value; break;
          case 7: result.lux = value; break;
          case 9: result.windSpeed = value; break;
          case 10: result.windGust = value; break;
          case 11: result.radiation = value; break;
          case 12: result.rainfall1h = value; break;
          case 13: result.rainfall24h = value; break;
        }
      } else if (wireType === 0) {
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }

        if (fieldNum === 8) result.windDirection = value;
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Decode NeighborInfo message
   */
  private decodeNeighborInfo(data: Buffer): any {
    const result: any = { neighbors: [] };
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 2 && fieldNum === 3) {
        // Neighbor submessage
        let length = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          length |= data[offset] << shift;
          offset++;
        }

        const neighbor = this.decodeNeighbor(data.slice(offset, offset + length));
        if (neighbor) result.neighbors.push(neighbor);
        offset += length;
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Decode single Neighbor
   */
  private decodeNeighbor(data: Buffer): any {
    const result: any = {};
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 0) {
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }

        if (fieldNum === 1) result.nodeId = value >>> 0;
      } else if (wireType === 5) {
        const value = data.readFloatLE(offset);
        offset += 4;
        if (fieldNum === 2) result.snr = value;
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Decode MapReport message
   */
  private decodeMapReport(data: Buffer): any {
    const result: any = {};
    let offset = 0;

    while (offset < data.length) {
      const tag = data[offset];
      const fieldNum = tag >> 3;
      const wireType = tag & 0x07;
      offset++;

      if (wireType === 2) {
        let length = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          length |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          length |= data[offset] << shift;
          offset++;
        }

        const fieldData = data.slice(offset, offset + length);
        offset += length;

        switch (fieldNum) {
          case 1: result.longName = fieldData.toString('utf8'); break;
          case 2: result.shortName = fieldData.toString('utf8'); break;
          case 8: result.fwVersion = fieldData.toString('utf8'); break;
        }
      } else if (wireType === 0) {
        let value = 0;
        let shift = 0;
        while (offset < data.length && data[offset] & 0x80) {
          value |= (data[offset] & 0x7f) << shift;
          shift += 7;
          offset++;
        }
        if (offset < data.length) {
          value |= data[offset] << shift;
          offset++;
        }

        switch (fieldNum) {
          case 4: result.role = this.roleToString(value); break;
          case 5: result.hwModel = this.hwModelToString(value); break;
          case 9: result.region = this.regionToString(value); break;
          case 10: result.modemPreset = this.modemPresetToString(value); break;
          case 11: result.hasDefaultChannel = value !== 0; break;
          case 14: result.onlineLocalNodes = value; break;
        }
      } else {
        break;
      }
    }

    return result;
  }

  /**
   * Convert HwModel enum to string
   */
  private hwModelToString(value: number): string {
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
      25: 'STATION_G1',
      26: 'RAK11310',
      32: 'CANARYONE',
      33: 'RP2040_LORA',
      34: 'STATION_G2',
      35: 'LORA_RELAY_V1',
      36: 'NRF52840DK',
      37: 'PPR',
      38: 'GENIEBLOCKS',
      39: 'NRF52_UNKNOWN',
      40: 'PORTDUINO',
      41: 'ANDROID_SIM',
      42: 'DIY_V1',
      43: 'NRF52840_PCA10059',
      44: 'DR_DEV',
      45: 'M5STACK',
      46: 'HELTEC_V3',
      47: 'HELTEC_WSL_V3',
      48: 'BETAFPV_2400_TX',
      49: 'BETAFPV_900_NANO_TX',
      50: 'RPI_PICO',
      51: 'HELTEC_WIRELESS_TRACKER',
      52: 'HELTEC_WIRELESS_PAPER',
      53: 'T_DECK',
      54: 'T_WATCH_S3',
      55: 'PICOMPUTER_S3',
      56: 'HELTEC_HT62',
      57: 'EBYTE_ESP32_S3',
      58: 'ESP32_S3_PICO',
      59: 'CHATTER_2',
      60: 'HELTEC_WIRELESS_PAPER_V1_0',
      61: 'HELTEC_WIRELESS_TRACKER_V1_0',
      62: 'UNPHONE',
      63: 'TD_LORAC',
      64: 'CDEBYTE_EORA_S3',
      65: 'TWC_MESH_V4',
      66: 'NRF52_PROMICRO_DIY',
      67: 'RADIOMASTER_900_BANDIT_NANO',
      68: 'HELTEC_CAPSULE_SENSOR_V3',
      69: 'HELTEC_VISION_MASTER_T190',
      70: 'HELTEC_VISION_MASTER_E213',
      71: 'HELTEC_VISION_MASTER_E290',
      72: 'HELTEC_MESH_NODE_T114',
      73: 'SENSECAP_INDICATOR',
      74: 'TRACKER_T1000_E',
      75: 'RAK3172',
      255: 'PRIVATE_HW',
    };
    return models[value] || `UNKNOWN_${value}`;
  }

  /**
   * Convert Role enum to string
   */
  private roleToString(value: number): string {
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
    };
    return roles[value] || `ROLE_${value}`;
  }

  /**
   * Convert Region enum to string
   */
  private regionToString(value: number): string {
    const regions: Record<number, string> = {
      0: 'UNSET',
      1: 'US',
      2: 'EU_433',
      3: 'EU_868',
      4: 'CN',
      5: 'JP',
      6: 'ANZ',
      7: 'KR',
      8: 'TW',
      9: 'RU',
      10: 'IN',
      11: 'NZ_865',
      12: 'TH',
      13: 'LORA_24',
      14: 'UA_433',
      15: 'UA_868',
      16: 'MY_433',
      17: 'MY_919',
      18: 'SG_923',
    };
    return regions[value] || `REGION_${value}`;
  }

  /**
   * Convert ModemPreset enum to string
   */
  private modemPresetToString(value: number): string {
    const presets: Record<number, string> = {
      0: 'LONG_FAST',
      1: 'LONG_SLOW',
      2: 'VERY_LONG_SLOW',
      3: 'MEDIUM_SLOW',
      4: 'MEDIUM_FAST',
      5: 'SHORT_SLOW',
      6: 'SHORT_FAST',
      7: 'LONG_MODERATE',
    };
    return presets[value] || `PRESET_${value}`;
  }
}

// Type definitions
export interface ServiceEnvelope {
  packet?: MeshPacket;
  channelId?: string;
  gatewayId?: string;
}

export interface MeshPacket {
  from?: number;
  to?: number;
  id?: number;
  encrypted?: Buffer;
  decoded?: DataPayload;
  hopLimit?: number;
  rxTime?: number;
}

export interface DataPayload {
  portnum: number;
  payload: Buffer;
}

export type PayloadType = 'position' | 'nodeinfo' | 'telemetry' | 'neighborinfo' | 'mapreport';

export interface DecodedPayload {
  type: PayloadType;
  data: any;
}
