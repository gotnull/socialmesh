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
  static const _positionHistoryTable = 'tak_position_history';
  static const _dbVersion = 3;

  /// Maximum events retained in the database.
  static const int maxEvents = 5000;

  /// Grace period (ms) after stale time before an event is purged.
  static const int staleGracePeriodMs = 300000; // 5 minutes

  Database? _db;
  final String? _testDbPath;

  TakDatabase({String? testDbPath}) : _testDbPath = testDbPath;

  /// Initialize the database and create tables if needed.
  Future<void> init() async {
    if (_db != null) {
      AppLogging.tak('Database already initialized, skipping');
      return;
    }

    AppLogging.tak('Initializing TAK database...');
    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, _dbName);
    }
    AppLogging.tak('Database path: $dbPath');

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        AppLogging.tak('Creating TAK events database v$version');
        await _createTables(db);
        AppLogging.tak('TAK events database tables created');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.tak(
          'Upgrading TAK events database v$oldVersion -> v$newVersion',
        );
        if (oldVersion < 2) {
          await _createPositionHistoryTable(db);
          AppLogging.tak('Migration v1->v2: created position history table');
        }
        if (oldVersion < 3) {
          await _migrateV2ToV3(db);
          AppLogging.tak(
            'Migration v2->v3: deduplicated rows, added UNIQUE(uid, type)',
          );
        }
      },
    );
    AppLogging.tak('TAK database initialized successfully');
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
        raw_payload_json TEXT,
        UNIQUE(uid, type)
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

    // Position history table (added in v2, also created for fresh installs)
    await _createPositionHistoryTable(db);
  }

  /// Migration v2 -> v3: deduplicate existing rows and add UNIQUE constraint.
  ///
  /// SQLite does not support ADD CONSTRAINT, so we recreate the table.
  Future<void> _migrateV2ToV3(Database db) async {
    // 1. Create a clean table with the UNIQUE constraint
    await db.execute('''
      CREATE TABLE ${_tableName}_v3 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        type TEXT NOT NULL,
        callsign TEXT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        time_utc INTEGER NOT NULL,
        stale_utc INTEGER NOT NULL,
        received_utc INTEGER NOT NULL,
        raw_payload_json TEXT,
        UNIQUE(uid, type)
      )
    ''');

    // 2. Copy deduplicated rows (keep the newest received_utc per uid+type)
    await db.execute('''
      INSERT OR REPLACE INTO ${_tableName}_v3
        (uid, type, callsign, lat, lon, time_utc, stale_utc, received_utc, raw_payload_json)
      SELECT uid, type, callsign, lat, lon, time_utc, stale_utc, received_utc, raw_payload_json
      FROM $_tableName
      WHERE id IN (
        SELECT id FROM $_tableName t1
        WHERE t1.received_utc = (
          SELECT MAX(t2.received_utc) FROM $_tableName t2
          WHERE t2.uid = t1.uid AND t2.type = t1.type
        )
        GROUP BY t1.uid, t1.type
      )
    ''');

    // 3. Drop old table and rename
    await db.execute('DROP TABLE $_tableName');
    await db.execute('ALTER TABLE ${_tableName}_v3 RENAME TO $_tableName');

    // 4. Recreate indexes
    await db.execute('CREATE INDEX idx_tak_uid ON $_tableName (uid)');
    await db.execute('CREATE INDEX idx_tak_type ON $_tableName (type)');
    await db.execute(
      'CREATE INDEX idx_tak_received ON $_tableName (received_utc DESC)',
    );
    await db.execute('CREATE INDEX idx_tak_stale ON $_tableName (stale_utc)');

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName',
    );
    final remaining = Sqflite.firstIntValue(countResult) ?? 0;
    AppLogging.tak(
      'v2->v3 migration complete: $remaining deduplicated rows remain',
    );
  }

  Future<void> _createPositionHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_positionHistoryTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        time_utc INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tph_uid_time
      ON $_positionHistoryTable (uid, time_utc DESC)
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
      AppLogging.tak(
        'DB upsert (update): uid=${event.uid}, type=${event.type}',
      );
    } else {
      await db.insert(_tableName, event.toDbRow());
      AppLogging.tak(
        'DB upsert (insert): uid=${event.uid}, type=${event.type}, '
        'callsign=${event.callsign ?? "none"}',
      );
    }
  }

  /// Insert a batch of events (used for snapshot backfill).
  ///
  /// Uses INSERT OR REPLACE which triggers on the UNIQUE(uid, type)
  /// constraint, ensuring no duplicate rows accumulate.
  Future<void> insertBatch(List<TakEvent> events) async {
    AppLogging.tak('DB insertBatch: ${events.length} events');
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
    AppLogging.tak('DB insertBatch committed: ${events.length} events');
  }

  /// Get the latest events, ordered by received time descending.
  Future<List<TakEvent>> getLatestEvents({int limit = 100}) async {
    final rows = await _database.query(
      _tableName,
      orderBy: 'received_utc DESC',
      limit: limit,
    );
    AppLogging.tak('DB getLatestEvents: ${rows.length} rows (limit=$limit)');
    return rows.map(TakEvent.fromDbRow).toList();
  }

  /// Get non-stale events ordered by received time descending.
  ///
  /// Returns events whose stale time has not yet passed, useful for
  /// populating the active entity list on startup.
  Future<List<TakEvent>> getActiveEvents({int limit = 500}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await _database.query(
      _tableName,
      where: 'stale_utc > ?',
      whereArgs: [nowMs],
      orderBy: 'received_utc DESC',
      limit: limit,
    );
    AppLogging.tak('DB getActiveEvents: ${rows.length} rows (limit=$limit)');
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
    final removed = await _database.delete(
      _tableName,
      where: 'stale_utc < ?',
      whereArgs: [cutoff],
    );
    if (removed > 0) {
      AppLogging.tak('DB cleanupStale: removed $removed stale events');
    }
    return removed;
  }

  /// Remove oldest events if count exceeds [maxEvents].
  Future<int> enforceMaxEvents() async {
    final total = await count();
    if (total <= maxEvents) return 0;

    final excess = total - maxEvents;
    AppLogging.tak(
      'DB enforceMaxEvents: total=$total, max=$maxEvents, removing $excess',
    );
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
    AppLogging.tak('DB clearing all events');
    await _database.delete(_tableName);
    AppLogging.tak('DB cleared');
  }

  // ---------------------------------------------------------------------------
  // Position history (v2)
  // ---------------------------------------------------------------------------

  /// Maximum position history points per entity.
  static const int maxPositionHistoryPerUid = 500;

  /// Record a position snapshot for trail rendering.
  Future<void> insertPositionHistory({
    required String uid,
    required double lat,
    required double lon,
    required int timeUtcMs,
  }) async {
    if (lat == 0.0 && lon == 0.0) return;

    await _database.insert(_positionHistoryTable, {
      'uid': uid,
      'lat': lat,
      'lon': lon,
      'time_utc': timeUtcMs,
    });

    // Enforce max points per UID
    await _trimPositionHistory(uid);
  }

  /// Get position history for an entity, newest first.
  Future<List<PositionHistoryPoint>> getPositionHistory(
    String uid, {
    int limit = 50,
  }) async {
    final rows = await _database.query(
      _positionHistoryTable,
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'time_utc DESC',
      limit: limit,
    );
    return rows.map(PositionHistoryPoint.fromRow).toList();
  }

  Future<void> _trimPositionHistory(String uid) async {
    final countResult = await _database.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_positionHistoryTable WHERE uid = ?',
      [uid],
    );
    final total = Sqflite.firstIntValue(countResult) ?? 0;
    if (total <= maxPositionHistoryPerUid) return;

    final excess = total - maxPositionHistoryPerUid;
    await _database.rawDelete(
      '''DELETE FROM $_positionHistoryTable WHERE id IN (
        SELECT id FROM $_positionHistoryTable
        WHERE uid = ? ORDER BY time_utc ASC LIMIT ?
      )''',
      [uid, excess],
    );
    AppLogging.tak(
      'Position history trimmed for uid=$uid: '
      'kept $maxPositionHistoryPerUid of $total points',
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    AppLogging.tak('Closing TAK database');
    await _db?.close();
    _db = null;
  }
}

/// A single position snapshot in the movement trail.
class PositionHistoryPoint {
  final double lat;
  final double lon;
  final int timeUtcMs;

  const PositionHistoryPoint({
    required this.lat,
    required this.lon,
    required this.timeUtcMs,
  });

  factory PositionHistoryPoint.fromRow(Map<String, dynamic> row) {
    return PositionHistoryPoint(
      lat: (row['lat'] as num).toDouble(),
      lon: (row['lon'] as num).toDouble(),
      timeUtcMs: row['time_utc'] as int,
    );
  }
}
