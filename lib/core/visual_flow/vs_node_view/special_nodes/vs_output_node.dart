// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Fixed class name spelling: EvalutationError → EvaluationError

import '../data/evaluation_error.dart';
import '../data/standard_interfaces/vs_dynamic_interface.dart';
import '../data/vs_interface.dart';
import '../data/vs_node_data.dart';
import 'vs_list_node.dart';

class VSOutputNode extends VSNodeData {
  /// Output Node
  ///
  /// Used to traverse the node tree and evaluate them to a result.
  VSOutputNode({
    required super.type,
    required super.widgetOffset,
    VSOutputData? ref,
    super.nodeWidth,
    super.title,
    super.toolTip,
    String? inputTitle,
    super.onUpdatedConnection,
  }) : super(
         inputData: [
           VSDynamicInputData(
             type: type,
             title: inputTitle,
             initialConnection: ref,
           ),
         ],
         outputData: const [],
       );

  /// Evaluates the tree from this node and returns the result.
  ///
  /// Supply an [onError] function to be called when an error occurs inside
  /// the evaluation.
  MapEntry<String, dynamic> evaluate({
    Function(Object e, StackTrace s)? onError,
  }) {
    try {
      Map<String, Map<String, dynamic>> nodeInputValues = {};
      _traverseInputNodes(nodeInputValues, this);

      return MapEntry(title, nodeInputValues[id]!.values.first);
    } catch (e, s) {
      onError?.call(e, s);
    }
    return MapEntry(title, null);
  }

  /// Traverses input nodes.
  ///
  /// Used by [evaluate] to recursively move through the nodes.
  void _traverseInputNodes(
    Map<String, Map<String, dynamic>> nodeInputValues,
    VSNodeData data,
  ) {
    Map<String, dynamic> inputValues = {};

    final inputs = data is VSListNode ? data.getCleanInputs() : data.inputData;

    for (final input in inputs) {
      final connectedNode = input.connectedInterface;
      if (connectedNode != null) {
        if (!nodeInputValues.containsKey(connectedNode.nodeData!.id)) {
          _traverseInputNodes(nodeInputValues, connectedNode.nodeData!);
        }

        try {
          inputValues[input.type] = connectedNode.outputFunction?.call(
            nodeInputValues[connectedNode.nodeData!.id]!,
          );
        } catch (e) {
          throw EvaluationError(
            nodeData: connectedNode.nodeData!,
            inputData: nodeInputValues[connectedNode.nodeData!.id]!,
            error: e,
          );
        }
      } else {
        inputValues[input.type] = null;
      }
    }
    nodeInputValues[data.id] = inputValues;
  }
}
