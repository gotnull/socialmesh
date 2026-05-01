// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/world_mesh_node.dart';
import '../../models/presence_confidence.dart';

/// Filter categories for world mesh map
enum WorldMeshFilterCategory {
  status,
  hardware,
  modemPreset,
  region,
  role,
  firmware,
  hasEnvironmentSensors,
  hasBattery,
}

extension WorldMeshFilterCategoryExtension on WorldMeshFilterCategory {
  String displayName(AppLocalizations l10n) {
    switch (this) {
      case WorldMeshFilterCategory.status:
        return l10n.worldMeshFilterCatStatus;
      case WorldMeshFilterCategory.hardware:
        return l10n.worldMeshFilterCatHardware;
      case WorldMeshFilterCategory.modemPreset:
        return l10n.worldMeshFilterCatModemPreset;
      case WorldMeshFilterCategory.region:
        return l10n.worldMeshFilterCatRegion;
      case WorldMeshFilterCategory.role:
        return l10n.worldMeshFilterCatRole;
      case WorldMeshFilterCategory.firmware:
        return l10n.worldMeshFilterCatFirmware;
      case WorldMeshFilterCategory.hasEnvironmentSensors:
        return l10n.worldMeshFilterCatEnvSensors;
      case WorldMeshFilterCategory.hasBattery:
        return l10n.worldMeshFilterCatBatteryInfo;
    }
  }

  IconData get icon {
    switch (this) {
      case WorldMeshFilterCategory.status:
        return Icons.circle;
      case WorldMeshFilterCategory.hardware:
        return Icons.memory;
      case WorldMeshFilterCategory.modemPreset:
        return Icons.settings_input_antenna;
      case WorldMeshFilterCategory.region:
        return Icons.public;
      case WorldMeshFilterCategory.role:
        return Icons.person;
      case WorldMeshFilterCategory.firmware:
        return Icons.system_update;
      case WorldMeshFilterCategory.hasEnvironmentSensors:
        return Icons.thermostat;
      case WorldMeshFilterCategory.hasBattery:
        return Icons.battery_full;
    }
  }
}

/// Filter state for world mesh map
class WorldMeshFilters {
  final Set<PresenceConfidence> statusFilter;
  final Set<String> hardwareFilter;
  final Set<String> modemPresetFilter;
  final Set<String> regionFilter;
  final Set<String> roleFilter;
  final Set<String> firmwareFilter;
  final bool? hasEnvironmentSensors;
  final bool? hasBattery;
  final String searchQuery;

  const WorldMeshFilters({
    this.statusFilter = const {},
    this.hardwareFilter = const {},
    this.modemPresetFilter = const {},
    this.regionFilter = const {},
    this.roleFilter = const {},
    this.firmwareFilter = const {},
    this.hasEnvironmentSensors,
    this.hasBattery,
    this.searchQuery = '',
  });

  /// Check if any filters are active
  bool get hasActiveFilters =>
      statusFilter.isNotEmpty ||
      hardwareFilter.isNotEmpty ||
      modemPresetFilter.isNotEmpty ||
      regionFilter.isNotEmpty ||
      roleFilter.isNotEmpty ||
      firmwareFilter.isNotEmpty ||
      hasEnvironmentSensors != null ||
      hasBattery != null;

  /// Count of active filter categories
  int get activeFilterCount {
    int count = 0;
    if (statusFilter.isNotEmpty) count++;
    if (hardwareFilter.isNotEmpty) count++;
    if (modemPresetFilter.isNotEmpty) count++;
    if (regionFilter.isNotEmpty) count++;
    if (roleFilter.isNotEmpty) count++;
    if (firmwareFilter.isNotEmpty) count++;
    if (hasEnvironmentSensors != null) count++;
    if (hasBattery != null) count++;
    return count;
  }

