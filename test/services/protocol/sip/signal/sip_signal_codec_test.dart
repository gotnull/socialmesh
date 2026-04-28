// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Wire-format tests for the SIP Signal v1 envelope codec.
///
/// Pinned invariants:
///   - 4-byte common header (typeAndVersion ‖ kind ‖ sequenceId).
///   - Phrase body: instrument(1) ‖ noteCount(1) ‖ (midi/dur/vel)*N.
///   - Morse body: speedWpm(1) ‖ toneInstrument(1) ‖ charCount(1) ‖
///     uppercase ASCII bytes.
///   - Every malformation returns a typed [SipSignalDecodeError]
///     instead of throwing. Receivers map every variant to a silent
///     drop+log.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_codec.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_constants.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_payload.dart';

SipSignalNote _n(int midi, {int duration = 18, int velocity = 100}) =>
    SipSignalNote(midiNote: midi, durationTicks: duration, velocity: velocity);

void main() {
  group('SipSignalCodec.encodePhrase / decode round-trip', () {
    test('1-note phrase round-trips byte-for-byte', () {
      final bytes = SipSignalCodec.encodePhrase(
        sequenceId: 0x0042,
        instrument: SipSignalInstrument.bell,
        notes: [_n(60)],
      )!;
      // Header(4) + phrase header(2) + 1 note(3) = 9 bytes.
      expect(bytes.length, equals(9));
      expect(bytes[0], equals(0x21));
      expect(bytes[1], equals(0x01));
      expect(bytes[2], equals(0x00));
      expect(bytes[3], equals(0x42));
      expect(bytes[4], equals(0x02)); // bell
      expect(bytes[5], equals(0x01)); // noteCount

      final result = SipSignalCodec.decode(bytes);
      expect(result.isOk, isTrue);
      final env = result.envelope!;
      expect(env.kind, equals(SipSignalKind.phrase));
      expect(env.sequenceId, equals(0x0042));
      expect(env.phrase!.instrument, equals(SipSignalInstrument.bell));
      expect(env.phrase!.notes.length, equals(1));
      expect(env.phrase!.notes.first.midiNote, equals(60));
    });

    test('4-note phrase: ~18 bytes pre-framing (matches spec budget)', () {
      final bytes = SipSignalCodec.encodePhrase(
        sequenceId: 0x1234,
        instrument: SipSignalInstrument.sine,
        notes: [_n(60), _n(64), _n(67), _n(72)],
      )!;
      // Header(4) + phrase header(2) + 4 notes * 3 = 18 bytes.
      expect(bytes.length, equals(18));
      final result = SipSignalCodec.decode(bytes);
      expect(result.isOk, isTrue);
      expect(result.envelope!.phrase!.notes.length, equals(4));
    });

    test('8-note phrase: ~30 bytes pre-framing (matches spec budget)', () {
      final bytes = SipSignalCodec.encodePhrase(
        sequenceId: 0xABCD,
        instrument: SipSignalInstrument.pluck,
        notes: List.generate(8, (i) => _n(60 + i)),
      )!;
      // Header(4) + phrase header(2) + 8 notes * 3 = 30 bytes.
      expect(bytes.length, equals(30));
      final result = SipSignalCodec.decode(bytes);
      expect(result.isOk, isTrue);
      expect(result.envelope!.phrase!.notes.length, equals(8));
      // Round-trip preserves midi numbers exactly.
      for (var i = 0; i < 8; i += 1) {
        expect(result.envelope!.phrase!.notes[i].midiNote, equals(60 + i));
      }
    });

    test('empty phrase rejected at encode', () {
      expect(
        SipSignalCodec.encodePhrase(
          sequenceId: 0,
          instrument: SipSignalInstrument.sine,
          notes: const [],
        ),
        isNull,
      );
    });

    test('over-max phrase (9 notes) rejected at encode', () {
      expect(
        SipSignalCodec.encodePhrase(
          sequenceId: 0,
          instrument: SipSignalInstrument.sine,
          notes: List.generate(9, (i) => _n(60 + i)),
        ),
        isNull,
      );
    });

    test('out-of-range midi note rejected at encode', () {
      expect(
        SipSignalCodec.encodePhrase(
          sequenceId: 0,
          instrument: SipSignalInstrument.sine,
          notes: [_n(128)],
        ),
        isNull,
      );
    });
  });

  group('SipSignalCodec.encodeMorse / decode round-trip', () {
    test('SOS round-trips', () {
      final bytes = SipSignalCodec.encodeMorse(
        sequenceId: 0x0001,
        speedWpm: 15,
        toneInstrument: SipSignalInstrument.sine,
        text: 'SOS',
      )!;
      // Header(4) + morse header(3) + 3 bytes UTF-8 = 10 bytes.
      expect(bytes.length, equals(10));
      final result = SipSignalCodec.decode(bytes);
      expect(result.isOk, isTrue);
      final env = result.envelope!;
      expect(env.kind, equals(SipSignalKind.morse));
      expect(env.morse!.speedWpm, equals(15));
      expect(env.morse!.toneInstrument, equals(SipSignalInstrument.sine));
      expect(env.morse!.text, equals('SOS'));
    });

    test('lowercase input is normalised to uppercase', () {
      final bytes = SipSignalCodec.encodeMorse(
        sequenceId: 0x0002,
        speedWpm: 15,
        toneInstrument: SipSignalInstrument.sine,
        text: 'hello',
      )!;
      final result = SipSignalCodec.decode(bytes);
      expect(result.envelope!.morse!.text, equals('HELLO'));
    });

    test('HELLO WORLD encodes 11 chars + decodes intact', () {
      final bytes = SipSignalCodec.encodeMorse(
        sequenceId: 0,
        speedWpm: 15,
        toneInstrument: SipSignalInstrument.bell,
        text: 'HELLO WORLD',
      )!;
      // 4 + 3 + 11 = 18 bytes.
      expect(bytes.length, equals(18));
      final result = SipSignalCodec.decode(bytes);
      expect(result.envelope!.morse!.text, equals('HELLO WORLD'));
    });

    test('empty Morse rejected at encode', () {
      expect(
        SipSignalCodec.encodeMorse(
          sequenceId: 0,
          speedWpm: 15,
          toneInstrument: SipSignalInstrument.sine,
          text: '',
        ),
        isNull,
      );
    });

    test('over-max (>40 chars) Morse rejected at encode', () {
      expect(
        SipSignalCodec.encodeMorse(
          sequenceId: 0,
          speedWpm: 15,
          toneInstrument: SipSignalInstrument.sine,
          text: 'A' * 41,
        ),
        isNull,
      );
    });

    test('unsupported character rejected at encode', () {
      // Unicode emoji — outside the supported subset.
      expect(
        SipSignalCodec.encodeMorse(
          sequenceId: 0,
          speedWpm: 15,
          toneInstrument: SipSignalInstrument.sine,
          text: 'HI 🚀',
        ),
        isNull,
      );
      // ASCII non-letter outside the punctuation subset.
      expect(
        SipSignalCodec.encodeMorse(
          sequenceId: 0,
          speedWpm: 15,
          toneInstrument: SipSignalInstrument.sine,
          text: 'HI&BYE',
        ),
        isNull,
      );
    });

    test('out-of-range WPM rejected at encode', () {
      expect(
        SipSignalCodec.encodeMorse(
          sequenceId: 0,
          speedWpm: 1,
          toneInstrument: SipSignalInstrument.sine,
          text: 'OK',
        ),
        isNull,
      );
      expect(
        SipSignalCodec.encodeMorse(
          sequenceId: 0,
          speedWpm: 999,
          toneInstrument: SipSignalInstrument.sine,
          text: 'OK',
        ),
        isNull,
      );
    });
  });

  group('SipSignalCodec.decode rejects malformed input', () {
    test('drops bytes shorter than the 4-byte header', () {
      final r = SipSignalCodec.decode(Uint8List.fromList([0x21, 0x01]));
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.truncatedHeader));
    });

    test('drops bytes larger than maxEnvelopeBytes', () {
      final r = SipSignalCodec.decode(
        Uint8List(SipSignalConstants.maxEnvelopeBytes + 1),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.payloadTooLarge));
    });

    test('drops envelope with wrong typeAndVersion sentinel', () {
      final r = SipSignalCodec.decode(
        Uint8List.fromList([0x99, 0x01, 0x00, 0x00]),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.unsupportedVersion));
    });

    test('drops envelope with unknown kind code', () {
      final r = SipSignalCodec.decode(
        Uint8List.fromList([0x21, 0xFE, 0x00, 0x00]),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.unknownKind));
    });

    test('drops phrase envelope with unknown instrument', () {
      final r = SipSignalCodec.decode(
        Uint8List.fromList([
          0x21, 0x01, 0x00, 0x00, // header
          0xFE, // unknown instrument
          0x01, // noteCount
          60, 18, 100, // one note
        ]),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.unknownInstrument));
    });

    test('drops phrase envelope with truncated notes (count mismatch)', () {
      final r = SipSignalCodec.decode(
        Uint8List.fromList([
          0x21, 0x01, 0x00, 0x00,
          0x01, // sine
          0x03, // claims 3 notes
          60, 18, 100, // only 1 actual note
        ]),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.truncatedNotes));
    });

    test('drops phrase envelope with noteCount=0', () {
      final r = SipSignalCodec.decode(
        Uint8List.fromList([
          0x21, 0x01, 0x00, 0x00,
          0x01,
          0x00, // noteCount=0
        ]),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.invalidNoteCount));
    });

    test('drops Morse envelope with truncated text', () {
      final r = SipSignalCodec.decode(
        Uint8List.fromList([
          0x21, 0x02, 0x00, 0x00,
          15, // wpm
          0x01, // sine
          0x05, // claims 5 chars
          ...utf8.encode('AB'), // only 2 actual bytes
        ]),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.truncatedMorseText));
    });

    test('drops Morse envelope with unsupported character in text', () {
      final r = SipSignalCodec.decode(
        Uint8List.fromList([
          0x21,
          0x02,
          0x00,
          0x00,
          15,
          0x01,
          0x02,
          ...utf8.encode('A&'),
        ]),
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipSignalDecodeError.unsupportedMorseChar));
    });

    test('never throws on random garbage input', () {
      for (final bytes in <Uint8List>[
        Uint8List(0),
        Uint8List.fromList([0]),
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]),
        Uint8List.fromList([0x21, 0x99, 0xAA, 0xBB]),
      ]) {
        // Either ok or a typed fail — never an exception.
        expect(() => SipSignalCodec.decode(bytes), returnsNormally);
      }
    });
  });

  group('SipSignalNote.frequencyHz', () {
    test('MIDI 69 = 440 Hz exactly (anchor)', () {
      final n = SipSignalNote(midiNote: 69, durationTicks: 1, velocity: 100);
      expect(n.frequencyHz, closeTo(440.0, 0.001));
    });

    test('MIDI 60 ≈ 261.63 Hz (middle C)', () {
      final n = SipSignalNote(midiNote: 60, durationTicks: 1, velocity: 100);
      expect(n.frequencyHz, closeTo(261.63, 0.5));
    });

    test('MIDI 81 = 880 Hz (one octave above 440)', () {
      final n = SipSignalNote(midiNote: 81, durationTicks: 1, velocity: 100);
      expect(n.frequencyHz, closeTo(880.0, 0.5));
    });
  });

  group('payloadHashForDedupe', () {
    test('identical bytes produce identical hashes', () {
      final a = Uint8List.fromList([
        0x21,
        0x01,
        0x00,
        0x00,
        0x01,
        0x01,
        60,
        18,
        100,
      ]);
      final b = Uint8List.fromList([
        0x21,
        0x01,
        0x00,
        0x00,
        0x01,
        0x01,
        60,
        18,
        100,
      ]);
      expect(payloadHashForDedupe(a), equals(payloadHashForDedupe(b)));
    });

    test('different bytes produce different hashes', () {
      final a = Uint8List.fromList([1, 2, 3, 4]);
      final b = Uint8List.fromList([1, 2, 3, 5]);
      expect(payloadHashForDedupe(a), isNot(equals(payloadHashForDedupe(b))));
    });
  });
}
