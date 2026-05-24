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
import 'package:socialmesh/services/canvas/canvas_inbound_limiter.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';
import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';
import 'package:socialmesh/services/canvas/mrrp_service_canvas.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath(String label) {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_s5_${label}_${_testPid}_${_testDbSeq++}.db');
}

class _FakeClock {
  int _ms;
  _FakeClock(this._ms);
  int now() => _ms;
  void advance(Duration d) {
    _ms += d.inMilliseconds;
  }
}

Future<
  ({
    CanvasDatabase db,
    CanvasRepository repo,
    _FakeClock clock,
    MrrpServiceCanvas handler,
  })
>
_buildHandler({String label = 'handler'}) async {
  final db = CanvasDatabase(testDbPath: _uniqueTestDbPath(label));
  await db.init();
  final repo = CanvasRepository(db);
  // Pick a fixed clock that places "now" comfortably inside u32 unix
  // seconds AND far enough away from sentinel values to exercise the
  // replay window naturally.
  final clock = _FakeClock(DateTime(2026, 6, 1).millisecondsSinceEpoch);
  final handler = MrrpServiceCanvas(repository: repo, nowMs: clock.now);
  return (db: db, repo: repo, clock: clock, handler: handler);
}

int _nowSec(_FakeClock c) => c.now() ~/ 1000;

