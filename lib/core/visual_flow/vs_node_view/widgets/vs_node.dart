// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Replaced plain Card with glass morphism styled container matching
// Socialmesh sci-fi aesthetic.
// Modified: Node width increased from 125 to 180 for mobile readability.
// Modified: Selected state uses accent glow border instead of solid color fill.
// Modified: Replaced Draggable with GestureDetector pan-based drag for live
// snap-preview feedback and grid-aligned node positioning on mobile.

import 'package:flutter/material.dart';

import '../data/vs_node_data.dart';
import '../data/vs_node_data_provider.dart';
import 'vs_node_input.dart';
import 'vs_node_output.dart';
import 'vs_node_title.dart';

/// Default width of a node card — increased from upstream 125 to 180 for
/// mobile readability.
const double _kDefaultNodeWidth = 180.0;

/// Minimum pan distance (in logical pixels) before a node drag is considered
/// intentional. Prevents accidental micro-drags when tapping nodes on mobile.
const double _kMinDragDistance = 8.0;

class VSNode extends StatefulWidget {
  /// The base node widget.
  ///
  /// Used inside [VSNodeView] to display nodes. Styled with a glass morphism
  /// card and glow border on selection matching the Socialmesh sci-fi design
  /// language.
  ///
  /// Uses [GestureDetector] with pan callbacks instead of [Draggable] so the
  /// canvas can render a live snap-preview ghost at the target grid position
  /// during the drag.
  const VSNode({
    required this.data,
    this.width = _kDefaultNodeWidth,
    this.nodeTitleBuilder,
    super.key,
  });

  /// The data the widget will use to build the UI.
  final VSNodeData data;

  /// Default width of the node.
  ///
  /// Will be used unless width is specified inside [VSNodeData].
  final double width;

  /// Can be used to take control over the building of the node's titles.
  ///
  /// See [VSNodeTitle] for reference.
  final Widget Function(BuildContext context, VSNodeData nodeData)?
  nodeTitleBuilder;

  @override
  State<VSNode> createState() => _VSNodeState();
}

class _VSNodeState extends State<VSNode> {
  /// Tracks whether the current pan gesture has exceeded the minimum drag
  /// distance threshold. Until it does, the gesture is treated as a potential
  /// tap, not a drag.
  bool _isDragActive = false;

  /// The global position where the pan gesture started.
  Offset? _panStartGlobal;

  /// Measured size of this node widget, captured on first drag start so the
  /// canvas can render a correctly-sized ghost preview.
  Size? _measuredSize;

  Size _measureSelf() {
    if (_measuredSize != null) return _measuredSize!;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      _measuredSize = renderBox.size;
    }
    return _measuredSize ?? Size(widget.data.nodeWidth ?? widget.width, 80);
  }

  @override
  Widget build(BuildContext context) {
    final nodeProvider = VSNodeDataProvider.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = nodeProvider.selectedNodes.contains(widget.data.id);
    final isDragging = nodeProvider.dragNodeId == widget.data.id;

    final nodeWidth = widget.data.nodeWidth ?? widget.width;

    // Build input/output interface widgets.
    final List<Widget> interfaceWidgets = [];

    for (final value in widget.data.inputData) {
      interfaceWidgets.add(VSNodeInput(data: value));
    }

    for (final value in widget.data.outputData) {
      interfaceWidgets.add(VSNodeOutput(data: value));
    }

    // Glass morphism card — semi-transparent surface with blur-like layering
    // and a subtle border. On selection, the border glows with the accent
    // color. While being dragged, the card is ghosted to indicate it is
    // in-flight (the preview ghost on the canvas shows the landing spot).
    final nodeCard = _GlassNodeCard(
      isSelected: isSelected,
      colorScheme: colorScheme,
      child: SizedBox(
        width: nodeWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.nodeTitleBuilder?.call(context, widget.data) ??
                VSNodeTitle(data: widget.data),
            ...interfaceWidgets,
          ],
        ),
      ),
    );

    // While this node is being dragged, render a ghosted version in place.
    if (isDragging) {
      return Opacity(opacity: 0.3, child: IgnorePointer(child: nodeCard));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: () {
        // Toggle selection on tap.
        if (isSelected) {
          nodeProvider.removeSelectedNodes({widget.data.id});
        } else {
          nodeProvider.addSelectedNodes({widget.data.id});
        }
      },

      onPanStart: (details) {
        _panStartGlobal = details.globalPosition;
        _isDragActive = false;
      },

      onPanUpdate: (details) {
        if (!_isDragActive) {
          // Check if we've exceeded the minimum drag distance.
          final delta = (details.globalPosition - _panStartGlobal!).distance;
          if (delta < _kMinDragDistance) return;

          // Drag is now active — notify the provider so the canvas can start
          // rendering the snap-preview ghost.
          _isDragActive = true;
          nodeProvider.startNodeDrag(widget.data, nodeSize: _measureSelf());
        }

        // Report the current pointer position so the provider can compute
        // the snapped grid target and the canvas can update the ghost.
        nodeProvider.updateNodeDrag(details.globalPosition);
      },

      onPanEnd: (details) {
        if (!_isDragActive) {
          // The user panned less than the threshold — treat as no-op.
          _panStartGlobal = null;
          return;
        }

        // Commit the drop at the last snapped preview position.
        // endNodeDrag uses dragPreviewOffset set by the most recent
        // updateNodeDrag call — no global offset needed.
        nodeProvider.endNodeDrag();

        _panStartGlobal = null;
        _isDragActive = false;
      },

      onPanCancel: () {
        if (_isDragActive) {
          nodeProvider.cancelNodeDrag();
        }
        _panStartGlobal = null;
        _isDragActive = false;
      },

      child: nodeCard,
    );
  }
}

/// Glass morphism styled card for flow nodes.
///
/// Uses a semi-transparent surface with a subtle border. When [isSelected] is
/// true, the border glows with the primary accent color to indicate selection
/// state.
class _GlassNodeCard extends StatelessWidget {
  const _GlassNodeCard({
    required this.isSelected,
    required this.colorScheme,
    required this.child,
  });

  final bool isSelected;
  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Surface color — semi-transparent for the glass effect.
    final surfaceColor = isDark
        ? colorScheme.surface.withValues(alpha: 0.85)
        : colorScheme.surface.withValues(alpha: 0.92);

    // Border color — accent glow on selection, subtle outline otherwise.
    final borderColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.8)
        : (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08));

    final borderWidth = isSelected ? 1.5 : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          // Ambient shadow for depth.
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          // Accent glow when selected.
          if (isSelected)
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(14.0), child: child),
      ),
    );
  }
}
