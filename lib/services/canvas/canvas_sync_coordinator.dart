// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas sync coordinator (S9b/c/d/e).
//
// Source of truth: docs/canvas/CANVAS_SYNC_V0_1.md.
//
// Owns the per-peer-per-tile state machine for tile-sync hydration.
// All wire I/O routes through the existing CanvasOutboundChannel +
// CanvasOutboundGovernor + SIP rate limiter — sync NEVER bypasses
// airtime fairness.
//
// Surface:
//   - emitDigest(canvasLocalId, channelIndex, canvasId)
//       Called on viewer mount (subject to participation gate). Reads
//       cells, computes BLAKE2s-128 digests, ships a 160 B
//       canvas_digest frame on the matching channel. Logs every
//       outcome at AppLogging.meshCanvas as `digest_emit`.
//   - handleInboundDigest(...)
//       Compare peer digests against local. For each tile mismatch
//       where the peer's cell_count is >= local count, schedule a
//       sync_request. Per-peer 4-request-per-minute cap.
//   - handleInboundSyncRequest(...)
//       Read cells in the requested tile, encode RLE or 8-band raw,
//       ship the response frame(s).
//   - handleInboundSyncResponse(...)
//       Reconstruct cells from the body, apply each through the
//       LWW path (applyInboundPaint). Invalidate digest cache.
//   - hydrationStateFor(canvasLocalId)
//       Returns one of MeshCanvasHydrationState for the HUD pill.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../core/logging.dart';
import 'canvas_codec.dart';
import 'canvas_constants.dart';
import 'canvas_models.dart';
import 'canvas_outbound_governor.dart';
import 'canvas_repository.dart';
import 'canvas_send_coordinator.dart'
    show CanvasOutboundChannel, CanvasSendOutcome;

/// Per-canvas hydration HUD state. Surfaced to the UI via a stream
/// provider; the HUD pill widget interprets the value.
enum MeshCanvasHydrationState {
  /// No outstanding sync work and no recent peer signal.
  idle,

  /// At least one sync_request is in flight to a peer for this canvas.
  recovering,

  /// At least one sync_response band has arrived recently and is
  /// being applied — visually distinct so the user sees the canvas
  /// "filling in" cause-and-effect.
  syncing,

  /// Local canvas is empty AND we've heard a peer who is also empty.
  /// Tells the user "you're early, and the mesh also has nothing".
  quiet,
}

/// In-memory state for one (canvas, peer, tile) coordinate.
class _PendingTileRequest {
  final int peerNodeNum;
  final int tileIndex;
  final int requestedAtMs;

  const _PendingTileRequest({
    required this.peerNodeNum,
    required this.tileIndex,
    required this.requestedAtMs,
  });
}

/// In-memory record of when we last asked a given peer for a tile.
/// Drives the 4-per-minute cap.
class _PeerRequestWindow {
  final int peerNodeNum;
  final List<int> requestTimestampsMs = [];

  _PeerRequestWindow(this.peerNodeNum);
}

class CanvasSyncCoordinator {
  final CanvasRepository _repository;
  final CanvasOutboundChannel _outbound;
  final CanvasOutboundGovernor _governor;
  final bool Function() _canEmit;
  final int Function() _nowMs;
  final void Function(int canvasLocalId)? _onCellApplied;

  /// `Map<canvasLocalId, pending requests by tile index>`. State of
  /// outstanding sync_requests waiting on a response.
  final Map<int, Map<int, _PendingTileRequest>> _pendingByCanvas = {};

  /// Per-canvas, per-peer sliding window of request timestamps to
  /// enforce the 4-per-minute cap.
  final Map<int, Map<int, _PeerRequestWindow>> _peerWindowByCanvas = {};

  /// Per-canvas "last syncing activity" timestamp (set when a
  /// sync_response band lands). The HUD uses this to differentiate
  /// `recovering` (request out, nothing back yet) vs `syncing` (bands
  /// actively applying).
  final Map<int, int> _lastBandAtMs = {};

  /// Per-canvas: whether a peer was recently observed reporting an
  /// empty digest. Drives the `quiet` hydration state when local is
  /// also empty.
  final Map<int, bool> _peerEmptyObserved = {};

