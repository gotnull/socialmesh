import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import 'selectors/icon_selector.dart';
import 'selectors/binding_selector.dart';
import 'selectors/action_selector.dart';
import 'selectors/color_selector.dart';
import 'simple_widget_canvas.dart';
import 'widget_validator.dart';

/// Simplified widget builder - easy to use, tap-to-place interface
class SimpleWidgetBuilder extends ConsumerStatefulWidget {
  final WidgetSchema? initialSchema;
  final void Function(WidgetSchema schema)? onSave;

  const SimpleWidgetBuilder({super.key, this.initialSchema, this.onSave});

  @override
  ConsumerState<SimpleWidgetBuilder> createState() =>
      _SimpleWidgetBuilderState();
}

class _SimpleWidgetBuilderState extends ConsumerState<SimpleWidgetBuilder> {
  late WidgetSchema _schema;
  String? _selectedElementId;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _schema = widget.initialSchema ?? _createEmptyWidget();
  }

  WidgetSchema _createEmptyWidget() {
    return WidgetSchema(
      name: 'New Widget',
      description: 'My custom widget',
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Size and layout selector
            _buildSizeBar(),
            // Canvas
            Expanded(child: _buildCanvas()),
          ],
        ),
      ),
      bottomNavigationBar: _selectedElementId != null
          ? _buildSelectedElementBar()
          : _buildAddElementBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.darkBackground,
      title: GestureDetector(
        onTap: _editName,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _schema.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: AppTheme.textTertiary),
          ],
        ),
      ),
      actions: [
        // Save
        TextButton.icon(
          onPressed: _save,
          icon: Icon(Icons.check, color: context.accentColor),
          label: Text('Save', style: TextStyle(color: context.accentColor)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSizeBar() {
    final isRow = _schema.root.type == ElementType.row;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          // Layout toggle
          _buildLayoutToggle(isRow),
          const Spacer(),
          // Size chips
          _buildSizeChip(CustomWidgetSize.small, 'S'),
          const SizedBox(width: 6),
          _buildSizeChip(CustomWidgetSize.medium, 'M'),
          const SizedBox(width: 6),
          _buildSizeChip(CustomWidgetSize.large, 'L'),
        ],
      ),
    );
  }

  Widget _buildLayoutToggle(bool isRow) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLayoutOption(
            icon: Icons.view_agenda,
            label: 'Stack',
            isSelected: !isRow,
            onTap: () => _setRootLayout(ElementType.column),
          ),
          _buildLayoutOption(
            icon: Icons.view_column,
            label: 'Side',
            isSelected: isRow,
            onTap: () => _setRootLayout(ElementType.row),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final accentColor = context.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? accentColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? accentColor : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setRootLayout(ElementType type) {
    setState(() {
      _schema = _schema.copyWith(root: _schema.root.copyWith(type: type));
    });
  }

  Widget _buildSizeChip(CustomWidgetSize size, String label) {
    final isSelected = _schema.size == size;
    final accentColor = context.accentColor;

    return GestureDetector(
      onTap: () => _selectPresetSize(size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : AppTheme.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? accentColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final width = _getWidgetWidth();
    final height = _getWidgetHeight();
    final accentColor = context.accentColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Create rect centered in available space
        final rect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: width,
          height: height,
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_selectedElementId != null) {
              setState(() => _selectedElementId = null);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TransformableBox(
                rect: rect,
                flip: Flip.none,
                draggable: false,
                resizable: true,
                allowFlippingWhileResizing: false,
                handleTapSize: 32,
                constraints: const BoxConstraints(
                  minWidth: 80,
                  minHeight: 80,
                  maxWidth: 400,
                  maxHeight: 400,
                ),
                onResizeStart: (handle, event) {
                  setState(() => _isResizing = true);
                },
                onResizeUpdate: (result, event) {
                  setState(() {
                    _schema = _schema.copyWith(
                      size: CustomWidgetSize.custom,
                      customWidth: result.rect.width,
                      customHeight: result.rect.height,
                    );
                  });
                },
                onResizeEnd: (handle, event) {
                  setState(() => _isResizing = false);
                },
                contentBuilder: (context, rect, flip) {
                  return Container(
                    width: rect.width,
                    height: rect.height,
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isResizing ? accentColor : AppTheme.darkBorder,
                        width: _isResizing ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SimpleWidgetCanvas(
                        schema: _schema,
                        selectedElementId: _selectedElementId,
                        onElementTap: (id) => setState(() {
                          _selectedElementId = _selectedElementId == id
                              ? null
                              : id;
                        }),
                        onDropZoneTap: _handleDropZoneTap,
                      ),
                    ),
                  );
                },
              ),
              // Size indicator when resizing
              if (_isResizing)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${width.toInt()} × ${height.toInt()}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _selectPresetSize(CustomWidgetSize size) {
    // Clear custom dimensions when selecting a preset
    setState(() {
      _schema = WidgetSchema(
        id: _schema.id,
        name: _schema.name,
        description: _schema.description,
        author: _schema.author,
        version: _schema.version,
        createdAt: _schema.createdAt,
        updatedAt: DateTime.now(),
        size: size,
        customWidth: null,
        customHeight: null,
        root: _schema.root,
        tags: _schema.tags,
        thumbnailUrl: _schema.thumbnailUrl,
        isPublic: _schema.isPublic,
        downloadCount: _schema.downloadCount,
        rating: _schema.rating,
      );
    });
  }

  Widget _buildAddElementBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickAddButton(
                  icon: Icons.text_fields,
                  label: 'Text',
                  onTap: () => _addElementToRoot(ElementType.text),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickAddButton(
                  icon: Icons.emoji_emotions,
                  label: 'Icon',
                  onTap: () => _addElementToRoot(ElementType.icon),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickAddButton(
                  icon: Icons.speed,
                  label: 'Gauge',
                  onTap: () => _addElementToRoot(ElementType.gauge),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickAddButton(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onTap: _showAllElements,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.accentColor, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedElementBar() {
    final element = _findElement(_schema.root, _selectedElementId!);
    if (element == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Element type indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getElementIcon(element.type),
                      size: 16,
                      color: context.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getElementName(element.type),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Edit button
              FilledButton.icon(
                onPressed: () => _editElement(element),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              IconButton(
                onPressed: () => _deleteElement(element.id),
                icon: Icon(Icons.delete_outline, color: AppTheme.errorRed),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.errorRed.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === Actions ===

  void _editName() async {
    final controller = TextEditingController(text: _schema.name);
    final result = await AppBottomSheet.show<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Widget Name',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter widget name',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.darkBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _schema = _schema.copyWith(name: result);
      });
    }
  }

  void _handleDropZoneTap(String? parentId, int index) async {
    final type = await QuickElementPicker.show(context);
    if (type == null) return;

    _addElementAt(parentId, index, type);
  }

  void _addElementToRoot(ElementType type) {
    _addElementAt(_schema.root.id, _schema.root.children.length, type);
  }

  void _addElementAt(String? parentId, int index, ElementType type) {
    final newElement = _createDefaultElement(type);

    setState(() {
      if (parentId == null || parentId == _schema.root.id) {
        final newChildren = List<ElementSchema>.from(_schema.root.children);
        newChildren.insert(index.clamp(0, newChildren.length), newElement);
        _schema = _schema.copyWith(
          root: _schema.root.copyWith(children: newChildren),
        );
      } else {
        _schema = _schema.copyWith(
          root: _insertElementInTree(_schema.root, parentId, index, newElement),
        );
      }
      _selectedElementId = newElement.id;
    });

    // Show edit sheet for the new element
    Future.delayed(const Duration(milliseconds: 100), () {
      final element = _findElement(_schema.root, newElement.id);
      if (element != null) {
        _editElement(element);
      }
    });
  }

  ElementSchema _createDefaultElement(ElementType type) {
    switch (type) {
      case ElementType.text:
        return ElementSchema(
          type: ElementType.text,
          text: 'Text',
          style: const StyleSchema(fontSize: 14, textColor: '#FFFFFF'),
        );
      case ElementType.icon:
        return ElementSchema(
          type: ElementType.icon,
          iconName: 'star',
          iconSize: 24,
          style: const StyleSchema(textColor: '#4F6AF6'),
        );
      case ElementType.gauge:
        return ElementSchema(
          type: ElementType.gauge,
          gaugeType: GaugeType.linear,
          gaugeMin: 0,
          gaugeMax: 100,
          style: const StyleSchema(height: 6),
        );
      case ElementType.chart:
        return ElementSchema(
          type: ElementType.chart,
          chartType: ChartType.sparkline,
          style: const StyleSchema(height: 40),
        );
      case ElementType.row:
        return ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(spacing: 8),
          children: [],
        );
      case ElementType.column:
        return ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(spacing: 8),
          children: [],
        );
      case ElementType.spacer:
        return ElementSchema(
          type: ElementType.spacer,
          style: const StyleSchema(height: 8),
        );
      case ElementType.shape:
        return ElementSchema(
          type: ElementType.shape,
          shapeType: ShapeType.rectangle,
          style: const StyleSchema(
            width: 40,
            height: 40,
            backgroundColor: '#4F6AF6',
            borderRadius: 8,
          ),
        );
      case ElementType.button:
        // Action button - needs action configuration
        return ElementSchema(
          type: ElementType.button,
          text: 'Tap me',
          iconName: 'touch_app',
          iconSize: 18,
          style: const StyleSchema(
            backgroundColor: '#4F6AF6',
            textColor: '#FFFFFF',
            borderRadius: 8,
            padding: 12,
          ),
        );
      default:
        return ElementSchema(type: type);
    }
  }

  ElementSchema _insertElementInTree(
    ElementSchema parent,
    String targetId,
    int index,
    ElementSchema newElement,
  ) {
    if (parent.id == targetId) {
      final newChildren = List<ElementSchema>.from(parent.children);
      newChildren.insert(index.clamp(0, newChildren.length), newElement);
      return parent.copyWith(children: newChildren);
    }

    return parent.copyWith(
      children: parent.children
          .map(
            (child) => _insertElementInTree(child, targetId, index, newElement),
          )
          .toList(),
    );
  }

  void _editElement(ElementSchema element) {
    AppBottomSheet.show(
      context: context,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _ElementEditor(
        element: element,
        onUpdate: (updated) {
          setState(() {
            _schema = _schema.copyWith(
              root: _updateElementInTree(_schema.root, updated),
            );
          });
        },
      ),
    );
  }

  ElementSchema _updateElementInTree(
    ElementSchema parent,
    ElementSchema updated,
  ) {
    if (parent.id == updated.id) {
      return updated;
    }
    return parent.copyWith(
      children: parent.children
          .map((child) => _updateElementInTree(child, updated))
          .toList(),
    );
  }

  void _deleteElement(String id) {
    setState(() {
      _schema = _schema.copyWith(
        root: _removeElementFromTree(_schema.root, id),
      );
      if (_selectedElementId == id) {
        _selectedElementId = null;
      }
    });
  }

  ElementSchema _removeElementFromTree(ElementSchema parent, String id) {
    return parent.copyWith(
      children: parent.children
          .where((child) => child.id != id)
          .map((child) => _removeElementFromTree(child, id))
          .toList(),
    );
  }

  void _showAllElements() async {
    final type = await QuickElementPicker.show(context);
    if (type != null) {
      _addElementToRoot(type);
    }
  }

  void _save() {
    // Validate widget before saving
    final result = WidgetValidator.validate(_schema);

    if (!result.isValid) {
      _showValidationIssues(result);
      return;
    }

    // Show warnings but allow saving
    if (result.hasWarnings) {
      _showValidationWarnings(result);
      return;
    }

    _doSave();
  }

  void _doSave() {
    widget.onSave?.call(_schema);
    Navigator.pop(context, _schema);
  }

  void _showValidationIssues(ValidationResult result) {
    final accentColor = context.accentColor;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 24, color: AppTheme.errorRed),
              const SizedBox(width: 8),
              const Text(
                'Widget needs fixes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Please fix these issues before saving:',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ...result.errors.map(
            (issue) => _buildIssueItem(issue, AppTheme.errorRed),
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...result.warnings.map(
              (issue) => _buildIssueItem(issue, Colors.orange),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('OK, I\'ll fix it'),
            ),
          ),
        ],
      ),
    );
  }

  void _showValidationWarnings(ValidationResult result) {
    final accentColor = context.accentColor;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, size: 24, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                'Some suggestions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your widget will work, but consider:',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ...result.warnings.map(
            (issue) => _buildIssueItem(issue, Colors.orange),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.darkBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Fix issues'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _doSave();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueItem(ValidationIssue issue, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            issue.severity == ValidationSeverity.error
                ? Icons.close
                : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.message,
                  style: const TextStyle(color: Colors.white),
                ),
                if (issue.fix != null)
                  Text(
                    issue.fix!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === Helpers ===

  ElementSchema? _findElement(ElementSchema parent, String id) {
    if (parent.id == id) return parent;
    for (final child in parent.children) {
      final found = _findElement(child, id);
      if (found != null) return found;
    }
    return null;
  }

  double _getWidgetWidth() {
    // Use custom width if set
    if (_schema.customWidth != null) {
      return _schema.customWidth!;
    }
    switch (_schema.size) {
      case CustomWidgetSize.small:
        return 160;
      case CustomWidgetSize.medium:
        return 320;
      case CustomWidgetSize.large:
        return 320;
      case CustomWidgetSize.custom:
        return 320; // Default for custom if no width set
    }
  }

  double _getWidgetHeight() {
    // Use custom height if set
    if (_schema.customHeight != null) {
      return _schema.customHeight!;
    }
    switch (_schema.size) {
      case CustomWidgetSize.small:
        return 160;
      case CustomWidgetSize.medium:
        return 160;
      case CustomWidgetSize.large:
        return 320;
      case CustomWidgetSize.custom:
        return 320; // Default for custom if no height set
    }
  }

  IconData _getElementIcon(ElementType type) {
    switch (type) {
      case ElementType.text:
        return Icons.text_fields;
      case ElementType.icon:
        return Icons.emoji_emotions;
      case ElementType.gauge:
        return Icons.speed;
      case ElementType.chart:
        return Icons.show_chart;
      case ElementType.row:
        return Icons.view_column;
      case ElementType.column:
        return Icons.view_agenda;
      case ElementType.container:
        return Icons.crop_square;
      case ElementType.spacer:
        return Icons.space_bar;
      case ElementType.shape:
        return Icons.square;
      case ElementType.image:
        return Icons.image;
      case ElementType.map:
        return Icons.map;
      case ElementType.button:
        return Icons.touch_app;
      default:
        return Icons.widgets;
    }
  }

  String _getElementName(ElementType type) {
    switch (type) {
      case ElementType.text:
        return 'Text';
      case ElementType.icon:
        return 'Icon';
      case ElementType.gauge:
        return 'Gauge';
      case ElementType.chart:
        return 'Chart';
      case ElementType.row:
        return 'Row';
      case ElementType.column:
        return 'Column';
      case ElementType.container:
        return 'Container';
      case ElementType.spacer:
        return 'Spacer';
      case ElementType.shape:
        return 'Shape';
      case ElementType.image:
        return 'Image';
      case ElementType.map:
        return 'Map';
      case ElementType.button:
        return 'Action Button';
      default:
        return type.name;
    }
  }
}

/// Inline element editor shown in bottom sheet
class _ElementEditor extends StatefulWidget {
  final ElementSchema element;
  final void Function(ElementSchema) onUpdate;

  const _ElementEditor({required this.element, required this.onUpdate});

  @override
  State<_ElementEditor> createState() => _ElementEditorState();
}

class _ElementEditorState extends State<_ElementEditor> {
  late ElementSchema _element;

  @override
  void initState() {
    super.initState();
    _element = widget.element;
  }

  void _update(ElementSchema updated) {
    setState(() => _element = updated);
    widget.onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(_getIcon(), size: 20, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'Edit ${_getName()}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Type-specific properties
        ..._buildProperties(accentColor),

        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _buildProperties(Color accentColor) {
    switch (_element.type) {
      case ElementType.text:
        return _buildTextProperties(accentColor);
      case ElementType.icon:
        return _buildIconProperties(accentColor);
      case ElementType.gauge:
        return _buildGaugeProperties(accentColor);
      case ElementType.spacer:
        return _buildSpacerProperties(accentColor);
      case ElementType.shape:
        return _buildShapeProperties(accentColor);
      case ElementType.button:
        return _buildButtonProperties(accentColor);
      default:
        return [
          Text(
            'No editable properties',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ];
    }
  }

  List<Widget> _buildTextProperties(Color accentColor) {
    return [
      // Static text or binding toggle
      _buildSectionLabel('Content'),
      const SizedBox(height: 8),
      _buildBindingSelector(
        currentPath: _element.binding?.path,
        onSelect: (path) {
          if (path == null || path.isEmpty) {
            _update(_element.copyWith(binding: null));
          } else {
            _update(_element.copyWith(binding: BindingSchema(path: path)));
          }
        },
      ),
      if (_element.binding == null) ...[
        const SizedBox(height: 12),
        _buildTextField(
          label: 'Text',
          value: _element.text ?? '',
          onChanged: (v) => _update(_element.copyWith(text: v)),
        ),
      ],
      const SizedBox(height: 16),
      _buildSectionLabel('Style'),
      const SizedBox(height: 8),
      _buildSlider(
        label: 'Size',
        value: _element.style.fontSize ?? 14,
        min: 8,
        max: 48,
        unit: 'sp',
        onChanged: (v) => _update(
          _element.copyWith(style: _element.style.copyWith(fontSize: v)),
        ),
      ),
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Text Color',
        currentColor: _element.style.textColorValue,
        defaultColor: Colors.white,
        onSelect: (color) => _update(
          _element.copyWith(
            style: _element.style.copyWith(textColor: colorToHex(color)),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildIconProperties(Color accentColor) {
    return [
      _buildSectionLabel('Icon'),
      const SizedBox(height: 8),
      _buildIconSelector(
        currentIcon: _element.iconName ?? 'star',
        onSelect: (name) => _update(_element.copyWith(iconName: name)),
      ),
      const SizedBox(height: 16),
      _buildSectionLabel('Style'),
      const SizedBox(height: 8),
      _buildSlider(
        label: 'Size',
        value: _element.iconSize ?? 24,
        min: 12,
        max: 64,
        unit: 'px',
        onChanged: (v) => _update(_element.copyWith(iconSize: v)),
      ),
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Icon Color',
        currentColor: _element.style.textColorValue,
        defaultColor: accentColor,
        onSelect: (color) => _update(
          _element.copyWith(
            style: _element.style.copyWith(textColor: colorToHex(color)),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildGaugeProperties(Color accentColor) {
    return [
      _buildSectionLabel('Data'),
      const SizedBox(height: 8),
      _buildBindingSelector(
        currentPath: _element.binding?.path,
        onSelect: (path) {
          if (path == null || path.isEmpty) {
            _update(_element.copyWith(binding: null));
          } else {
            _update(_element.copyWith(binding: BindingSchema(path: path)));
          }
        },
      ),
      const SizedBox(height: 16),
      _buildSectionLabel('Range'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildCompactNumberField(
              label: 'Min',
              value: _element.gaugeMin ?? 0,
              onChanged: (v) => _update(_element.copyWith(gaugeMin: v)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactNumberField(
              label: 'Max',
              value: _element.gaugeMax ?? 100,
              onChanged: (v) => _update(_element.copyWith(gaugeMax: v)),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSpacerProperties(Color accentColor) {
    return [
      _buildSectionLabel('Size'),
      const SizedBox(height: 8),
      _buildSlider(
        label: 'Height',
        value: _element.style.height ?? 8,
        min: 4,
        max: 48,
        unit: 'px',
        onChanged: (v) => _update(
          _element.copyWith(style: _element.style.copyWith(height: v)),
        ),
      ),
    ];
  }

  List<Widget> _buildShapeProperties(Color accentColor) {
    return [
      _buildSectionLabel('Shape'),
      const SizedBox(height: 8),
      _buildShapeTypeSelector(),
      const SizedBox(height: 16),
      _buildSectionLabel('Size'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildCompactNumberField(
              label: 'Width',
              value: _element.style.width ?? 40,
              onChanged: (v) => _update(
                _element.copyWith(style: _element.style.copyWith(width: v)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactNumberField(
              label: 'Height',
              value: _element.style.height ?? 40,
              onChanged: (v) => _update(
                _element.copyWith(style: _element.style.copyWith(height: v)),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildSectionLabel('Color'),
      const SizedBox(height: 8),
      InlineColorSelector(
        label: 'Fill Color',
        currentColor: _element.style.backgroundColorValue,
        defaultColor: accentColor,
        onSelect: (color) => _update(
          _element.copyWith(
            style: _element.style.copyWith(backgroundColor: colorToHex(color)),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildButtonProperties(Color accentColor) {
    final hasAction =
        _element.action != null && _element.action!.type != ActionType.none;

    return [
      // Action is the most important - show first with prominence
      _buildSectionLabel('What should this button do?'),
      const SizedBox(height: 8),
      _buildActionSelector(accentColor, hasAction),

      const SizedBox(height: 20),
      _buildSectionLabel('Appearance'),
      const SizedBox(height: 8),

      // Label
      _buildTextField(
        label: 'Button label',
        value: _element.text ?? 'Tap me',
        onChanged: (v) => _update(_element.copyWith(text: v)),
      ),

      const SizedBox(height: 12),

      // Icon selector
      _buildIconSelector(
        currentIcon: _element.iconName ?? 'touch_app',
        onSelect: (name) => _update(_element.copyWith(iconName: name)),
      ),

      const SizedBox(height: 12),

      // Button color
      InlineColorSelector(
        label: 'Button Color',
        currentColor: _element.style.backgroundColorValue,
        defaultColor: accentColor,
        onSelect: (color) => _update(
          _element.copyWith(
            style: _element.style.copyWith(backgroundColor: colorToHex(color)),
          ),
        ),
      ),
    ];
  }

  Widget _buildActionSelector(Color accentColor, bool hasAction) {
    return InkWell(
      onTap: () async {
        final result = await ActionSelector.show(
          context: context,
          currentAction: _element.action,
        );
        if (result != null) {
          // Get the suggested label for this action
          final suggestedLabel = _getSuggestedLabelForAction(result.type);
          final suggestedIcon = _getSuggestedIconForAction(result.type);
          final currentLabel = _element.text ?? 'Tap me';

          // Check if user has a custom label (not a default one)
          final isDefaultLabel = _isDefaultButtonLabel(currentLabel);

          if (isDefaultLabel) {
            // Auto-update label and icon since it's still a default
            _update(
              _element.copyWith(
                action: result,
                text: suggestedLabel,
                iconName: suggestedIcon,
              ),
            );
          } else {
            // User has customized the label - check preference or ask
            final shouldReplace = await _shouldReplaceLabelForAction(
              currentLabel,
              suggestedLabel,
            );

            if (shouldReplace == true) {
              _update(
                _element.copyWith(
                  action: result,
                  text: suggestedLabel,
                  iconName: suggestedIcon,
                ),
              );
            } else {
              // Keep user's custom label, just update action
              _update(_element.copyWith(action: result));
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasAction
              ? accentColor.withValues(alpha: 0.15)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasAction ? accentColor : AppTheme.darkBorder,
            width: hasAction ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasAction
                    ? accentColor.withValues(alpha: 0.2)
                    : AppTheme.darkBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasAction ? _getActionIcon(_element.action!.type) : Icons.add,
                color: hasAction ? accentColor : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAction
                        ? _getActionName(_element.action!.type)
                        : 'Choose an action',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: hasAction
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (!hasAction)
                    Text(
                      'Required - tap to configure',
                      style: TextStyle(fontSize: 12, color: AppTheme.errorRed),
                    )
                  else
                    Text(
                      'Tap to change',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: hasAction ? accentColor : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(ActionType type) {
    switch (type) {
      case ActionType.sendMessage:
        return Icons.send;
      case ActionType.shareLocation:
        return Icons.location_on;
      case ActionType.traceroute:
        return Icons.timeline;
      case ActionType.requestPositions:
        return Icons.refresh;
      case ActionType.sos:
        return Icons.warning_amber;
      case ActionType.navigate:
        return Icons.open_in_new;
      case ActionType.openUrl:
        return Icons.link;
      case ActionType.copyToClipboard:
        return Icons.copy;
      default:
        return Icons.touch_app;
    }
  }

  String _getActionName(ActionType type) {
    switch (type) {
      case ActionType.sendMessage:
        return 'Send Message';
      case ActionType.shareLocation:
        return 'Share Location';
      case ActionType.traceroute:
        return 'Traceroute';
      case ActionType.requestPositions:
        return 'Request Positions';
      case ActionType.sos:
        return 'SOS Alert';
      case ActionType.navigate:
        return 'Navigate';
      case ActionType.openUrl:
        return 'Open URL';
      case ActionType.copyToClipboard:
        return 'Copy to Clipboard';
      default:
        return 'No action';
    }
  }

  /// Get a suggested button label for an action type
  String _getSuggestedLabelForAction(ActionType type) {
    switch (type) {
      case ActionType.sendMessage:
        return 'Send';
      case ActionType.shareLocation:
        return 'Share Location';
      case ActionType.traceroute:
        return 'Traceroute';
      case ActionType.requestPositions:
        return 'Refresh';
      case ActionType.sos:
        return 'SOS';
      case ActionType.navigate:
        return 'Navigate';
      case ActionType.openUrl:
        return 'Open';
      case ActionType.copyToClipboard:
        return 'Copy';
      default:
        return 'Tap me';
    }
  }

  /// Get a suggested icon for an action type
  String _getSuggestedIconForAction(ActionType type) {
    switch (type) {
      case ActionType.sendMessage:
        return 'send';
      case ActionType.shareLocation:
        return 'location_on';
      case ActionType.traceroute:
        return 'timeline';
      case ActionType.requestPositions:
        return 'refresh';
      case ActionType.sos:
        return 'warning_amber';
      case ActionType.navigate:
        return 'open_in_new';
      case ActionType.openUrl:
        return 'link';
      case ActionType.copyToClipboard:
        return 'copy';
      default:
        return 'touch_app';
    }
  }

  /// Check if label is one of the default button labels
  bool _isDefaultButtonLabel(String label) {
    const defaultLabels = {
      'Tap me',
      'Send',
      'Share Location',
      'Traceroute',
      'Refresh',
      'SOS',
      'Navigate',
      'Open',
      'Copy',
    };
    return defaultLabels.contains(label);
  }

  /// Preference key for "don't ask again" checkbox
  static bool _dontAskToReplaceLabel = false;

  /// Ask user if they want to replace their custom label
  Future<bool?> _shouldReplaceLabelForAction(
    String currentLabel,
    String suggestedLabel,
  ) async {
    // If user checked "don't ask again" and said no, return false
    if (_dontAskToReplaceLabel) {
      return false;
    }

    bool dontAskAgain = false;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Update Button Label?',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your current label:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentLabel,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Suggested label:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.accentColor),
                ),
                child: Text(
                  suggestedLabel,
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setDialogState(() {
                  dontAskAgain = !dontAskAgain;
                }),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: dontAskAgain,
                        onChanged: (v) => setDialogState(() {
                          dontAskAgain = v ?? false;
                        }),
                        activeColor: context.accentColor,
                        side: BorderSide(color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Don't ask again",
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (dontAskAgain) {
                  _dontAskToReplaceLabel = true;
                }
                Navigator.pop(context, false);
              },
              child: Text(
                'Keep Mine',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textTertiary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required void Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required void Function(double) onChanged,
    String? unit,
  }) {
    final accentColor = context.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${value.round()}${unit ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: accentColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentColor,
            inactiveTrackColor: AppTheme.darkBorder,
            thumbColor: accentColor,
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => onChanged(v.roundToDouble()),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactNumberField({
    required String label,
    required double value,
    required void Function(double) onChanged,
  }) {
    return TextFormField(
      initialValue: value.round().toString(),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildBindingSelector({
    required String? currentPath,
    required void Function(String?) onSelect,
  }) {
    final hasBinding = currentPath != null && currentPath.isNotEmpty;
    final binding = hasBinding
        ? BindingRegistry.bindings
              .where((b) => b.path == currentPath)
              .firstOrNull
        : null;

    return InkWell(
      onTap: () async {
        final result = await BindingSelector.show(
          context: context,
          selectedPath: currentPath,
        );
        if (result != null) {
          onSelect(result.isEmpty ? null : result);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              hasBinding ? Icons.link : Icons.add_link,
              size: 20,
              color: hasBinding ? context.accentColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasBinding
                    ? (binding?.label ?? currentPath)
                    : 'Bind to data...',
                style: TextStyle(
                  color: hasBinding ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector({
    required String currentIcon,
    required void Function(String) onSelect,
  }) {
    return InkWell(
      onTap: () async {
        final result = await IconSelector.show(
          context: context,
          selectedIcon: currentIcon,
        );
        if (result != null) {
          onSelect(result);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _iconFromName(currentIcon),
              size: 24,
              color: context.accentColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                currentIcon,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShapeTypeSelector() {
    final shapes = [
      (ShapeType.rectangle, 'Rectangle', Icons.rectangle),
      (ShapeType.circle, 'Circle', Icons.circle),
      (ShapeType.roundedRect, 'Rounded', Icons.rounded_corner),
    ];

    return Row(
      children: shapes.map((s) {
        final isSelected = _element.shapeType == s.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: s != shapes.last ? 8 : 0),
            child: InkWell(
              onTap: () => _update(_element.copyWith(shapeType: s.$1)),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.accentColor.withValues(alpha: 0.2)
                      : AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? context.accentColor
                        : AppTheme.darkBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      s.$3,
                      size: 20,
                      color: isSelected
                          ? context.accentColor
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.$2,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIcon() {
    switch (_element.type) {
      case ElementType.text:
        return Icons.text_fields;
      case ElementType.icon:
        return Icons.emoji_emotions;
      case ElementType.gauge:
        return Icons.speed;
      case ElementType.chart:
        return Icons.show_chart;
      case ElementType.spacer:
        return Icons.space_bar;
      case ElementType.shape:
        return Icons.square;
      case ElementType.button:
        return Icons.touch_app;
      default:
        return Icons.widgets;
    }
  }

  String _getName() {
    switch (_element.type) {
      case ElementType.text:
        return 'Text';
      case ElementType.icon:
        return 'Icon';
      case ElementType.gauge:
        return 'Gauge';
      case ElementType.chart:
        return 'Chart';
      case ElementType.spacer:
        return 'Spacer';
      case ElementType.shape:
        return 'Shape';
      case ElementType.button:
        return 'Action Button';
      default:
        return _element.type.name;
    }
  }

  IconData _iconFromName(String name) {
    const map = {
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
    return map[name] ?? Icons.help_outline;
  }
}
