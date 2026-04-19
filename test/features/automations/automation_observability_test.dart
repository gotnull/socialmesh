// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/automation_debug_service.dart';
import 'package:socialmesh/features/automations/automation_history_presenter.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/automations/models/condition_node_result.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

AppLocalizations get _l10n => lookupAppLocalizations(const Locale('en'));

AutomationLogEntry _logEntry({
  bool success = true,
  String? branchSelection,
  bool manualBypass = false,
  String? conditionSummary,
  String? errorMessage,
  List<ActionResult>? actionResults,
}) {
  return AutomationLogEntry(
    automationId: 'test-1',
    automationName: 'Test Automation',
    timestamp: DateTime(2026, 4, 14, 10, 0),
    success: success,
    triggerEventType: 'messageReceived',
    actionsExecuted: ['sendMessage'],
    branchSelection: branchSelection,
    manualBypass: manualBypass,
    conditionSummary: conditionSummary,
    errorMessage: errorMessage,
    actionResults: actionResults,
  );
}

AutomationEvaluation _evaluation({
  bool triggered = false,
  SkipReason? skipReason,
  BranchSelection? branchSelection,
  bool manualBypass = false,
  ConditionNodeResult? conditionTreeResult,
}) {
  return AutomationEvaluation(
    automationId: 'test-1',
    automationName: 'Test Automation',
    enabled: true,
    triggerType: TriggerType.messageReceived,
    eventType: TriggerType.messageReceived,
    timestamp: DateTime(2026, 4, 14, 10, 0),
    triggered: triggered,
    skipReason: skipReason,
    branchSelection: branchSelection,
    manualBypass: manualBypass,
    conditionTreeResult: conditionTreeResult,
  );
}

