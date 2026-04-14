// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../l10n/app_localizations.dart';
import 'automation_debug_service.dart';
import 'models/automation.dart';
import 'models/condition_node_result.dart';

/// User-facing outcome of an automation run.
enum RunOutcome {
  /// All actions in THEN branch succeeded.
  executedThen,

  /// All actions in ELSE branch succeeded.
  executedElse,

  /// Executed without branching (legacy or no conditions).
  executed,

  /// Manual run bypassed conditions, executed THEN path.
  manualRun,

  /// One or more actions failed.
  failed,

  /// Condition failed and no ELSE branch — nothing ran.
  skippedNoElse,

  /// Skipped due to cooldown/throttle.
  skippedThrottled,

  /// Skipped because automation is disabled.
  skippedDisabled,

  /// Skipped due to trigger mismatch or filter.
  skippedFiltered,
}

/// Unified view model for a single automation history entry.
///
/// Merges data from [AutomationLogEntry] (persisted execution results) and
/// [AutomationEvaluation] (in-memory debug evaluations including skips).
class AutomationHistoryEntry {
  final String automationId;
  final String automationName;
  final DateTime timestamp;
  final RunOutcome outcome;
  final String? triggerEventType;
  final String? triggerNodeName;
  final int? triggerBatteryLevel;
  final String? triggerMessageText;
  final List<ActionResult>? actionResults;
  final String? conditionSummary;
  final String? errorMessage;
  final bool manualBypass;

  const AutomationHistoryEntry({
    required this.automationId,
    required this.automationName,
    required this.timestamp,
    required this.outcome,
    this.triggerEventType,
    this.triggerNodeName,
    this.triggerBatteryLevel,
    this.triggerMessageText,
    this.actionResults,
    this.conditionSummary,
    this.errorMessage,
    this.manualBypass = false,
  });

  /// Create from a persisted [AutomationLogEntry].
  factory AutomationHistoryEntry.fromLogEntry(AutomationLogEntry entry) {
    return AutomationHistoryEntry(
      automationId: entry.automationId,
      automationName: entry.automationName,
      timestamp: entry.timestamp,
      outcome: _outcomeFromLogEntry(entry),
      triggerEventType: entry.triggerEventType,
      triggerNodeName: entry.triggerNodeName,
      triggerBatteryLevel: entry.triggerBatteryLevel,
      triggerMessageText: entry.triggerMessageText,
      actionResults: entry.actionResults,
      conditionSummary: entry.conditionSummary,
      errorMessage: entry.errorMessage,
      manualBypass: entry.manualBypass,
    );
  }

  /// Create from an in-memory [AutomationEvaluation] (typically a skip).
  factory AutomationHistoryEntry.fromEvaluation(AutomationEvaluation eval) {
    return AutomationHistoryEntry(
      automationId: eval.automationId,
      automationName: eval.automationName,
      timestamp: eval.timestamp,
      outcome: _outcomeFromEvaluation(eval),
      triggerEventType: eval.eventType.name,
      conditionSummary: eval.conditionTreeResult != null
          ? ConditionResultPresenter.summarize(eval.conditionTreeResult!)
          : null,
      manualBypass: eval.manualBypass,
    );
  }

  static RunOutcome _outcomeFromLogEntry(AutomationLogEntry entry) {
    if (entry.manualBypass) return RunOutcome.manualRun;
    if (!entry.success) return RunOutcome.failed;
    final branch = entry.branchSelection;
    if (branch == 'then') return RunOutcome.executedThen;
    if (branch == 'else') return RunOutcome.executedElse;
    return RunOutcome.executed;
  }

