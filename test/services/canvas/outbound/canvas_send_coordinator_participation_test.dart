// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Participation-gate regression tests for [CanvasSendCoordinator].
//
// Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.3 + §8 (I4 mesh
// paint hard-gated).
//
// Invariants pinned here:
//   - drain() skips every send when canSend() returns false;
//   - pending_op rows are NOT consumed while gated (toggling
//     participation back on resumes the queue);
//   - flipping canSend false → true mid-test causes the next drain to
//     ship normally.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_coord_gate_${_testPid}_${_testDbSeq++}.db');
}

class _FakeChannel implements CanvasOutboundChannel {
  final List<Uint8List> sent = <Uint8List>[];

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    sent.add(canvasPayload);
    return CanvasSendResult.sent(wireBytes: canvasPayload.length + 22);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CanvasSendCoordinator participation gate', () {
    test(
      'drain() with canSend()=false sends nothing and leaves rows queued',
      () async {
        final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
        await db.init();
        addTearDown(db.close);
        final repo = CanvasRepository(db);
        final governor = CanvasOutboundGovernor();
        final channel = _FakeChannel();

        // Coordinator with the gate hard-off.
        final coordinator = CanvasSendCoordinator(
          repository: repo,
          governor: governor,
          outbound: channel,
          localNodeNumProvider: () => 0x100,
          canSend: () => false,
        );

        // Materialise a mesh canvas + queue 3 paint ops.
        final canvas = await repo.getOrCreateMeshCanvas(
          canvasId: 0xC0DE,
          channelIndex: 0,
          name: 'Mesh',
        );
        for (var i = 0; i < 3; i++) {
          final accepted = await repo.enqueuePaint(
            canvasLocalId: canvas.localId,
            x: i,
            y: 0,
            color: 1,
            authorNodeNum: 0x100,
            opTs: 1000 + i,
            opSeq: i,
          );
          expect(accepted, isTrue);
        }

        final framesSent = await coordinator.drain();

        expect(framesSent, 0, reason: 'gate must block every send');
        expect(channel.sent, isEmpty);

        // Rows remain queued and ready — re-enabling will drain them.
        final ready = await repo.getQueuedReadyOps(
          nowMs: DateTime.now().millisecondsSinceEpoch,
          limit: 64,
        );
        expect(ready, hasLength(3));
      },
    );

    test('gate flipping false → true allows the next drain to ship', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final governor = CanvasOutboundGovernor();
      final channel = _FakeChannel();

      var participation = false;
      final coordinator = CanvasSendCoordinator(
        repository: repo,
        governor: governor,
        outbound: channel,
        localNodeNumProvider: () => 0x100,
        canSend: () => participation,
      );

      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xCAFE,
        channelIndex: 0,
        name: 'Mesh',
      );
      await repo.enqueuePaint(
        canvasLocalId: canvas.localId,
        x: 0,
        y: 0,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1000,
        opSeq: 0,
      );

      // Gate off: nothing ships.
      expect(await coordinator.drain(), 0);
      expect(channel.sent, isEmpty);
      var ready = await repo.getQueuedReadyOps(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        limit: 64,
      );
      expect(ready, hasLength(1));

      // User opts in.
      participation = true;
      final framesSent = await coordinator.drain();
      expect(framesSent, greaterThanOrEqualTo(1));
      expect(channel.sent, hasLength(framesSent));

      // After successful send, the row leaves `pending_op`.
      ready = await repo.getQueuedReadyOps(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        limit: 64,
      );
      expect(ready, isEmpty);
    });

    test(
      'default canSend (no callback passed) preserves pre-existing send '
      'behaviour for tests that construct the coordinator without the gate',
      () async {
        final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
        await db.init();
        addTearDown(db.close);
        final repo = CanvasRepository(db);
        final governor = CanvasOutboundGovernor();
        final channel = _FakeChannel();

        // No canSend passed → defaults to `() => true`.
        final coordinator = CanvasSendCoordinator(
          repository: repo,
          governor: governor,
          outbound: channel,
          localNodeNumProvider: () => 0x100,
        );

        final canvas = await repo.getOrCreateMeshCanvas(
          canvasId: 0xBEEF,
          channelIndex: 0,
          name: 'Mesh',
        );
        await repo.enqueuePaint(
          canvasLocalId: canvas.localId,
          x: 0,
          y: 0,
          color: 1,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
        );

        expect(await coordinator.drain(), greaterThanOrEqualTo(1));
        expect(channel.sent, isNotEmpty);
      },
    );
  });
}
