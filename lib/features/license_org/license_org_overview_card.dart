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
import '../../core/widgets/primary_gradient_button.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_banner.dart';
import '../../models/license_org_audit_event.dart';
import '../../providers/license_org_audit_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/license_org.dart';
import '../../models/license_org_membership.dart';
import '../../providers/license_org_members_providers.dart';
import '../../providers/license_org_overview_providers.dart';
import '../../providers/seat_allocation_providers.dart';
import '../../services/license_org/license_org_invite_service.dart';
import '../../services/license_org/license_org_settings_service.dart';
import '../../utils/snackbar.dart';
import 'license_org_audit_log_screen.dart';
import 'license_org_members_sheet.dart';

/// Session-scoped set of orgIds the auto-prompt has already fired for
/// in this app launch. An owner who dismisses the prompt with "Not
/// yet" is not nagged again until next launch — the edit-name icon
/// remains available for a manual rename. Stored as a module-level
/// Set rather than a Riverpod provider because: (a) this state is
/// purely UI-ephemeral, (b) it must survive widget tear-downs (the
/// card unmounts when the user navigates away then back), and (c)
/// reaching for a provider would tempt persistence and turn a UX
/// nudge into a permanent piece of user state.
final Set<String> _autoPromptedOrgIds = <String>{};

