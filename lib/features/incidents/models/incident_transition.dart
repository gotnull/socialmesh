// SPDX-License-Identifier: GPL-3.0-or-later

import 'incident.dart';

/// An immutable record of a state transition on an incident.
///
/// The `incident_transitions` table is append-only — rows are never deleted.
/// Transitions that lose conflict resolution have [supersededBy] set to the
/// winning transition's ID but are otherwise preserved.
///
/// This table is the source of truth for incident state. The
/// `incidents.state` column is a derived projection rebuilt by replaying
/// non-superseded transitions.
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

  /// The actor's role name at the time of the transition (e.g. 'admin',
  /// 'supervisor', 'operator', 'observer'). Stored for deterministic conflict
  /// resolution without requiring a network lookup.
  ///
  /// Nullable for backward compatibility with transitions created before
  /// schema v2.
  final String? actorRole;

  /// Optional free-text note (maxLength: 500).
  final String? note;

  /// Epoch-millisecond timestamp of when the transition occurred.
  final DateTime timestamp;

  /// The ID of the winning transition that superseded this one during
  /// conflict resolution. Null when this transition is active (not
  /// superseded).
  final String? supersededBy;

  const IncidentTransition({
    required this.id,
    required this.incidentId,
    required this.fromState,
    required this.toState,
    required this.actorId,
    this.actorRole,
    this.note,
    required this.timestamp,
    this.supersededBy,
  });

  /// Deserialise from a SQLite row map.
  factory IncidentTransition.fromMap(Map<String, dynamic> map) {
    return IncidentTransition(
      id: map['id'] as String,
      incidentId: map['incidentId'] as String,
      fromState: IncidentState.values.byName(map['fromState'] as String),
      toState: IncidentState.values.byName(map['toState'] as String),
      actorId: map['actorId'] as String,
      actorRole: map['actorRole'] as String?,
      note: map['note'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      supersededBy: map['supersededBy'] as String?,
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
      'actorRole': actorRole,
      'note': note,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'supersededBy': supersededBy,
    };
  }

  @override
  String toString() =>
      'IncidentTransition(id=$id, ${fromState.name} -> ${toState.name})';
}
