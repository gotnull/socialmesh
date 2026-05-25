// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../automation_history_presenter.dart';
import '../automation_providers.dart';
import '../models/automation.dart';

/// Bottom sheet displaying the automation execution history.
///
/// Shows a merged view of persisted log entries and in-memory debug
/// evaluations, with expandable detail rows for each entry.
class AutomationHistorySheet extends StatelessWidget {
  final void Function() onClear;

  const AutomationHistorySheet({super.key, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (consumerContext, ref, _) {
        final history = ref.watch(automationHistoryProvider);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius20),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacing12,
                    ),
                    decoration: BoxDecoration(
                      color: SemanticColors.muted,
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          consumerContext.l10n.automationScreenExecutionLog,
                          style: Theme.of(consumerContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (history.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              final confirmed =
                                  await AppBottomSheet.showConfirm(
                                    context: consumerContext,
                                    title: consumerContext
                                        .l10n
                                        .automationScreenClearLogTitle,
                                    message: consumerContext
                                        .l10n
                                        .automationScreenClearLogMessage,
                                    confirmLabel: consumerContext
                                        .l10n
                                        .automationScreenClear,
                                    isDestructive: true,
                                  );
                              if (confirmed == true) {
                                onClear();
                              }
                            },
                            child: Text(
                              consumerContext.l10n.automationScreenClear,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: history.isEmpty
                        ? Center(
                            child: Text(
                              consumerContext.l10n.automationHistoryEmpty,
                              style: const TextStyle(
                                color: SemanticColors.disabled,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              return _HistoryRow(entry: history[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A single history row with an expandable detail section.
class _HistoryRow extends StatefulWidget {
  final AutomationHistoryEntry entry;

  const _HistoryRow({required this.entry});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final l10n = context.l10n;
    final isSuccess = RunOutcomePresenter.isSuccess(entry.outcome);
    final isSkip = RunOutcomePresenter.isSkip(entry.outcome);
    final outcomeLabel = RunOutcomePresenter.label(entry.outcome, l10n);

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Row(
              children: [
                // Status icon
                _buildStatusIcon(entry.outcome, isSuccess, isSkip),
                const SizedBox(width: AppTheme.spacing12),
                // Name + outcome
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.automationName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        outcomeLabel,
                        style: TextStyle(
                          color: _outcomeColor(entry.outcome),
                          fontSize: AppTheme.spacing12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Timestamp
                Text(
                  _formatTime(context, entry.timestamp),
                  style: const TextStyle(
                    color: SemanticColors.disabled,
                    fontSize: AppTheme.spacing12,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing4),
                // Expand arrow
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: AppTheme.spacing20,
                  color: SemanticColors.muted,
                ),
              ],
            ),
          ),
        ),
        // Expanded detail section
        if (_expanded) _buildDetailSection(context, entry, l10n),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildStatusIcon(RunOutcome outcome, bool isSuccess, bool isSkip) {
    final IconData icon;
    final Color color;

    if (outcome == RunOutcome.manualRun) {
      icon = Icons.play_circle;
      color = AccentColors.cyan;
    } else if (isSuccess) {
      icon = Icons.check_circle;
      color = AppTheme.successGreen;
    } else if (outcome == RunOutcome.failed) {
      icon = Icons.error;
      color = AppTheme.errorRed;
    } else {
      icon = Icons.skip_next;
      color = SemanticColors.muted;
    }

    return Icon(icon, color: color, size: AppTheme.spacing24);
  }

  Color _outcomeColor(RunOutcome outcome) {
    return switch (outcome) {
      RunOutcome.executedThen || RunOutcome.executed => AppTheme.successGreen,
      RunOutcome.manualRun => AccentColors.cyan,
      RunOutcome.executedElse => AppTheme.warningYellow,
      RunOutcome.failed => AppTheme.errorRed,
      RunOutcome.skippedNoElse ||
      RunOutcome.skippedThrottled ||
      RunOutcome.skippedDisabled ||
      RunOutcome.skippedFiltered => SemanticColors.muted,
    };
  }

  Widget _buildDetailSection(
    BuildContext context,
    AutomationHistoryEntry entry,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        left: AppTheme.spacing50 + AppTheme.spacing2,
        right: AppTheme.spacing16,
        bottom: AppTheme.spacing8,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trigger type
          if (entry.triggerEventType != null)
            _detailRow(
              l10n.automationHistoryDetailTrigger,
              _triggerLabel(entry.triggerEventType!, l10n),
            ),
          // Manual bypass
          if (entry.manualBypass) ...[
            _detailRow(
              l10n.automationHistoryDetailBranch,
              l10n.automationHistoryDetailManualBypass,
            ),
            _detailRow(
              '',
              l10n.automationHistoryDetailManualNote,
              valueColor: SemanticColors.muted,
            ),
          ],
          // Branch selection
          if (!entry.manualBypass &&
              (entry.outcome == RunOutcome.executedThen ||
                  entry.outcome == RunOutcome.executedElse))
            _detailRow(
              l10n.automationHistoryDetailBranch,
              RunOutcomePresenter.label(entry.outcome, l10n),
            ),
          // Condition summary
          if (entry.conditionSummary != null)
            _detailRow(
              l10n.automationHistoryDetailConditions,
              entry.conditionSummary!,
            ),
          // Action results
          if (entry.actionResults != null && entry.actionResults!.isNotEmpty)
            _buildActionResults(entry.actionResults!, l10n),
          // Error
          if (entry.errorMessage != null)
            _detailRow(
              l10n.automationHistoryDetailError,
              entry.errorMessage!,
              valueColor: AppTheme.errorRed,
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppTheme.spacing80 + AppTheme.spacing10,
            child: Text(
              label,
              style: const TextStyle(
                color: SemanticColors.muted,
                fontSize: AppTheme.spacing12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor, fontSize: AppTheme.spacing12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionResults(
    List<ActionResult> results,
    AppLocalizations l10n,
  ) {
    final successCount = results.where((r) => r.success).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(
            l10n.automationHistoryDetailActions,
            l10n.automationHistoryActionCount(successCount, results.length),
          ),
          for (final result in results)
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacing80 + AppTheme.spacing10,
                bottom: AppTheme.spacing2,
              ),
              child: Row(
                children: [
                  Icon(
                    result.success ? Icons.check : Icons.close,
                    size: AppTheme.spacing12,
                    color: result.success
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Expanded(
                    child: Text(
                      result.success
                          ? result.actionName
                          : '${result.actionName}: ${result.errorMessage ?? l10n.automationHistoryOutcomeFailed}',
                      style: TextStyle(
                        fontSize: AppTheme.spacing10 + AppTheme.spacing1,
                        color: result.success ? null : AppTheme.errorRed,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _triggerLabel(String typeName, AppLocalizations l10n) {
    TriggerType? triggerType;
    try {
      triggerType = TriggerType.values.byName(typeName);
    } catch (_) {}
    return triggerType?.localizedName(l10n) ?? typeName;
  }

  String _formatTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return context.l10n.automationScreenJustNow;
    if (diff.inMinutes < 60) {
      return context.l10n.automationScreenMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.automationScreenHoursAgo(diff.inHours);
    }
    return context.l10n.automationScreenDaysAgo(diff.inDays);
  }
}
