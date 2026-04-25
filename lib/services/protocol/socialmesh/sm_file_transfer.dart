// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../utils/text_sanitizer.dart';
import '../../payload/spp_constants.dart';
import 'sm_constants.dart';

/// File transfer packet types carried over Meshtastic private portnums.
///
/// Wire formats:
///
/// FILE_OFFER (manifest):
/// ```
/// [header:1][fileId:16][filenameLen:1][filename:N]
/// [mimeTypeLen:1][mimeType:N][totalBytes:4][chunkSize:2]
/// [chunkCount:2][sha256:32][createdAt:8][expiresAt:8][flags:1]
/// ```
///
/// FILE_CHUNK (payload fragment):
/// ```
/// [header:1][fileId:16][chunkIndex:2][chunkCount:2]
/// [bytesLen:2][bytes:N]
/// ```
///
/// FILE_NACK (missing chunk request):
/// ```
/// [header:1][fileId:16][missingCount:1][missingIndexes:2*N]
/// ```
///
/// FILE_ACK (completion confirmation):
/// ```
/// [header:1][fileId:16][status:1]
/// ```

/// Generates a random 128-bit file ID using a CSPRNG.
Uint8List generateFileId() {
  final rng = Random.secure();
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return bytes;
}

/// Converts a 128-bit file ID to a hex string for display/storage.
String fileIdToHex(Uint8List fileId) {
  return fileId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Parses a hex string back to a 128-bit file ID.
Uint8List? fileIdFromHex(String hex) {
  if (hex.length != 32) return null;
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    final b = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (b == null) return null;
    bytes[i] = b;
  }
  return bytes;
}

/// Transport mode preference for file transfers.
enum FileTransportMode {
  auto, // Let the engine decide (RF if direct, MQTT if available)
  rfOnly, // RF mesh only
  mqttOnly, // MQTT only
}

/// File transfer offer flags (bit field in flags byte).
abstract final class FileOfferFlags {
  /// Bit 0: Whether fetchHint is present (Phase 3 store-and-forward).
  static const int hasFetchHint = 0x01;

  /// Bit 1: Whether the transfer is targeted (DM) vs broadcast.
  static const int isDirected = 0x02;
}

// ---------------------------------------------------------------------------
// FILE_OFFER — manifest packet
// ---------------------------------------------------------------------------

/// A file transfer manifest announcing file metadata.
class SmFileOffer {
  /// 128-bit unique file transfer ID.
  final Uint8List fileId;

  /// Original filename (max 64 bytes UTF-8).
  final String filename;

  /// MIME type string (max 64 bytes UTF-8).
  final String mimeType;

  /// Total file size in bytes.
  final int totalBytes;

  /// Size of each chunk in bytes (last chunk may be smaller).
  final int chunkSize;

  /// Total number of chunks.
  final int chunkCount;

  /// SHA-256 hash of the complete file.
  final Uint8List sha256Hash;

  /// Unix timestamp (seconds) when the transfer was created.
  final int createdAt;

  /// Unix timestamp (seconds) when the transfer expires.
  final int expiresAt;

  /// Whether this is a directed (DM) transfer.
  final bool isDirected;

  /// Phase 3 store-and-forward hint (empty for Phase 1).
  final String fetchHint;

  const SmFileOffer({
    required this.fileId,
    required this.filename,
    required this.mimeType,
    required this.totalBytes,
    required this.chunkSize,
    required this.chunkCount,
    required this.sha256Hash,
    required this.createdAt,
    required this.expiresAt,
    this.isDirected = false,
    this.fetchHint = '',
  });

  /// Create a manifest from raw file bytes.
  factory SmFileOffer.fromFile({
    required String filename,
    required String mimeType,
    required Uint8List fileBytes,
    int? chunkSize,
    bool isDirected = false,
    Duration ttl = const Duration(hours: 24),
    String fetchHint = '',
  }) {
    final effectiveChunkSize =
        chunkSize ?? SmFileTransferLimits.defaultChunkSize;
    final chunkCount = (fileBytes.length / effectiveChunkSize).ceil();
    final hash = sha256.convert(fileBytes);
    final now = DateTime.now();

    return SmFileOffer(
      fileId: generateFileId(),
      filename: filename,
      mimeType: mimeType,
      totalBytes: fileBytes.length,
      chunkSize: effectiveChunkSize,
      chunkCount: chunkCount,
      sha256Hash: Uint8List.fromList(hash.bytes),
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      expiresAt: now.add(ttl).millisecondsSinceEpoch ~/ 1000,
      isDirected: isDirected,
      fetchHint: fetchHint,
    );
  }

