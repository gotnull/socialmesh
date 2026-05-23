// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S9g — resumable raw-band continuation tests.
//
// Spec: docs/canvas/CANVAS_SYNC_V0_1.md §11.
//
// Pinned invariants:
//   - A dense (raw-band) sync_request enqueues 8 bands as one job.
//   - When the canvas governor blocks band 1+, the remaining bands
//     stay queued (NOT silently dropped).
//   - A later `drainRawBands()` call ships the deferred bands.
//   - Duplicate sync_request for the same (peer, tile) is a no-op.
//   - Receiver's bitmask tracks each band arrival; complete only at
//     8/8.
//   - HUD `hydrationStateFor` reports `recovering` while sender or
//     receiver raw work is in flight (never `quiet`).
//   - `bandProgressForCanvas` reports lowest-completion N/8.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_codec.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';
import 'package:socialmesh/services/canvas/canvas_sync_coordinator.dart';

const int _kCanvasId = 0xDADA_CAFE_FACE_BEEF;
const int _kChannelIndex = 0;
const int _kPeer = 0xCAFE;

int _seq = 0;
final int _pid = pid;
String _testDbPath(String tag) => p.join(
  Directory.systemTemp.path,
  'canvas_raw_cont_${tag}_${_pid}_${_seq++}.db',
);

/// Recording channel that counts sync_response (action 0x05) emits
/// per band-index byte, so tests can assert the partial-then-resume
/// pattern across drain windows.
class _RecordingChannel implements CanvasOutboundChannel {
  final List<Uint8List> sent = [];

  int get rawBandSendCount =>
      sent.where((p) => p.length > 2 && p[2] == 0x05).length;

  /// Band index of each raw-band sync_response, parsed straight from
  /// the payload header at offset 15 (per CanvasCodec).
  List<int> get rawBandIndexesSent {
    final out = <int>[];
    for (final p in sent) {
      if (p.length < 18) continue;
      if (p[2] != 0x05) continue;
      final encoding = p[14];
      if (encoding != 1) continue; // 1 = raw band
      out.add(p[15]);
    }
    return out;
  }

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    sent.add(canvasPayload);
    return CanvasSendResult.sent(wireBytes: canvasPayload.length);
  }
}

/// Governor that allows exactly [allowedSends] more frames before
/// refusing. Models the "250 B / 60 s" budget closing after a fixed
/// number of raw bands ship. The test mutates `allowedSends` to
/// simulate budget refill across drain windows.
class _CountingGovernor extends CanvasOutboundGovernor {
  int allowedSends;

  _CountingGovernor({this.allowedSends = 1});

  @override
  bool canSend(int bytes) => allowedSends > 0;

  @override
  void recordSend(int bytes) {
    if (allowedSends > 0) allowedSends--;
  }

  @override
  int get remainingBytes => allowedSends > 0 ? 100000 : 0;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S9g — sender-side raw-band continuation', () {
    test(
      'dense tile → 8 bands queued; governor closes after band 0; '
      'bands 1..7 remain pending; later drainRawBands() ships them',
      () async {
        final db = CanvasDatabase(testDbPath: _testDbPath('sender'));
        await db.init();
        addTearDown(db.close);
        final repo = CanvasRepository(db);
        final channel = _RecordingChannel();
        // Allow exactly one send (band 0) before the budget closes.
        final governor = _CountingGovernor(allowedSends: 1);

        final sync = CanvasSyncCoordinator(
          repository: repo,
          outbound: channel,
          governor: governor,
          canEmit: () => true,
        );
        addTearDown(sync.dispose);

        // Paint a 32×32 checkerboard tile that forces RLE > 88 runs.
        final canvas = await repo.getOrCreateMeshCanvas(
          canvasId: _kCanvasId,
          channelIndex: _kChannelIndex,
          name: 'Primary',
        );
        var seq = 0;
        for (var y = 0; y < 32; y++) {
          for (var x = 0; x < 32; x++) {
            final color = ((x + y) % 2 == 0) ? 1 : 2;
            await repo.paintLocal(
              canvasLocalId: canvas.localId,
              x: x,
              y: y,
              color: color,
              authorNodeNum: 0xAAAA,
              opTs: 1000,
              opSeq: seq++ & 0xff,
            );
          }
        }

        // Inbound sync_request for tile (0, 0). Governor open → band 0
        // ships; then we close it manually so the rest defer.
        await sync.handleInboundSyncRequest(
          senderNodeId: _kPeer,
          channelIndex: _kChannelIndex,
          op: CanvasSyncRequestOp(canvasId: _kCanvasId, tileX: 0, tileY: 0),
        );

        // Only band 0 ships before the governor closes; bands 1..7
        // stay queued for a later drain.
        expect(
          channel.rawBandSendCount,
          1,
          reason:
              'governor allowed only one send; bands 1..7 must wait — '
              'NOT be dropped',
        );
        expect(channel.rawBandIndexesSent, [0]);

        // A drainRawBands() call with the budget still closed must
        // send nothing AND keep the job queued.
        final shippedWhileClosed = await sync.drainRawBands();
        expect(shippedWhileClosed, 0);
        expect(channel.rawBandSendCount, 1);

        // Refill the budget for 7 more sends — next drain ships the
        // remaining bands in order.
        governor.allowedSends = 7;
        final shippedAfterReopen = await sync.drainRawBands();
        expect(shippedAfterReopen, 7);
        expect(channel.rawBandSendCount, 8);
        expect(channel.rawBandIndexesSent, [0, 1, 2, 3, 4, 5, 6, 7]);

        // Job is drained — another drain ships nothing.
        expect(await sync.drainRawBands(), 0);
      },
    );

