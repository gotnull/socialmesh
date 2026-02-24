// SPDX-License-Identifier: GPL-3.0-or-later

// Incident Database — SQLite schema and lifecycle management.
//
// This file defines the database schema for the incident lifecycle engine.
// Tables: incidents, incident_transitions, incident_field_reports.
//
// Database: incidents.db
// Schema version: 2
//
// Spec: INCIDENT_LIFECYCLE.md (Sprint 007).

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/incident.dart';
import '../models/incident_transition.dart';
import 'incident_conflict_resolver.dart';

/// Schema version for the incidents SQLite database.
///
/// v1: Initial schema (incidents, incident_transitions, incident_field_reports).
/// v2: Added actorRole and supersededBy columns to incident_transitions.
const int incidentSchemaVersion = 2;

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
      singleInstance: path != inMemoryDatabasePath,
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
        actorRole       TEXT,
        note            TEXT,
        timestamp       INTEGER NOT NULL,
        supersededBy    TEXT,
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

  /// Migrations.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.incidents(
      'IncidentDatabase: upgrade v$oldVersion -> v$newVersion',
    );

    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE incident_transitions ADD COLUMN actorRole TEXT',
      );
      await db.execute(
        'ALTER TABLE incident_transitions ADD COLUMN supersededBy TEXT',
      );
      AppLogging.incidents(
        'IncidentDatabase: v2 migration — added actorRole, supersededBy',
      );
    }
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

  // -------------------------------------------------------------------------
  // Projection rebuild
  // -------------------------------------------------------------------------

  /// Replays all non-superseded transitions for [incidentId] by walking the
  /// from→to chain starting from `draft`. This is deterministic regardless of
  /// timestamp ordering.
  ///
  /// Returns the final [IncidentState] after replay.
  Future<IncidentState> rebuildProjection(String incidentId) async {
    final db = database;

    final rows = await db.query(
      'incident_transitions',
      where: 'incidentId = ? AND supersededBy IS NULL',
      whereArgs: [incidentId],
    );

    IncidentState current = IncidentState.draft;
    if (rows.isEmpty) {
      AppLogging.incidents(
        'projection rebuild $incidentId: no transitions found',
      );
    } else {
      // Index transitions by fromState for O(n) chain walk.
      final byFromState = <String, Map<String, Object?>>{};
      for (final row in rows) {
        byFromState[row['fromState'] as String] = row;
      }

      var steps = 0;
      while (byFromState.containsKey(current.name)) {
        final row = byFromState[current.name]!;
        current = IncidentState.values.byName(row['toState'] as String);
        steps++;
        // Safety: prevent infinite loops.
        if (steps > rows.length) break;
      }

      AppLogging.incidents(
        'projection rebuild $incidentId: '
        'replayed $steps transitions, final state=${current.name}',
      );
    }

    final now = DateTime.now();
    await db.update(
      'incidents',
      {'state': current.name, 'updatedAt': now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [incidentId],
    );

    return current;
  }

  // -------------------------------------------------------------------------
  // Remote transition reconciliation
  // -------------------------------------------------------------------------

  /// Applies a batch of remote transitions received during the drain cycle.
  ///
  /// 1. Inserts remote transitions (skips duplicates via transitionId
  ///    uniqueness constraint).
  /// 2. For each affected incident, queries all non-superseded transitions.
  /// 3. Runs [IncidentConflictResolver.resolveConflicts] to detect conflicts.
  /// 4. Marks losing transitions as superseded (sets `supersededBy` to the
  ///    winning transition's ID). Rows are never deleted.
  /// 5. Rebuilds the `incidents.state` projection from the winning sequence.
  ///
  /// This method is idempotent — calling it again with the same transitions
  /// produces the same result.
  Future<void> applyRemoteTransitions({
    required List<IncidentTransition> remoteTransitions,
    IncidentConflictResolver resolver = const IncidentConflictResolver(),
  }) async {
    final db = database;

    // 1. Insert remote transitions (ignore duplicates).
    for (final t in remoteTransitions) {
      await db.insert(
        'incident_transitions',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // 2. Resolve conflicts per affected incident.
    final affectedIncidents = remoteTransitions
        .map((t) => t.incidentId)
        .toSet();
    final remoteIds = remoteTransitions.map((t) => t.id).toSet();

    for (final incidentId in affectedIncidents) {
      // Query all non-superseded transitions.
      final rows = await db.query(
        'incident_transitions',
        where: 'incidentId = ? AND supersededBy IS NULL',
        whereArgs: [incidentId],
      );
      final allTransitions = rows.map(IncidentTransition.fromMap).toList();

      // 3. Resolve.
      final resolution = resolver.resolveConflicts(
        incidentId: incidentId,
        transitions: allTransitions,
      );

      // 4. Log and mark superseded transitions.
      if (resolution.supersededIds.isNotEmpty) {
        for (final sid in resolution.supersededIds) {
          final superseded = allTransitions.firstWhere((t) => t.id == sid);
          final isRemote = remoteIds.contains(sid);

          // Find the winner from the same fromState group.
          final winner = resolution.winningTransitions
              .where((w) => w.fromState == superseded.fromState)
              .firstOrNull;
          final winnerId =
              winner?.id ?? resolution.winningTransitions.lastOrNull?.id;
          final winIsRemote = winnerId != null && remoteIds.contains(winnerId);

          AppLogging.incidentSync(
            'conflict detected on $incidentId: '
            '${isRemote ? "remote" : "local"}='
            '${superseded.toState.name}'
            '@${superseded.timestamp.millisecondsSinceEpoch}, '
            '${winIsRemote ? "remote" : "local"}='
            '${winner?.toState.name ?? "?"}'
            '@${winner?.timestamp.millisecondsSinceEpoch ?? "?"}',
          );

          await db.update(
            'incident_transitions',
            {'supersededBy': winnerId ?? 'orphan'},
            where: 'id = ?',
            whereArgs: [sid],
          );
        }

        AppLogging.incidentSync(
          'resolution chain: ${resolution.debugResolutionPath}',
        );
      }

      // 5. Rebuild projection.
      final finalState = await rebuildProjection(incidentId);

      AppLogging.incidentSync(
        'projection rebuilt $incidentId: final state=${finalState.name}',
      );
    }
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
    _initFailed = false;
  }

  // -------------------------------------------------------------------------
  // Query helpers
  // -------------------------------------------------------------------------

  /// Returns all incidents for [orgId], ordered by [createdAt] descending
  /// then [id] for stable ordering.
  ///
  /// Optionally filters by [states], [priorities], and [assigneeId].
  Future<List<Incident>> getIncidentsByOrgId(
    String orgId, {
    Set<IncidentState>? states,
    Set<IncidentPriority>? priorities,
    String? assigneeId,
  }) async {
    final db = database;

    final where = StringBuffer('orgId = ?');
    final whereArgs = <Object>[orgId];

    if (states != null && states.isNotEmpty) {
      final placeholders = List.filled(states.length, '?').join(', ');
      where.write(' AND state IN ($placeholders)');
      whereArgs.addAll(states.map((s) => s.name));
    }

    if (priorities != null && priorities.isNotEmpty) {
      final placeholders = List.filled(priorities.length, '?').join(', ');
      where.write(' AND priority IN ($placeholders)');
      whereArgs.addAll(priorities.map((p) => p.name));
    }

    if (assigneeId != null) {
      where.write(' AND assigneeId = ?');
      whereArgs.add(assigneeId);
    }

    final rows = await db.query(
      'incidents',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC, id ASC',
    );

    return rows.map(Incident.fromMap).toList();
  }

  /// Returns a single incident by [id], or null if not found.
  Future<Incident?> getIncidentById(String id) async {
    final db = database;
    final rows = await db.query(
      'incidents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Incident.fromMap(rows.first);
  }

  /// Returns all transitions for [incidentId], ordered by timestamp
  /// ascending then id for stable ordering.
  Future<List<IncidentTransition>> getTransitionsByIncidentId(
    String incidentId,
  ) async {
    final db = database;
    final rows = await db.query(
      'incident_transitions',
      where: 'incidentId = ?',
      whereArgs: [incidentId],
      orderBy: 'timestamp ASC, id ASC',
    );
    return rows.map(IncidentTransition.fromMap).toList();
  }

  /// Inserts a new incident row.
  Future<void> insertIncident(Incident incident) async {
    final db = database;
    await db.insert('incidents', incident.toMap());
  }
}
