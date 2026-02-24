// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:uuid/uuid.dart';

import '../../../core/auth/permission.dart';
import '../../../core/auth/permission_context.dart';
import '../../../core/auth/permission_service.dart';
import '../../../core/logging.dart';
import '../models/incident.dart';
import '../models/incident_transition.dart';
import '../services/incident_database.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when a requested state transition is not valid per the lifecycle
/// spec.
class InvalidTransitionException implements Exception {
  final String message;
  const InvalidTransitionException(this.message);

  @override
  String toString() => 'InvalidTransitionException: $message';
}

// ---------------------------------------------------------------------------
// Transition rules
// ---------------------------------------------------------------------------

/// The set of all valid (fromState, toState) pairs.
///
/// Spec: INCIDENT_LIFECYCLE.md — Valid Transitions table.
const _validTransitions = <(IncidentState, IncidentState)>{
  // draft ->
  (IncidentState.draft, IncidentState.open), // submit
  (IncidentState.draft, IncidentState.cancelled), // cancel
  // open ->
  (IncidentState.open, IncidentState.assigned), // assign
  (IncidentState.open, IncidentState.escalated), // escalate
  (IncidentState.open, IncidentState.resolved), // resolve
  (IncidentState.open, IncidentState.cancelled), // cancel
  // escalated ->
  (IncidentState.escalated, IncidentState.assigned), // assign
  (IncidentState.escalated, IncidentState.cancelled), // cancel
  // assigned ->
  (IncidentState.assigned, IncidentState.resolved), // resolve
  (IncidentState.assigned, IncidentState.cancelled), // cancel
  // resolved ->
  (IncidentState.resolved, IncidentState.closed), // close
};

/// Maps target state to the [Permission] that must be checked.
Permission _permissionForTarget(IncidentState target) {
  return switch (target) {
    IncidentState.open => Permission.submitIncident,
    IncidentState.assigned => Permission.assignIncident,
    IncidentState.escalated => Permission.escalateIncident,
    IncidentState.resolved => Permission.resolveIncident,
    IncidentState.closed => Permission.closeIncident,
    IncidentState.cancelled => Permission.cancelIncident,
    IncidentState.draft => throw InvalidTransitionException(
      'Cannot transition to draft',
    ),
  };
}

// ---------------------------------------------------------------------------
// State machine
// ---------------------------------------------------------------------------

/// Incident lifecycle state machine.
///
/// Validates transitions, enforces RBAC via [PermissionService], and writes
/// to the append-only `incident_transitions` table.
///
/// The `incidents.state` column is a projection — updated after each
/// transition for query convenience but never treated as authoritative.
///
/// Spec: INCIDENT_LIFECYCLE.md (Sprint 007), Sprint 008/W3.1.
class IncidentStateMachine {
  final IncidentDatabase _db;
  final PermissionService _permissions;
  static const _uuid = Uuid();

  IncidentStateMachine({
    required IncidentDatabase db,
    required PermissionService permissions,
  }) : _db = db,
       _permissions = permissions;

  // -----------------------------------------------------------------------
  // Incident creation
  // -----------------------------------------------------------------------

  /// Creates a new incident in draft state.
  ///
  /// Inserts the incident row and an initial draft transition record.
  /// Requires [Permission.createIncident].
  ///
  /// Returns the created [Incident].
  Future<Incident> createIncident({
    required String orgId,
    required String title,
    String? description,
    required IncidentPriority priority,
    required IncidentClassification classification,
    required String actorId,
    double? locationLat,
    double? locationLon,
  }) async {
    // --- RBAC check ---
    if (!_permissions.can(Permission.createIncident)) {
      final roleName = _permissions.currentRole?.name ?? 'none';
      AppLogging.incidents(
        'create incident rejected (permission denied, role=$roleName)',
      );
      throw InsufficientPermissionException(
        'createIncident denied for role $roleName',
      );
    }

    final incidentId = _uuid.v4();
    final transitionId = _uuid.v4();
    final now = DateTime.now();

    final incident = Incident(
      id: incidentId,
      orgId: orgId,
      title: title,
      description: description,
      state: IncidentState.draft,
      priority: priority,
      classification: classification,
      ownerId: actorId,
      locationLat: locationLat,
      locationLon: locationLon,
      createdAt: now,
      updatedAt: now,
    );

    final record = IncidentTransition(
      id: transitionId,
      incidentId: incidentId,
      fromState: IncidentState.draft,
      toState: IncidentState.draft,
      actorId: actorId,
      actorRole: _permissions.currentRole?.name,
      note: 'Incident created',
      timestamp: now,
    );

    await _db.insertIncident(incident);

    final db = _db.database;
    await db.insert('incident_transitions', record.toMap());

    AppLogging.incidents(
      'created incident $incidentId '
      '(title="$title", priority=${priority.name}, actor=$actorId)',
    );

    return incident;
  }

