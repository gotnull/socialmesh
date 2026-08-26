// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Fleet device record for the group / community licensing namespace.
// Firestore path: `license_org_fleet_devices/{fleetDeviceId}`.
//
// This document holds CONFIGURED metadata only: what a radio is, and
// who or what the organisation says it belongs to. Observed runtime
// state - last seen, battery, position, SNR, hop count, connection
// state - is deliberately absent and stays local. Persisting
// observations here would make Firestore writes proportional to mesh
// packet rate.
//
// Writes are server-only via Admin SDK callables; `firestore.rules`
// denies every client write. Reads are scoped to active members of an
// active org.
//
// IMPORTANT - this belongs to the `license_orgs/` namespace, NOT the
// enterprise multi-tenancy `orgs/` namespace owned by
// backend/functions/src/org/createOrg.ts. The two must not share
// Firestore paths, roles, or custom claims.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Separator between the org slug and the transport identity in a
/// fleet device id.
///
/// Safe because org slugs are validated against
/// `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$` server-side and therefore contain
/// no underscores and never start with one. That also makes the
/// Firestore-reserved `__.*__` document-id pattern unreachable: the id
/// always begins with a slug character.
const String kFleetIdSeparator = '__';

/// Minimum / maximum org slug length, mirroring
/// `LICENSE_ORG_ID_MIN_LENGTH` / `LICENSE_ORG_ID_MAX_LENGTH` in
/// `backend/functions/src/external_checkout.ts`. The server is
/// authoritative; these exist so the client can reject a malformed id
/// before a round trip.
const int kLicenseOrgIdMinLength = 3;
const int kLicenseOrgIdMaxLength = 64;

/// Org slug shape, mirroring `LICENSE_ORG_ID_PATTERN` server-side.
final RegExp kLicenseOrgIdPattern = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$');

/// Canonical transport identity shapes.
final RegExp kFleetMeshtasticIdentityPattern = RegExp(r'^mt-[0-9a-f]{8}$');
final RegExp kFleetMeshCoreIdentityPattern = RegExp(r'^mc-[0-9a-f]{64}$');

const String _meshtasticIdentityPrefix = 'mt-';
const String _meshCoreIdentityPrefix = 'mc-';

/// Bytes in a MeshCore public key. The FULL key is used as identity -
/// truncating a 256-bit identifier would manufacture collision risk
/// for no benefit.
const int kFleetMeshCorePublicKeyBytes = 32;

/// Hex characters retained in the short device reference written to
/// the audit trail. See [fleetAuditDeviceRef].
const int _auditRefMeshCoreHexChars = 16;

/// Which mesh transport a fleet device is reached over.
///
/// Deliberately transport-agnostic at the domain level so the fleet is
/// not structurally tied to Meshtastic. Adding a transport requires a
/// canonical identity encoding and a matching wire value.
enum FleetTransport {
  meshtastic('meshtastic'),
  meshCore('meshcore'),
  unknown('');

  final String wire;

  const FleetTransport(this.wire);

  static FleetTransport fromWire(String? value) {
    if (value == null || value.isEmpty) return FleetTransport.unknown;
    for (final transport in FleetTransport.values) {
      if (transport.wire == value) return transport;
    }
    return FleetTransport.unknown;
  }

  String toWire() => wire;
}

/// How the organisation has allocated custody of a radio.
///
/// [member] means a named person holds it. [orgPool] means the
/// organisation holds it as a loaner. [unassigned] means custody is
/// not recorded. The distinction between the latter two is real:
/// a loaner pool is a deliberate state, an unassigned radio is a gap.
enum FleetAssignmentKind {
  member('member'),
  orgPool('org_pool'),
  unassigned('unassigned'),
  unknown('');

  final String wire;

  const FleetAssignmentKind(this.wire);

  static FleetAssignmentKind fromWire(String? value) {
    if (value == null || value.isEmpty) return FleetAssignmentKind.unknown;
    for (final kind in FleetAssignmentKind.values) {
      if (kind.wire == value) return kind;
    }
    return FleetAssignmentKind.unknown;
  }

  String toWire() => wire;
}

/// Lifecycle of a fleet record. Retirement is soft so the record stays
/// auditable; the row is never deleted.
enum FleetDeviceStatus {
  active('active'),
  retired('retired'),
  unknown('');

