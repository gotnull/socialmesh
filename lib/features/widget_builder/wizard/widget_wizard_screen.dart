import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../renderer/widget_renderer.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';

/// Result of the widget wizard
class WidgetWizardResult {
  final WidgetSchema schema;
  final bool addToDashboard;

  const WidgetWizardResult({required this.schema, this.addToDashboard = false});
}

/// Widget creation wizard - guides users through building a widget step-by-step
class WidgetWizardScreen extends ConsumerStatefulWidget {
  final Future<void> Function(WidgetSchema schema) onSave;
  final WidgetSchema? initialSchema;

  const WidgetWizardScreen({
    super.key,
    required this.onSave,
    this.initialSchema,
  });

  @override
  ConsumerState<WidgetWizardScreen> createState() => _WidgetWizardScreenState();
}

class _WidgetWizardScreenState extends ConsumerState<WidgetWizardScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Existing schema ID for edits
  String? _existingId;

  // Step 1: Template selection
  _WidgetTemplate? _selectedTemplate;

  // Step 2: Name
  final _nameController = TextEditingController();

  // Step 3: Data selection (or Actions for Quick Actions template)
  final Set<String> _selectedBindings = {};
  final Set<ActionType> _selectedActions = {};

  // Step 4: Appearance
  Color _accentColor = const Color(0xFF4F6AF6);
  bool _showLabels = true;
  bool _addToDashboard = true;
  _LayoutStyle _layoutStyle = _LayoutStyle.vertical;

  List<_WizardStep> get _steps {
    final isQuickActions = _selectedTemplate?.id == 'actions';
    return [
      const _WizardStep(
        title: 'Choose a Style',
        subtitle: 'How do you want your widget to look?',
        icon: Icons.style,
      ),
      const _WizardStep(
        title: 'Name Your Widget',
        subtitle: 'Give it a memorable name',
        icon: Icons.text_fields,
      ),
      _WizardStep(
        title: isQuickActions ? 'Choose Actions' : 'Pick Your Data',
        subtitle: isQuickActions
            ? 'Which actions do you want quick access to?'
            : 'What info do you want to see?',
        icon: isQuickActions ? Icons.touch_app : Icons.data_usage,
      ),
      const _WizardStep(
        title: 'Make it Yours',
        subtitle: 'Customize colors and layout',
        icon: Icons.palette,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _initFromSchema();
  }

  void _initFromSchema() {
    final schema = widget.initialSchema;
    if (schema == null) return;

    _existingId = schema.id;
    _nameController.text = schema.name;

    // Try to detect template from tags
    final tags = schema.tags;
    if (tags.contains('status')) {
      _selectedTemplate = _getTemplates().firstWhere((t) => t.id == 'status');
    } else if (tags.contains('info')) {
      _selectedTemplate = _getTemplates().firstWhere((t) => t.id == 'info');
    } else if (tags.contains('gauge')) {
      _selectedTemplate = _getTemplates().firstWhere((t) => t.id == 'gauge');
    } else if (tags.contains('actions')) {
      _selectedTemplate = _getTemplates().firstWhere((t) => t.id == 'actions');
    } else if (tags.contains('location')) {
      _selectedTemplate = _getTemplates().firstWhere((t) => t.id == 'location');
    } else if (tags.contains('environment')) {
      _selectedTemplate = _getTemplates().firstWhere(
        (t) => t.id == 'environment',
      );
    }

    // Extract bindings from schema
    _extractBindingsFromElement(schema.root);

    // Extract actions from schema
    _extractActionsFromElement(schema.root);
  }

  void _extractBindingsFromElement(ElementSchema element) {
    if (element.binding != null) {
      _selectedBindings.add(element.binding!.path);
    }
    for (final child in element.children) {
      _extractBindingsFromElement(child);
    }
  }

  void _extractActionsFromElement(ElementSchema element) {
    if (element.action != null && element.action!.type != ActionType.none) {
      _selectedActions.add(element.action!.type);
    }
    for (final child in element.children) {
      _extractActionsFromElement(child);
    }
  }

  /// Check if there are unsaved changes
  bool _hasUnsavedChanges() {
    // If on first step with no template selected, no changes
    if (_currentStep == 0 && _selectedTemplate == null) {
      return false;
    }
    // If template is selected or we've progressed, there are changes
    return _selectedTemplate != null ||
        _nameController.text.isNotEmpty ||
        _selectedBindings.isNotEmpty ||
        _selectedActions.isNotEmpty;
  }

  /// Handle close button with confirmation if needed
  Future<void> _handleClose() async {
    debugPrint('[WidgetWizard] _handleClose called');
    debugPrint('[WidgetWizard] hasUnsavedChanges: ${_hasUnsavedChanges()}');

    if (!_hasUnsavedChanges()) {
      debugPrint('[WidgetWizard] No unsaved changes, closing immediately');
      Navigator.pop(context);
      return;
    }

    // Show confirmation dialog
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'You have unsaved changes. Are you sure you want to close without saving?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    debugPrint('[WidgetWizard] Dialog result: $shouldClose');

    if (shouldClose == true && mounted) {
      debugPrint('[WidgetWizard] User confirmed close, popping');
      Navigator.pop(context);
    }
  }

  /// Check if switching to a new template would lose user data
  bool _wouldLoseDataOnTemplateSwitch(_WidgetTemplate newTemplate) {
    final isCurrentActions = _selectedTemplate?.id == 'actions';
    final isNewActions = newTemplate.id == 'actions';

    // If switching between same type, no data loss
    if (isCurrentActions == isNewActions) return false;

    // If switching from Actions to Data template, check if actions exist
    if (isCurrentActions && !isNewActions) {
      return _selectedActions.isNotEmpty;
    }

    // If switching from Data to Actions template, check if bindings exist
    if (!isCurrentActions && isNewActions) {
      return _selectedBindings.isNotEmpty;
    }

    return false;
  }

  /// Handle template selection with compatibility check
  Future<void> _handleTemplateSelection(_WidgetTemplate template) async {
    // If same template, just select it
    if (_selectedTemplate?.id == template.id) return;

    // Check if we would lose data
    if (_wouldLoseDataOnTemplateSwitch(template)) {
      final isCurrentActions = _selectedTemplate?.id == 'actions';
      final currentDataType = isCurrentActions ? 'actions' : 'data bindings';
      final newDataType = template.id == 'actions'
          ? 'actions'
          : 'data bindings';
      final itemCount = isCurrentActions
          ? _selectedActions.length
          : _selectedBindings.length;

      final shouldSwitch = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.warningYellow),
              const SizedBox(width: 12),
              const Text(
                'Switch Template?',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have $itemCount $currentDataType selected.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                '"${template.name}" uses $newDataType instead, so your current selections won\'t be used.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                'What would you like to do?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Current Template'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Switch Template'),
            ),
          ],
        ),
      );

      if (shouldSwitch != true) return;

      // User confirmed - clear the old data type
      setState(() {
        if (template.id == 'actions') {
          _selectedBindings.clear();
        } else {
          _selectedActions.clear();
        }
        _selectedTemplate = template;
      });
    } else {
      // No data loss, just switch
      setState(() => _selectedTemplate = template);
    }
  }

  /// Get validation error for current state, or null if valid
  String? _getValidationError() {
    // Check if data matches template type
    if (_selectedTemplate?.id == 'actions') {
      // Quick Actions template should have actions, not bindings
      if (_selectedBindings.isNotEmpty && _selectedActions.isEmpty) {
        return 'Quick Actions requires at least one action selected. '
            'You have data bindings but no actions.';
      }
    } else {
      // Data templates should have bindings, not actions
      if (_selectedActions.isNotEmpty && _selectedBindings.isEmpty) {
        return 'This template requires data bindings. '
            'You have actions selected but no data.';
      }
    }
    return null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialSchema != null;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: context.accentColor),
                onPressed: _goBack,
              )
            : null,
        title: Text(
          _steps[_currentStep].title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: _handleClose),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          // Step subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              _steps[_currentStep].subtitle,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          // Live preview (shown after step 1)
          if (_currentStep > 0) _buildLivePreviewPanel(),
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildTemplateStep(),
                _buildNameStep(),
                _selectedTemplate?.id == 'actions'
                    ? _buildActionsStep()
                    : _buildDataStep(),
                _buildAppearanceStep(),
              ],
            ),
          ),
          // Bottom actions
          _buildBottomActions(isEditing),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          // Can navigate to completed steps or current step
          final canNavigate = index <= _currentStep;

          return Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: canNavigate ? () => _goToStep(index) : null,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? context.accentColor
                          : isCurrent
                          ? context.accentColor.withValues(alpha: 0.2)
                          : AppTheme.darkCard,
                      border: isCurrent
                          ? Border.all(color: context.accentColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? context.accentColor
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: isCompleted
                          ? context.accentColor
                          : AppTheme.darkBorder,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Live preview panel - shows current widget progress
  Widget _buildLivePreviewPanel() {
    final previewSchema = _buildFinalSchema();
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final node = myNodeNum != null ? nodes[myNodeNum] : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.preview, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Live Preview',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Widget preview - auto-sizes to content
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: WidgetRenderer(
              schema: previewSchema,
              node: node,
              allNodes: nodes,
              accentColor: _accentColor,
              enableActions: false,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 1: Template Selection
  // ============================================================
  Widget _buildTemplateStep() {
    final templates = _getTemplates();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [...templates.map((template) => _buildTemplateCard(template))],
    );
  }

  Widget _buildTemplateCard(_WidgetTemplate template) {
    final isSelected = _selectedTemplate?.id == template.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTemplateSelection(template),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? context.accentColor : AppTheme.darkBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: template.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(template.icon, color: template.color, size: 28),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.description,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: context.accentColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_WidgetTemplate> _getTemplates() {
    return [
      _WidgetTemplate(
        id: 'status',
        name: 'Status Display',
        description: 'Show values with labels and optional progress bars',
        icon: Icons.speed,
        color: const Color(0xFF4ADE80),
        suggestedBindings: [
          'node.batteryLevel',
          'node.snr',
          'node.temperature',
        ],
      ),
      _WidgetTemplate(
        id: 'info',
        name: 'Info Card',
        description: 'Display text information in a clean layout',
        icon: Icons.info_outline,
        color: const Color(0xFF60A5FA),
        suggestedBindings: [
          'node.longName',
          'node.firmwareVersion',
          'node.role',
        ],
      ),
      _WidgetTemplate(
        id: 'gauge',
        name: 'Gauge Widget',
        description: 'Big visual gauge with a single value',
        icon: Icons.data_usage,
        color: const Color(0xFFFBBF24),
        suggestedBindings: ['node.batteryLevel'],
      ),
      _WidgetTemplate(
        id: 'actions',
        name: 'Quick Actions',
        description: 'Tap buttons to send messages, share location, etc.',
        icon: Icons.flash_on,
        color: const Color(0xFFF472B6),
        suggestedBindings: [],
      ),
      _WidgetTemplate(
        id: 'location',
        name: 'Location Info',
        description: 'Show GPS coordinates and distance',
        icon: Icons.location_on,
        color: const Color(0xFFA78BFA),
        suggestedBindings: ['node.latitude', 'node.longitude', 'node.distance'],
      ),
      _WidgetTemplate(
        id: 'environment',
        name: 'Weather & Environment',
        description: 'Temperature, humidity, and sensor readings',
        icon: Icons.thermostat,
        color: const Color(0xFF22D3EE),
        suggestedBindings: [
          'node.temperature',
          'node.humidity',
          'node.barometricPressure',
        ],
      ),
      _WidgetTemplate(
        id: 'blank',
        name: 'Start from Scratch',
        description: 'Empty canvas - build exactly what you want',
        icon: Icons.add_box_outlined,
        color: AppTheme.textSecondary,
        suggestedBindings: [],
      ),
    ];
  }

  // ============================================================
  // STEP 2: Name
  // ============================================================
  Widget _buildNameStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Name field
        Text(
          'Widget Name',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'e.g., My Battery Widget',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accentColor),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Helpful tip
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.accentColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: context.accentColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pick a name that helps you remember what this widget shows.',
                  style: TextStyle(color: context.accentColor, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STEP 3: Data Selection
  // ============================================================
  Widget _buildDataStep() {
    // Group bindings by category
    final relevantCategories = _getRelevantCategories();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Selection counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _selectedBindings.length >= _maxDataItems
                ? Colors.orange.withValues(alpha: 0.15)
                : context.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _selectedBindings.length >= _maxDataItems
                  ? Colors.orange.withValues(alpha: 0.3)
                  : context.accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _selectedBindings.length >= _maxDataItems
                    ? Icons.warning_amber
                    : Icons.data_usage,
                size: 16,
                color: _selectedBindings.length >= _maxDataItems
                    ? Colors.orange
                    : context.accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedBindings.length} / $_maxDataItems selected',
                style: TextStyle(
                  color: _selectedBindings.length >= _maxDataItems
                      ? Colors.orange
                      : context.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Suggested bindings from template
        if (_selectedTemplate != null &&
            _selectedTemplate!.suggestedBindings.isNotEmpty) ...[
          _buildDataCategory(
            'Suggested for ${_selectedTemplate!.name}',
            Icons.star,
            const Color(0xFFFBBF24),
            BindingRegistry.bindings
                .where(
                  (b) => _selectedTemplate!.suggestedBindings.contains(b.path),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        // Other categories
        ...relevantCategories.entries.map((entry) {
          return Column(
            children: [
              _buildDataCategory(
                _getCategoryName(entry.key),
                _getCategoryIcon(entry.key),
                _getCategoryColor(entry.key),
                entry.value,
              ),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  // Maximum number of data items allowed per widget
  static const int _maxDataItems = 6;

  Widget _buildDataCategory(
    String title,
    IconData icon,
    Color color,
    List<BindingDefinition> bindings,
  ) {
    final atLimit = _selectedBindings.length >= _maxDataItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bindings.map((binding) {
            final isSelected = _selectedBindings.contains(binding.path);
            final isDisabled = !isSelected && atLimit;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDisabled
                    ? null
                    : () {
                        setState(() {
                          if (isSelected) {
                            _selectedBindings.remove(binding.path);
                          } else {
                            _selectedBindings.add(binding.path);
                          }
                        });
                      },
                borderRadius: BorderRadius.circular(20),
                child: Opacity(
                  opacity: isDisabled ? 0.4 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.accentColor.withValues(alpha: 0.2)
                          : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.darkBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check,
                            size: 16,
                            color: context.accentColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          binding.label,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Map<BindingCategory, List<BindingDefinition>> _getRelevantCategories() {
    final categories = <BindingCategory, List<BindingDefinition>>{};

    // Filter out already-suggested bindings to avoid duplicates
    final suggestedPaths = _selectedTemplate?.suggestedBindings ?? [];

    for (final binding in BindingRegistry.bindings) {
      if (!suggestedPaths.contains(binding.path)) {
        categories.putIfAbsent(binding.category, () => []).add(binding);
      }
    }

    return categories;
  }

  String _getCategoryName(BindingCategory category) {
    return switch (category) {
      BindingCategory.node => 'Device Info',
      BindingCategory.device => 'Radio & Connectivity',
      BindingCategory.network => 'Network Stats',
      BindingCategory.environment => 'Weather & Sensors',
      BindingCategory.power => 'Battery & Power',
      BindingCategory.airQuality => 'Air Quality',
      BindingCategory.gps => 'Location',
      BindingCategory.messaging => 'Messages',
    };
  }

  IconData _getCategoryIcon(BindingCategory category) {
    return switch (category) {
      BindingCategory.node => Icons.device_hub,
      BindingCategory.device => Icons.cell_tower,
      BindingCategory.network => Icons.hub,
      BindingCategory.environment => Icons.thermostat,
      BindingCategory.power => Icons.battery_full,
      BindingCategory.airQuality => Icons.air,
      BindingCategory.gps => Icons.location_on,
      BindingCategory.messaging => Icons.message,
    };
  }

  Color _getCategoryColor(BindingCategory category) {
    return switch (category) {
      BindingCategory.node => const Color(0xFF60A5FA),
      BindingCategory.device => const Color(0xFFA78BFA),
      BindingCategory.network => const Color(0xFF4ADE80),
      BindingCategory.environment => const Color(0xFF22D3EE),
      BindingCategory.power => const Color(0xFFFBBF24),
      BindingCategory.airQuality => const Color(0xFF34D399),
      BindingCategory.gps => const Color(0xFFF472B6),
      BindingCategory.messaging => const Color(0xFFFF6B6B),
    };
  }

  // ============================================================
  // STEP 3 (Alt): Actions Selection for Quick Actions template
  // ============================================================
  Widget _buildActionsStep() {
    final actions = _getAvailableActions();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tap to select the actions you want:',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...actions.map((action) => _buildActionCard(action)),
      ],
    );
  }

  Widget _buildActionCard(_ActionOption action) {
    final isSelected = _selectedActions.contains(action.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedActions.remove(action.type);
              } else {
                _selectedActions.add(action.type);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? context.accentColor : AppTheme.darkBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.icon, color: action.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        action.description,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
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

  List<_ActionOption> _getAvailableActions() {
    return [
      _ActionOption(
        type: ActionType.sendMessage,
        label: 'Send Message',
        description: 'Quickly send a message to a node',
        icon: Icons.send,
        color: const Color(0xFF4F6AF6),
      ),
      _ActionOption(
        type: ActionType.shareLocation,
        label: 'Share Location',
        description: 'Send your current GPS position',
        icon: Icons.location_on,
        color: const Color(0xFF4ADE80),
      ),
      _ActionOption(
        type: ActionType.requestPositions,
        label: 'Request Positions',
        description: 'Ask all nodes to share their location',
        icon: Icons.radar,
        color: const Color(0xFFA78BFA),
      ),
      _ActionOption(
        type: ActionType.traceroute,
        label: 'Traceroute',
        description: 'See the path to a node',
        icon: Icons.route,
        color: const Color(0xFF22D3EE),
      ),
      _ActionOption(
        type: ActionType.sos,
        label: 'SOS Emergency',
        description: 'Send an emergency alert',
        icon: Icons.emergency,
        color: const Color(0xFFFF6B6B),
      ),
    ];
  }

  // ============================================================
  // STEP 4: Appearance
  // ============================================================
  Widget _buildAppearanceStep() {
    final validationError = _getValidationError();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Validation warning banner if there's an error
        if (validationError != null) ...[
          _buildValidationWarningBanner(validationError),
          const SizedBox(height: 16),
        ],
        // Color selection
        Text(
          'Accent Color',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildColorPicker(),
        const SizedBox(height: 24),
        // Layout style (only for data widgets, not actions)
        if (_selectedTemplate?.id != 'actions') ...[
          Text(
            'Layout',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildLayoutOptions(),
          const SizedBox(height: 24),
          // Show labels toggle
          _buildToggleOption(
            'Show Labels',
            'Display names next to values',
            _showLabels,
            (value) => setState(() => _showLabels = value),
          ),
        ],
      ],
    );
  }

  Widget _buildValidationWarningBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningYellow.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.warningYellow,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cannot Save Widget',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Go back to Step 1 to change your template, or Step 3 to update your selections.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF4ADE80), // Green
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFFF472B6), // Pink
      const Color(0xFFA78BFA), // Purple
      const Color(0xFF22D3EE), // Cyan
      const Color(0xFFFF6B6B), // Red
      const Color(0xFFFF9F43), // Orange
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((color) {
        final isSelected = _accentColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => setState(() => _accentColor = color),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLayoutOptions() {
    final layouts = [
      (_LayoutStyle.vertical, 'Vertical', Icons.view_agenda),
      (_LayoutStyle.horizontal, 'Horizontal', Icons.view_column),
      (_LayoutStyle.grid, 'Grid', Icons.grid_view),
    ];

    return Row(
      children: layouts.map((layout) {
        final isSelected = _layoutStyle == layout.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: layout.$1 != _LayoutStyle.grid ? 8 : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _layoutStyle = layout.$1),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.15)
                        : AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.accentColor
                          : AppTheme.darkBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        layout.$3,
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        layout.$2,
                        style: TextStyle(
                          color: isSelected
                              ? context.accentColor
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToggleOption(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: context.accentColor,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Bottom Actions
  // ============================================================
  Widget _buildBottomActions(bool isEditing) {
    final isLastStep = _currentStep == _steps.length - 1;
    final canContinue = _canContinue();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add to Dashboard checkbox on last step
            if (isLastStep && !isEditing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _addToDashboard = !_addToDashboard),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _addToDashboard
                              ? context.accentColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _addToDashboard
                                ? context.accentColor
                                : AppTheme.textSecondary,
                            width: 2,
                          ),
                        ),
                        child: _addToDashboard
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add to Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Continue / Create button
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: canContinue
                        ? (isLastStep ? _create : _goNext)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isLastStep
                          ? (isEditing ? 'Save Changes' : 'Create Widget')
                          : 'Continue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canContinue() {
    return switch (_currentStep) {
      0 => _selectedTemplate != null,
      1 => _nameController.text.trim().isNotEmpty,
      2 => true, // Data/actions selection is optional
      3 => _getValidationError() == null, // Must pass validation to create
      _ => false,
    };
  }

  void _goNext() {
    if (_currentStep < _steps.length - 1) {
      // Auto-fill name if empty
      if (_currentStep == 0 && _nameController.text.isEmpty) {
        _nameController.text = _selectedTemplate?.name ?? 'My Widget';
      }
      // Pre-select suggested bindings (only for new widgets)
      if (_currentStep == 1 &&
          _selectedTemplate != null &&
          widget.initialSchema == null) {
        _selectedBindings.addAll(_selectedTemplate!.suggestedBindings);
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToStep(int step) {
    if (step == _currentStep) return;
    if (step < 0 || step >= _steps.length) return;

    // Only allow going to completed steps or current step
    if (step > _currentStep) return;

    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _create() async {
    debugPrint('[WidgetWizard] _create called');

    // Final validation check
    final validationError = _getValidationError();
    if (validationError != null) {
      debugPrint('[WidgetWizard] Validation failed: $validationError');
      showErrorSnackBar(context, validationError);
      return;
    }

    debugPrint('[WidgetWizard] Building final schema...');

    final schema = _buildFinalSchema();
    debugPrint(
      '[WidgetWizard] Schema built: id=${schema.id}, name=${schema.name}',
    );
    debugPrint('[WidgetWizard] Existing ID was: $_existingId');

    try {
      debugPrint('[WidgetWizard] Calling onSave callback...');
      await widget.onSave(schema);
      debugPrint('[WidgetWizard] onSave completed successfully');
    } catch (e, stack) {
      debugPrint('[WidgetWizard] ERROR in onSave: $e');
      debugPrint('[WidgetWizard] Stack trace: $stack');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save widget: $e');
      }
      return;
    }

    if (mounted) {
      debugPrint(
        '[WidgetWizard] Popping with result, addToDashboard=$_addToDashboard',
      );
      showSuccessSnackBar(
        context,
        _existingId != null ? 'Widget updated!' : 'Widget created!',
      );
      Navigator.pop(
        context,
        WidgetWizardResult(schema: schema, addToDashboard: _addToDashboard),
      );
    }
  }

  // ============================================================
  // Schema Building
  // ============================================================
  WidgetSchema _buildFinalSchema() {
    final name = _nameController.text.trim().isEmpty
        ? 'My Widget'
        : _nameController.text.trim();

    // Build children based on template type
    final children = <ElementSchema>[];

    if (_selectedTemplate?.id == 'actions') {
      // Build action buttons
      children.addAll(_buildActionElements());
    } else {
      // Build data display
      children.addAll(_buildDataElements(name));
    }

    // Create root based on layout style
    final ElementSchema root;
    if (_selectedTemplate?.id == 'actions') {
      // Actions use horizontal layout with space around
      root = ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(
          padding: 12,
          mainAxisAlignment: MainAxisAlignmentOption.spaceAround,
        ),
        children: children,
      );
    } else if (_layoutStyle == _LayoutStyle.horizontal) {
      // Horizontal layout - stack rows of 3 items each for better wrapping
      if (children.length <= 3) {
        // Few items - single row with even spacing
        root = ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(
            padding: 12,
            spacing: 8,
            mainAxisAlignment: MainAxisAlignmentOption.spaceEvenly,
          ),
          children: children,
        );
      } else {
        // Many items - stack into rows of 3
        final rows = <ElementSchema>[];
        for (var i = 0; i < children.length; i += 3) {
          final rowItems = <ElementSchema>[];
          for (var j = i; j < i + 3 && j < children.length; j++) {
            rowItems.add(children[j]);
          }
          rows.add(
            ElementSchema(
              type: ElementType.row,
              style: const StyleSchema(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignmentOption.spaceEvenly,
              ),
              children: rowItems,
            ),
          );
        }
        root = ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 12, spacing: 8),
          children: rows,
        );
      }
    } else if (_layoutStyle == _LayoutStyle.grid) {
      // Create a 2-column grid - simpler approach without expanded containers
      if (children.isEmpty) {
        root = ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 12, spacing: 8),
          children: [
            ElementSchema(
              type: ElementType.text,
              text: 'No data selected',
              style: StyleSchema(
                textColor: _colorToHex(AppTheme.textSecondary),
                fontSize: 13,
              ),
            ),
          ],
        );
      } else {
        final rows = <ElementSchema>[];
        for (var i = 0; i < children.length; i += 2) {
          final rowChildren = <ElementSchema>[children[i]];
          if (i + 1 < children.length) {
            rowChildren.add(children[i + 1]);
          }
          rows.add(
            ElementSchema(
              type: ElementType.row,
              style: const StyleSchema(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignmentOption.spaceEvenly,
              ),
              children: rowChildren,
            ),
          );
        }
        root = ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 12, spacing: 8),
          children: rows,
        );
      }
    } else {
      root = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: children,
      );
    }

    return WidgetSchema(
      id: _existingId,
      name: name,
      description: _selectedTemplate?.description,
      size: CustomWidgetSize.medium, // Auto-resize, so medium is fine
      root: root,
      tags: _selectedTemplate != null ? [_selectedTemplate!.id] : [],
    );
  }

  List<ElementSchema> _buildDataElements(String name) {
    final children = <ElementSchema>[];
    final isCompactLayout =
        _layoutStyle == _LayoutStyle.horizontal ||
        _layoutStyle == _LayoutStyle.grid;

    // Title row with icon (only for vertical layout)
    if (!isCompactLayout &&
        _selectedTemplate != null &&
        _selectedTemplate!.id != 'blank') {
      children.add(
        ElementSchema(
          type: ElementType.row,
          children: [
            ElementSchema(
              type: ElementType.icon,
              iconName: _getIconNameForTemplate(_selectedTemplate!.id),
              iconSize: 18,
              style: StyleSchema(textColor: _colorToHex(_accentColor)),
            ),
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(width: 8),
            ),
            ElementSchema(
              type: ElementType.text,
              text: name,
              style: const StyleSchema(
                textColor: '#FFFFFF',
                fontSize: 14,
                fontWeight: 'w600',
              ),
            ),
          ],
        ),
      );
    }

    // Add binding elements
    for (final bindingPath in _selectedBindings) {
      final binding = BindingRegistry.bindings.firstWhere(
        (b) => b.path == bindingPath,
        orElse: () => BindingDefinition(
          path: bindingPath,
          label: bindingPath,
          description: '',
          category: BindingCategory.node,
          valueType: String,
        ),
      );

      if (isCompactLayout) {
        // Compact cell for horizontal/grid layout - stacked vertically in a cell
        final isHorizontal = _layoutStyle == _LayoutStyle.horizontal;
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: isHorizontal ? 4 : 8,
              backgroundColor: _colorToHex(
                AppTheme.darkCard.withValues(alpha: 0.5),
              ),
              borderRadius: 6,
              alignment: AlignmentOption.center,
            ),
            children: [
              if (_showLabels)
                ElementSchema(
                  type: ElementType.text,
                  text: binding.label,
                  style: StyleSchema(
                    textColor: _colorToHex(AppTheme.textSecondary),
                    fontSize: isHorizontal ? 9 : 11,
                  ),
                ),
              ElementSchema(
                type: ElementType.text,
                binding: BindingSchema(
                  path: bindingPath,
                  format: binding.defaultFormat,
                  defaultValue: '--',
                ),
                style: StyleSchema(
                  textColor: _colorToHex(_accentColor),
                  fontSize: isHorizontal ? 14 : 18,
                  fontWeight: 'w700',
                ),
              ),
            ],
          ),
        );
      } else if (_showLabels) {
        // Row with label and value for vertical layout
        children.add(
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(
              mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
            ),
            children: [
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(AppTheme.textSecondary),
                  fontSize: 13,
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: BindingSchema(
                  path: bindingPath,
                  format: binding.defaultFormat,
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  textColor: '#FFFFFF',
                  fontSize: 14,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
        );
      } else {
        // Just the value
        children.add(
          ElementSchema(
            type: ElementType.text,
            binding: BindingSchema(
              path: bindingPath,
              format: binding.defaultFormat,
              defaultValue: '--',
            ),
            style: const StyleSchema(
              textColor: '#FFFFFF',
              fontSize: 14,
              fontWeight: 'w600',
            ),
          ),
        );
      }

      // Add gauge for numeric values (only in vertical layout)
      if (!isCompactLayout &&
          (_selectedTemplate?.id == 'gauge' ||
              (_selectedTemplate?.id == 'status' &&
                  binding.valueType == int &&
                  binding.minValue != null))) {
        children.add(
          ElementSchema(
            type: ElementType.gauge,
            gaugeType: GaugeType.linear,
            gaugeMin: binding.minValue ?? 0,
            gaugeMax: binding.maxValue ?? 100,
            gaugeColor: _colorToHex(_accentColor),
            binding: BindingSchema(path: bindingPath),
            style: const StyleSchema(height: 6),
          ),
        );
      }
    }

    // If no bindings selected, add placeholder
    if (children.isEmpty ||
        (_selectedBindings.isEmpty && children.length <= 1)) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No data selected',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      );
    }

    return children;
  }

  List<ElementSchema> _buildActionElements() {
    if (_selectedActions.isEmpty) {
      return [
        ElementSchema(
          type: ElementType.text,
          text: 'No actions selected',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      ];
    }

    return _selectedActions.map((actionType) {
      final actionOption = _getAvailableActions().firstWhere(
        (a) => a.type == actionType,
      );

      return ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(alignment: AlignmentOption.center),
        action: ActionSchema(
          type: actionType,
          requiresNodeSelection:
              actionType == ActionType.sendMessage ||
              actionType == ActionType.traceroute,
          requiresChannelSelection: actionType == ActionType.sendMessage,
          label: actionOption.label,
        ),
        children: [
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.circle,
            style: StyleSchema(
              width: 48,
              height: 48,
              backgroundColor: _colorToHex(
                actionOption.color.withValues(alpha: 0.15),
              ),
            ),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: _getIconNameFromIconData(actionOption.icon),
                iconSize: 22,
                style: StyleSchema(textColor: _colorToHex(actionOption.color)),
              ),
            ],
          ),
          ElementSchema(
            type: ElementType.spacer,
            style: const StyleSchema(height: 6),
          ),
          ElementSchema(
            type: ElementType.text,
            text: actionOption.label,
            style: StyleSchema(
              textColor: _colorToHex(AppTheme.textSecondary),
              fontSize: 11,
            ),
          ),
        ],
      );
    }).toList();
  }

  String _getIconNameForTemplate(String templateId) {
    return switch (templateId) {
      'status' => 'speed',
      'info' => 'info_outline',
      'gauge' => 'data_usage',
      'actions' => 'flash_on',
      'location' => 'location_on',
      'environment' => 'thermostat',
      _ => 'widgets',
    };
  }

  String _getIconNameFromIconData(IconData icon) {
    // Map common icons to their names
    if (icon == Icons.send) return 'send';
    if (icon == Icons.location_on) return 'location_on';
    if (icon == Icons.radar) return 'radar';
    if (icon == Icons.route) return 'route';
    if (icon == Icons.emergency) return 'emergency';
    return 'touch_app';
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}

// ============================================================
// Supporting Classes
// ============================================================

class _WizardStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _WizardStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _WidgetTemplate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> suggestedBindings;

  const _WidgetTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.suggestedBindings,
  });
}

class _ActionOption {
  final ActionType type;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _ActionOption({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

enum _LayoutStyle { vertical, horizontal, grid }
