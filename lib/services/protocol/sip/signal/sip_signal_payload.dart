// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math' as math;
import 'dart:typed_data';

import 'sip_signal_constants.dart';

/// One musical note inside a SIP Signal phrase envelope.
class SipSignalNote {
  /// MIDI note number (0..127). Frequency derived as
  /// `440 * 2^((midi - 69) / 12)` by the synth.
  final int midiNote;

  /// Duration in 20 ms ticks (0..255 → 0 .. 5.1 s).
  final int durationTicks;

  /// MIDI-style velocity (0..127). Synth scales amplitude.
  final int velocity;

  const SipSignalNote({
    required this.midiNote,
    required this.durationTicks,
    required this.velocity,
  });

  /// Frequency in Hz. Pure helper — no I/O.
  /// Standard MIDI-to-frequency: `freq = 440 * 2^((midi - 69) / 12)`.
  double get frequencyHz =>
      440.0 * math.pow(2, (midiNote - 69) / 12.0).toDouble();

  Duration get duration =>
      Duration(milliseconds: durationTicks * SipSignalConstants.phraseTickMs);
}

/// Decoded SIP Signal envelope. One of [phrase] / [morse] is non-null;
/// the discriminator is [kind].
class SipSignalEnvelope {
  /// Wire `typeAndVersion` byte. v1 sentinel
  /// [SipSignalConstants.envelopeTypeAndVersionV1].
  final int typeAndVersion;

  /// Strongly-typed kind. Receivers reject unknown codes at decode.
  final SipSignalKind kind;

  /// Big-endian u16 dedupe key. The receiver tracks recent
  /// `(direction, sequenceId)` pairs to drop retransmits.
  final int sequenceId;

  /// Phrase body — null when [kind] is [SipSignalKind.morse].
  final SipSignalPhraseBody? phrase;

  /// Morse body — null when [kind] is [SipSignalKind.phrase].
  final SipSignalMorseBody? morse;

  const SipSignalEnvelope({
    required this.typeAndVersion,
    required this.kind,
    required this.sequenceId,
    this.phrase,
    this.morse,
  });
}

/// Phrase-kind body: instrument + 1..8 notes.
class SipSignalPhraseBody {
  final SipSignalInstrument instrument;
  final List<SipSignalNote> notes;

  const SipSignalPhraseBody({required this.instrument, required this.notes});

  int get noteCount => notes.length;
}

/// Morse-kind body: original text + speed + tone instrument. The
/// dot/dash pattern is regenerated on the receiver from [text] —
/// the wire deliberately doesn't carry it.
class SipSignalMorseBody {
  final int speedWpm;
  final SipSignalInstrument toneInstrument;

  /// Uppercase ASCII subset (A-Z 0-9 space . , ? ! / @). Validated
  /// at encode + decode time. Up to [SipSignalConstants.maxMorseChars]
  /// chars.
  final String text;

  const SipSignalMorseBody({
    required this.speedWpm,
    required this.toneInstrument,
    required this.text,
  });

  int get charCount => text.length;
}

/// Outcome of [SipSignalCodec.decode]. The codec never throws —
/// every error path returns a typed [SipSignalDecodeError] so
/// receivers drop+log without exception handling.
class SipSignalDecodeResult {
  final SipSignalEnvelope? envelope;
  final SipSignalDecodeError? error;

  const SipSignalDecodeResult.ok(SipSignalEnvelope e)
    : envelope = e,
      error = null;

  const SipSignalDecodeResult.fail(SipSignalDecodeError e)
    : envelope = null,
      error = e;

  bool get isOk => envelope != null;
}

/// Reasons a SIP Signal envelope can fail to decode. Receivers map
/// every variant to a structured drop+log; UI never shows them
/// verbatim.
enum SipSignalDecodeError {
  /// Fewer than [SipSignalConstants.envelopeHeaderBytes] bytes
  /// provided — couldn't even read the header.
  truncatedHeader,

  /// Total bytes exceed [SipSignalConstants.maxEnvelopeBytes] —
  /// either a malformed sender or a future-version envelope we
  /// can't interpret.
  payloadTooLarge,

  /// `typeAndVersion` byte was not the v1 sentinel.
  unsupportedVersion,

  /// `signalKind` byte didn't resolve to a known [SipSignalKind].
  unknownKind,

  /// Phrase body: instrument byte didn't resolve to a known
  /// [SipSignalInstrument].
  unknownInstrument,

  /// Phrase body: noteCount was 0 or > 8.
  invalidNoteCount,

  /// Phrase body: declared noteCount didn't match the bytes
  /// available (`noteCount * 3`).
  truncatedNotes,

  /// Phrase body: a note had midiNote > 127 or velocity > 127. v1
  /// rejects these — receivers MUST NOT clamp silently.
  invalidNoteFields,

  /// Morse body: speedWpm out of range or tone instrument unknown.
  invalidMorseHeader,

  /// Morse body: declared charCount didn't match the trailing UTF-8
  /// bytes.
  truncatedMorseText,

  /// Morse body: text contained a character outside the supported
  /// uppercase ASCII subset.
  unsupportedMorseChar,

  /// Morse body: text was empty after decoding (charCount == 0).
  emptyMorseText,
}

/// Helper used by encode/decode + receivers. Computes a stable
/// payload hash for dedupe — combined with `(direction, sequenceId)`
/// it lets the manager drop retransmitted signals without false
/// positives across distinct phrases.
int payloadHashForDedupe(Uint8List bytes) {
  // FNV-1a 32-bit. Cheap, stable, no collisions across the small
  // payloads we see (≤64 bytes).
  var hash = 0x811C9DC5;
  for (final b in bytes) {
    hash = (hash ^ b) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
