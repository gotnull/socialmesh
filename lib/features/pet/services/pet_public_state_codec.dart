// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetPublicStateCodec — 8-byte wire format for pet.v1.
//
// Layout (little-endian uint32 for dnaSeed):
//   byte 0   : schema_tag (0x01)
//   bytes 1-4: dnaSeed (uint32 LE)
//   byte 5   : packed1 = (stage & 0x07) << 5 | (branch & 0x07) << 2 | (mood_hi & 0x03)
//              where mood_hi = (mood >> 1) & 0x03
//   byte 6   : packed2 = (mood_lo & 0x01) << 7 | flags
//              flags bits: 0=isAsleep, 1=isSick, 2=isCalling, 3=isEvolving
//              bits 4..6 reserved (must be 0 on encode, ignored on decode)
//   byte 7   : ageInDays (uint8; saturates at 255)
//
// Stage has 6 values → 3 bits. Branch has 5 values → 3 bits. Mood has 6
// values → 3 bits. We split the 3-bit mood across packed1 (high 2 bits) and
// packed2 (low 1 bit) so the layout stays byte-aligned with room for flags.

import 'dart:typed_data';

import '../models/pet_enums.dart';
import '../models/pet_public_state.dart';

class PetPublicStateCodec {
  PetPublicStateCodec._();

  static const int schemaTagV1 = 0x01;
  static const int wireLengthV1 = 8;

  // Flag bit positions within byte 6 low nibble.
  static const int _flagAsleep = 1 << 0;
  static const int _flagSick = 1 << 1;
  static const int _flagCalling = 1 << 2;
  static const int _flagEvolving = 1 << 3;

  /// Encode [state] to its 8-byte wire representation.
  static Uint8List encode(PetPublicState state) {
    final bytes = Uint8List(wireLengthV1);
    bytes[0] = schemaTagV1;

    final seed = state.dnaSeed & 0xFFFFFFFF;
    bytes[1] = seed & 0xFF;
    bytes[2] = (seed >> 8) & 0xFF;
    bytes[3] = (seed >> 16) & 0xFF;
    bytes[4] = (seed >> 24) & 0xFF;

    final stageIdx = state.stage.index & 0x07;
    final branchIdx = state.branch.index & 0x07;
    final moodIdx = state.mood.index & 0x07;
    final moodHi = (moodIdx >> 1) & 0x03;
    final moodLo = moodIdx & 0x01;

    bytes[5] = (stageIdx << 5) | (branchIdx << 2) | moodHi;

    var flags = 0;
    if (state.isAsleep) flags |= _flagAsleep;
    if (state.isSick) flags |= _flagSick;
    if (state.isCalling) flags |= _flagCalling;
    if (state.isEvolving) flags |= _flagEvolving;

    bytes[6] = (moodLo << 7) | (flags & 0x0F);

    bytes[7] = state.ageInDays.clamp(0, 255);

    return bytes;
  }

  /// Decode an 8-byte wire blob. Throws [PetPublicStateDecodeException] on
  /// length mismatch or unknown schema tag.
  static PetPublicState decode(Uint8List bytes) {
    if (bytes.length < wireLengthV1) {
      throw PetPublicStateDecodeException(
        'Blob too short: ${bytes.length} < $wireLengthV1',
      );
    }
    final tag = bytes[0];
    if (tag != schemaTagV1) {
      throw PetPublicStateDecodeException(
        'Unknown schema tag: 0x${tag.toRadixString(16)}',
      );
    }

    final seed =
        bytes[1] | (bytes[2] << 8) | (bytes[3] << 16) | (bytes[4] << 24);

    final packed1 = bytes[5];
    final stageIdx = (packed1 >> 5) & 0x07;
    final branchIdx = (packed1 >> 2) & 0x07;
    final moodHi = packed1 & 0x03;

    final packed2 = bytes[6];
    final moodLo = (packed2 >> 7) & 0x01;
    final moodIdx = (moodHi << 1) | moodLo;
    final flags = packed2 & 0x0F;

    final ageInDays = bytes[7];

    return PetPublicState(
      dnaSeed: seed & 0xFFFFFFFF,
      stage: _safeEnum(PetStage.values, stageIdx),
      branch: _safeEnum(PetBranch.values, branchIdx),
      mood: _safeEnum(PetMood.values, moodIdx),
      ageInDays: ageInDays,
      isAsleep: (flags & _flagAsleep) != 0,
      isSick: (flags & _flagSick) != 0,
      isCalling: (flags & _flagCalling) != 0,
      isEvolving: (flags & _flagEvolving) != 0,
    );
  }

  /// Safely attempt to decode; returns null on any failure. Call sites that
  /// receive arbitrary mesh bytes should prefer this over [decode].
  static PetPublicState? tryDecode(Uint8List bytes) {
    try {
      return decode(bytes);
    } on PetPublicStateDecodeException {
      return null;
    }
  }

  static T _safeEnum<T>(List<T> values, int index) {
    if (index < 0 || index >= values.length) return values.first;
    return values[index];
  }
}

class PetPublicStateDecodeException implements Exception {
  final String message;
  const PetPublicStateDecodeException(this.message);
  @override
  String toString() => 'PetPublicStateDecodeException: $message';
}
