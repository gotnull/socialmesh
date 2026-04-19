// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/time_format.dart';

import '../../../core/auth/permission.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../services/haptic_service.dart';
import '../models/incident.dart';
import '../providers/incident_providers.dart';
import '../widgets/incident_filter_bar.dart';
import 'create_incident_screen.dart';
import 'incident_detail_screen.dart';

/// Incident list screen — shows all incidents for the current org.
///
/// Supports filtering by state, priority, and assignee via
/// [IncidentFilterBar]. Empty state prompts creation (RBAC-gated).
///
/// Spec: Sprint 008/W3.3.
class IncidentListScreen extends ConsumerWidget {
  const IncidentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(incidentListProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: context.l10n.incidentListTitle,
        actions: [
          PermissionGate(
            permission: Permission.createIncident,
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: context.l10n.incidentCreateTooltip,
              onPressed: () {
                ref.haptics.buttonTap();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateIncidentScreen(),
                  ),
                );
              },
            ),
          ),
        ],
        slivers: [
          // Filter bar
          const SliverToBoxAdapter(child: IncidentFilterBar()),

          // Content
          incidentsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Text(
                    context.l10n.incidentListLoadError('$e'),
                    textAlign: TextAlign.center,
                    style: context.bodyMutedStyle,
                  ),
                ),
              ),
            ),
            data: (incidents) {
              if (incidents.isEmpty) {
                return SliverFillRemaining(child: _EmptyState());
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _IncidentTile(incident: incidents[index]),
                  childCount: incidents.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 64,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.incidentEmptyStateTitle,
              style: context.titleStyle?.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.incidentEmptyStateDescription,
              textAlign: TextAlign.center,
              style: context.bodyMutedStyle,
            ),
            const SizedBox(height: AppTheme.spacing24),
            PermissionGate(
              permission: Permission.createIncident,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(context.l10n.incidentCreateButtonLabel),
                onPressed: () {
                  ref.haptics.buttonTap();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateIncidentScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident list tile
// ---------------------------------------------------------------------------

class _IncidentTile extends ConsumerWidget {
  final Incident incident;

  const _IncidentTile({required this.incident});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: () {
            ref.haptics.itemSelect();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IncidentDetailScreen(incidentId: incident.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  incident.title,
                  style: context.titleSmallStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),

                const SizedBox(height: AppTheme.spacing8),

                // Badges + metadata
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Badge(
                      label: incident.state.displayLabel(context.l10n),
                      color: _stateColor(incident.state),
                    ),
                    _Badge(
                      label: incident.priority.displayLabel(context.l10n),
                      color: _priorityColor(incident.priority),
                    ),
                    Text(
                      AppTimeFormat.withDatePrefix(
                        context,
                        'd MMM yyyy',
                      ).format(incident.createdAt),
                      style: context.captionMutedStyle,
                    ),
                    if (incident.assigneeId != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: context.textTertiary,
                          ),
                          const SizedBox(width: AppTheme.spacing2),
                          Text(
                            incident.assigneeId!.length > 8
                                ? '${incident.assigneeId!.substring(0, 8)}…'
                                : incident.assigneeId!,
                            style: context.captionMutedStyle,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _stateColor(IncidentState state) {
    return switch (state) {
      IncidentState.draft => SemanticColors.disabled,
      IncidentState.open => AccentColors.blue,
      IncidentState.assigned => AccentColors.orange,
      IncidentState.escalated => AppTheme.errorRed,
      IncidentState.resolved => AppTheme.successGreen,
      IncidentState.closed => AccentColors.slate,
      IncidentState.cancelled => AccentColors.slate,
    };
  }

  static Color _priorityColor(IncidentPriority priority) {
    return switch (priority) {
      IncidentPriority.routine => AccentColors.teal,
      IncidentPriority.priority => AppTheme.warningYellow,
      IncidentPriority.immediate => AccentColors.coral,
      IncidentPriority.flash => AppTheme.errorRed,
    };
  }
}

// ---------------------------------------------------------------------------
// Shared badge
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
