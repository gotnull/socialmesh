// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// License Org Invite-accept screen (slice N+5).
//
// Reached via the deep-link router for `https://socialmesh.app/invite/<token>`.
// Renders the consent gate (mandatory; no silent acceptance per the
// spec) and on user tap calls `acceptLicenseOrgInvite`.
//
// Privacy contract: shows the inviting org's name (read via a tiny
// preview path from license_orgs/{id}; admin reads via the rule
// fail closed for non-members so the lookup happens after accept
// for now). Does NOT show the inviter's uid or display name; only
// the inviter's free-form `note` (if any) lands on this screen, and
// even then only after accept since the invite doc is admin-read
// only.
//
// See docs/engineering/LICENSE_ORG_INVITES.md.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/external_purchase_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/license_org/license_org_invite_service.dart';
import '../../utils/snackbar.dart';

/// Route helper so deep-link router callers can write
/// `Navigator.push(InviteAcceptScreen.route(token))` without
/// importing MaterialPageRoute.
class InviteAcceptScreen extends ConsumerStatefulWidget {
  final String token;

  const InviteAcceptScreen({required this.token, super.key});

  static Route<void> route(String token) =>
      MaterialPageRoute<void>(builder: (_) => InviteAcceptScreen(token: token));

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen>
    with LifecycleSafeMixin<InviteAcceptScreen> {
  bool _busy = false;
  String? _errorMessage;

  Future<void> _onAccept() async {
    if (_busy) return;
    safeSetState(() {
      _busy = true;
      _errorMessage = null;
    });
    AppLogging.groupLicensing(
      '[InviteAcceptScreen] accept tapped tokenLen=${widget.token.length}',
    );
    final service = LicenseOrgInviteService();
    final result = await service.acceptInvite(widget.token);
    if (!mounted) return;

    switch (result) {
      case AcceptInviteSuccess(:final licenseOrgId, :final alreadyAllocated):
        AppLogging.groupLicensing(
          '[InviteAcceptScreen] accept ok replay=$alreadyAllocated',
        );
        // Refresh the external-entitlements cache so the org-scoped
        // packs unlocked by the freshly-allocated seat appear in
        // `effectiveEntitlementsProvider` without an app restart. The
        // membership + seat Firestore snapshots already invalidate
        // `currentUserLicenseOrgIdsProvider` and
        // `currentUserSeatAllocationsProvider`, but the entitlement
        // docs themselves only land in the local cache via a callable
        // refresh — without this kick the user sees price labels
        // until the next launch. Failure is swallowed by the helper
        // (it never throws), so error-pathing the snackbar isn't
        // needed.
        unawaited(refreshExternalEntitlements(ref));
        await ref.read(hapticServiceProvider).trigger(HapticType.success);
        if (!mounted) return;
        safeShowSnackBar(
          context.l10n.licenseOrgInviteAcceptSuccess(licenseOrgId),
          type: SnackBarType.success,
        );
        // The success snackbar lives on this screen's local
        // GlassScaffold ScaffoldMessenger. Popping in the same frame
        // unmounts that messenger before the snackbar renders, so
        // the user never sees confirmation. Hold the route for 1.8s
        // (matches the snackbar's natural display window) before
        // returning the user to wherever they came from.
        await Future.delayed(const Duration(milliseconds: 1800));
        if (!mounted) return;
        safeNavigatorPop();
      case AcceptInviteFailure(:final reason):
        AppLogging.groupLicensing(
          '[InviteAcceptScreen] accept failed reason=$reason',
        );
        await ref.read(hapticServiceProvider).trigger(HapticType.error);
        if (!mounted) return;
        safeSetState(() {
          _busy = false;
          _errorMessage = _errorMessageFor(context.l10n, reason);
        });
    }
  }

  void _onDecline() {
    AppLogging.groupLicensing('[InviteAcceptScreen] declined');
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    safeNavigatorPop();
  }

  String _errorMessageFor(AppLocalizations l10n, AcceptInviteReason reason) {
    switch (reason) {
      case AcceptInviteReason.expired:
        return l10n.licenseOrgInviteAcceptErrorExpired;
      case AcceptInviteReason.alreadyUsed:
        return l10n.licenseOrgInviteAcceptErrorRedeemed;
      case AcceptInviteReason.revoked:
        return l10n.licenseOrgInviteAcceptErrorRevoked;
      case AcceptInviteReason.malformedToken:
      case AcceptInviteReason.notFound:
        return l10n.licenseOrgInviteAcceptErrorMalformed;
      case AcceptInviteReason.orgSuspended:
        return l10n.licenseOrgInviteAcceptErrorOrgSuspended;
      case AcceptInviteReason.rateLimited:
        return l10n.licenseOrgInviteAcceptErrorRateLimited;
      case AcceptInviteReason.ownerCannotRedeem:
        return l10n.licenseOrgInviteAcceptErrorOwnerSelf;
      case AcceptInviteReason.permissionDenied:
      case AcceptInviteReason.unauthenticated:
      case AcceptInviteReason.generic:
        return l10n.licenseOrgInviteAcceptErrorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.licenseOrgInviteAcceptTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            AppTheme.spacing24,
            AppTheme.spacing24,
            AppTheme.spacing32,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Hero icon block.
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radius16),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.diversity_3_outlined,
                    color: context.accentColor,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
              Text(
                l10n.licenseOrgInviteAcceptHeadline('this group'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: context.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        l10n.licenseOrgInviteAcceptDescription,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppTheme.spacing16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.errorRed,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppTheme.errorRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacing32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _onAccept,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(l10n.licenseOrgInviteAcceptButton),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(l10n.licenseOrgInviteDeclineButton),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
