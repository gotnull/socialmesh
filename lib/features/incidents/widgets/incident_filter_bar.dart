// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../services/haptic_service.dart';
import '../models/incident.dart';
import '../providers/incident_providers.dart';

/// Horizontal filter bar for incident list.
///
/// Renders FilterChip groups for state and priority, plus an
/// "Assigned to me" toggle. Emits updates via [IncidentFilterNotifier].
///
/// Spec: Sprint 008/W3.3.
class IncidentFilterBar extends ConsumerWidget {
  const IncidentFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(incidentFilterProvider);
    final notifier = ref.read(incidentFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // -- State filter chips --
          ...IncidentState.values.map((state) {
            final isSelected = filter.states.contains(state);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_stateLabel(state)),
                selected: isSelected,
                onSelected: (selected) {
                  ref.haptics.toggle();
                  final updated = Set<IncidentState>.from(filter.states);
                  if (selected) {
                    updated.add(state);
                  } else {
                    updated.remove(state);
                  }
                  notifier.setStates(updated);
                },
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : context.textSecondary,
                ),
                selectedColor: _stateColor(state),
                backgroundColor: context.card,
                side: BorderSide(color: context.border),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
            );
          }),

          Container(
            width: 1,
            height: 24,
            color: context.border,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),

          // -- Priority filter chips --
          ...IncidentPriority.values.map((priority) {
            final isSelected = filter.priorities.contains(priority);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_priorityLabel(priority)),
                selected: isSelected,
                onSelected: (selected) {
                  ref.haptics.toggle();
                  final updated = Set<IncidentPriority>.from(filter.priorities);
                  if (selected) {
                    updated.add(priority);
                  } else {
                    updated.remove(priority);
                  }
                  notifier.setPriorities(updated);
                },
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : context.textSecondary,
                ),
                selectedColor: _priorityColor(priority),
                backgroundColor: context.card,
                side: BorderSide(color: context.border),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
            );
          }),

          Container(
            width: 1,
            height: 24,
            color: context.border,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),

          // -- Assigned to me toggle --
          FilterChip(
            label: const Text('Assigned to me'),
            selected: filter.assignedToMe,
            onSelected: (_) {
              ref.haptics.toggle();
              notifier.toggleAssignedToMe();
            },
            labelStyle: TextStyle(
              fontSize: 12,
              color: filter.assignedToMe ? Colors.white : context.textSecondary,
            ),
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: context.card,
            side: BorderSide(color: context.border),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  static String _stateLabel(IncidentState state) {
    return switch (state) {
      IncidentState.draft => 'Draft',
      IncidentState.open => 'Open',
      IncidentState.assigned => 'Assigned',
      IncidentState.escalated => 'Escalated',
      IncidentState.resolved => 'Resolved',
      IncidentState.closed => 'Closed',
      IncidentState.cancelled => 'Cancelled',
    };
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

  static String _priorityLabel(IncidentPriority priority) {
    return switch (priority) {
      IncidentPriority.routine => 'Routine',
      IncidentPriority.priority => 'Priority',
      IncidentPriority.immediate => 'Immediate',
      IncidentPriority.flash => 'Flash',
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
