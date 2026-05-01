// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/presence_confidence.dart';
import '../../providers/world_mesh_map_provider.dart';
import 'world_mesh_filters.dart';

/// Bottom sheet for filtering world mesh nodes. Hosted inside
/// `AppBottomSheet.showScrollable` — the parent provides the drag
/// pill, rounded background, and `DraggableScrollableSheet`. The
/// passed-in [scrollController] MUST be wired into the body
/// `ListView`, otherwise drag-to-dismiss breaks (gray-area bug).
class WorldMeshFilterSheet extends ConsumerStatefulWidget {
  const WorldMeshFilterSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

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
    final scrollController = widget.scrollController;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.filter_list, color: accentColor),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                context.l10n.worldMeshFilterTitle,
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
                    context.l10n.worldMeshFilterClearAll,
                    style: TextStyle(color: accentColor),
                  ),
                ),
            ],
          ),
        ),
        // Results count
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(20),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 16, color: accentColor),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  context.l10n.worldMeshFilterNodeCount(
                    filteredCount,
                    totalCount,
                  ),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (filters.hasActiveFilters) ...[
                  const SizedBox(width: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: Text(
                      context.l10n.worldMeshFilterActiveCount(
                        filters.activeFilterCount,
                      ),
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            children: [
              // Status filter
              _buildFilterSection(
                category: WorldMeshFilterCategory.status,
                title: context.l10n.worldMeshFilterStatus,
                icon: Icons.circle,
                isExpanded: _expandedCategory == WorldMeshFilterCategory.status,
                activeCount: filters.statusFilter.length,
                onToggle: () => _toggleCategory(WorldMeshFilterCategory.status),
                child: _buildStatusFilters(options, filters, accentColor),
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Hardware filter
              _buildFilterSection(
                category: WorldMeshFilterCategory.hardware,
                title: context.l10n.worldMeshFilterHardwareModel,
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
              const SizedBox(height: AppTheme.spacing12),

              // Modem Preset filter
              _buildFilterSection(
                category: WorldMeshFilterCategory.modemPreset,
                title: context.l10n.worldMeshFilterModemPreset,
                icon: Icons.settings_input_antenna,
                isExpanded:
                    _expandedCategory == WorldMeshFilterCategory.modemPreset,
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
              const SizedBox(height: AppTheme.spacing12),

              // Region filter
              _buildFilterSection(
                category: WorldMeshFilterCategory.region,
                title: context.l10n.worldMeshFilterRegion,
                icon: Icons.public,
                isExpanded: _expandedCategory == WorldMeshFilterCategory.region,
                activeCount: filters.regionFilter.length,
                onToggle: () => _toggleCategory(WorldMeshFilterCategory.region),
                child: _buildChipFilters(
                  items: options.sortedRegions,
                  selectedItems: filters.regionFilter,
                  onToggle: (item) => ref
                      .read(worldMeshFiltersProvider.notifier)
                      .toggleRegion(item),
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Role filter
              _buildFilterSection(
                category: WorldMeshFilterCategory.role,
                title: context.l10n.worldMeshFilterNodeRole,
                icon: Icons.person,
                isExpanded: _expandedCategory == WorldMeshFilterCategory.role,
                activeCount: filters.roleFilter.length,
                onToggle: () => _toggleCategory(WorldMeshFilterCategory.role),
                child: _buildChipFilters(
                  items: options.sortedRoles,
                  selectedItems: filters.roleFilter,
                  onToggle: (item) => ref
                      .read(worldMeshFiltersProvider.notifier)
                      .toggleRole(item),
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Firmware filter
              _buildFilterSection(
                category: WorldMeshFilterCategory.firmware,
                title: context.l10n.worldMeshFilterFirmwareVersion,
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
              const SizedBox(height: AppTheme.spacing12),

              // Boolean filters
              _buildBooleanFilterSection(
                title: context.l10n.worldMeshFilterEnvironmentSensors,
                icon: Icons.thermostat,
                subtitle: context.l10n.worldMeshFilterNodesWithSensors(
                  options.withEnvironmentSensors,
                ),
                value: filters.hasEnvironmentSensors,
                onChanged: (value) => ref
                    .read(worldMeshFiltersProvider.notifier)
                    .setHasEnvironmentSensors(value),
                accentColor: accentColor,
              ),
              const SizedBox(height: AppTheme.spacing12),

              _buildBooleanFilterSection(
                title: context.l10n.worldMeshFilterBatteryInfo,
                icon: Icons.battery_full,
                subtitle: context.l10n.worldMeshFilterNodesWithBattery(
                  options.withBattery,
                ),
                value: filters.hasBattery,
                onChanged: (value) => ref
                    .read(worldMeshFiltersProvider.notifier)
                    .setHasBattery(value),
                accentColor: accentColor,
              ),

              const SizedBox(height: AppTheme.spacing100), // Bottom padding
            ],
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          (activeCount > 0
                                  ? accentColor
                                  : SemanticColors.disabled)
                              .withAlpha(30),
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: activeCount > 0
                          ? accentColor
                          : SemanticColors.disabled,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing12),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                  const SizedBox(width: AppTheme.spacing8),
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
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 16),
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
          label: context.l10n.worldMeshFilterStatusActive,
          count: options.activeCount,
          color: AppTheme.successGreen,
          isSelected: filters.statusFilter.contains(PresenceConfidence.active),
          onTap: () => ref
              .read(worldMeshFiltersProvider.notifier)
              .toggleStatus(PresenceConfidence.active),
        ),
        SizedBox(height: AppTheme.spacing8),
        _buildStatusChip(
          label: context.l10n.worldMeshFilterStatusFading,
          count: options.fadingCount,
          color: AppTheme.warningYellow,
          isSelected: filters.statusFilter.contains(PresenceConfidence.fading),
          onTap: () => ref
              .read(worldMeshFiltersProvider.notifier)
              .toggleStatus(PresenceConfidence.fading),
        ),
        const SizedBox(height: AppTheme.spacing8),
        _buildStatusChip(
          label: context.l10n.worldMeshFilterStatusInactive,
          count: options.staleCount,
          color: context.textTertiary,
          isSelected: filters.statusFilter.contains(PresenceConfidence.stale),
          onTap: () => ref
              .read(worldMeshFiltersProvider.notifier)
              .toggleStatus(PresenceConfidence.stale),
        ),
        const SizedBox(height: AppTheme.spacing8),
        _buildStatusChip(
          label: context.l10n.worldMeshFilterStatusUnknown,
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
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(color: isSelected ? color : context.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: AppTheme.spacing12),
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
            SizedBox(width: AppTheme.spacing8),
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
        padding: const EdgeInsets.all(AppTheme.spacing8),
        child: Text(
          context.l10n.worldMeshFilterNoOptions,
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
              borderRadius: BorderRadius.circular(AppTheme.radius20),
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
                  const SizedBox(width: AppTheme.spacing6),
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                  color: (value != null ? accentColor : SemanticColors.disabled)
                      .withAlpha(30),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: value != null ? accentColor : SemanticColors.disabled,
                ),
              ),
              SizedBox(width: AppTheme.spacing12),
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
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: _buildTriStateButton(
                  label: context.l10n.worldMeshFilterAny,
                  isSelected: value == null,
                  onTap: () => onChanged(null),
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: _buildTriStateButton(
                  label: context.l10n.worldMeshFilterYes,
                  isSelected: value == true,
                  onTap: () => onChanged(true),
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: _buildTriStateButton(
                  label: context.l10n.worldMeshFilterNo,
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
          borderRadius: BorderRadius.circular(AppTheme.radius8),
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

/// Show the filter sheet via the canonical scrollable-sheet primitive
/// (drag pill, rounded background, and `DraggableScrollableSheet` are
/// all provided by `AppBottomSheet.showScrollable`).
Future<void> showWorldMeshFilterSheet(BuildContext context) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (controller) => WorldMeshFilterSheet(scrollController: controller),
  );
}
