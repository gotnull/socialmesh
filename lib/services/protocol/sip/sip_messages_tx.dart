// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP-3 micro-exchange message encode/decode.
///
/// Defines wire formats for TX_START, TX_CHUNK, TX_ACK, TX_NACK,
/// TX_DONE, and TX_CANCEL payloads. These formats are documented
/// and parseable but the transfer manager is **deferred to v0.2**
/// due to airtime budget constraints.
///
/// See docs/sip/SIP_V0_1.md "SIP-3 Status: Deferred to v0.2" section.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../utils/text_sanitizer.dart';
import 'sip_constants.dart';
import 'sip_types.dart';

// ---------------------------------------------------------------------------
// TX_START
// ---------------------------------------------------------------------------

/// Parsed TX_START payload.
class SipTxStart {
  /// First 4 bytes of the file's SHA-256.
  final int fileHash32;

  /// Total file size in bytes (max 8192).
  final int totalLen;

  /// Chunk data size in bytes.
  final int chunkSize;

  /// Total number of chunks.
  final int totalChunks;

  /// Optional MIME type (max 24 bytes).
  final String? mime;

  /// Optional filename (max 32 bytes).
  final String? filename;

  /// Full SHA-256 hash (32 bytes).
  final Uint8List fullSha256;

  const SipTxStart({
    required this.fileHash32,
    required this.totalLen,
    required this.chunkSize,
    required this.totalChunks,
    this.mime,
    this.filename,
    required this.fullSha256,
  });
}

// ---------------------------------------------------------------------------
// TX_CHUNK
// ---------------------------------------------------------------------------

/// Parsed TX_CHUNK payload.
class SipTxChunk {
  /// First 4 bytes of the file's SHA-256.
  final int fileHash32;

  /// Zero-based chunk index.
  final int chunkIndex;

  /// Chunk data length in bytes.
  final int chunkLen;

  /// Chunk data bytes.
  final Uint8List chunkData;

  const SipTxChunk({
    required this.fileHash32,
    required this.chunkIndex,
    required this.chunkLen,
    required this.chunkData,
  });
}

// ---------------------------------------------------------------------------
// TX_ACK
// ---------------------------------------------------------------------------

/// Parsed TX_ACK payload.
class SipTxAck {
  /// First 4 bytes of the file's SHA-256.
  final int fileHash32;

  /// Highest contiguously received chunk index.
  final int highestContiguous;

  /// Received bitmap (up to 8 bytes).
  final Uint8List receivedBitmap;

  const SipTxAck({
    required this.fileHash32,
    required this.highestContiguous,
    required this.receivedBitmap,
  });
}

// ---------------------------------------------------------------------------
// TX_NACK
// ---------------------------------------------------------------------------

/// Parsed TX_NACK payload.
class SipTxNack {
  /// First 4 bytes of the file's SHA-256.
  final int fileHash32;

  /// Base chunk index for missing range.
  final int baseIndex;

  /// Number of missing chunks.
  final int missingCount;

  /// Delta-encoded missing chunk indices.
  final Uint8List missingIndicesDeltas;

  const SipTxNack({
    required this.fileHash32,
    required this.baseIndex,
    required this.missingCount,
    required this.missingIndicesDeltas,
  });
}

// ---------------------------------------------------------------------------
// TX_DONE
// ---------------------------------------------------------------------------

/// Parsed TX_DONE payload.
class SipTxDone {
  /// First 4 bytes of the file's SHA-256.
  final int fileHash32;

  /// Total file length in bytes.
  final int totalLen;

  const SipTxDone({required this.fileHash32, required this.totalLen});
}

// ---------------------------------------------------------------------------
// TX_CANCEL
// ---------------------------------------------------------------------------

/// Parsed TX_CANCEL payload.
class SipTxCancel {
  /// First 4 bytes of the file's SHA-256.
  final int fileHash32;

  /// Cancel reason code.
  final SipCancelReason reason;

  const SipTxCancel({required this.fileHash32, required this.reason});
}

// ---------------------------------------------------------------------------
// Encode/decode
// ---------------------------------------------------------------------------

/// Encode/decode helpers for SIP-3 transfer message payloads.
///
/// The transfer manager is deferred to v0.2 but these codecs ensure
/// the wire formats are documented, parseable, and round-trip tested.
abstract final class SipTxMessages {
  // -------------------------------------------------------------------------
  // TX_START
  // -------------------------------------------------------------------------

