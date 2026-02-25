// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission.dart';
import '../../../core/auth/permission_provider.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../models/incident.dart';
import '../providers/incident_providers.dart';
import '../widgets/transition_timeline.dart';

/// Incident detail screen — shows header info and full transition timeline.
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
          title: 'Incident',
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => GlassScaffold.body(
          title: 'Incident',
          body: Center(child: Text('Error: $e', style: context.bodyMutedStyle)),
        ),
        data: (incident) {
          if (incident == null) {
            return GlassScaffold.body(
              title: 'Incident',
              body: Center(
                child: Text(
                  'Incident not found',
                  style: context.bodyMutedStyle,
                ),
              ),
            );
          }

          return GlassScaffold(
            title: 'Incident Detail',
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
                          'This incident is ${incident.state.name} — '
                          'no further actions available.',
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
                    'Transition History',
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
                      'Failed to load transitions: $e',
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
                label: incident.state.name,
                color: _stateColor(incident.state),
              ),
              _Badge(
                label: incident.priority.name,
                color: _priorityColor(incident.priority),
              ),
              _Badge(
                label: incident.classification.name,
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
                  'Assigned: ${incident.assigneeId}',
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
      IncidentState.draft => Colors.grey,
      IncidentState.open => Colors.blue,
      IncidentState.assigned => Colors.orange,
      IncidentState.escalated => Colors.red,
      IncidentState.resolved => Colors.green,
      IncidentState.closed => Colors.blueGrey,
      IncidentState.cancelled => Colors.brown,
    };
  }

  static Color _priorityColor(IncidentPriority priority) {
    return switch (priority) {
      IncidentPriority.routine => Colors.teal,
      IncidentPriority.priority => Colors.amber.shade700,
      IncidentPriority.immediate => Colors.deepOrange,
      IncidentPriority.flash => Colors.red.shade800,
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
    final targets = _availableActions(incident.state);

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
            deniedTooltip: 'Requires ${action.roleHint}',
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
        showSuccessSnackBar(context, 'Incident ${action.label.toLowerCase()}d');
      } else {
        final error = ref.read(incidentActionsProvider);
        showErrorSnackBar(
          context,
          error is AsyncError ? '${error.error}' : 'Action failed',
        );
      }
    }
  }

  Future<String?> _showAssigneeDialog(BuildContext context) async {
    final controller = TextEditingController();
    return AppBottomSheet.show<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign Incident',
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
            decoration: const InputDecoration(
              labelText: 'Assignee User ID',
              hintText: 'Enter user ID',
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
                    side: BorderSide(color: Colors.grey.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: const Text('Cancel'),
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
                  child: const Text('Assign'),
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
    return AppBottomSheet.show<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$action Note (optional)',
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
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Optional note for this transition',
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
                    side: BorderSide(color: Colors.grey.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: const Text('Skip'),
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
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<_ActionDef> _availableActions(IncidentState state) {
    return switch (state) {
      IncidentState.draft => [
        _ActionDef(
          label: 'Submit',
          target: IncidentState.open,
          permission: Permission.submitIncident,
          icon: Icons.send_outlined,
          color: Colors.blue,
          roleHint: 'Operator or above',
        ),
        _ActionDef(
          label: 'Cancel',
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: Colors.brown,
          roleHint: 'Operator or above',
        ),
      ],
      IncidentState.open => [
        _ActionDef(
          label: 'Assign',
          target: IncidentState.assigned,
          permission: Permission.assignIncident,
          icon: Icons.person_add_outlined,
          color: Colors.orange,
          roleHint: 'Supervisor or Admin',
        ),
        _ActionDef(
          label: 'Escalate',
          target: IncidentState.escalated,
          permission: Permission.escalateIncident,
          icon: Icons.priority_high,
          color: Colors.red,
          roleHint: 'Supervisor or Admin',
        ),
        _ActionDef(
          label: 'Resolve',
          target: IncidentState.resolved,
          permission: Permission.resolveIncident,
          icon: Icons.check_circle_outline,
          color: Colors.green,
          roleHint: 'Assigned Operator',
        ),
        _ActionDef(
          label: 'Cancel',
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: Colors.brown,
          roleHint: 'Operator or above',
        ),
      ],
      IncidentState.escalated => [
        _ActionDef(
          label: 'Assign',
          target: IncidentState.assigned,
          permission: Permission.assignIncident,
          icon: Icons.person_add_outlined,
          color: Colors.orange,
          roleHint: 'Supervisor or Admin',
        ),
        _ActionDef(
          label: 'Cancel',
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: Colors.brown,
          roleHint: 'Operator or above',
        ),
      ],
      IncidentState.assigned => [
        _ActionDef(
          label: 'Resolve',
          target: IncidentState.resolved,
          permission: Permission.resolveIncident,
          icon: Icons.check_circle_outline,
          color: Colors.green,
          roleHint: 'Assigned Operator',
        ),
        _ActionDef(
          label: 'Cancel',
          target: IncidentState.cancelled,
          permission: Permission.cancelIncident,
          icon: Icons.cancel_outlined,
          color: Colors.brown,
          roleHint: 'Operator or above',
        ),
      ],
      IncidentState.resolved => [
        _ActionDef(
          label: 'Close',
          target: IncidentState.closed,
          permission: Permission.closeIncident,
          icon: Icons.done_all,
          color: Colors.blueGrey,
          roleHint: 'Supervisor or Admin',
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
