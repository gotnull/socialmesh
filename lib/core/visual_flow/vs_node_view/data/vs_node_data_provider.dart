// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Fixed method name spelling: applyViewPortTransfrom → applyViewPortTransform
// Modified: Added grid snapping — nodes align to a visible grid on drop.
// Modified: Added drag state tracking for live drop-target preview rendering.

import 'package:flutter/material.dart';

import '../vs_node_view.dart';

/// Grid spacing for node snapping. Matches the dot-grid background spacing
/// so nodes visually land on grid intersections.
const double kNodeGridSpacing = 24.0;

/// Small data class to keep track of where the context menu is in 2D space.
///
/// Also knows if it was opened through a reference.
class ContextMenuContext {
  ContextMenuContext({required this.offset, this.reference});

  Offset offset;
  VSOutputData? reference;
}

class VSNodeDataProvider extends ChangeNotifier {
  /// Wraps [VSNodeManager] to allow UI interaction and updates.
  VSNodeDataProvider({required this.nodeManager, this.historyManager}) {
    if (historyManager != null) {
      historyManager!.provider = this;
      historyManager!.updateHistory();
    }
  }

  // ---------------------------------------------------------------------------
  // Grid snapping
  // ---------------------------------------------------------------------------

  /// Snaps an [Offset] to the nearest grid intersection.
  static Offset snapToGrid(Offset offset) {
    return Offset(
      (offset.dx / kNodeGridSpacing).round() * kNodeGridSpacing,
      (offset.dy / kNodeGridSpacing).round() * kNodeGridSpacing,
    );
  }

  // ---------------------------------------------------------------------------
  // Drag state — tracked so the canvas can render a drop-target preview
  // ---------------------------------------------------------------------------

  /// The ID of the node currently being dragged, or null.
  String? get dragNodeId => _dragNodeId;
  String? _dragNodeId;

  /// The snapped grid position where the dragged node will land.
  Offset? get dragPreviewOffset => _dragPreviewOffset;
  Offset? _dragPreviewOffset;

  /// The size (width, height) of the node being dragged, for ghost rendering.
  Size? get dragNodeSize => _dragNodeSize;
  Size? _dragNodeSize;

  /// Whether a node drag is currently in progress.
  bool get isDraggingNode => _dragNodeId != null;

  /// Called when the user starts dragging a node.
  void startNodeDrag(VSNodeData node, {Size? nodeSize}) {
    _dragNodeId = node.id;
    _dragPreviewOffset = snapToGrid(node.widgetOffset);
    _dragNodeSize = nodeSize;
    notifyListeners();
  }

  /// Called on each pointer move during a node drag.
  ///
  /// [globalOffset] is the current pointer position in screen coordinates.
  /// It is transformed into canvas coordinates and snapped to the grid.
  void updateNodeDrag(Offset globalOffset) {
    final canvasOffset = applyViewPortTransform(globalOffset);
    _dragPreviewOffset = snapToGrid(canvasOffset);
    notifyListeners();
  }

  /// Called when the user finishes dragging a node. Commits the last
  /// snapped preview position and clears drag state.
  ///
  /// Uses [dragPreviewOffset] (set by the most recent [updateNodeDrag])
  /// as the final landing position, so callers do not need to supply a
  /// global offset.
  void endNodeDrag() {
    final nodeId = _dragNodeId;
    final snappedOffset = _dragPreviewOffset;
    if (nodeId == null || snappedOffset == null) {
      _clearDragState();
      return;
    }

    final node = nodes[nodeId];
    if (node == null) {
      _clearDragState();
      return;
    }

    // Move the dragged node (and any co-selected nodes) to snapped positions.
    final movedDelta = snappedOffset - node.widgetOffset;

    final List<VSNodeData> modifiedNodes = [];

    if (selectedNodes.contains(node.id)) {
      for (final id in selectedNodes) {
        final n = nodes[id];
        if (n != null) {
          modifiedNodes.add(
            n..widgetOffset = snapToGrid(n.widgetOffset + movedDelta),
          );
        }
      }
    } else {
      modifiedNodes.add(node..widgetOffset = snappedOffset);
    }

    _clearDragState();
    updateOrCreateNodes(modifiedNodes);
  }

  /// Cancels an in-progress node drag without moving anything.
  void cancelNodeDrag() {
    _clearDragState();
  }

  void _clearDragState() {
    _dragNodeId = null;
    _dragPreviewOffset = null;
    _dragNodeSize = null;
    notifyListeners();
  }

  /// Gets the closest [VSNodeDataProvider] from the widget tree.
  static VSNodeDataProvider of(BuildContext context) {
    return context
        .findAncestorWidgetOfExactType<InheritedNodeDataProvider>()!
        .provider;
  }

  /// Instance of [VSNodeManager] representing the current nodes.
  ///
  /// Holds all the data and is used as an "API" to modify data.
  final VSNodeManager nodeManager;

  /// Instance of [VSHistoryManager].
  ///
  /// Holds and updates a history of the nodes.
  ///
  /// Has undo and redo functions.
  final VSHistoryManager? historyManager;

  /// A map of all nodeBuilders that can be used to build a context menu.
  ///
  /// Format:
  /// ```
  /// {
  ///   Subgroup: {
  ///     nodeName: NodeBuilder,
  ///   },
  ///   nodeName: NodeBuilder,
  /// }
  /// ```
  Map<String, dynamic> get nodeBuildersMap => nodeManager.nodeBuildersMap;

