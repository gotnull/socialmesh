import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../renderer/widget_renderer.dart';
import '../editor/widget_editor_screen.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';

/// Widget creation wizard - guides users through building a widget step-by-step
class WidgetWizardScreen extends ConsumerStatefulWidget {
  final Future<void> Function(WidgetSchema schema) onSave;

  const WidgetWizardScreen({super.key, required this.onSave});

  @override
  ConsumerState<WidgetWizardScreen> createState() => _WidgetWizardScreenState();
}

class _WidgetWizardScreenState extends ConsumerState<WidgetWizardScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Step 1: Template selection
  _WidgetTemplate? _selectedTemplate;

  // Step 2: Basics
  final _nameController = TextEditingController();
  CustomWidgetSize _selectedSize = CustomWidgetSize.medium;

  // Step 3: Data selection
  final Set<String> _selectedBindings = {};

  // Step 4: Appearance
  Color _accentColor = const Color(0xFF4F6AF6);
  bool _showLabels = true;
  _LayoutStyle _layoutStyle = _LayoutStyle.vertical;

  final List<_WizardStep> _steps = [
    _WizardStep(
      title: 'Choose a Style',
      subtitle: 'How do you want your widget to look?',
      icon: Icons.style,
    ),
    _WizardStep(
      title: 'Name & Size',
      subtitle: 'Give it a name and pick a size',
      icon: Icons.text_fields,
    ),
    _WizardStep(
      title: 'Pick Your Data',
      subtitle: 'What info do you want to see?',
      icon: Icons.data_usage,
    ),
    _WizardStep(
      title: 'Make it Yours',
      subtitle: 'Customize colors and layout',
      icon: Icons.palette,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _steps[_currentStep].title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _goBack,
              child: Text(
                'Back',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
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
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildTemplateStep(),
                _buildBasicsStep(),
                _buildDataStep(),
                _buildAppearanceStep(),
              ],
            ),
          ),
          // Bottom actions
          _buildBottomActions(),
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
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
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
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent
                                  ? context.accentColor
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
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
          onTap: () => setState(() => _selectedTemplate = template),
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
        description: 'Buttons for common tasks like messaging',
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
  // STEP 2: Basics (Name & Size)
  // ============================================================
  Widget _buildBasicsStep() {
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
        const SizedBox(height: 32),
        // Size selection
        Text(
          'Widget Size',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        ..._buildSizeOptions(),
      ],
    );
  }

  List<Widget> _buildSizeOptions() {
    final sizes = [
      (CustomWidgetSize.medium, 'Medium', 'Good for most widgets', 120.0),
      (CustomWidgetSize.large, 'Large', 'More space for details', 180.0),
    ];

    return sizes.map((size) {
      final isSelected = _selectedSize == size.$1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedSize = size.$1),
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
                  // Size preview
                  Container(
                    width: 48,
                    height: size.$4 / 3,
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          size.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          size.$3,
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
    }).toList();
  }

  // ============================================================
  // STEP 3: Data Selection
  // ============================================================
  Widget _buildDataStep() {
    // Group bindings by category
    final categories = <BindingCategory, List<BindingDefinition>>{};
    for (final binding in BindingRegistry.bindings) {
      categories.putIfAbsent(binding.category, () => []).add(binding);
    }

    // Filter to show relevant categories based on template
    final relevantCategories = _getRelevantCategories();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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

  Widget _buildDataCategory(
    String title,
    IconData icon,
    Color color,
    List<BindingDefinition> bindings,
  ) {
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
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedBindings.remove(binding.path);
                    } else {
                      _selectedBindings.add(binding.path);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
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
                        Icon(Icons.check, size: 16, color: context.accentColor),
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
  // STEP 4: Appearance
  // ============================================================
  Widget _buildAppearanceStep() {
    // Build live preview
    final previewSchema = _buildPreviewSchema();
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final node = myNodeNum != null ? nodes[myNodeNum] : null;

    final previewHeight = switch (_selectedSize) {
      CustomWidgetSize.medium => 120.0,
      CustomWidgetSize.large => 180.0,
      CustomWidgetSize.custom => 120.0,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live preview
        Text(
          'Preview',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: previewHeight,
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: WidgetRenderer(
            schema: previewSchema,
            node: node,
            allNodes: nodes,
            accentColor: _accentColor,
            enableActions: false,
          ),
        ),
        const SizedBox(height: 24),
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
        // Layout style
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
  Widget _buildBottomActions() {
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
        child: Row(
          children: [
            // Skip to editor
            if (!isLastStep)
              TextButton(
                onPressed: _openEditor,
                child: Text(
                  'Advanced Editor',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            const Spacer(),
            // Continue / Create
            SizedBox(
              width: 140,
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
                  isLastStep ? 'Create Widget' : 'Continue',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
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
      2 => true, // Data selection is optional
      3 => true, // Appearance always valid
      _ => false,
    };
  }

  void _goNext() {
    if (_currentStep < _steps.length - 1) {
      // Auto-fill name if empty
      if (_currentStep == 0 && _nameController.text.isEmpty) {
        _nameController.text = _selectedTemplate?.name ?? 'My Widget';
      }
      // Pre-select suggested bindings
      if (_currentStep == 1 && _selectedTemplate != null) {
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

  void _openEditor() async {
    final schema = _buildFinalSchema();
    final result = await Navigator.push<WidgetSchema>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WidgetEditorScreen(initialSchema: schema, onSave: widget.onSave),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  void _create() async {
    final schema = _buildFinalSchema();
    await widget.onSave(schema);
    if (mounted) {
      Navigator.pop(context, schema);
    }
  }

  // ============================================================
  // Schema Building
  // ============================================================
  WidgetSchema _buildPreviewSchema() {
    return _buildFinalSchema();
  }

  WidgetSchema _buildFinalSchema() {
    final name = _nameController.text.trim().isEmpty
        ? 'My Widget'
        : _nameController.text.trim();

    // Build children based on selected bindings
    final children = <ElementSchema>[];

    // Title row with icon
    if (_selectedTemplate != null && _selectedTemplate!.id != 'blank') {
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

      if (_showLabels) {
        // Row with label and value
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

      // Add gauge for numeric values
      if (_selectedTemplate?.id == 'gauge' ||
          (_selectedTemplate?.id == 'status' &&
              binding.valueType == int &&
              binding.minValue != null)) {
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
          text: 'Add data in the editor',
          style: StyleSchema(
            textColor: _colorToHex(AppTheme.textSecondary),
            fontSize: 13,
          ),
        ),
      );
    }

    // Create root based on layout style
    final ElementSchema root;
    if (_layoutStyle == _LayoutStyle.horizontal) {
      root = ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(
          padding: 12,
          spacing: 16,
          mainAxisAlignment: MainAxisAlignmentOption.spaceAround,
        ),
        children: children,
      );
    } else if (_layoutStyle == _LayoutStyle.grid && children.length > 2) {
      // Create a 2-column grid using rows
      final rows = <ElementSchema>[];
      for (var i = 0; i < children.length; i += 2) {
        rows.add(
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(
              spacing: 12,
              mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
            ),
            children: [
              children[i],
              if (i + 1 < children.length) children[i + 1],
            ],
          ),
        );
      }
      root = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: rows,
      );
    } else {
      root = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: children,
      );
    }

    return WidgetSchema(
      name: name,
      description: _selectedTemplate?.description,
      size: _selectedSize,
      root: root,
      tags: _selectedTemplate != null ? [_selectedTemplate!.id] : [],
    );
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

enum _LayoutStyle { vertical, horizontal, grid }
