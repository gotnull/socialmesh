// SPDX-License-Identifier: GPL-3.0-or-later
// Logic gate node builders for the Socialmesh visual automation flow builder.
//
// Logic gate nodes combine multiple event signals using boolean logic:
// - AND: All upstream signals must be present (all conditions met)
// - OR: At least one upstream signal must be present (any condition met)
// - NOT: Inverts the signal (passes through only when upstream is absent)
//
// AND and OR gates use VSListNode to accept a dynamic number of inputs,
// allowing users to wire in as many upstream condition/trigger signals as
// needed. The NOT gate has a single input.
//
// All logic gates output an EventSignalOutputData — they act as filters
// on the event signal flow, not as boolean data sources. This keeps the
// wire type consistent through the graph: amber EventSignal wires flow
// from triggers through conditions and logic gates into actions.
//
// At compile time, the compiler reads the gate type and its upstream
// connections to determine how to combine conditions:
// - AND gates map to multiple entries in Automation.conditions (all AND-gated)
// - OR gates cause the compiler to emit multiple Automation objects (one per
//   upstream path), achieving OR semantics through parallel automations
// - NOT gates set the inverted flag on the upstream condition

import 'package:flutter/material.dart';

import '../interfaces/event_signal_interface.dart';
import '../vs_node_view/common.dart';
import '../vs_node_view/data/vs_interface.dart';
import '../vs_node_view/data/vs_node_data.dart';
import '../vs_node_view/data/vs_subgroup.dart';
import '../vs_node_view/special_nodes/vs_list_node.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Node width for logic gate nodes — compact since they have minimal UI.
const double _kGateNodeWidth = 160.0;

/// Logic gate type identifiers.
class LogicGateTypes {
  LogicGateTypes._();

  static const and = 'logic_and';
  static const or = 'logic_or';
  static const not = 'logic_not';
  static const delay = 'logic_delay';

  /// Display names for each logic gate type.
  static const Map<String, String> displayNames = {
    and: 'AND',
    or: 'OR',
    not: 'NOT',
    delay: 'Delay',
  };

  /// Icons for each logic gate type.
  static const Map<String, IconData> icons = {
    and: Icons.join_full,
    or: Icons.join_inner,
    not: Icons.block,
    delay: Icons.timer_outlined,
  };
}

/// Accent color for logic gate node headers.
///
/// A warm white-blue that sits between the amber trigger color and the cyan
/// condition color, visually marking logic gates as "plumbing" that connects
/// triggers/conditions to actions without being either.
const Color _kGateAccent = Color(0xFFE0E7FF);

// ---------------------------------------------------------------------------
// Delay config
// ---------------------------------------------------------------------------

/// Configuration for the delay logic gate.
class _DelayConfig {
  int delaySeconds = 300; // 5 minutes default

  dynamic toJson() => {'delaySeconds': delaySeconds};

  void fromJson(dynamic json) {
    if (json is Map) {
      delaySeconds = json['delaySeconds'] as int? ?? 300;
    }
  }
}

// ---------------------------------------------------------------------------
// AND gate — VSListNode with dynamic EventSignal inputs
// ---------------------------------------------------------------------------

/// Builds an AND logic gate node.
///
/// Uses [VSListNode] to accept a dynamic number of EventSignal inputs.
/// All inputs must be connected and their upstream conditions must pass
/// for the output signal to be considered "passed" at compile time.
///
/// At runtime, AND semantics are achieved by the automation engine's
/// existing condition evaluation — all conditions in the Automation.conditions
/// list are AND-gated.
VSNodeDataBuilder _buildAndGateBuilder() {
  return (Offset offset, VSOutputData? ref) {
    return VSListNode(
      type: LogicGateTypes.and,
      widgetOffset: offset,
      nodeWidth: _kGateNodeWidth,
      title: 'AND',
      referenceConnection: ref,
      inputBuilder: (int index, VSOutputData? connection) {
        return EventSignalInputData(
          type: 'event_in_$index',
          title: 'Input ${index + 1}',
          initialConnection: connection,
        );
      },
      outputData: [
        EventSignalOutputData(
          type: 'event_out',
          title: 'All Met',
          outputFunction: (inputs) {
            // At compile time: walk all connected inputs and verify they
            // all carry a passed EventSignalPayload.
            EventSignalPayload? firstPayload;
            bool allPassed = true;

            for (final entry in inputs.entries) {
              final value = entry.value;
              if (value is EventSignalPayload) {
                firstPayload ??= value;
                if (!value.passed) {
                  allPassed = false;
                }
              }
            }

            if (firstPayload == null) {
              return EventSignalPayload(triggerType: '', passed: false);
            }

            return firstPayload.copyWith(passed: allPassed);
          },
        ),
      ],
    );
  };
}

