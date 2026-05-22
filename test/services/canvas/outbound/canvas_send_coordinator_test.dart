// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_codec.dart';
import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';
import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_coord_${_testPid}_${_testDbSeq++}.db');
}

class _FakeClock {
  int _ms;
  _FakeClock(this._ms);
  int now() => _ms;
  void advance(Duration d) {
    _ms += d.inMilliseconds;
  }
}

class _Sent {
  final Uint8List payload;
  final int channelIndex;
  const _Sent({required this.payload, required this.channelIndex});
}

class _FakeChannel implements CanvasOutboundChannel {
  final List<_Sent> sent = <_Sent>[];

  /// Outcomes consumed in arrival order. Defaults to a successful send
  /// when the queue runs dry.
  final List<CanvasSendResult> _outcomes = <CanvasSendResult>[];

  CanvasSendResult _defaultOutcome = CanvasSendResult.sent(wireBytes: 0);

  void setDefault(CanvasSendResult outcome) => _defaultOutcome = outcome;

  void enqueueOutcome(CanvasSendResult outcome) => _outcomes.add(outcome);

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    sent.add(_Sent(payload: canvasPayload, channelIndex: channelIndex));
    if (_outcomes.isNotEmpty) return _outcomes.removeAt(0);
    if (_defaultOutcome.outcome == CanvasSendOutcome.sent) {
      // Synthesise a plausible wire-byte count so success outcomes
      // always carry a non-zero number for assertions.
      return CanvasSendResult.sent(wireBytes: canvasPayload.length + 22);
    }
    return _defaultOutcome;
  }
}

Future<
  ({
    CanvasDatabase db,
    CanvasRepository repo,
    CanvasOutboundGovernor governor,
    _FakeChannel channel,
    _FakeClock clock,
    CanvasSendCoordinator coordinator,
  })
>
_buildHarness({
  int localNodeNum = 0x100,
  int? Function()? nodeNumOverride,
}) async {
  final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
  await db.init();
  final repo = CanvasRepository(db);
  final clock = _FakeClock(1_000_000);
  final governor = CanvasOutboundGovernor(nowMs: clock.now);
  final channel = _FakeChannel();
  final coordinator = CanvasSendCoordinator(
    repository: repo,
    governor: governor,
    outbound: channel,
    localNodeNumProvider: nodeNumOverride ?? () => localNodeNum,
    nowMs: clock.now,
  );
  return (
    db: db,
    repo: repo,
    governor: governor,
    channel: channel,
    clock: clock,
    coordinator: coordinator,
  );
}

Future<CanvasSummary> _mkMeshCanvas(
  CanvasRepository repo, {
  int canvasId = 0xC0DE,
  int channelIndex = 0,
  String name = 'Mesh',
}) async {
  return repo.getOrCreateMeshCanvas(
    canvasId: canvasId,
    channelIndex: channelIndex,
    name: name,
  );
}

