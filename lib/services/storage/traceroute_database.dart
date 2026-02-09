// SPDX-License-Identifier: GPL-3.0-or-later

// Traceroute Database — SQLite schema and lifecycle management.
//
// Database: traceroute_history.db
// Schema version: 1
//
// Tables:
//   - traceroute_runs: each traceroute attempt (pending or completed)
//   - traceroute_hops: individual hops within a traceroute run

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';

/// Schema version for the Traceroute SQLite database.
///
/// Bump this when adding tables, columns, or indices.
/// Migration logic runs in [_onUpgrade].
const int tracerouteSchemaVersion = 1;

/// Table and column name constants for Traceroute SQLite schema.
abstract final class TracerouteTables {
  // -- traceroute_runs --
  static const runs = 'traceroute_runs';
  static const colId = 'id';
  static const colCreatedAt = 'created_at';
  static const colTargetNodeId = 'target_node_id';
  static const colStatus = 'status';
  static const colForwardHops = 'forward_hops';
  static const colReturnHops = 'return_hops';
  static const colResponseReceived = 'response_received';
  static const colSnr = 'snr';

  // -- traceroute_hops --
  static const hops = 'traceroute_hops';
  static const colHopId = 'id';
  static const colRunId = 'run_id';
  static const colHopIndex = 'hop_index';
  static const colNodeId = 'node_id';
  static const colHopSnr = 'snr';
  static const colRssi = 'rssi';
  static const colDirection = 'direction';

  /// Status values for traceroute_runs.status
  static const statusPending = 'pending';
  static const statusCompleted = 'completed';

  /// Direction values for traceroute_hops.direction
  static const directionForward = 'forward';
  static const directionReturn = 'return';
}

/// Manages the Traceroute SQLite database lifecycle.
///
/// Handles opening, creating, upgrading, and corruption recovery.
/// Follows the same resilient pattern used by AutomationDatabase and
/// NodeDexDatabase.
class TracerouteDatabase {
  static const String _dbFileName = 'traceroute_history.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  TracerouteDatabase({String? dbPathOverride})
    : _dbPathOverride = dbPathOverride;

  /// The open database instance. Throws if not initialized.
  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError(
        'TracerouteDatabase not initialized. Call open() first.',
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
      throw StateError('TracerouteDatabase init failed permanently.');
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('TracerouteDatabase init failed.');
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
      AppLogging.storage('TracerouteDatabase: First open failed: $e');
      if (!await _attemptRecovery(path)) {
        AppLogging.storage('TracerouteDatabase: Recovery failed');
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) async {
    return openDatabase(
      path,
      version: tracerouteSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onConfigure: _onConfigure,
    );
  }

  /// Enable foreign keys before any other operations.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create all tables and indices for a fresh database.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // -- traceroute_runs --
    batch.execute('''
      CREATE TABLE ${TracerouteTables.runs} (
        ${TracerouteTables.colId} TEXT PRIMARY KEY,
        ${TracerouteTables.colCreatedAt} INTEGER NOT NULL,
        ${TracerouteTables.colTargetNodeId} INTEGER NOT NULL,
        ${TracerouteTables.colStatus} TEXT NOT NULL DEFAULT '${TracerouteTables.statusPending}',
        ${TracerouteTables.colForwardHops} INTEGER,
        ${TracerouteTables.colReturnHops} INTEGER,
        ${TracerouteTables.colResponseReceived} INTEGER NOT NULL DEFAULT 0,
        ${TracerouteTables.colSnr} REAL
      )
    ''');

    // Index on created_at for chronological queries and pruning
    batch.execute(
      'CREATE INDEX idx_runs_created_at '
      'ON ${TracerouteTables.runs}(${TracerouteTables.colCreatedAt})',
    );

    // Index on target_node_id for per-node lookups
    batch.execute(
      'CREATE INDEX idx_runs_target_node_id '
      'ON ${TracerouteTables.runs}(${TracerouteTables.colTargetNodeId})',
    );

    // -- traceroute_hops --
    batch.execute('''
      CREATE TABLE ${TracerouteTables.hops} (
        ${TracerouteTables.colHopId} TEXT PRIMARY KEY,
        ${TracerouteTables.colRunId} TEXT NOT NULL,
        ${TracerouteTables.colHopIndex} INTEGER NOT NULL,
        ${TracerouteTables.colNodeId} INTEGER NOT NULL,
        ${TracerouteTables.colHopSnr} REAL,
        ${TracerouteTables.colRssi} INTEGER,
        ${TracerouteTables.colDirection} TEXT NOT NULL,
        FOREIGN KEY(${TracerouteTables.colRunId}) REFERENCES ${TracerouteTables.runs}(${TracerouteTables.colId}) ON DELETE CASCADE
      )
    ''');

    // Index on run_id for joining hops to runs
    batch.execute(
      'CREATE INDEX idx_hops_run_id '
      'ON ${TracerouteTables.hops}(${TracerouteTables.colRunId})',
    );

    await batch.commit(noResult: true);

    AppLogging.storage(
      'TracerouteDatabase: Created schema v$version '
      '(${_tableNames().length} tables)',
    );
  }

  /// Handle schema upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'TracerouteDatabase: Upgrading v$oldVersion -> v$newVersion',
    );

    // Future migrations go here:
    // if (oldVersion < 2) { ... }
  }

  /// Handle downgrades by recreating.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'TracerouteDatabase: Downgrading v$oldVersion -> v$newVersion — '
      'recreating tables',
    );
    for (final table in _tableNames()) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _onCreate(db, newVersion);
  }

  /// Attempt corruption recovery by deleting and recreating.
  Future<bool> _attemptRecovery(String path) async {
    AppLogging.storage('TracerouteDatabase: Attempting recovery...');
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
      AppLogging.storage('TracerouteDatabase: Recovery succeeded');
      return true;
    } catch (e) {
      AppLogging.storage('TracerouteDatabase: Recovery failed: $e');
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

  List<String> _tableNames() => [TracerouteTables.hops, TracerouteTables.runs];
}
