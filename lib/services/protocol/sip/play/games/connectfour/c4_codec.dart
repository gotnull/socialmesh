// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../../../../../core/logging.dart';
import 'c4_payload.dart';

/// Connect Four v1 payload codec. Encodes / decodes the 1-byte move
/// payload that rides inside a SIP Play `move` envelope.
///
/// Other actions (`offer` / `accept` / `decline` / `resign`) carry
/// no game-specific payload — the codec returns/expects a zero-byte
/// [Uint8List] for those.
abstract final class C4Codec {
  /// Per-game declared payload budget. The framework uses this to
  /// validate inbound envelope sizes before handing off to the
  /// game-level decoder.
  static const int maxGamePayloadBytes = 1;

  /// Encode a [C4Move] to a single byte.
  ///
  /// Returns null when [C4Move.column] is out of range — callers
  /// should treat this as a programmer error since UI-level
  /// validation gates illegal taps before reaching this surface.
  static Uint8List? encodeMove(C4Move move) {
    if (move.column < 0 || move.column > 6) {
      AppLogging.sipPlay(
        'c4_encode_blocked reason=column_out_of_range column=${move.column}',
      );
      return null;
    }
    final byte = ((move.disc.code & 0x0F) << 4) | (move.column & 0x0F);
    return Uint8List.fromList([byte]);
  }

  /// Decode a 1-byte move payload. Returns null on any malformation.
  /// Receivers map the null result to a drop+log outcome — they MUST
  /// NOT throw or apply state changes.
  static C4Move? decodeMove(Uint8List bytes) {
    if (bytes.length != maxGamePayloadBytes) {
      AppLogging.sipPlay(
        'c4_decode_failed reason=wrong_length bytes=${bytes.length}',
      );
      return null;
    }
    final byte = bytes[0];
    final column = byte & 0x0F;
    final discCode = (byte >> 4) & 0x0F;
    if (column > 6) {
      AppLogging.sipPlay(
        'c4_decode_failed reason=column_out_of_range column=$column',
      );
      return null;
    }
    final disc = C4Disc.fromCode(discCode);
    if (disc == null) {
      AppLogging.sipPlay('c4_decode_failed reason=unknown_disc disc=$discCode');
      return null;
    }
    return C4Move(column: column, disc: disc);
  }
}
