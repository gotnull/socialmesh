// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../../../../../core/logging.dart';
import 'ttt_payload.dart';

/// Tic-Tac-Toe v1 payload codec. Encodes / decodes the 1-byte move
/// payload that rides inside a SIP Play `move` envelope.
///
/// Other actions (`offer` / `accept` / `decline` / `resign`) carry
/// no game-specific payload — the codec returns/expects a zero-byte
/// [Uint8List] for those.
abstract final class TttCodec {
  /// Per-game declared payload budget. The framework uses this to
  /// validate inbound envelope sizes before handing off to the
  /// game-level decoder.
  static const int maxGamePayloadBytes = 1;

  /// Encode a [TttMove] to a single byte.
  ///
  /// Returns null when [TttMove.cell] is out of range — callers
  /// should treat this as a programmer error since UI-level
  /// validation gates illegal taps before reaching this surface.
  static Uint8List? encodeMove(TttMove move) {
    if (move.cell < 0 || move.cell > 8) {
      AppLogging.sipPlay(
        'ttt_encode_blocked reason=cell_out_of_range cell=${move.cell}',
      );
      return null;
    }
    final byte = ((move.mark.code & 0x0F) << 4) | (move.cell & 0x0F);
    return Uint8List.fromList([byte]);
  }

  /// Decode a 1-byte move payload. Returns null on any malformation.
  /// Receivers map the null result to a drop+log outcome — they MUST
  /// NOT throw or apply state changes.
  static TttMove? decodeMove(Uint8List bytes) {
    if (bytes.length != maxGamePayloadBytes) {
      AppLogging.sipPlay(
        'ttt_decode_failed reason=wrong_length bytes=${bytes.length}',
      );
      return null;
    }
    final byte = bytes[0];
    final cell = byte & 0x0F;
    final markCode = (byte >> 4) & 0x0F;
    if (cell > 8) {
      AppLogging.sipPlay(
        'ttt_decode_failed reason=cell_out_of_range cell=$cell',
      );
      return null;
    }
    final mark = TttMark.fromCode(markCode);
    if (mark == null) {
      AppLogging.sipPlay(
        'ttt_decode_failed reason=unknown_mark mark=$markCode',
      );
      return null;
    }
    return TttMove(cell: cell, mark: mark);
  }
}
