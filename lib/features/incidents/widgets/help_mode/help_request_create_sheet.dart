// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Help request creation sheet (fixture / preview).
///
/// Opens via [AppBottomSheet.showScrollable]. The submit button does NOT send
/// anything over the mesh in this PR -- it pops and invokes [onSubmit] only.
/// Wiring the outbound help send is PR-7.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/chip_selector.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../models/incident_mode_models.dart';
import 'help_location_disclosure_banner.dart';
import 'help_mode_labels.dart';

/// Shows the help request creation sheet. Returns when dismissed.
///
/// [onSubmit] is invoked with the optional initial status when the user taps
/// send. No mesh transport is performed.
Future<void> showHelpRequestCreateSheet(
  BuildContext context, {
  void Function(IncidentQuickUpdate? initialStatus)? onSubmit,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    title: context.l10n.helpModeCreateTitle,
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (controller) => _HelpRequestCreateBody(
      scrollController: controller,
      onSubmit: onSubmit,
    ),
  );
}

class _HelpRequestCreateBody extends StatefulWidget {
  final ScrollController scrollController;
  final void Function(IncidentQuickUpdate? initialStatus)? onSubmit;

  const _HelpRequestCreateBody({required this.scrollController, this.onSubmit});

  @override
  State<_HelpRequestCreateBody> createState() => _HelpRequestCreateBodyState();
}

class _HelpRequestCreateBodyState extends State<_HelpRequestCreateBody> {
  IncidentQuickUpdate? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      children: [
        Text(l10n.helpModeCreateIntro, style: context.bodyMutedStyle),
        const SizedBox(height: AppTheme.spacing16),
        Text(l10n.helpModeCreateStatusLabel, style: context.labelStyle),
        const SizedBox(height: AppTheme.spacing8),
        ChipSelector<IncidentQuickUpdate?>(
          value: _status,
          options: quickUpdateChipOptions(context, requesterQuickUpdates),
          onChanged: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: AppTheme.spacing16),
        const HelpLocationDisclosureBanner(),
        const SizedBox(height: AppTheme.spacing24),
        PrimaryGradientButton(
          label: l10n.helpModeSend,
          icon: Icons.emergency_share,
          onPressed: () {
            final navigator = Navigator.of(context);
            final status = _status;
            navigator.pop();
            widget.onSubmit?.call(status);
          },
        ),
      ],
    );
  }
}
