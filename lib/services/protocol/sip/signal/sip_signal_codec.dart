// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/logging.dart';
import 'morse_table.dart';
import 'sip_signal_constants.dart';
import 'sip_signal_payload.dart';

/// SIP Signal v1 binary codec — phrase OR Morse, single envelope.
///
/// Wire layout:
///
/// ```
/// offset  size  field
/// 0       1     typeAndVersion        (0x21)
/// 1       1     signalKind            (0x01 phrase, 0x02 morse)
/// 2       2     sequenceId            (big-endian u16)
/// 4       N     kind-specific payload
/// ```
///
/// Phrase body (kind=0x01):
/// ```
/// 4       1     instrument            (1=sine, 2=bell, 3=pluck, 4=chirp)
/// 5       1     noteCount             (1..8)
/// 6       3*N   (midi, durationTicks, velocity) tuples
/// ```
///
/// Morse body (kind=0x02):
/// ```
/// 4       1     speedWpm              (5..30; default 15)
/// 5       1     toneInstrument
/// 6       1     charCount             (1..40)
/// 7       N     utf8Uppercase[charCount]   (A-Z 0-9 ' .,?!/@')
/// ```
///
/// The codec is pure — no I/O, no clock, no audio. Validation is
/// strict: out-of-range fields, unsupported instruments / kinds /
/// chars all yield typed [SipSignalDecodeError]s rather than
/// exceptions or silent fixups.
abstract final class SipSignalCodec {
  /// Encode a phrase into wire bytes. Returns null when the resulting
  /// envelope would exceed [SipSignalConstants.maxEnvelopeBytes] or
  /// any field is out of range — caller should treat null as a
  /// programmer error (UI-level validation gates ranges before
  /// reaching this surface).
  static Uint8List? encodePhrase({
    required int sequenceId,
    required SipSignalInstrument instrument,
    required List<SipSignalNote> notes,
  }) {
    if (sequenceId < 0 || sequenceId > 0xFFFF) {
      AppLogging.sipSignal(
        'encode_blocked reason=sequence_id_out_of_range seq=$sequenceId',
      );
      return null;
    }
    if (notes.isEmpty || notes.length > SipSignalConstants.maxPhraseNotes) {
      AppLogging.sipSignal(
        'encode_blocked reason=invalid_note_count count=${notes.length}',
      );
      return null;
    }
    for (final n in notes) {
      if (n.midiNote < 0 || n.midiNote > SipSignalConstants.maxMidiNote) {
        AppLogging.sipSignal(
          'encode_blocked reason=midi_out_of_range midi=${n.midiNote}',
        );
        return null;
      }
      if (n.durationTicks < 0 ||
          n.durationTicks > SipSignalConstants.maxPhraseDurationTicks) {
        AppLogging.sipSignal(
          'encode_blocked reason=duration_out_of_range '
          'ticks=${n.durationTicks}',
        );
        return null;
      }
      if (n.velocity < 0 || n.velocity > SipSignalConstants.maxVelocity) {
        AppLogging.sipSignal(
          'encode_blocked reason=velocity_out_of_range vel=${n.velocity}',
        );
        return null;
      }
    }

    final headerBytes = SipSignalConstants.envelopeHeaderBytes;
    final phraseHeaderBytes = 2; // instrument + noteCount
    final notesBytes = notes.length * 3;
    final total = headerBytes + phraseHeaderBytes + notesBytes;
    if (total > SipSignalConstants.maxEnvelopeBytes) {
      AppLogging.sipSignal(
        'encode_blocked reason=envelope_too_large bytes=$total',
      );
      return null;
    }

    final out = Uint8List(total);
    out[0] = SipSignalConstants.envelopeTypeAndVersionV1;
    out[1] = SipSignalKind.phrase.code;
    out[2] = (sequenceId >> 8) & 0xFF;
    out[3] = sequenceId & 0xFF;
    out[4] = instrument.code & 0xFF;
    out[5] = notes.length & 0xFF;
    var offset = headerBytes + phraseHeaderBytes;
    for (final n in notes) {
      out[offset++] = n.midiNote & 0xFF;
      out[offset++] = n.durationTicks & 0xFF;
      out[offset++] = n.velocity & 0xFF;
    }
    return out;
  }

