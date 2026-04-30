// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — navigation shell root scaffold with drawer and bottom nav
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/navigation.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/countdown_banner.dart';
import '../../core/widgets/requires_connection_guard.dart';
import '../../core/widgets/top_status_banner.dart';
import '../../core/widgets/user_avatar.dart';

import '../../core/widgets/legal_document_sheet.dart';
import '../../generated/meshtastic/mesh.pbenum.dart';
import '../../models/subscription_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/connection_providers.dart';
import '../../providers/connectivity_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/social_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/notifications/notification_service.dart';
import '../settings/battery_optimization_guide.dart';
import '../../utils/snackbar.dart';
import '../messaging/messages_container_screen.dart';
import '../nodes/nodes_screen.dart';
import '../map/map_screen.dart';
import '../dashboard/widget_dashboard_screen.dart';
import '../scanner/scanner_screen.dart';
import '../device/device_sheet.dart';
import '../device/region_selection_screen.dart';
import '../timeline/timeline_screen.dart';
import '../routes/routes_screen.dart';
import '../telemetry/telemetry_hub_screen.dart';
import '../automations/automations_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../settings/ringtone_screen.dart';
import '../settings/ifttt_config_screen.dart';
import '../settings/account_subscriptions_screen.dart';
import '../presence/presence_screen.dart';
import '../mesh3d/mesh_3d_screen.dart';
import '../world_mesh/world_mesh_screen.dart';
import '../settings/subscription_screen.dart';
import '../settings/translation_settings_screen.dart';
import '../widget_builder/widget_builder_screen.dart';
import '../reachability/mesh_reachability_screen.dart';
import '../device_shop/providers/admin_shop_providers.dart';
import '../device_shop/screens/device_shop_screen.dart';
import '../admin/bug_reports/admin_bug_report_watcher.dart';
import '../mesh_health/widgets/mesh_health_dashboard.dart';
import '../signals/signals.dart';
import '../profile/profile_screen.dart';
import '../debug/device_logs_screen.dart';
import '../nodedex/screens/nodedex_screen.dart';
import '../social/screens/activity_timeline_screen.dart';
import '../social/screens/social_hub_screen.dart';
import '../aether/screens/aether_screen.dart';
import '../file_transfer/screens/file_transfers_container_screen.dart';
import '../aether/providers/aether_flight_matcher_provider.dart';
import '../aether/providers/aether_flight_lifecycle_provider.dart';
import '../aether/widgets/aether_flight_detected_overlay.dart';
// import '../global_layer/screens/global_layer_hub_screen.dart';
import '../sip/sip_hub_screen.dart';
import '../mrrp_harness/mrrp_harness_home_screen.dart';
import '../mesh_explorer/mesh_explorer_screen.dart';
import '../mesh_feed/screens/mesh_feed_screen.dart';
import '../nodeboard/screens/nodeboard_list_screen.dart';
import '../incidents/screens/mesh_incident_list_screen.dart';
import '../tak/screens/tak_screen.dart';
import '../../providers/activity_providers.dart';
import '../../providers/mesh_explorer_providers.dart';
import '../../providers/whats_new_providers.dart';
import '../../core/whats_new/whats_new_sheet.dart';
import 'widgets/drawer_admin_section.dart';
import 'widgets/drawer_enterprise_section.dart';
import 'widgets/drawer_menu_tile.dart';
import 'widgets/drawer_node_header.dart';
import 'widgets/drawer_sticky_header.dart';
import 'widgets/nav_bar_item.dart';

/// Combined admin notification count provider
/// Uses FutureProvider to properly handle the async stream states
final adminNotificationCountProvider = Provider<int>((ref) {
  // Watch both providers - this creates proper dependency tracking
  final reviewAsync = ref.watch(pendingReviewCountProvider);
  final reportAsync = ref.watch(pendingReportCountProvider);

  // Extract counts, defaulting to 0 for loading/error states
  final reviewCount = reviewAsync.when(
    data: (count) => count,
    loading: () => 0,
    error: (_, _) => 0,
  );
  final reportCount = reportAsync.when(
    data: (count) => count,
    loading: () => 0,
    error: (_, _) => 0,
  );

  return reviewCount + reportCount;
});

/// Notifier to expose the main shell's scaffold key for drawer access
class MainShellScaffoldKeyNotifier extends Notifier<GlobalKey<ScaffoldState>?> {
  @override
  GlobalKey<ScaffoldState>? build() => null;

  void setKey(GlobalKey<ScaffoldState>? key) {
    state = key;
  }
}

/// Provider to expose the main shell's scaffold key for drawer access
final mainShellScaffoldKeyProvider =
    NotifierProvider<MainShellScaffoldKeyNotifier, GlobalKey<ScaffoldState>?>(
      MainShellScaffoldKeyNotifier.new,
    );

/// Provider for controlling the currently selected bottom tab in MainShell
class MainShellIndexNotifier extends Notifier<int> {
  @override
  int build() => 2; // start on Nodes tab

  void setIndex(int idx) {
    state = idx;
  }
}

final mainShellIndexProvider = NotifierProvider<MainShellIndexNotifier, int>(
  MainShellIndexNotifier.new,
);

/// When `true`, the Map tab should activate its TAK overlay layer.
/// Set by the "TAK Map" drawer item, consumed (and reset) by MapScreen.
class _MapTakModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;
  void consume() => state = false;
}

final mapTakModeProvider = NotifierProvider<_MapTakModeNotifier, bool>(
  _MapTakModeNotifier.new,
);

