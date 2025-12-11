import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import 'selectors/icon_selector.dart';
import 'selectors/binding_selector.dart';
import 'simple_widget_canvas.dart';

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
  bool _showPreview = false;

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
        style: const StyleSchema(padding: 12),
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
            // Size selector
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
        // Preview toggle
        IconButton(
          icon: Icon(
            _showPreview ? Icons.edit : Icons.visibility,
            color: _showPreview ? context.accentColor : Colors.white,
          ),
          onPressed: () => setState(() {
            _showPreview = !_showPreview;
            if (_showPreview) _selectedElementId = null;
          }),
          tooltip: _showPreview ? 'Edit' : 'Preview',
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSizeChip(CustomWidgetSize.small, 'Small'),
          const SizedBox(width: 8),
          _buildSizeChip(CustomWidgetSize.medium, 'Medium'),
          const SizedBox(width: 8),
          _buildSizeChip(CustomWidgetSize.large, 'Large'),
        ],
      ),
    );
  }

  Widget _buildSizeChip(CustomWidgetSize size, String label) {
    final isSelected = _schema.size == size;
    final accentColor = context.accentColor;

    return GestureDetector(
      onTap: () => setState(() {
        _schema = _schema.copyWith(size: size);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
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
              isPreview: _showPreview,
              onElementTap: (id) => setState(() {
                _selectedElementId = _selectedElementId == id ? null : id;
              }),
              onDropZoneTap: _handleDropZoneTap,
              onDeleteElement: _deleteElement,
            ),
          ),
        ),
      ),
    );
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
    widget.onSave?.call(_schema);
    Navigator.pop(context, _schema);
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
    switch (_schema.size) {
      case CustomWidgetSize.small:
        return 160;
      case CustomWidgetSize.medium:
        return 320;
      case CustomWidgetSize.large:
        return 320;
    }
  }

  double _getWidgetHeight() {
    switch (_schema.size) {
      case CustomWidgetSize.small:
        return 160;
      case CustomWidgetSize.medium:
        return 160;
      case CustomWidgetSize.large:
        return 320;
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
    ];
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
    return TextField(
      controller: TextEditingController(text: value),
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
    return TextField(
      controller: TextEditingController(text: value.round().toString()),
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
    };
    return map[name] ?? Icons.help_outline;
  }
}
