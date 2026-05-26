// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Per-org card used by [LicenseOrgOverviewScreen]. Renders one
// [SectionTitle] with the org name over a canonical [InfoTable].
//
// Status and Role are rendered as **pill-shaped valueWidgets inside
// the InfoTable cells** rather than as a SectionTitle trailing badge.
// This keeps both pills on the same vertical grid as the table values
// (right-aligned to the InfoTable's internal cell padding), which was
// the alignment ambiguity the first ship had — a Spacer-pushed
// trailing chip in the SectionTitle never aligned correctly with the
// InfoTable border below.
//
// Spec parent: docs/engineering/LICENSE_ORG_OVERVIEW_SCREEN.md.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/revenuecat_config.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/safety.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import '../../models/license_org.dart';
import '../../models/license_org_membership.dart';
import '../../providers/license_org_members_providers.dart';
import '../../providers/license_org_overview_providers.dart';
import '../../services/license_org/license_org_invite_service.dart';
import '../../utils/snackbar.dart';
import 'license_org_members_sheet.dart';

/// Reads the per-org providers for [orgId] and renders the canonical
/// [SectionTitle] + [InfoTable] card.
///
/// Fail-closed everywhere:
///   - org doc -> slug as placeholder name, unknown status pill
///   - membership doc -> falls back to [LicenseOrgMemberRole.unknown]
///   - seat count -> 0 while loading or on error
class LicenseOrgOverviewCard extends ConsumerWidget {
  final String orgId;