  /// Encode a [SipTxStart] into a payload [Uint8List].
  static Uint8List encodeTxStart(SipTxStart msg) {
    final mimeBytes = msg.mime != null
        ? Uint8List.fromList(msg.mime!.codeUnits)
        : null;
    final nameBytes = msg.filename != null
        ? Uint8List.fromList(msg.filename!.codeUnits)
        : null;

    final mimeLen = mimeBytes?.length ?? 0;
    final nameLen = nameBytes?.length ?? 0;

    // 4 + 4 + 2 + 2 + 1 + mimeLen + 1 + nameLen + 32
    final totalLen = 12 + 1 + mimeLen + 1 + nameLen + 32;
    final data = ByteData(totalLen);
    var offset = 0;

    data.setUint32(offset, msg.fileHash32, Endian.little);
    offset += 4;
    data.setUint32(offset, msg.totalLen, Endian.little);
    offset += 4;
    data.setUint16(offset, msg.chunkSize, Endian.little);
    offset += 2;
    data.setUint16(offset, msg.totalChunks, Endian.little);
    offset += 2;

    data.setUint8(offset++, mimeLen);
    if (mimeBytes != null) {
      for (var i = 0; i < mimeLen; i++) {
        data.setUint8(offset++, mimeBytes[i]);
      }
    }

    data.setUint8(offset++, nameLen);
    if (nameBytes != null) {
      for (var i = 0; i < nameLen; i++) {
        data.setUint8(offset++, nameBytes[i]);
      }
    }

    final result = data.buffer.asUint8List();
    for (var i = 0; i < 32; i++) {
      result[offset + i] = msg.fullSha256[i];
    }

    return result;
  }

  /// Decode a TX_START payload. Returns null on error.
  static SipTxStart? decodeTxStart(Uint8List payload) {
    // Minimum: 12 + 1 + 0 + 1 + 0 + 32 = 46 bytes
    if (payload.length < 46) {
      AppLogging.sip(
        'SIP_TX: TX_START decode rejected: too short (${payload.length}B)',
      );
      return null;
    }

    final bd = ByteData.sublistView(payload);
    var offset = 0;

    final fileHash32 = bd.getUint32(offset, Endian.little);
    offset += 4;
    final totalLen = bd.getUint32(offset, Endian.little);
    offset += 4;
    final chunkSize = bd.getUint16(offset, Endian.little);
    offset += 2;
    final totalChunks = bd.getUint16(offset, Endian.little);
    offset += 2;

    final mimeLen = bd.getUint8(offset++);
    if (mimeLen > 24 || offset + mimeLen > payload.length) return null;
    final mime = mimeLen > 0
        ? sanitizeExternalText(
            String.fromCharCodes(payload.sublist(offset, offset + mimeLen)),
          )
        : null;
    offset += mimeLen;

    if (offset >= payload.length) return null;
    final nameLen = bd.getUint8(offset++);
    if (nameLen > 32 || offset + nameLen > payload.length) return null;
    final filename = nameLen > 0
        ? sanitizeExternalText(
            String.fromCharCodes(payload.sublist(offset, offset + nameLen)),
          )
        : null;
    offset += nameLen;

    if (offset + 32 > payload.length) return null;
    final fullSha256 = Uint8List.fromList(payload.sublist(offset, offset + 32));

    if (totalLen > SipConstants.maxTransferSize) {
      AppLogging.sip('SIP_TX: TX_START total_len=$totalLen exceeds max');
      return null;
    }

    return SipTxStart(
      fileHash32: fileHash32,
      totalLen: totalLen,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      mime: mime,
      filename: filename,
      fullSha256: fullSha256,
    );
  }

  // -------------------------------------------------------------------------
  // TX_CHUNK
  // -------------------------------------------------------------------------

  /// Encode a [SipTxChunk] into a payload [Uint8List].
  static Uint8List encodeTxChunk(SipTxChunk msg) {
    final data = ByteData(SipConstants.sipTxChunkHeader + msg.chunkLen);
    data.setUint32(0, msg.fileHash32, Endian.little);
    data.setUint16(4, msg.chunkIndex, Endian.little);
    data.setUint16(6, msg.chunkLen, Endian.little);

    final result = data.buffer.asUint8List();
    for (var i = 0; i < msg.chunkLen; i++) {
      result[SipConstants.sipTxChunkHeader + i] = msg.chunkData[i];
    }
    return result;
  }

  /// Decode a TX_CHUNK payload. Returns null on error.
  static SipTxChunk? decodeTxChunk(Uint8List payload) {
    if (payload.length < SipConstants.sipTxChunkHeader) {
      AppLogging.sip(
        'SIP_TX: TX_CHUNK decode rejected: too short (${payload.length}B)',
      );
      return null;
    }

    final bd = ByteData.sublistView(payload);
    final fileHash32 = bd.getUint32(0, Endian.little);
    final chunkIndex = bd.getUint16(4, Endian.little);
    final chunkLen = bd.getUint16(6, Endian.little);

    if (SipConstants.sipTxChunkHeader + chunkLen > payload.length) {
      return null;
    }

    if (chunkLen > SipConstants.sipChunkSize) {
      AppLogging.sip('SIP_TX: TX_CHUNK chunk_len=$chunkLen exceeds max');
      return null;
    }

    final chunkData = Uint8List.fromList(
      payload.sublist(
        SipConstants.sipTxChunkHeader,
        SipConstants.sipTxChunkHeader + chunkLen,
      ),
    );

    return SipTxChunk(
      fileHash32: fileHash32,
      chunkIndex: chunkIndex,
      chunkLen: chunkLen,
      chunkData: chunkData,
    );
  }

