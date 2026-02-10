// SPDX-License-Identifier: GPL-3.0-or-later
// Custom interface type for the Socialmesh visual automation flow builder.
//
// EventSignal interfaces carry trigger event context through the automation
// graph. They represent the "signal" that flows from a trigger node through
// condition/logic gates and ultimately into action nodes.
//
// Color: Amber — matches the WHEN section color in the automation editor.

import 'package:flutter/material.dart';

import '../vs_node_view/data/vs_interface.dart';

/// Amber color matching the automation editor's WHEN (trigger) section.
///
/// This is the dominant wire color users will see flowing left-to-right
/// through their automation graphs.
const Color kEventSignalColor = Color(0xFFFBBF24);

/// Input interface that accepts an event signal.
///
/// Used on condition nodes, logic gate nodes, and action nodes — any node
/// that needs to receive the trigger event context flowing through the graph.
///
/// Accepts connections from [EventSignalOutputData] only. This prevents
/// users from accidentally wiring incompatible data types (e.g. a NodeList
/// output) into an event signal input.
class EventSignalInputData extends VSInputData {
  EventSignalInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [EventSignalOutputData];

  @override
  Color get interfaceColor => kEventSignalColor;
}

/// Output interface that emits an event signal.
///
/// Used on trigger nodes and condition/logic gate nodes — any node that
/// produces or forwards the trigger event context downstream.
///
/// The [outputFunction] receives a map of the node's evaluated input values
/// and returns an [EventSignalPayload] describing the event signal state at
/// that point in the graph.
class EventSignalOutputData extends VSOutputData<EventSignalPayload> {
  EventSignalOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => kEventSignalColor;
}

/// The payload carried by an event signal wire.
///
/// This is the data structure that flows through the graph at compile time
/// (when the user saves) or at design-time preview. It captures enough
/// context about the trigger event for downstream nodes to configure
/// themselves appropriately.
///
/// At runtime, the actual [AutomationEvent] is evaluated by the
/// [AutomationEngine] — this payload is used only for graph compilation
/// and type-checking, not for live event processing.
class EventSignalPayload {
  const EventSignalPayload({
    required this.triggerType,
    this.nodeNum,
    this.config = const {},
    this.passed = true,
  });

  /// The trigger type that originated this signal.
  ///
  /// Stored as a string to avoid a hard dependency on the automation model
  /// enum from within the interface layer. The compiler maps this back to
  /// [TriggerType] when building the [Automation] object.
  final String triggerType;

  /// Optional node number filter from the trigger configuration.
  ///
  /// When non-null, the automation only fires for events from this specific
  /// mesh node.
  final int? nodeNum;

  /// The raw trigger configuration map.
  ///
  /// Contains threshold values, keywords, geofence coordinates, schedule
  /// expressions, and other trigger-specific parameters. Passed through
  /// to the compiled [AutomationTrigger.config].
  final Map<String, dynamic> config;

  /// Whether the signal has passed all upstream conditions.
  ///
  /// Condition and logic gate nodes set this to false when their criteria
  /// are not met, which tells the compiler to exclude this path from the
  /// compiled automation. At design-time preview, a false value can be
  /// used to visually dim downstream wires and nodes.
  final bool passed;

  /// Creates a copy with the given fields replaced.
  EventSignalPayload copyWith({
    String? triggerType,
    int? nodeNum,
    Map<String, dynamic>? config,
    bool? passed,
  }) {
    return EventSignalPayload(
      triggerType: triggerType ?? this.triggerType,
      nodeNum: nodeNum ?? this.nodeNum,
      config: config ?? this.config,
      passed: passed ?? this.passed,
    );
  }

  @override
  String toString() {
    return 'EventSignalPayload(trigger: $triggerType, node: $nodeNum, '
        'passed: $passed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventSignalPayload &&
        other.triggerType == triggerType &&
        other.nodeNum == nodeNum &&
        other.passed == passed;
  }

  @override
  int get hashCode => Object.hash(triggerType, nodeNum, passed);
}
