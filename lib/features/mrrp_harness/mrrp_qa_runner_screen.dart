// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../services/haptic_service.dart';
import 'models/mrrp_qa_scenario.dart';

/// QA Scenario Runner — guided test sequences through MRRP protocol flows.
class MrrpQaRunnerScreen extends ConsumerStatefulWidget {
  const MrrpQaRunnerScreen({super.key});

  @override
  ConsumerState<MrrpQaRunnerScreen> createState() => _MrrpQaRunnerScreenState();
}

class _MrrpQaRunnerScreenState extends ConsumerState<MrrpQaRunnerScreen> {
  late final List<QaScenario> _scenarios;

  @override
  void initState() {
    super.initState();
    _scenarios = buildQaScenarios();
  }

  void _runScenario(int scenarioIndex) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);

    final scenario = _scenarios[scenarioIndex];
    scenario.reset();

    AppLogging.mrrpHarness(
      'MRRP_QA: scenario "${scenario.name}" started, ${scenario.steps.length} steps', // lint-allow: hardcoded-string
    );

    for (var i = 0; i < scenario.steps.length; i++) {
      final step = scenario.steps[i];
      final passed = step.verify(null);
      step.status = passed ? QaStepStatus.pass : QaStepStatus.fail;
      step.actualOutcome = passed
          ? step.expectedOutcome
          : 'Verification failed'; // lint-allow: hardcoded-string

      AppLogging.mrrpHarness(
        'MRRP_QA: step ${i + 1}/${scenario.steps.length} "${step.description}" ' // lint-allow: hardcoded-string
        '-> ${passed ? "PASS" : "FAIL"}',
      );
    }

    AppLogging.mrrpHarness(
      'MRRP_QA: scenario ${scenario.passed ? "PASSED" : "FAILED"} ' // lint-allow: hardcoded-string
      '(${scenario.passedCount}/${scenario.steps.length} steps)',
    );

    setState(() {});
  }

  void _runAll() {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);

    for (var i = 0; i < _scenarios.length; i++) {
      _runScenario(i);
    }

    final passed = _scenarios.where((s) => s.passed).length;
    AppLogging.mrrpHarness(
      'MRRP_QA: all scenarios complete -> $passed/${_scenarios.length} passed', // lint-allow: hardcoded-string
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final hasResults = _scenarios.any((s) => s.hasRun);
    final passedCount = _scenarios.where((s) => s.passed).length;
    final total = _scenarios.length;

    return GlassScaffold(
      title: l10n.mrrpHarnessQaTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          tooltip: l10n.mrrpHarnessQaRunAll,
          onPressed: _runAll,
        ),
      ],
      slivers: [
        // Summary bar
        if (hasResults)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing8,
            ),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: passedCount == total
                      ? SemanticColors.success.withValues(alpha: 0.15)
                      : SemanticColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  l10n.mrrpHarnessQaSummary(passedCount, total),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: passedCount == total
                        ? SemanticColors.success
                        : SemanticColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        // Scenarios section
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessQaScenarios,
            count: _scenarios.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ScenarioTile(
                scenario: _scenarios[index],
                onRun: () => _runScenario(index),
              ),
              childCount: _scenarios.length,
            ),
          ),
        ),

        // Bottom padding
        const SliverPadding(
          padding: EdgeInsets.only(bottom: AppTheme.spacing32),
        ),
      ],
    );
  }
}

/// Tile showing a single QA scenario with expandable steps.
class _ScenarioTile extends StatefulWidget {
  final QaScenario scenario;
  final VoidCallback onRun;

  const _ScenarioTile({required this.scenario, required this.onRun});

  @override
  State<_ScenarioTile> createState() => _ScenarioTileState();
}

class _ScenarioTileState extends State<_ScenarioTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.scenario;
    final hasRun = s.hasRun;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: name + pass/fail badge + run button
                Row(
                  children: [
                    if (hasRun)
                      Icon(
                        s.passed ? Icons.check_circle : Icons.cancel,
                        size: 20,
                        color: s.passed
                            ? SemanticColors.success
                            : SemanticColors.error,
                      )
                    else
                      Icon(
                        Icons.pending_outlined,
                        size: 20,
                        color: context.textTertiary,
                      ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            l10n.mrrpHarnessQaSteps(s.steps.length),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (hasRun)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing8,
                          vertical: AppTheme.spacing2,
                        ),
                        decoration: BoxDecoration(
                          color: s.passed
                              ? SemanticColors.success.withValues(alpha: 0.15)
                              : SemanticColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radius4),
                        ),
                        child: Text(
                          s.passed
                              ? l10n.mrrpHarnessQaScenarioPass
                              : l10n.mrrpHarnessQaScenarioFail,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: s.passed
                                    ? SemanticColors.success
                                    : SemanticColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    const SizedBox(width: AppTheme.spacing8),
                    TextButton(
                      onPressed: widget.onRun,
                      child: Text(l10n.mrrpHarnessQaRunScenario),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: context.textTertiary,
                    ),
                  ],
                ),

                // Expanded step details
                if (_expanded)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 28,
                      top: AppTheme.spacing8,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < s.steps.length; i++)
                          _StepRow(step: s.steps[i], index: i + 1),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single step row inside an expanded scenario.
class _StepRow extends StatelessWidget {
  final QaStep step;
  final int index;

  const _StepRow({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final Color statusColor;
    final String statusText;
    switch (step.status) {
      case QaStepStatus.pass:
        statusColor = SemanticColors.success;
        statusText = l10n.mrrpHarnessQaStepPass;
      case QaStepStatus.fail:
        statusColor = SemanticColors.error;
        statusText = l10n.mrrpHarnessQaStepFail;
      case QaStepStatus.pending:
        statusColor = context.textTertiary;
        statusText = l10n.mrrpHarnessQaStepPending;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppTheme.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${l10n.mrrpHarnessQaExpected}: ${step.expectedOutcome}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing2,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius4),
            ),
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
