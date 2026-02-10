// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Fixed class name spelling: EvalutationError → EvaluationError

import 'vs_node_data.dart';

/// Error that occurs during node tree evaluation.
///
/// Contains the node that caused the error, its input data at the time
/// of evaluation, and the underlying error object.
class EvaluationError {
  EvaluationError({
    required this.nodeData,
    required this.inputData,
    required this.error,
  });

  /// The node whose output function threw during evaluation.
  final VSNodeData nodeData;

  /// The input values that were passed to the node's output function.
  final Map<String, dynamic> inputData;

  /// The underlying error thrown by the output function.
  final Object error;

  @override
  String toString() {
    return 'EvaluationError(node: ${nodeData.type} [${nodeData.id}], '
        'error: $error)';
  }
}