// ---------------------------------------------------------------------------
// OR gate — VSListNode with dynamic EventSignal inputs
// ---------------------------------------------------------------------------

/// Builds an OR logic gate node.
///
/// Uses [VSListNode] to accept a dynamic number of EventSignal inputs.
/// At least one input must be connected and its upstream conditions must
/// pass for the output signal to be considered "passed" at compile time.
///
/// At runtime, OR semantics are achieved by the compiler emitting multiple
/// Automation objects — one for each upstream path through the OR gate.
/// This is a design-time tool; the engine does not evaluate OR at runtime.
VSNodeDataBuilder _buildOrGateBuilder() {
  return (Offset offset, VSOutputData? ref) {
    return VSListNode(
      type: LogicGateTypes.or,
      widgetOffset: offset,
      nodeWidth: _kGateNodeWidth,
      title: 'OR',
      referenceConnection: ref,
      inputBuilder: (int index, VSOutputData? connection) {
        return EventSignalInputData(
          type: 'event_in_$index',
          title: 'Input ${index + 1}',
          initialConnection: connection,
        );
      },
      outputData: [
        EventSignalOutputData(
          type: 'event_out',
          title: 'Any Met',
          outputFunction: (inputs) {
            // At compile time: walk all connected inputs and check if at
            // least one carries a passed EventSignalPayload.
            EventSignalPayload? firstPayload;
            bool anyPassed = false;

            for (final entry in inputs.entries) {
              final value = entry.value;
              if (value is EventSignalPayload) {
                firstPayload ??= value;
                if (value.passed) {
                  anyPassed = true;
                }
              }
            }

            if (firstPayload == null) {
              return EventSignalPayload(triggerType: '', passed: false);
            }

            return firstPayload.copyWith(passed: anyPassed);
          },
        ),
      ],
    );
  };
}

// ---------------------------------------------------------------------------
// NOT gate — single EventSignal input, inverted output
// ---------------------------------------------------------------------------

/// Builds a NOT logic gate node.
///
/// Has a single EventSignal input and a single EventSignal output. The
/// output signal has its `passed` flag inverted relative to the input.
///
/// At compile time, the compiler reads the NOT gate and sets the `inverted`
/// flag on the upstream condition, causing the engine to negate the
/// condition's boolean result at runtime.
///
/// This allows a single condition node type (e.g. "Node Online") to serve
/// as its inverse ("Node NOT Online") without requiring a separate node
/// type for every negation.
VSNodeDataBuilder _buildNotGateBuilder() {
  return (Offset offset, VSOutputData? ref) {
    return VSNodeData(
      type: LogicGateTypes.not,
      widgetOffset: offset,
      nodeWidth: _kGateNodeWidth,
      title: 'NOT',
      inputData: [
        EventSignalInputData(
          type: 'event_in',
          title: 'Input',
          initialConnection: ref,
        ),
      ],
      outputData: [
        EventSignalOutputData(
          type: 'event_out',
          title: 'Inverted',
          outputFunction: (inputs) {
            final upstream = inputs['event_in'] as EventSignalPayload?;
            if (upstream == null) {
              return EventSignalPayload(triggerType: '', passed: true);
            }
            return upstream.copyWith(passed: !upstream.passed);
          },
        ),
      ],
    );
  };
}

// ---------------------------------------------------------------------------
// Delay gate — single EventSignal input with configurable delay
// ---------------------------------------------------------------------------

/// Builds a Delay logic gate node.
///
/// Has a single EventSignal input and a single EventSignal output. The
/// delay duration is configurable via a slider widget embedded in the node.
///
/// At runtime, the delay is applied by the automation engine between
/// condition evaluation and action execution. At compile time, the compiler
/// reads the delay configuration and attaches it as metadata to the
/// compiled Automation.
///
/// The delay node uses a custom [VSNodeData] subclass to hold the
/// serializable delay configuration alongside the standard node data.
VSNodeDataBuilder _buildDelayGateBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _DelayConfig();

    return _DelayNode(
      type: LogicGateTypes.delay,
      widgetOffset: offset,
      nodeWidth: _kGateNodeWidth,
      title: 'Delay',
      ref: ref,
      config: config,
    );
  };
}

