// SPDX-License-Identifier: GPL-3.0-or-later

// Widget Database — SQLite schema and lifecycle management.
//
// This file defines the database schema for custom Widget persistence
// with Cloud Sync support via an outbox pattern.
//
// Database: widgets.db
// Schema version: 1
//
// Tables:
//   - widgets: stores each custom widget schema as a JSON blob with metadata
//   - sync_state: key-value pairs for sync watermarks and state
//   - sync_outbox: queued mutations waiting to be pushed to Firestore

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';

/// Schema version for the Widget SQLite database.
///
/// Bump this when adding tables, columns, or indices.
/// Migration logic runs in [_onUpgrade].
const int widgetSchemaVersion = 1;

/// Table and column name constants for Widget SQLite schema.
abstract final class WidgetTables {
  // -- widgets --
  static const widgets = 'widgets';
  static const colId = 'id';
  static const colDataJson = 'data_json';
  static const colUpdatedAtMs = 'updated_at_ms';
  static const colDeleted = 'deleted';

  // -- sync_state --
  static const syncState = 'sync_state';
  static const colSyncKey = 'key';
  static const colSyncValue = 'value';

  // -- sync_outbox --
  static const syncOutbox = 'sync_outbox';
  static const colOutboxId = 'id';
  static const colOutboxEntityType = 'entity_type';
  static const colOutboxEntityId = 'entity_id';
  static const colOutboxOp = 'op';
  static const colOutboxPayloadJson = 'payload_json';
  static const colOutboxUpdatedAtMs = 'updated_at_ms';
  static const colOutboxAttemptCount = 'attempt_count';
  static const colOutboxLastError = 'last_error';
}

/// Manages the Widget SQLite database lifecycle.
///
/// Handles opening, creating, upgrading, and corruption recovery.
/// Follows the same resilient pattern used by NodeDexDatabase.
class WidgetDatabase {
  static const String _dbFileName = 'widgets.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  WidgetDatabase({String? dbPathOverride}) : _dbPathOverride = dbPathOverride;

  /// The open database instance. Throws if not initialized.
  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('WidgetDatabase not initialized. Call open() first.');
    }
    return _db!;
  }

  /// Whether the database is open and ready.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Open the database, creating tables if needed.
  ///
  /// Safe to call multiple times. Uses a completer to prevent
  /// concurrent initialization.
  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_initFailed) {
      throw StateError('WidgetDatabase init failed permanently.');
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('WidgetDatabase init failed.');
      }
      return result;
    }

    _initCompleter = Completer<Database?>();

    try {
      await _openSafe();
      _initCompleter!.complete(_db);
      return _db!;
    } catch (e) {
      _initCompleter!.complete(null);
      _initFailed = true;
      rethrow;
    }
  }

  Future<void> _openSafe() async {
    final path = _dbPathOverride ?? await _defaultPath();

    try {
      _db = await _attemptOpen(path);
    } catch (e) {
      AppLogging.storage('WidgetDatabase: First open failed: $e');
      if (!await _attemptRecovery(path)) {
        AppLogging.storage('WidgetDatabase: Recovery failed');
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) async {
    return openDatabase(
      path,
      version: widgetSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  /// Create all tables and indices for a fresh database.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // -- widgets --
    batch.execute('''
      CREATE TABLE ${WidgetTables.widgets} (
        ${WidgetTables.colId} TEXT PRIMARY KEY,
        ${WidgetTables.colDataJson} TEXT NOT NULL,
        ${WidgetTables.colUpdatedAtMs} INTEGER NOT NULL,
        ${WidgetTables.colDeleted} INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_widgets_updated '
      'ON ${WidgetTables.widgets}(${WidgetTables.colUpdatedAtMs})',
    );
    batch.execute(
      'CREATE INDEX idx_widgets_deleted '
      'ON ${WidgetTables.widgets}(${WidgetTables.colDeleted})',
    );

    // -- sync_state --
    batch.execute('''
      CREATE TABLE ${WidgetTables.syncState} (
        ${WidgetTables.colSyncKey} TEXT PRIMARY KEY,
        ${WidgetTables.colSyncValue} TEXT NOT NULL
      )
    ''');

    // -- sync_outbox --
    batch.execute('''
      CREATE TABLE ${WidgetTables.syncOutbox} (
        ${WidgetTables.colOutboxId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${WidgetTables.colOutboxEntityType} TEXT NOT NULL,
        ${WidgetTables.colOutboxEntityId} TEXT NOT NULL,
        ${WidgetTables.colOutboxOp} TEXT NOT NULL,
        ${WidgetTables.colOutboxPayloadJson} TEXT NOT NULL,
        ${WidgetTables.colOutboxUpdatedAtMs} INTEGER NOT NULL,
        ${WidgetTables.colOutboxAttemptCount} INTEGER NOT NULL DEFAULT 0,
        ${WidgetTables.colOutboxLastError} TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_widget_outbox_entity '
      'ON ${WidgetTables.syncOutbox}'
      '(${WidgetTables.colOutboxEntityType}, ${WidgetTables.colOutboxEntityId})',
    );

    await batch.commit(noResult: true);

    AppLogging.storage(
      'WidgetDatabase: Created schema v$version '
      '(${_tableNames().length} tables)',
    );
  }

  /// Handle schema upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'WidgetDatabase: Upgrading v$oldVersion -> v$newVersion',
    );

    // if (oldVersion < 2) { ... }
  }

  /// Handle downgrades by recreating.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'WidgetDatabase: Downgrading v$oldVersion -> v$newVersion — '
      'recreating tables',
    );
    for (final table in _tableNames()) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _onCreate(db, newVersion);
  }

  /// Attempt corruption recovery by deleting and recreating.
  Future<bool> _attemptRecovery(String path) async {
    AppLogging.storage('WidgetDatabase: Attempting recovery...');
    try {
      await _db?.close();
      _db = null;

      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final f = File('$path$suffix');
        if (await f.exists()) await f.delete();
      }

      _db = await _attemptOpen(path);
      AppLogging.storage('WidgetDatabase: Recovery succeeded');
      return true;
    } catch (e) {
      AppLogging.storage('WidgetDatabase: Recovery failed: $e');
      return false;
    }
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
    _initFailed = false;
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  List<String> _tableNames() => [
    WidgetTables.widgets,
    WidgetTables.syncState,
    WidgetTables.syncOutbox,
  ];
}
