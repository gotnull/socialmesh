// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// One row in the Fleet list.
//
// Shows CONFIGURED metadata only: what the radio is called, how it is
// reached, and who the organisation says holds it. No battery, signal,
// last-seen or health - those are PR4, and a row that mixed them would
// make an inventory record look like a live status readout.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../models/license_org_fleet_device.dart';

class FleetDeviceTile extends StatelessWidget {
  final LicenseOrgFleetDevice device;

  /// Resolved display name for [LicenseOrgFleetDevice.assignedUid], or
  /// null when the org has no active member with that uid.
  ///
  /// Null does NOT mean unassigned - see the assignment line below.
  final String? assigneeName;

  /// True when the record points at someone who is no longer an active
  /// member. The assignment is preserved rather than silently reset, so
  /// the row must say so instead of implying nobody holds the radio.
  final bool assigneeInactive;

  final VoidCallback? onTap;

  const FleetDeviceTile({
    super.key,
    required this.device,
    required this.assigneeName,
    required this.assigneeInactive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      // Self-inset horizontally, exactly like SettingsTile. Every row
      // primitive in this feature owns its own horizontal inset so a
      // parent never has to add one - which is what stops a sibling
      // that IS self-inset from rendering 16pt narrower.
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent, // lint-allow: no-hardcoded-color
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            // Centred, matching MapEntityListItem - the app's canonical
            // multi-line list row - and SettingsTile. These lines are a
            // fixed metadata block, not wrapping copy, so top-aligning
            // pushes the leading glyph and the chevron up against the
            // first line and reads as misaligned.
            child: Row(
              children: [
                Icon(
                  Icons.router_outlined,
                  size: AppTheme.spacing24,
                  color: context.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.label.isEmpty
                            ? device.transportIdentity
                            : device.label,
                        style: context.bodyStyle,
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        device.transportIdentity,
                        style: context.captionMutedStyle,
                      ),
                      const SizedBox(height: AppTheme.spacing6),
                      Text(
                        _assignmentLine(context),
                        style: context.bodySmallStyle,
                      ),
                      if (assigneeInactive) ...[
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          l10n.fleetAssignInactiveMember,
                          style: context.captionStyle?.copyWith(
                            color: SemanticColors.warning,
                          ),
                        ),
                      ],
                      if (device.purpose != null || device.tags.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacing8),
                        Wrap(
                          spacing: AppTheme.spacing6,
                          runSpacing: AppTheme.spacing6,
                          children: [
                            if (device.purpose != null)
                              InfoChip(
                                icon: Icons.flag_outlined,
                                label: device.purpose!,
                              ),
                            for (final tag in device.tags)
                              InfoChip(icon: Icons.sell_outlined, label: tag),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppTheme.spacing8),
                  Icon(
                    Icons.chevron_right,
                    size: AppTheme.spacing20,
                    color: context.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Who the organisation says holds this radio.
  ///
  /// A member assignment whose person has left keeps their name where it
  /// is known, because "assigned to someone who has left" is a different
  /// operational fact from "not assigned" and the admin needs to act on
  /// it differently.
  String _assignmentLine(BuildContext context) {
    final l10n = context.l10n;
    switch (device.assignment) {
      case FleetAssignmentKind.member:
        final name = assigneeName;
        return name == null
            ? l10n.fleetLabelAssignedTo
            : '${l10n.fleetLabelAssignedTo}: $name';
      case FleetAssignmentKind.orgPool:
        return l10n.fleetAssignOrgPool;
      case FleetAssignmentKind.unassigned:
      case FleetAssignmentKind.unknown:
        return l10n.fleetAssignNobody;
    }
  }
}
