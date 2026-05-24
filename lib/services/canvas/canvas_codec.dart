// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas wire codec — encode/decode for canvas.v1 action payloads.
//
// Source of truth: docs/canvas/CANVAS_V0_1.md §4, §5, §6.
// Tests in test/services/canvas/codec/ pin byte vectors against the
// spec; do not relax decoders without revising the spec first.
//
// Common rules enforced by every decoder:
//   - magic byte at offset 0 MUST be 0xCA
//   - version byte at offset 1 MUST be 0x01
//   - op_type at offset 2 echoes the action_id low byte
//   - reserved color bits (top 2 of any palette index) MUST be 0
//   - flags reserved bits (2..7) MUST be 0
//   - all multibyte integers are little-endian
//
// Encoders return `null` only when input is rejected by the spec's
// encoder-side invariants (oversize batch, wrong digest length, etc.);
// caller-bug input (negative coordinates, etc.) throws ArgumentError.
// Decoders return `null` on any spec violation — they never throw.
library;

import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import 'canvas_constants.dart';

// ---------------------------------------------------------------------------
// Action ids and shared header layout
// ---------------------------------------------------------------------------

/// Action ids for canvas.v1. The low byte equals the `op_type` field
/// emitted at offset 2 of every payload.
enum CanvasAction {
  paint(0x0001),
  paintBatch(0x0002),
  canvasDigest(0x0003),
  syncRequest(0x0004),
  syncResponse(0x0005),
  canvasInfo(0x0006),
  presence(0x0007);

  const CanvasAction(this.code);

  final int code;

  int get opTypeByte => code & 0xFF;
}

/// Wire-level constants shared by every action. Changing any of these
/// is a spec break and requires a wire version bump.
abstract final class CanvasWireFormat {
  /// Common-prefix magic byte at offset 0.
  static const int magic = 0xCA;

  /// canvas.v1 wire version byte at offset 1. NOT the MRRP version.
  static const int version = 0x01;

  /// Length of the common prefix in bytes (`magic + version + op_type
  /// + flags + canvas_id`).
  static const int commonPrefixLen = 12;

  /// `flags` bit 0: set on paint_batch, clear on every other action.
  static const int flagBitBatch = 1 << 0;

  /// `flags` bit 1: set on paint / paint_batch when the author opts out
  /// of attribution (`author_id` MUST be 0 when set).
  static const int flagBitAnonymousAuthor = 1 << 1;

  /// Bitmask of reserved flag bits (2..7). MUST be 0 in v0.1.
  static const int reservedFlagBitsMask = 0xFC;

  /// Bitmask of reserved color bits (top 2). MUST be 0 in v0.1.
  static const int reservedColorBitsMask = 0xC0;

  /// MRRP frame payload budget. Every encoded canvas payload MUST fit.
  static const int mrrpMaxPayload = 195;

  /// paint_batch op-count cap (inclusive). Receivers MUST reject larger.
  static const int paintBatchMaxOps = 21;

  /// Maximum RLE runs that fit in a single sync_response frame
  /// (encoding 0): `floor((195 - 18) / 2) = 88`.
  static const int syncResponseMaxRunsPerFrame = 88;

  /// Total bands per tile in sync_response encoding 1 (raw banded).
  /// 32×32 tile / (32×4 band) = 8 bands.
  static const int syncResponseRawBandCount = 8;

  /// Cells per raw band: 32 wide × 4 tall.
  static const int syncResponseRawBandCells = 128;

  /// Sync_request rect MUST be a 32×32 tile (`x1 == x0+31`, `y1 == y0+31`).
  static const int syncTileSpan = CanvasGeometry.tileSize - 1;
}

// ---------------------------------------------------------------------------
// Op models
// ---------------------------------------------------------------------------

/// Single paint op (action 0x0001). Wire shape: 24 bytes.
@immutable
class CanvasPaintOp {
  final int canvasId;
  final int x;
  final int y;
  final int color;
  final int authorId;
  final int opTs;
  final int opSeq;
  final bool anonymousAuthor;

  const CanvasPaintOp({
    required this.canvasId,
    required this.x,
    required this.y,
    required this.color,
    required this.authorId,
    required this.opTs,
    required this.opSeq,
    this.anonymousAuthor = false,
  });
}

/// A single packed record inside a paint_batch frame. Wire shape: 5 bytes.
@immutable
class CanvasBatchedPaintRecord {
  final int x;
  final int y;
  final int color;

  /// Signed i8 offset (seconds) relative to the batch_ts header.
  final int tsOffset;

  /// u8 mod-256 monotonic sequence within the author's stream.
  final int opSeq;

  const CanvasBatchedPaintRecord({
    required this.x,
    required this.y,
    required this.color,
    required this.tsOffset,
    required this.opSeq,
  });
}

/// Batched paint op (action 0x0002). Wire shape: 22 + 5N bytes.
@immutable
class CanvasPaintBatchOp {
  final int canvasId;
  final int authorId;
  final int batchTs;
  final int batchSeq;
  final List<CanvasBatchedPaintRecord> ops;
  final bool anonymousAuthor;

