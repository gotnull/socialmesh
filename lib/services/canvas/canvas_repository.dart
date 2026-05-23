// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas repository — typed CRUD on top of CanvasDatabase.
//
// Owns:
//   - LWW conflict resolution (CANVAS_V0_1.md §8)
//   - op-layer dedupe via (canvas_id, author, op_ts, op_seq, x, y)
//   - pending queue cap (256 per canvas, oldest dropped)
//   - selective digest invalidation on accepted cell apply
//   - prune helpers for applied_op + peer_digest
//   - input validation (cell bounds, palette, channel, name, digest sizes)
//
// Does NOT own:
//   - codec / wire format (slice S3)
//   - send/receive coordinators (slices S4, S5, S9)
//   - feature flag resolution or providers (slice S6)
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';
import 'canvas_constants.dart';
import 'canvas_database.dart';
import 'canvas_digest_compute.dart';
import 'canvas_merge.dart';
import 'canvas_models.dart';
import 'canvas_transmission_status_models.dart';

/// Bundles a single inbound paint op for [CanvasRepository.applyInboundPaint].
@immutable
class InboundPaintOp {
  final int x;
  final int y;
  final int color;
  final int authorNodeNum;
  final int opTs;
  final int opSeq;

  const InboundPaintOp({
    required this.x,
    required this.y,
    required this.color,
    required this.authorNodeNum,
    required this.opTs,
    required this.opSeq,
  });
}

/// Typed CRUD facade over [CanvasDatabase]. One instance per process;
/// safe to share between providers.
class CanvasRepository {
  final CanvasDatabase _db;

  CanvasRepository(this._db);

  Database get _database => _db.database;

  // ---------------------------------------------------------------------------
  // Canvas row CRUD
  // ---------------------------------------------------------------------------

  /// Get the singleton Local Device Canvas, creating it if absent.
  ///
  /// Local canvases use [kLocalCanvasIdSentinel] for `canvas_id` and
  /// `scope = 'local'`. The unique key `(canvas_id, scope, channel_index)`
  /// guarantees only one local row exists.
  Future<CanvasSummary> getOrCreateLocalCanvas({
    String name = 'Local Sandbox', // lint-allow: hardcoded-string
    int? nowMsOverride,
  }) async {
    _validateCanvasName(name);
    final existing = await _findCanvas(
      canvasId: kLocalCanvasIdSentinel,
      scope: CanvasScope.local,
      channelIndex: null,
    );
    if (existing != null) return existing;
    final nowMs = nowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
    final localId = await _database.insert(CanvasTables.canvas, {
      'canvas_id': kLocalCanvasIdSentinel,
      'scope': CanvasScope.local.storageName,
      'channel_index': null,
      'name': name,
      'width': kCanvasDefaultWidth,
      'height': kCanvasDefaultHeight,
      'palette_id': kCanvasDefaultPaletteId,
      'status': CanvasStatus.open.storageCode,
      'owner_node_num': null,
      'created_at_ms': nowMs,
      'last_op_at_ms': nowMs,
      'global_digest': null,
      'tile_digests': null,
      'cell_count': 0,
    });
    AppLogging.meshCanvas('created local canvas localId=$localId');
    return (await getCanvasByLocalId(localId))!;
  }

  /// Get a mesh canvas keyed by `(canvasId, channelIndex)`, creating it
  /// if absent. Wire side derives `canvas_id = SHA-256(psk||name)[0:8]`
  /// so passing the same triple is idempotent.
  Future<CanvasSummary> getOrCreateMeshCanvas({
    required int canvasId,
    required int channelIndex,
    required String name,
    int? ownerNodeNum,
    int? nowMsOverride,
  }) async {
    _validateCanvasName(name);
    _validateChannelIndex(channelIndex);
    final existing = await _findCanvas(
      canvasId: canvasId,
      scope: CanvasScope.mesh,
      channelIndex: channelIndex,
    );
    if (existing != null) return existing;
    final nowMs = nowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
    final localId = await _database.insert(CanvasTables.canvas, {
      'canvas_id': canvasId,
      'scope': CanvasScope.mesh.storageName,
      'channel_index': channelIndex,
      'name': name,
      'width': kCanvasDefaultWidth,
      'height': kCanvasDefaultHeight,
      'palette_id': kCanvasDefaultPaletteId,
      'status': CanvasStatus.open.storageCode,
      'owner_node_num': ownerNodeNum,
      'created_at_ms': nowMs,
      'last_op_at_ms': nowMs,
      'global_digest': null,
      'tile_digests': null,
      'cell_count': 0,
    });
    AppLogging.meshCanvas(
      'created mesh canvas localId=$localId canvasId=0x'
      '${canvasId.toRadixString(16)} channel=$channelIndex',
    );
    return (await getCanvasByLocalId(localId))!;
  }

