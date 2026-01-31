// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../models/presence_confidence.dart';
import '../../providers/world_mesh_map_provider.dart';
import 'world_mesh_filters.dart';

/// Bottom sheet for filtering world mesh nodes
class WorldMeshFilterSheet extends ConsumerStatefulWidget {
  const WorldMeshFilterSheet({super.key});

  @override
  ConsumerState<WorldMeshFilterSheet> createState() =>
      _WorldMeshFilterSheetState();
}

class _WorldMeshFilterSheetState extends ConsumerState<WorldMeshFilterSheet> {
  WorldMeshFilterCategory? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final filters = ref.watch(worldMeshFiltersProvider);
    final options = ref.watch(worldMeshFilterOptionsProvider);
    final filteredCount = ref
        .watch(worldMeshAdvancedFilteredNodesProvider)
        .length;
    final totalCount = ref.watch(worldMeshNodesWithPositionProvider).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: accentColor),
                  const SizedBox(width: 12),
                  Text(
                    'Filter Nodes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (filters.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(worldMeshFiltersProvider.notifier)
                            .clearAllFilters();
                      },
                      child: Text(
                        'Clear All',
                        style: TextStyle(color: accentColor),
                      ),
                    ),
                ],
              ),
            ),
            // Results count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      '$filteredCount of $totalCount nodes',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (filters.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filters.activeFilterCount} filter${filters.activeFilterCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Filter categories
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Status filter
                  _buildFilterSection(
                    category: WorldMeshFilterCategory.status,
                    title: 'Status',
                    icon: Icons.circle,
                    isExpanded:
                        _expandedCategory == WorldMeshFilterCategory.status,
                    activeCount: filters.statusFilter.length,
                    onToggle: () =>
                        _toggleCategory(WorldMeshFilterCategory.status),
                    child: _buildStatusFilters(options, filters, accentColor),
                  ),
                  const SizedBox(height: 12),

                  // Hardware filter
                  _buildFilterSection(
                    category: WorldMeshFilterCategory.hardware,
                    title: 'Hardware Model',
                    icon: Icons.memory,
                    isExpanded:
                        _expandedCategory == WorldMeshFilterCategory.hardware,
                    activeCount: filters.hardwareFilter.length,
                    onToggle: () =>
                        _toggleCategory(WorldMeshFilterCategory.hardware),
                    child: _buildChipFilters(
                      items: options.sortedHardwareModels,
                      selectedItems: filters.hardwareFilter,
                      onToggle: (item) => ref
                          .read(worldMeshFiltersProvider.notifier)
                          .toggleHardware(item),
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Modem Preset filter
                  _buildFilterSection(
                    category: WorldMeshFilterCategory.modemPreset,
                    title: 'Modem Preset',
                    icon: Icons.settings_input_antenna,
                    isExpanded:
                        _expandedCategory ==
                        WorldMeshFilterCategory.modemPreset,
                    activeCount: filters.modemPresetFilter.length,
                    onToggle: () =>
                        _toggleCategory(WorldMeshFilterCategory.modemPreset),
                    child: _buildChipFilters(
                      items: options.sortedModemPresets,
                      selectedItems: filters.modemPresetFilter,
                      onToggle: (item) => ref
                          .read(worldMeshFiltersProvider.notifier)
                          .toggleModemPreset(item),
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Region filter
                  _buildFilterSection(
                    category: WorldMeshFilterCategory.region,
                    title: 'Region',
                    icon: Icons.public,
                    isExpanded:
                        _expandedCategory == WorldMeshFilterCategory.region,
                    activeCount: filters.regionFilter.length,
                    onToggle: () =>
                        _toggleCategory(WorldMeshFilterCategory.region),
                    child: _buildChipFilters(
                      items: options.sortedRegions,
                      selectedItems: filters.regionFilter,
                      onToggle: (item) => ref
                          .read(worldMeshFiltersProvider.notifier)
                          .toggleRegion(item),
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Role filter
                  _buildFilterSection(
                    category: WorldMeshFilterCategory.role,
                    title: 'Node Role',
                    icon: Icons.person,
                    isExpanded:
                        _expandedCategory == WorldMeshFilterCategory.role,
                    activeCount: filters.roleFilter.length,
                    onToggle: () =>
                        _toggleCategory(WorldMeshFilterCategory.role),
                    child: _buildChipFilters(
                      items: options.sortedRoles,
                      selectedItems: filters.roleFilter,
                      onToggle: (item) => ref
                          .read(worldMeshFiltersProvider.notifier)
                          .toggleRole(item),
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Firmware filter
                  _buildFilterSection(
                    category: WorldMeshFilterCategory.firmware,
                    title: 'Firmware Version',
                    icon: Icons.system_update,
                    isExpanded:
                        _expandedCategory == WorldMeshFilterCategory.firmware,
                    activeCount: filters.firmwareFilter.length,
                    onToggle: () =>
                        _toggleCategory(WorldMeshFilterCategory.firmware),
                    child: _buildChipFilters(
                      items: options.sortedFirmwareVersions,
                      selectedItems: filters.firmwareFilter,
                      onToggle: (item) => ref
                          .read(worldMeshFiltersProvider.notifier)
                          .toggleFirmware(item),
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Boolean filters
                  _buildBooleanFilterSection(
                    title: 'Environment Sensors',
                    icon: Icons.thermostat,
                    subtitle:
                        '${options.withEnvironmentSensors} nodes with sensors',
                    value: filters.hasEnvironmentSensors,
                    onChanged: (value) => ref
                        .read(worldMeshFiltersProvider.notifier)
                        .setHasEnvironmentSensors(value),
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 12),

                  _buildBooleanFilterSection(
                    title: 'Battery Info',
                    icon: Icons.battery_full,
                    subtitle: '${options.withBattery} nodes with battery data',
                    value: filters.hasBattery,
                    onChanged: (value) => ref
                        .read(worldMeshFiltersProvider.notifier)
                        .setHasBattery(value),
                    accentColor: accentColor,
                  ),

                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCategory(WorldMeshFilterCategory category) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedCategory == category) {
        _expandedCategory = null;
      } else {
        _expandedCategory = category;
      }
    });
  }

  Widget _buildFilterSection({
    required WorldMeshFilterCategory category,
    required String title,
    required IconData icon,
    required bool isExpanded,
    required int activeCount,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activeCount > 0 ? accentColor : context.border,
        ),
      ),
      child: Column(
        children: [
          // Header (always visible)
          BouncyTap(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (activeCount > 0 ? accentColor : Colors.grey)
                          .withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: activeCount > 0 ? accentColor : Colors.grey,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: activeCount > 0 ? accentColor : null,
                      ),
                    ),
                  ),
                  if (activeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilters(
    WorldMeshFilterOptions options,
    WorldMeshFilters filters,
    Color accentColor,
  ) {
    return Column(
      children: [
        _buildStatusChip(
          label: 'Active (≤2m)',
          count: options.activeCount,
          color: AppTheme.successGreen,
          isSelected: filters.statusFilter.contains(PresenceConfidence.active),
          onTap: () => ref
              .read(worldMeshFiltersProvider.notifier)
              .toggleStatus(PresenceConfidence.active),
        ),
        SizedBox(height: 8),
        _buildStatusChip(
          label: 'Fading (2-10m)',
          count: options.fadingCount,
          color: Colors.amber,
          isSelected: filters.statusFilter.contains(PresenceConfidence.fading),
          onTap: () => ref
              .read(worldMeshFiltersProvider.notifier)
              .toggleStatus(PresenceConfidence.fading),
        ),
        const SizedBox(height: 8),
        _buildStatusChip(
          label: 'Inactive (10-60m)',
          count: options.staleCount,
          color: context.textTertiary,
          isSelected: filters.statusFilter.contains(PresenceConfidence.stale),
          onTap: () => ref
              .read(worldMeshFiltersProvider.notifier)
              .toggleStatus(PresenceConfidence.stale),
        ),
        const SizedBox(height: 8),
        _buildStatusChip(
          label: 'Unknown (>60m)',
          count: options.unknownCount,
          color: context.textTertiary,
          isSelected: filters.statusFilter.contains(PresenceConfidence.unknown),
          onTap: () => ref
              .read(worldMeshFiltersProvider.notifier)
              .toggleStatus(PresenceConfidence.unknown),
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : context.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : context.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : null,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
            SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: isSelected ? color : context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipFilters({
    required List<String> items,
    required Set<String> selectedItems,
    required void Function(String) onToggle,
    required Color accentColor,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'No options available',
          style: TextStyle(color: context.textTertiary, fontSize: 13),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selectedItems.contains(item);
        return BouncyTap(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(item);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withAlpha(30)
                  : context.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? accentColor : context.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? accentColor : null,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check, size: 14, color: accentColor),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBooleanFilterSection({
    required String title,
    required IconData icon,
    required String subtitle,
    required bool? value,
    required void Function(bool?) onChanged,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value != null ? accentColor : context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (value != null ? accentColor : Colors.grey).withAlpha(
                    30,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: value != null ? accentColor : Colors.grey,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: value != null ? accentColor : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTriStateButton(
                  label: 'Any',
                  isSelected: value == null,
                  onTap: () => onChanged(null),
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTriStateButton(
                  label: 'Yes',
                  isSelected: value == true,
                  onTap: () => onChanged(true),
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTriStateButton(
                  label: 'No',
                  isSelected: value == false,
                  onTap: () => onChanged(false),
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTriStateButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withAlpha(30) : context.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? accentColor : context.border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? accentColor : context.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Show the filter sheet
Future<void> showWorldMeshFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const WorldMeshFilterSheet(),
  );
}
