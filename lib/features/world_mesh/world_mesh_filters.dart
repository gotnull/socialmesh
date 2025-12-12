import 'package:flutter/material.dart';

import '../../models/world_mesh_node.dart';

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
  String get displayName {
    switch (this) {
      case WorldMeshFilterCategory.status:
        return 'Status';
      case WorldMeshFilterCategory.hardware:
        return 'Hardware';
      case WorldMeshFilterCategory.modemPreset:
        return 'Modem Preset';
      case WorldMeshFilterCategory.region:
        return 'Region';
      case WorldMeshFilterCategory.role:
        return 'Role';
      case WorldMeshFilterCategory.firmware:
        return 'Firmware';
      case WorldMeshFilterCategory.hasEnvironmentSensors:
        return 'Environment Sensors';
      case WorldMeshFilterCategory.hasBattery:
        return 'Battery Info';
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
  final Set<NodeStatus> statusFilter;
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
    Set<NodeStatus>? statusFilter,
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

  /// Apply filters to a list of nodes
  List<WorldMeshNode> apply(List<WorldMeshNode> nodes) {
    var filtered = nodes;

    // Apply search query
    if (searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filtered = filtered.where((node) {
        return node.longName.toLowerCase().contains(lowerQuery) ||
            node.shortName.toLowerCase().contains(lowerQuery) ||
            node.nodeId.toLowerCase().contains(lowerQuery) ||
            node.hwModel.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    // Apply status filter
    if (statusFilter.isNotEmpty) {
      filtered = filtered.where((node) {
        return statusFilter.contains(node.status);
      }).toList();
    }

    // Apply hardware filter
    if (hardwareFilter.isNotEmpty) {
      filtered = filtered.where((node) {
        return hardwareFilter.contains(node.hwModel);
      }).toList();
    }

    // Apply modem preset filter
    if (modemPresetFilter.isNotEmpty) {
      filtered = filtered.where((node) {
        return node.modemPreset != null &&
            modemPresetFilter.contains(node.modemPreset);
      }).toList();
    }

    // Apply region filter
    if (regionFilter.isNotEmpty) {
      filtered = filtered.where((node) {
        return node.region != null && regionFilter.contains(node.region);
      }).toList();
    }

    // Apply role filter
    if (roleFilter.isNotEmpty) {
      filtered = filtered.where((node) {
        return roleFilter.contains(node.role);
      }).toList();
    }

    // Apply firmware filter
    if (firmwareFilter.isNotEmpty) {
      filtered = filtered.where((node) {
        return node.fwVersion != null &&
            firmwareFilter.contains(node.fwVersion);
      }).toList();
    }

    // Apply environment sensors filter
    if (hasEnvironmentSensors != null) {
      filtered = filtered.where((node) {
        final hasSensors =
            node.temperature != null ||
            node.relativeHumidity != null ||
            node.barometricPressure != null ||
            node.lux != null;
        return hasSensors == hasEnvironmentSensors;
      }).toList();
    }

    // Apply battery filter
    if (hasBattery != null) {
      filtered = filtered.where((node) {
        final hasBatteryInfo = node.batteryLevel != null;
        return hasBatteryInfo == hasBattery;
      }).toList();
    }

    return filtered;
  }
}

/// Helper to extract unique values from nodes for filter options
class WorldMeshFilterOptions {
  final Set<String> hardwareModels;
  final Set<String> modemPresets;
  final Set<String> regions;
  final Set<String> roles;
  final Set<String> firmwareVersions;
  final int onlineCount;
  final int idleCount;
  final int offlineCount;
  final int withEnvironmentSensors;
  final int withBattery;

  const WorldMeshFilterOptions({
    this.hardwareModels = const {},
    this.modemPresets = const {},
    this.regions = const {},
    this.roles = const {},
    this.firmwareVersions = const {},
    this.onlineCount = 0,
    this.idleCount = 0,
    this.offlineCount = 0,
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
    int onlineCount = 0;
    int idleCount = 0;
    int offlineCount = 0;
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
      switch (node.status) {
        case NodeStatus.online:
          onlineCount++;
        case NodeStatus.idle:
          idleCount++;
        case NodeStatus.offline:
          offlineCount++;
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
      onlineCount: onlineCount,
      idleCount: idleCount,
      offlineCount: offlineCount,
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
