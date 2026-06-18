// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Unified Incident Mode domain model.
///
/// This is the pure, transport-agnostic domain layer that backs both
/// incident workflows on the mesh:
///
/// - [IncidentWorkflowKind.hazardReport] -- CAP-style field-hazard reporting
///   (the workflow already implemented by [MeshIncidentReport]).
/// - [IncidentWorkflowKind.helpRequest] -- the personal "Help Mode" / SOS
///   request with a responder lifecycle.
///
/// The wire format, SPP type ids, MRRP service ids, and capability bits are
/// intentionally NOT defined here -- they are owned by the protocol layer and
/// land in a later change. This file deals only with in-memory domain objects
/// and serialises enums by `.name` so it carries no numeric protocol constants.
///
/// State is never stored as a field on the wire. The effective local state of
/// an incident is a projection ([IncidentProjection]) derived by replaying its
/// immutable [IncidentEvent] timeline through [IncidentReducer.project].
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md
library;

import '../../../services/protocol/sip/spp_types.dart';

/// Which incident workflow an event or projection belongs to.
///
/// The two workflows share the same envelope, persistence, timeline, and
/// dedupe machinery but have different lifecycles. Hazard reporting must never
/// be forced into the personal-help responder lifecycle.
enum IncidentWorkflowKind { hazardReport, helpRequest }

/// The role a participant plays within a help-request incident.
enum IncidentRole { requester, responder }

/// Domain-level event discriminator.
///
/// These are semantic event kinds, NOT wire codes. The mapping between these
/// and on-wire `msg_type` values is owned by the codec in a later change.
enum IncidentEventType {
  /// Hazard-report workflow: a field report (initial / update / correction /
  /// closure -- distinguished by [IncidentEvent.hazardUpdateType]).
  hazardReport,

  /// Help-request workflow: requester raises a help request.
  create,

  /// Help-request workflow: delivery / surfacing / responding / resolved ack.
  ack,

  /// Help-request workflow: a receiver surfaced the request in its UI.
  seen,

  /// Help-request workflow: a peer accepts and becomes a responder.
  responderAccept,

  /// Help-request workflow: a responder stands down.
  responderLeave,

  /// Help-request workflow: requester quick-status update.
  requesterStatus,

  /// Help-request workflow: responder quick-status update.
  responderStatus,

  /// Help-request workflow: an escalated location sample.
  location,

  /// Help-request workflow: an incident-scoped chat message.
  message,

  /// Help-request workflow: requester is safe; responders stand down.
  resolve,

  /// Help-request workflow: false alarm; stop the request.
  cancel,

  /// Help-request workflow: request expired with no resolution.
  expire,
}

/// Local lifecycle state for a help-request incident.
///
/// This is a UI projection produced by [IncidentReducer], not a wire value.
/// Hazard-report incidents never enter these states (their projected status is
/// the separate [IncidentProjection.hazardStatus]).
enum IncidentLifecycleState {
  /// Composed locally but not yet raised (no wire event yet).
  draft,

  /// Raised and searching; no acknowledgement or responder observed yet.
  broadcasting,

  /// Acknowledged by at least one peer but no responder has accepted.
  activeNoResponder,

  /// At least one responder has accepted.
  activeWithResponder,

  /// A responder is en route ([IncidentQuickUpdate.onMyWay]).
  responderEnRoute,

  /// A responder has arrived ([IncidentQuickUpdate.arrived]).
  responderArrived,

  /// Requester marked safe; responders stand down. Terminal.
  resolvedSafe,

  /// Requester cancelled (false alarm / stop request). Terminal.
  cancelled,

  /// Request expired with no resolution. Terminal.
  expired;

  /// Whether this state is terminal (no further transitions expected).
  bool get isTerminal =>
      this == resolvedSafe || this == cancelled || this == expired;
}

/// Typed quick-status codes for the help-request workflow.
///
/// Requester and responder codes share one enum for ergonomic event payloads;
/// [isRequesterCode] / [isResponderCode] partition them.
enum IncidentQuickUpdate {
  // Requester codes.
  imOk,
  imInjured,
  cantMove,
  needWater,
  needMedical,
  falseAlarm,
  situationWorse,

