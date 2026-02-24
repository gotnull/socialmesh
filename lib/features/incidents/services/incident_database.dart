// SPDX-License-Identifier: GPL-3.0-or-later

// Incident Database — SQLite schema and lifecycle management.
//
// This file defines the database schema for the incident lifecycle engine.
// Tables: incidents, incident_transitions, incident_field_reports.
//
// Database: incidents.db
// Schema version: 1
//
// Spec: INCIDENT_LIFECYCLE.md (Sprint 007).

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';

/// Schema version for the incidents SQLite database.
///
/// Bump this when adding tables, columns, or indices.
/// Migration logic runs in [_onUpgrade].
const int incidentSchemaVersion = 1;

/// Manages the incidents SQLite database lifecycle.
///
/// Handles opening, creating, upgrading, and corruption recovery.
/// Follows the same resilient pattern used by NodeDexDatabase.
class IncidentDatabase {
  static const String _dbFileName = 'incidents.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  IncidentDatabase({String? dbPathOverride}) : _dbPathOverride = dbPathOverride;

  /// The open database instance. Throws if not initialised.
  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('IncidentDatabase not initialized. Call open() first.');
    }
    return _db!;
  }

  /// Whether the database is open and ready.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Open the database, creating tables if needed.
  ///
  /// Safe to call multiple times. Uses a completer to prevent
  /// concurrent initialisation.
  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_initFailed) {
      throw StateError('IncidentDatabase init failed permanently.');
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('IncidentDatabase init failed.');
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
      AppLogging.incidents('IncidentDatabase: First open failed: $e');
      if (!await _attemptRecovery(path)) {
        AppLogging.incidents('IncidentDatabase: Recovery failed');
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) async {
    return openDatabase(
      path,
      version: incidentSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  /// Create all tables and indices for a fresh database.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // -- incidents --
    batch.execute('''
      CREATE TABLE incidents (
        id              TEXT PRIMARY KEY,
        orgId           TEXT NOT NULL,
        title           TEXT NOT NULL,
        description     TEXT,
        state           TEXT NOT NULL DEFAULT 'draft',
        priority        TEXT NOT NULL DEFAULT 'routine',
        classification  TEXT NOT NULL DEFAULT 'operational',
        ownerId         TEXT NOT NULL,
        assigneeId      TEXT,
        locationLat     REAL,
        locationLon     REAL,
        createdAt       INTEGER NOT NULL,
        updatedAt       INTEGER NOT NULL,
        syncedAt        INTEGER
      )
    ''');

    batch.execute('CREATE INDEX idx_incidents_orgId ON incidents(orgId)');
    batch.execute('CREATE INDEX idx_incidents_state ON incidents(state)');
    batch.execute('CREATE INDEX idx_incidents_ownerId ON incidents(ownerId)');
    batch.execute(
      'CREATE INDEX idx_incidents_assigneeId ON incidents(assigneeId)',
    );
    batch.execute('CREATE INDEX idx_incidents_priority ON incidents(priority)');
    batch.execute(
      'CREATE INDEX idx_incidents_createdAt ON incidents(createdAt)',
    );

    // -- incident_transitions (append-only) --
    batch.execute('''
      CREATE TABLE incident_transitions (
        id              TEXT PRIMARY KEY,
        incidentId      TEXT NOT NULL,
        fromState       TEXT NOT NULL,
        toState         TEXT NOT NULL,
        actorId         TEXT NOT NULL,
        note            TEXT,
        timestamp       INTEGER NOT NULL,
        FOREIGN KEY (incidentId) REFERENCES incidents(id)
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_transitions_incidentId '
      'ON incident_transitions(incidentId)',
    );
    batch.execute(
      'CREATE INDEX idx_transitions_timestamp '
      'ON incident_transitions(timestamp)',
    );

    // -- incident_field_reports --
    batch.execute('''
      CREATE TABLE incident_field_reports (
        id              TEXT PRIMARY KEY,
        incidentId      TEXT NOT NULL,
        signalId        TEXT NOT NULL,
        linkedAt        INTEGER NOT NULL,
        linkedBy        TEXT NOT NULL,
        FOREIGN KEY (incidentId) REFERENCES incidents(id)
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_field_reports_incidentId '
      'ON incident_field_reports(incidentId)',
    );
    batch.execute(
      'CREATE INDEX idx_field_reports_signalId '
      'ON incident_field_reports(signalId)',
    );

    await batch.commit(noResult: true);
    AppLogging.incidents('IncidentDatabase: created v$version');
  }

  /// Migrations scaffold — currently only version 1.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.incidents(
      'IncidentDatabase: upgrade v$oldVersion -> v$newVersion',
    );
    // Future migrations:
    // if (oldVersion < 2) { ... }
  }

  /// Downgrade: drop and recreate.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.incidents(
      'IncidentDatabase: downgrade v$oldVersion -> v$newVersion — recreating',
    );
    await db.execute('DROP TABLE IF EXISTS incident_field_reports');
    await db.execute('DROP TABLE IF EXISTS incident_transitions');
    await db.execute('DROP TABLE IF EXISTS incidents');
    await _onCreate(db, newVersion);
  }

  /// Attempt corruption recovery by deleting and recreating the database.
  Future<bool> _attemptRecovery(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();

      // Also clean up WAL / SHM journal files.
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final journal = File('$path$suffix');
        if (await journal.exists()) await journal.delete();
      }

      _db = await _attemptOpen(path);
      AppLogging.incidents('IncidentDatabase: recovered via recreate');
      return true;
    } catch (e) {
      AppLogging.incidents('IncidentDatabase: recovery error: $e');
      return false;
    }
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
    _initFailed = false;
  }
}
