// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Per-user membership row inside a [LicenseOrg].
// Firestore path: `license_orgs/{licenseOrgId}/members/{uid}`.
//
// See docs/engineering/GROUP_LICENSING_FOUNDATION.md.
//
// IMPORTANT - this collection is distinct from the enterprise
// multi-tenancy `orgs/{orgId}/members/{uid}` collection (see
// backend/functions/src/org/createOrg.ts and
// docs/specs/MULTI_TENANCY.md). The licensing membership layer must
// not share Firestore paths, roles, custom claims, or security rules
// with enterprise multi-tenancy: the two systems have fundamentally
// different access models (many-orgs-per-user via collection group
// queries here, vs. one-org-per-user via custom claims there).

import 'package:cloud_firestore/cloud_firestore.dart';

/// Role a user holds inside a license org. Roles do not currently
/// grant entitlements - they exist so a future admin surface can
/// authorise owner / admin actions without re-deriving the rule.
///
/// Intentionally distinct from the enterprise multi-tenancy role set
/// (`admin | supervisor | operator | observer`). The two namespaces
/// must not share role vocabulary because a single user may hold
/// different roles in an enterprise org and a license org.
enum LicenseOrgMemberRole {
  owner,
  admin,
  member,
  unknown;

  static LicenseOrgMemberRole fromWire(String? value) {
    switch (value) {
      case 'owner':
        return LicenseOrgMemberRole.owner;
      case 'admin':
        return LicenseOrgMemberRole.admin;
      case 'member':
        return LicenseOrgMemberRole.member;
      default:
        return LicenseOrgMemberRole.unknown;
    }
  }

  String toWire() => name;
}

/// Lifecycle of a single membership row.
///
/// Only [LicenseOrgMemberStatus.active] members count towards the
/// org-id set returned by `currentUserLicenseOrgIdsProvider`.
/// `invited` rows are placeholders for an invite flow that has not
/// been accepted; `revoked` rows are retained for audit so we can
/// show "you were removed by `admin` on `date`" without re-querying
/// the audit log.
enum LicenseOrgMemberStatus {
  active,
  revoked,
  invited,
  unknown;

  static LicenseOrgMemberStatus fromWire(String? value) {
    switch (value) {
      case 'active':
        return LicenseOrgMemberStatus.active;
      case 'revoked':
        return LicenseOrgMemberStatus.revoked;
      case 'invited':
        return LicenseOrgMemberStatus.invited;
      default:
        return LicenseOrgMemberStatus.unknown;
    }
  }

  String toWire() => name;
}

/// A single membership row binding a user [uid] to a license org
/// identified by [orgId].
class LicenseOrgMembership {
  /// Member uid. Mirror of the document id so a collection-group query
  /// can filter by `uid` without parsing the path.
  final String uid;

  /// Parent license org id. Mirror of the path segment for the same
  /// reason. Distinct from any enterprise multi-tenancy orgId the user
  /// may carry in their custom claims.
  final String orgId;

  /// Role the member holds. Defaults to [LicenseOrgMemberRole.member]
  /// for rows that pre-date the role field; never throws on missing
  /// data.
  final LicenseOrgMemberRole role;

  /// Server-stamped join time. Nullable when a partial write landed
  /// without the timestamp; the membership still counts.
  final DateTime? joinedAt;

  /// Uid of the admin who issued the invite, if any. Optional.
  final String? invitedBy;

  /// Live status. Anything other than [LicenseOrgMemberStatus.active]
  /// is filtered out before the org id reaches downstream providers.
  final LicenseOrgMemberStatus status;

  const LicenseOrgMembership({
    required this.uid,
    required this.orgId,
    required this.role,
    required this.joinedAt,
    required this.invitedBy,
    required this.status,
  });

  /// Parse a Firestore member document. Returns null when the row is
  /// missing required fields (uid, orgId) so the repository can fail
  /// closed without throwing into the provider stream.
  static LicenseOrgMembership? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => fromMap(doc.data());

  /// Pure map -> model parser. Mirrors the validation rules used by
  /// [fromFirestore] but testable without a Firestore mock.
  static LicenseOrgMembership? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final uid = data['uid'];
    final orgId = data['orgId'];
    if (uid is! String || uid.isEmpty) return null;
    if (orgId is! String || orgId.isEmpty) return null;
    final joined = data['joinedAt'];
    DateTime? joinedAt;
    if (joined is Timestamp) {
      joinedAt = joined.toDate().toUtc();
    } else if (joined is String) {
      joinedAt = DateTime.tryParse(joined)?.toUtc();
    }
    final invitedBy = data['invitedBy'];
    return LicenseOrgMembership(
      uid: uid,
      orgId: orgId,
      role: LicenseOrgMemberRole.fromWire(data['role'] as String?),
      joinedAt: joinedAt,
      invitedBy: invitedBy is String && invitedBy.isNotEmpty ? invitedBy : null,
      status: LicenseOrgMemberStatus.fromWire(data['status'] as String?),
    );
  }

  /// True if this row is currently effective. Used by the repository's
  /// query layer as a defence-in-depth check after the Firestore
  /// `status == active` filter (catches corrupt rows where the field
  /// arrived as the wrong type).
  bool get isAccessActive => status == LicenseOrgMemberStatus.active;

  LicenseOrgMembership copyWith({
    String? uid,
    String? orgId,
    LicenseOrgMemberRole? role,
    DateTime? joinedAt,
    String? invitedBy,
    LicenseOrgMemberStatus? status,
  }) {
    return LicenseOrgMembership(
      uid: uid ?? this.uid,
      orgId: orgId ?? this.orgId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseOrgMembership &&
          uid == other.uid &&
          orgId == other.orgId &&
          role == other.role &&
          joinedAt == other.joinedAt &&
          invitedBy == other.invitedBy &&
          status == other.status;

  @override
  int get hashCode =>
      Object.hash(uid, orgId, role, joinedAt, invitedBy, status);

  @override
  String toString() =>
      'LicenseOrgMembership(uid: $uid, orgId: $orgId, role: $role, '
      'status: $status)';
}
