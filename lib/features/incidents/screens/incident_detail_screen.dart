// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission.dart';
import '../../../core/auth/permission_provider.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../models/incident.dart';
import '../providers/incident_providers.dart';
import '../widgets/transition_timeline.dart';

/// Incident detail screen - shows header info and full transition timeline.
///
/// Action buttons are RBAC-gated and only shown for valid transitions
/// from the current state. Terminal states show no actions.
///
/// Spec: Sprint 008/W3.3.
class IncidentDetailScreen extends ConsumerStatefulWidget {
  final String incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  ConsumerState<IncidentDetailScreen> createState() =>
      _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    final incidentAsync = ref.watch(incidentDetailProvider(widget.incidentId));
    final transitionsAsync = ref.watch(
      incidentTransitionsProvider(widget.incidentId),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: incidentAsync.when(
        loading: () => GlassScaffold.body(
          title: context.l10n.incidentDetailTitleLoading,
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => GlassScaffold.body(
          title: context.l10n.incidentDetailTitleLoading,
          body: Center(
            child: Text(
              context.l10n.incidentDetailError('$e'),
              style: context.bodyMutedStyle,
            ),
          ),
        ),
        data: (incident) {
          if (incident == null) {
            return GlassScaffold.body(
              title: context.l10n.incidentDetailTitleLoading,
              body: Center(
                child: Text(
                  context.l10n.incidentNotFound,
                  style: context.bodyMutedStyle,
                ),
              ),
            );
          }

          return GlassScaffold(
            title: context.l10n.incidentDetailTitle,
            slivers: [
              // Header
              SliverToBoxAdapter(child: _IncidentHeader(incident: incident)),

              // Action buttons
              if (!incident.state.isTerminal)
                SliverToBoxAdapter(child: _ActionButtons(incident: incident)),

              // Terminal state message
              if (incident.state.isTerminal)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing6),
                        Text(
                          context.l10n.incidentTerminalStateMessage(
                            incident.state.name,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Timeline section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    16,
                    16,
                    8,
                  ),
                  child: Text(
                    context.l10n.incidentTransitionHistoryHeader,
                    style: context.titleSmallStyle?.copyWith(
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ),

              // Transition timeline
              SliverToBoxAdapter(
                child: transitionsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppTheme.spacing24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    child: Text(
                      context.l10n.incidentTransitionsLoadError('$e'),
                      style: context.bodyMutedStyle,
                    ),
                  ),
                  data: (transitions) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TransitionTimeline(transitions: transitions),
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacing32),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _IncidentHeader extends StatelessWidget {
  final Incident incident;

  const _IncidentHeader({required this.incident});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            incident.title,
            style: context.headingStyle?.copyWith(color: context.textPrimary),
          ),

          if (incident.description != null &&
              incident.description!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              incident.description!,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spacing12),

          // Badges
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
              _Badge(
                label: incident.classification.displayLabel(context.l10n),
                color: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),

          // Location snippet
          if (incident.locationLat != null && incident.locationLon != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '${incident.locationLat!.toStringAsFixed(5)}, '
                  '${incident.locationLon!.toStringAsFixed(5)}',
                  style: context.captionMutedStyle,
                ),
              ],
            ),
          ],

          // Assignee
          if (incident.assigneeId != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  context.l10n.incidentAssignedLabel(incident.assigneeId!),
                  style: context.captionMutedStyle,
                ),
              ],
            ),
          ],

