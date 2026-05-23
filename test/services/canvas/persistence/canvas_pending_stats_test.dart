// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for `CanvasRepository.pendingStatsForCanvas` +
// `getPendingCellCoordinates`. Both surfaces feed the transmission
// status view model.
//
// Spec: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §5.1.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_pending_stats_${_testPid}_${_testDbSeq++}.db');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CanvasRepository.pendingStatsForCanvas', () {
    test('empty canvas returns CanvasPendingStats.empty', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );

      final stats = await repo.pendingStatsForCanvas(canvas.localId);
      expect(stats.count, 0);
      expect(stats.oldestCreatedAtMs, isNull);
      expect(stats.nextAttemptAtMs, isNull);
    });

    test(
      'single queued op returns (count=1, oldest=<insertedMs>, next=<insertedMs>)',
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
        const insertedMs = 1_000_000;
        await repo.enqueuePaint(
          canvasLocalId: canvas.localId,
          x: 5,
          y: 7,
          color: 3,
          authorNodeNum: 0x100,
          opTs: 1000,
          opSeq: 0,
          createdAtMsOverride: insertedMs,
        );

        final stats = await repo.pendingStatsForCanvas(canvas.localId);
        expect(stats.count, 1);
        expect(stats.oldestCreatedAtMs, insertedMs);
        expect(stats.nextAttemptAtMs, insertedMs);
      },
    );

    test('three queued ops with different created_at_ms → oldest reflects '
        'the minimum', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );
      for (var i = 0; i < 3; i++) {
        await repo.enqueuePaint(
          canvasLocalId: canvas.localId,
          x: i,
          y: 0,
          color: 1,
          authorNodeNum: 0x100,
          opTs: 1000 + i,
          opSeq: i,
          createdAtMsOverride: 1_000_000 + i * 1000,
        );
      }

      final stats = await repo.pendingStatsForCanvas(canvas.localId);
      expect(stats.count, 3);
      expect(stats.oldestCreatedAtMs, 1_000_000);
    });

    test('canvases are isolated — one canvas\'s queue does not affect '
        'another\'s stats', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final a = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'A',
      );
      final b = await repo.getOrCreateMeshCanvas(
        canvasId: 0xCAFE,
        channelIndex: 1,
        name: 'B',
      );
      await repo.enqueuePaint(
        canvasLocalId: a.localId,
        x: 0,
        y: 0,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1000,
        opSeq: 0,
      );
      await repo.enqueuePaint(
        canvasLocalId: a.localId,
        x: 1,
        y: 0,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1001,
        opSeq: 1,
      );

      final statsA = await repo.pendingStatsForCanvas(a.localId);
      final statsB = await repo.pendingStatsForCanvas(b.localId);
      expect(statsA.count, 2);
      expect(statsB.count, 0);
    });
  });

  group('CanvasRepository.getPendingCellCoordinates', () {
    test('empty queue returns empty set', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );
      final coords = await repo.getPendingCellCoordinates(
        canvas.localId,
        widthCells: 128,
      );
      expect(coords, isEmpty);
    });

    test('queued ops appear in the set as packed y * width + x', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );
      await repo.enqueuePaint(
        canvasLocalId: canvas.localId,
        x: 5,
        y: 7,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1000,
        opSeq: 0,
      );
      await repo.enqueuePaint(
        canvasLocalId: canvas.localId,
        x: 10,
        y: 0,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1001,
        opSeq: 1,
      );

      final coords = await repo.getPendingCellCoordinates(
        canvas.localId,
        widthCells: 128,
      );
      expect(coords, hasLength(2));
      expect(coords.contains(7 * 128 + 5), isTrue);
      expect(coords.contains(0 * 128 + 10), isTrue);
    });

    test('once a row is sent the coord drops out of the set', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      addTearDown(db.close);
      final repo = CanvasRepository(db);
      final canvas = await repo.getOrCreateMeshCanvas(
        canvasId: 0xC0DE,
        channelIndex: 0,
        name: 'Mesh',
      );
      await repo.enqueuePaint(
        canvasLocalId: canvas.localId,
        x: 5,
        y: 7,
        color: 1,
        authorNodeNum: 0x100,
        opTs: 1000,
        opSeq: 0,
      );
      // Fetch the row id so we can mark it sent.
      final queued = await repo.getQueuedReadyOps(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        limit: 8,
      );
      expect(queued, hasLength(1));
      await repo.markPendingSent(queued.first.id);

      final coords = await repo.getPendingCellCoordinates(
        canvas.localId,
        widthCells: 128,
      );
      expect(coords, isEmpty);
    });
  });
}