  /// Encode to binary payload.
  ///
  /// Returns null if the payload would exceed MTU or validation fails.
  Uint8List? encode() {
    final filenameBytes = utf8.encode(filename);
    final mimeTypeBytes = utf8.encode(mimeType);
    final fetchHintBytes = fetchHint.isNotEmpty
        ? utf8.encode(fetchHint)
        : Uint8List(0);

    if (filenameBytes.length > 64) return null;
    if (mimeTypeBytes.length > 64) return null;
    if (fileId.length != 16) return null;
    if (sha256Hash.length != 32) return null;

    // Calculate total size.
    var size = 1; // header
    size += 16; // fileId
    size += 1 + filenameBytes.length; // filenameLen + filename
    size += 1 + mimeTypeBytes.length; // mimeTypeLen + mimeType
    size += 4; // totalBytes
    size += 2; // chunkSize
    size += 2; // chunkCount
    size += 32; // sha256
    size += 8; // createdAt
    size += 8; // expiresAt
    size += 1; // flags
    if (fetchHintBytes.isNotEmpty) {
      size += 1 + fetchHintBytes.length;
    }

    final buffer = ByteData(size);
    var offset = 0;

    // Header: version=SPP v1, kind=FILE_OFFER (4) → 0x14
    buffer.setUint8(
      offset++,
      (SppVersion.current << 4) | SmPacketKind.fileOffer,
    );

    // File ID
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(offset, offset + 16, fileId);
    offset += 16;

    // Filename
    buffer.setUint8(offset++, filenameBytes.length);
    bytes.setRange(offset, offset + filenameBytes.length, filenameBytes);
    offset += filenameBytes.length;

    // MIME type
    buffer.setUint8(offset++, mimeTypeBytes.length);
    bytes.setRange(offset, offset + mimeTypeBytes.length, mimeTypeBytes);
    offset += mimeTypeBytes.length;

    // Total bytes (uint32 big-endian)
    buffer.setUint32(offset, totalBytes, Endian.big);
    offset += 4;

    // Chunk size (uint16 big-endian)
    buffer.setUint16(offset, chunkSize, Endian.big);
    offset += 2;

    // Chunk count (uint16 big-endian)
    buffer.setUint16(offset, chunkCount, Endian.big);
    offset += 2;

    // SHA-256
    bytes.setRange(offset, offset + 32, sha256Hash);
    offset += 32;

    // Created at (int64 big-endian)
    buffer.setInt64(offset, createdAt, Endian.big);
    offset += 8;

    // Expires at (int64 big-endian)
    buffer.setInt64(offset, expiresAt, Endian.big);
    offset += 8;

    // Flags
    var flags = 0;
    if (fetchHintBytes.isNotEmpty) flags |= FileOfferFlags.hasFetchHint;
    if (isDirected) flags |= FileOfferFlags.isDirected;
    buffer.setUint8(offset++, flags);

    // Fetch hint (optional)
    if (fetchHintBytes.isNotEmpty) {
      buffer.setUint8(offset++, fetchHintBytes.length);
      bytes.setRange(offset, offset + fetchHintBytes.length, fetchHintBytes);
      offset += fetchHintBytes.length;
    }

    return buffer.buffer.asUint8List(0, offset);
  }

