// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/logging.dart';
import 'voice_decoder.dart';

/// Plays a decoded voice message WAV buffer through [just_audio].
///
/// Usage:
/// ```dart
/// final player = VoicePlayer();
/// await player.play(wavBytes);
/// // …
/// player.dispose();
/// ```
class VoicePlayer {
  final _player = AudioPlayer();
  final isPlaying = ValueNotifier<bool>(false);

  /// Decodes [c2Payload] from the Socialmesh `.c2` wire format and plays it.
  ///
  /// Stops any ongoing playback first. Returns false if decoding fails.
  Future<bool> playC2(Uint8List c2Payload) async {
    final wav = await VoiceDecoder.decode(c2Payload);
    if (wav == null) return false;
    return play(wav);
  }

  /// Plays [wavBytes] through the audio output.
  ///
  /// Returns false if playback could not be started.
  Future<bool> play(Uint8List wavBytes) async {
    try {
      if (isPlaying.value) {
        await stop();
      }
      await _player.setAudioSource(_VoiceAudioSource(wavBytes));
      isPlaying.value = true;
      await _player.play();

      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle) {
          isPlaying.value = false;
        }
      });

      AppLogging.voice('playback started (${wavBytes.length} bytes)');
      return true;
    } catch (e) {
      isPlaying.value = false;
      AppLogging.voice('playback error: $e');
      return false;
    }
  }

  /// Stops ongoing playback.
  Future<void> stop() async {
    isPlaying.value = false;
    await _player.stop();
    AppLogging.voice('playback stopped');
  }

  /// Releases the underlying audio player resources.
  Future<void> dispose() async {
    isPlaying.dispose();
    await _player.dispose();
  }
}

/// In-memory audio source that streams WAV bytes to just_audio.
class _VoiceAudioSource extends StreamAudioSource {
  _VoiceAudioSource(this._wavData);

  final Uint8List _wavData;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _wavData.length;
    return StreamAudioResponse(
      sourceLength: _wavData.length,
      contentLength: e - s,
      offset: s,
      stream: Stream.value(_wavData.sublist(s, e)),
      contentType: 'audio/wav',
    );
  }
}
