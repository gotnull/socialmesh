// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/logging.dart';
import '../codec2/codec2_bindings.dart';
import 'voice_constants.dart';
import 'voice_decoder.dart';

/// A versioned snapshot of amplitude peaks derived from a Codec2 voice file.
///
/// [peaks] holds the peak absolute amplitude for each bucket, normalised to
/// the range [0.0, 1.0]` where 1.0 is the loudest sample in the clip.
/// A minimum floor of 0.05 is applied so that very quiet passages still render
/// as a thin bar.
///
/// Feed this directly to the [WaveformPainter] CustomPainter.
class WaveformAnalysis {
  const WaveformAnalysis({
    required this.cacheKey,
    required this.durationMs,
    required this.sampleRate,
    required this.channelCount,
    required this.peaks,
    required this.bucketCount,
    required this.generatedAt,
    required this.isFallback,
  });

  /// Bump this when the cache key schema or bucket computation changes.
  static const int version = 1;

  /// Composite key used for in-memory caching (`v{version}_{buckets}_{id}`).
  final String cacheKey;

  /// Estimated duration in milliseconds, derived from the `.c2` frame count.
  final int durationMs;

  final int sampleRate;
  final int channelCount;

  /// Per-bucket peak amplitudes, normalised to [0.0, 1.0].
  final Float32List peaks;

  final int bucketCount;
  final DateTime generatedAt;

  /// True when this analysis was produced without real Codec2 decode (native
  /// library absent or decode failed). Callers can show a visual hint.
  final bool isFallback;
}

/// Analyses a Socialmesh `.c2` voice payload and returns a [WaveformAnalysis].
///
/// Results are cached in memory keyed by [cacheKey]. Repeated calls for the
/// same key return the cached result without re-decoding.
///
/// The heavy computation (Codec2 decode) runs in a Dart isolate via
/// [VoiceDecoder.decode]. The subsequent peak extraction happens
/// synchronously but is extremely fast (~1–5 ms for a 10-second clip).
abstract final class WaveformAnalyser {
  static final Map<String, WaveformAnalysis> _cache = {};

  /// Default number of amplitude buckets generated per waveform.
  static const int defaultBucketCount = 60;

  static const String _schemaVersion = 'v${WaveformAnalysis.version}';

  /// Returns a [WaveformAnalysis] for [c2Payload].
  ///
  /// [cacheKey] must be a stable, unique identifier for this payload, e.g.
  /// `"${transferId}_${payload.length}"` or `"${filename}_${payload.length}"`.
  ///
  /// Returns `null` only if [c2Payload] is not a valid `.c2` file.
  /// If Codec2 is unavailable the returned analysis is a graceful fallback —
  /// not null — so the card still renders.
  static Future<WaveformAnalysis?> analyse(
    Uint8List c2Payload, {
    required String cacheKey,
    int bucketCount = defaultBucketCount,
  }) async {
    // Validate the header before doing any work.
    if (!_hasValidHeader(c2Payload)) return null;

    final key = '${_schemaVersion}_${bucketCount}_$cacheKey';
    final cached = _cache[key];
    if (cached != null) return cached;

    final int frames = c2Payload[2] | (c2Payload[3] << 8);
    final quality = VoiceQuality.fromWireModeByte(c2Payload[1])!;
    final durationMs =
        frames * quality.samplesPerFrame * 1000 ~/ VoiceConstants.sampleRate;

    WaveformAnalysis result;

    if (!Codec2Bindings.isAvailable) {
      // Native library absent — produce a stable low-amplitude placeholder.
      result = _buildFallback(
        key: key,
        durationMs: durationMs,
        bucketCount: bucketCount,
        seed: c2Payload.length ^ frames,
      );
    } else {
      // Decode to WAV using the existing isolate-safe decoder.
      final wav = await VoiceDecoder.decode(c2Payload);
      if (wav == null) {
        result = _buildFallback(
          key: key,
          durationMs: durationMs,
          bucketCount: bucketCount,
          seed: c2Payload.length ^ frames,
        );
      } else {
        const wavHeaderSize = 44;
        if (wav.length <= wavHeaderSize) return null;
        // Reinterpret WAV PCM bytes (after RIFF/fmt/data header) as Int16LE.
        final pcm = wav.buffer.asInt16List(
          wavHeaderSize,
          (wav.length - wavHeaderSize) ~/ 2,
        );
        final peaks = _computePeaks(pcm, bucketCount);
        result = WaveformAnalysis(
          cacheKey: key,
          durationMs: durationMs,
          sampleRate: VoiceConstants.sampleRate,
          channelCount: VoiceConstants.channels,
          peaks: peaks,
          bucketCount: bucketCount,
          generatedAt: DateTime.now(),
          isFallback: false,
        );
      }
    }

    _cache[key] = result;
    AppLogging.voice(
      'waveform: key=$cacheKey buckets=$bucketCount '
      'fallback=${result.isFallback}',
    );
    return result;
  }

