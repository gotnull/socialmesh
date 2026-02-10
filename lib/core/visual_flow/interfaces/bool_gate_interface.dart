// SPDX-License-Identifier: GPL-3.0-or-later
// Custom interface type for the Socialmesh visual automation flow builder.
//
// BoolGate interfaces carry condition pass/fail signals through the automation
// graph. They represent the boolean result of a condition or logic gate node,
// allowing downstream nodes to branch based on whether a condition was met.
//
// Color: Cyan — visually distinct from the amber event signal wires, making
// it easy for users to distinguish "event flow" from "condition evaluation"
// at a glance.
//
// BoolGate inputs accept connections from both BoolGateOutputData and the
// standard VSBoolOutputData, allowing interoperability with any node that
// produces a boolean result.

import 'package:flutter/material.dart';

import '../vs_node_view/data/standard_interfaces/vs_bool_interface.dart';
import '../vs_node_view/data/vs_interface.dart';

/// Cyan color for condition/logic gate wires.
///
/// Chosen to be visually distinct from the amber event signal color and the
/// green action signal color, making the three signal types immediately
/// distinguishable on the canvas.
const Color kBoolGateColor = Color(0xFF22D3EE);

/// Input interface that accepts a boolean gate signal.
///
/// Used on logic gate nodes (AND, OR, NOT) and on action nodes that need to
/// be conditionally gated. A bool gate input represents a question: "Should
/// this path continue?"
///
/// Accepts connections from:
/// - [BoolGateOutputData] — the primary condition/logic gate output type.
/// - [VSBoolOutputData] — the standard vs_node_view boolean output, allowing
///   interoperability with any generic boolean-producing node.
class BoolGateInputData extends VSInputData {
  BoolGateInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [BoolGateOutputData, VSBoolOutputData];

  @override
  Color get interfaceColor => kBoolGateColor;
}

/// Output interface that emits a boolean gate signal.
///
/// Used on condition nodes and logic gate nodes — any node that evaluates
/// a boolean expression and forwards the result downstream.
///
/// The [outputFunction] receives a map of the node's evaluated input values
/// and returns a [BoolGatePayload] describing the condition result and any
/// metadata about how the condition was evaluated.
class BoolGateOutputData extends VSOutputData<BoolGatePayload> {
  BoolGateOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => kBoolGateColor;
}

/// The payload carried by a bool gate wire.
///
/// This data structure flows through the graph at compile time (when the
/// user saves the flow) and at design-time preview. It captures the result
/// of a condition evaluation along with enough metadata for the compiler
/// to reconstruct the corresponding [AutomationCondition] model.
///
/// At runtime, the actual condition evaluation is handled by
/// [AutomationEngine._evaluateCondition] — this payload is used only for
/// graph compilation and visual feedback, not for live event processing.
class BoolGatePayload {
  const BoolGatePayload({
    required this.conditionType,
    this.config = const {},
    this.result = true,
    this.inverted = false,
  });

  /// The condition type that produced this boolean result.
  ///
  /// Stored as a string to avoid a hard dependency on the automation model
  /// enum from within the interface layer. The compiler maps this back to
  /// [ConditionType] when building the [AutomationCondition] object.
  final String conditionType;

  /// The raw condition configuration map.
  ///
  /// Contains threshold values, time ranges, day-of-week lists, node numbers,
  /// and other condition-specific parameters. Passed through to the compiled
  /// [AutomationCondition.config].
  final Map<String, dynamic> config;

  /// The boolean result of this condition evaluation.
  ///
  /// At design time this represents a preview/default state. At compile time
  /// it is always set to true — the actual runtime evaluation is deferred to
  /// the [AutomationEngine].
  ///
  /// For visual feedback, a false result can dim downstream wires and nodes
  /// to indicate that this path would not fire under current conditions.
  final bool result;

  /// Whether this condition's result should be logically inverted.
  ///
  /// When true, the compiler wraps this condition in a NOT gate. This allows
  /// a single condition node type (e.g. "Node Online") to serve double duty
  /// as its inverse ("Node Offline") without requiring a separate node type.
  final bool inverted;

  /// The effective boolean result after applying [inverted].
  bool get effectiveResult => inverted ? !result : result;

  /// Creates a copy with the given fields replaced.
  BoolGatePayload copyWith({
    String? conditionType,
    Map<String, dynamic>? config,
    bool? result,
    bool? inverted,
  }) {
    return BoolGatePayload(
      conditionType: conditionType ?? this.conditionType,
      config: config ?? this.config,
      result: result ?? this.result,
      inverted: inverted ?? this.inverted,
    );
  }

  @override
  String toString() {
    return 'BoolGatePayload(condition: $conditionType, result: $result, '
        'inverted: $inverted, effective: $effectiveResult)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BoolGatePayload &&
        other.conditionType == conditionType &&
        other.result == result &&
        other.inverted == inverted;
  }

  @override
  int get hashCode => Object.hash(conditionType, result, inverted);
}
