// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SQLite persistence for mesh-transmitted incident reports.
///
/// Database: mesh_incidents.db
/// Schema version: 1
///
/// Separate from the cloud-synced incident database (incidents.db) because
/// mesh incidents operate without authentication, org context, or cloud sync.
/// They use compact uint32 case IDs rather than UUID strings.
///
/// Spec: docs/protocol/INCIDENT_SPP_V0_1.md
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/mesh_incident_report.dart';
import '../../../services/protocol/sip/spp_constants.dart';
import '../../../services/protocol/sip/spp_types.dart';
import 'mesh_incident_service.dart';

/// Schema version for the mesh incidents SQLite database.
///
/// v1: Initial schema (mesh_incident_reports).
const int meshIncidentSchemaVersion = 1;

/// SQLite persistence for mesh incident reports.
///
/// Implements [MeshIncidentDatabase] for use by [MeshIncidentService].
class MeshIncidentDatabaseImpl implements MeshIncidentDatabase {
  static const String _dbFileName = 'mesh_incidents.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  MeshIncidentDatabaseImpl({String? dbPathOverride})
    : _dbPathOverride = dbPathOverride;

  /// Whether the database is open and ready.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Open the database, creating tables if needed.
  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_initFailed) {
      throw StateError('MeshIncidentDatabase init failed permanently.');
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('MeshIncidentDatabase init failed.');
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
      AppLogging.incidents('MeshIncidentDatabase: First open failed: $e');
      if (!await _attemptRecovery(path)) {
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) async {
    return openDatabase(
      path,
      version: meshIncidentSchemaVersion,
      singleInstance: path != inMemoryDatabasePath,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE mesh_incident_reports (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        caseId          INTEGER NOT NULL,
        seqNum          INTEGER NOT NULL,
        updateType      INTEGER NOT NULL,
        confidence      INTEGER NOT NULL,
        classification  INTEGER NOT NULL,
        priority        INTEGER NOT NULL,
        status          INTEGER NOT NULL,
        reporterRole    INTEGER NOT NULL,
        timestamp       INTEGER NOT NULL,
        refSeq          INTEGER,
        latitude        REAL,
        longitude       REAL,
        body            TEXT NOT NULL,
        senderNodeId    INTEGER NOT NULL,
        isSuperseded    INTEGER NOT NULL DEFAULT 0,
        receivedAt      INTEGER,
        UNIQUE(caseId, seqNum, senderNodeId)
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_mesh_ir_caseId '
      'ON mesh_incident_reports(caseId)',
    );
    batch.execute(
      'CREATE INDEX idx_mesh_ir_timestamp '
      'ON mesh_incident_reports(timestamp)',
    );
    batch.execute(
      'CREATE INDEX idx_mesh_ir_status '
      'ON mesh_incident_reports(status)',
    );
    batch.execute(
      'CREATE INDEX idx_mesh_ir_sender '
      'ON mesh_incident_reports(senderNodeId)',
    );

    await batch.commit(noResult: true);
    AppLogging.incidents('MeshIncidentDatabase: created v$version');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.incidents(
      'MeshIncidentDatabase: upgrade v$oldVersion -> v$newVersion',
    );
  }

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.incidents(
      'MeshIncidentDatabase: downgrade v$oldVersion -> v$newVersion',
    );
    await db.execute('DROP TABLE IF EXISTS mesh_incident_reports');
    await _onCreate(db, newVersion);
  }

  Future<bool> _attemptRecovery(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final journal = File('$path$suffix');
        if (await journal.exists()) await journal.delete();
      }
      _db = await _attemptOpen(path);
      AppLogging.incidents('MeshIncidentDatabase: recovered via recreate');
      return true;
    } catch (e) {
      AppLogging.incidents('MeshIncidentDatabase: recovery error: $e');
      return false;
    }
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  Database get _database {
    if (_db == null || !_db!.isOpen) {
      throw StateError(
        'MeshIncidentDatabase not initialized. Call open() first.',
      );
    }
    return _db!;
  }

  // -------------------------------------------------------------------------
  // MeshIncidentDatabase interface
  // -------------------------------------------------------------------------

  @override
  Future<void> insertReport(MeshIncidentReport report) async {
    final db = _database;
    await db.insert(
      'mesh_incident_reports',
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> markSuperseded(int caseId, int seqNum) async {
    final db = _database;
    await db.update(
      'mesh_incident_reports',
      {'isSuperseded': 1},
      where: 'caseId = ? AND seqNum = ?',
      whereArgs: [caseId, seqNum],
    );
  }

  @override
  Future<List<MeshIncidentReport>> getReportsForCase(int caseId) async {
    final db = _database;
    final rows = await db.query(
      'mesh_incident_reports',
      where: 'caseId = ?',
      whereArgs: [caseId],
      orderBy: 'seqNum ASC',
    );
    return rows.map(MeshIncidentReport.fromMap).toList();
  }

  @override
  Future<List<MeshIncidentCaseState>> getActiveCases() async {
    final db = _database;

    // Get distinct case IDs with non-terminal status
    final caseRows = await db.rawQuery('''
      SELECT DISTINCT caseId FROM mesh_incident_reports
      WHERE caseId IN (
        SELECT caseId FROM mesh_incident_reports
        GROUP BY caseId
        HAVING MAX(seqNum) = seqNum
          AND status < ${IncidentMeshStatus.resolved.code}
      )
      ORDER BY timestamp DESC
      LIMIT ${SppConstants.maxActiveCases}
    ''');

    final cases = <MeshIncidentCaseState>[];
    for (final row in caseRows) {
      final caseId = row['caseId'] as int;
      final reports = await getReportsForCase(caseId);
      if (reports.isNotEmpty) {
        cases.add(MeshIncidentCaseState.fromReports(reports));
      }
    }
    return cases;
  }

  @override
  Future<int> getMaxCaseId() async {
    final db = _database;
    final result = await db.rawQuery(
      'SELECT MAX(caseId) as maxId FROM mesh_incident_reports '
      'WHERE senderNodeId = 0',
    );
    if (result.isEmpty || result.first['maxId'] == null) return 0;
    return result.first['maxId'] as int;
  }

  @override
  Future<int> getMaxSeqNum(int caseId) async {
    final db = _database;
    final result = await db.rawQuery(
      'SELECT MAX(seqNum) as maxSeq FROM mesh_incident_reports '
      'WHERE caseId = ?',
      [caseId],
    );
    if (result.isEmpty || result.first['maxSeq'] == null) return -1;
    return result.first['maxSeq'] as int;
  }

  /// Get all reports across all cases, ordered by timestamp descending.
  Future<List<MeshIncidentReport>> getRecentReports({int limit = 50}) async {
    final db = _database;
    final rows = await db.query(
      'mesh_incident_reports',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(MeshIncidentReport.fromMap).toList();
  }

  /// Evict reports older than the TTL.
  Future<int> evictExpired() async {
    final db = _database;
    final cutoff = DateTime.now()
        .subtract(SppConstants.incidentTtl)
        .millisecondsSinceEpoch;
    return db.delete(
      'mesh_incident_reports',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
    _initFailed = false;
  }
}
