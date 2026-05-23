// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Two-repository integration test for the digest + tile-sync
// hydration round trip.
//
// Spec: docs/canvas/CANVAS_SYNC_V0_1.md §3 + §10.9 (end-to-end).
//
// Scenario:
//   - Device A repo has painted cells across multiple tiles.
//   - Device B repo is empty.
//   - A emits canvas_digest.
//   - B compares, finds mismatch + peer richer, emits sync_request
//     per mismatched tile.
//   - A handles sync_request, encodes + emits sync_response.
//   - B handles sync_response, applies cells via LWW.
//   - Final: B's cells match A's for the synced tile.
//
// Wire emulation: each device's CanvasOutboundChannel feeds the
// other device's MrrpServiceCanvas.applyInbound (with senderNodeId
// and channelIndex). The channel never touches a real SIP path —
// this is a pure logic + LWW + state-machine test.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';
import 'package:socialmesh/services/canvas/canvas_sync_coordinator.dart';
import 'package:socialmesh/services/canvas/mrrp_service_canvas.dart';

const int _kCanvasId = 0xC0DE_CAFE_FACE_BEEF;
const int _kChannelIndex = 0;

int _seq = 0;
final int _pid = pid;
String _testDbPath(String tag) => p.join(
  Directory.systemTemp.path,
  'canvas_sync_${tag}_${_pid}_${_seq++}.db',
);

/// Outbound channel that forwards every send into a peer's MRRP
/// service handler. The `apply` lambda is the entry point on the
/// receiving side.
class _LoopbackChannel implements CanvasOutboundChannel {
  final int senderNodeId;
  final Future<void> Function(
    int senderNodeId,
    int channelIndex,
    Uint8List payload,
  )
  deliver;

  _LoopbackChannel({required this.senderNodeId, required this.deliver});

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    await deliver(senderNodeId, channelIndex, canvasPayload);
    return CanvasSendResult.sent(wireBytes: canvasPayload.length);
  }
}

class _Device {
  final int nodeNum;
  final CanvasDatabase db;
  final CanvasRepository repo;
  final CanvasOutboundGovernor governor;
  late final CanvasSyncCoordinator sync;
  late final MrrpServiceCanvas service;
  late final _LoopbackChannel channel;
  int meshCanvasLocalId = 0;

  _Device(this.nodeNum, this.db, this.repo, this.governor);
}

