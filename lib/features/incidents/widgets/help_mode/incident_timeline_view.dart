// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Read-only activity timeline for an Incident Mode incident.
///
/// Renders the (non-superseded) event log in chronological order. Pure
/// presentation: it takes a list of [IncidentEvent] and never mutates state.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../models/incident_mode_models.dart';
import 'help_mode_labels.dart';

class IncidentTimelineView extends StatelessWidget {
  final List<IncidentEvent> events;

  const IncidentTimelineView({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final visible = events.where((e) => !e.isSuperseded).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Text(
          context.l10n.helpModeTimelineEmpty,
          style: context.hintStyle,
        ),
      );
    }

    final timeFmt = DateFormat.Hm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing4),
                  child: Icon(
                    Icons.circle,
                    size: AppTheme.spacing8,
                    color: context.accentColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incidentEventLabel(context, e),
                        style: context.bodySecondaryStyle,
                      ),
                      if (e.quickUpdate != null)
                        Text(
                          incidentQuickUpdateLabel(context, e.quickUpdate!),
                          style: context.captionMutedStyle,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  timeFmt.format(e.timestamp.toLocal()),
                  style: context.captionMutedStyle,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
