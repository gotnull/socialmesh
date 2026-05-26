// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Per-org card used by [LicenseOrgOverviewScreen]. Renders one
// SectionTitle (with role badge as trailing) over a canonical
// InfoTable with the org id, role, seat count, status, and joined
// date. Read-only by design - actions hang off the parent screen so
// the card stays composition-free.
//
// Spec: docs/engineering/LICENSE_ORG_OVERVIEW_SCREEN.md section 2
// "Per-org card structure". All UI primitives are canonical (no
// hand-rolled Row / Container / Stack arrangements).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import '../../models/license_org.dart';
import '../../models/license_org_membership.dart';
import '../../providers/license_org_overview_providers.dart';

/// Reads the per-org providers for [orgId] and renders the canonical
/// SectionTitle + InfoTable card.
///
/// All four data sources fail closed:
///   - org doc -> shows the slug as a placeholder name and an unknown
///     status badge if the doc is missing
///   - membership doc -> falls back to LicenseOrgMemberRole.unknown
///     (rendered as "Member" for accessibility)
///   - seat count -> 0 when no seats or while loading
///
/// The card itself never throws into the build phase.
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
        SectionTitle(
          title: displayName,
          trailing: _RoleBadge(role: role),
        ),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.licenseOrgOverviewOrgIdLabel,
              value: orgId,
              icon: Icons.fingerprint,
            ),
            InfoTableRow(
              label: l10n.licenseOrgOverviewRoleLabel,
              value: _roleString(l10n, role),
              icon: Icons.shield_outlined,
            ),
            InfoTableRow(
              label: l10n.licenseOrgOverviewSeatsLabel,
              value: seatCount.toString(),
              icon: Icons.event_seat_outlined,
            ),
            InfoTableRow(
              label: l10n.licenseOrgOverviewStatusLabel,
              value: _statusString(l10n, status),
              icon: Icons.circle,
              iconColor: _statusColor(context, status),
            ),
            if (membership?.joinedAt != null)
              InfoTableRow(
                label: l10n.licenseOrgOverviewJoinedLabel,
                value: _formatJoinedAt(membership!.joinedAt!),
                icon: Icons.event_available_outlined,
              ),
          ],
        ),
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

  Color _statusColor(BuildContext context, LicenseOrgStatus status) {
    switch (status) {
      case LicenseOrgStatus.active:
        return AppTheme.successGreen;
      case LicenseOrgStatus.suspended:
      case LicenseOrgStatus.unknown:
        return AppTheme.errorRed;
    }
  }

  // Day-precision absolute date: YYYY-MM-DD. The Overview screen does
  // not show timestamps, so the membership join date renders without a
  // time component to match the read-only audit-style InfoTable.
  String _formatJoinedAt(DateTime joinedAt) {
    final local = joinedAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _RoleBadge extends StatelessWidget {
  final LicenseOrgMemberRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = _accent(context);
    final label = _label(l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 1,
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n) {
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

  Color _accent(BuildContext context) {
    switch (role) {
      case LicenseOrgMemberRole.owner:
        return AppTheme.warningYellow;
      case LicenseOrgMemberRole.admin:
        return context.accentColor;
      case LicenseOrgMemberRole.member:
      case LicenseOrgMemberRole.unknown:
        return context.textTertiary;
    }
  }
}
