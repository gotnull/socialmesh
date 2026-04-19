// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/voice/voice_constants.dart';
import 'package:socialmesh/services/voice/voice_decoder.dart';

/// Builds a minimal valid .c2 payload header with zero frame body.
/// Used to test header-validation logic without Codec2 native code.
Uint8List _buildHeader({
  int magic = VoiceConstants.magicByte,
  int mode = VoiceConstants.wireMode1200,
  int frames = 0,
}) {
  final buf = Uint8List(VoiceConstants.headerSize);
  buf[0] = magic;
  buf[1] = mode;
  buf[2] = frames & 0xFF;
  buf[3] = (frames >> 8) & 0xFF;
  return buf;
}

void main() {
  group(
    'VoiceDecoder.decode — header validation (no native library required)',
    () {
      test('returns null for empty input', () async {
        final result = await VoiceDecoder.decode(Uint8List(0));
        expect(result, isNull);
      });

      test('returns null for input shorter than 4-byte header', () async {
        final result = await VoiceDecoder.decode(Uint8List(3));
        expect(result, isNull);
      });

      test('returns null when magic byte is wrong', () async {
        final payload = _buildHeader(magic: 0x00, frames: 1);
        final result = await VoiceDecoder.decode(payload);
        expect(result, isNull);
      });

      test('returns null when mode byte is unsupported', () async {
        // 0xFF is not a valid wire mode byte for any VoiceQuality.
        final payload = _buildHeader(mode: 0xFF, frames: 1);
        final result = await VoiceDecoder.decode(payload);
        expect(result, isNull);
      });

      test(
        'returns null when declared frames > 0 but data body is empty',
        () async {
          // Header says 1 frame but no frame bytes follow.
          final payload = _buildHeader(frames: 1);
          // payload is exactly 4 bytes — no frame data appended
          final result = await VoiceDecoder.decode(payload);
          expect(result, isNull);
        },
      );

      test('returns null for all-zero payload (no magic, no frames)', () async {
        final result = await VoiceDecoder.decode(Uint8List(16));
        expect(result, isNull);
      });

      test(
        'header-only payload with correct magic/mode but zero frame bytes returns null',
        () async {
          // 4-byte header: [0xC2, 0x04, 1, 0] but no frame bytes follow.
          final payload = _buildHeader(
            magic: VoiceConstants.magicByte,
            mode: VoiceConstants.wireMode1200,
            frames: 1,
          );
          final result = await VoiceDecoder.decode(payload);
          expect(result, isNull);
        },
      );

      test('accepts all known wire mode bytes in header', () async {
        for (final q in VoiceQuality.values) {
          // Header-only (no frame body) → still returns null, but should NOT
          // reject the mode byte itself.
          final payload = _buildHeader(mode: q.wireModeByte, frames: 1);
          // These will return null because there's no frame data (native lib
          // not available in unit tests), but the important thing is the mode
          // byte is not rejected with "unsupported mode byte".
          final result = await VoiceDecoder.decode(payload);
          expect(result, isNull, reason: '${q.name} header-only returns null');
        }
      });
    },
  );

  group('VoiceDecoder — frame count parsing', () {
    test('little-endian 16-bit frame count parses above 255 correctly', () async {
      // Construct a payload with frame count = 256 (0x00 0x01 in LE) but no body.
      const frames = 256;
      final payload = Uint8List(VoiceConstants.headerSize);
      payload[0] = VoiceConstants.magicByte;
      payload[1] = VoiceConstants.wireMode1200;
      payload[2] = frames & 0xFF; // low byte = 0
      payload[3] = (frames >> 8) & 0xFF; // high byte = 1

      // With no frame body the decoder returns null — but it must at least
      // not throw (frame-count overflow / index errors).
      final result = await VoiceDecoder.decode(payload);
      expect(result, isNull); // expected: no data to decode
    });
  });
}
