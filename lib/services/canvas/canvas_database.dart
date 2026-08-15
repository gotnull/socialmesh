// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas SQLite database wrapper.
//
// Schema source of truth: docs/canvas/CANVAS_V0_1.md §5 (plan §5 mirror).
// Migration policy follows lib/services/storage/CLAUDE.md: additive
// nullable columns only; bump _version; never ALTER existing columns or
// DROP tables on live users.
library;

import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';
import '../../core/radio_scope.dart';
import 'canvas_constants.dart';

/// Owns the `canvas.db` SQLite connection and its schema.
///
/// One instance per app process. The repository layer talks to the
/// raw [Database] via [database]; tests construct with [testDbPath]
/// to pin a unique temp file and avoid colliding with the production
/// `getApplicationDocumentsDirectory()` path.
class CanvasDatabase {
  Database? _db;
  final String? _testDbPath;

  CanvasDatabase({this._testDbPath});

  /// Open (or create) the database. Idempotent — calling more than once
  /// is a no-op after the first successful open.
  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      dbPath = await RadioScope.instance.databasePath(CanvasDbConfig.dbName);
    }

    AppLogging.meshCanvas('opening canvas.db at $dbPath');
    _db = await openDatabase(
      dbPath,
      version: CanvasDbConfig.dbVersion,
      onCreate: (db, version) async {
        AppLogging.meshCanvas('creating canvas.db schema v$version');
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.meshCanvas('upgrade canvas.db v$oldVersion -> v$newVersion');
        // v1 → v2 (64×64 reduction): nuke every canvas row. Pre-v2
        // cells may sit at coords ≥ 64 (no longer valid), and
        // cached digest blobs were 128 bytes (now must be 32). No
        // user-data loss concerns at this stage — v0.1 is still
        // pre-launch. Local Device Canvas, Mesh canvases, pending
        // ops, applied_op history, and peer digest cache all reset.
        // Hydration from peers via canvas_digest sync re-populates
        // mesh canvases naturally on next viewer mount.
        if (oldVersion < 2 && newVersion >= 2) {
          AppLogging.meshCanvas(
            'canvas.db v1 → v2: wiping all rows for 128→64 resize',
          );
          await db.delete(CanvasTables.peerDigest);
          await db.delete(CanvasTables.appliedOp);
          await db.delete(CanvasTables.pendingOp);
          await db.delete(CanvasTables.cell);
          await db.delete(CanvasTables.canvas);
        }
      },
    );
  }

  /// Live [Database] handle. Throws if [init] has not completed.
  Database get database {
    final db = _db;
    if (db == null) {
      throw StateError(
        'CanvasDatabase not initialized — call init() first', // lint-allow: hardcoded-string
      );
    }
    return db;
  }

  /// Whether the database has been opened.
  bool get isOpen => _db != null;

  /// Close the database. Idempotent — safe to call multiple times.
  Future<void> close() async {
    final db = _db;
    if (db == null) return;
    AppLogging.meshCanvas('closing canvas.db');
    _db = null;
    await db.close();
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${CanvasTables.canvas} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        canvas_id INTEGER NOT NULL,
        scope TEXT NOT NULL,
        channel_index INTEGER,
        name TEXT NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        palette_id INTEGER NOT NULL,
        status INTEGER NOT NULL,
        owner_node_num INTEGER,
        created_at_ms INTEGER NOT NULL,
        last_op_at_ms INTEGER NOT NULL,
        global_digest BLOB,
        tile_digests BLOB,
        cell_count INTEGER NOT NULL DEFAULT 0,
        UNIQUE (canvas_id, scope, channel_index)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_canvas_scope_channel
        ON ${CanvasTables.canvas} (scope, channel_index)
    ''');
    await db.execute('''
      CREATE INDEX idx_canvas_last_op_at
        ON ${CanvasTables.canvas} (last_op_at_ms DESC)
    ''');

    await db.execute('''
      CREATE TABLE ${CanvasTables.cell} (
        canvas_id INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        color INTEGER NOT NULL,
        last_ts INTEGER NOT NULL,
        last_author INTEGER NOT NULL,
        last_seq INTEGER NOT NULL,
        PRIMARY KEY (canvas_id, x, y)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${CanvasTables.pendingOp} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        canvas_id INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        color INTEGER NOT NULL,
        op_ts INTEGER NOT NULL,
        op_seq INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at_ms INTEGER NOT NULL,
        state INTEGER NOT NULL,
        last_error TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_pending_state_next_attempt
        ON ${CanvasTables.pendingOp} (state, next_attempt_at_ms)
    ''');
    await db.execute('''
      CREATE INDEX idx_pending_canvas
        ON ${CanvasTables.pendingOp} (canvas_id)
    ''');

    await db.execute('''
      CREATE TABLE ${CanvasTables.appliedOp} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        canvas_id INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        color INTEGER NOT NULL,
        op_ts INTEGER NOT NULL,
        author_node_num INTEGER NOT NULL,
        op_seq INTEGER NOT NULL,
        direction INTEGER NOT NULL,
        received_at_ms INTEGER NOT NULL,
        was_accepted INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_applied_canvas_received
        ON ${CanvasTables.appliedOp} (canvas_id, received_at_ms DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_applied_canvas_cell
        ON ${CanvasTables.appliedOp} (canvas_id, x, y, op_ts DESC)
    ''');
    // Op-layer dedupe key. The earlier (canvas_id, author, op_seq)
    // candidate was unsafe because op_seq rolls over every 256 paints
    // per author; including op_ts plus (x, y) makes the tuple genuinely
    // unique in practice. See CANVAS_V0_1.md §9.
    await db.execute('''
      CREATE INDEX idx_applied_dedupe
        ON ${CanvasTables.appliedOp}
           (canvas_id, author_node_num, op_ts, op_seq, x, y)
    ''');

    await db.execute('''
      CREATE TABLE ${CanvasTables.peerDigest} (
        canvas_id INTEGER NOT NULL,
        peer_node_num INTEGER NOT NULL,
        peer_global_digest BLOB,
        peer_tile_digests BLOB,
        peer_cell_count INTEGER,
        last_heard_at_ms INTEGER NOT NULL,
        last_sync_at_ms INTEGER,
        PRIMARY KEY (canvas_id, peer_node_num)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_peer_digest_canvas_heard
        ON ${CanvasTables.peerDigest} (canvas_id, last_heard_at_ms DESC)
    ''');

    AppLogging.meshCanvas(
      'canvas.db schema v${CanvasDbConfig.dbVersion} created',
    );
  }
}
