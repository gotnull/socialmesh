// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Raw-band sync_response test — the pathological-tile fallback path.
//
// Spec: docs/canvas/CANVAS_SYNC_V0_1.md §3.4 + §10.4.
//
// When a tile's RLE encoding would exceed 88 runs, the coordinator
// MUST fall back to 8 raw bands of 128 cells each. This test paints
// a 32×32 alternating-color checkerboard into tile (0, 0) on Device A,
// has Device B request the tile, and verifies B reconstructs every
// non-default cell after the 8 bands arrive.
//
// A checkerboard produces 1024 runs (one per cell) when RLE-encoded,
// which is far above the 88-run cap → guaranteed to exercise the
// 8-band fallback.

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
import 'package:socialmesh/services/canvas/mrrp_service_canvas.dart';

const int _kCanvasId = 0xC0FFEE_FACE;
const int _kChannelIndex = 0;

int _seq = 0;
final int _pid = pid;
String _testDbPath(String tag) => p.join(
  Directory.systemTemp.path,
  'canvas_sync_raw_${tag}_${_pid}_${_seq++}.db',
);

/// Governor stub that allows every send regardless of byte volume.
/// Lets the test exercise the 8-band fallback without bumping into
/// the production 250B/60s ceiling (8 bands × ~146B = 1168B > 250B).
class _UnlimitedGovernor extends CanvasOutboundGovernor {
  @override
  bool canSend(int bytes) => true;

  @override
  void recordSend(int bytes) {}

  @override
  int get remainingBytes => 100000;
}

class _LoopbackChannel implements CanvasOutboundChannel {
  final int senderNodeId;
  final Future<void> Function(
    int senderNodeId,
    int channelIndex,
    Uint8List payload,
  )
  deliver;

  /// Count of sync_response frames (action 0x05) emitted through
  /// this channel. The test inspects this to confirm 8 raw bands
  /// shipped (vs 1 RLE frame).
  int syncResponseEmits = 0;

  _LoopbackChannel({required this.senderNodeId, required this.deliver});

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    if (canvasPayload.length > 2 && canvasPayload[2] == 0x05) {
      syncResponseEmits++;
    }
    await deliver(senderNodeId, channelIndex, canvasPayload);
    return CanvasSendResult.sent(wireBytes: canvasPayload.length);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('checkerboard tile (1024 cells alternating) syncs via 8 raw bands; '
      'Device B reconstructs every non-default cell', () async {
    final aDb = CanvasDatabase(testDbPath: _testDbPath('A'));
    final bDb = CanvasDatabase(testDbPath: _testDbPath('B'));
    await aDb.init();
    await bDb.init();
    addTearDown(() async {
      await aDb.close();
      await bDb.close();
    });

    final aRepo = CanvasRepository(aDb);
    final bRepo = CanvasRepository(bDb);
    final aGov = _UnlimitedGovernor();
    final bGov = _UnlimitedGovernor();

    late _LoopbackChannel aChannel;
    late _LoopbackChannel bChannel;
    late MrrpServiceCanvas aService;
    late MrrpServiceCanvas bService;

    Future<void> deliverToB(int s, int c, Uint8List p) => bService.applyInbound(
      canvasPayload: p,
      senderNodeId: s,
      channelIndex: c,
    );
    Future<void> deliverToA(int s, int c, Uint8List p) => aService.applyInbound(
      canvasPayload: p,
      senderNodeId: s,
      channelIndex: c,
    );

    aChannel = _LoopbackChannel(senderNodeId: 0xAAAA, deliver: deliverToB);
    bChannel = _LoopbackChannel(senderNodeId: 0xBBBB, deliver: deliverToA);

    final aSync = CanvasSyncCoordinator(
      repository: aRepo,
      outbound: aChannel,
      governor: aGov,
      canEmit: () => true,
    );
    final bSync = CanvasSyncCoordinator(
      repository: bRepo,
      outbound: bChannel,
      governor: bGov,
      canEmit: () => true,
    );
    addTearDown(() {
      aSync.dispose();
      bSync.dispose();
    });

    aService = MrrpServiceCanvas(repository: aRepo, syncCoordinator: aSync);
    bService = MrrpServiceCanvas(repository: bRepo, syncCoordinator: bSync);

    final aCanvas = await aRepo.getOrCreateMeshCanvas(
      canvasId: _kCanvasId,
      channelIndex: _kChannelIndex,
      name: 'Primary',
    );
    final bCanvas = await bRepo.getOrCreateMeshCanvas(
      canvasId: _kCanvasId,
      channelIndex: _kChannelIndex,
      name: 'Primary',
    );

    // Paint a 32×32 checkerboard into tile (0, 0). Use colors 1
    // and 2 so neither is the transparent sentinel (0). Pre-compute
    // expected cell coordinates so we can assert reconstruction.
    final expectedCells = <(int, int, int)>[];
    var opSeq = 0;
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 32; x++) {
        final color = ((x + y) % 2 == 0) ? 1 : 2;
        await aRepo.paintLocal(
          canvasLocalId: aCanvas.localId,
          x: x,
          y: y,
          color: color,
          authorNodeNum: 0xAAAA,
          opTs: 1000,
          opSeq: opSeq & 0xff,
        );
        opSeq++;
        expectedCells.add((x, y, color));
      }
    }
    expect(
      (await aRepo.getCanvasCells(aCanvas.localId)).length,
      1024,
      reason: 'A should have a full 32x32 painted tile',
    );

    // B requests tile (0, 0) directly. We bypass the digest dance
    // and call handleInboundSyncRequest on A's service to keep the
    // test focused on the raw-band response path.
    await bSync.handleInboundDigest(
      senderNodeId: 0xAAAA,
      channelIndex: _kChannelIndex,
      // Use A's actual digest so global mismatch fires and B asks
      // for the (only) mismatched tile.
      op: await () async {
        final aSet = await aRepo.computeAndCacheDigests(aCanvas.localId);
        return CanvasDigestOp(
          canvasId: _kCanvasId,
          globalDigest: aSet.globalDigest,
          cellCount: aSet.cellCount,
          tileDigests: aSet.tileDigests,
        );
      }(),
    );

    // Drain microtasks for the request and the 8-band response.
    for (var i = 0; i < 32; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    // A should have shipped 8 sync_response frames for the
    // checkerboard tile (one per band).
    expect(
      aChannel.syncResponseEmits,
      8,
      reason: 'checkerboard tile must take the 8-band raw fallback',
    );

    // B should have reconstructed every cell from the 8 bands.
    final bCells = await bRepo.getCanvasCells(bCanvas.localId);
    // The reconstructed cells include only non-default colors so
    // every checkerboard cell (both color 1 and color 2) lands.
    expect(
      bCells.length,
      1024,
      reason: 'every checkerboard cell must land on B',
    );

    // Spot-check a few cells.
    bool hasCell(int x, int y, int color) {
      for (final c in bCells) {
        if (c.x == x && c.y == y && c.color == color) return true;
      }
      return false;
    }

    expect(hasCell(0, 0, 1), isTrue, reason: '(0,0)=color1');
    expect(hasCell(1, 0, 2), isTrue, reason: '(1,0)=color2');
    // (31+31)%2 = 0 → color 1.
    expect(hasCell(31, 31, 1), isTrue, reason: '(31,31)=color1');
    // (30+31)%2 = 1 → color 2.
    expect(hasCell(30, 31, 2), isTrue, reason: '(30,31)=color2');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
