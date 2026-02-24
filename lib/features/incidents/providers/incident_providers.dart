// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/claims_provider.dart';
import '../../../core/auth/permission_provider.dart';
import '../../../core/logging.dart';
import '../../../providers/auth_providers.dart';
import '../models/incident.dart';
import '../models/incident_transition.dart';
import '../services/incident_database.dart';
import '../services/incident_state_machine.dart';

// ---------------------------------------------------------------------------
// Database provider
// ---------------------------------------------------------------------------

/// Provides the [IncidentDatabase] singleton.
///
/// Callers must call `open()` before querying.
final incidentDatabaseProvider = Provider<IncidentDatabase>((ref) {
  final db = IncidentDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ---------------------------------------------------------------------------
// Filter state
// ---------------------------------------------------------------------------

/// Filter configuration for the incident list.
class IncidentFilter {
  final Set<IncidentState> states;
  final Set<IncidentPriority> priorities;
  final bool assignedToMe;

  const IncidentFilter({
    this.states = const {},
    this.priorities = const {},
    this.assignedToMe = false,
  });

  IncidentFilter copyWith({
    Set<IncidentState>? states,
    Set<IncidentPriority>? priorities,
    bool? assignedToMe,
  }) {
    return IncidentFilter(
      states: states ?? this.states,
      priorities: priorities ?? this.priorities,
      assignedToMe: assignedToMe ?? this.assignedToMe,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (states.isNotEmpty) parts.add('states=${states.map((s) => s.name)}');
    if (priorities.isNotEmpty) {
      parts.add('priorities=${priorities.map((p) => p.name)}');
    }
    if (assignedToMe) parts.add('assignedToMe');
    return parts.isEmpty ? 'none' : parts.join(', ');
  }
}

/// Provider for the current incident list filter.
class IncidentFilterNotifier extends Notifier<IncidentFilter> {
  @override
  IncidentFilter build() => const IncidentFilter();

  void setStates(Set<IncidentState> states) {
    state = state.copyWith(states: states);
  }

  void setPriorities(Set<IncidentPriority> priorities) {
    state = state.copyWith(priorities: priorities);
  }

  void toggleAssignedToMe() {
    state = state.copyWith(assignedToMe: !state.assignedToMe);
  }

  void clear() {
    state = const IncidentFilter();
  }
}

final incidentFilterProvider =
    NotifierProvider<IncidentFilterNotifier, IncidentFilter>(
      IncidentFilterNotifier.new,
    );

// ---------------------------------------------------------------------------
// Incident list provider
// ---------------------------------------------------------------------------

/// Loads incidents for the current orgId with applied filters.
///
/// Returns an empty list if the user has no orgId (consumer user).
final incidentListProvider = FutureProvider<List<Incident>>((ref) async {
  final orgId = ref.watch(orgIdProvider);
  if (orgId == null) return [];

  final filter = ref.watch(incidentFilterProvider);
  final db = ref.watch(incidentDatabaseProvider);
  await db.open();

  final currentUserId = ref.watch(currentUserProvider)?.uid;
  final assigneeId = filter.assignedToMe && currentUserId != null
      ? currentUserId
      : null;

  final incidents = await db.getIncidentsByOrgId(
    orgId,
    states: filter.states.isNotEmpty ? filter.states : null,
    priorities: filter.priorities.isNotEmpty ? filter.priorities : null,
    assigneeId: assigneeId,
  );

  AppLogging.incidentUI(
    'list loaded (orgId=$orgId, count=${incidents.length}, '
    'filter=${filter.toString()})',
  );

  return incidents;
});

// ---------------------------------------------------------------------------
// Incident detail provider
// ---------------------------------------------------------------------------

/// Loads a single incident by ID.
final incidentDetailProvider = FutureProvider.family<Incident?, String>((
  ref,
  incidentId,
) async {
  final db = ref.watch(incidentDatabaseProvider);
  await db.open();
  return db.getIncidentById(incidentId);
});

// ---------------------------------------------------------------------------
// Transitions provider
// ---------------------------------------------------------------------------

/// Loads the full transition history for an incident (immutable timeline).
final incidentTransitionsProvider =
    FutureProvider.family<List<IncidentTransition>, String>((
      ref,
      incidentId,
    ) async {
      final db = ref.watch(incidentDatabaseProvider);
      await db.open();
      final transitions = await db.getTransitionsByIncidentId(incidentId);

      AppLogging.incidentUI(
        'detail loaded incident $incidentId (transitions=${transitions.length})',
      );

      return transitions;
    });

// ---------------------------------------------------------------------------
// Actions controller
// ---------------------------------------------------------------------------

/// Centralised incident action controller.
///
/// Handles create and transition actions with error handling and loading
/// states. Invalidates dependent providers after mutations.
class IncidentActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  IncidentStateMachine _stateMachine() {
    final db = ref.read(incidentDatabaseProvider);
    final permissions = ref.read(permissionServiceProvider);
    return IncidentStateMachine(db: db, permissions: permissions);
  }

  String? get _currentUserId => ref.read(currentUserProvider)?.uid;
  String? get _currentOrgId => ref.read(orgIdProvider);

  /// Creates a new incident and returns it.
  Future<Incident?> createIncident({
    required String title,
    String? description,
    IncidentPriority priority = IncidentPriority.routine,
    IncidentClassification classification = IncidentClassification.operational,
    double? locationLat,
    double? locationLon,
  }) async {
    final userId = _currentUserId;
    final orgId = _currentOrgId;
    if (userId == null || orgId == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncLoading();
    try {
      final sm = _stateMachine();
      final db = ref.read(incidentDatabaseProvider);
      await db.open();

      final incident = await sm.createIncident(
        orgId: orgId,
        title: title,
        description: description,
        priority: priority,
        classification: classification,
        actorId: userId,
        locationLat: locationLat,
        locationLon: locationLon,
      );

      ref.invalidate(incidentListProvider);
      state = const AsyncData(null);
      return incident;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Applies a state transition to an incident.
  Future<bool> applyTransition({
    required Incident incident,
    required IncidentState target,
    String? assigneeId,
    String? note,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncLoading();
    try {
      final sm = _stateMachine();
      await sm.transition(
        incident: incident,
        target: target,
        actorId: userId,
        assigneeId: assigneeId,
        note: note,
      );

      ref.invalidate(incidentListProvider);
      ref.invalidate(incidentDetailProvider(incident.id));
      ref.invalidate(incidentTransitionsProvider(incident.id));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final incidentActionsProvider =
    NotifierProvider<IncidentActionsNotifier, AsyncValue<void>>(
      IncidentActionsNotifier.new,
    );