  /// Encode a Morse phrase. Returns null on any range / charset
  /// violation. Caller should validate text via
  /// [MorseTable.isEncodable] first.
  static Uint8List? encodeMorse({
    required int sequenceId,
    required int speedWpm,
    required SipSignalInstrument toneInstrument,
    required String text,
  }) {
    if (sequenceId < 0 || sequenceId > 0xFFFF) return null;
    if (speedWpm < SipSignalConstants.minMorseWpm ||
        speedWpm > SipSignalConstants.maxMorseWpm) {
      AppLogging.sipSignal(
        'encode_blocked reason=wpm_out_of_range wpm=$speedWpm',
      );
      return null;
    }
    final upper = text.toUpperCase();
    if (upper.isEmpty || upper.length > SipSignalConstants.maxMorseChars) {
      AppLogging.sipSignal(
        'encode_blocked reason=invalid_morse_length len=${upper.length}',
      );
      return null;
    }
    if (!MorseTable.isEncodable(upper)) {
      AppLogging.sipSignal('encode_blocked reason=unsupported_morse_char');
      return null;
    }
    final utf8Bytes = utf8.encode(upper);
    final headerBytes = SipSignalConstants.envelopeHeaderBytes;
    final morseHeaderBytes = 3; // wpm + toneInstrument + charCount
    final total = headerBytes + morseHeaderBytes + utf8Bytes.length;
    if (total > SipSignalConstants.maxEnvelopeBytes) {
      AppLogging.sipSignal(
        'encode_blocked reason=envelope_too_large bytes=$total',
      );
      return null;
    }

    final out = Uint8List(total);
    out[0] = SipSignalConstants.envelopeTypeAndVersionV1;
    out[1] = SipSignalKind.morse.code;
    out[2] = (sequenceId >> 8) & 0xFF;
    out[3] = sequenceId & 0xFF;
    out[4] = speedWpm & 0xFF;
    out[5] = toneInstrument.code & 0xFF;
    out[6] = utf8Bytes.length & 0xFF;
    out.setRange(headerBytes + morseHeaderBytes, total, utf8Bytes);
    return out;
  }

  /// Decode wire bytes into a [SipSignalEnvelope]. Pure — no I/O —
  /// and never throws. Every error is reported via
  /// [SipSignalDecodeResult.fail] so the dispatcher drops+logs
  /// without `try/catch`.
  static SipSignalDecodeResult decode(Uint8List bytes) {
    if (bytes.length < SipSignalConstants.envelopeHeaderBytes) {
      AppLogging.sipSignal(
        'decode_failed reason=truncated_header bytes=${bytes.length}',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.truncatedHeader,
      );
    }
    if (bytes.length > SipSignalConstants.maxEnvelopeBytes) {
      AppLogging.sipSignal(
        'decode_failed reason=payload_too_large bytes=${bytes.length}',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.payloadTooLarge,
      );
    }

    final typeAndVersion = bytes[0];
    if (typeAndVersion != SipSignalConstants.envelopeTypeAndVersionV1) {
      AppLogging.sipSignal(
        'decode_failed reason=unsupported_version '
        'tv=0x${typeAndVersion.toRadixString(16)}',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.unsupportedVersion,
      );
    }

    final kind = SipSignalKind.fromCode(bytes[1]);
    if (kind == null) {
      AppLogging.sipSignal(
        'decode_failed reason=unknown_kind code=0x${bytes[1].toRadixString(16)}',
      );
      return const SipSignalDecodeResult.fail(SipSignalDecodeError.unknownKind);
    }

    final sequenceId = (bytes[2] << 8) | bytes[3];

    switch (kind) {
      case SipSignalKind.phrase:
        return _decodePhraseBody(bytes, sequenceId);
      case SipSignalKind.morse:
        return _decodeMorseBody(bytes, sequenceId);
    }
  }

