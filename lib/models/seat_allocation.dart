// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Per-user seat allocation row binding a [uid] to a specific
// `(orgId, productId)` pair inside an org-owned external entitlement.
//
// Firestore path: `org_seat_allocations/{allocationId}`. The
// allocation row is the join key between [LicenseOrg] /
// [LicenseOrgMembership] (slice 2) and an org-owned
// [ExternalEntitlement]. Without a
// matching allocation, an org row remains filtered out at
// `ExternalEntitlementCache.activeProductIds()` even when the user
// is a member of the owning org.
//
// See `docs/engineering/GROUP_LICENSING_FOUNDATION.md` for the full
// rationale. The `(orgId, productId)` pair is exposed as
// [SeatAllocationRef] so set-membership checks at the cache filter
// stay cheap and explicit (no string parsing).

import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of a single seat allocation row.
///
/// Only [SeatAllocationStatus.active] rows admit the matching
/// org-owned entitlement. `revoked` rows persist for audit so a
/// future admin surface can show "seat reclaimed by `admin` on
/// `date`" without re-querying the audit log.
enum SeatAllocationStatus {
  active,
  revoked,
  unknown;

  static SeatAllocationStatus fromWire(String? value) {
    switch (value) {
      case 'active':
        return SeatAllocationStatus.active;
      case 'revoked':
        return SeatAllocationStatus.revoked;
      default:
        return SeatAllocationStatus.unknown;
    }
  }

  String toWire() => name;
}

/// Lightweight tuple identifying an active seat. Emitted by
/// [SeatAllocationRepository.watchCurrentUserSeats] and consumed by
/// the cache filter at
/// `ExternalEntitlementCache.activeProductIds(ownedSeats: ...)`.
///
/// Equality and hashCode are field-based via the underlying record
/// type so `Set<SeatAllocationRef>` works as expected.
class SeatAllocationRef {
  final String orgId;
  final String productId;

  const SeatAllocationRef({required this.orgId, required this.productId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeatAllocationRef &&
          orgId == other.orgId &&
          productId == other.productId;

  @override
  int get hashCode => Object.hash(orgId, productId);

  @override
  String toString() => 'SeatAllocationRef($orgId/$productId)';
}

/// A single seat allocation row.
class SeatAllocation {
  /// Owning org id. Must match a row in `orgs/{orgId}` for the seat
  /// to be honoured at the cache filter (defence-in-depth: the user
  /// must also be a member of this org).
  final String orgId;

  /// Seat holder uid.
  final String uid;

  /// Product id the seat grants when the owning org's entitlement is
  /// active.
  final String productId;

  /// Server-stamped allocation time. Nullable to tolerate partial
  /// writes.
  final DateTime? allocatedAt;

  /// Uid of the admin who granted the seat. Optional.
  final String? allocatedBy;

  /// Server-stamped revocation time. Present iff [status] is
  /// [SeatAllocationStatus.revoked]; kept independently for audit.
  final DateTime? revokedAt;

  /// Live status. Anything other than [SeatAllocationStatus.active]
  /// is filtered out before the seat reaches the cache filter.
  final SeatAllocationStatus status;

  const SeatAllocation({
    required this.orgId,
    required this.uid,
    required this.productId,
    required this.allocatedAt,
    required this.allocatedBy,
    required this.revokedAt,
    required this.status,
  });

  /// Parse a Firestore seat allocation document. Returns null when
  /// required fields (orgId, uid, productId) are missing or malformed
  /// so the repository can fail closed.
  static SeatAllocation? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => fromMap(doc.data());

  /// Pure map -> model parser. Mirrors the validation rules used by
  /// [fromFirestore] but testable without a Firestore mock.
  static SeatAllocation? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final orgId = data['orgId'];
    final uid = data['uid'];
    final productId = data['productId'];
    if (orgId is! String || orgId.isEmpty) return null;
    if (uid is! String || uid.isEmpty) return null;
    if (productId is! String || productId.isEmpty) return null;

    DateTime? parseTs(Object? raw) {
      if (raw is Timestamp) return raw.toDate().toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc();
      return null;
    }

    final allocatedBy = data['allocatedBy'];
    return SeatAllocation(
      orgId: orgId,
      uid: uid,
      productId: productId,
      allocatedAt: parseTs(data['allocatedAt']),
      allocatedBy: allocatedBy is String && allocatedBy.isNotEmpty
          ? allocatedBy
          : null,
      revokedAt: parseTs(data['revokedAt']),
      status: SeatAllocationStatus.fromWire(data['status'] as String?),
    );
  }

  /// True if this seat should be honoured for access decisions.
  bool get isAccessActive => status == SeatAllocationStatus.active;

  /// Project to the lightweight ref tuple used by the cache filter.
  SeatAllocationRef toRef() =>
      SeatAllocationRef(orgId: orgId, productId: productId);

  SeatAllocation copyWith({
    String? orgId,
    String? uid,
    String? productId,
    DateTime? allocatedAt,
    String? allocatedBy,
    DateTime? revokedAt,
    SeatAllocationStatus? status,
  }) {
    return SeatAllocation(
      orgId: orgId ?? this.orgId,
      uid: uid ?? this.uid,
      productId: productId ?? this.productId,
      allocatedAt: allocatedAt ?? this.allocatedAt,
      allocatedBy: allocatedBy ?? this.allocatedBy,
      revokedAt: revokedAt ?? this.revokedAt,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeatAllocation &&
          orgId == other.orgId &&
          uid == other.uid &&
          productId == other.productId &&
          allocatedAt == other.allocatedAt &&
          allocatedBy == other.allocatedBy &&
          revokedAt == other.revokedAt &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
    orgId,
    uid,
    productId,
    allocatedAt,
    allocatedBy,
    revokedAt,
    status,
  );

  @override
  String toString() =>
      'SeatAllocation(orgId: $orgId, uid: $uid, productId: $productId, '
      'status: $status)';
}
