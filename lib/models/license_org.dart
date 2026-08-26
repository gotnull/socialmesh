// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Group / community licensing models. See
// docs/engineering/GROUP_LICENSING_FOUNDATION.md for the long-form
// design and the rationale for failing closed at every layer until a
// seat-allocation model lands.
//
// This file defines the [LicenseOrg] document shape (collection:
// `license_orgs/{orgId}`). Member rows live alongside in
// [LicenseOrgMembership] (`license_orgs/{orgId}/members/{uid}`),
// defined in `license_org_membership.dart`.
//
// IMPORTANT - distinct namespace from the enterprise multi-tenancy
// `orgs/` collection (see backend/functions/src/org/createOrg.ts and
// docs/specs/MULTI_TENANCY.md). The two systems must NOT share
// Firestore paths: multi-tenancy is one-org-per-user with custom
// claims gating cross-org reads; licensing is many-orgs-per-user via
// collection group queries. Mixing them creates security-rule
// exceptions and role-field collisions.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a license org as recorded server-side.
///
/// Only `active` orgs admit members. `suspended` is the abuse / billing
/// hold state - members remain in the collection so a future re-enable
/// path can restore them, but they should not grant access while the
/// status is suspended.
enum LicenseOrgStatus {
  active,
  suspended,
  unknown;

  static LicenseOrgStatus fromWire(String? value) {
    switch (value) {
      case 'active':
        return LicenseOrgStatus.active;
      case 'suspended':
        return LicenseOrgStatus.suspended;
      default:
        return LicenseOrgStatus.unknown;
    }
  }

  String toWire() => name;
}

/// Whether an org is authorised to use the Teams fleet, and on what
/// basis.
///
/// **This is a DISPLAY value on the client. It is never a security
/// boundary.** Authorisation lives in `firestore.rules`
/// (`hasLicenseOrgFleetAccess`) and in every fleet callable. A screen
/// may branch on this to render "Pilot access" / "Fleet access not
/// enabled"; it must never treat that branch as the thing preventing an
/// unauthorised operation, because the client copy is trivially
/// forgeable and the server never consults it.
///
/// The value is a grant REASON, not a billing state, so a future
/// commercial entitlement grants [commercial] without any enforcement
/// point changing.
///
/// Wire mapping deliberately differs from the other enums in this file:
/// an ABSENT field means [none], not [unknown]. An org that predates
/// the capability genuinely has no access, and saying "unknown" about
/// it would be less accurate than saying "not granted". [unknown] is
/// reserved for a value this build does not recognise - a newer server
/// grant kind - which is a real third display state: we should not
/// claim access is granted, nor confidently claim it is denied.
enum LicenseOrgFleetAccess {
  none,
  pilot,
  commercial,
  unknown;

  static LicenseOrgFleetAccess fromWire(String? value) {
    if (value == null || value.isEmpty) return LicenseOrgFleetAccess.none;
    switch (value) {
      case 'none':
        return LicenseOrgFleetAccess.none;
      case 'pilot':
        return LicenseOrgFleetAccess.pilot;
      case 'commercial':
        return LicenseOrgFleetAccess.commercial;
      default:
        return LicenseOrgFleetAccess.unknown;
    }
  }

  String toWire() => name;

  /// True when this build recognises the value as a grant.
  ///
  /// Presentation only. Never gate an operation on it - the server is
  /// the authority and will refuse regardless of what this returns.
  bool get isGrantedForDisplay =>
      this == LicenseOrgFleetAccess.pilot ||
      this == LicenseOrgFleetAccess.commercial;
}

/// A group / community license owner.
///
/// One [LicenseOrg] document per organisation, keyed by a slug-style
/// id (e.g. `acme-eng-team`). The doc is read-only from the client in
/// this groundwork slice. Owner / admin write paths land in a later
/// slice alongside the admin surface.
class LicenseOrg {
  /// Firestore document id. Slug-style, lowercase, hyphen-separated.
  final String id;

  /// Human-readable name. Free-form, may be empty for partially-set-up
  /// orgs - parsers must accept the empty string rather than fail.
  final String name;

