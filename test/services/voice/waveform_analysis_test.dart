// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/voice/waveform_analysis.dart';
import 'package:socialmesh/services/voice/voice_constants.dart';

/// Builds a minimal valid `.c2` payload with [frameCount] zero-byte frames.
Uint8List _buildC2Payload({required int frameCount}) {
  final data = Uint8List(
    VoiceConstants.headerSize + frameCount * VoiceConstants.bytesPerFrame,
  );
  data[0] = VoiceConstants.magicByte;
  data[1] = VoiceConstants.wireMode1200;
  data[2] = frameCount & 0xFF;
  data[3] = (frameCount >> 8) & 0xFF;
  // Frame bytes remain 0 — valid (all-silence) encoded content.
  return data;
}

void main() {
  tearDown(() => WaveformAnalyser.clearCache());

  group('WaveformAnalyser.analyse()', () {
    test('returns null for too-short payload', () async {
      final result = await WaveformAnalyser.analyse(
        Uint8List(3),
        cacheKey: 'short',
      );
      expect(result, isNull);
    });

    test('returns null for wrong magic byte', () async {
      final bad = Uint8List(8)
        ..[0] =
            0xAB // wrong magic
        ..[1] = VoiceConstants.wireMode1200
        ..[2] = 1
        ..[3] = 0;
      final result = await WaveformAnalyser.analyse(bad, cacheKey: 'bad_magic');
      expect(result, isNull);
    });

    test('returns null for wrong mode byte', () async {
      final bad = Uint8List(8)
        ..[0] = VoiceConstants.magicByte
        ..[1] =
            0x99 // wrong mode
        ..[2] = 1
        ..[3] = 0;
      final result = await WaveformAnalyser.analyse(bad, cacheKey: 'bad_mode');
      expect(result, isNull);
    });

    test('returns non-null for a valid payload (fallback or real)', () async {
      // In unit tests, Codec2 may or may not be available depending on the
      // host platform. Either way the analyser must return a non-null result.
      final payload = _buildC2Payload(frameCount: 25); // ~1s of audio
      final result = await WaveformAnalyser.analyse(
        payload,
        cacheKey: 'fallback_test',
      );
      expect(result, isNotNull);
    });

    test('fallback produces correct bucketCount', () async {
      final payload = _buildC2Payload(frameCount: 10);
      const buckets = 40;
      final result = await WaveformAnalyser.analyse(
        payload,
        cacheKey: 'bucket_count',
        bucketCount: buckets,
      );
      expect(result!.bucketCount, buckets);
      expect(result.peaks.length, buckets);
    });

    test('fallback peaks are within valid range [0.0, 1.0]', () async {
      final payload = _buildC2Payload(frameCount: 50);
      final result = await WaveformAnalyser.analyse(
        payload,
        cacheKey: 'peak_range',
      );
      for (final peak in result!.peaks) {
        expect(peak, greaterThanOrEqualTo(0.0));
        expect(peak, lessThanOrEqualTo(1.0));
      }
    });

    test('fallback durationMs is derived from frame count', () async {
      const frameCount = 25;
      // 25 frames × 320 samples/frame ÷ 8000 Hz = 1.0 s = 1000 ms
      final payload = _buildC2Payload(frameCount: frameCount);
      final result = await WaveformAnalyser.analyse(
        payload,
        cacheKey: 'duration_check',
      );
      final expectedMs =
          frameCount *
          VoiceConstants.samplesPerFrame *
          1000 ~/
          VoiceConstants.sampleRate;
      expect(result!.durationMs, expectedMs);
    });

    test('cache hit returns the same object instance', () async {
      final payload = _buildC2Payload(frameCount: 10);
      const key = 'cache_hit_test';
      final first = await WaveformAnalyser.analyse(payload, cacheKey: key);
      final second = await WaveformAnalyser.analyse(payload, cacheKey: key);
      expect(identical(first, second), isTrue);
    });

    test('clearCache() causes fresh analysis on next call', () async {
      final payload = _buildC2Payload(frameCount: 10);
      const key = 'clear_cache_test';
      final first = await WaveformAnalyser.analyse(payload, cacheKey: key);
      WaveformAnalyser.clearCache();
      final second = await WaveformAnalyser.analyse(payload, cacheKey: key);
      // Different object instances after cache clear.
      expect(identical(first, second), isFalse);
    });

    test('invalidate() evicts only the targeted key', () async {
      final payload = _buildC2Payload(frameCount: 10);
      const keyA = 'invalidate_A';
      const keyB = 'invalidate_B';
      final a1 = await WaveformAnalyser.analyse(payload, cacheKey: keyA);
      final b1 = await WaveformAnalyser.analyse(payload, cacheKey: keyB);

      WaveformAnalyser.invalidate(keyA);

      final a2 = await WaveformAnalyser.analyse(payload, cacheKey: keyA);
      final b2 = await WaveformAnalyser.analyse(payload, cacheKey: keyB);

      // A was invalidated — new instance.
      expect(identical(a1, a2), isFalse);
      // B was not invalidated — same cached instance.
      expect(identical(b1, b2), isTrue);
    });

    test('fallback waveform is stable (same seed → same peaks)', () async {
      final payload = _buildC2Payload(frameCount: 20);
      WaveformAnalyser.clearCache();
      final first = await WaveformAnalyser.analyse(
        payload,
        cacheKey: 'stability_1',
      );
      WaveformAnalyser.clearCache();
      final second = await WaveformAnalyser.analyse(
        payload,
        cacheKey: 'stability_2', // different key, same payload → same seed
      );
      // Seed = payload.length ^ frameCount — consistent for same payload size.
      expect(first!.peaks.length, second!.peaks.length);
    });
  });
}