  const CanvasPaintBatchOp({
    required this.canvasId,
    required this.authorId,
    required this.batchTs,
    required this.batchSeq,
    required this.ops,
    this.anonymousAuthor = false,
  });
}

/// Digest advert (action 0x0003). Wire shape: 160 bytes.
@immutable
class CanvasDigestOp {
  final int canvasId;

  /// Exactly 16 bytes.
  final Uint8List globalDigest;
  final int cellCount;

  /// Concatenated per-tile digest blob, exactly
  /// [CanvasDigestSizes.tilesConcatenatedBytes] bytes
  /// (v0.1 64×64 → 32 bytes = 4 tiles × 8).
  final Uint8List tileDigests;

  const CanvasDigestOp({
    required this.canvasId,
    required this.globalDigest,
    required this.cellCount,
    required this.tileDigests,
  });
}

/// Sync request (action 0x0004). Wire shape: 18 bytes. v0.1 always
/// targets exactly one tile-aligned 32×32 rect.
@immutable
class CanvasSyncRequestOp {
  final int canvasId;
  final int tileX;
  final int tileY;

  const CanvasSyncRequestOp({
    required this.canvasId,
    required this.tileX,
    required this.tileY,
  });

  int get x0 => tileX * CanvasGeometry.tileSize;
  int get y0 => tileY * CanvasGeometry.tileSize;
  int get x1 => x0 + CanvasWireFormat.syncTileSpan;
  int get y1 => y0 + CanvasWireFormat.syncTileSpan;
}

/// Sync response (action 0x0005). The body has two encodings — RLE
/// single-frame, OR raw banded multi-frame — discriminated by the
/// `encoding` byte at offset 14.
sealed class CanvasSyncResponseBody {
  const CanvasSyncResponseBody();
}

/// One run-length record inside an encoding-0 sync_response.
@immutable
class CanvasSyncResponseRun {
  /// 1..255 consecutive cells of the same colour.
  final int length;
  final int color;

  const CanvasSyncResponseRun({required this.length, required this.color});
}

/// Encoding 0: opportunistic RLE single-frame for low-entropy tiles.
@immutable
class CanvasSyncResponseRleBody extends CanvasSyncResponseBody {
  final List<CanvasSyncResponseRun> runs;

  const CanvasSyncResponseRleBody({required this.runs});
}

/// Encoding 1: deterministic raw band for high-entropy tiles. Each
/// band carries exactly 128 raw palette indices for a 32×4 strip.
@immutable
class CanvasSyncResponseRawBandBody extends CanvasSyncResponseBody {
  /// `band_index` (0..7). 0 = top strip, 7 = bottom.
  final int bandIndex;

  /// Exactly 128 palette-index bytes, raster order within the strip.
  final Uint8List cells;

  const CanvasSyncResponseRawBandBody({
    required this.bandIndex,
    required this.cells,
  });
}

/// Sync response (action 0x0005).
@immutable
class CanvasSyncResponseOp {
  final int canvasId;
  final int tileX;
  final int tileY;
  final CanvasSyncResponseBody body;

  const CanvasSyncResponseOp({
    required this.canvasId,
    required this.tileX,
    required this.tileY,
    required this.body,
  });
}

/// Presence state on the wire byte at offset 16 of a presence frame.
/// Source: docs/canvas/CANVAS_PRESENCE_V0_1.md §2.3.
///
/// Receivers MUST drop frames whose state byte is outside this enum.
/// `leaving` is transient: it evicts the matching cache entry and is
/// never stored as a persistent state value in the cache (cf. §4.1).
enum PresenceState {
  viewing(0x00),
  active(0x01),
  painting(0x02),
  leaving(0x03);

  const PresenceState(this.code);

  final int code;

