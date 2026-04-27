// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP Signal v1 — wire constants for the musical-phrase + Morse
// signal layer that rides inside accepted SIP Handshake DM sessions.
//
// Two signal kinds share one envelope:
//
//   Phrase (kind=0x01): a 1..8 note musical phrase. Each note is a
//   `(midiNote, durationTicks, velocity)` triple — the receiver
//   synthesizes audio LOCALLY using `SipSignalSynthService`. No audio
//   samples are ever placed on the wire.
//
//   Morse (kind=0x02): a short uppercase ASCII phrase + speed (WPM)
//   + tone instrument. The receiver displays the original text AND
//   the regenerated Morse pattern in the bubble, then synthesizes
//   the Morse tones locally on Replay.
//
// Common envelope header (4 bytes):
//
//   u8  typeAndVersion       // 0x21 = type=2 (SipSignal) version=1
//   u8  signalKind           // 0x01=phrase 0x02=morse
//   u16 sequenceId           // big-endian; primary dedupe key
//
// Total payload budget (header + kind body) is bounded by
// [maxEnvelopeBytes] so the rate limiter pre-account stays accurate.

abstract final class SipSignalConstants {
  /// First byte of the envelope. High nibble = protocol family
  /// ("SIP Signal" = 2), low nibble = version (1). Receivers reject
  /// any other value at decode time.
  static const int envelopeTypeAndVersionV1 = 0x21;

  /// Header bytes before the kind-specific payload:
  /// `typeAndVersion(1) + signalKind(1) + sequenceId(2)`.
  static const int envelopeHeaderBytes = 4;

  /// Hard upper bound on a single SIP Signal envelope's wire size,
  /// inclusive of the 4-byte common header. An 8-note phrase fits
  /// in `4 + 1 + 1 + 8*3 = 30` bytes; a 40-char Morse fits in
  /// `4 + 1 + 1 + 1 + 40 = 47` bytes. The ceiling stays well below
  /// the SIP DM wrapper max so a malformed sender can't outrun the
  /// rate limiter.
  static const int maxEnvelopeBytes = 64;

  /// Phrase: maximum notes in a single phrase envelope (v1).
  static const int maxPhraseNotes = 8;

  /// Phrase: per-note tick base (ms). 1 tick = 20 ms → 255 ticks =
  /// 5.1 s, plenty for a held note.
  static const int phraseTickMs = 20;

  /// Phrase: maximum durationTicks per note (u8).
  static const int maxPhraseDurationTicks = 0xFF;

  /// Phrase: maximum MIDI note value. The synth maps MIDI → frequency
  /// via `440 * 2^((midi - 69) / 12)`.
  static const int maxMidiNote = 127;

  /// Phrase: maximum velocity (u8 cap is 0xFF; we use 0..127 for
  /// MIDI-style scaling).
  static const int maxVelocity = 127;

  /// Morse: maximum text characters in a single Morse envelope (v1).
  /// Keeps the bubble readable + the wire payload bounded.
  static const int maxMorseChars = 40;

  /// Morse: default speed (Words Per Minute). Standard SOS speed —
  /// well within human-hand sending range.
  static const int defaultMorseWpm = 15;

  /// Morse: minimum / maximum sender-selectable speed.
  static const int minMorseWpm = 5;
  static const int maxMorseWpm = 30;

  /// Morse: timing unit derivation. unitMs = 1200 / WPM.
  /// At 15 WPM that's 80 ms per dot.
  static int unitMsForWpm(int wpm) {
    final clamped = wpm.clamp(minMorseWpm, maxMorseWpm);
    return 1200 ~/ clamped;
  }
}

/// SIP Signal kind discriminator (envelope byte 1).
enum SipSignalKind {
  /// Musical phrase (1..8 notes). Body: `instrument(1) | noteCount(1)
  /// | (midi(1) | durationTicks(1) | velocity(1)) * noteCount`.
  phrase(0x01),

  /// Morse (uppercase ASCII subset). Body: `speedWpm(1) |
  /// toneInstrument(1) | charCount(1) | utf8Uppercase[charCount]`.
  morse(0x02);

  const SipSignalKind(this.code);
  final int code;

  static SipSignalKind? fromCode(int code) {
    for (final k in values) {
      if (k.code == code) return k;
    }
    return null;
  }
}

/// Built-in instruments. Each maps to a specific synthesis envelope
/// inside `SipSignalSynthService`. The wire only carries the byte
/// code — the synth implementation is local and can evolve.
enum SipSignalInstrument {
  /// Pure sine wave with simple ADSR.
  sine(0x01),

  /// Bell — sine with fast attack + long exponential decay.
  bell(0x02),

  /// Pluck — short noise burst into a low-pass filter (Karplus-Strong
  /// style approximation in v1).
  pluck(0x03),

  /// Chirp — frequency sweep around the target note for an alert /
  /// "hey listen" feel.
  chirp(0x04);

  const SipSignalInstrument(this.code);
  final int code;

  static SipSignalInstrument? fromCode(int code) {
    for (final i in values) {
      if (i.code == code) return i;
    }
    return null;
  }
}
