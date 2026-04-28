// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Local SIP Signal synthesis — turns a [SipSignalEnvelope] into
/// audible output by generating 16-bit PCM WAV in memory, writing
/// it to a temp file, and handing it to [just_audio].
///
/// Hard rules:
///   - **No audio samples are ever placed on the SIP wire.** This
///     service runs locally on both sender (preview) and receiver
///     (replay), generating waveforms from the compact wire envelope.
///   - Pure synthesis. No network. No persistence beyond the
///     short-lived WAV temp file (cleaned on next play).
///   - Every public method is fire-and-forget — exceptions are
///     logged + swallowed, so a missing audio backend never breaks
///     the SIP DM happy path.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import '../../core/logging.dart';
import '../protocol/sip/signal/morse_table.dart';
import '../protocol/sip/signal/sip_signal_constants.dart';
import '../protocol/sip/signal/sip_signal_payload.dart';
import 'wav_temp_file.dart';

/// Sample rate used for all synthesis. 22.05 kHz is enough for
/// 1–4 kHz tones (well above the highest MIDI note we generate)
/// and halves the WAV temp file size vs 44.1 kHz.
const int _kSampleRate = 22050;

/// 1 unit = 1200 / WPM ms; the synth converts this to a sample count.
int _samplesForUnits(int units, int unitMs) {
  return ((units * unitMs) / 1000.0 * _kSampleRate).round();
}

/// Test-only sink for capturing synthesis requests without touching
/// the audio backend. Tests install via
/// [SipSignalSynthService.overrideSinkForTest].
class SipSignalSynthCueSink {
  final List<SipSignalSynthCue> cues = [];
  void recordCue(SipSignalSynthCue cue) => cues.add(cue);
}

/// Discriminated record of a synthesis request — used by tests.
class SipSignalSynthCue {
  final SipSignalKind kind;

  /// Phrase: list of MIDI notes. Morse: empty.
  final List<int> midiNotes;

  /// Morse: original text. Phrase: empty.
  final String morseText;

  /// Common: instrument code (or 0 when irrelevant).
  final int instrumentCode;

  const SipSignalSynthCue({
    required this.kind,
    this.midiNotes = const [],
    this.morseText = '',
    this.instrumentCode = 0,
  });
}

class SipSignalSynthService {
  /// Test override — when non-null, [playPhrase] / [playMorse] route
  /// to the sink instead of generating audio.
  static SipSignalSynthCueSink? overrideSinkForTest;

  // Lazy: never instantiated in cue-sink test mode (AudioPlayer
  // requires platform channels that aren't bound under unit tests).
  late final AudioPlayer _player = AudioPlayer();
  WavTempFile? _tempFile;

  /// Tap-feedback player pool. Composer pad taps route through this
  /// pool (round-robin) so rapid finger drumming doesn't queue up
  /// behind a single AudioPlayer's setFilePath / play awaits. Pool
  /// size 4 covers ~250 ms inter-tap intervals at the default
  /// 240-300 ms tone duration without any single slot still busy
  /// when the round-robin index points back at it.
  static const int _kTapPoolSize = 4;
  late final List<AudioPlayer> _tapPool = List.generate(
    _kTapPoolSize,
    (_) => AudioPlayer(),
  );
  final List<WavTempFile?> _tapTempFiles = List<WavTempFile?>.filled(
    _kTapPoolSize,
    null,
  );
  int _tapPoolNext = 0;

  /// Cached WAV bytes keyed by `(midi, instrument, durationTicks,
  /// velocity)`. Repeat-same-note taps (and instrument-stable phrase
  /// previews) skip the per-tap synthesis cost, which is the bulk of
  /// the user-perceived "delay before sound" on Android. Capped to a
  /// sane maximum so a long-running session can't let it grow
  /// unbounded — eviction is FIFO via [_tapWavCacheOrder].
  static const int _kTapWavCacheMax = 64;
  final Map<int, Uint8List> _tapWavCache = {};
  final List<int> _tapWavCacheOrder = [];

  int _tapWavCacheKey({
    required int midi,
    required SipSignalInstrument instrument,
    required int durationTicks,
    required int velocity,
  }) {
    // Pack into a single int for a cheap map key. MIDI fits in 7
    // bits, instrument in 3, duration in 8, velocity in 7 — under
    // 32 bits total, no collisions across realistic inputs.
    return (midi & 0x7F) |
        ((instrument.code & 0x07) << 7) |
        ((durationTicks & 0xFF) << 10) |
        ((velocity & 0x7F) << 18);
  }

  /// Play a phrase locally. Fire-and-forget. Failures are logged.
  Future<void> playPhrase(SipSignalPhraseBody phrase) async {
    final overrideSink = SipSignalSynthService.overrideSinkForTest;
    if (overrideSink != null) {
      overrideSink.recordCue(
        SipSignalSynthCue(
          kind: SipSignalKind.phrase,
          midiNotes: phrase.notes.map((n) => n.midiNote).toList(),
          instrumentCode: phrase.instrument.code,
        ),
      );
      return;
    }
    try {
      final wav = _renderPhrase(phrase);
      await _playWav(wav, tag: 'sip_signal_phrase');
      AppLogging.sipSignal(
        'playPhrase ok notes=${phrase.notes.length} '
        'instrument=${phrase.instrument.name}',
      );
    } catch (e, st) {
      AppLogging.sipSignal('playPhrase failed: $e\n$st');
    }
  }

