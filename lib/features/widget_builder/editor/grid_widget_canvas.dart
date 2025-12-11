import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../models/grid_widget_schema.dart';

/// Resize handle positions
enum _ResizeHandle { right, bottom }

/// Grid-based visual canvas for widget building
/// Displays a grid where users can tap cells to add elements
/// and drag elements to move/resize them
class GridWidgetCanvas extends StatefulWidget {
  final GridWidgetSchema schema;
  final String? selectedElementId;
  final void Function(String elementId)? onElementTap;
  final void Function(int row, int column)? onEmptyCellTap;
  final void Function(GridElement updated)? onElementUpdated;
  final void Function(GridElement a, GridElement b)? onElementsSwapped;
  final VoidCallback? onTapOutside;

  const GridWidgetCanvas({
    super.key,
    required this.schema,
    this.selectedElementId,
    this.onElementTap,
    this.onEmptyCellTap,
    this.onElementUpdated,
    this.onElementsSwapped,
    this.onTapOutside,
  });

  @override
  State<GridWidgetCanvas> createState() => _GridWidgetCanvasState();
}

class _GridWidgetCanvasState extends State<GridWidgetCanvas> {
  // Drag state
  String? _draggingElementId;
  int? _previewRow;
  int? _previewCol;

  // Resize state
  String? _resizingElementId;
  int? _resizePreviewRowSpan;
  int? _resizePreviewColSpan;
  double _resizeDragAccumulator = 0;

  // Grid dimensions (cached for drag calculations)
  double _cellWidth = 0;
  double _cellHeight = 0;
  final double _spacing = 8;
  final double _padding = 12;

  @override
  void didUpdateWidget(GridWidgetCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only clear drag state if the element positions actually changed
    // (indicating a successful drop), not just on selection changes
    if (_draggingElementId != null) {
      final oldElement = oldWidget.schema.elements
          .cast<GridElement?>()
          .firstWhere((e) => e?.id == _draggingElementId, orElse: () => null);
      final newElement = widget.schema.elements.cast<GridElement?>().firstWhere(
        (e) => e?.id == _draggingElementId,
        orElse: () => null,
      );
      // Only clear if the dragged element's position actually changed
      if (oldElement != null &&
          newElement != null &&
          (oldElement.row != newElement.row ||
              oldElement.column != newElement.column)) {
        _clearDragState();
      }
    }
  }

