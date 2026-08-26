// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// One fleet radio, in full.
//
// Everything shown here is CONFIGURED metadata - what an admin recorded
// about the radio, plus a hardware/firmware snapshot taken when it was
// enrolled. Nothing on this screen is live. No battery, signal,
// last-seen or reachability, and no derived "healthy"/"stale" verdict:
// a record that looked like a status readout would be read as one, and
// SocialMesh has no observation pipeline behind it.
//
// The snapshot rows carry their own note saying when they were taken,
// because a firmware version with no age attached is exactly the kind of
// number an operator would act on.
//
// Retirement is soft. The record and its history survive, which is why
// the confirmation says where the radio goes rather than warning about
// data loss that does not happen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/license_org_fleet_device.dart';
import '../../../models/license_org_membership.dart';
import '../../../providers/license_org_members_providers.dart';
import '../../../services/license_org/license_org_fleet_service.dart';
import '../../../utils/snackbar.dart';
import '../../../utils/time_format.dart';
import '../../license_org/utils/member_label.dart';
import '../application/fleet_failure_message.dart';
import '../application/fleet_providers.dart';
import 'fleet_assign_sheet.dart';

class FleetDeviceDetailScreen extends ConsumerStatefulWidget {
  final String licenseOrgId;
  final String fleetDeviceId;

  const FleetDeviceDetailScreen({
    super.key,
    required this.licenseOrgId,
    required this.fleetDeviceId,
  });

  static Route<void> route(String licenseOrgId, String fleetDeviceId) {
    return MaterialPageRoute<void>(
      builder: (_) => FleetDeviceDetailScreen(
        licenseOrgId: licenseOrgId,
        fleetDeviceId: fleetDeviceId,
      ),
    );
  }

  @override
  ConsumerState<FleetDeviceDetailScreen> createState() =>
      _FleetDeviceDetailScreenState();
}

