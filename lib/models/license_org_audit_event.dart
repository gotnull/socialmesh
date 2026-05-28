// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Read-only model for a single row in the
// `license_org_audit_events/{eventId}` collection (slice N+2).
//
// Documents are written exclusively by Cloud Functions via
// `appendLicenseOrgAuditEvent`. The mobile client reads a small,
// bounded slice (typically the 5 most recent events for the org the
// user is viewing) and renders a privacy-safe summary on the License
// Org Overview screen.
//
// Privacy posture: this model NEVER reproduces full target ids on the
// UI. `targetId` is kept on the model so a future admin debug view
// can render it, but the Overview row only surfaces action + actor
// label + outcome + relative time. Metadata is intentionally not
// exposed to non-admin members.
//
// See docs/engineering/LICENSE_ORG_AUDIT_EVENTS.md.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Closed action set the audit row is allowed to carry. Mirrors the
/// allowlist in `backend/functions/src/lib/license_org_audit.ts` so
/// the mobile client can switch on the enum exhaustively. Unknown
/// wire values (future server-side actions the client doesn't know
/// about yet) collapse to [unknown] rather than throwing.
enum LicenseOrgAuditAction {
  seatCodeMinted('seat_code_minted'),
  seatCodeRedeemed('seat_code_redeemed'),
  seatCodeReplayed('seat_code_replayed'),
  seatRevokedManual('seat_revoked_manual'),
  seatReplacementMinted('seat_replacement_minted'),
  seatReinstated('seat_reinstated'),
  memberInvited('member_invited'),
  memberJoined('member_joined'),
  orgPurchased('org_purchased'),
  orgOwnerCollision('org_owner_collision'),
  orgSeatRevokedRefund('org_seat_revoked_refund'),
  orgSuspendedDrained('org_suspended_drained'),
  licenseOrgRenamed('license_org_renamed'),
  unknown('');

  final String wire;

  const LicenseOrgAuditAction(this.wire);

  static LicenseOrgAuditAction fromWire(String? value) {
    if (value == null || value.isEmpty) return LicenseOrgAuditAction.unknown;
    for (final action in LicenseOrgAuditAction.values) {
      if (action.wire == value) return action;
    }
    return LicenseOrgAuditAction.unknown;
  }
}

/// Outcome of a single audit row. `success` and `rejected` are the
/// only valid wire values per the audit helper's `VALID_OUTCOMES`.
enum LicenseOrgAuditOutcome {
  success('success'),
  rejected('rejected'),
  unknown('');

  final String wire;

  const LicenseOrgAuditOutcome(this.wire);

  static LicenseOrgAuditOutcome fromWire(String? value) {
    switch (value) {
      case 'success':
        return LicenseOrgAuditOutcome.success;
      case 'rejected':
        return LicenseOrgAuditOutcome.rejected;
      default:
        return LicenseOrgAuditOutcome.unknown;
    }
  }
}

/// Actor role recorded on the audit row. Used by the UI to colour
/// the actor badge and decide whether to surface admin-only metadata
/// on future drill-in surfaces.
enum LicenseOrgAuditActorRole {
  owner('owner'),
  admin('admin'),
  member('member'),
  system('system'),
  unknown('');

  final String wire;

  const LicenseOrgAuditActorRole(this.wire);

  static LicenseOrgAuditActorRole fromWire(String? value) {
    switch (value) {
      case 'owner':
        return LicenseOrgAuditActorRole.owner;
      case 'admin':
        return LicenseOrgAuditActorRole.admin;
      case 'member':
        return LicenseOrgAuditActorRole.member;
      case 'system':
        return LicenseOrgAuditActorRole.system;
      default:
        return LicenseOrgAuditActorRole.unknown;
    }
  }
}

/// Target kind referenced by the audit row. Matches the wire enum
/// from `appendLicenseOrgAuditEvent`. Used by the UI to decide what
/// shape the [LicenseOrgAuditEvent.targetId] takes (uid, allocation
/// id, hashed code prefix, etc.).
enum LicenseOrgAuditTargetKind {
  licenseOrg('license_org'),
  licenseOrgInvite('license_org_invite'),
  licenseOrgMembership('license_org_membership'),
  licenseSeatCode('license_seat_code'),
  orgSeatAllocation('org_seat_allocation'),
  unknown('');

  final String wire;

  const LicenseOrgAuditTargetKind(this.wire);

  static LicenseOrgAuditTargetKind fromWire(String? value) {
    if (value == null || value.isEmpty) {
      return LicenseOrgAuditTargetKind.unknown;
    }
    for (final kind in LicenseOrgAuditTargetKind.values) {
      if (kind.wire == value) return kind;
    }
    return LicenseOrgAuditTargetKind.unknown;
  }
}

/// One row in `license_org_audit_events/{eventId}`.
///
/// Construction is via [fromFirestore] / [fromMap]; both return null
/// when the wire data is missing required fields. The repository's
/// query layer drops nulls before they reach the provider stream.
class LicenseOrgAuditEvent {
  /// Auto-generated event id (Firestore doc id). Stable across
  /// reads; used as the widget key by the recent-activity list.
  final String id;

  /// Parent license org id. Mirror of the `licenseOrgId` field, NOT
  /// the doc path - audit events live at the top level. A
  /// defence-in-depth filter; UI consumers re-check this equals the
  /// org they're viewing.
  final String licenseOrgId;

  /// The discriminated action. [LicenseOrgAuditAction.unknown] for
  /// future actions the client hasn't been updated to render yet.
  final LicenseOrgAuditAction action;