  /// List canvases, optionally filtered by scope, ordered by recency.
  Future<List<CanvasSummary>> listCanvases({CanvasScope? scope}) async {
    final rows = await _database.query(
      CanvasTables.canvas,
      where: scope == null ? null : 'scope = ?',
      whereArgs: scope == null ? null : [scope.storageName],
      orderBy: 'last_op_at_ms DESC',
    );
    return rows.map(_canvasFromRow).toList(growable: false);
  }

  /// Look up a canvas by its local SQLite primary key.
  Future<CanvasSummary?> getCanvasByLocalId(int localId) async {
    final rows = await _database.query(
      CanvasTables.canvas,
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _canvasFromRow(rows.first);
  }

  Future<CanvasSummary?> _findCanvas({
    required int canvasId,
    required CanvasScope scope,
    required int? channelIndex,
  }) async {
    final rows = await _database.query(
      CanvasTables.canvas,
      where: channelIndex == null
          ? 'canvas_id = ? AND scope = ? AND channel_index IS NULL'
          : 'canvas_id = ? AND scope = ? AND channel_index = ?',
      whereArgs: channelIndex == null
          ? [canvasId, scope.storageName]
          : [canvasId, scope.storageName, channelIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _canvasFromRow(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Cell + applied_op + LWW
  // ---------------------------------------------------------------------------

  /// Apply a paint op that originated on this device against the Local
  /// Device Canvas (no enqueue, never broadcast).
  ///
  /// LWW is still consulted for safety: if the cell already carries a
  /// newer op (e.g. from a previous session with a clock skew), the
  /// local paint is rejected. Returns true if the paint won the LWW
  /// comparator and the cell was mutated.
  Future<bool> paintLocal({
    required int canvasLocalId,
    required int x,
    required int y,
    required int color,
    required int authorNodeNum,
    required int opTs,
    required int opSeq,
    int? receivedAtMsOverride,
  }) async {
    _validateCell(x: x, y: y, color: color);
    final receivedAtMs =
        receivedAtMsOverride ?? DateTime.now().millisecondsSinceEpoch;

    return _database.transaction((txn) async {
      final accepted = await _applyOpInTransaction(
        txn: txn,
        canvasLocalId: canvasLocalId,
        x: x,
        y: y,
        color: color,
        authorNodeNum: authorNodeNum,
        opTs: opTs,
        opSeq: opSeq,
        direction: AppliedOpDirection.outbound,
        receivedAtMs: receivedAtMs,
      );
      // Local Device Canvas never enqueues to pending_op by design.
      return accepted;
    });
  }

  /// Apply a paint op that originated on this device against a Mesh
  /// Canvas. Updates `cell` + `applied_op` (direction = outbound), and
  /// inserts a `pending_op` row for the send coordinator to drain.
  ///
  /// Returns true if the paint won the LWW comparator (cell mutated +
  /// op queued). When LWW rejects (a peer's paint already supersedes
  /// it), nothing is enqueued.
  Future<bool> enqueuePaint({
    required int canvasLocalId,
    required int x,
    required int y,
    required int color,
    required int authorNodeNum,
    required int opTs,
    required int opSeq,
    int? receivedAtMsOverride,
    int? createdAtMsOverride,
  }) async {
    _validateCell(x: x, y: y, color: color);
    final nowMs = createdAtMsOverride ?? DateTime.now().millisecondsSinceEpoch;
    final receivedAtMs = receivedAtMsOverride ?? nowMs;

    return _database.transaction((txn) async {
      final accepted = await _applyOpInTransaction(
        txn: txn,
        canvasLocalId: canvasLocalId,
        x: x,
        y: y,
        color: color,
        authorNodeNum: authorNodeNum,
        opTs: opTs,
        opSeq: opSeq,
        direction: AppliedOpDirection.outbound,
        receivedAtMs: receivedAtMs,
      );
      if (!accepted) return false;

      // Enforce queue cap BEFORE insert to keep depth ≤ cap. Oldest
      // queued rows for this canvas are dropped — their cell-state
      // effect has already been recorded by _applyOpInTransaction, so
      // peers catch up via digest sync per CANVAS_V0_1.md §9.
      await _enforcePendingQueueCap(txn, canvasLocalId);

      await txn.insert(CanvasTables.pendingOp, {
        'canvas_id': canvasLocalId,
        'x': x,
        'y': y,
        'color': color,
        'op_ts': opTs,
        'op_seq': opSeq,
        'created_at_ms': nowMs,
        'attempts': 0,
        'next_attempt_at_ms': nowMs,
        'state': PendingOpState.queued.storageCode,
        'last_error': null,
      });
      return true;
    });
  }

  /// Apply an inbound paint op received from a peer.
  ///
  /// The op-layer dedupe key `(canvas_id, author, op_ts, op_seq, x, y)`
  /// is consulted first; a duplicate is silently skipped (no mutation,
  /// no `applied_op` row inserted). When LWW rejects the op as stale,
  /// an `applied_op` row is still inserted with `was_accepted = 0` for
  /// forensic visibility.
  ///
  /// Returns true if the op was accepted (cell mutated).
  Future<bool> applyInboundPaint({
    required int canvasLocalId,
    required InboundPaintOp op,
    int? receivedAtMsOverride,
  }) async {
    _validateCell(x: op.x, y: op.y, color: op.color);
    final receivedAtMs =
        receivedAtMsOverride ?? DateTime.now().millisecondsSinceEpoch;

    return _database.transaction((txn) async {
      // Op-layer dedupe probe.
      final dupe = await txn.query(
        CanvasTables.appliedOp,
        columns: const ['id'],
        where:
            'canvas_id = ? AND author_node_num = ? AND op_ts = ? AND op_seq = ? AND x = ? AND y = ?',
        whereArgs: [
          canvasLocalId,
          op.authorNodeNum,
          op.opTs,
          op.opSeq,
          op.x,
          op.y,
        ],
        limit: 1,
      );
      if (dupe.isNotEmpty) {
        AppLogging.meshCanvas(
          'inbound dup drop canvas=$canvasLocalId author=0x'
          '${op.authorNodeNum.toRadixString(16)} '
          'ts=${op.opTs} seq=${op.opSeq} cell=(${op.x},${op.y})',
        );
        return false;
      }

      final accepted = await _applyOpInTransaction(
        txn: txn,
        canvasLocalId: canvasLocalId,
        x: op.x,
        y: op.y,
        color: op.color,
        authorNodeNum: op.authorNodeNum,
        opTs: op.opTs,
        opSeq: op.opSeq,
        direction: AppliedOpDirection.inbound,
        receivedAtMs: receivedAtMs,
      );
      if (!accepted) {
        AppLogging.meshCanvas(
          'inbound stale reject canvas=$canvasLocalId author=0x'
          '${op.authorNodeNum.toRadixString(16)} '
          'ts=${op.opTs} seq=${op.opSeq} cell=(${op.x},${op.y})',
        );
      }
      return accepted;
    });
  }

  /// Read all painted cells for a canvas. Default-color cells are NOT
  /// returned (sparse representation).
  Future<List<CanvasCell>> getCanvasCells(int canvasLocalId) async {
    final rows = await _database.query(
      CanvasTables.cell,
      where: 'canvas_id = ?',
      whereArgs: [canvasLocalId],
      orderBy: 'x ASC, y ASC',
    );
    return rows.map(_cellFromRow).toList(growable: false);
  }

  /// Read the latest applied ops for a canvas, newest first.
  Future<List<AppliedCanvasOp>> getRecentAppliedOps(
    int canvasLocalId, {
    int limit = 50,
  }) async {
    final rows = await _database.query(
      CanvasTables.appliedOp,
      where: 'canvas_id = ?',
      whereArgs: [canvasLocalId],
      orderBy: 'received_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(_appliedFromRow).toList(growable: false);
  }

  /// Read the current cell at (`x`, `y`) for a canvas, or null when
  /// the cell has never been painted (the sparse table omits default-
  /// colour cells). Used by the S7.D tile inspector.
  Future<CanvasCell?> getCellAt(int canvasLocalId, int x, int y) async {
    final rows = await _database.query(
      CanvasTables.cell,
      where: 'canvas_id = ? AND x = ? AND y = ?',
      whereArgs: [canvasLocalId, x, y],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _cellFromRow(rows.first);
  }

  /// Read the per-cell op history for (`x`, `y`) on a canvas, newest
  /// `op_ts` first. The `idx_applied_canvas_cell` index makes this
  /// cheap even on a busy canvas. Used by the S7.D tile inspector.
  Future<List<AppliedCanvasOp>> getCellHistory(
    int canvasLocalId,
    int x,
    int y, {
    int limit = 10,
  }) async {
    final rows = await _database.query(
      CanvasTables.appliedOp,
      where: 'canvas_id = ? AND x = ? AND y = ?',
      whereArgs: [canvasLocalId, x, y],
      orderBy: 'op_ts DESC, id DESC',
      limit: limit,
    );
    return rows.map(_appliedFromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Pending outbound queue
  // ---------------------------------------------------------------------------

  /// Aggregate pending-queue stats for one canvas in a single round
  /// trip. Powers the transmission-status view model
  /// (CANVAS_TRANSMISSION_STATUS_V0_1.md §5.1) without forcing three
  /// separate queries on the 2-second tick.
  Future<CanvasPendingStats> pendingStatsForCanvas(int canvasLocalId) async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS count, '
      'MIN(created_at_ms) AS oldest, '
      'MIN(next_attempt_at_ms) AS next_attempt '
      'FROM ${CanvasTables.pendingOp} '
      'WHERE canvas_id = ?',
      [canvasLocalId],
    );
    if (rows.isEmpty) return CanvasPendingStats.empty;
    final row = rows.first;
    final count = (row['count'] as int?) ?? 0;
    if (count == 0) return CanvasPendingStats.empty;
    return CanvasPendingStats(
      count: count,
      oldestCreatedAtMs: row['oldest'] as int?,
      nextAttemptAtMs: row['next_attempt'] as int?,
    );
  }

  /// Packed `y * widthCells + x` coordinates of every cell with a
  /// row in `pending_op`. The painter uses this to render pending
  /// cells at reduced opacity. Returns an empty set when the queue is
  /// empty.
  ///
  /// [widthCells] is the canvas width (128 in v0.1). The caller passes
  /// it so the packing matches the painter's coordinate scheme — keeps
  /// the repository free of canvas-geometry knowledge.
  Future<Set<int>> getPendingCellCoordinates(
    int canvasLocalId, {
    required int widthCells,
  }) async {
    final rows = await _database.query(
      CanvasTables.pendingOp,
      columns: const ['x', 'y'],
      where: 'canvas_id = ?',
      whereArgs: [canvasLocalId],
    );
    if (rows.isEmpty) return const <int>{};
    final result = <int>{};
    for (final row in rows) {
      final x = row['x'] as int;
      final y = row['y'] as int;
      result.add(y * widthCells + x);
    }
    return result;
  }

  /// Read queued ops for a canvas, oldest first.
  Future<List<PendingCanvasOp>> getPendingOpsForCanvas(
    int canvasLocalId, {
    int limit = 32,
  }) async {
    final rows = await _database.query(
      CanvasTables.pendingOp,
      where: 'canvas_id = ?',
      whereArgs: [canvasLocalId],
      orderBy: 'created_at_ms ASC, id ASC',
      limit: limit,
    );
    return rows.map(_pendingFromRow).toList(growable: false);
  }

  /// Read queued ops that are ready to send (state = queued, next
  /// attempt time has elapsed), oldest first. Used by the send
  /// coordinator (slice S4).
  Future<List<PendingCanvasOp>> getQueuedReadyOps({
    required int nowMs,
    int limit = 32,
  }) async {
    final rows = await _database.query(
      CanvasTables.pendingOp,
      where: 'state = ? AND next_attempt_at_ms <= ?',
      whereArgs: [PendingOpState.queued.storageCode, nowMs],
      orderBy: 'next_attempt_at_ms ASC, id ASC',
      limit: limit,
    );
    return rows.map(_pendingFromRow).toList(growable: false);
  }

  /// Mark an in-flight op as sent. Row is deleted; audit lives in
  /// `applied_op`.
  Future<void> markPendingSent(int pendingOpId) async {
    await _database.delete(
      CanvasTables.pendingOp,
      where: 'id = ?',
      whereArgs: [pendingOpId],
    );
  }

  /// Mark an op as in-flight. Used by the send coordinator immediately
  /// before handing the frame to the transport.
  Future<void> markPendingInFlight(int pendingOpId) async {
    await _database.update(
      CanvasTables.pendingOp,
      {'state': PendingOpState.inFlight.storageCode},
      where: 'id = ?',
      whereArgs: [pendingOpId],
    );
  }

  /// Defer a row back to the queued pool without incrementing `attempts`.
  ///
  /// Used by the send coordinator when the **SIP rate limiter** denied a
  /// frame: the row never actually went on-air, so we restart from a
  /// clean slate after the backoff. `attempts` and `last_error` are left
  /// untouched. Rate-limited rows MUST NOT count toward the `maxAttempts`
  /// terminal cap.
  Future<void> markPendingDeferred(
    int pendingOpId, {
    required int nextAttemptAtMs,
  }) async {
    await _database.update(
      CanvasTables.pendingOp,
      {
        'state': PendingOpState.queued.storageCode,
        'next_attempt_at_ms': nextAttemptAtMs,
      },
      where: 'id = ?',
      whereArgs: [pendingOpId],
    );
  }

  /// Record a send failure. Increments `attempts`, advances
  /// `next_attempt_at_ms`, transitions to `failedTerminal` after the
  /// configured max attempts.
  Future<void> markPendingFailed(
    int pendingOpId, {
    required String error,
    required int nextAttemptAtMs,
    int maxAttempts = 5,
  }) async {
    final rows = await _database.query(
      CanvasTables.pendingOp,
      columns: const ['attempts'],
      where: 'id = ?',
      whereArgs: [pendingOpId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final attempts = (rows.first['attempts'] as int) + 1;
    final terminal = attempts >= maxAttempts;
    await _database.update(
      CanvasTables.pendingOp,
      {
        'attempts': attempts,
        'next_attempt_at_ms': nextAttemptAtMs,
        'state': terminal
            ? PendingOpState.failedTerminal.storageCode
            : PendingOpState.queued.storageCode,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [pendingOpId],
    );
  }

  /// Enforce the per-canvas pending queue cap. Drops oldest queued rows
  /// until count < cap to make room for a fresh insert. Cell state has
  /// already been written to `cell`; peers catch up via digest sync.
  Future<void> _enforcePendingQueueCap(
    DatabaseExecutor txn,
    int canvasLocalId,
  ) async {
    final countRow = await txn.rawQuery(
      'SELECT COUNT(*) AS c FROM ${CanvasTables.pendingOp} WHERE canvas_id = ?',
      [canvasLocalId],
    );
    final currentCount = (countRow.first['c'] as int?) ?? 0;
    if (currentCount < CanvasLimits.pendingQueueCap) return;
    final toDrop = currentCount - CanvasLimits.pendingQueueCap + 1;
    final victims = await txn.query(
      CanvasTables.pendingOp,
      columns: const ['id'],
      where: 'canvas_id = ?',
      whereArgs: [canvasLocalId],
      orderBy: 'created_at_ms ASC, id ASC',
      limit: toDrop,
    );
    final ids = victims.map((r) => r['id'] as int).toList();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    final deleted = await txn.rawDelete(
      'DELETE FROM ${CanvasTables.pendingOp} WHERE id IN ($placeholders)',
      ids,
    );
    AppLogging.meshCanvas(
      'queue cap reached canvas=$canvasLocalId '
      'dropped=$deleted (count was $currentCount, cap=${CanvasLimits.pendingQueueCap})',
    );
  }

  // ---------------------------------------------------------------------------
  // Digest cache management
  // ---------------------------------------------------------------------------

  /// Set the global + concatenated tile digests for a canvas. Called by
  /// the digest computer (slice S9) after a successful recomputation.
  Future<void> updateCanvasDigests({
    required int canvasLocalId,
    required Uint8List globalDigest,
    required Uint8List tileDigests,
  }) async {
    _validateGlobalDigest(globalDigest);
    _validateTileDigests(tileDigests);
    await _database.update(
      CanvasTables.canvas,
      {'global_digest': globalDigest, 'tile_digests': tileDigests},
      where: 'id = ?',
      whereArgs: [canvasLocalId],
    );
  }

  /// Compute the current digests over a canvas's painted cells AND
  /// write them back to the `canvas` row. Returns the freshly-computed
  /// digest set so the caller can hand it to the wire emitter without
  /// a second read.
  ///
  /// Cheap on small canvases (the BLAKE2s-128 of a few hundred cells
  /// is sub-millisecond); for fully-painted boards we accept the
  /// ~10ms cost — the caller (sync coordinator) gates this with the
  /// canvas governor + jitter so it never lands on a hot UI frame.
  Future<CanvasDigestSet> computeAndCacheDigests(int canvasLocalId) async {
    final cells = await getCanvasCells(canvasLocalId);
    final set = await computeCanvasDigests(cells);
    await updateCanvasDigests(
      canvasLocalId: canvasLocalId,
      globalDigest: set.globalDigest,
      tileDigests: set.tileDigests,
    );
    return set;
  }

  /// Selectively invalidate the digest cache for a given cell.
  ///
  /// Mechanism: NULL `global_digest`, AND zero out the 8-byte slot for
  /// the affected tile inside `tile_digests`. The other 15 tile slots
  /// stay intact, satisfying the "do not wipe all tile digests" rule.
  /// A zero-filled slot is interpreted as "needs recomputation" by the
  /// digest computer; we trust that a real BLAKE2s-128 output is
  /// statistically never all zeros.
  Future<void> invalidateDigestForCell({
    required int canvasLocalId,
    required int x,
    required int y,
  }) async {
    _validateCellCoords(x, y);
    await _database.transaction((txn) async {
      await _invalidateDigestForCellInTxn(txn, canvasLocalId, x, y);
    });
  }

  Future<void> _invalidateDigestForCellInTxn(
    DatabaseExecutor txn,
    int canvasLocalId,
    int x,
    int y,
  ) async {
    final rows = await txn.query(
      CanvasTables.canvas,
      columns: const ['tile_digests'],
      where: 'id = ?',
      whereArgs: [canvasLocalId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final existing = rows.first['tile_digests'] as Uint8List?;
    Uint8List? updatedTileDigests;
    if (existing != null) {
      if (existing.length != CanvasDigestSizes.tilesConcatenatedBytes) {
        // Corrupted blob — refuse to mutate, just NULL it so the
        // digest computer will rebuild from scratch.
        updatedTileDigests = null;
        AppLogging.meshCanvas(
          'tile_digests size ${existing.length} != '
          '${CanvasDigestSizes.tilesConcatenatedBytes} for canvas=$canvasLocalId; '
          'resetting blob to NULL',
        );
      } else {
        final tileIdx = canvasTileIndexForCell(x, y);
        final mutated = Uint8List.fromList(existing);
        final offset = tileIdx * CanvasDigestSizes.tileBytes;
        for (var i = 0; i < CanvasDigestSizes.tileBytes; i++) {
          mutated[offset + i] = 0;
        }
        updatedTileDigests = mutated;
        AppLogging.meshCanvas(
          'digest invalidate canvas=$canvasLocalId cell=($x,$y) '
          'tileIdx=$tileIdx global=cleared',
        );
      }
    } else {
      AppLogging.meshCanvas(
        'digest invalidate canvas=$canvasLocalId cell=($x,$y) '
        '(no cached tile digests; global=cleared)',
      );
    }
    await txn.update(
      CanvasTables.canvas,
      {'global_digest': null, 'tile_digests': updatedTileDigests},
      where: 'id = ?',
      whereArgs: [canvasLocalId],
    );
  }

  // ---------------------------------------------------------------------------
  // Peer digest tracking
  // ---------------------------------------------------------------------------

  /// Upsert a peer's digest advertisement for a canvas.
  Future<void> upsertPeerDigest({
    required int canvasLocalId,
    required int peerNodeNum,
    required Uint8List? peerGlobalDigest,
    required Uint8List? peerTileDigests,
    required int? peerCellCount,
    required int lastHeardAtMs,
    int? lastSyncAtMs,
  }) async {
    if (peerGlobalDigest != null) _validateGlobalDigest(peerGlobalDigest);
    if (peerTileDigests != null) _validateTileDigests(peerTileDigests);
    await _database.insert(CanvasTables.peerDigest, {
      'canvas_id': canvasLocalId,
      'peer_node_num': peerNodeNum,
      'peer_global_digest': peerGlobalDigest,
      'peer_tile_digests': peerTileDigests,
      'peer_cell_count': peerCellCount,
      'last_heard_at_ms': lastHeardAtMs,
      'last_sync_at_ms': lastSyncAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Read peer digest rows for a canvas, freshest first.
  Future<List<PeerCanvasDigest>> listPeerDigests(int canvasLocalId) async {
    final rows = await _database.query(
      CanvasTables.peerDigest,
      where: 'canvas_id = ?',
      whereArgs: [canvasLocalId],
      orderBy: 'last_heard_at_ms DESC',
    );
    return rows.map(_peerDigestFromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Prune helpers
  // ---------------------------------------------------------------------------

  /// Delete `applied_op` rows older than [beforeMs]. Returns the number
  /// of rows deleted. Default retention is [CanvasRetention.appliedOpAge].
  Future<int> pruneAppliedOpsOlderThan({required int beforeMs}) async {
    final deleted = await _database.delete(
      CanvasTables.appliedOp,
      where: 'received_at_ms < ?',
      whereArgs: [beforeMs],
    );
    if (deleted > 0) {
      AppLogging.meshCanvas(
        'pruned $deleted applied_op rows older than $beforeMs',
      );
    }
    return deleted;
  }

  /// Delete `peer_digest` rows older than [beforeMs]. Returns the
  /// number of rows deleted.
  Future<int> prunePeerDigestsOlderThan({required int beforeMs}) async {
    final deleted = await _database.delete(
      CanvasTables.peerDigest,
      where: 'last_heard_at_ms < ?',
      whereArgs: [beforeMs],
    );
    if (deleted > 0) {
      AppLogging.meshCanvas(
        'pruned $deleted peer_digest rows older than $beforeMs',
      );
    }
    return deleted;
  }

  // ---------------------------------------------------------------------------
  // Internal: apply op + LWW comparator
  // ---------------------------------------------------------------------------

  /// Core apply routine shared by paintLocal / enqueuePaint /
  /// applyInboundPaint. Computes LWW, mutates `cell` only if accepted,
  /// always records an `applied_op` row with the accept/reject outcome,
  /// updates `canvas.last_op_at_ms`/`cell_count`, and selectively
  /// invalidates the digest cache when the cell mutates.
  Future<bool> _applyOpInTransaction({
    required DatabaseExecutor txn,
    required int canvasLocalId,
    required int x,
    required int y,
    required int color,
    required int authorNodeNum,
    required int opTs,
    required int opSeq,
    required AppliedOpDirection direction,
    required int receivedAtMs,
  }) async {
    final currentRows = await txn.query(
      CanvasTables.cell,
      where: 'canvas_id = ? AND x = ? AND y = ?',
      whereArgs: [canvasLocalId, x, y],
      limit: 1,
    );

    final bool accepted;
    final bool wasNewCell;
    if (currentRows.isEmpty) {
      accepted = true;
      wasNewCell = true;
    } else {
      final current = currentRows.first;
      accepted = canvasMergeAccept(
        opTs: opTs,
        opAuthor: authorNodeNum,
        opSeq: opSeq,
        currentTs: current['last_ts'] as int,
        currentAuthor: current['last_author'] as int,
        currentSeq: current['last_seq'] as int,
      );
      wasNewCell = false;
    }

    await txn.insert(CanvasTables.appliedOp, {
      'canvas_id': canvasLocalId,
      'x': x,
      'y': y,
      'color': color,
      'op_ts': opTs,
      'author_node_num': authorNodeNum,
      'op_seq': opSeq,
      'direction': direction.storageCode,
      'received_at_ms': receivedAtMs,
      'was_accepted': accepted ? 1 : 0,
    });

    if (!accepted) return false;

    await txn.insert(CanvasTables.cell, {
      'canvas_id': canvasLocalId,
      'x': x,
      'y': y,
      'color': color,
      'last_ts': opTs,
      'last_author': authorNodeNum,
      'last_seq': opSeq,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (wasNewCell) {
      await txn.rawUpdate(
        'UPDATE ${CanvasTables.canvas} '
        'SET last_op_at_ms = ?, cell_count = cell_count + 1 '
        'WHERE id = ?',
        [receivedAtMs, canvasLocalId],
      );
    } else {
      await txn.update(
        CanvasTables.canvas,
        {'last_op_at_ms': receivedAtMs},
        where: 'id = ?',
        whereArgs: [canvasLocalId],
      );
    }

    await _invalidateDigestForCellInTxn(txn, canvasLocalId, x, y);
    return true;
  }

  /// Test-only seam exposing the LWW comparator for direct verification.
  /// Delegates to the shared [canvasMergeAccept] in `canvas_merge.dart`.
  @visibleForTesting
  static bool debugAcceptForTest({
    required int opTs,
    required int opAuthor,
    required int opSeq,
    required int currentTs,
    required int currentAuthor,
    required int currentSeq,
  }) => canvasMergeAccept(
    opTs: opTs,
    opAuthor: opAuthor,
    opSeq: opSeq,
    currentTs: currentTs,
    currentAuthor: currentAuthor,
    currentSeq: currentSeq,
  );

  // ---------------------------------------------------------------------------
  // Row decoders
  // ---------------------------------------------------------------------------

  CanvasSummary _canvasFromRow(Map<String, Object?> row) => CanvasSummary(
    localId: row['id'] as int,
    canvasId: row['canvas_id'] as int,
    scope: CanvasScopeStorage.fromStorage(row['scope'] as String),
    channelIndex: row['channel_index'] as int?,
    name: row['name'] as String,
    width: row['width'] as int,
    height: row['height'] as int,
    paletteId: row['palette_id'] as int,
    status: CanvasStatusStorage.fromStorage(row['status'] as int),
    ownerNodeNum: row['owner_node_num'] as int?,
    createdAtMs: row['created_at_ms'] as int,
    lastOpAtMs: row['last_op_at_ms'] as int,
    globalDigest: row['global_digest'] as Uint8List?,
    tileDigests: row['tile_digests'] as Uint8List?,
    cellCount: row['cell_count'] as int,
  );

  CanvasCell _cellFromRow(Map<String, Object?> row) => CanvasCell(
    canvasLocalId: row['canvas_id'] as int,
    x: row['x'] as int,
    y: row['y'] as int,
    color: row['color'] as int,
    lastTs: row['last_ts'] as int,
    lastAuthor: row['last_author'] as int,
    lastSeq: row['last_seq'] as int,
  );

  PendingCanvasOp _pendingFromRow(Map<String, Object?> row) => PendingCanvasOp(
    id: row['id'] as int,
    canvasLocalId: row['canvas_id'] as int,
    x: row['x'] as int,
    y: row['y'] as int,
    color: row['color'] as int,
    opTs: row['op_ts'] as int,
    opSeq: row['op_seq'] as int,
    createdAtMs: row['created_at_ms'] as int,
    attempts: row['attempts'] as int,
    nextAttemptAtMs: row['next_attempt_at_ms'] as int,
    state: PendingOpStateStorage.fromStorage(row['state'] as int),
    lastError: row['last_error'] as String?,
  );

  AppliedCanvasOp _appliedFromRow(Map<String, Object?> row) => AppliedCanvasOp(
    id: row['id'] as int,
    canvasLocalId: row['canvas_id'] as int,
    x: row['x'] as int,
    y: row['y'] as int,
    color: row['color'] as int,
    opTs: row['op_ts'] as int,
    authorNodeNum: row['author_node_num'] as int,
    opSeq: row['op_seq'] as int,
    direction: AppliedOpDirectionStorage.fromStorage(row['direction'] as int),
    receivedAtMs: row['received_at_ms'] as int,
    wasAccepted: (row['was_accepted'] as int) == 1,
  );

  PeerCanvasDigest _peerDigestFromRow(Map<String, Object?> row) =>
      PeerCanvasDigest(
        canvasLocalId: row['canvas_id'] as int,
        peerNodeNum: row['peer_node_num'] as int,
        peerGlobalDigest: row['peer_global_digest'] as Uint8List?,
        peerTileDigests: row['peer_tile_digests'] as Uint8List?,
        peerCellCount: row['peer_cell_count'] as int?,
        lastHeardAtMs: row['last_heard_at_ms'] as int,
        lastSyncAtMs: row['last_sync_at_ms'] as int?,
      );

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  void _validateCanvasName(String name) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'canvas name must be non-empty');
    }
    final bytes = name.codeUnits;
    // Quick guard: a single code-unit count above the byte cap can never
    // shrink under UTF-8 encoding, so reject early without full encode.
    if (bytes.length > CanvasLimits.canvasNameMaxBytes) {
      throw ArgumentError.value(
        name,
        'name',
        'canvas name exceeds ${CanvasLimits.canvasNameMaxBytes} UTF-16 code units',
      );
    }
    final utf8Bytes = name.runes
        .map((rune) {
          if (rune < 0x80) return 1;
          if (rune < 0x800) return 2;
          if (rune < 0x10000) return 3;
          return 4;
        })
        .fold<int>(0, (a, b) => a + b);
    if (utf8Bytes > CanvasLimits.canvasNameMaxBytes) {
      throw ArgumentError.value(
        name,
        'name',
        'canvas name exceeds ${CanvasLimits.canvasNameMaxBytes} UTF-8 bytes',
      );
    }
  }

  void _validateChannelIndex(int channelIndex) {
    if (channelIndex < 0 || channelIndex > CanvasLimits.channelIndexMax) {
      throw ArgumentError.value(
        channelIndex,
        'channelIndex',
        'must be 0..${CanvasLimits.channelIndexMax}',
      );
    }
  }

  void _validateCell({required int x, required int y, required int color}) {
    _validateCellCoords(x, y);
    if (color < 0 || color > CanvasLimits.colorMax) {
      throw ArgumentError.value(
        color,
        'color',
        'palette index must be 0..${CanvasLimits.colorMax}',
      );
    }
  }

  void _validateCellCoords(int x, int y) {
    if (x < 0 || x > CanvasLimits.cellCoordMax) {
      throw ArgumentError.value(
        x,
        'x',
        'cell x must be 0..${CanvasLimits.cellCoordMax}',
      );
    }
    if (y < 0 || y > CanvasLimits.cellCoordMax) {
      throw ArgumentError.value(
        y,
        'y',
        'cell y must be 0..${CanvasLimits.cellCoordMax}',
      );
    }
  }

  void _validateGlobalDigest(Uint8List digest) {
    if (digest.length != CanvasDigestSizes.globalBytes) {
      throw ArgumentError.value(
        digest.length,
        'globalDigest.length',
        'global digest must be exactly ${CanvasDigestSizes.globalBytes} bytes',
      );
    }
  }

  void _validateTileDigests(Uint8List blob) {
    if (blob.length != CanvasDigestSizes.tilesConcatenatedBytes) {
      throw ArgumentError.value(
        blob.length,
        'tileDigests.length',
        'tile digests blob must be exactly '
            '${CanvasDigestSizes.tilesConcatenatedBytes} bytes',
      );
    }
  }
}
