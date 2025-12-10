import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../renderer/widget_renderer.dart';
import '../../../core/theme.dart';

/// Widget builder editor screen with drag-drop canvas
class WidgetEditorScreen extends ConsumerStatefulWidget {
  final WidgetSchema? initialSchema;
  final void Function(WidgetSchema schema)? onSave;

  const WidgetEditorScreen({super.key, this.initialSchema, this.onSave});

  @override
  ConsumerState<WidgetEditorScreen> createState() => _WidgetEditorScreenState();
}

class _WidgetEditorScreenState extends ConsumerState<WidgetEditorScreen> {
  late WidgetSchema _schema;
  String? _selectedElementId;
  bool _showPreview = false;
  bool _showToolbox = true;

  @override
  void initState() {
    super.initState();
    _schema = widget.initialSchema ?? _createDefaultSchema();
  }

  WidgetSchema _createDefaultSchema() {
    return WidgetSchema(
      name: 'New Widget',
      description: 'Custom widget',
      root: ElementSchema(
        type: ElementType.container,
        style: const StyleSchema(padding: 12, backgroundColor: '#1E1E2E'),
        children: [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Left: Toolbox
                if (_showToolbox) _buildToolbox(),
                // Center: Canvas
                Expanded(child: _buildCanvas()),
                // Right: Property Inspector
                if (_selectedElementId != null) _buildPropertyInspector(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.darkBackground,
      title: Text(
        _schema.name,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        // Toggle toolbox
        IconButton(
          icon: Icon(
            _showToolbox ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            color: _showToolbox ? context.accentColor : Colors.white,
          ),
          onPressed: () => setState(() => _showToolbox = !_showToolbox),
          tooltip: 'Toggle Toolbox',
        ),
        // Toggle preview
        IconButton(
          icon: Icon(
            _showPreview ? Icons.edit : Icons.preview,
            color: _showPreview ? context.accentColor : Colors.white,
          ),
          onPressed: () => setState(() {
            _showPreview = !_showPreview;
            if (_showPreview) _selectedElementId = null;
          }),
          tooltip: _showPreview ? 'Edit Mode' : 'Preview Mode',
        ),
        const SizedBox(width: 8),
        // Save button
        TextButton.icon(
          onPressed: _saveWidget,
          icon: Icon(Icons.save, color: context.accentColor),
          label: Text(
            'Save',
            style: TextStyle(
              color: context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildToolbox() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(right: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: const Row(
              children: [
                Icon(Icons.widgets_outlined, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Elements',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Element list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _buildToolboxSection('Layout', [
                  _ToolboxItem(ElementType.row, 'Row', Icons.view_column),
                  _ToolboxItem(ElementType.column, 'Column', Icons.view_agenda),
                  _ToolboxItem(
                    ElementType.container,
                    'Container',
                    Icons.crop_square,
                  ),
                  _ToolboxItem(ElementType.stack, 'Stack', Icons.layers),
                  _ToolboxItem(ElementType.spacer, 'Spacer', Icons.space_bar),
                ]),
                const SizedBox(height: 12),
                _buildToolboxSection('Content', [
                  _ToolboxItem(ElementType.text, 'Text', Icons.text_fields),
                  _ToolboxItem(
                    ElementType.icon,
                    'Icon',
                    Icons.emoji_emotions_outlined,
                  ),
                  _ToolboxItem(ElementType.image, 'Image', Icons.image),
                  _ToolboxItem(ElementType.shape, 'Shape', Icons.square),
                ]),
                const SizedBox(height: 12),
                _buildToolboxSection('Data Display', [
                  _ToolboxItem(ElementType.gauge, 'Gauge', Icons.speed),
                  _ToolboxItem(ElementType.chart, 'Chart', Icons.show_chart),
                  _ToolboxItem(ElementType.map, 'Map', Icons.map),
                ]),
                const SizedBox(height: 12),
                _buildToolboxSection('Logic', [
                  _ToolboxItem(
                    ElementType.conditional,
                    'Conditional',
                    Icons.rule,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolboxSection(String title, List<_ToolboxItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items.map((item) => _buildDraggableElement(item)),
      ],
    );
  }

  Widget _buildDraggableElement(_ToolboxItem item) {
    return Draggable<ElementType>(
      data: item.type,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildToolboxButton(item),
      ),
      child: _buildToolboxButton(item),
    );
  }

  Widget _buildToolboxButton(_ToolboxItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addElement(item.type),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Container(
      color: AppTheme.darkBackground,
      child: Column(
        children: [
          // Widget info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                // Widget name
                Expanded(
                  child: GestureDetector(
                    onTap: _editWidgetName,
                    child: Row(
                      children: [
                        Text(
                          _schema.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Size selector
                _buildSizeSelector(),
              ],
            ),
          ),
          // Canvas area
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: DragTarget<ElementType>(
                  onAcceptWithDetails: (details) => _addElement(details.data),
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    return Container(
                      width: _getWidgetWidth(),
                      height: _getWidgetHeight(),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isHovering
                              ? context.accentColor
                              : AppTheme.darkBorder,
                          width: isHovering ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _showPreview
                          ? _buildPreviewContent()
                          : _buildEditableContent(),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelector() {
    return Row(
      children: [
        _buildSizeOption(CustomWidgetSize.small, 'S'),
        const SizedBox(width: 4),
        _buildSizeOption(CustomWidgetSize.medium, 'M'),
        const SizedBox(width: 4),
        _buildSizeOption(CustomWidgetSize.large, 'L'),
      ],
    );
  }

  Widget _buildSizeOption(CustomWidgetSize size, String label) {
    final isSelected = _schema.size == size;
    return GestureDetector(
      onTap: () => setState(() {
        _schema = _schema.copyWith(size: size);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentColor.withValues(alpha: 0.2)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? context.accentColor : AppTheme.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? context.accentColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
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

  Widget _buildEditableContent() {
    return WidgetRenderer(
      schema: _schema,
      accentColor: context.accentColor,
      isPreview: true,
      selectedElementId: _selectedElementId,
      onElementTap: (id) => setState(() => _selectedElementId = id),
    );
  }

  Widget _buildPreviewContent() {
    return WidgetRenderer(schema: _schema, accentColor: context.accentColor);
  }

  Widget _buildPropertyInspector() {
    final element = _findElementById(_schema.root, _selectedElementId!);
    if (element == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(left: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getElementTypeName(element.type),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppTheme.errorRed,
                  ),
                  onPressed: () => _deleteElement(element.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Properties
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildPropertySection(
                  'Content',
                  _buildContentProperties(element),
                ),
                const SizedBox(height: 16),
                _buildPropertySection(
                  'Data Binding',
                  _buildBindingProperties(element),
                ),
                const SizedBox(height: 16),
                _buildPropertySection('Style', _buildStyleProperties(element)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertySection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  List<Widget> _buildContentProperties(ElementSchema element) {
    final properties = <Widget>[];

    switch (element.type) {
      case ElementType.text:
        properties.add(
          _buildTextField(
            label: 'Text',
            value: element.text ?? '',
            onChanged: (value) =>
                _updateElement(element.id, element.copyWith(text: value)),
          ),
        );
        break;

      case ElementType.icon:
        properties.add(
          _buildDropdownField(
            label: 'Icon',
            value: element.iconName ?? 'help_outline',
            options: _commonIconNames,
            onChanged: (value) =>
                _updateElement(element.id, element.copyWith(iconName: value)),
          ),
        );
        properties.add(const SizedBox(height: 8));
        properties.add(
          _buildNumberField(
            label: 'Size',
            value: element.iconSize ?? 24,
            onChanged: (value) =>
                _updateElement(element.id, element.copyWith(iconSize: value)),
          ),
        );
        break;

      case ElementType.gauge:
        properties.add(
          _buildDropdownField(
            label: 'Type',
            value: (element.gaugeType ?? GaugeType.linear).name,
            options: GaugeType.values.map((e) => e.name).toList(),
            onChanged: (value) => _updateElement(
              element.id,
              element.copyWith(
                gaugeType: GaugeType.values.firstWhere((e) => e.name == value),
              ),
            ),
          ),
        );
        properties.add(const SizedBox(height: 8));
        properties.add(
          _buildNumberField(
            label: 'Min',
            value: element.gaugeMin ?? 0,
            onChanged: (value) =>
                _updateElement(element.id, element.copyWith(gaugeMin: value)),
          ),
        );
        properties.add(const SizedBox(height: 8));
        properties.add(
          _buildNumberField(
            label: 'Max',
            value: element.gaugeMax ?? 100,
            onChanged: (value) =>
                _updateElement(element.id, element.copyWith(gaugeMax: value)),
          ),
        );
        break;

      case ElementType.chart:
        properties.add(
          _buildDropdownField(
            label: 'Type',
            value: (element.chartType ?? ChartType.sparkline).name,
            options: ChartType.values.map((e) => e.name).toList(),
            onChanged: (value) => _updateElement(
              element.id,
              element.copyWith(
                chartType: ChartType.values.firstWhere((e) => e.name == value),
              ),
            ),
          ),
        );
        break;

      case ElementType.shape:
        properties.add(
          _buildDropdownField(
            label: 'Shape',
            value: (element.shapeType ?? ShapeType.rectangle).name,
            options: ShapeType.values.map((e) => e.name).toList(),
            onChanged: (value) => _updateElement(
              element.id,
              element.copyWith(
                shapeType: ShapeType.values.firstWhere((e) => e.name == value),
              ),
            ),
          ),
        );
        break;

      default:
        break;
    }

    return properties;
  }

  List<Widget> _buildBindingProperties(ElementSchema element) {
    return [
      _buildDropdownField(
        label: 'Bind to',
        value: element.binding?.path ?? '',
        options: ['', ...BindingRegistry.bindings.map((b) => b.path)],
        onChanged: (value) {
          if (value.isEmpty) {
            _updateElement(
              element.id,
              ElementSchema(
                id: element.id,
                type: element.type,
                style: element.style,
                binding: null,
                condition: element.condition,
                children: element.children,
                text: element.text,
                iconName: element.iconName,
                iconSize: element.iconSize,
                gaugeType: element.gaugeType,
                gaugeMin: element.gaugeMin,
                gaugeMax: element.gaugeMax,
                chartType: element.chartType,
                shapeType: element.shapeType,
              ),
            );
          } else {
            _updateElement(
              element.id,
              element.copyWith(binding: BindingSchema(path: value)),
            );
          }
        },
      ),
      if (element.binding != null) ...[
        const SizedBox(height: 8),
        _buildTextField(
          label: 'Format',
          value: element.binding?.format ?? '{value}',
          onChanged: (value) => _updateElement(
            element.id,
            element.copyWith(
              binding: BindingSchema(
                path: element.binding!.path,
                format: value,
                defaultValue: element.binding?.defaultValue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          label: 'Default',
          value: element.binding?.defaultValue ?? '',
          onChanged: (value) => _updateElement(
            element.id,
            element.copyWith(
              binding: BindingSchema(
                path: element.binding!.path,
                format: element.binding?.format,
                defaultValue: value.isEmpty ? null : value,
              ),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildStyleProperties(ElementSchema element) {
    return [
      _buildNumberField(
        label: 'Width',
        value: element.style.width ?? 0,
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(
            style: element.style.copyWith(width: value > 0 ? value : null),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _buildNumberField(
        label: 'Height',
        value: element.style.height ?? 0,
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(
            style: element.style.copyWith(height: value > 0 ? value : null),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _buildNumberField(
        label: 'Padding',
        value: element.style.padding ?? 0,
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(
            style: element.style.copyWith(padding: value > 0 ? value : null),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _buildColorField(
        label: 'Text Color',
        value: element.style.textColor ?? '#FFFFFF',
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(style: element.style.copyWith(textColor: value)),
        ),
      ),
      const SizedBox(height: 8),
      _buildNumberField(
        label: 'Font Size',
        value: element.style.fontSize ?? 14,
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(
            style: element.style.copyWith(fontSize: value > 0 ? value : null),
          ),
        ),
      ),
    ];
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: value),
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: AppTheme.darkBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AppTheme.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AppTheme.darkBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: value.toString()),
          keyboardType: TextInputType.number,
          onChanged: (text) {
            final parsed = double.tryParse(text);
            if (parsed != null) onChanged(parsed);
          },
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: AppTheme.darkBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AppTheme.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AppTheme.darkBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: DropdownButton<String>(
            value: options.contains(value) ? value : options.first,
            isExpanded: true,
            isDense: true,
            dropdownColor: AppTheme.darkCard,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(
                  option.isEmpty ? '(none)' : option,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorField({
    required String label,
    required String value,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _parseColor(value),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.darkBorder),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: value),
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: AppTheme.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  void _addElement(ElementType type) {
    final newElement = _createDefaultElement(type);

    // Add to root children
    final updatedRoot = _schema.root.copyWith(
      children: [..._schema.root.children, newElement],
    );

    setState(() {
      _schema = _schema.copyWith(root: updatedRoot);
      _selectedElementId = newElement.id;
    });
  }

  ElementSchema _createDefaultElement(ElementType type) {
    switch (type) {
      case ElementType.text:
        return ElementSchema(
          type: type,
          text: 'Text',
          style: const StyleSchema(textColor: '#FFFFFF', fontSize: 14),
        );
      case ElementType.icon:
        return ElementSchema(
          type: type,
          iconName: 'star',
          iconSize: 24,
          style: const StyleSchema(textColor: '#FFFFFF'),
        );
      case ElementType.gauge:
        return ElementSchema(
          type: type,
          gaugeType: GaugeType.linear,
          gaugeMin: 0,
          gaugeMax: 100,
          style: const StyleSchema(height: 8),
          binding: const BindingSchema(path: 'node.batteryLevel'),
        );
      case ElementType.chart:
        return ElementSchema(
          type: type,
          chartType: ChartType.sparkline,
          style: const StyleSchema(height: 60),
        );
      case ElementType.shape:
        return ElementSchema(
          type: type,
          shapeType: ShapeType.rectangle,
          style: const StyleSchema(
            width: 40,
            height: 40,
            backgroundColor: '#3B3B4F',
            borderRadius: 8,
          ),
        );
      case ElementType.row:
        return ElementSchema(
          type: type,
          style: const StyleSchema(spacing: 8),
          children: [],
        );
      case ElementType.column:
        return ElementSchema(
          type: type,
          style: const StyleSchema(spacing: 8),
          children: [],
        );
      case ElementType.container:
        return ElementSchema(
          type: type,
          style: const StyleSchema(padding: 8),
          children: [],
        );
      case ElementType.spacer:
        return ElementSchema(type: type, style: const StyleSchema(height: 8));
      case ElementType.stack:
        return ElementSchema(type: type, children: []);
      case ElementType.image:
        return ElementSchema(
          type: type,
          style: const StyleSchema(width: 40, height: 40),
        );
      case ElementType.map:
        return ElementSchema(type: type, style: const StyleSchema(height: 100));
      case ElementType.conditional:
        return ElementSchema(
          type: type,
          condition: const ConditionalSchema(
            bindingPath: 'node.isOnline',
            operator: ConditionalOperator.equals,
            value: true,
          ),
          children: [],
        );
    }
  }

  void _updateElement(String id, ElementSchema updatedElement) {
    setState(() {
      _schema = _schema.copyWith(
        root: _updateElementInTree(_schema.root, id, updatedElement),
      );
    });
  }

  ElementSchema _updateElementInTree(
    ElementSchema parent,
    String id,
    ElementSchema updated,
  ) {
    if (parent.id == id) return updated;

    return parent.copyWith(
      children: parent.children.map((child) {
        return _updateElementInTree(child, id, updated);
      }).toList(),
    );
  }

  void _deleteElement(String id) {
    setState(() {
      _schema = _schema.copyWith(
        root: _removeElementFromTree(_schema.root, id),
      );
      _selectedElementId = null;
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

  ElementSchema? _findElementById(ElementSchema parent, String id) {
    if (parent.id == id) return parent;

    for (final child in parent.children) {
      final found = _findElementById(child, id);
      if (found != null) return found;
    }

    return null;
  }

  String _getElementTypeName(ElementType type) {
    switch (type) {
      case ElementType.text:
        return 'Text';
      case ElementType.icon:
        return 'Icon';
      case ElementType.image:
        return 'Image';
      case ElementType.gauge:
        return 'Gauge';
      case ElementType.chart:
        return 'Chart';
      case ElementType.map:
        return 'Map';
      case ElementType.shape:
        return 'Shape';
      case ElementType.conditional:
        return 'Conditional';
      case ElementType.container:
        return 'Container';
      case ElementType.row:
        return 'Row';
      case ElementType.column:
        return 'Column';
      case ElementType.spacer:
        return 'Spacer';
      case ElementType.stack:
        return 'Stack';
    }
  }

  void _editWidgetName() async {
    final controller = TextEditingController(text: _schema.name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Widget Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter widget name',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save', style: TextStyle(color: context.accentColor)),
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

  void _saveWidget() {
    widget.onSave?.call(_schema);
    Navigator.of(context).pop(_schema);
  }

  static const _commonIconNames = [
    'battery_full',
    'battery_alert',
    'signal_cellular_alt',
    'wifi',
    'bluetooth',
    'gps_fixed',
    'thermostat',
    'water_drop',
    'air',
    'cloud',
    'wb_sunny',
    'hub',
    'router',
    'devices',
    'message',
    'chat',
    'send',
    'map',
    'navigation',
    'explore',
    'near_me',
    'settings',
    'info',
    'warning',
    'error',
    'check_circle',
    'speed',
    'timeline',
    'trending_up',
    'trending_down',
    'show_chart',
    'favorite',
    'star',
    'help_outline',
  ];
}

class _ToolboxItem {
  final ElementType type;
  final String label;
  final IconData icon;

  const _ToolboxItem(this.type, this.label, this.icon);
}