          const Divider(height: 24),
        ],
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
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends ConsumerWidget {
  final Incident incident;

  const _ActionButtons({required this.incident});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(incidentActionsProvider);
    final isLoading = actions is AsyncLoading;

    // Valid targets for current state, mapped to permission + label.
    final l10n = context.l10n;
    final targets = _availableActions(incident.state, l10n);

    if (targets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: targets.map((action) {
          return PermissionGate(
            permission: action.permission,
            mode: PermissionGateMode.disabled,
            deniedTooltip: context.l10n.incidentActionDeniedTooltip(
              action.roleHint,
            ),
            child: BouncyTap(
              onTap: isLoading ? null : () => _onAction(context, ref, action),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                  border: Border.all(
                    color: action.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.icon, size: 16, color: action.color),
                    const SizedBox(width: AppTheme.spacing6),
                    Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: action.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _ActionDef action,
  ) async {
    ref.haptics.buttonTap();

    final roleName =
        ref.read(permissionServiceProvider).currentRole?.name ?? 'unknown';

    AppLogging.incidentUI(
      'transition button tapped: ${action.label} '
      '(incident=${incident.id}, role=$roleName)',
    );

    String? assigneeId;
    String? note;

    // If assigning, ask for assignee ID.
    if (action.target == IncidentState.assigned) {
      assigneeId = await _showAssigneeDialog(context);
      if (assigneeId == null) return; // cancelled
    }

    // Optional note for any transition.
    if (context.mounted) {
      note = await _showNoteDialog(context, action.label);
    }

    final success = await ref
        .read(incidentActionsProvider.notifier)
        .applyTransition(
          incident: incident,
          target: action.target,
          assigneeId: assigneeId,
          note: note,
        );

    if (context.mounted) {
      if (success) {
        showSuccessSnackBar(
          context,
          context.l10n.incidentActionSuccessSnackbar(
            action.label.toLowerCase(),
          ),
        );
      } else {
        final error = ref.read(incidentActionsProvider);
        showErrorSnackBar(
          context,
          error is AsyncError
              ? '${error.error}'
              : context.l10n.incidentActionFailedSnackbar,
        );
      }
    }
  }

  Future<String?> _showAssigneeDialog(BuildContext context) async {
    final controller = TextEditingController();
    final l10n = context.l10n;
    return AppBottomSheet.show<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.incidentAssignSheetTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: controller,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: l10n.incidentAssigneeLabel,
              hintText: l10n.incidentAssigneeHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(l10n.incidentAssignCancelButton),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isNotEmpty) Navigator.of(context).pop(value);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(l10n.incidentAssignConfirmButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _showNoteDialog(BuildContext context, String action) async {
    final controller = TextEditingController();
    final l10n = context.l10n;
    return AppBottomSheet.show<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.incidentNoteSheetTitle(action),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: controller,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.incidentNoteLabel,
              hintText: l10n.incidentNoteHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(l10n.incidentNoteSkipButton),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    Navigator.of(context).pop(value.isEmpty ? null : value);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(l10n.incidentNoteContinueButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<_ActionDef> _availableActions(
    IncidentState state,
    AppLocalizations l10n,
  ) {
    return switch (state) {
      IncidentState.draft => [
        _ActionDef(
          label: l10n.incidentActionSubmit,
          target: IncidentState.open,
          permission: Permission.submitIncident,
          icon: Icons.send_outlined,
          color: AccentColors.blue,
          roleHint: l10n.incidentRoleHintOperatorOrAbove,
        ),
        _ActionDef(
          label: l10n.incidentActionCancel,
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: AccentColors.slate,
          roleHint: l10n.incidentRoleHintOperatorOrAbove,
        ),
      ],
      IncidentState.open => [
        _ActionDef(
          label: l10n.incidentActionAssign,
          target: IncidentState.assigned,
          permission: Permission.assignIncident,
          icon: Icons.person_add_outlined,
          color: AccentColors.orange,
          roleHint: l10n.incidentRoleHintSupervisorOrAdmin,
        ),
        _ActionDef(
          label: l10n.incidentActionEscalate,
          target: IncidentState.escalated,
          permission: Permission.escalateIncident,
          icon: Icons.priority_high,
          color: AppTheme.errorRed,
          roleHint: l10n.incidentRoleHintSupervisorOrAdmin,
        ),
        _ActionDef(
          label: l10n.incidentActionResolve,
          target: IncidentState.resolved,
          permission: Permission.resolveIncident,
          icon: Icons.check_circle_outline,
          color: AppTheme.successGreen,
          roleHint: l10n.incidentRoleHintAssignedOperator,
        ),
        _ActionDef(
          label: l10n.incidentActionCancel,
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: AccentColors.slate,
          roleHint: l10n.incidentRoleHintOperatorOrAbove,
        ),
      ],
      IncidentState.escalated => [
        _ActionDef(
          label: l10n.incidentActionAssign,
          target: IncidentState.assigned,
          permission: Permission.assignIncident,
          icon: Icons.person_add_outlined,
          color: AccentColors.orange,
          roleHint: l10n.incidentRoleHintSupervisorOrAdmin,
        ),
        _ActionDef(
          label: l10n.incidentActionCancel,
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: AccentColors.slate,
          roleHint: l10n.incidentRoleHintOperatorOrAbove,
        ),
      ],
      IncidentState.assigned => [
        _ActionDef(
          label: l10n.incidentActionResolve,
          target: IncidentState.resolved,
          permission: Permission.resolveIncident,
          icon: Icons.check_circle_outline,
          color: AppTheme.successGreen,
          roleHint: l10n.incidentRoleHintAssignedOperator,
        ),
        _ActionDef(
          label: l10n.incidentActionCancel,
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: AccentColors.slate,
          roleHint: l10n.incidentRoleHintOperatorOrAbove,
        ),
      ],
      IncidentState.resolved => [
        _ActionDef(
          label: l10n.incidentActionClose,
          target: IncidentState.closed,
          permission: Permission.closeIncident,
          icon: Icons.done_all,
          color: AccentColors.slate,
          roleHint: l10n.incidentRoleHintSupervisorOrAdmin,
        ),
      ],
      IncidentState.closed || IncidentState.cancelled => [],
    };
  }
}

class _ActionDef {
  final String label;
  final IncidentState target;
  final Permission permission;
  final IconData icon;
  final Color color;
  final String roleHint;

  const _ActionDef({
    required this.label,
    required this.target,
    required this.permission,
    required this.icon,
    required this.color,
    required this.roleHint,
  });
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
