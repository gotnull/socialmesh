// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../models/trigger_protocol.dart';

/// Types of widgets available for the dashboard
enum DashboardWidgetType {
  signalStrength,
  networkOverview,
  recentMessages,
  nearbyNodes,
  channelActivity,
  meshHealth,
  quickCompose,
  nodeMap,
  environmentMetrics,
  custom, // Schema-based custom widgets from Widget Builder
}

// Per-protocol compatibility for each Meshtastic-side widget type.
// Source of truth: docs/engineering/MESHCORE_PROTOCOL_COMPATIBILITY.md.
// Used by the `updateWidget` automation action's picker to gate
// incompatible widget types from MeshCore-pinned automations.
extension DashboardWidgetTypeProtocolSupport on DashboardWidgetType {
  ProtocolSupport supportOn(TriggerProtocol protocol) {
    switch (protocol) {
      case TriggerProtocol.meshtastic:
        return ProtocolSupport.supported;
      case TriggerProtocol.meshcore:
        switch (this) {
          case DashboardWidgetType.networkOverview:
          case DashboardWidgetType.recentMessages:
          case DashboardWidgetType.nearbyNodes:
          case DashboardWidgetType.custom:
            return ProtocolSupport.supported;
          case DashboardWidgetType.signalStrength:
          case DashboardWidgetType.channelActivity:
          case DashboardWidgetType.meshHealth:
          case DashboardWidgetType.quickCompose:
          case DashboardWidgetType.nodeMap:
          case DashboardWidgetType.environmentMetrics:
            return ProtocolSupport.unsupported;
        }
    }
  }
}

/// Size options for widgets
enum WidgetSize {
  small, // 1x1 - compact info
  medium, // 2x1 - standard widget
  large, // 2x2 - detailed view
}

/// Configuration for a dashboard widget instance
class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;
  final WidgetSize size;
  final int order;
  final bool isFavorite;
  final bool isVisible;
  final String? schemaId; // For custom widgets - references WidgetSchema ID

  const DashboardWidgetConfig({
    required this.id,
    required this.type,
    this.size = WidgetSize.medium,
    this.order = 0,
    this.isFavorite = false,
    this.isVisible = true,
    this.schemaId,
  });

  DashboardWidgetConfig copyWith({
    String? id,
    DashboardWidgetType? type,
    WidgetSize? size,
    int? order,
    bool? isFavorite,
    bool? isVisible,
    String? schemaId,
  }) {
    return DashboardWidgetConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      size: size ?? this.size,
      order: order ?? this.order,
      isFavorite: isFavorite ?? this.isFavorite,
      isVisible: isVisible ?? this.isVisible,
      schemaId: schemaId ?? this.schemaId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'size': size.name,
    'order': order,
    'isFavorite': isFavorite,
    'isVisible': isVisible,
    if (schemaId != null) 'schemaId': schemaId,
  };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetConfig(
      id: json['id'] as String,
      type: DashboardWidgetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DashboardWidgetType.signalStrength,
      ),
      size: WidgetSize.values.firstWhere(
        (e) => e.name == json['size'],
        orElse: () => WidgetSize.medium,
      ),
      order: json['order'] as int? ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      schemaId: json['schemaId'] as String?,
    );
  }
}

/// Metadata about a widget type
class WidgetTypeInfo {
  final DashboardWidgetType type;
  final String name;
  final String description;
  final IconData icon;
  final WidgetSize defaultSize;
  final List<WidgetSize> supportedSizes;

  const WidgetTypeInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.defaultSize = WidgetSize.medium,
    this.supportedSizes = const [
      WidgetSize.small,
      WidgetSize.medium,
      WidgetSize.large,
    ],
  });
}

/// Registry of all available widget types
class WidgetRegistry {
  static const List<WidgetTypeInfo> widgets = [
    WidgetTypeInfo(
      type: DashboardWidgetType.signalStrength,
      name: 'Signal Strength',
      description:
          'Live RSSI, SNR, and channel utilization chart', // lint-allow: hardcoded-string
      icon: Icons.signal_cellular_alt,
      defaultSize: WidgetSize.large,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.networkOverview,
      name: 'Network Overview',
      description:
          'Mesh network status at a glance', // lint-allow: hardcoded-string
      icon: Icons.hub,
      defaultSize: WidgetSize.medium,
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.recentMessages,
      name: 'Recent Messages',
      description:
          'Latest messages from the mesh', // lint-allow: hardcoded-string
      icon: Icons.chat_bubble_outline,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.nearbyNodes,
      name: 'Nearby Nodes',
      description:
          'Closest nodes by signal or distance', // lint-allow: hardcoded-string
      icon: Icons.near_me,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.channelActivity,
      name: 'Channel Activity',
      description:
          'Active channels and recent traffic', // lint-allow: hardcoded-string
      icon: Icons.wifi_tethering,
      defaultSize: WidgetSize.medium,
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.meshHealth,
      name: 'Mesh Health',
      description:
          'Overall mesh network health metrics', // lint-allow: hardcoded-string
      icon: Icons.favorite,
      defaultSize: WidgetSize.small,
      supportedSizes: [WidgetSize.small, WidgetSize.medium],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.quickCompose,
      name: 'Quick Compose',
      description:
          'Send a quick broadcast message', // lint-allow: hardcoded-string
      icon: Icons.edit_note,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.medium],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.nodeMap,
      name: 'Node Map',
      description:
          'Map showing nodes with GPS positions', // lint-allow: hardcoded-string
      icon: Icons.map,
      defaultSize: WidgetSize.large,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.environmentMetrics,
      name: 'Environment Metrics',
      description:
          'Latest temperature, humidity, pressure — tap for full log', // lint-allow: hardcoded-string
      icon: Icons.thermostat,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.custom,
      name: 'Custom Widget',
      description:
          'Schema-based widget from Widget Builder', // lint-allow: hardcoded-string
      icon: Icons.widgets,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.small, WidgetSize.medium, WidgetSize.large],
    ),
  ];

  static WidgetTypeInfo getInfo(DashboardWidgetType type) {
    return widgets.firstWhere(
      (w) => w.type == type,
      orElse: () => widgets.first,
    );
  }
}
