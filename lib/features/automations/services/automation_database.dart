// SPDX-License-Identifier: GPL-3.0-or-later

// Automation Database — SQLite schema and lifecycle management.
//
// This file defines the database schema for Automation persistence
// with Cloud Sync support via an outbox pattern.
//
// Database: automations.db
// Schema version: 1
//
// Tables:
//   - automations: stores each automation as a JSON blob with metadata
//   - sync_state: key-value pairs for sync watermarks and state
//   - sync_outbox: queued mutations waiting to be pushed to Firestore

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';

/// Schema version for the Automation SQLite database.
///
/// Bump this when adding tables, columns, or indices.
/// Migration logic runs in [_onUpgrade].
const int automationSchemaVersion = 1;

/// Table and column name constants for Automation SQLite schema.
abstract final class AutomationTables {
  // -- automations --
  static const automations = 'automations';
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

/// Manages the Automation SQLite database lifecycle.
///
/// Handles opening, creating, upgrading, and corruption recovery.
/// Follows the same resilient pattern used by NodeDexDatabase.
class AutomationDatabase {
  static const String _dbFileName = 'automations.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  AutomationDatabase({String? dbPathOverride})
    : _dbPathOverride = dbPathOverride;

  /// The open database instance. Throws if not initialized.
  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError(
        'AutomationDatabase not initialized. Call open() first.',
      );
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
      throw StateError('AutomationDatabase init failed permanently.');
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('AutomationDatabase init failed.');
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
      AppLogging.storage('AutomationDatabase: First open failed: $e');
      if (!await _attemptRecovery(path)) {
        AppLogging.storage('AutomationDatabase: Recovery failed');
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) async {
    return openDatabase(
      path,
      version: automationSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  /// Create all tables and indices for a fresh database.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // -- automations --
    batch.execute('''
      CREATE TABLE ${AutomationTables.automations} (
        ${AutomationTables.colId} TEXT PRIMARY KEY,
        ${AutomationTables.colDataJson} TEXT NOT NULL,
        ${AutomationTables.colUpdatedAtMs} INTEGER NOT NULL,
        ${AutomationTables.colDeleted} INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_automations_updated '
      'ON ${AutomationTables.automations}(${AutomationTables.colUpdatedAtMs})',
    );
    batch.execute(
      'CREATE INDEX idx_automations_deleted '
      'ON ${AutomationTables.automations}(${AutomationTables.colDeleted})',
    );

    // -- sync_state --
    batch.execute('''
      CREATE TABLE ${AutomationTables.syncState} (
        ${AutomationTables.colSyncKey} TEXT PRIMARY KEY,
        ${AutomationTables.colSyncValue} TEXT NOT NULL
      )
    ''');

    // -- sync_outbox --
    batch.execute('''
      CREATE TABLE ${AutomationTables.syncOutbox} (
        ${AutomationTables.colOutboxId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AutomationTables.colOutboxEntityType} TEXT NOT NULL,
        ${AutomationTables.colOutboxEntityId} TEXT NOT NULL,
        ${AutomationTables.colOutboxOp} TEXT NOT NULL,
        ${AutomationTables.colOutboxPayloadJson} TEXT NOT NULL,
        ${AutomationTables.colOutboxUpdatedAtMs} INTEGER NOT NULL,
        ${AutomationTables.colOutboxAttemptCount} INTEGER NOT NULL DEFAULT 0,
        ${AutomationTables.colOutboxLastError} TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_outbox_entity '
      'ON ${AutomationTables.syncOutbox}'
      '(${AutomationTables.colOutboxEntityType}, ${AutomationTables.colOutboxEntityId})',
    );

    await batch.commit(noResult: true);

    AppLogging.storage(
      'AutomationDatabase: Created schema v$version '
      '(${_tableNames().length} tables)',
    );
  }

  /// Handle schema upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'AutomationDatabase: Upgrading v$oldVersion -> v$newVersion',
    );

    // if (oldVersion < 2) { ... }
  }

  /// Handle downgrades by recreating.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'AutomationDatabase: Downgrading v$oldVersion -> v$newVersion — '
      'recreating tables',
    );
    for (final table in _tableNames()) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _onCreate(db, newVersion);
  }

  /// Attempt corruption recovery by deleting and recreating.
  Future<bool> _attemptRecovery(String path) async {
    AppLogging.storage('AutomationDatabase: Attempting recovery...');
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
      AppLogging.storage('AutomationDatabase: Recovery succeeded');
      return true;
    } catch (e) {
      AppLogging.storage('AutomationDatabase: Recovery failed: $e');
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
    AutomationTables.automations,
    AutomationTables.syncState,
    AutomationTables.syncOutbox,
  ];
}