  static RunOutcome _outcomeFromEvaluation(AutomationEvaluation eval) {
    if (eval.triggered) {
      if (eval.manualBypass) return RunOutcome.manualRun;
      final branch = eval.branchSelection;
      if (branch == BranchSelection.thenBranch) return RunOutcome.executedThen;
      if (branch == BranchSelection.elseBranch) return RunOutcome.executedElse;
      if (branch == BranchSelection.none) return RunOutcome.skippedNoElse;
      return RunOutcome.executed;
    }
    final skip = eval.skipReason;
    if (skip == SkipReason.throttled) return RunOutcome.skippedThrottled;
    if (skip == SkipReason.disabled) return RunOutcome.skippedDisabled;
    if (skip == SkipReason.conditionFailed) return RunOutcome.skippedNoElse;
    return RunOutcome.skippedFiltered;
  }
}

/// Produces user-facing labels for [RunOutcome] values.
class RunOutcomePresenter {
  RunOutcomePresenter._();

  /// Localized label for the outcome.
  static String label(RunOutcome outcome, AppLocalizations l10n) {
    return switch (outcome) {
      RunOutcome.executedThen => l10n.automationHistoryOutcomeThen,
      RunOutcome.executedElse => l10n.automationHistoryOutcomeElse,
      RunOutcome.executed => l10n.automationHistoryOutcomeExecuted,
      RunOutcome.manualRun => l10n.automationHistoryOutcomeManual,
      RunOutcome.failed => l10n.automationHistoryOutcomeFailed,
      RunOutcome.skippedNoElse => l10n.automationHistoryOutcomeSkippedNoElse,
      RunOutcome.skippedThrottled =>
        l10n.automationHistoryOutcomeSkippedThrottled,
      RunOutcome.skippedDisabled =>
        l10n.automationHistoryOutcomeSkippedDisabled,
      RunOutcome.skippedFiltered =>
        l10n.automationHistoryOutcomeSkippedFiltered,
    };
  }

  /// Whether this outcome represents a successful execution.
  static bool isSuccess(RunOutcome outcome) {
    return outcome == RunOutcome.executedThen ||
        outcome == RunOutcome.executedElse ||
        outcome == RunOutcome.executed ||
        outcome == RunOutcome.manualRun;
  }

  /// Whether this outcome was a skip (no actions ran).
  static bool isSkip(RunOutcome outcome) {
    return outcome == RunOutcome.skippedNoElse ||
        outcome == RunOutcome.skippedThrottled ||
        outcome == RunOutcome.skippedDisabled ||
        outcome == RunOutcome.skippedFiltered;
  }

  /// Whether this outcome was a manual test run (conditions bypassed).
  static bool isManualRun(RunOutcome outcome) {
    return outcome == RunOutcome.manualRun;
  }
}

/// Produces user-readable summaries from [ConditionNodeResult] trees.
class ConditionResultPresenter {
  ConditionResultPresenter._();

  /// One-line concise summary of a condition tree result.
  static String summarize(ConditionNodeResult result) {
    return switch (result) {
      PredicateResult(:final passed, :final conditionType) =>
        '${conditionType.displayName}: ${passed ? "passed" : "failed"}',
      AllGroupResult(:final passed, :final childResults) =>
        passed
            ? 'All ${childResults.length} conditions passed'
            : '${childResults.where((c) => !c.passed).length} of ${childResults.length} conditions failed',
      AnyGroupResult(:final passed, :final childResults) =>
        passed
            ? '${childResults.where((c) => c.passed).length} of ${childResults.length} conditions matched'
            : 'No conditions matched',
      NotGroupResult(:final passed) =>
        passed ? 'NOT condition passed' : 'NOT condition failed',
    };
  }

  /// Localized summary using ARB keys.
  static String localizedSummary(
    ConditionNodeResult result,
    AppLocalizations l10n,
  ) {
    return switch (result) {
      PredicateResult(:final passed, :final conditionType) =>
        passed
            ? l10n.automationConditionPassed(conditionType.displayName)
            : l10n.automationConditionFailed(conditionType.displayName),
      AllGroupResult(:final passed, :final childResults) =>
        passed
            ? l10n.automationConditionAllPassed(childResults.length)
            : l10n.automationConditionSomeFailed(
                childResults.where((c) => !c.passed).length,
                childResults.length,
              ),
      AnyGroupResult(:final passed, :final childResults) =>
        passed
            ? l10n.automationConditionSomeMatched(
                childResults.where((c) => c.passed).length,
                childResults.length,
              )
            : l10n.automationConditionNoneMatched,
      NotGroupResult(:final passed) =>
        passed
            ? l10n.automationConditionNotPassed
            : l10n.automationConditionNotFailed,
    };
  }