  // Responder codes.
  onMyWay,
  arrived,
  needBackup,
  blocked,
  cantReachYou,
  leavingResponse;

  /// Whether this code is sent by the requester.
  bool get isRequesterCode => switch (this) {
    imOk ||
    imInjured ||
    cantMove ||
    needWater ||
    needMedical ||
    falseAlarm ||
    situationWorse => true,
    _ => false,
  };

  /// Whether this code is sent by a responder.
  bool get isResponderCode => !isRequesterCode;
}

/// Acknowledgement categories carried by an [IncidentEventType.ack] event.
///
/// Ordered by progression: a peer received, then surfaced, then accepted
/// (became a responder), and finally observed resolution.
enum IncidentAckCategory { received, surfaced, accepted, resolved }

/// Per-participant delivery / engagement state.
///
/// Tracks how far an incident has progressed with respect to a given peer.
/// Full transport-driven delivery tracking lands with the wiring change; here
/// it is a projected convenience derived from the event log.
enum IncidentDeliveryState {
  pending,
  sent,
  received,
  surfaced,
  accepted,
  resolved,
  expired,
  failed,
}

/// An escalated location sample associated with an incident.
///
/// Stores plain doubles; constructing a map `LatLng` from these values is the
/// caller's responsibility and must route through `safeLatLng`.
class IncidentLocation {
  final int incidentId;
  final int nodeId;
  final double latitude;
  final double longitude;

  /// Horizontal accuracy in metres, if known.
  final double? accuracyMeters;

  /// When the GPS fix was taken (used to display location age).
  final DateTime fixedAt;

  /// Local receive timestamp (null for locally-originated samples).
  final DateTime? receivedAt;

  const IncidentLocation({
    required this.incidentId,
    required this.nodeId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.fixedAt,
    this.receivedAt,
  });

  /// Whether both coordinates are finite (cheap defence-in-depth before any
  /// downstream `safeLatLng`).
  bool get isFinite => latitude.isFinite && longitude.isFinite;

  /// Age of the GPS fix relative to [now].
  Duration ageFrom(DateTime now) => now.difference(fixedAt);

  IncidentLocation copyWith({
    int? incidentId,
    int? nodeId,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    DateTime? fixedAt,
    DateTime? receivedAt,
  }) {
    return IncidentLocation(
      incidentId: incidentId ?? this.incidentId,
      nodeId: nodeId ?? this.nodeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      fixedAt: fixedAt ?? this.fixedAt,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'nodeId': nodeId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'fixedAt': fixedAt.millisecondsSinceEpoch,
      'receivedAt': receivedAt?.millisecondsSinceEpoch,
    };
  }

