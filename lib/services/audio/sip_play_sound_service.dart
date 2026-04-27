// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP Play + SIP Handshake short-form sound effects.
///
/// Four lifetime moments in the SIP DM stack get a discrete audio
/// cue. The service is a thin wrapper around [just_audio] —
/// fire-and-forget playback, asset-backed, no settings UI for v1
/// (the system silent switch is the primary mute affordance).
///
/// Trigger points:
///
///   - [playGameStart]            — SIP Play game transitions to active
///                                  (offer accepted by either side).
///   - [playConnectionSucceeded]  — SIP Handshake reaches `accepted`
///                                  state and the DM session is live.
///   - [playConnectionFailed]     — SIP Handshake fails or times out
///                                  (NOT for user-initiated cancels).
///   - [playRejectedDeclined]     — SIP Handshake OR SIP Play offer
///                                  is declined (either direction).
///
/// Each method is fire-and-forget — exceptions are swallowed and
/// logged so a missing asset / disabled audio system never blocks
/// the SIP / DM happy path.
library;

import 'package:just_audio/just_audio.dart';

import '../../core/logging.dart';

/// Strongly-typed identifier for the four SIP Play SFX. Keeps the
/// public API testable without a real [just_audio] backend.
enum SipPlaySoundCue {
  gameStart('assets/sounds/sip_play/play_game.mp3'),
  connectionSucceeded('assets/sounds/sip_play/connection_succeeded.mp3'),
  connectionFailed('assets/sounds/sip_play/connection_failed.mp3'),
  rejectedDeclined('assets/sounds/sip_play/rejected_declined.mp3');

  final String assetPath;
  const SipPlaySoundCue(this.assetPath);
}

/// Sound service for SIP Play + Handshake cues.
///
/// One [AudioPlayer] per cue so back-to-back triggers (e.g. a
/// handshake completing right as a game offer is accepted) don't
/// cancel each other mid-clip. Players are lazy-built on first
/// playback.
class SipPlaySoundService {
  /// Plug for tests — when set, [play] dispatches here instead of
  /// touching the real audio backend.
  static SipPlaySoundCueSink? overrideSinkForTest;

  final Map<SipPlaySoundCue, AudioPlayer> _players = {};

  Future<void> play(SipPlaySoundCue cue) async {
    final overrideSink = SipPlaySoundService.overrideSinkForTest;
    if (overrideSink != null) {
      overrideSink.recordCue(cue);
      return;
    }
    try {
      final player = _players.putIfAbsent(cue, AudioPlayer.new);
      // setAsset caches once; re-seek to start so rapid retriggers
      // play from frame zero rather than continuing the previous
      // playback.
      await player.setAsset(cue.assetPath);
      await player.seek(Duration.zero);
      await player.play();
    } catch (e, st) {
      // Asset missing / audio backend unavailable — log + drop.
      // The user MUST never have a SIP / DM action blocked because
      // a sound failed to play.
      AppLogging.audio('SipPlaySoundService: cue=${cue.name} failed: $e\n$st');
    }
  }

  /// Stop + dispose every player. Called on provider disposal so we
  /// don't keep audio engines alive after the user leaves the
  /// SIP session screens.
  Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {
        // Best effort.
      }
    }
    _players.clear();
  }
}

/// Test-only sink for capturing cues without touching the audio
/// backend. Tests install via [SipPlaySoundService.overrideSinkForTest].
class SipPlaySoundCueSink {
  final List<SipPlaySoundCue> recorded = [];
  void recordCue(SipPlaySoundCue cue) => recorded.add(cue);
}
