// SPDX-License-Identifier: GPL-3.0-or-later

import 'incident.dart';

/// An immutable record of a state transition on an incident.
///
/// The `incident_transitions` table is append-only -- rows are never modified
/// or deleted. This is the source of truth for incident state. The
/// `incidents.state` column is a derived projection.
///
/// Spec: INCIDENT_LIFECYCLE.md (Sprint 007).
class IncidentTransition {
  /// UUID v4 generated at creation time.
  /// Must NOT depend on timestamp or device clock.
  final String id;

  final String incidentId;
  final IncidentState fromState;
  final IncidentState toState;

  /// Firebase UID of the actor who triggered the transition.
  final String actorId;

  /// Optional free-text note (maxLength: 500).
  final String? note;

  /// Epoch-millisecond timestamp of when the transition occurred.
  final DateTime timestamp;

  const IncidentTransition({
    required this.id,
    required this.incidentId,
    required this.fromState,
    required this.toState,
    required this.actorId,
    this.note,
    required this.timestamp,
  });

  /// Deserialise from a SQLite row map.
  factory IncidentTransition.fromMap(Map<String, dynamic> map) {
    return IncidentTransition(
      id: map['id'] as String,
      incidentId: map['incidentId'] as String,
      fromState: IncidentState.values.byName(map['fromState'] as String),
      toState: IncidentState.values.byName(map['toState'] as String),
      actorId: map['actorId'] as String,
      note: map['note'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  /// Serialise to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incidentId': incidentId,
      'fromState': fromState.name,
      'toState': toState.name,
      'actorId': actorId,
      'note': note,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'IncidentTransition(id=$id, ${fromState.name} -> ${toState.name})';
}