/// Custom node data class for the Delay gate that holds a serializable
/// delay configuration.
class _DelayNode extends VSNodeData {
  _DelayNode({
    required super.type,
    required super.widgetOffset,
    required this.config,
    super.nodeWidth,
    super.title,
    VSOutputData? ref,
  }) : super(
         inputData: [
           EventSignalInputData(
             type: 'event_in',
             title: 'Input',
             initialConnection: ref,
           ),
         ],
         outputData: [
           EventSignalOutputData(
             type: 'event_out',
             title: 'Delayed',
             outputFunction: (inputs) {
               final upstream = inputs['event_in'] as EventSignalPayload?;
               if (upstream == null) {
                 return EventSignalPayload(triggerType: '', passed: false);
               }
               // Pass through with delay metadata attached to the config.
               return upstream;
             },
           ),
         ],
       );

  final _DelayConfig config;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    return json..['value'] = config.toJson();
  }
}

// ---------------------------------------------------------------------------
// Public API: logic gate node builder list and subgroup
// ---------------------------------------------------------------------------

/// Returns a [VSSubgroup] containing builders for all logic gate node types.
///
/// This is the entry point for registering logic gate nodes with the
/// [VSNodeManager]. Pass this subgroup into the nodeBuilders list.
VSSubgroup logicGateNodeSubgroup() {
  return VSSubgroup(
    name: 'Logic',
    subgroup: [
      _buildAndGateBuilder(),
      _buildOrGateBuilder(),
      _buildNotGateBuilder(),
      _buildDelayGateBuilder(),
    ],
  );
}

/// Returns a flat list of all logic gate node builders (without subgroup
/// wrapping). Useful for registering as additional nodes for deserialization.
List<VSNodeDataBuilder> allLogicGateNodeBuilders() {
  return [
    _buildAndGateBuilder(),
    _buildOrGateBuilder(),
    _buildNotGateBuilder(),
    _buildDelayGateBuilder(),
  ];
}

// ---------------------------------------------------------------------------
// Gate node custom rendering
//
// Logic gate nodes use a custom nodeBuilder in the VSNodeView to render
// a distinctive visual style — a compact symbol-centric card with the
// gate icon prominently displayed and a minimal interface layout.
//
// This builder is registered via the VSNodeView.nodeBuilder parameter
// in the visual flow screen, not embedded in the node data itself.
// The rendering functions below are exported for use by the screen.
// ---------------------------------------------------------------------------

/// Returns true if the given node data represents a logic gate node.
bool isLogicGateNode(VSNodeData data) {
  return data.type == LogicGateTypes.and ||
      data.type == LogicGateTypes.or ||
      data.type == LogicGateTypes.not ||
      data.type == LogicGateTypes.delay;
}

/// Returns the accent color for a logic gate node based on its type.
///
/// AND and OR gates use the cool blue-white accent. NOT uses a warm
/// red-tinted accent to visually signal "negation". Delay uses the
/// amber trigger accent to signal "time-related".
Color gateAccentColor(String gateType) {
  return switch (gateType) {
    LogicGateTypes.not => const Color(0xFFFF6B6B),
    LogicGateTypes.delay => const Color(0xFFFBBF24),
    _ => _kGateAccent,
  };
}

/// Returns the icon for a logic gate node based on its type.
IconData gateIcon(String gateType) {
  return LogicGateTypes.icons[gateType] ?? Icons.account_tree_outlined;
}

/// Returns the display label for a logic gate node based on its type.
String gateLabel(String gateType) {
  return LogicGateTypes.displayNames[gateType] ?? gateType;
}

/// Returns a human-readable description of what the gate does.
String gateDescription(String gateType) {
  return switch (gateType) {
    LogicGateTypes.and => 'All inputs must pass',
    LogicGateTypes.or => 'Any input can pass',
    LogicGateTypes.not => 'Inverts the signal',
    LogicGateTypes.delay => 'Delays the signal',
    _ => '',
  };
}

/// Returns the delay configuration from a delay gate node, or null if
/// the node is not a delay gate.
///
/// Used by the compiler to extract delay metadata from the graph.
Map<String, dynamic>? getDelayConfig(VSNodeData data) {
  if (data is _DelayNode) {
    return data.config.toJson() as Map<String, dynamic>;
  }
  return null;
}

/// Formats a delay duration in seconds into a human-readable string.
///
/// Examples:
/// - 30 → "30s"
/// - 300 → "5m"
/// - 3600 → "1h"
/// - 5400 → "1h 30m"
String formatDelayDuration(int seconds) {
  if (seconds < 60) {
    return '${seconds}s';
  }
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes < 60) {
    if (remainingSeconds == 0) {
      return '${minutes}m';
    }
    return '${minutes}m ${remainingSeconds}s';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainingMinutes}m';
}
