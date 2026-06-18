// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Requester-side Help Mode view, driven entirely by an [IncidentProjection].
///
/// Covers broadcasting, active (with/without responder, en route, arrived) and
/// the terminal states (resolved safe, cancelled, expired). "I'm safe" and
/// "Cancel request" are visually and semantically distinct. Pure presentation:
/// all actions are callbacks; no transport.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../../core/widgets/chip_selector.dart';
import '../../models/incident_mode_models.dart';
import 'help_location_disclosure_banner.dart';
import 'help_mode_labels.dart';
import 'incident_timeline_view.dart';

class HelpRequesterActiveView extends StatelessWidget {
  final IncidentProjection projection;
  final void Function(IncidentQuickUpdate code)? onUpdateStatus;
  final VoidCallback? onMessages;
  final VoidCallback? onImSafe;
  final VoidCallback? onCancel;

  const HelpRequesterActiveView({
    super.key,
    required this.projection,
    this.onUpdateStatus,
    this.onMessages,
    this.onImSafe,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = projection.helpState ?? IncidentLifecycleState.broadcasting;
    final terminal = state.isTerminal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, state),
        if (!terminal) ...[
          const SizedBox(height: AppTheme.spacing12),
          const HelpLocationDisclosureBanner(),
          const SizedBox(height: AppTheme.spacing16),
          Text(l10n.helpModeUpdateStatus, style: context.labelStyle),
          const SizedBox(height: AppTheme.spacing8),
          ChipSelector<IncidentQuickUpdate?>(
            value: projection.lastRequesterStatus,
            options: quickUpdateChipOptions(context, requesterQuickUpdates),
            onChanged: (v) {
              if (v != null) onUpdateStatus?.call(v);
            },
          ),
        ],
        const SizedBox(height: AppTheme.spacing20),
        SectionTitle(title: l10n.helpModeActivityTitle),
        const SizedBox(height: AppTheme.spacing8),
        IncidentTimelineView(events: projection.timeline),
        if (!terminal) ...[
          const SizedBox(height: AppTheme.spacing20),
          OutlinedButton.icon(
            onPressed: onMessages,
            icon: const Icon(Icons.forum_outlined),
            label: Text(l10n.helpModeMessages),
          ),
          const SizedBox(height: AppTheme.spacing12),
          // Resolve (safe): primary, success-coloured, distinct from cancel.
          PrimaryGradientButton(
            label: l10n.helpModeImSafe,
            icon: Icons.verified_user,
            accentColor: AppTheme.successGreen,
            onPressed: onImSafe,
          ),
          const SizedBox(height: AppTheme.spacing8),
          // Cancel (false alarm): low-emphasis, error-coloured, separate.
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: Icon(Icons.cancel_outlined, color: AppTheme.errorRed),
            label: Text(
              l10n.helpModeCancelRequest,
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, IncidentLifecycleState state) {
    final l10n = context.l10n;
    switch (state) {
      case IncidentLifecycleState.draft:
      case IncidentLifecycleState.broadcasting:
        return StatusBanner.info(
          title: l10n.helpModeBroadcastingTitle,
          subtitle: l10n.helpModeBroadcastingBody,
          icon: Icons.wifi_tethering,
          isLoading: true,
        );
      case IncidentLifecycleState.activeNoResponder:
      case IncidentLifecycleState.activeWithResponder:
      case IncidentLifecycleState.responderEnRoute:
      case IncidentLifecycleState.responderArrived:
        return StatusBanner.warning(
          title: l10n.helpModeActiveTitle,
          subtitle: projection.responderCount > 0
              ? l10n.helpModeResponderCount(projection.responderCount)
              : l10n.helpModeNoResponders,
          icon: Icons.emergency_share,
        );
      case IncidentLifecycleState.resolvedSafe:
        return StatusBanner.success(
          title: l10n.helpModeResolvedTitle,
          subtitle: l10n.helpModeResolvedBody,
          icon: Icons.check_circle_outline,
        );
      case IncidentLifecycleState.cancelled:
        return StatusBanner.info(
          title: l10n.helpModeCancelledTitle,
          subtitle: l10n.helpModeCancelledBody,
          icon: Icons.cancel_outlined,
        );
      case IncidentLifecycleState.expired:
        return StatusBanner.warning(
          title: l10n.helpModeExpiredTitle,
          subtitle: l10n.helpModeExpiredBody,
          icon: Icons.timer_off_outlined,
        );
    }
  }
}
