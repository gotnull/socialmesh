// SPDX-License-Identifier: GPL-3.0-or-later
// Custom interface type for the Socialmesh visual automation flow builder.
//
// ActionSignal interfaces are terminal inputs on action nodes. They represent
// the final destination of an event signal flowing through the automation
// graph — the point where "something happens" (send a message, push a
// notification, trigger a webhook, etc.).
//
// Color: Green — matches the THEN section color in the automation editor
// and the AppTheme.successGreen accent, reinforcing the visual metaphor
// that green means "go / execute / complete".
//
// ActionSignal inputs accept connections from EventSignalOutputData. This
// ensures that only properly-typed trigger/condition/logic gate outputs can
// feed into action nodes, preventing users from wiring nonsensical
// connections like a NodeList directly into an action.

import 'package:flutter/material.dart';

import '../vs_node_view/data/vs_interface.dart';
import 'event_signal_interface.dart';

/// Green color matching the automation editor's THEN (action) section and
/// AppTheme.successGreen.
///
/// This is the wire color users see on the rightmost connections in their
/// automation graphs — the final leg from the last condition/logic gate
/// into each action node.
const Color kActionSignalColor = Color(0xFF4ADE80);

/// Input interface that accepts an event signal for action execution.
///
/// Used exclusively on action nodes — the terminal nodes in an automation
/// graph. Each action node has exactly one ActionSignalInputData, which
/// connects to the upstream event signal chain (trigger → conditions →
/// logic gates → action).
///
/// Accepts connections from:
/// - [EventSignalOutputData] — the primary event signal type flowing through
///   the graph from trigger nodes through condition and logic gate nodes.
///
/// This type is intentionally restrictive. Action nodes should only receive
/// properly-typed event signals that have passed through the full
/// trigger/condition pipeline. If a user needs to gate an action on a
/// boolean condition, they wire the condition node's event signal output
/// (not its bool gate output) into the action — the condition node acts as
/// a pass-through filter on the event signal, not as a boolean data source.
class ActionSignalInputData extends VSInputData {
  ActionSignalInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [EventSignalOutputData];

  @override
  Color get interfaceColor => kActionSignalColor;
}

/// Output interface that emits an action signal.
///
/// Used on action nodes that need to chain into downstream actions or
/// logging nodes. In the simplest case (Phase 2), action nodes are pure
/// terminals with no output. This output type exists for Phase 3+ when
/// action chaining is introduced — e.g. "Send Message → Log Event" where
/// the send message action's completion signal feeds into the log node.
///
/// The [outputFunction] receives a map of the node's evaluated input values
/// and returns an [ActionSignalPayload] describing the action configuration
/// and its position in the execution chain.
class ActionSignalOutputData extends VSOutputData<ActionSignalPayload> {
  ActionSignalOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => kActionSignalColor;
}

/// The payload carried by an action signal wire.
///
/// This data structure is used at compile time (when the user saves the
/// flow) to extract the action configuration from the graph and build the
/// corresponding [AutomationAction] model objects.
///
/// At runtime, the actual action execution is handled by
/// [AutomationEngine._executeAction] — this payload is used only for
/// graph compilation, not for live action processing.
class ActionSignalPayload {
  const ActionSignalPayload({
    required this.actionType,
    this.config = const {},
    this.executionOrder = 0,
  });

  /// The action type to execute.
  ///
  /// Stored as a string to avoid a hard dependency on the automation model
  /// enum from within the interface layer. The compiler maps this back to
  /// [ActionType] when building the [AutomationAction] object.
  ///
  /// Examples: 'sendMessage', 'pushNotification', 'triggerWebhook',
  /// 'playSound', 'vibrate', 'logEvent', 'updateWidget', 'sendToChannel',
  /// 'triggerShortcut', 'glyphPattern'.
  final String actionType;

  /// The raw action configuration map.
  ///
  /// Contains message text, target node numbers, channel indices, webhook
  /// URLs, notification titles/bodies, sound selections, shortcut names,
  /// and other action-specific parameters. Passed through to the compiled
  /// [AutomationAction.config].
  final Map<String, dynamic> config;

  /// The position of this action in the execution sequence.
  ///
  /// When multiple action nodes are wired to the same upstream signal, the
  /// compiler uses this value to determine the order in which actions are
  /// executed within the compiled [Automation.actions] list.
  ///
  /// Lower values execute first. Actions with the same execution order are
  /// ordered by their horizontal position on the canvas (left-to-right).
  final int executionOrder;

  /// Creates a copy with the given fields replaced.
  ActionSignalPayload copyWith({
    String? actionType,
    Map<String, dynamic>? config,
    int? executionOrder,
  }) {
    return ActionSignalPayload(
      actionType: actionType ?? this.actionType,
      config: config ?? this.config,
      executionOrder: executionOrder ?? this.executionOrder,
    );
  }

  @override
  String toString() {
    return 'ActionSignalPayload(action: $actionType, order: $executionOrder)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActionSignalPayload &&
        other.actionType == actionType &&
        other.executionOrder == executionOrder;
  }

  @override
  int get hashCode => Object.hash(actionType, executionOrder);
}