/// Widget to create a hamburger menu button for app bars
/// Automatically shows a back button if the screen was pushed onto the navigation stack
class HamburgerMenuButton extends ConsumerWidget {
  const HamburgerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = ref.watch(mainShellScaffoldKeyProvider);
    final theme = Theme.of(context);
    final adminNotificationCount = ref.watch(adminNotificationCountProvider);
    final activityCount = ref.watch(unreadActivityCountProvider);
    final newPeerCount = ref.watch(newMeshPeerCountProvider);
    final hasUnseenWhatsNew = ref.watch(whatsNewHasUnseenProvider);

    // Combine admin, activity, and new-peer counts for hamburger badge
    final totalBadgeCount =
        adminNotificationCount + activityCount + newPeerCount;

    // Determine which badge to show on the icon itself
    Widget menuIcon = Icon(
      Icons.menu,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );

    if (totalBadgeCount > 0) {
      // Count badge — uses Flutter's Badge for correct positioning
      menuIcon = Badge(
        label: Text(
          totalBadgeCount > 99 ? '99+' : '$totalBadgeCount',
          style: const TextStyle(
            color: SemanticColors.onAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: context.accentColor,
        child: menuIcon,
      );
    } else if (hasUnseenWhatsNew) {
      // Gradient dot — small indicator for unseen What's New
      menuIcon = Badge(
        smallSize: 10,
        backgroundColor: context.accentColor,
        child: menuIcon,
      );
    }

    return IconButton(
      icon: menuIcon,
      onPressed: () {
        HapticFeedback.lightImpact();
        // Open the drawer using the provider-stored scaffold key
        // This key is from MainShell which has the drawer
        final scaffoldState = scaffoldKey?.currentState;
        if (scaffoldState != null) {
          scaffoldState.openDrawer();
        } else {
          // Fallback: if the provider key didn't work, try to find a Scaffold ancestor
          // This handles edge cases where the key reference is stale or not yet set
          try {
            Scaffold.of(context).openDrawer();
          } catch (e) {
            // If no Scaffold ancestor found, log the issue
            AppLogging.app(
              '⚠️ HamburgerMenuButton: Could not open drawer - no scaffold key or ancestor found',
            );
          }
        }
      },
      tooltip: context.l10n.navigationMenuTooltip,
    );
  }
}

/// Global device status button for app bars
/// Shows connection status with colored indicator and opens device sheet
class DeviceStatusButton extends ConsumerWidget {
  const DeviceStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);

    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (e, s) => false,
    );
    final isReconnecting =
        autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting;

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.router,
            color: isConnected
                ? context.accentColor
                : isReconnecting
                ? AppTheme.warningYellow
                : context.textTertiary,
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isConnected
                    ? context.accentColor
                    : isReconnecting
                    ? AppTheme.warningYellow
                    : AppTheme.errorRed,
                shape: BoxShape.circle,
                border: Border.all(color: context.background, width: 2),
              ),
            ),
          ),
        ],
      ),
      onPressed: () => showDeviceSheet(context),
      tooltip: context.l10n.navigationDeviceTooltip,
    );
  }
}

/// Helper to navigate from drawer items.
/// Closes drawer first, then navigates after a brief delay to ensure
/// the drawer close animation completes smoothly.
///
/// The pushed route is tagged with [routeName] (defaulting to
/// `screen.runtimeType.toString()`). This lets push-from-notification
/// handlers (in `main.dart`) detect when the destination screen is
/// already on top of the stack and skip the duplicate push — without
/// it, tapping a notification while the corresponding screen is
/// already visible stacks an identical second copy on top, requiring
/// two back taps to return to the previous context.
///
/// Callers wrapping [screen] in `RequiresConnectionGuard` (or any
/// other guard widget) MUST pass [routeName] explicitly with the
/// inner screen's type name, since the wrapped widget's runtimeType
/// would otherwise come back as `'RequiresConnectionGuard'` and the
/// notification dedupe would never match.
@visibleForTesting
void navigateFromDrawer(
  BuildContext context,
  Widget screen, {
  String? routeName,
}) {
  Navigator.of(context).pop(); // Close drawer
  // Use post-frame callback to ensure drawer animation completes
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => screen,
          settings: RouteSettings(
            name: routeName ?? screen.runtimeType.toString(),
          ),
        ),
      );
    }
  });
}