Uint8List _paint({
  required int canvasId,
  required int x,
  required int y,
  required int color,
  required int author,
  required int opTs,
  required int opSeq,
}) {
  return CanvasCodec.encodePaint(
    CanvasPaintOp(
      canvasId: canvasId,
      x: x,
      y: y,
      color: color,
      authorId: author,
      opTs: opTs,
      opSeq: opSeq,
    ),
  )!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ---------------------------------------------------------------------------
  // Registration / routing
  // ---------------------------------------------------------------------------

  group('service registration', () {
    test('registry routes canvas.v1 payload to MrrpServiceCanvas', () async {
      final h = await _buildHandler(label: 'reg');
      try {
        final registry = MrrpServiceRegistry();
        final ok = registry.register(
          h.handler,
          MrrpServiceDescriptor(
            serviceId: MrrpServiceId.canvasV1,
            serviceType: MrrpServiceType.app,
          ),
        );
        expect(ok, isTrue);

        final lookup = registry.getHandler(MrrpServiceId.canvasV1);
        expect(lookup, same(h.handler));

        // Other service IDs are NOT routed here.
        expect(registry.getHandler(MrrpServiceId.boardV1), isNull);
        expect(registry.getHandler(MrrpServiceId.petV1), isNull);
      } finally {
        await h.db.close();
      }
    });

    test(
      'handler claims service id 0x00000007 and the seven v0.1 actions',
      () async {
        final h = await _buildHandler(label: 'actions');
        try {
          expect(h.handler.serviceId, 0x00000007);
          expect(h.handler.supportedActions, <int>{
            0x0001,
            0x0002,
            0x0003,
            0x0004,
            0x0005,
            0x0006,
            0x0007,
          });
        } finally {
          await h.db.close();
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // paint apply
  // ---------------------------------------------------------------------------

  group('inbound paint apply', () {
    test('valid paint creates mesh canvas and mutates cell', () async {
      final h = await _buildHandler(label: 'paint');
      try {
        final report = await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0xAABBCCDDEEFF0011,
            x: 5,
            y: 7,
            color: 12,
            author: 0xDEADBEEF,
            opTs: _nowSec(h.clock),
            opSeq: 1,
          ),
          senderNodeId: 0x100,
          channelIndex: 3,
        );
        expect(report.outcome, CanvasInboundOutcome.applied);
        expect(report.appliedCount, 1);

        // Canvas was auto-created bound to channel 3.
        final canvases = await h.repo.listCanvases(scope: CanvasScope.mesh);
        expect(canvases, hasLength(1));
        expect(canvases.single.canvasId, 0xAABBCCDDEEFF0011);
        expect(canvases.single.channelIndex, 3);
        expect(canvases.single.name, 'Canvas 3');

        final cells = await h.repo.getCanvasCells(canvases.single.localId);
        expect(cells.single.x, 5);
        expect(cells.single.y, 7);
        expect(cells.single.color, 12);
      } finally {
        await h.db.close();
      }
    });

    test('valid paint_batch applies multiple cells', () async {
      final h = await _buildHandler(label: 'batch');
      try {
        final encoded = CanvasCodec.encodePaintBatch(
          CanvasPaintBatchOp(
            canvasId: 0xC0DE,
            authorId: 0xAA,
            batchTs: _nowSec(h.clock),
            batchSeq: 0,
            ops: const [
              CanvasBatchedPaintRecord(
                x: 1,
                y: 1,
                color: 1,
                tsOffset: 0,
                opSeq: 1,
              ),
              CanvasBatchedPaintRecord(
                x: 2,
                y: 2,
                color: 2,
                tsOffset: 0,
                opSeq: 2,
              ),
              CanvasBatchedPaintRecord(
                x: 3,
                y: 3,
                color: 3,
                tsOffset: 0,
                opSeq: 3,
              ),
            ],
          ),
        )!;
        final report = await h.handler.applyInbound(
          canvasPayload: encoded,
          senderNodeId: 0x200,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.applied);
        expect(report.appliedCount, 3);

        final canvas = (await h.repo.listCanvases(
          scope: CanvasScope.mesh,
        )).single;
        final cells = await h.repo.getCanvasCells(canvas.localId);
        expect(cells, hasLength(3));
      } finally {
        await h.db.close();
      }
    });

    test('older op recorded rejected; cell unchanged', () async {
      final h = await _buildHandler(label: 'lww');
      try {
        // First paint at op_ts=now.
        await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0x99,
            x: 0,
            y: 0,
            color: 5,
            author: 1,
            opTs: _nowSec(h.clock),
            opSeq: 1,
          ),
          senderNodeId: 0x10,
          channelIndex: 0,
        );

        // Older paint at op_ts=now-100 (still inside replay window, but
        // older than the existing cell timestamp). Should be recorded
        // as applied_op with was_accepted=0 and the cell should stay
        // color=5.
        final stale = await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0x99,
            x: 0,
            y: 0,
            color: 9,
            author: 1,
            opTs: _nowSec(h.clock) - 100,
            opSeq: 2,
          ),
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(stale.outcome, CanvasInboundOutcome.acceptedNoOp);
        expect(stale.appliedCount, 0);
        expect(stale.unappliedByRepositoryCount, 1);

        final canvas = (await h.repo.listCanvases(
          scope: CanvasScope.mesh,
        )).single;
        final cells = await h.repo.getCanvasCells(canvas.localId);
        expect(cells.single.color, 5);

        final applied = await h.repo.getRecentAppliedOps(canvas.localId);
        expect(applied, hasLength(2));
        // Newer op accepted, older op rejected.
        expect(applied.any((o) => o.wasAccepted && o.color == 5), isTrue);
        expect(applied.any((o) => !o.wasAccepted && o.color == 9), isTrue);
      } finally {
        await h.db.close();
      }
    });

    test('duplicate 6-field op is skipped (no extra applied_op row)', () async {
      final h = await _buildHandler(label: 'dup');
      try {
        final payload = _paint(
          canvasId: 0xD0,
          x: 4,
          y: 4,
          color: 8,
          author: 0xAA,
          opTs: _nowSec(h.clock),
          opSeq: 7,
        );

        final first = await h.handler.applyInbound(
          canvasPayload: payload,
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(first.appliedCount, 1);

        final second = await h.handler.applyInbound(
          canvasPayload: payload,
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(second.appliedCount, 0);
        expect(second.unappliedByRepositoryCount, 1);

        // The 6-field dedupe prevented a second applied_op row.
        final canvas = (await h.repo.listCanvases(
          scope: CanvasScope.mesh,
        )).single;
        final applied = await h.repo.getRecentAppliedOps(canvas.localId);
        expect(applied, hasLength(1));
      } finally {
        await h.db.close();
      }
    });

    test(
      'same author + same op_seq + different op_ts is NOT a duplicate',
      () async {
        final h = await _buildHandler(label: 'no-dup-on-ts');
        try {
          await h.handler.applyInbound(
            canvasPayload: _paint(
              canvasId: 0xE0,
              x: 1,
              y: 1,
              color: 1,
              author: 0xAA,
              opTs: _nowSec(h.clock) - 10,
              opSeq: 5,
            ),
            senderNodeId: 0x10,
            channelIndex: 0,
          );
          final second = await h.handler.applyInbound(
            canvasPayload: _paint(
              canvasId: 0xE0,
              x: 1,
              y: 1,
              color: 2,
              author: 0xAA,
              opTs: _nowSec(h.clock),
              opSeq: 5, // same seq, different ts
            ),
            senderNodeId: 0x10,
            channelIndex: 0,
          );
          expect(second.outcome, CanvasInboundOutcome.applied);

          final canvas = (await h.repo.listCanvases(
            scope: CanvasScope.mesh,
          )).single;
          final applied = await h.repo.getRecentAppliedOps(canvas.localId);
          expect(applied, hasLength(2));
          final cells = await h.repo.getCanvasCells(canvas.localId);
          expect(cells.single.color, 2);
        } finally {
          await h.db.close();
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Replay window
  // ---------------------------------------------------------------------------

  group('replay window', () {
    test('op > now + 5 minutes is rejected; cell unchanged', () async {
      final h = await _buildHandler(label: 'future');
      try {
        final farFuture =
            _nowSec(h.clock) + kCanvasReplayFutureThreshold.inSeconds + 10;
        final report = await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0xF0,
            x: 0,
            y: 0,
            color: 9,
            author: 1,
            opTs: farFuture,
            opSeq: 0,
          ),
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.staleReplayWindow);
        expect(report.appliedCount, 0);
        expect(report.replayWindowRejectedCount, 1);

        final canvas = (await h.repo.listCanvases(
          scope: CanvasScope.mesh,
        )).single;
        final cells = await h.repo.getCanvasCells(canvas.localId);
        expect(cells, isEmpty);
      } finally {
        await h.db.close();
      }
    });

    test('op < now - 7 days is rejected; cell unchanged', () async {
      final h = await _buildHandler(label: 'ancient');
      try {
        final ancient =
            _nowSec(h.clock) - kCanvasReplayOldThreshold.inSeconds - 10;
        final report = await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0xF1,
            x: 0,
            y: 0,
            color: 9,
            author: 1,
            opTs: ancient,
            opSeq: 0,
          ),
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.staleReplayWindow);
        expect(report.replayWindowRejectedCount, 1);
      } finally {
        await h.db.close();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Decoder robustness
  // ---------------------------------------------------------------------------

  group('decoder robustness', () {
    test('malformed payload is dropped without crash', () async {
      final h = await _buildHandler(label: 'bad');
      try {
        final report = await h.handler.applyInbound(
          canvasPayload: Uint8List.fromList([0xAB, 0xCD, 0x00]),
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.decodeFailed);
      } finally {
        await h.db.close();
      }
    });

    test('truncated paint payload is dropped without crash', () async {
      final h = await _buildHandler(label: 'truncated');
      try {
        final full = _paint(
          canvasId: 1,
          x: 0,
          y: 0,
          color: 0,
          author: 1,
          opTs: _nowSec(h.clock),
          opSeq: 0,
        );
        // Truncate to common-prefix only — sniffer matches but
        // decodePaint will reject the length.
        final truncated = Uint8List.fromList(full.sublist(0, 12));
        final report = await h.handler.applyInbound(
          canvasPayload: truncated,
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(report.outcome, CanvasInboundOutcome.decodeFailed);
      } finally {
        await h.db.close();
      }
    });

    test('unsupported v0.1 actions (digest/sync/info) no-op safely', () async {
      final h = await _buildHandler(label: 'noop');
      try {
        final digestPayload = CanvasCodec.encodeCanvasDigest(
          CanvasDigestOp(
            canvasId: 0xAA,
            globalDigest: Uint8List(16),
            cellCount: 0,
            tileDigests: Uint8List(CanvasDigestSizes.tilesConcatenatedBytes),
          ),
        )!;
        final syncReqPayload = CanvasCodec.encodeSyncRequest(
          const CanvasSyncRequestOp(canvasId: 0xAA, tileX: 0, tileY: 0),
        )!;
        final infoReqPayload = CanvasCodec.encodeCanvasInfoRequest(
          const CanvasInfoRequest(canvasId: 0xAA),
        )!;

        for (final payload in [digestPayload, syncReqPayload, infoReqPayload]) {
          final report = await h.handler.applyInbound(
            canvasPayload: payload,
            senderNodeId: 0x10,
            channelIndex: 0,
          );
          expect(report.outcome, CanvasInboundOutcome.acceptedNoOp);
        }

        // None of the no-op actions touched canvas state.
        final canvases = await h.repo.listCanvases(scope: CanvasScope.mesh);
        expect(canvases, isEmpty);
      } finally {
        await h.db.close();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Decoder-side per-sender inbound rate limit (12 / 60 s)
  // ---------------------------------------------------------------------------

  group('inbound rate limit (canvas-private 12/60s)', () {
    test('13th frame within 60 s is dropped; recovers after window', () async {
      final h = await _buildHandler(label: 'cap');
      try {
        // Send 12 valid paints. Use distinct cells + op_seqs so each
        // is a unique op and the repository accepts all of them.
        for (var i = 0; i < 12; i++) {
          final report = await h.handler.applyInbound(
            canvasPayload: _paint(
              canvasId: 0xCAFE,
              x: i,
              y: 0,
              color: i % 64,
              author: 1,
              opTs: _nowSec(h.clock),
              opSeq: i & 0xFF,
            ),
            senderNodeId: 0x10,
            channelIndex: 0,
          );
          expect(report.outcome, CanvasInboundOutcome.applied);
        }

        // 13th MUST be dropped.
        final dropped = await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0xCAFE,
            x: 12,
            y: 0,
            color: 12,
            author: 1,
            opTs: _nowSec(h.clock),
            opSeq: 12,
          ),
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(dropped.outcome, CanvasInboundOutcome.rateLimited);

        // Advance past the window — same sender can paint again.
        h.clock.advance(
          CanvasInboundLimiter.defaultWindow + const Duration(seconds: 1),
        );
        final recovered = await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0xCAFE,
            x: 13,
            y: 0,
            color: 13,
            author: 1,
            opTs: _nowSec(h.clock),
            opSeq: 13,
          ),
          senderNodeId: 0x10,
          channelIndex: 0,
        );
        expect(recovered.outcome, CanvasInboundOutcome.applied);
      } finally {
        await h.db.close();
      }
    });

    test('one sender hitting cap does not affect a different sender', () async {
      final h = await _buildHandler(label: 'cap-isolated');
      try {
        for (var i = 0; i < 13; i++) {
          await h.handler.applyInbound(
            canvasPayload: _paint(
              canvasId: 0xAB,
              x: i,
              y: 0,
              color: i % 64,
              author: 1,
              opTs: _nowSec(h.clock),
              opSeq: i & 0xFF,
            ),
            senderNodeId: 0x10,
            channelIndex: 0,
          );
        }

        // A different sender's first frame is still accepted.
        final other = await h.handler.applyInbound(
          canvasPayload: _paint(
            canvasId: 0xAB,
            x: 50,
            y: 0,
            color: 5,
            author: 2,
            opTs: _nowSec(h.clock),
            opSeq: 0,
          ),
          senderNodeId: 0x20,
          channelIndex: 0,
        );
        expect(other.outcome, CanvasInboundOutcome.applied);
      } finally {
        await h.db.close();
      }
    });

    test(
      'global MrrpConstants.mrrpMaxInboundRequestsPerSenderPer60s unchanged',
      () {
        // Regression pin: the canvas-private cap is on top of the global
        // default. Lowering or raising the global cap is a separate
        // protocol-wide decision.
        expect(MrrpConstants.mrrpMaxInboundRequestsPerSenderPer60s, 4);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Dispatcher path: channelIndex unknown -> drop
  // ---------------------------------------------------------------------------

  group('dispatcher path (no channel context)', () {
    test(
      'applyInbound with kCanvasChannelIndexUnknown drops with no apply',
      () async {
        final h = await _buildHandler(label: 'dispatcher');
        try {
          final report = await h.handler.applyInbound(
            canvasPayload: _paint(
              canvasId: 1,
              x: 0,
              y: 0,
              color: 0,
              author: 1,
              opTs: _nowSec(h.clock),
              opSeq: 0,
            ),
            senderNodeId: 0x10,
            channelIndex: kCanvasChannelIndexUnknown,
          );
          expect(report.outcome, CanvasInboundOutcome.noChannelContext);
          expect(await h.repo.listCanvases(scope: CanvasScope.mesh), isEmpty);
        } finally {
          await h.db.close();
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // S4 -> S5 round trip
  // ---------------------------------------------------------------------------

  group('S4 -> S5 round trip', () {
    test(
      'CanvasSendCoordinator output decodes and applies via MrrpServiceCanvas',
      () async {
        // Sender side
        final tx = await _buildHandler(label: 'tx');
        try {
          final mesh = await tx.repo.getOrCreateMeshCanvas(
            canvasId: 0xDEADBEEFCAFE0001,
            channelIndex: 2,
            name: 'Round-trip',
          );
          await tx.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: 7,
            y: 11,
            color: 17,
            authorNodeNum: 0xAAAA,
            opTs: _nowSec(tx.clock),
            opSeq: 1,
            createdAtMsOverride: 100,
          );
          await tx.repo.enqueuePaint(
            canvasLocalId: mesh.localId,
            x: 8,
            y: 12,
            color: 18,
            authorNodeNum: 0xAAAA,
            opTs: _nowSec(tx.clock),
            opSeq: 2,
            createdAtMsOverride: 100,
          );

          final governor = CanvasOutboundGovernor(nowMs: tx.clock.now);
          final captured = <_Sent>[];
          final coordinator = CanvasSendCoordinator(
            repository: tx.repo,
            governor: governor,
            outbound: _CapturingChannel(captured),
            localNodeNumProvider: () => 0xAAAA,
            nowMs: tx.clock.now,
          );

          final framesSent = await coordinator.drain();
          expect(framesSent, 1);
          expect(captured, hasLength(1));

          // Receiver side (separate DB) replays the captured payload
          // through MrrpServiceCanvas with the matching channelIndex.
          final rx = await _buildHandler(label: 'rx');
          try {
            // Align clocks so the replay-window check sees a valid op_ts.
            rx.clock._ms = tx.clock.now();
            final report = await rx.handler.applyInbound(
              canvasPayload: captured.single.payload,
              senderNodeId: 0xAAAA,
              channelIndex: captured.single.channelIndex,
            );
            expect(report.outcome, CanvasInboundOutcome.applied);
            expect(report.appliedCount, 2);

            final rxCanvas = (await rx.repo.listCanvases(
              scope: CanvasScope.mesh,
            )).single;
            expect(rxCanvas.canvasId, 0xDEADBEEFCAFE0001);
            expect(rxCanvas.channelIndex, 2);
            final rxCells = await rx.repo.getCanvasCells(rxCanvas.localId);
            expect(rxCells, hasLength(2));
            expect(rxCells.map((c) => (c.x, c.y, c.color)).toSet(), {
              (7, 11, 17),
              (8, 12, 18),
            });
          } finally {
            await rx.db.close();
          }
        } finally {
          await tx.db.close();
        }
      },
    );
  });
}

class _Sent {
  final Uint8List payload;
  final int channelIndex;
  const _Sent({required this.payload, required this.channelIndex});
}

class _CapturingChannel implements CanvasOutboundChannel {
  final List<_Sent> _sink;
  _CapturingChannel(this._sink);

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    _sink.add(_Sent(payload: canvasPayload, channelIndex: channelIndex));
    return CanvasSendResult.sent(wireBytes: canvasPayload.length + 22);
  }
}
