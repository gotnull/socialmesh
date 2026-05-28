// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Thin client wrapper over the slice N+5+2 settings callable:
//   - updateLicenseOrgName  (owner-only rename)
//
// Sibling to [LicenseOrgInviteService] / [LicenseOrgSeatService]. Reuses
// the same [InviteCallableInvoker] abstraction so tests inject the
// same fake.
//
// Validation parity: the client clamps to the same constraints the
// backend enforces (non-empty after trim, max 50 chars). Pre-flighting
// here keeps the snackbar fast and avoids a network round-trip for
// the trivial-typo case.
//
// PII-safe: never logs uid, orgId, or the submitted name.

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/logging.dart';
import 'license_org_invite_service.dart' show InviteCallableInvoker;

/// Hard cap matched against the backend's `NAME_MAX_LEN`. Source of
/// truth lives in `backend/functions/src/license_org_settings.ts`; pin
/// both sides via the service tests.
const int licenseOrgNameMaxLength = 50;

sealed class UpdateLicenseOrgNameResult {
  const UpdateLicenseOrgNameResult();
}

class UpdateLicenseOrgNameSuccess extends UpdateLicenseOrgNameResult {
  final String licenseOrgId;
  final String name;
  final String previousName;

  const UpdateLicenseOrgNameSuccess({
    required this.licenseOrgId,
    required this.name,
    required this.previousName,
  });

  /// True when the submitted name equalled the stored name. The
  /// backend writes nothing and skips the audit row in this case so
  /// the UI should show a neutral "no change" snackbar.
  bool get noChange => name == previousName;
}

enum UpdateLicenseOrgNameReason {
  /// Caller is not the org owner (admins are intentionally excluded).
  permissionDenied,

  /// The org doc no longer exists (suspended / disbanded since the
  /// sheet opened).
  notFound,

  /// Client validation: empty (after trim) or over the length cap.
  invalidArgument,

  /// User must be signed in with a permanent account.
  unauthenticated,

  /// Network or other transient.
  generic,
}

class UpdateLicenseOrgNameFailure extends UpdateLicenseOrgNameResult {
  final UpdateLicenseOrgNameReason reason;
  final String message;

  const UpdateLicenseOrgNameFailure({
    required this.reason,
    required this.message,
  });
}

class LicenseOrgSettingsService {
  final InviteCallableInvoker _invoker;

  LicenseOrgSettingsService({InviteCallableInvoker? invoker})
    : _invoker = invoker ?? InviteCallableInvoker.firebase();

  /// Rename [licenseOrgId] to [name]. Caller MUST be the org owner;
  /// admins are rejected with [UpdateLicenseOrgNameReason.permissionDenied].
  ///
  /// Client-side validation pre-empts the network round-trip for the
  /// trivial cases (empty / over-long). Anything else falls through
  /// to the callable.
  Future<UpdateLicenseOrgNameResult> updateName({
    required String licenseOrgId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return UpdateLicenseOrgNameFailure(
        reason: UpdateLicenseOrgNameReason.invalidArgument,
        message: 'name is required',
      );
    }
    // Match the backend's JS-side `.length` (UTF-16 code units), not
    // graphemes. Both sides agree to within the same character count
    // so the client-side preflight never accepts a string the server
    // would reject.
    if (trimmed.length > licenseOrgNameMaxLength) {
      return UpdateLicenseOrgNameFailure(
        reason: UpdateLicenseOrgNameReason.invalidArgument,
        message: 'name is too long',
      );
    }

    AppLogging.groupLicensing('[LicenseOrgSettingsService] updateName');
    try {
      final result = await _invoker.call('updateLicenseOrgName', {
        'licenseOrgId': licenseOrgId,
        'name': trimmed,
      });
      return UpdateLicenseOrgNameSuccess(
        licenseOrgId: result['licenseOrgId'] as String,
        name: result['name'] as String,
        previousName: result['previousName'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgSettingsService] updateName failed code=${e.code}',
      );
      return UpdateLicenseOrgNameFailure(
        reason: _mapReason(e),
        message: e.message ?? '',
      );
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgSettingsService] updateName unexpected '
        '(error class: ${e.runtimeType})',
      );
      return UpdateLicenseOrgNameFailure(
        reason: UpdateLicenseOrgNameReason.generic,
        message: e.toString(),
      );
    }
  }
}

UpdateLicenseOrgNameReason _mapReason(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'permission-denied':
      return UpdateLicenseOrgNameReason.permissionDenied;
    case 'not-found':
      return UpdateLicenseOrgNameReason.notFound;
    case 'invalid-argument':
      return UpdateLicenseOrgNameReason.invalidArgument;
    case 'unauthenticated':
      return UpdateLicenseOrgNameReason.unauthenticated;
    default:
      return UpdateLicenseOrgNameReason.generic;
  }
}
