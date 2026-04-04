// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Domain model for mesh-transmitted incident reports.
///
/// A [MeshIncidentReport] is an immutable event in an incident's timeline.
/// The effective state of a case is derived by replaying all reports for
/// that case_id in sequence order. Corrections reference the seq_num
/// they supersede.
///
/// Spec: docs/protocol/INCIDENT_SPP_V0_1.md
library;

import '../../../services/protocol/sip/spp_types.dart';
import 'incident.dart';

/// An immutable mesh incident report event.
///
/// Each report is identified by (case_id, seq_num). The case_id is stable
/// across the lifetime of an incident. The seq_num increments per update.
///
/// For corrections, [refSeq] points to the seq_num being corrected.
/// The original report is NOT deleted -- it remains in the timeline
/// but is marked as superseded.
class MeshIncidentReport {
  /// Stable case identifier (uint32). Unique per originator node.
  final int caseId;

  /// Per-case sequence number (0-255).
  final int seqNum;

  /// Type of update (initial, update, correction, closure).
  final IncidentUpdateType updateType;

  /// Confidence level of this report.
  final IncidentConfidence confidence;

  /// Incident classification.
  final IncidentClassification classification;

  /// Severity / priority level.
  final IncidentPriority priority;

  /// Current mesh status.
  final IncidentMeshStatus status;

  /// Role of the reporter.
  final IncidentReporterRole reporterRole;

  /// When this report was created (UTC).
  final DateTime timestamp;

  /// Sequence number of the report being corrected (null if not a correction).
  final int? refSeq;

  /// Coarse latitude (centidegree precision, null if not provided).
  final double? latitude;

  /// Coarse longitude (centidegree precision, null if not provided).
  final double? longitude;

  /// Free-text body / summary.
  final String body;

  /// Meshtastic node ID of the sender (set on receive, 0 for local).
  final int senderNodeId;

  /// Whether this report has been superseded by a correction.
  final bool isSuperseded;

  /// Local persistence ID (set after DB insert, null before).
  final int? dbId;

  /// Local receive timestamp (set on ingest, null for outbound).
  final DateTime? receivedAt;

  const MeshIncidentReport({
    required this.caseId,
    required this.seqNum,
    required this.updateType,
    required this.confidence,
    required this.classification,
    required this.priority,
    required this.status,
    required this.reporterRole,
    required this.timestamp,
    this.refSeq,
    this.latitude,
    this.longitude,
    required this.body,
    this.senderNodeId = 0,
    this.isSuperseded = false,
    this.dbId,
    this.receivedAt,
  });

  /// Whether this report has a coarse location.
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether this report corrects a previous report.
  bool get isCorrection => updateType == IncidentUpdateType.correction;

  /// Whether this is the initial report for a case.
  bool get isInitial => updateType == IncidentUpdateType.initial;

  /// Composite key for deduplication: "caseId:seqNum:senderNodeId".
  String get dedupeKey => '$caseId:$seqNum:$senderNodeId';

  /// Creates a copy with the given fields replaced.
  MeshIncidentReport copyWith({
    int? caseId,
    int? seqNum,
    IncidentUpdateType? updateType,
    IncidentConfidence? confidence,
    IncidentClassification? classification,
    IncidentPriority? priority,
    IncidentMeshStatus? status,
    IncidentReporterRole? reporterRole,
    DateTime? timestamp,
    int? refSeq,
    double? latitude,
    double? longitude,
    String? body,
    int? senderNodeId,
    bool? isSuperseded,
    int? dbId,
    DateTime? receivedAt,
  }) {
    return MeshIncidentReport(
      caseId: caseId ?? this.caseId,
      seqNum: seqNum ?? this.seqNum,
      updateType: updateType ?? this.updateType,
      confidence: confidence ?? this.confidence,
      classification: classification ?? this.classification,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      reporterRole: reporterRole ?? this.reporterRole,
      timestamp: timestamp ?? this.timestamp,
      refSeq: refSeq ?? this.refSeq,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      body: body ?? this.body,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      isSuperseded: isSuperseded ?? this.isSuperseded,
      dbId: dbId ?? this.dbId,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  /// Serialise to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'seqNum': seqNum,
      'updateType': updateType.code,
      'confidence': confidence.code,
      'classification': classification.index,
      'priority': priority.index,
      'status': status.code,
      'reporterRole': reporterRole.code,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'refSeq': refSeq,
      'latitude': latitude,
      'longitude': longitude,
      'body': body,
      'senderNodeId': senderNodeId,
      'isSuperseded': isSuperseded ? 1 : 0,
      'receivedAt': receivedAt?.millisecondsSinceEpoch,
    };
  }

