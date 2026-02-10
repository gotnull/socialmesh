// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../common.dart';
import 'offset_extension.dart';
import 'vs_interface.dart';
import 'vs_node_data.dart';
import 'vs_subgroup.dart';
import '../special_nodes/vs_widget_node.dart';

class VSNodeSerializationManager {
  /// Builds maps based on supplied nodeBuilders.
  ///
  /// Makes sure supplied nodeBuilders follow guidelines.
  ///
  /// Handles serialization and deserialization.
  VSNodeSerializationManager({
    required List<dynamic> nodeBuilders,
    this.onBuilderMissing,

    /// These nodes will not be part of [contextNodeBuilders].
    ///
    /// They will only be used for deserialization.
    List<VSNodeDataBuilder>? additionalNodes,
  }) {
    if (additionalNodes != null) {
      for (final node in additionalNodes) {
        _addNodeBuilder(node);
      }
    }

    _findNodes(nodeBuilders, contextNodeBuilders);
  }

  /// This function gets called when a node failed to deserialize due to a
  /// missing builder.
  ///
  /// The nodeJSON in question is given as a parameter.
  final Function(Map nodeJSON)? onBuilderMissing;

  void _findNodes(List<dynamic> builders, Map<String, dynamic> builderMap) {
    for (final builder in builders) {
      if (builder is VSSubgroup) {
        final Map<String, dynamic> subMap = {};
        _findNodes(builder.subgroup, subMap);
        if (!builderMap.containsKey(builder.name)) {
          builderMap[builder.name] = subMap;
        } else {
          throw FormatException(
            "There are 2 or more subgroups with the name ${builder.name}. "
            "There can only be one on the same level",
          );
        }
      } else {
        VSNodeData instance = _addNodeBuilder(builder);
        builderMap[instance.type] = builder;
      }
    }
  }

  VSNodeData _addNodeBuilder(VSNodeDataBuilder builder) {
    final instance = builder(Offset.zero, null);
    if (!_nodeBuilders.containsKey(instance.type)) {
      final inputNames = instance.inputData.map((e) => e.type);
      if (inputNames.length != inputNames.toSet().length) {
        throw FormatException(
          "There are 2 or more Inputs in the node ${instance.type} with the "
          "same type. There can only be one",
        );
      }
      final outputNames = instance.outputData.map((e) => e.type);
      if (outputNames.length != outputNames.toSet().length) {
        throw FormatException(
          "There are 2 or more Outputs in the node ${instance.type} with the "
          "same type. There can only be one",
        );
      }
      _nodeBuilders[instance.type] = builder;
    } else {
      throw FormatException(
        "There are 2 or more nodes with the type ${instance.type}. "
        "There can only be one",
      );
    }
    return instance;
  }

  final Map<String, VSNodeDataBuilder> _nodeBuilders = {};
  final Map<String, dynamic> contextNodeBuilders = {};

  /// Calls jsonEncode on data.
  String serializeNodes(Map<String, VSNodeData> data) {
    return jsonEncode(data);
  }

  /// Deserializes data in two steps:
  /// 1. Builds new nodes with position and id from saved data.
  /// 2. Reconstructs connections between the nodes.
  ///
  /// Returns a `Map<NodeId, VSNodeData>`.
  Map<String, VSNodeData> deserializeNodes(String dataString) {
    final data = jsonDecode(dataString) as Map<String, dynamic>;

    final Map<String, VSNodeData> decoded = {};

    data.forEach((key, value) {
      final node = _nodeBuilders[value["type"]]?.call(Offset.zero, null);

      if (node == null) {
        debugPrint(
          "A node was serialized but the builder for its type is missing.\n"
          "It will be removed from the current node tree.\n$value",
        );
        onBuilderMissing?.call(value);
        return;
      }

      node.setBaseData(
        value["id"],
        value["title"],
        offsetFromJson(value["widgetOffset"]),
      );

      if (value["value"] != null) {
        (node as VSWidgetNode).setValue(value["value"]);
      }

      decoded[key] = node;
    });

    data.forEach((key, value) {
      final inputData = value["inputData"] as List<dynamic>;
      final Map<String, VSOutputData?> inputRefs = {};

      for (final element in inputData) {
        final serializedOutput = element["connectedNode"];

        if (serializedOutput != null) {
          final refOutput = decoded[serializedOutput["nodeData"]]?.outputData
              .firstWhere(
                (element) => element.type == serializedOutput["name"],
              );
          inputRefs[element["name"]] = refOutput;
        }
      }

      decoded[key]?.setRefData(inputRefs);
    });

    return decoded;
  }
}