  static SipSignalDecodeResult _decodePhraseBody(
    Uint8List bytes,
    int sequenceId,
  ) {
    final headerBytes = SipSignalConstants.envelopeHeaderBytes;
    if (bytes.length < headerBytes + 2) {
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.truncatedNotes,
      );
    }
    final instrument = SipSignalInstrument.fromCode(bytes[headerBytes]);
    if (instrument == null) {
      AppLogging.sipSignal(
        'decode_failed reason=unknown_instrument '
        'code=0x${bytes[headerBytes].toRadixString(16)}',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.unknownInstrument,
      );
    }
    final noteCount = bytes[headerBytes + 1];
    if (noteCount == 0 || noteCount > SipSignalConstants.maxPhraseNotes) {
      AppLogging.sipSignal(
        'decode_failed reason=invalid_note_count count=$noteCount',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.invalidNoteCount,
      );
    }
    final expectedTotal = headerBytes + 2 + (noteCount * 3);
    if (bytes.length != expectedTotal) {
      AppLogging.sipSignal(
        'decode_failed reason=truncated_notes have=${bytes.length} '
        'want=$expectedTotal',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.truncatedNotes,
      );
    }
    final notes = <SipSignalNote>[];
    var offset = headerBytes + 2;
    for (var i = 0; i < noteCount; i += 1) {
      final midi = bytes[offset++];
      final durationTicks = bytes[offset++];
      final velocity = bytes[offset++];
      if (midi > SipSignalConstants.maxMidiNote ||
          velocity > SipSignalConstants.maxVelocity) {
        AppLogging.sipSignal(
          'decode_failed reason=invalid_note_fields midi=$midi '
          'velocity=$velocity',
        );
        return const SipSignalDecodeResult.fail(
          SipSignalDecodeError.invalidNoteFields,
        );
      }
      notes.add(
        SipSignalNote(
          midiNote: midi,
          durationTicks: durationTicks,
          velocity: velocity,
        ),
      );
    }
    return SipSignalDecodeResult.ok(
      SipSignalEnvelope(
        typeAndVersion: SipSignalConstants.envelopeTypeAndVersionV1,
        kind: SipSignalKind.phrase,
        sequenceId: sequenceId,
        phrase: SipSignalPhraseBody(instrument: instrument, notes: notes),
      ),
    );
  }

  static SipSignalDecodeResult _decodeMorseBody(
    Uint8List bytes,
    int sequenceId,
  ) {
    final headerBytes = SipSignalConstants.envelopeHeaderBytes;
    if (bytes.length < headerBytes + 3) {
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.invalidMorseHeader,
      );
    }
    final speedWpm = bytes[headerBytes];
    final toneInstrument = SipSignalInstrument.fromCode(bytes[headerBytes + 1]);
    if (toneInstrument == null ||
        speedWpm < SipSignalConstants.minMorseWpm ||
        speedWpm > SipSignalConstants.maxMorseWpm) {
      AppLogging.sipSignal(
        'decode_failed reason=invalid_morse_header wpm=$speedWpm '
        'tone=0x${bytes[headerBytes + 1].toRadixString(16)}',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.invalidMorseHeader,
      );
    }
    final charCount = bytes[headerBytes + 2];
    if (charCount == 0) {
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.emptyMorseText,
      );
    }
    if (charCount > SipSignalConstants.maxMorseChars) {
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.invalidMorseHeader,
      );
    }
    final textStart = headerBytes + 3;
    final textEnd = textStart + charCount;
    if (bytes.length != textEnd) {
      AppLogging.sipSignal(
        'decode_failed reason=truncated_morse_text have=${bytes.length} '
        'want=$textEnd',
      );
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.truncatedMorseText,
      );
    }
    String text;
    try {
      text = utf8.decode(
        bytes.sublist(textStart, textEnd),
        allowMalformed: false,
      );
    } catch (_) {
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.unsupportedMorseChar,
      );
    }
    final upper = text.toUpperCase();
    if (upper != text) {
      // Receivers reject lowercase / mixed case — uppercase
      // normalisation is the sender's job.
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.unsupportedMorseChar,
      );
    }
    if (!MorseTable.isEncodable(upper)) {
      AppLogging.sipSignal('decode_failed reason=unsupported_morse_char');
      return const SipSignalDecodeResult.fail(
        SipSignalDecodeError.unsupportedMorseChar,
      );
    }

    return SipSignalDecodeResult.ok(
      SipSignalEnvelope(
        typeAndVersion: SipSignalConstants.envelopeTypeAndVersionV1,
        kind: SipSignalKind.morse,
        sequenceId: sequenceId,
        morse: SipSignalMorseBody(
          speedWpm: speedWpm,
          toneInstrument: toneInstrument,
          text: upper,
        ),
      ),
    );
  }
}
