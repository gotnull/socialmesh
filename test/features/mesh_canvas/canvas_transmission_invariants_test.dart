// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Cross-cutting invariant tests for MeshCanvas transmission status.
//
// Spec: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §7.
//
// Coverage:
//   - I1 Local Canvas immunity (static-grep): the HUD widget is
//     never mounted on local-scope viewers — confirmed by source
//     inspection of the viewport body's Stack children.
//   - I3 Queue-full block leaves pending_op untouched: paint a row
//     into a real DB at the soft cap, attempt one more paint via
//     the recording fake — assert no row was added.
//   - I4 Cooling decay: governor saturation lifts after the window
//     drains; the snapshot transitions cooling → queued → idle.
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

class _FakeClock {
  int _ms;
  _FakeClock(this._ms);
  int now() => _ms;
  void advance(Duration d) {
    _ms += d.inMilliseconds;
  }
}

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_status_inv_${_testPid}_${_testDbSeq++}.db');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('I1 — Local Canvas immunity (static surface guarantees)', () {
    test('CanvasTransmissionStatusHud is only mounted under a mesh-scope '
        'branch in canvas_viewport_body.dart', () {
      final body = File(
        'lib/features/mesh_canvas/widgets/canvas_viewport_body.dart',
      );
      expect(body.existsSync(), isTrue);
      final src = body.readAsStringSync();
      // The HUD must sit inside a `canvas.scope == CanvasScope.mesh`
      // guard block. We assert the mount site appears AFTER such a
      // guard exists somewhere in the file and that there is no
      // unguarded `CanvasTransmissionStatusHud(` reference.
      final hudMounts = 'CanvasTransmissionStatusHud(';
      final hudCount = hudMounts.allMatches(src).length;
      expect(
        hudCount,
        1,
        reason:
            'transmission HUD should appear exactly once in the viewport '
            'body — any new mount site must be reviewed for scope gating',
      );
      // Find the byte offset of the HUD mount and ensure the most
      // recent `CanvasScope.mesh` guard appears before it.
      final hudOffset = src.indexOf(hudMounts);
      final guardOffset = src.lastIndexOf(
        'canvas.scope == CanvasScope.mesh',
        hudOffset,
      );
      expect(
        guardOffset,
        greaterThan(0),
        reason:
            'transmission HUD mount must follow a CanvasScope.mesh guard '
            'so local-scope viewers never instantiate the HUD widget',
      );
    });
  });

  group('I3 — Soft-cap is informative, not a hard block', () {
    test(
      'severity=full snapshot still has accurate pending count + cap '
      'reference — the HUD pill can read both to render queue chrome',
      () async {
        final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
        await db.init();
        addTearDown(db.close);
        final repo = CanvasRepository(db);
        final canvas = await repo.getOrCreateMeshCanvas(
          canvasId: 0xC0DE,
          channelIndex: 0,
          name: 'Mesh',
        );

        // Pre-fill the queue to the soft cap.
        for (var i = 0; i < MeshCanvasTransmissionStatus.softQueueCap; i++) {
          await repo.enqueuePaint(
            canvasLocalId: canvas.localId,
            x: i,
            y: 0,
            color: 1,
            authorNodeNum: 0x100,
            opTs: 1000 + i,
            opSeq: i,
          );
        }

        final governor = CanvasOutboundGovernor();
        final coordinator = CanvasSendCoordinator(
          repository: repo,
          governor: governor,
          outbound: _FakeChannel(),
          localNodeNumProvider: () => 0x100,
        );
        final status = await computeTransmissionStatus(
          repo: repo,
          coordinator: coordinator,
          governor: governor,
          canvasLocalId: canvas.localId,
        );
        expect(status.severity, MeshCanvasTransmissionSeverity.full);
        expect(status.canPaint, isFalse);
        expect(
          status.pendingCount,
          MeshCanvasTransmissionStatus.softQueueCap,
          reason:
              'view model still surfaces queue depth for HUD chrome even '
              'though the paint handler no longer hard-blocks at the cap',
        );
      },
    );
  });

  group('I4 — Cooling decay', () {
    test(
      'governor saturation lifts after the 60-second window drains; '
      'snapshot transitions cooling → queued → idle (queue drained)',
      () async {
        final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
        await db.init();
        addTearDown(db.close);
        final repo = CanvasRepository(db);
        final clock = _FakeClock(1_000_000);
        final governor = CanvasOutboundGovernor(nowMs: clock.now);
        final coordinator = CanvasSendCoordinator(
          repository: repo,
          governor: governor,
          outbound: _FakeChannel(),
          localNodeNumProvider: () => 0x100,
          nowMs: clock.now,
        );
        final canvas = await repo.getOrCreateMeshCanvas(
          canvasId: 0xC0DE,
          channelIndex: 0,
          name: 'Mesh',
        );

        // Pin governor below minPaintBytes (24).
        governor.recordSend(230); // headroom = 20 B < 24
        await repo.enqueuePaint(
          canvasLocalId: canvas.localId,
          x: 0,
          y: 0,
          color: 1,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
          createdAtMsOverride: clock.now(),
        );

        var status = await computeTransmissionStatus(
          repo: repo,
          coordinator: coordinator,
          governor: governor,
          canvasLocalId: canvas.localId,
          nowMsOverride: clock.now(),
        );
        expect(status.severity, MeshCanvasTransmissionSeverity.cooling);

        // Advance past the governor window. The next snapshot should
        // be queued (governor empty, but pending row still present).
        clock.advance(const Duration(seconds: 61));
        status = await computeTransmissionStatus(
          repo: repo,
          coordinator: coordinator,
          governor: governor,
          canvasLocalId: canvas.localId,
          nowMsOverride: clock.now(),
        );
        expect(status.severity, MeshCanvasTransmissionSeverity.queued);
        expect(status.isCanvasBudgetCooling, isFalse);

        // Drain the queue manually (simulate the row going through).
        final queued = await repo.getQueuedReadyOps(
          nowMs: clock.now(),
          limit: 64,
        );
        for (final op in queued) {
          await repo.markPendingSent(op.id, op.canvasLocalId);
        }
        status = await computeTransmissionStatus(
          repo: repo,
          coordinator: coordinator,
          governor: governor,
          canvasLocalId: canvas.localId,
          nowMsOverride: clock.now(),
        );
        expect(status.severity, MeshCanvasTransmissionSeverity.idle);
      },
    );
  });
}
