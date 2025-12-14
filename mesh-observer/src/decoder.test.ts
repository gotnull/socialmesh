import { MeshtasticDecoder } from './decoder';

describe('MeshtasticDecoder', () => {
  let decoder: MeshtasticDecoder;

  beforeEach(() => {
    decoder = new MeshtasticDecoder();
  });

  describe('decodeServiceEnvelope', () => {
    it('should return null for empty buffer', () => {
      const result = decoder.decodeServiceEnvelope(Buffer.alloc(0));
      expect(result).toBeNull();
    });

    it('should return null for null input', () => {
      const result = decoder.decodeServiceEnvelope(null as any);
      expect(result).toBeNull();
    });

    it('should handle malformed protobuf gracefully', () => {
      const malformed = Buffer.from([0xff, 0xff, 0xff, 0xff]);
      const result = decoder.decodeServiceEnvelope(malformed);
      // Should not throw, may return partial result or null
      expect(() => decoder.decodeServiceEnvelope(malformed)).not.toThrow();
    });

    it('should decode a valid ServiceEnvelope structure', () => {
      // Minimal valid ServiceEnvelope with just channelId field (field 2, wire type 2)
      // Field 2, wire type 2 (length-delimited) = 0x12
      // Length 8
      // "LongFast" = 0x4c 0x6f 0x6e 0x67 0x46 0x61 0x73 0x74
      const envelope = Buffer.from([
        0x12, 0x08, 0x4c, 0x6f, 0x6e, 0x67, 0x46, 0x61, 0x73, 0x74
      ]);

      const result = decoder.decodeServiceEnvelope(envelope);
      expect(result).toBeDefined();
      expect(result?.channelId).toBe('LongFast');
    });

    it('should decode gatewayId field', () => {
      // Field 3 (gatewayId), wire type 2, length 9, "!abcd1234"
      const envelope = Buffer.from([
        0x1a, 0x09, 0x21, 0x61, 0x62, 0x63, 0x64, 0x31, 0x32, 0x33, 0x34
      ]);

      const result = decoder.decodeServiceEnvelope(envelope);
      expect(result).toBeDefined();
      expect(result?.gatewayId).toBe('!abcd1234');
    });
  });

  describe('decodePayload', () => {
    it('should return null when packet has no decoded data', () => {
      const packet = { from: 123456789 };
      const result = decoder.decodePayload(packet);
      expect(result).toBeNull();
    });

    it('should return null when payload is empty', () => {
      const packet = {
        from: 123456789,
        decoded: {
          portnum: 3, // POSITION_APP
          payload: Buffer.alloc(0),
        },
      };
      const result = decoder.decodePayload(packet);
      expect(result).toBeNull();
    });

    it('should handle unknown port numbers gracefully', () => {
      const packet = {
        from: 123456789,
        decoded: {
          portnum: 999, // Unknown port
          payload: Buffer.from([0x01, 0x02, 0x03]),
        },
      };
      const result = decoder.decodePayload(packet);
      expect(result).toBeNull();
    });
  });

  describe('Position decoding', () => {
    it('should decode position with latitude and longitude', () => {
      // Minimal position protobuf:
      // Field 1 (latitudeI): sfixed32, wire type 5, value 377749000 (37.7749 * 1e7)
      // Field 2 (longitudeI): sfixed32, wire type 5, value -1224194000 (-122.4194 * 1e7)
      const positionPayload = Buffer.alloc(10);
      positionPayload[0] = 0x0d; // Field 1, wire type 5
      positionPayload.writeInt32LE(377749000, 1); // latitudeI
      positionPayload[5] = 0x15; // Field 2, wire type 5
      positionPayload.writeInt32LE(-1224194000, 6); // longitudeI

      const packet = {
        from: 123456789,
        decoded: {
          portnum: 3, // POSITION_APP
          payload: positionPayload,
        },
      };

      const result = decoder.decodePayload(packet);
      expect(result).toBeDefined();
      expect(result?.type).toBe('position');
      expect(result?.data.latitudeI).toBe(377749000);
      expect(result?.data.longitudeI).toBe(-1224194000);
    });
  });

  describe('Hardware model mapping', () => {
    it('should map known hardware models', () => {
      // Access private method via any cast for testing
      const decoder_any = decoder as any;

      expect(decoder_any.hwModelToString(4)).toBe('TBEAM');
      expect(decoder_any.hwModelToString(9)).toBe('RAK4631');
      expect(decoder_any.hwModelToString(46)).toBe('HELTEC_V3');
      expect(decoder_any.hwModelToString(53)).toBe('T_DECK');
    });

    it('should return UNKNOWN for unmapped models', () => {
      const decoder_any = decoder as any;
      expect(decoder_any.hwModelToString(9999)).toBe('UNKNOWN_9999');
    });
  });

  describe('Role mapping', () => {
    it('should map known roles', () => {
      const decoder_any = decoder as any;

      expect(decoder_any.roleToString(0)).toBe('CLIENT');
      expect(decoder_any.roleToString(2)).toBe('ROUTER');
      expect(decoder_any.roleToString(3)).toBe('ROUTER_CLIENT');
      expect(decoder_any.roleToString(5)).toBe('TRACKER');
    });

    it('should return ROLE_X for unknown roles', () => {
      const decoder_any = decoder as any;
      expect(decoder_any.roleToString(99)).toBe('ROLE_99');
    });
  });

  describe('Region mapping', () => {
    it('should map known regions', () => {
      const decoder_any = decoder as any;

      expect(decoder_any.regionToString(1)).toBe('US');
      expect(decoder_any.regionToString(3)).toBe('EU_868');
      expect(decoder_any.regionToString(6)).toBe('ANZ');
    });

    it('should return REGION_X for unknown regions', () => {
      const decoder_any = decoder as any;
      expect(decoder_any.regionToString(99)).toBe('REGION_99');
    });
  });

  describe('Modem preset mapping', () => {
    it('should map known modem presets', () => {
      const decoder_any = decoder as any;

      expect(decoder_any.modemPresetToString(0)).toBe('LONG_FAST');
      expect(decoder_any.modemPresetToString(1)).toBe('LONG_SLOW');
      expect(decoder_any.modemPresetToString(6)).toBe('SHORT_FAST');
    });

    it('should return PRESET_X for unknown presets', () => {
      const decoder_any = decoder as any;
      expect(decoder_any.modemPresetToString(99)).toBe('PRESET_99');
    });
  });
});
