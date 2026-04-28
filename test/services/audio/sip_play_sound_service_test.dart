// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [SipPlaySoundService].
///
/// The service owns just_audio players in production. For tests we
/// install a [SipPlaySoundCueSink] override so the audio backend
/// never gets touched and we can assert exactly which cues fired.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/audio/sip_play_sound_service.dart';

void main() {
  group('SipPlaySoundService cue routing', () {
    late SipPlaySoundCueSink sink;
    late SipPlaySoundService svc;

    setUp(() {
      sink = SipPlaySoundCueSink();
      SipPlaySoundService.overrideSinkForTest = sink;
      svc = SipPlaySoundService();
    });

    tearDown(() {
      SipPlaySoundService.overrideSinkForTest = null;
    });

    test('play(gameStart) records the right cue', () async {
      await svc.play(SipPlaySoundCue.gameStart);
      expect(sink.recorded, equals([SipPlaySoundCue.gameStart]));
    });

    test('every enum cue maps to a non-empty asset path', () {
      for (final cue in SipPlaySoundCue.values) {
        expect(cue.assetPath, isNotEmpty);
        expect(
          cue.assetPath.startsWith('assets/sounds/sip_play/'),
          isTrue,
          reason: 'asset paths must live under assets/sounds/sip_play/',
        );
        expect(cue.assetPath.endsWith('.mp3'), isTrue);
      }
    });

    test('back-to-back cues record in order (no swallow)', () async {
      await svc.play(SipPlaySoundCue.gameStart);
      await svc.play(SipPlaySoundCue.connectionSucceeded);
      await svc.play(SipPlaySoundCue.rejectedDeclined);
      await svc.play(SipPlaySoundCue.connectionFailed);
      expect(
        sink.recorded,
        equals([
          SipPlaySoundCue.gameStart,
          SipPlaySoundCue.connectionSucceeded,
          SipPlaySoundCue.rejectedDeclined,
          SipPlaySoundCue.connectionFailed,
        ]),
      );
    });

    test('all five cues exist (full enum coverage)', () {
      // Defensive: pin every enum value name + count so a future
      // refactor that drops or renames a cue forces a test update.
      // `consentRequested` was added so the user gets an audible
      // cue when an inbound HS_HELLO surfaces the Accept / Decline
      // prompt — distinct from `connectionSucceeded` (which fires
      // *after* the handshake completes).
      expect(SipPlaySoundCue.values.length, equals(5));
      expect(
        SipPlaySoundCue.values.map((c) => c.name).toSet(),
        equals({
          'gameStart',
          'consentRequested',
          'connectionSucceeded',
          'connectionFailed',
          'rejectedDeclined',
        }),
      );
    });
  });
}