  WorldMeshFilters copyWith({
    Set<PresenceConfidence>? statusFilter,
    Set<String>? hardwareFilter,
    Set<String>? modemPresetFilter,
    Set<String>? regionFilter,
    Set<String>? roleFilter,
    Set<String>? firmwareFilter,
    bool? hasEnvironmentSensors,
    bool? hasBattery,
    String? searchQuery,
    bool clearHasEnvironmentSensors = false,
    bool clearHasBattery = false,
  }) {
    return WorldMeshFilters(
      statusFilter: statusFilter ?? this.statusFilter,
      hardwareFilter: hardwareFilter ?? this.hardwareFilter,
      modemPresetFilter: modemPresetFilter ?? this.modemPresetFilter,
      regionFilter: regionFilter ?? this.regionFilter,
      roleFilter: roleFilter ?? this.roleFilter,
      firmwareFilter: firmwareFilter ?? this.firmwareFilter,
      hasEnvironmentSensors: clearHasEnvironmentSensors
          ? null
          : (hasEnvironmentSensors ?? this.hasEnvironmentSensors),
      hasBattery: clearHasBattery ? null : (hasBattery ?? this.hasBattery),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Clear all filters
  WorldMeshFilters clear() {
    return WorldMeshFilters(searchQuery: searchQuery);
  }

  /// Apply filters to a list of nodes in a single pass.
  ///
  /// Combined predicate evaluation — one allocation, one walk. Replaces a
  /// previous chain of nine `.where(...).toList()` calls that materialised an
  /// intermediate list per filter and dominated frame time on 19k+ nodes.
  List<WorldMeshNode> apply(List<WorldMeshNode> nodes) {
    if (!hasActiveFilters && searchQuery.isEmpty) return nodes;

    final lowerQuery = searchQuery.isEmpty ? null : searchQuery.toLowerCase();
    final hasStatus = statusFilter.isNotEmpty;
    final hasHardware = hardwareFilter.isNotEmpty;
    final hasModem = modemPresetFilter.isNotEmpty;
    final hasRegion = regionFilter.isNotEmpty;
    final hasRole = roleFilter.isNotEmpty;
    final hasFirmware = firmwareFilter.isNotEmpty;
    final envSensorsRequired = hasEnvironmentSensors;
    final batteryRequired = hasBattery;

    final result = <WorldMeshNode>[];
    for (final node in nodes) {
      if (lowerQuery != null) {
        if (!node.longName.toLowerCase().contains(lowerQuery) &&
            !node.shortName.toLowerCase().contains(lowerQuery) &&
            !node.nodeId.toLowerCase().contains(lowerQuery) &&
            !node.hwModel.toLowerCase().contains(lowerQuery)) {
          continue;
        }
      }
      if (hasStatus && !statusFilter.contains(node.presenceConfidence)) {
        continue;
      }
      if (hasHardware && !hardwareFilter.contains(node.hwModel)) continue;
      if (hasModem &&
          (node.modemPreset == null ||
              !modemPresetFilter.contains(node.modemPreset))) {
        continue;
      }
      if (hasRegion &&
          (node.region == null || !regionFilter.contains(node.region))) {
        continue;
      }
      if (hasRole && !roleFilter.contains(node.role)) continue;
      if (hasFirmware &&
          (node.fwVersion == null ||
              !firmwareFilter.contains(node.fwVersion))) {
        continue;
      }
      if (envSensorsRequired != null) {
        final hasSensors =
            node.temperature != null ||
            node.relativeHumidity != null ||
            node.barometricPressure != null ||
            node.lux != null;
        if (hasSensors != envSensorsRequired) continue;
      }
      if (batteryRequired != null &&
          (node.batteryLevel != null) != batteryRequired) {
        continue;
      }
      result.add(node);
    }
    return result;
  }
}

/// Helper to extract unique values from nodes for filter options
class WorldMeshFilterOptions {
  final Set<String> hardwareModels;
  final Set<String> modemPresets;
  final Set<String> regions;
  final Set<String> roles;
  final Set<String> firmwareVersions;
  final int activeCount;
  final int fadingCount;
  final int staleCount;
  final int unknownCount;
  final int withEnvironmentSensors;
  final int withBattery;

  const WorldMeshFilterOptions({
    this.hardwareModels = const {},
    this.modemPresets = const {},
    this.regions = const {},
    this.roles = const {},
    this.firmwareVersions = const {},
    this.activeCount = 0,
    this.fadingCount = 0,
    this.staleCount = 0,
    this.unknownCount = 0,
    this.withEnvironmentSensors = 0,
    this.withBattery = 0,
  });

  /// Extract filter options from a list of nodes
  factory WorldMeshFilterOptions.fromNodes(List<WorldMeshNode> nodes) {
    final hardwareModels = <String>{};
    final modemPresets = <String>{};
    final regions = <String>{};
    final roles = <String>{};
    final firmwareVersions = <String>{};
    int activeCount = 0;
    int fadingCount = 0;
    int staleCount = 0;
    int unknownCount = 0;
    int withEnvironmentSensors = 0;
    int withBattery = 0;

    for (final node in nodes) {
      hardwareModels.add(node.hwModel);
      if (node.modemPreset != null && node.modemPreset!.isNotEmpty) {
        modemPresets.add(node.modemPreset!);
      }
      if (node.region != null && node.region!.isNotEmpty) {
        regions.add(node.region!);
      }
      roles.add(node.role);
      if (node.fwVersion != null && node.fwVersion!.isNotEmpty) {
        firmwareVersions.add(node.fwVersion!);
      }

      // Count statuses
      switch (node.presenceConfidence) {
        case PresenceConfidence.active:
          activeCount++;
        case PresenceConfidence.fading:
          fadingCount++;
        case PresenceConfidence.stale:
          staleCount++;
        case PresenceConfidence.unknown:
          unknownCount++;
      }

      // Count sensors
      if (node.temperature != null ||
          node.relativeHumidity != null ||
          node.barometricPressure != null ||
          node.lux != null) {
        withEnvironmentSensors++;
      }

      // Count battery
      if (node.batteryLevel != null) {
        withBattery++;
      }
    }

    return WorldMeshFilterOptions(
      hardwareModels: hardwareModels,
      modemPresets: modemPresets,
      regions: regions,
      roles: roles,
      firmwareVersions: firmwareVersions,
      activeCount: activeCount,
      fadingCount: fadingCount,
      staleCount: staleCount,
      unknownCount: unknownCount,
      withEnvironmentSensors: withEnvironmentSensors,
      withBattery: withBattery,
    );
  }

  /// Get sorted list of hardware models
  List<String> get sortedHardwareModels =>
      hardwareModels.toList()..sort((a, b) => a.compareTo(b));

  /// Get sorted list of modem presets
  List<String> get sortedModemPresets =>
      modemPresets.toList()..sort((a, b) => a.compareTo(b));

  /// Get sorted list of regions
  List<String> get sortedRegions =>
      regions.toList()..sort((a, b) => a.compareTo(b));

  /// Get sorted list of roles
  List<String> get sortedRoles =>
      roles.toList()..sort((a, b) => a.compareTo(b));

  /// Get sorted list of firmware versions (newest first)
  List<String> get sortedFirmwareVersions =>
      firmwareVersions.toList()..sort((a, b) => b.compareTo(a));
}