  /// Detailed per-child results for expanded tree view.
  static List<ConditionDetail> details(ConditionNodeResult result) {
    return switch (result) {
      PredicateResult(:final passed, :final conditionType, :final detail) => [
        ConditionDetail(
          label: conditionType.displayName,
          passed: passed,
          detail: detail,
        ),
      ],
      AllGroupResult(:final childResults) ||
      AnyGroupResult(
        :final childResults,
      ) => childResults.expand((child) => details(child)).toList(),
      NotGroupResult(:final childResult) => details(childResult),
    };
  }
}

/// A single leaf condition detail for display.
class ConditionDetail {
  final String label;
  final bool passed;
  final String detail;

  const ConditionDetail({
    required this.label,
    required this.passed,
    required this.detail,
  });
}

/// Localized skip reason from a [SkipReason] enum.
class SkipReasonPresenter {
  SkipReasonPresenter._();

  static String label(SkipReason reason, AppLocalizations l10n) {
    return switch (reason) {
      SkipReason.disabled => l10n.automationSkipDisabled,
      SkipReason.triggerTypeMismatch => l10n.automationSkipTriggerMismatch,
      SkipReason.throttled => l10n.automationSkipThrottled,
      SkipReason.nodeFilterMismatch => l10n.automationSkipNodeFilter,
      SkipReason.batteryThresholdNotMet => l10n.automationSkipBatteryThreshold,
      SkipReason.keywordNotMatched => l10n.automationSkipKeywordNotMatched,
      SkipReason.signalThresholdNotMet => l10n.automationSkipSignalThreshold,
      SkipReason.channelFilterMismatch => l10n.automationSkipChannelFilter,
      SkipReason.conditionFailed => l10n.automationSkipConditionFailed,
    };
  }
}

/// Merges persisted log entries with in-memory debug evaluations into a
/// unified, deduplicated, time-sorted history list.
class AutomationHistoryMerger {
  AutomationHistoryMerger._();

  /// Build a merged history list. Persisted log entries take priority.
  /// Only non-triggered evaluations (skips) are added from the debug list
  /// to avoid duplicates with executed log entries.
  static List<AutomationHistoryEntry> merge({
    required List<AutomationLogEntry> logEntries,
    required List<AutomationEvaluation> evaluations,
    int maxEntries = 100,
    String? automationId,
  }) {
    final entries = <AutomationHistoryEntry>[];

    // Add all persisted log entries (executions).
    for (final log in logEntries) {
      if (automationId != null && log.automationId != automationId) continue;
      entries.add(AutomationHistoryEntry.fromLogEntry(log));
    }

    // Add skip evaluations that don't have matching log entries.
    final logTimestamps = entries.map((e) => e.timestamp).toSet();
    for (final eval in evaluations) {
      if (automationId != null && eval.automationId != automationId) continue;
      // Only include non-triggered (skip) evaluations, OR triggered-but-none
      // branch selections (condition failed, no ELSE).
      final isSkip =
          !eval.triggered || eval.branchSelection == BranchSelection.none;
      if (!isSkip) continue;
      // Avoid duplicate: skip if a log entry exists within 2 seconds.
      final isDuplicate = logTimestamps.any(
        (t) => t.difference(eval.timestamp).abs() < const Duration(seconds: 2),
      );
      if (isDuplicate) continue;
      entries.add(AutomationHistoryEntry.fromEvaluation(eval));
    }

    // Sort by timestamp descending (most recent first).
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return entries.take(maxEntries).toList();
  }
}
