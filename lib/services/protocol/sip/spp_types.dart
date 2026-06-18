// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SPP (SocialMesh Payload Protocol) v0.1 type registry.
///
/// SPP provides a typed, versioned payload schema layer above MRRP.
/// Each payload type has a numeric ID and versioned encode/decode semantics.
/// Unknown types are handled gracefully for forward compatibility.
///
/// Wire format: 2-byte header (type_id uint8, version uint8) followed by
/// type-specific body. Rides inside MRRP service payloads.
///
/// Spec: docs/protocol/SPP_V0_1.md
library;

/// SPP payload type identifiers.
///
/// Each type defines a versioned schema for encode/decode within MRRP
/// service payloads. Types 0x00-0x0F are reserved for protocol control.
/// Types 0x10-0x1F are the incident report family.
/// Types 0x20-0x2F are reserved for future extensions.
enum SppPayloadType {
  /// Incident report (initial, update, correction, close, cancel).
  incidentReport(0x10),

  /// Incident query (request current state of a case).
  incidentQuery(0x11),

  /// Incident state response (reply to query).
  incidentState(0x12),

  /// Unified Incident Mode envelope (hazard_report + help_request workflows).
  ///
  /// Carries an explicit `workflow_kind` and `msg_type` discriminator so the
  /// incident.v1 layer can express both the field-hazard workflow and the
  /// personal Help Mode workflow. Codec: `spp_incident_mode_codec.dart`.
  /// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md
  incidentMode(0x13);

  const SppPayloadType(this.code);

  /// Wire code for this payload type.
  final int code;

  /// Look up a payload type by its wire code. Returns null if unknown.
  static SppPayloadType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Incident report update types.
///
/// Encoded in the flags byte of the incident wire format.
enum IncidentUpdateType {
  /// Initial report for a new case.
  initial(0),

  /// Follow-up update to an existing case.
  update(1),

  /// Correction to a previous report in the same case.
  correction(2),

  /// Case closure.
  closure(3);

  const IncidentUpdateType(this.code);
  final int code;

  static IncidentUpdateType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Confidence level for an incident report.
enum IncidentConfidence {
  /// Not yet verified.
  unconfirmed(0),

  /// Likely but not certain.
  probable(1),

  /// Verified by direct observation or multiple sources.
  confirmed(2);

  const IncidentConfidence(this.code);
  final int code;

  static IncidentConfidence? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Reporter role in the incident reporting hierarchy.
enum IncidentReporterRole {
  /// General observer with no special authority.
  observer(0),

  /// Field operator with direct knowledge.
  operator(1),

  /// Supervisor with coordination responsibility.
  supervisor(2),

  /// Administrator with full authority.
  admin(3);

  const IncidentReporterRole(this.code);
  final int code;

  static IncidentReporterRole? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Incident status as reported over mesh.
///
/// Subset of the full IncidentState lifecycle, scoped to field reporting.
enum IncidentMeshStatus {
  /// Newly reported, not yet triaged.
  reported(0),

  /// Acknowledged and being worked.
  active(1),

  /// Situation contained or stabilised.
  contained(2),

  /// Incident resolved or closed.
  resolved(3),

  /// Report cancelled or invalidated.
  cancelled(4);

  const IncidentMeshStatus(this.code);
  final int code;

  static IncidentMeshStatus? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// SPP header size in bytes: type_id(1) + version(1) = 2.
const int sppHeaderSize = 2;

/// Current SPP version for incident payloads.
const int sppIncidentVersion = 1;

/// Current SPP version for the unified Incident Mode envelope.
const int sppIncidentModeVersion = 1;