  /// Stream controller broadcasting hydration-state changes per canvas.
  /// UI watches via `hydrationStateFor`.
  final StreamController<int> _hydrationChanges =
      StreamController<int>.broadcast();

  /// Maximum requests to one peer per canvas in the trailing 60 s.
  static const int maxRequestsPerPeerPerMinute = 4;

  /// How long a sync_response band counts as "syncing" before the
  /// HUD drops back toward idle.
  static const Duration syncingActivityWindow = Duration(seconds: 10);

  /// Sync_request timeout — if no response after this, clear the
  /// pending state so we may re-request later (e.g. after the peer
  /// re-emits a digest).
  static const Duration requestTimeout = Duration(seconds: 60);

  CanvasSyncCoordinator({
    required CanvasRepository repository,
    required CanvasOutboundChannel outbound,
    required CanvasOutboundGovernor governor,
    required bool Function() canEmit,
    int Function()? nowMs,
    void Function(int canvasLocalId)? onCellApplied,
  }) : _repository = repository,
       _outbound = outbound,
       _governor = governor,
       _canEmit = canEmit,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _onCellApplied = onCellApplied;

  /// Stream of canvasLocalIds whose hydration state may have changed.
  /// UI subscribes via `hydrationStateFor` for the snapshot.
  Stream<int> get changes => _hydrationChanges.stream;

  // ---------------------------------------------------------------------------
  // Outbound: digest emit on viewer mount
  // ---------------------------------------------------------------------------

