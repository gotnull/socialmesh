import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../models/data_binding.dart';

/// Selector for choosing data bindings with descriptions
class BindingSelector extends StatefulWidget {
  final String? selectedPath;
  final ValueChanged<String?> onSelected;

  const BindingSelector({
    super.key,
    this.selectedPath,
    required this.onSelected,
  });

  /// Show the binding selector as a bottom sheet
  /// If [numericOnly] is true, only show numeric bindings (int, double)
  static Future<String?> show({
    required BuildContext context,
    String? selectedPath,
    bool numericOnly = false,
  }) {
    return AppBottomSheet.showScrollable<String>(
      context: context,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (scrollController) => _BindingSelectorContent(
        selectedPath: selectedPath,
        scrollController: scrollController,
        numericOnly: numericOnly,
      ),
    );
  }

  @override
  State<BindingSelector> createState() => _BindingSelectorState();
}

class _BindingSelectorState extends State<BindingSelector> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _BindingSelectorContent extends StatefulWidget {
  final String? selectedPath;
  final ScrollController scrollController;
  final bool numericOnly;

  const _BindingSelectorContent({
    this.selectedPath,
    required this.scrollController,
    this.numericOnly = false,
  });

  @override
  State<_BindingSelectorContent> createState() =>
      _BindingSelectorContentState();
}

class _BindingSelectorContentState extends State<_BindingSelectorContent> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  BindingCategory? _selectedCategory;

  List<BindingDefinition> get _filteredBindings {
    final query = _searchQuery.toLowerCase();
    var bindings = BindingRegistry.bindings.toList();

    // Filter to numeric types only if required (for gauges and charts)
    if (widget.numericOnly) {
      bindings = bindings
          .where((b) => b.valueType == int || b.valueType == double)
          .toList();
    }

    if (_selectedCategory != null) {
      bindings = bindings
          .where((b) => b.category == _selectedCategory)
          .toList();
    }

    if (query.isNotEmpty) {
      bindings = bindings.where((b) {
        return b.path.toLowerCase().contains(query) ||
            b.label.toLowerCase().contains(query) ||
            b.description.toLowerCase().contains(query);
      }).toList();
    }

    return bindings;
  }

  String _categoryDisplayName(BindingCategory category) {
    switch (category) {
      case BindingCategory.node:
        return 'Node Info';
      case BindingCategory.device:
        return 'Device';
      case BindingCategory.network:
        return 'Network';
      case BindingCategory.environment:
        return 'Environment';
      case BindingCategory.power:
        return 'Power';
      case BindingCategory.airQuality:
        return 'Air Quality';
      case BindingCategory.gps:
        return 'GPS';
      case BindingCategory.messaging:
        return 'Messages';
    }
  }

  IconData _categoryIcon(BindingCategory category) {
    switch (category) {
      case BindingCategory.node:
        return Icons.hub;
      case BindingCategory.device:
        return Icons.devices;
      case BindingCategory.network:
        return Icons.lan;
      case BindingCategory.environment:
        return Icons.thermostat;
      case BindingCategory.power:
        return Icons.battery_full;
      case BindingCategory.airQuality:
        return Icons.air;
      case BindingCategory.gps:
        return Icons.gps_fixed;
      case BindingCategory.messaging:
        return Icons.message;
    }
  }

  Color _categoryColor(BindingCategory category) {
    switch (category) {
      case BindingCategory.node:
        return const Color(0xFF4F6AF6);
      case BindingCategory.device:
        return const Color(0xFF06B6D4);
      case BindingCategory.network:
        return const Color(0xFF8B5CF6);
      case BindingCategory.environment:
        return const Color(0xFFF97316);
      case BindingCategory.power:
        return const Color(0xFF4ADE80);
      case BindingCategory.airQuality:
        return const Color(0xFF64748B);
      case BindingCategory.gps:
        return const Color(0xFFEF4444);
      case BindingCategory.messaging:
        return const Color(0xFFFBBF24);
    }
  }

  IconData _typeIcon(Type type) {
    if (type == String) return Icons.text_fields;
    if (type == int) return Icons.tag;
    if (type == double) return Icons.numbers;
    if (type == bool) return Icons.toggle_on;
    if (type == DateTime) return Icons.schedule;
    return Icons.data_object;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Select Variable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),

          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search variables...',
              hintStyle: TextStyle(color: context.textSecondary),
              prefixIcon: Icon(
                Icons.search,
                color: context.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          SizedBox(height: 12),

          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip(null, 'All', Icons.apps, accentColor),
                ...BindingCategory.values.map(
                  (cat) => _buildCategoryChip(
                    cat,
                    _categoryDisplayName(cat),
                    _categoryIcon(cat),
                    _categoryColor(cat),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // "None" option
          _buildBindingTile(null, accentColor),

          Divider(height: 24, color: context.border),

          // Bindings list
          Expanded(
            child: _filteredBindings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _filteredBindings.length,
                    itemBuilder: (context, index) {
                      final binding = _filteredBindings[index];
                      return _buildBindingTile(binding, accentColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BindingCategory? category,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            SizedBox(width: 4),
            Text(label),
          ],
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : context.textSecondary,
        ),
        backgroundColor: context.background,
        selectedColor: color.withValues(alpha: 0.3),
        checkmarkColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(color: isSelected ? color : Colors.transparent),
        onSelected: (_) {
          setState(() {
            _selectedCategory = isSelected ? null : category;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: context.textSecondary),
          SizedBox(height: 8),
          Text(
            'No variables found',
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBindingTile(BindingDefinition? binding, Color accentColor) {
    final isSelected = binding == null
        ? widget.selectedPath == null || widget.selectedPath!.isEmpty
        : widget.selectedPath == binding.path;

    if (binding == null) {
      return InkWell(
        onTap: () => Navigator.pop(context, ''),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.block,
                  size: 18,
                  color: context.textSecondary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'None',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? accentColor : context.textPrimary,
                      ),
                    ),
                    Text(
                      'No data binding - use static text',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
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
      );
    }

    final categoryColor = _categoryColor(binding.category);

    return InkWell(
      onTap: () => Navigator.pop(context, binding.path),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _categoryIcon(binding.category),
                size: 18,
                color: categoryColor,
              ),
            ),
            SizedBox(width: 12),

            // Label and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          binding.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? accentColor
                                : context.textPrimary,
                          ),
                        ),
                      ),
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _typeIcon(binding.valueType),
                              size: 10,
                              color: context.textSecondary,
                            ),
                            SizedBox(width: 2),
                            Text(
                              _typeName(binding.valueType),
                              style: TextStyle(
                                fontSize: 9,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    binding.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Path and unit
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          binding.path,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                      if (binding.unit != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          binding.unit!,
                          style: TextStyle(
                            fontSize: 10,
                            color: categoryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: accentColor, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  String _typeName(Type type) {
    if (type == String) return 'text';
    if (type == int) return 'number';
    if (type == double) return 'decimal';
    if (type == bool) return 'yes/no';
    if (type == DateTime) return 'time';
    return 'value';
  }
}
