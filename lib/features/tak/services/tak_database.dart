// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/tak_event.dart';

/// SQLite-backed storage for TAK/CoT events received from the gateway.
///
/// Schema mirrors the gateway's normalized JSON model.
/// Cleanup runs on [cleanupStale] to remove expired events.
class TakDatabase {
  static const _dbName = 'tak_events.db';
  static const _tableName = 'tak_cot_events';
  static const _dbVersion = 1;

  /// Maximum events retained in the database.
  static const int maxEvents = 5000;

  /// Grace period (ms) after stale time before an event is purged.
  static const int staleGracePeriodMs = 300000; // 5 minutes

  Database? _db;
  final String? _testDbPath;

  TakDatabase({String? testDbPath}) : _testDbPath = testDbPath;

  /// Initialize the database and create tables if needed.
  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, _dbName);
    }

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        AppLogging.storage('Creating TAK events database v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage(
          'Upgrading TAK events database v$oldVersion -> v$newVersion',
        );
      },
    );
  }

  Database get _database {
    if (_db == null) {
      throw StateError('TakDatabase not initialized \u2014 call init() first');
    }
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        type TEXT NOT NULL,
        callsign TEXT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        time_utc INTEGER NOT NULL,
        stale_utc INTEGER NOT NULL,
        received_utc INTEGER NOT NULL,
        raw_payload_json TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_tak_uid ON $_tableName (uid)
    ''');

    await db.execute('''
      CREATE INDEX idx_tak_type ON $_tableName (type)
    ''');

    await db.execute('''
      CREATE INDEX idx_tak_received ON $_tableName (received_utc DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_tak_stale ON $_tableName (stale_utc)
    ''');
  }

  /// Insert or update a TAK event.
  /// Uses uid+type as a logical key — updates the existing row if present.
  Future<void> upsert(TakEvent event) async {
    final db = _database;
    // Check for existing row with same uid+type
    final existing = await db.query(
      _tableName,
      where: 'uid = ? AND type = ?',
      whereArgs: [event.uid, event.type],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        _tableName,
        event.toDbRow(),
        where: 'uid = ? AND type = ?',
        whereArgs: [event.uid, event.type],
      );
    } else {
      await db.insert(_tableName, event.toDbRow());
    }
  }

  /// Insert a batch of events (used for snapshot backfill).
  Future<void> insertBatch(List<TakEvent> events) async {
    final db = _database;
    final batch = db.batch();
    for (final event in events) {
      batch.rawInsert(
        '''INSERT OR REPLACE INTO $_tableName
           (uid, type, callsign, lat, lon, time_utc, stale_utc, received_utc, raw_payload_json)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          event.uid,
          event.type,
          event.callsign,
          event.lat,
          event.lon,
          event.timeUtcMs,
          event.staleUtcMs,
          event.receivedUtcMs,
          event.rawPayloadJson,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get the latest events, ordered by received time descending.
  Future<List<TakEvent>> getLatestEvents({int limit = 100}) async {
    final rows = await _database.query(
      _tableName,
      orderBy: 'received_utc DESC',
      limit: limit,
    );
    return rows.map(TakEvent.fromDbRow).toList();
  }

  /// Get a single event by uid and type.
  Future<TakEvent?> getByUidAndType(String uid, String type) async {
    final rows = await _database.query(
      _tableName,
      where: 'uid = ? AND type = ?',
      whereArgs: [uid, type],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TakEvent.fromDbRow(rows.first);
  }

  /// Count of all events in the database.
  Future<int> count() async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Remove events whose stale time + grace period has passed.
  Future<int> cleanupStale() async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - staleGracePeriodMs;
    return _database.delete(
      _tableName,
      where: 'stale_utc < ?',
      whereArgs: [cutoff],
    );
  }

  /// Remove oldest events if count exceeds [maxEvents].
  Future<int> enforceMaxEvents() async {
    final total = await count();
    if (total <= maxEvents) return 0;

    final excess = total - maxEvents;
    return _database.rawDelete(
      '''
      DELETE FROM $_tableName WHERE id IN (
        SELECT id FROM $_tableName ORDER BY received_utc ASC LIMIT ?
      )
    ''',
      [excess],
    );
  }

  /// Clear all events.
  Future<void> clear() async {
    await _database.delete(_tableName);
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