  const LicenseOrgOverviewCard({super.key, required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgAsync = ref.watch(licenseOrgProvider(orgId));
    final role = ref.watch(licenseOrgRoleProvider(orgId));
    final seatCount = ref.watch(licenseOrgRedeemedSeatCountProvider(orgId));
    final membershipAsync = ref.watch(
      currentUserLicenseOrgMembershipProvider(orgId),
    );

    final l10n = context.l10n;
    final org = orgAsync.maybeWhen(data: (o) => o, orElse: () => null);
    final membership = membershipAsync.maybeWhen(
      data: (m) => m,
      orElse: () => null,
    );

    final displayName = (org?.name.isNotEmpty ?? false) ? org!.name : orgId;
    final status = org?.status ?? LicenseOrgStatus.unknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: displayName),
        const SizedBox(height: AppTheme.spacing12),
        InfoTable(
          rows: [
            // Status first - the field a user opens this screen TO
            // check. Rendered as a colored pill in the value cell so
            // active / suspended is scannable at a glance.
            InfoTableRow(
              label: l10n.licenseOrgOverviewStatusLabel,
              value: _statusString(l10n, status),
              icon: Icons.shield_outlined,
              valueWidget: _StatusPill(status: status, l10n: l10n),
            ),
            // Role second - "what can I do here?". Owner / Admin /
            // Member are accent-colored pills in the value cell.
            InfoTableRow(
              label: l10n.licenseOrgOverviewRoleLabel,
              value: _roleString(l10n, role),
              icon: Icons.workspace_premium_outlined,
              valueWidget: _RolePill(role: role, l10n: l10n),
            ),
            // Primary metric - how many seats the current user holds.
            InfoTableRow(
              label: l10n.licenseOrgOverviewSeatsLabel,
              value: seatCount.toString(),
              icon: Icons.event_seat_outlined,
            ),
            // Audit / temporal.
            if (membership?.joinedAt != null)
              InfoTableRow(
                label: l10n.licenseOrgOverviewJoinedLabel,
                value: _formatJoinedAt(membership!.joinedAt!),
                icon: Icons.event_available_outlined,
              ),
            // Technical identifier - bottom row, copy/debug only.
            InfoTableRow(
              label: l10n.licenseOrgOverviewOrgIdLabel,
              value: orgId,
              icon: Icons.fingerprint,
            ),
          ],
        ),
        // Trailing action area. Suspended orgs hide the View members
        // button - the roster sheet would render empty + an
        // explanatory state, but keeping the button visible would
        // imply admin recourse that doesn't exist. The "Open in web
        // admin" button is still gated on the future
        // licenseOrgAdminWebEnabled flag and stays deferred.
        if (status == LicenseOrgStatus.active) ...[
          const SizedBox(height: AppTheme.spacing12),
          _ViewMembersButton(orgId: orgId),
          // Owner / admin can mint an invite link directly from the
          // Overview card. Member role doesn't see the button (mint
          // is admin-only at the Function layer; surfacing the
          // button to members would be a confusing dead-end). The
          // future web admin pane has the same mint affordance.
          if (role == LicenseOrgMemberRole.owner ||
              role == LicenseOrgMemberRole.admin) ...[
            const SizedBox(height: AppTheme.spacing8),
            _InviteMemberButton(orgId: orgId),
          ],
        ],
      ],
    );
  }

  String _roleString(AppLocalizations l10n, LicenseOrgMemberRole role) {
    switch (role) {
      case LicenseOrgMemberRole.owner:
        return l10n.licenseOrgOverviewRoleOwner;
      case LicenseOrgMemberRole.admin:
        return l10n.licenseOrgOverviewRoleAdmin;
      case LicenseOrgMemberRole.member:
      case LicenseOrgMemberRole.unknown:
        return l10n.licenseOrgOverviewRoleMember;
    }
  }

  String _statusString(AppLocalizations l10n, LicenseOrgStatus status) {
    switch (status) {
      case LicenseOrgStatus.active:
        return l10n.licenseOrgOverviewStatusActive;
      case LicenseOrgStatus.suspended:
      case LicenseOrgStatus.unknown:
        return l10n.licenseOrgOverviewStatusSuspended;
    }
  }

  // Day-precision absolute date: YYYY-MM-DD. The Overview screen does
  // not show timestamps, so the membership join date renders without
  // a time component to match the read-only audit-style InfoTable.
  String _formatJoinedAt(DateTime joinedAt) {
    final local = joinedAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Colored pill rendered in the Status row's value cell.
///
/// Aligns right via the InfoTable's right-cell `alignment:
/// Alignment.topRight`. No Spacer hacks, no SectionTitle trailing -
/// the chip sits exactly where every other value sits, on the table's
/// right-edge grid.
class _StatusPill extends StatelessWidget {
  final LicenseOrgStatus status;
  final AppLocalizations l10n;

  const _StatusPill({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      LicenseOrgStatus.active => (
        AppTheme.successGreen,
        l10n.licenseOrgOverviewStatusActive,
      ),
      LicenseOrgStatus.suspended || LicenseOrgStatus.unknown => (
        AppTheme.errorRed,
        l10n.licenseOrgOverviewStatusSuspended,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Accent-colored pill rendered in the Role row's value cell.
class _RolePill extends StatelessWidget {
  final LicenseOrgMemberRole role;
  final AppLocalizations l10n;

  const _RolePill({required this.role, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (role) {
      LicenseOrgMemberRole.owner => (
        AppTheme.warningYellow,
        l10n.licenseOrgOverviewRoleOwner,
      ),
      LicenseOrgMemberRole.admin => (
        context.accentColor,
        l10n.licenseOrgOverviewRoleAdmin,
      ),
      LicenseOrgMemberRole.member || LicenseOrgMemberRole.unknown => (
        context.textSecondary,
        l10n.licenseOrgOverviewRoleMember,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Trailing action button under the per-org InfoTable that opens the
/// License Org Members sheet. Subtitle shows the live member count
/// so the user can see at a glance whether their team has grown
/// without opening the sheet. Hidden for suspended orgs by the
/// caller.
class _ViewMembersButton extends ConsumerWidget {
  final String orgId;

  const _ViewMembersButton({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(licenseOrgMemberCountProvider(orgId));
    final l10n = context.l10n;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => LicenseOrgMembersSheet.show(context, orgId),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          // Center cross-axis alignment is correct here: the title +
          // 1-line count subtitle is short enough that the icon
          // container (36x36) dominates the row height, so centering
          // makes the chevron sit at the visual midpoint - no
          // off-balance "floating at the top" feel like a long-text
          // tile would have. Multi-line tiles elsewhere still use
          // CrossAxisAlignment.start per the auto-memory rule
          // feedback_top_align_rows_with_multiline_text.md.
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.people_outline,
                  color: context.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.licenseOrgOverviewViewMembersAction,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      l10n.licenseOrgMembersCount(count),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owner / admin affordance to mint a single-use invite link via
/// `inviteLicenseOrgMember`. Opens an `AppBottomSheet.show` with a
/// short explainer; on confirm, calls the callable and renders the
/// returned URL with copy + share actions. Member role does not see
/// this button.
class _InviteMemberButton extends ConsumerWidget {
  final String orgId;

  const _InviteMemberButton({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showMintSheet(context, orgId),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.person_add_alt_1_outlined,
                  color: context.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  l10n.licenseOrgInviteMintAction,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showMintSheet(BuildContext context, String orgId) {
  return AppBottomSheet.show<void>(
    context: context,
    child: _InviteMintSheet(orgId: orgId),
  );
}

class _InviteMintSheet extends ConsumerStatefulWidget {
  final String orgId;

  const _InviteMintSheet({required this.orgId});

  @override
  ConsumerState<_InviteMintSheet> createState() => _InviteMintSheetState();
}

class _InviteMintSheetState extends ConsumerState<_InviteMintSheet>
    with LifecycleSafeMixin {
  bool _busy = false;
  String? _acceptUrl;
  String? _errorMessage;

  Future<void> _mint() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final service = LicenseOrgInviteService();
    final result = await service.mintInvite(
      licenseOrgId: widget.orgId,
      productId: RevenueCatConfig.themePackProductId,
    );
    if (!mounted) return;
    switch (result) {
      case MintInviteSuccess(:final acceptUrl):
        setState(() {
          _busy = false;
          _acceptUrl = acceptUrl;
        });
      case MintInviteFailure():
        setState(() {
          _busy = false;
          _errorMessage = context.l10n.licenseOrgInviteMintGenericError;
        });
    }
  }

  Future<void> _copy() async {
    final url = _acceptUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showSuccessSnackBar(context, context.l10n.licenseOrgInviteMintCopySuccess);
  }

  Future<void> _share() async {
    final url = _acceptUrl;
    if (url == null) return;
    await SharePlus.instance.share(ShareParams(text: url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        AppTheme.spacing8,
        AppTheme.spacing24,
        AppTheme.spacing24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.licenseOrgInviteMintSheetTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            l10n.licenseOrgInviteMintSheetBody,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          if (_acceptUrl == null) ...[
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppTheme.errorRed, fontSize: 13),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _mint,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link),
              label: Text(l10n.licenseOrgInviteMintSubmit),
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: context.border),
              ),
              child: SelectableText(
                _acceptUrl!,
                style: TextStyle(
                  fontSize: 13,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.licenseOrgInviteMintCopySuccess),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(
                        color: context.accentColor.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.licenseOrgInviteMintShareLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
