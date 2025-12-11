import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grid_widget_schema.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import 'selectors/icon_selector.dart';
import 'selectors/binding_selector.dart';

import 'selectors/color_selector.dart';
import 'grid_widget_canvas.dart';

/// Grid-based widget builder - simplified tap-to-place interface
class GridWidgetBuilder extends ConsumerStatefulWidget {
  final GridWidgetSchema? initialSchema;
  final void Function(GridWidgetSchema schema)? onSave;

  const GridWidgetBuilder({super.key, this.initialSchema, this.onSave});

  @override
  ConsumerState<GridWidgetBuilder> createState() => _GridWidgetBuilderState();
}

class _GridWidgetBuilderState extends ConsumerState<GridWidgetBuilder> {
  late GridWidgetSchema _schema;
  String? _selectedElementId;

  @override
  void initState() {
    super.initState();
    _schema = widget.initialSchema ?? _createEmptyWidget();
  }

  GridWidgetSchema _createEmptyWidget() {
    return GridWidgetSchema(name: 'New Widget', size: GridWidgetSize.medium);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildSizeBar(),
            Expanded(child: _buildCanvas()),
          ],
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSizeChip(GridWidgetSize.small, 'S', '2×2'),
          const SizedBox(width: 8),
          _buildSizeChip(GridWidgetSize.medium, 'M', '3×2'),
          const SizedBox(width: 8),
          _buildSizeChip(GridWidgetSize.large, 'L', '3×3'),
        ],
      ),
    );
  }

  Widget _buildSizeChip(GridWidgetSize size, String label, String dims) {
    final isSelected = _schema.size == size;
    final accentColor = context.accentColor;

    return GestureDetector(
      onTap: () => _selectSize(size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : AppTheme.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? accentColor : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              dims,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? accentColor.withValues(alpha: 0.7)
                    : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSize(GridWidgetSize size) {
    if (_schema.size == size) return;

    // Check if any elements would be outside new grid bounds
    final newRows = size.rows;
    final newCols = size.columns;

    final elementsOutOfBounds = _schema.elements.where((e) {
      return e.row + e.rowSpan > newRows || e.column + e.columnSpan > newCols;
    }).toList();

    if (elementsOutOfBounds.isNotEmpty) {
      // Remove out-of-bounds elements
      final newElements = _schema.elements
          .where(
            (e) =>
                e.row + e.rowSpan <= newRows &&
                e.column + e.columnSpan <= newCols,
          )
          .toList();

      setState(() {
        _schema = _schema.copyWith(size: size, elements: newElements);
        if (_selectedElementId != null &&
            !newElements.any((e) => e.id == _selectedElementId)) {
          _selectedElementId = null;
        }
      });

      // Notify user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${elementsOutOfBounds.length} element(s) removed - didn\'t fit new size',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _schema = _schema.copyWith(size: size);
      });
    }
  }

  Widget _buildCanvas() {
    final width = _getWidgetWidth();
    final height = _getWidgetHeight();

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_selectedElementId != null) {
              setState(() => _selectedElementId = null);
            }
          },
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder, width: 1),
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
                child: GridWidgetCanvas(
                  schema: _schema,
                  selectedElementId: _selectedElementId,
                  onElementTap: (id) => setState(() {
                    _selectedElementId = _selectedElementId == id ? null : id;
                  }),
                  onEmptyCellTap: _handleCellTap,
                  onElementUpdated: (updated) {
                    setState(() {
                      _schema = _schema.updateElement(updated);
                    });
                  },
                  onElementsSwapped: (element1, element2) {
                    setState(() {
                      _schema = _schema
                          .updateElement(element1)
                          .updateElement(element2);
                    });
                  },
                  onTapOutside: () {
                    if (_selectedElementId != null) {
                      setState(() => _selectedElementId = null);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
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

  void _handleCellTap(int row, int column) async {
    final type = await GridElementPicker.show(context);
    if (type == null) return;

    _addElement(type, row, column);
  }

  void _addElement(GridElementType type, int row, int column) {
    final newElement = _createDefaultElement(type, row, column);

    final added = _schema.addElement(newElement);
    setState(() {
      _schema = added;
      _selectedElementId = newElement.id;
    });

    // Show edit sheet for the new element
    Future.delayed(const Duration(milliseconds: 100), () {
      _editElement(newElement);
    });
  }

  GridElement _createDefaultElement(GridElementType type, int row, int column) {
    switch (type) {
      case GridElementType.text:
        return GridElement(
          type: GridElementType.text,
          row: row,
          column: column,
          text: 'Text',
          fontSize: 14,
          textColor: Colors.white,
        );
      case GridElementType.icon:
        return GridElement(
          type: GridElementType.icon,
          row: row,
          column: column,
          iconName: 'star',
          iconSize: 24,
          iconColor: context.accentColor,
        );
      case GridElementType.iconText:
        return GridElement(
          type: GridElementType.iconText,
          row: row,
          column: column,
          iconName: 'info',
          iconSize: 18,
          iconColor: context.accentColor,
          text: 'Label',
          fontSize: 14,
          textColor: Colors.white,
        );
      case GridElementType.gauge:
        return GridElement(
          type: GridElementType.gauge,
          row: row,
          column: column,
          gaugeStyle: GaugeStyle.linear,
          gaugeMin: 0,
          gaugeMax: 100,
          gaugeColor: context.accentColor,
        );
      case GridElementType.chart:
        return GridElement(
          type: GridElementType.chart,
          row: row,
          column: column,
          chartStyle: ChartStyle.sparkline,
          chartColor: context.accentColor,
        );
      case GridElementType.button:
        return GridElement(
          type: GridElementType.button,
          row: row,
          column: column,
          text: 'Button',
          fontSize: 14,
          textColor: Colors.white,
          iconName: 'touch_app',
          iconSize: 18,
          iconColor: context.accentColor,
        );
    }
  }

  void _editElement(GridElement element) {
    AppBottomSheet.show(
      context: context,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _GridElementEditor(
        element: element,
        onUpdate: (updated) {
          setState(() {
            _schema = _schema.updateElement(updated);
          });
        },
      ),
    );
  }

  void _save() {
    // Basic validation
    if (_schema.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a widget name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_schema.elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one element'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onSave?.call(_schema);
    Navigator.pop(context, _schema);
  }

  // === Helpers ===

  double _getWidgetWidth() {
    if (_schema.customWidth != null) return _schema.customWidth!;
    switch (_schema.size) {
      case GridWidgetSize.small:
        return 160;
      case GridWidgetSize.medium:
        return 240;
      case GridWidgetSize.large:
        return 240;
    }
  }

  double _getWidgetHeight() {
    if (_schema.customHeight != null) return _schema.customHeight!;
    switch (_schema.size) {
      case GridWidgetSize.small:
        return 160;
      case GridWidgetSize.medium:
        return 160;
      case GridWidgetSize.large:
        return 240;
    }
  }
}

/// Inline element editor for grid elements
class _GridElementEditor extends StatefulWidget {
  final GridElement element;
  final void Function(GridElement) onUpdate;

  const _GridElementEditor({required this.element, required this.onUpdate});

  @override
  State<_GridElementEditor> createState() => _GridElementEditorState();
}

class _GridElementEditorState extends State<_GridElementEditor> {
  late GridElement _element;

  @override
  void initState() {
    super.initState();
    _element = widget.element;
  }

  void _update(GridElement updated) {
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
        Row(
          children: [
            Icon(_getIcon(), size: 20, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'Edit ${_element.type.displayName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._buildProperties(accentColor),
        const SizedBox(height: 8),
      ],
    );
  }

  IconData _getIcon() {
    switch (_element.type) {
      case GridElementType.text:
        return Icons.text_fields;
      case GridElementType.icon:
        return Icons.emoji_emotions;
      case GridElementType.iconText:
        return Icons.view_headline;
      case GridElementType.gauge:
        return Icons.speed;
      case GridElementType.chart:
        return Icons.show_chart;
      case GridElementType.button:
        return Icons.touch_app;
    }
  }

  List<Widget> _buildProperties(Color accentColor) {
    switch (_element.type) {
      case GridElementType.text:
        return _buildTextProperties(accentColor);
      case GridElementType.icon:
        return _buildIconProperties(accentColor);
      case GridElementType.iconText:
        return _buildIconTextProperties(accentColor);
      case GridElementType.gauge:
        return _buildGaugeProperties(accentColor);
      case GridElementType.chart:
        return _buildChartProperties(accentColor);
      case GridElementType.button:
        return _buildButtonProperties(accentColor);
    }
  }

  List<Widget> _buildTextProperties(Color accentColor) {
    return [
      _buildSectionLabel('Content'),
      const SizedBox(height: 8),
      _buildBindingSelector(
        currentPath: _element.binding?.path,
        onSelect: (path) {
          if (path == null || path.isEmpty) {
            _update(_element.copyWith(binding: null));
          } else {
            _update(_element.copyWith(binding: GridBinding(path: path)));
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
        value: _element.fontSize ?? 14,
        min: 8,
        max: 48,
        unit: 'sp',
        onChanged: (v) => _update(_element.copyWith(fontSize: v)),
      ),
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Text Color',
        currentColor: _element.textColor,
        defaultColor: Colors.white,
        onSelect: (color) => _update(_element.copyWith(textColor: color)),
      ),
      const SizedBox(height: 12),
      _buildSectionLabel('Alignment'),
      const SizedBox(height: 8),
      _buildAlignmentSelector(accentColor),
      const SizedBox(height: 16),
      _buildSectionLabel('Action (optional)'),
      const SizedBox(height: 8),
      _buildActionSelector(accentColor),
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
        currentColor: _element.iconColor,
        defaultColor: accentColor,
        onSelect: (color) => _update(_element.copyWith(iconColor: color)),
      ),
      const SizedBox(height: 16),
      _buildSectionLabel('Action (optional)'),
      const SizedBox(height: 8),
      _buildActionSelector(accentColor),
    ];
  }

  List<Widget> _buildIconTextProperties(Color accentColor) {
    return [
      _buildSectionLabel('Icon'),
      const SizedBox(height: 8),
      _buildIconSelector(
        currentIcon: _element.iconName ?? 'info',
        onSelect: (name) => _update(_element.copyWith(iconName: name)),
      ),
      const SizedBox(height: 12),
      _buildSlider(
        label: 'Icon Size',
        value: _element.iconSize ?? 18,
        min: 12,
        max: 32,
        unit: 'px',
        onChanged: (v) => _update(_element.copyWith(iconSize: v)),
      ),
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Icon Color',
        currentColor: _element.iconColor,
        defaultColor: accentColor,
        onSelect: (color) => _update(_element.copyWith(iconColor: color)),
      ),
      const SizedBox(height: 16),
      _buildSectionLabel('Text'),
      const SizedBox(height: 8),
      _buildBindingSelector(
        currentPath: _element.binding?.path,
        onSelect: (path) {
          if (path == null || path.isEmpty) {
            _update(_element.copyWith(binding: null));
          } else {
            _update(_element.copyWith(binding: GridBinding(path: path)));
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
      const SizedBox(height: 12),
      _buildSlider(
        label: 'Text Size',
        value: _element.fontSize ?? 14,
        min: 8,
        max: 24,
        unit: 'sp',
        onChanged: (v) => _update(_element.copyWith(fontSize: v)),
      ),
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Text Color',
        currentColor: _element.textColor,
        defaultColor: Colors.white,
        onSelect: (color) => _update(_element.copyWith(textColor: color)),
      ),
      const SizedBox(height: 12),
      _buildSectionLabel('Alignment'),
      const SizedBox(height: 8),
      _buildAlignmentSelector(accentColor),
      const SizedBox(height: 16),
      _buildSectionLabel('Action (optional)'),
      const SizedBox(height: 8),
      _buildActionSelector(accentColor),
    ];
  }

  List<Widget> _buildGaugeProperties(Color accentColor) {
    return [
      _buildSectionLabel('Style'),
      const SizedBox(height: 8),
      _buildGaugeStyleSelector(accentColor),
      const SizedBox(height: 16),
      _buildSectionLabel('Data'),
      const SizedBox(height: 8),
      _buildBindingSelector(
        currentPath: _element.binding?.path,
        numericOnly: true, // Gauges only accept numeric values
        onSelect: (path) {
          if (path == null || path.isEmpty) {
            _update(_element.copyWith(binding: null));
          } else {
            _update(_element.copyWith(binding: GridBinding(path: path)));
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
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Gauge Color',
        currentColor: _element.gaugeColor,
        defaultColor: accentColor,
        onSelect: (color) => _update(_element.copyWith(gaugeColor: color)),
      ),
    ];
  }

  List<Widget> _buildChartProperties(Color accentColor) {
    return [
      _buildSectionLabel('Style'),
      const SizedBox(height: 8),
      _buildChartStyleSelector(accentColor),
      const SizedBox(height: 16),
      _buildSectionLabel('Data'),
      const SizedBox(height: 8),
      _buildBindingSelector(
        currentPath: _element.binding?.path,
        numericOnly: true, // Charts only accept numeric values
        onSelect: (path) {
          if (path == null || path.isEmpty) {
            _update(_element.copyWith(binding: null));
          } else {
            _update(_element.copyWith(binding: GridBinding(path: path)));
          }
        },
      ),
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Chart Color',
        currentColor: _element.chartColor,
        defaultColor: accentColor,
        onSelect: (color) => _update(_element.copyWith(chartColor: color)),
      ),
    ];
  }

  List<Widget> _buildButtonProperties(Color accentColor) {
    return [
      _buildSectionLabel('Button Text'),
      const SizedBox(height: 8),
      _buildTextField(
        label: 'Label',
        value: _element.text ?? 'Button',
        onChanged: (value) => _update(_element.copyWith(text: value)),
      ),
      const SizedBox(height: 16),
      _buildSectionLabel('Icon (Optional)'),
      const SizedBox(height: 8),
      _buildIconSelector(
        currentIcon: _element.iconName ?? 'touch_app',
        onSelect: (icon) => _update(_element.copyWith(iconName: icon)),
      ),
      const SizedBox(height: 12),
      InlineColorSelector(
        label: 'Icon Color',
        currentColor: _element.iconColor,
        defaultColor: accentColor,
        onSelect: (color) => _update(_element.copyWith(iconColor: color)),
      ),
      const SizedBox(height: 16),
      _buildSectionLabel('Action'),
      const SizedBox(height: 8),
      _buildActionSelector(accentColor),
    ];
  }

  Widget _buildGaugeStyleSelector(Color accentColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: GaugeStyle.values.map((style) {
        final isSelected = _element.gaugeStyle == style;
        return GestureDetector(
          onTap: () => _update(_element.copyWith(gaugeStyle: style)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.2)
                  : AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? accentColor : AppTheme.darkBorder,
              ),
            ),
            child: Text(
              style.name[0].toUpperCase() + style.name.substring(1),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? accentColor : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartStyleSelector(Color accentColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ChartStyle.values.map((style) {
        final isSelected = _element.chartStyle == style;
        return GestureDetector(
          onTap: () => _update(_element.copyWith(chartStyle: style)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.2)
                  : AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? accentColor : AppTheme.darkBorder,
              ),
            ),
            child: Text(
              style.name[0].toUpperCase() + style.name.substring(1),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? accentColor : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlignmentSelector(Color accentColor) {
    final currentAlignment = _element.alignment ?? ElementAlignment.left;

    return Row(
      children: ElementAlignment.values.map((alignment) {
        final isSelected = currentAlignment == alignment;
        IconData icon;
        switch (alignment) {
          case ElementAlignment.left:
            icon = Icons.format_align_left;
          case ElementAlignment.center:
            icon = Icons.format_align_center;
          case ElementAlignment.right:
            icon = Icons.format_align_right;
        }

        return Expanded(
          child: GestureDetector(
            onTap: () => _update(_element.copyWith(alignment: alignment)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.2)
                    : AppTheme.darkBackground,
                borderRadius: BorderRadius.horizontal(
                  left: alignment == ElementAlignment.left
                      ? const Radius.circular(8)
                      : Radius.zero,
                  right: alignment == ElementAlignment.right
                      ? const Radius.circular(8)
                      : Radius.zero,
                ),
                border: Border.all(
                  color: isSelected ? accentColor : AppTheme.darkBorder,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? accentColor : AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionSelector(Color accentColor) {
    final hasAction =
        _element.action != null && _element.action!.type != GridActionType.none;

    return InkWell(
      onTap: () async {
        final result = await _showGridActionSelector();
        if (result != null) {
          _update(_element.copyWith(action: result));
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasAction
              ? accentColor.withValues(alpha: 0.1)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasAction ? accentColor : AppTheme.darkBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasAction ? _getActionIcon(_element.action!.type) : Icons.add,
              size: 18,
              color: hasAction ? accentColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasAction
                    ? _getActionName(_element.action!.type)
                    : 'Add tap action',
                style: TextStyle(
                  color: hasAction ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<GridAction?> _showGridActionSelector() async {
    return await AppBottomSheet.show<GridAction>(
      context: context,
      child: _GridActionPicker(
        currentAction: _element.action,
        onSelect: (action) => Navigator.pop(context, action),
      ),
    );
  }

  IconData _getActionIcon(GridActionType type) {
    switch (type) {
      case GridActionType.sendMessage:
        return Icons.send;
      case GridActionType.shareLocation:
        return Icons.location_on;
      case GridActionType.traceroute:
        return Icons.timeline;
      case GridActionType.requestPositions:
        return Icons.refresh;
      case GridActionType.sos:
        return Icons.warning_amber;
      case GridActionType.navigate:
        return Icons.open_in_new;
      case GridActionType.openUrl:
        return Icons.link;
      case GridActionType.copyToClipboard:
        return Icons.copy;
      case GridActionType.none:
        return Icons.block;
    }
  }

  String _getActionName(GridActionType type) {
    switch (type) {
      case GridActionType.sendMessage:
        return 'Send Message';
      case GridActionType.shareLocation:
        return 'Share Location';
      case GridActionType.traceroute:
        return 'Traceroute';
      case GridActionType.requestPositions:
        return 'Request Positions';
      case GridActionType.sos:
        return 'SOS Alert';
      case GridActionType.navigate:
        return 'Navigate';
      case GridActionType.openUrl:
        return 'Open URL';
      case GridActionType.copyToClipboard:
        return 'Copy to Clipboard';
      case GridActionType.none:
        return 'None';
    }
  }

  // === UI Builders ===

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
    return _ManagedTextField(label: label, value: value, onChanged: onChanged);
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AppTheme.textSecondary)),
            Text(
              '${value.round()}$unit',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            thumbColor: context.accentColor,
            activeTrackColor: context.accentColor,
            inactiveTrackColor: AppTheme.darkBorder,
            overlayColor: context.accentColor.withValues(alpha: 0.2),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildCompactNumberField({
    required String label,
    required double value,
    required void Function(double) onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value.toStringAsFixed(0)),
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
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
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
    );
  }

  Widget _buildBindingSelector({
    required String? currentPath,
    required void Function(String?) onSelect,
    bool numericOnly = false,
  }) {
    final hasBinding = currentPath != null && currentPath.isNotEmpty;

    return InkWell(
      onTap: () async {
        final result = await BindingSelector.show(
          context: context,
          selectedPath: currentPath,
          numericOnly: numericOnly,
        );
        if (result != null) {
          onSelect(result.isEmpty ? null : result);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasBinding
              ? context.accentColor.withValues(alpha: 0.1)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasBinding ? context.accentColor : AppTheme.darkBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasBinding ? Icons.data_object : Icons.add_link,
              size: 18,
              color: hasBinding ? context.accentColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasBinding ? currentPath : 'Bind to data',
                style: TextStyle(
                  color: hasBinding ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
            if (hasBinding)
              GestureDetector(
                onTap: () => onSelect(null),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppTheme.textSecondary,
              ),
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
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Row(
          children: [
            Icon(
              _getIconDataFromName(currentIcon),
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
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  IconData _getIconDataFromName(String name) {
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

/// Action picker for grid elements
class _GridActionPicker extends StatelessWidget {
  final GridAction? currentAction;
  final void Function(GridAction) onSelect;

  const _GridActionPicker({this.currentAction, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Action',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionOption(
          context,
          GridActionType.sendMessage,
          Icons.send,
          'Send Message',
          'Send a preset message',
          accentColor,
        ),
        _buildActionOption(
          context,
          GridActionType.shareLocation,
          Icons.location_on,
          'Share Location',
          'Share your current location',
          accentColor,
        ),
        _buildActionOption(
          context,
          GridActionType.traceroute,
          Icons.timeline,
          'Traceroute',
          'Trace the route to this node',
          accentColor,
        ),
        _buildActionOption(
          context,
          GridActionType.requestPositions,
          Icons.refresh,
          'Request Positions',
          'Request positions from all nodes',
          accentColor,
        ),
        _buildActionOption(
          context,
          GridActionType.sos,
          Icons.warning_amber,
          'SOS Alert',
          'Send emergency alert',
          accentColor,
        ),
        const SizedBox(height: 8),
        if (currentAction != null && currentAction!.type != GridActionType.none)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () =>
                  onSelect(const GridAction(type: GridActionType.none)),
              child: Text(
                'Remove action',
                style: TextStyle(color: AppTheme.errorRed),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionOption(
    BuildContext context,
    GridActionType type,
    IconData icon,
    String title,
    String subtitle,
    Color accentColor,
  ) {
    final isSelected = currentAction?.type == type;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelect(GridAction(type: type)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.15)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentColor : AppTheme.darkBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: accentColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field that properly manages its controller to avoid keyboard/typing issues
class _ManagedTextField extends StatefulWidget {
  final String label;
  final String value;
  final void Function(String) onChanged;

  const _ManagedTextField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ManagedTextField> createState() => _ManagedTextFieldState();
}

class _ManagedTextFieldState extends State<_ManagedTextField> {
  late TextEditingController _controller;
  bool _isUserEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ManagedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text if user isn't actively editing and value changed externally
    if (!_isUserEditing && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isUserEditing = hasFocus;
        });
      },
      child: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: widget.label,
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
        onChanged: widget.onChanged,
      ),
    );
  }
}
