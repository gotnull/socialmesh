// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

/// Parsed Meshtastic port-76 fragment header per `RETICULUM_TUNNEL_V0_1.md`
/// §11.1.
///
/// Wire layout (2 bytes total, prepended to the body):
/// ```
/// offset  size  field      type
/// 0       1     index      uint8       Frame identifier, cycles 0..255
/// 1       1     position   int8        ≥1 = non-last fragment (1-indexed),
///                                       <0 = last fragment, value = -N
///                                       where N is total fragment count
/// 2       N     body       bytes       Slice of the underlying RNS frame
/// ```
class ReticulumFragmentHeader {
  const ReticulumFragmentHeader({
    required this.index,
    required this.position,
    required this.body,
  });

  /// Frame identifier (0..255). Reassembly key component.
  final int index;

  /// Fragment position. Negative ⇒ this is the last fragment of the
  /// frame, and `abs(position)` is the total fragment count `N`.
  /// Positive (≥1) ⇒ this is fragment `(position - 1)` of an N-fragment
  /// frame (1-indexed on the wire).
  final int position;

  /// Body bytes — the slice of the underlying RNS frame this fragment
  /// carries.
  final Uint8List body;

  static const int headerBytes = 2;

  bool get isLast => position < 0;

  /// 1-indexed wire position. Same value as [position] for non-last
  /// fragments; `abs(position)` for the last fragment.
  int get fragmentNumber => position < 0 ? -position : position;
}

/// Thrown when a port-76 payload is too short or carries an
/// out-of-spec position byte.
class ReticulumFragmentDecodeError implements Exception {
  ReticulumFragmentDecodeError(this.reason);
  final String reason;
  @override
  String toString() => 'ReticulumFragmentDecodeError($reason)';
}

/// Pure parser for port-76 fragment headers. No I/O, no state.
class ReticulumFragmentParser {
  const ReticulumFragmentParser();

  /// Parse a port-76 payload into a header + body.
  ///
  /// Throws [ReticulumFragmentDecodeError] if the payload is too short
  /// to hold the 2-byte header, or if the position byte is `0`
  /// (1-indexed positions per §11.6.1; zero is reserved/invalid).
  ReticulumFragmentHeader parse(Uint8List payload) {
    if (payload.length < ReticulumFragmentHeader.headerBytes) {
      throw ReticulumFragmentDecodeError('short_payload len=${payload.length}');
    }
    final index = payload[0];
    // Sign-extend the second byte. Dart's Uint8List gives 0..255;
    // values 128..255 map to -128..-1 as signed int8.
    final raw = payload[1];
    final position = raw >= 128 ? raw - 256 : raw;
    if (position == 0) {
      // Per §11.6.1, positions are 1-indexed; 0 is not a valid
      // wire value.
      throw ReticulumFragmentDecodeError('zero_position');
    }
    final body = Uint8List.fromList(
      payload.sublist(ReticulumFragmentHeader.headerBytes),
    );
    return ReticulumFragmentHeader(
      index: index,
      position: position,
      body: body,
    );
  }
}