  final String wire;

  const FleetDeviceStatus(this.wire);

  static FleetDeviceStatus fromWire(String? value) {
    if (value == null || value.isEmpty) return FleetDeviceStatus.unknown;
    for (final status in FleetDeviceStatus.values) {
      if (status.wire == value) return status;
    }
    return FleetDeviceStatus.unknown;
  }

  String toWire() => wire;
}

/// Canonical transport identity for a Meshtastic radio.
///
/// The node number is treated as UNSIGNED. Dart `int` is 64-bit signed,
/// so the mask is explicit; the TypeScript side uses `>>> 0`. This
/// matches `radioScopeKeyForNodeNum` in `lib/core/radio_scope.dart`,
/// which already encodes node numbers exactly this way.
///
/// `nodeNum` derives from the hardware MAC and survives a firmware
/// reflash, which is why it - and not the rotating public key - is the
/// Meshtastic identity.
String fleetMeshtasticIdentity(int nodeNum) {
  final masked = nodeNum & 0xFFFFFFFF;
  return '$_meshtasticIdentityPrefix'
      '${masked.toRadixString(16).padLeft(8, '0')}';
}

/// Canonical transport identity for a MeshCore radio.
///
/// Uses the FULL 32-byte public key. Returns null when the key is the
/// wrong length or carries a non-byte value, so callers fail closed
/// rather than minting an identity from partial material.
///
/// Known limitation: a MeshCore factory reset re-derives the key, so
/// the same physical radio reappears as a different fleet device.
/// MeshCore exposes no stable alternative. See
/// docs/teams/RELIABILITY-GAPS.md H1.
String? fleetMeshCoreIdentity(List<int> publicKey) {
  if (publicKey.length != kFleetMeshCorePublicKeyBytes) return null;
  final buffer = StringBuffer(_meshCoreIdentityPrefix);
  for (final byte in publicKey) {
    if (byte < 0 || byte > 0xFF) return null;
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// True when [transportIdentity] matches a known canonical shape.
bool isValidFleetTransportIdentity(String transportIdentity) =>
    kFleetMeshtasticIdentityPattern.hasMatch(transportIdentity) ||
    kFleetMeshCoreIdentityPattern.hasMatch(transportIdentity);

/// True when [licenseOrgId] matches the server's slug contract.
bool isValidLicenseOrgId(String licenseOrgId) =>
    licenseOrgId.length >= kLicenseOrgIdMinLength &&
    licenseOrgId.length <= kLicenseOrgIdMaxLength &&
    kLicenseOrgIdPattern.hasMatch(licenseOrgId);

/// Compose the canonical, organisation-scoped fleet document id.
///
/// The org is part of the id because `license_orgs` allows a user to
/// belong to many organisations and no invariant makes a physical radio
/// globally exclusive to one. Without the org prefix, two organisations
/// referencing the same radio would collide in a top-level collection.
///
/// Returns null when either part is invalid so callers fail closed.
/// The server derives this itself and never trusts a client-supplied
/// document id.
String? fleetDeviceIdFor({
  required String licenseOrgId,
  required String transportIdentity,
}) {
  if (!isValidLicenseOrgId(licenseOrgId)) return null;
  if (!isValidFleetTransportIdentity(transportIdentity)) return null;
  return '$licenseOrgId$kFleetIdSeparator$transportIdentity';
}

/// Short device reference for the audit trail.
///
/// `appendLicenseOrgAuditEvent` caps `targetId` at 64 characters, and a
/// MeshCore fleet device id runs to 133. This yields a compact
/// reference instead:
///
///   `mt-aabbccdd`            (11 chars, unchanged)
///   `mc-<first 16 hex>`      (19 chars, shortened)
///
/// This is a human-triage reference scoped by the audit row's own
/// `licenseOrgId`. It is explicitly NOT an identity - the authoritative
/// identity keeps the full untruncated key in the document id. Never
/// use this value for lookup or uniqueness.
///
/// Returns null for an unrecognised identity shape.
String? fleetAuditDeviceRef(String transportIdentity) {
  if (kFleetMeshtasticIdentityPattern.hasMatch(transportIdentity)) {
    return transportIdentity;
  }
  if (kFleetMeshCoreIdentityPattern.hasMatch(transportIdentity)) {
    final hex = transportIdentity.substring(_meshCoreIdentityPrefix.length);
    return '$_meshCoreIdentityPrefix'
        '${hex.substring(0, _auditRefMeshCoreHexChars)}';
  }
  return null;
}

/// One row in `license_org_fleet_devices/{fleetDeviceId}`.
class LicenseOrgFleetDevice {
  /// Firestore document id: `<licenseOrgId>__<transportIdentity>`.
  final String id;

  /// Parent license org. Mirrored out of the path so the collection can
  /// be queried and so security rules can read it from `resource.data`.
  final String licenseOrgId;

  /// Transport this radio is reached over.
  final FleetTransport transport;

  /// Canonical transport identity, e.g. `mt-aabbccdd`.
  final String transportIdentity;

  /// Friendly name chosen by an admin. May be empty.
  final String label;

  /// Member holding the radio. Null unless [assignment] is
  /// [FleetAssignmentKind.member].
  final String? assignedUid;

  /// How custody is allocated.
  final FleetAssignmentKind assignment;

  /// Free-form operational purpose, e.g. "Gate Operations".
  final String? purpose;

  /// Admin-applied tags. Bounded server-side.
  final List<String> tags;

  /// Free-form notes: antenna, mount, last service date. The tribal
  /// knowledge clubs otherwise lose.
  final String? notes;

  /// Hardware model observed at enrolment. Display fallback for a radio
  /// currently out of range - NOT a compliance baseline, and never
  /// refreshed per observation.
  final String? lastKnownHardware;

  /// Firmware version observed at enrolment. Same caveat as
  /// [lastKnownHardware].
  final String? lastKnownFirmware;

  /// Uid of the admin who enrolled the radio. Server-derived.
  final String createdBy;

  /// Server-stamped creation time. Non-null - see [fromMap].
  final DateTime createdAt;

  /// Server-stamped last-modification time. Non-null - see [fromMap].
  final DateTime updatedAt;

  /// Lifecycle state.
  final FleetDeviceStatus status;

  const LicenseOrgFleetDevice({
    required this.id,
    required this.licenseOrgId,
    required this.transport,
    required this.transportIdentity,
    required this.label,
    required this.assignedUid,
    required this.assignment,
    required this.purpose,
    required this.tags,
    required this.notes,
    required this.lastKnownHardware,
    required this.lastKnownFirmware,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  /// Parse a Firestore document. Returns null on malformed data so
  /// callers fail closed instead of throwing into a Riverpod stream.
  static LicenseOrgFleetDevice? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => fromMap(doc.id, doc.data());

  /// Pure map -> model parser. Mirrors [fromFirestore] but testable
  /// without a Firestore mock.
  ///
  /// Unlike the neighbouring licensing models, `createdAt` and
  /// `updatedAt` are REQUIRED. Those models tolerate nulls to survive
  /// partial legacy writes; this collection is new and only ever
  /// written by server code, so a missing timestamp means the document
  /// is malformed. Rejecting it here spares every downstream caller a
  /// nullable it would have to defend against.
  static LicenseOrgFleetDevice? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;

    final licenseOrgId = data['licenseOrgId'];
    if (licenseOrgId is! String || !isValidLicenseOrgId(licenseOrgId)) {
      return null;
    }

    final transportIdentity = data['transportIdentity'];
    if (transportIdentity is! String ||
        !isValidFleetTransportIdentity(transportIdentity)) {
      return null;
    }

    // The document id is derived, so a row whose id disagrees with its
    // own fields is corrupt and must not be trusted.
    final expectedId = fleetDeviceIdFor(
      licenseOrgId: licenseOrgId,
      transportIdentity: transportIdentity,
    );
    if (expectedId == null || expectedId != id) return null;

    final transport = FleetTransport.fromWire(data['transport'] as String?);
    if (transport == FleetTransport.unknown) return null;

    final createdBy = data['createdBy'];
    if (createdBy is! String || createdBy.isEmpty) return null;

    final createdAt = _parseTimestamp(data['createdAt']);
    if (createdAt == null) return null;
    final updatedAt = _parseTimestamp(data['updatedAt']);
    if (updatedAt == null) return null;

    final assignment = FleetAssignmentKind.fromWire(
      data['assignment'] as String?,
    );
    final assignedUidRaw = data['assignedUid'];
    final assignedUid = assignedUidRaw is String && assignedUidRaw.isNotEmpty
        ? assignedUidRaw
        : null;

    final tagsRaw = data['tags'];
    final tags = <String>[];
    if (tagsRaw is List) {
      for (final tag in tagsRaw) {
        if (tag is String && tag.isNotEmpty) tags.add(tag);
      }
    }

    return LicenseOrgFleetDevice(
      id: id,
      licenseOrgId: licenseOrgId,
      transport: transport,
      transportIdentity: transportIdentity,
      label: (data['label'] as String?) ?? '',
      assignedUid: assignedUid,
      assignment: assignment,
      purpose: _nonEmptyString(data['purpose']),
      tags: List<String>.unmodifiable(tags),
      notes: _nonEmptyString(data['notes']),
      lastKnownHardware: _nonEmptyString(data['lastKnownHardware']),
      lastKnownFirmware: _nonEmptyString(data['lastKnownFirmware']),
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: FleetDeviceStatus.fromWire(data['status'] as String?),
    );
  }

  static String? _nonEmptyString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static DateTime? _parseTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  /// Short reference used as the audit row's `targetId`.
  String? get auditDeviceRef => fleetAuditDeviceRef(transportIdentity);

  /// True when [assignment] and [assignedUid] agree.
  ///
  /// The two fields are partially redundant by design: `orgPool` and
  /// `unassigned` are both null-uid but semantically distinct, so one
  /// extra bit is unavoidable. The redundancy is therefore enforced
  /// rather than accidental. The server rejects violations with
  /// `invalid-argument`; this predicate lets the client and tests
  /// assert the same rule.
  bool get isConsistent {
    switch (assignment) {
      case FleetAssignmentKind.member:
        return assignedUid != null && assignedUid!.isNotEmpty;
      case FleetAssignmentKind.orgPool:
      case FleetAssignmentKind.unassigned:
        return assignedUid == null;
      case FleetAssignmentKind.unknown:
        return false;
    }
  }

  LicenseOrgFleetDevice copyWith({
    String? id,
    String? licenseOrgId,
    FleetTransport? transport,
    String? transportIdentity,
    String? label,
    String? assignedUid,
    FleetAssignmentKind? assignment,
    String? purpose,
    List<String>? tags,
    String? notes,
    String? lastKnownHardware,
    String? lastKnownFirmware,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    FleetDeviceStatus? status,
  }) {
    return LicenseOrgFleetDevice(
      id: id ?? this.id,
      licenseOrgId: licenseOrgId ?? this.licenseOrgId,
      transport: transport ?? this.transport,
      transportIdentity: transportIdentity ?? this.transportIdentity,
      label: label ?? this.label,
      assignedUid: assignedUid ?? this.assignedUid,
      assignment: assignment ?? this.assignment,
      purpose: purpose ?? this.purpose,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      lastKnownHardware: lastKnownHardware ?? this.lastKnownHardware,
      lastKnownFirmware: lastKnownFirmware ?? this.lastKnownFirmware,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseOrgFleetDevice &&
          id == other.id &&
          licenseOrgId == other.licenseOrgId &&
          transport == other.transport &&
          transportIdentity == other.transportIdentity &&
          label == other.label &&
          assignedUid == other.assignedUid &&
          assignment == other.assignment &&
          purpose == other.purpose &&
          _listEquals(tags, other.tags) &&
          notes == other.notes &&
          lastKnownHardware == other.lastKnownHardware &&
          lastKnownFirmware == other.lastKnownFirmware &&
          createdBy == other.createdBy &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          status == other.status;

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    licenseOrgId,
    transport,
    transportIdentity,
    label,
    assignedUid,
    assignment,
    purpose,
    Object.hashAll(tags),
    notes,
    lastKnownHardware,
    lastKnownFirmware,
    createdBy,
    createdAt,
    updatedAt,
    status,
  );

  @override
  String toString() =>
      'LicenseOrgFleetDevice(id: $id, transport: ${transport.wire}, '
      'assignment: ${assignment.wire}, status: ${status.wire})';
}
