// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Thin client wrapper over the three slice N+5 invite callables:
//   - inviteLicenseOrgMember    (admin / owner mints a new invite)
//   - acceptLicenseOrgInvite    (any signed-in user redeems a token)
//   - revokeLicenseOrgInvite    (admin / owner cancels an invite)
//
// All three return sealed result types so callers can switch on the
// outcome without inspecting raw FirebaseFunctionsException codes.
// Tests inject a fake invoker so the service does not require a
// real Firebase emulator.
//
// PII-safe: the service does NOT log uid, orgId, productId, or the
// plaintext token. The accept callable's plaintext token is forwarded
// verbatim; only the deep-link router and the consent screen handle
// it, never log output.
//
// See docs/engineering/LICENSE_ORG_INVITES.md.

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/logging.dart';

abstract class InviteCallableInvoker {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);

  static InviteCallableInvoker firebase() => _FirebaseInviteCallableInvoker();
}

class _FirebaseInviteCallableInvoker implements InviteCallableInvoker {
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }
}

// =============================================================================
// Mint
// =============================================================================

sealed class MintInviteResult {
  const MintInviteResult();
}

class MintInviteSuccess extends MintInviteResult {
  final String inviteId;
  final String acceptUrl;
  final DateTime expiresAt;

  /// Multi-use invite cap. Equals the org's remaining seat capacity
  /// at mint time. Null on legacy single-use mints (treated as 1).
  final int? maxUses;

  /// True when this mint REVOKED a previously-active invite (i.e.
  /// the owner regenerated the share link, invalidating any URL
  /// they shared earlier). UI uses this to surface a snackbar like
  /// "Old link is now invalid".
  final bool replacedPrevious;

  const MintInviteSuccess({
    required this.inviteId,
    required this.acceptUrl,
    required this.expiresAt,
    this.maxUses,
    this.replacedPrevious = false,
  });
}

class MintInviteFailure extends MintInviteResult {
  final String reasonCode;
  final String message;

  const MintInviteFailure({required this.reasonCode, required this.message});
}

// =============================================================================
// Get active invite (multi-use shareable-link contract)
// =============================================================================

sealed class GetActiveInviteResult {
  const GetActiveInviteResult();
}

class GetActiveInviteNone extends GetActiveInviteResult {
  const GetActiveInviteNone();
}

class GetActiveInviteFound extends GetActiveInviteResult {
  final String inviteId;
  final String? acceptUrl;
  final int maxUses;
  final int usedCount;
  final DateTime expiresAt;

  const GetActiveInviteFound({
    required this.inviteId,
    required this.acceptUrl,
    required this.maxUses,
    required this.usedCount,
    required this.expiresAt,
  });

  /// Joins remaining on this link. Owner-facing UI shows this so the
  /// owner knows how many people can still redeem before the link
  /// exhausts and they need to regenerate.
  int get remaining => (maxUses - usedCount).clamp(0, maxUses);
}

class GetActiveInviteFailure extends GetActiveInviteResult {
  final String reasonCode;
  final String message;

  const GetActiveInviteFailure({
    required this.reasonCode,
    required this.message,
  });
}

// =============================================================================
// Accept
// =============================================================================

sealed class AcceptInviteResult {
  const AcceptInviteResult();
}

class AcceptInviteSuccess extends AcceptInviteResult {
  final String licenseOrgId;
  final String allocationId;
  final bool alreadyAllocated;

  const AcceptInviteSuccess({
    required this.licenseOrgId,
    required this.allocationId,
    required this.alreadyAllocated,
  });
}

class AcceptInviteFailure extends AcceptInviteResult {
  final AcceptInviteReason reason;
  final String message;

  const AcceptInviteFailure({required this.reason, required this.message});
}

/// Mapped from `FirebaseFunctionsException.code` + `details.reason`
/// where present. The string variants ride through from the server's
/// rejection-audit `reasonCode` for any case the closed enum below
/// hasn't anticipated.
enum AcceptInviteReason {
  notFound,
  expired,
  alreadyUsed,
  revoked,
  orgSuspended,
  malformedToken,
  permissionDenied,
  unauthenticated,
  rateLimited,

  /// The caller is the owner of the target org and tried to redeem
  /// their own invite. Backend rejects to prevent the owner from
  /// consuming a seat and ending up as both OWNER and MEMBER.
  ownerCannotRedeem,
  generic,
}

// =============================================================================
// Revoke
// =============================================================================

sealed class RevokeInviteResult {
  const RevokeInviteResult();
}

class RevokeInviteSuccess extends RevokeInviteResult {
  final bool revoked;

  const RevokeInviteSuccess({required this.revoked});
}

class RevokeInviteFailure extends RevokeInviteResult {
  final String reasonCode;
  final String message;

  const RevokeInviteFailure({required this.reasonCode, required this.message});
}

// =============================================================================
// Service
// =============================================================================

class LicenseOrgInviteService {
  final InviteCallableInvoker _invoker;

  LicenseOrgInviteService({InviteCallableInvoker? invoker})
    : _invoker = invoker ?? InviteCallableInvoker.firebase();

