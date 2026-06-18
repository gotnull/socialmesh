// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pure reducer for the unified Incident Mode domain model.
///
/// [IncidentReducer.project] replays an immutable [IncidentEvent] timeline into
/// the effective local [IncidentProjection]. It is deterministic and pure: the
/// same set of events always yields the same projection regardless of input
/// order, and it performs no I/O.
///
/// Responsibilities:
/// - Deduplicate by `(incidentId, senderNodeId, seq)`.
/// - Apply correction / supersession (an event with `refSeq` supersedes the
///   event sharing that seq within the same incident).
/// - Order the timeline deterministically.
/// - Project the help-request responder lifecycle for help requests.
/// - Project the reporting status for hazard reports WITHOUT ever entering the
///   personal-help lifecycle.
///
/// Wire formats and numeric protocol constants are out of scope -- this reducer
/// operates purely on domain objects.
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md
library;

import '../../../services/protocol/sip/spp_types.dart';
import '../models/incident_mode_models.dart';

/// Stateless projector from an incident event log to its effective state.
abstract final class IncidentReducer {
  /// Responder progress ranks used to derive the help lifecycle.
  static const int _progressAccepted = 0;
  static const int _progressEnRoute = 1;
  static const int _progressArrived = 2;

  /// Project a single incident's event log into its effective state.
  ///
  /// All events must belong to the same `incidentId`. Throws [ArgumentError]
  /// for an empty log or a log spanning multiple incidents.
  static IncidentProjection project(Iterable<IncidentEvent> events) {
    final raw = List<IncidentEvent>.of(events);
    if (raw.isEmpty) {
      throw ArgumentError('Cannot project an empty incident event log');
    }

    // 1. Deduplicate by composite key, keeping one event per key.
    final byKey = <String, IncidentEvent>{};
    for (final e in raw) {
      byKey.putIfAbsent(e.dedupeKey, () => e);
    }
    final deduped = byKey.values.toList();

    // 2. Enforce single-incident invariant.
    final incidentId = deduped.first.incidentId;
    if (deduped.any((e) => e.incidentId != incidentId)) {
      throw ArgumentError(
        'project() received events for multiple incidents; '
        'group by incidentId first',
      );
    }

    // 3. Deterministic ordering -- independent of input order.
    deduped.sort(_compareEvents);

    // 4. Apply supersession: a correction supersedes the event with the
    //    referenced seq within the same incident.
    final supersededSeqs = <int>{
      for (final e in deduped)
        if (e.refSeq != null) e.refSeq!,
    };
    final timeline = supersededSeqs.isEmpty
        ? deduped
        : [
            for (final e in deduped)
              if (supersededSeqs.contains(e.seq) && !e.isCorrection)
                e.copyWith(isSuperseded: true)
              else
                e,
          ];

    final createEvent = timeline
        .where((e) => e.type == IncidentEventType.create)
        .cast<IncidentEvent?>()
        .firstWhere((_) => true, orElse: () => null);

    final workflowKind =
        createEvent?.workflowKind ?? timeline.first.workflowKind;
    final createdAt = timeline.first.timestamp;
    final updatedAt = timeline.last.timestamp;

    if (workflowKind == IncidentWorkflowKind.helpRequest) {
      return _projectHelp(
        incidentId: incidentId,
        timeline: timeline,
        createEvent: createEvent,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }
    return _projectHazard(
      incidentId: incidentId,
      timeline: timeline,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // --- help-request projection -------------------------------------------

  static IncidentProjection _projectHelp({
    required int incidentId,
    required List<IncidentEvent> timeline,
    required IncidentEvent? createEvent,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final live = timeline.where((e) => !e.isSuperseded).toList();
    final originNodeId = createEvent?.senderNodeId ?? live.first.senderNodeId;
    final expiresAt = createEvent?.expiresAt;

    // Terminal events win, latest-timestamp first (precedence breaks ties).
    final terminal = _latestTerminal(live);

    // Active responder set and per-responder progress.
    final progress = <int, int>{};
    final responderLastStatus = <int, IncidentQuickUpdate>{};
    final lastSeen = <int, DateTime>{};
    var acknowledged = false;
    IncidentQuickUpdate? lastRequesterStatus;
    IncidentLocation? lastRequesterLocation;

    for (final e in live) {
      lastSeen[e.senderNodeId] = e.timestamp;
      switch (e.type) {
        case IncidentEventType.responderAccept:
          progress.putIfAbsent(e.senderNodeId, () => _progressAccepted);
          acknowledged = true;
        case IncidentEventType.responderLeave:
          progress.remove(e.senderNodeId);
        case IncidentEventType.responderStatus:
          if (progress.containsKey(e.senderNodeId) && e.quickUpdate != null) {
            responderLastStatus[e.senderNodeId] = e.quickUpdate!;
            final rank = _progressForStatus(e.quickUpdate!);
            if (rank > progress[e.senderNodeId]!) {
              progress[e.senderNodeId] = rank;
            }
          }
        case IncidentEventType.requesterStatus:
          if (e.senderNodeId == originNodeId && e.quickUpdate != null) {
            lastRequesterStatus = e.quickUpdate;
          }
        case IncidentEventType.ack:
          if (e.ackCategory != null &&
              e.ackCategory != IncidentAckCategory.resolved) {
            acknowledged = true;
          }
        case IncidentEventType.seen:
          acknowledged = true;
        case IncidentEventType.location:
          if (e.senderNodeId == originNodeId && e.location != null) {
            lastRequesterLocation = e.location;
          }
        case IncidentEventType.create:
        case IncidentEventType.message:
        case IncidentEventType.resolve:
        case IncidentEventType.cancel:
        case IncidentEventType.expire:
        case IncidentEventType.hazardReport:
          break;
      }
    }

    final IncidentLifecycleState state;
    if (terminal != null) {
      state = _terminalState(terminal.type);
    } else if (createEvent == null) {
      // No create observed yet -- treat as locally composed.
      state = IncidentLifecycleState.draft;
    } else if (progress.isNotEmpty) {
      final overall = progress.values.reduce((a, b) => a > b ? a : b);
      state = switch (overall) {
        _progressArrived => IncidentLifecycleState.responderArrived,
        _progressEnRoute => IncidentLifecycleState.responderEnRoute,
        _ => IncidentLifecycleState.activeWithResponder,
      };
    } else {
      state = acknowledged
          ? IncidentLifecycleState.activeNoResponder
          : IncidentLifecycleState.broadcasting;
    }

    final participants = <IncidentParticipant>[
      IncidentParticipant(
        incidentId: incidentId,
        nodeId: originNodeId,
        role: IncidentRole.requester,
        lastStatus: lastRequesterStatus,
        lastSeen: lastSeen[originNodeId],
        deliveryState: _requesterDelivery(state),
      ),
      for (final nodeId in progress.keys)
        IncidentParticipant(
          incidentId: incidentId,
          nodeId: nodeId,
          role: IncidentRole.responder,
          lastStatus: responderLastStatus[nodeId],
          lastSeen: lastSeen[nodeId],
          deliveryState: IncidentDeliveryState.accepted,
        ),
    ]..sort((a, b) => a.nodeId.compareTo(b.nodeId));

    return IncidentProjection(
      incidentId: incidentId,
      workflowKind: IncidentWorkflowKind.helpRequest,
      originNodeId: originNodeId,
      helpState: state,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      lastRequesterStatus: lastRequesterStatus,
      lastRequesterLocation: lastRequesterLocation,
      locationSharing: !state.isTerminal && createEvent != null,
      participants: participants,
      timeline: timeline,
    );
  }

  // --- hazard-report projection ------------------------------------------

  static IncidentProjection _projectHazard({
    required int incidentId,
    required List<IncidentEvent> timeline,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final hazardEvents = timeline
        .where((e) => e.type == IncidentEventType.hazardReport)
        .toList();
    final live = hazardEvents.where((e) => !e.isSuperseded).toList();
    final effective = live.isNotEmpty ? live.last : hazardEvents.last;

    final initial = hazardEvents.firstWhere(
      (e) => e.hazardUpdateType == IncidentUpdateType.initial,
      orElse: () => hazardEvents.first,
    );

    return IncidentProjection(
      incidentId: incidentId,
      workflowKind: IncidentWorkflowKind.hazardReport,
      originNodeId: initial.senderNodeId,
      // helpState intentionally left null: hazard reports never enter the
      // personal-help responder lifecycle.
      hazardStatus: effective.hazardStatus,
      createdAt: createdAt,
      updatedAt: updatedAt,
      locationSharing: false,
      participants: const [],
      timeline: timeline,
    );
  }

  // --- helpers -----------------------------------------------------------

  static int _compareEvents(IncidentEvent a, IncidentEvent b) {
    final byTime = a.timestamp.millisecondsSinceEpoch.compareTo(
      b.timestamp.millisecondsSinceEpoch,
    );
    if (byTime != 0) return byTime;
    final bySeq = a.seq.compareTo(b.seq);
    if (bySeq != 0) return bySeq;
    final bySender = a.senderNodeId.compareTo(b.senderNodeId);
    if (bySender != 0) return bySender;
    return a.type.index.compareTo(b.type.index);
  }

  static int _progressForStatus(IncidentQuickUpdate status) {
    return switch (status) {
      IncidentQuickUpdate.arrived => _progressArrived,
      IncidentQuickUpdate.onMyWay => _progressEnRoute,
      _ => _progressAccepted,
    };
  }

  /// Pick the governing terminal event: latest timestamp, then by precedence
  /// resolve > cancel > expire on ties.
  static IncidentEvent? _latestTerminal(List<IncidentEvent> live) {
    IncidentEvent? best;
    for (final e in live) {
      if (!_isTerminalType(e.type)) continue;
      if (best == null) {
        best = e;
        continue;
      }
      final cmp = e.timestamp.compareTo(best.timestamp);
      if (cmp > 0 ||
          (cmp == 0 &&
              _terminalPrecedence(e.type) > _terminalPrecedence(best.type))) {
        best = e;
      }
    }
    return best;
  }

  static bool _isTerminalType(IncidentEventType type) =>
      type == IncidentEventType.resolve ||
      type == IncidentEventType.cancel ||
      type == IncidentEventType.expire;

  static int _terminalPrecedence(IncidentEventType type) {
    return switch (type) {
      IncidentEventType.resolve => 3,
      IncidentEventType.cancel => 2,
      IncidentEventType.expire => 1,
      _ => 0,
    };
  }

  static IncidentLifecycleState _terminalState(IncidentEventType type) {
    return switch (type) {
      IncidentEventType.resolve => IncidentLifecycleState.resolvedSafe,
      IncidentEventType.cancel => IncidentLifecycleState.cancelled,
      IncidentEventType.expire => IncidentLifecycleState.expired,
      _ => IncidentLifecycleState.broadcasting,
    };
  }

  static IncidentDeliveryState _requesterDelivery(
    IncidentLifecycleState state,
  ) {
    return switch (state) {
      IncidentLifecycleState.resolvedSafe => IncidentDeliveryState.resolved,
      IncidentLifecycleState.expired => IncidentDeliveryState.expired,
      IncidentLifecycleState.draft => IncidentDeliveryState.pending,
      _ => IncidentDeliveryState.sent,
    };
  }
}
