// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import '../common.dart';
import 'vs_node_data.dart';
import 'vs_node_serialization_manager.dart';
import '../special_nodes/vs_output_node.dart';

class VSNodeManager {
  /// Holds all relevant node data.
  ///
  /// Handles interactions with the data.
  ///
  /// Creates an instance of VSNodeSerializationManager to handle
  /// serializations.
  VSNodeManager({
    required List<dynamic> nodeBuilders,
    String? serializedNodes,
    this.onNodesUpdate,

    /// This function gets called when a node failed to deserialize due to a
    /// missing builder.
    ///
    /// The nodeJSON in question is given as a parameter.
    Function(Map nodeJSON)? onBuilderMissing,

    /// These nodes will not be part of [contextNodeBuilders].
    ///
    /// They will only be used for deserialization.
    List<VSNodeDataBuilder>? additionalNodes,
  }) {
    serializationManager = VSNodeSerializationManager(
      nodeBuilders: nodeBuilders,
      onBuilderMissing: onBuilderMissing,
      additionalNodes: additionalNodes,
    );

    if (serializedNodes != null) {
      _nodes = serializationManager.deserializeNodes(serializedNodes);
    }
  }

  late VSNodeSerializationManager serializationManager;

  Map<String, dynamic> get nodeBuildersMap =>
      serializationManager.contextNodeBuilders;

  /// This function gets called whenever the nodes get updated.
  ///
  /// Use it to run code synchronously.
  final void Function(
    Map<String, VSNodeData> oldData,
    Map<String, VSNodeData> newData,
  )?
  onNodesUpdate;

  Map<String, VSNodeData> _nodes = {};

  /// Returns a copy of the current node data.
  Map<String, VSNodeData> get nodes => Map.from(_nodes);
  set nodes(Map<String, VSNodeData> value) {
    onNodesUpdate?.call(_nodes, value);
    _nodes = value;
  }

  /// Returns all output nodes in the current node data.
  Iterable<VSOutputNode> get getOutputNodes =>
      _nodes.values.whereType<VSOutputNode>();

  /// Calls serializationManager.serializeNodes with the current node data and
  /// returns a String.
  String serializeNodes() {
    return serializationManager.serializeNodes(_nodes);
  }

  /// Loads nodes from string and replaces current nodes.
  void loadSerializedNodes(String serializedNodes) {
    nodes = serializationManager.deserializeNodes(serializedNodes);
  }

  /// Updates or creates nodes.
  void updateOrCreateNodes(List<VSNodeData> nodeDatas) {
    for (final node in nodeDatas) {
      _nodes[node.id] = node;
    }
    nodes = Map.from(_nodes);
  }

  /// Removes multiple nodes and clears all references.
  void removeNodes(List<VSNodeData> nodeDatas) {
    for (final node in nodeDatas) {
      _nodes.remove(node.id);
    }
    nodes = Map.from(_nodes);
    for (final node in _nodes.values) {
      for (final input in node.inputData) {
        if (nodeDatas.contains(input.connectedInterface?.nodeData)) {
          input.connectedInterface = null;
        }
      }
    }
  }

  /// Clears all nodes.
  void clearNodes() {
    nodes = {};
  }
}