/// Test seam: clear the auto-prompt set between widget tests so each
/// scenario starts from a clean session. Not exposed publicly outside
/// the test library.
@visibleForTesting
void debugResetLicenseOrgAutoPromptSet() {
  _autoPromptedOrgIds.clear();
}

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
    final activeSeatCountAsync = ref.watch(
      licenseOrgActiveSeatCountProvider(orgId),
    );
    final activeSeatCount = activeSeatCountAsync.maybeWhen(
      data: (n) => n,
      orElse: () => 0,
    );
    final membershipAsync = ref.watch(
      currentUserLicenseOrgMembershipProvider(orgId),
    );

    final l10n = context.l10n;
    final org = orgAsync.maybeWhen(data: (o) => o, orElse: () => null);
    final membership = membershipAsync.maybeWhen(
      data: (m) => m,
      orElse: () => null,
    );

    // Display name: real stored name takes priority; falls back to a
    // neutral placeholder ("Unnamed community" in en, localised
    // per-locale) instead of the raw orgId slug. The slug is an
    // internal artifact - exposing it (e.g. "cleanrun-pack-ten") is
    // the load-bearing UX gap this slice closes. Owners see an edit
    // affordance in the title trailing slot; non-owners just see the
    // current name.
    final hasStoredName = org?.name.isNotEmpty ?? false;
    final displayName = hasStoredName
        ? org!.name
        : l10n.licenseOrgNameEmptyPlaceholder;
    final status = org?.status ?? LicenseOrgStatus.unknown;
    final isOwner = role == LicenseOrgMemberRole.owner;

    // Auto-prompt the name sheet the first time an owner lands on a
    // card for an org that has no name yet. Conditions to fire (all
    // must hold):
    //   - org doc has actually loaded (we know name is empty, not
    //     just "not yet loaded")
    //   - caller is the owner (admins / members don't see the
    //     affordance at all)
    //   - org isn't suspended (a paused org has bigger problems than
    //     a missing name; don't pile a sheet on top)
    //   - this orgId hasn't already triggered a prompt this session
    //     so a "Not yet" dismissal stays sticky until the next launch
    // Scheduled via postFrameCallback so the sheet animates on top
    // of the fully-laid-out screen rather than competing with the
    // overview's initial paint.
    final shouldAutoPromptName =
        org != null &&
        !hasStoredName &&
        isOwner &&
        status == LicenseOrgStatus.active &&
        !_autoPromptedOrgIds.contains(orgId);
    if (shouldAutoPromptName) {
      _autoPromptedOrgIds.add(orgId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _openNameSheet(context, ref, orgId: orgId, currentName: '');
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          // Community names are user-generated and can be up to 50
          // chars — well past the title's natural width on small
          // devices. Marquee instead of fading so the owner doesn't
          // lose the tail of their own name.
          title: displayName,
          marquee: true,
          trailing: isOwner
              ? IconButton(
                  tooltip: l10n.licenseOrgNameSheetEditButton,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: context.textSecondary,
                    size: 18,
                  ),
                  onPressed: () => _openNameSheet(
                    context,
                    ref,
                    orgId: orgId,
                    currentName: hasStoredName ? org!.name : '',
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                )
              : null,
        ),
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
            // Primary metric. For owners with a known capacity (the
            // typical case after a Community Pack purchase) show the
            // org's total seat budget WITH the live used-count
            // denominator: "Capacity: 2 of 10 seats used". Members
            // and orgs without a capacity field fall back to the
            // per-user "Your seats: <count>" row that was the
            // original semantic.
            if (role == LicenseOrgMemberRole.owner && org?.seatCapacity != null)
              InfoTableRow(
                label: l10n.licenseOrgOverviewCapacityLabel,
                value: l10n.licenseOrgOverviewCapacityValueUsed(
                  activeSeatCount,
                  org!.seatCapacity!,
                ),
                icon: Icons.event_seat_outlined,
              )
            else
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
          const SizedBox(height: AppTheme.spacing16),
          _RecentActivitySection(orgId: orgId),
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

/// Compact list of the 5 most recent audit events for the org.
///
/// Renders nothing (zero-height) when the underlying provider yields
/// an empty list (signed out, suspended org, no events, permission
/// denied). The Overview card never shows an empty placeholder for
/// recent activity - the absence of the section is the empty state.
///
/// Mirrors the web admin's Recent activity card on the per-org
/// detail page but with the bounded 5-row preview suited for the
/// mobile Overview card height.
class _RecentActivitySection extends ConsumerWidget {
  final String orgId;

  const _RecentActivitySection({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(licenseOrgRecentAuditProvider(orgId));
    final events = eventsAsync.maybeWhen(
      data: (e) => e,
      orElse: () => const <LicenseOrgAuditEvent>[],
    );
    if (events.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: l10n.licenseOrgOverviewRecentActivityTitle),
        const SizedBox(height: AppTheme.spacing8),
        Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < events.length; i++) ...[
                if (i > 0) Divider(color: context.border, height: 1),
                _AuditRow(event: events[i]),
              ],
              Divider(color: context.border, height: 1),
              InkWell(
                onTap: () => Navigator.of(
                  context,
                ).push(LicenseOrgAuditLogScreen.route(orgId)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radius12),
                  bottomRight: Radius.circular(AppTheme.radius12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.licenseOrgOverviewRecentActivityViewAll,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.accentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  final LicenseOrgAuditEvent event;

  const _AuditRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isRejected = event.outcome == LicenseOrgAuditOutcome.rejected;
    final outcomeColor = isRejected ? AppTheme.errorRed : AppTheme.successGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(event.action), size: 20, color: context.textSecondary),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(l10n, event.action),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Wrap(
                  spacing: AppTheme.spacing8,
                  runSpacing: AppTheme.spacing4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      event.actorDisplayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    Text(
                      _relativeTime(l10n, event.tsServer),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    if (isRejected && event.reasonCode != null) ...[
                      Text(
                        '·',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                      Text(
                        event.reasonCode!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.errorRed,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: outcomeColor.withValues(alpha: 0.45)),
            ),
            child: Text(
              isRejected
                  ? l10n.licenseOrgAuditOutcomeRejected
                  : l10n.licenseOrgAuditOutcomeSuccess,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: outcomeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(LicenseOrgAuditAction action) {
    switch (action) {
      case LicenseOrgAuditAction.memberInvited:
        return Icons.mail_outline;
      case LicenseOrgAuditAction.memberJoined:
        return Icons.person_add_alt_1_outlined;
      case LicenseOrgAuditAction.seatCodeMinted:
      case LicenseOrgAuditAction.seatReplacementMinted:
        return Icons.confirmation_number_outlined;
      case LicenseOrgAuditAction.seatCodeRedeemed:
      case LicenseOrgAuditAction.seatCodeReplayed:
        return Icons.event_seat_outlined;
      case LicenseOrgAuditAction.seatRevokedManual:
      case LicenseOrgAuditAction.orgSeatRevokedRefund:
        return Icons.remove_circle_outline;
      case LicenseOrgAuditAction.seatReinstated:
        return Icons.restore_outlined;
      case LicenseOrgAuditAction.orgPurchased:
        return Icons.shopping_bag_outlined;
      case LicenseOrgAuditAction.orgOwnerCollision:
        return Icons.warning_amber_outlined;
      case LicenseOrgAuditAction.orgSuspendedDrained:
        return Icons.block_outlined;
      case LicenseOrgAuditAction.licenseOrgRenamed:
        return Icons.edit_outlined;
      case LicenseOrgAuditAction.unknown:
        return Icons.history_outlined;
    }
  }

  static String _actionLabel(AppLocalizations l10n, LicenseOrgAuditAction a) {
    switch (a) {
      case LicenseOrgAuditAction.seatCodeMinted:
        return l10n.licenseOrgAuditActionSeatCodeMinted;
      case LicenseOrgAuditAction.seatCodeRedeemed:
        return l10n.licenseOrgAuditActionSeatCodeRedeemed;
      case LicenseOrgAuditAction.seatCodeReplayed:
        return l10n.licenseOrgAuditActionSeatCodeReplayed;
      case LicenseOrgAuditAction.seatRevokedManual:
        return l10n.licenseOrgAuditActionSeatRevokedManual;
      case LicenseOrgAuditAction.seatReplacementMinted:
        return l10n.licenseOrgAuditActionSeatReplacementMinted;
      case LicenseOrgAuditAction.seatReinstated:
        return l10n.licenseOrgAuditActionSeatReinstated;
      case LicenseOrgAuditAction.memberInvited:
        return l10n.licenseOrgAuditActionMemberInvited;
      case LicenseOrgAuditAction.memberJoined:
        return l10n.licenseOrgAuditActionMemberJoined;
      case LicenseOrgAuditAction.orgPurchased:
        return l10n.licenseOrgAuditActionOrgPurchased;
      case LicenseOrgAuditAction.orgOwnerCollision:
        return l10n.licenseOrgAuditActionOrgOwnerCollision;
      case LicenseOrgAuditAction.orgSeatRevokedRefund:
        return l10n.licenseOrgAuditActionOrgSeatRevokedRefund;
      case LicenseOrgAuditAction.orgSuspendedDrained:
        return l10n.licenseOrgAuditActionOrgSuspendedDrained;
      case LicenseOrgAuditAction.licenseOrgRenamed:
        return l10n.licenseOrgAuditActionLicenseOrgRenamed;
      case LicenseOrgAuditAction.unknown:
        return l10n.licenseOrgAuditActionUnknown;
    }
  }

  static String _relativeTime(AppLocalizations l10n, DateTime? tsServer) {
    if (tsServer == null) return l10n.licenseOrgAuditRelativeJustNow;
    final diff = DateTime.now().toUtc().difference(tsServer);
    if (diff.inSeconds < 60) return l10n.licenseOrgAuditRelativeJustNow;
    if (diff.inMinutes < 60) {
      return l10n.licenseOrgAuditRelativeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.licenseOrgAuditRelativeHours(diff.inHours);
    }
    if (diff.inDays < 30) {
      return l10n.licenseOrgAuditRelativeDays(diff.inDays);
    }
    final months = diff.inDays ~/ 30;
    if (months < 12) return l10n.licenseOrgAuditRelativeMonths(months);
    return l10n.licenseOrgAuditRelativeYears(months ~/ 12);
  }
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
      productId: RevenueCatConfig.completePackProductId,
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
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing8,
        AppTheme.spacing20,
        AppTheme.spacing20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.licenseOrgInviteMintSheetTitle,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.licenseOrgInviteMintSheetBody,
            style: textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          if (_acceptUrl == null) ...[
            if (_errorMessage != null) ...[
              StatusBanner.error(
                title: _errorMessage!,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],
            PrimaryGradientButton(
              label: l10n.licenseOrgInviteMintSubmit,
              icon: Icons.link,
              isLoading: _busy,
              onPressed: _busy ? null : _mint,
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: context.border),
              ),
              child: SelectableText(
                _acceptUrl!,
                style: textTheme.bodySmall?.copyWith(
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            PrimaryGradientButton(
              label: l10n.licenseOrgInviteMintShareLabel,
              icon: Icons.ios_share,
              onPressed: _share,
            ),
            const SizedBox(height: AppTheme.spacing8),
            TextButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy, size: AppTheme.spacing16),
              label: Text(l10n.licenseOrgInviteMintCopyAction),
              style: TextButton.styleFrom(
                foregroundColor: context.textSecondary,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Name your community
// =============================================================================

/// Owner-only sheet trigger. Opens an `AppBottomSheet` with the
/// inline `_NameOrgSheet` body. Submits via [LicenseOrgSettingsService]
/// and surfaces a success / no-change / error snackbar.
///
/// [orgId] is passed explicitly because [BuildContext.findAncestorWidgetOfExactType]
/// walks UP from the calling element and EXCLUDES the starting element
/// — so calling it with the card's own context would skip the card
/// and either grab a wrong ancestor (multiple cards in a list) or
/// return null. The earlier attempt to use the ancestor lookup
/// resolved to `''` and the backend rejected with `invalid-argument`,
/// which was a silent UX bug because the error snackbar shape
/// matched a valid-but-empty rename request.
Future<void> _openNameSheet(
  BuildContext context,
  WidgetRef ref, {
  required String orgId,
  required String currentName,
}) {
  return AppBottomSheet.show<void>(
    context: context,
    child: _NameOrgSheet(
      currentName: currentName,
      onSubmit: (name) async {
        final l10n = context.l10n;
        final service = LicenseOrgSettingsService();
        final result = await service.updateName(
          licenseOrgId: orgId,
          name: name,
        );
        if (!context.mounted) return;
        switch (result) {
          case UpdateLicenseOrgNameSuccess(:final noChange):
            Navigator.of(context).pop();
            if (noChange) {
              showInfoSnackBar(context, l10n.licenseOrgNameSaveNoChange);
            } else {
              showSuccessSnackBar(context, l10n.licenseOrgNameSaveSuccess);
            }
          case UpdateLicenseOrgNameFailure(:final reason):
            showErrorSnackBar(context, _nameErrorMessage(l10n, reason));
        }
      },
    ),
  );
}

String _nameErrorMessage(
  AppLocalizations l10n,
  UpdateLicenseOrgNameReason reason,
) {
  switch (reason) {
    case UpdateLicenseOrgNameReason.permissionDenied:
      return l10n.licenseOrgNameErrorPermission;
    case UpdateLicenseOrgNameReason.invalidArgument:
      // Surfaced via the field's own errorText too; the snackbar is
      // a belt-and-braces for the rare case where the field passes
      // a value the server still rejects (e.g. trim differences).
      return l10n.licenseOrgNameValidationEmpty;
    case UpdateLicenseOrgNameReason.notFound:
    case UpdateLicenseOrgNameReason.unauthenticated:
    case UpdateLicenseOrgNameReason.generic:
      return l10n.licenseOrgNameErrorGeneric;
  }
}

class _NameOrgSheet extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String name) onSubmit;

  const _NameOrgSheet({required this.currentName, required this.onSubmit});

  @override
  State<_NameOrgSheet> createState() => _NameOrgSheetState();
}

class _NameOrgSheetState extends State<_NameOrgSheet> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final l10n = context.l10n;
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorText = l10n.licenseOrgNameValidationEmpty);
      return;
    }
    if (raw.length > licenseOrgNameMaxLength) {
      setState(() => _errorText = l10n.licenseOrgNameValidationTooLong);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(raw);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacing16,
        right: AppTheme.spacing16,
        top: AppTheme.spacing16,
        // Lift above the keyboard so the input row stays visible.
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacing16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.licenseOrgNameSheetTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.licenseOrgNameSheetBody,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: licenseOrgNameMaxLength,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onSave(),
            decoration: InputDecoration(
              hintText: l10n.licenseOrgNameSheetHint,
              errorText: _errorText,
              errorMaxLines: 3,
              filled: true,
              fillColor: context.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.accentColor),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.licenseOrgNameSheetCancelButton),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.licenseOrgNameSheetSaveButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
