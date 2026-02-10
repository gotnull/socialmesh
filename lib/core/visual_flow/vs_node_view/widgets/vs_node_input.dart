// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Enlarged touch targets for mobile usability (min 44dp hit area).
// Modified: Added minimum drag distance threshold before accepting connections
// to reduce accidental disconnects on mobile.

import 'package:flutter/material.dart';

import '../common.dart';
import '../data/vs_interface.dart';
import '../data/vs_node_data_provider.dart';
import '../special_nodes/vs_list_node.dart';

/// Minimum touch target size for mobile usability (Material Design guideline).
const double _kMinTouchTarget = 44.0;

class VSNodeInput extends StatefulWidget {
  /// Base node input widget.
  ///
  /// Used in [VSNode].
  ///
  /// Uses [DragTarget] to accept [VSOutputData].
  const VSNodeInput({required this.data, super.key});

  final VSInputData data;

  @override
  State<VSNodeInput> createState() => _VSNodeInputState();
}

class _VSNodeInputState extends State<VSNodeInput> {
  RenderBox? renderBox;
  final GlobalKey _anchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    updateRenderBox();
  }

  @override
  void didUpdateWidget(covariant VSNodeInput oldWidget) {
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

  void updateConnectedNode(VSOutputData? data) {
    widget.data.connectedInterface = data;
    VSNodeDataProvider.of(context).updateOrCreateNodes([widget.data.nodeData!]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Wrap DragTarget in a SizedBox to guarantee minimum touch area.
        SizedBox(
          width: _kMinTouchTarget,
          height: _kMinTouchTarget,
          child: Center(
            child: DragTarget<VSOutputData>(
              builder:
                  (
                    BuildContext context,
                    List<dynamic> accepted,
                    List<dynamic> rejected,
                  ) {
                    return GestureDetector(
                      // Tap to disconnect — uses the enlarged parent hit area.
                      onTap: () {
                        updateConnectedNode(null);
                      },
                      behavior: HitTestBehavior.opaque,
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
                    );
                  },
              onWillAcceptWithDetails: (details) {
                return widget.data.acceptInput(details.data);
              },
              onAcceptWithDetails: (details) {
                updateConnectedNode(details.data);
              },
            ),
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              widget.data.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
