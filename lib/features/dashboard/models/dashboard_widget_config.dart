import 'package:flutter/material.dart';

/// Types of widgets available for the dashboard
enum DashboardWidgetType {
  signalStrength,
  networkOverview,
  recentMessages,
  nearbyNodes,
  batteryStatus,
  channelActivity,
  meshHealth,
  quickCompose,
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

  const DashboardWidgetConfig({
    required this.id,
    required this.type,
    this.size = WidgetSize.medium,
    this.order = 0,
    this.isFavorite = false,
    this.isVisible = true,
  });

  DashboardWidgetConfig copyWith({
    String? id,
    DashboardWidgetType? type,
    WidgetSize? size,
    int? order,
    bool? isFavorite,
    bool? isVisible,
  }) {
    return DashboardWidgetConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      size: size ?? this.size,
      order: order ?? this.order,
      isFavorite: isFavorite ?? this.isFavorite,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'size': size.name,
    'order': order,
    'isFavorite': isFavorite,
    'isVisible': isVisible,
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
      description: 'Live RSSI, SNR, and channel utilization chart',
      icon: Icons.signal_cellular_alt,
      defaultSize: WidgetSize.large,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.networkOverview,
      name: 'Network Overview',
      description: 'Mesh network status at a glance',
      icon: Icons.hub,
      defaultSize: WidgetSize.medium,
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.recentMessages,
      name: 'Recent Messages',
      description: 'Latest messages from the mesh',
      icon: Icons.chat_bubble_outline,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.nearbyNodes,
      name: 'Nearby Nodes',
      description: 'Closest nodes by signal or distance',
      icon: Icons.near_me,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.medium, WidgetSize.large],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.batteryStatus,
      name: 'Battery Status',
      description: 'Your device battery level and health',
      icon: Icons.battery_std,
      defaultSize: WidgetSize.small,
      supportedSizes: [WidgetSize.small, WidgetSize.medium],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.channelActivity,
      name: 'Channel Activity',
      description: 'Active channels and recent traffic',
      icon: Icons.wifi_tethering,
      defaultSize: WidgetSize.medium,
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.meshHealth,
      name: 'Mesh Health',
      description: 'Overall mesh network health metrics',
      icon: Icons.favorite,
      defaultSize: WidgetSize.small,
      supportedSizes: [WidgetSize.small, WidgetSize.medium],
    ),
    WidgetTypeInfo(
      type: DashboardWidgetType.quickCompose,
      name: 'Quick Compose',
      description: 'Send a quick broadcast message',
      icon: Icons.edit_note,
      defaultSize: WidgetSize.medium,
      supportedSizes: [WidgetSize.medium],
    ),
  ];

  static WidgetTypeInfo getInfo(DashboardWidgetType type) {
    return widgets.firstWhere(
      (w) => w.type == type,
      orElse: () => widgets.first,
    );
  }
}
