// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Thin client wrapper over the slice N+5+1 seat callable:
//   - revokeLicenseSeat  (admin / owner deactivates a member's seat)
//
// Sibling to [LicenseOrgInviteService] but lives in its own file so
// the invite namespace doesn't grow into "license-org-anything". Reuses
// the same [InviteCallableInvoker] abstraction so tests inject the
// same fake.
//
// Doc-id contract: the backend keys seat allocations by
// `<orgId>__<uid>__<productId>`. Today every Community Pack purchase
// mints a single `complete_pack` seat per member; if a future product
// catalog introduces per-pack seats, the caller must pass the matching
// productId. [communityPackSeatProductId] is exposed for the common
// path so callers don't hand-roll the constant.
//
// PII-safe: never logs uid, orgId, productId, or the allocationId.

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/logging.dart';
import 'license_org_invite_service.dart' show InviteCallableInvoker;

/// Product id every Community Pack 10/20 seat resolves to. The org
/// purchase mints `complete_pack` entitlement plus the bundle
/// expansion, but the seat row itself carries the canonical
/// `complete_pack` productId. Pinned here so the revoke UI does not
/// have to know the catalog detail.
const String communityPackSeatProductId = 'complete_pack';

/// Compose the seat allocation document id from the same three
/// components the backend uses. Source of truth lives in
/// `backend/functions/src/license_org_invites.ts::seatAllocationDocId`;
/// pin them on both sides so a rename surfaces in tests.
String seatAllocationDocId({
  required String licenseOrgId,
  required String uid,
  required String productId,
}) {
  return '${licenseOrgId}__${uid}__$productId';
}

sealed class RevokeSeatResult {
  const RevokeSeatResult();
}

class RevokeSeatSuccess extends RevokeSeatResult {
  final String allocationId;

  /// True when the backend reports the seat was ALREADY revoked
  /// before this call. The owner UI shows a "no change" snackbar in
  /// this case (a double-tap, or two admins racing the same revoke).
  final bool alreadyRevoked;

  const RevokeSeatSuccess({
    required this.allocationId,
    required this.alreadyRevoked,
  });
}

enum RevokeSeatReason {
  permissionDenied,
  notFound,
  unauthenticated,
  rateLimited,
  generic,
}

class RevokeSeatFailure extends RevokeSeatResult {
  final RevokeSeatReason reason;
  final String message;

  const RevokeSeatFailure({required this.reason, required this.message});
}

class LicenseOrgSeatService {
  final InviteCallableInvoker _invoker;

  LicenseOrgSeatService({InviteCallableInvoker? invoker})
    : _invoker = invoker ?? InviteCallableInvoker.firebase();

