// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:sqflite/sqflite.dart';

import '../../../core/radio_scope.dart';
import '../../../services/storage/encrypted_database.dart';

import '../../../core/logging.dart';
import '../models/mesh_waypoint.dart';

/// SQLite-backed storage for shared Meshtastic waypoints (WAYPOINT_APP).
///
/// Keyed on the wire `id` (u32) so an edit broadcast replaces the existing
/// row. Expired waypoints (real expiry in the past) are pruned by
/// [cleanupExpired]; the `expire == 1` delete sentinel is handled on the event
/// path, never persisted.
class WaypointDatabase {
  static const _dbName = 'waypoints.db';
  static const _tableName = 'mesh_waypoints';
  static const _dbVersion = 1;

  Database? _db;
  final String? _testDbPath;

  WaypointDatabase({this._testDbPath});

  /// Initialize the database and create tables if needed.
  Future<void> init() async {
    if (_db != null) {
      AppLogging.map('Waypoint database already initialized, skipping');
      return;
    }

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      dbPath = await RadioScope.instance.databasePath(_dbName);
    }
    AppLogging.map('Initializing waypoint database: $dbPath');

    _db = await openEncryptedDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        final walResult = await db.rawQuery('PRAGMA journal_mode=WAL');
        // In-memory databases (tests) do not support WAL.
        if (_testDbPath == null) {
          assert(
            walResult.isNotEmpty && walResult.first['journal_mode'] == 'wal',
            'WAL mode not active',
          ); // lint-allow: hardcoded-string
        }
      },
      onCreate: (db, version) async {
        AppLogging.map('Creating waypoint database v$version');
        await _createTables(db);
      },
    );
    AppLogging.map('Waypoint database initialized');
  }

  Database get _database {
    if (_db == null) {
      throw StateError('WaypointDatabase not initialized — call init() first');
    }
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        expire INTEGER NOT NULL DEFAULT 0,
        locked_to INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        icon INTEGER NOT NULL DEFAULT 0,
        source_node_num INTEGER NOT NULL DEFAULT 0,
        received_at_ms INTEGER NOT NULL,
        is_mine INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_waypoint_expire ON $_tableName (expire)',
    );
    await db.execute(
      'CREATE INDEX idx_waypoint_received ON $_tableName (received_at_ms DESC)',
    );
  }

  /// Insert or replace a waypoint, keyed on [MeshWaypoint.id].
  Future<void> upsert(MeshWaypoint waypoint) async {
    await _database.insert(
      _tableName,
      waypoint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogging.map('DB upsert waypoint id=${waypoint.id}');
  }

  /// All waypoints, newest first. Pass [includeExpired] = false (default) to
  /// drop waypoints whose real expiry has passed.
  Future<List<MeshWaypoint>> getAll({bool includeExpired = false}) async {
    final rows = await _database.query(
      _tableName,
      orderBy: 'received_at_ms DESC',
    );
    final all = rows.map(MeshWaypoint.fromMap).toList();
    if (includeExpired) return all;
    return all.where((w) => !w.isExpired).toList();
  }

  /// Fetch a single waypoint by wire id.
  Future<MeshWaypoint?> getById(int id) async {
    final rows = await _database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeshWaypoint.fromMap(rows.first);
  }

  /// Delete a single waypoint by wire id.
  Future<void> deleteById(int id) async {
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    AppLogging.map('DB delete waypoint id=$id');
  }

  /// Remove waypoints whose real expiry (expire > 1) has passed. Returns the
  /// number of rows removed.
  Future<int> cleanupExpired() async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final removed = await _database.delete(
      _tableName,
      where: 'expire > 1 AND expire <= ?',
      whereArgs: [nowSec],
    );
    if (removed > 0) {
      AppLogging.map('DB cleanupExpired: removed $removed waypoints');
    }
    return removed;
  }

  /// Remove all waypoints.
  Future<void> clear() async {
    await _database.delete(_tableName);
    AppLogging.map('DB cleared all waypoints');
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
