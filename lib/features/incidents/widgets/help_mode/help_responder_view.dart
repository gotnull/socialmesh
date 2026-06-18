// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Responder-side Help Mode view, driven by an [IncidentProjection].
///
/// Shows the requester's last known location with an age (or a placeholder),
/// responder quick-status chips, the activity timeline, a Messages action and
/// Leave response. Pure presentation: all actions are callbacks; no transport.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/chip_selector.dart';
import '../../../../core/widgets/info_table.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../models/incident_mode_models.dart';
import 'help_mode_labels.dart';
import 'incident_location_display.dart';
import 'incident_timeline_view.dart';

class HelpResponderView extends StatelessWidget {
  final IncidentProjection projection;
  final void Function(IncidentQuickUpdate code)? onUpdateStatus;
  final VoidCallback? onMessages;
  final VoidCallback? onLeave;

  /// Wall clock used to compute location age (injectable for tests).
  final DateTime? now;

  const HelpResponderView({
    super.key,
    required this.projection,
    this.onUpdateStatus,
    this.onMessages,
    this.onLeave,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loc = projection.lastRequesterLocation;
    final clock = now ?? DateTime.now();

    final IncidentQuickUpdate? myLast = projection.responders.isNotEmpty
        ? projection.responders.first.lastStatus
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusBanner.warning(
          title: l10n.helpModeRespondingTitle,
          subtitle: l10n.helpModeInboundBody,
          icon: Icons.volunteer_activism,
        ),
        const SizedBox(height: AppTheme.spacing20),
        SectionTitle(title: l10n.helpModeRequesterLocation),
        const SizedBox(height: AppTheme.spacing8),
        InfoTable(rows: _locationRows(context, loc, clock)),
        const SizedBox(height: AppTheme.spacing16),
        Text(l10n.helpModeUpdateResponse, style: context.labelStyle),
        const SizedBox(height: AppTheme.spacing8),
        ChipSelector<IncidentQuickUpdate?>(
          value: myLast,
          options: quickUpdateChipOptions(context, responderQuickUpdates),
          onChanged: (v) {
            if (v != null) onUpdateStatus?.call(v);
          },
        ),
        const SizedBox(height: AppTheme.spacing20),
        SectionTitle(title: l10n.helpModeActivityTitle),
        const SizedBox(height: AppTheme.spacing8),
        IncidentTimelineView(events: projection.timeline),
        const SizedBox(height: AppTheme.spacing20),
        OutlinedButton.icon(
          onPressed: onMessages,
          icon: const Icon(Icons.forum_outlined),
          label: Text(l10n.helpModeMessages),
        ),
        const SizedBox(height: AppTheme.spacing8),
        OutlinedButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.logout),
          label: Text(l10n.helpModeLeaveResponse),
        ),
      ],
    );
  }

  /// Location rows: a calm "not shared" state when absent, otherwise age +
  /// optional accuracy + a stale note. Never renders raw coordinates.
  List<InfoTableRow> _locationRows(
    BuildContext context,
    IncidentLocation? loc,
    DateTime clock,
  ) {
    final l10n = context.l10n;
    if (loc == null) {
      return [
        InfoTableRow(
          label: l10n.helpModeRequesterLocation,
          value: l10n.helpModeLocationPending,
          icon: Icons.location_off,
        ),
      ];
    }
    final accuracy = roundedAccuracyMeters(loc.accuracyMeters);
    final stale =
        classifyLocationFreshness(loc, now: clock) ==
        IncidentLocationFreshness.stale;
    return [
      InfoTableRow(
        label: l10n.helpModeRequesterLocation,
        value: l10n.helpModeLocationAge(
          formatIncidentAge(clock.difference(loc.fixedAt)),
        ),
        icon: Icons.my_location,
      ),
      if (accuracy != null)
        InfoTableRow(
          label: l10n.helpModeRequesterLocation,
          value: l10n.helpModeLocationAccuracy(accuracy),
          icon: Icons.adjust,
        ),
      if (stale)
        InfoTableRow(
          label: l10n.helpModeRequesterLocation,
          value: l10n.helpModeLocationStale,
          icon: Icons.history,
        ),
    ];
  }
}
