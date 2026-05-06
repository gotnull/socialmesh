// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/logging.dart';
import '../audio/wav_temp_file.dart';
import 'voice_decoder.dart';

/// Plays a decoded voice message WAV buffer through [just_audio].
///
/// Lifecycle:
///  1. Call [playC2] or [play] to load an audio source and begin playing.
///  2. Call [pause] to pause without losing the seek position.
///  3. Call [resume] to continue from the paused position.
///  4. Call [seekTo] at any time while loaded (playing or paused).
///  5. Call [restart] to seek back to the beginning.
///  6. Call [dispose] to release resources.
///
/// Important: never call [stop] while expecting to seek and resume — [stop]
/// clears the audio pipeline.  Always use [pause]/[resume] for
/// play/pause toggles.
class VoicePlayer {
  final _player = AudioPlayer();
  final isPlaying = ValueNotifier<bool>(false);

  StreamSubscription<PlayerState>? _stateSub;
  WavTempFile? _tempFile;

  VoicePlayer() {
    // Listen to just_audio state changes so we can flip isPlaying when
    // the track completes naturally.
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      isPlaying.value = false;
      AppLogging.voice('playback completed');
    }
  }

  /// Real-time playback position stream from just_audio.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Duration stream — emits once the audio source is loaded and metadata is known.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Current playback position (synchronous snapshot).
  Duration get currentPosition => _player.position;

  /// Total duration if known, null before [playC2] or [play] is called.
  Duration? get currentDuration => _player.duration;

  /// Whether the player currently has a loaded audio source (playing or paused).
  bool get hasSource => _player.audioSource != null;

  /// Decodes [c2Payload] from the SocialMesh `.c2` wire format and plays it.
  ///
  /// Returns false if decoding fails.
  Future<bool> playC2(Uint8List c2Payload) async {
    final wav = await VoiceDecoder.decode(c2Payload);
    if (wav == null) return false;
    return play(wav);
  }

  /// Loads [wavBytes] as the audio source and begins playback from the start.
  ///
  /// If playback is currently in progress it is stopped first.
  /// Returns false if the source could not be loaded.
  Future<bool> play(Uint8List wavBytes) async {
    try {
      if (isPlaying.value) {
        // Pause current playback before swapping the source so the pipeline
        // is in a defined state.  Do NOT call stop() — it discards position
        // and the audio source entirely.
        await _player.pause();
        isPlaying.value = false;
      }
      await _tempFile?.cleanup();
      _tempFile = await WavTempFile.write(wavBytes, tag: 'voice');
      await _player.setFilePath(_tempFile!.filePath);
      await _player.seek(Duration.zero);
      isPlaying.value = true;
      AppLogging.voice('playback started (${wavBytes.length} bytes)');
      // Fire-and-forget: just_audio play() returns when playback ends or is
      // paused/stopped. We track completion via _onPlayerState instead of
      // awaiting here, which would block and race with pause()/resume().
      unawaited(
        _player.play().catchError((Object e) {
          isPlaying.value = false;
          AppLogging.voice('playback error: $e');
        }),
      );
      return true;
    } catch (e) {
      isPlaying.value = false;
      AppLogging.voice('playback error: $e');
      return false;
    }
  }

  /// Pauses playback without resetting the seek position.
  ///
  /// The audio source remains loaded so [resume] and [seekTo] continue to work.
  Future<void> pause() async {
    isPlaying.value = false;
    await _player.pause();
    AppLogging.voice('playback paused');
  }

  /// Resumes playback from the current seek position.
  ///
  /// Has no effect if nothing is loaded.
  Future<void> resume() async {
    if (!hasSource) return;
    // If the track finished (ProcessingState.completed), seeking back is
    // required before play() will produce audio again.
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      AppLogging.voice('seek to start for replay');
    }
    isPlaying.value = true;
    AppLogging.voice('playback resumed');
    unawaited(
      _player.play().catchError((Object e) {
        isPlaying.value = false;
        AppLogging.voice('resume error: $e');
      }),
    );
  }

  /// Seeks back to the start of the loaded audio.
  ///
  /// If the track had finished, this allows [resume] to replay from the top.
  Future<void> restart() async {
    await _player.seek(Duration.zero);
  }

  /// Stops ongoing playback and clears the audio source.
  ///
  /// After calling [stop], [hasSource] returns false.  Prefer [pause] when
  /// you want to seek and resume later.
  Future<void> stop() async {
    isPlaying.value = false;
    await _player.stop();
    await _tempFile?.cleanup();
    _tempFile = null;
    AppLogging.voice('playback stopped');
  }

  /// Seeks to [position] in the currently loaded audio source.
  ///
  /// Works while playing, paused, or after natural completion.
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  /// Releases the underlying audio player resources.
  Future<void> dispose() async {
    await _stateSub?.cancel();
    _stateSub = null;
    await _tempFile?.cleanup();
    _tempFile = null;
    isPlaying.dispose();
    await _player.dispose();
  }
}