  factory IncidentLocation.fromMap(Map<String, dynamic> map) {
    return IncidentLocation(
      incidentId: map['incidentId'] as int,
      nodeId: map['nodeId'] as int,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      fixedAt: DateTime.fromMillisecondsSinceEpoch(
        map['fixedAt'] as int,
        isUtc: true,
      ),
      receivedAt: map['receivedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['receivedAt'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  @override
  String toString() =>
      'IncidentLocation(incident=$incidentId, node=$nodeId, '
      '$latitude,$longitude)';
}

/// An incident-scoped chat message.
///
/// Untrusted text is sanitised with `sanitizeExternalText` at the ingest /
/// codec boundary, not in this pure model.
class IncidentMessage {
  final int incidentId;
  final int senderNodeId;
  final int seq;
  final String text;
  final DateTime timestamp;

  const IncidentMessage({
    required this.incidentId,
    required this.senderNodeId,
    required this.seq,
    required this.text,
    required this.timestamp,
  });

  IncidentMessage copyWith({
    int? incidentId,
    int? senderNodeId,
    int? seq,
    String? text,
    DateTime? timestamp,
  }) {
    return IncidentMessage(
      incidentId: incidentId ?? this.incidentId,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      seq: seq ?? this.seq,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'senderNodeId': senderNodeId,
      'seq': seq,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory IncidentMessage.fromMap(Map<String, dynamic> map) {
    return IncidentMessage(
      incidentId: map['incidentId'] as int,
      senderNodeId: map['senderNodeId'] as int,
      seq: map['seq'] as int,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
        isUtc: true,
      ),
    );
  }

  @override
  String toString() =>
      'IncidentMessage(incident=$incidentId, node=$senderNodeId, seq=$seq)';
}

/// A participant in an incident (requester or responder), as projected from
/// the event log.
class IncidentParticipant {
  final int incidentId;
  final int nodeId;
  final IncidentRole role;

  /// Latest quick-status this participant sent, if any.
  final IncidentQuickUpdate? lastStatus;

  /// Latest time this participant was observed (event timestamp).
  final DateTime? lastSeen;

  /// Projected delivery / engagement state for this participant.
  final IncidentDeliveryState deliveryState;

  const IncidentParticipant({
    required this.incidentId,
    required this.nodeId,
    required this.role,
    this.lastStatus,
    this.lastSeen,
    this.deliveryState = IncidentDeliveryState.pending,
  });

  IncidentParticipant copyWith({
    int? incidentId,
    int? nodeId,
    IncidentRole? role,
    IncidentQuickUpdate? lastStatus,
    DateTime? lastSeen,
    IncidentDeliveryState? deliveryState,
  }) {
    return IncidentParticipant(
      incidentId: incidentId ?? this.incidentId,
      nodeId: nodeId ?? this.nodeId,
      role: role ?? this.role,
      lastStatus: lastStatus ?? this.lastStatus,
      lastSeen: lastSeen ?? this.lastSeen,
      deliveryState: deliveryState ?? this.deliveryState,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'nodeId': nodeId,
      'role': role.name,
      'lastStatus': lastStatus?.name,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'deliveryState': deliveryState.name,
    };
  }

  factory IncidentParticipant.fromMap(Map<String, dynamic> map) {
    return IncidentParticipant(
      incidentId: map['incidentId'] as int,
      nodeId: map['nodeId'] as int,
      role: IncidentRole.values.byName(map['role'] as String),
      lastStatus: map['lastStatus'] != null
          ? IncidentQuickUpdate.values.byName(map['lastStatus'] as String)
          : null,
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['lastSeen'] as int,
              isUtc: true,
            )
          : null,
      deliveryState: IncidentDeliveryState.values.byName(
        map['deliveryState'] as String,
      ),
    );
  }

  @override
  String toString() =>
      'IncidentParticipant(incident=$incidentId, node=$nodeId, '
      'role=${role.name}, delivery=${deliveryState.name})';
}

/// An immutable event in an incident's timeline.
///
/// One [IncidentEvent] corresponds to one decoded application frame (or one
/// locally-originated action). The effective incident state is derived by
/// replaying the event log -- never stored on an event itself.
///
/// Identity for deduplication is `(incidentId, senderNodeId, seq)`.
class IncidentEvent {
  /// Origin-allocated incident identifier.
  final int incidentId;

  /// Which workflow this event belongs to.
  final IncidentWorkflowKind workflowKind;

  /// Semantic event kind.
  final IncidentEventType type;

  /// Node id of the sender (0 for locally-originated events).
  final int senderNodeId;

  /// Per-sender monotonic sequence number.
  final int seq;

  /// Sender-clock timestamp.
  final DateTime timestamp;

  /// Local receive timestamp (null for locally-originated events).
  final DateTime? receivedAt;

  /// Sequence number this event corrects / supersedes, if any.
  final int? refSeq;

  /// Whether this event has been superseded by a later correction.
  final bool isSuperseded;

  // --- help-request payload fields (null for hazard events) ---

  /// Quick-status code, for [IncidentEventType.requesterStatus] /
  /// [IncidentEventType.responderStatus].
  final IncidentQuickUpdate? quickUpdate;

  /// Acknowledgement category, for [IncidentEventType.ack].
  final IncidentAckCategory? ackCategory;

  /// Location sample, for [IncidentEventType.location].
  final IncidentLocation? location;

  /// Chat message, for [IncidentEventType.message].
  final IncidentMessage? message;

  /// Expiry horizon carried by an [IncidentEventType.create] event.
  final DateTime? expiresAt;

  // --- hazard-report payload fields (null for help events) ---

  /// Hazard reporting status, for [IncidentEventType.hazardReport].
  final IncidentMeshStatus? hazardStatus;

  /// Hazard update kind (initial / update / correction / closure).
  final IncidentUpdateType? hazardUpdateType;

  const IncidentEvent({
    required this.incidentId,
    required this.workflowKind,
    required this.type,
    required this.senderNodeId,
    required this.seq,
    required this.timestamp,
    this.receivedAt,
    this.refSeq,
    this.isSuperseded = false,
    this.quickUpdate,
    this.ackCategory,
    this.location,
    this.message,
    this.expiresAt,
    this.hazardStatus,
    this.hazardUpdateType,
  });

  /// Composite dedupe key: "incidentId:senderNodeId:seq".
  String get dedupeKey => '$incidentId:$senderNodeId:$seq';

  /// Whether this event corrects a previous one.
  bool get isCorrection => refSeq != null;

  IncidentEvent copyWith({
    int? incidentId,
    IncidentWorkflowKind? workflowKind,
    IncidentEventType? type,
    int? senderNodeId,
    int? seq,
    DateTime? timestamp,
    DateTime? receivedAt,
    int? refSeq,
    bool? isSuperseded,
    IncidentQuickUpdate? quickUpdate,
    IncidentAckCategory? ackCategory,
    IncidentLocation? location,
    IncidentMessage? message,
    DateTime? expiresAt,
    IncidentMeshStatus? hazardStatus,
    IncidentUpdateType? hazardUpdateType,
  }) {
    return IncidentEvent(
      incidentId: incidentId ?? this.incidentId,
      workflowKind: workflowKind ?? this.workflowKind,
      type: type ?? this.type,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      seq: seq ?? this.seq,
      timestamp: timestamp ?? this.timestamp,
      receivedAt: receivedAt ?? this.receivedAt,
      refSeq: refSeq ?? this.refSeq,
      isSuperseded: isSuperseded ?? this.isSuperseded,
      quickUpdate: quickUpdate ?? this.quickUpdate,
      ackCategory: ackCategory ?? this.ackCategory,
      location: location ?? this.location,
      message: message ?? this.message,
      expiresAt: expiresAt ?? this.expiresAt,
      hazardStatus: hazardStatus ?? this.hazardStatus,
      hazardUpdateType: hazardUpdateType ?? this.hazardUpdateType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'workflowKind': workflowKind.name,
      'type': type.name,
      'senderNodeId': senderNodeId,
      'seq': seq,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'receivedAt': receivedAt?.millisecondsSinceEpoch,
      'refSeq': refSeq,
      'isSuperseded': isSuperseded ? 1 : 0,
      'quickUpdate': quickUpdate?.name,
      'ackCategory': ackCategory?.name,
      'location': location?.toMap(),
      'message': message?.toMap(),
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'hazardStatus': hazardStatus?.name,
      'hazardUpdateType': hazardUpdateType?.name,
    };
  }

  factory IncidentEvent.fromMap(Map<String, dynamic> map) {
    return IncidentEvent(
      incidentId: map['incidentId'] as int,
      workflowKind: IncidentWorkflowKind.values.byName(
        map['workflowKind'] as String,
      ),
      type: IncidentEventType.values.byName(map['type'] as String),
      senderNodeId: map['senderNodeId'] as int,
      seq: map['seq'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
        isUtc: true,
      ),
      receivedAt: map['receivedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['receivedAt'] as int,
              isUtc: true,
            )
          : null,
      refSeq: map['refSeq'] as int?,
      isSuperseded: (map['isSuperseded'] as int?) == 1,
      quickUpdate: map['quickUpdate'] != null
          ? IncidentQuickUpdate.values.byName(map['quickUpdate'] as String)
          : null,
      ackCategory: map['ackCategory'] != null
          ? IncidentAckCategory.values.byName(map['ackCategory'] as String)
          : null,
      location: map['location'] != null
          ? IncidentLocation.fromMap(
              (map['location'] as Map).cast<String, dynamic>(),
            )
          : null,
      message: map['message'] != null
          ? IncidentMessage.fromMap(
              (map['message'] as Map).cast<String, dynamic>(),
            )
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['expiresAt'] as int,
              isUtc: true,
            )
          : null,
      hazardStatus: map['hazardStatus'] != null
          ? IncidentMeshStatus.values.byName(map['hazardStatus'] as String)
          : null,
      hazardUpdateType: map['hazardUpdateType'] != null
          ? IncidentUpdateType.values.byName(map['hazardUpdateType'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'IncidentEvent(incident=$incidentId, kind=${workflowKind.name}, '
      'type=${type.name}, sender=$senderNodeId, seq=$seq)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncidentEvent &&
          incidentId == other.incidentId &&
          senderNodeId == other.senderNodeId &&
          seq == other.seq;

  @override
  int get hashCode => Object.hash(incidentId, senderNodeId, seq);
}

/// The projected local state of a single incident.
///
/// This is a derived view, not a persisted entity. It is rebuilt on demand
/// from the immutable [IncidentEvent] timeline by [IncidentReducer.project].
///
/// For help-request incidents, [helpState] holds the responder lifecycle and
/// [hazardStatus] is null. For hazard-report incidents, [hazardStatus] holds
/// the effective reporting status and [helpState] is null -- hazard incidents
/// never enter the personal-help lifecycle.
class IncidentProjection {
  final int incidentId;
  final IncidentWorkflowKind workflowKind;

  /// Node id that originated the incident.
  final int originNodeId;

  /// Help-request lifecycle state (null for hazard reports).
  final IncidentLifecycleState? helpState;

  /// Hazard reporting status (null for help requests).
  final IncidentMeshStatus? hazardStatus;

  /// Earliest event timestamp.
  final DateTime createdAt;

  /// Latest event timestamp.
  final DateTime updatedAt;

  /// Expiry horizon, if a create event carried one.
  final DateTime? expiresAt;

  /// Latest requester quick-status (help requests only).
  final IncidentQuickUpdate? lastRequesterStatus;

  /// Latest known location of the requester (help requests only).
  final IncidentLocation? lastRequesterLocation;

  /// Whether escalated location sharing is currently active.
  final bool locationSharing;

  /// All participants (requester + active responders), sorted by node id.
  final List<IncidentParticipant> participants;

  /// Ordered, deduplicated event timeline (superseded events retained but
  /// flagged via [IncidentEvent.isSuperseded]).
  final List<IncidentEvent> timeline;

  const IncidentProjection({
    required this.incidentId,
    required this.workflowKind,
    required this.originNodeId,
    this.helpState,
    this.hazardStatus,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.lastRequesterStatus,
    this.lastRequesterLocation,
    this.locationSharing = false,
    this.participants = const [],
    this.timeline = const [],
  });

  /// Active responders (help requests only).
  List<IncidentParticipant> get responders =>
      participants.where((p) => p.role == IncidentRole.responder).toList();

  /// Number of active responders.
  int get responderCount => responders.length;

  /// Whether the incident has reached a terminal state.
  ///
  /// Hazard reports are terminal when resolved or cancelled; help requests when
  /// the lifecycle state is terminal.
  bool get isTerminal {
    if (workflowKind == IncidentWorkflowKind.helpRequest) {
      return helpState?.isTerminal ?? false;
    }
    return hazardStatus == IncidentMeshStatus.resolved ||
        hazardStatus == IncidentMeshStatus.cancelled;
  }

  @override
  String toString() {
    final state = workflowKind == IncidentWorkflowKind.helpRequest
        ? helpState?.name
        : hazardStatus?.name;
    return 'IncidentProjection(incident=$incidentId, '
        'kind=${workflowKind.name}, state=$state, '
        'responders=$responderCount)';
  }
}
