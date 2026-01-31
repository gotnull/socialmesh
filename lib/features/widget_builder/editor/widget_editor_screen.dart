// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../renderer/widget_renderer.dart';
import '../storage/widget_storage_service.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/glass_scaffold.dart';
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
  final bool _showPreview = false;
  bool _showToolbox = true;
  bool _isMarketplaceWidget = false;

  // Track if we're in portrait mode
  bool get _isPortrait =>
      MediaQuery.of(context).orientation == Orientation.portrait;
  bool get _isNarrow => MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    _schema = widget.initialSchema ?? _createDefaultSchema();
    _checkMarketplaceStatus();
  }

  Future<void> _checkMarketplaceStatus() async {
    if (widget.initialSchema != null) {
      final storage = WidgetStorageService();
      await storage.init();
      final isMarketplace = await storage.isMarketplaceWidget(_schema.id);
      if (mounted && isMarketplace) {
        setState(() => _isMarketplaceWidget = true);
      }
    }
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
    return GlassScaffold.body(
      titleWidget: GestureDetector(
        onTap: _editWidgetName,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AutoScrollText(
                _schema.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: context.textTertiary),
          ],
        ),
      ),
      actions: [
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
      body: SafeArea(
        top: false,
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
    return GlassScaffold.body(
      titleWidget: AutoScrollText(
        _schema.name,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      actions: [
        // Toggle toolbox
        IconButton(
          icon: Icon(
            _showToolbox ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            color: _showToolbox ? context.accentColor : context.textPrimary,
          ),
          onPressed: () => setState(() => _showToolbox = !_showToolbox),
          tooltip: 'Toggle Toolbox',
        ),
        SizedBox(width: 8),
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
      body: SafeArea(
        top: false,
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

  Widget _buildCompactInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(bottom: BorderSide(color: context.border)),
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
    // Render widget at ACTUAL size it will appear in marketplace/dashboard
    // Full width with height based on size setting
    final previewHeight = _getPreviewHeight();

    return Container(
      color: context.background,
      child: Column(
        children: [
          // Centered widget preview at actual render size
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DragTarget<ElementType>(
                  onAcceptWithDetails: (details) => _addElement(details.data),
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;

                    return Container(
                      // Full width like marketplace cards
                      width: double.infinity,
                      height: previewHeight,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isHovering
                              ? context.accentColor
                              : Colors.transparent,
                          width: isHovering ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
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

  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        border: Border(top: BorderSide(color: context.border)),
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
                  icon: Icon(Icons.add, size: 20),
                  label: const Text('Add Element'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_selectedElementId != null) ...[
                SizedBox(width: 8),
                // Edit selected element
                OutlinedButton.icon(
                  onPressed: _showPropertySheet,
                  icon: const Icon(Icons.tune, size: 20),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Delete selected element
                IconButton(
                  onPressed: () => _deleteElement(_selectedElementId!),
                  icon: Icon(Icons.delete_outline, color: AppTheme.errorRed),
                  style: IconButton.styleFrom(
                    backgroundColor: context.background,
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
      backgroundColor: context.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
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
                  color: context.border,
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
                    Icons.add_box_outlined,
                    size: 20,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Block',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Simplified block grid
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildBlockPickerSection('Display Blocks', [
                    _BlockItem(
                      'info',
                      'Info Block',
                      Icons.info_outline,
                      'Icon + Label + Data Value',
                    ),
                    _BlockItem(
                      'metric',
                      'Metric',
                      Icons.trending_up,
                      'Large value with label',
                    ),
                    _BlockItem(
                      'status',
                      'Status',
                      Icons.circle,
                      'Status indicator with binding',
                    ),
                  ]),
                  _buildBlockPickerSection('Action Blocks', [
                    _BlockItem(
                      'action_button',
                      'Action Button',
                      Icons.touch_app,
                      'Tappable button with action',
                    ),
                  ]),
                  _buildBlockPickerSection('Layout', [
                    _BlockItem(
                      'row',
                      'New Row',
                      Icons.view_column,
                      'Add a row for more blocks',
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

  Widget _buildBlockPickerSection(String title, List<_BlockItem> items) {
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
              color: context.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items.map((item) => _buildBlockPickerCard(item)),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Show dialog to add a child element to a layout container
  void _showAddChildDialog(ElementSchema parent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'What would you like to add?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Simple, clear options with visual previews
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSimpleAddOption(
                    ctx,
                    parent,
                    ElementType.text,
                    'Text',
                    'Add a label or value',
                    Icons.text_fields,
                  ),
                  _buildSimpleAddOption(
                    ctx,
                    parent,
                    ElementType.icon,
                    'Icon',
                    'Add a symbol or emoji',
                    Icons.emoji_emotions_outlined,
                  ),
                  _buildSimpleAddOption(
                    ctx,
                    parent,
                    ElementType.gauge,
                    'Progress Bar',
                    'Show a value visually',
                    Icons.linear_scale,
                  ),
                  _buildSimpleAddOption(
                    ctx,
                    parent,
                    ElementType.spacer,
                    'Space',
                    'Add empty space between items',
                    Icons.expand,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleAddOption(
    BuildContext ctx,
    ElementSchema parent,
    ElementType type,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(ctx);
            _addChildToElement(parent, type);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: context.accentColor),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_outline,
                  color: context.accentColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addChildToElement(ElementSchema parent, ElementType type) {
    final newElement = _createDefaultElement(type);
    final updatedParent = parent.copyWith(
      children: [...parent.children, newElement],
    );
    setState(() {
      _schema = _schema.copyWith(
        root: _updateElementInTree(_schema.root, parent.id, updatedParent),
      );
      _selectedElementId = newElement.id;
    });
    // Refresh property sheet if open
    _sheetSetState?.call(() {});
  }

  Widget _buildBlockPickerCard(_BlockItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            _addBlock(item.type);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 22, color: context.accentColor),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addBlock(String blockType) {
    final newBlock = _createBlock(blockType);
    if (newBlock == null) return;

    // Find or create a row to add the block to
    if (_schema.root.type == ElementType.row) {
      // Root is already a row, add directly
      final updatedRoot = _schema.root.copyWith(
        children: [..._schema.root.children, newBlock],
      );
      setState(() => _schema = _schema.copyWith(root: updatedRoot));
    } else if (_schema.root.type == ElementType.column) {
      // Root is a column, find the last row or create one
      final children = _schema.root.children;
      if (children.isNotEmpty && children.last.type == ElementType.row) {
        // Add to existing last row
        final lastRow = children.last;
        final updatedRow = lastRow.copyWith(
          children: [...lastRow.children, newBlock],
        );
        final updatedChildren = [...children];
        updatedChildren[updatedChildren.length - 1] = updatedRow;
        setState(
          () => _schema = _schema.copyWith(
            root: _schema.root.copyWith(children: updatedChildren),
          ),
        );
      } else {
        // Create a new row with the block
        final newRow = ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(spacing: 8, expanded: true),
          children: [newBlock],
        );
        setState(
          () => _schema = _schema.copyWith(
            root: _schema.root.copyWith(children: [...children, newRow]),
          ),
        );
      }
    } else {
      // Root is container or something else, wrap in row
      final newRow = ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(spacing: 8, expanded: true),
        children: [newBlock],
      );
      setState(
        () => _schema = _schema.copyWith(
          root: ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(padding: 12, spacing: 8),
            children: [newRow],
          ),
        ),
      );
    }
  }

  ElementSchema? _createBlock(String blockType) {
    switch (blockType) {
      case 'info':
        return ElementSchema(
          type: ElementType.container,
          style: const StyleSchema(
            flex: 1,
            expanded: true,
            padding: 8,
            borderRadius: 12,
            backgroundColor: 'accent:0.08',
            borderColor: 'accent:0.2',
            borderWidth: 1,
            mainAxisAlignment: MainAxisAlignmentOption.center,
            crossAxisAlignment: CrossAxisAlignmentOption.center,
          ),
          children: [
            ElementSchema(
              type: ElementType.icon,
              iconName: 'info',
              iconSize: 22,
              style: const StyleSchema(textColor: 'accent'),
            ),
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 4),
            ),
            ElementSchema(
              type: ElementType.text,
              text: 'Label',
              style: const StyleSchema(
                textColor: 'accent',
                fontSize: 9,
                fontWeight: 'w600',
                textAlign: TextAlignOption.center,
              ),
            ),
          ],
        );

      case 'metric':
        return ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(flex: 1, alignment: AlignmentOption.center),
          children: [
            ElementSchema(
              type: ElementType.icon,
              iconName: 'trending_up',
              iconSize: 24,
              style: const StyleSchema(textColor: 'accent'),
            ),
            ElementSchema(
              type: ElementType.text,
              text: '--',
              binding: const BindingSchema(path: '', defaultValue: '--'),
              style: const StyleSchema(
                fontSize: 16,
                fontWeight: 'w600',
                textColor: '#FFFFFF',
              ),
            ),
            ElementSchema(
              type: ElementType.text,
              text: 'Value',
              style: const StyleSchema(fontSize: 10, textColor: '#888888'),
            ),
          ],
        );

      case 'status':
        return ElementSchema(
          type: ElementType.container,
          style: const StyleSchema(
            flex: 1,
            expanded: true,
            padding: 8,
            borderRadius: 12,
            backgroundColor: 'accent:0.08',
            borderColor: 'accent:0.2',
            borderWidth: 1,
            mainAxisAlignment: MainAxisAlignmentOption.center,
            crossAxisAlignment: CrossAxisAlignmentOption.center,
          ),
          children: [
            ElementSchema(
              type: ElementType.icon,
              iconName: 'circle',
              iconSize: 12,
              style: const StyleSchema(textColor: 'accent'),
            ),
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 4),
            ),
            ElementSchema(
              type: ElementType.text,
              text: 'Status',
              style: const StyleSchema(textColor: '#AAAAAA', fontSize: 11),
            ),
          ],
        );

      case 'action_button':
        return ElementSchema(
          type: ElementType.container,
          style: const StyleSchema(
            flex: 1,
            expanded: true,
            padding: 8,
            borderRadius: 12,
            backgroundColor: 'accent:0.08',
            borderColor: 'accent:0.2',
            borderWidth: 1,
            mainAxisAlignment: MainAxisAlignmentOption.center,
            crossAxisAlignment: CrossAxisAlignmentOption.center,
          ),
          action: const ActionSchema(type: ActionType.none),
          children: [
            ElementSchema(
              type: ElementType.icon,
              iconName: 'touch_app',
              iconSize: 22,
              style: const StyleSchema(textColor: 'accent'),
            ),
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 4),
            ),
            ElementSchema(
              type: ElementType.text,
              text: 'Action',
              style: const StyleSchema(
                textColor: 'accent',
                fontSize: 9,
                fontWeight: 'w600',
                textAlign: TextAlignOption.center,
              ),
            ),
          ],
        );

      case 'row':
        // Check if we can add a row
        if (!_canAddRow()) {
          showInfoSnackBar(
            context,
            _schema.size == CustomWidgetSize.medium
                ? 'Medium widgets only allow 1 row'
                : 'Large widgets allow max 2 rows',
          );
          return null;
        }
        // Create a new empty row
        setState(
          () => _schema = _schema.copyWith(
            root: _schema.root.type == ElementType.column
                ? _schema.root.copyWith(
                    children: [
                      ..._schema.root.children,
                      ElementSchema(
                        type: ElementType.row,
                        style: const StyleSchema(spacing: 8, expanded: true),
                        children: [],
                      ),
                    ],
                  )
                : ElementSchema(
                    type: ElementType.column,
                    style: const StyleSchema(padding: 12, spacing: 8),
                    children: [
                      _schema.root,
                      ElementSchema(
                        type: ElementType.row,
                        style: const StyleSchema(spacing: 8, expanded: true),
                        children: [],
                      ),
                    ],
                  ),
          ),
        );
        return null; // Row is added directly, no block to return

      default:
        return null;
    }
  }

  // Callback to refresh the property sheet when element changes
  void Function(void Function())? _sheetSetState;

  void _showPropertySheet() {
    if (_selectedElementId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        // Calculate safe area and keyboard height
        final mediaQuery = MediaQuery.of(context);
        final bottomPadding = mediaQuery.viewInsets.bottom;
        final screenHeight = mediaQuery.size.height;
        final availableHeight = screenHeight - mediaQuery.padding.top - 40;
        final maxSheetHeight = availableHeight / screenHeight;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: maxSheetHeight.clamp(0.85, 0.95),
            expand: false,
            builder: (context, scrollController) => StatefulBuilder(
              builder: (context, setSheetState) {
                // Store the sheet's setState so we can call it from _updateElement
                _sheetSetState = setSheetState;

                // Get fresh element data each rebuild
                final element = _findElementById(
                  _schema.root,
                  _selectedElementId!,
                );
                if (element == null) {
                  return const Center(child: Text('Element not found'));
                }

                return Column(
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
                                color: context.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          // Full widget preview - EXACT same size as canvas
                          SizedBox(
                            height: _getPreviewHeight(),
                            width: double.infinity,
                            child: WidgetRenderer(
                              schema: _schema,
                              accentColor: context.accentColor,
                              usePlaceholderData: true,
                              isPreview: false,
                              enableActions: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    // Breadcrumb path showing where in hierarchy
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildElementBreadcrumb(element),
                    ),
                    const SizedBox(height: 8),
                    // Title row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune,
                            size: 18,
                            color: context.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getElementTypeName(element.type),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
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
                    Divider(height: 1, color: context.border),
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
                          // Only show binding for bindable elements (text, gauge, chart)
                          if (_shouldShowBinding(element)) ...[
                            const SizedBox(height: 16),
                            _buildPropertySection(
                              'Data Binding',
                              _buildBindingProperties(element),
                            ),
                          ],
                          // Only show actions for actionable elements (container, button)
                          if (_isActionableElement(element.type)) ...[
                            const SizedBox(height: 16),
                            _buildPropertySection(
                              'Action',
                              _buildActionProperties(element),
                            ),
                          ],
                          // Only show style for styleable elements
                          if (_isStyleableElement(element.type)) ...[
                            const SizedBox(height: 16),
                            _buildPropertySection(
                              'Style',
                              _buildStyleProperties(element),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Clear the callback when sheet is dismissed
      _sheetSetState = null;
    });
  }

  Widget _buildToolbox() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: context.card,
        border: Border(right: BorderSide(color: context.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.widgets_outlined,
                  size: 18,
                  color: context.textPrimary,
                ),
                SizedBox(width: 8),
                Text(
                  'Elements',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
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
              color: context.textTertiary,
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
              color: context.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: context.textSecondary),
                SizedBox(width: 8),
                Text(
                  item.label,
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    // Render widget at ACTUAL size it will appear in marketplace/dashboard
    final previewHeight = _getPreviewHeight();

    return Container(
      color: context.background,
      child: Column(
        children: [
          // Widget info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(bottom: BorderSide(color: context.border)),
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit, size: 14, color: context.textTertiary),
                      ],
                    ),
                  ),
                ),
                // Size selector (hidden for marketplace widgets)
                if (!_isMarketplaceWidget) _buildSizeSelector(),
              ],
            ),
          ),
          // Canvas area - render at actual marketplace size
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: DragTarget<ElementType>(
                  onAcceptWithDetails: (details) => _addElement(details.data),
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    // Use a reasonable max width for landscape (typical card width)
                    final maxWidth =
                        MediaQuery.of(context).size.width * 0.5 - 64;
                    return Container(
                      width: maxWidth.clamp(280.0, 400.0),
                      height: previewHeight,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isHovering
                              ? context.accentColor
                              : Colors.transparent,
                          width: isHovering ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
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
              : context.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? context.accentColor : context.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? context.accentColor : context.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Returns the ACTUAL height at which widgets render in marketplace/dashboard
  /// This MUST match the heights used in:
  /// - widget_marketplace_screen.dart (_MarketplaceWidgetCard)
  /// - widget_builder_screen.dart (_buildWidgetCard)
  /// - dashboard_screen.dart
  double _getPreviewHeight() {
    if (_schema.customHeight != null) {
      return _schema.customHeight!;
    }
    switch (_schema.size) {
      case CustomWidgetSize.medium:
        return 120.0; // Matches marketplace preview height
      case CustomWidgetSize.large:
        return 180.0; // Matches marketplace preview height
      case CustomWidgetSize.custom:
        return _schema.customHeight ?? 120.0;
    }
  }

  Widget _buildEditableContent() {
    return WidgetRenderer(
      schema: _schema,
      accentColor: context.accentColor,
      isPreview: true,
      usePlaceholderData: true,
      enableActions: false, // Only interactive on dashboard
      selectedElementId: _selectedElementId,
      onElementTap: (id) => setState(() => _selectedElementId = id),
    );
  }

  Widget _buildPreviewContent() {
    return WidgetRenderer(
      schema: _schema,
      accentColor: context.accentColor,
      usePlaceholderData: true,
      enableActions: false, // Only interactive on dashboard
    );
  }

  Widget _buildPropertyInspector() {
    final element = _findElementById(_schema.root, _selectedElementId!);
    if (element == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: context.card,
        border: Border(left: BorderSide(color: context.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: context.textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getElementTypeName(element.type),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
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
                if (_shouldShowBinding(element)) ...[
                  const SizedBox(height: 16),
                  _buildPropertySection(
                    'Data Binding',
                    _buildBindingProperties(element),
                  ),
                ],
                if (_isActionableElement(element.type)) ...[
                  const SizedBox(height: 16),
                  _buildPropertySection(
                    'Action',
                    _buildActionProperties(element),
                  ),
                ],
                if (_isStyleableElement(element.type)) ...[
                  const SizedBox(height: 16),
                  _buildPropertySection(
                    'Style',
                    _buildStyleProperties(element),
                  ),
                ],
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
            color: context.textTertiary,
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
        // Only show text field if NOT bound - binding takes precedence
        if (element.binding == null || element.binding!.path.isEmpty) {
          properties.add(
            _buildTextField(
              label: 'Text',
              value: element.text ?? '',
              onChanged: (value) =>
                  _updateElement(element.id, element.copyWith(text: value)),
            ),
          );
        }
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

      case ElementType.row:
      case ElementType.column:
      case ElementType.container:
        // Human-friendly layout options
        final isRow = element.type == ElementType.row;

        // For rows: horizontal alignment (left/center/right/spread)
        // For columns: vertical alignment (top/middle/bottom/spread)
        properties.add(
          _buildAlignmentSelector(
            label: isRow ? 'Horizontal' : 'Vertical',
            value:
                element.style.mainAxisAlignment ??
                MainAxisAlignmentOption.start,
            isHorizontal: isRow,
            onChanged: (value) => _updateElement(
              element.id,
              element.copyWith(
                style: element.style.copyWith(mainAxisAlignment: value),
              ),
            ),
          ),
        );
        properties.add(const SizedBox(height: 12));
        // For rows: vertical alignment (top/middle/bottom)
        // For columns: horizontal alignment (left/center/right)
        properties.add(
          _buildCrossAlignmentSelector(
            label: isRow ? 'Vertical' : 'Horizontal',
            value:
                element.style.crossAxisAlignment ??
                CrossAxisAlignmentOption.start,
            isHorizontal: !isRow,
            onChanged: (value) => _updateElement(
              element.id,
              element.copyWith(
                style: element.style.copyWith(crossAxisAlignment: value),
              ),
            ),
          ),
        );
        if (element.type == ElementType.row ||
            element.type == ElementType.column) {
          properties.add(const SizedBox(height: 12));
          properties.add(
            _buildSliderField(
              label: 'Gap between items',
              value: element.style.spacing ?? 0,
              min: 0,
              max: 32,
              onChanged: (value) => _updateElement(
                element.id,
                element.copyWith(style: element.style.copyWith(spacing: value)),
              ),
            ),
          );
        }
        // Children count with Add button
        properties.add(const SizedBox(height: 16));
        properties.add(
          FilledButton.icon(
            onPressed: () => _showAddChildDialog(element),
            icon: Icon(Icons.add, size: 18),
            label: Text('Add item (${element.children.length} items)'),
            style: FilledButton.styleFrom(
              backgroundColor: context.accentColor,
              minimumSize: const Size(double.infinity, 44),
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
    ];
  }

  List<Widget> _buildActionProperties(ElementSchema element) {
    final actionLabels = {
      ActionType.none: 'No Action',
      ActionType.sendMessage: 'Send Message',
      ActionType.shareLocation: 'Share Location',
      ActionType.traceroute: 'Traceroute',
      ActionType.requestPositions: 'Request Positions',
      ActionType.sos: 'Emergency SOS',
      ActionType.navigate: 'Navigate',
      ActionType.openUrl: 'Open URL',
      ActionType.copyToClipboard: 'Copy to Clipboard',
    };

    return [
      _buildDropdownField(
        label: 'Add Action',
        value: (element.action?.type ?? ActionType.none).name,
        options: ActionType.values.map((e) => e.name).toList(),
        displayLabels: actionLabels.values.toList(),
        onChanged: (value) {
          final actionType = ActionType.values.firstWhere(
            (e) => e.name == value,
            orElse: () => ActionType.none,
          );
          if (actionType == ActionType.none) {
            _updateElement(
              element.id,
              ElementSchema(
                id: element.id,
                type: element.type,
                style: element.style,
                binding: element.binding,
                condition: element.condition,
                action: null,
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
              element.copyWith(
                action: ActionSchema(
                  type: actionType,
                  label: actionLabels[actionType],
                ),
              ),
            );
          }
        },
      ),
      if (element.action != null &&
          element.action!.type == ActionType.openUrl) ...[
        const SizedBox(height: 8),
        _buildTextField(
          label: 'URL',
          value: element.action?.url ?? '',
          onChanged: (value) => _updateElement(
            element.id,
            element.copyWith(
              action: ActionSchema(
                type: element.action!.type,
                url: value,
                label: element.action?.label,
              ),
            ),
          ),
        ),
      ],
      if (element.action != null &&
          element.action!.type == ActionType.navigate) ...[
        const SizedBox(height: 8),
        _buildTextField(
          label: 'Screen',
          value: element.action?.navigateTo ?? '',
          onChanged: (value) => _updateElement(
            element.id,
            element.copyWith(
              action: ActionSchema(
                type: element.action!.type,
                navigateTo: value,
                label: element.action?.label,
              ),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildStyleProperties(ElementSchema element) {
    // Simplified style properties - only icon color picker using theme colors
    final hasIcon =
        element.type == ElementType.icon ||
        element.iconName != null ||
        element.type == ElementType.container;

    if (!hasIcon) {
      return []; // No style options for text-only elements
    }

    return [
      _buildThemeColorPicker(
        label: 'Icon Color',
        value: element.style.textColor,
        onChanged: (value) => _updateElement(
          element.id,
          element.copyWith(style: element.style.copyWith(textColor: value)),
        ),
      ),
    ];
  }

  Widget _buildThemeColorPicker({
    required String label,
    required String? value,
    required void Function(String) onChanged,
  }) {
    // Parse current color to find matching theme color
    Color? currentColor;
    if (value != null) {
      if (value == 'accent') {
        currentColor = context.accentColor;
      } else if (value.startsWith('#')) {
        final hex = value.replaceFirst('#', '');
        if (hex.length == 6) {
          currentColor = Color(int.parse('FF$hex', radix: 16));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Accent color option (inherits from app settings)
            _buildColorOption(
              color: context.accentColor,
              label: 'Accent',
              isSelected: value == 'accent',
              onTap: () => onChanged('accent'),
            ),
            // Theme colors
            ...AccentColors.all.asMap().entries.map((entry) {
              final color = entry.value;
              final name = AccentColors.names[entry.key];
              final hexValue =
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              final isSelected =
                  currentColor != null &&
                  (currentColor.toARGB32() & 0xFFFFFF) ==
                      (color.toARGB32() & 0xFFFFFF);
              return _buildColorOption(
                color: color,
                label: name,
                isSelected: isSelected && value != 'accent',
                onTap: () => onChanged(hexValue),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildColorOption({
    required Color color,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isSelected ? Colors.white : context.textTertiary,
            ),
          ),
        ],
      ),
    );
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
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          style: TextStyle(color: context.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: context.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: context.border),
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
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isZero ? (zeroLabel ?? '0') : '$displayValue${unit ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isZero ? context.textSecondary : accentColor,
                  fontFamily: isZero ? null : AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentColor,
            inactiveTrackColor: context.border,
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

  /// Visual alignment selector with icon buttons (human-friendly)
  Widget _buildAlignmentSelector({
    required String label,
    required MainAxisAlignmentOption value,
    required bool isHorizontal,
    required void Function(MainAxisAlignmentOption) onChanged,
  }) {
    // Human-friendly labels with icons
    final options = [
      (
        MainAxisAlignmentOption.start,
        isHorizontal ? 'Left' : 'Top',
        isHorizontal ? Icons.align_horizontal_left : Icons.align_vertical_top,
      ),
      (
        MainAxisAlignmentOption.center,
        'Center',
        isHorizontal
            ? Icons.align_horizontal_center
            : Icons.align_vertical_center,
      ),
      (
        MainAxisAlignmentOption.end,
        isHorizontal ? 'Right' : 'Bottom',
        isHorizontal
            ? Icons.align_horizontal_right
            : Icons.align_vertical_bottom,
      ),
      (
        MainAxisAlignmentOption.spaceBetween,
        'Spread',
        isHorizontal ? Icons.horizontal_distribute : Icons.vertical_distribute,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = value == opt.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: opt != options.last ? 6 : 0),
                child: _buildAlignButton(
                  icon: opt.$3,
                  label: opt.$2,
                  isSelected: isSelected,
                  onTap: () => onChanged(opt.$1),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCrossAlignmentSelector({
    required String label,
    required CrossAxisAlignmentOption value,
    required bool isHorizontal,
    required void Function(CrossAxisAlignmentOption) onChanged,
  }) {
    final options = [
      (
        CrossAxisAlignmentOption.start,
        isHorizontal ? 'Left' : 'Top',
        isHorizontal ? Icons.align_horizontal_left : Icons.align_vertical_top,
      ),
      (
        CrossAxisAlignmentOption.center,
        'Center',
        isHorizontal
            ? Icons.align_horizontal_center
            : Icons.align_vertical_center,
      ),
      (
        CrossAxisAlignmentOption.end,
        isHorizontal ? 'Right' : 'Bottom',
        isHorizontal
            ? Icons.align_horizontal_right
            : Icons.align_vertical_bottom,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = value == opt.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: opt != options.last ? 6 : 0),
                child: _buildAlignButton(
                  icon: opt.$3,
                  label: opt.$2,
                  isSelected: isSelected,
                  onTap: () => onChanged(opt.$1),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAlignButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final accentColor = context.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : context.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : context.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accentColor : context.textSecondary,
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? accentColor : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String) onChanged,
    List<String>? displayLabels,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.border),
          ),
          child: DropdownButton<String>(
            value: options.contains(value) ? value : options.first,
            isExpanded: true,
            isDense: true,
            dropdownColor: context.card,
            underline: const SizedBox.shrink(),
            style: TextStyle(color: context.textPrimary, fontSize: 13),
            items: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final displayText =
                  displayLabels != null && index < displayLabels.length
                  ? displayLabels[index]
                  : (option.isEmpty ? '(none)' : option);
              return DropdownMenuItem(
                value: option,
                child: Text(displayText, overflow: TextOverflow.ellipsis),
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
          style: TextStyle(fontSize: 12, color: context.textSecondary),
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
              color: context.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Icon(iconData, size: 20, color: accentColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(color: context.textPrimary, fontSize: 13),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: context.textSecondary,
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
    final hasBinding = value.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
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
              color: context.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Icon(
                  hasBinding ? Icons.link : Icons.link_off,
                  size: 18,
                  color: hasBinding ? accentColor : context.textSecondary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        binding?.label ?? (hasBinding ? value : '(none)'),
                        style: TextStyle(
                          color: hasBinding
                              ? Colors.white
                              : context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (hasBinding)
                        Text(
                          value,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 10,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: context.textSecondary,
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

    // If a layout element is selected, add as child of that element
    // Otherwise add to root
    if (_selectedElementId != null) {
      final selectedElement = _findElementById(
        _schema.root,
        _selectedElementId!,
      );
      if (selectedElement != null && _isLayoutElement(selectedElement.type)) {
        // Add to selected container
        final updatedSelected = selectedElement.copyWith(
          children: [...selectedElement.children, newElement],
        );
        setState(() {
          _schema = _schema.copyWith(
            root: _updateElementInTree(
              _schema.root,
              selectedElement.id,
              updatedSelected,
            ),
          );
          _selectedElementId = newElement.id;
        });
        return;
      }
    }

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
            bindingPath: 'node.presenceConfidence',
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
    // Also update the property sheet if it's open
    _sheetSetState?.call(() {});
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

  /// Get path to element as list of (id, type) pairs
  List<(String, ElementType)> _getElementPath(String targetId) {
    final path = <(String, ElementType)>[];
    _findPath(_schema.root, targetId, path);
    return path;
  }

  bool _findPath(
    ElementSchema current,
    String targetId,
    List<(String, ElementType)> path,
  ) {
    path.add((current.id, current.type));
    if (current.id == targetId) return true;

    for (final child in current.children) {
      if (_findPath(child, targetId, path)) return true;
    }

    path.removeLast();
    return false;
  }

  /// Build breadcrumb widget showing path to current element
  Widget _buildElementBreadcrumb(ElementSchema element) {
    final path = _getElementPath(element.id);
    if (path.length <= 1) {
      return const SizedBox.shrink(); // Root element, no breadcrumb needed
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < path.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: context.textTertiary,
                ),
              ),
            GestureDetector(
              onTap: i < path.length - 1
                  ? () {
                      setState(() => _selectedElementId = path[i].$1);
                      _sheetSetState?.call(() {});
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: i == path.length - 1
                      ? context.accentColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getElementTypeName(path[i].$2),
                  style: TextStyle(
                    fontSize: 11,
                    color: i == path.length - 1
                        ? context.accentColor
                        : context.textSecondary,
                    fontWeight: i == path.length - 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Check if element should show binding option
  /// Text shows binding only if it doesn't have static text OR already has a binding
  bool _shouldShowBinding(ElementSchema element) {
    if (element.type == ElementType.gauge ||
        element.type == ElementType.chart) {
      return true;
    }
    if (element.type == ElementType.text) {
      // Show binding if already has one, or if text is empty
      final hasBinding =
          element.binding != null && element.binding!.path.isNotEmpty;
      final hasStaticText = element.text != null && element.text!.isNotEmpty;
      return hasBinding || !hasStaticText;
    }
    return false;
  }

  /// Elements that can have tap actions
  bool _isActionableElement(ElementType type) {
    return const {ElementType.container, ElementType.button}.contains(type);
  }

  /// Elements that have editable styles (icon color)
  bool _isStyleableElement(ElementType type) {
    return const {ElementType.icon, ElementType.container}.contains(type);
  }

  /// Elements that can contain children (layout containers)
  bool _isLayoutElement(ElementType type) {
    return const {
      ElementType.container,
      ElementType.row,
      ElementType.column,
      ElementType.stack,
    }.contains(type);
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
        return 'Show/Hide';
      case ElementType.container:
        return 'Group';
      case ElementType.row:
        return 'Horizontal Stack';
      case ElementType.column:
        return 'Vertical Stack';
      case ElementType.spacer:
        return 'Space';
      case ElementType.stack:
        return 'Layer Stack';
      case ElementType.button:
        return 'Button';
    }
  }

  void _editWidgetName() async {
    final controller = TextEditingController(text: _schema.name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Widget Name',
          style: TextStyle(color: context.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter widget name',
            hintStyle: TextStyle(color: context.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
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

class _BlockItem {
  final String type;
  final String label;
  final IconData icon;
  final String description;

  const _BlockItem(this.type, this.label, this.icon, this.description);
}