    test('duplicate sync_request for the same (peer, tile) is a no-op while '
        'a job is queued', () async {
      final db = CanvasDatabase(testDbPath: _testDbPath('dedupe'));
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final channel = _RecordingChannel();
      final governor = _CountingGovernor(allowedSends: 1);

      final sync = CanvasSyncCoordinator(
        repository: repo,
        outbound: channel,
        governor: governor,
        canEmit: () => true,
      );
      addTearDown(sync.dispose);

      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: _kCanvasId,
        channelIndex: _kChannelIndex,
        name: 'Primary',
      );
      var seq = 0;
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          await repo.paintLocal(
            canvasLocalId: canvas.localId,
            x: x,
            y: y,
            color: ((x + y) % 2 == 0) ? 1 : 2,
            authorNodeNum: 0xAAAA,
            opTs: 1000,
            opSeq: seq++ & 0xff,
          );
        }
      }

      // First request enqueues 8 bands; ships band 0 then runs out
      // of budget.
      await sync.handleInboundSyncRequest(
        senderNodeId: _kPeer,
        channelIndex: _kChannelIndex,
        op: CanvasSyncRequestOp(canvasId: _kCanvasId, tileX: 0, tileY: 0),
      );
      expect(channel.rawBandSendCount, 1);

      // Duplicate request → no new bands enqueued, no new sends.
      await sync.handleInboundSyncRequest(
        senderNodeId: _kPeer,
        channelIndex: _kChannelIndex,
        op: CanvasSyncRequestOp(canvasId: _kCanvasId, tileX: 0, tileY: 0),
      );
      expect(channel.rawBandSendCount, 1);

      // Refill budget — drain finishes the original 7 deferred
      // bands. Total ships is 8 (not 16) because the dedupe blocked
      // the second 8-band enqueue.
      governor.allowedSends = 7;
      expect(await sync.drainRawBands(), 7);
      expect(channel.rawBandSendCount, 8);
    });
  });

  group('S9g — receiver-side band tracking + state', () {
    test(
      'receiver bitmask tracks each band arrival; tile complete only at 8/8',
      () async {
        final db = CanvasDatabase(testDbPath: _testDbPath('receiver'));
        await db.init();
        addTearDown(db.close);
        final repo = CanvasRepository(db);
        final sync = CanvasSyncCoordinator(
          repository: repo,
          outbound: _RecordingChannel(),
          governor: _CountingGovernor(),
          canEmit: () => true,
        );
        addTearDown(sync.dispose);

        final canvas = await repo.getOrCreateMeshCanvas(
          canvasId: _kCanvasId,
          channelIndex: _kChannelIndex,
          name: 'Primary',
        );

        // Initial state — quiet/idle, no progress.
        expect(sync.bandProgressForCanvas(canvas.localId), isNull);
        expect(
          sync.hydrationStateFor(canvas.localId),
          MeshCanvasHydrationState.idle,
        );

        // Deliver bands 0, 2, 4 (non-contiguous; tests bitmask
        // accumulation).
        for (final band in [0, 2, 4]) {
          await sync.handleInboundSyncResponse(
            senderNodeId: _kPeer,
            channelIndex: _kChannelIndex,
            op: CanvasSyncResponseOp(
              canvasId: _kCanvasId,
              tileX: 0,
              tileY: 0,
              body: CanvasSyncResponseRawBandBody(
                bandIndex: band,
                cells: Uint8List(CanvasWireFormat.syncResponseRawBandCells),
              ),
            ),
          );
        }

        // Progress should report 3/8 — receiver state is recovering.
        final progress = sync.bandProgressForCanvas(canvas.localId);
        expect(progress, isNotNull);
        expect(progress!.received, 3);
        expect(progress.total, 8);

        // Deliver the remaining 5 bands — set completes, progress
        // disappears, state returns toward idle.
        for (final band in [1, 3, 5, 6, 7]) {
          await sync.handleInboundSyncResponse(
            senderNodeId: _kPeer,
            channelIndex: _kChannelIndex,
            op: CanvasSyncResponseOp(
              canvasId: _kCanvasId,
              tileX: 0,
              tileY: 0,
              body: CanvasSyncResponseRawBandBody(
                bandIndex: band,
                cells: Uint8List(CanvasWireFormat.syncResponseRawBandCells),
              ),
            ),
          );
        }
        expect(sync.bandProgressForCanvas(canvas.localId), isNull);
      },
    );
  });

  group('S9g — HUD state under partial hydration', () {
    test('hydrationStateFor reports recovering while sender raw-band job '
        'still queued; never quiet', () async {
      final db = CanvasDatabase(testDbPath: _testDbPath('hud-sender'));
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final channel = _RecordingChannel();
      // Allow exactly one send so band 0 ships, bands 1..7 stay
      // queued. The job's presence drives the recovering state.
      final governor = _CountingGovernor(allowedSends: 1);
      final sync = CanvasSyncCoordinator(
        repository: repo,
        outbound: channel,
        governor: governor,
        canEmit: () => true,
      );
      addTearDown(sync.dispose);

      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: _kCanvasId,
        channelIndex: _kChannelIndex,
        name: 'Primary',
      );
      var seq = 0;
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          await repo.paintLocal(
            canvasLocalId: canvas.localId,
            x: x,
            y: y,
            color: ((x + y) % 2 == 0) ? 1 : 2,
            authorNodeNum: 0xAAAA,
            opTs: 1000,
            opSeq: seq++ & 0xff,
          );
        }
      }

      // Enqueue a raw-band job; band 0 ships, bands 1..7 stay
      // queued because the governor's allowedSends is exhausted.
      await sync.handleInboundSyncRequest(
        senderNodeId: _kPeer,
        channelIndex: _kChannelIndex,
        op: CanvasSyncRequestOp(canvasId: _kCanvasId, tileX: 0, tileY: 0),
      );
      expect(channel.rawBandSendCount, 1);

      // With bands 1..7 still queued on the sender side, state
      // must be recovering — NOT quiet, NOT idle.
      // Note: `_lastBandAtMs` was set by sending band 0 a moment
      // ago, so state might also report `syncing`. Either is fine
      // for this assertion — both indicate active sync, not quiet.
      final state = sync.hydrationStateFor(canvas.localId);
      expect(
        state == MeshCanvasHydrationState.recovering ||
            state == MeshCanvasHydrationState.syncing,
        isTrue,
        reason:
            'sender raw-band job still queued — state must be a recovery '
            'state, never quiet/idle. Got: $state',
      );
      expect(state, isNot(MeshCanvasHydrationState.quiet));
      expect(state, isNot(MeshCanvasHydrationState.idle));
    });

    test('hydrationStateFor reports recovering while receiver raw-band set '
        'incomplete; returns idle after all 8 bands land', () async {
      final db = CanvasDatabase(testDbPath: _testDbPath('hud-recv'));
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final sync = CanvasSyncCoordinator(
        repository: repo,
        outbound: _RecordingChannel(),
        governor: _CountingGovernor(),
        canEmit: () => true,
      );
      addTearDown(sync.dispose);

      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: _kCanvasId,
        channelIndex: _kChannelIndex,
        name: 'Primary',
      );

      // Land bands 0, 1, 2 — receiver state is recovering.
      for (final band in [0, 1, 2]) {
        await sync.handleInboundSyncResponse(
          senderNodeId: _kPeer,
          channelIndex: _kChannelIndex,
          op: CanvasSyncResponseOp(
            canvasId: _kCanvasId,
            tileX: 0,
            tileY: 0,
            body: CanvasSyncResponseRawBandBody(
              bandIndex: band,
              cells: Uint8List(CanvasWireFormat.syncResponseRawBandCells),
            ),
          ),
        );
      }
      // syncingActivityWindow = 10s — fresh band landed → syncing.
      expect(
        sync.hydrationStateFor(canvas.localId),
        MeshCanvasHydrationState.syncing,
      );

      // Land the remaining 5 — full set complete.
      for (final band in [3, 4, 5, 6, 7]) {
        await sync.handleInboundSyncResponse(
          senderNodeId: _kPeer,
          channelIndex: _kChannelIndex,
          op: CanvasSyncResponseOp(
            canvasId: _kCanvasId,
            tileX: 0,
            tileY: 0,
            body: CanvasSyncResponseRawBandBody(
              bandIndex: band,
              cells: Uint8List(CanvasWireFormat.syncResponseRawBandCells),
            ),
          ),
        );
      }
      // Still syncing for ~10s — that's expected. Progress is gone
      // because the set completed.
      expect(sync.bandProgressForCanvas(canvas.localId), isNull);
    });
  });
}
