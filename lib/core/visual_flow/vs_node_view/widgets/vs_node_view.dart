// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Added sci-fi themed canvas background rendering.
// Modified: Long-press gesture opens context menu with haptic-friendly delay.
// Modified: Tap on canvas clears selection and closes context menu.
// Modified: Added snap-preview ghost rendered at the grid-snapped drop target
// position during node drags, giving users clear visual feedback of where the
// node will land.

import 'package:flutter/material.dart';

import '../data/vs_interface.dart';
import '../data/vs_node_data.dart';
import '../data/vs_node_data_provider.dart';
import 'inherited_node_data_provider.dart';
import 'line_drawer/multi_gradiant_line_drawer.dart';
import 'vs_context_menu.dart';
import 'vs_node.dart';
import 'vs_node_title.dart';
import 'vs_selection_area.dart';

class VSNodeView extends StatelessWidget {
  /// The base node view widget.
  ///
  /// Displays and interacts with nodes to build node trees. Renders connection
  /// lines with a sci-fi glow effect and provides a glass-styled context menu
  /// for creating new nodes.
  const VSNodeView({
    required this.nodeDataProvider,
    this.contextMenuBuilder,
    this.nodeBuilder,
    this.nodeTitleBuilder,
    this.enableSelectionArea = true,
    this.selectionAreaBuilder,
    this.gestureDetectorBuilder,
    this.showGridBackground = true,
    super.key,
  });

  /// The provider that will be used to control the UI.
  final VSNodeDataProvider nodeDataProvider;

  /// Can be used to take control over the building of the nodes.
  ///
  /// See [VSNode] for reference.
  final Widget Function(BuildContext context, VSNodeData data)? nodeBuilder;

  /// Can be used to take control over the building of the context menu.
  ///
  /// See [VSContextMenu] for reference.
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> nodeBuildersMap,
  )?
  contextMenuBuilder;

  /// Can be used to take control over the building of the nodes' titles.
  ///
  /// See [VSNodeTitle] for reference.
  final Widget Function(BuildContext context, VSNodeData nodeData)?
  nodeTitleBuilder;

  /// If [VSSelectionArea] or [selectionAreaBuilder] will be inserted to the
  /// widget tree.
  final bool enableSelectionArea;

  /// Can be used to take control over the building of the selection area.
  ///
  /// See [VSSelectionArea] for reference.
  final Widget Function(BuildContext context, Widget view)?
  selectionAreaBuilder;

  /// Can be used to override the GestureDetector.
  ///
  /// See [VSNodeDataProvider.closeContextMenu],
  /// [VSNodeDataProvider.openContextMenu], and
  /// [VSNodeDataProvider.selectedNodes].
  final GestureDetector Function(
    BuildContext context,
    VSNodeDataProvider nodeDataProvider,
  )?
  gestureDetectorBuilder;

  /// Whether to render the subtle dot-grid background on the canvas.
  ///
  /// The grid provides spatial reference when panning/zooming and reinforces
  /// the sci-fi aesthetic. Set to false if you are providing your own
  /// background.
  final bool showGridBackground;

  @override
  Widget build(BuildContext context) {
    return InheritedNodeDataProvider(
      provider: nodeDataProvider,
      child: ListenableBuilder(
        listenable: nodeDataProvider,
        builder: (context, _) {
          // Build positioned node widgets.
          final nodes = nodeDataProvider.nodes.values.map((value) {
            return Positioned(
              left: value.widgetOffset.dx,
              top: value.widgetOffset.dy,
              child:
                  nodeBuilder?.call(context, value) ??
                  VSNode(
                    key: ValueKey(value.id),
                    data: value,
                    nodeTitleBuilder: nodeTitleBuilder,
                  ),
            );
          });

          // Collect all input interfaces for the connection line painter.
          final allInputs = nodeDataProvider.nodes.values
              .expand<VSInputData>((element) => element.inputData)
              .toList();

          final view = Stack(
            children: [
              // Canvas background — the gesture detector fills the entire
              // canvas area. Single tap clears selection and closes any
              // open context menu. Long-press opens the context menu for
              // creating new nodes (mobile-friendly alternative to
              // right-click). Secondary tap (right-click on desktop) also
              // opens the context menu.
              gestureDetectorBuilder?.call(context, nodeDataProvider) ??
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      nodeDataProvider.closeContextMenu();
                      nodeDataProvider.selectedNodes = {};
                    },
                    onSecondaryTapUp: (details) {
                      nodeDataProvider.openContextMenu(
                        position: details.globalPosition,
                      );
                    },
                    onLongPressStart: (details) {
                      nodeDataProvider.openContextMenu(
                        position: details.globalPosition,
                      );
                    },
                    // Paint the dot-grid background inside the gesture
                    // detector so it fills the entire canvas.
                    child: showGridBackground
                        ? CustomPaint(
                            painter: _DotGridPainter(
                              dotColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            child: const SizedBox.expand(),
                          )
                        : const SizedBox.expand(),
                  ),

              // Connection lines — painted between all connected interfaces
              // with glow effect.
              CustomPaint(
                foregroundPainter: MultiGradientLinePainter(
                  data: allInputs,
                  glowEnabled: true,
                  glowWidth: 8.0,
                  glowOpacity: 0.3,
                  lineWidth: 2.0,
                ),
              ),

              // Snap-preview ghost — rendered at the grid-snapped target
              // position while a node is being dragged. Shows the user
              // exactly where the node will land on the grid.
              if (nodeDataProvider.isDraggingNode &&
                  nodeDataProvider.dragPreviewOffset != null)
                Positioned(
                  left: nodeDataProvider.dragPreviewOffset!.dx,
                  top: nodeDataProvider.dragPreviewOffset!.dy,
                  child: _SnapPreviewGhost(
                    size: nodeDataProvider.dragNodeSize ?? const Size(180, 80),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

              // Node widgets.
              ...nodes,

              // Context menu — positioned at the point where the user
              // long-pressed or right-clicked.
              if (nodeDataProvider.contextMenuContext != null)
                Positioned(
                  left: nodeDataProvider.contextMenuContext!.offset.dx,
                  top: nodeDataProvider.contextMenuContext!.offset.dy,
                  child:
                      contextMenuBuilder?.call(
                        context,
                        nodeDataProvider.nodeBuildersMap,
                      ) ??
                      VSContextMenu(
                        nodeBuilders: nodeDataProvider.nodeBuildersMap,
                      ),
                ),
            ],
          );

          if (enableSelectionArea) {
            return selectionAreaBuilder?.call(context, view) ??
                VSSelectionArea(child: view);
          } else {
            return view;
          }
        },
      ),
    );
  }
}

