// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/spp_types.dart';
import '../models/incident.dart';
import '../models/mesh_incident_report.dart';
import '../providers/mesh_incident_providers.dart';
import 'mesh_incident_composer_screen.dart';

/// Detail screen for a mesh incident case.
///
/// Shows the effective state projection at the top, followed by the
/// chronological timeline of all reports. Corrections are flagged.
/// Superseded reports are dimmed.
class MeshIncidentDetailScreen extends ConsumerWidget {
  final int caseId;

  const MeshIncidentDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(meshIncidentCaseDetailProvider(caseId));
    final caseStateAsync = ref.watch(meshIncidentCaseStateProvider(caseId));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: context.l10n.meshIncidentDetailTitle,
        actions: [
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              ref.haptics.buttonTap();
              switch (value) {
                case 'update':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MeshIncidentComposerScreen(
                        existingCaseId: caseId,
                        updateType: IncidentUpdateType.update,
                      ),
                    ),
                  );
                case 'close':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MeshIncidentComposerScreen(
                        existingCaseId: caseId,
                        updateType: IncidentUpdateType.closure,
                      ),
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'update',
                child: Text(context.l10n.meshIncidentAddUpdate),
              ),
              PopupMenuItem(
                value: 'close',
                child: Text(context.l10n.meshIncidentCloseCase),
              ),
            ],
          ),
        ],
        slivers: [
          // Case header
          SliverToBoxAdapter(
            child: caseStateAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppTheme.spacing24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: Text('$e', style: context.bodyMutedStyle),
              ),
              data: (caseState) {
                if (caseState == null) {
                  return Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    child: Text(
                      context.l10n.meshIncidentEmptyTitle,
                      style: context.bodyMutedStyle,
                    ),
                  );
                }
                return _CaseHeader(caseState: caseState);
              },
            ),
          ),

          // Timeline header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing8,
              ),
              child: Text(
                context.l10n.meshIncidentTimelineTitle,
                style: context.titleSmallStyle?.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Report timeline
          reportsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('$e'))),
            data: (reports) {
              if (reports.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                sliver: SliverList.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _ReportTimelineEntry(
                      report: report,
                      isFirst: index == 0,
                      isLast: index == reports.length - 1,
                      onCorrect: () {
                        ref.haptics.buttonTap();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MeshIncidentComposerScreen(
                              existingCaseId: caseId,
                              updateType: IncidentUpdateType.correction,
                              refSeq: report.seqNum,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing80)),
        ],
      ),
    );
  }
}

class _CaseHeader extends StatelessWidget {
  final MeshIncidentCaseState caseState;

  const _CaseHeader({required this.caseState});

  @override
  Widget build(BuildContext context) {
    final report = caseState.latestReport;
    final statusColor = _statusColor(caseState.effectiveStatus);
    final isActive = caseState.effectiveStatus == IncidentMeshStatus.active;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
      ).copyWith(top: AppTheme.spacing16),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius16,
        borderWidth: isActive ? 2 : 1.5,
        accentColor: statusColor,
        accentOpacity: isActive ? 0.6 : 0.4,
        enableDepthBlend: true,
        depthBlendOpacity: 0.1,
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

            // Classification
            _ClassificationBadge(
              classification: caseState.effectiveClassification,
            ),
            const SizedBox(height: AppTheme.spacing12),