/// Main navigation shell with bottom navigation bar
// Global key to reference the existing SignalFeedScreen instance when it's
// part of the MainShell. This allows other widgets to instruct the signal
// feed screen to focus a specific signal without pushing additional routes.
final GlobalKey signalFeedScreenKey = GlobalKey();

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Tracks whether the [TopStatusBanner] is actually taking up space on
  /// screen (accounts for slide animation). Used to keep
  /// [MediaQuery.removePadding] in sync with the banner's real footprint.
  bool _bannerActuallyVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mainShellScaffoldKeyProvider.notifier).setKey(_scaffoldKey);

        // Trigger What's New popup if there is an unseen payload.
        // This runs after the first frame so the navigator is ready.
        // GUARD: Skip if region setup is still needed — the inline
        // RegionSelectionScreen would be visible and What's New would
        // overlay on top of it, creating a confusing UX.
        final needsRegion = ref.read(needsRegionSetupProvider);
        final regionConfigured =
            ref
                .read(settingsServiceProvider)
                .whenOrNull(data: (settings) => settings.regionConfigured) ??
            false;
        if (needsRegion && !regionConfigured) {
          AppLogging.app('WhatsNew: suppressed — region setup still needed');
        } else {
          WhatsNewSheet.showIfNeeded();
        }

        // Listen for first connection to show OEM battery optimization guide
        // (Android only, once per install).
        ref.listenManual(deviceConnectionProvider, (previous, next) {
          if (next.state == DevicePairingState.connected &&
              previous?.state != DevicePairingState.connected) {
            _showBatteryGuideIfNeeded();
          }
        });
      }
    });
  }

  /// Show the OEM battery optimization guide after a short delay.
  ///
  /// This gives the system-level battery prompt (fired from
  /// [BackgroundBleService.promptBatteryOptimizationIfNeeded]) time to resolve
  /// before stacking another bottom sheet.
  void _showBatteryGuideIfNeeded() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      showBatteryOptimizationGuide(context);
    });
  }

  @override
  void dispose() {
    // Note: We don't clear the scaffold key here because:
    // 1. Modifying providers during dispose causes Riverpod exceptions
    // 2. When MainShell is recreated, initState will set a new key anyway
    // 3. If MainShell is permanently gone, the key becomes naturally stale
    super.dispose();
  }

  /// Drawer menu items for quick access screens not in bottom nav
  /// Organized into intent-based sections with headers:
  /// DISCOVER → IDENTITY → TOOLS → ADVANCED → PREMIUM
  List<DrawerMenuItem> _buildDrawerMenuItems(AppLocalizations l10n) => [
    // Discover section — features that help you see what's around you
    DrawerMenuItem(
      icon: Icons.sensors,
      label: l10n.navigationSignals,
      screen: SignalFeedScreen(key: signalFeedScreenKey),
      sectionHeader: l10n.navigationSectionDiscover,
      iconColor: AccentColors.lavender,
    ),
    DrawerMenuItem(
      icon: Icons.auto_stories_outlined,
      label: l10n.navigationNodeDex,
      screen: const NodeDexScreen(),
      iconColor: AccentColors.yellow,
      requiresConnection: false,
      whatsNewBadgeKey: 'nodedex',
    ),
    if (AppFeatureFlags.isNodeBoardEnabled)
      DrawerMenuItem(
        icon: Icons.dashboard_outlined,
        label: l10n.nodeboardDrawerLabel,
        screen: const NodeBoardListScreen(),
        iconColor: AccentColors.coral,
        requiresConnection: false,
        whatsNewBadgeKey: 'nodeboard',
      ),
    DrawerMenuItem(
      icon: Icons.people_alt_outlined,
      label: l10n.navigationPresence,
      screen: const PresenceScreen(),
      iconColor: AccentColors.green,
      requiresConnection: true,
    ),
    DrawerMenuItem(
      icon: Icons.public,
      label: l10n.navigationWorldMap,
      screen: const WorldMeshScreen(),
      iconColor: AccentColors.blue,
      requiresConnection: false, // Shows global mesh data from server
    ),
    if (AppFeatureFlags.isMeshExplorerEnabled)
      DrawerMenuItem(
        icon: Icons.explore_outlined,
        label: l10n.meshExplorerDrawerLabel,
        screen: const MeshExplorerScreen(),
        iconColor: AccentColors.teal,
        requiresConnection: true,
        badgeProviderKey: 'mesh_explorer',
      ),
    if (AppFeatureFlags.isMeshFeedEnabled)
      DrawerMenuItem(
        icon: Icons.dynamic_feed_outlined,
        label: l10n.meshFeedDrawerLabel,
        screen: const MeshFeedScreen(),
        iconColor: AccentColors.orange,
        requiresConnection: false,
      ),
    if (AppFeatureFlags.isSocialEnabled)
      DrawerMenuItem(
        icon: Icons.forum_outlined,
        label: l10n.navigationSocial,
        screen: const SocialHubScreen(),
        sectionHeader: l10n.navigationSectionIdentity,
        iconColor: AccentColors.pink,
        requiresConnection: false,
      ),
    DrawerMenuItem(
      icon: Icons.favorite_border,
      label: l10n.navigationActivity,
      screen: const ActivityTimelineScreen(),
      // Only set section header when Social Hub is hidden (feature flag off)
      sectionHeader: AppFeatureFlags.isSocialEnabled
          ? null
          : l10n.navigationSectionIdentity,
      iconColor: AccentColors.red,
      requiresConnection: false,
      badgeProviderKey: 'activity',
    ),

    // Tools section — operational capabilities
    DrawerMenuItem(
      icon: Icons.insights_outlined,
      label: l10n.navigationTelemetry,
      screen: const TelemetryHubScreen(),
      sectionHeader: l10n.navigationSectionTools,
      iconColor: AccentColors.green,
      requiresConnection: false,
    ),
    if (AppFeatureFlags.isDeviceShopEnabled)
      DrawerMenuItem(
        icon: Icons.storefront_outlined,
        label: l10n.deviceShopTitle,
        screen: const DeviceShopScreen(),
        iconColor: AccentColors.cyan,
        requiresConnection: false,
        whatsNewBadgeKey: 'device_shop',
      ),
    if (AppFeatureFlags.isFileTransferEnabled)
      DrawerMenuItem(
        icon: Icons.swap_vert,
        label: l10n.navigationFileTransfers,
        screen: const FileTransfersContainerScreen(),
        iconColor: AccentColors.cyan,
        requiresConnection: true,
        whatsNewBadgeKey: 'file_transfers',
      ),
    if (AppFeatureFlags.isAetherEnabled)
      DrawerMenuItem(
        icon: Icons.flight_takeoff_outlined,
        label: l10n.navigationAether,
        screen: const AetherScreen(),
        iconColor: AccentColors.sky,
        requiresConnection: false,
        whatsNewBadgeKey: 'aether',
      ),
    if (AppFeatureFlags.isTakGatewayEnabled ||
        AppFeatureFlags.isTakMeshBridgeEnabled)
      DrawerMenuItem(
        icon: Icons.gps_fixed,
        label: l10n.navigationTakGateway,
        screen: const TakScreen(),
        iconColor: AccentColors.orange,
        requiresConnection: false,
        whatsNewBadgeKey: 'tak',
      ),
    if (AppFeatureFlags.isTakGatewayEnabled ||
        AppFeatureFlags.isTakMeshBridgeEnabled)
      DrawerMenuItem(
        icon: Icons.military_tech,
        label: l10n.navigationTakMap,
        tabIndex: 1,
        requestsTakMode: true,
        iconColor: AccentColors.orange,
        requiresConnection: false,
      ),
    if (AppFeatureFlags.isSipEnabled)
      DrawerMenuItem(
        icon: Icons.wifi_tethering,
        label: l10n.sipBadgeLabel,
        screen: const SipHubScreen(),
        iconColor: AccentColors.teal,
        requiresConnection: true,
        whatsNewBadgeKey: 'sip',
      ),
    if (AppFeatureFlags.isMrrpHarnessEnabled && AppFeatureFlags.isMrrpEnabled)
      DrawerMenuItem(
        icon: Icons.hub,
        label: l10n.mrrpHarnessDrawerLabel,
        screen: const MrrpHarnessHomeScreen(),
        iconColor: AccentColors.purple,
        requiresConnection: true,
      ),
    if (AppFeatureFlags.isMeshIncidentsEnabled)
      DrawerMenuItem(
        icon: Icons.warning_amber_outlined,
        label: l10n.navigationMeshIncidents,
        screen: const MeshIncidentListScreen(),
        iconColor: AccentColors.red,
        requiresConnection: true,
      ),

    // Advanced section — deep mesh analysis and diagnostics
    DrawerMenuItem(
      icon: Icons.timeline,
      label: l10n.navigationTimeline,
      screen: const TimelineScreen(),
      sectionHeader: l10n.navigationSectionAdvanced,
      iconColor: AccentColors.indigo,
    ),
    DrawerMenuItem(
      icon: Icons.view_in_ar,
      label: l10n.navigationMesh3dView,
      screen: const Mesh3DScreen(),
      iconColor: AccentColors.cyan,
    ),
    DrawerMenuItem(
      icon: Icons.route,
      label: l10n.navigationRoutes,
      screen: const RoutesScreen(),
      iconColor: AccentColors.purple,
    ),
    DrawerMenuItem(
      icon: Icons.wifi_find,
      label: l10n.navigationReachability,
      screen: const MeshReachabilityScreen(),
      iconColor: AccentColors.teal,
      requiresConnection: true,
    ),
    DrawerMenuItem(
      icon: Icons.monitor_heart_outlined,
      label: l10n.navigationMeshHealth,
      screen: const MeshHealthDashboard(),
      iconColor: AccentColors.pink,
      requiresConnection: true,
    ),
    DrawerMenuItem(
      icon: Icons.terminal,
      label: l10n.navigationDeviceLogs,
      screen: const DeviceLogsScreen(),
      iconColor: AccentColors.slate,
      requiresConnection: true,
    ),

    // Premium Features - mixed requirements
    if (AppFeatureFlags.isTranslationEnabled)
      DrawerMenuItem(
        icon: Icons.translate_outlined,
        label: l10n.navigationTranslationPack,
        screen: const TranslationSettingsScreen(),
        premiumFeature: PremiumFeature.translation,
        sectionHeader: l10n.navigationSectionPremium,
        iconColor: AccentColors.teal,
        whatsNewBadgeKey: 'translation_pack',
      ),
    DrawerMenuItem(
      icon: Icons.palette_outlined,
      label: l10n.navigationThemePack,
      screen: const ThemeSettingsScreen(),
      premiumFeature: PremiumFeature.premiumThemes,
      iconColor: AccentColors.purple,
      sectionHeader: !AppFeatureFlags.isTranslationEnabled
          ? l10n.navigationSectionPremium
          : null,
    ),
    DrawerMenuItem(
      icon: Icons.music_note_outlined,
      label: l10n.navigationRingtonePack,
      screen: const RingtoneScreen(),
      premiumFeature: PremiumFeature.customRingtones,
      iconColor: AccentColors.pink,
    ),
    DrawerMenuItem(
      icon: Icons.widgets_outlined,
      label: l10n.navigationWidgets,
      screen: const WidgetBuilderScreen(),
      premiumFeature: PremiumFeature.homeWidgets,
      iconColor: AccentColors.coral,
    ),
    DrawerMenuItem(
      icon: Icons.auto_awesome,
      label: l10n.navigationAutomations,
      screen: const AutomationsScreen(),
      premiumFeature: PremiumFeature.automations,
      iconColor: AccentColors.yellow,
    ),
    DrawerMenuItem(
      icon: Icons.webhook_outlined,
      label: l10n.navigationIftttIntegration,
      screen: const IftttConfigScreen(),
      premiumFeature: PremiumFeature.iftttIntegration,
      iconColor: AccentColors.sky,
    ),
  ];

  List<NavItem> _buildNavItems(AppLocalizations l10n) => [
    NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: l10n.navigationMessages,
    ),
    NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: l10n.navigationMap,
    ),
    NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: l10n.navigationNodes,
    ),
    NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: l10n.navigationDashboard,
    ),
  ];

  Widget _buildScreen(int index) {
    // Scanner is the sole destination when disconnected — no inline
    // "No Device Connected" wrapper needed. MainShell's TopStatusBanner
    // handles the reconnecting/disconnected banner at the top.
    switch (index) {
      case 0:
        return const MessagesContainerScreen();
      case 1:
        return const MapScreen();
      case 2:
        return const NodesScreen();
      case 3:
        return const WidgetDashboardScreen();
      default:
        return const MessagesContainerScreen();
    }
  }

  /// Build drawer menu slivers with sticky section headers
  List<Widget> _buildDrawerMenuSlivers(BuildContext context, ThemeData theme) {
    final slivers = <Widget>[];
    // Use themeModeProvider for brightness to stay in sync with toggle button
    final currentMode = ref.watch(themeModeProvider);
    final isDark =
        currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final dividerAlpha = isDark ? 0.1 : 0.2;

    // Check connection status for items that require it
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (_, _) => false,
    );

    // Watch unseen What's New badge keys for NEW chip indicators
    final unseenBadgeKeys = ref.watch(whatsNewUnseenBadgeKeysProvider);

    // Add top padding
    slivers.add(const SliverPadding(padding: EdgeInsets.only(top: 8)));

    // Group items by section
    final l10n = context.l10n;
    final drawerMenuItems = _buildDrawerMenuItems(l10n);
    final sections = <DrawerMenuSection>[];
    DrawerMenuSection? currentSection;

    for (var i = 0; i < drawerMenuItems.length; i++) {
      final item = drawerMenuItems[i];

      if (item.sectionHeader != null) {
        // Start new section
        if (currentSection != null) {
          sections.add(currentSection);
        }
        currentSection = DrawerMenuSection(item.sectionHeader!, []);
      }

      if (currentSection != null) {
        currentSection.items.add(DrawerMenuItemWithIndex(item, i));
      } else {
        // Items before any section header go in a special section
        if (sections.isEmpty || sections.last.title.isNotEmpty) {
          sections.add(DrawerMenuSection('', []));
        }
        sections.last.items.add(DrawerMenuItemWithIndex(item, i));
      }
    }

    // Add the last section
    if (currentSection != null) {
      sections.add(currentSection);
    }

    // Build slivers for each section
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      final isLastSection = sectionIndex == sections.length - 1;

      // Add sticky header if section has a title
      if (section.title.isNotEmpty) {
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: DrawerStickyHeaderDelegate(
              title: section.title,
              theme: theme,
            ),
          ),
        );
      }

      // Add section items
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final itemWithIndex = section.items[index];
              final item = itemWithIndex.item;
              final isLastInSection = index == section.items.length - 1;

              // Check if this is a premium feature and if user has access
              final isPremium = item.premiumFeature != null;
              final hasAccess =
                  !isPremium ||
                  ref.watch(hasFeatureProvider(item.premiumFeature!));

              // When upsell mode is enabled for this feature, allow navigation
              // The feature screen itself handles the upsell gate on actions
              // Use per-feature gate instead of global upsellEnabled
              final featureKey = item.premiumFeature?.name ?? '';
              final upsellEnabled = isPremium
                  ? ref.watch(premiumFeatureGateProvider(featureKey))
                  : false;
              final allowNavigation = hasAccess || upsellEnabled;

              // Check if item requires connection but we're not connected
              final needsConnection = item.requiresConnection && !isConnected;

              // Get badge count for items with badge provider
              int? badgeCount;
              if (item.badgeProviderKey == 'activity') {
                badgeCount = ref.watch(unreadActivityCountProvider);
              } else if (item.badgeProviderKey == 'mesh_explorer') {
                badgeCount = ref.watch(newMeshPeerCountProvider);
                if (badgeCount == 0) badgeCount = null;
              }

              // Check if this item should show a NEW chip
              // Suppress when already purchased — the verified badge is enough
              final isNew =
                  item.whatsNewBadgeKey != null &&
                  unseenBadgeKeys.contains(item.whatsNewBadgeKey) &&
                  !(isPremium && hasAccess);

              return Column(
                children: [
                  DrawerMenuTile(
                    icon: item.icon,
                    label: item.label,
                    isSelected: false, // Never selected, items push new screens
                    isPremium: isPremium && hasAccess, // Only true if owned
                    // Show locked state only when upsell is disabled
                    isLocked: isPremium && !hasAccess && !upsellEnabled,
                    // Show "TRY IT" when upsell enabled but not owned
                    showTryIt: isPremium && !hasAccess && upsellEnabled,
                    isDisabled: needsConnection,
                    iconColor: item.iconColor,
                    badgeCount: badgeCount,
                    showNewChip: isNew,
                    onTap: needsConnection
                        ? null
                        : () {
                            ref.haptics.tabChange();
                            // Dismiss the NEW badge if this item has one
                            if (item.whatsNewBadgeKey != null) {
                              ref
                                  .read(whatsNewProvider.notifier)
                                  .dismissBadgeKey(item.whatsNewBadgeKey!);
                            }
                            // Dismiss peer-found badge immediately on tapping Mesh Explorer
                            if (item.badgeProviderKey == 'mesh_explorer') {
                              ref
                                  .read(newMeshPeerCountProvider.notifier)
                                  .clear();
                            }
                            if (item.tabIndex != null) {
                              // Tab-based item — switch bottom-nav index
                              Navigator.of(context).pop(); // close drawer
                              if (item.requestsTakMode) {
                                ref.read(mapTakModeProvider.notifier).request();
                              }
                              ref
                                  .read(mainShellIndexProvider.notifier)
                                  .setIndex(item.tabIndex!);
                            } else if (isPremium && !allowNavigation) {
                              // Upsell disabled - redirect to subscription screen
                              navigateFromDrawer(
                                context,
                                const SubscriptionScreen(),
                              );
                            } else if (item.screen != null) {
                              // Push screen with back button for consistent navigation.
                              // Wrap node-required screens in `RequiresConnectionGuard`
                              // so an in-session disconnect pops them back to the
                              // previous route — the drawer-level gate prevents entry,
                              // and this gate enforces the same invariant if the
                              // device drops while the user is inside the screen.
                              final pushed = item.requiresConnection
                                  ? RequiresConnectionGuard(child: item.screen!)
                                  : item.screen!;
                              // Pass the INNER screen's runtime type as
                              // the route name so notification dedupe
                              // (in `main.dart`) recognises the route
                              // even though it's wrapped in
                              // `RequiresConnectionGuard`.
                              navigateFromDrawer(
                                context,
                                pushed,
                                routeName: item.screen!.runtimeType.toString(),
                              );
                            }
                          },
                  ),
                  // Add spacing between items within a section
                  if (!isLastInSection)
                    const SizedBox(height: AppTheme.spacing4),
                  // Add divider after last item in section
                  if (isLastInSection && !isLastSection)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Divider(
                        color: theme.dividerColor.withValues(
                          alpha: dividerAlpha,
                        ),
                      ),
                    ),
                ],
              );
            }, childCount: section.items.length),
          ),
        ),
      );
    }

    return slivers;
  }

  /// Build account section inline so setState works directly
  Widget _buildAccountSection(BuildContext context, ThemeData theme) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isSignedIn = authState.value != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              context.l10n.navigationSectionAccount,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),

          // Account tile - same navigation as other drawer items
          profileAsync.when(
            data: (profile) =>
                _buildProfileTile(context, theme, profile, isSignedIn),
            loading: () => const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, st) =>
                _buildProfileTile(context, theme, null, isSignedIn),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext context,
    ThemeData theme,
    dynamic profile,
    bool isSignedIn,
  ) {
    final accentColor = theme.colorScheme.primary;
    final syncStatus = ref.watch(syncStatusProvider);
    final isOnline = ref.watch(isOnlineProvider);

    final displayName =
        profile?.displayName ?? context.l10n.navigationGuestName;
    final initials = profile?.initials ?? '?';
    final avatarUrl = profile?.avatarUrl;

    String getSyncStatusText() {
      final l10n = context.l10n;
      if (!isSignedIn) return l10n.navigationNotSignedIn;
      if (!isOnline) return l10n.navigationOffline;
      return switch (syncStatus) {
        SyncStatus.syncing => l10n.navigationSyncing,
        SyncStatus.error => l10n.navigationSyncError,
        SyncStatus.synced => l10n.navigationSynced,
        SyncStatus.idle => l10n.navigationViewProfile,
      };
    }

    return Material(
      color: Colors
          .transparent, // lint-allow: no-hardcoded-color — transparent is not a color literal
      child: InkWell(
        onTap: () {
          ref.haptics.tabChange();
          // Navigate to Account screen if not signed in, Profile screen otherwise
          if (isSignedIn) {
            navigateFromDrawer(context, const ProfileScreen());
          } else {
            navigateFromDrawer(context, const AccountSubscriptionsScreen());
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              UserAvatar(
                imageUrl: avatarUrl,
                initials: initials,
                size: 40,
                borderWidth: 1.5,
                borderColor: accentColor.withValues(alpha: 0.3),
                foregroundColor: accentColor,
                backgroundColor: accentColor.withValues(alpha: 0.15),
              ),
              const SizedBox(width: AppTheme.spacing12),
              // Name and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Row(
                      children: [
                        if (isOnline && syncStatus == SyncStatus.syncing)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: accentColor,
                              ),
                            ),
                          ),
                        Text(
                          getSyncStatusText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    // lint-allow: no-hardcoded-color — Colors.transparent is not a color literal
    final theme = Theme.of(context);
    final currentMode = ref.watch(themeModeProvider);
    final isDark =
        currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final dividerAlpha = isDark ? 0.1 : 0.2;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Node Info Header
            const DrawerNodeHeader(),

            // Divider after header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),

            // Account section - inline so setState works
            _buildAccountSection(context, theme),

            // Divider after account
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),

            // Menu items with sticky headers
            Expanded(
              child: CustomScrollView(
                slivers: [
                  ..._buildDrawerMenuSlivers(context, theme),

                  // Enterprise section (only visible to org members)
                  SliverToBoxAdapter(
                    child: DrawerEnterpriseSection(
                      onNavigate: (screen) {
                        navigateFromDrawer(context, screen);
                      },
                    ),
                  ),

                  // Admin section (only visible to shop admins)
                  SliverToBoxAdapter(
                    child: DrawerAdminSection(
                      onNavigate: (screen) {
                        navigateFromDrawer(context, screen);
                      },
                    ),
                  ),

                  // Divider before Settings/Help
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Divider(
                        color: theme.dividerColor.withValues(
                          alpha: dividerAlpha,
                        ),
                      ),
                    ),
                  ),

                  // Help & Support
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DrawerMenuTile(
                        icon: Icons.help_outline,
                        label: context.l10n.navigationHelpSupport,
                        isSelected: false,
                        iconColor: AccentColors.blue,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.of(context).pop();
                          LegalDocumentSheet.showSupport(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider before theme toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),

            // Settings button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                12,
                16,
                16,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SettingsButton(
                  onTap: () {
                    navigateFromDrawer(context, const SettingsScreen());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final settingsAsync = ref.watch(settingsServiceProvider);
    final deviceState = ref.watch(deviceConnectionProvider);

    // Watch Firestore config for real-time updates (premium upsell, etc.)
    // This keeps the stream alive and syncs remote changes to local storage
    ref.watch(firestoreConfigWatcherProvider);

    // Watch for new bug reports and fire local notifications (admin only).
    // Non-admins get an inert stream that never emits.
    ref.watch(adminBugReportWatcherProvider);

    // Auto-reconnect and live activity managers are now watched at app level in main.dart

    // Watch for UNSET region - firmware updates can reset it!
    // BUT only if we haven't already marked region as configured (user set it before)
    // During auto-reconnect, the region might briefly show UNSET before config loads
    final needsRegionSetup = ref.watch(needsRegionSetupProvider);
    final regionConfigured =
        settingsAsync.whenOrNull(
          data: (settings) => settings.regionConfigured,
        ) ??
        false;

    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (e, s) => false,
    );
    final isReconnecting =
        autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting;

    // Listen for firmware client notifications (errors, warnings)
    // These are important messages that need to be shown to the user
    final l10n = context.l10n;
    ref.listen(clientNotificationStreamProvider, (previous, next) {
      next.whenData((notification) {
        final level = notification.level;
        final message = notification.message;
        final levelName = level.name;

        // Show appropriate snackbar based on severity level
        if (level == LogRecord_Level.ERROR ||
            level == LogRecord_Level.CRITICAL) {
          showErrorSnackBar(context, l10n.navigationFirmwareMessage(message));
          // Also show a local push notification for critical errors
          // This ensures user sees the error even if app is backgrounded
          NotificationService().showFirmwareNotification(
            title: l10n.navigationFirmwareErrorTitle,
            message: message,
            level: levelName,
          );
        } else if (level == LogRecord_Level.WARNING) {
          showWarningSnackBar(context, l10n.navigationFirmwareMessage(message));
          // Push notification for warnings too - they're important
          NotificationService().showFirmwareNotification(
            title: l10n.navigationFirmwareWarningTitle,
            message: message,
            level: levelName,
          );
        } else if (level == LogRecord_Level.INFO) {
          showInfoSnackBar(context, l10n.navigationFirmwareMessage(message));
        }
        // DEBUG and TRACE levels are not shown to user
      });
    });

    // Aether flight detection and lifecycle — only when feature is enabled.
    if (AppFeatureFlags.isAetherEnabled) {
      // Cross-reference mesh nodes with active flights and alert the user
      // when a match is found so they can report their reception immediately.
      // The in-app floating overlay is handled by AetherFlightDetectedOverlay.
      ref.listen<AetherFlightMatcherState>(aetherFlightMatcherProvider, (
        previous,
        next,
      ) {
        final matcher = ref.read(aetherFlightMatcherProvider.notifier);
        final unnotified = matcher.unnotifiedMatches;
        for (final match in unnotified) {
          matcher.markNotified(match.flight.nodeId);
          // Push notification (visible if app is backgrounded)
          NotificationService().showAetherFlightDetectedNotification(
            flightNumber: match.flight.flightNumber,
            departure: match.flight.departure,
            arrival: match.flight.arrival,
            nodeName: match.node.displayName,
          );
          AppLogging.aether(
            'Flight match detected: ${match.flight.flightNumber} '
            'node ${match.flight.nodeId} = ${match.node.displayName}',
          );
        }
      });

      // Auto-activate flights when departure time passes and
      // auto-deactivate when arrival time passes.
      ref.listen<FlightLifecycleState>(aetherFlightLifecycleProvider, (
        previous,
        next,
      ) {
        final notifier = ref.read(aetherFlightLifecycleProvider.notifier);
        for (final event in next.pendingEvents) {
          notifier.acknowledgeEvent(event);
          final flight = event.flight;
          final route = '${flight.departure} → ${flight.arrival}';
          if (event.activated) {
            showInfoSnackBar(
              context,
              l10n.navigationFlightActivated(flight.flightNumber, route),
            );
            AppLogging.aether('Lifecycle: activated ${flight.flightNumber}');
          } else {
            showInfoSnackBar(
              context,
              l10n.navigationFlightCompleted(flight.flightNumber, route),
            );
            AppLogging.aether('Lifecycle: deactivated ${flight.flightNumber}');
          }
        }
      });
    }

    // Check if we need to show the "Connect Device" screen
    // ONLY show scanner on first launch (never paired before) AND auto-reconnect disabled
    // For subsequent disconnections, show a non-intrusive banner instead
    final autoReconnectEnabled =
        settingsAsync.whenOrNull(data: (settings) => settings.autoReconnect) ??
        true;
    final hasEverPaired =
        settingsAsync.whenOrNull(
          data: (settings) => settings.lastDeviceId != null,
        ) ??
        false;

    // Only block the UI with ScannerScreen if:
    // 1. Never paired before AND not reconnecting AND auto-reconnect disabled
    // This ensures first-time users go through the scanner flow
    // CRITICAL: Only show ScannerScreen (full scan wrapper) on first launch (never paired, auto-reconnect disabled)
    // or after a MANUAL disconnect (handled by device_sheet.dart). Never show on signal loss/out-of-range.
    if (!isConnected &&
        !hasEverPaired &&
        !isReconnecting &&
        !autoReconnectEnabled) {
      return const ScannerScreen(isInline: true);
    }

    // If pairing was invalidated (factory reset, device replaced, etc.), go straight to scanner
    // User needs to forget device in Bluetooth settings and re-pair
    if (deviceState.isTerminalInvalidated) {
      return const ScannerScreen(isInline: true);
    }

    // If connected but region is UNSET, force region selection
    // This catches firmware updates/resets that clear the region
    // BUT: skip this during auto-reconnect if user already configured region before
    // The device config might not have loaded yet, and we don't want a loop
    if (isConnected && needsRegionSetup && !regionConfigured) {
      AppLogging.app(
        '⚠️ MainShell: Connected but region is UNSET and not configured - forcing region setup',
      );
      // CRITICAL: User has already been through onboarding, so screen should pop after selection
      return const RegionSelectionScreen(isInitialSetup: false);
    }

    // Build the main scaffold with Drawer
    // Determine if we should show the reconnection banner (only as a banner, never replaces screen)
    //
    // STABILITY GUARD: Tie banner visibility to "fully connected" — i.e.
    // transport connected AND auto-reconnect not actively cycling — so a
    // brief transport.state==connected window during a TCP retry (where
    // the socket comes up but protocol.start() then times out) does NOT
    // toggle the banner off and on. Without this guard, every TCP-conflict
    // retry cycle (e.g. another client owns the radio at
    // tcp:host:4403) flipped `isConnected` true→false in the seconds
    // between socket-up and protocol-config-timeout, dragging the
    // SizeTransition up/down and bopping the Nodes screen vertically
    // each cycle. See logs.txt lines 88–161 for the smoking-gun
    // sequence.
    //
    // USER-DISCONNECTED GATE: The route-replacement flows (banner
    // Cancel, device-sheet Disconnect, factory reset) unmount MainShell,
    // so in production the banner is never seen in the idle/manual-
    // disconnected state. The `!userDisconnected` clause keeps the
    // formula correct as a pure invariant — any future code path that
    // leaves the user on MainShell while `userDisconnected=true` will
    // not resurrect a stale "Disconnected" banner.
    //
    // NOTE: `ref.read` (not `ref.watch`) — the disconnect flow mutates
    // `userDisconnectedProvider` synchronously alongside other writes
    // (`autoReconnectStateProvider`, `appInitProvider`) inside a single
    // callback that ends with `pushNamedAndRemoveUntil('/app', …)`. A
    // `watch` here adds MainShell as another listener of that mid-
    // teardown write, which (via Riverpod's notification path) caused
    // a "Tried to modify a provider while the widget tree was building"
    // assertion during the in-flight route replacement. The autoReconnect
    // and connection providers MainShell already watches re-trigger
    // its build whenever this gate would matter, so a one-shot read is
    // sufficient.
    final userDisconnected = ref.read(userDisconnectedProvider);
    final isFullyConnected = isConnected && !isReconnecting;
    final showReconnectionBanner =
        hasEverPaired && !isFullyConnected && !userDisconnected;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      drawerEdgeDragWidth: 40,
      body: Column(
        children: [
          // Reconnection status banner — sits above content when
          // disconnected after having paired before. Always in the tree
          // so it can animate in/out; visibility is driven by [visible].
          TopStatusBanner(
            autoReconnectState: autoReconnectState,
            autoReconnectEnabled: autoReconnectEnabled,
            visible: showReconnectionBanner,
            onVisibilityChanged: (visible) {
              if (mounted && visible != _bannerActuallyVisible) {
                setState(() => _bannerActuallyVisible = visible);
              }
            },
            onRetry: () {
              ref
                  .read(deviceConnectionProvider.notifier)
                  .startBackgroundConnection();
            },
            onGoToScanner: () {
              // Route-replace to the scanner via the declarative router
              // (mirrors the disconnect-button flow). Using the root
              // navigator + setNeedsScanner avoids ending up with a
              // scanner pushed on top of a still-mounted MainShell.
              ref.read(appInitProvider.notifier).setNeedsScanner();
              final nav = navigatorKey.currentState;
              if (nav != null) {
                AppLogging.connection(
                  'RECONNECT_CANCEL_ROUTE_REPLACE_SCANNER source=banner '
                  'method=pushNamedAndRemoveUntil dest=/app',
                );
                nav.pushNamedAndRemoveUntil('/app', (route) => false);
              } else {
                AppLogging.connection(
                  'RECONNECT_CANCEL_ROUTE_REPLACE_SCANNER source=banner '
                  'method=local_fallback (navigatorKey.currentState=null)',
                );
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/app', (route) => false);
              }
            },
            deviceState: deviceState,
          ),

          // Main content (fills remaining space below banner)
          // Users can fully interact with cached data while
          // reconnecting — app bars, drawers, and nav all work.
          Expanded(
            // Smoothly transition the top inset as the banner animates
            // in/out so the app bar doesn't jump when safe-area padding
            // is restored. Duration & curve match TopStatusBanner's
            // AnimationController so they stay in visual sync.
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                top: _bannerActuallyVisible
                    ? 0.0
                    : MediaQuery.of(context).padding.top,
              ),
              child: MediaQuery.removePadding(
                context: context,
                // Always strip the framework-level top inset — we
                // manage it ourselves via the AnimatedPadding above.
                removeTop: true,
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(
                          'main_${ref.watch(mainShellIndexProvider)}',
                        ),
                        child: _buildScreen(ref.watch(mainShellIndexProvider)),
                      ),
                    ),
                    // Aether flight match floating overlay — flush to bottom
                    if (AppFeatureFlags.isAetherEnabled)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AetherFlightDetectedOverlay(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Global countdown banner — sits just above the bottom nav bar
          // so it is visible regardless of which tab/screen is active
          // without obstructing app bar content (search fields, filters, etc.).
          if (ref.watch(hasActiveCountdownsProvider)) const CountdownBanner(),
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.1 : 0.2,
                  ),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkBackground.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: _buildBottomNavRow(l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavRow(AppLocalizations l10n) {
    final navItems = _buildNavItems(l10n);
    return Row(
      children: List.generate(navItems.length, (index) {
        final item = navItems[index];
        final isSelected = ref.watch(mainShellIndexProvider) == index;

        // Calculate badge count for each tab
        int badgeCount = 0;
        if (index == 0) {
          // Messages tab - show unread count
          badgeCount = ref.watch(unreadMessagesCountProvider);
        } else if (index == 2) {
          // Nodes tab - show new nodes count
          badgeCount = ref.watch(newNodesCountProvider);
        } else if (index == 3) {
          // Dashboard tab - no badge needed
          badgeCount = 0;
        }

        return Expanded(
          child: NavBarItem(
            icon: isSelected ? item.activeIcon : item.icon,
            label: item.label,
            isSelected: isSelected,
            badgeCount: badgeCount,
            showWarningBadge: false,
            showReconnectingBadge: false,
            onTap: () {
              ref.haptics.tabChange();
              // Clear new nodes badge when navigating to Nodes tab
              if (index == 2) {
                ref.read(newNodesCountProvider.notifier).reset();
              }
              ref.read(mainShellIndexProvider.notifier).setIndex(index);
            },
          ),
        );
      }),
    );
  }
}

/// Settings button for the drawer footer
class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.settings_outlined,
          size: 22,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
