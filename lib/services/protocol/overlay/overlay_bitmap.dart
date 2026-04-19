// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Compact chunk-receipt bitmap used by SPP v0.2 `BITMAP` frames.
///
/// The bitmap carries one bit per chunk, LSB-first within each byte:
/// byte 0 bit 0 = chunk 0, byte 0 bit 1 = chunk 1, …, byte 0 bit 7 =
/// chunk 7, byte 1 bit 0 = chunk 8, and so on. The packed length is
/// `ceil(chunkCount / 8)` bytes.
///
/// See `docs/sip/OVERLAY_V0_2.md` §11.4 for the wire definition and
/// byte-budget rationale (a 64 KiB resource at 128 B chunks produces
/// a 64 B bitmap — fits comfortably in one LoRa packet).
library;

import 'dart:typed_data';

/// Build + inspect chunk-receipt bitmaps.
abstract final class OverlayBitmap {
  /// Number of bytes required to pack [chunkCount] bits.
  ///
  /// Returns 0 for [chunkCount] == 0. Throws [ArgumentError] for
  /// negative inputs.
  static int byteLength(int chunkCount) {
    if (chunkCount < 0) {
      throw ArgumentError.value(chunkCount, 'chunkCount', 'must be >= 0');
    }
    return (chunkCount + 7) >> 3;
  }

  /// Pack a `Set<int>` of received chunk indexes into a wire bitmap of
  /// width [chunkCount].
  ///
  /// Indexes in [received] that lie outside `[0, chunkCount)` are
  /// silently ignored. The returned buffer is a fresh [Uint8List] of
  /// length `ceil(chunkCount / 8)`.
  static Uint8List encode(Set<int> received, int chunkCount) {
    final buffer = Uint8List(byteLength(chunkCount));
    for (final index in received) {
      if (index < 0 || index >= chunkCount) continue;
      final byteIdx = index >> 3;
      final bitIdx = index & 0x07;
      buffer[byteIdx] |= 1 << bitIdx;
    }
    return buffer;
  }

  /// Pack an ordered iterable of boolean flags into a wire bitmap.
  ///
  /// `flags[i] == true` means chunk `i` has been received. The
  /// resulting buffer has width `ceil(flags.length / 8)`.
  static Uint8List encodeBools(List<bool> flags) {
    final buffer = Uint8List(byteLength(flags.length));
    for (var i = 0; i < flags.length; i++) {
      if (!flags[i]) continue;
      final byteIdx = i >> 3;
      final bitIdx = i & 0x07;
      buffer[byteIdx] |= 1 << bitIdx;
    }
    return buffer;
  }

  /// Decode a wire bitmap into the set of received chunk indexes.
  ///
  /// Only indexes in `[0, chunkCount)` are returned; trailing padding
  /// bits in the final byte are ignored. Throws [FormatException] if
  /// [bitmap] is too short to cover [chunkCount].
  static Set<int> decode(Uint8List bitmap, int chunkCount) {
    if (chunkCount < 0) {
      throw ArgumentError.value(chunkCount, 'chunkCount', 'must be >= 0');
    }
    final required = byteLength(chunkCount);
    if (bitmap.length < required) {
      throw FormatException(
        'bitmap length ${bitmap.length} < required $required for '
        'chunkCount=$chunkCount',
      );
    }
    final received = <int>{};
    for (var i = 0; i < chunkCount; i++) {
      final byteIdx = i >> 3;
      final bitIdx = i & 0x07;
      if ((bitmap[byteIdx] >> bitIdx) & 0x01 == 1) {
        received.add(i);
      }
    }
    return received;
  }

  /// Return the ordered list of chunk indexes in `[0, chunkCount)`
  /// whose bit is clear in [bitmap]. This is the missing-chunks view
  /// used by the sender to schedule retransmissions.
  ///
  /// Throws [FormatException] if [bitmap] is too short.
  static List<int> missingIndexes(Uint8List bitmap, int chunkCount) {
    if (chunkCount < 0) {
      throw ArgumentError.value(chunkCount, 'chunkCount', 'must be >= 0');
    }
    final required = byteLength(chunkCount);
    if (bitmap.length < required) {
      throw FormatException(
        'bitmap length ${bitmap.length} < required $required for '
        'chunkCount=$chunkCount',
      );
    }
    final missing = <int>[];
    for (var i = 0; i < chunkCount; i++) {
      final byteIdx = i >> 3;
      final bitIdx = i & 0x07;
      if ((bitmap[byteIdx] >> bitIdx) & 0x01 == 0) {
        missing.add(i);
      }
    }
    return missing;
  }

  /// True if every chunk index in `[0, chunkCount)` is set in [bitmap].
  static bool isComplete(Uint8List bitmap, int chunkCount) {
    final required = byteLength(chunkCount);
    if (bitmap.length < required) return false;
    for (var i = 0; i < chunkCount; i++) {
      final byteIdx = i >> 3;
      final bitIdx = i & 0x07;
      if ((bitmap[byteIdx] >> bitIdx) & 0x01 == 0) {
        return false;
      }
    }
    return true;
  }

  /// Count of set bits for the first [chunkCount] bits of [bitmap].
  static int popcount(Uint8List bitmap, int chunkCount) {
    final required = byteLength(chunkCount);
    if (bitmap.length < required) {
      throw FormatException(
        'bitmap length ${bitmap.length} < required $required for '
        'chunkCount=$chunkCount',
      );
    }
    var count = 0;
    for (var i = 0; i < chunkCount; i++) {
      final byteIdx = i >> 3;
      final bitIdx = i & 0x07;
      if ((bitmap[byteIdx] >> bitIdx) & 0x01 == 1) count++;
    }
    return count;
  }
}
