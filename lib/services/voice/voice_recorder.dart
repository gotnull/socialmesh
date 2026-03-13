// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../core/logging.dart';
import 'voice_constants.dart';

/// Captures microphone audio as raw 16-bit PCM at 8000 Hz mono and returns
/// it as an [Int16List] when the recording session ends.
///
/// Usage:
/// ```dart
/// final recorder = VoiceRecorder();
/// await recorder.startRecording();
/// // Press-to-talk held …
/// final pcm = await recorder.stopRecording();
/// recorder.dispose();
/// ```
///
/// Auto-stops after [VoiceConstants.maxRecordingDuration] to enforce the
/// 8192-byte payload limit of the Socialmesh `.c2` wire format.
class VoiceRecorder {
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  Timer? _autoStopTimer;
  final _pcmBuffer = <int>[];
  bool _recording = false;
  void Function()? onAutoStop;

  bool get isRecording => _recording;

  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: VoiceConstants.sampleRate,
    numChannels: VoiceConstants.channels,
    noiseSuppress: false,
    echoCancel: false,
    autoGain: false,
  );

  /// Starts a PCM streaming recording session.
  ///
  /// Throws if microphone permission was not granted before calling this.
  Future<void> startRecording() async {
    if (_recording) return;
    _pcmBuffer.clear();
    _recording = true;

    final stream = await _recorder.startStream(_config);
    AppLogging.voice(
      'recording started (sampleRate=${VoiceConstants.sampleRate}, '
      'channels=${VoiceConstants.channels})',
    );

    _sub = stream.listen(
      (bytes) {
        _pcmBuffer.addAll(bytes);
        AppLogging.voice(
          'rx ${bytes.length} PCM bytes (total=${_pcmBuffer.length})',
        );
      },
      onError: (Object e) {
        AppLogging.voice('stream error: $e');
        _recording = false;
      },
      cancelOnError: true,
    );

    _autoStopTimer = Timer(VoiceConstants.maxRecordingDuration, () {
      AppLogging.voice('auto-stop at max duration');
      onAutoStop?.call();
    });
  }

  /// Stops recording and returns the captured PCM as an [Int16List].
  ///
  /// Returns null if no audio was captured or an error occurred.
  Future<Int16List?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();

    if (_pcmBuffer.isEmpty) {
      AppLogging.voice('stopRecording: buffer empty');
      return null;
    }

    // Raw PCM from the record package is little-endian 16-bit interleaved.
    // Each sample is 2 bytes, so byte count must be even.
    if (_pcmBuffer.length % 2 != 0) {
      _pcmBuffer.removeLast();
    }

    final byteData = Uint8List.fromList(_pcmBuffer);
    final samples = Int16List(byteData.length ~/ 2);
    final bd = byteData.buffer.asByteData();
    for (var i = 0; i < samples.length; i++) {
      samples[i] = bd.getInt16(i * 2, Endian.little);
    }

    // Clamp to maxFrames worth of samples.
    final maxSamples =
        VoiceConstants.maxFrames * VoiceConstants.samplesPerFrame;
    final clamped = samples.length > maxSamples
        ? Int16List.fromList(samples.sublist(0, maxSamples))
        : samples;

    AppLogging.voice(
      'stopRecording: ${clamped.length} samples '
      '(${(clamped.length / VoiceConstants.sampleRate).toStringAsFixed(2)}s)',
    );
    return clamped;
  }

  /// Discards the current recording without returning any audio.
  Future<void> cancelRecording() async {
    if (!_recording) return;
    _recording = false;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _recorder.cancel();
    _pcmBuffer.clear();
    AppLogging.voice('recording cancelled');
  }

  /// Releases the underlying native recorder resource.
  Future<void> dispose() async {
    await cancelRecording();
    _recorder.dispose();
  }
}
