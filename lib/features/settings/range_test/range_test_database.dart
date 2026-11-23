// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../../../core/radio_scope.dart';
import '../../../services/storage/encrypted_database.dart';
import 'range_test_models.dart';

/// Recorded Range Test sessions and their readings. Encrypted because each
/// reading holds the receiver's and the sender's positions; radio-scoped
/// because the readings were heard through one radio.
class RangeTestDatabase {
  static const _dbName = 'range_test.db';
  static const _sessionsTable = 'range_test_sessions';
  static const _readingsTable = 'range_test_readings';
  static const _dbVersion = 1;

  Database? _db;
  Future<void>? _opening;
  final String? _testDbPath;

  RangeTestDatabase({this._testDbPath});

  /// Opens the database once; concurrent callers share the same open.
  Future<void> init() => _opening ??= _open();

  Future<void> _open() async {
    final dbPath =
        _testDbPath ?? await RadioScope.instance.databasePath(_dbName);
    AppLogging.settings('Initializing range test database: $dbPath');
    _db = await openEncryptedDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_sessionsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at_ms INTEGER NOT NULL,
            ended_at_ms INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE $_readingsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            received_at_ms INTEGER NOT NULL,
            sender_node_num INTEGER NOT NULL,
            sender_name TEXT,
            packet_id INTEGER NOT NULL,
            sequence INTEGER,
            payload TEXT NOT NULL,
            rx_snr REAL,
            rx_rssi INTEGER,
            via_mqtt INTEGER NOT NULL DEFAULT 0,
            rx_latitude REAL,
            rx_longitude REAL,
            rx_altitude INTEGER,
            rx_position_source TEXT,
            sender_latitude REAL,
            sender_longitude REAL,
            distance_m REAL,
            UNIQUE (session_id, sender_node_num, packet_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_range_test_readings_session '
          'ON $_readingsTable (session_id, received_at_ms)',
        );
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('RangeTestDatabase not initialized - call init() first');
    }
    return db;
  }

  Future<RangeTestSession> createSession(DateTime startedAt) async {
    final id = await _database.insert(_sessionsTable, {
      'started_at_ms': startedAt.millisecondsSinceEpoch,
    });
    return RangeTestSession(
      id: id,
      startedAt: startedAt,
      endedAt: null,
      readingCount: 0,
    );
  }

  Future<void> endSession(int sessionId, DateTime endedAt) async {
    await _database.update(
      _sessionsTable,
      {'ended_at_ms': endedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Ends every session left open, which happens when the app stopped while
  /// recording. A session ends at its last reading, or at its start when it
  /// recorded nothing.
  Future<void> endOpenSessions() async {
    final closed = await _database.rawUpdate('''
      UPDATE $_sessionsTable
      SET ended_at_ms = COALESCE(
        (SELECT MAX(received_at_ms) FROM $_readingsTable
         WHERE session_id = $_sessionsTable.id),
        started_at_ms
      )
      WHERE ended_at_ms IS NULL
    ''');
    if (closed > 0) {
      AppLogging.settings('Range test: ended $closed interrupted session(s)');
    }
  }

  /// Every session with its reading count, newest first.
  Future<List<RangeTestSession>> sessions() async {
    final rows = await _database.rawQuery('''
      SELECT s.id, s.started_at_ms, s.ended_at_ms, COUNT(r.id) AS reading_count
      FROM $_sessionsTable s
      LEFT JOIN $_readingsTable r ON r.session_id = s.id
      GROUP BY s.id
      ORDER BY s.started_at_ms DESC, s.id DESC
    ''');
    return rows.map(RangeTestSession.fromMap).toList();
  }

  /// A session's readings in the order they were received.
  Future<List<RangeTestReading>> readings(int sessionId) async {
    final rows = await _database.query(
      _readingsTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'received_at_ms ASC, id ASC',
    );
    return rows.map(RangeTestReading.fromMap).toList();
  }

  /// Stores [reading] and returns true, or returns false when the session
  /// already holds that packet from that sender.
  Future<bool> insertReading(RangeTestReading reading) {
    return _database.transaction((txn) async {
      final existing = await txn.query(
        _readingsTable,
        columns: ['id'],
        where: 'session_id = ? AND sender_node_num = ? AND packet_id = ?',
        whereArgs: [reading.sessionId, reading.senderNodeNum, reading.packetId],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      await txn.insert(_readingsTable, reading.toMap());
      return true;
    });
  }

  Future<void> deleteSession(int sessionId) async {
    await _database.transaction((txn) async {
      await txn.delete(
        _readingsTable,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(_sessionsTable, where: 'id = ?', whereArgs: [sessionId]);
    });
  }

  Future<void> close() async {
    await _opening;
    await _db?.close();
    _db = null;
    _opening = null;
  }
}