Future<_Device> _buildDevice({
  required int nodeNum,
  required String tag,
  required Future<void> Function(
    int senderNodeId,
    int channelIndex,
    Uint8List payload,
  )
  deliverPeer,
  bool participation = true,
}) async {
  final db = CanvasDatabase(testDbPath: _testDbPath(tag));
  await db.init();
  final repo = CanvasRepository(db);
  final governor = CanvasOutboundGovernor(
    nowMs: () => DateTime.now().millisecondsSinceEpoch,
  );
  final device = _Device(nodeNum, db, repo, governor);
  device.channel = _LoopbackChannel(
    senderNodeId: nodeNum,
    deliver: deliverPeer,
  );
  device.sync = CanvasSyncCoordinator(
    repository: repo,
    outbound: device.channel,
    governor: governor,
    canEmit: () => participation,
  );
  device.service = MrrpServiceCanvas(
    repository: repo,
    syncCoordinator: device.sync,
  );
  final canvas = await repo.getOrCreateMeshCanvas(
    canvasId: _kCanvasId,
    channelIndex: _kChannelIndex,
    name: 'Primary',
  );
  device.meshCanvasLocalId = canvas.localId;
  return device;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('A has cells across 2 tiles; B is empty; B hydrates from A '
      'via digest → request → response → apply', () async {
    // Two devices wired with loopback channels. A.channel.deliver
    // points into B.service.applyInbound and vice versa. We have
    // to declare the deliverer functions before building devices.
    late _Device deviceA;
    late _Device deviceB;

    Future<void> deliverToB(
      int senderNodeId,
      int channelIndex,
      Uint8List payload,
    ) async {
      await deviceB.service.applyInbound(
        canvasPayload: payload,
        senderNodeId: senderNodeId,
        channelIndex: channelIndex,
      );
    }

    Future<void> deliverToA(
      int senderNodeId,
      int channelIndex,
      Uint8List payload,
    ) async {
      await deviceA.service.applyInbound(
        canvasPayload: payload,
        senderNodeId: senderNodeId,
        channelIndex: channelIndex,
      );
    }

    deviceA = await _buildDevice(
      nodeNum: 0xAAAA,
      tag: 'A',
      deliverPeer: deliverToB,
    );
    deviceB = await _buildDevice(
      nodeNum: 0xBBBB,
      tag: 'B',
      deliverPeer: deliverToA,
    );
    addTearDown(() async {
      deviceA.sync.dispose();
      deviceB.sync.dispose();
      await deviceA.db.close();
      await deviceB.db.close();
    });

    // Paint cells on A across two tiles (one in tile (0, 0) and
    // one in tile (2, 2)).
    await deviceA.repo.paintLocal(
      canvasLocalId: deviceA.meshCanvasLocalId,
      x: 5,
      y: 5,
      color: 3,
      authorNodeNum: deviceA.nodeNum,
      opTs: 1000,
      opSeq: 0,
    );
    await deviceA.repo.paintLocal(
      canvasLocalId: deviceA.meshCanvasLocalId,
      x: 75,
      y: 80,
      color: 5,
      authorNodeNum: deviceA.nodeNum,
      opTs: 1001,
      opSeq: 1,
    );

    // Sanity check.
    expect(
      (await deviceA.repo.getCanvasCells(deviceA.meshCanvasLocalId)).length,
      2,
    );
    expect(
      (await deviceB.repo.getCanvasCells(deviceB.meshCanvasLocalId)).length,
      0,
    );

    // A emits its digest. B receives, compares, requests mismatched
    // tiles. A handles each sync_request and emits sync_response
    // back. B applies the cells.
    await deviceA.sync.emitDigest(
      canvasLocalId: deviceA.meshCanvasLocalId,
      channelIndex: _kChannelIndex,
      canvasId: _kCanvasId,
    );

    // Settle any pending microtasks. The loopback channel calls
    // applyInbound which is async; sync_request emit from B happens
    // inside its digest handler; A's sync_response is also async.
    // A few yields are enough.
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    // B should now have the same cells A has (for the requested
    // tiles).
    final cellsA = await deviceA.repo.getCanvasCells(deviceA.meshCanvasLocalId);
    final cellsB = await deviceB.repo.getCanvasCells(deviceB.meshCanvasLocalId);
    expect(
      cellsB.length,
      greaterThanOrEqualTo(2),
      reason: 'B should have received the cells A had in mismatched tiles',
    );

    // Confirm the specific cells landed.
    bool hasCell(List<dynamic> cells, int x, int y, int color) {
      for (final c in cells) {
        if (c.x == x && c.y == y && c.color == color) return true;
      }
      return false;
    }

    expect(hasCell(cellsA, 5, 5, 3), isTrue);
    expect(hasCell(cellsA, 75, 80, 5), isTrue);
    expect(hasCell(cellsB, 5, 5, 3), isTrue, reason: 'cell (5,5)=3 hydrated');
    expect(
      hasCell(cellsB, 75, 80, 5),
      isTrue,
      reason: 'cell (75,80)=5 hydrated',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'matching digests → no sync_request emitted (B is already up-to-date)',
    () async {
      late _Device deviceA;
      late _Device deviceB;
      var bRequestEmits = 0;

      Future<void> deliverToB(
        int senderNodeId,
        int channelIndex,
        Uint8List payload,
      ) async {
        await deviceB.service.applyInbound(
          canvasPayload: payload,
          senderNodeId: senderNodeId,
          channelIndex: channelIndex,
        );
      }

      Future<void> deliverToA(
        int senderNodeId,
        int channelIndex,
        Uint8List payload,
      ) async {
        // Count any sync_request action bytes flowing toward A.
        if (payload.length > 2 && payload[2] == 0x04) {
          bRequestEmits++;
        }
        await deviceA.service.applyInbound(
          canvasPayload: payload,
          senderNodeId: senderNodeId,
          channelIndex: channelIndex,
        );
      }

      deviceA = await _buildDevice(
        nodeNum: 0xAAAA,
        tag: 'matchA',
        deliverPeer: deliverToB,
      );
      deviceB = await _buildDevice(
        nodeNum: 0xBBBB,
        tag: 'matchB',
        deliverPeer: deliverToA,
      );
      addTearDown(() async {
        deviceA.sync.dispose();
        deviceB.sync.dispose();
        await deviceA.db.close();
        await deviceB.db.close();
      });

      // Both devices empty → identical digests.
      await deviceA.sync.emitDigest(
        canvasLocalId: deviceA.meshCanvasLocalId,
        channelIndex: _kChannelIndex,
        canvasId: _kCanvasId,
      );
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        bRequestEmits,
        0,
        reason: 'matching digests must not trigger any sync_request',
      );
    },
  );
}
