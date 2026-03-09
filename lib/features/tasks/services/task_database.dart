// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Task Database — SQLite schema and lifecycle management.
//
// This file defines the database schema for the task system.
// Tables: tasks, task_transitions.
//
// Database: tasks.db
// Schema version: 1
//
// Spec: TASK_SYSTEM.md (Sprint 007/W3.1), Sprint 008/W4.1.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/task.dart';
import '../models/task_transition.dart';
import 'task_conflict_resolver.dart';

/// Schema version for the tasks SQLite database.
///
/// v1: Initial schema (tasks, task_transitions).
const int taskSchemaVersion = 1;

/// Manages the tasks SQLite database lifecycle.
///
/// Handles opening, creating, upgrading, and corruption recovery.
/// Follows the same resilient pattern used by IncidentDatabase.
class TaskDatabase {
  static const String _dbFileName = 'tasks.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  TaskDatabase({String? dbPathOverride}) : _dbPathOverride = dbPathOverride;

  /// The open database instance. Throws if not initialised.
  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('TaskDatabase not initialized. Call open() first.');
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
      throw StateError('TaskDatabase init failed permanently.');
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('TaskDatabase init failed.');
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
      AppLogging.tasks('TaskDatabase: First open failed: $e');
      if (!await _attemptRecovery(path)) {
        AppLogging.tasks('TaskDatabase: Recovery failed');
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) async {
    return openDatabase(
      path,
      version: taskSchemaVersion,
      singleInstance: path != inMemoryDatabasePath,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    final walResult = await db.rawQuery('PRAGMA journal_mode=WAL'); assert(walResult.isNotEmpty && walResult.first['journal_mode'] == 'wal', 'WAL mode not active'); // lint-allow: hardcoded-string
  }

  /// Create all tables and indices for a fresh database.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // -- tasks --
    batch.execute('''
      CREATE TABLE tasks (
        id              TEXT PRIMARY KEY,
        orgId           TEXT NOT NULL,
        incidentId      TEXT,
        title           TEXT NOT NULL,
        description     TEXT,
        state           TEXT NOT NULL DEFAULT 'created',
        priority        TEXT NOT NULL DEFAULT 'routine',
        createdBy       TEXT NOT NULL,
        assigneeId      TEXT NOT NULL,
        completionNote  TEXT,
        failureReason   TEXT,
        reassignedTo    TEXT,
        reassignedFrom  TEXT,
        locationLat     REAL,
        locationLon     REAL,
        dueAt           INTEGER,
        createdAt       INTEGER NOT NULL,
        updatedAt       INTEGER NOT NULL,
        syncedAt        INTEGER
      )
    ''');

    batch.execute('CREATE INDEX idx_tasks_orgId ON tasks(orgId)');
    batch.execute('CREATE INDEX idx_tasks_state ON tasks(state)');
    batch.execute('CREATE INDEX idx_tasks_assigneeId ON tasks(assigneeId)');
    batch.execute('CREATE INDEX idx_tasks_incidentId ON tasks(incidentId)');
    batch.execute('CREATE INDEX idx_tasks_priority ON tasks(priority)');
    batch.execute('CREATE INDEX idx_tasks_createdAt ON tasks(createdAt)');
    batch.execute('CREATE INDEX idx_tasks_dueAt ON tasks(dueAt)');

    // -- task_transitions (append-only) --
    batch.execute('''
      CREATE TABLE task_transitions (
        id              TEXT PRIMARY KEY,
        taskId          TEXT NOT NULL,
        fromState       TEXT NOT NULL,
        toState         TEXT NOT NULL,
        actorId         TEXT NOT NULL,
        note            TEXT,
        timestamp       INTEGER NOT NULL,
        FOREIGN KEY (taskId) REFERENCES tasks(id)
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_task_transitions_taskId '
      'ON task_transitions(taskId)',
    );
    batch.execute(
      'CREATE INDEX idx_task_transitions_timestamp '
      'ON task_transitions(timestamp)',
    );

    await batch.commit(noResult: true);
    AppLogging.tasks('TaskDatabase: created v$version');
  }

  /// Migrations for future schema versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.tasks('TaskDatabase: upgrade v$oldVersion -> v$newVersion');
    // Future migrations go here:
    // if (oldVersion < 2) { ... }
  }

  /// Downgrade: drop and recreate.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.tasks(
      'TaskDatabase: downgrade v$oldVersion -> v$newVersion — recreating',
    );
    await db.execute('DROP TABLE IF EXISTS task_transitions');
    await db.execute('DROP TABLE IF EXISTS tasks');
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
      AppLogging.tasks('TaskDatabase: recovered via recreate');
      return true;
    } catch (e) {
      AppLogging.tasks('TaskDatabase: recovery error: $e');
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

  // -------------------------------------------------------------------------
  // CRUD helpers
  // -------------------------------------------------------------------------

  /// Inserts a new task row.
  Future<void> insertTask(Task task) async {
    final db = database;
    await db.insert('tasks', task.toMap());
  }

  /// Returns a single task by [id], or null if not found.
  Future<Task?> getTaskById(String id) async {
    final db = database;
    final rows = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  /// Returns all tasks for [orgId], ordered by [createdAt] descending
  /// then [id] for stable ordering.
  ///
  /// Optionally filters by [states], [priorities], and [assigneeId].
  Future<List<Task>> getTasksByOrgId(
    String orgId, {
    Set<TaskState>? states,
    Set<TaskPriority>? priorities,
    String? assigneeId,
    String? incidentId,
  }) async {
    final db = database;

    final where = StringBuffer('orgId = ?');
    final whereArgs = <Object>[orgId];

    if (states != null && states.isNotEmpty) {
      final placeholders = List.filled(states.length, '?').join(', ');
      where.write(' AND state IN ($placeholders)');
      whereArgs.addAll(states.map((s) => s.dbValue));
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

    if (incidentId != null) {
      where.write(' AND incidentId = ?');
      whereArgs.add(incidentId);
    }

    final rows = await db.query(
      'tasks',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC, id ASC',
    );

    return rows.map(Task.fromMap).toList();
  }

  /// Returns all transitions for [taskId], ordered by timestamp
  /// ascending then id for stable ordering.
  Future<List<TaskTransition>> getTransitionsByTaskId(String taskId) async {
    final db = database;
    final rows = await db.query(
      'task_transitions',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'timestamp ASC, id ASC',
    );
    return rows.map(TaskTransition.fromMap).toList();
  }

  /// Inserts a transition record (append-only).
  Future<void> insertTransition(TaskTransition transition) async {
    final db = database;
    await db.insert('task_transitions', transition.toMap());
  }

  /// Updates the task projection row after a state transition.
  ///
  /// This is called by [TaskStateMachine] after appending a transition.
  Future<void> updateTaskProjection(
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    final db = database;
    await db.update('tasks', updates, where: 'id = ?', whereArgs: [taskId]);
  }

  /// Updates the [syncedAt] timestamp for a task after a successful push.
  Future<void> markSynced(String taskId, DateTime syncedAt) async {
    final db = database;
    await db.update(
      'tasks',
      {'syncedAt': syncedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Returns all tasks that have unsynchronised local changes.
  ///
  /// A task is considered unsynced if [syncedAt] is null or
  /// [updatedAt] > [syncedAt].
  Future<List<Task>> getUnsyncedTasks() async {
    final db = database;
    final rows = await db.query(
      'tasks',
      where: 'syncedAt IS NULL OR updatedAt > syncedAt',
      orderBy: 'updatedAt ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  /// Returns all transitions for [taskId] that have not yet been synced.
  ///
  /// Transitions are considered unsynced if their timestamp is after
  /// the task's [syncedAt].
  Future<List<TaskTransition>> getUnsyncedTransitions(String taskId) async {
    final db = database;
    final taskRows = await db.query(
      'tasks',
      columns: ['syncedAt'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (taskRows.isEmpty) return [];

    final syncedAt = taskRows.first['syncedAt'] as int?;

    if (syncedAt == null) {
      // Never synced — return all transitions.
      return getTransitionsByTaskId(taskId);
    }

    final rows = await db.query(
      'task_transitions',
      where: 'taskId = ? AND timestamp > ?',
      whereArgs: [taskId, syncedAt],
      orderBy: 'timestamp ASC, id ASC',
    );
    return rows.map(TaskTransition.fromMap).toList();
  }

  // -------------------------------------------------------------------------
  // Remote transition reconciliation
  // -------------------------------------------------------------------------

  /// Rebuilds the task projection state by replaying all transitions.
  ///
  /// Returns the computed final [TaskState] after replay.
  /// Updates the `tasks.state` and `tasks.updatedAt` columns.
  Future<TaskState> rebuildProjection(String taskId) async {
    final db = database;
    final transitions = await getTransitionsByTaskId(taskId);

    if (transitions.isEmpty) {
      return TaskState.created;
    }

    // Replay transitions in order to derive final state.
    var currentState = transitions.first.fromState;
    final now = DateTime.now();

    final updates = <String, dynamic>{'updatedAt': now.millisecondsSinceEpoch};

    for (final t in transitions) {
      currentState = t.toState;

      // Carry forward relevant fields from transitions.
      if (t.toState == TaskState.completed && t.note != null) {
        updates['completionNote'] = t.note;
      }
      if (t.toState == TaskState.failed && t.note != null) {
        updates['failureReason'] = t.note;
      }
    }

    updates['state'] = currentState.dbValue;

    await db.update('tasks', updates, where: 'id = ?', whereArgs: [taskId]);

    AppLogging.taskSync(
      'projection rebuilt $taskId: final state=${currentState.name}',
    );

    return currentState;
  }

  /// Applies a batch of remote transitions received during the sync drain
  /// cycle.
  ///
  /// For each remote transition:
  /// 1. Inserts the transition (skips duplicates via primary key constraint).
  /// 2. Loads the local task and its transitions.
  /// 3. Runs [TaskConflictResolver.resolve] to determine the outcome.
  /// 4. Updates the task projection based on the resolution.
  ///
  /// Both local and remote transitions are preserved (append-only).
  /// This method is idempotent — calling it again with the same transitions
  /// produces the same result.
  ///
  /// Spec: TASK_SYSTEM.md — Reconciliation Rules, Sprint 008/W4.2.
  Future<void> applyRemoteTransitions({
    required List<TaskTransition> remoteTransitions,
    TaskConflictResolver resolver = const TaskConflictResolver(),
  }) async {
    final db = database;

    // Group remote transitions by taskId for batch processing.
    final groupedByTask = <String, List<TaskTransition>>{};
    for (final rt in remoteTransitions) {
      groupedByTask.putIfAbsent(rt.taskId, () => []).add(rt);
    }

    for (final entry in groupedByTask.entries) {
      final taskId = entry.key;
      final taskRemoteTransitions = entry.value
        ..sort(
          (a, b) => a.timestamp.millisecondsSinceEpoch.compareTo(
            b.timestamp.millisecondsSinceEpoch,
          ),
        );

      for (final rt in taskRemoteTransitions) {
        // 1. Load local state BEFORE inserting, so the resolver
        //    does not see the incoming transition as a duplicate.
        final localTask = await getTaskById(taskId);
        final localTransitions = await getTransitionsByTaskId(taskId);

        // 2. Insert remote transition (ignore duplicates).
        await db.insert(
          'task_transitions',
          rt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 3. Resolve conflict.
        final result = resolver.resolve(
          localTask: localTask,
          localTransitions: localTransitions,
          remoteTransition: rt,
        );

        AppLogging.taskSync(
          'resolved ${rt.taskId}: '
          '${result.outcome.name} — ${result.reason}',
        );

        // 4. Update projection if resolution changed the state.
        if (result.resolvedState != null &&
            localTask != null &&
            result.resolvedState != localTask.state) {
          final updates = <String, dynamic>{
            'state': result.resolvedState!.dbValue,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          };

          // Carry forward completion note or failure reason from the
          // winning transition.
          if (result.winningTransition?.note != null) {
            if (result.resolvedState == TaskState.completed) {
              updates['completionNote'] = result.winningTransition!.note;
            } else if (result.resolvedState == TaskState.failed) {
              updates['failureReason'] = result.winningTransition!.note;
            }
          }

          await updateTaskProjection(taskId, updates);
        }
      }
    }
  }
}
