// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Fuzz cases for MRRP codec testing.
///
/// These cover malformed frames, boundary conditions, and edge cases
/// that the decoder must handle gracefully (return null, no exceptions).
library;

import 'dart:typed_data';

/// Malformed and boundary MRRP frame cases.
abstract final class MrrpFuzzCases {
  /// Empty input.
  static final Uint8List empty = Uint8List(0);

  /// Single byte.
  static final Uint8List oneByte = Uint8List.fromList([0x4D]);

  /// Valid magic bytes only (2 bytes, no header).
  static final Uint8List magicOnly = Uint8List.fromList([0x4D, 0x52]);

  /// Valid magic + truncated header (10 bytes, less than 20).
  static final Uint8List truncatedHeader = Uint8List.fromList([
    0x4D,
    0x52,
    0x00,
    0x01,
    0x10,
    0x00,
    0x14,
    0x00,
    0x01,
    0x00,
  ]);

  /// header_len < 20 (set to 10).
  static final Uint8List headerLenTooSmall = Uint8List.fromList([
    0x4D,
    0x52,
    0x00,
    0x01,
    0x10,
    0x00,
    0x0A,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
  ]);

  /// header_len > total data length (header says 30, actual data 20).
  static final Uint8List headerLenExceedsData = Uint8List.fromList([
    0x4D,
    0x52,
    0x00,
    0x01,
    0x10,
    0x00,
    0x1E,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
  ]);

  /// payload_len > remaining bytes after header.
  static final Uint8List payloadLenExceedsRemaining = Uint8List.fromList([
    0x4D, 0x52, 0x00, 0x01, 0x10, 0x00, 0x14, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x00, 0xFF, 0x00, // payload_len = 255, but no payload follows
  ]);

  /// payload_len = 0 but trailing bytes after header.
  static final Uint8List payloadZeroWithTrailing = Uint8List.fromList([
    0x4D, 0x52, 0x00, 0x01, 0x10, 0x00, 0x14, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00,
    0xAA, 0xBB, // trailing bytes not accounted for
  ]);

  /// version_major = 255 (unsupported future version).
  static final Uint8List versionMajor255 = Uint8List.fromList([
    0x4D,
    0x52,
    0xFF,
    0x01,
    0x10,
    0x00,
    0x14,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
  ]);

  /// All-zero frame (wrong magic).
  static final Uint8List allZero = Uint8List(20);

  /// Max-size frame (215 bytes = full SIP_MAX_PAYLOAD).
  static final Uint8List maxSizeFrame = _buildMaxSizeFrame();

  /// MRRP magic bytes embedded in non-MRRP data (wrong offset).
  static final Uint8List magicInsideNonMrrp = Uint8List.fromList([
    0x00,
    0x00,
    0x4D,
    0x52,
    0x00,
    0x01,
    0x10,
    0x00,
    0x14,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
  ]);

  /// Unknown message type (0xFF).
  static final Uint8List unknownMsgType = Uint8List.fromList([
    0x4D,
    0x52,
    0x00,
    0x01,
    0xFF,
    0x00,
    0x14,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
  ]);

  /// Total frame exceeds SIP_MAX_PAYLOAD (216 bytes).
  static final Uint8List exceedsSipMtu = _buildOversizedFrame();

  static Uint8List _buildMaxSizeFrame() {
    final frame = Uint8List(215);
    frame[0] = 0x4D;
    frame[1] = 0x52;
    frame[2] = 0x00; // version major
    frame[3] = 0x01; // version minor
    frame[4] = 0x10; // REQUEST
    frame[5] = 0x00; // flags
    // header_len = 20 (LE)
    frame[6] = 0x14;
    frame[7] = 0x00;
    // request_id = 1
    frame[8] = 0x01;
    // service_id = 1
    frame[12] = 0x01;
    // action_id = 1
    frame[16] = 0x01;
    // payload_len = 195 (LE: 0xC3 0x00)
    frame[18] = 0xC3;
    frame[19] = 0x00;
    // Fill payload with 0xAA
    for (var i = 20; i < 215; i++) {
      frame[i] = 0xAA;
    }
    return frame;
  }

  static Uint8List _buildOversizedFrame() {
    // 216 bytes total — 1 over SIP_MAX_PAYLOAD
    final frame = Uint8List(216);
    frame[0] = 0x4D;
    frame[1] = 0x52;
    frame[2] = 0x00;
    frame[3] = 0x01;
    frame[4] = 0x10; // REQUEST
    frame[5] = 0x00;
    frame[6] = 0x14; // header_len = 20
    frame[7] = 0x00;
    frame[8] = 0x01;
    frame[12] = 0x01;
    frame[16] = 0x01;
    // payload_len = 196 (LE: 0xC4 0x00)
    frame[18] = 0xC4;
    frame[19] = 0x00;
    for (var i = 20; i < 216; i++) {
      frame[i] = 0xBB;
    }
    return frame;
  }
}
