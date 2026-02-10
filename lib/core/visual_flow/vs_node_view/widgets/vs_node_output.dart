// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Enlarged touch targets for mobile usability (min 44dp hit area).
// Modified: Added minimum drag distance before starting connection to prevent
// accidental drags on mobile.
// Modified: Removed context menu on drag cancel — mobile users trigger this
// accidentally too often. Context menu is available via long-press on canvas.
// Modified: Drag preview line uses glow painter for visual consistency.

import 'package:flutter/material.dart';

import '../common.dart';
import '../data/vs_interface.dart';
import '../data/vs_node_data_provider.dart';
import '../special_nodes/vs_list_node.dart';
import '../special_nodes/vs_widget_node.dart';
import 'line_drawer/gradiant_line_drawer.dart';

/// Minimum touch target size for mobile usability (Material Design guideline).
const double _kMinTouchTarget = 44.0;

/// Minimum drag distance (in logical pixels) before a connection drag is
/// considered intentional. Prevents accidental short-distance drags on
/// mobile from opening the context menu or starting a wire.
const double _kMinDragDistance = 12.0;

class VSNodeOutput extends StatefulWidget {
  /// Base node output widget.
  ///
  /// Used in [VSNode].
  ///
  /// Uses [Draggable] to make a connection with [VSInputData].
  const VSNodeOutput({required this.data, super.key});

  final VSOutputData data;

  @override
  State<VSNodeOutput> createState() => _VSNodeOutputState();
}

class _VSNodeOutputState extends State<VSNodeOutput> {
  Offset? dragPos;
  Offset? _dragStartPos;
  bool _isDragActive = false;
  RenderBox? renderBox;
  final GlobalKey _anchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    updateRenderBox();
  }

  @override
  void didUpdateWidget(covariant VSNodeOutput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.data.widgetOffset == null ||
        widget.data.nodeData is VSListNode) {
      updateRenderBox();
    }
  }

  void updateRenderBox() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      renderBox = findAndUpdateWidgetPosition(
        widgetAnchor: _anchor,
        context: context,
        data: widget.data,
      );
    });
  }

  void updateLinePosition(Offset newPosition) {
    // On first update, record the start position for distance check.
    _dragStartPos ??= newPosition;

    // Only activate the visual drag line once the user has dragged beyond
    // the minimum distance threshold. This prevents ghost wires from
    // appearing during accidental short taps/drags on mobile.
    if (!_isDragActive) {
      final delta = (newPosition - _dragStartPos!).distance;
      if (delta < _kMinDragDistance) return;
      _isDragActive = true;
    }

    setState(() => dragPos = renderBox?.globalToLocal(newPosition));
  }

  void _resetDragState() {
    setState(() {
      dragPos = null;
      _dragStartPos = null;
      _isDragActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstItem = widget.data.nodeData is VSWidgetNode
        ? (widget.data.nodeData as VSWidgetNode).child
        : Text(widget.data.title);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: firstItem,
          ),
        ),
        // Wrap Draggable in a SizedBox to guarantee minimum touch area.
        SizedBox(
          width: _kMinTouchTarget,
          height: _kMinTouchTarget,
          child: Center(
            child: CustomPaint(
              foregroundPainter: GradientLinePainter(
                startPoint: getWidgetCenter(renderBox),
                endPoint: dragPos,
                startColor: widget.data.interfaceColor,
                endColor: widget.data.interfaceColor,
                glowEnabled: true,
              ),
              child: Draggable<VSOutputData>(
                data: widget.data,
                onDragUpdate: (details) =>
                    updateLinePosition(details.localPosition),
                onDragEnd: (details) => _resetDragState(),
                onDraggableCanceled: (velocity, offset) {
                  // Only open context menu if the user dragged a meaningful
                  // distance. On mobile, short accidental drags are very common
                  // and opening a menu each time is disruptive.
                  if (_isDragActive) {
                    VSNodeDataProvider.of(context).openContextMenu(
                      position: offset,
                      outputData: widget.data,
                    );
                  }
                  _resetDragState();
                },
                feedback: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.circle,
                    color: widget.data.interfaceColor,
                    size: kInterfaceIconSize,
                  ),
                ),
                child: Padding(
                  // Extra padding around the icon so the tap area extends
                  // beyond the visual icon bounds.
                  padding: const EdgeInsets.all(6.0),
                  child: wrapWithToolTip(
                    toolTip: widget.data.toolTip,
                    child: widget.data.getInterfaceIcon(
                      context: context,
                      anchor: _anchor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
