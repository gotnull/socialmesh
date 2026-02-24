// SPDX-License-Identifier: GPL-3.0-or-later

/// A link between an incident and a field report (signal).
///
/// Stored in the `incident_field_reports` table.
///
/// Spec: INCIDENT_LIFECYCLE.md (Sprint 007).
class IncidentFieldReport {
  /// UUID v4.
  final String id;

  final String incidentId;

  /// Foreign key to the signals table in signals.db.
  final String signalId;

  /// Epoch-millisecond timestamp of when the link was created.
  final DateTime linkedAt;

  /// Firebase UID of the user who linked the report.
  final String linkedBy;

  const IncidentFieldReport({
    required this.id,
    required this.incidentId,
    required this.signalId,
    required this.linkedAt,
    required this.linkedBy,
  });

  /// Deserialise from a SQLite row map.
  factory IncidentFieldReport.fromMap(Map<String, dynamic> map) {
    return IncidentFieldReport(
      id: map['id'] as String,
      incidentId: map['incidentId'] as String,
      signalId: map['signalId'] as String,
      linkedAt: DateTime.fromMillisecondsSinceEpoch(map['linkedAt'] as int),
      linkedBy: map['linkedBy'] as String,
    );
  }

  /// Serialise to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incidentId': incidentId,
      'signalId': signalId,
      'linkedAt': linkedAt.millisecondsSinceEpoch,
      'linkedBy': linkedBy,
    };
  }

  @override
  String toString() =>
      'IncidentFieldReport(id=$id, incident=$incidentId, signal=$signalId)';
}
