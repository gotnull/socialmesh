// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — onTap delegates to parent callback
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../models/automation.dart';

/// Widget for editing a single automation condition's type and parameters.
class ConditionEditor extends StatelessWidget {
  final AutomationCondition condition;
  final void Function(AutomationCondition condition) onChanged;
  final VoidCallback onDelete;

  const ConditionEditor({
    super.key,
    required this.condition,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(condition.type.icon, size: 18, color: AccentColors.cyan),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  condition.type.localizedName(context.l10n),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              BouncyTap(
                onTap: onDelete,
                child: Icon(Icons.close, size: 18, color: SemanticColors.muted),
              ),
            ],
          ),
          // Condition-specific config
          _buildConfigEditor(context),
        ],
      ),
    );
  }

  Widget _buildConfigEditor(BuildContext context) {
    switch (condition.type) {
      case ConditionType.timeRange:
        return _buildTimeRangeConfig(context);
      case ConditionType.dayOfWeek:
        return _buildDayOfWeekConfig(context);
      case ConditionType.batteryAbove:
      case ConditionType.batteryBelow:
        return _buildBatteryConfig(context);
      case ConditionType.nodeOnline:
      case ConditionType.nodeOffline:
      case ConditionType.withinGeofence:
      case ConditionType.outsideGeofence:
        // These have no additional config parameters
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimeRangeConfig(BuildContext context) {
    final start =
        condition.timeStart ?? '08:00'; // lint-allow: hardcoded-string
    final end = condition.timeEnd ?? '22:00'; // lint-allow: hardcoded-string
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing8),
      child: Row(
        children: [
          Expanded(
            child: BouncyTap(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _parseTime(start),
                );
                if (time != null) {
                  final formatted = _formatTime(time);
                  onChanged(
                    AutomationCondition(
                      type: condition.type,
                      config: {...condition.config, 'timeStart': formatted},
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(color: context.border),
                ),
                child: Text(
                  start,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
            child: Text('–', style: TextStyle(color: SemanticColors.muted)),
          ),
          Expanded(
            child: BouncyTap(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _parseTime(end),
                );
                if (time != null) {
                  final formatted = _formatTime(time);
                  onChanged(
                    AutomationCondition(
                      type: condition.type,
                      config: {...condition.config, 'timeEnd': formatted},
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(color: context.border),
                ),
                child: Text(end, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayOfWeekConfig(BuildContext context) {
    final selectedDays = condition.daysOfWeek ?? [1, 2, 3, 4, 5];
    final dayLabels = [
      'S', 'M', 'T', 'W', 'T', 'F', 'S', // lint-allow: hardcoded-string
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final isSelected = selectedDays.contains(index);
          return BouncyTap(
            onTap: () {
              final newDays = List<int>.from(selectedDays);
              if (isSelected) {
                newDays.remove(index);
              } else {
                newDays.add(index);
                newDays.sort();
              }
              onChanged(
                AutomationCondition(
                  type: condition.type,
                  config: {...condition.config, 'daysOfWeek': newDays},
                ),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AccentColors.cyan.withValues(alpha: 0.2)
                    : context.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AccentColors.cyan : context.border,
                ),
              ),
              child: Center(
                child: Text(
                  dayLabels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AccentColors.cyan
                        : SemanticColors.muted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBatteryConfig(BuildContext context) {
    final threshold = condition.batteryThreshold;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing8),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: threshold.toDouble(),
              min: 5,
              max: 95,
              divisions: 18,
              label: '$threshold%',
              onChanged: (value) {
                onChanged(
                  AutomationCondition(
                    type: condition.type,
                    config: {
                      ...condition.config,
                      'batteryThreshold': value.round(),
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$threshold%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.firstOrNull ?? '') ?? 0,
      minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
