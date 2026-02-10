// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Completely rewritten for mobile — replaced desktop Alt-key based
// selection with two-finger drag gesture. On mobile, users perform a
// two-finger pan to draw a selection rectangle. A single-finger pan is
// reserved for canvas panning (handled by InteractiveViewer), so there is
// no conflict.
//
// Selection behaviour:
// - Two-finger drag draws a translucent selection rectangle.
// - Nodes whose origin falls inside the rectangle are selected on release.
// - If nodes were already selected, newly enclosed nodes are toggled:
//   already-selected nodes are deselected, unselected nodes are added.
// - Tapping the canvas (handled elsewhere) clears selection.

import 'package:flutter/material.dart';

import '../data/vs_node_data_provider.dart';

class VSSelectionArea extends StatefulWidget {
  /// Mobile-friendly selection area overlay.
  ///
  /// Wraps the node view and intercepts two-finger (scale) gestures to draw
  /// a selection rectangle. Single-finger gestures pass through to the child
  /// (typically an [InteractiveViewer] for pan/zoom).
  const VSSelectionArea({required this.child, super.key});

  final Widget child;

  @override
  State<VSSelectionArea> createState() => _VSSelectionAreaState();
}

class _VSSelectionAreaState extends State<VSSelectionArea> {
  /// Whether a two-finger selection drag is currently active.
  bool _isSelecting = false;

  /// The two anchor points of the selection rectangle in global coordinates,
  /// transformed into the node canvas coordinate space.
  Offset? _startPos;
  Offset? _endPos;

  /// Normalised top-left of the selection rectangle.
  Offset? _topLeft;

  /// Normalised bottom-right of the selection rectangle.
  Offset? _bottomRight;

  late VSNodeDataProvider _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = VSNodeDataProvider.of(context);
  }

  /// Normalise [_startPos] and [_endPos] so that [_topLeft] is always the
  /// minimum corner and [_bottomRight] the maximum corner.
  void _normalise() {
    if (_startPos == null || _endPos == null) return;

    final double left;
    final double right;
    if (_startPos!.dx < _endPos!.dx) {
      left = _startPos!.dx;
      right = _endPos!.dx;
    } else {
      left = _endPos!.dx;
      right = _startPos!.dx;
    }

    final double top;
    final double bottom;
    if (_startPos!.dy < _endPos!.dy) {
      top = _startPos!.dy;
      bottom = _endPos!.dy;
    } else {
      top = _endPos!.dy;
      bottom = _startPos!.dy;
    }

    _topLeft = Offset(left, top);
    _bottomRight = Offset(right, bottom);
  }

  void _reset() {
    setState(() {
      _isSelecting = false;
      _startPos = null;
      _endPos = null;
      _topLeft = null;
      _bottomRight = null;
    });
  }

  /// Compute the midpoint of the two fingers from a [ScaleUpdateDetails].
  ///
  /// The focal point is already the midpoint of all pointers in the gesture,
  /// so we use it directly.
  Offset _toCanvasOffset(Offset focalPoint) {
    return _provider.applyViewPortTransform(focalPoint);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> layers = [];

    // Selection rectangle overlay — painted below the node layer but above
    // the canvas background.
    if (_isSelecting && _topLeft != null && _bottomRight != null) {
      final theme = Theme.of(context);
      final accentColor = theme.colorScheme.primary;

      layers.add(
        Positioned(
          left: _topLeft!.dx,
          top: _topLeft!.dy,
          child: IgnorePointer(
            child: Container(
              width: _bottomRight!.dx - _topLeft!.dx,
              height: _bottomRight!.dy - _topLeft!.dy,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.5),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }

    // The actual node view is always rendered on top.
    layers.add(widget.child);

    // We use a RawGestureDetector-free approach: a GestureDetector with
    // scale callbacks. The scale gesture fires for two-or-more pointer
    // drags, distinguishing it from the single-pointer pan used for canvas
    // movement. We only activate selection when the scale is very close to
    // 1.0 (i.e. the fingers are moving together, not pinching). This lets
    // pinch-to-zoom pass through naturally.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // We use onScaleStart/Update/End which fire for multi-touch gestures.
      // Single-touch gestures will not set _isSelecting and are ignored here,
      // allowing the InteractiveViewer underneath to handle them.
      onScaleStart: (details) {
        // Only activate for two-finger gestures.
        if (details.pointerCount >= 2) {
          setState(() {
            _isSelecting = true;
            _startPos = _toCanvasOffset(details.focalPoint);
            _endPos = _startPos;
          });
        }
      },
      onScaleUpdate: (details) {
        if (!_isSelecting) return;

        // If the user is clearly pinching (scale deviates significantly from
        // 1.0), abort the selection and let the zoom gesture take over.
        if ((details.scale - 1.0).abs() > 0.15) {
          _reset();
          return;
        }

        setState(() {
          _endPos = _toCanvasOffset(details.focalPoint);
          _normalise();
        });
      },
      onScaleEnd: (details) {
        if (!_isSelecting || _topLeft == null || _bottomRight == null) {
          _reset();
          return;
        }

        // Find all nodes inside the selection rectangle.
        final enclosed = _provider
            .findNodesInsideSelectionArea(_topLeft!, _bottomRight!)
            .map((e) => e.id)
            .toList();

        if (enclosed.isNotEmpty) {
          // Toggle behaviour: deselect already-selected nodes, add new ones.
          final Set<String> alreadySelected = {};

          enclosed.removeWhere((node) {
            if (_provider.selectedNodes.contains(node)) {
              alreadySelected.add(node);
              return true;
            }
            return false;
          });

          _provider.removeSelectedNodes(alreadySelected);
          _provider.addSelectedNodes(enclosed);
        }

        _reset();
      },
      child: Stack(children: layers),
    );
  }
}