  /// Compute + ship a canvas_digest frame. Logs `digest_emit` with
  /// the cell count + digest hex prefix so two-device sim traces are
  /// readable.
  Future<void> emitDigest({
    required int canvasLocalId,
    required int channelIndex,
    required int canvasId,
  }) async {
    if (!_canEmit()) {
      AppLogging.meshCanvas(
        'sync digest_emit skipped: participation gate closed '
        'canvas=$canvasLocalId',
      );
      return;
    }
    if (canvasId == kLocalCanvasIdSentinel) {
      AppLogging.meshCanvas(
        'sync digest_emit skipped: local canvas sentinel '
        'canvas=$canvasLocalId',
      );
      return;
    }
    final set = await _repository.computeAndCacheDigests(canvasLocalId);
    final payload = CanvasCodec.encodeCanvasDigest(
      CanvasDigestOp(
        canvasId: canvasId,
        globalDigest: set.globalDigest,
        cellCount: set.cellCount,
        tileDigests: set.tileDigests,
      ),
    );
    if (payload == null) {
      AppLogging.meshCanvas(
        'sync digest_emit drop_reason=encode_failed canvas=$canvasLocalId',
      );
      return;
    }
    if (!_governor.canSend(payload.length)) {
      AppLogging.meshCanvas(
        'sync digest_emit drop_reason=governor_closed '
        'canvas=$canvasLocalId payload=${payload.length}B '
        'headroom=${_governor.remainingBytes}B',
      );
      return;
    }
    final result = await _outbound.sendCanvasPayload(
      canvasPayload: payload,
      channelIndex: channelIndex,
    );
    if (result.outcome == CanvasSendOutcome.sent) {
      _governor.recordSend(payload.length);
      AppLogging.meshCanvas(
        'sync digest_emit canvas=$canvasLocalId channel=$channelIndex '
        'canvasId=0x${canvasId.toRadixString(16)} '
        'cells=${set.cellCount} '
        'global=${_hexPrefix(set.globalDigest, 4)} payload=${payload.length}B',
      );
    } else {
      AppLogging.meshCanvas(
        'sync digest_emit drop_reason=${result.outcome.name} '
        'canvas=$canvasLocalId',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound: digest received → maybe schedule sync_requests
  // ---------------------------------------------------------------------------

  Future<void> handleInboundDigest({
    required int senderNodeId,
    required int channelIndex,
    required CanvasDigestOp op,
  }) async {
    AppLogging.meshCanvas(
      'sync digest_received sender=0x${senderNodeId.toRadixString(16)} '
      'channel=$channelIndex canvasId=0x${op.canvasId.toRadixString(16)} '
      'peerCells=${op.cellCount} '
      'peerGlobal=${_hexPrefix(op.globalDigest, 4)}',
    );

    final canvas = await _findCanvas(op.canvasId, channelIndex);
    if (canvas == null) {
      AppLogging.meshCanvas(
        'sync digest_compare_result drop_reason=canvas_unknown '
        'canvasId=0x${op.canvasId.toRadixString(16)} channel=$channelIndex',
      );
      return;
    }

    final local = await _repository.computeAndCacheDigests(canvas.localId);

    // Track whether a peer reports empty so the HUD can show `quiet`
    // when local is also empty.
    if (op.cellCount == 0 && local.cellCount == 0) {
      _peerEmptyObserved[canvas.localId] = true;
      _hydrationChanges.add(canvas.localId);
    }

    final globalMatch = _bytesEqual(local.globalDigest, op.globalDigest);
    AppLogging.meshCanvas(
      'sync digest_compare_result canvas=${canvas.localId} '
      'localCells=${local.cellCount} peerCells=${op.cellCount} '
      'globalMatch=$globalMatch',
    );
    if (globalMatch) return;

    // Only request from peers with at least as many cells as we have.
    // If we're richer, the peer will request from us when their
    // viewer mounts.
    if (op.cellCount < local.cellCount) {
      AppLogging.meshCanvas(
        'sync digest_compare_result skip_reason=peer_poorer '
        'canvas=${canvas.localId}',
      );
      return;
    }

    // Identify mismatched tile indices.
    final mismatchedTiles = <int>[];
    for (var t = 0; t < CanvasGeometry.tileCount; t++) {
      final offset = t * CanvasDigestSizes.tileBytes;
      final ourSlot = local.tileDigests.sublist(
        offset,
        offset + CanvasDigestSizes.tileBytes,
      );
      final peerSlot = op.tileDigests.sublist(
        offset,
        offset + CanvasDigestSizes.tileBytes,
      );
      if (!_bytesEqual(ourSlot, peerSlot)) {
        mismatchedTiles.add(t);
      }
    }
    if (mismatchedTiles.isEmpty) return;

    AppLogging.meshCanvas(
      'sync digest_compare_result canvas=${canvas.localId} '
      'mismatched_tiles=${mismatchedTiles.length}',
    );

    // Apply per-peer rate cap.
    final window = _peerWindow(canvas.localId, senderNodeId);
    final now = _nowMs();
    final cutoff = now - 60_000;
    window.requestTimestampsMs.removeWhere((t) => t < cutoff);

    var emitted = 0;
    for (final tile in mismatchedTiles) {
      if (window.requestTimestampsMs.length >= maxRequestsPerPeerPerMinute) {
        AppLogging.meshCanvas(
          'sync sync_request drop_reason=per_peer_cap '
          'canvas=${canvas.localId} peer=0x${senderNodeId.toRadixString(16)}',
        );
        break;
      }
      final pending = _pendingTiles(canvas.localId);
      if (pending.containsKey(tile)) {
        // Already waiting on this tile from someone — skip duplicate.
        continue;
      }
      final tileX = tile % CanvasGeometry.tilesPerRow;
      final tileY = tile ~/ CanvasGeometry.tilesPerRow;
      final reqPayload = CanvasCodec.encodeSyncRequest(
        CanvasSyncRequestOp(canvasId: op.canvasId, tileX: tileX, tileY: tileY),
      );
      if (reqPayload == null) continue;
      if (!_governor.canSend(reqPayload.length)) {
        AppLogging.meshCanvas(
          'sync sync_request drop_reason=governor_closed '
          'canvas=${canvas.localId} tile=$tileX,$tileY',
        );
        break;
      }
      final res = await _outbound.sendCanvasPayload(
        canvasPayload: reqPayload,
        channelIndex: channelIndex,
      );
      if (res.outcome == CanvasSendOutcome.sent) {
        _governor.recordSend(reqPayload.length);
        window.requestTimestampsMs.add(now);
        pending[tile] = _PendingTileRequest(
          peerNodeNum: senderNodeId,
          tileIndex: tile,
          requestedAtMs: now,
        );
        emitted++;
        AppLogging.meshCanvas(
          'sync sync_request_emit canvas=${canvas.localId} '
          'tile=$tileX,$tileY peer=0x${senderNodeId.toRadixString(16)}',
        );
      } else {
        AppLogging.meshCanvas(
          'sync sync_request drop_reason=${res.outcome.name} '
          'canvas=${canvas.localId} tile=$tileX,$tileY',
        );
        break;
      }
    }
    if (emitted > 0) {
      _hydrationChanges.add(canvas.localId);
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound: sync_request received → emit sync_response
  // ---------------------------------------------------------------------------

  Future<void> handleInboundSyncRequest({
    required int senderNodeId,
    required int channelIndex,
    required CanvasSyncRequestOp op,
  }) async {
    AppLogging.meshCanvas(
      'sync sync_request_received sender=0x${senderNodeId.toRadixString(16)} '
      'channel=$channelIndex canvasId=0x${op.canvasId.toRadixString(16)} '
      'tile=${op.tileX},${op.tileY}',
    );

    if (!_canEmit()) {
      AppLogging.meshCanvas(
        'sync sync_response drop_reason=participation_closed '
        'canvasId=0x${op.canvasId.toRadixString(16)}',
      );
      return;
    }

    final canvas = await _findCanvas(op.canvasId, channelIndex);
    if (canvas == null) {
      AppLogging.meshCanvas(
        'sync sync_response drop_reason=canvas_unknown '
        'canvasId=0x${op.canvasId.toRadixString(16)}',
      );
      return;
    }

    // Read cells inside the requested tile.
    final allCells = await _repository.getCanvasCells(canvas.localId);
    final tileOriginX = op.tileX * CanvasGeometry.tileSize;
    final tileOriginY = op.tileY * CanvasGeometry.tileSize;
    final tileCells = <CanvasCell>[];
    for (final cell in allCells) {
      if (cell.x >= tileOriginX &&
          cell.x < tileOriginX + CanvasGeometry.tileSize &&
          cell.y >= tileOriginY &&
          cell.y < tileOriginY + CanvasGeometry.tileSize) {
        tileCells.add(cell);
      }
    }

    // Build the raster-ordered color array (32×32 = 1024 cells; index
    // = (y-tileOriginY) * 32 + (x-tileOriginX)). Default to color 0.
    final raster = Uint8List(CanvasGeometry.tileSize * CanvasGeometry.tileSize);
    for (final cell in tileCells) {
      final lx = cell.x - tileOriginX;
      final ly = cell.y - tileOriginY;
      raster[ly * CanvasGeometry.tileSize + lx] = cell.color & 0xff;
    }

    // Attempt RLE encoding. If runs > 88 → fall back to 8 raw bands.
    final runs = _rleRuns(raster);
    if (runs.length <= CanvasWireFormat.syncResponseMaxRunsPerFrame) {
      await _sendSyncResponse(
        canvasId: op.canvasId,
        channelIndex: channelIndex,
        op: CanvasSyncResponseOp(
          canvasId: op.canvasId,
          tileX: op.tileX,
          tileY: op.tileY,
          body: CanvasSyncResponseRleBody(runs: runs),
        ),
      );
    } else {
      // 8 bands of 32 wide × 4 tall = 128 cells each.
      for (
        var band = 0;
        band < CanvasWireFormat.syncResponseRawBandCount;
        band++
      ) {
        final offset = band * CanvasWireFormat.syncResponseRawBandCells;
        final slice = Uint8List.fromList(
          raster.sublist(
            offset,
            offset + CanvasWireFormat.syncResponseRawBandCells,
          ),
        );
        await _sendSyncResponse(
          canvasId: op.canvasId,
          channelIndex: channelIndex,
          op: CanvasSyncResponseOp(
            canvasId: op.canvasId,
            tileX: op.tileX,
            tileY: op.tileY,
            body: CanvasSyncResponseRawBandBody(bandIndex: band, cells: slice),
          ),
        );
      }
    }
  }

  Future<void> _sendSyncResponse({
    required int canvasId,
    required int channelIndex,
    required CanvasSyncResponseOp op,
  }) async {
    final payload = CanvasCodec.encodeSyncResponse(op);
    if (payload == null) {
      AppLogging.meshCanvas(
        'sync sync_response drop_reason=encode_failed '
        'tile=${op.tileX},${op.tileY}',
      );
      return;
    }
    if (!_governor.canSend(payload.length)) {
      AppLogging.meshCanvas(
        'sync sync_response drop_reason=governor_closed '
        'tile=${op.tileX},${op.tileY} payload=${payload.length}B '
        'headroom=${_governor.remainingBytes}B',
      );
      return;
    }
    final res = await _outbound.sendCanvasPayload(
      canvasPayload: payload,
      channelIndex: channelIndex,
    );
    if (res.outcome == CanvasSendOutcome.sent) {
      _governor.recordSend(payload.length);
      AppLogging.meshCanvas(
        'sync sync_response_emit canvasId=0x${canvasId.toRadixString(16)} '
        'channel=$channelIndex tile=${op.tileX},${op.tileY} '
        'encoding=${op.body is CanvasSyncResponseRleBody ? "rle" : "raw"} '
        'payload=${payload.length}B',
      );
    } else {
      AppLogging.meshCanvas(
        'sync sync_response drop_reason=${res.outcome.name} '
        'tile=${op.tileX},${op.tileY}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound: sync_response received → apply cells via LWW
  // ---------------------------------------------------------------------------

  Future<void> handleInboundSyncResponse({
    required int senderNodeId,
    required int channelIndex,
    required CanvasSyncResponseOp op,
  }) async {
    AppLogging.meshCanvas(
      'sync sync_response_received sender=0x'
      '${senderNodeId.toRadixString(16)} '
      'channel=$channelIndex canvasId=0x${op.canvasId.toRadixString(16)} '
      'tile=${op.tileX},${op.tileY}',
    );

    final canvas = await _findCanvas(op.canvasId, channelIndex);
    if (canvas == null) {
      AppLogging.meshCanvas(
        'sync sync_response drop_reason=canvas_unknown '
        'canvasId=0x${op.canvasId.toRadixString(16)}',
      );
      return;
    }

    // Reconstruct the band of cells described by this frame.
    final reconstructed = _reconstructCells(op);
    final tileOriginX = op.tileX * CanvasGeometry.tileSize;
    final tileOriginY = op.tileY * CanvasGeometry.tileSize;
    final now = _nowMs();
    final opTsSeconds = now ~/ 1000;

    var applied = 0;
    for (var i = 0; i < reconstructed.length; i++) {
      final entry = reconstructed[i];
      if (entry.color == 0) {
        // color 0 is the unpainted sentinel — sync_response uses it
        // to mean "no cell at this position in the peer's state".
        continue;
      }
      final x = tileOriginX + entry.dx;
      final y = tileOriginY + entry.dy;
      // Use sender as author + a deterministic op_ts so LWW resolves
      // correctly against any existing local cell. We don't carry
      // per-cell timestamps over the wire in v0.1, so the freshly-
      // applied cell wins only when local is empty (default cell).
      final accepted = await _repository.applyInboundPaint(
        canvasLocalId: canvas.localId,
        op: InboundPaintOp(
          x: x,
          y: y,
          color: entry.color,
          authorNodeNum: senderNodeId,
          opTs: opTsSeconds,
          opSeq: i & 0xff,
        ),
      );
      if (accepted) applied++;
    }
    _lastBandAtMs[canvas.localId] = now;
    _hydrationChanges.add(canvas.localId);
    if (applied > 0 && _onCellApplied != null) {
      _onCellApplied(canvas.localId);
    }

    AppLogging.meshCanvas(
      'sync sync_apply_cells canvas=${canvas.localId} '
      'tile=${op.tileX},${op.tileY} '
      'reconstructed=${reconstructed.length} applied=$applied',
    );

    // Mark this tile as resolved in the pending map.
    final pending = _pendingTiles(canvas.localId);
    final tileIdx = op.tileY * CanvasGeometry.tilesPerRow + op.tileX;
    pending.remove(tileIdx);
  }

  // ---------------------------------------------------------------------------
  // Hydration state for UI
  // ---------------------------------------------------------------------------

  MeshCanvasHydrationState hydrationStateFor(int canvasLocalId) {
    final pending = _pendingByCanvas[canvasLocalId];
    final hasPending = pending != null && pending.isNotEmpty;
    final lastBand = _lastBandAtMs[canvasLocalId];
    final now = _nowMs();
    final actively =
        lastBand != null &&
        (now - lastBand) <= syncingActivityWindow.inMilliseconds;
    if (actively) return MeshCanvasHydrationState.syncing;
    if (hasPending) return MeshCanvasHydrationState.recovering;
    if (_peerEmptyObserved[canvasLocalId] == true) {
      return MeshCanvasHydrationState.quiet;
    }
    return MeshCanvasHydrationState.idle;
  }

  void dispose() {
    _hydrationChanges.close();
    _pendingByCanvas.clear();
    _peerWindowByCanvas.clear();
    _lastBandAtMs.clear();
    _peerEmptyObserved.clear();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<CanvasSummary?> _findCanvas(int canvasId, int channelIndex) async {
    final existing = await _repository.listCanvases(scope: CanvasScope.mesh);
    for (final row in existing) {
      if (row.canvasId == canvasId && row.channelIndex == channelIndex) {
        return row;
      }
    }
    return null;
  }

  Map<int, _PendingTileRequest> _pendingTiles(int canvasLocalId) {
    return _pendingByCanvas.putIfAbsent(canvasLocalId, () => {});
  }

  _PeerRequestWindow _peerWindow(int canvasLocalId, int peerNodeNum) {
    final byPeer = _peerWindowByCanvas.putIfAbsent(canvasLocalId, () => {});
    return byPeer.putIfAbsent(
      peerNodeNum,
      () => _PeerRequestWindow(peerNodeNum),
    );
  }

  /// RLE-encode a raster buffer of 1024 cells. Runs of identical
  /// colors compress; max length per run is 255 (the wire format's
  /// 1-byte length field). Longer runs split into multiple records.
  List<CanvasSyncResponseRun> _rleRuns(Uint8List raster) {
    final runs = <CanvasSyncResponseRun>[];
    if (raster.isEmpty) return runs;
    var currentColor = raster[0];
    var currentLength = 1;
    for (var i = 1; i < raster.length; i++) {
      if (raster[i] == currentColor && currentLength < 255) {
        currentLength++;
      } else {
        runs.add(
          CanvasSyncResponseRun(length: currentLength, color: currentColor),
        );
        currentColor = raster[i];
        currentLength = 1;
      }
    }
    runs.add(CanvasSyncResponseRun(length: currentLength, color: currentColor));
    return runs;
  }

  /// Reconstruct (dx, dy, color) entries from a sync_response body.
  /// For RLE the position walks raster order across the 32×32 tile;
  /// for raw bands the position walks raster order inside that band
  /// (32×4 strip).
  List<({int dx, int dy, int color})> _reconstructCells(
    CanvasSyncResponseOp op,
  ) {
    final result = <({int dx, int dy, int color})>[];
    final body = op.body;
    if (body is CanvasSyncResponseRleBody) {
      var idx = 0;
      for (final run in body.runs) {
        for (var i = 0; i < run.length; i++) {
          final dx = idx % CanvasGeometry.tileSize;
          final dy = idx ~/ CanvasGeometry.tileSize;
          result.add((dx: dx, dy: dy, color: run.color));
          idx++;
          if (idx >= CanvasGeometry.tileSize * CanvasGeometry.tileSize) {
            break;
          }
        }
        if (idx >= CanvasGeometry.tileSize * CanvasGeometry.tileSize) break;
      }
    } else if (body is CanvasSyncResponseRawBandBody) {
      final bandTopY = body.bandIndex * 4;
      for (var i = 0; i < body.cells.length; i++) {
        final dx = i % CanvasGeometry.tileSize;
        final dy = bandTopY + (i ~/ CanvasGeometry.tileSize);
        result.add((dx: dx, dy: dy, color: body.cells[i]));
      }
    }
    return result;
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _hexPrefix(Uint8List bytes, int n) {
    final clamped = n.clamp(0, bytes.length);
    final buf = StringBuffer();
    for (var i = 0; i < clamped; i++) {
      buf.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }
}