  /// Decode from binary payload.
  ///
  /// Returns null if the payload is malformed or has an unsupported version.
  static SmFileOffer? decode(Uint8List data) {
    if (data.length < 76) return null; // minimum size

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Header byte
    final header = buffer.getUint8(offset++);
    final version = (header >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    final kind = header & 0x0F;
    if (kind != SmPacketKind.fileOffer) return null;

    // File ID
    if (offset + 16 > data.length) return null;
    final fileId = Uint8List.fromList(data.sublist(offset, offset + 16));
    offset += 16;

    // Filename
    if (offset >= data.length) return null;
    final filenameLen = buffer.getUint8(offset++);
    if (offset + filenameLen > data.length) return null;
    final filename = sanitizeExternalText(
      utf8.decode(
        data.sublist(offset, offset + filenameLen),
        allowMalformed: true,
      ),
    );
    offset += filenameLen;

    // MIME type
    if (offset >= data.length) return null;
    final mimeTypeLen = buffer.getUint8(offset++);
    if (offset + mimeTypeLen > data.length) return null;
    final mimeType = sanitizeExternalText(
      utf8.decode(
        data.sublist(offset, offset + mimeTypeLen),
        allowMalformed: true,
      ),
    );
    offset += mimeTypeLen;

    // Total bytes
    if (offset + 4 > data.length) return null;
    final totalBytes = buffer.getUint32(offset, Endian.big);
    offset += 4;

    // Chunk size
    if (offset + 2 > data.length) return null;
    final chunkSize = buffer.getUint16(offset, Endian.big);
    offset += 2;

    // Chunk count
    if (offset + 2 > data.length) return null;
    final chunkCount = buffer.getUint16(offset, Endian.big);
    offset += 2;

    // SHA-256
    if (offset + 32 > data.length) return null;
    final sha256Hash = Uint8List.fromList(data.sublist(offset, offset + 32));
    offset += 32;

    // Created at
    if (offset + 8 > data.length) return null;
    final createdAt = buffer.getInt64(offset, Endian.big);
    offset += 8;

    // Expires at
    if (offset + 8 > data.length) return null;
    final expiresAt = buffer.getInt64(offset, Endian.big);
    offset += 8;

    // Flags
    if (offset >= data.length) return null;
    final flags = buffer.getUint8(offset++);
    final hasFetchHint = (flags & FileOfferFlags.hasFetchHint) != 0;
    final isDirected = (flags & FileOfferFlags.isDirected) != 0;

    // Fetch hint (optional)
    var fetchHint = '';
    if (hasFetchHint && offset < data.length) {
      final hintLen = buffer.getUint8(offset++);
      if (offset + hintLen <= data.length) {
        fetchHint = sanitizeExternalText(
          utf8.decode(
            data.sublist(offset, offset + hintLen),
            allowMalformed: true,
          ),
        );
        offset += hintLen;
      }
    }

    return SmFileOffer(
      fileId: fileId,
      filename: filename,
      mimeType: mimeType,
      totalBytes: totalBytes,
      chunkSize: chunkSize,
      chunkCount: chunkCount,
      sha256Hash: sha256Hash,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isDirected: isDirected,
      fetchHint: fetchHint,
    );
  }
}

// ---------------------------------------------------------------------------
// FILE_CHUNK — payload fragment
// ---------------------------------------------------------------------------

/// A single chunk of a file transfer.
class SmFileChunk {
  /// 128-bit file transfer ID (matches offer).
  final Uint8List fileId;

  /// Zero-based index of this chunk.
  final int chunkIndex;

  /// Total number of chunks (for validation).
  final int chunkCount;

  /// Chunk payload bytes.
  final Uint8List payload;

  const SmFileChunk({
    required this.fileId,
    required this.chunkIndex,
    required this.chunkCount,
    required this.payload,
  });

  /// Encode to binary payload.
  Uint8List? encode() {
    if (fileId.length != 16) return null;
    if (payload.isEmpty) return null;

    final size = 1 + 16 + 2 + 2 + 2 + payload.length;
    final buffer = ByteData(size);
    var offset = 0;

    // Header: version=SPP v1, kind=FILE_CHUNK (5) → 0x15
    buffer.setUint8(
      offset++,
      (SppVersion.current << 4) | SmPacketKind.fileChunk,
    );

    // File ID
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(offset, offset + 16, fileId);
    offset += 16;

    // Chunk index (uint16 big-endian)
    buffer.setUint16(offset, chunkIndex, Endian.big);
    offset += 2;

    // Chunk count (uint16 big-endian)
    buffer.setUint16(offset, chunkCount, Endian.big);
    offset += 2;

    // Bytes length (uint16 big-endian)
    buffer.setUint16(offset, payload.length, Endian.big);
    offset += 2;

    // Payload bytes
    bytes.setRange(offset, offset + payload.length, payload);
    offset += payload.length;

    return buffer.buffer.asUint8List(0, offset);
  }

  /// Decode from binary payload.
  static SmFileChunk? decode(Uint8List data) {
    if (data.length < 23) return null; // header + fileId + idx + count + len

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Header
    final header = buffer.getUint8(offset++);
    final version = (header >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    final kind = header & 0x0F;
    if (kind != SmPacketKind.fileChunk) return null;

    // File ID
    if (offset + 16 > data.length) return null;
    final fileId = Uint8List.fromList(data.sublist(offset, offset + 16));
    offset += 16;

    // Chunk index
    if (offset + 2 > data.length) return null;
    final chunkIndex = buffer.getUint16(offset, Endian.big);
    offset += 2;

    // Chunk count
    if (offset + 2 > data.length) return null;
    final chunkCount = buffer.getUint16(offset, Endian.big);
    offset += 2;

    // Bytes length
    if (offset + 2 > data.length) return null;
    final bytesLen = buffer.getUint16(offset, Endian.big);
    offset += 2;

    // Payload
    if (offset + bytesLen > data.length) return null;
    final payload = Uint8List.fromList(data.sublist(offset, offset + bytesLen));

    return SmFileChunk(
      fileId: fileId,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
      payload: payload,
    );
  }
}

// ---------------------------------------------------------------------------
// FILE_NACK — missing chunk request
// ---------------------------------------------------------------------------

/// Request for retransmission of missing chunks.
class SmFileNack {
  /// 128-bit file transfer ID.
  final Uint8List fileId;

