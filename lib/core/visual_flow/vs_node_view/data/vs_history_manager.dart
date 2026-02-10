// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Fixed class name spelling: VSHistoryManger → VSHistoryManager

import 'vs_node_data_provider.dart';

class VSHistoryManager {
  /// A list of the last states [nodeManager.nodes] has had.
  ///
  /// Gets updated whenever [nodeManager]'s nodes get set.
  final List<String> _history = [];
  late VSNodeDataProvider provider;

  void updateHistory() {
    if (historyIndex < (_history.length - 1)) {
      _history.removeRange(historyIndex + 1, _history.length);
    }

    _history.add(provider.nodeManager.serializeNodes());
    historyIndex++;
  }

  /// Loads the state of [_history] at the current [historyIndex].
  void loadHistory() {
    provider.loadSerializedNodes(_history[historyIndex]);
  }

  /// The current index of the history.
  int get historyIndex => _historyIndex;
  int _historyIndex = 0;
  set historyIndex(int value) {
    if (value < 0) {
      value = 0;
    }
    if (_history.elementAtOrNull(value) != null) {
      _historyIndex = value;
    }
  }

  /// Will overwrite the current nodes with the last state according to
  /// [_history].
  ///
  /// Returns true when the state has successfully been undone.
  bool undo() {
    final willUndo = _history.isNotEmpty;
    if (willUndo) {
      historyIndex--;
      loadHistory();
    }
    return willUndo;
  }

  /// Whether there is a previous state to undo to.
  bool get canUndo => _history.isNotEmpty && _historyIndex > 0;

  /// Whether there is a next state to redo to.
  bool get canRedo => _historyIndex < (_history.length - 1);

  /// Will overwrite the current nodes with the next state according to
  /// [_history].
  ///
  /// Returns true when the state has successfully been redone.
  bool redo() {
    final willRedo = (historyIndex - 1) < _history.length;
    if (willRedo) {
      historyIndex++;
      loadHistory();
    }
    return willRedo;
  }
}
