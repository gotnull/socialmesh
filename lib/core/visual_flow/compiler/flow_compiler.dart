// SPDX-License-Identifier: GPL-3.0-or-later
// Flow compiler for the Socialmesh visual automation flow builder.
//
// Walks the visual node graph backwards from action nodes to trigger nodes,
// collecting conditions and logic gate semantics along the way, and produces
// compiled Automation objects compatible with the existing AutomationEngine.
//
// The compiler treats the visual editor as a design-time tool. The node graph
// is never evaluated at runtime — instead it is compiled into one or more
// Automation objects that the push-based AutomationEngine can execute.
//
// Key semantics:
// - AND gates: all upstream conditions are collected into a single
//   Automation.conditions list (the engine AND-gates them by default).
// - OR gates: the compiler forks, producing a separate Automation for each
//   upstream path through the OR gate. This achieves OR semantics through
//   parallel automations without changing the engine.
// - NOT gates: the compiler inverts the conditions found on the upstream
//   path by swapping condition types to their logical inverse where possible.
// - Delay gates: delay metadata is attached to the compiled Automation's
//   description and config for the engine to interpret.
//
// Multiple action nodes sharing the same trigger+conditions path are merged
// into a single Automation with multiple actions to reduce duplication.

import 'dart:ui' show Offset;

import '../../../features/automations/models/automation.dart';
import '../nodes/action_nodes.dart';
import '../nodes/condition_nodes.dart';
import '../nodes/logic_gate_nodes.dart';
import '../nodes/trigger_nodes.dart';
import '../vs_node_view/data/vs_node_data.dart';
import '../vs_node_view/special_nodes/vs_list_node.dart';
import '../vs_node_view/special_nodes/vs_widget_node.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Result of compiling a visual flow graph into Automation objects.
class FlowCompilationResult {
  const FlowCompilationResult({
    required this.automations,
    this.errors = const [],
    this.warnings = const [],
    this.graphMetadata,
  });

  /// The compiled Automation objects ready for the engine.
  final List<Automation> automations;

  /// Hard errors that prevented compilation of one or more paths.
  final List<FlowCompilationError> errors;

  /// Non-fatal warnings about the graph structure.
  final List<FlowCompilationWarning> warnings;

  /// Optional metadata mapping graph node IDs to compiled automation IDs.
  ///
  /// Used for round-trip editing: when the user opens the visual editor for
  /// an existing automation, this metadata allows the editor to reconstruct
  /// the original graph layout.
  final FlowGraphMetadata? graphMetadata;

  /// Whether compilation succeeded with no errors.
  bool get isSuccess => errors.isEmpty && automations.isNotEmpty;

  /// Whether compilation produced no automations at all.
  bool get isEmpty => automations.isEmpty;
}

/// A compilation error describing why a path could not be compiled.
class FlowCompilationError {
  const FlowCompilationError({
    required this.message,
    this.nodeId,
    this.nodeType,
  });

  final String message;

  /// The ID of the node that caused the error, if identifiable.
  final String? nodeId;

  /// The type of the node that caused the error, if identifiable.
  final String? nodeType;

  @override
  String toString() {
    final location = nodeId != null ? ' (node: $nodeId, type: $nodeType)' : '';
    return 'FlowCompilationError: $message$location';
  }
}

/// A non-fatal warning about the graph structure.
class FlowCompilationWarning {
  const FlowCompilationWarning({
    required this.message,
    this.nodeId,
    this.nodeType,
  });

  final String message;
  final String? nodeId;
  final String? nodeType;

  @override
  String toString() {
    final location = nodeId != null ? ' (node: $nodeId, type: $nodeType)' : '';
    return 'FlowCompilationWarning: $message$location';
  }
}

/// Metadata mapping graph structure to compiled automation IDs.
///
/// Stored alongside the serialized graph JSON so that existing automations
/// can be loaded back into the visual editor for refinement.
class FlowGraphMetadata {
  const FlowGraphMetadata({
    required this.graphJson,
    required this.automationIds,
    required this.actionNodeToAutomationId,
    this.flowName,
  });

  /// The serialized graph JSON at the time of compilation.
  final String graphJson;

  /// All automation IDs produced by this graph.
  final List<String> automationIds;

  /// Maps each action node ID to the automation ID(s) it contributed to.
  ///
  /// An action node can map to multiple automation IDs when OR gates
  /// upstream cause path forking.
  final Map<String, List<String>> actionNodeToAutomationId;

  /// Optional user-assigned name for the flow.
  final String? flowName;

  Map<String, dynamic> toJson() => {
    'graphJson': graphJson,
    'automationIds': automationIds,
    'actionNodeToAutomationId': actionNodeToAutomationId,
    'flowName': flowName,
  };

