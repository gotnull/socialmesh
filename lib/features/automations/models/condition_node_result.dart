// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'condition_node.dart';
import 'automation.dart';

/// Result of evaluating a single [ConditionNode] in the condition tree.
///
/// Forms a tree of results mirroring the [ConditionNode] tree structure,
/// capturing per-node pass/fail, child results for groups, and detail
/// payloads for predicates.
sealed class ConditionNodeResult {
  const ConditionNodeResult();

  /// The type of node that was evaluated.
  ConditionNodeType get nodeType;

  /// Whether this node evaluated to true.
  bool get passed;

  Map<String, dynamic> toJson();
}

/// Result of evaluating a [PredicateNode].
class PredicateResult extends ConditionNodeResult {
  @override
  final bool passed;

  /// The condition type that was evaluated.
  final ConditionType conditionType;

  /// Human-readable detail about the evaluation (e.g. "timeRange: passed").
  final String detail;

  const PredicateResult({
    required this.passed,
    required this.conditionType,
    required this.detail,
  });

  @override
  ConditionNodeType get nodeType => ConditionNodeType.predicate;

  @override
  Map<String, dynamic> toJson() => {
    'nodeType': 'predicate',
    'passed': passed,
    'conditionType': conditionType.name,
    'detail': detail,
  };
}

/// Result of evaluating an [AllGroup] (AND).
class AllGroupResult extends ConditionNodeResult {
  @override
  final bool passed;

  /// Results for each child node.
  final List<ConditionNodeResult> childResults;

  const AllGroupResult({required this.passed, required this.childResults});

  @override
  ConditionNodeType get nodeType => ConditionNodeType.all;

  @override
  Map<String, dynamic> toJson() => {
    'nodeType': 'all',
    'passed': passed,
    'childResults': childResults.map((r) => r.toJson()).toList(),
  };
}

/// Result of evaluating an [AnyGroup] (OR).
class AnyGroupResult extends ConditionNodeResult {
  @override
  final bool passed;

  /// Results for each child node.
  final List<ConditionNodeResult> childResults;

  const AnyGroupResult({required this.passed, required this.childResults});

  @override
  ConditionNodeType get nodeType => ConditionNodeType.any;

  @override
  Map<String, dynamic> toJson() => {
    'nodeType': 'any',
    'passed': passed,
    'childResults': childResults.map((r) => r.toJson()).toList(),
  };
}

/// Result of evaluating a [NotGroup].
class NotGroupResult extends ConditionNodeResult {
  @override
  final bool passed;

  /// Result of the inner child (before inversion).
  final ConditionNodeResult childResult;

  const NotGroupResult({required this.passed, required this.childResult});

  @override
  ConditionNodeType get nodeType => ConditionNodeType.not;

  @override
  Map<String, dynamic> toJson() => {
    'nodeType': 'not',
    'passed': passed,
    'childResult': childResult.toJson(),
  };
}