/// Ghost rectangle rendered at the snap-target position during a node drag.
///
/// Shows a dashed border with a subtle fill so the user can see exactly
/// which grid cell the node will land on when they release.
class _SnapPreviewGhost extends StatelessWidget {
  const _SnapPreviewGhost({required this.size, required this.color});

  final Size size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: size,
        painter: _DashedRectPainter(color: color),
      ),
    );
  }
}

/// Paints a dashed-border rectangle with a faint fill for the snap preview.
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Faint fill.
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    // Dashed border.
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const double dashLength = 6.0;
    const double gapLength = 4.0;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, borderPaint);
        distance += dashLength + gapLength;
      }
    }

    // Corner accent dots — small filled circles at the four corners of the
    // rectangle so the target feels anchored to the grid.
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    const double dotRadius = 3.0;
    const double inset = 12.0; // matches border radius
    canvas.drawCircle(Offset(inset, inset), dotRadius, dotPaint);
    canvas.drawCircle(Offset(size.width - inset, inset), dotRadius, dotPaint);
    canvas.drawCircle(Offset(inset, size.height - inset), dotRadius, dotPaint);
    canvas.drawCircle(
      Offset(size.width - inset, size.height - inset),
      dotRadius,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

/// Paints a subtle dot grid on the node canvas for spatial reference.
///
/// The grid spacing and dot size are designed to be visible enough to provide
/// orientation when panning and zooming, but subtle enough not to compete
/// with the node content and connection lines.
class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.dotColor});

  /// The color of each grid dot.
  final Color dotColor;

  /// The distance between dots in both axes.
  static const double spacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const double dotRadius = 1.0;

    // Only paint dots that fall within the visible canvas area.
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return dotColor != oldDelegate.dotColor;
  }
}