  /// Node data map in this format: `{NodeData.id: NodeData}`.
  Map<String, VSNodeData> get nodes => nodeManager.nodes;

  /// Loads nodes from string and replaces current nodes.
  ///
  /// Notifies listeners to this provider.
  void loadSerializedNodes(String serializedNodes) {
    nodeManager.loadSerializedNodes(serializedNodes);
    notifyListeners();
  }

  /// Updates existing nodes or creates them.
  ///
  /// Notifies listeners to this provider.
  void updateOrCreateNodes(
    List<VSNodeData> nodeDatas, {
    bool updateHistory = true,
  }) {
    nodeManager.updateOrCreateNodes(nodeDatas);
    if (updateHistory) historyManager?.updateHistory();
    notifyListeners();
  }

  /// Used to move one or multiple nodes.
  ///
  /// Offset will be applied to all nodes based on the offset from the moved
  /// node's original position. Final positions are snapped to the grid.
  void moveNode(VSNodeData nodeData, Offset offset) {
    final targetOffset = snapToGrid(applyViewPortTransform(offset));
    final movedOffset = targetOffset - nodeData.widgetOffset;

    final List<VSNodeData> modifiedNodes = [];

    if (selectedNodes.contains(nodeData.id)) {
      for (final nodeId in selectedNodes) {
        final currentNode = nodes[nodeId]!;
        modifiedNodes.add(
          currentNode
            ..widgetOffset = snapToGrid(currentNode.widgetOffset + movedOffset),
        );
      }
    } else {
      modifiedNodes.add(nodeData..widgetOffset = targetOffset);
    }

    updateOrCreateNodes(modifiedNodes);
  }

  /// Removes multiple nodes.
  ///
  /// Notifies listeners to this provider.
  void removeNodes(List<VSNodeData> nodeDatas) {
    nodeManager.removeNodes(nodeDatas);
    historyManager?.updateHistory();
    notifyListeners();
  }

  /// Clears all nodes.
  ///
  /// Notifies listeners to this provider.
  void clearNodes() {
    nodeManager.clearNodes();
    historyManager?.updateHistory();
    notifyListeners();
  }

  /// Creates a node based on the builder and the current
  /// [_contextMenuContext].
  ///
  /// Notifies listeners to this provider.
  void createNodeFromContext(VSNodeDataBuilder builder) {
    updateOrCreateNodes([
      builder(_contextMenuContext!.offset, _contextMenuContext!.reference),
    ]);
  }

  /// Set of currently selected node IDs.
  Set<String> get selectedNodes => _selectedNodes;
  Set<String> _selectedNodes = {};

  set selectedNodes(Set<String> data) {
    _selectedNodes = Set.from(data);
    notifyListeners();
  }

  /// Adds an [Iterable] of type [String] to the currently selected nodes.
  void addSelectedNodes(Iterable<String> data) {
    selectedNodes = selectedNodes..addAll(data);
  }

  /// Removes an [Iterable] of type [String] from the currently selected nodes.
  void removeSelectedNodes(Iterable<String> data) {
    selectedNodes = selectedNodes
        .where((element) => !data.contains(element))
        .toSet();
  }

  /// Returns a set of all nodes that fall into the area between the supplied
  /// start and end offsets.
  Set<VSNodeData> findNodesInsideSelectionArea(Offset start, Offset end) {
    final Set<VSNodeData> inside = {};
    for (final node in nodeManager.nodes.values) {
      final pos = node.widgetOffset;
      if (pos.dy > start.dy &&
          pos.dx > start.dx &&
          pos.dy < end.dy &&
          pos.dx < end.dx) {
        inside.add(node);
      }
    }
    return inside;
  }

  ContextMenuContext? _contextMenuContext;
  ContextMenuContext? get contextMenuContext => _contextMenuContext;

  /// Used to offset the UI by a given value.
  ///
  /// Useful when wrapping [VSNodeView] in an [InteractiveViewer] or similar,
  /// to ensure context menu and node interactions work as planned.
  Offset viewportOffset = Offset.zero;

  /// Scale factor for the viewport.
  ///
  /// Useful when wrapping [VSNodeView] in an [InteractiveViewer] or similar,
  /// to ensure context menu and node interactions work as planned.
  double get viewportScale => _viewportScale;
  double _viewportScale = 1;
  set viewportScale(double value) {
    _viewportScale = value;
    notifyListeners();
  }

  /// Helper function to apply [viewportOffset] and [viewportScale] to an
  /// offset.
  ///
  /// Fixed spelling from upstream `applyViewPortTransfrom`.
  Offset applyViewPortTransform(Offset initial) =>
      (initial - viewportOffset) * viewportScale;

  /// Opens the context menu at a given position.
  ///
  /// If the context menu was opened through a reference it will also be
  /// passed.
  void openContextMenu({required Offset position, VSOutputData? outputData}) {
    _contextMenuContext = ContextMenuContext(
      offset: applyViewPortTransform(position),
      reference: outputData,
    );
    notifyListeners();
  }

  /// Closes the context menu.
  void closeContextMenu() {
    _contextMenuContext = null;
    notifyListeners();
  }
}