  // -----------------------------------------------------------------------
  // Query helpers
  // -----------------------------------------------------------------------

  /// Returns true if the transition from [current] to [target] is valid.
  bool canTransition(IncidentState current, IncidentState target) {
    return _validTransitions.contains((current, target));
  }

  /// Returns the set of valid target states from [current].
  Set<IncidentState> validTargets(IncidentState current) {
    return {
      for (final (from, to) in _validTransitions)
        if (from == current) to,
    };
  }

  // -----------------------------------------------------------------------
  // Transition execution
  // -----------------------------------------------------------------------

  /// Validates and executes the transition.
  ///
  /// 1. Validates the transition is in the valid-transitions table.
  /// 2. Checks RBAC via [PermissionService.canWith].
  /// 3. Writes transition record to `incident_transitions` (append-only).
  /// 4. Updates the `incidents` projection row.
  ///
  /// Throws [InvalidTransitionException] if the transition is invalid.
  /// Throws [InsufficientPermissionException] if the actor lacks the
  /// required role.
  Future<IncidentTransition> transition({
    required Incident incident,
    required IncidentState target,
    required String actorId,
    String? assigneeId,
    String? note,
  }) async {
    final current = incident.state;

    // --- Terminal state guard ---
    if (current.isTerminal) {
      final reason = 'terminal state: ${current.name}';
      AppLogging.incidents(
        'transition rejected ${incident.id}: '
        '${current.name} -> ${target.name} ($reason)',
      );
      throw InvalidTransitionException(
        'Cannot transition from ${current.name}: $reason',
      );
    }

    // --- Valid transition check ---
    if (!canTransition(current, target)) {
      final reason =
          '${current.name} -> ${target.name} is not a valid transition';
      AppLogging.incidents(
        'transition rejected ${incident.id}: '
        '${current.name} -> ${target.name} ($reason)',
      );
      throw InvalidTransitionException(reason);
    }

    // --- assigneeId required for assigned target ---
    if (target == IncidentState.assigned && assigneeId == null) {
      throw InvalidTransitionException(
        'assigneeId is required when transitioning to assigned',
      );
    }

    // --- RBAC check ---
    final permission = _permissionForTarget(target);
    final context = PermissionContext(
      incidentAssigneeId: incident.assigneeId,
      currentUserId: actorId,
    );

    if (!_permissions.canWith(permission, context)) {
      final roleName = _permissions.currentRole?.name ?? 'none';
      AppLogging.incidents(
        'transition rejected ${incident.id}: '
        '${current.name} -> ${target.name} '
        '(permission denied: ${permission.name}, role=$roleName)',
      );
      throw InsufficientPermissionException(
        '${permission.name} denied for role $roleName',
      );
    }

    // --- Write transition (append-only) ---
    final transitionId = _uuid.v4();
    final now = DateTime.now();

    final record = IncidentTransition(
      id: transitionId,
      incidentId: incident.id,
      fromState: current,
      toState: target,
      actorId: actorId,
      actorRole: _permissions.currentRole?.name,
      note: note,
      timestamp: now,
    );

    final db = _db.database;

    // 1) Append transition record (source of truth).
    await db.insert('incident_transitions', record.toMap());

    // 2) Update projection.
    await db.update(
      'incidents',
      {
        'state': target.name,
        'updatedAt': now.millisecondsSinceEpoch,
        if (target == IncidentState.assigned && assigneeId != null)
          'assigneeId': assigneeId,
      },
      where: 'id = ?',
      whereArgs: [incident.id],
    );

    final logSuffix = StringBuffer(
      'actor=$actorId, transitionId=$transitionId',
    );
    if (assigneeId != null) logSuffix.write(', assignee=$assigneeId');
    if (note != null) logSuffix.write(', note="$note"');

    AppLogging.incidents(
      'transition ${incident.id}: '
      '${current.name} -> ${target.name} ($logSuffix)',
    );

    return record;
  }

  // -----------------------------------------------------------------------
  // Projection rebuild (corruption recovery)
  // -----------------------------------------------------------------------

  /// Replays all non-superseded transitions for [incidentId] ordered by
  /// timestamp then transitionId (lexicographic tie-break per spec) and
  /// overwrites the `incidents.state` projection with the derived value.
  ///
  /// Delegates to [IncidentDatabase.rebuildProjection] which filters out
  /// superseded transitions.
  ///
  /// Returns the final [IncidentState] after replay.
  Future<IncidentState> rebuildProjection(String incidentId) async {
    return _db.rebuildProjection(incidentId);
  }
}