  factory FlowGraphMetadata.fromJson(Map<String, dynamic> json) {
    final rawMap =
        json['actionNodeToAutomationId'] as Map<String, dynamic>? ?? {};
    final actionMap = <String, List<String>>{};
    for (final entry in rawMap.entries) {
      final value = entry.value;
      if (value is List) {
        actionMap[entry.key] = value.cast<String>();
      }
    }
    return FlowGraphMetadata(
      graphJson: json['graphJson'] as String? ?? '',
      automationIds:
          (json['automationIds'] as List?)?.cast<String>() ?? const [],
      actionNodeToAutomationId: actionMap,
      flowName: json['flowName'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Internal: compiled path segment
// ---------------------------------------------------------------------------

/// A single path through the graph from a trigger to an action endpoint.
///
/// OR gates produce multiple _CompiledPath objects for the same action node.
/// AND gates merge conditions from all upstream branches into one path.
class _CompiledPath {
  _CompiledPath({
    required this.triggerType,
    required this.triggerConfig,
    this.triggerNodeId,
    List<AutomationCondition>? conditions,
    this.delaySeconds,
  }) : conditions = conditions ?? [];

  /// The trigger type string (matches TriggerType.name).
  final String triggerType;

  /// The trigger configuration map.
  final Map<String, dynamic> triggerConfig;

  /// The ID of the trigger node in the graph.
  final String? triggerNodeId;

  /// Conditions collected along this path (AND-gated).
  final List<AutomationCondition> conditions;

  /// Optional delay in seconds from a Delay gate on this path.
  final int? delaySeconds;

  /// Creates a copy with additional conditions prepended.
  _CompiledPath withConditions(List<AutomationCondition> extra) {
    return _CompiledPath(
      triggerType: triggerType,
      triggerConfig: triggerConfig,
      triggerNodeId: triggerNodeId,
      conditions: [...extra, ...conditions],
      delaySeconds: delaySeconds,
    );
  }

  /// Creates a copy with a delay value set (takes the maximum if already set).
  _CompiledPath withDelay(int seconds) {
    final effective = delaySeconds != null && delaySeconds! > seconds
        ? delaySeconds!
        : seconds;
    return _CompiledPath(
      triggerType: triggerType,
      triggerConfig: triggerConfig,
      triggerNodeId: triggerNodeId,
      conditions: conditions,
      delaySeconds: effective,
    );
  }

  /// A signature string used to group paths with identical trigger+conditions.
  ///
  /// Paths with the same signature can share an Automation (multiple actions).
  String get signature {
    final condSig = conditions.map((c) => '${c.type.name}:${c.config}').toList()
      ..sort();
    return '$triggerType|${triggerConfig.toString()}|${condSig.join(",")}|$delaySeconds';
  }
}

// ---------------------------------------------------------------------------
// Trigger type detection
// ---------------------------------------------------------------------------

/// Set of all known trigger type strings for quick lookup.
final Set<String> _allTriggerTypes = {
  TriggerTypes.nodeOnline,
  TriggerTypes.nodeOffline,
  TriggerTypes.batteryLow,
  TriggerTypes.batteryFull,
  TriggerTypes.messageReceived,
  TriggerTypes.messageContains,
  TriggerTypes.positionChanged,
  TriggerTypes.geofenceEnter,
  TriggerTypes.geofenceExit,
  TriggerTypes.nodeSilent,
  TriggerTypes.scheduled,
  TriggerTypes.signalWeak,
  TriggerTypes.channelActivity,
  TriggerTypes.detectionSensor,
  TriggerTypes.manual,
};

/// Returns true if the given node is a trigger node.
bool _isTriggerNode(VSNodeData node) {
  return node is VSWidgetNode && _allTriggerTypes.contains(node.type);
}

/// Map from condition node type string to its inverse, used by NOT gates.
///
/// Keys and values are condition node type strings (matching
/// [ConditionTypes] constants), not raw enum names.
const Map<String, String> _conditionInverseMap = {
  ConditionTypes.timeRange: ConditionTypes.timeRange,
  ConditionTypes.dayOfWeek: ConditionTypes.dayOfWeek,
  ConditionTypes.batteryAbove: ConditionTypes.batteryBelow,
  ConditionTypes.batteryBelow: ConditionTypes.batteryAbove,
  ConditionTypes.nodeOnline: ConditionTypes.nodeOffline,
  ConditionTypes.nodeOffline: ConditionTypes.nodeOnline,
  ConditionTypes.withinGeofence: ConditionTypes.outsideGeofence,
  ConditionTypes.outsideGeofence: ConditionTypes.withinGeofence,
};

// ---------------------------------------------------------------------------
// Compiler
// ---------------------------------------------------------------------------

/// Compiles a visual flow node graph into Automation objects.
///
/// The [nodes] map is keyed by node ID (as returned by VSNodeManager.nodes).
/// The optional [flowName] is used as a prefix for generated automation names.
/// The optional [graphJson] is stored in the metadata for round-trip editing.
///
/// Returns a [FlowCompilationResult] containing the compiled automations,
/// any errors encountered, and metadata for graph↔automation mapping.
FlowCompilationResult compileFlowGraph({
  required Map<String, VSNodeData> nodes,
  String? flowName,
  String? graphJson,
}) {
  final errors = <FlowCompilationError>[];
  final warnings = <FlowCompilationWarning>[];
  final actionNodeToAutomationId = <String, List<String>>{};

  // 1. Find all action nodes (terminals).
  final actionNodes = <String, ActionNode>{};
  for (final entry in nodes.entries) {
    if (entry.value is ActionNode) {
      actionNodes[entry.key] = entry.value as ActionNode;
    }
  }

  if (actionNodes.isEmpty) {
    errors.add(
      const FlowCompilationError(
        message:
            'No action nodes found in the graph. '
            'Add at least one action node to create an automation.',
      ),
    );
    return FlowCompilationResult(
      automations: const [],
      errors: errors,
      warnings: warnings,
    );
  }

  // 2. For each action node, trace back to find all paths to triggers.
  //    Each path becomes a candidate for an Automation.
  final pathsPerAction = <String, List<_CompiledPath>>{};
  final visitedDuringTrace = <String>{};

  for (final entry in actionNodes.entries) {
    final actionNodeId = entry.key;
    final actionNode = entry.value;

    // Get the upstream connection from the action's input.
    final actionInput = actionNode.inputData.firstOrNull;
    if (actionInput == null || actionInput.connectedInterface == null) {
      errors.add(
        FlowCompilationError(
          message:
              'Action node "${actionNode.title}" has no upstream connection. '
              'Connect a trigger or condition to its input.',
          nodeId: actionNodeId,
          nodeType: actionNode.type,
        ),
      );
      continue;
    }

    final upstreamNode = actionInput.connectedInterface!.nodeData;
    if (upstreamNode == null) {
      errors.add(
        FlowCompilationError(
          message:
              'Action node "${actionNode.title}" has a broken upstream reference.',
          nodeId: actionNodeId,
          nodeType: actionNode.type,
        ),
      );
      continue;
    }

    visitedDuringTrace.clear();
    final paths = _tracePaths(
      upstreamNode,
      visitedDuringTrace,
      errors,
      warnings,
    );

    if (paths.isEmpty) {
      errors.add(
        FlowCompilationError(
          message:
              'Action node "${actionNode.title}" has no valid path to a trigger node.',
          nodeId: actionNodeId,
          nodeType: actionNode.type,
        ),
      );
      continue;
    }

    pathsPerAction[actionNodeId] = paths;
  }

  // 3. Group actions by path signature to merge into shared Automations.
  //    Actions that share the same trigger+conditions path become multiple
  //    actions in a single Automation.
  final signatureToActions = <String, List<_ActionEntry>>{};
  final signatureToPath = <String, _CompiledPath>{};

  for (final entry in pathsPerAction.entries) {
    final actionNodeId = entry.key;
    final actionNode = actionNodes[actionNodeId]!;
    final paths = entry.value;

    for (final path in paths) {
      final sig = path.signature;
      signatureToPath[sig] = path;
      signatureToActions.putIfAbsent(sig, () => []);
      signatureToActions[sig]!.add(
        _ActionEntry(
          nodeId: actionNodeId,
          actionType: actionNode.actionType,
          config: _extractActionConfig(actionNode),
          title: actionNode.title,
        ),
      );
    }
  }

  // 4. Build Automation objects from grouped paths.
  final automations = <Automation>[];
  int automationIndex = 0;

  for (final entry in signatureToActions.entries) {
    final sig = entry.key;
    final actionEntries = entry.value;
    final path = signatureToPath[sig]!;

    automationIndex++;

    // Resolve trigger type.
    final triggerType = _resolveTriggerType(path.triggerType);
    if (triggerType == null) {
      errors.add(
        FlowCompilationError(
          message:
              'Unknown trigger type "${path.triggerType}" encountered during compilation.',
          nodeId: path.triggerNodeId,
          nodeType: path.triggerType,
        ),
      );
      continue;
    }

    // Build actions list, sorted by horizontal position on canvas.
    final actions = actionEntries.map((ae) {
      final resolvedActionType = _resolveActionType(ae.actionType);
      if (resolvedActionType == null) {
        warnings.add(
          FlowCompilationWarning(
            message:
                'Unknown action type "${ae.actionType}" — using pushNotification as fallback.',
            nodeId: ae.nodeId,
            nodeType: ae.actionType,
          ),
        );
        return AutomationAction(
          type: ActionType.pushNotification,
          config: ae.config,
        );
      }
      return AutomationAction(type: resolvedActionType, config: ae.config);
    }).toList();

    // Build trigger.
    final trigger = AutomationTrigger(
      type: triggerType,
      config: path.triggerConfig,
    );

    // Build conditions (may be empty).
    final conditions = path.conditions.isNotEmpty ? path.conditions : null;

    // Generate name.
    final namePrefix = flowName ?? 'Visual Flow';
    final actionNames = actionEntries.map((ae) => ae.title).join(', ');
    final triggerName =
        TriggerTypes.displayNames[path.triggerType] ?? path.triggerType;
    final name = signatureToActions.length > 1
        ? '$namePrefix $automationIndex: $triggerName → $actionNames'
        : '$namePrefix: $triggerName → $actionNames';

    // Generate description.
    final descParts = <String>[];
    descParts.add('When: $triggerName');
    if (conditions != null && conditions.isNotEmpty) {
      final condNames = conditions
          .map(
            (c) =>
                ConditionTypes.displayNames[ConditionTypes.fromEnum[c.type] ??
                    c.type.name] ??
                c.type.displayName,
          )
          .join(' AND ');
      descParts.add('If: $condNames');
    }
    if (path.delaySeconds != null && path.delaySeconds! > 0) {
      descParts.add('After: ${formatDelayDuration(path.delaySeconds!)} delay');
    }
    descParts.add('Then: $actionNames');
    final description = descParts.join(' · ');

    // Build config with delay metadata if present.
    Map<String, dynamic> triggerConfig = Map.from(path.triggerConfig);
    if (path.delaySeconds != null && path.delaySeconds! > 0) {
      triggerConfig = Map.from(triggerConfig)
        ..['_flowDelaySeconds'] = path.delaySeconds;
    }

    final automation = Automation(
      name: name,
      description: description,
      enabled: true,
      trigger: trigger.copyWith(config: triggerConfig),
      actions: actions,
      conditions: conditions,
    );

    automations.add(automation);

    // Record mapping from action nodes to this automation's ID.
    for (final ae in actionEntries) {
      actionNodeToAutomationId.putIfAbsent(ae.nodeId, () => []);
      actionNodeToAutomationId[ae.nodeId]!.add(automation.id);
    }
  }

  // 5. Build metadata.
  FlowGraphMetadata? metadata;
  if (graphJson != null) {
    metadata = FlowGraphMetadata(
      graphJson: graphJson,
      automationIds: automations.map((a) => a.id).toList(),
      actionNodeToAutomationId: actionNodeToAutomationId,
      flowName: flowName,
    );
  }

  // Warn about disconnected nodes.
  final referencedNodeIds = <String>{};
  for (final node in nodes.values) {
    for (final input in node.inputData) {
      final upstream = input.connectedInterface?.nodeData;
      if (upstream != null) {
        referencedNodeIds.add(upstream.id);
      }
    }
  }
  for (final entry in nodes.entries) {
    final node = entry.value;
    final isActionOrConnected =
        node is ActionNode || referencedNodeIds.contains(node.id);
    if (!isActionOrConnected && !_isTriggerNode(node)) {
      // Node is not an action, not a trigger, and nobody references it.
      if (node is ConditionNode ||
          isLogicGateNode(node) ||
          isActionNode(node)) {
        warnings.add(
          FlowCompilationWarning(
            message:
                'Node "${node.title}" is disconnected and was not included '
                'in any compiled automation.',
            nodeId: entry.key,
            nodeType: node.type,
          ),
        );
      }
    }
  }

  return FlowCompilationResult(
    automations: automations,
    errors: errors,
    warnings: warnings,
    graphMetadata: metadata,
  );
}

// ---------------------------------------------------------------------------
// Graph → Automation decompiler (auto-layout)
// ---------------------------------------------------------------------------

/// Layout constants for decompiled graph positioning.
///
/// All values are multiples of [kNodeGridSpacing] (24) so decompiled nodes
/// land exactly on grid intersections. Columns are spaced 240dp apart
/// (10 grid cells) to fit comfortably on mobile screens while leaving
/// enough room for connection wires between nodes.
const double _kDecompileColTrigger = 48.0;
const double _kDecompileColCondition = 288.0;
const double _kDecompileColAndGate = 528.0;
const double _kDecompileColAction = 768.0;
const double _kDecompileRowSpacing = 144.0;
const double _kDecompileRowStart = 72.0;

/// Describes a node to be created during decompilation, along with its
/// position and wiring instructions.
///
/// This is a data-only class — the actual VSNodeData objects are created
/// by the provider layer using the appropriate node builders registered
/// with the VSNodeManager.
class DecompiledNode {
  const DecompiledNode({
    required this.type,
    required this.offset,
    this.config,
    this.id,
  });

  /// The node type string (matches builder type).
  final String type;

  /// The canvas position for this node.
  final Offset offset;

  /// Optional config to set via setValue after node creation.
  final dynamic config;

  /// Optional pre-assigned ID for wiring references.
  final String? id;
}

/// Describes a connection between two decompiled nodes.
class DecompiledConnection {
  const DecompiledConnection({
    required this.fromNodeIndex,
    required this.fromOutputType,
    required this.toNodeIndex,
    required this.toInputType,
  });

  /// Index into the DecompiledGraph.nodes list for the source node.
  final int fromNodeIndex;

  /// The output interface type on the source node.
  final String fromOutputType;

  /// Index into the DecompiledGraph.nodes list for the destination node.
  final int toNodeIndex;

  /// The input interface type on the destination node.
  final String toInputType;
}

/// A complete decompiled graph ready to be instantiated by the provider.
class DecompiledGraph {
  const DecompiledGraph({required this.nodes, required this.connections});

  final List<DecompiledNode> nodes;
  final List<DecompiledConnection> connections;
}

/// Decompiles an [Automation] into a [DecompiledGraph] describing the nodes
/// and connections to create in the visual editor.
///
/// The resulting graph follows a left-to-right layout:
/// Trigger → Conditions → (AND gate if multiple) → Action(s)
DecompiledGraph decompileAutomation(Automation automation) {
  final nodes = <DecompiledNode>[];
  final connections = <DecompiledConnection>[];

  double currentRow = _kDecompileRowStart;

  // 1. Create trigger node.
  final triggerTypeStr = automation.trigger.type.name;
  final triggerConfig = automation.trigger.config;

  nodes.add(
    DecompiledNode(
      type: triggerTypeStr,
      offset: Offset(_kDecompileColTrigger, currentRow),
      config: triggerConfig.isNotEmpty ? triggerConfig : null,
    ),
  );
  final triggerIndex = 0;

  // 2. Create condition nodes.
  final conditionIndices = <int>[];
  final conditions = automation.conditions ?? [];

  for (int i = 0; i < conditions.length; i++) {
    final condition = conditions[i];
    final condRow = _kDecompileRowStart + (i * _kDecompileRowSpacing);
    currentRow = condRow;

    nodes.add(
      DecompiledNode(
        type: ConditionTypes.fromEnum[condition.type] ?? condition.type.name,
        offset: Offset(_kDecompileColCondition, condRow),
        config: condition.config.isNotEmpty ? condition.config : null,
      ),
    );
    final condIndex = nodes.length - 1;
    conditionIndices.add(condIndex);

    // Wire trigger → condition.
    connections.add(
      DecompiledConnection(
        fromNodeIndex: triggerIndex,
        fromOutputType: 'event_out',
        toNodeIndex: condIndex,
        toInputType: 'event_in',
      ),
    );
  }

  // 3. Determine the "last node before actions" — either the trigger,
  //    a single condition, or an AND gate combining multiple conditions.
  int preActionNodeIndex;
  String preActionOutputType = 'event_out';

  if (conditions.isEmpty) {
    // No conditions — trigger feeds directly into actions.
    preActionNodeIndex = triggerIndex;
  } else if (conditions.length == 1) {
    // Single condition — it feeds directly into actions.
    preActionNodeIndex = conditionIndices.first;
  } else {
    // Multiple conditions — insert an AND gate to combine them.
    final andRow =
        _kDecompileRowStart +
        ((conditions.length - 1) * _kDecompileRowSpacing / 2);

    nodes.add(
      DecompiledNode(
        type: LogicGateTypes.and,
        offset: Offset(_kDecompileColAndGate, andRow),
      ),
    );
    final andIndex = nodes.length - 1;

    // Wire each condition → AND gate input.
    for (int i = 0; i < conditionIndices.length; i++) {
      connections.add(
        DecompiledConnection(
          fromNodeIndex: conditionIndices[i],
          fromOutputType: 'event_out',
          toNodeIndex: andIndex,
          toInputType: 'event_in_$i',
        ),
      );
    }

    preActionNodeIndex = andIndex;
  }

  // 4. Create action nodes.
  for (int i = 0; i < automation.actions.length; i++) {
    final action = automation.actions[i];
    final actionRow = _kDecompileRowStart + (i * _kDecompileRowSpacing);

    nodes.add(
      DecompiledNode(
        type: action.type.name,
        offset: Offset(_kDecompileColAction, actionRow),
        config: action.config.isNotEmpty ? action.config : null,
      ),
    );
    final actionIndex = nodes.length - 1;

    // Wire pre-action node → action.
    connections.add(
      DecompiledConnection(
        fromNodeIndex: preActionNodeIndex,
        fromOutputType: preActionOutputType,
        toNodeIndex: actionIndex,
        toInputType: 'action_in',
      ),
    );
  }

  return DecompiledGraph(nodes: nodes, connections: connections);
}

// ---------------------------------------------------------------------------
// Internal: recursive path tracer
// ---------------------------------------------------------------------------

/// Recursively traces paths from a node back to a trigger node.
///
/// Returns a list of [_CompiledPath] objects, one for each distinct path
/// through the graph (OR gates cause forking).
///
/// [visited] tracks node IDs to detect cycles. A cycle is reported as an
/// error and the path is abandoned.
List<_CompiledPath> _tracePaths(
  VSNodeData node,
  Set<String> visited,
  List<FlowCompilationError> errors,
  List<FlowCompilationWarning> warnings,
) {
  // Cycle detection.
  if (visited.contains(node.id)) {
    errors.add(
      FlowCompilationError(
        message:
            'Cycle detected at node "${node.title}" — '
            'automation graphs must be acyclic.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );
    return [];
  }
  visited.add(node.id);

  try {
    // Base case: trigger node.
    if (_isTriggerNode(node)) {
      return [_pathFromTrigger(node)];
    }

    // Condition node: extract condition, trace upstream.
    if (node is ConditionNode) {
      return _traceConditionNode(node, visited, errors, warnings);
    }

    // Logic gates.
    if (node.type == LogicGateTypes.and) {
      return _traceAndGate(node, visited, errors, warnings);
    }
    if (node.type == LogicGateTypes.or) {
      return _traceOrGate(node, visited, errors, warnings);
    }
    if (node.type == LogicGateTypes.not) {
      return _traceNotGate(node, visited, errors, warnings);
    }
    if (node.type == LogicGateTypes.delay) {
      return _traceDelayGate(node, visited, errors, warnings);
    }

    // Unknown node type in the path.
    warnings.add(
      FlowCompilationWarning(
        message:
            'Unknown node type "${node.type}" encountered during path '
            'tracing. Attempting to trace through its first input.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );

    // Best-effort: try to follow the first connected input.
    return _traceFirstInput(node, visited, errors, warnings);
  } finally {
    visited.remove(node.id);
  }
}

/// Builds a _CompiledPath from a trigger node.
_CompiledPath _pathFromTrigger(VSNodeData triggerNode) {
  Map<String, dynamic> config = {};
  if (triggerNode is VSWidgetNode) {
    final rawConfig = triggerNode.getValue();
    if (rawConfig is Map<String, dynamic>) {
      config = rawConfig;
    } else if (rawConfig is Map) {
      config = Map<String, dynamic>.from(rawConfig);
    }
  }

  return _CompiledPath(
    triggerType: triggerNode.type,
    triggerConfig: config,
    triggerNodeId: triggerNode.id,
  );
}

/// Traces through a condition node: extracts the condition, then continues
/// tracing upstream.
List<_CompiledPath> _traceConditionNode(
  ConditionNode node,
  Set<String> visited,
  List<FlowCompilationError> errors,
  List<FlowCompilationWarning> warnings,
) {
  // Extract condition from the node.
  final condition = _extractCondition(node);

  // Find upstream node through event_in.
  final upstream = _findUpstreamNode(node, 'event_in');
  if (upstream == null) {
    errors.add(
      FlowCompilationError(
        message:
            'Condition node "${node.title}" has no upstream connection '
            'on its event input.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );
    return [];
  }

  // Trace upstream and prepend this condition to each resulting path.
  final upstreamPaths = _tracePaths(upstream, visited, errors, warnings);
  if (condition != null) {
    return upstreamPaths
        .map((path) => path.withConditions([condition]))
        .toList();
  }
  return upstreamPaths;
}

/// Traces through an AND gate: walks ALL connected inputs and merges the
/// conditions from all branches into a single path.
///
/// All branches through an AND gate must converge to the same trigger.
/// If they don't, the first trigger found is used and a warning is emitted.
List<_CompiledPath> _traceAndGate(
  VSNodeData node,
  Set<String> visited,
  List<FlowCompilationError> errors,
  List<FlowCompilationWarning> warnings,
) {
  final connectedInputs = _getConnectedInputs(node);

  if (connectedInputs.isEmpty) {
    errors.add(
      FlowCompilationError(
        message: 'AND gate "${node.title}" has no connected inputs.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );
    return [];
  }

  // Trace each input branch independently.
  final allBranchPaths = <List<_CompiledPath>>[];
  for (final upstream in connectedInputs) {
    final branchVisited = Set<String>.from(visited);
    final branchPaths = _tracePaths(upstream, branchVisited, errors, warnings);
    if (branchPaths.isNotEmpty) {
      allBranchPaths.add(branchPaths);
    }
  }

  if (allBranchPaths.isEmpty) {
    errors.add(
      FlowCompilationError(
        message: 'AND gate "${node.title}" has no valid upstream paths.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );
    return [];
  }

  // For an AND gate, we merge ALL conditions from ALL branches.
  // All branches should share the same trigger. We take the trigger from
  // the first branch and merge conditions from all branches.

  // Start with the first branch's paths.
  List<_CompiledPath> merged = allBranchPaths.first;

  for (int i = 1; i < allBranchPaths.length; i++) {
    final branchPaths = allBranchPaths[i];
    final newMerged = <_CompiledPath>[];

    for (final existing in merged) {
      for (final branch in branchPaths) {
        // Check trigger compatibility.
        if (existing.triggerType != branch.triggerType) {
          warnings.add(
            FlowCompilationWarning(
              message:
                  'AND gate "${node.title}" has inputs from different triggers '
                  '("${existing.triggerType}" and "${branch.triggerType}"). '
                  'Using the first trigger.',
              nodeId: node.id,
              nodeType: node.type,
            ),
          );
        }

        // Merge conditions from both paths.
        final mergedConditions = <AutomationCondition>[
          ...existing.conditions,
          ...branch.conditions,
        ];

        // Take the maximum delay.
        int? delay = existing.delaySeconds;
        if (branch.delaySeconds != null) {
          delay = delay != null && delay > branch.delaySeconds!
              ? delay
              : branch.delaySeconds;
        }

        newMerged.add(
          _CompiledPath(
            triggerType: existing.triggerType,
            triggerConfig: existing.triggerConfig,
            triggerNodeId: existing.triggerNodeId,
            conditions: mergedConditions,
            delaySeconds: delay,
          ),
        );
      }
    }

    merged = newMerged;
  }

  return merged;
}

/// Traces through an OR gate: walks each connected input independently and
/// returns ALL paths from ALL branches.
///
/// Each branch through an OR gate produces separate Automation objects.
List<_CompiledPath> _traceOrGate(
  VSNodeData node,
  Set<String> visited,
  List<FlowCompilationError> errors,
  List<FlowCompilationWarning> warnings,
) {
  final connectedInputs = _getConnectedInputs(node);

  if (connectedInputs.isEmpty) {
    errors.add(
      FlowCompilationError(
        message: 'OR gate "${node.title}" has no connected inputs.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );
    return [];
  }

  // Each branch produces independent paths.
  final allPaths = <_CompiledPath>[];
  for (final upstream in connectedInputs) {
    final branchVisited = Set<String>.from(visited);
    final branchPaths = _tracePaths(upstream, branchVisited, errors, warnings);
    allPaths.addAll(branchPaths);
  }

  return allPaths;
}

/// Traces through a NOT gate: follows the single upstream input and inverts
/// the conditions found on the resulting paths.
List<_CompiledPath> _traceNotGate(
  VSNodeData node,
  Set<String> visited,
  List<FlowCompilationError> errors,
  List<FlowCompilationWarning> warnings,
) {
  final upstream = _findUpstreamNode(node, 'event_in');
  if (upstream == null) {
    errors.add(
      FlowCompilationError(
        message: 'NOT gate "${node.title}" has no upstream connection.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );
    return [];
  }

  final upstreamPaths = _tracePaths(upstream, visited, errors, warnings);

  // Invert conditions on each path. If the upstream node is a condition,
  // its condition will be in the path. We invert the most recent condition
  // (the one closest to the NOT gate) on each path.
  return upstreamPaths.map((path) {
    if (path.conditions.isEmpty) {
      // NOT gate applied to a trigger with no conditions — warn and pass
      // through. This is semantically questionable but not a hard error.
      warnings.add(
        FlowCompilationWarning(
          message:
              'NOT gate "${node.title}" has no condition to invert — '
              'the NOT gate is ignored.',
          nodeId: node.id,
          nodeType: node.type,
        ),
      );
      return path;
    }

    // Invert the last condition in the list (the one immediately upstream
    // of the NOT gate in the graph).
    final invertedConditions = List<AutomationCondition>.from(path.conditions);
    final lastCondition = invertedConditions.removeLast();
    final invertedType = _invertConditionType(lastCondition.type);

    invertedConditions.add(
      AutomationCondition(type: invertedType, config: lastCondition.config),
    );

    return _CompiledPath(
      triggerType: path.triggerType,
      triggerConfig: path.triggerConfig,
      triggerNodeId: path.triggerNodeId,
      conditions: invertedConditions,
      delaySeconds: path.delaySeconds,
    );
  }).toList();
}

/// Traces through a Delay gate: follows the upstream input and adds delay
/// metadata to the resulting paths.
List<_CompiledPath> _traceDelayGate(
  VSNodeData node,
  Set<String> visited,
  List<FlowCompilationError> errors,
  List<FlowCompilationWarning> warnings,
) {
  final upstream = _findUpstreamNode(node, 'event_in');
  if (upstream == null) {
    errors.add(
      FlowCompilationError(
        message: 'Delay gate "${node.title}" has no upstream connection.',
        nodeId: node.id,
        nodeType: node.type,
      ),
    );
    return [];
  }

  // Extract delay configuration.
  final delayConfig = getDelayConfig(node);
  final delaySeconds = delayConfig?['delaySeconds'] as int? ?? 300;

  final upstreamPaths = _tracePaths(upstream, visited, errors, warnings);
  return upstreamPaths.map((path) => path.withDelay(delaySeconds)).toList();
}

/// Fallback tracer: follows the first connected input of an unknown node.
List<_CompiledPath> _traceFirstInput(
  VSNodeData node,
  Set<String> visited,
  List<FlowCompilationError> errors,
  List<FlowCompilationWarning> warnings,
) {
  for (final input in node.inputData) {
    final upstream = input.connectedInterface?.nodeData;
    if (upstream != null) {
      return _tracePaths(upstream, visited, errors, warnings);
    }
  }
  return [];
}

// ---------------------------------------------------------------------------
// Internal: helpers
// ---------------------------------------------------------------------------

/// Finds the upstream node connected to a specific input type on [node].
VSNodeData? _findUpstreamNode(VSNodeData node, String inputType) {
  for (final input in node.inputData) {
    if (input.type == inputType) {
      return input.connectedInterface?.nodeData;
    }
  }
  // Fallback: try any connected input.
  for (final input in node.inputData) {
    final upstream = input.connectedInterface?.nodeData;
    if (upstream != null) return upstream;
  }
  return null;
}

/// Returns all upstream nodes connected to the inputs of [node].
///
/// For VSListNode (AND/OR gates), this handles the dynamic input list.
List<VSNodeData> _getConnectedInputs(VSNodeData node) {
  final upstream = <VSNodeData>[];

  if (node is VSListNode) {
    // VSListNode has dynamic inputs. Use getCleanInputs to get only
    // the inputs with actual connections.
    for (final input in node.getCleanInputs()) {
      final connected = input.connectedInterface?.nodeData;
      if (connected != null) {
        upstream.add(connected);
      }
    }
  } else {
    for (final input in node.inputData) {
      final connected = input.connectedInterface?.nodeData;
      if (connected != null) {
        upstream.add(connected);
      }
    }
  }

  return upstream;
}

/// Extracts an AutomationCondition from a ConditionNode.
AutomationCondition? _extractCondition(ConditionNode node) {
  final conditionType = _resolveConditionType(node.conditionType);
  if (conditionType == null) {
    return null;
  }

  Map<String, dynamic> config = {};
  final rawConfig = node.getConfig();
  if (rawConfig is Map<String, dynamic>) {
    config = rawConfig;
  } else if (rawConfig is Map) {
    config = Map<String, dynamic>.from(rawConfig);
  }

  return AutomationCondition(type: conditionType, config: config);
}

/// Extracts the action configuration map from an ActionNode.
Map<String, dynamic> _extractActionConfig(ActionNode node) {
  final raw = node.getConfig();
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return {};
}

/// Resolves a trigger type string to a TriggerType enum value.
TriggerType? _resolveTriggerType(String typeName) {
  for (final t in TriggerType.values) {
    if (t.name == typeName) return t;
  }
  return null;
}

/// Resolves an action type string to an ActionType enum value.
ActionType? _resolveActionType(String typeName) {
  for (final t in ActionType.values) {
    if (t.name == typeName) return t;
  }
  return null;
}

/// Resolves a condition node type string to a [ConditionType] enum value.
///
/// Supports both prefixed node type strings (e.g. `cond_nodeOnline` from
/// [ConditionTypes]) and raw enum names (e.g. `timeRange`).
ConditionType? _resolveConditionType(String typeName) {
  // Fast path: direct lookup via ConditionTypes.toEnum handles prefixed
  // condition types (e.g. cond_nodeOnline → ConditionType.nodeOnline).
  final direct = ConditionTypes.toEnum[typeName];
  if (direct != null) return direct;

  // Fallback: match against enum .name for non-prefixed types.
  for (final t in ConditionType.values) {
    if (t.name == typeName) return t;
  }
  return null;
}

/// Inverts a condition type using the inverse map.
///
/// For types with a natural inverse (e.g. nodeOnline↔nodeOffline,
/// batteryAbove↔batteryBelow), returns the inverse type.
/// For types without a clean inverse (e.g. timeRange, dayOfWeek),
/// returns the same type — the engine will need to handle these via
/// runtime inversion if supported.
ConditionType _invertConditionType(ConditionType type) {
  final nodeType = ConditionTypes.fromEnum[type] ?? type.name;
  final inverseName = _conditionInverseMap[nodeType];
  if (inverseName != null && inverseName != nodeType) {
    return _resolveConditionType(inverseName) ?? type;
  }
  // No clean inverse exists — return the same type.
  // The caller should note that this condition could not be fully inverted.
  return type;
}

// ---------------------------------------------------------------------------
// Internal: action entry for grouping
// ---------------------------------------------------------------------------

/// Temporary structure holding action node data during compilation.
class _ActionEntry {
  const _ActionEntry({
    required this.nodeId,
    required this.actionType,
    required this.config,
    required this.title,
  });

  final String nodeId;
  final String actionType;
  final Map<String, dynamic> config;
  final String title;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Validates a node graph for completeness before compilation.
///
/// Returns a list of validation issues. An empty list means the graph is
/// valid and ready to compile.
///
/// This is a lighter-weight check than full compilation — it verifies
/// structural requirements without walking the full graph.
List<FlowCompilationError> validateGraph(Map<String, VSNodeData> nodes) {
  final issues = <FlowCompilationError>[];

  // Must have at least one trigger.
  final hasTrigger = nodes.values.any(_isTriggerNode);
  if (!hasTrigger) {
    issues.add(
      const FlowCompilationError(
        message:
            'Graph has no trigger node. Add a trigger to define when '
            'the automation should fire.',
      ),
    );
  }

  // Must have at least one action.
  final hasAction = nodes.values.any((n) => n is ActionNode);
  if (!hasAction) {
    issues.add(
      const FlowCompilationError(
        message:
            'Graph has no action node. Add an action to define what '
            'happens when the automation fires.',
      ),
    );
  }

  // Each action node must have a connected input.
  for (final entry in nodes.entries) {
    final node = entry.value;
    if (node is ActionNode) {
      final input = node.inputData.firstOrNull;
      if (input == null || input.connectedInterface == null) {
        issues.add(
          FlowCompilationError(
            message:
                'Action node "${node.title}" is not connected to any '
                'upstream node.',
            nodeId: entry.key,
            nodeType: node.type,
          ),
        );
      }
    }
  }

  // Logic gates must have at least one connected input.
  for (final entry in nodes.entries) {
    final node = entry.value;
    if (isLogicGateNode(node)) {
      final connectedInputs = _getConnectedInputs(node);
      if (connectedInputs.isEmpty) {
        // Only warn if the gate has downstream connections (someone is using it).
        final hasDownstream = nodes.values.any(
          (other) => other.inputData.any(
            (input) => input.connectedInterface?.nodeData?.id == node.id,
          ),
        );
        if (hasDownstream) {
          issues.add(
            FlowCompilationError(
              message:
                  'Logic gate "${node.title}" has no connected inputs but '
                  'has downstream nodes depending on it.',
              nodeId: entry.key,
              nodeType: node.type,
            ),
          );
        }
      }
    }
  }

  return issues;
}
