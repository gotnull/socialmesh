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

  const LicenseOrg({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
    required this.status,
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
    return LicenseOrg(
      id: id,
      name: (data['name'] as String?) ?? '',
      ownerUid: ownerUid,
      createdAt: createdAt,
      status: LicenseOrgStatus.fromWire(data['status'] as String?),
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
  }) {
    return LicenseOrg(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
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
          status == other.status;

  @override
  int get hashCode => Object.hash(id, name, ownerUid, createdAt, status);

  @override
  String toString() =>
      'LicenseOrg(id: $id, ownerUid: $ownerUid, status: $status)';
}
