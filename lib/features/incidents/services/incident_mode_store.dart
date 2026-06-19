// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Persistence + projection facade for the unified Incident Mode event log.
///
/// The event log is the single source of truth. Participants, locations,
/// messages, and lifecycle state are NOT stored as hand-maintained rows --
/// they are derived on demand by [IncidentReducer.project], mirroring how the
/// legacy hazard path derives `MeshIncidentCaseState` from its report rows.
///
/// Trust discipline: [IncidentModeStore] persists events that have ALREADY
/// passed Handshake-trust gating. It does not perform trust checks itself, and
/// it is never wired to an untrusted inbound source. The MRRP help-event sink
/// stays unwired until the trust gate is cleanly enforced (see
/// `docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md` PR-7).
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md
library;

import '../models/incident_mode_models.dart';
import 'incident_mode_reducer.dart';

/// Raw event-log persistence contract for Incident Mode.
///
/// Implemented by the SQLite-backed `MeshIncidentDatabaseImpl`. Extracted as an
/// interface so the store can be unit-tested and so future providers depend on
/// the contract rather than the concrete database.
abstract class IncidentModeDatabase {
  /// Inserts one event, idempotent on `(incidentId, senderNodeId, seq)`.
  ///
  /// Returns true if a new row was inserted, false if it was a duplicate that
  /// was ignored.
  Future<bool> insertIncidentEvent(IncidentEvent event);

  /// All events for [incidentId], ordered deterministically by
  /// `(timestamp, seq, senderNodeId)`.
  Future<List<IncidentEvent>> getIncidentEvents(int incidentId);

  /// Candidate help_request incident ids that have no terminal event
  /// (resolve / cancel / expire), most recently active first.
  Future<List<int>> getActiveHelpRequestIds({int limit});

  /// Largest incident id currently stored, or 0 if the log is empty. Used to
  /// allocate a fresh local incident id.
  Future<int> getMaxIncidentId();
}

/// Stores decoded [IncidentEvent] facts and derives projections through
/// [IncidentReducer]. The reducer is the only lifecycle-projection authority;
/// this store never hand-maintains lifecycle state.
class IncidentModeStore {
  final IncidentModeDatabase _db;

  IncidentModeStore({required this._db});

  /// Ingests one already-trusted, already-decoded event.
  ///
  /// Returns whether the event was new (true) or a duplicate that was ignored
  /// (false). Callers MUST apply Handshake-trust gating before calling this;
  /// the store assumes the event has already passed trust checks.
  Future<bool> ingestEvent(IncidentEvent event) =>
      _db.insertIncidentEvent(event);

  /// Ingests a batch of already-trusted events, returning the count newly
  /// inserted (duplicates are skipped).
  Future<int> ingestEvents(Iterable<IncidentEvent> events) async {
    var inserted = 0;
    for (final e in events) {
      if (await _db.insertIncidentEvent(e)) inserted++;
    }
    return inserted;
  }

  /// The full event timeline for one incident, deterministically ordered.
  Future<List<IncidentEvent>> getTimeline(int incidentId) =>
      _db.getIncidentEvents(incidentId);

  /// Alias for [getTimeline] -- raw events for one incident.
  Future<List<IncidentEvent>> getIncidentEvents(int incidentId) =>
      _db.getIncidentEvents(incidentId);

  /// Loads and projects one incident, or null if it has no events.
  Future<IncidentProjection?> loadIncidentProjection(int incidentId) async {
    final events = await _db.getIncidentEvents(incidentId);
    if (events.isEmpty) return null;
    return IncidentReducer.project(events);
  }

  /// Allocates the next local incident id (largest stored id + 1).
  ///
  /// This is a local monotonic scheme. It does NOT guarantee global uniqueness
  /// across devices -- true origin-allocated unique ids are deferred. Adequate
  /// for the flag-gated review build and tests.
  Future<int> nextLocalIncidentId() async => (await _db.getMaxIncidentId()) + 1;

  /// Allocates the next per-sender sequence number for [localNodeId] within
  /// [incidentId] (monotonic; 0 for the first local event).
  Future<int> nextLocalSeq(int incidentId, int localNodeId) async {
    final mine = (await _db.getIncidentEvents(
      incidentId,
    )).where((e) => e.senderNodeId == localNodeId).map((e) => e.seq);
    if (mine.isEmpty) return 0;
    return mine.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Active (non-terminal) help_request incidents, newest first.
  ///
  /// Resolved / cancelled / expired incidents are excluded. Hazard-report
  /// incidents are never returned here.
  Future<List<IncidentProjection>> getActiveHelpRequests({
    int limit = 32,
  }) async {
    final ids = await _db.getActiveHelpRequestIds(limit: limit);
    final out = <IncidentProjection>[];
    for (final id in ids) {
      final events = await _db.getIncidentEvents(id);
      if (events.isEmpty) continue;
      final projection = IncidentReducer.project(events);
      if (projection.workflowKind == IncidentWorkflowKind.helpRequest &&
          !projection.isTerminal) {
        out.add(projection);
      }
    }
    return out;
  }
}
