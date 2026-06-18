// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Persistent "Need help" affordance for the map stack.
///
/// Self-gating: renders nothing unless BOTH the unified incident layer master
/// flag and the help_request workflow subflag are enabled. When shown, it is a
/// map-control-styled pill positioned in the map stack; tapping it opens the
/// help request creation sheet. On submit it raises a real help request via
/// the outbound controller (persist-local-first, send only to eligible peers)
/// and opens the requester active screen. No notifications or location
/// escalation are wired.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/safety/lifecycle_mixin.dart';
import '../../../../core/theme.dart';
import '../../../../providers/incident_help_providers.dart';
import '../../../../utils/snackbar.dart';
import '../../models/incident_mode_models.dart';
import '../../screens/help_requester_active_screen.dart';
import 'help_request_create_sheet.dart';

class HelpRequestAffordance extends ConsumerStatefulWidget {
  /// Test-only override for the combined feature-flag gate.
  @visibleForTesting
  final bool? enabledOverride;

  const HelpRequestAffordance({super.key, this.enabledOverride});

  @override
  ConsumerState<HelpRequestAffordance> createState() =>
      _HelpRequestAffordanceState();
}

class _HelpRequestAffordanceState extends ConsumerState<HelpRequestAffordance>
    with LifecycleSafeMixin<HelpRequestAffordance> {
  bool get _enabled =>
      widget.enabledOverride ??
      (AppFeatureFlags.isMeshIncidentsEnabled &&
          AppFeatureFlags.isIncidentHelpRequestEnabled);

  Future<void> _onNeedHelp() async {
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context);

    IncidentQuickUpdate? initialStatus;
    var submitted = false;
    await showHelpRequestCreateSheet(
      context,
      onSubmit: (status) {
        submitted = true;
        initialStatus = status;
      },
    );
    if (!mounted || !submitted) return;

    final outcome = await ref
        .read(incidentHelpControllerProvider)
        .createHelpRequest(initialStatus: initialStatus);
    if (!mounted) return;

    if (outcome.idAllocationFailed) {
      showErrorSnackBar(context, context.l10n.helpModeCreateFailed);
      return;
    }
    if (!outcome.hadEligibleRecipients) {
      showWarningSnackBar(context, context.l10n.helpModeNoEligiblePeers);
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HelpRequesterActiveScreen(incidentId: outcome.incidentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();

    return Positioned(
      left: AppTheme.spacing16,
      bottom: AppTheme.spacing16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(
            color: AppTheme.warningYellow.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: AppTheme.spacing8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius20),
            onTap: _onNeedHelp,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emergency_share,
                    size: AppTheme.spacing20,
                    color: AppTheme.warningYellow,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    context.l10n.helpModeNeedHelp,
                    style: context.labelStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
