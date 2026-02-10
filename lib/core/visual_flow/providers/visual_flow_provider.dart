// SPDX-License-Identifier: GPL-3.0-or-later
// Riverpod provider for the Socialmesh visual automation flow builder.
//
// This provider manages the VSNodeManager lifecycle, graph state, and bridges
// the visual editor to the automations system via the flow compiler.
//
// Architecture:
// - VSNodeDataProvider (ChangeNotifier) is kept INTERNAL to the node widget
//   tree and is never exposed to the global Riverpod provider graph.
// - This Notifier owns the VSNodeManager and exposes compile/serialize/load
//   operations to the rest of the app.
// - The visual flow screen creates a VSNodeDataProvider locally and feeds it
//   the VSNodeManager from this provider.
//
// State lifecycle:
// - createNew() → empty graph with registered node builders
// - loadFromJson(String) → deserialize a previously saved graph
// - loadFromAutomation(Automation) → decompile an Automation into a graph
// - compile() → walk the graph and produce Automation objects
// - serialize() → JSON string of the current graph state
// - save() → compile + persist via automationsProvider

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/automations/models/automation.dart';
import '../compiler/flow_compiler.dart';
import '../nodes/action_nodes.dart';
import '../nodes/condition_nodes.dart';
import '../nodes/logic_gate_nodes.dart';
import '../nodes/nodedex_query_nodes.dart';
import '../nodes/trigger_nodes.dart';
import '../vs_node_view/common.dart';
import '../vs_node_view/data/vs_interface.dart';
import '../vs_node_view/data/vs_node_data.dart';
import '../vs_node_view/data/vs_node_manager.dart';
import '../vs_node_view/special_nodes/vs_widget_node.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state snapshot for the visual flow editor.
class VisualFlowState {
  const VisualFlowState({
    this.isLoaded = false,
    this.isDirty = false,
    this.flowName,
    this.sourceAutomationId,
    this.lastCompilationResult,
    this.validationErrors = const [],
    this.graphMetadata,
  });

  /// Whether a graph is currently loaded (new or from file).
  final bool isLoaded;

  /// Whether the graph has unsaved changes since last compile/save.
  final bool isDirty;

  /// User-assigned name for this flow.
  final String? flowName;

  /// If this flow was loaded from an existing Automation, its ID.
  ///
  /// Used to update the existing Automation on save rather than creating
  /// a new one.
  final String? sourceAutomationId;

  /// Result of the most recent compilation attempt.
  final FlowCompilationResult? lastCompilationResult;

  /// Validation errors from the most recent validate() call.
  final List<FlowCompilationError> validationErrors;

  /// Graph↔Automation mapping metadata from the last successful compile.
  final FlowGraphMetadata? graphMetadata;

  /// Whether the graph is valid and ready to compile.
  bool get isValid => validationErrors.isEmpty;

  /// Whether the last compilation succeeded.
  bool get isCompiled =>
      lastCompilationResult != null && lastCompilationResult!.isSuccess;

