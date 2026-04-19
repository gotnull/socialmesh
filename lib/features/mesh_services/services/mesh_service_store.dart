// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Local SQLite store for mesh service instances.
///
/// Persists user-created service instances across app restarts.
/// Bounded to [maxInstances] rows. Expired instances are cleaned
/// up periodically.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/mesh_service_instance.dart';

/// Maximum locally persisted service instances.
const int _maxInstances = 50;

/// SQLite store for [MeshServiceInstance].
class MeshServiceStore {
  /// Optional path override — used by tests to inject in-memory paths.
  final String? _dbPathOverride;

  Database? _db;

  /// Create a store. Pass [dbPathOverride] in tests to use an in-memory DB.
  MeshServiceStore({String? dbPathOverride}) : _dbPathOverride = dbPathOverride;

  /// Open or create the database.
  Future<void> open() async {
    if (_db != null) return;
    final String dbPath;
    if (_dbPathOverride != null) {
      dbPath = _dbPathOverride;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(
        dir.path,
        'mesh_services.db',
      ); // lint-allow: hardcoded-string
    }

    _db = await openDatabase(
      dbPath,
      version: 2,
      onConfigure: (db) async {
        final walResult = await db.rawQuery('PRAGMA journal_mode=WAL');
        // Only enforce WAL for on-disk databases. In-memory databases
        // (used in tests via _dbPathOverride) do not support WAL mode.
        if (_dbPathOverride == null) {
          assert(
            walResult.isNotEmpty && walResult.first['journal_mode'] == 'wal',
            'WAL mode not active',
          ); // lint-allow: hardcoded-string
        }
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateFromV1(db);
        }
      },
    );

    AppLogging.mrrp(
      'MESH_SERVICE_STORE: opened mesh_services.db', // lint-allow: hardcoded-string
    );
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Insert a new instance. Returns true on success.
  Future<bool> insert(MeshServiceInstance instance) async {
    final db = _db;
    if (db == null) return false;

    // Enforce max instances by evicting oldest expired first.
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM service_instances'),
    );
    if (count != null && count >= _maxInstances) {
      await _evictOldest(db);
    }

    await db.insert(
      'service_instances',
      instance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    AppLogging.mrrp(
      'MESH_SERVICE_STORE: inserted ${instance.instanceId} '
      '(${instance.canonicalType.name})', // lint-allow: hardcoded-string
    );
    return true;
  }

  /// Update an existing instance.
  Future<void> update(MeshServiceInstance instance) async {
    final db = _db;
    if (db == null) return;

    await db.update(
      'service_instances',
      instance.toMap(),
      where: 'instance_id = ?',
      whereArgs: [instance.instanceId],
    );
  }

  /// Delete an instance by ID.
  Future<void> delete(String instanceId) async {
    final db = _db;
    if (db == null) return;

    await db.delete(
      'service_instances',
      where: 'instance_id = ?',
      whereArgs: [instanceId],
    );
  }

  /// Get a single instance by ID.
  Future<MeshServiceInstance?> get(String instanceId) async {
    final db = _db;
    if (db == null) return null;

    final rows = await db.query(
      'service_instances',
      where: 'instance_id = ?',
      whereArgs: [instanceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeshServiceInstance.fromMap(rows.first);
  }

  /// Get all local instances, ordered by creation time (newest first).
  Future<List<MeshServiceInstance>> getAll() async {
    final db = _db;
    if (db == null) return const [];

    final rows = await db.query(
      'service_instances',
      where: 'is_local = 1',
      orderBy: 'created_at DESC',
    );
    return rows.map(MeshServiceInstance.fromMap).toList();
  }

  /// Get only active (non-expired, non-stopped) local instances.
  Future<List<MeshServiceInstance>> getActive() async {
    final db = _db;
    if (db == null) return const [];

    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'service_instances',
      where:
          'is_local = 1 AND status = ? AND '
          '(expires_at IS NULL OR expires_at > ?)',
      whereArgs: ['active', now],
      orderBy: 'created_at DESC',
    );
    return rows.map(MeshServiceInstance.fromMap).toList();
  }

  /// Mark expired instances as expired in the database.
  Future<int> markExpired() async {
    final db = _db;
    if (db == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      'service_instances',
      {'status': 'expired'},
      where: 'status = ? AND expires_at IS NOT NULL AND expires_at <= ?',
      whereArgs: ['active', now],
    );
  }

  /// Count of active local instances.
  Future<int> activeCount() async {
    final db = _db;
    if (db == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM service_instances '
            'WHERE is_local = 1 AND status = ? AND '
            '(expires_at IS NULL OR expires_at > ?)',
            ['active', now],
          ),
        ) ??
        0;
  }

  Future<void> _evictOldest(Database db) async {
    // Evict oldest expired first, then oldest stopped, then oldest active.
    await db.delete(
      'service_instances',
      where:
          'instance_id = (SELECT instance_id FROM service_instances '
          'ORDER BY CASE status '
          "WHEN 'expired' THEN 0 "
          "WHEN 'stopped' THEN 1 "
          'ELSE 2 END, created_at ASC LIMIT 1)',
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_instances (
        instance_id TEXT PRIMARY KEY,
        canonical_type TEXT NOT NULL,
        preset_id TEXT,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        expires_at INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        config TEXT NOT NULL DEFAULT '{}',
        is_local INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_instances_status
      ON service_instances (status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_instances_expires
      ON service_instances (expires_at)
    ''');
  }

  Future<void> _migrateFromV1(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE service_instances_v2 (
          instance_id TEXT PRIMARY KEY,
          canonical_type TEXT NOT NULL,
          preset_id TEXT,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          expires_at INTEGER,
          status TEXT NOT NULL DEFAULT 'active',
          config TEXT NOT NULL DEFAULT '{}',
          is_local INTEGER NOT NULL DEFAULT 1
        )
      ''');

      final legacyRows = await txn.query('service_instances');
      for (final row in legacyRows) {
        final migrated = MeshServiceInstance.fromMap(row).toMap();
        await txn.insert(
          'service_instances_v2',
          migrated,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.execute('DROP TABLE service_instances');
      await txn.execute(
        'ALTER TABLE service_instances_v2 RENAME TO service_instances',
      );
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_instances_status
        ON service_instances (status)
      ''');
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_instances_expires
        ON service_instances (expires_at)
      ''');
    });
  }
}
