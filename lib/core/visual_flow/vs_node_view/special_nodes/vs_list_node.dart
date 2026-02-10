// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import '../data/vs_interface.dart';
import '../data/vs_node_data.dart';

class VSListNode extends VSNodeData {
  /// List Node
  ///
  /// Can be used to add a node that bundles multiple inputs into one output.
  VSListNode({
    super.id,
    required super.type,
    required super.widgetOffset,
    required this.inputBuilder,
    required super.outputData,
    super.nodeWidth,
    super.title,
    super.toolTip,
    super.onUpdatedConnection,

    /// Can be used to set the initial connection of the first created input.
    VSOutputData? referenceConnection,
  }) : super(
         inputData: [
           inputBuilder(0, null)..connectedInterface = referenceConnection,
         ],
       ) {
    if (inputData.first.connectedInterface != null) {
      _setInputs([inputData.first.connectedInterface]);
    }
  }

  /// Used to build the node's inputs dynamically.
  ///
  /// [index] is the current index of this input in the [inputData] of this
  /// node.
  ///
  /// Make sure to pass [connection] to [initialConnection] of your input
  /// interface.
  VSInputData Function(int index, VSOutputData? connection) inputBuilder;

  @override
  Function(VSInputData interfaceData)? get onUpdatedConnection => _updateInputs;

  /// The inputs of this [VSListNode] without [VSInputData] that have no
  /// connectedInterface.
  List<VSInputData> getCleanInputs() {
    return inputData
        .where((element) => element.connectedInterface != null)
        .toList();
  }

  void _updateInputs(VSInputData interfaceData) {
    final cleanInputData = getCleanInputs();
    _setInputs(cleanInputData.map((e) => e.connectedInterface));

    super.onUpdatedConnection?.call(interfaceData);
  }

  void _setInputs(Iterable<VSOutputData?> connectedInterface) {
    final List<VSInputData> newInputData = [];
    connectedInterface = [...connectedInterface, null];

    for (int i = 0; i < connectedInterface.length; i++) {
      final currentInput = inputBuilder(
        i,
        connectedInterface.elementAtOrNull(i),
      );
      currentInput.nodeData = this;
      newInputData.add(currentInput);
    }

    inputData = newInputData;
  }

  /// Used for deserializing.
  ///
  /// Reconstructs list connections based on index.
  @override
  void setRefData(Map<String, VSOutputData?> inputRefs) {
    _setInputs(inputRefs.values);
  }
}
