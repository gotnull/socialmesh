// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../services/protocol/sip/spp_types.dart';
import '../../../utils/time_format.dart';
import '../models/incident.dart';
import '../models/mesh_incident_report.dart';

/// Card widget displaying a mesh incident case summary.
///
/// Uses [GradientBorderContainer] with status-coloured accent border
/// and [BouncyTap] press animation, matching NodeDex / Aether / Signals
/// card styling.
class MeshIncidentCard extends StatelessWidget {
  final MeshIncidentCaseState caseState;
  final VoidCallback onTap;

  const MeshIncidentCard({
    super.key,
    required this.caseState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final report = caseState.latestReport;
    final dateFormat = AppTimeFormat.numericDateAndTime(context);
    final statusColor = _statusColor(caseState.effectiveStatus);
    final isActive = caseState.effectiveStatus == IncidentMeshStatus.active;

    return BouncyTap(
      onTap: onTap,
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius16,
        borderWidth: isActive ? 1.5 : 1.0,
        accentColor: statusColor,
        accentOpacity: isActive ? 0.6 : 0.3,
        enableDepthBlend: isActive,
        depthBlendOpacity: 0.08,
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + priority + case ID
            Row(
              children: [
                _StatusBadge(status: caseState.effectiveStatus),
                const SizedBox(width: AppTheme.spacing8),
                _PriorityBadge(priority: caseState.effectivePriority),
                const Spacer(),
                Text(
                  context.l10n.meshIncidentCaseId(
                    caseState.caseId.toRadixString(16).toUpperCase(),
                  ),
                  style: context.captionMutedStyle,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),

            // Classification badge
            _ClassificationBadge(
              classification: caseState.effectiveClassification,
            ),
            const SizedBox(height: AppTheme.spacing8),

            // Body preview
            Text(
              report.body,
              style: context.bodySecondaryStyle?.copyWith(height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacing12),

            // Footer metadata
            Wrap(
              spacing: AppTheme.spacing12,
              runSpacing: AppTheme.spacing4,
              children: [
                _MetadataChip(
                  icon: Icons.access_time,
                  text: dateFormat.format(report.timestamp.toLocal()),
                  context: context,
                ),
                _MetadataChip(
                  icon: Icons.layers,
                  text: context.l10n.meshIncidentReportCount(
                    caseState.reportCount,
                  ),
                  context: context,
                ),
                if (caseState.contributorNodes.length > 1)
                  _MetadataChip(
                    icon: Icons.people_outline,
                    text: context.l10n.meshIncidentContributors(
                      caseState.contributorNodes.length,
                    ),
                    context: context,
                  ),
                if (caseState.hasCorrections)
                  _MetadataChip(
                    icon: Icons.edit_note,
                    text: context.l10n.meshIncidentCorrectionBadge,
                    context: context,
                    color: AccentColors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge widgets — matching NodeDex / Aether badge pattern:
// color.withValues(alpha: 0.10-0.15) fill, 0.25-0.3 border, 0.5 border width
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final IncidentMeshStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        _statusLabel(context, status),
        style: context.captionStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final IncidentPriority priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        priority.displayLabel(context.l10n),
        style: context.captionStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClassificationBadge extends StatelessWidget {
  final IncidentClassification classification;
  const _ClassificationBadge({required this.classification});

  @override
  Widget build(BuildContext context) {
    final color = _classificationColor(classification);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _classificationIcon(classification),
            size: AppTheme.spacing12,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            classification.displayLabel(context.l10n),
            style: context.captionStyle?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final BuildContext context;
  final Color? color;

  const _MetadataChip({
    required this.icon,
    required this.text,
    required this.context,
    this.color,
  });

  @override
  Widget build(BuildContext _) {
    final c = color ?? context.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppTheme.spacing12, color: c),
        const SizedBox(width: AppTheme.spacing3),
        Text(text, style: context.captionMutedStyle?.copyWith(color: c)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Color / label helpers
// ---------------------------------------------------------------------------

Color _statusColor(IncidentMeshStatus status) => switch (status) {
  IncidentMeshStatus.reported => SemanticColors.info,
  IncidentMeshStatus.active => AccentColors.orange,
  IncidentMeshStatus.contained => AccentColors.teal,
  IncidentMeshStatus.resolved => SemanticColors.success,
  IncidentMeshStatus.cancelled => SemanticColors.disabled,
};

String _statusLabel(BuildContext context, IncidentMeshStatus status) =>
    switch (status) {
      IncidentMeshStatus.reported => context.l10n.meshIncidentStatusReported,
      IncidentMeshStatus.active => context.l10n.meshIncidentStatusActive,
      IncidentMeshStatus.contained => context.l10n.meshIncidentStatusContained,
      IncidentMeshStatus.resolved => context.l10n.meshIncidentStatusResolved,
      IncidentMeshStatus.cancelled => context.l10n.meshIncidentStatusCancelled,
    };

Color _priorityColor(IncidentPriority priority) => switch (priority) {
  IncidentPriority.routine => SemanticColors.disabled,
  IncidentPriority.priority => SemanticColors.info,
  IncidentPriority.immediate => AccentColors.orange,
  IncidentPriority.flash => SemanticColors.error,
};

Color _classificationColor(IncidentClassification c) => switch (c) {
  IncidentClassification.safety => AccentColors.red,
  IncidentClassification.security => AccentColors.orange,
  IncidentClassification.environmental => AccentColors.emerald,
  IncidentClassification.operational => AccentColors.blue,
  IncidentClassification.logistics => AccentColors.purple,
  IncidentClassification.medical => AccentColors.pink,
  IncidentClassification.comms => AccentColors.cyan,
};

IconData _classificationIcon(IncidentClassification c) => switch (c) {
  IncidentClassification.safety => Icons.shield_outlined,
  IncidentClassification.security => Icons.lock_outline,
  IncidentClassification.environmental => Icons.eco_outlined,
  IncidentClassification.operational => Icons.build_outlined,
  IncidentClassification.logistics => Icons.local_shipping_outlined,
  IncidentClassification.medical => Icons.medical_services_outlined,
  IncidentClassification.comms => Icons.cell_tower,
};
