// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Who holds a fleet radio, and what for.
//
// Assignment and purpose are separate callables server-side, so this
// sheet issues at most two writes. It sends only the halves that
// actually changed, which keeps the common case to one call, and when
// both change it reports the outcome of each rather than collapsing a
// partial save into "something went wrong".
//
// Three rules the surface exists to keep honest:
//
//   1. `member` requires a currently-active member. The server rejects
//      anything else, so an assignment pointing at someone who has left
//      is shown as a problem to fix, never re-offered as a valid choice.
//   2. The record is never silently reset. A departed assignee stays on
//      the record until an admin decides what should replace them.
//   3. The device is re-read from the authority while the sheet is
//      open, so a radio retired by another admin stops offering a save
//      that the server would refuse.
//
// lint-allow: haptic-feedback - the only GestureDetector here dismisses
// the keyboard on an incidental background tap. Buzzing for that would
// fire on taps the admin did not aim at anything. The real interactive
// elements (ChipSelector, PrimaryGradientButton) carry their own.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/license_org_fleet_device.dart';
import '../../../models/license_org_membership.dart';
import '../../../providers/license_org_members_providers.dart';
import '../../../services/license_org/license_org_fleet_service.dart';
import '../../../utils/snackbar.dart';
import '../../license_org/utils/member_label.dart';
import '../application/fleet_failure_message.dart';
import '../application/fleet_providers.dart';

/// Server bound for `purpose`. Mirrored here so the field cannot submit
/// something the callable will reject.
const int kFleetPurposeMaxLength = 64;

/// Opens the assignment sheet for [device].
Future<void> showFleetAssignSheet(
  BuildContext context, {
  required String licenseOrgId,
  required LicenseOrgFleetDevice device,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.75,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) => _FleetAssignSheet(
      licenseOrgId: licenseOrgId,
      device: device,
      scrollController: controller,
    ),
  );
}

class _FleetAssignSheet extends ConsumerStatefulWidget {
  final String licenseOrgId;
  final LicenseOrgFleetDevice device;
  final ScrollController scrollController;

  const _FleetAssignSheet({
    required this.licenseOrgId,
    required this.device,
    required this.scrollController,
  });

  @override
  ConsumerState<_FleetAssignSheet> createState() => _FleetAssignSheetState();
}

