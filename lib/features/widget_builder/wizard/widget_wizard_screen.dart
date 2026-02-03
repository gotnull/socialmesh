// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../renderer/widget_renderer.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/premium_feature_gate.dart';
import '../../../models/subscription_models.dart';
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

/// Helper class for per-series gradient config
class _GradientConfig {
  bool enabled;
  Color lowColor;
  Color highColor;

  _GradientConfig._({
    required this.enabled,
    required this.lowColor,
    required this.highColor,
  });

  factory _GradientConfig() => _GradientConfig._(
    enabled: false,
    lowColor: ChartColors.gradientGreen,
    highColor: ChartColors.gradientRed,
  );
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
  late final PageController _pageController;

  // Existing schema ID for edits
  String? _existingId;

  // Step 1: Template selection
  _WidgetTemplate? _selectedTemplate;

  // Step 2: Name
  final _nameController = TextEditingController();

  // Step 3: Data selection (or Actions for Quick Actions template)
  final Set<String> _selectedBindings = {};
  final Set<ActionType> _selectedActions = {};
  // Track original state for edited widgets to detect structural changes
  Set<String>? _originalBindings; // Bindings at load time
  Set<ActionType>?
  _originalActions; // Actions at load time (for actions template)
  bool? _originalMergeCharts; // Merge state at load time (for graph template)
  _LayoutStyle? _originalLayoutStyle; // Layout at load time
  bool? _originalShowLabels; // Show labels at load time

  // Step 4: Appearance
  Color _accentColor = ChartColors.blue;
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
  final Map<String, String> _bindingLabels =
      {}; // Custom labels extracted from original schema

