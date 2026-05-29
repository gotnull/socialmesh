// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Confirmation sheet shown after the owner picks "Revoke seat" from
// any per-member action menu in the License Org admin surfaces.
//
// Why shared: the Members sheet (`LicenseOrgMembersSheet`) and the
// Seat Usage section on the per-org card both surface the same
// destructive action with identical copy + warning shape. Promoting
// the sheet here keeps both callers in lockstep and means a future
// copy change (or adding a "reason" text field) lands once.
//
// Pops `true` on confirm, `false` on cancel. The caller wires the
// returned bool into its own state (await `AppBottomSheet.show<bool>`
// and branch on the result).

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';

class RevokeSeatConfirmSheet extends StatelessWidget {
  /// Opaque member label (e.g. `#9LTXJG`) interpolated into the title
  /// copy. Pass the output of `licenseOrgMemberLabel(uid)` from
  /// `lib/features/license_org/utils/member_label.dart`.
  final String memberLabel;

  const RevokeSeatConfirmSheet({super.key, required this.memberLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.licenseOrgMembersRevokeConfirmTitle(memberLabel),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            l10n.licenseOrgMembersRevokeConfirmBody,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.licenseOrgMembersRevokeCancelButton),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.licenseOrgMembersRevokeConfirmButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
