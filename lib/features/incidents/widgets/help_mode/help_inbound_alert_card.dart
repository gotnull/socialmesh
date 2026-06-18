// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inbound help alert card for a trusted peer's help request.
///
/// Primary actions are Acknowledge / Respond / Open map. "Dismiss" is a
/// deliberately low-emphasis secondary action -- it is never the primary way to
/// clear a safety alert. Pure presentation: all actions are callbacks.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/gradient_border_container.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class HelpInboundAlertCard extends StatelessWidget {
  final String requesterName;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onRespond;
  final VoidCallback? onOpenMap;
  final VoidCallback? onDismiss;

  const HelpInboundAlertCard({
    super.key,
    required this.requesterName,
    this.onAcknowledge,
    this.onRespond,
    this.onOpenMap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GradientBorderContainer(
      borderRadius: AppTheme.radius16,
      accentColor: AppTheme.warningYellow,
      accentOpacity: 0.6,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_share, color: AppTheme.warningYellow),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  l10n.helpModeInboundTitle(requesterName),
                  style: context.titleSmallStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(l10n.helpModeInboundBody, style: context.captionMutedStyle),
          const SizedBox(height: AppTheme.spacing16),
          // Primary action: respond.
          PrimaryGradientButton(
            label: l10n.helpModeRespond,
            icon: Icons.volunteer_activism,
            onPressed: onRespond,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAcknowledge,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.helpModeAcknowledge),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.helpModeOpenMap),
                ),
              ),
            ],
          ),
          // Low-emphasis secondary dismiss.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: Text(
                l10n.helpModeDismiss,
                style: context.captionMutedStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