  /// Uid of the user who created / owns the org. Multiple admins may
  /// exist in the members collection; this field tracks the single
  /// billing / refund counter-party.
  final String ownerUid;

  /// Server-stamped creation time. Nullable to tolerate partial writes.
  final DateTime? createdAt;

  /// Live status. Anything other than [LicenseOrgStatus.active] must NOT
  /// admit org-owned entitlements for any user.
  final LicenseOrgStatus status;

  /// Total seat capacity for this org, derived from the purchased
  /// Community Pack at upsert time (`community_pack_10` -> 10,
  /// `community_pack_20` -> 20). Null for legacy orgs (purchased
  /// before this field shipped) and for any future org-eligible
  /// product that doesn't declare a capacity.
  final int? seatCapacity;

  /// Whether this org may use the Teams fleet, and on what basis.
  ///
  /// DISPLAY ONLY - see [LicenseOrgFleetAccess]. Defaults to
  /// [LicenseOrgFleetAccess.none] when the server has not granted it.
  final LicenseOrgFleetAccess fleetAccess;

  const LicenseOrg({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
    required this.status,
    this.seatCapacity,
    this.fleetAccess = LicenseOrgFleetAccess.none,
  });

  /// Parse a Firestore document. Returns null when required fields
  /// are missing or malformed so callers can fail closed instead of
  /// throwing into a Riverpod stream.
  static LicenseOrg? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => fromMap(doc.id, doc.data());

  /// Pure map -> model parser. Mirrors the validation rules used by
  /// [fromFirestore] but testable without a Firestore mock. Returns
  /// null for missing data or any required field that fails the
  /// `is String && isNotEmpty` check.
  static LicenseOrg? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final ownerUid = data['ownerUid'];
    if (ownerUid is! String || ownerUid.isEmpty) return null;
    final created = data['createdAt'];
    DateTime? createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate().toUtc();
    } else if (created is String) {
      createdAt = DateTime.tryParse(created)?.toUtc();
    }
    final fleetAccessRaw = data['fleetAccess'];
    final seatCapacityRaw = data['seatCapacity'];
    final int? seatCapacity = switch (seatCapacityRaw) {
      final int v when v > 0 => v,
      final num v when v > 0 => v.toInt(),
      _ => null,
    };
    return LicenseOrg(
      id: id,
      name: (data['name'] as String?) ?? '',
      ownerUid: ownerUid,
      createdAt: createdAt,
      status: LicenseOrgStatus.fromWire(data['status'] as String?),
      seatCapacity: seatCapacity,
      // Type-checked rather than cast: a malformed value must degrade
      // to "not granted" like every other parser in this file, never
      // throw into a Riverpod stream.
      fleetAccess: LicenseOrgFleetAccess.fromWire(
        fleetAccessRaw is String ? fleetAccessRaw : null,
      ),
    );
  }

  /// True if this org should be honoured for access decisions. Used
  /// by the membership provider so admins do not accidentally surface
  /// suspended orgs to their members.
  bool get isAccessActive => status == LicenseOrgStatus.active;

  LicenseOrg copyWith({
    String? id,
    String? name,
    String? ownerUid,
    DateTime? createdAt,
    LicenseOrgStatus? status,
    int? seatCapacity,
    LicenseOrgFleetAccess? fleetAccess,
  }) {
    return LicenseOrg(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      fleetAccess: fleetAccess ?? this.fleetAccess,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseOrg &&
          id == other.id &&
          name == other.name &&
          ownerUid == other.ownerUid &&
          createdAt == other.createdAt &&
          status == other.status &&
          seatCapacity == other.seatCapacity &&
          fleetAccess == other.fleetAccess;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ownerUid,
    createdAt,
    status,
    seatCapacity,
    fleetAccess,
  );

  @override
  String toString() =>
      'LicenseOrg(id: $id, ownerUid: $ownerUid, status: $status, '
      'seatCapacity: $seatCapacity, fleetAccess: ${fleetAccess.name})';
}