  /// Low-latency single-note feedback for composer pad taps.
  /// Routes through the round-robin player pool so concurrent taps
  /// run in parallel, and consults the WAV cache so repeat-same-note
  /// taps skip both the synthesis and (for the cached slot) the
  /// temp-file rewrite. Skipping the previous-temp-file cleanup
  /// await — stale `sm_tap_*` files purge in the background or with
  /// the OS temp sweep.
  Future<void> playToneTap({
    required int midi,
    required SipSignalInstrument instrument,
    int durationTicks = 12,
    int velocity = 100,
  }) async {
    final overrideSink = SipSignalSynthService.overrideSinkForTest;
    if (overrideSink != null) {
      overrideSink.recordCue(
        SipSignalSynthCue(
          kind: SipSignalKind.phrase,
          midiNotes: [midi],
          instrumentCode: instrument.code,
        ),
      );
      return;
    }
    try {
      final cacheKey = _tapWavCacheKey(
        midi: midi,
        instrument: instrument,
        durationTicks: durationTicks,
        velocity: velocity,
      );
      var wav = _tapWavCache[cacheKey];
      if (wav == null) {
        wav = _renderPhrase(
          SipSignalPhraseBody(
            instrument: instrument,
            notes: [
              SipSignalNote(
                midiNote: midi,
                durationTicks: durationTicks,
                velocity: velocity,
              ),
            ],
          ),
        );
        _tapWavCache[cacheKey] = wav;
        _tapWavCacheOrder.add(cacheKey);
        if (_tapWavCacheOrder.length > _kTapWavCacheMax) {
          final evict = _tapWavCacheOrder.removeAt(0);
          _tapWavCache.remove(evict);
        }
      }

      final slot = _tapPoolNext;
      _tapPoolNext = (_tapPoolNext + 1) % _kTapPoolSize;

      // Fire-and-forget cleanup of whatever temp file this slot
      // previously owned. Awaiting it would re-introduce the
      // serialisation we're trying to avoid.
      unawaited(_tapTempFiles[slot]?.cleanup());

      final temp = await WavTempFile.write(wav, tag: 'tap_$slot');
      _tapTempFiles[slot] = temp;

      final player = _tapPool[slot];
      await player.setFilePath(temp.filePath);
      // No explicit seek — setFilePath leaves position at 0, and
      // skipping the await shaves another small platform round-trip.
      await player.play();
    } catch (e, st) {
      AppLogging.sipSignal('playToneTap failed: $e\n$st');
    }
  }

  /// Play Morse locally. Fire-and-forget.
  Future<void> playMorse(SipSignalMorseBody morse) async {
    final overrideSink = SipSignalSynthService.overrideSinkForTest;
    if (overrideSink != null) {
      overrideSink.recordCue(
        SipSignalSynthCue(
          kind: SipSignalKind.morse,
          morseText: morse.text,
          instrumentCode: morse.toneInstrument.code,
        ),
      );
      return;
    }
    try {
      final wav = _renderMorse(morse);
      await _playWav(wav, tag: 'sip_signal_morse');
      AppLogging.sipSignal(
        'playMorse ok chars=${morse.text.length} wpm=${morse.speedWpm} '
        'instrument=${morse.toneInstrument.name}',
      );
    } catch (e, st) {
      AppLogging.sipSignal('playMorse failed: $e\n$st');
    }
  }

  Future<void> _playWav(Uint8List wav, {required String tag}) async {
    await _tempFile?.cleanup();
    _tempFile = await WavTempFile.write(wav, tag: tag);
    await _player.setFilePath(_tempFile!.filePath);
    await _player.seek(Duration.zero);
    await _player.play();
  }

  /// Stop + dispose. Called from provider teardown.
  Future<void> dispose() async {
    try {
      await _player.stop();
      await _player.dispose();
      for (final p in _tapPool) {
        await p.stop();
        await p.dispose();
      }
    } catch (_) {
      // Best effort.
    }
    await _tempFile?.cleanup();
    _tempFile = null;
    for (var i = 0; i < _tapTempFiles.length; i += 1) {
      await _tapTempFiles[i]?.cleanup();
      _tapTempFiles[i] = null;
    }
    _tapWavCache.clear();
    _tapWavCacheOrder.clear();
  }

  // ---------------------------------------------------------------
  // Pure synthesis — no I/O, deterministic, testable.
  // ---------------------------------------------------------------