  /// Revoke the seat identified by [allocationId]. Caller is expected
  /// to be the owner or an admin of [licenseOrgId]; the backend
  /// rejects non-admins with `permission-denied`.
  ///
  /// [reason] is optional free-form text that lands in the audit row
  /// so the owner can later see why a member was removed. Max length
  /// is enforced server-side (currently 280 chars; over-length is
  /// rejected with `invalid-argument`).
  Future<RevokeSeatResult> revokeSeat({
    required String licenseOrgId,
    required String allocationId,
    String? reason,
  }) async {
    AppLogging.groupLicensing('[LicenseOrgSeatService] revokeSeat requested');
    try {
      final payload = <String, dynamic>{
        'licenseOrgId': licenseOrgId,
        'allocationId': allocationId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };
      final result = await _invoker.call('revokeLicenseSeat', payload);
      return RevokeSeatSuccess(
        allocationId: result['allocationId'] as String,
        alreadyRevoked: (result['alreadyRevoked'] as bool?) ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgSeatService] revokeSeat failed code=${e.code}',
      );
      return RevokeSeatFailure(
        reason: _mapRevokeReason(e),
        message: e.message ?? '',
      );
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgSeatService] revokeSeat unexpected '
        '(error class: ${e.runtimeType})',
      );
      return RevokeSeatFailure(
        reason: RevokeSeatReason.generic,
        message: e.toString(),
      );
    }
  }

  /// Inverse of [revokeSeat]: flips a revoked allocation row back to
  /// active so the affected member regains access without redeeming
  /// a fresh invite. Backend rejects when:
  ///   - caller is not owner/admin (`permission-denied`)
  ///   - allocation doesn't exist or doesn't belong to the org
  ///     (`notFound`)
  ///   - org is suspended (`failedPrecondition` mapped to
  ///     [ReinstateSeatReason.orgSuspended])
  ///   - reinstating would push past the org's seat capacity
  ///     (`failedPrecondition` mapped to
  ///     [ReinstateSeatReason.overCapacity])
  ///   - admin rate-limit exhausted (`rateLimited`)
  Future<ReinstateSeatResult> reinstateSeat({
    required String licenseOrgId,
    required String allocationId,
  }) async {
    AppLogging.groupLicensing(
      '[LicenseOrgSeatService] reinstateSeat requested',
    );
    try {
      final result = await _invoker.call('reinstateLicenseSeat', {
        'licenseOrgId': licenseOrgId,
        'allocationId': allocationId,
      });
      return ReinstateSeatSuccess(
        allocationId: result['allocationId'] as String,
        alreadyActive: (result['alreadyActive'] as bool?) ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgSeatService] reinstateSeat failed code=${e.code} '
        'msg=${e.message?.length ?? 0}c',
      );
      return ReinstateSeatFailure(
        reason: _mapReinstateReason(e),
        message: e.message ?? '',
      );
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgSeatService] reinstateSeat unexpected '
        '(error class: ${e.runtimeType})',
      );
      return ReinstateSeatFailure(
        reason: ReinstateSeatReason.generic,
        message: e.toString(),
      );
    }
  }
}

sealed class ReinstateSeatResult {
  const ReinstateSeatResult();
}

class ReinstateSeatSuccess extends ReinstateSeatResult {
  final String allocationId;

  /// True when the backend reports the seat was ALREADY active before
  /// this call (a double-tap, or two admins racing the same reinstate).
  final bool alreadyActive;

  const ReinstateSeatSuccess({
    required this.allocationId,
    required this.alreadyActive,
  });
}

enum ReinstateSeatReason {
  permissionDenied,
  notFound,
  unauthenticated,
  rateLimited,
  orgSuspended,

  /// Reinstating would push the org past its `seatCapacity`. Owner
  /// sees a distinct message: "Group is at the seat cap — revoke
  /// someone else first."
  overCapacity,
  generic,
}

class ReinstateSeatFailure extends ReinstateSeatResult {
  final ReinstateSeatReason reason;
  final String message;

  const ReinstateSeatFailure({required this.reason, required this.message});
}

ReinstateSeatReason _mapReinstateReason(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'permission-denied':
      return ReinstateSeatReason.permissionDenied;
    case 'not-found':
      return ReinstateSeatReason.notFound;
    case 'unauthenticated':
      return ReinstateSeatReason.unauthenticated;
    case 'resource-exhausted':
      return ReinstateSeatReason.rateLimited;
    case 'failed-precondition':
      // Backend uses the same code for both "org suspended" and
      // "over capacity". Discriminate by the message substring the
      // backend emits — preferred over a side-channel because the
      // wire shape is small and we already pin the message in the
      // backend source-text tests.
      final msg = (e.message ?? '').toLowerCase();
      if (msg.contains('seat capacity'))
        return ReinstateSeatReason.overCapacity;
      return ReinstateSeatReason.orgSuspended;
    default:
      return ReinstateSeatReason.generic;
  }
}

RevokeSeatReason _mapRevokeReason(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'permission-denied':
      return RevokeSeatReason.permissionDenied;
    case 'not-found':
      return RevokeSeatReason.notFound;
    case 'unauthenticated':
      return RevokeSeatReason.unauthenticated;
    case 'resource-exhausted':
      return RevokeSeatReason.rateLimited;
    default:
      return RevokeSeatReason.generic;
  }
}