  // Advanced chart options
  ChartMergeMode _mergeMode = ChartMergeMode.overlay;
  ChartNormalization _normalization = ChartNormalization.raw;
  ChartBaseline _baseline = ChartBaseline.none;
  int _dataPoints = 30; // Number of data points to display
  bool _showMinMax = false; // Show min/max indicators
  // Per-series gradient settings: Map from binding path (or '_merged') to gradient config
  final Map<String, _GradientConfig> _seriesGradients = {};
  // Per-series thresholds: Map from binding path to list of thresholds
  final Map<String, List<_ThresholdLine>> _seriesThresholds = {};

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
    // When editing, skip step 1 (template selection) - start at step 2 (naming)
    final isEditing = widget.initialSchema != null;
    _currentStep = isEditing ? 1 : 0;
    _pageController = PageController(initialPage: _currentStep);
    _initFromSchema();
  }

  void _initFromSchema() {
    final schema = widget.initialSchema;
    AppLogging.widgets(
      'Wizard: _initFromSchema called, schema is ${schema == null ? "NULL" : "present"}',
    );
    if (schema == null) return;

    AppLogging.widgets('Wizard: Schema id=${schema.id}, name=${schema.name}');
    AppLogging.widgets('Wizard: Schema root type=${schema.root.type}');
    AppLogging.widgets(
      'Wizard: Schema root has ${schema.root.children.length} children',
    );

    _existingId = schema.id;
    _nameController.text = schema.name;

    // Extract bindings FIRST (needed for template detection)
    _extractBindingsFromElement(schema.root);
    // Store original bindings to detect structural changes later
    _originalBindings = Set<String>.from(_selectedBindings);
    AppLogging.widgets('Wizard: Extracted bindings: $_selectedBindings');

    // Extract actions from schema
    _extractActionsFromElement(schema.root);
    // Store original actions to detect changes later
    _originalActions = Set<ActionType>.from(_selectedActions);
    AppLogging.widgets('Wizard: Extracted actions: $_selectedActions');

    // Try to detect template from tags first - MOST RELIABLE
    final tags = schema.tags;
    AppLogging.widgets('Wizard: Schema tags: $tags');

    // Tags are the authoritative source for template type
    // They're saved by the wizard and should be trusted
    _WidgetTemplate? templateFromTags;
    if (tags.contains('status')) {
      templateFromTags = _getTemplates().firstWhere((t) => t.id == 'status');
    } else if (tags.contains('info')) {
      templateFromTags = _getTemplates().firstWhere((t) => t.id == 'info');
    } else if (tags.contains('gauge')) {
      templateFromTags = _getTemplates().firstWhere((t) => t.id == 'gauge');
    } else if (tags.contains('actions')) {
      templateFromTags = _getTemplates().firstWhere((t) => t.id == 'actions');
    } else if (tags.contains('location')) {
      templateFromTags = _getTemplates().firstWhere((t) => t.id == 'location');
    } else if (tags.contains('environment')) {
      templateFromTags = _getTemplates().firstWhere(
        (t) => t.id == 'environment',
      );
    } else if (tags.contains('graph')) {
      templateFromTags = _getTemplates().firstWhere((t) => t.id == 'graph');
    }

    if (templateFromTags != null) {
      _selectedTemplate = templateFromTags;
      AppLogging.widgets(
        'Wizard: Template detected from tags: ${_selectedTemplate?.id}',
      );
    } else {
      // No template tag - try to detect from structure (for UI purposes only)
      // Note: We DON'T rebuild edited widgets - we preserve the original structure
      _selectedTemplate = _detectTemplateFromStructure(schema.root);
      AppLogging.widgets(
        'Wizard: Template detected from structure: ${_selectedTemplate?.id}',
      );
    }

    // Extract appearance settings from schema
    _extractAppearanceFromElement(schema.root);
    // Store original merge state to detect changes later
    _originalMergeCharts = _mergeCharts;

    // Detect if labels are shown by analyzing the schema structure
    // Labels are static text elements (no binding) used to describe values
    _showLabels = _detectShowLabels(schema.root);
    // Store original showLabels to detect changes later
    _originalShowLabels = _showLabels;
    AppLogging.widgets(
      'Wizard: Accent color: $_accentColor, Chart type: $_chartType, Merge: $_mergeCharts, ShowLabels: $_showLabels',
    );

    // Detect layout style from root element structure
    _detectLayoutStyle(schema.root);
    // Store original layout style to detect changes later
    _originalLayoutStyle = _layoutStyle;
    AppLogging.widgets('Wizard: Layout style: $_layoutStyle');
  }

  /// Detect if labels are shown in the schema by looking for static text elements
  /// that describe data values (text without bindings next to text with bindings)
  bool _detectShowLabels(ElementSchema root) {
    bool hasLabelText = false;
    bool hasValueText = false;

    void scanElement(ElementSchema element) {
      if (element.type == ElementType.text) {
        if (element.binding != null) {
          // This is a dynamic value text
          hasValueText = true;
        } else if (element.text != null && element.text!.isNotEmpty) {
          // This is a static label text
          hasLabelText = true;
        }
      }
      for (final child in element.children) {
        scanElement(child);
      }
    }

    scanElement(root);

    // Labels are shown if we have both static labels AND dynamic values
    // If we only have dynamic values, labels are hidden
    // If we have no values at all, default to true (new widget behavior)
    if (!hasValueText) return true;
    return hasLabelText;
  }

  /// Detect template type from element structure
  /// CRITICAL: Must correctly identify template to rebuild widget identically
  _WidgetTemplate? _detectTemplateFromStructure(ElementSchema root) {
    final templates = _getTemplates();
    bool hasChart = false;
    bool hasRadialGauge =
        false; // Radial/arc/battery/signal gauges = gauge template
    bool hasLinearGauge = false; // Linear gauges = status template
    bool hasAction = false;
    bool hasMap = false;

    void scanElement(ElementSchema element) {
      if (element.type == ElementType.chart) {
        hasChart = true;
        AppLogging.widgets('Wizard: Found chart element');
      }
      if (element.type == ElementType.gauge) {
        // CRITICAL: Distinguish between gauge types
        // Radial, arc, battery, signal = gauge template
        // Linear = status template (progress bars)
        final gaugeType = element.gaugeType ?? GaugeType.linear;
        AppLogging.widgets('Wizard: Found gauge with type: ${gaugeType.name}');
        if (gaugeType == GaugeType.linear) {
          hasLinearGauge = true;
        } else {
          hasRadialGauge = true;
        }
      }
      if (element.type == ElementType.map) {
        hasMap = true;
        AppLogging.widgets('Wizard: Found map element');
      }
      if (element.action != null && element.action!.type != ActionType.none) {
        hasAction = true;
        AppLogging.widgets('Wizard: Found action: ${element.action!.type}');
      }
      for (final child in element.children) {
        scanElement(child);
      }
    }

    scanElement(root);

    AppLogging.widgets(
      'Wizard: Structure detection - chart=$hasChart, radialGauge=$hasRadialGauge, '
      'linearGauge=$hasLinearGauge, map=$hasMap, action=$hasAction, '
      'bindings=${_selectedBindings.length}',
    );

    // Determine template based on detected elements
    // Order matters - more specific detections first
    if (hasChart) {
      AppLogging.widgets('Wizard: Detected as GRAPH template (has chart)');
      return templates.firstWhere((t) => t.id == 'graph');
    } else if (hasRadialGauge) {
      // Only radial/arc/etc gauges indicate gauge template
      AppLogging.widgets(
        'Wizard: Detected as GAUGE template (has radial gauge)',
      );
      return templates.firstWhere((t) => t.id == 'gauge');
    } else if (hasLinearGauge) {
      // Linear gauges indicate status template (progress bars)
      AppLogging.widgets(
        'Wizard: Detected as STATUS template (has linear gauge)',
      );
      return templates.firstWhere((t) => t.id == 'status');
    } else if (hasMap) {
      AppLogging.widgets('Wizard: Detected as LOCATION template (has map)');
      return templates.firstWhere((t) => t.id == 'location');
    } else if (hasAction && _selectedBindings.isEmpty) {
      AppLogging.widgets(
        'Wizard: Detected as ACTIONS template (has action, no bindings)',
      );
      return templates.firstWhere((t) => t.id == 'actions');
    } else if (_selectedBindings.isNotEmpty) {
      // Default to info for widgets with data bindings but no gauges
      AppLogging.widgets(
        'Wizard: Detected as INFO template (has bindings, no gauges)',
      );
      return templates.firstWhere((t) => t.id == 'info');
    }

    AppLogging.widgets('Wizard: No template detected');
    return null;
  }

  /// Parse hex color string to Color
  Color? _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      String cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex'; // Add alpha
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// Check if a color is a likely accent color (not secondary text)
  bool _isAccentColor(Color color) {
    // Secondary text colors are typically gray/low saturation
    final hsl = HSLColor.fromColor(color);
    return hsl.saturation > 0.3 && hsl.lightness > 0.2 && hsl.lightness < 0.9;
  }

  void _extractAppearanceFromElement(ElementSchema element) {
    // Extract accent color from styled elements (text, gauge, icons)
    if (element.type == ElementType.text && element.style.textColor != null) {
      final color = _hexToColor(element.style.textColor);
      if (color != null && _isAccentColor(color)) {
        _accentColor = color;
      }
    }

    if (element.type == ElementType.gauge && element.gaugeColor != null) {
      final color = _hexToColor(element.gaugeColor);
      if (color != null) {
        _accentColor = color;
      }
    }

    // Extract chart settings
    if (element.type == ElementType.chart) {
      // Chart type
      if (element.chartType != null) {
        _chartType = element.chartType!;
      }

      // Grid and dots
      if (element.chartShowGrid != null) {
        _showGrid = element.chartShowGrid!;
      }
      if (element.chartShowDots != null) {
        _showDots = element.chartShowDots!;
      }

      // Curved (smooth) lines
      if (element.chartCurved != null) {
        _smoothCurve = element.chartCurved!;
      }

      // Fill area (check if area or sparkline type)
      _fillArea =
          element.chartType == ChartType.area ||
          element.chartType == ChartType.sparkline;

      // Data points
      if (element.chartMaxPoints != null) {
        _dataPoints = element.chartMaxPoints!;
      }

      // Advanced chart options
      if (element.chartMergeMode != null) {
        _mergeMode = element.chartMergeMode!;
      }
      if (element.chartNormalization != null) {
        _normalization = element.chartNormalization!;
      }
      if (element.chartBaseline != null) {
        _baseline = element.chartBaseline!;
      }
      if (element.chartShowMinMax != null) {
        _showMinMax = element.chartShowMinMax!;
      }

      // Check if merged chart (multiple binding paths)
      if (element.chartBindingPaths != null &&
          element.chartBindingPaths!.length > 1) {
        _mergeCharts = true;

        // Extract merge colors - ensure all paths have colors (use defaults for missing)
        final paths = element.chartBindingPaths!;
        final colors = element.chartLegendColors ?? [];
        for (int i = 0; i < paths.length; i++) {
          Color? color;
          if (i < colors.length) {
            color = _hexToColor(colors[i]);
          }
          // Use stored color or fall back to default for this index
          _mergeColors[paths[i]] = color ?? ChartColors.forIndex(i);
        }
      }

      // Extract gradient settings
      if (element.chartGradientFill == true) {
        final bindingPath =
            element.chartBindingPath ?? element.chartBindingPaths?.first ?? '';
        final key = _mergeCharts ? '_merged' : bindingPath;

        final lowColor =
            _hexToColor(element.chartGradientLowColor) ?? Colors.green;
        final highColor =
            _hexToColor(element.chartGradientHighColor) ?? Colors.red;

        final config = _GradientConfig()
          ..enabled = true
          ..lowColor = lowColor
          ..highColor = highColor;
        _seriesGradients[key] = config;
      }

      // Extract threshold settings
      if (element.chartThresholds != null &&
          element.chartThresholds!.isNotEmpty) {
        final bindingPath =
            element.chartBindingPath ?? element.chartBindingPaths?.first ?? '';
        final key = _mergeCharts ? '_merged' : bindingPath;

        final thresholds = element.chartThresholds!;
        final colors = element.chartThresholdColors ?? [];
        final labels = element.chartThresholdLabels ?? [];

        final thresholdLines = <_ThresholdLine>[];
        for (int i = 0; i < thresholds.length; i++) {
          thresholdLines.add(
            _ThresholdLine(
              value: thresholds[i],
              color: i < colors.length
                  ? _hexToColor(colors[i]) ?? Colors.red
                  : Colors.red,
              label: i < labels.length ? labels[i] : '',
            ),
          );
        }
        _seriesThresholds[key] = thresholdLines;
      }

      // Extract per-binding chart types if they exist
      if (element.chartBindingPath != null) {
        _bindingChartTypes[element.chartBindingPath!] =
            element.chartType ?? ChartType.area;
      }
    }

    // Recurse into children
    for (final child in element.children) {
      _extractAppearanceFromElement(child);
    }
  }

  void _detectLayoutStyle(ElementSchema root) {
    // Detect layout based on structural analysis
    // Default to vertical if we can't determine
    _layoutStyle = _LayoutStyle.vertical;

    AppLogging.widgets(
      '[DETECT_LAYOUT] Root type: ${root.type}, children: ${root.children.length}',
    );

    if (root.type == ElementType.row) {
      // Single row at root = horizontal with few items
      _layoutStyle = _LayoutStyle.horizontal;
      AppLogging.widgets('[DETECT_LAYOUT] Result: HORIZONTAL (root is row)');
      return;
    }

    if (root.type == ElementType.column && root.children.isNotEmpty) {
      // Check if children are rows (either horizontal or grid)
      final rowChildren = root.children
          .where((c) => c.type == ElementType.row)
          .toList();

      AppLogging.widgets(
        '[DETECT_LAYOUT] Column has ${rowChildren.length} row children',
      );

      if (rowChildren.isEmpty) {
        // No row children = vertical layout
        _layoutStyle = _LayoutStyle.vertical;
        AppLogging.widgets(
          '[DETECT_LAYOUT] Result: VERTICAL (no row children)',
        );
        return;
      }

      // Analyze row structure to distinguish horizontal vs grid
      // Horizontal: rows with 3 items, tight spacing (6), spaceEvenly
      // Grid: rows with 2 items, wider spacing (12), start alignment
      final firstRow = rowChildren.first;
      final itemsPerRow = firstRow.children.length;
      final spacing = firstRow.style.spacing ?? 8;
      final mainAxisAlign = firstRow.style.mainAxisAlignment;

      AppLogging.widgets(
        '[DETECT_LAYOUT] First row analysis: items=$itemsPerRow, spacing=$spacing, mainAxis=$mainAxisAlign',
      );

      // Grid uses 2 items per row, start alignment, and larger spacing (>= 10)
      // Horizontal uses 3+ items with spaceEvenly
      if (itemsPerRow <= 2 &&
          spacing >= 10 &&
          mainAxisAlign == MainAxisAlignmentOption.start) {
        _layoutStyle = _LayoutStyle.grid;
        AppLogging.widgets(
          '[DETECT_LAYOUT] Result: GRID (2 items, spacing>=10, start align)',
        );
      } else if (itemsPerRow >= 3 &&
          mainAxisAlign == MainAxisAlignmentOption.spaceEvenly) {
        _layoutStyle = _LayoutStyle.horizontal;
        AppLogging.widgets(
          '[DETECT_LAYOUT] Result: HORIZONTAL (3+ items, spaceEvenly)',
        );
      } else {
        // Fallback based on item count
        _layoutStyle = itemsPerRow >= 3
            ? _LayoutStyle.horizontal
            : _LayoutStyle.grid;
        AppLogging.widgets(
          '[DETECT_LAYOUT] Result: ${_layoutStyle.name} (fallback based on item count)',
        );
      }
    } else {
      AppLogging.widgets('[DETECT_LAYOUT] Result: VERTICAL (default)');
    }
  }

  void _extractBindingsFromElement(ElementSchema element) {
    AppLogging.widgets(
      'Wizard: Scanning element type=${element.type}, binding=${element.binding?.path}, chartBindingPath=${element.chartBindingPath}, chartBindingPaths=${element.chartBindingPaths}',
    );

    // Regular binding
    if (element.binding != null) {
      AppLogging.widgets(
        'Wizard: Found regular binding: ${element.binding!.path}',
      );
      _selectedBindings.add(element.binding!.path);
    }

    // Chart-specific bindings
    if (element.type == ElementType.chart) {
      AppLogging.widgets('Wizard: Found chart element');
      if (element.chartBindingPath != null) {
        AppLogging.widgets(
          'Wizard: Found chartBindingPath: ${element.chartBindingPath}',
        );
        _selectedBindings.add(element.chartBindingPath!);

        // Extract custom label if there's a chartLegendLabels with one entry
        if (element.chartLegendLabels != null &&
            element.chartLegendLabels!.isNotEmpty) {
          _bindingLabels[element.chartBindingPath!] =
              element.chartLegendLabels!.first;
        }
      }
      if (element.chartBindingPaths != null) {
        AppLogging.widgets(
          'Wizard: Found chartBindingPaths: ${element.chartBindingPaths}',
        );
        for (int i = 0; i < element.chartBindingPaths!.length; i++) {
          final path = element.chartBindingPaths![i];
          _selectedBindings.add(path);

          // Extract custom labels for each path
          if (element.chartLegendLabels != null &&
              i < element.chartLegendLabels!.length) {
            _bindingLabels[path] = element.chartLegendLabels![i];
          }
        }
        // If multiple paths, it's a merged chart
        if (element.chartBindingPaths!.length > 1) {
          _mergeCharts = true;
        }
      }
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
    AppLogging.widgets('[WidgetWizard] _handleClose called');
    AppLogging.widgets(
      '[WidgetWizard] hasUnsavedChanges: ${_hasUnsavedChanges()}',
    );

    if (!_hasUnsavedChanges()) {
      AppLogging.widgets(
        '[WidgetWizard] No unsaved changes, closing immediately',
      );
      Navigator.pop(context);
      return;
    }

    // Show confirmation dialog
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Discard Changes?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'You have unsaved changes. Are you sure you want to close without saving?',
          style: TextStyle(color: context.textSecondary),
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
              foregroundColor: SemanticColors.onAccent,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    AppLogging.widgets('[WidgetWizard] Dialog result: $shouldClose');

    if (shouldClose == true && mounted) {
      AppLogging.widgets('[WidgetWizard] User confirmed close, popping');
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
          backgroundColor: context.card,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.warningYellow),
              SizedBox(width: 12),
              Text(
                'Switch Template?',
                style: TextStyle(color: context.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have $itemCount $currentDataType selected.',
                style: TextStyle(color: context.textSecondary),
              ),
              SizedBox(height: 12),
              Text(
                '"${template.name}" uses $newDataType instead, so your current selections won\'t be used.',
                style: TextStyle(color: context.textSecondary),
              ),
              SizedBox(height: 12),
              Text(
                'What would you like to do?',
                style: TextStyle(
                  color: context.textPrimary,
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
                foregroundColor: SemanticColors.onAccent,
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
    return GlassScaffold(
      title: _steps[_currentStep].title,
      leading: _currentStep > 0
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: context.accentColor),
              onPressed: _goBack,
            )
          : null,
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: _handleClose),
      ],
      slivers: [
        // Progress indicator
        SliverToBoxAdapter(child: _buildProgressIndicator()),
        // Step subtitle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              _steps[_currentStep].subtitle,
              style: TextStyle(color: context.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Live preview (shown after step 1)
        if (_currentStep > 0)
          SliverToBoxAdapter(child: _buildLivePreviewPanel()),
        // Page content + Bottom actions
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
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
        ),
      ],
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
                          : context.card,
                      border: isCurrent
                          ? Border.all(color: context.accentColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: SemanticColors.onAccent,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? context.accentColor
                                    : context.textSecondary,
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
                      color: isCompleted ? context.accentColor : context.border,
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
  /// UNIFIED RENDER PIPELINE: This method ALWAYS rebuilds the widget from
  /// current configuration state - same logic for new AND edited widgets.
  Widget _buildLivePreviewPanel() {
    // CRITICAL: Always rebuild from current state for live preview
    // This ensures layout, colors, labels, gauge count all update reactively
    // NO CACHING - NO CONDITIONAL PATHS - ALWAYS REBUILD FROM CONFIG STATE
    AppLogging.widgets('[PREVIEW] === Building Live Preview ===');
    AppLogging.widgets('[PREVIEW] _mergeCharts=$_mergeCharts');
    AppLogging.widgets('[PREVIEW] _showMinMax=$_showMinMax');
    AppLogging.widgets('[PREVIEW] _mergeColors=$_mergeColors');
    AppLogging.widgets('[PREVIEW] _seriesGradients=$_seriesGradients');
    AppLogging.widgets('[PREVIEW] _selectedBindings=$_selectedBindings');

    final previewSchema = _buildPreviewSchema();

    // Generate a unique key based on ALL configuration state to force Flutter
    // to rebuild the WidgetRenderer when any config changes.
    // This ensures edited widgets get the same live preview behavior as new widgets.
    // CRITICAL: Include ALL appearance settings that affect the chart!
    final gradientKey = _seriesGradients.entries
        .map(
          (e) =>
              '${e.key}:${e.value.enabled}:${e.value.lowColor.toARGB32()}:${e.value.highColor.toARGB32()}',
        )
        .join('|');
    final thresholdKey = _seriesThresholds.entries
        .map(
          (e) =>
              '${e.key}:${e.value.map((t) => '${t.value}:${t.color.toARGB32()}').join(";")}',
        )
        .join('|');
    // Include merge colors in the key!
    final mergeColorsKey = _mergeColors.entries
        .map((e) => '${e.key}:${e.value.toARGB32()}')
        .join('|');
    final previewKey = ValueKey(
      'preview_'
      '${_selectedTemplate?.id ?? "none"}_'
      '${_selectedBindings.join(",")}_'
      '${_layoutStyle.name}_'
      '${_accentColor.toARGB32()}_'
      '${_showLabels}_'
      '${_chartType.name}_'
      '${_mergeCharts}_'
      '${_selectedActions.map((a) => a.name).join(",")}_'
      // Chart appearance settings
      '${_showGrid}_${_showDots}_${_smoothCurve}_${_fillArea}_${_dataPoints}_'
      // Advanced chart options
      '${_mergeMode.name}_${_normalization.name}_${_baseline.name}_${_showMinMax}_'
      // Per-series gradients and thresholds
      '${gradientKey}_$thresholdKey'
      // Series colors
      '_$mergeColorsKey',
    );
    AppLogging.widgets('[PREVIEW] previewKey=$previewKey');

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
        color: context.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.preview, size: 14, color: context.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Live Preview',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Widget preview - auto-sizes to content
          // KEY IS CRITICAL: Forces Flutter to rebuild when config state changes
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: WidgetRenderer(
              key: previewKey,
              schema: previewSchema,
              node: node,
              allNodes: nodes,
              accentColor: _accentColor,
              enableActions: false,
              isPreview: true,
              usePlaceholderData: node == null,
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
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? context.accentColor : context.border,
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
              SizedBox(height: 10),
              // Name
              Text(
                template.name,
                style: TextStyle(
                  color: context.textPrimary,
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
        color: ChartColors.green,
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
        color: ChartColors.categoryNode,
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
        color: ChartColors.yellow,
        suggestedBindings: ['node.batteryLevel'],
      ),
      _WidgetTemplate(
        id: 'actions',
        name: 'Quick Actions',
        description: 'Tap buttons to send messages, share location, etc.',
        icon: Icons.flash_on,
        color: ChartColors.pink,
        suggestedBindings: [],
      ),
      _WidgetTemplate(
        id: 'location',
        name: 'Location Info',
        description: 'Show GPS coordinates and distance',
        icon: Icons.location_on,
        color: ChartColors.purple,
        suggestedBindings: ['node.latitude', 'node.longitude', 'node.distance'],
      ),
      _WidgetTemplate(
        id: 'environment',
        name: 'Weather & Environment',
        description: 'Temperature, humidity, and sensor readings',
        icon: Icons.thermostat,
        color: ChartColors.cyan,
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
        color: ChartColors.orange,
        suggestedBindings: ['node.rssi', 'node.snr'],
      ),
      _WidgetTemplate(
        id: 'blank',
        name: 'Start from Scratch',
        description: 'Empty canvas - build exactly what you want',
        icon: Icons.add_box_outlined,
        color: context.textSecondary,
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
            color: context.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: TextStyle(color: context.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'e.g., My Battery Widget',
            hintStyle: TextStyle(color: context.textTertiary),
            filled: true,
            fillColor: context.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accentColor),
            ),
          ),
        ),
        SizedBox(height: 24),
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
              SizedBox(width: 12),
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
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gauge widgets display a single numeric value with a visual indicator. Only numeric data is shown below.',
                    style: TextStyle(color: context.accentColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
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
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Graph widgets display numeric values over time. Select up to 3 data series to track. Only numeric data is shown below.',
                    style: TextStyle(color: context.accentColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
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
              SizedBox(width: 8),
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
            ChartColors.yellow,
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
              style: TextStyle(
                color: context.textPrimary,
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
                            // Clean up per-series data for removed binding
                            _seriesThresholds.remove(binding.path);
                            _seriesGradients.remove(binding.path);
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
                          : context.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? context.accentColor
                            : context.border,
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
                          SizedBox(width: 6),
                        ],
                        Text(
                          binding.label,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : context.textPrimary,
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

    // Track labels to filter out aliases (device.* that duplicate node.* bindings)
    final seenLabels = <String>{};

    for (final binding in BindingRegistry.bindings) {
      if (!suggestedPaths.contains(binding.path)) {
        // Filter by value type for gauge/graph widgets - only numeric
        if (numericOnly) {
          if (binding.valueType != int && binding.valueType != double) {
            continue;
          }
        }
        // Skip device.* aliases that duplicate node.* bindings (same label)
        // These are internal aliases for marketplace widget compatibility
        if (binding.path.startsWith('device.') &&
            seenLabels.contains(binding.label)) {
          continue;
        }
        seenLabels.add(binding.label);
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
      BindingCategory.node => ChartColors.categoryNode,
      BindingCategory.device => ChartColors.categoryDevice,
      BindingCategory.network => ChartColors.categoryNetwork,
      BindingCategory.environment => ChartColors.categoryEnvironment,
      BindingCategory.power => ChartColors.categoryPower,
      BindingCategory.airQuality => ChartColors.categoryAirQuality,
      BindingCategory.gps => ChartColors.categoryGps,
      BindingCategory.messaging => ChartColors.categoryMessaging,
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
          style: TextStyle(color: context.textSecondary, fontSize: 13),
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
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? context.accentColor : context.border,
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
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        action.description,
                        style: TextStyle(
                          color: context.textSecondary,
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
        color: ChartColors.blue,
      ),
      _ActionOption(
        type: ActionType.shareLocation,
        label: 'Share Location',
        description: 'Send your current GPS position',
        icon: Icons.location_on,
        color: ChartColors.green,
      ),
      _ActionOption(
        type: ActionType.requestPositions,
        label: 'Request Positions',
        description: 'Ask all nodes to share their location',
        icon: Icons.radar,
        color: ChartColors.purple,
      ),
      _ActionOption(
        type: ActionType.traceroute,
        label: 'Traceroute',
        description: 'See the path to a node',
        icon: Icons.route,
        color: ChartColors.cyan,
      ),
      _ActionOption(
        type: ActionType.sos,
        label: 'SOS Emergency',
        description: 'Send an emergency alert',
        icon: Icons.emergency,
        color: ChartColors.red,
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
    final isGaugeTemplate = _selectedTemplate?.id == 'gauge';
    final isEnvironmentTemplate = _selectedTemplate?.id == 'environment';
    final isLocationTemplate = _selectedTemplate?.id == 'location';
    // Hide accent color for:
    // - Actions (they use their own colors)
    // - Graphs with multiple series (they have individual colors)
    // - Environment (uses semantic colors per reading type)
    // - Location (uses its own fixed color scheme)
    final hasSeriesColors =
        isGraphTemplate && (_mergeCharts || _selectedBindings.length > 1);
    final showAccentColor =
        !isActionsTemplate &&
        !hasSeriesColors &&
        !isEnvironmentTemplate &&
        !isLocationTemplate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Validation warning banner if there's an error
        if (validationError != null) ...[
          _buildValidationWarningBanner(validationError),
          SizedBox(height: 16),
        ],
        // Color selection (not for actions or merged graphs)
        if (showAccentColor) ...[
          Text(
            'Accent Color',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          _buildColorPicker(),
          const SizedBox(height: 24),
        ],
        // Graph-specific options
        if (isGraphTemplate) ...[
          _buildGraphStyleOptions(),
          const SizedBox(height: 24),
        ],
        // Layout style (only for data widgets, not actions, graphs, or gauges)
        // Gauge widgets don't need layout options as they have a fixed layout
        if (!isActionsTemplate && !isGraphTemplate && !isGaugeTemplate) ...[
          Text(
            'Layout',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
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
        // Show labels toggle for gauge widgets (separate from layout)
        if (isGaugeTemplate) ...[
          _buildToggleOption(
            'Show Labels',
            'Display value labels on gauges',
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
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: context.textSecondary,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Action buttons use their own colors based on the action type.',
                    style: TextStyle(
                      color: context.textSecondary,
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cannot Save Widget',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                SizedBox(height: 8),
                Text(
                  'Go back to Step 1 to change your template, or Step 3 to update your selections.',
                  style: TextStyle(
                    color: context.textSecondary,
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
    // Use centralized chart series colors
    final colors = ChartColors.seriesColors;

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
                  ? Border.all(color: SemanticColors.onMarker, width: 3)
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
                ? const Icon(
                    Icons.check,
                    color: SemanticColors.onMarker,
                    size: 22,
                  )
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
                onTap: () {
                  AppLogging.widgets(
                    '[LAYOUT_TAP] Tapped layout: ${layout.$2}, was: $_layoutStyle, now: ${layout.$1}',
                  );
                  setState(() => _layoutStyle = layout.$1);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.15)
                        : context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? context.accentColor : context.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        layout.$3,
                        color: isSelected
                            ? context.accentColor
                            : context.textSecondary,
                        size: 24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        layout.$2,
                        style: TextStyle(
                          color: isSelected
                              ? context.accentColor
                              : context.textPrimary,
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
        color: context.card,
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
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
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
            color: context.textSecondary,
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
          SizedBox(height: 16),
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
                SizedBox(width: 8),
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
            SizedBox(height: 16),
            Text(
              'Chart Type per Series',
              style: TextStyle(
                color: context.textSecondary,
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
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border),
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
                      style: TextStyle(
                        color: context.textPrimary,
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
    // Use centralized chart series colors
    return ChartColors.forIndex(index);
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
          }
          // Note: _fillArea is NOT used anymore - the chart type directly
          // determines whether to show fill (Area) or not (Line).
          // The conversion logic in _buildGraphElements was removed.
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.15)
                : context.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? context.accentColor : context.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                type.$3,
                color: isSelected ? context.accentColor : context.textSecondary,
                size: 18,
              ),
              SizedBox(height: 2),
              Text(
                type.$2,
                style: TextStyle(
                  color: isSelected
                      ? context.accentColor
                      : context.textSecondary,
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
            : context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _mergeCharts ? context.accentColor : context.border,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleMergeCharts(),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(
              Icons.merge_type,
              color: _mergeCharts ? context.accentColor : context.textSecondary,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merge into Single Chart',
                    style: TextStyle(
                      color: _mergeCharts
                          ? context.accentColor
                          : context.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Combine all data series with color-coded legend',
                    style: TextStyle(
                      color: context.textSecondary,
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
    AppLogging.widgets(
      '[MERGE] _toggleMergeCharts called, current _mergeCharts=$_mergeCharts',
    );
    _setMergeCharts(!_mergeCharts);
  }

  void _setMergeCharts(bool value) {
    AppLogging.widgets(
      '[MERGE] _setMergeCharts($value), current _mergeCharts=$_mergeCharts',
    );
    if (value && !_mergeCharts) {
      // Check if there are different chart types selected
      final chartTypes = _bindingChartTypes.values.toSet();
      if (chartTypes.length > 1) {
        _showMergeConfirmationDialog();
        return;
      }
      // Migrate thresholds and gradients from per-series to merged
      _migrateToMerged();
    } else if (!value && _mergeCharts) {
      // Migrate thresholds and gradients from merged to per-series
      _migrateFromMerged();
    }
    AppLogging.widgets('[MERGE] Setting _mergeCharts to $value');
    setState(() => _mergeCharts = value);
    AppLogging.widgets('[MERGE] After setState, _mergeCharts=$_mergeCharts');
  }

  void _migrateToMerged() {
    AppLogging.widgets('[MERGE] _migrateToMerged called');
    // Migrate thresholds: collect all thresholds into _merged key
    final allThresholds = <_ThresholdLine>[];
    for (final bindingPath in _selectedBindings) {
      final thresholds = _seriesThresholds[bindingPath] ?? [];
      allThresholds.addAll(thresholds);
    }
    _seriesThresholds.clear();
    if (allThresholds.isNotEmpty) {
      // Limit to max 3 thresholds when merging
      _seriesThresholds['_merged'] = allThresholds.take(3).toList();
    }

    // Migrate gradients: if any series has gradient enabled, enable for merged
    _GradientConfig? firstEnabled;
    for (final bindingPath in _selectedBindings) {
      final gradient = _seriesGradients[bindingPath];
      if (gradient != null && gradient.enabled) {
        firstEnabled = gradient;
        break;
      }
    }
    _seriesGradients.clear();
    if (firstEnabled != null) {
      _seriesGradients['_merged'] = firstEnabled;
    }
    AppLogging.widgets(
      '[MERGE] After migration: _seriesGradients=$_seriesGradients',
    );
  }

  void _migrateFromMerged() {
    AppLogging.widgets('[MERGE] _migrateFromMerged called');
    // Migrate thresholds: move _merged thresholds to first series
    final mergedThresholds = _seriesThresholds['_merged'] ?? [];
    _seriesThresholds.remove('_merged');
    if (mergedThresholds.isNotEmpty && _selectedBindings.isNotEmpty) {
      _seriesThresholds[_selectedBindings.first] = mergedThresholds;
    }

    // Migrate gradients: move _merged gradient to first series
    final mergedGradient = _seriesGradients['_merged'];
    _seriesGradients.remove('_merged');
    if (mergedGradient != null &&
        mergedGradient.enabled &&
        _selectedBindings.isNotEmpty) {
      _seriesGradients[_selectedBindings.first] = mergedGradient;
    }
    AppLogging.widgets(
      '[MERGE] After migration: _seriesGradients=$_seriesGradients',
    );
  }

  void _showMergeConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Merge Charts?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'You have selected different chart types for each series. '
          'Merging will combine all series into a single multi-line chart view. '
          'Individual chart types will no longer apply.\n\n'
          'Do you want to continue?',
          style: TextStyle(color: context.textSecondary),
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
            onPressed: () {
              Navigator.pop(context);
              _migrateToMerged();
              setState(() => _mergeCharts = true);
            },
            child: Text('Merge', style: TextStyle(color: context.accentColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeColorPickers() {
    // Use centralized chart series colors
    final availableColors = ChartColors.seriesColors;
    final defaultColors = availableColors;

    final bindingsList = _selectedBindings.toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Series Colors',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...bindingsList.asMap().entries.map((entry) {
            final index = entry.key;
            final bindingPath = entry.value;

            // Use custom label if extracted from original schema, otherwise lookup from registry
            String bindingLabel;
            if (_bindingLabels.containsKey(bindingPath)) {
              bindingLabel = _bindingLabels[bindingPath]!;
            } else {
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
              bindingLabel = binding.label;
            }

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
                      bindingLabel,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                      ),
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
                        onTap: () {
                          AppLogging.widgets(
                            '[COLOR] Setting color for $bindingPath to ${color.toARGB32().toRadixString(16)}',
                          );
                          setState(() {
                            _mergeColors[bindingPath] = color;
                          });
                          AppLogging.widgets(
                            '[COLOR] _mergeColors after update: $_mergeColors',
                          );
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: SemanticColors.onMarker,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: SemanticColors.onMarker,
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
    // Use centralized chart series colors
    final availableColors = ChartColors.seriesColors;
    final defaultColors = availableColors;

    final bindingsList = _selectedBindings.toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Series Colors',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...bindingsList.asMap().entries.map((entry) {
            final index = entry.key;
            final bindingPath = entry.value;

            // Use custom label if extracted from original schema, otherwise lookup from registry
            String bindingLabel;
            if (_bindingLabels.containsKey(bindingPath)) {
              bindingLabel = _bindingLabels[bindingPath]!;
            } else {
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
              bindingLabel = binding.label;
            }

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
                      bindingLabel,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                      ),
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
                                ? Border.all(
                                    color: SemanticColors.onMarker,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: SemanticColors.onMarker,
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
    // Determine which chart types are in use
    final activeChartTypes = _getActiveChartTypes();

    // Feature compatibility checks
    final showDotsApplicable = activeChartTypes.any(
      (t) => t != ChartType.bar && t != ChartType.stackedBar,
    );
    final smoothCurveApplicable = activeChartTypes.any(
      (t) =>
          t == ChartType.line ||
          t == ChartType.area ||
          t == ChartType.sparkline ||
          t == ChartType.multiLine ||
          t == ChartType.stackedArea,
    );
    final fillAreaApplicable =
        activeChartTypes.length == 1 &&
        activeChartTypes.contains(ChartType.line);
    final minMaxApplicable = activeChartTypes.any(
      (t) =>
          t != ChartType.bar &&
          t != ChartType.stackedBar &&
          t != ChartType.scatter,
    );
    final gradientApplicable = activeChartTypes.any(
      (t) =>
          t == ChartType.line ||
          t == ChartType.area ||
          t == ChartType.sparkline ||
          t == ChartType.multiLine ||
          t == ChartType.stackedArea,
    );
    final baselineApplicable = activeChartTypes.any(
      (t) =>
          t == ChartType.line ||
          t == ChartType.area ||
          t == ChartType.sparkline ||
          t == ChartType.multiLine,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Display Options
        _buildToggleOption(
          'Show Grid',
          'Display horizontal grid lines',
          _showGrid,
          (value) => setState(() => _showGrid = value),
        ),
        const SizedBox(height: 12),
        _buildToggleOption(
          'Show Current Value',
          'Display the current value above the chart',
          _showLabels,
          (value) => setState(() => _showLabels = value),
        ),

        // Line/Area specific options
        if (showDotsApplicable) ...[
          const SizedBox(height: 12),
          _buildToggleOption(
            'Show Data Points',
            'Display dots at each data point',
            _showDots,
            (value) => setState(() => _showDots = value),
          ),
        ],
        if (smoothCurveApplicable) ...[
          const SizedBox(height: 12),
          _buildToggleOption(
            'Smooth Curve',
            'Use curved lines instead of straight',
            _smoothCurve,
            (value) => setState(() => _smoothCurve = value),
          ),
        ],
        if (fillAreaApplicable) ...[
          const SizedBox(height: 12),
          _buildToggleOption(
            'Fill Area',
            'Fill the area under the line',
            _fillArea,
            (value) => setState(() => _fillArea = value),
          ),
        ],

        const SizedBox(height: 24),
        // Advanced Options Header
        Text(
          'Advanced Options',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Data Points Slider - always applicable
        _buildDataPointsSlider(),

        // Thresholds - always applicable
        const SizedBox(height: 16),
        _buildThresholdSection(),

        // Min/Max Indicators - line/area charts only
        if (minMaxApplicable) ...[
          const SizedBox(height: 16),
          _buildToggleOption(
            'Show Min/Max',
            'Display markers at highest and lowest points',
            _showMinMax,
            (value) => setState(() => _showMinMax = value),
          ),
        ],

        // Gradient Fill - line/area charts only
        if (gradientApplicable) ...[
          const SizedBox(height: 16),
          _buildGradientFillOption(),
        ],

        // Data Normalization - always available but with context
        const SizedBox(height: 16),
        _buildNormalizationSelector(),

        // Comparison Baseline - line/area charts only
        if (baselineApplicable) ...[
          const SizedBox(height: 16),
          _buildBaselineSelector(),
        ],
      ],
    );
  }

  /// Get all active chart types based on current selection
  Set<ChartType> _getActiveChartTypes() {
    if (_mergeCharts && _selectedBindings.length > 1) {
      // When merged, the effective type depends on merge mode
      switch (_mergeMode) {
        case ChartMergeMode.overlay:
          return {ChartType.multiLine};
        case ChartMergeMode.stackedArea:
          return {ChartType.stackedArea};
        case ChartMergeMode.stackedBar:
          return {ChartType.stackedBar};
      }
    }

    // Non-merged: collect all unique chart types from bindings
    final types = <ChartType>{};
    if (_selectedBindings.isNotEmpty) {
      for (final binding in _selectedBindings) {
        types.add(_bindingChartTypes[binding] ?? _chartType);
      }
    } else {
      // No bindings selected yet, use the default chart type
      types.add(_chartType);
    }
    return types;
  }

  Widget _buildDataPointsSlider() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data Points',
                style: TextStyle(color: context.textPrimary, fontSize: 13),
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
          SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.accentColor,
              inactiveTrackColor: context.border,
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
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
              Text(
                '60',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientFillOption() {
    // Use centralized gradient picker colors
    final gradientColors = ChartColors.gradientPickerColors;

    // Get the binding paths to show gradients for
    List<String> bindingsToShow;
    if (_mergeCharts) {
      // In merged mode, use a synthetic "global" key since all series share Y-axis
      bindingsToShow = ['_merged'];
    } else {
      // In non-merged mode, show gradients for each binding separately
      bindingsToShow = _selectedBindings.toList();
    }

    // Get binding labels for display
    String getBindingLabel(String bindingPath) {
      if (bindingPath == '_merged') return 'All Series';
      final binding = BindingRegistry.bindings.firstWhere(
        (b) => b.path == bindingPath,
        orElse: () => BindingDefinition(
          path: bindingPath,
          label: bindingPath.split('.').last,
          description: '',
          category: BindingCategory.node,
          valueType: double,
        ),
      );
      return binding.label;
    }

    // Get series color for visual indicator
    Color getBindingColor(String bindingPath) {
      if (bindingPath == '_merged') return context.accentColor;
      final index = _selectedBindings.toList().indexOf(bindingPath);
      return _mergeColors[bindingPath] ??
          (index >= 0 ? ChartColors.forIndex(index) : context.accentColor);
    }

    // Check if any gradient is enabled
    final anyEnabled = bindingsToShow.any(
      (path) => (_seriesGradients[path]?.enabled ?? false),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: anyEnabled
            ? context.accentColor.withValues(alpha: 0.1)
            : context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: anyEnabled ? context.accentColor : context.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gradient Fill',
            style: TextStyle(color: context.textPrimary, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Color based on value (low → high)',
            style: TextStyle(color: context.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          // Per-series gradient sections
          ...bindingsToShow.map((bindingPath) {
            final config = _seriesGradients[bindingPath] ?? _GradientConfig();
            final label = getBindingLabel(bindingPath);
            final color = getBindingColor(bindingPath);

            return Container(
              margin: EdgeInsets.only(
                bottom: bindingPath != bindingsToShow.last ? 10 : 0,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: config.enabled
                    ? color.withValues(alpha: 0.1)
                    : color.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: config.enabled
                      ? color.withValues(alpha: 0.4)
                      : color.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Series header with toggle
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: config.enabled
                                ? color
                                : context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: config.enabled,
                        onChanged: (value) {
                          setState(() {
                            final current =
                                _seriesGradients[bindingPath] ??
                                _GradientConfig();
                            current.enabled = value;
                            _seriesGradients[bindingPath] = current;
                          });
                        },
                        activeTrackColor: color,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  // Color pickers when enabled
                  if (config.enabled) ...[
                    SizedBox(height: 10),
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
                                  color: context.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: gradientColors.map((c) {
                                  final isSelected =
                                      config.lowColor.toARGB32() ==
                                      c.toARGB32();
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        final current =
                                            _seriesGradients[bindingPath] ??
                                            _GradientConfig();
                                        current.lowColor = c;
                                        _seriesGradients[bindingPath] = current;
                                      });
                                    },
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? Border.all(
                                                color: SemanticColors.onMarker,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        // High color
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'High',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: gradientColors.map((c) {
                                  final isSelected =
                                      config.highColor.toARGB32() ==
                                      c.toARGB32();
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        final current =
                                            _seriesGradients[bindingPath] ??
                                            _GradientConfig();
                                        current.highColor = c;
                                        _seriesGradients[bindingPath] = current;
                                      });
                                    },
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? Border.all(
                                                color: SemanticColors.onMarker,
                                                width: 2,
                                              )
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
          }),
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Display',
            style: TextStyle(color: context.textPrimary, fontSize: 13),
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
                            : context.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : context.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          opt.$3,
                          style: TextStyle(
                            color: context.textSecondary,
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparison Baseline',
            style: TextStyle(color: context.textPrimary, fontSize: 13),
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
                            : context.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          opt.$3,
                          color: isSelected
                              ? context.accentColor
                              : context.textPrimary,
                          size: 18,
                        ),
                        SizedBox(height: 4),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : context.textPrimary,
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

  void _showThresholdEditor(String bindingPath, int index) {
    final thresholds = _seriesThresholds[bindingPath] ?? [];
    if (index >= thresholds.length) return;
    final threshold = thresholds[index];
    final valueController = TextEditingController(text: '${threshold.value}');
    final labelController = TextEditingController(text: threshold.label);
    Color selectedColor = threshold.color;

    // Use centralized threshold picker colors
    final thresholdColors = ChartColors.thresholdPickerColors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Threshold',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              final thresholds =
                                  _seriesThresholds[bindingPath] ?? [];
                              if (index < thresholds.length) {
                                thresholds.removeAt(index);
                                _seriesThresholds[bindingPath] = thresholds;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Color selection
                    Text(
                      'Color',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: thresholdColors.map((color) {
                        final isSelected =
                            selectedColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: SemanticColors.onMarker,
                                      width: 3,
                                    )
                                  : null,
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
                                ? const Icon(
                                    Icons.check,
                                    color: SemanticColors.onMarker,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),
                    // Value input
                    Text(
                      'Value',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter threshold value',
                        hintStyle: TextStyle(color: context.textSecondary),
                        filled: true,
                        fillColor: context.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: selectedColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Label input
                    Text(
                      'Label (optional)',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: labelController,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., "Warning", "Critical"',
                        hintStyle: TextStyle(color: context.textSecondary),
                        filled: true,
                        fillColor: context.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: selectedColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final parsedValue =
                              double.tryParse(valueController.text) ??
                              threshold.value;
                          setState(() {
                            final thresholds =
                                _seriesThresholds[bindingPath] ?? [];
                            if (index < thresholds.length) {
                              thresholds[index] = _ThresholdLine(
                                value: parsedValue,
                                color: selectedColor,
                                label: labelController.text,
                              );
                              _seriesThresholds[bindingPath] = thresholds;
                            }
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedColor,
                          foregroundColor: SemanticColors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Save Threshold',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdSection() {
    // Get the binding paths to show thresholds for
    List<String> bindingsToShow;
    if (_mergeCharts) {
      // In merged mode, use a synthetic "global" key since all series share Y-axis
      bindingsToShow = ['_merged'];
    } else {
      // In non-merged mode, show thresholds for each binding separately
      bindingsToShow = _selectedBindings.toList();
    }

    // Get binding labels for display
    String getBindingLabel(String bindingPath) {
      if (bindingPath == '_merged') return 'All Series';
      final binding = BindingRegistry.bindings.firstWhere(
        (b) => b.path == bindingPath,
        orElse: () => BindingDefinition(
          path: bindingPath,
          label: bindingPath.split('.').last,
          description: '',
          category: BindingCategory.node,
          valueType: double,
        ),
      );
      return binding.label;
    }

    // Get series color for visual indicator
    Color getBindingColor(String bindingPath) {
      if (bindingPath == '_merged') return context.accentColor;
      final index = _selectedBindings.toList().indexOf(bindingPath);
      return _mergeColors[bindingPath] ??
          (index >= 0 ? ChartColors.forIndex(index) : context.accentColor);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Threshold Lines',
            style: TextStyle(color: context.textPrimary, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Add reference lines at specific values',
            style: TextStyle(color: context.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          // Per-series threshold sections
          ...bindingsToShow.map((bindingPath) {
            final thresholds = _seriesThresholds[bindingPath] ?? [];
            final label = getBindingLabel(bindingPath);
            final color = getBindingColor(bindingPath);

            return Container(
              margin: EdgeInsets.only(
                bottom: bindingPath != bindingsToShow.last ? 12 : 0,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Series header with add button
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (thresholds.length < 3)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              final current =
                                  _seriesThresholds[bindingPath] ?? [];
                              current.add(
                                _ThresholdLine(
                                  value: 50,
                                  color: ChartColors.thresholdRed,
                                  label: '',
                                ),
                              );
                              _seriesThresholds[bindingPath] = current;
                            });
                            // Immediately open editor for new threshold
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final thresholdCount =
                                  (_seriesThresholds[bindingPath] ?? []).length;
                              _showThresholdEditor(
                                bindingPath,
                                thresholdCount - 1,
                              );
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: color, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  'Add',
                                  style: TextStyle(color: color, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Threshold items
                  if (thresholds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...thresholds.asMap().entries.map((entry) {
                      final index = entry.key;
                      final threshold = entry.value;
                      return GestureDetector(
                        onTap: () => _showThresholdEditor(bindingPath, index),
                        child: Container(
                          margin: EdgeInsets.only(top: index > 0 ? 6 : 0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: threshold.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: threshold.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Color indicator
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: threshold.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8),
                              // Value
                              Text(
                                '${threshold.value}',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              // Label if present
                              if (threshold.label.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: threshold.color.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    threshold.label,
                                    style: TextStyle(
                                      color: threshold.color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // Edit indicator
                              Icon(
                                Icons.edit,
                                color: context.textSecondary,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              // Delete button
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    final current =
                                        _seriesThresholds[bindingPath] ?? [];
                                    if (index < current.length) {
                                      current.removeAt(index);
                                      _seriesThresholds[bindingPath] = current;
                                    }
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  color: context.textSecondary,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merge Style',
            style: TextStyle(color: context.textPrimary, fontSize: 13),
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
                            : context.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          opt.$3,
                          color: isSelected
                              ? context.accentColor
                              : context.textPrimary,
                          size: 20,
                        ),
                        SizedBox(height: 4),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : context.textPrimary,
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
        color: context.card,
        border: Border(top: BorderSide(color: context.border)),
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
                                : context.textSecondary,
                            width: 2,
                          ),
                        ),
                        child: _addToDashboard
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: SemanticColors.onAccent,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Add to Dashboard',
                        style: TextStyle(
                          color: context.textPrimary,
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
                      foregroundColor: SemanticColors.onAccent,
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
    AppLogging.widgets('[WidgetWizard] _create called');

    // Check premium for new widgets (editing existing widgets is always allowed)
    final isNewWidget = widget.initialSchema == null;
    if (isNewWidget) {
      final hasPremium = await checkPremiumOrShowUpsell(
        context: context,
        ref: ref,
        feature: PremiumFeature.homeWidgets,
      );
      if (!hasPremium || !mounted) return;
    }

    // Final validation check
    final validationError = _getValidationError();
    if (validationError != null) {
      AppLogging.widgets('[WidgetWizard] Validation failed: $validationError');
      if (!mounted) return;
      showErrorSnackBar(context, validationError);
      return;
    }

    AppLogging.widgets('[WidgetWizard] Building final schema...');

    final schema = _buildFinalSchema();
    AppLogging.widgets(
      '[WidgetWizard] Schema built: id=${schema.id}, name=${schema.name}',
    );
    AppLogging.widgets('[WidgetWizard] Existing ID was: $_existingId');

    try {
      AppLogging.widgets('[WidgetWizard] Calling onSave callback...');
      await widget.onSave(schema);
      AppLogging.widgets('[WidgetWizard] onSave completed successfully');
    } catch (e, stack) {
      AppLogging.widgets('[WidgetWizard] ERROR in onSave: $e');
      AppLogging.widgets('[WidgetWizard] Stack trace: $stack');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save widget: $e');
      }
      return;
    }

    if (mounted) {
      AppLogging.widgets(
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
  // Schema Building - UNIFIED RENDER PIPELINE
  // ============================================================
  // CRITICAL: There is ONE render function for widgets.
  // No "creation render" vs "edit render" - just renderWidget(config).
  //
  // FOR NEW WIDGETS (no initialSchema):
  //   Both preview AND final save use _buildSchemaFromCurrentState().
  //   This builds a fresh widget from the wizard's template system.
  //
  // FOR EDITED WIDGETS (has initialSchema):
  //   Preview uses the ORIGINAL root structure from initialSchema.
  //   The wizard's template builders don't match how widgets were
  //   originally structured, so rebuilding would break them.
  //   Only metadata (name) is updated on save.
  // ============================================================

  /// Apply wizard appearance settings to an existing element tree
  /// This preserves the structure but updates colors, chart settings, etc.
  ElementSchema _applyAppearanceToElement(ElementSchema element) {
    AppLogging.widgets(
      '[APPLY] _applyAppearanceToElement type=${element.type}',
    );
    final colorHex =
        '#${_accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

    // Apply changes based on element type
    ElementSchema modified = element;

    if (element.type == ElementType.gauge) {
      AppLogging.widgets('[APPLY] Gauge: setting color=$colorHex');
      // Update gauge color
      modified = element.copyWith(gaugeColor: colorHex);
    } else if (element.type == ElementType.chart) {
      // CRITICAL: Determine gradient key based on WIZARD STATE (_mergeCharts),
      // not the element's existing properties. This ensures the UI state
      // (which uses _mergeCharts to determine keys) matches what we look up.
      String gradientKey;
      if (_mergeCharts) {
        // Merged mode: always use '_merged' key
        gradientKey = '_merged';
      } else {
        // Non-merged mode: use the binding path from the element
        if (element.chartBindingPath != null) {
          gradientKey = element.chartBindingPath!;
        } else if (element.binding?.path != null) {
          gradientKey = element.binding!.path;
        } else if (element.chartBindingPaths != null &&
            element.chartBindingPaths!.isNotEmpty) {
          // Fallback to first path if available
          gradientKey = element.chartBindingPaths!.first;
        } else {
          gradientKey = '';
        }
      }
      AppLogging.widgets('[APPLY] Chart: gradientKey=$gradientKey');
      AppLogging.widgets(
        '[APPLY] Chart: chartBindingPath=${element.chartBindingPath}',
      );
      AppLogging.widgets(
        '[APPLY] Chart: binding.path=${element.binding?.path}',
      );
      AppLogging.widgets(
        '[APPLY] Chart: chartBindingPaths=${element.chartBindingPaths}',
      );
      AppLogging.widgets('[APPLY] Chart: _showMinMax=$_showMinMax');
      AppLogging.widgets('[APPLY] Chart: _mergeCharts=$_mergeCharts');

      // Get gradient settings for this chart
      final gradient = _seriesGradients[gradientKey] ?? _GradientConfig();
      AppLogging.widgets('[APPLY] Chart: gradient.enabled=${gradient.enabled}');

      // Get threshold settings for this chart
      final thresholds = _seriesThresholds[gradientKey] ?? [];

      // Update ALL chart settings including gradient and advanced options
      // CRITICAL: Update chartBindingPaths with user's current selections
      final selectedBindingsList = _selectedBindings.toList();
      final newChartType = selectedBindingsList.length > 1 && _mergeCharts
          ? ChartType.multiLine
          : _chartType;
      AppLogging.widgets('[APPLY] Chart: Setting chartType=$newChartType');
      AppLogging.widgets('[APPLY] Chart: Setting chartShowMinMax=$_showMinMax');
      AppLogging.widgets(
        '[APPLY] Chart: Setting chartGradientFill=${gradient.enabled}',
      );
      AppLogging.widgets(
        '[APPLY] Chart: Setting chartBindingPaths=$selectedBindingsList',
      );

      // CRITICAL: Build chartLegendColors from _mergeColors for series colors
      final legendColors = <String>[];
      for (final path in selectedBindingsList) {
        final color = _mergeColors[path];
        if (color != null) {
          legendColors.add(_colorToHex(color));
        } else {
          // Use default color based on index
          final index = selectedBindingsList.indexOf(path);
          legendColors.add(_colorToHex(_getDefaultColorForIndex(index)));
        }
      }
      AppLogging.widgets(
        '[APPLY] Chart: Setting chartLegendColors=$legendColors',
      );

      // For non-merged single-binding charts, also set the style.textColor
      // because the renderer uses style.textColor for single-series charts
      String? chartTextColor;
      if (!_mergeCharts && element.binding?.path != null) {
        final bindingPath = element.binding!.path;
        final bindingIndex = selectedBindingsList.indexOf(bindingPath);
        final chartColor =
            _mergeColors[bindingPath] ??
            (bindingIndex >= 0
                ? _getDefaultColorForIndex(bindingIndex)
                : _accentColor);
        chartTextColor = _colorToHex(chartColor);
        AppLogging.widgets(
          '[APPLY] Chart: Non-merged chart for $bindingPath, setting textColor=$chartTextColor',
        );
      }

      modified = element.copyWith(
        chartType: newChartType,
        chartShowGrid: _showGrid,
        chartShowDots: _showDots,
        chartCurved: _smoothCurve,
        chartMaxPoints: _dataPoints,
        chartMergeMode: _mergeMode,
        chartNormalization: _normalization,
        chartBaseline: _baseline,
        chartShowMinMax: _showMinMax,
        chartGradientFill: gradient.enabled,
        chartGradientLowColor: _colorToHex(gradient.lowColor),
        chartGradientHighColor: _colorToHex(gradient.highColor),
        chartThresholds: thresholds.map((t) => t.value).toList(),
        chartThresholdColors: thresholds
            .map((t) => _colorToHex(t.color))
            .toList(),
        chartThresholdLabels: thresholds.map((t) => t.label).toList(),
        // CRITICAL: Update bindings and colors with user selections
        chartBindingPaths: selectedBindingsList,
        chartLegendColors: legendColors,
        // For non-merged charts, also update style.textColor
        style: chartTextColor != null
            ? element.style.copyWith(textColor: chartTextColor)
            : element.style,
      );
      AppLogging.widgets(
        '[APPLY] Chart: modified.chartShowMinMax=${modified.chartShowMinMax}',
      );
    } else if (element.type == ElementType.text &&
        element.style.textColor != null) {
      // Update accent-colored text (but not all text - preserve labels)
      final originalColor = _hexToColor(element.style.textColor);
      if (originalColor != null && _isAccentColor(originalColor)) {
        modified = element.copyWith(
          style: element.style.copyWith(textColor: colorHex),
        );
      }
    }

    // Recursively apply to children, filtering out label elements if needed
    if (element.children.isNotEmpty) {
      List<ElementSchema> filteredChildren = element.children;

      // If _showLabels is false, filter out label-style text elements
      // Labels are text elements with static text (no binding) - they're descriptors
      if (!_showLabels) {
        filteredChildren = element.children.where((child) {
          // Keep the element unless it's a label text element
          if (child.type == ElementType.text &&
              child.text != null &&
              child.binding == null) {
            // This is a static label text element - filter it out
            return false;
          }
          return true;
        }).toList();
      }

      final updatedChildren = filteredChildren
          .map(_applyAppearanceToElement)
          .toList();
      modified = modified.copyWith(children: updatedChildren);
    }

    return modified;
  }

  /// Check if the template has been changed from the original
  bool _hasTemplateChanged() {
    if (widget.initialSchema == null) return false;
    final originalTags = widget.initialSchema!.tags;
    final currentTemplateId = _selectedTemplate?.id;
    if (currentTemplateId == null) return false;
    // Template changed if the current template id is not in original tags
    return !originalTags.contains(currentTemplateId);
  }

  /// Check if the actions have been changed from the original (for actions template)
  bool _haveActionsChanged() {
    if (_originalActions == null) return false;
    // Check if sets are different (different size or different contents)
    if (_selectedActions.length != _originalActions!.length) return true;
    return !_selectedActions.containsAll(_originalActions!);
  }

  /// Check if the merge setting has been changed from the original (for graph template)
  bool _hasMergeChanged() {
    if (_originalMergeCharts == null) return false;
    return _mergeCharts != _originalMergeCharts;
  }

  /// Check if the layout style has been changed from the original
  bool _hasLayoutChanged() {
    if (_originalLayoutStyle == null) {
      AppLogging.widgets(
        '[LAYOUT_CHANGED] _originalLayoutStyle is null, returning false',
      );
      return false;
    }
    final changed = _layoutStyle != _originalLayoutStyle;
    AppLogging.widgets(
      '[LAYOUT_CHANGED] current=$_layoutStyle, original=$_originalLayoutStyle, changed=$changed',
    );
    return changed;
  }

  /// Check if the showLabels setting has been changed from the original
  bool _hasShowLabelsChanged() {
    if (_originalShowLabels == null) return false;
    return _showLabels != _originalShowLabels;
  }

  /// Check if bindings have been changed from the original (adding/removing data fields)
  bool _haveBindingsChanged() {
    if (_originalBindings == null) return false;
    // Check if sets are different (different size or different contents)
    if (_selectedBindings.length != _originalBindings!.length) return true;
    return !_selectedBindings.containsAll(_originalBindings!);
  }

  /// UNIFIED REBUILD PREDICATE
  /// This is the single source of truth for determining if a structural rebuild is needed.
  /// Used by both _buildPreviewSchema() and _buildFinalSchema() to ensure consistency.
  ///
  /// Returns true if the widget structure needs to be rebuilt from current wizard state.
  /// Returns false if only appearance changes can be applied to the existing structure.
  bool _requiresStructuralRebuild() {
    final isNewWidget = widget.initialSchema == null;
    final isGraphTemplate = _selectedTemplate?.id == 'graph';
    final isActionsTemplate = _selectedTemplate?.id == 'actions';

    // NEW WIDGETS: Always rebuild from current state
    if (isNewWidget) {
      AppLogging.widgets('[REBUILD] New widget - requires rebuild');
      return true;
    }

    // TEMPLATE CHANGED: Always rebuild to use new template structure
    if (_hasTemplateChanged()) {
      AppLogging.widgets('[REBUILD] Template changed - requires rebuild');
      return true;
    }

    // ACTIONS TEMPLATE: Rebuild if actions have changed
    if (isActionsTemplate && _haveActionsChanged()) {
      AppLogging.widgets('[REBUILD] Actions changed - requires rebuild');
      return true;
    }

    // GRAPH TEMPLATE: Rebuild if merge setting has changed
    if (isGraphTemplate && _hasMergeChanged()) {
      AppLogging.widgets('[REBUILD] Merge changed - requires rebuild');
      return true;
    }

    // ALL TEMPLATES: Rebuild if bindings have changed
    if (_haveBindingsChanged()) {
      AppLogging.widgets('[REBUILD] Bindings changed - requires rebuild');
      return true;
    }

    // ALL TEMPLATES: Rebuild if layout style has changed
    if (_hasLayoutChanged()) {
      AppLogging.widgets('[REBUILD] Layout changed - requires rebuild');
      return true;
    }

    // ALL TEMPLATES: Rebuild if showLabels has changed
    if (_hasShowLabelsChanged()) {
      AppLogging.widgets('[REBUILD] ShowLabels changed - requires rebuild');
      return true;
    }

    // No structural changes detected - can apply appearance updates only
    AppLogging.widgets('[REBUILD] No structural changes - appearance only');
    return false;
  }

  /// Build schema for LIVE PREVIEW
  /// Uses unified rebuild predicate to determine if structural rebuild is needed
  WidgetSchema _buildPreviewSchema() {
    AppLogging.widgets('[SCHEMA] _buildPreviewSchema called');

    final name = _nameController.text.trim().isEmpty
        ? 'My Widget'
        : _nameController.text.trim();

    // Use unified rebuild predicate
    if (_requiresStructuralRebuild()) {
      return _buildSchemaFromCurrentState(name);
    }

    // EDITED WIDGETS (no structural changes): Preserve structure but apply appearance changes
    AppLogging.widgets(
      '[SCHEMA] Using EDITED path - preserving structure with appearance updates',
    );
    final modifiedRoot = _applyAppearanceToElement(widget.initialSchema!.root);

    return WidgetSchema(
      id: _existingId ?? widget.initialSchema!.id,
      name: name,
      description: widget.initialSchema!.description,
      size: widget.initialSchema!.size,
      root: modifiedRoot,
      tags: widget.initialSchema!.tags,
    );
  }

  /// Build schema for FINAL SAVE
  /// Uses unified rebuild predicate to determine if structural rebuild is needed
  WidgetSchema _buildFinalSchema() {
    final name = _nameController.text.trim().isEmpty
        ? 'My Widget'
        : _nameController.text.trim();

    // Use unified rebuild predicate
    if (_requiresStructuralRebuild()) {
      return _buildSchemaFromCurrentState(name);
    }

    // EDITED WIDGETS (no structural changes): Preserve structure but apply appearance changes
    final modifiedRoot = _applyAppearanceToElement(widget.initialSchema!.root);

    return WidgetSchema(
      id: _existingId ?? widget.initialSchema!.id,
      name: name,
      description: widget.initialSchema!.description,
      size: widget.initialSchema!.size,
      root: modifiedRoot,
      tags: widget.initialSchema!.tags,
    );
  }

  /// UNIFIED SCHEMA BUILDER - the single source of truth for widget rendering
  /// Used by both preview and final save for consistent behavior
  /// This method ALWAYS rebuilds the widget tree from current wizard state:
  ///   - _selectedBindings (determines gauge/chart count)
  ///   - _selectedTemplate (determines visual style)
  ///   - _accentColor (determines colors)
  ///   - _layoutStyle (determines layout)
  ///   - _showLabels, _chartType, _mergeCharts, etc.
  WidgetSchema _buildSchemaFromCurrentState(String name) {
    // ALWAYS build from current wizard state - same logic for new and edit
    // This ensures preview matches final output and all changes are reflected
    // NO PARTIAL UPDATES - NO CONDITIONAL PATHS - NO REUSE OF OLD INSTANCES

    // Build children based on template type
    final children = <ElementSchema>[];

    if (_selectedTemplate?.id == 'actions') {
      // Build action buttons
      children.addAll(_buildActionElements());
      AppLogging.widgets(
        '[SCHEMA_BUILD] Actions template - ${children.length} action elements',
      );
    } else {
      // Build data display
      children.addAll(_buildDataElements(name));
      AppLogging.widgets(
        '[SCHEMA_BUILD] Data template - ${children.length} data elements',
      );
    }

    AppLogging.widgets(
      '[SCHEMA_BUILD] Layout style: $_layoutStyle, children.length: ${children.length}',
    );

    // Create root based on layout style
    final ElementSchema root;
    if (_selectedTemplate?.id == 'actions') {
      // Actions use vertical layout - each action is a row with icon + label
      AppLogging.widgets('[SCHEMA_BUILD] Using ACTIONS layout (column)');
      root = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 8, spacing: 8),
        children: children,
      );
    } else if (_selectedTemplate?.id == 'graph') {
      // Graph template: ALWAYS use column layout for chart stacking
      // Graph elements include headers, spacers, and charts that must be vertical
      AppLogging.widgets('[SCHEMA_BUILD] Using GRAPH layout (column)');
      root = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 4),
        children: children,
      );
    } else if (_layoutStyle == _LayoutStyle.horizontal) {
      AppLogging.widgets(
        '[SCHEMA_BUILD] Using HORIZONTAL layout, children: ${children.length}',
      );
      // Check if children have flex (like Status template cards)
      final hasFlexChildren =
          children.isNotEmpty && children.first.style.flex != null;
      // Use start alignment with flex children, spaceEvenly without
      final rowAlignment = hasFlexChildren
          ? MainAxisAlignmentOption.start
          : MainAxisAlignmentOption.spaceEvenly;
      AppLogging.widgets(
        '[SCHEMA_BUILD] HORIZONTAL: hasFlexChildren=$hasFlexChildren, rowAlignment=$rowAlignment',
      );

      // Horizontal layout - compact chips in rows of 3 with tight spacing
      if (children.length <= 3) {
        // Few items - single row with even spacing
        AppLogging.widgets('[SCHEMA_BUILD] HORIZONTAL: Single row (<=3 items)');
        AppLogging.widgets(
          '[SCHEMA_BUILD] HORIZONTAL row style: padding=8, spacing=6, mainAxis=$rowAlignment, crossAxis=center',
        );
        root = ElementSchema(
          type: ElementType.row,
          style: StyleSchema(
            padding: 8,
            spacing: 6,
            mainAxisAlignment: rowAlignment,
            crossAxisAlignment: CrossAxisAlignmentOption.center,
          ),
          children: children,
        );
      } else {
        // Many items - stack into rows of 3 with tight spacing
        AppLogging.widgets(
          '[SCHEMA_BUILD] HORIZONTAL: Multiple rows (>3 items)',
        );
        final rows = <ElementSchema>[];
        for (var i = 0; i < children.length; i += 3) {
          final rowItems = <ElementSchema>[];
          for (var j = i; j < i + 3 && j < children.length; j++) {
            rowItems.add(children[j]);
          }
          AppLogging.widgets(
            '[SCHEMA_BUILD] HORIZONTAL row $i: ${rowItems.length} items, mainAxis=$rowAlignment',
          );
          rows.add(
            ElementSchema(
              type: ElementType.row,
              style: StyleSchema(
                spacing: 6,
                mainAxisAlignment: rowAlignment,
                crossAxisAlignment: CrossAxisAlignmentOption.center,
              ),
              children: rowItems,
            ),
          );
        }
        AppLogging.widgets(
          '[SCHEMA_BUILD] HORIZONTAL: Created ${rows.length} rows',
        );
        root = ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 8, spacing: 6),
          children: rows,
        );
      }
    } else if (_layoutStyle == _LayoutStyle.grid) {
      AppLogging.widgets(
        '[SCHEMA_BUILD] Using GRID layout, children: ${children.length}',
      );
      // Grid layout - card-style 2-column layout with larger spacing
      if (children.isEmpty) {
        AppLogging.widgets('[SCHEMA_BUILD] GRID: Empty, showing placeholder');
        root = ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 12, spacing: 12),
          children: [
            ElementSchema(
              type: ElementType.text,
              text: 'No data selected',
              style: StyleSchema(
                textColor: _colorToHex(context.textSecondary),
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
          AppLogging.widgets(
            '[SCHEMA_BUILD] GRID row ${i ~/ 2}: ${rowChildren.length} items',
          );
          for (var j = 0; j < rowChildren.length; j++) {
            final child = rowChildren[j];
            AppLogging.widgets(
              '[SCHEMA_BUILD] GRID row child $j: type=${child.type}, flex=${child.style.flex}, expanded=${child.style.expanded}',
            );
          }
          rows.add(
            ElementSchema(
              type: ElementType.row,
              style: const StyleSchema(
                spacing: 12,
                // Use start alignment - children have flex:1 which handles equal distribution
                // Do NOT use spaceBetween with flex children (causes layout conflicts)
                // Do NOT use stretch cross-axis - causes unbounded height issues with flex children
                mainAxisAlignment: MainAxisAlignmentOption.start,
                crossAxisAlignment: CrossAxisAlignmentOption.start,
              ),
              children: rowChildren,
            ),
          );
        }
        AppLogging.widgets(
          '[SCHEMA_BUILD] GRID: Created ${rows.length} rows, mainAxis=start, crossAxis=start',
        );
        root = ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 12, spacing: 12),
          children: rows,
        );
      }
    } else {
      AppLogging.widgets(
        '[SCHEMA_BUILD] Using VERTICAL layout (default), children: ${children.length}',
      );
      root = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: children,
      );
    }

    AppLogging.widgets(
      '[SCHEMA_BUILD] Final root: type=${root.type}, children=${root.children.length}',
    );

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
    AppLogging.widgets(
      '[DATA_ELEMENTS] template=${_selectedTemplate?.id}, layout=$_layoutStyle',
    );
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
    AppLogging.widgets(
      '[GAUGE_ELEMENTS] START - layout=$_layoutStyle, bindings=${_selectedBindings.length}',
    );
    if (_selectedBindings.isEmpty) {
      return [
        ElementSchema(
          type: ElementType.text,
          text: 'Select up to 3 numeric values',
          style: StyleSchema(
            textColor: _colorToHex(context.textSecondary),
            fontSize: 13,
          ),
        ),
      ];
    }

    // Build a gauge column for each binding - layout affects sizing and structure
    final gaugeColumns = <ElementSchema>[];

    for (final bindingPath in _selectedBindings) {
      // Build element from registry
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

      // Adjust size based on layout style and number of gauges
      late final double gaugeSize;
      late final double valueFontSize;
      late final double labelFontSize;
      late final int? flexValue;
      late final double padding;
      late final double? borderRadius;
      late final String? backgroundColor;
      late final double? borderWidth;
      late final String? borderColor;

      if (_layoutStyle == _LayoutStyle.horizontal) {
        // HORIZONTAL: Smaller, compact gauges with flex for distribution
        AppLogging.widgets(
          '[GAUGE_ELEMENTS] HORIZONTAL: compact gauge with flex=1 for $bindingPath',
        );
        gaugeSize = 50.0;
        valueFontSize = 14.0;
        labelFontSize = 9.0;
        flexValue = 1;
        padding = 4.0;
        borderRadius = 8.0;
        backgroundColor = '#1A1A2E';
        borderWidth = null;
        borderColor = null;
      } else if (_layoutStyle == _LayoutStyle.grid) {
        // GRID: Medium gauges with borders and flex
        AppLogging.widgets(
          '[GAUGE_ELEMENTS] GRID: bordered gauge with flex=1 for $bindingPath',
        );
        gaugeSize = 70.0;
        valueFontSize = 20.0;
        labelFontSize = 11.0;
        flexValue = 1;
        padding = 8.0;
        borderRadius = 12.0;
        backgroundColor = '#1A1A2E';
        borderWidth = 1.0;
        borderColor = '#2D2D44';
      } else {
        // VERTICAL: Original sizing based on count
        AppLogging.widgets(
          '[GAUGE_ELEMENTS] VERTICAL: standard gauge for $bindingPath',
        );
        gaugeSize = _selectedBindings.length == 1 ? 100.0 : 70.0;
        valueFontSize = _selectedBindings.length == 1 ? 28.0 : 20.0;
        labelFontSize = _selectedBindings.length == 1 ? 13.0 : 11.0;
        flexValue = null;
        padding = 0.0;
        borderRadius = null;
        backgroundColor = null;
        borderWidth = null;
        borderColor = null;
      }

      gaugeColumns.add(
        ElementSchema(
          type: ElementType.column,
          style: StyleSchema(
            crossAxisAlignment: CrossAxisAlignmentOption.center,
            padding: padding > 0 ? padding : null,
            borderRadius: borderRadius,
            backgroundColor: backgroundColor,
            borderWidth: borderWidth,
            borderColor: borderColor,
            flex: flexValue,
          ),
          children: [
            // Value text above gauge (controlled by _showLabels)
            if (_showLabels) ...[
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
                style: StyleSchema(
                  height: _layoutStyle == _LayoutStyle.horizontal ? 4 : 8,
                ),
              ),
            ],
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
            // Label below gauge (controlled by _showLabels)
            if (_showLabels) ...[
              ElementSchema(
                type: ElementType.spacer,
                style: StyleSchema(
                  height: _layoutStyle == _LayoutStyle.horizontal ? 4 : 8,
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: labelFontSize,
                  fontWeight: 'w500',
                ),
              ),
            ],
          ],
        ),
      );
    }

    // If single gauge and vertical layout, return centered column
    if (gaugeColumns.length == 1 && _layoutStyle == _LayoutStyle.vertical) {
      return gaugeColumns;
    }

    // Multiple gauges or non-vertical: wrap in a row
    // Use start alignment when children have flex (horizontal/grid)
    final hasFlexChildren = _layoutStyle != _LayoutStyle.vertical;
    return [
      ElementSchema(
        type: ElementType.row,
        style: StyleSchema(
          mainAxisAlignment: hasFlexChildren
              ? MainAxisAlignmentOption.start
              : MainAxisAlignmentOption.spaceEvenly,
          spacing: hasFlexChildren ? 8 : null,
        ),
        children: gaugeColumns,
      ),
    ];
  }

  /// Graph: Line, area, bar, or sparkline charts
  List<ElementSchema> _buildGraphElements(String name) {
    AppLogging.widgets('[GRAPH] === _buildGraphElements ===');
    AppLogging.widgets('[GRAPH] _layoutStyle=$_layoutStyle');
    AppLogging.widgets('[GRAPH] _mergeCharts=$_mergeCharts');
    AppLogging.widgets('[GRAPH] _showMinMax=$_showMinMax');
    AppLogging.widgets('[GRAPH] _selectedBindings=$_selectedBindings');
    AppLogging.widgets('[GRAPH] _mergeColors=$_mergeColors');
    AppLogging.widgets('[GRAPH] _seriesGradients=$_seriesGradients');

    if (_selectedBindings.isEmpty) {
      return [
        ElementSchema(
          type: ElementType.text,
          text: 'Select data to graph',
          style: StyleSchema(
            textColor: _colorToHex(context.textSecondary),
            fontSize: 13,
          ),
        ),
      ];
    }

    final children = <ElementSchema>[];

    // Use centralized chart series colors
    final defaultChartColors = ChartColors.seriesColors;

    // Merge mode: single chart with multiple data series
    if (_mergeCharts && _selectedBindings.length > 1) {
      AppLogging.widgets('[GRAPH] Building MERGED chart');
      // Collect labels and colors for legend
      final legendLabels = <String>[];
      final legendColors = <String>[];
      final bindingsList = _selectedBindings.toList();

      for (int i = 0; i < bindingsList.length; i++) {
        final bindingPath = bindingsList[i];

        // Use custom label if extracted from original schema, otherwise lookup from registry
        String label;
        if (_bindingLabels.containsKey(bindingPath)) {
          label = _bindingLabels[bindingPath]!;
        } else {
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
          label = binding.label;
        }
        legendLabels.add(label);

        // Use user-selected color or fall back to default
        final color =
            _mergeColors[bindingPath] ??
            defaultChartColors[i % defaultChartColors.length];
        AppLogging.widgets(
          '[GRAPH] Merged binding $bindingPath color=${color.toARGB32().toRadixString(16)}',
        );
        legendColors.add(_colorToHex(color));
      }
      AppLogging.widgets('[GRAPH] legendColors=$legendColors');

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
                        textColor: _colorToHex(context.textSecondary),
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
      // For merged charts, use the "_merged" key for thresholds and gradient
      final mergedThresholds = _seriesThresholds['_merged'] ?? [];
      final mergedGradient = _seriesGradients['_merged'] ?? _GradientConfig();
      AppLogging.widgets('[GRAPH] Creating merged chart element');
      AppLogging.widgets('[GRAPH] chartShowMinMax=$_showMinMax');
      AppLogging.widgets('[GRAPH] chartLegendColors=$legendColors');
      AppLogging.widgets(
        '[GRAPH] mergedGradient.enabled=${mergedGradient.enabled}',
      );
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
          chartGradientFill: mergedGradient.enabled,
          chartGradientLowColor: _colorToHex(mergedGradient.lowColor),
          chartGradientHighColor: _colorToHex(mergedGradient.highColor),
          chartThresholds: mergedThresholds.map((t) => t.value).toList(),
          chartThresholdColors: mergedThresholds
              .map((t) => _colorToHex(t.color))
              .toList(),
          chartThresholdLabels: mergedThresholds.map((t) => t.label).toList(),
          style: StyleSchema(
            height: 120.0,
            textColor: _colorToHex(_accentColor),
          ),
        ),
      );
    } else {
      AppLogging.widgets(
        '[GRAPH] Building NON-MERGED charts (separate per binding)',
      );
      // Non-merged mode: separate chart per binding
      for (final bindingPath in _selectedBindings) {
        AppLogging.widgets('[GRAPH] Building chart for binding: $bindingPath');
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
        // CRITICAL: multiLine is only valid for merged charts - convert to line for single-series
        ChartType bindingChartType =
            _bindingChartTypes[bindingPath] ?? _chartType;
        if (bindingChartType == ChartType.multiLine ||
            bindingChartType == ChartType.stackedArea ||
            bindingChartType == ChartType.stackedBar) {
          bindingChartType = ChartType.line; // Fallback for multi-series types
        }
        // Note: Chart type is used directly - Area shows fill, Line does not
        AppLogging.widgets('[GRAPH] bindingChartType=$bindingChartType');

        // Get color for this specific binding (series colors)
        final bindingIndex = _selectedBindings.toList().indexOf(bindingPath);
        // Use centralized chart series colors
        final bindingColor =
            _mergeColors[bindingPath] ??
            (bindingIndex >= 0
                ? ChartColors.forIndex(bindingIndex)
                : _accentColor);

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
                    textColor: _colorToHex(context.textSecondary),
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
                    textColor: _colorToHex(bindingColor),
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
        // Get per-series thresholds and gradient for this specific binding
        final bindingThresholds = _seriesThresholds[bindingPath] ?? [];
        final bindingGradient =
            _seriesGradients[bindingPath] ?? _GradientConfig();
        AppLogging.widgets('[GRAPH] Non-merged chart for $bindingPath:');
        AppLogging.widgets('[GRAPH]   chartShowMinMax=$_showMinMax');
        AppLogging.widgets(
          '[GRAPH]   bindingGradient.enabled=${bindingGradient.enabled}',
        );
        AppLogging.widgets(
          '[GRAPH]   bindingColor=${bindingColor.toARGB32().toRadixString(16)}',
        );
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
            chartGradientFill: bindingGradient.enabled,
            chartGradientLowColor: _colorToHex(bindingGradient.lowColor),
            chartGradientHighColor: _colorToHex(bindingGradient.highColor),
            chartThresholds: bindingThresholds.map((t) => t.value).toList(),
            chartThresholdColors: bindingThresholds
                .map((t) => _colorToHex(t.color))
                .toList(),
            chartThresholdLabels: bindingThresholds
                .map((t) => t.label)
                .toList(),
            style: StyleSchema(
              height: _selectedBindings.length == 1 ? 100.0 : 70.0,
              textColor: _colorToHex(bindingColor),
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
    AppLogging.widgets(
      '[INFO_ELEMENTS] START - layout=$_layoutStyle, bindings=${_selectedBindings.length}',
    );
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No info selected',
          style: StyleSchema(
            textColor: _colorToHex(context.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    // Info template creates label + value for each binding
    // Layout style affects how these are wrapped and styled
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);

      if (_layoutStyle == _LayoutStyle.horizontal) {
        // HORIZONTAL: Compact card with label and value stacked
        AppLogging.widgets(
          '[INFO_ELEMENTS] HORIZONTAL: compact card with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: 8,
              backgroundColor: _colorToHex(context.card.withValues(alpha: 0.3)),
              borderRadius: 8,
              alignment: AlignmentOption.center,
              spacing: 2,
              flex: 1, // Equal distribution in horizontal rows
            ),
            children: [
              // Label
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 10,
                ),
              ),
              // Value
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
                  fontWeight: 'w500',
                ),
              ),
            ],
          ),
        );
      } else if (_layoutStyle == _LayoutStyle.grid) {
        // GRID: Card-style tile with label and large value
        AppLogging.widgets(
          '[INFO_ELEMENTS] GRID: card tile with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: 12,
              backgroundColor: _colorToHex(context.card.withValues(alpha: 0.6)),
              borderRadius: 12,
              borderWidth: 1,
              borderColor: _colorToHex(context.border),
              alignment: AlignmentOption.center,
              spacing: 4,
              flex: 1, // CRITICAL: flex for equal distribution in grid rows
            ),
            children: [
              // Label
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 11,
                  fontWeight: 'w500',
                ),
              ),
              // Large value
              ElementSchema(
                type: ElementType.text,
                binding: BindingSchema(
                  path: bindingPath,
                  format: binding.defaultFormat,
                  defaultValue: '--',
                ),
                style: StyleSchema(
                  textColor: _colorToHex(_accentColor),
                  fontSize: 20,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
        );
      } else {
        // VERTICAL (default): Label + value row with subtle styling
        AppLogging.widgets('[INFO_ELEMENTS] VERTICAL: row for $bindingPath');
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
                  textColor: _colorToHex(context.textSecondary),
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
                  fontSize: 13,
                  fontWeight: 'w500',
                ),
              ),
            ],
          ),
        );
      }
    }

    AppLogging.widgets(
      '[INFO_ELEMENTS] END - created ${children.length} elements',
    );
    return children;
  }

  /// Location: Map-style layout with coordinates and compass
  List<ElementSchema> _buildLocationElements(String name) {
    AppLogging.widgets(
      '[LOCATION_ELEMENTS] START - layout=$_layoutStyle, bindings=${_selectedBindings.length}',
    );
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No location data selected',
          style: StyleSchema(
            textColor: _colorToHex(context.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    // Coordinate-style display - layout affects structure
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      final isCoord =
          bindingPath.contains('latitude') || bindingPath.contains('longitude');
      final valueColor = isCoord ? '#A78BFA' : '#FFFFFF';

      if (_layoutStyle == _LayoutStyle.horizontal) {
        // HORIZONTAL: Compact card with icon, label, value stacked vertically
        AppLogging.widgets(
          '[LOCATION_ELEMENTS] HORIZONTAL: compact card with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(
              crossAxisAlignment: CrossAxisAlignmentOption.center,
              padding: 6,
              borderRadius: 8,
              backgroundColor: '#1A1A2E',
              flex: 1,
            ),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: isCoord ? 'explore' : 'near_me',
                iconSize: 12,
                style: const StyleSchema(textColor: '#A78BFA'),
              ),
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 9,
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: BindingSchema(
                  path: bindingPath,
                  format: isCoord ? '%.4f' : binding.defaultFormat,
                  defaultValue: '--',
                ),
                style: StyleSchema(
                  textColor: valueColor,
                  fontSize: 12,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
        );
      } else if (_layoutStyle == _LayoutStyle.grid) {
        // GRID: Larger card with border, icon, label, value
        AppLogging.widgets(
          '[LOCATION_ELEMENTS] GRID: bordered card with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(
              crossAxisAlignment: CrossAxisAlignmentOption.center,
              padding: 10,
              borderRadius: 12,
              backgroundColor: '#1A1A2E',
              borderWidth: 1,
              borderColor: '#2D2D44',
              flex: 1,
            ),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: isCoord ? 'explore' : 'near_me',
                iconSize: 16,
                style: const StyleSchema(textColor: '#A78BFA'),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(height: 4),
              ),
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 11,
                ),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(height: 2),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: BindingSchema(
                  path: bindingPath,
                  format: isCoord ? '%.5f' : binding.defaultFormat,
                  defaultValue: '--',
                ),
                style: StyleSchema(
                  textColor: valueColor,
                  fontSize: 18,
                  fontWeight: 'w700',
                ),
              ),
            ],
          ),
        );
      } else {
        // VERTICAL: Row with icon+label on left, value on right
        AppLogging.widgets(
          '[LOCATION_ELEMENTS] VERTICAL: row with spaceBetween for $bindingPath',
        );
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
                      textColor: _colorToHex(context.textSecondary),
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
                  textColor: valueColor,
                  fontSize: 13,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
        );
      }
    }

    return children;
  }

  /// Environment: Weather card style with icons for each reading
  List<ElementSchema> _buildEnvironmentElements(String name) {
    AppLogging.widgets(
      '[ENVIRONMENT_ELEMENTS] START - layout=$_layoutStyle, bindings=${_selectedBindings.length}',
    );
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No sensor data selected',
          style: StyleSchema(
            textColor: _colorToHex(context.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    // Environment readings with appropriate icons - layout affects structure
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      final iconName = _getEnvironmentIcon(bindingPath);
      final valueColor = _getEnvironmentColor(bindingPath);

      if (_layoutStyle == _LayoutStyle.horizontal) {
        // HORIZONTAL: Compact card with icon, label, value stacked vertically
        AppLogging.widgets(
          '[ENVIRONMENT_ELEMENTS] HORIZONTAL: compact card with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(
              crossAxisAlignment: CrossAxisAlignmentOption.center,
              padding: 6,
              borderRadius: 8,
              backgroundColor: '#1A1A2E',
              flex: 1,
            ),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: iconName,
                iconSize: 14,
                style: StyleSchema(textColor: valueColor),
              ),
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 9,
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
                  textColor: valueColor,
                  fontSize: 13,
                  fontWeight: 'w700',
                ),
              ),
            ],
          ),
        );
      } else if (_layoutStyle == _LayoutStyle.grid) {
        // GRID: Larger card with border, icon, label, value
        AppLogging.widgets(
          '[ENVIRONMENT_ELEMENTS] GRID: bordered card with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(
              crossAxisAlignment: CrossAxisAlignmentOption.center,
              padding: 10,
              borderRadius: 12,
              backgroundColor: '#1A1A2E',
              borderWidth: 1,
              borderColor: '#2D2D44',
              flex: 1,
            ),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: iconName,
                iconSize: 20,
                style: StyleSchema(textColor: valueColor),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(height: 4),
              ),
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 11,
                ),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(height: 2),
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
                  fontSize: 20,
                  fontWeight: 'w700',
                ),
              ),
            ],
          ),
        );
      } else {
        // VERTICAL: Row with icon+label on left, value on right
        AppLogging.widgets(
          '[ENVIRONMENT_ELEMENTS] VERTICAL: row with spaceBetween for $bindingPath',
        );
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
                      textColor: _colorToHex(context.textSecondary),
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
    }

    return children;
  }

  /// Status: Dashboard-style with progress bars
  List<ElementSchema> _buildStatusElements(String name) {
    AppLogging.widgets(
      '[STATUS_ELEMENTS] START - layout=$_layoutStyle, bindings=${_selectedBindings.length}',
    );
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No data selected',
          style: StyleSchema(
            textColor: _colorToHex(context.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    // Status template creates label + value + gauge for each binding
    // Layout style affects how these are wrapped and styled
    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      final isNumeric = binding.valueType == int || binding.valueType == double;

      if (_layoutStyle == _LayoutStyle.horizontal) {
        // HORIZONTAL: Compact card with label, value, and small gauge
        // Uses flex:1 for equal distribution in rows
        AppLogging.widgets(
          '[STATUS_ELEMENTS] HORIZONTAL: compact card with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: 8,
              backgroundColor: _colorToHex(context.card.withValues(alpha: 0.3)),
              borderRadius: 8,
              alignment: AlignmentOption.center,
              spacing: 4,
              flex: 1, // Equal distribution in horizontal rows
            ),
            children: [
              // Label
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 10,
                ),
              ),
              // Value
              ElementSchema(
                type: ElementType.text,
                binding: BindingSchema(
                  path: bindingPath,
                  format: binding.defaultFormat,
                  defaultValue: '--',
                ),
                style: StyleSchema(
                  textColor: _colorToHex(_accentColor),
                  fontSize: 16,
                  fontWeight: 'w600',
                ),
              ),
              // Small gauge for numeric values
              if (isNumeric)
                ElementSchema(
                  type: ElementType.gauge,
                  gaugeType: GaugeType.linear,
                  gaugeMin: binding.minValue ?? 0,
                  gaugeMax: binding.maxValue ?? 100,
                  gaugeColor: _colorToHex(_accentColor),
                  binding: BindingSchema(path: bindingPath),
                  style: const StyleSchema(height: 4),
                ),
            ],
          ),
        );
      } else if (_layoutStyle == _LayoutStyle.grid) {
        // GRID: Card-style tile with label, large value, and gauge
        AppLogging.widgets(
          '[STATUS_ELEMENTS] GRID: card tile with flex=1 for $bindingPath',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: 12,
              backgroundColor: _colorToHex(context.card.withValues(alpha: 0.6)),
              borderRadius: 12,
              borderWidth: 1,
              borderColor: _colorToHex(context.border),
              alignment: AlignmentOption.center,
              spacing: 6,
              flex: 1, // CRITICAL: flex for equal distribution in grid rows
            ),
            children: [
              // Label
              ElementSchema(
                type: ElementType.text,
                text: binding.label,
                style: StyleSchema(
                  textColor: _colorToHex(context.textSecondary),
                  fontSize: 11,
                  fontWeight: 'w500',
                ),
              ),
              // Large value
              ElementSchema(
                type: ElementType.text,
                binding: BindingSchema(
                  path: bindingPath,
                  format: binding.defaultFormat,
                  defaultValue: '--',
                ),
                style: StyleSchema(
                  textColor: _colorToHex(_accentColor),
                  fontSize: 22,
                  fontWeight: 'w700',
                ),
              ),
              // Gauge for numeric values
              if (isNumeric)
                ElementSchema(
                  type: ElementType.gauge,
                  gaugeType: GaugeType.linear,
                  gaugeMin: binding.minValue ?? 0,
                  gaugeMax: binding.maxValue ?? 100,
                  gaugeColor: _colorToHex(_accentColor),
                  binding: BindingSchema(path: bindingPath),
                  style: const StyleSchema(height: 6),
                ),
            ],
          ),
        );
      } else {
        // VERTICAL (default): Label + value row, then gauge below
        AppLogging.widgets(
          '[STATUS_ELEMENTS] VERTICAL: row + gauge for $bindingPath',
        );
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
                  textColor: _colorToHex(context.textSecondary),
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
    }

    AppLogging.widgets(
      '[STATUS_ELEMENTS] END - created ${children.length} elements',
    );
    return children;
  }

  /// Generic fallback for blank/custom templates
  List<ElementSchema> _buildGenericElements(String name) {
    AppLogging.widgets(
      '[GENERIC_ELEMENTS] START - layout=$_layoutStyle, bindings=${_selectedBindings.length}, showLabels=$_showLabels',
    );
    final children = <ElementSchema>[];

    if (_selectedBindings.isEmpty) {
      AppLogging.widgets('[GENERIC_ELEMENTS] No bindings selected');
      children.add(
        ElementSchema(
          type: ElementType.text,
          text: 'No data selected',
          style: StyleSchema(
            textColor: _colorToHex(context.textSecondary),
            fontSize: 13,
          ),
        ),
      );
      return children;
    }

    for (final bindingPath in _selectedBindings) {
      final binding = _getBinding(bindingPath);
      AppLogging.widgets(
        '[GENERIC_ELEMENTS] Building element for binding: $bindingPath, layout=$_layoutStyle',
      );

      if (_layoutStyle == _LayoutStyle.horizontal) {
        // HORIZONTAL: Compact inline chips - small footprint, value-focused
        // These will be arranged 3-per-row in _buildSchemaFromCurrentState
        AppLogging.widgets(
          '[GENERIC_ELEMENTS] HORIZONTAL style: padding=6, borderRadius=6, fontSize=9/14, NO flex, NO border',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: 6,
              backgroundColor: _colorToHex(context.card.withValues(alpha: 0.3)),
              borderRadius: 6,
              alignment: AlignmentOption.center,
              spacing: 2,
            ),
            children: [
              if (_showLabels)
                ElementSchema(
                  type: ElementType.text,
                  text: binding.label,
                  style: StyleSchema(
                    textColor: _colorToHex(context.textSecondary),
                    fontSize: 9,
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
      } else if (_layoutStyle == _LayoutStyle.grid) {
        // GRID: Card-style tiles - larger, more visual presence
        // These will be arranged 2-per-row in _buildSchemaFromCurrentState
        // NOTE: Do NOT use expanded:true here - it conflicts with spaceBetween in rows
        // Instead, use flex on children and let the row handle distribution
        AppLogging.widgets(
          '[GENERIC_ELEMENTS] GRID style: padding=16, borderRadius=12, fontSize=12/24, flex=1, HAS border',
        );
        children.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: 16,
              backgroundColor: _colorToHex(context.card.withValues(alpha: 0.6)),
              borderRadius: 12,
              borderWidth: 1,
              borderColor: _colorToHex(context.border),
              alignment: AlignmentOption.center,
              spacing: 8,
              flex:
                  1, // Use flex instead of expanded for proper row distribution
            ),
            children: [
              if (_showLabels)
                ElementSchema(
                  type: ElementType.text,
                  text: binding.label,
                  style: StyleSchema(
                    textColor: _colorToHex(context.textSecondary),
                    fontSize: 12,
                    fontWeight: 'w500',
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
                  fontSize: 24,
                  fontWeight: 'w700',
                ),
              ),
            ],
          ),
        );
      } else if (_showLabels) {
        AppLogging.widgets(
          '[GENERIC_ELEMENTS] VERTICAL style (with labels): row with spaceBetween, fontSize=13/14',
        );
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
                  textColor: _colorToHex(context.textSecondary),
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
        AppLogging.widgets(
          '[GENERIC_ELEMENTS] VERTICAL style (no labels): single text element',
        );
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
            textColor: _colorToHex(context.textSecondary),
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
          backgroundColor: _colorToHex(context.card),
          borderRadius: 12,
          borderWidth: 1,
          borderColor: _colorToHex(context.border),
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
