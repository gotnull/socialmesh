// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SQLite persistence for mesh-transmitted incident reports.
///
/// Database: mesh_incidents.db
/// Schema version: 2
///
/// Separate from the cloud-synced incident database (incidents.db) because
/// mesh incidents operate without authentication, org context, or cloud sync.
/// They use compact uint32 case IDs rather than UUID strings.
///
/// v2 adds the unified Incident Mode event log (`incident_mode_events`) used
/// by both the hazard_report and help_request workflows. The legacy
/// `mesh_incident_reports` table is unchanged.
///
/// Spec: docs/protocol/INCIDENT_SPP_V0_1.md
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/incident_mode_models.dart';
import '../models/mesh_incident_report.dart';
import '../../../services/protocol/sip/spp_constants.dart';
import '../../../services/protocol/sip/spp_types.dart';
import 'incident_mode_store.dart';
import 'mesh_incident_service.dart';

/// Schema version for the mesh incidents SQLite database.
///
/// v1: Initial schema (mesh_incident_reports).
/// v2: Adds incident_mode_events (unified Incident Mode event log).
const int meshIncidentSchemaVersion = 2;

/// DDL for the unified Incident Mode event log. The event log is the single
/// source of truth; projections are derived via [IncidentReducer].
const String _createIncidentModeEventsTable = '''
  CREATE TABLE incident_mode_events (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    incidentId        INTEGER NOT NULL,
    workflowKind      TEXT NOT NULL,
    type              TEXT NOT NULL,
    senderNodeId      INTEGER NOT NULL,
    seq               INTEGER NOT NULL,
    timestamp         INTEGER NOT NULL,
    receivedAt        INTEGER,
    refSeq            INTEGER,
    isSuperseded      INTEGER NOT NULL DEFAULT 0,
    quickUpdate       TEXT,
    ackCategory       TEXT,
    expiresAt         INTEGER,
    hazardStatus      TEXT,
    hazardUpdateType  TEXT,
    locLatitude       REAL,
    locLongitude      REAL,
    locAccuracyMeters REAL,
    locFixedAt        INTEGER,
    locReceivedAt     INTEGER,
    msgText           TEXT,
    UNIQUE(incidentId, senderNodeId, seq)
  )
''';

const String _idxIncidentModeIncidentId =
    'CREATE INDEX idx_incident_mode_incidentId '
    'ON incident_mode_events(incidentId)';

const String _idxIncidentModeWorkflow =
    'CREATE INDEX idx_incident_mode_workflow '
    'ON incident_mode_events(workflowKind)';

const String _idxIncidentModeTimestamp =
    'CREATE INDEX idx_incident_mode_timestamp '
    'ON incident_mode_events(timestamp)';

