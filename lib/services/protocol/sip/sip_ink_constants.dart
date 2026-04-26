// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP Ink v1 wire-level constants.
///
/// SIP Ink rides DM_INK (0x45) frames inside an existing accepted SIP
/// DM session. Wire format and test vectors are pinned in
/// `docs/sip/SIP_V0_1.md` §6 "DM_INK (v0.2 amendment)".
///
/// Frame layout:
/// ```
///   global header (4 B)
///     u8 type_and_version  (high nibble = type, low nibble = version)
///     u8 flags             (bit 0 = canvas size, 1..7 reserved = 0)
///     u8 stroke_count      (1..6)
///     u8 total_point_count (2..64)
///   per stroke
///     u8 stroke_flags_and_width   (low nibble = width 1..4)
///     u8 point_count              (>= 2)
///     u8 first_x                  (0..canvasSize-1)
///     u8 first_y                  (0..canvasSize-1)
///     u8 packed_deltas[point_count - 1]
///         high nibble = dx + 8, low nibble = dy + 8 (each in -8..+7)
/// ```
library;

import 'sip_messages_dm.dart';

/// SIP Ink v1 protocol constants. All values are spec-derived; changing
/// any of them requires a SIP version bump and updated test vectors.
abstract final class SipInkConstants {
  /// Type nibble in the global header byte. 0x1 = freehand sketch.
  static const int typeCode = 0x1;

  /// Version nibble. v1 = 0x1.
  static const int versionV1 = 0x1;

  /// Combined `(type << 4) | version` byte for v1 frames: `0x11`.
  static const int typeAndVersionV1 = (typeCode << 4) | versionV1;

  /// Flag bit 0: canvas size. 0 = 64x64, 1 = 128x128.
  static const int flagCanvas128 = 1 << 0;

  /// Reserved flag mask. Bits 1-7 must be zero on the wire.
  static const int reservedFlagMask = 0xFE;

  /// Maximum strokes per sketch.
  static const int maxStrokes = 6;

  /// Maximum total points across all strokes.
  static const int maxTotalPoints = 64;

  /// Minimum points per stroke after dedup. A stroke with one point is
  /// degenerate and is dropped during simplification.
  static const int minPointsPerStroke = 2;

  /// Minimum stroke width.
  static const int minStrokeWidth = 1;

  /// Maximum stroke width.
  static const int maxStrokeWidth = 4;

  /// 64-pixel canvas dimension.
  static const int canvas64 = 64;

  /// 128-pixel canvas dimension.
  static const int canvas128 = 128;

  /// Default canvas dimension. The composer uses this unless the user
  /// flips the larger surface.
  static const int defaultCanvas = canvas64;

  /// Global header size in bytes.
  static const int globalHeaderBytes = 4;

  /// Per-stroke fixed header size in bytes
  /// (`stroke_flags_and_width`, `point_count`, `first_x`, `first_y`).
  static const int strokeHeaderBytes = 4;

  /// Inclusive lower bound on a packed delta nibble.
  static const int deltaMin = -8;

  /// Inclusive upper bound on a packed delta nibble.
  static const int deltaMax = 7;

  /// Maximum payload bytes for a DM_INK frame.
  ///
  /// Mirrors [SipDmConstants.maxDmTextBytes] so SIP Ink shares the same
  /// envelope headroom as DM text and the existing 22-byte SIP wrapper
  /// budget remains valid.
  static const int maxPayloadBytes = SipDmConstants.maxDmTextBytes;

  /// Preferred payload ceiling. The simplifier first targets this size
  /// with a low tolerance and only relaxes towards [maxPayloadBytes]
  /// when needed.
  static const int preferredPayloadBytes = 120;
}