class _FleetDeviceDetailScreenState
    extends ConsumerState<FleetDeviceDetailScreen>
    with LifecycleSafeMixin<FleetDeviceDetailScreen> {
  bool _retiring = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Read straight from the fleet authority rather than holding the
    // row the list was built from, so a record changed elsewhere shows
    // its new state instead of a stale copy.
    final device = ref.watch(
      fleetDeviceByIdProvider((
        licenseOrgId: widget.licenseOrgId,
        fleetDeviceId: widget.fleetDeviceId,
      )),
    );

    if (device == null) {
      return GlassScaffold(
        title: l10n.fleetScreenTitle,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: Text(
                  l10n.fleetDetailMissing,
                  style: context.bodySecondaryStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final writeBlock = ref.watch(fleetWriteBlockProvider(widget.licenseOrgId));
    final isActive = device.status == FleetDeviceStatus.active;
    final canWrite = writeBlock == FleetWriteBlock.none && isActive;

    return GlassScaffold(
      title: device.label.isEmpty ? device.transportIdentity : device.label,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_alt_outlined),
          tooltip: l10n.fleetAssignTitle,
          onPressed: canWrite && !_retiring
              ? () => showFleetAssignSheet(
                  context,
                  licenseOrgId: widget.licenseOrgId,
                  device: device,
                )
              : null,
        ),
        if (canWrite)
          AppBarOverflowMenu<String>(
            onSelected: (_) => _confirmRetire(device),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'retire',
                enabled: !_retiring,
                child: Row(
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: AppTheme.spacing20,
                      color: SemanticColors.warning,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Text(l10n.fleetRetireAction),
                  ],
                ),
              ),
            ],
          ),
      ],
      slivers: [
        if (writeBlock != FleetWriteBlock.none && isActive)
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
                title: writeBlock == FleetWriteBlock.offline
                    ? l10n.fleetOfflineWriteBlocked
                    : l10n.fleetErrorPermissionDenied,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            AppTheme.spacing32,
          ),
          sliver: SliverList.list(
            children: [
              SectionTitle(title: l10n.fleetDetailSectionRecord),
              InfoTable(rows: _recordRows(context, device)),
              const SizedBox(height: AppTheme.spacing20),

              SectionTitle(title: l10n.fleetDetailSectionSnapshot),
              InfoTable(rows: _snapshotRows(context, device)),
              const SizedBox(height: AppTheme.spacing8),
              // Age matters more than the values: a firmware string with
              // no date attached invites an operator to treat it as
              // current.
              Text(l10n.fleetSnapshotNote, style: context.captionMutedStyle),

              if (device.transport == FleetTransport.meshCore) ...[
                const SizedBox(height: AppTheme.spacing16),
                StatusBanner(
                  type: StatusBannerType.info,
                  title: l10n.fleetMeshCoreResetNote,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Configured metadata, most actionable first.
  ///
  /// Status leads because it decides whether anything else on the screen
  /// can be acted on; identifiers and dates sink to the bottom where
  /// they are reference material rather than the answer to a question.
  List<InfoTableRow> _recordRows(
    BuildContext context,
    LicenseOrgFleetDevice device,
  ) {
    final l10n = context.l10n;
    final format = AppTimeFormat.fullDateAndTime(context);

    return [
      InfoTableRow(
        label: l10n.fleetLabelStatus,
        value: device.status == FleetDeviceStatus.retired
            ? l10n.fleetSectionRetired
            : l10n.fleetSectionInService,
        icon: device.status == FleetDeviceStatus.retired
            ? Icons.archive_outlined
            : Icons.check_circle_outline,
      ),
      InfoTableRow(
        label: l10n.fleetLabelAssignedTo,
        value: _assignmentValue(context, device),
        icon: Icons.person_outline,
      ),
      if (device.purpose != null)
        InfoTableRow(
          label: l10n.fleetLabelPurpose,
          value: device.purpose!,
          icon: Icons.flag_outlined,
        ),
      if (device.tags.isNotEmpty)
        InfoTableRow(
          label: l10n.fleetLabelTags,
          value: device.tags.join(', '),
          icon: Icons.sell_outlined,
        ),
      if (device.notes != null)
        InfoTableRow(
          label: l10n.fleetLabelNotes,
          value: device.notes!,
          icon: Icons.notes_outlined,
        ),
      InfoTableRow(
        label: l10n.fleetLabelTransport,
        value: switch (device.transport) {
          FleetTransport.meshtastic => l10n.scannerProtocolMeshtastic,
          FleetTransport.meshCore => l10n.scannerProtocolMeshCore,
          FleetTransport.unknown => l10n.scannerProtocolUnknown,
        },
        icon: Icons.settings_input_antenna,
      ),
      InfoTableRow(
        label: l10n.fleetLabelIdentity,
        value: device.transportIdentity,
        icon: Icons.fingerprint,
      ),
      InfoTableRow(
        label: l10n.fleetLabelAdded,
        value: format.format(device.createdAt.toLocal()),
        icon: Icons.event_outlined,
      ),
      InfoTableRow(
        label: l10n.fleetLabelUpdated,
        value: format.format(device.updatedAt.toLocal()),
        icon: Icons.update,
      ),
    ];
  }

  List<InfoTableRow> _snapshotRows(
    BuildContext context,
    LicenseOrgFleetDevice device,
  ) {
    final l10n = context.l10n;
    return [
      InfoTableRow(
        label: l10n.fleetLabelHardware,
        value: device.lastKnownHardware ?? l10n.scannerProtocolUnknown,
        icon: Icons.memory_outlined,
      ),
      InfoTableRow(
        label: l10n.fleetLabelFirmware,
        value: device.lastKnownFirmware ?? l10n.scannerProtocolUnknown,
        icon: Icons.system_update_alt,
      ),
    ];
  }

  /// Who the organisation says holds this radio.
  ///
  /// A member assignment whose person has left keeps the record and says
  /// so: "assigned to someone who has left" and "not assigned" call for
  /// different actions, and collapsing them loses that.
  String _assignmentValue(BuildContext context, LicenseOrgFleetDevice device) {
    final l10n = context.l10n;
    switch (device.assignment) {
      case FleetAssignmentKind.member:
        final uid = device.assignedUid;
        if (uid == null) return l10n.fleetAssignNobody;
        final isActiveMember = ref
            .watch(licenseOrgMembersProvider(widget.licenseOrgId))
            .maybeWhen(
              data: (list) => list.any(
                (m) =>
                    m.uid == uid && m.status == LicenseOrgMemberStatus.active,
              ),
              orElse: () => false,
            );
        final label = licenseOrgMemberLabel(uid);
        return isActiveMember
            ? label
            : '$label - ${l10n.fleetAssignInactiveMember}';
      case FleetAssignmentKind.orgPool:
        return l10n.fleetAssignOrgPool;
      case FleetAssignmentKind.unassigned:
      case FleetAssignmentKind.unknown:
        return l10n.fleetAssignNobody;
    }
  }

  Future<void> _confirmRetire(LicenseOrgFleetDevice device) async {
    final l10n = context.l10n;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.fleetRetireConfirmTitle,
      // Says where the radio goes rather than warning about data loss:
      // retirement is soft and the record stays reachable.
      message: l10n.fleetRetireConfirmBody,
      confirmLabel: l10n.fleetRetireAction,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!mounted || confirmed != true) return;

    setState(() => _retiring = true);
    final result = await ref
        .read(fleetMutationControllerProvider(widget.licenseOrgId).notifier)
        .retire(
          transport: device.transport,
          rawIdentity: device.transportIdentity.substring(3),
        );
    if (!mounted) return;
    setState(() => _retiring = false);

    switch (result) {
      case FleetMutationSuccess():
        // Stays on the screen: the record is still there, now under
        // Retired, and leaving would hide the state change that was
        // just made.
        showSuccessSnackBar(context, l10n.fleetRetiredSnack);
      case FleetMutationFailure(reason: final reason):
        showErrorSnackBar(context, fleetFailureMessage(l10n, reason));
    }
  }
}
