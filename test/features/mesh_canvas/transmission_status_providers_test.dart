// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the transmission-status snapshot computation that
// powers `meshCanvasTransmissionStatusProvider`.
//
// Spec: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §4.
//
// We test the snapshot function directly (the StreamProvider is thin
// glue around it: yield once, then yield every 2 s). Going through
// the StreamProvider in flutter_test forces a Stream.periodic timer
// that fights flutter_test's "no pending timers at teardown"
// invariant. The provider's lifecycle is verified indirectly through
// the HUD widget tests that wire it in S3.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/features/mesh_canvas/providers/transmission_status_providers.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';
import 'package:socialmesh/services/canvas/canvas_transmission_status_models.dart';

class _FakeChannel implements CanvasOutboundChannel {
  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    return CanvasSendResult.sent(wireBytes: canvasPayload.length + 22);
  }
}

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_status_providers_${_testPid}_${_testDbSeq++}.db');
}

Future<
  ({
    CanvasRepository repo,
    CanvasOutboundGovernor governor,
    CanvasSendCoordinator coordinator,
  })
>
_buildStack(CanvasDatabase db) async {
  final repo = CanvasRepository(db);
  final governor = CanvasOutboundGovernor();
  final coordinator = CanvasSendCoordinator(
    repository: repo,
    governor: governor,
    outbound: _FakeChannel(),
    localNodeNumProvider: () => 0x100,
  );
  return (repo: repo, governor: governor, coordinator: coordinator);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('computeTransmissionStatus — snapshot derivation', () {
    test('fresh canvas with empty queue → idle severity', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final stack = await _buildStack(db);
      final canvas = await stack.repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );

      final status = await computeTransmissionStatus(
        repo: stack.repo,
        coordinator: stack.coordinator,
        governor: stack.governor,
        canvasLocalId: canvas.localId,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.idle);
      expect(status.pendingCount, 0);
      expect(status.canPaint, isTrue);
    });

    test('one queued op → severity=queued, pendingCount=1', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final stack = await _buildStack(db);
      final canvas = await stack.repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );
      await stack.repo.enqueuePaint(
        canvasLocalId: canvas.localId,
        x: 5,
        y: 7,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1000,
        opSeq: 0,
      );

      final status = await computeTransmissionStatus(
        repo: stack.repo,
        coordinator: stack.coordinator,
        governor: stack.governor,
        canvasLocalId: canvas.localId,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.queued);
      expect(status.pendingCount, 1);
      expect(status.canPaint, isTrue);
    });

    test('pendingCount >= softQueueCap (32) → full + canPaint=false', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final stack = await _buildStack(db);
      final canvas = await stack.repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );
      for (var i = 0; i < 32; i++) {
        await stack.repo.enqueuePaint(
          canvasLocalId: canvas.localId,
          x: i,
          y: 0,
          color: 1,
          authorNodeNum: 0x100,
          opTs: 1000 + i,
          opSeq: i,
        );
      }

      final status = await computeTransmissionStatus(
        repo: stack.repo,
        coordinator: stack.coordinator,
        governor: stack.governor,
        canvasLocalId: canvas.localId,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.full);
      expect(status.pendingCount, 32);
      expect(status.canPaint, isFalse);
    });

    test('governor saturated below minPaintBytes → cooling severity', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final stack = await _buildStack(db);
      final canvas = await stack.repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );
      await stack.repo.enqueuePaint(
        canvasLocalId: canvas.localId,
        x: 0,
        y: 0,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1000,
        opSeq: 0,
      );
      // Pin the governor right at the boundary — 230 bytes used
      // out of 250 leaves only 20 B headroom, below the 24-byte
      // minPaint threshold. The view model treats this as cooling.
      stack.governor.recordSend(230);

      final status = await computeTransmissionStatus(
        repo: stack.repo,
        coordinator: stack.coordinator,
        governor: stack.governor,
        canvasLocalId: canvas.localId,
      );
      expect(status.severity, MeshCanvasTransmissionSeverity.cooling);
      expect(status.isCanvasBudgetCooling, isTrue);
      expect(status.canPaint, isTrue);
    });
  });
}
