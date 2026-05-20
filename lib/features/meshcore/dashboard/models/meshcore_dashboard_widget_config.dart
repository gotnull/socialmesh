// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

// MeshCore-side mirror of `DashboardWidgetType`. Enum values + JSON
// names are protocol-scoped so persisted configs never collide with the
// Meshtastic dashboard's stored widgets.
enum MeshCoreDashboardWidgetType {
  networkOverview,
  quickActions,
  nearbyContacts,
  recentMessages,
  signalStrength,
  channelActivity,
  meshHealth,
  nodeMap,
}

enum MeshCoreWidgetSize { small, medium, large }

class MeshCoreDashboardWidgetConfig {
  final String id;
  final MeshCoreDashboardWidgetType type;
  final MeshCoreWidgetSize size;
  final int order;
  final bool isFavorite;
  final bool isVisible;

  const MeshCoreDashboardWidgetConfig({
    required this.id,
    required this.type,
    this.size = MeshCoreWidgetSize.medium,
    this.order = 0,
    this.isFavorite = false,
    this.isVisible = true,
  });

  MeshCoreDashboardWidgetConfig copyWith({
    String? id,
    MeshCoreDashboardWidgetType? type,
    MeshCoreWidgetSize? size,
    int? order,
    bool? isFavorite,
    bool? isVisible,
  }) {
    return MeshCoreDashboardWidgetConfig(
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

  factory MeshCoreDashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    return MeshCoreDashboardWidgetConfig(
      id: json['id'] as String,
      type: MeshCoreDashboardWidgetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MeshCoreDashboardWidgetType.networkOverview,
      ),
      size: MeshCoreWidgetSize.values.firstWhere(
        (e) => e.name == json['size'],
        orElse: () => MeshCoreWidgetSize.medium,
      ),
      order: json['order'] as int? ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }
}

class MeshCoreWidgetTypeInfo {
  final MeshCoreDashboardWidgetType type;
  final String name;
  final String description;
  final IconData icon;
  final MeshCoreWidgetSize defaultSize;

  const MeshCoreWidgetTypeInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.defaultSize = MeshCoreWidgetSize.medium,
  });
}

// Registry rendered into l10n labels at consumer sites; `name` /
// `description` here are the technical fallbacks used when no
// AppLocalizations is available (e.g. error logs).
class MeshCoreWidgetRegistry {
  static const List<MeshCoreWidgetTypeInfo> widgets = [
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.networkOverview,
      name: 'Network Overview', // lint-allow: hardcoded-string
      description:
          'MeshCore mesh status at a glance', // lint-allow: hardcoded-string
      icon: Icons.bar_chart_rounded,
    ),
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.quickActions,
      name: 'Quick Actions', // lint-allow: hardcoded-string
      description:
          'Send advert, refresh contacts, sync time', // lint-allow: hardcoded-string
      icon: Icons.flash_on_rounded,
    ),
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.nearbyContacts,
      name: 'Nearby Contacts', // lint-allow: hardcoded-string
      description:
          'Top contacts by recent activity and signal', // lint-allow: hardcoded-string
      icon: Icons.near_me_outlined,
    ),
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.recentMessages,
      name: 'Recent Messages', // lint-allow: hardcoded-string
      description:
          'Latest DMs and channel messages', // lint-allow: hardcoded-string
      icon: Icons.chat_bubble_outline_rounded,
    ),
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.signalStrength,
      name: 'Signal Strength', // lint-allow: hardcoded-string
      description:
          'Network-wide SNR aggregate across recent contact adverts', // lint-allow: hardcoded-string
      icon: Icons.signal_cellular_alt_rounded,
    ),
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.channelActivity,
      name: 'Channel Activity', // lint-allow: hardcoded-string
      description:
          'Recent message traffic per channel', // lint-allow: hardcoded-string
      icon: Icons.wifi_tethering_rounded,
    ),
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.meshHealth,
      name: 'Mesh Health', // lint-allow: hardcoded-string
      description:
          'Overall MeshCore mesh status and quality score', // lint-allow: hardcoded-string
      icon: Icons.favorite_rounded,
    ),
    MeshCoreWidgetTypeInfo(
      type: MeshCoreDashboardWidgetType.nodeMap,
      name: 'Node Map', // lint-allow: hardcoded-string
      description:
          'Compact map view of contacts with location', // lint-allow: hardcoded-string
      icon: Icons.map_outlined,
    ),
  ];

  static MeshCoreWidgetTypeInfo getInfo(MeshCoreDashboardWidgetType type) {
    return widgets.firstWhere(
      (w) => w.type == type,
      orElse: () => widgets.first,
    );
  }
}
