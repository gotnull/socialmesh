// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/logging.dart';

/// Result of a reassembly attempt.
sealed class ReassemblyResult {
  const ReassemblyResult();
}

/// Reassembly succeeded — payload verified and complete.
class ReassemblySuccess extends ReassemblyResult {
  /// The reassembled payload bytes.
  final Uint8List payload;

  const ReassemblySuccess(this.payload);
}

/// Reassembly is still in progress — not all chunks received yet.
class ReassemblyIncomplete extends ReassemblyResult {
  /// Number of chunks received so far.
  final int receivedCount;

  /// Total expected chunks.
  final int totalCount;

  /// Missing chunk indexes (for NACK generation).
  final List<int> missingIndexes;

  const ReassemblyIncomplete({
    required this.receivedCount,
    required this.totalCount,
    required this.missingIndexes,
  });
}

/// Reassembly failed — integrity check did not pass.
class ReassemblyFailed extends ReassemblyResult {
  /// Human-readable reason for failure.
  final String reason;

  const ReassemblyFailed(this.reason);
}

/// Accepts chunks in any order, detects completeness, and reconstructs
/// the original payload exactly once.
///
/// Thread-safe for single-isolate use (no concurrent mutation).
/// Supports expiry cleanup via [isExpired].
class PayloadReassembler {
  /// Unique payload identifier (hex string).
  final String payloadIdHex;

  /// Expected total payload size in bytes.
  final int totalBytes;

  /// Total number of expected chunks.
  final int chunkCount;

  /// SHA-256 hash of the complete payload (from OFFER).
  final Uint8List sha256Hash;

  /// When this reassembler expires (for cleanup).
  final DateTime expiresAt;

  /// Internal chunk buffer: chunkIndex -> chunk bytes.
  final Map<int, Uint8List> _chunks = {};

  /// Set of received chunk indexes (for fast lookup).
  final Set<int> _receivedIndexes = {};

  /// Whether reassembly has been completed (prevents double-complete).
  bool _completed = false;

  PayloadReassembler({
    required this.payloadIdHex,
    required this.totalBytes,
    required this.chunkCount,
    required this.sha256Hash,
    required this.expiresAt,
  });

  /// Number of chunks received so far.
  int get receivedCount => _receivedIndexes.length;

  /// Whether all chunks have been received (not yet verified).
  bool get isComplete => _receivedIndexes.length == chunkCount;

  /// Whether this reassembler has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether reassembly has already been finalized.
  bool get isFinalized => _completed;

  /// Set of received chunk indexes (read-only copy).
  Set<int> get receivedIndexes => Set.unmodifiable(_receivedIndexes);

  /// Progress as a fraction [0.0, 1.0].
  double get progress => chunkCount > 0 ? receivedCount / chunkCount : 0.0;

  /// Add a chunk. Returns true if this was a new chunk, false if duplicate.
  ///
  /// Validates the chunk index against [chunkCount]. Ignores duplicates
  /// silently (returns false).
  bool addChunk(int chunkIndex, Uint8List chunkData) {
    if (_completed) {
      AppLogging.spp(
        'reassembler: $payloadIdHex chunk $chunkIndex ignored (completed)',
      );
      return false;
    }

    if (chunkIndex < 0 || chunkIndex >= chunkCount) {
      AppLogging.spp(
        'reassembler: $payloadIdHex chunk $chunkIndex out of range '
        '(0..${chunkCount - 1})',
      );
      return false;
    }

    if (_receivedIndexes.contains(chunkIndex)) {
      AppLogging.spp(
        'reassembler: $payloadIdHex chunk $chunkIndex duplicate ignored',
      );
      return false;
    }

    _chunks[chunkIndex] = chunkData;
    _receivedIndexes.add(chunkIndex);
    return true;
  }

  /// Get the list of missing chunk indexes (for NACK generation).
  List<int> getMissingIndexes() {
    final missing = <int>[];
    for (var i = 0; i < chunkCount; i++) {
      if (!_receivedIndexes.contains(i)) missing.add(i);
    }
    return missing;
  }

  /// Attempt to reassemble the payload.
  ///
  /// Returns:
  /// - [ReassemblySuccess] if all chunks present and SHA-256 matches
  /// - [ReassemblyIncomplete] if chunks are still missing
  /// - [ReassemblyFailed] if verification fails
  ///
  /// Once [ReassemblySuccess] is returned, this reassembler is finalized
  /// and will reject further chunks.
  ReassemblyResult tryReassemble() {
    if (_completed) {
      return const ReassemblyFailed('already finalized');
    }

    if (!isComplete) {
      return ReassemblyIncomplete(
        receivedCount: receivedCount,
        totalCount: chunkCount,
        missingIndexes: getMissingIndexes(),
      );
    }

    // Reassemble in order
    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < chunkCount; i++) {
      final chunk = _chunks[i];
      if (chunk == null) {
        return ReassemblyFailed('missing chunk $i after completeness check');
      }
      builder.add(chunk);
    }

    final payload = builder.toBytes();

    // Verify size
    if (payload.length != totalBytes) {
      AppLogging.spp(
        'reassembler: $payloadIdHex size mismatch '
        '(got ${payload.length}, expected $totalBytes)',
      );
      return ReassemblyFailed(
        'size mismatch: got ${payload.length}, expected $totalBytes',
      );
    }

    // Verify SHA-256
    final hash = sha256.convert(payload);
    var hashMatch = hash.bytes.length == sha256Hash.length;
    if (hashMatch) {
      for (var i = 0; i < hash.bytes.length; i++) {
        if (hash.bytes[i] != sha256Hash[i]) {
          hashMatch = false;
          break;
        }
      }
    }

    if (!hashMatch) {
      AppLogging.spp('reassembler: $payloadIdHex SHA-256 mismatch');
      return const ReassemblyFailed('SHA-256 mismatch');
    }

    _completed = true;
    _chunks.clear(); // Free memory

    AppLogging.spp(
      'reassembler: $payloadIdHex complete (${payload.length} bytes verified)',
    );

    return ReassemblySuccess(Uint8List.fromList(payload));
  }

  /// Free all chunk buffers and mark as finalized.
  void dispose() {
    _chunks.clear();
    _receivedIndexes.clear();
    _completed = true;
  }
}