  /// Render a phrase to a 16-bit PCM WAV byte buffer.
  Uint8List _renderPhrase(SipSignalPhraseBody phrase) {
    final samples = <int>[];
    // Brief intra-note gap so adjacent same-pitch notes don't blur.
    final gapSamples = (_kSampleRate * 0.04).round();
    for (final note in phrase.notes) {
      final freq = note.frequencyHz;
      final durationMs = note.durationTicks * SipSignalConstants.phraseTickMs;
      final n = (durationMs / 1000.0 * _kSampleRate).round();
      final amp = (note.velocity / 127.0).clamp(0.0, 1.0);
      _appendNote(
        samples,
        freq: freq,
        sampleCount: n,
        amplitude: amp,
        instrument: phrase.instrument,
      );
      samples.addAll(List<int>.filled(gapSamples, 0));
    }
    return _writeWav(samples);
  }

  /// Render Morse to a 16-bit PCM WAV byte buffer.
  Uint8List _renderMorse(SipSignalMorseBody morse) {
    final unitMs = SipSignalConstants.unitMsForWpm(morse.speedWpm);
    final timing = morseTimingForText(morse.text);
    final samples = <int>[];
    // Standard Morse practice tone — 600 Hz; clear + non-fatiguing.
    const freq = 600.0;
    for (final step in timing) {
      final n = _samplesForUnits(step.units, unitMs);
      switch (step.kind) {
        case MorseStepKind.tone:
          _appendNote(
            samples,
            freq: freq,
            sampleCount: n,
            amplitude: 0.7,
            instrument: morse.toneInstrument,
          );
        case MorseStepKind.gap:
          samples.addAll(List<int>.filled(n, 0));
      }
    }
    return _writeWav(samples);
  }

  /// Append a single tone of [sampleCount] samples to [out] using
  /// the given instrument's amplitude envelope.
  void _appendNote(
    List<int> out, {
    required double freq,
    required int sampleCount,
    required double amplitude,
    required SipSignalInstrument instrument,
  }) {
    if (sampleCount <= 0) return;
    final twoPiF = 2.0 * math.pi * freq;
    for (var i = 0; i < sampleCount; i += 1) {
      final t = i / _kSampleRate;
      final progress = sampleCount == 0 ? 0.0 : i / sampleCount;
      double env;
      double sample;
      switch (instrument) {
        case SipSignalInstrument.sine:
          // Linear ADSR — 5 ms attack, 30 ms release, sustain elsewhere.
          env = _adsr(progress, sampleCount);
          sample = math.sin(twoPiF * t);
        case SipSignalInstrument.bell:
          // Fast attack, exponential decay, slight metallic shimmer
          // via a 2nd harmonic at 1/3 amplitude.
          env = math.exp(-progress * 4.0);
          final h2 = 0.33 * math.sin(2.0 * twoPiF * t);
          sample = (math.sin(twoPiF * t) + h2) / 1.33;
        case SipSignalInstrument.pluck:
          // Pluck: damped sine + filtered noise burst at the start.
          env = math.exp(-progress * 6.0);
          final noiseBurst = i < (_kSampleRate ~/ 100)
              ? (math.Random(i).nextDouble() * 2.0 - 1.0) * 0.3
              : 0.0;
          sample = math.sin(twoPiF * t) + noiseBurst;
        case SipSignalInstrument.chirp:
          // Chirp: sweep ±2 semitones around the centre over the
          // note's duration.
          env = _adsr(progress, sampleCount);
          final sweep = 1.0 + 0.06 * (progress - 0.5);
          sample = math.sin(twoPiF * sweep * t);
      }
      final value = (sample * env * amplitude * 0.5 * 32767).round().clamp(
        -32768,
        32767,
      );
      out.add(value);
    }
  }

  /// Linear ADSR-ish envelope. Symmetric attack + release, sustain
  /// elsewhere. Caller passes [progress] in [0, 1].
  double _adsr(double progress, int sampleCount) {
    const attackUnit = 0.04;
    const releaseUnit = 0.08;
    if (progress < attackUnit) return progress / attackUnit;
    if (progress > 1 - releaseUnit) {
      return (1 - progress) / releaseUnit;
    }
    return 1.0;
  }

  /// Wrap raw 16-bit signed samples into a mono PCM WAV byte buffer.
  Uint8List _writeWav(List<int> samples) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = _kSampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;
    final buffer = ByteData(44 + dataSize);
    var offset = 0;
    // RIFF
    buffer.setUint8(offset++, 0x52);
    buffer.setUint8(offset++, 0x49);
    buffer.setUint8(offset++, 0x46);
    buffer.setUint8(offset++, 0x46);
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    // WAVE
    buffer.setUint8(offset++, 0x57);
    buffer.setUint8(offset++, 0x41);
    buffer.setUint8(offset++, 0x56);
    buffer.setUint8(offset++, 0x45);
    // fmt
    buffer.setUint8(offset++, 0x66);
    buffer.setUint8(offset++, 0x6D);
    buffer.setUint8(offset++, 0x74);
    buffer.setUint8(offset++, 0x20);
    buffer.setUint32(offset, 16, Endian.little);
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, _kSampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;
    // data
    buffer.setUint8(offset++, 0x64);
    buffer.setUint8(offset++, 0x61);
    buffer.setUint8(offset++, 0x74);
    buffer.setUint8(offset++, 0x61);
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;
    for (final s in samples) {
      buffer.setInt16(offset, s, Endian.little);
      offset += 2;
    }
    return buffer.buffer.asUint8List();
  }
}
