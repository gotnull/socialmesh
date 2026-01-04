import 'dart:convert';

import 'package:flutter/services.dart';

import '../../utils/share_utils.dart';
import 'automation_repository.dart';
import 'models/automation.dart';

/// Reasons why an automation was skipped
enum SkipReason {
  disabled('Disabled'),
  triggerTypeMismatch('Trigger type mismatch'),
  throttled('Throttled'),
  nodeFilterMismatch('Node filter mismatch'),
  batteryThresholdNotMet('Battery threshold not met'),
  keywordNotMatched('Keyword not matched'),
  signalThresholdNotMet('Signal threshold not met'),
  channelFilterMismatch('Channel filter mismatch'),
  conditionFailed('Condition failed');

  final String displayName;
  const SkipReason(this.displayName);
}

/// Result of evaluating a single condition
class ConditionEvaluation {
  final ConditionType type;
  final bool passed;
  final String details;

  const ConditionEvaluation({
    required this.type,
    required this.passed,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'typeDisplayName': type.displayName,
    'passed': passed,
    'details': details,
  };
}

/// Record of a single automation evaluation
class AutomationEvaluation {
  final String automationId;
  final String automationName;
  final bool enabled;
  final TriggerType triggerType;
  final TriggerType eventType;
  final DateTime timestamp;
  final bool triggered;
  final SkipReason? skipReason;
  final String? skipDetails;
  final Map<String, dynamic> eventData;
  final Map<String, dynamic> triggerConfig;
  final List<ConditionEvaluation>? conditionResults;

  const AutomationEvaluation({
    required this.automationId,
    required this.automationName,
    required this.enabled,
    required this.triggerType,
    required this.eventType,
    required this.timestamp,
    required this.triggered,
    this.skipReason,
    this.skipDetails,
    this.eventData = const {},
    this.triggerConfig = const {},
    this.conditionResults,
  });

  Map<String, dynamic> toJson() => {
    'automationId': automationId,
    'automationName': automationName,
    'enabled': enabled,
    'triggerType': triggerType.name,
    'triggerTypeDisplayName': triggerType.displayName,
    'eventType': eventType.name,
    'eventTypeDisplayName': eventType.displayName,
    'timestamp': timestamp.toIso8601String(),
    'triggered': triggered,
    'skipReason': skipReason?.name,
    'skipReasonDisplayName': skipReason?.displayName,
    'skipDetails': skipDetails,
    'eventData': eventData,
    'triggerConfig': triggerConfig,
    'conditionResults': conditionResults?.map((c) => c.toJson()).toList(),
  };
}

/// Complete snapshot for debugging
class AutomationDebugSnapshot {
  final DateTime timestamp;
  final List<Automation> automations;
  final List<AutomationEvaluation> evaluations;
  final Map<String, dynamic> engineState;

  const AutomationDebugSnapshot({
    required this.timestamp,
    required this.automations,
    required this.evaluations,
    required this.engineState,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'automations': automations.map((a) => a.toJson()).toList(),
    'recentEvaluations': evaluations.map((e) => e.toJson()).toList(),
    'engineState': engineState,
    'summary': {
      'totalAutomations': automations.length,
      'enabledAutomations': automations.where((a) => a.enabled).length,
      'totalEvaluations': evaluations.length,
      'triggeredCount': evaluations.where((e) => e.triggered).length,
      'skippedCount': evaluations.where((e) => !e.triggered).length,
    },
  };
}

/// Service for tracking and exporting automation debug information
class AutomationDebugService {
  static const int maxEvaluations = 500;

  final List<AutomationEvaluation> _evaluations = [];
  Map<String, dynamic> _lastEngineState = {};

  List<AutomationEvaluation> get evaluations =>
      List.unmodifiable(_evaluations.reversed);

  /// Record an evaluation result
  void recordEvaluation(AutomationEvaluation evaluation) {
    _evaluations.add(evaluation);
    // Keep list bounded
    while (_evaluations.length > maxEvaluations) {
      _evaluations.removeAt(0);
    }
  }

  /// Update engine state for debugging
  void updateEngineState(Map<String, dynamic> state) {
    _lastEngineState = state;
  }

  /// Clear evaluation history
  void clearHistory() {
    _evaluations.clear();
  }

  /// Get summary statistics
  Map<String, int> getSummary() {
    final triggered = _evaluations.where((e) => e.triggered).length;
    return {
      'total': _evaluations.length,
      'triggered': triggered,
      'skipped': _evaluations.length - triggered,
    };
  }

  /// Get skip reasons breakdown
  Map<SkipReason, int> getSkipReasonsSummary() {
    final counts = <SkipReason, int>{};
    for (final eval in _evaluations) {
      if (eval.skipReason != null) {
        counts[eval.skipReason!] = (counts[eval.skipReason!] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Create a debug snapshot
  AutomationDebugSnapshot createSnapshot(AutomationRepository repository) {
    return AutomationDebugSnapshot(
      timestamp: DateTime.now(),
      automations: repository.automations,
      evaluations: _evaluations.toList(),
      engineState: _lastEngineState,
    );
  }

  /// Export debug data as JSON string
  String exportDebugJson(AutomationRepository repository) {
    final json = createSnapshot(repository);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json.toJson());
  }

  /// Copy debug data to clipboard
  Future<void> copyDebugToClipboard(AutomationRepository repository) async {
    final jsonStr = exportDebugJson(repository);
    await Clipboard.setData(ClipboardData(text: jsonStr));
  }

  /// Share debug data
  Future<void> shareDebugJson(AutomationRepository repository) async {
    final jsonStr = exportDebugJson(repository);
    await shareText(jsonStr, subject: 'Socialmesh Automation Debug Export');
  }
}
