// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'package:flutter/material.dart';

import '../data/vs_interface.dart';
import '../data/vs_node_data.dart';

class VSWidgetNode extends VSNodeData {
  /// Widget Node
  ///
  /// Can be used to add a custom UI component to a node.
  VSWidgetNode({
    super.id,
    required super.type,
    required super.widgetOffset,
    required VSOutputData outputData,
    required this.setValue,
    required this.getValue,
    required this.child,
    super.nodeWidth,
    super.title,
    super.toolTip,
    super.onUpdatedConnection,
  }) : super(inputData: const [], outputData: [outputData]);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    return json..["value"] = getValue();
  }

  /// The widget displayed inside this node.
  final Widget child;

  /// Used to set the value of the supplied widget during deserialization.
  final Function(dynamic) setValue;

  /// Used to get the value of the supplied widget during serialization.
  final dynamic Function() getValue;
}