  Future<MintInviteResult> mintInvite({
    required String licenseOrgId,
    required String productId,
    int? expiresInDays,
    String? note,
  }) async {
    AppLogging.groupLicensing(
      '[LicenseOrgInviteService] mintInvite '
      'productExpiresInDays=${expiresInDays ?? 7}',
    );
    try {
      final payload = <String, dynamic>{
        'licenseOrgId': licenseOrgId,
        'productId': productId,
        if (expiresInDays != null) 'expiresInDays': expiresInDays,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };
      final result = await _invoker.call('inviteLicenseOrgMember', payload);
      return MintInviteSuccess(
        inviteId: result['inviteId'] as String,
        acceptUrl: result['acceptUrl'] as String,
        expiresAt: DateTime.parse(result['expiresAt'] as String),
        maxUses: (result['maxUses'] as num?)?.toInt(),
        replacedPrevious: (result['replacedPrevious'] as bool?) ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] mintInvite failed code=${e.code}',
      );
      return MintInviteFailure(reasonCode: e.code, message: e.message ?? '');
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] mintInvite unexpected '
        '(error class: ${e.runtimeType})',
      );
      return MintInviteFailure(reasonCode: 'internal', message: e.toString());
    }
  }

  /// Read the currently-active multi-use invite for (orgId, productId).
  /// The mint sheet calls this on open so it can show the existing
  /// share link instead of always minting a fresh one (which under
  /// the v2 contract would revoke the old link and surprise an owner
  /// who already shared it). Returns [GetActiveInviteNone] when no
  /// active invite exists; the owner must then mint a fresh one to
  /// get a shareable URL.
  Future<GetActiveInviteResult> getActiveInvite({
    required String licenseOrgId,
    required String productId,
  }) async {
    AppLogging.groupLicensing('[LicenseOrgInviteService] getActiveInvite');
    try {
      final result = await _invoker.call('getActiveLicenseOrgInvite', {
        'licenseOrgId': licenseOrgId,
        'productId': productId,
      });
      if ((result['hasActive'] as bool?) != true) {
        return const GetActiveInviteNone();
      }
      // acceptUrl is only present when STORE_INVITE_TOKEN_PLAINTEXT
      // is on (default off in production). Surface null so the UI
      // can prompt the owner to regenerate when the plaintext is
      // not retrievable.
      final urlRaw = result['acceptUrl'];
      return GetActiveInviteFound(
        inviteId: result['inviteId'] as String,
        acceptUrl: urlRaw is String && urlRaw.isNotEmpty ? urlRaw : null,
        maxUses: (result['maxUses'] as num?)?.toInt() ?? 0,
        usedCount: (result['usedCount'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.parse(result['expiresAt'] as String),
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] getActiveInvite failed code=${e.code}',
      );
      return GetActiveInviteFailure(
        reasonCode: e.code,
        message: e.message ?? '',
      );
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] getActiveInvite unexpected '
        '(error class: ${e.runtimeType})',
      );
      return GetActiveInviteFailure(
        reasonCode: 'internal',
        message: e.toString(),
      );
    }
  }

  Future<AcceptInviteResult> acceptInvite(String token) async {
    AppLogging.groupLicensing(
      '[LicenseOrgInviteService] acceptInvite tokenLen=${token.length}',
    );
    try {
      final result = await _invoker.call('acceptLicenseOrgInvite', {
        'token': token,
      });
      return AcceptInviteSuccess(
        licenseOrgId: result['licenseOrgId'] as String,
        allocationId: result['allocationId'] as String,
        alreadyAllocated: (result['alreadyAllocated'] as bool?) ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] acceptInvite failed code=${e.code}',
      );
      final reason = _mapAcceptReason(e);
      return AcceptInviteFailure(reason: reason, message: e.message ?? '');
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] acceptInvite unexpected '
        '(error class: ${e.runtimeType})',
      );
      return AcceptInviteFailure(
        reason: AcceptInviteReason.generic,
        message: e.toString(),
      );
    }
  }

  Future<RevokeInviteResult> revokeInvite(String inviteId) async {
    AppLogging.groupLicensing('[LicenseOrgInviteService] revokeInvite');
    try {
      final result = await _invoker.call('revokeLicenseOrgInvite', {
        'inviteId': inviteId,
      });
      return RevokeInviteSuccess(
        revoked: (result['revoked'] as bool?) ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] revokeInvite failed code=${e.code}',
      );
      return RevokeInviteFailure(reasonCode: e.code, message: e.message ?? '');
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgInviteService] revokeInvite unexpected '
        '(error class: ${e.runtimeType})',
      );
      return RevokeInviteFailure(reasonCode: 'internal', message: e.toString());
    }
  }

  AcceptInviteReason _mapAcceptReason(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').toLowerCase();
    switch (e.code) {
      case 'unauthenticated':
        return AcceptInviteReason.unauthenticated;
      case 'permission-denied':
        return AcceptInviteReason.permissionDenied;
      case 'not-found':
        return AcceptInviteReason.notFound;
      case 'invalid-argument':
        return AcceptInviteReason.malformedToken;
      case 'resource-exhausted':
        return AcceptInviteReason.rateLimited;
      case 'failed-precondition':
        if (msg.contains('owner cannot redeem')) {
          return AcceptInviteReason.ownerCannotRedeem;
        }
        if (msg.contains('expired')) return AcceptInviteReason.expired;
        if (msg.contains('already used') || msg.contains('exhausted')) {
          return AcceptInviteReason.alreadyUsed;
        }
        if (msg.contains('revoked')) return AcceptInviteReason.revoked;
        if (msg.contains('suspended') || msg.contains('no longer exists')) {
          return AcceptInviteReason.orgSuspended;
        }
        return AcceptInviteReason.generic;
      default:
        return AcceptInviteReason.generic;
    }
  }
}