  /// List of missing chunk indexes (bounded).
  final List<int> missingIndexes;

  const SmFileNack({required this.fileId, required this.missingIndexes});

  /// Encode to binary payload.
  Uint8List? encode() {
    if (fileId.length != 16) return null;
    if (missingIndexes.isEmpty) return null;
    // Bound the NACK list to prevent mesh pollution.
    final bounded = missingIndexes.length > SmFileTransferLimits.maxNackIndexes
        ? missingIndexes.sublist(0, SmFileTransferLimits.maxNackIndexes)
        : missingIndexes;

    final size = 1 + 16 + 1 + (bounded.length * 2);
    final buffer = ByteData(size);
    var offset = 0;

    // Header: version=SPP v1, kind=FILE_NACK (6) → 0x16
    buffer.setUint8(
      offset++,
      (SppVersion.current << 4) | SmPacketKind.fileNack,
    );

    // File ID
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(offset, offset + 16, fileId);
    offset += 16;

    // Missing count
    buffer.setUint8(offset++, bounded.length);

    // Missing indexes (uint16 big-endian each)
    for (final idx in bounded) {
      buffer.setUint16(offset, idx, Endian.big);
      offset += 2;
    }

    return buffer.buffer.asUint8List(0, offset);
  }

  /// Decode from binary payload.
  static SmFileNack? decode(Uint8List data) {
    if (data.length < 18) return null; // header + fileId + count

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Header
    final header = buffer.getUint8(offset++);
    final version = (header >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    final kind = header & 0x0F;
    if (kind != SmPacketKind.fileNack) return null;

    // File ID
    if (offset + 16 > data.length) return null;
    final fileId = Uint8List.fromList(data.sublist(offset, offset + 16));
    offset += 16;

    // Missing count
    if (offset >= data.length) return null;
    final count = buffer.getUint8(offset++);

    // Missing indexes
    final missing = <int>[];
    for (var i = 0; i < count; i++) {
      if (offset + 2 > data.length) break;
      missing.add(buffer.getUint16(offset, Endian.big));
      offset += 2;
    }

    if (missing.isEmpty) return null;

    return SmFileNack(fileId: fileId, missingIndexes: missing);
  }
}

// ---------------------------------------------------------------------------
// FILE_ACK — completion confirmation
// ---------------------------------------------------------------------------

/// File transfer acknowledgement status.
enum FileAckStatus {
  complete, // 0: File received and verified
  rejected, // 1: File rejected (too large, rate limit, etc.)
  cancelled, // 2: Transfer cancelled by receiver
}

/// Completion confirmation for a file transfer.
class SmFileAck {
  /// 128-bit file transfer ID.
  final Uint8List fileId;

  /// Acknowledgement status.
  final FileAckStatus status;

  const SmFileAck({required this.fileId, required this.status});

  /// Encode to binary payload.
  Uint8List? encode() {
    if (fileId.length != 16) return null;

    final buffer = ByteData(18); // header + fileId + status
    var offset = 0;

    // Header: version=SPP v1, kind=FILE_ACK (7) → 0x17
    buffer.setUint8(offset++, (SppVersion.current << 4) | SmPacketKind.fileAck);

    // File ID
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(offset, offset + 16, fileId);
    offset += 16;

    // Status
    buffer.setUint8(offset++, status.index);

    return buffer.buffer.asUint8List(0, offset);
  }

  /// Decode from binary payload.
  static SmFileAck? decode(Uint8List data) {
    if (data.length < 18) return null;

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Header
    final header = buffer.getUint8(offset++);
    final version = (header >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    final kind = header & 0x0F;
    if (kind != SmPacketKind.fileAck) return null;

    // File ID
    if (offset + 16 > data.length) return null;
    final fileId = Uint8List.fromList(data.sublist(offset, offset + 16));
    offset += 16;

    // Status
    if (offset >= data.length) return null;
    final statusIndex = buffer.getUint8(offset++);
    final status = statusIndex < FileAckStatus.values.length
        ? FileAckStatus.values[statusIndex]
        : FileAckStatus.rejected;

    return SmFileAck(fileId: fileId, status: status);
  }
}
