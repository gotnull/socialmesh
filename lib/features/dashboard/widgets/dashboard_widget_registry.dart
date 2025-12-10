import 'package:flutter/material.dart';

/// Unique identifier for each dashboard widget type
enum DashboardWidgetType {
  signalStrength,
  nodeStats,
  messageStats,
  quickActions,
  recentMessages,
  activeNodes,
  meshHealth,
  gpsPosition,
  channelActivity,
  networkTopology,
  weatherStation,
  rangeTest,
  packetStats,
  airtime,
}

/// Configuration for a dashboard widget
class DashboardWidgetConfig {
  final DashboardWidgetType type;
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isFavorite;
  final bool isVisible;
  final int order;
  final DashboardWidgetSize size;
  final bool requiresConnection;
  final Set<String> tags;

  const DashboardWidgetConfig({
    required this.type,
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isFavorite = false,
    this.isVisible = true,
    this.order = 0,
    this.size = DashboardWidgetSize.medium,
    this.requiresConnection = true,
    this.tags = const {},
  });

  DashboardWidgetConfig copyWith({
    DashboardWidgetType? type,
    String? id,
    String? title,
    String? description,
    IconData? icon,
    bool? isFavorite,
    bool? isVisible,
    int? order,
    DashboardWidgetSize? size,
    bool? requiresConnection,
    Set<String>? tags,
  }) {
    return DashboardWidgetConfig(
      type: type ?? this.type,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isFavorite: isFavorite ?? this.isFavorite,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
      size: size ?? this.size,
      requiresConnection: requiresConnection ?? this.requiresConnection,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'id': id,
    'isFavorite': isFavorite,
    'isVisible': isVisible,
    'order': order,
    'size': size.index,
  };

  factory DashboardWidgetConfig.fromJson(
    Map<String, dynamic> json,
    DashboardWidgetConfig defaults,
  ) {
    return defaults.copyWith(
      isFavorite: json['isFavorite'] as bool? ?? defaults.isFavorite,
      isVisible: json['isVisible'] as bool? ?? defaults.isVisible,
      order: json['order'] as int? ?? defaults.order,
      size: json['size'] != null
          ? DashboardWidgetSize.values[json['size'] as int]
          : defaults.size,
    );
  }
}

/// Size options for widgets
enum DashboardWidgetSize {
  small, // 1/2 width, compact
  medium, // Full width, standard
  large, // Full width, expanded
}

/// Registry of all available dashboard widgets
class DashboardWidgetRegistry {
  static final List<DashboardWidgetConfig> allWidgets = [
    // Signal & Connection
    const DashboardWidgetConfig(
      type: DashboardWidgetType.signalStrength,
      id: 'signal_strength',
      title: 'Signal Strength',
      description: 'Live RSSI, SNR, and channel utilization chart',
      icon: Icons.signal_cellular_alt,
      size: DashboardWidgetSize.large,
      tags: {'signal', 'live', 'chart'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.meshHealth,
      id: 'mesh_health',
      title: 'Mesh Health',
      description: 'Overall mesh network health score',
      icon: Icons.health_and_safety,
      size: DashboardWidgetSize.small,
      tags: {'network', 'health'},
    ),

    // Stats
    const DashboardWidgetConfig(
      type: DashboardWidgetType.nodeStats,
      id: 'node_stats',
      title: 'Nodes',
      description: 'Total discovered nodes on the mesh',
      icon: Icons.group_outlined,
      size: DashboardWidgetSize.small,
      tags: {'nodes', 'stats'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.messageStats,
      id: 'message_stats',
      title: 'Messages',
      description: 'Total messages sent and received',
      icon: Icons.chat_bubble_outline,
      size: DashboardWidgetSize.small,
      tags: {'messages', 'stats'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.packetStats,
      id: 'packet_stats',
      title: 'Packet Statistics',
      description: 'Sent, received, and dropped packet counts',
      icon: Icons.analytics_outlined,
      size: DashboardWidgetSize.medium,
      tags: {'packets', 'stats', 'network'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.airtime,
      id: 'airtime',
      title: 'Airtime Usage',
      description: 'Radio transmission time and limits',
      icon: Icons.timer_outlined,
      size: DashboardWidgetSize.small,
      tags: {'airtime', 'radio'},
    ),

    // Quick Access
    const DashboardWidgetConfig(
      type: DashboardWidgetType.quickActions,
      id: 'quick_actions',
      title: 'Quick Actions',
      description: 'Fast access to common features',
      icon: Icons.flash_on_outlined,
      size: DashboardWidgetSize.medium,
      tags: {'navigation', 'actions'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.recentMessages,
      id: 'recent_messages',
      title: 'Recent Messages',
      description: 'Latest messages from the mesh',
      icon: Icons.message_outlined,
      size: DashboardWidgetSize.medium,
      tags: {'messages', 'recent'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.activeNodes,
      id: 'active_nodes',
      title: 'Active Nodes',
      description: 'Nodes heard in the last hour',
      icon: Icons.people_outline,
      size: DashboardWidgetSize.medium,
      tags: {'nodes', 'active', 'recent'},
    ),

    // Device Info
    const DashboardWidgetConfig(
      type: DashboardWidgetType.gpsPosition,
      id: 'gps_position',
      title: 'GPS Position',
      description: 'Current device location',
      icon: Icons.location_on_outlined,
      size: DashboardWidgetSize.small,
      tags: {'gps', 'location'},
    ),

    // Activity
    const DashboardWidgetConfig(
      type: DashboardWidgetType.channelActivity,
      id: 'channel_activity',
      title: 'Channel Activity',
      description: 'Message activity per channel',
      icon: Icons.wifi_tethering,
      size: DashboardWidgetSize.medium,
      tags: {'channels', 'activity'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.networkTopology,
      id: 'network_topology',
      title: 'Network Topology',
      description: 'Visual mesh network graph',
      icon: Icons.hub_outlined,
      size: DashboardWidgetSize.large,
      tags: {'network', 'topology', 'graph'},
    ),

    // Special Features
    const DashboardWidgetConfig(
      type: DashboardWidgetType.weatherStation,
      id: 'weather_station',
      title: 'Weather Data',
      description: 'Environmental sensor readings',
      icon: Icons.thermostat_outlined,
      size: DashboardWidgetSize.medium,
      tags: {'weather', 'sensors', 'telemetry'},
    ),
    const DashboardWidgetConfig(
      type: DashboardWidgetType.rangeTest,
      id: 'range_test',
      title: 'Range Test',
      description: 'Test signal range with other nodes',
      icon: Icons.radar_outlined,
      size: DashboardWidgetSize.medium,
      tags: {'range', 'test', 'signal'},
    ),
  ];

  /// Get widget config by type
  static DashboardWidgetConfig? getByType(DashboardWidgetType type) {
    try {
      return allWidgets.firstWhere((w) => w.type == type);
    } catch (_) {
      return null;
    }
  }

  /// Get widget config by ID
  static DashboardWidgetConfig? getById(String id) {
    try {
      return allWidgets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get default widget order for new users
  static List<DashboardWidgetConfig> getDefaultWidgets() {
    return [
      allWidgets
          .firstWhere((w) => w.type == DashboardWidgetType.nodeStats)
          .copyWith(order: 0, isVisible: true),
      allWidgets
          .firstWhere((w) => w.type == DashboardWidgetType.messageStats)
          .copyWith(order: 1, isVisible: true),
      allWidgets
          .firstWhere((w) => w.type == DashboardWidgetType.quickActions)
          .copyWith(order: 2, isVisible: true),
      allWidgets
          .firstWhere((w) => w.type == DashboardWidgetType.signalStrength)
          .copyWith(order: 3, isVisible: true, isFavorite: true),
    ];
  }

  /// Get widgets by tag
  static List<DashboardWidgetConfig> getByTag(String tag) {
    return allWidgets.where((w) => w.tags.contains(tag)).toList();
  }
}
