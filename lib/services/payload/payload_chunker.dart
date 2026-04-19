// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'spp_constants.dart';

/// A single chunk definition produced by the chunker.
class ChunkDefinition {
  /// Zero-based chunk index.
  final int index;

  /// Start offset in the original payload.
  final int offset;

  /// Number of bytes in this chunk.
  final int length;

  const ChunkDefinition({
    required this.index,
    required this.offset,
    required this.length,
  });
}

/// Splits a payload into MTU-safe chunks.
///
/// This class is stateless — it produces deterministic chunk definitions
/// from payload length and chunk size parameters without holding the
/// payload bytes itself.
class PayloadChunker {
  /// Create chunk definitions for a payload of [totalBytes].
  ///
  /// Returns an ordered list of [ChunkDefinition] covering the entire
  /// payload. Chunks are [chunkSize] bytes except potentially the last
  /// one, which contains the remainder.
  ///
  /// [stlOverhead] is subtracted from [chunkSize] when STL wrapping is
  /// active, ensuring the wire-level chunk still fits within MTU.
  static List<ChunkDefinition> createChunkDefinitions({
    required int totalBytes,
    int chunkSize = SppLimits.defaultChunkSize,
    int stlOverhead = 0,
  }) {
    if (totalBytes <= 0) return const [];

    final effectiveChunkSize = chunkSize - stlOverhead;
    if (effectiveChunkSize <= 0) {
      throw ArgumentError(
        'Effective chunk size must be positive. '
        'chunkSize=$chunkSize, stlOverhead=$stlOverhead',
      );
    }

    final chunkCount =
        (totalBytes + effectiveChunkSize - 1) ~/ effectiveChunkSize;
    final definitions = <ChunkDefinition>[];

    for (var i = 0; i < chunkCount; i++) {
      final offset = i * effectiveChunkSize;
      final remaining = totalBytes - offset;
      final length = remaining < effectiveChunkSize
          ? remaining
          : effectiveChunkSize;

      definitions.add(
        ChunkDefinition(index: i, offset: offset, length: length),
      );
    }

    return definitions;
  }

  /// Extract the bytes for a specific chunk from [payload].
  ///
  /// Returns a view into the original payload (no copy).
  static Uint8List extractChunkBytes(Uint8List payload, ChunkDefinition chunk) {
    return Uint8List.sublistView(
      payload,
      chunk.offset,
      chunk.offset + chunk.length,
    );
  }

  /// Calculate the number of chunks needed for a payload of [totalBytes].
  static int chunkCount({
    required int totalBytes,
    int chunkSize = SppLimits.defaultChunkSize,
    int stlOverhead = 0,
  }) {
    if (totalBytes <= 0) return 0;
    final effective = chunkSize - stlOverhead;
    if (effective <= 0) return 0;
    return (totalBytes + effective - 1) ~/ effective;
  }
}
