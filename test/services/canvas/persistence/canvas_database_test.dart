// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'canvas_db_${_testPid}_${_testDbSeq++}.db');
}

Set<String> _columnNames(List<Map<String, Object?>> pragma) =>
    pragma.map((r) => r['name'] as String).toSet();

Set<String> _indexNames(List<Map<String, Object?>> pragma) =>
    pragma.map((r) => r['name'] as String).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CanvasDatabase schema v1', () {
    test('opens at v1 and reports the configured version', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      try {
        await db.init();
        expect(db.isOpen, isTrue);
        final rawDb = db.database;
        expect(await rawDb.getVersion(), CanvasDbConfig.dbVersion);
      } finally {
        await db.close();
      }
    });

    test('creates all five tables', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      try {
        await db.init();
        final tables = (await db.database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'", // lint-allow: hardcoded-string
        )).map((r) => r['name'] as String).toSet();
        expect(
          tables,
          containsAll([
            CanvasTables.canvas,
            CanvasTables.cell,
            CanvasTables.pendingOp,
            CanvasTables.appliedOp,
            CanvasTables.peerDigest,
          ]),
        );
      } finally {
        await db.close();
      }
    });

    test('canvas table has every required column', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      try {
        await db.init();
        final cols = _columnNames(
          await db.database.rawQuery(
            'PRAGMA table_info(${CanvasTables.canvas})',
          ),
        );
        expect(
          cols,
          containsAll(<String>[
            'id',
            'canvas_id',
            'scope',
            'channel_index',
            'name',
            'width',
            'height',
            'palette_id',
            'status',
            'owner_node_num',
            'created_at_ms',
            'last_op_at_ms',
            'global_digest',
            'tile_digests',
            'cell_count',
          ]),
        );
      } finally {
        await db.close();
      }
    });

    test('cell + pending_op + applied_op + peer_digest columns', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      try {
        await db.init();
        final cell = _columnNames(
          await db.database.rawQuery('PRAGMA table_info(${CanvasTables.cell})'),
        );
        expect(
          cell,
          containsAll(<String>[
            'canvas_id',
            'x',
            'y',
            'color',
            'last_ts',
            'last_author',
            'last_seq',
          ]),
        );

        final pending = _columnNames(
          await db.database.rawQuery(
            'PRAGMA table_info(${CanvasTables.pendingOp})',
          ),
        );
        expect(
          pending,
          containsAll(<String>[
            'id',
            'canvas_id',
            'x',
            'y',
            'color',
            'op_ts',
            'op_seq',
            'created_at_ms',
            'attempts',
            'next_attempt_at_ms',
            'state',
            'last_error',
          ]),
        );

        final applied = _columnNames(
          await db.database.rawQuery(
            'PRAGMA table_info(${CanvasTables.appliedOp})',
          ),
        );
        expect(
          applied,
          containsAll(<String>[
            'id',
            'canvas_id',
            'x',
            'y',
            'color',
            'op_ts',
            'author_node_num',
            'op_seq',
            'direction',
            'received_at_ms',
            'was_accepted',
          ]),
        );

        final peer = _columnNames(
          await db.database.rawQuery(
            'PRAGMA table_info(${CanvasTables.peerDigest})',
          ),
        );
        expect(
          peer,
          containsAll(<String>[
            'canvas_id',
            'peer_node_num',
            'peer_global_digest',
            'peer_tile_digests',
            'peer_cell_count',
            'last_heard_at_ms',
            'last_sync_at_ms',
          ]),
        );
      } finally {
        await db.close();
      }
    });

    test('all required indexes exist', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      try {
        await db.init();
        final canvasIdx = _indexNames(
          await db.database.rawQuery(
            'PRAGMA index_list(${CanvasTables.canvas})',
          ),
        );
        expect(
          canvasIdx,
          containsAll(<String>[
            'idx_canvas_scope_channel',
            'idx_canvas_last_op_at',
          ]),
        );

        final pendingIdx = _indexNames(
          await db.database.rawQuery(
            'PRAGMA index_list(${CanvasTables.pendingOp})',
          ),
        );
        expect(
          pendingIdx,
          containsAll(<String>[
            'idx_pending_state_next_attempt',
            'idx_pending_canvas',
          ]),
        );

        final appliedIdx = _indexNames(
          await db.database.rawQuery(
            'PRAGMA index_list(${CanvasTables.appliedOp})',
          ),
        );
        expect(
          appliedIdx,
          containsAll(<String>[
            'idx_applied_canvas_received',
            'idx_applied_canvas_cell',
            'idx_applied_dedupe',
          ]),
        );

        final peerIdx = _indexNames(
          await db.database.rawQuery(
            'PRAGMA index_list(${CanvasTables.peerDigest})',
          ),
        );
        expect(peerIdx, containsAll(<String>['idx_peer_digest_canvas_heard']));
      } finally {
        await db.close();
      }
    });

    test('idx_applied_dedupe uses the safe 6-column composite key', () async {
      // Regression pin against re-introducing the unsafe
      // (canvas_id, author_node_num, op_seq) key — op_seq is u8 and
      // rolls over every 256 paints per author, so that 3-column key
      // would treat distinct paints as duplicates.
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      try {
        await db.init();
        final cols = (await db.database.rawQuery(
          'PRAGMA index_info(idx_applied_dedupe)',
        )).map((r) => r['name'] as String).toList();
        expect(
          cols,
          equals(<String>[
            'canvas_id',
            'author_node_num',
            'op_ts',
            'op_seq',
            'x',
            'y',
          ]),
        );
      } finally {
        await db.close();
      }
    });
  });

  group('CanvasDatabase lifecycle', () {
    test('init is idempotent', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      try {
        await db.init();
        expect(db.isOpen, isTrue);
        // Second init must not throw or replace the underlying handle.
        await db.init();
        expect(db.isOpen, isTrue);
      } finally {
        await db.close();
      }
    });

    test('close is safe and idempotent', () async {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      await db.init();
      await db.close();
      expect(db.isOpen, isFalse);
      // Second close MUST be a silent no-op.
      await db.close();
      expect(db.isOpen, isFalse);
    });

    test('database getter throws before init', () {
      final db = CanvasDatabase(testDbPath: _uniqueTestDbPath());
      expect(() => db.database, throwsA(isA<StateError>()));
    });
  });
}