Future<void> _enqueueRange({
  required CanvasRepository repo,
  required int canvasLocalId,
  required int count,
  required int authorNodeNum,
  required int baseOpTs,
  required int baseCreatedAtMs,
}) async {
  // Every row shares the same `created_at_ms` / `next_attempt_at_ms`
  // so the drain query (`next_attempt_at_ms <= now`) sees them all
  // ready at once. Within-canvas ordering is preserved by the
  // AUTOINCREMENT `id ASC` secondary sort in the repository query.
  for (var i = 0; i < count; i++) {
    final accepted = await repo.enqueuePaint(
      canvasLocalId: canvasLocalId,
      x: i % CanvasGeometry.width,
      y: (i ~/ CanvasGeometry.width) % CanvasGeometry.height,
      color: i % 64,
      authorNodeNum: authorNodeNum,
      opTs: baseOpTs + i,
      opSeq: i & 0xFF,
      createdAtMsOverride: baseCreatedAtMs,
    );
    expect(accepted, isTrue);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ---------------------------------------------------------------------------
  // Happy path
  // ---------------------------------------------------------------------------

  group('drain basic flow', () {
    test('sends one queued op as a paint_batch with one record', () async {
      final h = await _buildHarness(localNodeNum: 0xAA);
      try {
        final mesh = await _mkMeshCanvas(h.repo, channelIndex: 2);
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 5,
          y: 7,
          color: 12,
          authorNodeNum: 0xAA,
          opTs: 1000,
          opSeq: 1,
          createdAtMsOverride: h.clock.now(),
        );

        final framesSent = await h.coordinator.drain();
        expect(framesSent, 1);
        expect(h.channel.sent, hasLength(1));

        final captured = h.channel.sent.first;
        expect(captured.channelIndex, 2);
        final decoded = CanvasCodec.decodePaintBatch(captured.payload);
        expect(decoded, isNotNull);
        expect(decoded!.canvasId, mesh.canvasId);
        expect(decoded.authorId, 0xAA);
        expect(decoded.ops, hasLength(1));
        expect(decoded.ops.first.x, 5);
        expect(decoded.ops.first.y, 7);
        expect(decoded.ops.first.color, 12);
        expect(decoded.ops.first.tsOffset, 0);
        expect(decoded.ops.first.opSeq, 1);

        // pending_op row was deleted on success.
        final remaining = await h.repo.getPendingOpsForCanvas(mesh.localId);
        expect(remaining, isEmpty);

        // Canvas governor charged exactly the canvas payload size.
        expect(
          h.governor.remainingBytes,
          CanvasOutboundGovernor.budgetBytes - captured.payload.length,
        );
      } finally {
        await h.db.close();
      }
    });

    test('batches up to 21 ops into one frame', () async {
      final h = await _buildHarness();
      try {
        final mesh = await _mkMeshCanvas(h.repo);
        await _enqueueRange(
          repo: h.repo,
          canvasLocalId: mesh.localId,
          count: 21,
          authorNodeNum: 0x100,
          baseOpTs: 1000,
          baseCreatedAtMs: h.clock.now(),
        );

        final framesSent = await h.coordinator.drain();
        expect(framesSent, 1);
        final decoded = CanvasCodec.decodePaintBatch(
          h.channel.sent.single.payload,
        )!;
        expect(decoded.ops, hasLength(21));
      } finally {
        await h.db.close();
      }
    });

    test('22 ops produce two frames in one drain pass', () async {
      final h = await _buildHarness();
      try {
        final mesh = await _mkMeshCanvas(h.repo);
        await _enqueueRange(
          repo: h.repo,
          canvasLocalId: mesh.localId,
          count: 22,
          authorNodeNum: 0x100,
          baseOpTs: 1000,
          baseCreatedAtMs: h.clock.now(),
        );

        final framesSent = await h.coordinator.drain();
        expect(framesSent, 2);
        expect(h.channel.sent, hasLength(2));
        final first = CanvasCodec.decodePaintBatch(h.channel.sent[0].payload)!;
        final second = CanvasCodec.decodePaintBatch(h.channel.sent[1].payload)!;
        expect(first.ops, hasLength(21));
        expect(second.ops, hasLength(1));
        expect(second.batchSeq, isNot(first.batchSeq));
      } finally {
        await h.db.close();
      }
    });

    test('explicit channelIndex propagates to the outbound channel', () async {
      final h = await _buildHarness();
      try {
        final mesh = await _mkMeshCanvas(h.repo, channelIndex: 5);
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 0,
          y: 0,
          color: 0,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
          createdAtMsOverride: 100,
        );
        await h.coordinator.drain();
        expect(h.channel.sent.single.channelIndex, 5);
      } finally {
        await h.db.close();
      }
    });

    test('pending order is preserved within a canvas', () async {
      final h = await _buildHarness();
      try {
        final mesh = await _mkMeshCanvas(h.repo);
        await _enqueueRange(
          repo: h.repo,
          canvasLocalId: mesh.localId,
          count: 5,
          authorNodeNum: 0x100,
          baseOpTs: 1000,
          baseCreatedAtMs: h.clock.now(),
        );
        await h.coordinator.drain();
        final decoded = CanvasCodec.decodePaintBatch(
          h.channel.sent.single.payload,
        )!;
        for (var i = 0; i < 5; i++) {
          expect(decoded.ops[i].opSeq, i);
        }
      } finally {
        await h.db.close();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Scope and routing
  // ---------------------------------------------------------------------------

  group('drain scope and routing', () {
    test('Local Device Canvas pending rows are never sent', () async {
      final h = await _buildHarness();
      try {
        final local = await h.repo.getOrCreateLocalCanvas();

        // Force-insert a stray pending_op row against the local canvas
        // (paintLocal never enqueues; we simulate corruption to exercise
        // the defensive cleanup path).
        await h.db.database.insert(CanvasTables.pendingOp, {
          'canvas_id': local.localId,
          'x': 1,
          'y': 1,
          'color': 1,
          'op_ts': 1000,
          'op_seq': 0,
          'created_at_ms': h.clock.now(),
          'attempts': 0,
          'next_attempt_at_ms': h.clock.now(),
          'state': PendingOpState.queued.storageCode,
          'last_error': null,
        });

        final framesSent = await h.coordinator.drain();
        expect(framesSent, 0);
        expect(h.channel.sent, isEmpty);

        // Defensive cleanup deleted the orphan row.
        final remaining = await h.repo.getPendingOpsForCanvas(local.localId);
        expect(remaining, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test('different canvases produce separate frames', () async {
      final h = await _buildHarness();
      try {
        final a = await _mkMeshCanvas(
          h.repo,
          canvasId: 0xAAA,
          channelIndex: 0,
          name: 'A',
        );
        final b = await _mkMeshCanvas(
          h.repo,
          canvasId: 0xBBB,
          channelIndex: 0,
          name: 'B',
        );

        await h.repo.enqueuePaint(
          canvasLocalId: a.localId,
          x: 0,
          y: 0,
          color: 0,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
          createdAtMsOverride: 100,
        );
        await h.repo.enqueuePaint(
          canvasLocalId: b.localId,
          x: 1,
          y: 1,
          color: 1,
          authorNodeNum: 0x100,
          opTs: 1001,
          opSeq: 0,
          createdAtMsOverride: 101,
        );

        final framesSent = await h.coordinator.drain();
        expect(framesSent, 2);
        final firstDecoded = CanvasCodec.decodePaintBatch(
          h.channel.sent[0].payload,
        )!;
        final secondDecoded = CanvasCodec.decodePaintBatch(
          h.channel.sent[1].payload,
        )!;
        // Older `created_at_ms` is drained first.
        expect(firstDecoded.canvasId, 0xAAA);
        expect(secondDecoded.canvasId, 0xBBB);
      } finally {
        await h.db.close();
      }
    });

    test('different channel indexes produce separate sends', () async {
      final h = await _buildHarness();
      try {
        final a = await _mkMeshCanvas(h.repo, canvasId: 0xAAA, channelIndex: 1);
        final b = await _mkMeshCanvas(h.repo, canvasId: 0xBBB, channelIndex: 3);
        await h.repo.enqueuePaint(
          canvasLocalId: a.localId,
          x: 0,
          y: 0,
          color: 0,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
          createdAtMsOverride: 100,
        );
        await h.repo.enqueuePaint(
          canvasLocalId: b.localId,
          x: 0,
          y: 0,
          color: 0,
          authorNodeNum: 0x100,
          opTs: 1001,
          opSeq: 0,
          createdAtMsOverride: 101,
        );
        await h.coordinator.drain();
        expect(h.channel.sent.map((s) => s.channelIndex), [1, 3]);
      } finally {
        await h.db.close();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Gates and backoff
  // ---------------------------------------------------------------------------

  group('drain gates', () {
    test(
      'canvas governor denial leaves rows queued and schedules retry',
      () async {
        final h = await _buildHarness();
        try {
          final mesh = await _mkMeshCanvas(h.repo);
          await h.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: 0,
            y: 0,
            color: 0,
            authorNodeNum: 0x100,
            opTs: 1000,
            opSeq: 0,
            createdAtMsOverride: h.clock.now(),
          );

          // Saturate the governor so no payload of any size can fit.
          h.governor.recordSend(CanvasOutboundGovernor.budgetBytes);

          final framesSent = await h.coordinator.drain();
          expect(framesSent, 0);
          expect(h.channel.sent, isEmpty);

          final row = (await h.repo.getPendingOpsForCanvas(
            mesh.localId,
          )).single;
          expect(row.state, PendingOpState.queued);
          expect(row.attempts, 0);
          expect(
            row.nextAttemptAtMs,
            h.clock.now() + CanvasSendCoordinator.debugGovernorBackoffMs,
          );
        } finally {
          await h.db.close();
        }
      },
    );

    test(
      'SIP denial leaves rows queued, does not burn canvas budget',
      () async {
        final h = await _buildHarness();
        try {
          final mesh = await _mkMeshCanvas(h.repo);
          await h.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: 0,
            y: 0,
            color: 0,
            authorNodeNum: 0x100,
            opTs: 1000,
            opSeq: 0,
            createdAtMsOverride: h.clock.now(),
          );
          h.channel.enqueueOutcome(CanvasSendResult.sipRateLimited);

          final framesSent = await h.coordinator.drain();
          expect(framesSent, 0);
          expect(h.channel.sent, hasLength(1)); // attempt was made

          // Canvas budget was NOT charged.
          expect(h.governor.remainingBytes, CanvasOutboundGovernor.budgetBytes);

          // Row is back to queued (not inFlight), attempts unchanged.
          final row = (await h.repo.getPendingOpsForCanvas(
            mesh.localId,
          )).single;
          expect(row.state, PendingOpState.queued);
          expect(row.attempts, 0);
          expect(
            row.nextAttemptAtMs,
            h.clock.now() + CanvasSendCoordinator.debugSipBackoffMs,
          );
        } finally {
          await h.db.close();
        }
      },
    );

    test(
      'transient failure marks attempts and applies the backoff schedule',
      () async {
        final h = await _buildHarness();
        try {
          final mesh = await _mkMeshCanvas(h.repo);
          await h.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: 0,
            y: 0,
            color: 0,
            authorNodeNum: 0x100,
            opTs: 1000,
            opSeq: 0,
            createdAtMsOverride: h.clock.now(),
          );
          h.channel.enqueueOutcome(
            CanvasSendResult.failure(
              'transport-down',
            ), // lint-allow: hardcoded-string
          );

          final framesSent = await h.coordinator.drain();
          expect(framesSent, 0);

          // First-failure attempt counter = 1, backoff = 1 s.
          final row = (await h.repo.getPendingOpsForCanvas(
            mesh.localId,
          )).single;
          expect(row.attempts, 1);
          expect(row.state, PendingOpState.queued);
          expect(row.lastError, 'transport-down');
          expect(
            row.nextAttemptAtMs,
            h.clock.now() + CanvasSendCoordinator.debugBackoffMsForAttempts(0),
          );
          expect(CanvasSendCoordinator.debugBackoffMsForAttempts(0), 1000);

          // Canvas governor still untouched.
          expect(h.governor.remainingBytes, CanvasOutboundGovernor.budgetBytes);
        } finally {
          await h.db.close();
        }
      },
    );

    test('backoff schedule matches 1s / 2s / 5s / 10s / 60s', () {
      expect(CanvasSendCoordinator.debugBackoffMsForAttempts(0), 1000);
      expect(CanvasSendCoordinator.debugBackoffMsForAttempts(1), 2000);
      expect(CanvasSendCoordinator.debugBackoffMsForAttempts(2), 5000);
      expect(CanvasSendCoordinator.debugBackoffMsForAttempts(3), 10000);
      expect(CanvasSendCoordinator.debugBackoffMsForAttempts(4), 60000);
      expect(CanvasSendCoordinator.debugBackoffMsForAttempts(99), 60000);
    });
  });

  // ---------------------------------------------------------------------------
  // Idempotency / state hygiene
  // ---------------------------------------------------------------------------

  group('drain idempotency', () {
    test('successful send deletes pending rows', () async {
      final h = await _buildHarness();
      try {
        final mesh = await _mkMeshCanvas(h.repo);
        await _enqueueRange(
          repo: h.repo,
          canvasLocalId: mesh.localId,
          count: 3,
          authorNodeNum: 0x100,
          baseOpTs: 1000,
          baseCreatedAtMs: h.clock.now(),
        );
        await h.coordinator.drain();
        expect(await h.repo.getPendingOpsForCanvas(mesh.localId), isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test('repeated drain does not resend in-flight rows', () async {
      // Mark rows in-flight by setting up a SIP-rate-limit outcome:
      // the rows move to inFlight before send, then come back to
      // queued under a backoff. Verify a second drain at the SAME
      // wall-clock time doesn't re-pick them.
      final h = await _buildHarness();
      try {
        final mesh = await _mkMeshCanvas(h.repo);
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 0,
          y: 0,
          color: 0,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
          createdAtMsOverride: h.clock.now(),
        );
        h.channel.enqueueOutcome(CanvasSendResult.sipRateLimited);
        await h.coordinator.drain();
        expect(h.channel.sent, hasLength(1));

        // Drain again immediately — next_attempt_at_ms is in the
        // future, so getQueuedReadyOps returns an empty set.
        final framesSent = await h.coordinator.drain();
        expect(framesSent, 0);
        expect(h.channel.sent, hasLength(1));

        // Advance past the SIP backoff and the row becomes ready
        // again.
        h.clock.advance(
          Duration(milliseconds: CanvasSendCoordinator.debugSipBackoffMs + 1),
        );
        await h.coordinator.drain();
        expect(h.channel.sent, hasLength(2));
      } finally {
        await h.db.close();
      }
    });

    test('drain returns 0 when local node num is unknown', () async {
      final h = await _buildHarness(nodeNumOverride: () => null);
      try {
        final mesh = await _mkMeshCanvas(h.repo);
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 0,
          y: 0,
          color: 0,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
        );
        final framesSent = await h.coordinator.drain();
        expect(framesSent, 0);
        expect(h.channel.sent, isEmpty);
        // Row stays queued exactly as it was.
        final row = (await h.repo.getPendingOpsForCanvas(mesh.localId)).single;
        expect(row.state, PendingOpState.queued);
      } finally {
        await h.db.close();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Wire-level assertion: encoded payload decodes as canvas.v1 paint_batch
  // ---------------------------------------------------------------------------

  group('wire-level encoding', () {
    test('captured payload decodes round-trip via CanvasCodec', () async {
      final h = await _buildHarness(localNodeNum: 0xABCDEF01);
      try {
        final mesh = await _mkMeshCanvas(
          h.repo,
          canvasId: 0xDEAD_BEEF_CAFE_BABE,
          channelIndex: 4,
        );
        // Three ops with non-zero ts_offsets so we can confirm
        // batch_ts anchoring works.
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 1,
          y: 2,
          color: 3,
          authorNodeNum: 0xABCDEF01,
          opTs: 5_000,
          opSeq: 1,
          createdAtMsOverride: 100,
        );
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 4,
          y: 5,
          color: 6,
          authorNodeNum: 0xABCDEF01,
          opTs: 5_002,
          opSeq: 2,
          createdAtMsOverride: 101,
        );
        await h.repo.enqueuePaint(
          canvasLocalId: mesh.localId,
          x: 7,
          y: 8,
          color: 9,
          authorNodeNum: 0xABCDEF01,
          opTs: 5_010,
          opSeq: 3,
          createdAtMsOverride: 102,
        );

        await h.coordinator.drain();
        expect(h.channel.sent, hasLength(1));

        // sniffAction confirms the magic / version / op_type match.
        final captured = h.channel.sent.single.payload;
        expect(CanvasCodec.sniffAction(captured), CanvasAction.paintBatch);

        final decoded = CanvasCodec.decodePaintBatch(captured)!;
        expect(decoded.canvasId, 0xDEAD_BEEF_CAFE_BABE);
        expect(decoded.authorId, 0xABCDEF01);
        expect(decoded.batchTs, 5_000);
        expect(decoded.ops, hasLength(3));
        expect(decoded.ops[0].opSeq, 1);
        expect(decoded.ops[0].tsOffset, 0);
        expect(decoded.ops[1].tsOffset, 2);
        expect(decoded.ops[2].tsOffset, 10);
      } finally {
        await h.db.close();
      }
    });
  });
}
