// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/voice/voice_constants.dart';
import 'package:socialmesh/services/voice/voice_encoder.dart';

void main() {
  group('VoiceEncoder.encode — edge cases (no native library required)', () {
    test('returns null for empty PCM input', () async {
      final result = await VoiceEncoder.encode(Int16List(0));
      expect(result, isNull);
    });
  });

  group('VoiceEncoder — wire format header spec', () {
    // These tests verify the *expected* header layout by building a synthetic
    // payload following the spec, then asserting the byte positions match.
    // They do not call VoiceEncoder.encode() with real PCM (that requires the
    // native Codec2 library).

    test(
      '4-byte header layout is [magicByte, wireMode1200, frameLow, frameHigh]',
      () {
        const frameCount = 42;
        final payload = Uint8List(
          VoiceConstants.headerSize + frameCount * VoiceConstants.bytesPerFrame,
        );
        payload[0] = VoiceConstants.magicByte;
        payload[1] = VoiceConstants.wireMode1200;
        payload[2] = frameCount & 0xFF;
        payload[3] = (frameCount >> 8) & 0xFF;

        expect(payload[0], 0xC2, reason: 'magic byte mismatch');
        expect(payload[1], 0x04, reason: 'mode byte mismatch');
        expect(payload[2], frameCount & 0xFF);
        expect(payload[3], (frameCount >> 8) & 0xFF);
      },
    );

    test('frame count > 255 encodes across two bytes (little-endian)', () {
      const frameCount = 300; // 0x012C → low=0x2C, high=0x01
      final payload = Uint8List(VoiceConstants.headerSize);
      payload[2] = frameCount & 0xFF;
      payload[3] = (frameCount >> 8) & 0xFF;

      final decoded = payload[2] | (payload[3] << 8);
      expect(decoded, frameCount);
    });

    test('max frame count 1364 fits in 16-bit little-endian field', () {
      const frameCount = VoiceConstants.maxFrames; // 1364
      final payload = Uint8List(VoiceConstants.headerSize);
      payload[2] = frameCount & 0xFF;
      payload[3] = (frameCount >> 8) & 0xFF;

      final decoded = payload[2] | (payload[3] << 8);
      expect(decoded, 1364);
    });

    test(
      'max payload size (including header) is headerSize + maxFrames * bytesPerFrame',
      () {
        final expected =
            VoiceConstants.headerSize +
            VoiceConstants.maxFrames * VoiceConstants.bytesPerFrame;
        expect(VoiceConstants.maxPayloadBytes, expected);
      },
    );
  });

  group('VoiceEncoder — multi-mode header spec', () {
    test('each quality mode has a unique wire mode byte', () {
      final bytes = VoiceQuality.values.map((q) => q.wireModeByte).toSet();
      expect(bytes.length, VoiceQuality.values.length);
    });

    test('header byte 1 matches VoiceQuality.wireModeByte for each mode', () {
      for (final q in VoiceQuality.values) {
        const frameCount = 10;
        final payload = Uint8List(
          VoiceConstants.headerSize + frameCount * q.bytesPerFrame,
        );
        payload[0] = VoiceConstants.magicByte;
        payload[1] = q.wireModeByte;
        payload[2] = frameCount & 0xFF;
        payload[3] = (frameCount >> 8) & 0xFF;

        expect(payload[0], 0xC2, reason: '${q.name} magic');
        expect(payload[1], q.wireModeByte, reason: '${q.name} mode');
      }
    });
  });
}