void main() {
  group('Phase 5 Observability -', () {
    group('AutomationLogEntry extended fields', () {
      test('new fields serialize and deserialize correctly', () {
        final entry = _logEntry(
          branchSelection: 'then',
          manualBypass: true,
          conditionSummary: 'All 2 conditions passed',
        );

        final json = entry.toJson();
        expect(json['branchSelection'], 'then');
        expect(json['manualBypass'], true);
        expect(json['conditionSummary'], 'All 2 conditions passed');

        final restored = AutomationLogEntry.fromJson(json);
        expect(restored.branchSelection, 'then');
        expect(restored.manualBypass, true);
        expect(restored.conditionSummary, 'All 2 conditions passed');
      });

      test('legacy entries without new fields deserialize safely', () {
        final json = {
          'automationId': 'legacy',
          'automationName': 'Legacy',
          'timestamp': '2026-01-01T00:00:00.000',
          'success': true,
          'actionsExecuted': ['sendMessage'],
        };
        final entry = AutomationLogEntry.fromJson(json);
        expect(entry.branchSelection, isNull);
        expect(entry.manualBypass, false);
        expect(entry.conditionSummary, isNull);
      });

      test('null branch fields omitted from JSON', () {
        final entry = _logEntry();
        final json = entry.toJson();
        expect(json.containsKey('branchSelection'), false);
        expect(json.containsKey('conditionSummary'), false);
        // manualBypass defaults to false → omitted
        expect(json.containsKey('manualBypass'), false);
      });
    });

    group('RunOutcome mapping', () {
      test('THEN branch log entry maps to executedThen', () {
        final entry = AutomationHistoryEntry.fromLogEntry(
          _logEntry(branchSelection: 'then'),
        );
        expect(entry.outcome, RunOutcome.executedThen);
      });

      test('ELSE branch log entry maps to executedElse', () {
        final entry = AutomationHistoryEntry.fromLogEntry(
          _logEntry(branchSelection: 'else'),
        );
        expect(entry.outcome, RunOutcome.executedElse);
      });

      test('legacy success maps to executed', () {
        final entry = AutomationHistoryEntry.fromLogEntry(_logEntry());
        expect(entry.outcome, RunOutcome.executed);
      });

      test('failed maps to failed', () {
        final entry = AutomationHistoryEntry.fromLogEntry(
          _logEntry(success: false, errorMessage: 'Network error'),
        );
        expect(entry.outcome, RunOutcome.failed);
      });

      test('manual bypass maps to manualRun', () {
        final entry = AutomationHistoryEntry.fromLogEntry(
          _logEntry(manualBypass: true),
        );
        expect(entry.outcome, RunOutcome.manualRun);
      });

      test('evaluation skip throttled maps correctly', () {
        final entry = AutomationHistoryEntry.fromEvaluation(
          _evaluation(skipReason: SkipReason.throttled),
        );
        expect(entry.outcome, RunOutcome.skippedThrottled);
      });

      test('evaluation skip disabled maps correctly', () {
        final entry = AutomationHistoryEntry.fromEvaluation(
          _evaluation(skipReason: SkipReason.disabled),
        );
        expect(entry.outcome, RunOutcome.skippedDisabled);
      });

      test('evaluation skip condition failed maps correctly', () {
        final entry = AutomationHistoryEntry.fromEvaluation(
          _evaluation(skipReason: SkipReason.conditionFailed),
        );
        expect(entry.outcome, RunOutcome.skippedNoElse);
      });

      test('evaluation skip filter mismatch maps correctly', () {
        final entry = AutomationHistoryEntry.fromEvaluation(
          _evaluation(skipReason: SkipReason.nodeFilterMismatch),
        );
        expect(entry.outcome, RunOutcome.skippedFiltered);
      });

      test('triggered but none branch maps to skippedNoElse', () {
        final entry = AutomationHistoryEntry.fromEvaluation(
          _evaluation(triggered: true, branchSelection: BranchSelection.none),
        );
        expect(entry.outcome, RunOutcome.skippedNoElse);
      });
    });

    group('RunOutcomePresenter', () {
      test('isSuccess returns true for execution outcomes', () {
        expect(RunOutcomePresenter.isSuccess(RunOutcome.executedThen), true);
        expect(RunOutcomePresenter.isSuccess(RunOutcome.executedElse), true);
        expect(RunOutcomePresenter.isSuccess(RunOutcome.executed), true);
        expect(RunOutcomePresenter.isSuccess(RunOutcome.manualRun), true);
        expect(RunOutcomePresenter.isSuccess(RunOutcome.failed), false);
        expect(RunOutcomePresenter.isSuccess(RunOutcome.skippedNoElse), false);
      });

      test('isSkip returns true for skip outcomes', () {
        expect(RunOutcomePresenter.isSkip(RunOutcome.skippedNoElse), true);
        expect(RunOutcomePresenter.isSkip(RunOutcome.skippedThrottled), true);
        expect(RunOutcomePresenter.isSkip(RunOutcome.skippedDisabled), true);
        expect(RunOutcomePresenter.isSkip(RunOutcome.skippedFiltered), true);
        expect(RunOutcomePresenter.isSkip(RunOutcome.executedThen), false);
        expect(RunOutcomePresenter.isSkip(RunOutcome.failed), false);
      });

      test('labels are localized and non-empty', () {
        final l10n = _l10n;
        for (final outcome in RunOutcome.values) {
          final label = RunOutcomePresenter.label(outcome, l10n);
          expect(label.isNotEmpty, true, reason: 'Outcome $outcome has label');
        }
      });
    });

    group('ConditionResultPresenter', () {
      test('summarizes PredicateResult passed', () {
        const result = PredicateResult(
          passed: true,
          conditionType: ConditionType.batteryBelow,
          detail: 'battery: 15%',
        );
        final summary = ConditionResultPresenter.summarize(result);
        expect(summary, contains('Battery below threshold'));
        expect(summary, contains('passed'));
      });

      test('summarizes PredicateResult failed', () {
        const result = PredicateResult(
          passed: false,
          conditionType: ConditionType.dayOfWeek,
          detail: 'dayOfWeek: not Monday',
        );
        final summary = ConditionResultPresenter.summarize(result);
        expect(summary, contains('On specific days'));
        expect(summary, contains('failed'));
      });

      test('summarizes AllGroupResult all passed', () {
        const result = AllGroupResult(
          passed: true,
          childResults: [
            PredicateResult(
              passed: true,
              conditionType: ConditionType.timeRange,
              detail: '',
            ),
            PredicateResult(
              passed: true,
              conditionType: ConditionType.dayOfWeek,
              detail: '',
            ),
          ],
        );
        final summary = ConditionResultPresenter.summarize(result);
        expect(summary, 'All 2 conditions passed');
      });

      test('summarizes AllGroupResult some failed', () {
        const result = AllGroupResult(
          passed: false,
          childResults: [
            PredicateResult(
              passed: true,
              conditionType: ConditionType.timeRange,
              detail: '',
            ),
            PredicateResult(
              passed: false,
              conditionType: ConditionType.dayOfWeek,
              detail: '',
            ),
          ],
        );
        final summary = ConditionResultPresenter.summarize(result);
        expect(summary, '1 of 2 conditions failed');
      });

      test('summarizes AnyGroupResult some matched', () {
        const result = AnyGroupResult(
          passed: true,
          childResults: [
            PredicateResult(
              passed: true,
              conditionType: ConditionType.nodeOnline,
              detail: '',
            ),
            PredicateResult(
              passed: false,
              conditionType: ConditionType.batteryAbove,
              detail: '',
            ),
          ],
        );
        final summary = ConditionResultPresenter.summarize(result);
        expect(summary, '1 of 2 conditions matched');
      });

      test('summarizes AnyGroupResult none matched', () {
        const result = AnyGroupResult(
          passed: false,
          childResults: [
            PredicateResult(
              passed: false,
              conditionType: ConditionType.nodeOnline,
              detail: '',
            ),
          ],
        );
        final summary = ConditionResultPresenter.summarize(result);
        expect(summary, 'No conditions matched');
      });

      test('summarizes NotGroupResult', () {
        const result = NotGroupResult(
          passed: true,
          childResult: PredicateResult(
            passed: false,
            conditionType: ConditionType.nodeOffline,
            detail: '',
          ),
        );
        expect(
          ConditionResultPresenter.summarize(result),
          'NOT condition passed',
        );
      });

      test('localized summary produces non-empty strings', () {
        final l10n = _l10n;
        const result = AllGroupResult(
          passed: true,
          childResults: [
            PredicateResult(
              passed: true,
              conditionType: ConditionType.timeRange,
              detail: '',
            ),
          ],
        );
        final summary = ConditionResultPresenter.localizedSummary(result, l10n);
        expect(summary.isNotEmpty, true);
      });

      test('details returns flat list from nested tree', () {
        const result = AllGroupResult(
          passed: false,
          childResults: [
            PredicateResult(
              passed: true,
              conditionType: ConditionType.timeRange,
              detail: 'time: 09:00-17:00',
            ),
            PredicateResult(
              passed: false,
              conditionType: ConditionType.dayOfWeek,
              detail: 'day: Monday',
            ),
          ],
        );
        final details = ConditionResultPresenter.details(result);
        expect(details.length, 2);
        expect(details[0].passed, true);
        expect(details[1].passed, false);
      });
    });

    group('SkipReasonPresenter', () {
      test('all skip reasons have localized labels', () {
        final l10n = _l10n;
        for (final reason in SkipReason.values) {
          final label = SkipReasonPresenter.label(reason, l10n);
          expect(
            label.isNotEmpty,
            true,
            reason: 'SkipReason $reason has label',
          );
        }
      });
    });

    group('AutomationHistoryMerger', () {
      test('merges log entries and skip evaluations', () {
        final logs = [_logEntry(branchSelection: 'then')];
        // Use different timestamps to avoid dedup collision
        final result = AutomationHistoryMerger.merge(
          logEntries: logs,
          evaluations: [
            AutomationEvaluation(
              automationId: 'test-1',
              automationName: 'Test Automation',
              enabled: true,
              triggerType: TriggerType.messageReceived,
              eventType: TriggerType.messageReceived,
              timestamp: DateTime(2026, 4, 14, 9, 50),
              triggered: false,
              skipReason: SkipReason.throttled,
            ),
          ],
        );
        expect(result.length, 2);
      });

      test('deduplicates evaluations close in time to log entries', () {
        final ts = DateTime(2026, 4, 14, 10, 0);
        final logs = [
          AutomationLogEntry(
            automationId: 'test-1',
            automationName: 'Test',
            timestamp: ts,
            success: true,
            actionsExecuted: ['sendMessage'],
          ),
        ];
        final evals = [
          AutomationEvaluation(
            automationId: 'test-1',
            automationName: 'Test',
            enabled: true,
            triggerType: TriggerType.messageReceived,
            eventType: TriggerType.messageReceived,
            timestamp: ts.add(const Duration(milliseconds: 500)),
            triggered: true,
            branchSelection: BranchSelection.none,
          ),
        ];
        final result = AutomationHistoryMerger.merge(
          logEntries: logs,
          evaluations: evals,
        );
        // Skip eval is within 2s of log entry → deduped
        expect(result.length, 1);
      });

      test('filters by automationId when provided', () {
        final logs = [
          AutomationLogEntry(
            automationId: 'a1',
            automationName: 'A1',
            timestamp: DateTime(2026, 4, 14, 10, 0),
            success: true,
            actionsExecuted: [],
          ),
          AutomationLogEntry(
            automationId: 'a2',
            automationName: 'A2',
            timestamp: DateTime(2026, 4, 14, 9, 0),
            success: true,
            actionsExecuted: [],
          ),
        ];
        final result = AutomationHistoryMerger.merge(
          logEntries: logs,
          evaluations: [],
          automationId: 'a1',
        );
        expect(result.length, 1);
        expect(result.first.automationId, 'a1');
      });

      test('sorts by timestamp descending', () {
        final early = DateTime(2026, 4, 14, 8, 0);
        final late = DateTime(2026, 4, 14, 12, 0);
        final logs = [
          AutomationLogEntry(
            automationId: 'a',
            automationName: 'A',
            timestamp: early,
            success: true,
            actionsExecuted: [],
          ),
          AutomationLogEntry(
            automationId: 'a',
            automationName: 'A',
            timestamp: late,
            success: true,
            actionsExecuted: [],
          ),
        ];
        final result = AutomationHistoryMerger.merge(
          logEntries: logs,
          evaluations: [],
        );
        expect(result.first.timestamp, late);
        expect(result.last.timestamp, early);
      });
    });

    group('ActionResult display', () {
      test('log entry with action results tracks success/fail counts', () {
        final entry = _logEntry(
          success: false,
          actionResults: [
            ActionResult(actionName: 'sendMessage', success: true),
            ActionResult(
              actionName: 'playSound',
              success: false,
              errorMessage: 'File not found',
            ),
          ],
        );
        expect(entry.successfulActionCount, 1);
        expect(entry.failedActionCount, 1);
        expect(entry.hasFailedActions, true);
      });
    });

    group('Phase 5.1 — Manual Run Clarity', () {
      test('manual run outcome is distinct from automatic THEN execution', () {
        final manualEntry = _logEntry(
          branchSelection: 'then',
          manualBypass: true,
        );
        final autoEntry = _logEntry(
          branchSelection: 'then',
          manualBypass: false,
        );

        final manualHistory = AutomationHistoryEntry.fromLogEntry(manualEntry);
        final autoHistory = AutomationHistoryEntry.fromLogEntry(autoEntry);

        expect(manualHistory.outcome, RunOutcome.manualRun);
        expect(autoHistory.outcome, RunOutcome.executedThen);
        expect(manualHistory.outcome, isNot(autoHistory.outcome));
      });

      test('manual run label does not imply condition pass', () {
        final label = RunOutcomePresenter.label(RunOutcome.manualRun, _l10n);
        final thenLabel = RunOutcomePresenter.label(
          RunOutcome.executedThen,
          _l10n,
        );

        // Manual label should contain 'manually' to clarify forced execution
        expect(label.toLowerCase(), contains('manually'));
        // Must differ from the automatic THEN label
        expect(label, isNot(thenLabel));
      });

      test('isManualRun returns true only for manualRun outcome', () {
        expect(RunOutcomePresenter.isManualRun(RunOutcome.manualRun), true);
        expect(RunOutcomePresenter.isManualRun(RunOutcome.executedThen), false);
        expect(RunOutcomePresenter.isManualRun(RunOutcome.executed), false);
        expect(RunOutcomePresenter.isManualRun(RunOutcome.failed), false);
      });

      test('manual run is still classified as success', () {
        expect(RunOutcomePresenter.isSuccess(RunOutcome.manualRun), true);
        expect(RunOutcomePresenter.isSkip(RunOutcome.manualRun), false);
      });

      test('automatic THEN execution still renders correctly', () {
        final label = RunOutcomePresenter.label(RunOutcome.executedThen, _l10n);
        expect(label, isNotEmpty);
        expect(RunOutcomePresenter.isSuccess(RunOutcome.executedThen), true);
        expect(RunOutcomePresenter.isManualRun(RunOutcome.executedThen), false);
      });

      test('skipped and ELSE outcomes remain unchanged', () {
        expect(RunOutcomePresenter.isSkip(RunOutcome.skippedNoElse), true);
        expect(RunOutcomePresenter.isSkip(RunOutcome.skippedThrottled), true);
        expect(RunOutcomePresenter.isSuccess(RunOutcome.executedElse), true);
        expect(RunOutcomePresenter.isManualRun(RunOutcome.executedElse), false);
      });

      test('manual run from evaluation maps to manualRun outcome', () {
        final eval = _evaluation(
          triggered: true,
          branchSelection: BranchSelection.thenBranch,
          manualBypass: true,
        );
        final entry = AutomationHistoryEntry.fromEvaluation(eval);
        expect(entry.outcome, RunOutcome.manualRun);
        expect(entry.manualBypass, true);
      });

      test('manual bypass detail wording explains forced execution', () {
        // Verify the localized string contains key concepts
        final bypassText = _l10n.automationHistoryDetailManualBypass;
        expect(bypassText.toLowerCase(), contains('not evaluated'));

        final noteText = _l10n.automationHistoryDetailManualNote;
        expect(noteText.toLowerCase(), contains('automatic'));
      });

      test('card trust signal text for manual runs is distinct', () {
        final manualLabel = _l10n.automationCardLastRunManual;
        final autoLabel = _l10n.automationCardLastRun(
          RunOutcomePresenter.label(RunOutcome.executedThen, _l10n),
        );

        expect(manualLabel, isNot(autoLabel));
        expect(manualLabel.toLowerCase(), contains('manual'));
      });
    });
  });
}
