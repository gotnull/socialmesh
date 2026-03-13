// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../core/logging.dart';
import 'voice_constants.dart';
import 'voice_encoder.dart';
import 'voice_permission_service.dart';
import 'voice_recorder.dart';

/// Orchestrates a complete press-to-talk voice message recording session and
/// returns the encoded `.c2` payload ready for [FileTransferStateNotifier.sendVoiceMessage].
///
/// Lifecycle:
/// 1. [startSession] — checks permission, creates [VoiceRecorder], starts recording.
/// 2. [stopSession] — stops recording, encodes PCM to Codec2, returns [VoiceMessageResult].
/// 3. [cancelSession] — discards the recording with no output.
///
/// Only one session may be active at a time. Calling [startSession] while
/// [isActive] is true is a no-op.
class VoiceMessageService {
  VoiceRecorder? _recorder;
  bool _active = false;

  bool get isActive => _active;

  /// Live amplitude stream (0.0 = silence, 1.0 = peak) sourced from
  /// [VoiceRecorder.amplitudeStream]. Returns null when no session is active.
  Stream<double>? get amplitudeStream => _recorder?.amplitudeStream;

  /// Begins a recording session.
  ///
  /// Returns false when microphone permission is denied or a session is
  /// already active.
  Future<bool> startSession({void Function()? onAutoStop}) async {
    if (_active) return false;

    final hasPermission =
        await VoicePermissionService.requestMicrophonePermission();
    if (!hasPermission) {
      AppLogging.voice('startSession: microphone permission denied');
      return false;
    }

    _recorder = VoiceRecorder();
    _recorder!.onAutoStop = onAutoStop;

    try {
      await _recorder!.startRecording();
      _active = true;
      AppLogging.voice('session started');
      return true;
    } catch (e) {
      AppLogging.voice('startSession error: $e');
      await _recorder?.dispose();
      _recorder = null;
      return false;
    }
  }

  /// Stops the active session and encodes the captured PCM to `.c2` format.
  ///
  /// Returns a [VoiceMessageResult] with the encoded payload, or a result
  /// with [VoiceMessageResult.failed] when recording was too short or
  /// encoding failed.
  Future<VoiceMessageResult> stopSession() async {
    if (!_active || _recorder == null) {
      return const VoiceMessageResult.failed();
    }

    _active = false;
    final pcm = await _recorder!.stopRecording();
    await _recorder!.dispose();
    _recorder = null;

    if (pcm == null || pcm.isEmpty) {
      AppLogging.voice('stopSession: no PCM captured');
      return const VoiceMessageResult.failed();
    }

    // Enforce minimum 1-frame recording (40 ms) to avoid sending noise.
    if (pcm.length < VoiceConstants.samplesPerFrame) {
      AppLogging.voice(
        'stopSession: recording too short (${pcm.length} samples)',
      );
      return const VoiceMessageResult.tooShort();
    }

    final payload = await VoiceEncoder.encode(pcm);
    if (payload == null) {
      AppLogging.voice('stopSession: encoding failed');
      return const VoiceMessageResult.failed();
    }

    final durationMs = (pcm.length / VoiceConstants.sampleRate * 1000).round();
    AppLogging.voice(
      'stopSession: success (${payload.length} bytes, ${durationMs}ms)',
    );
    return VoiceMessageResult.success(payload: payload, durationMs: durationMs);
  }

  /// Discards the active recording session with no output.
  Future<void> cancelSession() async {
    if (!_active) return;
    _active = false;
    await _recorder?.cancelRecording();
    await _recorder?.dispose();
    _recorder = null;
    AppLogging.voice('session cancelled');
  }

  /// Releases all resources. Safe to call even when no session is active.
  Future<void> dispose() async {
    _active = false;
    await _recorder?.dispose();
    _recorder = null;
  }
}

/// The result of a completed [VoiceMessageService.stopSession] call.
final class VoiceMessageResult {
  final Uint8List? payload;
  final int durationMs;
  final VoiceMessageOutcome outcome;

  const VoiceMessageResult.success({
    required Uint8List this.payload,
    required this.durationMs,
  }) : outcome = VoiceMessageOutcome.success;

  const VoiceMessageResult.tooShort()
    : payload = null,
      durationMs = 0,
      outcome = VoiceMessageOutcome.tooShort;

  const VoiceMessageResult.failed()
    : payload = null,
      durationMs = 0,
      outcome = VoiceMessageOutcome.failed;

  bool get isSuccess => outcome == VoiceMessageOutcome.success;
}

/// Outcome of a voice message session.
enum VoiceMessageOutcome { success, tooShort, failed }
