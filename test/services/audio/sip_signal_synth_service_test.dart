// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the SIP Signal synth's tap-feedback fast path.
///
/// The composer pad-tap routes through [SipSignalSynthService.playToneTap]
/// instead of the heavier [SipSignalSynthService.playPhrase] so rapid
/// drumming on the pads doesn't queue behind a single AudioPlayer's
/// setFilePath / play awaits. This test runs against the
/// `overrideSinkForTest` so we never touch the audio backend.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/audio/sip_signal_synth_service.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_constants.dart';

void main() {
  group('SipSignalSynthService.playToneTap', () {
    late SipSignalSynthCueSink sink;
    late SipSignalSynthService service;

    setUp(() {
      sink = SipSignalSynthCueSink();
      SipSignalSynthService.overrideSinkForTest = sink;
      service = SipSignalSynthService();
    });

    tearDown(() {
      SipSignalSynthService.overrideSinkForTest = null;
    });

    test(
      'single tap records a phrase cue with the right note + instrument',
      () async {
        await service.playToneTap(
          midi: 60,
          instrument: SipSignalInstrument.bell,
        );
        expect(sink.cues, hasLength(1));
        final cue = sink.cues.single;
        expect(cue.kind, SipSignalKind.phrase);
        expect(cue.midiNotes, equals([60]));
        expect(cue.instrumentCode, SipSignalInstrument.bell.code);
      },
    );

    test('rapid taps record one cue per call (no debounce / drop)', () async {
      // Eight pads on the composer keypad — fire all of them
      // back-to-back without awaiting in between. The override sink
      // captures synchronously so the order is deterministic.
      const padMidi = [60, 62, 64, 65, 67, 69, 71, 72];
      for (final m in padMidi) {
        // Fire-and-forget — composer pad-tap doesn't await.
        // ignore: unawaited_futures
        service.playToneTap(midi: m, instrument: SipSignalInstrument.sine);
      }
      // Drain the microtask queue so every override-sink dispatch
      // resolves.
      await Future<void>.delayed(Duration.zero);
      expect(sink.cues, hasLength(padMidi.length));
      for (var i = 0; i < padMidi.length; i += 1) {
        expect(sink.cues[i].midiNotes, equals([padMidi[i]]));
      }
    });

    test('changing instrument flows through to the recorded cue', () async {
      await service.playToneTap(midi: 60, instrument: SipSignalInstrument.bell);
      await service.playToneTap(
        midi: 60,
        instrument: SipSignalInstrument.pluck,
      );
      expect(sink.cues, hasLength(2));
      expect(sink.cues[0].instrumentCode, SipSignalInstrument.bell.code);
      expect(sink.cues[1].instrumentCode, SipSignalInstrument.pluck.code);
    });
  });
}
