// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SQLite-backed storage for operations progress + an optional append-only
// event log for debugging / replay.
//
// Schema rules (from `lib/services/storage/CLAUDE.md`):
//  - never alter an existing column on a live build
//  - new columns are nullable
//  - bump version + add an onUpgrade migration

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';

abstract final class OperationsTables {
  static const progress = 'operations_progress';
  static const colOperationId = 'operation_id';
  static const colObjectiveProgressJson = 'objective_progress_json';
  static const colDedupedKeysJson = 'deduped_keys_json';
  static const colCompletedAtMs = 'completed_at_ms';
  static const colClaimedAtMs = 'claimed_at_ms';
  static const colUpdatedAtMs = 'updated_at_ms';
  static const colVersion = 'version';

  static const eventLog = 'operations_event_log';
  static const colEventId = 'id';
  static const colEventOperationId = 'operation_id';
  static const colEventType = 'event_type';
  static const colEventDedupeKey = 'dedupe_key';
  static const colEventObjectiveId = 'objective_id';
  static const colEventDelta = 'delta';
  static const colEventTsMs = 'ts_ms';
  static const colEventPayloadJson = 'payload_json';
}

/// Schema version. Bump when adding columns; add the matching migration
/// in `_onUpgrade`.
const int operationsSchemaVersion = 1;

/// Default DB filename. Tests can override via [OperationsDatabase].
const String _defaultDbName = 'operations.db';

/// Database wrapper with completer-guarded init mirroring NodeDexDatabase.
class OperationsDatabase {
  /// Optional override path used in tests (in-memory or temp dir).
  final String? testDbPath;

  Database? _db;
  Future<Database>? _opening;

  OperationsDatabase({this.testDbPath});

  /// Returns the opened database, opening it on first call.
  Future<Database> get database async {
    if (_db != null) return _db!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      final path = testDbPath ?? await _resolveDefaultPath();
      AppLogging.operations('OPERATIONS_INIT path=$path');
      final db = await openDatabase(
        path,
        version: operationsSchemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      _db = db;
      return db;
    } catch (e) {
      AppLogging.operations('OPERATIONS_PERSIST_FAILED open error=$e');
      rethrow;
    }
  }

  Future<String> _resolveDefaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _defaultDbName);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA journal_mode=WAL');
    await db.execute('PRAGMA foreign_keys=ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE ${OperationsTables.progress} (
        ${OperationsTables.colOperationId} TEXT PRIMARY KEY,
        ${OperationsTables.colObjectiveProgressJson} TEXT NOT NULL,
        ${OperationsTables.colDedupedKeysJson} TEXT NOT NULL,
        ${OperationsTables.colCompletedAtMs} INTEGER,
        ${OperationsTables.colClaimedAtMs} INTEGER,
        ${OperationsTables.colUpdatedAtMs} INTEGER NOT NULL,
        ${OperationsTables.colVersion} INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute('''
      CREATE TABLE ${OperationsTables.eventLog} (
        ${OperationsTables.colEventId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${OperationsTables.colEventOperationId} TEXT NOT NULL,
        ${OperationsTables.colEventType} TEXT NOT NULL,
        ${OperationsTables.colEventDedupeKey} TEXT NOT NULL,
        ${OperationsTables.colEventObjectiveId} TEXT,
        ${OperationsTables.colEventDelta} INTEGER NOT NULL DEFAULT 0,
        ${OperationsTables.colEventTsMs} INTEGER NOT NULL,
        ${OperationsTables.colEventPayloadJson} TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_operations_event_log_op_ts '
      'ON ${OperationsTables.eventLog} '
      '(${OperationsTables.colEventOperationId}, ${OperationsTables.colEventTsMs})',
    );
    await batch.commit(noResult: true);
    AppLogging.operations(
      'OPERATIONS_INIT schema_created version=$operationsSchemaVersion',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.operations(
      'OPERATIONS_INIT migrate from=$oldVersion to=$newVersion',
    );
    // Future migrations land here. New columns must be nullable; never
    // ALTER an existing column.
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
      _opening = null;
    }
  }
}
