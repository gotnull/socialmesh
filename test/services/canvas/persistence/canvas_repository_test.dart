// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_repo_${_testPid}_${_testDbSeq++}.db');
}

Future<({CanvasDatabase db, CanvasRepository repo})> _open() async {
  final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
  await db.init();
  return (db: db, repo: CanvasRepository(db));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Canvas row CRUD', () {
    test('getOrCreateLocalCanvas is idempotent', () async {
      final h = await _open();
      try {
        final first = await h.repo.getOrCreateLocalCanvas();
        final second = await h.repo.getOrCreateLocalCanvas();
        expect(first.localId, second.localId);
        expect(first.scope, CanvasScope.local);
        expect(first.canvasId, kLocalCanvasIdSentinel);
        expect(first.width, kCanvasDefaultWidth);
        expect(first.height, kCanvasDefaultHeight);
        expect(first.paletteId, kCanvasDefaultPaletteId);
        expect(first.status, CanvasStatus.open);
        expect(first.channelIndex, isNull);
      } finally {
        await h.db.close();
      }
    });

    test(
      'getOrCreateMeshCanvas is idempotent on (canvas_id, channel)',
      () async {
        final h = await _open();
        try {
          final a = await h.repo.getOrCreateMeshCanvas(
            canvasId: 0x12345678ABCDEF01,
            channelIndex: 0,
            name: 'Primary',
          );
          final b = await h.repo.getOrCreateMeshCanvas(
            canvasId: 0x12345678ABCDEF01,
            channelIndex: 0,
            name: 'Primary',
          );
          expect(a.localId, b.localId);

          // Different channel → different row.
          final c = await h.repo.getOrCreateMeshCanvas(
            canvasId: 0x12345678ABCDEF01,
            channelIndex: 1,
            name: 'Primary',
          );
          expect(c.localId, isNot(a.localId));
        } finally {
          await h.db.close();
        }
      },
    );

    test('listCanvases returns rows ordered by recency', () async {
      final h = await _open();
      try {
        await h.repo.getOrCreateLocalCanvas(nowMsOverride: 1000);
        await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xAA,
          channelIndex: 0,
          name: 'A',
          nowMsOverride: 2000,
        );
        await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xBB,
          channelIndex: 1,
          name: 'B',
          nowMsOverride: 3000,
        );

        final all = await h.repo.listCanvases();
        expect(all.length, 3);
        expect(all.first.canvasId, 0xBB);

        final meshOnly = await h.repo.listCanvases(scope: CanvasScope.mesh);
        expect(meshOnly.length, 2);
        expect(meshOnly.every((c) => c.scope == CanvasScope.mesh), isTrue);
      } finally {
        await h.db.close();
      }
    });
  });

  group('paintLocal', () {
    test('updates cell + applied_op but inserts no pending_op row', () async {
      final h = await _open();
      try {
        final local = await h.repo.getOrCreateLocalCanvas();
        final accepted = await h.repo.paintLocal(
          canvasLocalId: local.localId,
          x: 5,
          y: 7,
          color: 12,
          authorNodeNum: 0x100,
          opTs: 100,
          opSeq: 1,
          receivedAtMsOverride: 1_000_000,
        );
        expect(accepted, isTrue);

        final cells = await h.repo.getCanvasCells(local.localId);
        expect(cells.length, 1);
        expect(cells.first.color, 12);

        final applied = await h.repo.getRecentAppliedOps(local.localId);
        expect(applied.length, 1);
        expect(applied.first.direction, AppliedOpDirection.outbound);
        expect(applied.first.wasAccepted, isTrue);

        final pending = await h.repo.getPendingOpsForCanvas(local.localId);
        expect(pending, isEmpty);
      } finally {
        await h.db.close();
      }
    });
  });

  group('enqueuePaint', () {
    test('updates cell + applied_op + inserts pending_op', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xCC,
          channelIndex: 0,
          name: 'Mesh',
        );
        final accepted = await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 9,
          y: 11,
          color: 33,
          authorNodeNum: 0x200,
          opTs: 200,
          opSeq: 5,
          createdAtMsOverride: 5_000_000,
        );
        expect(accepted, isTrue);

        final cells = await h.repo.getCanvasCells(mesh.localId);
        expect(cells.length, 1);
        expect(cells.first.color, 33);

        final applied = await h.repo.getRecentAppliedOps(mesh.localId);
        expect(applied.length, 1);
        expect(applied.first.direction, AppliedOpDirection.outbound);
        expect(applied.first.wasAccepted, isTrue);

        final pending = await h.repo.getPendingOpsForCanvas(mesh.localId);
        expect(pending.length, 1);
        expect(pending.first.state, PendingOpState.queued);
        expect(pending.first.attempts, 0);
        expect(pending.first.color, 33);
      } finally {
        await h.db.close();
      }
    });

    // Coalescing: tapping the same cell while an earlier pending row
    // is still queued must NOT grow the queue. The earlier row is
    // updated in place with the latest color / op_ts / op_seq.
    // Prevents users from filling pending_op with obsolete paints
    // when they hammer a single cell. Spec: anti-spam brief item 4.
    test(
      'coalesces same-cell repaints into the existing pending row',
      () async {
        final h = await _open();
        try {
          final mesh = await h.repo.getOrCreateMeshCanvas(
            canvasId: 0xCD,
            channelIndex: 0,
            name: 'Mesh',
          );
          await h.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: 5,
            y: 7,
            color: 10,
            authorNodeNum: 0x200,
            opTs: 100,
            opSeq: 1,
            createdAtMsOverride: 1_000,
          );
          // Same cell, fresher tap. Should overwrite the existing row.
          await h.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: 5,
            y: 7,
            color: 42,
            authorNodeNum: 0x200,
            opTs: 200,
            opSeq: 2,
            createdAtMsOverride: 2_000,
          );

          final pending = await h.repo.getPendingOpsForCanvas(mesh.localId);
          expect(
            pending.length,
            1,
            reason: 'same-cell repaint must coalesce, not grow the queue',
          );
          expect(pending.first.color, 42, reason: 'latest local intent wins');
          expect(pending.first.opTs, 200);
          expect(pending.first.opSeq, 2);
        } finally {
          await h.db.close();
        }
      },
    );

    test('different cells stay as separate pending rows', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xCE,
          channelIndex: 0,
          name: 'Mesh',
        );
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 1,
          y: 1,
          color: 5,
          authorNodeNum: 0x200,
          opTs: 100,
          opSeq: 1,
        );
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 2,
          y: 2,
          color: 5,
          authorNodeNum: 0x200,
          opTs: 100,
          opSeq: 2,
        );
        final pending = await h.repo.getPendingOpsForCanvas(mesh.localId);
        expect(
          pending.length,
          2,
          reason: 'distinct cells must remain distinct pending rows',
        );
      } finally {
        await h.db.close();
      }
    });
  });

  group('LWW comparator (applyInboundPaint)', () {
    test('newer op_ts wins', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xD0,
          channelIndex: 0,
          name: 'M',
        );
        await h.repo.applyInboundPaint(
          canvasLocalId: mesh.localId,
          op: const InboundPaintOp(
            x: 1,
            y: 1,
            color: 5,
            authorNodeNum: 0x500,
            opTs: 100,
            opSeq: 1,
          ),
        );
        final accepted = await h.repo.applyInboundPaint(
          canvasLocalId: mesh.localId,
          op: const InboundPaintOp(
            x: 1,
            y: 1,
            color: 6,
            authorNodeNum: 0x500,
            opTs: 200,
            opSeq: 2,
          ),
        );
        expect(accepted, isTrue);
        final cells = await h.repo.getCanvasCells(mesh.localId);
        expect(cells.single.color, 6);
        expect(cells.single.lastTs, 200);
      } finally {
        await h.db.close();
      }
    });

    test(
      'older op_ts rejected, records was_accepted=0, cell unchanged',
      () async {
        final h = await _open();
        try {
          final mesh = await h.repo.getOrCreateMeshCanvas(
            canvasId: 0xD1,
            channelIndex: 0,
            name: 'M',
          );
          await h.repo.applyInboundPaint(
            canvasLocalId: mesh.localId,
            op: const InboundPaintOp(
              x: 0,
              y: 0,
              color: 9,
              authorNodeNum: 0x100,
              opTs: 500,
              opSeq: 1,
            ),
          );
          final accepted = await h.repo.applyInboundPaint(
            canvasLocalId: mesh.localId,
            op: const InboundPaintOp(
              x: 0,
              y: 0,
              color: 3,
              authorNodeNum: 0x100,
              opTs: 100, // older
              opSeq: 99,
            ),
          );
          expect(accepted, isFalse);

          final cells = await h.repo.getCanvasCells(mesh.localId);
          expect(cells.single.color, 9);

          final applied = await h.repo.getRecentAppliedOps(mesh.localId);
          expect(applied.length, 2);
          // Two distinct applied_op rows; one rejected.
          expect(applied.any((o) => !o.wasAccepted), isTrue);
          expect(applied.any((o) => o.wasAccepted), isTrue);
        } finally {
          await h.db.close();
        }
      },
    );

    test('same timestamp lower author_id wins', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xD2,
          channelIndex: 0,
          name: 'M',
        );
        await h.repo.applyInboundPaint(
          canvasLocalId: mesh.localId,
          op: const InboundPaintOp(
            x: 2,
            y: 2,
            color: 1,
            authorNodeNum: 0x200,
            opTs: 100,
            opSeq: 0,
          ),
        );
        final accepted = await h.repo.applyInboundPaint(
          canvasLocalId: mesh.localId,
          op: const InboundPaintOp(
            x: 2,
            y: 2,
            color: 2,
            authorNodeNum: 0x100, // lower
            opTs: 100,
            opSeq: 0,
          ),
        );
        expect(accepted, isTrue);
        final cells = await h.repo.getCanvasCells(mesh.localId);
        expect(cells.single.color, 2);
        expect(cells.single.lastAuthor, 0x100);
      } finally {
        await h.db.close();
      }
    });

    test('same (ts, author) — newer op_seq via u8 modulo wins', () async {
      // Direct comparator test isolates the rollover-aware op_seq rule
      // from the I/O layer.
      expect(
        CanvasRepository.debugAcceptForTest(
          opTs: 100,
          opAuthor: 1,
          opSeq: 5,
          currentTs: 100,
          currentAuthor: 1,
          currentSeq: 4,
        ),
        isTrue,
      );
      // Wrap forward across 255 → 0.
      expect(
        CanvasRepository.debugAcceptForTest(
          opTs: 100,
          opAuthor: 1,
          opSeq: 0,
          currentTs: 100,
          currentAuthor: 1,
          currentSeq: 255,
        ),
        isTrue,
      );
      // delta=128 sits at the inclusive boundary and is NOT accepted —
      // the safe forward window is [1..127].
      expect(
        CanvasRepository.debugAcceptForTest(
          opTs: 100,
          opAuthor: 1,
          opSeq: 128,
          currentTs: 100,
          currentAuthor: 1,
          currentSeq: 0,
        ),
        isFalse,
      );
      // Reverse direction is rejected.
      expect(
        CanvasRepository.debugAcceptForTest(
          opTs: 100,
          opAuthor: 1,
          opSeq: 4,
          currentTs: 100,
          currentAuthor: 1,
          currentSeq: 5,
        ),
        isFalse,
      );
    });
  });

  group('op-layer dedupe', () {
    test(
      'duplicate (canvas, author, op_ts, op_seq, x, y) is skipped',
      () async {
        final h = await _open();
        try {
          final mesh = await h.repo.getOrCreateMeshCanvas(
            canvasId: 0xD3,
            channelIndex: 0,
            name: 'M',
          );
          const op = InboundPaintOp(
            x: 4,
            y: 4,
            color: 7,
            authorNodeNum: 0x100,
            opTs: 1000,
            opSeq: 1,
          );
          final first = await h.repo.applyInboundPaint(
            canvasLocalId: mesh.localId,
            op: op,
          );
          expect(first, isTrue);
          final second = await h.repo.applyInboundPaint(
            canvasLocalId: mesh.localId,
            op: op,
          );
          expect(second, isFalse);

          // Only ONE applied_op row exists for the dedupe tuple.
          final applied = await h.repo.getRecentAppliedOps(mesh.localId);
          expect(applied.length, 1);
        } finally {
          await h.db.close();
        }
      },
    );

    test(
      'op_seq rollover: same seq but different op_ts is NOT a duplicate',
      () async {
        final h = await _open();
        try {
          final mesh = await h.repo.getOrCreateMeshCanvas(
            canvasId: 0xD4,
            channelIndex: 0,
            name: 'M',
          );
          // Paint at ts=100 seq=5
          await h.repo.applyInboundPaint(
            canvasLocalId: mesh.localId,
            op: const InboundPaintOp(
              x: 1,
              y: 1,
              color: 10,
              authorNodeNum: 0xAA,
              opTs: 100,
              opSeq: 5,
            ),
          );
          // Now the same author has wrapped op_seq 256 times and lands
          // on seq=5 again, but with a later op_ts. Without op_ts in
          // the dedupe key this would falsely be skipped.
          final laterAccepted = await h.repo.applyInboundPaint(
            canvasLocalId: mesh.localId,
            op: const InboundPaintOp(
              x: 1,
              y: 1,
              color: 11,
              authorNodeNum: 0xAA,
              opTs: 100_000, // much later
              opSeq: 5,
            ),
          );
          expect(laterAccepted, isTrue);

          final applied = await h.repo.getRecentAppliedOps(mesh.localId);
          expect(applied.length, 2);

          final cells = await h.repo.getCanvasCells(mesh.localId);
          expect(cells.single.color, 11);
        } finally {
          await h.db.close();
        }
      },
    );
  });

  group('pending queue cap', () {
    test('enqueueing past 256 drops oldest queued rows and logs', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xE0,
          channelIndex: 0,
          name: 'M',
        );

        // Enqueue (cap + extra) ops, varying (x, y) so each is a new
        // cell and op_ts increments to keep LWW happy.
        for (var i = 0; i < CanvasLimits.pendingQueueCap + 10; i++) {
          final x = i % CanvasGeometry.width;
          final y = (i ~/ CanvasGeometry.width) % CanvasGeometry.height;
          await h.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: x,
            y: y,
            color: i % 64,
            authorNodeNum: 0x500,
            opTs: 1000 + i,
            opSeq: i & 0xFF,
            createdAtMsOverride: 10_000_000 + i,
          );
        }

        // Queue stays at or below the cap.
        final rawCount =
            (await h.db.database.rawQuery(
                  'SELECT COUNT(*) AS c FROM ${CanvasTables.pendingOp}',
                )).first['c']
                as int;
        expect(rawCount, lessThanOrEqualTo(CanvasLimits.pendingQueueCap));

        // The newest enqueue MUST still be present (we drop OLDEST).
        final pending = await h.repo.getPendingOpsForCanvas(
          mesh.localId,
          limit: CanvasLimits.pendingQueueCap + 50,
        );
        expect(pending.last.opTs, 1000 + CanvasLimits.pendingQueueCap + 9);
      } finally {
        await h.db.close();
      }
    });
  });

  group('pending state transitions', () {
    test('markPendingSent deletes the row', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xE1,
          channelIndex: 0,
          name: 'M',
        );
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 0,
          y: 0,
          color: 1,
          authorNodeNum: 1,
          opTs: 100,
          opSeq: 1,
        );
        final pending = await h.repo.getPendingOpsForCanvas(mesh.localId);
        expect(pending, hasLength(1));
        await h.repo.markPendingSent(pending.first.id);
        final after = await h.repo.getPendingOpsForCanvas(mesh.localId);
        expect(after, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test('markPendingFailed increments attempts and sets next_attempt_at_ms; '
        'transitions to failedTerminal after maxAttempts', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xE2,
          channelIndex: 0,
          name: 'M',
        );
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 2,
          y: 2,
          color: 1,
          authorNodeNum: 1,
          opTs: 100,
          opSeq: 1,
        );
        final pending = (await h.repo.getPendingOpsForCanvas(
          mesh.localId,
        )).single;

        // 4 failures keep it queued.
        for (var i = 0; i < 4; i++) {
          await h.repo.markPendingFailed(
            pending.id,
            error: 'timeout', // lint-allow: hardcoded-string
            nextAttemptAtMs: 9000 + i,
          );
        }
        var current = (await h.repo.getPendingOpsForCanvas(
          mesh.localId,
        )).single;
        expect(current.attempts, 4);
        expect(current.state, PendingOpState.queued);
        expect(current.nextAttemptAtMs, 9003);
        expect(current.lastError, 'timeout');

        // 5th failure trips terminal.
        await h.repo.markPendingFailed(
          pending.id,
          error: 'timeout', // lint-allow: hardcoded-string
          nextAttemptAtMs: 9999,
        );
        current = (await h.repo.getPendingOpsForCanvas(mesh.localId)).single;
        expect(current.attempts, 5);
        expect(current.state, PendingOpState.failedTerminal);
      } finally {
        await h.db.close();
      }
    });
  });

  group('digest invalidation', () {
    test('clears global_digest and only the affected tile slot', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xF0,
          channelIndex: 0,
          name: 'M',
        );
        // Seed both digest blobs with a non-zero pattern so we can
        // distinguish "cleared" from "untouched".
        final globalSeed = Uint8List.fromList(List.filled(16, 0xAB));
        final tilesSeed = Uint8List.fromList(
          List.filled(CanvasDigestSizes.tilesConcatenatedBytes, 0xCD),
        );
        await h.repo.updateCanvasDigests(
          canvasLocalId: mesh.localId,
          globalDigest: globalSeed,
          tileDigests: tilesSeed,
        );

        // Paint into tile (1, 0) (cell (40, 5) → tile idx 1).
        await h.repo.applyInboundPaint(
          canvasLocalId: mesh.localId,
          op: const InboundPaintOp(
            x: 40,
            y: 5,
            color: 7,
            authorNodeNum: 1,
            opTs: 100,
            opSeq: 1,
          ),
        );

        final updated = (await h.repo.getCanvasByLocalId(mesh.localId))!;
        expect(updated.globalDigest, isNull);

        final td = updated.tileDigests;
        expect(td, isNotNull);
        expect(td!.length, CanvasDigestSizes.tilesConcatenatedBytes);

        final tileIdx = canvasTileIndexForCell(40, 5);
        expect(tileIdx, 1);
        // The affected 8-byte slot is now zero-filled.
        for (var i = 0; i < CanvasDigestSizes.tileBytes; i++) {
          expect(td[tileIdx * CanvasDigestSizes.tileBytes + i], 0);
        }
        // Every other tile slot keeps the seed value.
        for (var t = 0; t < CanvasGeometry.tileCount; t++) {
          if (t == tileIdx) continue;
          for (var i = 0; i < CanvasDigestSizes.tileBytes; i++) {
            expect(td[t * CanvasDigestSizes.tileBytes + i], 0xCD);
          }
        }
      } finally {
        await h.db.close();
      }
    });

    test('invalidate when tile_digests is null only nulls global', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xF1,
          channelIndex: 0,
          name: 'M',
        );
        await h.repo.applyInboundPaint(
          canvasLocalId: mesh.localId,
          op: const InboundPaintOp(
            x: 0,
            y: 0,
            color: 3,
            authorNodeNum: 1,
            opTs: 1,
            opSeq: 0,
          ),
        );
        final s = (await h.repo.getCanvasByLocalId(mesh.localId))!;
        expect(s.globalDigest, isNull);
        expect(s.tileDigests, isNull);
      } finally {
        await h.db.close();
      }
    });
  });

  group('peer digest', () {
    test('upsert + list returns latest state', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xF2,
          channelIndex: 0,
          name: 'M',
        );
        await h.repo.upsertPeerDigest(
          canvasLocalId: mesh.localId,
          peerNodeNum: 0x100,
          peerGlobalDigest: Uint8List.fromList(List.filled(16, 1)),
          peerTileDigests: Uint8List.fromList(
            List.filled(CanvasDigestSizes.tilesConcatenatedBytes, 2),
          ),
          peerCellCount: 50,
          lastHeardAtMs: 1000,
        );
        await h.repo.upsertPeerDigest(
          canvasLocalId: mesh.localId,
          peerNodeNum: 0x100,
          peerGlobalDigest: Uint8List.fromList(List.filled(16, 9)),
          peerTileDigests: Uint8List.fromList(
            List.filled(CanvasDigestSizes.tilesConcatenatedBytes, 8),
          ),
          peerCellCount: 60,
          lastHeardAtMs: 2000,
        );
        final peers = await h.repo.listPeerDigests(mesh.localId);
        expect(peers, hasLength(1));
        expect(peers.single.peerCellCount, 60);
        expect(peers.single.lastHeardAtMs, 2000);
        expect(peers.single.peerGlobalDigest!.first, 9);
      } finally {
        await h.db.close();
      }
    });

    test('prunePeerDigestsOlderThan deletes stale rows', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xF3,
          channelIndex: 0,
          name: 'M',
        );
        await h.repo.upsertPeerDigest(
          canvasLocalId: mesh.localId,
          peerNodeNum: 0x1,
          peerGlobalDigest: null,
          peerTileDigests: null,
          peerCellCount: 0,
          lastHeardAtMs: 100, // stale
        );
        await h.repo.upsertPeerDigest(
          canvasLocalId: mesh.localId,
          peerNodeNum: 0x2,
          peerGlobalDigest: null,
          peerTileDigests: null,
          peerCellCount: 0,
          lastHeardAtMs: 9_000_000, // fresh
        );
        final deleted = await h.repo.prunePeerDigestsOlderThan(beforeMs: 1000);
        expect(deleted, 1);
        final remaining = await h.repo.listPeerDigests(mesh.localId);
        expect(remaining, hasLength(1));
        expect(remaining.single.peerNodeNum, 0x2);
      } finally {
        await h.db.close();
      }
    });
  });

  group('applied_op prune', () {
    test('pruneAppliedOpsOlderThan deletes by received_at_ms', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 0xF4,
          channelIndex: 0,
          name: 'M',
        );
        for (var i = 0; i < 5; i++) {
          await h.repo.applyInboundPaint(
            canvasLocalId: mesh.localId,
            op: InboundPaintOp(
              x: i,
              y: i,
              color: i % 64,
              authorNodeNum: 1,
              opTs: i,
              opSeq: i,
            ),
            receivedAtMsOverride: 1000 + i,
          );
        }
        final before = await h.repo.getRecentAppliedOps(mesh.localId);
        expect(before, hasLength(5));

        final deleted = await h.repo.pruneAppliedOpsOlderThan(beforeMs: 1003);
        // rows with received_at_ms < 1003 → 1000, 1001, 1002 = 3 rows
        expect(deleted, 3);

        final after = await h.repo.getRecentAppliedOps(mesh.localId);
        expect(after, hasLength(2));
      } finally {
        await h.db.close();
      }
    });
  });

  group('validation', () {
    test('rejects out-of-range x/y/color', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 1,
          channelIndex: 0,
          name: 'M',
        );
        expect(
          () => h.repo.paintLocal(
            canvasLocalId: mesh.localId,
            x: 128,
            y: 0,
            color: 0,
            authorNodeNum: 1,
            opTs: 1,
            opSeq: 0,
          ),
          throwsArgumentError,
        );
        expect(
          () => h.repo.paintLocal(
            canvasLocalId: mesh.localId,
            x: 0,
            y: -1,
            color: 0,
            authorNodeNum: 1,
            opTs: 1,
            opSeq: 0,
          ),
          throwsArgumentError,
        );
        expect(
          () => h.repo.paintLocal(
            canvasLocalId: mesh.localId,
            x: 0,
            y: 0,
            color: 64,
            authorNodeNum: 1,
            opTs: 1,
            opSeq: 0,
          ),
          throwsArgumentError,
        );
      } finally {
        await h.db.close();
      }
    });

    test('rejects out-of-range channel index', () async {
      final h = await _open();
      try {
        expect(
          () => h.repo.getOrCreateMeshCanvas(
            canvasId: 1,
            channelIndex: 8,
            name: 'X',
          ),
          throwsArgumentError,
        );
        expect(
          () => h.repo.getOrCreateMeshCanvas(
            canvasId: 1,
            channelIndex: -1,
            name: 'X',
          ),
          throwsArgumentError,
        );
      } finally {
        await h.db.close();
      }
    });

    test('rejects empty and oversize canvas names', () async {
      final h = await _open();
      try {
        expect(
          () => h.repo.getOrCreateLocalCanvas(name: ''),
          throwsArgumentError,
        );
        // 33 single-byte UTF-8 chars exceeds 32-byte cap.
        expect(
          () => h.repo.getOrCreateLocalCanvas(name: 'a' * 33),
          throwsArgumentError,
        );
      } finally {
        await h.db.close();
      }
    });

    test('rejects wrong digest blob lengths', () async {
      final h = await _open();
      try {
        final mesh = await h.repo.getOrCreateMeshCanvas(
          canvasId: 1,
          channelIndex: 0,
          name: 'M',
        );
        expect(
          () => h.repo.updateCanvasDigests(
            canvasLocalId: mesh.localId,
            globalDigest: Uint8List(15), // wrong
            tileDigests: Uint8List(CanvasDigestSizes.tilesConcatenatedBytes),
          ),
          throwsArgumentError,
        );
        expect(
          () => h.repo.updateCanvasDigests(
            canvasLocalId: mesh.localId,
            globalDigest: Uint8List(CanvasDigestSizes.globalBytes),
            tileDigests: Uint8List(127), // wrong
          ),
          throwsArgumentError,
        );
      } finally {
        await h.db.close();
      }
    });
  });
}
