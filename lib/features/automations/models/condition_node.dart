// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'automation.dart';

/// Node types in a condition evaluation tree.
enum ConditionNodeType {
  /// A single predicate wrapping an [AutomationCondition].
  predicate,

  /// All children must be true (logical AND).
  all,

  /// At least one child must be true (logical OR).
  any,

  /// Inverts the result of its single child (logical NOT).
  not,
}

/// A typed node in a boolean condition evaluation tree.
///
/// This model can represent:
/// - A single [predicate] wrapping an existing [AutomationCondition]
/// - An [all] group (AND) with one or more children
/// - An [any] group (OR) with one or more children
/// - A [not] group inverting exactly one child
///
/// The tree is serializable and designed for future extension (nested groups,
/// richer predicates) while remaining backward-compatible with the legacy
/// flat `conditions[]` list via [fromLegacyConditions].
sealed class ConditionNode {
  const ConditionNode();

  ConditionNodeType get type;

  Map<String, dynamic> toJson();

  /// Deserialize a [ConditionNode] from JSON with type discrimination.
  ///
  /// Returns `null` for malformed payloads rather than throwing, so that
  /// a single corrupt node does not crash deserialization of an entire
  /// automation definition.
  static ConditionNode? fromJson(Map<String, dynamic> json) {
    final typeStr = json['nodeType'] as String?;
    if (typeStr == null) return null;

    switch (typeStr) {
      case 'predicate':
        final conditionJson = json['condition'] as Map<String, dynamic>?;
        if (conditionJson == null) return null;
        return PredicateNode(
          condition: AutomationCondition.fromJson(conditionJson),
        );

      case 'all':
      case 'any':
        final childrenJson = json['children'] as List?;
        if (childrenJson == null || childrenJson.isEmpty) return null;
        final children = <ConditionNode>[];
        for (final childJson in childrenJson) {
          if (childJson is! Map<String, dynamic>) continue;
          final child = ConditionNode.fromJson(childJson);
          if (child != null) children.add(child);
        }
        if (children.isEmpty) return null;
        return typeStr == 'all'
            ? AllGroup(children: children)
            : AnyGroup(children: children);

      case 'not':
        final childJson = json['child'] as Map<String, dynamic>?;
        if (childJson == null) return null;
        final child = ConditionNode.fromJson(childJson);
        if (child == null) return null;
        return NotGroup(child: child);

      default:
        return null;
    }
  }

  /// Lift a legacy flat `conditions` list into a condition tree.
  ///
  /// A flat list of conditions maps to an [AllGroup] containing one
  /// [PredicateNode] per condition (preserving the existing AND semantics).
  ///
  /// Returns `null` if the list is null or empty.
  static ConditionNode? fromLegacyConditions(
    List<AutomationCondition>? conditions,
  ) {
    if (conditions == null || conditions.isEmpty) return null;
    if (conditions.length == 1) {
      return PredicateNode(condition: conditions.first);
    }
    return AllGroup(
      children: conditions.map((c) => PredicateNode(condition: c)).toList(),
    );
  }

  /// Extract a flat list of [AutomationCondition] from the tree for legacy
  /// compatibility (export, share, flat condition display).
  ///
  /// Only meaningful for trees that are purely AND-gated predicates (i.e.,
  /// trees produced by [fromLegacyConditions]). For complex trees with ANY
  /// or NOT nodes, this returns all predicates found via depth-first
  /// traversal — the caller should prefer the tree model instead.
  List<AutomationCondition> toLegacyConditions() {
    return switch (this) {
      PredicateNode(condition: final c) => [c],
      AllGroup(children: final ch) =>
        ch.expand((c) => c.toLegacyConditions()).toList(),
      AnyGroup(children: final ch) =>
        ch.expand((c) => c.toLegacyConditions()).toList(),
      NotGroup(child: final ch) => ch.toLegacyConditions(),
    };
  }
}

/// A leaf node wrapping a single [AutomationCondition].
class PredicateNode extends ConditionNode {
  final AutomationCondition condition;

  const PredicateNode({required this.condition});

  @override
  ConditionNodeType get type => ConditionNodeType.predicate;

  @override
  Map<String, dynamic> toJson() => {
    'nodeType': 'predicate',
    'condition': condition.toJson(),
  };
}

/// An AND group: all children must evaluate to true.
class AllGroup extends ConditionNode {
  final List<ConditionNode> children;

  const AllGroup({required this.children});

  @override
  ConditionNodeType get type => ConditionNodeType.all;

  @override
  Map<String, dynamic> toJson() => {
    'nodeType': 'all',
    'children': children.map((c) => c.toJson()).toList(),
  };
}

/// An OR group: at least one child must evaluate to true.
class AnyGroup extends ConditionNode {
  final List<ConditionNode> children;

  const AnyGroup({required this.children});

  @override
  ConditionNodeType get type => ConditionNodeType.any;

  @override
  Map<String, dynamic> toJson() => {
    'nodeType': 'any',
    'children': children.map((c) => c.toJson()).toList(),
  };
}

/// A NOT group: inverts the result of its single child.
class NotGroup extends ConditionNode {
  final ConditionNode child;

  const NotGroup({required this.child});

  @override
  ConditionNodeType get type => ConditionNodeType.not;

  @override
  Map<String, dynamic> toJson() => {'nodeType': 'not', 'child': child.toJson()};
}