  /// What kind of entity the action targets (a membership, an
  /// invite, a seat allocation, etc.). [targetId] is interpreted in
  /// the context of this kind.
  final LicenseOrgAuditTargetKind targetKind;

  /// Identifier of the targeted entity. Format varies by
  /// [targetKind]:
  ///   - membership: the uid of the affected member
  ///   - invite: an 8-char hash prefix of the invite token
  ///   - allocation: the allocation id
  ///   - seat code: an 8-char hash prefix of the LSEAT code
  ///
  /// Nullable on the wire when an action is org-scoped and has no
  /// specific sub-entity.
  final String? targetId;

  /// Uid of the actor who triggered the event. May be `'system'`
  /// when the actor was a Cloud Function (e.g. refund cascade).
  final String actorUid;

  /// Role the actor held in the org at the time of the event.
  final LicenseOrgAuditActorRole actorRole;

  /// Did the action complete or get rejected? Rejection rows carry a
  /// non-null [reasonCode] explaining why.
  final LicenseOrgAuditOutcome outcome;

  /// Snake-case reason code (e.g. `revoked`, `expired`,
  /// `rate_limited`, `not_admin`). Only present on rejected
  /// outcomes; null on success.
  final String? reasonCode;

  /// Server-stamped event time. Used for ordering and relative-time
  /// labels. Null when the timestamp field is missing on a partial
  /// write (the row still renders, with `—` for the time column).
  final DateTime? tsServer;

  /// Optional flat key/value metadata block. Limited to short
  /// primitive values by the server-side validator. The Overview
  /// preview does NOT surface metadata; this field is here so future
  /// admin drill-in surfaces can render it.
  final Map<String, Object?> metadata;

  const LicenseOrgAuditEvent({
    required this.id,
    required this.licenseOrgId,
    required this.action,
    required this.targetKind,
    required this.targetId,
    required this.actorUid,
    required this.actorRole,
    required this.outcome,
    required this.reasonCode,
    required this.tsServer,
    required this.metadata,
  });

  /// Parse a Firestore snapshot. Returns null when required fields
  /// (licenseOrgId, action) are missing - the repository drops null
  /// rows so the UI never has to defend against partial wire data.
  static LicenseOrgAuditEvent? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;
    return fromMap(doc.id, data);
  }

  /// Pure map -> model parser, testable without a Firestore mock.
  static LicenseOrgAuditEvent? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final licenseOrgId = data['licenseOrgId'];
    if (licenseOrgId is! String || licenseOrgId.isEmpty) return null;
    final actionWire = data['action'];
    if (actionWire is! String || actionWire.isEmpty) return null;

    DateTime? tsServer;
    final tsRaw = data['tsServer'];
    if (tsRaw is Timestamp) {
      tsServer = tsRaw.toDate().toUtc();
    } else if (tsRaw is String) {
      tsServer = DateTime.tryParse(tsRaw)?.toUtc();
    }

    final actorUid = data['actorUid'];
    final reasonRaw = data['reasonCode'];
    final targetIdRaw = data['targetId'];

    final metadataRaw = data['metadata'];
    final metadata = <String, Object?>{};
    if (metadataRaw is Map) {
      metadataRaw.forEach((k, v) {
        if (k is String) metadata[k] = v;
      });
    }

    return LicenseOrgAuditEvent(
      id: id,
      licenseOrgId: licenseOrgId,
      action: LicenseOrgAuditAction.fromWire(actionWire),
      targetKind: LicenseOrgAuditTargetKind.fromWire(
        data['targetKind'] as String?,
      ),
      targetId: targetIdRaw is String && targetIdRaw.isNotEmpty
          ? targetIdRaw
          : null,
      actorUid: actorUid is String ? actorUid : '',
      actorRole: LicenseOrgAuditActorRole.fromWire(
        data['actorRole'] as String?,
      ),
      outcome: LicenseOrgAuditOutcome.fromWire(data['outcome'] as String?),
      reasonCode: reasonRaw is String && reasonRaw.isNotEmpty
          ? reasonRaw
          : null,
      tsServer: tsServer,
      metadata: Map.unmodifiable(metadata),
    );
  }

  /// Stable opaque actor label used by the Overview preview. Mirrors
  /// the `#XXXXXX` convention used elsewhere in the licensing UI
  /// (the Members sheet's display label). Returns `system` verbatim
  /// for system-actor rows (Cloud Functions like the refund cascade)
  /// so the audit row is self-explanatory.
  String get actorDisplayLabel {
    if (actorRole == LicenseOrgAuditActorRole.system) return 'system';
    if (actorUid.isEmpty) return '#??????';
    return '#${actorUid.substring(0, actorUid.length >= 6 ? 6 : actorUid.length).toUpperCase()}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseOrgAuditEvent &&
          id == other.id &&
          licenseOrgId == other.licenseOrgId &&
          action == other.action &&
          targetKind == other.targetKind &&
          targetId == other.targetId &&
          actorUid == other.actorUid &&
          actorRole == other.actorRole &&
          outcome == other.outcome &&
          reasonCode == other.reasonCode &&
          tsServer == other.tsServer;

  @override
  int get hashCode => Object.hash(
    id,
    licenseOrgId,
    action,
    targetKind,
    targetId,
    actorUid,
    actorRole,
    outcome,
    reasonCode,
    tsServer,
  );

  @override
  String toString() =>
      'LicenseOrgAuditEvent(id: $id, action: ${action.wire}, '
      'outcome: ${outcome.wire}, actorRole: ${actorRole.wire})';
}
