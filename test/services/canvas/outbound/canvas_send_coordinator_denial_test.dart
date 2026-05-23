// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests that the send coordinator records denial timestamps so the
// transmission-status view model can derive `isCanvasBudgetCooling`
// + `isSipBudgetCooling`.
//
// Spec: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §5.2.

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
  return p.join(dir, 'canvas_coord_denial_${_testPid}_${_testDbSeq++}.db');
}

class _FakeClock {
  int _ms;
  _FakeClock(this._ms);
  int now() => _ms;
  void advance(Duration d) {
    _ms += d.inMilliseconds;
  }
}

class _FakeChannel implements CanvasOutboundChannel {
  CanvasSendResult outcome = CanvasSendResult.sent(wireBytes: 0);

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    if (outcome.outcome == CanvasSendOutcome.sent) {
      return CanvasSendResult.sent(wireBytes: canvasPayload.length + 22);
    }
    return outcome;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CanvasSendCoordinator — denial timestamps', () {
    test('before any drain, both denial timestamps are null', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final coordinator = CanvasSendCoordinator(
        repository: repo,
        governor: CanvasOutboundGovernor(),
        outbound: _FakeChannel(),
        localNodeNumProvider: () => 0x100,
      );
      expect(coordinator.lastGovernorDenialAtMs, isNull);
      expect(coordinator.lastSipDenialAtMs, isNull);
    });

    test('canvas-governor full → lastGovernorDenialAtMs is set, lastSipDenial '
        'remains null', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final clock = _FakeClock(1_000_000);
      final governor = CanvasOutboundGovernor(nowMs: clock.now);
      // Pre-saturate the governor so the first send is denied.
      governor.recordSend(CanvasOutboundGovernor.budgetBytes);
      final channel = _FakeChannel();
      final coordinator = CanvasSendCoordinator(
        repository: repo,
        governor: governor,
        outbound: channel,
        localNodeNumProvider: () => 0x100,
        nowMs: clock.now,
      );

      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
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
        // Drain queries `next_attempt_at_ms <= nowMs`. The override
        // makes the row immediately ready under the fake clock.
        createdAtMsOverride: 999_000,
      );

      final framesSent = await coordinator.drain();
      expect(framesSent, 0);
      expect(coordinator.lastGovernorDenialAtMs, 1_000_000);
      expect(coordinator.lastSipDenialAtMs, isNull);
    });

    test('SIP rate-limited send → lastSipDenialAtMs is set, lastGovernorDenial '
        'remains null', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final clock = _FakeClock(2_000_000);
      final governor = CanvasOutboundGovernor(nowMs: clock.now);
      final channel = _FakeChannel();
      channel.outcome = const CanvasSendResult(
        outcome: CanvasSendOutcome.sipRateLimited,
        wireBytes: 0,
      );
      final coordinator = CanvasSendCoordinator(
        repository: repo,
        governor: governor,
        outbound: channel,
        localNodeNumProvider: () => 0x100,
        nowMs: clock.now,
      );

      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
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
        createdAtMsOverride: 1_999_000,
      );

      final framesSent = await coordinator.drain();
      expect(framesSent, 0);
      expect(coordinator.lastGovernorDenialAtMs, isNull);
      expect(coordinator.lastSipDenialAtMs, 2_000_000);
    });

    test('successful drain leaves both denial timestamps untouched — they '
        'only track failures, the view model handles decay itself', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final clock = _FakeClock(3_000_000);
      final governor = CanvasOutboundGovernor(nowMs: clock.now);
      final channel = _FakeChannel(); // default: sent OK
      final coordinator = CanvasSendCoordinator(
        repository: repo,
        governor: governor,
        outbound: channel,
        localNodeNumProvider: () => 0x100,
        nowMs: clock.now,
      );

      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
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
        createdAtMsOverride: 2_999_000,
      );

      final framesSent = await coordinator.drain();
      expect(framesSent, greaterThanOrEqualTo(1));
      expect(coordinator.lastGovernorDenialAtMs, isNull);
      expect(coordinator.lastSipDenialAtMs, isNull);
    });
  });
}