  /// Evicts all cached waveform analyses (useful in tests or on memory pressure).
  static void clearCache() => _cache.clear();

  /// Evicts the analysis for one specific [cacheKey] + [bucketCount] pair.
  static void invalidate(
    String cacheKey, {
    int bucketCount = defaultBucketCount,
  }) {
    _cache.remove('${_schemaVersion}_${bucketCount}_$cacheKey');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static bool _hasValidHeader(Uint8List data) {
    if (data.length < VoiceConstants.headerSize) return false;
    if (data[0] != VoiceConstants.magicByte) return false;
    // Accept any known Codec2 mode byte (1200, 2400, 3200 bps).
    if (VoiceQuality.fromWireModeByte(data[1]) == null) return false;
    return true;
  }

  /// Normalised peak amplitudes per bucket.
  ///
  /// Each bucket covers `pcm.length / bucketCount` samples. The maximum
  /// absolute value in each bucket is taken, then the entire array is
  /// normalised so the loudest bucket = 1.0. A floor of 0.05 ensures minimum
  /// bar height.
  static Float32List _computePeaks(Int16List pcm, int bucketCount) {
    final peaks = Float32List(bucketCount);
    final samplesPerBucket = pcm.length / bucketCount;

    for (var b = 0; b < bucketCount; b++) {
      final start = (b * samplesPerBucket).round();
      final end = math.min(((b + 1) * samplesPerBucket).round(), pcm.length);
      var maxAbs = 0;
      for (var i = math.max(start, 0); i < end; i++) {
        final abs = pcm[i].abs();
        if (abs > maxAbs) maxAbs = abs;
      }
      peaks[b] = maxAbs.toDouble();
    }

    // Normalise: loudest bucket → 1.0; everything else proportional.
    var maxPeak = 0.0;
    for (var i = 0; i < bucketCount; i++) {
      if (peaks[i] > maxPeak) maxPeak = peaks[i];
    }
    if (maxPeak > 0) {
      for (var i = 0; i < bucketCount; i++) {
        peaks[i] = math.max(peaks[i] / maxPeak, 0.05);
      }
    } else {
      // All-silence recording — flat floor.
      for (var i = 0; i < bucketCount; i++) {
        peaks[i] = 0.05;
      }
    }
    return peaks;
  }

  /// Builds a low-amplitude placeholder waveform when real decoding is
  /// unavailable. A seeded RNG ensures the pattern is stable across renders.
  static WaveformAnalysis _buildFallback({
    required String key,
    required int durationMs,
    required int bucketCount,
    required int seed,
  }) {
    final rng = math.Random(seed);
    final peaks = Float32List(bucketCount);
    for (var i = 0; i < bucketCount; i++) {
      peaks[i] = 0.08 + rng.nextDouble() * 0.22;
    }
    return WaveformAnalysis(
      cacheKey: key,
      durationMs: durationMs,
      sampleRate: VoiceConstants.sampleRate,
      channelCount: VoiceConstants.channels,
      peaks: peaks,
      bucketCount: bucketCount,
      generatedAt: DateTime.now(),
      isFallback: true,
    );
  }
}