  static PresenceState? fromCode(int code) {
    for (final s in PresenceState.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Presence advert (action 0x0007). Wire shape: 24 bytes.
/// Source: docs/canvas/CANVAS_PRESENCE_V0_1.md §2.2.
///
/// Presence is inherently identity-bound; the anonymous-author flag
/// is incompatible with presence and is rejected by the decoder
/// (invariant P7).
@immutable
class CanvasPresenceOp {
  final int canvasId;
  final int authorId;
  final PresenceState state;

  /// u32 LE Unix seconds when the emitter produced this frame.
  final int emitTs;

  /// u16 LE seconds. Wire bounds are [60, 600] inclusive; decoder
  /// rejects out-of-range values.
  final int ttlSeconds;

  const CanvasPresenceOp({
    required this.canvasId,
    required this.authorId,
    required this.state,
    required this.emitTs,
    required this.ttlSeconds,
  });
}

/// canvas_info request payload (action 0x0006). Wire shape: 16 bytes.
@immutable
class CanvasInfoRequest {
  final int canvasId;

  const CanvasInfoRequest({required this.canvasId});
}

/// canvas_info response payload (action 0x0006). Wire shape: 36 bytes.
@immutable
class CanvasInfoResponse {
  final int canvasId;
  final int width;
  final int height;
  final int paletteId;

  /// 0 = open, 1 = read_only, 2 = archived.
  final int status;
  final int createdAt;
  final int ownerId;
  final int cellCount;

  /// UTF-8 bytes, NUL-padded to exactly 8 bytes on the wire.
  final Uint8List nameHint;

  const CanvasInfoResponse({
    required this.canvasId,
    required this.width,
    required this.height,
    required this.paletteId,
    required this.status,
    required this.createdAt,
    required this.ownerId,
    required this.cellCount,
    required this.nameHint,
  });
}

// ---------------------------------------------------------------------------
// Codec
// ---------------------------------------------------------------------------

/// canvas.v1 wire codec. All methods are static.
abstract final class CanvasCodec {
  // ---------------------------------------------------------------------------
  // Sniff
  // ---------------------------------------------------------------------------

  /// Inspect a payload's common prefix and return the discovered action,
  /// or `null` if magic/version/op_type are not recognized.
  static CanvasAction? sniffAction(Uint8List payload) {
    if (payload.length < CanvasWireFormat.commonPrefixLen) return null;
    if (payload[0] != CanvasWireFormat.magic) return null;
    if (payload[1] != CanvasWireFormat.version) return null;
    final opType = payload[2];
    for (final action in CanvasAction.values) {
      if (action.opTypeByte == opType) return action;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // paint (action 0x0001) — 24 bytes
  // ---------------------------------------------------------------------------

  static Uint8List? encodePaint(CanvasPaintOp op) {
    _validateCellCoords(op.x, op.y);
    _validateColor(op.color);
    _validateAuthorAnonymity(
      authorId: op.authorId,
      anonymous: op.anonymousAuthor,
    );
    final flags = op.anonymousAuthor
        ? CanvasWireFormat.flagBitAnonymousAuthor
        : 0;
    final buf = ByteData(24);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.paint,
      canvasId: op.canvasId,
      flags: flags,
    );
    buf.setUint8(12, op.x);
    buf.setUint8(13, op.y);
    buf.setUint8(14, op.color);
    buf.setUint32(15, op.authorId, Endian.little);
    buf.setUint32(19, op.opTs, Endian.little);
    buf.setUint8(23, op.opSeq);
    return buf.buffer.asUint8List();
  }

  static CanvasPaintOp? decodePaint(Uint8List payload) {
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.paint,
      expectedLen: 24,
      expectBatchBit: false,
    )) {
      return null;
    }
    final buf = _viewOf(payload);
    final flags = payload[3];
    final anonymous = (flags & CanvasWireFormat.flagBitAnonymousAuthor) != 0;
    final canvasId = buf.getUint64(4, Endian.little);
    final x = payload[12];
    final y = payload[13];
    final color = payload[14];
    if (x > CanvasLimits.cellCoordMax || y > CanvasLimits.cellCoordMax) {
      _logDecodeDrop('paint: cell out of range ($x,$y)');
      return null;
    }
    if ((color & CanvasWireFormat.reservedColorBitsMask) != 0) {
      _logDecodeDrop(
        'paint: reserved color bits set (0x${color.toRadixString(16)})',
      );
      return null;
    }
    final authorId = buf.getUint32(15, Endian.little);
    if (anonymous && authorId != 0) {
      _logDecodeDrop('paint: anonymous flag set but author_id != 0');
      return null;
    }
    final opTs = buf.getUint32(19, Endian.little);
    final opSeq = payload[23];
    return CanvasPaintOp(
      canvasId: canvasId,
      x: x,
      y: y,
      color: color,
      authorId: authorId,
      opTs: opTs,
      opSeq: opSeq,
      anonymousAuthor: anonymous,
    );
  }

  // ---------------------------------------------------------------------------
  // paint_batch (action 0x0002) — 22 + 5N bytes, 1 <= N <= 21
  // ---------------------------------------------------------------------------

  static Uint8List? encodePaintBatch(CanvasPaintBatchOp batch) {
    if (batch.ops.isEmpty) {
      AppLogging.meshCanvas('paint_batch encode rejected: empty ops');
      return null;
    }
    if (batch.ops.length > CanvasWireFormat.paintBatchMaxOps) {
      AppLogging.meshCanvas(
        'paint_batch encode rejected: ${batch.ops.length} '
        '> ${CanvasWireFormat.paintBatchMaxOps}',
      );
      return null;
    }
    _validateAuthorAnonymity(
      authorId: batch.authorId,
      anonymous: batch.anonymousAuthor,
    );
    for (final op in batch.ops) {
      _validateCellCoords(op.x, op.y);
      _validateColor(op.color);
      _validateTsOffset(op.tsOffset);
    }
    final total = 22 + 5 * batch.ops.length;
    final buf = ByteData(total);
    final flags =
        CanvasWireFormat.flagBitBatch |
        (batch.anonymousAuthor ? CanvasWireFormat.flagBitAnonymousAuthor : 0);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.paintBatch,
      canvasId: batch.canvasId,
      flags: flags,
    );
    buf.setUint32(12, batch.authorId, Endian.little);
    buf.setUint32(16, batch.batchTs, Endian.little);
    buf.setUint8(20, batch.ops.length);
    buf.setUint8(21, batch.batchSeq);
    var off = 22;
    for (final op in batch.ops) {
      buf.setUint8(off, op.x);
      buf.setUint8(off + 1, op.y);
      buf.setUint8(off + 2, op.color);
      buf.setInt8(off + 3, op.tsOffset);
      buf.setUint8(off + 4, op.opSeq);
      off += 5;
    }
    return buf.buffer.asUint8List();
  }

  static CanvasPaintBatchOp? decodePaintBatch(Uint8List payload) {
    if (payload.length < 23) {
      _logDecodeDrop('paint_batch: payload too short (${payload.length})');
      return null;
    }
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.paintBatch,
      expectedLen: null,
      expectBatchBit: true,
    )) {
      return null;
    }
    final flags = payload[3];
    final anonymous = (flags & CanvasWireFormat.flagBitAnonymousAuthor) != 0;
    final buf = _viewOf(payload);
    final canvasId = buf.getUint64(4, Endian.little);
    final authorId = buf.getUint32(12, Endian.little);
    final batchTs = buf.getUint32(16, Endian.little);
    final opCount = payload[20];
    if (opCount == 0 || opCount > CanvasWireFormat.paintBatchMaxOps) {
      _logDecodeDrop('paint_batch: op_count $opCount out of [1..21]');
      return null;
    }
    if (anonymous && authorId != 0) {
      _logDecodeDrop('paint_batch: anonymous flag set but author_id != 0');
      return null;
    }
    final batchSeq = payload[21];
    final expectedLen = 22 + 5 * opCount;
    if (payload.length != expectedLen) {
      _logDecodeDrop(
        'paint_batch: length ${payload.length} != expected $expectedLen',
      );
      return null;
    }
    final ops = <CanvasBatchedPaintRecord>[];
    var off = 22;
    for (var i = 0; i < opCount; i++) {
      final x = payload[off];
      final y = payload[off + 1];
      final color = payload[off + 2];
      final tsOffset = buf.getInt8(off + 3);
      final opSeq = payload[off + 4];
      if (x > CanvasLimits.cellCoordMax || y > CanvasLimits.cellCoordMax) {
        _logDecodeDrop('paint_batch[$i]: cell out of range ($x,$y)');
        return null;
      }
      if ((color & CanvasWireFormat.reservedColorBitsMask) != 0) {
        _logDecodeDrop('paint_batch[$i]: reserved color bits set');
        return null;
      }
      ops.add(
        CanvasBatchedPaintRecord(
          x: x,
          y: y,
          color: color,
          tsOffset: tsOffset,
          opSeq: opSeq,
        ),
      );
      off += 5;
    }
    return CanvasPaintBatchOp(
      canvasId: canvasId,
      authorId: authorId,
      batchTs: batchTs,
      batchSeq: batchSeq,
      ops: List.unmodifiable(ops),
      anonymousAuthor: anonymous,
    );
  }

  // ---------------------------------------------------------------------------
  // canvas_digest (action 0x0003) — 64 bytes at v0.1 (12 prefix + 16
  // global + 4 cellCount + tilesConcatenatedBytes). All offsets +
  // lengths derive from CanvasDigestSizes so the encoder stays valid
  // if CanvasGeometry tile count ever changes.
  // ---------------------------------------------------------------------------

  static Uint8List? encodeCanvasDigest(CanvasDigestOp op) {
    if (op.globalDigest.length != CanvasDigestSizes.globalBytes) {
      AppLogging.meshCanvas(
        'canvas_digest encode rejected: global digest '
        '${op.globalDigest.length} != ${CanvasDigestSizes.globalBytes}',
      );
      return null;
    }
    if (op.tileDigests.length != CanvasDigestSizes.tilesConcatenatedBytes) {
      AppLogging.meshCanvas(
        'canvas_digest encode rejected: tile digests '
        '${op.tileDigests.length} != ${CanvasDigestSizes.tilesConcatenatedBytes}',
      );
      return null;
    }
    final buf = ByteData(CanvasDigestSizes.totalDigestPayloadBytes);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.canvasDigest,
      canvasId: op.canvasId,
      flags: 0,
    );
    final bytes = buf.buffer.asUint8List();
    bytes.setRange(12, 28, op.globalDigest);
    buf.setUint32(28, op.cellCount, Endian.little);
    bytes.setRange(
      32,
      CanvasDigestSizes.totalDigestPayloadBytes,
      op.tileDigests,
    );
    return bytes;
  }

  static CanvasDigestOp? decodeCanvasDigest(Uint8List payload) {
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.canvasDigest,
      expectedLen: CanvasDigestSizes.totalDigestPayloadBytes,
      expectBatchBit: false,
    )) {
      return null;
    }
    final buf = _viewOf(payload);
    final canvasId = buf.getUint64(4, Endian.little);
    final globalDigest = Uint8List.fromList(payload.sublist(12, 28));
    final cellCount = buf.getUint32(28, Endian.little);
    final tileDigests = Uint8List.fromList(
      payload.sublist(32, CanvasDigestSizes.totalDigestPayloadBytes),
    );
    return CanvasDigestOp(
      canvasId: canvasId,
      globalDigest: globalDigest,
      cellCount: cellCount,
      tileDigests: tileDigests,
    );
  }

  // ---------------------------------------------------------------------------
  // sync_request (action 0x0004) — 18 bytes
  // ---------------------------------------------------------------------------

  static Uint8List? encodeSyncRequest(CanvasSyncRequestOp op) {
    final maxTile = CanvasGeometry.tilesPerRow - 1;
    if (op.tileX < 0 || op.tileX >= CanvasGeometry.tilesPerRow) {
      throw ArgumentError.value(op.tileX, 'tileX', 'must be 0..$maxTile');
    }
    if (op.tileY < 0 || op.tileY >= CanvasGeometry.tilesPerRow) {
      throw ArgumentError.value(op.tileY, 'tileY', 'must be 0..$maxTile');
    }
    final buf = ByteData(18);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.syncRequest,
      canvasId: op.canvasId,
      flags: 0,
    );
    buf.setUint8(12, op.x0);
    buf.setUint8(13, op.y0);
    buf.setUint8(14, op.x1);
    buf.setUint8(15, op.y1);
    buf.setUint16(16, 0, Endian.little);
    return buf.buffer.asUint8List();
  }

  static CanvasSyncRequestOp? decodeSyncRequest(Uint8List payload) {
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.syncRequest,
      expectedLen: 18,
      expectBatchBit: false,
    )) {
      return null;
    }
    final buf = _viewOf(payload);
    final canvasId = buf.getUint64(4, Endian.little);
    final x0 = payload[12];
    final y0 = payload[13];
    final x1 = payload[14];
    final y1 = payload[15];
    final reserved = buf.getUint16(16, Endian.little);
    if (reserved != 0) {
      _logDecodeDrop('sync_request: reserved u16 != 0 ($reserved)');
      return null;
    }
    if (x0 % CanvasGeometry.tileSize != 0 ||
        y0 % CanvasGeometry.tileSize != 0 ||
        x1 != x0 + CanvasWireFormat.syncTileSpan ||
        y1 != y0 + CanvasWireFormat.syncTileSpan) {
      _logDecodeDrop(
        'sync_request: non-tile-aligned rect ($x0,$y0)..($x1,$y1)',
      );
      return null;
    }
    if (x0 >= CanvasGeometry.width || y0 >= CanvasGeometry.height) {
      _logDecodeDrop('sync_request: tile origin off-canvas ($x0,$y0)');
      return null;
    }
    return CanvasSyncRequestOp(
      canvasId: canvasId,
      tileX: x0 ~/ CanvasGeometry.tileSize,
      tileY: y0 ~/ CanvasGeometry.tileSize,
    );
  }

  // ---------------------------------------------------------------------------
  // sync_response (action 0x0005) — dual-mode, 18-byte header + body
  // ---------------------------------------------------------------------------

  static Uint8List? encodeSyncResponse(CanvasSyncResponseOp op) {
    final maxTile = CanvasGeometry.tilesPerRow - 1;
    if (op.tileX < 0 || op.tileX >= CanvasGeometry.tilesPerRow) {
      throw ArgumentError.value(op.tileX, 'tileX', 'must be 0..$maxTile');
    }
    if (op.tileY < 0 || op.tileY >= CanvasGeometry.tilesPerRow) {
      throw ArgumentError.value(op.tileY, 'tileY', 'must be 0..$maxTile');
    }
    final body = op.body;
    final int encoding;
    final int bandIndex;
    final int totalBands;
    final Uint8List bodyBytes;
    switch (body) {
      case CanvasSyncResponseRleBody():
        if (body.runs.isEmpty) {
          AppLogging.meshCanvas('sync_response encode rejected: zero runs');
          return null;
        }
        if (body.runs.length > CanvasWireFormat.syncResponseMaxRunsPerFrame) {
          AppLogging.meshCanvas(
            'sync_response encode rejected: '
            '${body.runs.length} > ${CanvasWireFormat.syncResponseMaxRunsPerFrame} runs',
          );
          return null;
        }
        encoding = 0;
        bandIndex = 0;
        totalBands = 1;
        final raw = Uint8List(body.runs.length * 2);
        for (var i = 0; i < body.runs.length; i++) {
          final run = body.runs[i];
          if (run.length < 1 || run.length > 255) {
            AppLogging.meshCanvas(
              'sync_response encode rejected: run length ${run.length}',
            );
            return null;
          }
          _validateColor(run.color);
          raw[i * 2] = run.length;
          raw[i * 2 + 1] = run.color;
        }
        bodyBytes = raw;
      case CanvasSyncResponseRawBandBody():
        if (body.bandIndex < 0 ||
            body.bandIndex >= CanvasWireFormat.syncResponseRawBandCount) {
          throw ArgumentError.value(
            body.bandIndex,
            'bandIndex',
            'must be 0..${CanvasWireFormat.syncResponseRawBandCount - 1}',
          );
        }
        if (body.cells.length != CanvasWireFormat.syncResponseRawBandCells) {
          throw ArgumentError.value(
            body.cells.length,
            'cells.length',
            'raw band MUST be exactly '
                '${CanvasWireFormat.syncResponseRawBandCells} cells',
          );
        }
        for (var i = 0; i < body.cells.length; i++) {
          _validateColor(body.cells[i]);
        }
        encoding = 1;
        bandIndex = body.bandIndex;
        totalBands = CanvasWireFormat.syncResponseRawBandCount;
        bodyBytes = body.cells;
    }
    final total = 18 + bodyBytes.length;
    if (total > CanvasWireFormat.mrrpMaxPayload) {
      AppLogging.meshCanvas(
        'sync_response encode rejected: $total > '
        '${CanvasWireFormat.mrrpMaxPayload}',
      );
      return null;
    }
    final buf = ByteData(total);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.syncResponse,
      canvasId: op.canvasId,
      flags: 0,
    );
    buf.setUint8(12, op.tileX);
    buf.setUint8(13, op.tileY);
    buf.setUint8(14, encoding);
    buf.setUint8(15, bandIndex);
    buf.setUint8(16, totalBands);
    buf.setUint8(17, 0);
    final bytes = buf.buffer.asUint8List();
    bytes.setRange(18, total, bodyBytes);
    return bytes;
  }

  static CanvasSyncResponseOp? decodeSyncResponse(Uint8List payload) {
    if (payload.length < 18) {
      _logDecodeDrop('sync_response: header too short (${payload.length})');
      return null;
    }
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.syncResponse,
      expectedLen: null,
      expectBatchBit: false,
    )) {
      return null;
    }
    final buf = _viewOf(payload);
    final canvasId = buf.getUint64(4, Endian.little);
    final tileX = payload[12];
    final tileY = payload[13];
    final encoding = payload[14];
    final bandIndex = payload[15];
    final totalBands = payload[16];
    final reserved = payload[17];
    if (reserved != 0) {
      _logDecodeDrop('sync_response: reserved u8 != 0 ($reserved)');
      return null;
    }
    if (tileX >= CanvasGeometry.tilesPerRow ||
        tileY >= CanvasGeometry.tilesPerRow) {
      _logDecodeDrop('sync_response: tile out of range ($tileX,$tileY)');
      return null;
    }
    final bodyLen = payload.length - 18;
    if (encoding == 0) {
      if (totalBands != 1 || bandIndex != 0) {
        _logDecodeDrop(
          'sync_response: encoding=0 requires totalBands=1 band_index=0',
        );
        return null;
      }
      if (bodyLen.isOdd) {
        _logDecodeDrop('sync_response: RLE body length $bodyLen is odd');
        return null;
      }
      final runCount = bodyLen ~/ 2;
      if (runCount == 0) {
        _logDecodeDrop('sync_response: RLE body has zero runs');
        return null;
      }
      if (runCount > CanvasWireFormat.syncResponseMaxRunsPerFrame) {
        _logDecodeDrop(
          'sync_response: RLE run count $runCount > '
          '${CanvasWireFormat.syncResponseMaxRunsPerFrame}',
        );
        return null;
      }
      final runs = <CanvasSyncResponseRun>[];
      for (var i = 0; i < runCount; i++) {
        final length = payload[18 + i * 2];
        final color = payload[18 + i * 2 + 1];
        if (length == 0) {
          _logDecodeDrop('sync_response: zero-length run at $i');
          return null;
        }
        if ((color & CanvasWireFormat.reservedColorBitsMask) != 0) {
          _logDecodeDrop(
            'sync_response: reserved color bits set in RLE run $i',
          );
          return null;
        }
        runs.add(CanvasSyncResponseRun(length: length, color: color));
      }
      return CanvasSyncResponseOp(
        canvasId: canvasId,
        tileX: tileX,
        tileY: tileY,
        body: CanvasSyncResponseRleBody(runs: List.unmodifiable(runs)),
      );
    }
    if (encoding == 1) {
      if (totalBands != CanvasWireFormat.syncResponseRawBandCount) {
        _logDecodeDrop(
          'sync_response: encoding=1 requires totalBands='
          '${CanvasWireFormat.syncResponseRawBandCount}',
        );
        return null;
      }
      if (bandIndex >= CanvasWireFormat.syncResponseRawBandCount) {
        _logDecodeDrop('sync_response: band_index $bandIndex out of range');
        return null;
      }
      if (bodyLen != CanvasWireFormat.syncResponseRawBandCells) {
        _logDecodeDrop(
          'sync_response: raw band body length $bodyLen != '
          '${CanvasWireFormat.syncResponseRawBandCells}',
        );
        return null;
      }
      final cells = Uint8List.fromList(payload.sublist(18, 18 + bodyLen));
      for (var i = 0; i < cells.length; i++) {
        if ((cells[i] & CanvasWireFormat.reservedColorBitsMask) != 0) {
          _logDecodeDrop(
            'sync_response: reserved color bits set in raw band byte $i',
          );
          return null;
        }
      }
      return CanvasSyncResponseOp(
        canvasId: canvasId,
        tileX: tileX,
        tileY: tileY,
        body: CanvasSyncResponseRawBandBody(bandIndex: bandIndex, cells: cells),
      );
    }
    _logDecodeDrop('sync_response: unknown encoding=$encoding');
    return null;
  }

  // ---------------------------------------------------------------------------
  // canvas_info (action 0x0006)
  // ---------------------------------------------------------------------------

  static Uint8List? encodeCanvasInfoRequest(CanvasInfoRequest req) {
    final buf = ByteData(16);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.canvasInfo,
      canvasId: req.canvasId,
      flags: 0,
    );
    buf.setUint32(12, 0, Endian.little);
    return buf.buffer.asUint8List();
  }

  static CanvasInfoRequest? decodeCanvasInfoRequest(Uint8List payload) {
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.canvasInfo,
      expectedLen: 16,
      expectBatchBit: false,
    )) {
      return null;
    }
    final buf = _viewOf(payload);
    final canvasId = buf.getUint64(4, Endian.little);
    final reserved = buf.getUint32(12, Endian.little);
    if (reserved != 0) {
      _logDecodeDrop('canvas_info request: reserved u32 != 0');
      return null;
    }
    return CanvasInfoRequest(canvasId: canvasId);
  }

  static Uint8List? encodeCanvasInfoResponse(CanvasInfoResponse resp) {
    if (resp.nameHint.length != 8) {
      throw ArgumentError.value(
        resp.nameHint.length,
        'nameHint.length',
        'canvas_info response name_hint MUST be exactly 8 bytes',
      );
    }
    final buf = ByteData(36);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.canvasInfo,
      canvasId: resp.canvasId,
      flags: 0,
    );
    buf.setUint8(12, resp.width);
    buf.setUint8(13, resp.height);
    buf.setUint8(14, resp.paletteId);
    buf.setUint8(15, resp.status);
    buf.setUint32(16, resp.createdAt, Endian.little);
    buf.setUint32(20, resp.ownerId, Endian.little);
    buf.setUint32(24, resp.cellCount, Endian.little);
    final bytes = buf.buffer.asUint8List();
    bytes.setRange(28, 36, resp.nameHint);
    return bytes;
  }

  static CanvasInfoResponse? decodeCanvasInfoResponse(Uint8List payload) {
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.canvasInfo,
      expectedLen: 36,
      expectBatchBit: false,
    )) {
      return null;
    }
    final buf = _viewOf(payload);
    final canvasId = buf.getUint64(4, Endian.little);
    final width = payload[12];
    final height = payload[13];
    final paletteId = payload[14];
    final status = payload[15];
    final createdAt = buf.getUint32(16, Endian.little);
    final ownerId = buf.getUint32(20, Endian.little);
    final cellCount = buf.getUint32(24, Endian.little);
    final nameHint = Uint8List.fromList(payload.sublist(28, 36));
    return CanvasInfoResponse(
      canvasId: canvasId,
      width: width,
      height: height,
      paletteId: paletteId,
      status: status,
      createdAt: createdAt,
      ownerId: ownerId,
      cellCount: cellCount,
      nameHint: nameHint,
    );
  }

  // ---------------------------------------------------------------------------
  // presence (action 0x0007) — 24 bytes
  // ---------------------------------------------------------------------------

  static Uint8List? encodePresence(CanvasPresenceOp op) {
    if (op.ttlSeconds < CanvasPresenceLimits.ttlSecondsMin ||
        op.ttlSeconds > CanvasPresenceLimits.ttlSecondsMax) {
      AppLogging.meshCanvas(
        'presence encode rejected: ttl_seconds=${op.ttlSeconds} '
        'outside [${CanvasPresenceLimits.ttlSecondsMin}, '
        '${CanvasPresenceLimits.ttlSecondsMax}]',
      );
      return null;
    }
    final buf = ByteData(24);
    _writeCommonPrefix(
      buf,
      action: CanvasAction.presence,
      canvasId: op.canvasId,
      flags: 0,
    );
    buf.setUint32(12, op.authorId, Endian.little);
    buf.setUint8(16, op.state.code);
    buf.setUint32(17, op.emitTs, Endian.little);
    buf.setUint16(21, op.ttlSeconds, Endian.little);
    buf.setUint8(23, 0);
    return buf.buffer.asUint8List();
  }

  static CanvasPresenceOp? decodePresence(Uint8List payload) {
    if (!_checkCommonPrefix(
      payload,
      expectedAction: CanvasAction.presence,
      expectedLen: 24,
      expectBatchBit: false,
    )) {
      return null;
    }
    final flags = payload[3];
    // Invariant P7: presence is inherently identity-bound. Anonymous
    // presence is meaningless and a vector for grief; receivers MUST
    // drop with debug log.
    if ((flags & CanvasWireFormat.flagBitAnonymousAuthor) != 0) {
      _logDecodeDrop('presence: anonymous_author flag set');
      return null;
    }
    final buf = _viewOf(payload);
    final canvasId = buf.getUint64(4, Endian.little);
    final authorId = buf.getUint32(12, Endian.little);
    final stateByte = payload[16];
    final state = PresenceState.fromCode(stateByte);
    if (state == null) {
      _logDecodeDrop(
        'presence: unknown state byte 0x${stateByte.toRadixString(16)}',
      );
      return null;
    }
    final emitTs = buf.getUint32(17, Endian.little);
    final ttlSeconds = buf.getUint16(21, Endian.little);
    if (ttlSeconds < CanvasPresenceLimits.ttlSecondsMin ||
        ttlSeconds > CanvasPresenceLimits.ttlSecondsMax) {
      _logDecodeDrop(
        'presence: ttl_seconds=$ttlSeconds outside '
        '[${CanvasPresenceLimits.ttlSecondsMin}, '
        '${CanvasPresenceLimits.ttlSecondsMax}]',
      );
      return null;
    }
    final reserved = payload[23];
    if (reserved != 0) {
      _logDecodeDrop('presence: reserved byte != 0 ($reserved)');
      return null;
    }
    return CanvasPresenceOp(
      canvasId: canvasId,
      authorId: authorId,
      state: state,
      emitTs: emitTs,
      ttlSeconds: ttlSeconds,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static void _writeCommonPrefix(
    ByteData buf, {
    required CanvasAction action,
    required int canvasId,
    required int flags,
  }) {
    buf.setUint8(0, CanvasWireFormat.magic);
    buf.setUint8(1, CanvasWireFormat.version);
    buf.setUint8(2, action.opTypeByte);
    buf.setUint8(3, flags);
    buf.setUint64(4, canvasId, Endian.little);
  }

  /// Validate a payload's common prefix against an expected action.
  /// Returns true when the prefix is acceptable. Logs every drop.
  ///
  /// [expectedLen] enforces an exact total payload length; pass `null`
  /// for variable-length frames (paint_batch, sync_response).
  static bool _checkCommonPrefix(
    Uint8List payload, {
    required CanvasAction expectedAction,
    required int? expectedLen,
    required bool expectBatchBit,
  }) {
    if (payload.length < CanvasWireFormat.commonPrefixLen) {
      _logDecodeDrop(
        '${expectedAction.name}: payload too short (${payload.length})',
      );
      return false;
    }
    if (expectedLen != null && payload.length != expectedLen) {
      _logDecodeDrop(
        '${expectedAction.name}: payload ${payload.length} != $expectedLen',
      );
      return false;
    }
    if (payload[0] != CanvasWireFormat.magic) {
      _logDecodeDrop(
        '${expectedAction.name}: bad magic 0x${payload[0].toRadixString(16)}',
      );
      return false;
    }
    if (payload[1] != CanvasWireFormat.version) {
      _logDecodeDrop(
        '${expectedAction.name}: unsupported version ${payload[1]}',
      );
      return false;
    }
    if (payload[2] != expectedAction.opTypeByte) {
      _logDecodeDrop(
        '${expectedAction.name}: op_type 0x${payload[2].toRadixString(16)} '
        '!= expected 0x${expectedAction.opTypeByte.toRadixString(16)}',
      );
      return false;
    }
    final flags = payload[3];
    if ((flags & CanvasWireFormat.reservedFlagBitsMask) != 0) {
      _logDecodeDrop(
        '${expectedAction.name}: reserved flag bits set '
        '(0x${flags.toRadixString(16)})',
      );
      return false;
    }
    final batchBitSet = (flags & CanvasWireFormat.flagBitBatch) != 0;
    if (batchBitSet != expectBatchBit) {
      _logDecodeDrop(
        '${expectedAction.name}: batch flag bit mismatch '
        '(got=$batchBitSet, expected=$expectBatchBit)',
      );
      return false;
    }
    return true;
  }

  static ByteData _viewOf(Uint8List payload) =>
      payload.buffer.asByteData(payload.offsetInBytes, payload.length);

  static void _validateCellCoords(int x, int y) {
    if (x < 0 || x > CanvasLimits.cellCoordMax) {
      throw ArgumentError.value(
        x,
        'x',
        'must be 0..${CanvasLimits.cellCoordMax}',
      );
    }
    if (y < 0 || y > CanvasLimits.cellCoordMax) {
      throw ArgumentError.value(
        y,
        'y',
        'must be 0..${CanvasLimits.cellCoordMax}',
      );
    }
  }

  static void _validateColor(int color) {
    if (color < 0 || color > CanvasLimits.colorMax) {
      throw ArgumentError.value(
        color,
        'color',
        'palette index must be 0..${CanvasLimits.colorMax} '
            '(top 2 bits reserved)',
      );
    }
  }

  static void _validateTsOffset(int tsOffset) {
    if (tsOffset < -128 || tsOffset > 127) {
      throw ArgumentError.value(
        tsOffset,
        'tsOffset',
        'must fit in signed 8-bit range',
      );
    }
  }

  static void _validateAuthorAnonymity({
    required int authorId,
    required bool anonymous,
  }) {
    if (anonymous && authorId != 0) {
      throw ArgumentError(
        'anonymousAuthor=true requires authorId=0', // lint-allow: hardcoded-string
      );
    }
  }

  static void _logDecodeDrop(String reason) {
    AppLogging.meshCanvas('canvas_codec decode drop: $reason');
  }
}