  void _clearDragState() {
    if (_draggingElementId != null ||
        _previewRow != null ||
        _previewCol != null) {
      setState(() {
        _draggingElementId = null;
        _previewRow = null;
        _previewCol = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildGrid(context, constraints);
      },
    );
  }

  Widget _buildGrid(BuildContext context, BoxConstraints constraints) {
    final accentColor = context.accentColor;
    final rows = widget.schema.gridRows;
    final cols = widget.schema.gridColumns;

    // Calculate and cache cell dimensions
    final availableWidth = constraints.maxWidth - _padding * 2;
    final availableHeight = constraints.maxHeight - _padding * 2;
    _cellWidth = (availableWidth - (cols - 1) * _spacing) / cols;
    _cellHeight = (availableHeight - (rows - 1) * _spacing) / rows;

    return Padding(
      padding: EdgeInsets.all(_padding),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Grid background - empty cells
          ..._buildEmptyCells(accentColor, rows, cols),
          // Drag preview (drop target highlight)
          if (_draggingElementId != null && _previewRow != null)
            _buildDragPreview(accentColor),
          // Elements
          ..._buildElements(context, accentColor),
          // Resize preview
          if (_resizingElementId != null) _buildResizePreview(accentColor),
        ],
      ),
    );
  }

  Widget _buildDragPreview(Color accentColor) {
    final element = widget.schema.elements.cast<GridElement?>().firstWhere(
      (e) => e?.id == _draggingElementId,
      orElse: () => null,
    );

    // Element may have been removed during drag
    if (element == null) return const SizedBox.shrink();

    final left = _previewCol! * (_cellWidth + _spacing);
    final top = _previewRow! * (_cellHeight + _spacing);
    final width =
        element.columnSpan * _cellWidth + (element.columnSpan - 1) * _spacing;
    final height =
        element.rowSpan * _cellHeight + (element.rowSpan - 1) * _spacing;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accentColor,
            width: 2,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
    );
  }

  Widget _buildResizePreview(Color accentColor) {
    final element = widget.schema.elements.cast<GridElement?>().firstWhere(
      (e) => e?.id == _resizingElementId,
      orElse: () => null,
    );

    // Element may have been removed during resize
    if (element == null) return const SizedBox.shrink();

    final left = element.column * (_cellWidth + _spacing);
    final top = element.row * (_cellHeight + _spacing);
    final colSpan = _resizePreviewColSpan ?? element.columnSpan;
    final rowSpan = _resizePreviewRowSpan ?? element.rowSpan;
    final width = colSpan * _cellWidth + (colSpan - 1) * _spacing;
    final height = rowSpan * _cellHeight + (rowSpan - 1) * _spacing;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentColor,
              width: 2,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmptyCells(Color accentColor, int rows, int cols) {
    final cells = <Widget>[];

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        // Skip cells that are occupied by elements
        if (widget.schema.isCellOccupied(row, col)) continue;

        final left = col * (_cellWidth + _spacing);
        final top = row * (_cellHeight + _spacing);

        cells.add(
          Positioned(
            key: ValueKey('empty_${row}_$col'),
            left: left,
            top: top,
            width: _cellWidth,
            height: _cellHeight,
            child: _buildEmptyCell(accentColor, row, col),
          ),
        );
      }
    }

    return cells;
  }

  Widget _buildEmptyCell(Color accentColor, int row, int col) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final element = widget.schema.elements.firstWhere(
          (e) => e.id == details.data,
        );
        final canPlace = _canPlaceElement(element, row, col);
        AppLogging.widgetBuilder(
          'EmptyCell($row,$col) onWillAccept: element=${details.data} '
          '(${element.rowSpan}x${element.columnSpan}) -> canPlace=$canPlace',
        );
        // Update preview position without triggering immediate rebuild
        // Use post-frame callback to avoid interrupting drag gesture
        if (canPlace && (_previewRow != row || _previewCol != col)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _draggingElementId != null) {
              setState(() {
                _previewRow = row;
                _previewCol = col;
              });
            }
          });
        }
        return canPlace;
      },
      onLeave: (data) {
        // Only clear if we're actually leaving THIS cell's preview
        // and there's still a drag in progress
        if (_draggingElementId != null &&
            _previewRow == row &&
            _previewCol == col) {
          // Don't clear immediately - let the next cell set the preview
          // This prevents flickering between cells
        }
      },
      onAcceptWithDetails: (details) {
        AppLogging.widgetBuilder(
          'EmptyCell($row,$col) onAccept: dropped ${details.data}',
        );
        _finalizeDrag(row, col);
      },
      builder: (context, candidateData, rejectedData) {
        // Use candidateData to determine if this is a valid drop target
        final isDropTarget = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () => widget.onEmptyCellTap?.call(row, col),
          child: Container(
            decoration: BoxDecoration(
              color: isDropTarget
                  ? accentColor.withValues(alpha: 0.3)
                  : AppTheme.darkBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDropTarget
                    ? accentColor
                    : accentColor.withValues(alpha: 0.2),
                width: isDropTarget ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: accentColor.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _canPlaceElement(GridElement element, int row, int col) {
    final rows = widget.schema.gridRows;
    final cols = widget.schema.gridColumns;

    // Check bounds
    if (row + element.rowSpan > rows) return false;
    if (col + element.columnSpan > cols) return false;

    // Check for overlap with other elements (excluding the dragged element)
    for (var r = row; r < row + element.rowSpan; r++) {
      for (var c = col; c < col + element.columnSpan; c++) {
        final occupier = widget.schema.elementAt(r, c);
        if (occupier != null && occupier.id != element.id) {
          return false;
        }
      }
    }

    return true;
  }

  List<Widget> _buildElements(BuildContext context, Color accentColor) {
    return widget.schema.elements.map((element) {
      final left = element.column * (_cellWidth + _spacing);
      final top = element.row * (_cellHeight + _spacing);
      final width =
          element.columnSpan * _cellWidth + (element.columnSpan - 1) * _spacing;
      final height =
          element.rowSpan * _cellHeight + (element.rowSpan - 1) * _spacing;

      final isSelected = widget.selectedElementId == element.id;
      final isDragging = _draggingElementId == element.id;

      return Positioned(
        key: ValueKey('element_${element.id}'),
        left: left,
        top: top,
        width: width,
        height: height,
        child: Opacity(
          opacity: isDragging ? 0.5 : 1.0,
          child: _buildDraggableElement(
            context,
            element,
            isSelected,
            isDragging,
            accentColor,
            width,
            height,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDraggableElement(
    BuildContext context,
    GridElement element,
    bool isSelected,
    bool isDragging,
    Color accentColor,
    double width,
    double height,
  ) {
    // Wrap in DragTarget to receive drops from other elements
    // When this element is being dragged, wrap in IgnorePointer so drops go to empty cells
    final dragTarget = DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        // Don't accept self
        if (details.data == element.id) {
          AppLogging.widgetBuilder(
            'Element(${element.id}) onWillAccept: REJECTED - same element',
          );
          return false;
        }

        final dragged = widget.schema.elements.firstWhere(
          (e) => e.id == details.data,
        );
        final canSwap = _canPlaceOrSwap(dragged, element.row, element.column);
        AppLogging.widgetBuilder(
          'Element(${element.id} at ${element.row},${element.column}) onWillAccept: '
          'dragged=${details.data} (${dragged.rowSpan}x${dragged.columnSpan}), '
          'target=(${element.rowSpan}x${element.columnSpan}) -> canSwap=$canSwap',
        );
        return canSwap;
      },
      onAcceptWithDetails: (details) {
        AppLogging.widgetBuilder(
          'Element(${element.id}) onAccept: SWAP with ${details.data}',
        );
        // Perform swap
        final dragged = widget.schema.elements.firstWhere(
          (e) => e.id == details.data,
        );
        AppLogging.widgetBuilder(
          'SWAP: ${dragged.id} (${dragged.row},${dragged.column}) <-> '
          '${element.id} (${element.row},${element.column})',
        );
        final updatedDragged = dragged.copyWith(
          row: element.row,
          column: element.column,
        );
        final updatedTarget = element.copyWith(
          row: dragged.row,
          column: dragged.column,
        );
        // Use atomic swap callback if available, otherwise fall back to sequential updates
        if (widget.onElementsSwapped != null) {
          widget.onElementsSwapped!(updatedDragged, updatedTarget);
        } else {
          widget.onElementUpdated?.call(updatedDragged);
          widget.onElementUpdated?.call(updatedTarget);
        }
        HapticFeedback.mediumImpact();
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return LongPressDraggable<String>(
          data: element.id,
          delay: const Duration(milliseconds: 150),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: SizedBox(
                width: width,
                height: height,
                child: _buildElementWidget(
                  context,
                  element,
                  true, // Always show selected style when dragging
                  accentColor,
                  width,
                  height,
                ),
              ),
            ),
          ),
          childWhenDragging: Container(
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          onDragStarted: () {
            AppLogging.widgetBuilder(
              'DRAG START: ${element.id} from (${element.row},${element.column}) '
              'size=${element.rowSpan}x${element.columnSpan}',
            );
            HapticFeedback.mediumImpact();
            // Set drag state directly without causing rebuild during gesture
            _draggingElementId = element.id;
            _previewRow = element.row;
            _previewCol = element.column;
            // Defer the actual setState to after the gesture is fully started
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          },
          onDragEnd: (details) {
            AppLogging.widgetBuilder(
              'DRAG END: ${element.id} wasAccepted=${details.wasAccepted}',
            );
            // Always clear drag state on end, regardless of acceptance
            _clearDragState();
          },
          onDraggableCanceled: (velocity, offset) {
            AppLogging.widgetBuilder('DRAG CANCELLED: ${element.id}');
            _clearDragState();
          },
          child: GestureDetector(
            onTap: () => widget.onElementTap?.call(element.id),
            child: _buildElementWidget(
              context,
              element,
              isSelected || isDropTarget,
              accentColor,
              width,
              height,
              isDropTarget: isDropTarget,
            ),
          ),
        );
      },
    );

    // When dragging, ignore pointer on this element's DragTarget so drops go to empty cells
    if (isDragging) {
      return IgnorePointer(child: dragTarget);
    }
    return dragTarget;
  }

  /// Check if element can be placed at position (allows single element swap)
  bool _canPlaceOrSwap(GridElement element, int row, int col) {
    final rows = widget.schema.gridRows;
    final cols = widget.schema.gridColumns;

    // Check bounds
    if (row + element.rowSpan > rows) {
      AppLogging.widgetBuilder(
        '_canPlaceOrSwap: REJECTED - row overflow ($row + ${element.rowSpan} > $rows)',
      );
      return false;
    }
    if (col + element.columnSpan > cols) {
      AppLogging.widgetBuilder(
        '_canPlaceOrSwap: REJECTED - col overflow ($col + ${element.columnSpan} > $cols)',
      );
      return false;
    }

    // Find any elements that would be overlapped
    GridElement? swapTarget;
    for (var r = row; r < row + element.rowSpan; r++) {
      for (var c = col; c < col + element.columnSpan; c++) {
        final occupier = widget.schema.elementAt(r, c);
        if (occupier != null && occupier.id != element.id) {
          AppLogging.widgetBuilder(
            '_canPlaceOrSwap: found occupier ${occupier.id} '
            '(${occupier.rowSpan}x${occupier.columnSpan}) at ($r,$c)',
          );
          // Can only swap with ONE other element that's 1x1
          if (swapTarget == null &&
              occupier.rowSpan == 1 &&
              occupier.columnSpan == 1 &&
              element.rowSpan == 1 &&
              element.columnSpan == 1) {
            swapTarget = occupier;
            AppLogging.widgetBuilder(
              '_canPlaceOrSwap: valid swap target found: ${occupier.id}',
            );
          } else if (swapTarget?.id != occupier.id) {
            // Multiple different elements - can't swap
            AppLogging.widgetBuilder(
              '_canPlaceOrSwap: REJECTED - multiple elements or not 1x1 '
              '(element=${element.rowSpan}x${element.columnSpan}, '
              'occupier=${occupier.rowSpan}x${occupier.columnSpan})',
            );
            return false;
          }
        }
      }
    }

    AppLogging.widgetBuilder(
      '_canPlaceOrSwap: ALLOWED (swapTarget=${swapTarget?.id})',
    );
    return true;
  }

  void _finalizeDrag(int row, int col) {
    if (_draggingElementId == null) return;

    final element = widget.schema.elements.firstWhere(
      (e) => e.id == _draggingElementId,
    );

    AppLogging.widgetBuilder(
      'finalizeDrag: element=${element.id} (${element.rowSpan}x${element.columnSpan}) '
      'from (${element.row},${element.column}) to ($row,$col)',
    );

    // Check if we're dropping on another element (swap)
    final occupier = widget.schema.elementAt(row, col);
    AppLogging.widgetBuilder(
      'finalizeDrag: occupier=${occupier?.id} (${occupier?.rowSpan}x${occupier?.columnSpan})',
    );

    if (occupier != null && occupier.id != element.id) {
      AppLogging.widgetBuilder('finalizeDrag: SWAPPING elements');
      // Swap positions
      final updatedDragged = element.copyWith(row: row, column: col);
      final updatedOccupier = occupier.copyWith(
        row: element.row,
        column: element.column,
      );
      widget.onElementUpdated?.call(updatedDragged);
      widget.onElementUpdated?.call(updatedOccupier);
      HapticFeedback.mediumImpact();
    } else if (element.row != row || element.column != col) {
      AppLogging.widgetBuilder('finalizeDrag: MOVING to empty cell');
      // Just move to empty cell
      final updated = element.copyWith(row: row, column: col);
      widget.onElementUpdated?.call(updated);
      HapticFeedback.lightImpact();
    } else {
      AppLogging.widgetBuilder('finalizeDrag: NO CHANGE');
    }
  }

  Widget _buildElementWidget(
    BuildContext context,
    GridElement element,
    bool isSelected,
    Color accentColor,
    double width,
    double height, {
    bool isDropTarget = false,
  }) {
    // Use consistent border width to avoid size jump on selection
    final borderColor = isDropTarget
        ? Colors.green
        : (isSelected ? accentColor : AppTheme.darkBorder);

    final content = Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 2, // Always 2px to avoid size change
        ),
        boxShadow: isSelected || isDropTarget
            ? [
                BoxShadow(
                  color: (isDropTarget ? Colors.green : accentColor).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _buildElementPreview(context, element, accentColor),
      ),
    );

    // Add edge resize zones for selected elements
    if (isSelected) {
      final canResizeRight =
          element.column + element.columnSpan < widget.schema.gridColumns ||
          element.columnSpan > 1;
      final canResizeBottom =
          element.row + element.rowSpan < widget.schema.gridRows ||
          element.rowSpan > 1;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          // Right edge resize zone (invisible, covers right 12px of element)
          if (canResizeRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    AppLogging.widgetBuilder(
                      'RESIZE START (right): ${element.id} current=${element.columnSpan}x${element.rowSpan}',
                    );
                    HapticFeedback.selectionClick();
                    setState(() {
                      _resizingElementId = element.id;
                      _resizePreviewColSpan = element.columnSpan;
                      _resizePreviewRowSpan = element.rowSpan;
                      _resizeDragAccumulator = 0;
                    });
                  },
                  onPanUpdate: (details) {
                    _updateResizePreviewCumulative(
                      element,
                      _ResizeHandle.right,
                      details.delta.dx,
                    );
                  },
                  onPanEnd: (details) {
                    AppLogging.widgetBuilder(
                      'RESIZE END (right): ${element.id} -> ${_resizePreviewColSpan}x$_resizePreviewRowSpan',
                    );
                    _finalizeResize(element);
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          // Bottom edge resize zone (invisible, covers bottom 12px of element)
          if (canResizeBottom)
            Positioned(
              left: 0,
              right: canResizeRight ? 12 : 0, // Don't overlap corner
              bottom: 0,
              height: 12,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    AppLogging.widgetBuilder(
                      'RESIZE START (bottom): ${element.id} current=${element.columnSpan}x${element.rowSpan}',
                    );
                    HapticFeedback.selectionClick();
                    setState(() {
                      _resizingElementId = element.id;
                      _resizePreviewColSpan = element.columnSpan;
                      _resizePreviewRowSpan = element.rowSpan;
                      _resizeDragAccumulator = 0;
                    });
                  },
                  onPanUpdate: (details) {
                    _updateResizePreviewCumulative(
                      element,
                      _ResizeHandle.bottom,
                      details.delta.dy,
                    );
                  },
                  onPanEnd: (details) {
                    AppLogging.widgetBuilder(
                      'RESIZE END (bottom): ${element.id} -> ${_resizePreviewColSpan}x$_resizePreviewRowSpan',
                    );
                    _finalizeResize(element);
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
        ],
      );
    }

    return content;
  }

  void _updateResizePreviewCumulative(
    GridElement element,
    _ResizeHandle handle,
    double delta,
  ) {
    _resizeDragAccumulator += delta;
    final cellSize = handle == _ResizeHandle.right
        ? _cellWidth + _spacing
        : _cellHeight + _spacing;

    // Calculate cells to add/remove based on accumulated drag
    final cellsToAdd = (_resizeDragAccumulator / cellSize).round();

    if (handle == _ResizeHandle.right) {
      final newColSpan = (element.columnSpan + cellsToAdd).clamp(
        1,
        widget.schema.gridColumns - element.column,
      );

      if (newColSpan != _resizePreviewColSpan &&
          _canResizeElement(element, element.rowSpan, newColSpan)) {
        HapticFeedback.selectionClick();
        setState(() {
          _resizePreviewColSpan = newColSpan;
        });
      }
    } else {
      final newRowSpan = (element.rowSpan + cellsToAdd).clamp(
        1,
        widget.schema.gridRows - element.row,
      );

      if (newRowSpan != _resizePreviewRowSpan &&
          _canResizeElement(element, newRowSpan, element.columnSpan)) {
        HapticFeedback.selectionClick();
        setState(() {
          _resizePreviewRowSpan = newRowSpan;
        });
      }
    }
  }

  bool _canResizeElement(GridElement element, int newRowSpan, int newColSpan) {
    // Check bounds
    if (element.row + newRowSpan > widget.schema.gridRows) return false;
    if (element.column + newColSpan > widget.schema.gridColumns) return false;

    // Check for overlap with other elements
    for (var r = element.row; r < element.row + newRowSpan; r++) {
      for (var c = element.column; c < element.column + newColSpan; c++) {
        final occupier = widget.schema.elementAt(r, c);
        if (occupier != null && occupier.id != element.id) {
          return false;
        }
      }
    }

    return true;
  }

  void _finalizeResize(GridElement element) {
    final newRowSpan = _resizePreviewRowSpan ?? element.rowSpan;
    final newColSpan = _resizePreviewColSpan ?? element.columnSpan;

    if (newRowSpan != element.rowSpan || newColSpan != element.columnSpan) {
      final updated = element.copyWith(
        rowSpan: newRowSpan,
        columnSpan: newColSpan,
      );
      widget.onElementUpdated?.call(updated);
      HapticFeedback.lightImpact();
    }

    setState(() {
      _resizingElementId = null;
      _resizePreviewRowSpan = null;
      _resizePreviewColSpan = null;
    });
  }

  Widget _buildElementPreview(
    BuildContext context,
    GridElement element,
    Color accentColor,
  ) {
    switch (element.type) {
      case GridElementType.text:
        return _buildTextPreview(element, accentColor);
      case GridElementType.icon:
        return _buildIconPreview(element, accentColor);
      case GridElementType.iconText:
        return _buildIconTextPreview(element, accentColor);
      case GridElementType.gauge:
        return _buildGaugePreview(element, accentColor);
      case GridElementType.chart:
        return _buildChartPreview(element, accentColor);
      case GridElementType.button:
        return _buildButtonPreview(element, accentColor);
    }
  }

  Widget _buildTextPreview(GridElement element, Color accentColor) {
    final text = element.text ?? element.binding?.path ?? 'Text';
    final displayText = element.binding != null
        ? '{${element.binding!.path.split('.').last}}'
        : text;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: element.textColor ?? Colors.white,
            fontSize: element.fontSize ?? 14,
            fontWeight: element.fontWeight,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
      ),
    );
  }

  Widget _buildIconPreview(GridElement element, Color accentColor) {
    return Center(
      child: Icon(
        _getIconData(element.iconName ?? 'help_outline'),
        size: element.iconSize ?? 24,
        color: element.iconColor ?? accentColor,
      ),
    );
  }

  Widget _buildIconTextPreview(GridElement element, Color accentColor) {
    final text = element.text ?? element.binding?.path ?? 'Text';
    final displayText = element.binding != null
        ? '{${element.binding!.path.split('.').last}}'
        : text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _getIconData(element.iconName ?? 'info'),
            size: element.iconSize ?? 18,
            color: element.iconColor ?? accentColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                color: element.textColor ?? Colors.white,
                fontSize: element.fontSize ?? 14,
                fontWeight: element.fontWeight,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugePreview(GridElement element, Color accentColor) {
    final style = element.gaugeStyle ?? GaugeStyle.linear;
    final color = element.gaugeColor ?? accentColor;

    switch (style) {
      case GaugeStyle.circular:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _CircularGaugePainter(color, 0.65)),
          ),
        );
      case GaugeStyle.arc:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: CustomPaint(
            painter: _ArcGaugePainter(color, 0.65),
            size: const Size(double.infinity, 60),
          ),
        );
      case GaugeStyle.battery:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: _BatteryGaugePreview(color: color, value: 0.65),
        );
      case GaugeStyle.signal:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: _SignalGaugePreview(color: color, value: 0.65),
        );
      case GaugeStyle.linear:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: _LinearGaugePreview(color: color, value: 0.65),
        );
    }
  }

  Widget _buildChartPreview(GridElement element, Color accentColor) {
    final style = element.chartStyle ?? ChartStyle.sparkline;
    final color = element.chartColor ?? accentColor;

    switch (style) {
      case ChartStyle.bar:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: CustomPaint(
            painter: _BarChartPainter(color),
            size: const Size(double.infinity, double.infinity),
          ),
        );
      case ChartStyle.area:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: CustomPaint(
            painter: _AreaChartPainter(color),
            size: const Size(double.infinity, double.infinity),
          ),
        );
      case ChartStyle.sparkline:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: CustomPaint(
            painter: _SparklinePainter(color),
            size: const Size(double.infinity, double.infinity),
          ),
        );
    }
  }

  Widget _buildButtonPreview(GridElement element, Color accentColor) {
    final text = element.text ?? 'Button';
    final iconName = element.iconName;
    final iconColor = element.iconColor ?? accentColor;
    final textColor = element.textColor ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor, width: 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconName != null) ...[
                Icon(
                  _getIconData(iconName),
                  size: element.iconSize ?? 18,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: element.fontSize ?? 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    const iconMap = {
      'star': Icons.star,
      'favorite': Icons.favorite,
      'battery_full': Icons.battery_full,
      'signal_cellular_alt': Icons.signal_cellular_alt,
      'wifi': Icons.wifi,
      'gps_fixed': Icons.gps_fixed,
      'thermostat': Icons.thermostat,
      'water_drop': Icons.water_drop,
      'check_circle': Icons.check_circle,
      'warning': Icons.warning,
      'error': Icons.error,
      'info': Icons.info,
      'send': Icons.send,
      'message': Icons.message,
      'flash_on': Icons.flash_on,
      'speed': Icons.speed,
      'hub': Icons.hub,
      'router': Icons.router,
      'touch_app': Icons.touch_app,
      'location_on': Icons.location_on,
      'timeline': Icons.timeline,
      'refresh': Icons.refresh,
      'warning_amber': Icons.warning_amber,
    };
    return iconMap[name] ?? Icons.help_outline;
  }
}