  // -------------------------------------------------------------------------
  // TX_ACK
  // -------------------------------------------------------------------------

  /// Encode a [SipTxAck] into a payload [Uint8List].
  static Uint8List encodeTxAck(SipTxAck msg) {
    // 4 + 2 + bitmap
    final data = ByteData(6 + msg.receivedBitmap.length);
    data.setUint32(0, msg.fileHash32, Endian.little);
    data.setUint16(4, msg.highestContiguous, Endian.little);

    final result = data.buffer.asUint8List();
    for (var i = 0; i < msg.receivedBitmap.length; i++) {
      result[6 + i] = msg.receivedBitmap[i];
    }
    return result;
  }

  /// Decode a TX_ACK payload. Returns null on error.
  static SipTxAck? decodeTxAck(Uint8List payload) {
    if (payload.length < 6) {
      AppLogging.sip(
        'SIP_TX: TX_ACK decode rejected: too short (${payload.length}B)',
      );
      return null;
    }

    final bd = ByteData.sublistView(payload);
    final fileHash32 = bd.getUint32(0, Endian.little);
    final highestContiguous = bd.getUint16(4, Endian.little);
    final bitmap = Uint8List.fromList(payload.sublist(6));

    return SipTxAck(
      fileHash32: fileHash32,
      highestContiguous: highestContiguous,
      receivedBitmap: bitmap,
    );
  }

  // -------------------------------------------------------------------------
  // TX_NACK
  // -------------------------------------------------------------------------

  /// Encode a [SipTxNack] into a payload [Uint8List].
  static Uint8List encodeTxNack(SipTxNack msg) {
    // 4 + 2 + 1 + deltas
    final data = ByteData(7 + msg.missingIndicesDeltas.length);
    data.setUint32(0, msg.fileHash32, Endian.little);
    data.setUint16(4, msg.baseIndex, Endian.little);
    data.setUint8(6, msg.missingCount);

    final result = data.buffer.asUint8List();
    for (var i = 0; i < msg.missingIndicesDeltas.length; i++) {
      result[7 + i] = msg.missingIndicesDeltas[i];
    }
    return result;
  }

  /// Decode a TX_NACK payload. Returns null on error.
  static SipTxNack? decodeTxNack(Uint8List payload) {
    if (payload.length < 7) {
      AppLogging.sip(
        'SIP_TX: TX_NACK decode rejected: too short (${payload.length}B)',
      );
      return null;
    }

    final bd = ByteData.sublistView(payload);
    final fileHash32 = bd.getUint32(0, Endian.little);
    final baseIndex = bd.getUint16(4, Endian.little);
    final missingCount = bd.getUint8(6);
    final deltas = Uint8List.fromList(payload.sublist(7));

    return SipTxNack(
      fileHash32: fileHash32,
      baseIndex: baseIndex,
      missingCount: missingCount,
      missingIndicesDeltas: deltas,
    );
  }

  // -------------------------------------------------------------------------
  // TX_DONE
  // -------------------------------------------------------------------------

  /// Encode a [SipTxDone] into a payload [Uint8List].
  static Uint8List encodeTxDone(SipTxDone msg) {
    final data = ByteData(8);
    data.setUint32(0, msg.fileHash32, Endian.little);
    data.setUint32(4, msg.totalLen, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Decode a TX_DONE payload. Returns null on error.
  static SipTxDone? decodeTxDone(Uint8List payload) {
    if (payload.length < 8) {
      AppLogging.sip(
        'SIP_TX: TX_DONE decode rejected: too short (${payload.length}B)',
      );
      return null;
    }

    final bd = ByteData.sublistView(payload);
    return SipTxDone(
      fileHash32: bd.getUint32(0, Endian.little),
      totalLen: bd.getUint32(4, Endian.little),
    );
  }

  // -------------------------------------------------------------------------
  // TX_CANCEL
  // -------------------------------------------------------------------------

  /// Encode a [SipTxCancel] into a payload [Uint8List].
  static Uint8List encodeTxCancel(SipTxCancel msg) {
    final data = ByteData(5);
    data.setUint32(0, msg.fileHash32, Endian.little);
    data.setUint8(4, msg.reason.code);
    return data.buffer.asUint8List();
  }

  /// Decode a TX_CANCEL payload. Returns null on error.
  static SipTxCancel? decodeTxCancel(Uint8List payload) {
    if (payload.length < 5) {
      AppLogging.sip(
        'SIP_TX: TX_CANCEL decode rejected: too short (${payload.length}B)',
      );
      return null;
    }

    final bd = ByteData.sublistView(payload);
    final fileHash32 = bd.getUint32(0, Endian.little);
    final reasonCode = bd.getUint8(4);
    final reason = SipCancelReason.fromCode(reasonCode);
    if (reason == null) {
      AppLogging.sip(
        'SIP_TX: TX_CANCEL unknown reason=0x${reasonCode.toRadixString(16)}',
      );
      return null;
    }

    return SipTxCancel(fileHash32: fileHash32, reason: reason);
  }
}
