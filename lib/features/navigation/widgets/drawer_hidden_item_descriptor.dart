// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';

// Lightweight render-only view of a drawer item.
//
// The full default-item list lives inside `_MainDrawerState`
// (`main_shell.dart`) and depends on every feature screen + flag. The
// drawer customization sheet only needs icon + label + accent to
// render a "show hidden item" tile, so we expose those three fields
// here behind an id lookup. Keeping the lookup in lock-step with the
// drawer's real list is pinned by `drawer_customization_test.dart` —
// every customizable id in the live drawer must resolve here too.
class DrawerHiddenItemDescriptor {
  final IconData icon;
  final String label;
  final Color iconColor;

  const DrawerHiddenItemDescriptor({
    required this.icon,
    required this.label,
    required this.iconColor,
  });
}

DrawerHiddenItemDescriptor? drawerHiddenItemDescriptor(
  String id,
  AppLocalizations l10n,
) {
  switch (id) {
    case 'nodedex':
      return DrawerHiddenItemDescriptor(
        icon: Icons.auto_stories_outlined,
        label: l10n.navigationNodeDex,
        iconColor: AccentColors.yellow,
      );
    case 'nodedex_map':
      return DrawerHiddenItemDescriptor(
        icon: Icons.map_outlined,
        label: l10n.nodedexMapTooltip,
        iconColor: AccentColors.blue,
      );
    case 'nodeboard':
      return DrawerHiddenItemDescriptor(
        icon: Icons.dashboard_outlined,
        label: l10n.nodeboardDrawerLabel,
        iconColor: AccentColors.coral,
      );
    case 'operations':
      return DrawerHiddenItemDescriptor(
        icon: Icons.flag_outlined,
        label: l10n.navigationOperations,
        iconColor: AccentColors.emerald,
      );
    case 'presence':
      return DrawerHiddenItemDescriptor(
        icon: Icons.people_alt_outlined,
        label: l10n.navigationPresence,
        iconColor: AccentColors.green,
      );
    case 'world_map':
      return DrawerHiddenItemDescriptor(
        icon: Icons.public,
        label: l10n.navigationWorldMap,
        iconColor: AccentColors.blue,
      );
    case 'mesh_explorer':
      return DrawerHiddenItemDescriptor(
        icon: Icons.explore_outlined,
        label: l10n.meshExplorerDrawerLabel,
        iconColor: AccentColors.teal,
      );
    case 'mesh_capacity':
      return DrawerHiddenItemDescriptor(
        icon: Icons.network_check,
        label: l10n.meshCapacityScreenTitle,
        iconColor: AccentColors.cyan,
      );
    case 'mesh_feed':
      return DrawerHiddenItemDescriptor(
        icon: Icons.dynamic_feed_outlined,
        label: l10n.meshFeedDrawerLabel,
        iconColor: AccentColors.orange,
      );
    case 'telemetry':
      return DrawerHiddenItemDescriptor(
        icon: Icons.insights_outlined,
        label: l10n.navigationTelemetry,
        iconColor: AccentColors.green,
      );
    case 'device_shop':
      return DrawerHiddenItemDescriptor(
        icon: Icons.storefront_outlined,
        label: l10n.deviceShopTitle,
        iconColor: AccentColors.cyan,
      );
    case 'file_transfers':
      return DrawerHiddenItemDescriptor(
        icon: Icons.swap_vert,
        label: l10n.navigationFileTransfers,
        iconColor: AccentColors.cyan,
      );
    case 'aether':
      return DrawerHiddenItemDescriptor(
        icon: Icons.flight_takeoff_outlined,
        label: l10n.navigationAether,
        iconColor: AccentColors.sky,
      );
    case 'tak_gateway':
      return DrawerHiddenItemDescriptor(
        icon: Icons.gps_fixed,
        label: l10n.navigationTakGateway,
        iconColor: AccentColors.orange,
      );
    case 'tak_map':
      return DrawerHiddenItemDescriptor(
        icon: Icons.military_tech,
        label: l10n.navigationTakMap,
        iconColor: AccentColors.orange,
      );
    case 'sip':
      return DrawerHiddenItemDescriptor(
        icon: Icons.wifi_tethering,
        label: l10n.sipBadgeLabel,
        iconColor: AccentColors.teal,
      );
    case 'mrrp_harness':
      return DrawerHiddenItemDescriptor(
        icon: Icons.hub,
        label: l10n.mrrpHarnessDrawerLabel,
        iconColor: AccentColors.purple,
      );
    case 'mesh_incidents':
      return DrawerHiddenItemDescriptor(
        icon: Icons.warning_amber_outlined,
        label: l10n.navigationMeshIncidents,
        iconColor: AccentColors.red,
      );
    case 'timeline':
      return DrawerHiddenItemDescriptor(
        icon: Icons.timeline,
        label: l10n.navigationTimeline,
        iconColor: AccentColors.indigo,
      );
    case 'routes':
      return DrawerHiddenItemDescriptor(
        icon: Icons.route,
        label: l10n.navigationRoutes,
        iconColor: AccentColors.purple,
      );
    case 'reachability':
      return DrawerHiddenItemDescriptor(
        icon: Icons.wifi_find,
        label: l10n.navigationReachability,
        iconColor: AccentColors.teal,
      );
    case 'mesh_health':
      return DrawerHiddenItemDescriptor(
        icon: Icons.monitor_heart_outlined,
        label: l10n.navigationMeshHealth,
        iconColor: AccentColors.pink,
      );
    case 'device_logs':
      return DrawerHiddenItemDescriptor(
        icon: Icons.terminal,
        label: l10n.navigationDeviceLogs,
        iconColor: AccentColors.slate,
      );
    case 'translation_pack':
      return DrawerHiddenItemDescriptor(
        icon: Icons.translate_outlined,
        label: l10n.navigationTranslationPack,
        iconColor: AccentColors.teal,
      );
    case 'theme_pack':
      return DrawerHiddenItemDescriptor(
        icon: Icons.palette_outlined,
        label: l10n.navigationThemePack,
        iconColor: AccentColors.purple,
      );
    case 'ringtone_pack':
      return DrawerHiddenItemDescriptor(
        icon: Icons.music_note_outlined,
        label: l10n.navigationRingtonePack,
        iconColor: AccentColors.pink,
      );
    case 'widgets':
      return DrawerHiddenItemDescriptor(
        icon: Icons.widgets_outlined,
        label: l10n.navigationWidgets,
        iconColor: AccentColors.coral,
      );
    case 'automations':
      return DrawerHiddenItemDescriptor(
        icon: Icons.auto_awesome,
        label: l10n.navigationAutomations,
        iconColor: AccentColors.yellow,
      );
    case 'ifttt_integration':
      return DrawerHiddenItemDescriptor(
        icon: Icons.webhook_outlined,
        label: l10n.navigationIftttIntegration,
        iconColor: AccentColors.sky,
      );
  }
  return null;
}