            // Body text
            Text(
              report.body,
              style: context.bodyStyle?.copyWith(height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Metadata row
            Wrap(
              spacing: AppTheme.spacing12,
              runSpacing: AppTheme.spacing4,
              children: [
                _MetaChip(
                  icon: Icons.layers,
                  text: context.l10n.meshIncidentReportCount(
                    caseState.reportCount,
                  ),
                  context: context,
                ),
                _MetaChip(
                  icon: Icons.people_outline,
                  text: context.l10n.meshIncidentContributors(
                    caseState.contributorNodes.length,
                  ),
                  context: context,
                ),
                if (caseState.hasCorrections)
                  _MetaChip(
                    icon: Icons.edit_note,
                    text: context.l10n.meshIncidentCorrectionBadge,
                    context: context,
                    color: AccentColors.orange,
                  ),
                if (report.hasLocation)
                  _MetaChip(
                    icon: Icons.location_on,
                    text: context.l10n.meshIncidentLocationCoarse,
                    context: context,
                    color: AccentColors.teal,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTimelineEntry extends StatelessWidget {
  final MeshIncidentReport report;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onCorrect;

  const _ReportTimelineEntry({
    required this.report,
    required this.isFirst,
    required this.isLast,
    required this.onCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = report.isSuperseded;
    final dateFormat = DateFormat.yMd().add_Hm();
    final typeColor = _updateTypeColor(report.updateType);

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + dot
            SizedBox(
              width: AppTheme.spacing24,
              child: Column(
                children: [
                  if (!isFirst)
                    SizedBox(
                      height: AppTheme.spacing4,
                      child: Container(
                        width: AppTheme.spacing2,
                        color: context.border.withValues(alpha: 0.2),
                      ),
                    ),
                  Container(
                    width: AppTheme.spacing10,
                    height: AppTheme.spacing10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: typeColor,
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.4),
                          blurRadius: AppTheme.spacing6,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: AppTheme.spacing2,
                        color: context.border.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: AppTheme.spacing8),

            // Report card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: dimmed
                        ? context.border.withValues(alpha: 0.1)
                        : context.border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        _UpdateTypeBadge(type: report.updateType),
                        const SizedBox(width: AppTheme.spacing8),
                        _ConfidenceBadge(confidence: report.confidence),
                        const Spacer(),
                        if (report.isSuperseded) _SupersededBadge(),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing8),

                    // Body text
                    Text(
                      report.body,
                      style: context.bodySecondaryStyle?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppTheme.spacing10),

                    // Metadata row
                    Wrap(
                      spacing: AppTheme.spacing12,
                      runSpacing: AppTheme.spacing4,
                      children: [
                        Text(
                          dateFormat.format(report.timestamp.toLocal()),
                          style: context.captionMutedStyle,
                        ),
                        Text(
                          context.l10n.meshIncidentFromNode(
                            report.senderNodeId == 0
                                ? 'local' // lint-allow: hardcoded-string
                                : '!${report.senderNodeId.toRadixString(16)}',
                          ),
                          style: context.captionMutedStyle,
                        ),
                        Text(
                          report.classification.displayLabel(context.l10n),
                          style: context.captionMutedStyle,
                        ),
                      ],
                    ),

                    // Correct action
                    if (!dimmed &&
                        report.status != IncidentMeshStatus.resolved &&
                        report.status != IncidentMeshStatus.cancelled)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onCorrect,
                          icon: Icon(
                            Icons.edit_note,
                            size: AppTheme.spacing14,
                            color: AccentColors.orange,
                          ),
                          label: Text(
                            context.l10n.meshIncidentCorrectReport,
                            style: context.captionStyle?.copyWith(
                              color: AccentColors.orange,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge widgets — matching app design language
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

class _UpdateTypeBadge extends StatelessWidget {
  final IncidentUpdateType type;
  const _UpdateTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _updateTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        _updateTypeLabel(context, type),
        style: context.captionStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final IncidentConfidence confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = _confidenceColor(confidence);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        _confidenceLabel(context, confidence),
        style: context.captionStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SupersededBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: SemanticColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(
          color: SemanticColors.error.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        context.l10n.meshIncidentSuperseded,
        style: context.captionStyle?.copyWith(
          color: SemanticColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final BuildContext context;
  final Color? color;

  const _MetaChip({
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

Color _updateTypeColor(IncidentUpdateType type) => switch (type) {
  IncidentUpdateType.initial => SemanticColors.info,
  IncidentUpdateType.update => AccentColors.teal,
  IncidentUpdateType.correction => AccentColors.orange,
  IncidentUpdateType.closure => SemanticColors.disabled,
};

String _updateTypeLabel(BuildContext context, IncidentUpdateType type) =>
    switch (type) {
      IncidentUpdateType.initial => context.l10n.meshIncidentUpdateTypeInitial,
      IncidentUpdateType.update => context.l10n.meshIncidentUpdateTypeUpdate,
      IncidentUpdateType.correction =>
        context.l10n.meshIncidentUpdateTypeCorrection,
      IncidentUpdateType.closure => context.l10n.meshIncidentUpdateTypeClosure,
    };

Color _confidenceColor(IncidentConfidence confidence) => switch (confidence) {
  IncidentConfidence.unconfirmed => SemanticColors.warning,
  IncidentConfidence.probable => SemanticColors.info,
  IncidentConfidence.confirmed => SemanticColors.success,
};

String _confidenceLabel(
  BuildContext context,
  IncidentConfidence confidence,
) => switch (confidence) {
  IncidentConfidence.unconfirmed =>
    context.l10n.meshIncidentConfidenceUnconfirmed,
  IncidentConfidence.probable => context.l10n.meshIncidentConfidenceProbable,
  IncidentConfidence.confirmed => context.l10n.meshIncidentConfidenceConfirmed,
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