/// SQLite persistence for mesh incident reports.
///
/// Implements [MeshIncidentDatabase] (legacy hazard reports) and
/// [IncidentModeDatabase] (unified Incident Mode event log) for use by
/// [MeshIncidentService] and [IncidentModeStore] respectively.
class MeshIncidentDatabaseImpl
    implements MeshIncidentDatabase, IncidentModeDatabase {
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

    // Unified Incident Mode event log (v2).
    batch.execute(_createIncidentModeEventsTable);
    batch.execute(_idxIncidentModeIncidentId);
    batch.execute(_idxIncidentModeWorkflow);
    batch.execute(_idxIncidentModeTimestamp);

    await batch.commit(noResult: true);
    AppLogging.incidents('MeshIncidentDatabase: created v$version');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.incidents(
      'MeshIncidentDatabase: upgrade v$oldVersion -> v$newVersion',
    );
    // v2: additive Incident Mode event log. Legacy hazard reports untouched.
    if (oldVersion < 2) {
      await db.execute(_createIncidentModeEventsTable);
      await db.execute(_idxIncidentModeIncidentId);
      await db.execute(_idxIncidentModeWorkflow);
      await db.execute(_idxIncidentModeTimestamp);
    }
  }

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.incidents(
      'MeshIncidentDatabase: downgrade v$oldVersion -> v$newVersion',
    );
    await db.execute('DROP TABLE IF EXISTS mesh_incident_reports');
    await db.execute('DROP TABLE IF EXISTS incident_mode_events');
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

  // -------------------------------------------------------------------------
  // IncidentModeDatabase interface (unified Incident Mode event log)
  // -------------------------------------------------------------------------

  @override
  Future<bool> insertIncidentEvent(IncidentEvent event) async {
    final db = _database;
    final rowId = await db.insert(
      'incident_mode_events',
      _incidentEventToRow(event),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // insert() returns 0 when the row was ignored due to a UNIQUE conflict.
    return rowId > 0;
  }

  @override
  Future<List<IncidentEvent>> getIncidentEvents(int incidentId) async {
    final db = _database;
    final rows = await db.query(
      'incident_mode_events',
      where: 'incidentId = ?',
      whereArgs: [incidentId],
      orderBy: 'timestamp ASC, seq ASC, senderNodeId ASC',
    );
    return rows.map(_incidentEventFromRow).toList();
  }

  @override
  Future<List<int>> getActiveHelpRequestIds({int limit = 32}) async {
    final db = _database;
    final rows = await db.rawQuery(
      '''
      SELECT incidentId, MAX(timestamp) AS maxTs
      FROM incident_mode_events
      WHERE workflowKind = ?
        AND incidentId NOT IN (
          SELECT incidentId FROM incident_mode_events WHERE type IN (?, ?, ?)
        )
      GROUP BY incidentId
      ORDER BY maxTs DESC
      LIMIT ?
      ''',
      [
        IncidentWorkflowKind.helpRequest.name,
        IncidentEventType.resolve.name,
        IncidentEventType.cancel.name,
        IncidentEventType.expire.name,
        limit,
      ],
    );
    return rows.map((r) => r['incidentId'] as int).toList();
  }

  @override
  Future<int> getMaxIncidentId() async {
    final db = _database;
    final result = await db.rawQuery(
      'SELECT MAX(incidentId) AS maxId FROM incident_mode_events',
    );
    if (result.isEmpty || result.first['maxId'] == null) return 0;
    return result.first['maxId'] as int;
  }

  /// Evict Incident Mode events older than the TTL.
  Future<int> evictExpiredIncidentModeEvents() async {
    final db = _database;
    final cutoff = DateTime.now()
        .subtract(SppConstants.incidentTtl)
        .millisecondsSinceEpoch;
    return db.delete(
      'incident_mode_events',
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

DateTime? _epochOrNull(Object? ms) => ms == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);

/// Flattens an [IncidentEvent] into an `incident_mode_events` row.
///
/// Location and message payloads are flattened onto the row; their
/// nodeId/incidentId/seq/timestamp are reconstructed on read from the parent
/// event, so they are not stored redundantly.
Map<String, Object?> _incidentEventToRow(IncidentEvent e) {
  return {
    'incidentId': e.incidentId,
    'workflowKind': e.workflowKind.name,
    'type': e.type.name,
    'senderNodeId': e.senderNodeId,
    'seq': e.seq,
    'timestamp': e.timestamp.millisecondsSinceEpoch,
    'receivedAt': e.receivedAt?.millisecondsSinceEpoch,
    'refSeq': e.refSeq,
    'isSuperseded': e.isSuperseded ? 1 : 0,
    'quickUpdate': e.quickUpdate?.name,
    'ackCategory': e.ackCategory?.name,
    'expiresAt': e.expiresAt?.millisecondsSinceEpoch,
    'hazardStatus': e.hazardStatus?.name,
    'hazardUpdateType': e.hazardUpdateType?.name,
    'locLatitude': e.location?.latitude,
    'locLongitude': e.location?.longitude,
    'locAccuracyMeters': e.location?.accuracyMeters,
    'locFixedAt': e.location?.fixedAt.millisecondsSinceEpoch,
    'locReceivedAt': e.location?.receivedAt?.millisecondsSinceEpoch,
    'msgText': e.message?.text,
  };
}

/// Reconstructs an [IncidentEvent] from an `incident_mode_events` row.
IncidentEvent _incidentEventFromRow(Map<String, Object?> row) {
  final incidentId = row['incidentId'] as int;
  final senderNodeId = row['senderNodeId'] as int;
  final seq = row['seq'] as int;
  final timestamp = DateTime.fromMillisecondsSinceEpoch(
    row['timestamp'] as int,
    isUtc: true,
  );

  IncidentLocation? location;
  if (row['locLatitude'] != null && row['locLongitude'] != null) {
    location = IncidentLocation(
      incidentId: incidentId,
      nodeId: senderNodeId,
      latitude: (row['locLatitude'] as num).toDouble(),
      longitude: (row['locLongitude'] as num).toDouble(),
      accuracyMeters: (row['locAccuracyMeters'] as num?)?.toDouble(),
      fixedAt: DateTime.fromMillisecondsSinceEpoch(
        row['locFixedAt'] as int,
        isUtc: true,
      ),
      receivedAt: _epochOrNull(row['locReceivedAt']),
    );
  }

  IncidentMessage? message;
  if (row['msgText'] != null) {
    message = IncidentMessage(
      incidentId: incidentId,
      senderNodeId: senderNodeId,
      seq: seq,
      text: row['msgText'] as String,
      timestamp: timestamp,
    );
  }

  return IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.values.byName(
      row['workflowKind'] as String,
    ),
    type: IncidentEventType.values.byName(row['type'] as String),
    senderNodeId: senderNodeId,
    seq: seq,
    timestamp: timestamp,
    receivedAt: _epochOrNull(row['receivedAt']),
    refSeq: row['refSeq'] as int?,
    isSuperseded: (row['isSuperseded'] as int?) == 1,
    quickUpdate: row['quickUpdate'] != null
        ? IncidentQuickUpdate.values.byName(row['quickUpdate'] as String)
        : null,
    ackCategory: row['ackCategory'] != null
        ? IncidentAckCategory.values.byName(row['ackCategory'] as String)
        : null,
    location: location,
    message: message,
    expiresAt: _epochOrNull(row['expiresAt']),
    hazardStatus: row['hazardStatus'] != null
        ? IncidentMeshStatus.values.byName(row['hazardStatus'] as String)
        : null,
    hazardUpdateType: row['hazardUpdateType'] != null
        ? IncidentUpdateType.values.byName(row['hazardUpdateType'] as String)
        : null,
  );
}
