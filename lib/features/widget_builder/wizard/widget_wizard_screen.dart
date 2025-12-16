import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../renderer/widget_renderer.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';

/// Helper class for threshold lines
class _ThresholdLine {
  double value;
  Color color;
  String label;

  _ThresholdLine({
    required this.value,
    required this.color,
    required this.label,
  });
}

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

  // Graph-specific options
  ChartType _chartType = ChartType.area; // Default/merged chart type
  bool _showGrid = true;
  bool _showDots = true;
  bool _smoothCurve = true;
  bool _fillArea = true;
  bool _mergeCharts = false; // Combine all data series into one chart
  final Map<String, Color> _mergeColors =
      {}; // Individual colors for merged charts
  final Map<String, ChartType> _bindingChartTypes =
      {}; // Individual chart types per binding

  // Advanced chart options
  ChartMergeMode _mergeMode = ChartMergeMode.overlay;
  ChartNormalization _normalization = ChartNormalization.raw;
  ChartBaseline _baseline = ChartBaseline.none;
  int _dataPoints = 30; // Number of data points to display
  bool _showMinMax = false; // Show min/max indicators
  bool _gradientFill = false; // Use gradient fill
  Color _gradientLowColor = const Color(0xFF4CAF50); // Green
  Color _gradientHighColor = const Color(0xFFFF5252); // Red
  final List<_ThresholdLine> _thresholds = []; // Threshold lines

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
    } else if (tags.contains('graph')) {
      _selectedTemplate = _getTemplates().firstWhere((t) => t.id == 'graph');
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

    // Get live signal data from protocol streams
    final rssiAsync = ref.watch(currentRssiProvider);
    final snrAsync = ref.watch(currentSnrProvider);
    final channelUtilAsync = ref.watch(currentChannelUtilProvider);

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
              deviceRssi: rssiAsync.value,
              deviceSnr: snrAsync.value,
              deviceChannelUtil: channelUtilAsync.value,
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) => _buildTemplateCard(templates[index]),
    );
  }

  Widget _buildTemplateCard(_WidgetTemplate template) {
    final isSelected = _selectedTemplate?.id == template.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTemplateSelection(template),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? context.accentColor : AppTheme.darkBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: template.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(template.icon, color: template.color, size: 24),
              ),
              const SizedBox(height: 10),
              // Name
              Text(
                template.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Selection indicator
              if (isSelected) ...[
                const SizedBox(height: 6),
                Icon(Icons.check_circle, color: context.accentColor, size: 18),
              ],
            ],
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
        id: 'graph',
        name: 'Graph Widget',
        description: 'Line, area, or bar charts for tracking data over time',
        icon: Icons.show_chart,
        color: const Color(0xFFFF9F43),
        suggestedBindings: ['node.rssi', 'node.snr'],
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
    final isGauge = _selectedTemplate?.id == 'gauge';
    final isGraph = _selectedTemplate?.id == 'graph';

    // Filter suggested bindings for gauge/graph (numeric only)
    final suggestedBindings =
        _selectedTemplate?.suggestedBindings.where((path) {
          if (!isGauge && !isGraph) return true;
          final binding = BindingRegistry.bindings.firstWhere(
            (b) => b.path == path,
            orElse: () => BindingDefinition(
              path: path,
              label: path,
              description: '',
              category: BindingCategory.node,
              valueType: String,
            ),
          );
          return binding.valueType == int || binding.valueType == double;
        }).toList() ??
        [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Gauge-specific guidance
        if (isGauge) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gauge widgets display a single numeric value with a visual indicator. Only numeric data is shown below.',
                    style: TextStyle(color: context.accentColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Graph-specific guidance
        if (isGraph) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.show_chart, color: context.accentColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Graph widgets display numeric values over time. Select up to 3 data series to track. Only numeric data is shown below.',
                    style: TextStyle(color: context.accentColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
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
        // Suggested bindings from template (filtered for gauge)
        if (_selectedTemplate != null && suggestedBindings.isNotEmpty) ...[
          _buildDataCategory(
            'Suggested for ${_selectedTemplate!.name}',
            Icons.star,
            const Color(0xFFFBBF24),
            BindingRegistry.bindings
                .where((b) => suggestedBindings.contains(b.path))
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

  // Maximum number of data items allowed per widget - depends on template
  int get _maxDataItems {
    return switch (_selectedTemplate?.id) {
      'gauge' => 3, // Gauge shows up to 3 values horizontally
      'graph' => 2, // Graph can show up to 2 data series stacked vertically
      'info' => 4, // Info cards are text-focused
      _ => 6, // Default
    };
  }

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

    // For gauge and graph widgets, only show numeric types
    final isGaugeWidget = _selectedTemplate?.id == 'gauge';
    final isGraphWidget = _selectedTemplate?.id == 'graph';
    final numericOnly = isGaugeWidget || isGraphWidget;

    for (final binding in BindingRegistry.bindings) {
      if (!suggestedPaths.contains(binding.path)) {
        // Filter by value type for gauge/graph widgets - only numeric
        if (numericOnly) {
          if (binding.valueType != int && binding.valueType != double) {
            continue;
          }
        }
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
    final isActionsTemplate = _selectedTemplate?.id == 'actions';
    final isGraphTemplate = _selectedTemplate?.id == 'graph';
    // Hide accent color for graphs with multiple series - they have individual colors
    // Also hide for merged graphs
    final hasSeriesColors =
        isGraphTemplate && (_mergeCharts || _selectedBindings.length > 1);
    final showAccentColor = !isActionsTemplate && !hasSeriesColors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Validation warning banner if there's an error
        if (validationError != null) ...[
          _buildValidationWarningBanner(validationError),
          const SizedBox(height: 16),
        ],
        // Color selection (not for actions or merged graphs)
        if (showAccentColor) ...[
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
        ],
        // Graph-specific options
        if (isGraphTemplate) ...[
          _buildGraphStyleOptions(),
          const SizedBox(height: 24),
        ],
        // Layout style (only for data widgets, not actions or graphs)
        if (!isActionsTemplate && !isGraphTemplate) ...[
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
        // Show labels toggle for graph (outside the layout section)
        if (isGraphTemplate) ...[_buildGraphToggleOptions()],
        // For actions template, show a simple message
        if (isActionsTemplate)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Action buttons use their own colors based on the action type.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
  // Graph Style Options
  // ============================================================
  Widget _buildGraphStyleOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart Type selection
        Text(
          'Chart Type',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildChartTypeSelector(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChartTypeSelector() {
    // Merge option first (only show if multiple bindings selected)
    final showMergeOption = _selectedBindings.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Merge option at top when multiple bindings
        if (showMergeOption) ...[
          _buildMergeChartsOption(),
          const SizedBox(height: 16),
        ],

        // When merged: single chart type for all + color pickers
        if (_mergeCharts && showMergeOption) ...[
          _buildMergeColorPickers(),
          const SizedBox(height: 16),
          _buildMergeModeSelector(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Merged charts use a combined multi-line view. Individual chart types are disabled.',
                    style: TextStyle(color: context.accentColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        // When NOT merged: individual chart type per binding
        if (!_mergeCharts) ...[
          if (_selectedBindings.length > 1) ...[
            _buildSeriesColorPickers(),
            const SizedBox(height: 16),
            Text(
              'Chart Type per Series',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildIndividualChartTypePickers(),
          ] else ...[
            // Single binding: just show the chart type grid
            _buildChartTypeGrid(),
          ],
        ],
      ],
    );
  }

  Widget _buildChartTypeGrid({String? bindingPath, ChartType? currentType}) {
    // First row - main chart types
    final mainChartTypes = [
      (ChartType.area, 'Area', Icons.area_chart),
      (ChartType.line, 'Line', Icons.show_chart),
      (ChartType.bar, 'Bar', Icons.bar_chart),
    ];

    // Second row - additional chart types
    final additionalChartTypes = [
      (ChartType.sparkline, 'Spark', Icons.timeline),
      (ChartType.stepped, 'Stepped', Icons.stacked_line_chart),
      (ChartType.scatter, 'Scatter', Icons.scatter_plot),
    ];

    final selectedType = currentType ?? _chartType;

    return Column(
      children: [
        // First row
        Row(
          children: mainChartTypes.asMap().entries.map((entry) {
            final type = entry.value;
            final isSelected = selectedType == type.$1;
            final isLast = entry.key == mainChartTypes.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: _buildChartTypeButton(
                  type,
                  isSelected,
                  bindingPath: bindingPath,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Second row
        Row(
          children: additionalChartTypes.asMap().entries.map((entry) {
            final type = entry.value;
            final isSelected = selectedType == type.$1;
            final isLast = entry.key == additionalChartTypes.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: _buildChartTypeButton(
                  type,
                  isSelected,
                  bindingPath: bindingPath,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIndividualChartTypePickers() {
    final bindingsList = _selectedBindings.toList();

    return Column(
      children: bindingsList.asMap().entries.map((entry) {
        final index = entry.key;
        final bindingPath = entry.value;
        final binding = BindingRegistry.bindings.firstWhere(
          (b) => b.path == bindingPath,
          orElse: () => BindingDefinition(
            path: bindingPath,
            label: bindingPath,
            description: '',
            category: BindingCategory.node,
            valueType: double,
          ),
        );

        // Get current chart type for this binding or default
        final currentType = _bindingChartTypes[bindingPath] ?? ChartType.area;

        return Container(
          margin: EdgeInsets.only(
            bottom: index < bindingsList.length - 1 ? 16 : 0,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Binding label
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getDefaultColorForIndex(index),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      binding.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Chart type grid for this binding
              _buildChartTypeGrid(
                bindingPath: bindingPath,
                currentType: currentType,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getDefaultColorForIndex(int index) {
    final colors = [
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF9800), // Orange
      const Color(0xFF4CAF50), // Green
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
    ];
    return colors[index % colors.length];
  }

  Widget _buildChartTypeButton(
    (ChartType, String, IconData) type,
    bool isSelected, {
    String? bindingPath,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          if (bindingPath != null) {
            // Per-binding chart type
            _bindingChartTypes[bindingPath] = type.$1;
          } else {
            // Global chart type (single binding or merged)
            _chartType = type.$1;
            // Auto-adjust fill area based on chart type
            if (type.$1 == ChartType.area) {
              _fillArea = true;
            } else if (type.$1 == ChartType.line) {
              _fillArea = false;
            }
          }
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.15)
                : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? context.accentColor : AppTheme.darkBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(
                type.$3,
                color: isSelected
                    ? context.accentColor
                    : AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                type.$2,
                style: TextStyle(
                  color: isSelected ? context.accentColor : Colors.white,
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMergeChartsOption() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _mergeCharts
            ? context.accentColor.withValues(alpha: 0.1)
            : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _mergeCharts ? context.accentColor : AppTheme.darkBorder,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleMergeCharts(),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(
              Icons.merge_type,
              color: _mergeCharts
                  ? context.accentColor
                  : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merge into Single Chart',
                    style: TextStyle(
                      color: _mergeCharts ? context.accentColor : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Combine all data series with color-coded legend',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _mergeCharts,
              onChanged: (value) => _setMergeCharts(value),
              activeTrackColor: context.accentColor,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMergeCharts() {
    _setMergeCharts(!_mergeCharts);
  }

  void _setMergeCharts(bool value) {
    if (value && !_mergeCharts) {
      // Check if there are different chart types selected
      final chartTypes = _bindingChartTypes.values.toSet();
      if (chartTypes.length > 1) {
        _showMergeConfirmationDialog();
        return;
      }
    }
    setState(() => _mergeCharts = value);
  }

  void _showMergeConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          'Merge Charts?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'You have selected different chart types for each series. '
          'Merging will combine all series into a single multi-line chart view. '
          'Individual chart types will no longer apply.\n\n'
          'Do you want to continue?',
          style: TextStyle(color: AppTheme.textSecondary),
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
            onPressed: () {
              Navigator.pop(context);
              setState(() => _mergeCharts = true);
            },
            child: Text('Merge', style: TextStyle(color: context.accentColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeColorPickers() {
    // Default colors for merged chart lines
    final defaultColors = [
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF9800), // Orange
      const Color(0xFF4CAF50), // Green
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
    ];

    final availableColors = [
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF4ADE80), // Green
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFFF472B6), // Pink
      const Color(0xFFA78BFA), // Purple
      const Color(0xFF22D3EE), // Cyan
      const Color(0xFFFF6B6B), // Red
      const Color(0xFFFF9F43), // Orange
      const Color(0xFF00BCD4), // Teal
      const Color(0xFF4CAF50), // Forest Green
      const Color(0xFFE91E63), // Magenta
      const Color(0xFF9C27B0), // Deep Purple
    ];

    final bindingsList = _selectedBindings.toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Series Colors',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...bindingsList.asMap().entries.map((entry) {
            final index = entry.key;
            final bindingPath = entry.value;
            final binding = BindingRegistry.bindings.firstWhere(
              (b) => b.path == bindingPath,
              orElse: () => BindingDefinition(
                path: bindingPath,
                label: bindingPath,
                description: '',
                category: BindingCategory.node,
                valueType: double,
              ),
            );

            // Get current color or use default
            final currentColor =
                _mergeColors[bindingPath] ??
                defaultColors[index % defaultColors.length];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < bindingsList.length - 1 ? 12 : 0,
              ),
              child: Row(
                children: [
                  // Color indicator dot
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Binding label
                  Expanded(
                    child: Text(
                      binding.label,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Color picker dots
                  Wrap(
                    spacing: 6,
                    children: availableColors.take(6).map((color) {
                      final isSelected =
                          currentColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() {
                          _mergeColors[bindingPath] = color;
                        }),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Series color pickers for non-merged multi-series charts
  Widget _buildSeriesColorPickers() {
    final defaultColors = [
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF9800), // Orange
      const Color(0xFF4CAF50), // Green
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
    ];

    final availableColors = [
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF4ADE80), // Green
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFFF472B6), // Pink
      const Color(0xFFA78BFA), // Purple
      const Color(0xFF22D3EE), // Cyan
      const Color(0xFFFF6B6B), // Red
      const Color(0xFFFF9F43), // Orange
    ];

    final bindingsList = _selectedBindings.toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Series Colors',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...bindingsList.asMap().entries.map((entry) {
            final index = entry.key;
            final bindingPath = entry.value;
            final binding = BindingRegistry.bindings.firstWhere(
              (b) => b.path == bindingPath,
              orElse: () => BindingDefinition(
                path: bindingPath,
                label: bindingPath,
                description: '',
                category: BindingCategory.node,
                valueType: double,
              ),
            );

            final currentColor =
                _mergeColors[bindingPath] ??
                defaultColors[index % defaultColors.length];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < bindingsList.length - 1 ? 12 : 0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      binding.label,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: availableColors.take(6).map((color) {
                      final isSelected =
                          currentColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() {
                          _mergeColors[bindingPath] = color;
                        }),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGraphToggleOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic toggles section
        _buildToggleOption(
          'Show Grid',
          'Display horizontal grid lines',
          _showGrid,
          (value) => setState(() => _showGrid = value),
        ),
        const SizedBox(height: 12),
        if (_chartType != ChartType.bar)
          _buildToggleOption(
            'Show Data Points',
            'Display dots at each data point',
            _showDots,
            (value) => setState(() => _showDots = value),
          ),
        if (_chartType != ChartType.bar) const SizedBox(height: 12),
        if (_chartType != ChartType.bar)
          _buildToggleOption(
            'Smooth Curve',
            'Use curved lines instead of straight',
            _smoothCurve,
            (value) => setState(() => _smoothCurve = value),
          ),
        if (_chartType != ChartType.bar) const SizedBox(height: 12),
        if (_chartType == ChartType.line)
          _buildToggleOption(
            'Fill Area',
            'Fill the area under the line',
            _fillArea,
            (value) => setState(() => _fillArea = value),
          ),
        _buildToggleOption(
          'Show Current Value',
          'Display the current value above the chart',
          _showLabels,
          (value) => setState(() => _showLabels = value),
        ),

        const SizedBox(height: 24),
        // Advanced Options Header
        Text(
          'Advanced Options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Data Points Slider
        _buildDataPointsSlider(),
        const SizedBox(height: 16),

        // Min/Max Indicators
        _buildToggleOption(
          'Show Min/Max',
          'Display markers at highest and lowest points',
          _showMinMax,
          (value) => setState(() => _showMinMax = value),
        ),
        const SizedBox(height: 16),

        // Gradient Fill
        _buildGradientFillOption(),
        const SizedBox(height: 16),

        // Data Normalization (only when merged or single)
        _buildNormalizationSelector(),
        const SizedBox(height: 16),

        // Comparison Baseline
        _buildBaselineSelector(),
        const SizedBox(height: 16),

        // Threshold Lines
        _buildThresholdSection(),
      ],
    );
  }

  Widget _buildDataPointsSlider() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data Points',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                '$_dataPoints points',
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.accentColor,
              inactiveTrackColor: AppTheme.darkBorder,
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _dataPoints.toDouble(),
              min: 10,
              max: 60,
              divisions: 10,
              onChanged: (value) => setState(() => _dataPoints = value.toInt()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              Text(
                '60',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientFillOption() {
    final gradientColors = [
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5252), // Red
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF9C27B0), // Purple
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gradientFill
            ? context.accentColor.withValues(alpha: 0.1)
            : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _gradientFill ? context.accentColor : AppTheme.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gradient Fill',
                      style: TextStyle(
                        color: _gradientFill
                            ? context.accentColor
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Color based on value (low → high)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _gradientFill,
                onChanged: (value) => setState(() => _gradientFill = value),
                activeTrackColor: context.accentColor,
              ),
            ],
          ),
          if (_gradientFill) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Low color
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: gradientColors.map((color) {
                          final isSelected =
                              _gradientLowColor.toARGB32() == color.toARGB32();
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _gradientLowColor = color),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // High color
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'High',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: gradientColors.map((color) {
                          final isSelected =
                              _gradientHighColor.toARGB32() == color.toARGB32();
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _gradientHighColor = color),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNormalizationSelector() {
    final options = [
      (ChartNormalization.raw, 'Raw', 'Show actual values'),
      (ChartNormalization.percentChange, '% Change', 'Delta from start'),
      (ChartNormalization.normalized, '0-100', 'Normalized scale'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Display',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((opt) {
              final isSelected = _normalization == opt.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _normalization = opt.$1),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: opt.$1 != ChartNormalization.normalized ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.accentColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.darkBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.$3,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineSelector() {
    final options = [
      (ChartBaseline.none, 'None', Icons.remove),
      (ChartBaseline.firstValue, 'First Value', Icons.start),
      (ChartBaseline.average, 'Average', Icons.horizontal_rule),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparison Baseline',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((opt) {
              final isSelected = _baseline == opt.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _baseline = opt.$1),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: opt.$1 != ChartBaseline.average ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.accentColor.withValues(alpha: 0.15)
                          : Colors.transparent,
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
                          opt.$3,
                          color: isSelected
                              ? context.accentColor
                              : Colors.white,
                          size: 18,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSection() {
    final thresholdColors = [
      const Color(0xFFFF5252), // Red
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFF4CAF50), // Green
      const Color(0xFF4F6AF6), // Blue
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Threshold Lines',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (_thresholds.length < 3)
                GestureDetector(
                  onTap: () => setState(() {
                    _thresholds.add(
                      _ThresholdLine(
                        value: 50,
                        color: const Color(0xFFFF5252),
                        label: '',
                      ),
                    );
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: context.accentColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: context.accentColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_thresholds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add reference lines at specific values',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
          if (_thresholds.isNotEmpty) const SizedBox(height: 12),
          ..._thresholds.asMap().entries.map((entry) {
            final index = entry.key;
            final threshold = entry.value;
            return Container(
              margin: EdgeInsets.only(
                bottom: index < _thresholds.length - 1 ? 10 : 0,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: threshold.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: threshold.color.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  // Color selector
                  ...thresholdColors.map((color) {
                    final isSelected =
                        threshold.color.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => threshold.color = color),
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  // Value input
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Value',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: AppTheme.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: AppTheme.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: threshold.color),
                          ),
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) {
                            setState(() => threshold.value = parsed);
                          }
                        },
                        controller: TextEditingController(
                          text: '${threshold.value}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Label input
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Label',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: AppTheme.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: AppTheme.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: threshold.color),
                          ),
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                        ),
                        onChanged: (val) =>
                            setState(() => threshold.label = val),
                        controller: TextEditingController(
                          text: threshold.label,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete button
                  GestureDetector(
                    onTap: () => setState(() => _thresholds.removeAt(index)),
                    child: Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMergeModeSelector() {
    final options = [
      (ChartMergeMode.overlay, 'Overlay', Icons.layers),
      (ChartMergeMode.stackedArea, 'Stacked Area', Icons.area_chart),
      (ChartMergeMode.stackedBar, 'Stacked Bar', Icons.stacked_bar_chart),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merge Style',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((opt) {
              final isSelected = _mergeMode == opt.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mergeMode = opt.$1),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: opt.$1 != ChartMergeMode.stackedBar ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.accentColor.withValues(alpha: 0.15)
                          : Colors.transparent,
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
                          opt.$3,
                          color: isSelected
                              ? context.accentColor
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
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
      // Actions use vertical layout - each action is a row with icon + label
      root = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 8, spacing: 8),
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
    // Dispatch to template-specific builders for distinct visual styles
    return switch (_selectedTemplate?.id) {
      'gauge' => _buildGaugeElements(name),
      'graph' => _buildGraphElements(name),
      'info' => _buildInfoCardElements(name),
      'location' => _buildLocationElements(name),
      'environment' => _buildEnvironmentElements(name),
      'status' => _buildStatusElements(name),
      _ => _buildGenericElements(name),
    };
  }

  /// Gauge: Up to 3 gauges displayed horizontally
  List<ElementSchema> _buildGaugeElements(String name) {
    if (_selectedBindings.isEmpty) {
      return [
        ElementSchema(
          type: ElementType.text,
          text: 'Select up to 3 numeric values',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      ];
    }

    // Build a gauge column for each binding
    final gaugeColumns = <ElementSchema>[];

    for (final bindingPath in _selectedBindings) {
      final binding = BindingRegistry.bindings.firstWhere(
        (b) => b.path == bindingPath,
        orElse: () => BindingDefinition(
          path: bindingPath,
          label: bindingPath,
          description: '',
          category: BindingCategory.node,
          valueType: int,
          minValue: 0,
          maxValue: 100,
        ),
      );

      // Adjust size based on number of gauges
      final gaugeSize = _selectedBindings.length == 1 ? 100.0 : 70.0;
      final valueFontSize = _selectedBindings.length == 1 ? 28.0 : 20.0;
      final labelFontSize = _selectedBindings.length == 1 ? 13.0 : 11.0;

      gaugeColumns.add(
        ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(alignment: AlignmentOption.center),
          children: [
            // Value text above gauge
            ElementSchema(
              type: ElementType.text,
              binding: BindingSchema(
                path: bindingPath,
                format: binding.defaultFormat ?? '{value}',
                defaultValue: '--',
              ),
              style: StyleSchema(
                textColor: _colorToHex(_accentColor),
                fontSize: valueFontSize,
                fontWeight: 'w700',
              ),
            ),
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 8),
            ),
            // Radial gauge
            ElementSchema(
              type: ElementType.gauge,
              gaugeType: GaugeType.radial,
              gaugeMin: binding.minValue ?? 0,
              gaugeMax: binding.maxValue ?? 100,
              gaugeColor: _colorToHex(_accentColor),
              binding: BindingSchema(path: bindingPath),
              style: StyleSchema(width: gaugeSize, height: gaugeSize),
            ),
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 8),
            ),
            // Label below gauge
            ElementSchema(
              type: ElementType.text,
              text: binding.label,
              style: StyleSchema(
                textColor: _colorToHex(AppTheme.textSecondary),
                fontSize: labelFontSize,
                fontWeight: 'w500',
              ),
            ),
          ],
        ),
      );
    }

    // If single gauge, return centered column
    if (gaugeColumns.length == 1) {
      return gaugeColumns;
    }

    // Multiple gauges: wrap in a row with space around
    return [
      ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(
          mainAxisAlignment: MainAxisAlignmentOption.spaceEvenly,
        ),
        children: gaugeColumns,
      ),
    ];
  }

  /// Graph: Line, area, bar, or sparkline charts
  List<ElementSchema> _buildGraphElements(String name) {
    if (_selectedBindings.isEmpty) {
      return [
        ElementSchema(
          type: ElementType.text,
          text: 'Select data to graph',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      ];
    }

    final children = <ElementSchema>[];

    // Default colors for merged charts (fallback)
    final defaultChartColors = <Color>[
      const Color(0xFF4F6AF6), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF9800), // Orange
      const Color(0xFF4CAF50), // Green
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
    ];

    // Merge mode: single chart with multiple data series
    if (_mergeCharts && _selectedBindings.length > 1) {
      // Collect labels and colors for legend
      final legendLabels = <String>[];
      final legendColors = <String>[];
      final bindingsList = _selectedBindings.toList();

      for (int i = 0; i < bindingsList.length; i++) {
        final bindingPath = bindingsList[i];
        final binding = BindingRegistry.bindings.firstWhere(
          (b) => b.path == bindingPath,
          orElse: () => BindingDefinition(
            path: bindingPath,
            label: bindingPath,
            description: '',
            category: BindingCategory.node,
            valueType: double,
          ),
        );
        legendLabels.add(binding.label);
        // Use user-selected color or fall back to default
        final color =
            _mergeColors[bindingPath] ??
            defaultChartColors[i % defaultChartColors.length];
        legendColors.add(_colorToHex(color));
      }

      // Legend row at top
      if (_showLabels) {
        children.add(
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(
              mainAxisAlignment: MainAxisAlignmentOption.center,
              crossAxisAlignment: CrossAxisAlignmentOption.center,
              padding: 4,
              spacing: 16,
            ),
            children: [
              for (int i = 0; i < legendLabels.length; i++)
                ElementSchema(
                  type: ElementType.row,
                  style: const StyleSchema(
                    spacing: 4,
                    crossAxisAlignment: CrossAxisAlignmentOption.center,
                  ),
                  children: [
                    ElementSchema(
                      type: ElementType.container,
                      style: StyleSchema(
                        width: 8,
                        height: 8,
                        borderRadius: 4,
                        backgroundColor: legendColors[i],
                      ),
                    ),
                    ElementSchema(
                      type: ElementType.text,
                      text: legendLabels[i],
                      style: StyleSchema(
                        textColor: _colorToHex(AppTheme.textSecondary),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
        children.add(
          ElementSchema(
            type: ElementType.spacer,
            style: const StyleSchema(height: 8),
          ),
        );
      }

      // Single merged chart with multiLine type
      children.add(
        ElementSchema(
          type: ElementType.chart,
          chartType: ChartType.multiLine,
          chartShowGrid: _showGrid,
          chartShowDots: _showDots,
          chartCurved: _smoothCurve,
          chartMaxPoints: _dataPoints,
          chartBindingPaths: bindingsList,
          chartLegendLabels: legendLabels,
          chartLegendColors: legendColors,
          // Advanced options
          chartMergeMode: _mergeMode,
          chartNormalization: _normalization,
          chartBaseline: _baseline,
          chartShowMinMax: _showMinMax,
          chartGradientFill: _gradientFill,
          chartGradientLowColor: _colorToHex(_gradientLowColor),
          chartGradientHighColor: _colorToHex(_gradientHighColor),
          chartThresholds: _thresholds.map((t) => t.value).toList(),
          chartThresholdColors: _thresholds
              .map((t) => _colorToHex(t.color))
              .toList(),
          chartThresholdLabels: _thresholds.map((t) => t.label).toList(),
          style: StyleSchema(
            height: 120.0,
            textColor: _colorToHex(_accentColor),
          ),
        ),
      );
    } else {
      // Non-merged mode: separate chart per binding
      for (final bindingPath in _selectedBindings) {
        final binding = BindingRegistry.bindings.firstWhere(
          (b) => b.path == bindingPath,
          orElse: () => BindingDefinition(
            path: bindingPath,
            label: bindingPath,
            description: '',
            category: BindingCategory.node,
            valueType: double,
          ),
        );

        // Get chart type for this specific binding (or use global default)
        ChartType bindingChartType =
            _bindingChartTypes[bindingPath] ?? _chartType;
        // Apply fill area logic for line charts
        if (bindingChartType == ChartType.line && _fillArea) {
          bindingChartType = ChartType.area;
        }

        // Header row with label and current value
        if (_showLabels) {
          children.add(
            ElementSchema(
              type: ElementType.row,
              style: const StyleSchema(
                mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
                padding: 4,
              ),
              children: [
                // Label
                ElementSchema(
                  type: ElementType.text,
                  text: binding.label,
                  style: StyleSchema(
                    textColor: _colorToHex(AppTheme.textSecondary),
                    fontSize: 12,
                    fontWeight: 'w500',
                  ),
                ),
                // Current value
                ElementSchema(
                  type: ElementType.text,
                  binding: BindingSchema(
                    path: bindingPath,
                    format: binding.defaultFormat ?? '{value}',
                    defaultValue: '--',
                  ),
                  style: StyleSchema(
                    textColor: _colorToHex(_accentColor),
                    fontSize: 14,
                    fontWeight: 'w700',
                  ),
                ),
              ],
            ),
          );
          children.add(
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 8),
            ),
          );
        }

        // The chart element with per-binding chart type
        children.add(
          ElementSchema(
            type: ElementType.chart,
            chartType: bindingChartType,
            chartShowGrid: _showGrid,
            chartShowDots: _showDots,
            chartCurved: _smoothCurve,
            chartMaxPoints: _dataPoints,
            binding: BindingSchema(path: bindingPath),
            // Advanced options
            chartNormalization: _normalization,
            chartBaseline: _baseline,
            chartShowMinMax: _showMinMax,
            chartGradientFill: _gradientFill,
            chartGradientLowColor: _colorToHex(_gradientLowColor),
            chartGradientHighColor: _colorToHex(_gradientHighColor),
            chartThresholds: _thresholds.map((t) => t.value).toList(),
            chartThresholdColors: _thresholds
                .map((t) => _colorToHex(t.color))
                .toList(),
            chartThresholdLabels: _thresholds.map((t) => t.label).toList(),
            style: StyleSchema(
              height: _selectedBindings.length == 1 ? 100.0 : 70.0,
              textColor: _colorToHex(_accentColor),
            ),
          ),
        );

        // Add spacing between charts if multiple
        if (_selectedBindings.length > 1 &&
            bindingPath != _selectedBindings.last) {
          children.add(
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 16),
            ),
          );
        }
      }
    }

    return children;
  }

  /// Info Card: Clean text-focused layout with icon badges
  List<ElementSchema> _buildInfoCardElements(String name) {
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No info selected',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    // Info rows with subtle styling
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      children.add(
        ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(
            mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
            padding: 6,
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
                fontSize: 13,
                fontWeight: 'w500',
              ),
            ),
          ],
        ),
      );
    }

    return children;
  }

  /// Location: Map-style layout with coordinates and compass
  List<ElementSchema> _buildLocationElements(String name) {
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No location data selected',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    // Coordinate-style display
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      final isCoord =
          bindingPath.contains('latitude') || bindingPath.contains('longitude');

      children.add(
        ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(
            mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
          ),
          children: [
            ElementSchema(
              type: ElementType.row,
              children: [
                ElementSchema(
                  type: ElementType.icon,
                  iconName: isCoord ? 'explore' : 'near_me',
                  iconSize: 14,
                  style: const StyleSchema(textColor: '#A78BFA'),
                ),
                ElementSchema(
                  type: ElementType.spacer,
                  style: const StyleSchema(width: 6),
                ),
                ElementSchema(
                  type: ElementType.text,
                  text: binding.label,
                  style: StyleSchema(
                    textColor: _colorToHex(AppTheme.textSecondary),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            ElementSchema(
              type: ElementType.text,
              binding: BindingSchema(
                path: bindingPath,
                format: isCoord ? '%.5f' : binding.defaultFormat,
                defaultValue: '--',
              ),
              style: StyleSchema(
                textColor: isCoord ? '#A78BFA' : '#FFFFFF',
                fontSize: 13,
                fontWeight: 'w600',
              ),
            ),
          ],
        ),
      );
    }

    return children;
  }

  /// Environment: Weather card style with icons for each reading
  List<ElementSchema> _buildEnvironmentElements(String name) {
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No sensor data selected',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    // Environment readings with appropriate icons
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      final iconName = _getEnvironmentIcon(bindingPath);
      final valueColor = _getEnvironmentColor(bindingPath);

      children.add(
        ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(
            mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
            padding: 4,
          ),
          children: [
            ElementSchema(
              type: ElementType.row,
              children: [
                ElementSchema(
                  type: ElementType.icon,
                  iconName: iconName,
                  iconSize: 16,
                  style: StyleSchema(textColor: valueColor),
                ),
                ElementSchema(
                  type: ElementType.spacer,
                  style: const StyleSchema(width: 8),
                ),
                ElementSchema(
                  type: ElementType.text,
                  text: binding.label,
                  style: StyleSchema(
                    textColor: _colorToHex(AppTheme.textSecondary),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            ElementSchema(
              type: ElementType.text,
              binding: BindingSchema(
                path: bindingPath,
                format: binding.defaultFormat,
                defaultValue: '--',
              ),
              style: StyleSchema(
                textColor: valueColor,
                fontSize: 15,
                fontWeight: 'w700',
              ),
            ),
          ],
        ),
      );
    }

    return children;
  }

  /// Status: Dashboard-style with progress bars
  List<ElementSchema> _buildStatusElements(String name) {
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
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
      return children;
    }

    // Status rows with progress bars for numeric values
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      final isNumeric = binding.valueType == int || binding.valueType == double;

      // Label + value row
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

      // Add progress bar for numeric values
      if (isNumeric) {
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

    return children;
  }

  /// Generic fallback for blank/custom templates
  List<ElementSchema> _buildGenericElements(String name) {
    final children = <ElementSchema>[];
    final isCompactLayout =
        _layoutStyle == _LayoutStyle.horizontal ||
        _layoutStyle == _LayoutStyle.grid;

    if (_selectedBindings.isEmpty) {
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
      return children;
    }

    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);

      if (isCompactLayout) {
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
                style: StyleSchema(
                  textColor: _colorToHex(_accentColor),
                  fontSize: 14,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
        );
      } else {
        children.add(
          ElementSchema(
            type: ElementType.text,
            binding: BindingSchema(
              path: bindingPath,
              format: binding.defaultFormat,
              defaultValue: '--',
            ),
            style: StyleSchema(
              textColor: _colorToHex(_accentColor),
              fontSize: 14,
              fontWeight: 'w600',
            ),
          ),
        );
      }
    }

    return children;
  }

  BindingDefinition _getBinding(String path) {
    return BindingRegistry.bindings.firstWhere(
      (b) => b.path == path,
      orElse: () => BindingDefinition(
        path: path,
        label: path,
        description: '',
        category: BindingCategory.node,
        valueType: String,
      ),
    );
  }

  String _getEnvironmentIcon(String path) {
    if (path.contains('temperature')) return 'thermostat';
    if (path.contains('humidity')) return 'water_drop';
    if (path.contains('pressure') || path.contains('barometric')) {
      return 'speed';
    }
    if (path.contains('wind')) return 'air';
    if (path.contains('uv')) return 'wb_sunny';
    if (path.contains('rain')) return 'grain';
    return 'eco';
  }

  String _getEnvironmentColor(String path) {
    if (path.contains('temperature')) return '#FF6B6B';
    if (path.contains('humidity')) return '#60A5FA';
    if (path.contains('pressure')) return '#A78BFA';
    if (path.contains('wind')) return '#22D3EE';
    return '#4ADE80';
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

    // Simple row layout: icon badge on left, label on right
    // expanded: true makes row fill width so entire area is tappable
    return _selectedActions.map((actionType) {
      final actionOption = _getAvailableActions().firstWhere(
        (a) => a.type == actionType,
      );

      return ElementSchema(
        type: ElementType.row,
        style: StyleSchema(
          padding: 12,
          backgroundColor: _colorToHex(AppTheme.darkCard),
          borderRadius: 12,
          borderWidth: 1,
          borderColor: _colorToHex(AppTheme.darkBorder),
          spacing: 12,
          expanded: true, // Fill width so entire row is tappable
        ),
        action: ActionSchema(
          type: actionType,
          requiresNodeSelection:
              actionType == ActionType.sendMessage ||
              actionType == ActionType.traceroute,
          requiresChannelSelection: actionType == ActionType.sendMessage,
          label: actionOption.label,
        ),
        children: [
          // Icon with colored background badge
          ElementSchema(
            type: ElementType.container,
            style: StyleSchema(
              width: 44,
              height: 44,
              backgroundColor: _colorToHex(actionOption.color),
              borderRadius: 12,
              alignment: AlignmentOption.center,
            ),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: _getIconNameFromIconData(actionOption.icon),
                iconSize: 22,
                style: const StyleSchema(textColor: '#FFFFFF'),
              ),
            ],
          ),
          // Label text
          ElementSchema(
            type: ElementType.text,
            text: actionOption.label,
            style: const StyleSchema(
              textColor: '#FFFFFF',
              fontSize: 14,
              fontWeight: 'w600',
            ),
          ),
        ],
      );
    }).toList();
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