class _FleetAssignSheetState extends ConsumerState<_FleetAssignSheet>
    with LifecycleSafeMixin<_FleetAssignSheet> {
  late FleetAssignmentKind _kind;
  late String? _uid;
  late final TextEditingController _purpose;
  bool _submitting = false;

  /// Last refusal, shown INSIDE the sheet.
  ///
  /// A snackbar cannot be used for a failure that keeps this sheet open:
  /// the sheet covers most of the screen, so a root ScaffoldMessenger
  /// renders its bar behind the modal route and the admin is told
  /// nothing. Only the success path may use a snackbar, and only because
  /// it pops the sheet first.
  String? _error;

  @override
  void initState() {
    super.initState();
    // Seeded once. Re-seeding from the live authority would overwrite
    // whatever the admin is part-way through typing.
    final device = widget.device;
    _kind = device.assignment == FleetAssignmentKind.unknown
        ? FleetAssignmentKind.unassigned
        : device.assignment;
    _uid = device.assignedUid;
    _purpose = TextEditingController(text: device.purpose ?? '');
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // The live record, not the one the sheet opened with. A radio
    // retired by another admin in the meantime must stop offering a
    // save the server would refuse.
    final live = ref.watch(
      fleetDeviceByIdProvider((
        licenseOrgId: widget.licenseOrgId,
        fleetDeviceId: widget.device.id,
      )),
    );
    final retiredElsewhere = live?.status == FleetDeviceStatus.retired;

    final members = ref
        .watch(licenseOrgMembersProvider(widget.licenseOrgId))
        .maybeWhen(
          data: (list) => list
              .where((m) => m.status == LicenseOrgMemberStatus.active)
              .toList(growable: false),
          orElse: () => const <LicenseOrgMembership>[],
        );

    // An assignment naming someone who is no longer active cannot be
    // re-saved: the callable re-reads the roster and refuses. It is
    // surfaced as something to resolve rather than quietly cleared.
    final assigneeDeparted =
        widget.device.assignment == FleetAssignmentKind.member &&
        widget.device.assignedUid != null &&
        !members.any((m) => m.uid == widget.device.assignedUid);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        // Lifts the pinned action clear of the keyboard while the
        // purpose field has focus.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing8,
                AppTheme.spacing16,
                AppTheme.spacing12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.fleetAssignTitle, style: context.titleStyle),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    widget.device.label.isEmpty
                        ? widget.device.transportIdentity
                        : widget.device.label,
                    style: context.bodySecondaryStyle,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        AppTheme.spacing12,
                        AppTheme.spacing16,
                        0,
                      ),
                      child: StatusBanner(
                        type: StatusBannerType.error,
                        title: _error!,
                      ),
                    ),
                  if (retiredElsewhere)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        AppTheme.spacing12,
                        AppTheme.spacing16,
                        0,
                      ),
                      child: StatusBanner(
                        type: StatusBannerType.warning,
                        title: l10n.fleetErrorDeviceRetired,
                      ),
                    ),
                  if (assigneeDeparted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        AppTheme.spacing12,
                        AppTheme.spacing16,
                        0,
                      ),
                      child: StatusBanner(
                        type: StatusBannerType.warning,
                        title: l10n.fleetAssignInactiveMember,
                      ),
                    ),

                  SettingsSectionHeader(title: l10n.fleetLabelAssignedTo),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: ChipSelector<FleetAssignmentKind>(
                      value: _kind,
                      enabled: !_submitting && !retiredElsewhere,
                      options: [
                        ChipOption<FleetAssignmentKind>(
                          value: FleetAssignmentKind.member,
                          label: l10n.fleetAssignMember,
                          icon: Icons.person_outline,
                          color: context.accentColor,
                        ),
                        ChipOption<FleetAssignmentKind>(
                          value: FleetAssignmentKind.orgPool,
                          label: l10n.fleetAssignOrgPool,
                          icon: Icons.inventory_2_outlined,
                          color: context.accentColor,
                        ),
                        ChipOption<FleetAssignmentKind>(
                          value: FleetAssignmentKind.unassigned,
                          label: l10n.fleetAssignUnassigned,
                          icon: Icons.remove_circle_outline,
                          color: context.accentColor,
                        ),
                      ],
                      onChanged: (kind) => setState(() {
                        _kind = kind;
                        // orgPool and unassigned are both null-uid
                        // server-side; carrying a stale uid across the
                        // switch would submit a contradictory record.
                        if (kind != FleetAssignmentKind.member) _uid = null;
                      }),
                    ),
                  ),

                  if (_kind == FleetAssignmentKind.member) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    if (members.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spacing16,
                          AppTheme.spacing8,
                          AppTheme.spacing16,
                          0,
                        ),
                        child: Text(
                          l10n.fleetAssignNoMembers,
                          style: context.bodySecondaryStyle,
                        ),
                      )
                    else
                      _MemberPicker(
                        members: members,
                        selectedUid: _uid,
                        enabled: !_submitting && !retiredElsewhere,
                        onSelected: (uid) => setState(() => _uid = uid),
                      ),
                  ],

                  const SizedBox(height: AppTheme.spacing8),
                  SettingsSectionHeader(title: l10n.fleetLabelPurpose),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: TextField(
                      controller: _purpose,
                      enabled: !_submitting && !retiredElsewhere,
                      maxLength: kFleetPurposeMaxLength,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      style: context.bodyStyle,
                      decoration: InputDecoration(
                        // Marquee, never truncate. The hint is
                        // instructional copy and it does not fit on one
                        // line in every locale, so it scrolls rather
                        // than ending in an ellipsis that hides half
                        // the examples.
                        hint: AutoScrollText(
                          l10n.fleetPurposeHint,
                          style: context.bodyStyle?.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                        filled: true,
                        fillColor: context.background,
                        // Explicit and SYMMETRIC. Flutter's default
                        // contentPadding for an outlined field with a
                        // prefixIcon is asymmetric, which leaves the
                        // entered text sitting off-centre in the box.
                        isDense: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing12,
                          vertical: AppTheme.spacing16,
                        ),
                        prefixIcon: Icon(
                          Icons.flag_outlined,
                          color: context.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                          borderSide: BorderSide(color: context.accentColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing8,
                AppTheme.spacing16,
                AppTheme.spacing16,
              ),
              child: PrimaryGradientButton(
                label: l10n.commonSave,
                isLoading: _submitting,
                enabled: !retiredElsewhere && _canSave,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _trimmedPurpose {
    final text = _purpose.text.trim();
    return text.isEmpty ? null : text;
  }

  bool get _assignmentChanged =>
      _kind != widget.device.assignment || _uid != widget.device.assignedUid;

  bool get _purposeChanged => _trimmedPurpose != widget.device.purpose;

  /// Save is offered only for a submittable, actually-different record.
  ///
  /// The consistency half mirrors the server invariant: `member` needs a
  /// uid, the other two must not carry one.
  bool get _canSave {
    if (_submitting) return false;
    if (!_assignmentChanged && !_purposeChanged) return false;
    if (_kind == FleetAssignmentKind.member) return _uid != null;
    return _uid == null;
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final l10n = context.l10n;
    final controller = ref.read(
      fleetMutationControllerProvider(widget.licenseOrgId).notifier,
    );
    final transport = widget.device.transport;
    final rawIdentity = widget.device.transportIdentity.substring(3);
    final assignmentChanged = _assignmentChanged;
    final purposeChanged = _purposeChanged;

    setState(() {
      _submitting = true;
      // Cleared per attempt so a stale refusal never sits above a
      // request that is currently in flight.
      _error = null;
    });

    if (assignmentChanged) {
      final result = await controller.assign(
        transport: transport,
        rawIdentity: rawIdentity,
        assignment: _kind,
        assignedUid: _uid,
      );
      if (!mounted) return;
      if (result case FleetMutationFailure(reason: final reason)) {
        setState(() {
          _submitting = false;
          _error = fleetFailureMessage(l10n, reason);
        });
        return;
      }
    }

    if (purposeChanged) {
      final result = await controller.updateMetadata(
        transport: transport,
        rawIdentity: rawIdentity,
        purpose: _trimmedPurpose,
      );
      if (!mounted) return;
      if (result case FleetMutationFailure(reason: final reason)) {
        // Naming which half landed: the assignment write already
        // succeeded and reporting a flat failure would send the admin
        // back to redo work that is done.
        setState(() {
          _submitting = false;
          _error = assignmentChanged
              ? l10n.fleetAssignPartialSave
              : fleetFailureMessage(l10n, reason);
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    safeNavigatorPop();
    showSuccessSnackBar(
      context,
      assignmentChanged ? l10n.fleetAssignedSnack : l10n.fleetUpdatedSnack,
    );
  }
}

/// Active members, one selectable row each.
///
/// Labels are the opaque roster form - the org roster deliberately
/// exposes no display names or email addresses, and this surface is not
/// the place to start.
class _MemberPicker extends StatelessWidget {
  final List<LicenseOrgMembership> members;
  final String? selectedUid;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const _MemberPicker({
    required this.members,
    required this.selectedUid,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Column(
          children: [
            for (var i = 0; i < members.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.border),
              InkWell(
                onTap: enabled ? () => onSelected(members[i].uid) : null,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        members[i].uid == selectedUid
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: AppTheme.spacing20,
                        color: members[i].uid == selectedUid
                            ? context.accentColor
                            : context.textTertiary,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Text(
                          licenseOrgMemberLabel(members[i].uid),
                          style: context.bodyStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