  VisualFlowState copyWith({
    bool? isLoaded,
    bool? isDirty,
    String? flowName,
    String? sourceAutomationId,
    FlowCompilationResult? lastCompilationResult,
    List<FlowCompilationError>? validationErrors,
    FlowGraphMetadata? graphMetadata,
    bool clearSourceAutomationId = false,
    bool clearLastCompilationResult = false,
    bool clearGraphMetadata = false,
  }) {
    return VisualFlowState(
      isLoaded: isLoaded ?? this.isLoaded,
      isDirty: isDirty ?? this.isDirty,
      flowName: flowName ?? this.flowName,
      sourceAutomationId: clearSourceAutomationId
          ? null
          : (sourceAutomationId ?? this.sourceAutomationId),
      lastCompilationResult: clearLastCompilationResult
          ? null
          : (lastCompilationResult ?? this.lastCompilationResult),
      validationErrors: validationErrors ?? this.validationErrors,
      graphMetadata: clearGraphMetadata
          ? null
          : (graphMetadata ?? this.graphMetadata),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provider for the visual flow editor state and operations.
///
/// Usage:
/// ```dart
/// final flowState = ref.watch(visualFlowProvider);
/// final flowNotifier = ref.read(visualFlowProvider.notifier);
///
/// // Create a new empty graph
/// flowNotifier.createNew(name: 'My Automation');
///
/// // Access the node manager for the visual editor widget
/// final manager = flowNotifier.nodeManager;
///
/// // Compile and get automations
/// final result = flowNotifier.compile();
/// ```
final visualFlowProvider =
    NotifierProvider<VisualFlowNotifier, VisualFlowState>(
      VisualFlowNotifier.new,
    );

/// Notifier managing the visual flow editor lifecycle.
///
/// Owns the [VSNodeManager] and provides methods to create, load, compile,
/// serialize, and save visual automation flows.
class VisualFlowNotifier extends Notifier<VisualFlowState> {
  VSNodeManager? _nodeManager;

  /// Registered node builders for the visual editor context menu.
  ///
  /// These are the subgroups shown when the user taps the canvas to add
  /// a new node.
  late final List<dynamic> _nodeBuilders;

  /// Additional node builders used only for deserialization (flat list).
  late final List<VSNodeDataBuilder> _additionalNodeBuilders;

  @override
  VisualFlowState build() {
    _nodeBuilders = _buildNodeBuilderList();
    _additionalNodeBuilders = _buildAdditionalNodeBuilders();

    ref.onDispose(() {
      _nodeManager = null;
    });

    return const VisualFlowState();
  }

  // -------------------------------------------------------------------------
  // Public API: node manager access
  // -------------------------------------------------------------------------

  /// The current VSNodeManager, or null if no graph is loaded.
  ///
  /// The visual editor widget should access this to create a local
  /// VSNodeDataProvider. Do NOT expose the VSNodeDataProvider through
  /// this provider — it is a ChangeNotifier that belongs to the widget tree.
  VSNodeManager? get nodeManager => _nodeManager;

  /// The registered node builders for the context menu.
  ///
  /// Passed to VSNodeDataProvider for the "Add Node" context menu.
  List<dynamic> get nodeBuilders => _nodeBuilders;

  // -------------------------------------------------------------------------
  // Public API: lifecycle
  // -------------------------------------------------------------------------

  /// Creates a new empty graph with all node builders registered.
  void createNew({String? name}) {
    _nodeManager = VSNodeManager(
      nodeBuilders: _nodeBuilders,
      additionalNodes: _additionalNodeBuilders,
      onNodesUpdate: _onNodesUpdated,
    );

    state = VisualFlowState(
      isLoaded: true,
      isDirty: false,
      flowName: name ?? 'New Flow',
      validationErrors: const [],
    );
  }

  /// Loads a graph from a serialized JSON string.
  ///
  /// Used when opening a previously saved flow for editing.
  void loadFromJson(String serializedGraph, {String? name, String? sourceId}) {
    _nodeManager = VSNodeManager(
      nodeBuilders: _nodeBuilders,
      serializedNodes: serializedGraph,
      additionalNodes: _additionalNodeBuilders,
      onNodesUpdate: _onNodesUpdated,
      onBuilderMissing: (nodeJson) {
        debugPrint(
          'Visual flow: missing builder for node type "${nodeJson["type"]}"',
        );
      },
    );

    state = VisualFlowState(
      isLoaded: true,
      isDirty: false,
      flowName: name,
      sourceAutomationId: sourceId,
      validationErrors: const [],
    );
  }

  /// Loads a graph from a [FlowGraphMetadata] object.
  ///
  /// Restores both the graph and the automation mapping metadata.
  void loadFromMetadata(FlowGraphMetadata metadata) {
    loadFromJson(metadata.graphJson, name: metadata.flowName);

    state = state.copyWith(graphMetadata: metadata);
  }

  /// Decompiles an existing [Automation] into a visual graph.
  ///
  /// Creates the appropriate nodes and wires them together based on the
  /// automation's trigger, conditions, and actions. The resulting graph
  /// is auto-laid out left-to-right.
  void loadFromAutomation(Automation automation) {
    // Create a fresh manager first.
    createNew(name: automation.name);

    final manager = _nodeManager;
    if (manager == null) return;

    final graph = decompileAutomation(automation);

    // Create nodes using the registered builders.
    final createdNodes = <int, VSNodeData>{};

    for (int i = 0; i < graph.nodes.length; i++) {
      final spec = graph.nodes[i];
      final builder = _findBuilder(spec.type);
      if (builder == null) {
        debugPrint(
          'Visual flow: no builder for decompiled node type "${spec.type}"',
        );
        continue;
      }

      final node = builder(spec.offset, null);

      // Apply config if provided.
      if (spec.config != null) {
        if (node is VSWidgetNode) {
          node.setValue(spec.config);
        } else if (node is ConditionNode) {
          node.setConfig(spec.config);
        } else if (node is ActionNode) {
          node.setConfig(spec.config);
        }
      }

      createdNodes[i] = node;
    }

    // Register all nodes with the manager.
    if (createdNodes.isNotEmpty) {
      manager.updateOrCreateNodes(createdNodes.values.toList());
    }

    // Wire connections.
    for (final conn in graph.connections) {
      final fromNode = createdNodes[conn.fromNodeIndex];
      final toNode = createdNodes[conn.toNodeIndex];

      if (fromNode == null || toNode == null) continue;

      // Find the output interface on the source node.
      VSOutputData<Object?>? outputInterface;
      for (final output in fromNode.outputData) {
        if (output.type == conn.fromOutputType) {
          outputInterface = output;
          break;
        }
      }

      // For list nodes (AND/OR gates), the output type should match.
      outputInterface ??= fromNode.outputData.firstOrNull;

      if (outputInterface == null) continue;

      // Find the input interface on the destination node.
      for (final input in toNode.inputData) {
        if (input.type == conn.toInputType) {
          input.connectedInterface = outputInterface;
          break;
        }
      }
    }

    // Update the manager with the wired nodes.
    manager.updateOrCreateNodes(createdNodes.values.toList());

    state = state.copyWith(sourceAutomationId: automation.id, isDirty: false);
  }

  /// Closes the current graph and resets state.
  void close() {
    _nodeManager = null;
    state = const VisualFlowState();
  }

  // -------------------------------------------------------------------------
  // Public API: editing
  // -------------------------------------------------------------------------

  /// Updates the flow name.
  void setFlowName(String name) {
    state = state.copyWith(flowName: name, isDirty: true);
  }

  /// Marks the graph as having unsaved changes.
  ///
  /// Called by the visual editor widget when the user modifies nodes or
  /// connections.
  void markDirty() {
    if (!state.isDirty) {
      state = state.copyWith(isDirty: true);
    }
  }

  /// Marks the graph as clean (no unsaved changes).
  void markClean() {
    if (state.isDirty) {
      state = state.copyWith(isDirty: false);
    }
  }

  // -------------------------------------------------------------------------
  // Public API: validation and compilation
  // -------------------------------------------------------------------------

  /// Validates the current graph for structural correctness.
  ///
  /// Returns the list of validation errors. An empty list means valid.
  List<FlowCompilationError> validate() {
    final manager = _nodeManager;
    if (manager == null) {
      return [const FlowCompilationError(message: 'No graph is loaded.')];
    }

    final errors = validateGraph(manager.nodes);
    state = state.copyWith(validationErrors: errors);
    return errors;
  }

  /// Compiles the current graph into Automation objects.
  ///
  /// Returns the compilation result containing automations, errors, and
  /// warnings. Also updates the provider state with the result.
  FlowCompilationResult compile() {
    final manager = _nodeManager;
    if (manager == null) {
      final result = const FlowCompilationResult(
        automations: [],
        errors: [FlowCompilationError(message: 'No graph is loaded.')],
      );
      state = state.copyWith(lastCompilationResult: result);
      return result;
    }

    // Validate first.
    final validationErrors = validateGraph(manager.nodes);
    if (validationErrors.isNotEmpty) {
      final result = FlowCompilationResult(
        automations: const [],
        errors: validationErrors,
      );
      state = state.copyWith(
        lastCompilationResult: result,
        validationErrors: validationErrors,
      );
      return result;
    }

    // Compile.
    final result = compileFlowGraph(
      nodes: manager.nodes,
      flowName: state.flowName,
      graphJson: manager.serializeNodes(),
    );

    state = state.copyWith(
      lastCompilationResult: result,
      validationErrors: result.errors,
      graphMetadata: result.graphMetadata,
    );

    return result;
  }

  /// Serializes the current graph to a JSON string.
  ///
  /// Returns null if no graph is loaded.
  String? serialize() {
    return _nodeManager?.serializeNodes();
  }

  /// Returns the current graph nodes map.
  ///
  /// Returns null if no graph is loaded.
  Map<String, VSNodeData>? get currentNodes => _nodeManager?.nodes;

  /// Returns the count of nodes in the current graph.
  int get nodeCount => _nodeManager?.nodes.length ?? 0;

  /// Returns true if the graph has any action nodes.
  bool get hasActionNodes {
    final nodes = _nodeManager?.nodes;
    if (nodes == null) return false;
    return nodes.values.any((n) => isActionNode(n));
  }

  /// Returns true if the graph has any trigger nodes.
  bool get hasTriggerNodes {
    final nodes = _nodeManager?.nodes;
    if (nodes == null) return false;
    return nodes.values.any((n) => _isTriggerNode(n));
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  /// Callback fired by VSNodeManager when nodes are updated.
  void _onNodesUpdated(
    Map<String, VSNodeData> oldData,
    Map<String, VSNodeData> newData,
  ) {
    // Mark dirty on any node change.
    if (state.isLoaded && !state.isDirty) {
      state = state.copyWith(isDirty: true);
    }
  }

  /// Builds the node builder list with subgroups for the context menu.
  List<dynamic> _buildNodeBuilderList() {
    return [
      triggerNodeSubgroup(),
      conditionNodeSubgroup(),
      logicGateNodeSubgroup(),
      actionNodeSubgroup(),
      nodeDexQueryNodeSubgroup(),
    ];
  }

  /// Builds a flat list of all node builders for deserialization.
  ///
  /// This ensures that serialized graphs referencing any known node type
  /// can be deserialized even if the builder is not in the context menu
  /// subgroups.
  List<VSNodeDataBuilder> _buildAdditionalNodeBuilders() {
    // The subgroup builders already register themselves. Additional builders
    // are only needed for node types that exist outside the subgroups.
    // For now, return an empty list — all node types are covered by the
    // subgroups.
    return [];
  }

  /// Finds a node builder by type string.
  ///
  /// Searches through all registered builders to find one that produces
  /// a node with the matching type.
  VSNodeDataBuilder? _findBuilder(String type) {
    if (_nodeManager == null) return null;

    // The serialization manager keeps a map of type → builder.
    // We can access it through the nodeBuildersMap, but it contains
    // subgroup maps too. Walk it to find the builder.
    return _findBuilderInMap(_nodeManager!.nodeBuildersMap, type);
  }

  /// Recursively searches a node builders map (which may contain subgroup
  /// maps) for a builder matching the given type.
  VSNodeDataBuilder? _findBuilderInMap(Map<String, dynamic> map, String type) {
    for (final entry in map.entries) {
      if (entry.key == type && entry.value is VSNodeDataBuilder) {
        return entry.value as VSNodeDataBuilder;
      }
      if (entry.value is Map<String, dynamic>) {
        final found = _findBuilderInMap(
          entry.value as Map<String, dynamic>,
          type,
        );
        if (found != null) return found;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Trigger node detection (duplicated from compiler for provider-level use)
// ---------------------------------------------------------------------------

/// Set of all known trigger type strings.
final Set<String> _triggerTypeSet = {
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
  return node is VSWidgetNode && _triggerTypeSet.contains(node.type);
}

// ---------------------------------------------------------------------------
// Derived providers
// ---------------------------------------------------------------------------

/// Whether the visual flow editor currently has a loaded graph.
final visualFlowIsLoadedProvider = Provider<bool>((ref) {
  return ref.watch(visualFlowProvider).isLoaded;
});

/// Whether the visual flow editor has unsaved changes.
final visualFlowIsDirtyProvider = Provider<bool>((ref) {
  return ref.watch(visualFlowProvider).isDirty;
});

/// The current flow name, or null if no flow is loaded.
final visualFlowNameProvider = Provider<String?>((ref) {
  return ref.watch(visualFlowProvider).flowName;
});

/// Whether the current graph is valid and ready to compile.
final visualFlowIsValidProvider = Provider<bool>((ref) {
  return ref.watch(visualFlowProvider).isValid;
});

/// The most recent compilation result, or null if not yet compiled.
final visualFlowCompilationResultProvider = Provider<FlowCompilationResult?>((
  ref,
) {
  return ref.watch(visualFlowProvider).lastCompilationResult;
});

/// The number of validation errors in the current graph.
final visualFlowErrorCountProvider = Provider<int>((ref) {
  return ref.watch(visualFlowProvider).validationErrors.length;
});
