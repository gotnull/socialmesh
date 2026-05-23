// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas digest computation (S9a).
//
// Source of truth: docs/canvas/CANVAS_V0_1.md §6.3 + CANVAS_SYNC_V0_1.md
// §2.1.
//
// Pure functions — no I/O, no Riverpod, no flutter binding. Safe to
// call from any isolate. Two outputs derived from the canonical
// `cell` list of one canvas:
//
//   - globalDigest: BLAKE2s-128 (16 B) of the canonical encoding of
//     EVERY painted cell, sorted ascending by (y, x).
//   - tileDigests: a flat 128-byte buffer = 16 tiles × 8 B per tile.
//     Each tile's 8 B is the first 8 bytes of BLAKE2s-128 over the
//     canonical encoding of cells whose `(x, y)` lies inside that
//     32×32 tile.
//
// Per-cell canonical encoding (12 bytes, little-endian multibyte):
//
//   x          u8   0..127
//   y          u8   0..127
//   color      u8   palette index 0..63
//   last_ts    u32  last_modified epoch seconds
//   last_author u32 originating author_id
//   last_seq   u8   op_seq mod 256
//
// Empty canvas → globalDigest is BLAKE2s-128 of a zero-length input.
// Empty tile → tileDigest is the first 8 B of BLAKE2s-128 of a
// zero-length input. Both are well-defined, non-zero, and unique to
// "empty" so a fresh repo's digest is meaningful (not all-zeros).
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'canvas_constants.dart';
import 'canvas_models.dart';

/// Result of computing digests over a canvas. The three fields land
/// directly into the `canvas` table via `updateCanvasDigests`.
class CanvasDigestSet {
  /// BLAKE2s-128 over the canonical encoding of every cell. Exactly
  /// [CanvasDigestSizes.globalBytes] bytes.
  final Uint8List globalDigest;

  /// 16 × 8 B truncated per-tile digests, in tile-index order
  /// (row-major: `tile_idx = (y/32)*4 + (x/32)`). Exactly
  /// [CanvasDigestSizes.tilesConcatenatedBytes] bytes.
  final Uint8List tileDigests;

  /// Number of cells that contributed to the digest. Echoed to peers
  /// in the `canvas_digest` frame so the receiver can apply the
  /// "richer peer" heuristic without computing local count.
  final int cellCount;

  const CanvasDigestSet({
    required this.globalDigest,
    required this.tileDigests,
    required this.cellCount,
  });
}

/// Compute global + per-tile digests from a snapshot of painted
/// cells. Cells need not be pre-sorted — this function sorts a copy.
///
/// [widthCells] / [heightCells] only affect tile-index math; cells
/// outside the canvas bounds are silently dropped.
Future<CanvasDigestSet> computeCanvasDigests(
  List<CanvasCell> cells, {
  int widthCells = CanvasGeometry.width,
  int heightCells = CanvasGeometry.height,
}) async {
  // Defensive copy + canonical sort by (y, x).
  final sorted = cells.toList(growable: false)
    ..sort((a, b) {
      final dy = a.y.compareTo(b.y);
      if (dy != 0) return dy;
      return a.x.compareTo(b.x);
    });

  // Partition by tile. `tilesPerRow * tilesPerColumn == 16` per
  // CanvasGeometry constants. Storing one BytesBuilder per tile keeps
  // the inner loop allocation-bounded.
  final tileBuilders = <BytesBuilder>[
    for (var i = 0; i < CanvasGeometry.tileCount; i++) BytesBuilder(),
  ];
  final globalBuilder = BytesBuilder();
  var contributingCells = 0;

  for (final cell in sorted) {
    if (cell.x < 0 || cell.x >= widthCells) continue;
    if (cell.y < 0 || cell.y >= heightCells) continue;
    final encoded = _encodeCell(cell);
    globalBuilder.add(encoded);
    final tileIdx = canvasTileIndexForCell(cell.x, cell.y);
    tileBuilders[tileIdx].add(encoded);
    contributingCells++;
  }

  // Hash global.
  final blake = Blake2s(hashLengthInBytes: CanvasDigestSizes.globalBytes);
  final globalHash = await blake.hash(globalBuilder.toBytes());
  final globalDigest = Uint8List.fromList(globalHash.bytes);
  assert(globalDigest.length == CanvasDigestSizes.globalBytes);

  // Hash each tile, truncating to the spec's per-tile size (8 B).
  final tileDigests = Uint8List(CanvasDigestSizes.tilesConcatenatedBytes);
  for (var t = 0; t < CanvasGeometry.tileCount; t++) {
    final tileHash = await blake.hash(tileBuilders[t].toBytes());
    final fullDigest = tileHash.bytes;
    final offset = t * CanvasDigestSizes.tileBytes;
    for (var i = 0; i < CanvasDigestSizes.tileBytes; i++) {
      tileDigests[offset + i] = fullDigest[i] & 0xff;
    }
  }

  return CanvasDigestSet(
    globalDigest: globalDigest,
    tileDigests: tileDigests,
    cellCount: contributingCells,
  );
}

/// Canonical 12-byte cell encoding. Public so test vectors can be
/// reconstructed without re-deriving the layout.
Uint8List _encodeCell(CanvasCell cell) {
  final bytes = Uint8List(_cellEncodedBytes);
  bytes[0] = cell.x & 0xff;
  bytes[1] = cell.y & 0xff;
  bytes[2] = cell.color & 0xff;
  // last_ts: u32 little-endian.
  final ts = cell.lastTs & 0xffffffff;
  bytes[3] = ts & 0xff;
  bytes[4] = (ts >> 8) & 0xff;
  bytes[5] = (ts >> 16) & 0xff;
  bytes[6] = (ts >> 24) & 0xff;
  // last_author: u32 little-endian.
  final author = cell.lastAuthor & 0xffffffff;
  bytes[7] = author & 0xff;
  bytes[8] = (author >> 8) & 0xff;
  bytes[9] = (author >> 16) & 0xff;
  bytes[10] = (author >> 24) & 0xff;
  // last_seq: u8.
  bytes[11] = cell.lastSeq & 0xff;
  return bytes;
}

const int _cellEncodedBytes = 12;
