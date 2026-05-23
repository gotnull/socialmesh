// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Test for [CanvasRepository.computeAndCacheDigests] — the bridge
// between the pure digest computer and the canvas table cache.
//
// Spec: docs/canvas/CANVAS_SYNC_V0_1.md §5.1.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_digest_compute.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';

int _seq = 0;
final int _pid = pid;

String _testDbPath() {
  return p.join(
    Directory.systemTemp.path,
    'canvas_compute_digests_${_pid}_${_seq++}.db',
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('computeAndCacheDigests on empty canvas returns empty-input digest + '
      'writes it back to the canvas row', () async {
    final db = CanvasDatabase(testDbPath: _testDbPath());
    await db.init();
    addTearDown(db.close);
    final repo = CanvasRepository(db);
    final canvas = await repo.getOrCreateMeshCanvas(
      canvasId: 0xC0DE,
      channelIndex: 0,
      name: 'Mesh',
    );

    final set = await repo.computeAndCacheDigests(canvas.localId);
    expect(set.cellCount, 0);

    // Reread the row and confirm digests were persisted.
    final reread = await repo.listCanvases();
    final stored = reread.firstWhere((c) => c.localId == canvas.localId);
    expect(stored.globalDigest, isNotNull);
    expect(stored.tileDigests, isNotNull);
    expect(stored.globalDigest, equals(set.globalDigest));
    expect(stored.tileDigests, equals(set.tileDigests));
  });

  test('computeAndCacheDigests with painted cells captures them in global + '
      'tile digests', () async {
    final db = CanvasDatabase(testDbPath: _testDbPath());
    await db.init();
    addTearDown(db.close);
    final repo = CanvasRepository(db);
    final canvas = await repo.getOrCreateMeshCanvas(
      canvasId: 0xC0DE,
      channelIndex: 0,
      name: 'Mesh',
    );

    // Paint locally a couple of cells across different tiles.
    await repo.paintLocal(
      canvasLocalId: canvas.localId,
      x: 5,
      y: 5,
      color: 3,
      authorNodeNum: 0x100,
      opTs: 1000,
      opSeq: 0,
    );
    await repo.paintLocal(
      canvasLocalId: canvas.localId,
      x: 70,
      y: 70,
      color: 5,
      authorNodeNum: 0x100,
      opTs: 1001,
      opSeq: 1,
    );

    final empty = await computeCanvasDigests(const []);
    final set = await repo.computeAndCacheDigests(canvas.localId);

    expect(set.cellCount, 2);
    expect(
      set.globalDigest,
      isNot(equals(empty.globalDigest)),
      reason: 'painted canvas global digest must differ from empty',
    );
  });
}