// === Preview Widgets ===

class _LinearGaugePreview extends StatelessWidget {
  final Color color;
  final double value;

  const _LinearGaugePreview({required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BatteryGaugePreview extends StatelessWidget {
  final Color color;
  final double value;

  const _BatteryGaugePreview({required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(2),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Container(
            width: 3,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalGaugePreview extends StatelessWidget {
  final Color color;
  final double value;

  const _SignalGaugePreview({required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    final bars = 4;
    final activeBars = (value * bars).ceil();

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars, (i) {
          final isActive = i < activeBars;
          final height = 8.0 + (i * 6);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 6,
              height: height,
              decoration: BoxDecoration(
                color: isActive ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// === Custom Painters ===

class _CircularGaugePainter extends CustomPainter {
  final Color color;
  final double value;

  _CircularGaugePainter(this.color, this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final strokeWidth = 6.0;

    // Background arc
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2; // Start from top
    final sweepAngle = 2 * 3.14159 * value;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcGaugePainter extends CustomPainter {
  final Color color;
  final double value;

  _ArcGaugePainter(this.color, this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 8;
    final strokeWidth = 8.0;

    // Background arc
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159 * value,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparklinePainter extends CustomPainter {
  final Color color;

  _SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [0.3, 0.5, 0.4, 0.7, 0.6, 0.8, 0.5, 0.6];

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y =
          size.height - (points[i] * size.height * 0.8) - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarChartPainter extends CustomPainter {
  final Color color;

  _BarChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final values = [0.4, 0.7, 0.5, 0.9, 0.6];
    final barWidth = size.width / (values.length * 2 - 1);

    for (var i = 0; i < values.length; i++) {
      final left = i * barWidth * 2;
      final height = values[i] * size.height * 0.8;
      final top = size.height - height;

      final paint = Paint()..color = color;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AreaChartPainter extends CustomPainter {
  final Color color;

  _AreaChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.3, 0.5, 0.4, 0.7, 0.6, 0.8, 0.5, 0.6];

    // Build line path
    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y =
          size.height - (points[i] * size.height * 0.8) - size.height * 0.1;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    // Build area path
    final areaPath = Path.from(linePath);
    areaPath.lineTo(size.width, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    // Draw area
    final areaPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Quick element picker for grid cells
class GridElementPicker extends StatelessWidget {
  final void Function(GridElementType type) onSelect;

  const GridElementPicker({super.key, required this.onSelect});

  static Future<GridElementType?> show(BuildContext context) {
    return AppBottomSheet.show<GridElementType>(
      context: context,
      child: GridElementPicker(
        onSelect: (type) => Navigator.pop(context, type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Element',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildOption(
              context,
              GridElementType.text,
              Icons.text_fields,
              'Text',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildOption(
              context,
              GridElementType.icon,
              Icons.emoji_emotions,
              'Icon',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildOption(
              context,
              GridElementType.iconText,
              Icons.view_headline,
              'Icon+Text',
              accentColor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildOption(
              context,
              GridElementType.gauge,
              Icons.speed,
              'Gauge',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildOption(
              context,
              GridElementType.chart,
              Icons.show_chart,
              'Chart',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildOption(
              context,
              GridElementType.button,
              Icons.touch_app,
              'Button',
              accentColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    GridElementType type,
    IconData icon,
    String label,
    Color accentColor,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