  /// Deserialise from a SQLite row map.
  factory MeshIncidentReport.fromMap(Map<String, dynamic> map) {
    return MeshIncidentReport(
      dbId: map['id'] as int?,
      caseId: map['caseId'] as int,
      seqNum: map['seqNum'] as int,
      updateType:
          IncidentUpdateType.fromCode(map['updateType'] as int) ??
          IncidentUpdateType.initial,
      confidence:
          IncidentConfidence.fromCode(map['confidence'] as int) ??
          IncidentConfidence.unconfirmed,
      classification:
          IncidentClassification.values[map['classification'] as int],
      priority: IncidentPriority.values[map['priority'] as int],
      status:
          IncidentMeshStatus.fromCode(map['status'] as int) ??
          IncidentMeshStatus.reported,
      reporterRole:
          IncidentReporterRole.fromCode(map['reporterRole'] as int) ??
          IncidentReporterRole.observer,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
        isUtc: true,
      ),
      refSeq: map['refSeq'] as int?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      body: map['body'] as String,
      senderNodeId: map['senderNodeId'] as int,
      isSuperseded: (map['isSuperseded'] as int?) == 1,
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
      'MeshIncidentReport(case=$caseId, seq=$seqNum, '
      'type=${updateType.name}, status=${status.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshIncidentReport &&
          caseId == other.caseId &&
          seqNum == other.seqNum &&
          senderNodeId == other.senderNodeId;

  @override
  int get hashCode => Object.hash(caseId, seqNum, senderNodeId);
}

/// Effective state of a mesh incident case, derived from replaying reports.
///
/// This is a projection, not a persisted entity. It is rebuilt on demand
/// from the immutable report timeline.
class MeshIncidentCaseState {
  /// Stable case identifier.
  final int caseId;

  /// Total number of reports in this case.
  final int reportCount;

  /// Latest non-superseded report.
  final MeshIncidentReport latestReport;

  /// Initial report (seq 0).
  final MeshIncidentReport initialReport;

  /// The effective status after applying all non-superseded reports.
  final IncidentMeshStatus effectiveStatus;

  /// The effective priority.
  final IncidentPriority effectivePriority;

  /// The effective classification.
  final IncidentClassification effectiveClassification;

  /// The effective confidence level.
  final IncidentConfidence effectiveConfidence;

  /// All unique sender node IDs that contributed reports.
  final Set<int> contributorNodes;

  /// Whether this case has any corrections.
  final bool hasCorrections;

  const MeshIncidentCaseState({
    required this.caseId,
    required this.reportCount,
    required this.latestReport,
    required this.initialReport,
    required this.effectiveStatus,
    required this.effectivePriority,
    required this.effectiveClassification,
    required this.effectiveConfidence,
    required this.contributorNodes,
    required this.hasCorrections,
  });

  /// Derives the effective case state from a list of reports.
  ///
  /// Reports must be for the same case_id. They are processed in
  /// seq_num order. Superseded reports are excluded from the projection.
  factory MeshIncidentCaseState.fromReports(List<MeshIncidentReport> reports) {
    assert(reports.isNotEmpty, 'Cannot derive state from empty reports');
    final sorted = List<MeshIncidentReport>.from(reports)
      ..sort((a, b) => a.seqNum.compareTo(b.seqNum));

    final initial = sorted.first;
    final active = sorted.where((r) => !r.isSuperseded).toList();
    final latest = active.isNotEmpty ? active.last : sorted.last;

    return MeshIncidentCaseState(
      caseId: initial.caseId,
      reportCount: reports.length,
      latestReport: latest,
      initialReport: initial,
      effectiveStatus: latest.status,
      effectivePriority: latest.priority,
      effectiveClassification: latest.classification,
      effectiveConfidence: latest.confidence,
      contributorNodes: reports.map((r) => r.senderNodeId).toSet(),
      hasCorrections: reports.any((r) => r.isCorrection),
    );
  }
}
