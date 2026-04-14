// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — onTap delegates to parent callback
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../automation_history_presenter.dart';
import '../models/automation.dart';

/// Card displaying an automation with toggle and actions
class AutomationCard extends StatelessWidget {
  final Automation automation;
  final void Function(bool enabled) onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onRun;
  final AutomationHistoryEntry? lastRun;

  const AutomationCard({
    super.key,
    required this.automation,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    this.onShare,
    this.onRun,
    this.lastRun,
  });

  @override
  Widget build(BuildContext context) {
    final trigger = automation.trigger;
    final isEnabled = automation.enabled;

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: isEnabled
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : context.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Trigger icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2)
                        : context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(
                    trigger.type.icon,
                    color: isEnabled
                        ? Theme.of(context).colorScheme.primary
                        : SemanticColors.disabled,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),

                // Name and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        automation.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isEnabled ? null : SemanticColors.disabled,
                            ),
                      ),
                      if (automation.description != null) ...[
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          automation.description!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: SemanticColors.disabled),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Toggle switch
                ThemedSwitch(value: isEnabled, onChanged: onToggle),
              ],
            ),

            const SizedBox(height: AppTheme.spacing12),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacing12),

            // Trigger and actions summary
            Row(
              children: [
                // Trigger info
                Expanded(
                  child: _buildInfoChip(
                    context,
                    icon: Icons.bolt,
                    label: trigger.type.displayName,
                    color: AppTheme.warningYellow,
                  ),
                ),

                const SizedBox(width: AppTheme.spacing8),

                // Arrow
                const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: SemanticColors.disabled,
                ),

                const SizedBox(width: AppTheme.spacing8),

                // Actions count
                Expanded(
                  child: _buildInfoChip(
                    context,
                    icon: Icons.play_arrow,
                    label: context.l10n.automationCardActionCount(
                      automation.effectiveThenActions.length,
                      automation.effectiveThenActions.length == 1 ? '' : 's',
                    ),
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),

            // Conditions and branch indicators
            if (automation.conditions != null &&
                automation.conditions!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  _buildInfoChip(
                    context,
                    icon: Icons.filter_alt,
                    label: context.l10n.automationCardConditionCount(
                      automation.conditions!.length,
                    ),
                    color: AccentColors.cyan,
                  ),
                  if (automation.effectiveElseActions != null) ...[
                    const SizedBox(width: AppTheme.spacing8),
                    _buildInfoChip(
                      context,
                      icon: Icons.alt_route,
                      label: context.l10n.automationCardBranchElse,
                      color: AppTheme.errorRed,
                    ),
                  ],
                ],
              ),
            ],

            // Stats row
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                if (automation.triggerCount > 0) ...[
                  Icon(
                    Icons.trending_up,
                    size: 14,
                    color: SemanticColors.muted,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    context.l10n.automationCardRunsCount(
                      automation.triggerCount,
                    ),
                    style: TextStyle(color: SemanticColors.muted, fontSize: 12),
                  ),
                ],
                if (automation.lastTriggered != null) ...[
                  if (automation.triggerCount > 0)
                    const SizedBox(width: AppTheme.spacing16),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: SemanticColors.muted,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    _formatLastTriggered(context, automation.lastTriggered!),
                    style: TextStyle(color: SemanticColors.muted, fontSize: 12),
                  ),
                ],
                // Last run outcome trust signal
                if (lastRun != null) ...[
                  if (automation.triggerCount > 0 ||
                      automation.lastTriggered != null)
                    const SizedBox(width: AppTheme.spacing8),
                  Flexible(child: _buildLastRunSignal(context, lastRun!)),
                ],
                const Spacer(),
                // Run button — visible for manual-trigger automations
                if (onRun != null) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onRun!();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.successGreen,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                ],
                // Share button
                if (onShare != null) ...[
                  GestureDetector(
                    onTap: onShare,
                    child: Icon(
                      Icons.qr_code_2,
                      color: context.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                ],
                // Delete button - always visible
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.delete_outline,
                    color: AppTheme.errorRed,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastRunSignal(
    BuildContext context,
    AutomationHistoryEntry entry,
  ) {
    final isManual = entry.outcome == RunOutcome.manualRun;
    final isSuccess = RunOutcomePresenter.isSuccess(entry.outcome);
    final isFailed = entry.outcome == RunOutcome.failed;
    final color = isManual
        ? AccentColors.cyan
        : isSuccess
        ? AppTheme.successGreen
        : isFailed
        ? AppTheme.errorRed
        : SemanticColors.muted;
    final label = isManual
        ? context.l10n.automationCardLastRunManual
        : context.l10n.automationCardLastRun(
            RunOutcomePresenter.label(entry.outcome, context.l10n),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppTheme.spacing6,
          height: AppTheme.spacing6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppTheme.spacing10 + AppTheme.spacing1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppTheme.spacing6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastTriggered(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return context.l10n.automationCardJustNow;
    if (diff.inMinutes < 60) {
      return context.l10n.automationCardMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.automationCardHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return context.l10n.automationCardDaysAgo(diff.inDays);
    }
    return context.l10n.automationCardWeeksAgo(diff.inDays ~/ 7);
  }
}
