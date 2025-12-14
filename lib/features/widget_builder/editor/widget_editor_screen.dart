import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../renderer/widget_renderer.dart';
import '../../../core/theme.dart';
import '../../../utils/snackbar.dart';
import 'selectors/icon_selector.dart';
import 'selectors/binding_selector.dart';

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

  // Track if we're in portrait mode
  bool get _isPortrait =>
      MediaQuery.of(context).orientation == Orientation.portrait;
  bool get _isNarrow => MediaQuery.of(context).size.width < 600;

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
    // Use different layouts for portrait/narrow vs landscape/wide
    if (_isPortrait || _isNarrow) {
      return _buildPortraitLayout();
    }
    return _buildLandscapeLayout();
  }

  /// Portrait layout - full screen canvas with bottom sheets for tools/properties
  Widget _buildPortraitLayout() {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildCompactAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Widget info bar with size selector
            _buildCompactInfoBar(),
            // Canvas takes all remaining space
            Expanded(child: _buildFullscreenCanvas()),
          ],
        ),
      ),
      // Bottom navigation for tools
      bottomNavigationBar: _buildBottomToolbar(),
    );
  }

  /// Landscape layout - side-by-side panels
  Widget _buildLandscapeLayout() {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
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
    );
  }

  AppBar _buildCompactAppBar() {
    return AppBar(
      backgroundColor: AppTheme.darkBackground,
      leadingWidth: 40,
      title: GestureDetector(
        onTap: _editWidgetName,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _schema.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: AppTheme.textTertiary),
          ],
        ),
      ),
      actions: [
        // Toggle preview
        IconButton(
          icon: Icon(
            _showPreview ? Icons.edit : Icons.preview,
            color: _showPreview ? context.accentColor : Colors.white,
            size: 22,
          ),
          onPressed: () => setState(() {
            _showPreview = !_showPreview;
            if (_showPreview) _selectedElementId = null;
          }),
          tooltip: _showPreview ? 'Edit Mode' : 'Preview Mode',
        ),
        // Save button
        TextButton.icon(
          onPressed: _saveWidget,
          icon: Icon(Icons.save, color: context.accentColor, size: 20),
          label: Text(
            'Save',
            style: TextStyle(
              color: context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildCompactInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          // Size selector - takes priority
          Expanded(child: _buildCompactSizeSelector()),
        ],
      ),
    );
  }

  Widget _buildCompactSizeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSizeOption(CustomWidgetSize.medium, 'M'),
        const SizedBox(width: 8),
        _buildSizeOption(CustomWidgetSize.large, 'L'),
      ],
    );
  }

  Widget _buildFullscreenCanvas() {
    return Container(
      color: AppTheme.darkBackground,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DragTarget<ElementType>(
            onAcceptWithDetails: (details) => _addElement(details.data),
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              // Scale widget to fit screen while maintaining aspect ratio
              final screenWidth = MediaQuery.of(context).size.width - 32;
              final widgetWidth = _getWidgetWidth();
              final scale = screenWidth < widgetWidth
                  ? screenWidth / widgetWidth
                  : 1.0;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widgetWidth,
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Add element button
              Expanded(
                child: FilledButton.icon(
                  onPressed: _showElementPicker,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Element'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_selectedElementId != null) ...[
                const SizedBox(width: 8),
                // Edit selected element
                OutlinedButton.icon(
                  onPressed: _showPropertySheet,
                  icon: const Icon(Icons.tune, size: 20),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.darkBorder),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete selected element
                IconButton(
                  onPressed: () => _deleteElement(_selectedElementId!),
                  icon: Icon(Icons.delete_outline, color: AppTheme.errorRed),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.darkBackground,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showElementPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.widgets_outlined,
                    size: 20,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Add Element',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Element grid
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildElementPickerSection('Layout', [
                    _ToolboxItem(ElementType.row, 'Row', Icons.view_column),
                    _ToolboxItem(
                      ElementType.column,
                      'Column',
                      Icons.view_agenda,
                    ),
                    _ToolboxItem(
                      ElementType.container,
                      'Container',
                      Icons.crop_square,
                    ),
                    _ToolboxItem(ElementType.stack, 'Stack', Icons.layers),
                    _ToolboxItem(ElementType.spacer, 'Spacer', Icons.space_bar),
                  ]),
                  _buildElementPickerSection('Content', [
                    _ToolboxItem(ElementType.text, 'Text', Icons.text_fields),
                    _ToolboxItem(
                      ElementType.icon,
                      'Icon',
                      Icons.emoji_emotions_outlined,
                    ),
                    _ToolboxItem(ElementType.image, 'Image', Icons.image),
                    _ToolboxItem(ElementType.shape, 'Shape', Icons.square),
                  ]),
                  _buildElementPickerSection('Data Display', [
                    _ToolboxItem(ElementType.gauge, 'Gauge', Icons.speed),
                    _ToolboxItem(ElementType.chart, 'Chart', Icons.show_chart),
                    _ToolboxItem(ElementType.map, 'Map', Icons.map),
                  ]),
                  _buildElementPickerSection('Logic', [
                    _ToolboxItem(
                      ElementType.conditional,
                      'Conditional',
                      Icons.rule,
                    ),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElementPickerSection(String title, List<_ToolboxItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) => _buildElementPickerChip(item)).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildElementPickerChip(_ToolboxItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _addElement(item.type);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 18, color: context.accentColor),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPropertySheet() {
    if (_selectedElementId == null) return;
    final element = _findElementById(_schema.root, _selectedElementId!);
    if (element == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => Column(
            children: [
              // Handle + Live preview row
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.darkBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Mini widget preview
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _getWidgetWidth(),
                            height: _getWidgetHeight(),
                            child: WidgetRenderer(
                              schema: _schema,
                              accentColor: context.accentColor,
                              usePlaceholderData: true,
                              isPreview: false,
                              enableActions: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: context.accentColor),
                    const SizedBox(width: 8),
                    Text(
                      _getElementTypeName(element.type),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteElement(element.id);
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        color: AppTheme.errorRed,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              // Properties
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
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
                    _buildPropertySection(
                      'Style',
                      _buildStyleProperties(element),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        _buildSizeOption(CustomWidgetSize.medium, 'M'),
        const SizedBox(width: 4),
        _buildSizeOption(CustomWidgetSize.large, 'L'),
      ],
    );
  }

  Widget _buildSizeOption(CustomWidgetSize size, String label) {
    final isSelected = _schema.size == size;
    return GestureDetector(
      onTap: () => _changeSize(size),
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
    if (_schema.customWidth != null) {
      return _schema.customWidth!;
    }
    switch (_schema.size) {
      case CustomWidgetSize.medium:
        return 320;
      case CustomWidgetSize.large:
        return 320;
      case CustomWidgetSize.custom:
        return 320;
    }
  }

  double _getWidgetHeight() {
    if (_schema.customHeight != null) {
      return _schema.customHeight!;
    }
    switch (_schema.size) {
      case CustomWidgetSize.medium:
        return 160;
      case CustomWidgetSize.large:
        return 320;
      case CustomWidgetSize.custom:
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
          _buildIconSelectorField(
            label: 'Icon',
            value: element.iconName ?? 'help_outline',
            onChanged: (value) =>
                _updateElement(element.id, element.copyWith(iconName: value)),
          ),
        );
        properties.add(const SizedBox(height: 8));
        properties.add(
          _buildSliderField(
            label: 'Size',
            value: element.iconSize ?? 24,
            min: 12,
            max: 96,
            unit: 'px',
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
          _buildSliderField(
            label: 'Min',
            value: element.gaugeMin ?? 0,
            min: -100,
            max: 100,
            onChanged: (value) =>
                _updateElement(element.id, element.copyWith(gaugeMin: value)),
          ),
        );
        properties.add(const SizedBox(height: 8));
        properties.add(
          _buildSliderField(
            label: 'Max',
            value: element.gaugeMax ?? 100,
            min: 0,
            max: 1000,
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
      _buildBindingSelectorField(
        label: 'Bind to',
        value: element.binding?.path ?? '',
        onChanged: (value) {
          if (value == null || value.isEmpty) {
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
      _buildSliderField(
        label: 'Width',
        value: element.style.width ?? 0,
        min: 0,
        max: 400,
        unit: 'px',
        allowZero: true,
        zeroLabel: 'Auto',
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(
            style: element.style.copyWith(width: value > 0 ? value : null),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildSliderField(
        label: 'Height',
        value: element.style.height ?? 0,
        min: 0,
        max: 400,
        unit: 'px',
        allowZero: true,
        zeroLabel: 'Auto',
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(
            style: element.style.copyWith(height: value > 0 ? value : null),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildSliderField(
        label: 'Padding',
        value: element.style.padding ?? 0,
        min: 0,
        max: 48,
        unit: 'px',
        allowZero: true,
        zeroLabel: 'None',
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(
            style: element.style.copyWith(padding: value > 0 ? value : null),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildColorField(
        label: 'Text Color',
        value: element.style.textColor ?? '#FFFFFF',
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(style: element.style.copyWith(textColor: value)),
        ),
      ),
      const SizedBox(height: 12),
      _buildSliderField(
        label: 'Font Size',
        value: element.style.fontSize ?? 14,
        min: 8,
        max: 72,
        unit: 'sp',
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
        TextFormField(
          initialValue: value,
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

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required void Function(double) onChanged,
    String? unit,
    bool allowZero = false,
    String? zeroLabel,
  }) {
    final accentColor = context.accentColor;
    final displayValue = value.round();
    final isZero = displayValue == 0 && allowZero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isZero ? (zeroLabel ?? '0') : '$displayValue${unit ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isZero ? AppTheme.textSecondary : accentColor,
                  fontFamily: isZero ? null : 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentColor,
            inactiveTrackColor: AppTheme.darkBorder,
            thumbColor: accentColor,
            overlayColor: accentColor.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (newValue) => onChanged(newValue.roundToDouble()),
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

  Widget _buildIconSelectorField({
    required String label,
    required String value,
    required void Function(String) onChanged,
  }) {
    // Get the icon data for the current value
    final iconData = _getIconData(value);
    final accentColor = context.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final result = await IconSelector.show(
              context: context,
              selectedIcon: value,
            );
            if (result != null) {
              onChanged(result);
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Icon(iconData, size: 20, color: accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBindingSelectorField({
    required String label,
    required String value,
    required void Function(String?) onChanged,
  }) {
    // Find the binding definition for display
    final binding = value.isNotEmpty
        ? BindingRegistry.bindings.where((b) => b.path == value).firstOrNull
        : null;
    final accentColor = context.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final result = await BindingSelector.show(
              context: context,
              selectedPath: value,
            );
            if (result != null) {
              onChanged(result.isEmpty ? null : result);
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Icon(
                  binding != null ? Icons.link : Icons.link_off,
                  size: 18,
                  color: binding != null ? accentColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        binding?.label ?? '(none)',
                        style: TextStyle(
                          color: binding != null
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (binding != null)
                        Text(
                          binding.path,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    const iconMap = {
      'battery_full': Icons.battery_full,
      'battery_alert': Icons.battery_alert,
      'battery_charging_full': Icons.battery_charging_full,
      'bolt': Icons.bolt,
      'signal_cellular_alt': Icons.signal_cellular_alt,
      'wifi': Icons.wifi,
      'bluetooth': Icons.bluetooth,
      'gps_fixed': Icons.gps_fixed,
      'thermostat': Icons.thermostat,
      'water_drop': Icons.water_drop,
      'air': Icons.air,
      'cloud': Icons.cloud,
      'wb_sunny': Icons.wb_sunny,
      'hub': Icons.hub,
      'router': Icons.router,
      'devices': Icons.devices,
      'lan': Icons.lan,
      'message': Icons.message,
      'chat': Icons.chat,
      'send': Icons.send,
      'map': Icons.map,
      'navigation': Icons.navigation,
      'explore': Icons.explore,
      'near_me': Icons.near_me,
      'location_on': Icons.location_on,
      'route': Icons.route,
      'settings': Icons.settings,
      'info': Icons.info,
      'warning': Icons.warning,
      'error': Icons.error,
      'check_circle': Icons.check_circle,
      'speed': Icons.speed,
      'timeline': Icons.timeline,
      'trending_up': Icons.trending_up,
      'trending_down': Icons.trending_down,
      'show_chart': Icons.show_chart,
      'analytics': Icons.analytics,
      'favorite': Icons.favorite,
      'star': Icons.star,
      'bookmark': Icons.bookmark,
      'thumb_up': Icons.thumb_up,
      'flash_on': Icons.flash_on,
      'refresh': Icons.refresh,
      'edit': Icons.edit,
      'delete': Icons.delete,
      'add': Icons.add,
      'remove': Icons.remove,
      'notifications': Icons.notifications,
      'call': Icons.call,
      'compress': Icons.compress,
      'help_outline': Icons.help_outline,
    };
    return iconMap[iconName] ?? Icons.help_outline;
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
              child: TextFormField(
                initialValue: value,
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

  /// Get max allowed rows based on widget size
  int _getMaxRows() {
    switch (_schema.size) {
      case CustomWidgetSize.medium:
        return 1;
      case CustomWidgetSize.large:
        return 2;
      case CustomWidgetSize.custom:
        return 2; // Default to large behavior for custom
    }
  }

  /// Count the number of row elements at root level
  int _countRootRows() {
    return _schema.root.children.where((e) => e.type == ElementType.row).length;
  }

  /// Check if adding a row is allowed
  bool _canAddRow() {
    return _countRootRows() < _getMaxRows();
  }

  void _changeSize(CustomWidgetSize newSize) {
    // Check if downsizing from large to medium with too many rows
    if (newSize == CustomWidgetSize.medium) {
      final rowCount = _countRootRows();
      if (rowCount > 1) {
        showInfoSnackBar(
          context,
          'Remove extra rows first - medium allows only 1 row',
        );
        return;
      }
    }

    setState(() {
      _schema = _schema.copyWith(size: newSize);
    });
  }

  void _addElement(ElementType type) {
    // Check row limit for row elements
    if (type == ElementType.row && !_canAddRow()) {
      showInfoSnackBar(
        context,
        _schema.size == CustomWidgetSize.medium
            ? 'Medium widgets only allow 1 row'
            : 'Large widgets only allow 2 rows max',
      );
      return;
    }

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
      case ElementType.button:
        return ElementSchema(
          type: type,
          text: 'Tap me',
          iconName: 'touch_app',
          style: const StyleSchema(
            backgroundColor: '#4F6AF6',
            textColor: '#FFFFFF',
            borderRadius: 8,
            padding: 12,
          ),
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
      case ElementType.button:
        return 'Action Button';
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
}

class _ToolboxItem {
  final ElementType type;
  final String label;
  final IconData icon;

  const _ToolboxItem(this.type, this.label, this.icon);
}
