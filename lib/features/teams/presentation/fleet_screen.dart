// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// A Team's Fleet inventory.
//
// The ONLY lifecycle split shown is in-service vs retired. No health,
// staleness-per-device, signal or firmware-readiness semantics - those
// are PR4, and mixing them in would turn an inventory record into
// something that looks like a live status readout.
//
// Two states are kept deliberately separate:
//
//   READ visibility  - cached rows may be shown, with their age
//   WRITE capability - may be blocked while those rows are perfectly
//                      readable
//
// A stale banner therefore says nothing about whether the admin can
// change anything, and the disabled Add action says nothing about
// whether the list is trustworthy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/license_org_fleet_device.dart';
import '../../../models/license_org_membership.dart';
import '../../../providers/license_org_fleet_providers.dart';
import '../../../providers/license_org_members_providers.dart';
import '../../license_org/utils/member_label.dart';
import '../application/fleet_providers.dart';
import '../widgets/fleet_device_tile.dart';
import 'fleet_device_detail_screen.dart';
import 'fleet_enrol_sheet.dart';

class FleetScreen extends ConsumerWidget {
  final String licenseOrgId;

  const FleetScreen({super.key, required this.licenseOrgId});

  static Route<void> route(String licenseOrgId) => MaterialPageRoute<void>(
    builder: (_) => FleetScreen(licenseOrgId: licenseOrgId),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final active = ref.watch(activeFleetProvider(licenseOrgId));
    final retired = ref.watch(retiredFleetProvider(licenseOrgId));
    final writeBlock = ref.watch(fleetWriteBlockProvider(licenseOrgId));
    final snapshot = ref
        .watch(licenseOrgFleetProvider(licenseOrgId))
        .maybeWhen(data: (s) => s, orElse: () => null);

    // Resolved once for the whole list rather than per row, so a roster
    // of 25 does not re-scan members 25 times.
    final membersByUid = <String, LicenseOrgMembership>{
      for (final m
          in ref
              .watch(licenseOrgMembersProvider(licenseOrgId))
              .maybeWhen(data: (list) => list, orElse: () => const []))
        m.uid: m,
    };

    return GlassScaffold(
      title: l10n.fleetScreenTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: writeBlock == FleetWriteBlock.none
              ? l10n.fleetAddAction
              : _blockReason(context, writeBlock),
          // Disabled BEFORE interaction rather than failing on tap. The
          // server stays authoritative; this only avoids offering an
          // action already known to be refused.
          onPressed: writeBlock == FleetWriteBlock.none
              ? () => _openEnrol(context)
              : null,
        ),
      ],
      slivers: [
        if (writeBlock != FleetWriteBlock.none)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing12,
                AppTheme.spacing16,
                0,
              ),
              child: StatusBanner(
                type: StatusBannerType.info,
                title: _blockReason(context, writeBlock),
              ),
            ),
          ),

        // One banner for the whole list, never a "stale" mark per row.
        if (snapshot != null && snapshot.isStale && snapshot.syncedAt != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing12,
                AppTheme.spacing16,
                0,
              ),
              child: StatusBanner(
                type: StatusBannerType.warning,
                title: l10n.fleetLastSynced(
                  _relativeAge(context, snapshot.syncedAt!),
                ),
              ),
            ),
          ),

        // A failed read must NEVER render as "no radios yet". Only a
        // resolved, genuinely empty fleet may make that claim - the same
        // rule TeamsUnavailable vs TeamsEmpty enforces one screen up.
        if (active.isEmpty &&
            retired.isEmpty &&
            (snapshot?.loadFailed ?? false))
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: AppTheme.spacing40,
                      color: context.textTertiary,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      l10n.fleetLoadFailedTitle,
                      style: context.titleStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      l10n.fleetLoadFailedBody,
                      style: context.bodySecondaryStyle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (active.isEmpty && retired.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AnimatedEmptyState(
              config: AnimatedEmptyStateConfig(
                icons: const [
                  Icons.router_outlined,
                  Icons.inventory_2_outlined,
                  Icons.badge_outlined,
                ],
                taglines: [l10n.fleetEmptyTagline],
                titlePrefix: l10n.fleetEmptyTitlePrefix,
                titleKeyword: l10n.fleetEmptyTitleKeyword,
                titleSuffix: l10n.fleetEmptyTitleSuffix,
              ),
            ),
          )
        else
          // VERTICAL INSET ONLY. FleetDeviceTile carries its own
          // horizontal inset of spacing16; adding one here would double
          // it and step the rows in from their siblings. SectionTitle
          // has none, so it is wrapped individually below.
          SliverPadding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacing8,
              bottom: AppTheme.spacing32,
            ),
            sliver: SliverList.list(
              children: [
                if (active.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: SectionTitle(title: l10n.fleetSectionInService),
                  ),
                  ...active.map((d) => _tile(context, d, membersByUid)),
                ],
                if (retired.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: SectionTitle(title: l10n.fleetSectionRetired),
                  ),
                  ...retired.map((d) => _tile(context, d, membersByUid)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    LicenseOrgFleetDevice device,
    Map<String, LicenseOrgMembership> membersByUid,
  ) {
    final uid = device.assignedUid;
    final member = uid == null ? null : membersByUid[uid];
    return FleetDeviceTile(
      device: device,
      assigneeName: member == null ? null : licenseOrgMemberLabel(member.uid),
      // A member assignment whose person is absent from the ACTIVE
      // roster has been revoked since. The record is preserved rather
      // than reset, so the row says so instead of reading "unassigned".
      assigneeInactive:
          device.assignment == FleetAssignmentKind.member && member == null,
      // Retired rows open too: the detail screen is where a retired
      // record stays readable rather than becoming a dead end.
      onTap: () => Navigator.push(
        context,
        FleetDeviceDetailScreen.route(licenseOrgId, device.id),
      ),
    );
  }

  static String _blockReason(BuildContext context, FleetWriteBlock block) {
    final l10n = context.l10n;
    return switch (block) {
      FleetWriteBlock.offline => l10n.fleetOfflineWriteBlocked,
      FleetWriteBlock.notAdmin => l10n.fleetErrorPermissionDenied,
      FleetWriteBlock.none => l10n.fleetAddAction,
    };
  }

  static String _relativeAge(BuildContext context, DateTime syncedAt) {
    final diff = DateTime.now().toUtc().difference(syncedAt);
    final l10n = context.l10n;
    if (diff.inMinutes < 60) return l10n.fleetSyncedMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.fleetSyncedHours(diff.inHours);
    return l10n.fleetSyncedDays(diff.inDays);
  }

  void _openEnrol(BuildContext context) {
    showFleetEnrolSheet(context, licenseOrgId: licenseOrgId);
  }
}
