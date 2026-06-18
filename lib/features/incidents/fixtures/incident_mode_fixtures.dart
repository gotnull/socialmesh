// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// FIXTURE / DEV / TEST-ONLY data for the Incident Mode (Help Mode) UI.
///
/// These builders synthesise [IncidentEvent] logs and project them through the
/// real [IncidentReducer] so the UI can be reviewed without any mesh transport
/// or persisted state. NONE of this is wired to inbound packets or the store --
/// it must never be mistaken for real incident data.
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md (PR-6 fixture UI)
library;

import '../models/incident_mode_models.dart';
import '../services/incident_mode_reducer.dart';

/// Fixture constants used across the Help Mode preview surfaces.
abstract final class IncidentModeFixtures {
  /// Stable fixture incident id (clearly not a real origin-allocated id).
  static const int incidentId = 0xF1A7;
  static const int requesterNode = 4242;
  static const int responderA = 5151;
  static const int responderB = 6262;

  /// Display name used in the inbound-alert fixture.
  static const String requesterName = 'Jordan';

  // A fixed base clock keeps projections deterministic. Location "age" in the
  // responder view is computed against wall-clock at render time, which is
  // acceptable for a preview surface.
  static final DateTime _base = DateTime.utc(2026, 6, 17, 10);
  static DateTime _at(int minutes) => _base.add(Duration(minutes: minutes));

  static IncidentEvent _create({DateTime? expiresAt}) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: IncidentEventType.create,
    senderNodeId: requesterNode,
    seq: 0,
    timestamp: _at(0),
    receivedAt: _at(0),
    expiresAt: expiresAt,
  );

  static IncidentEvent _event({
    required IncidentEventType type,
    required int sender,
    required int seq,
    required int minute,
    IncidentQuickUpdate? quickUpdate,
    IncidentAckCategory? ackCategory,
    IncidentLocation? location,
    IncidentMessage? message,
  }) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: type,
    senderNodeId: sender,
    seq: seq,
    timestamp: _at(minute),
    receivedAt: _at(minute),
    quickUpdate: quickUpdate,
    ackCategory: ackCategory,
    location: location,
    message: message,
  );

  static IncidentLocation _location({int minutesAgo = 2}) => IncidentLocation(
    incidentId: incidentId,
    nodeId: requesterNode,
    latitude: -33.8688,
    longitude: 151.2093,
    accuracyMeters: 12,
    // Recent-ish fix so the responder view shows a believable age.
    fixedAt: DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)),
  );

  /// Requester just raised a request; no ack or responder yet.
  static IncidentProjection broadcasting() =>
      IncidentReducer.project([_create()]);

  /// Acknowledged by a peer but no responder accepted.
  static IncidentProjection activeNoResponder() => IncidentReducer.project([
    _create(),
    _event(
      type: IncidentEventType.ack,
      sender: responderA,
      seq: 0,
      minute: 1,
      ackCategory: IncidentAckCategory.received,
    ),
  ]);

  /// One responder has accepted.
  static IncidentProjection activeWithResponder() => IncidentReducer.project([
    _create(),
    _event(
      type: IncidentEventType.location,
      sender: requesterNode,
      seq: 1,
      minute: 1,
      location: _location(minutesAgo: 3),
    ),
    _event(
      type: IncidentEventType.responderAccept,
      sender: responderA,
      seq: 0,
      minute: 2,
    ),
  ]);

  /// Responder is en route.
  static IncidentProjection responderEnRoute() => IncidentReducer.project([
    _create(),
    _event(
      type: IncidentEventType.responderAccept,
      sender: responderA,
      seq: 0,
      minute: 2,
    ),
    _event(
      type: IncidentEventType.responderStatus,
      sender: responderA,
      seq: 1,
      minute: 3,
      quickUpdate: IncidentQuickUpdate.onMyWay,
    ),
  ]);

  /// Responder has arrived (with a second responder and a requester status).
  static IncidentProjection responderArrived() => IncidentReducer.project([
    _create(),
    _event(
      type: IncidentEventType.requesterStatus,
      sender: requesterNode,
      seq: 1,
      minute: 1,
      quickUpdate: IncidentQuickUpdate.imInjured,
    ),
    _event(
      type: IncidentEventType.location,
      sender: requesterNode,
      seq: 2,
      minute: 1,
      location: _location(),
    ),
    _event(
      type: IncidentEventType.responderAccept,
      sender: responderA,
      seq: 0,
      minute: 2,
    ),
    _event(
      type: IncidentEventType.responderAccept,
      sender: responderB,
      seq: 0,
      minute: 2,
    ),
    _event(
      type: IncidentEventType.responderStatus,
      sender: responderA,
      seq: 1,
      minute: 3,
      quickUpdate: IncidentQuickUpdate.onMyWay,
    ),
    _event(
      type: IncidentEventType.responderStatus,
      sender: responderA,
      seq: 2,
      minute: 4,
      quickUpdate: IncidentQuickUpdate.arrived,
    ),
  ]);

  /// Resolved safe.
  static IncidentProjection resolvedSafe() => IncidentReducer.project([
    _create(),
    _event(
      type: IncidentEventType.responderAccept,
      sender: responderA,
      seq: 0,
      minute: 2,
    ),
    _event(
      type: IncidentEventType.resolve,
      sender: requesterNode,
      seq: 1,
      minute: 6,
    ),
  ]);

  /// Cancelled (false alarm).
  static IncidentProjection cancelled() => IncidentReducer.project([
    _create(),
    _event(
      type: IncidentEventType.cancel,
      sender: requesterNode,
      seq: 1,
      minute: 3,
    ),
  ]);

  /// Expired with no response.
  static IncidentProjection expired() => IncidentReducer.project([
    _create(expiresAt: _at(30)),
    _event(
      type: IncidentEventType.expire,
      sender: requesterNode,
      seq: 1,
      minute: 31,
    ),
  ]);

  /// Sample incident-scoped messages.
  static List<IncidentMessage> messages() => [
    IncidentMessage(
      incidentId: incidentId,
      senderNodeId: requesterNode,
      seq: 3,
      text: 'Near the north gate, by the water tank.',
      timestamp: _at(2),
    ),
    IncidentMessage(
      incidentId: incidentId,
      senderNodeId: responderA,
      seq: 1,
      text: 'On my way, five minutes out.',
      timestamp: _at(3),
    ),
  ];
}
