// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui';

import '../../core/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/admin_pin_dialog.dart';
import '../../core/widgets/node_avatar.dart';
import '../../core/widgets/connection_required_wrapper.dart';
import '../../core/widgets/top_status_banner.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../generated/meshtastic/mesh.pbenum.dart';
import '../../models/subscription_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/connection_providers.dart';
import '../../providers/connectivity_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/signal_providers.dart';
import '../../providers/social_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/notifications/notification_service.dart';
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
import '../widget_builder/widget_builder_screen.dart';
import '../reachability/mesh_reachability_screen.dart';
import '../device_shop/providers/admin_shop_providers.dart';
import '../mesh_health/widgets/mesh_health_dashboard.dart';
import '../signals/signals.dart';
import '../profile/profile_screen.dart';
import '../debug/device_logs_screen.dart';
import '../nodedex/screens/nodedex_screen.dart';
import '../social/screens/activity_timeline_screen.dart';
import '../../providers/activity_providers.dart';
import '../../providers/whats_new_providers.dart';
import '../../core/whats_new/whats_new_sheet.dart';
import '../admin/screens/admin_screen.dart';

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
  int build() => 3; // start on Nodes tab

  void setIndex(int idx) {
    state = idx;
  }
}

final mainShellIndexProvider = NotifierProvider<MainShellIndexNotifier, int>(
  MainShellIndexNotifier.new,
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
    final hasUnseenWhatsNew = ref.watch(whatsNewHasUnseenProvider);

    // Combine admin and activity counts for hamburger badge
    final totalBadgeCount = adminNotificationCount + activityCount;

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
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red,
        child: menuIcon,
      );
    } else if (hasUnseenWhatsNew) {
      // Gradient dot — small indicator for unseen What's New
      menuIcon = Badge(
        smallSize: 10,
        backgroundColor: AppTheme.primaryMagenta,
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
      tooltip: 'Menu',
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
      tooltip: 'Device',
    );
  }
}

/// Drawer menu item data for quick access screens
class _DrawerMenuItem {
  final IconData icon;
  final String label;

  /// Screen to push when tapped. Null when [tabIndex] is used instead.
  final Widget? screen;

  /// When non-null, tapping this item switches the bottom-nav to this
  /// tab index instead of pushing a new screen.
  final int? tabIndex;

  final PremiumFeature? premiumFeature;
  final String? sectionHeader;
  final Color? iconColor;
  final bool requiresConnection;

  /// Provider key for badge count - use 'activity' for activity count
  final String? badgeProviderKey;

  /// Key that links this item to a What's New payload badge.
  /// When a matching key is in the unseen badge keys set, a NEW chip
  /// is shown next to this drawer item.
  final String? whatsNewBadgeKey;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    this.screen,
    this.tabIndex,
    this.premiumFeature,
    this.sectionHeader,
    this.iconColor,
    this.requiresConnection = false,
    this.badgeProviderKey,
    this.whatsNewBadgeKey,
  });
}

/// Helper to navigate from drawer items.
/// Closes drawer first, then navigates after a brief delay to ensure
/// the drawer close animation completes smoothly.
void _navigateFromDrawer(BuildContext context, Widget screen) {
  Navigator.of(context).pop(); // Close drawer
  // Use post-frame callback to ensure drawer animation completes
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    }
  });
}

/// Main navigation shell with bottom navigation bar
// Global key to reference the existing PresenceFeedScreen instance when it's
// part of the MainShell. This allows other widgets to instruct the presence
// screen to focus a specific signal without pushing additional routes.
final GlobalKey presenceFeedScreenKey = GlobalKey();

/// Global key for the bottom navigation bar so utilities (e.g., snackbars)
/// can measure its runtime height instead of hardcoding offsets.
final GlobalKey mainShellBottomNavKey = GlobalKey();

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mainShellScaffoldKeyProvider.notifier).setKey(_scaffoldKey);

        // Trigger What's New popup if there is an unseen payload.
        // This runs after the first frame so the navigator is ready.
        WhatsNewSheet.showIfNeeded(ref);
      }
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
  /// Organized into logical sections with headers
  final List<_DrawerMenuItem> _drawerMenuItems = [
    // Social section — Signals switches to bottom-nav tab 2
    _DrawerMenuItem(
      icon: Icons.sensors,
      label: 'Signals',
      tabIndex: 2,
      sectionHeader: 'SOCIAL',
      iconColor: Colors.purple.shade300,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.auto_stories_outlined,
      label: 'NodeDex',
      screen: const NodeDexScreen(),
      iconColor: Colors.amber.shade400,
      requiresConnection: false,
      whatsNewBadgeKey: 'nodedex',
    ),
    _DrawerMenuItem(
      icon: Icons.favorite_border,
      label: 'Activity',
      screen: const ActivityTimelineScreen(),
      iconColor: Colors.red.shade400,
      requiresConnection: false,
      badgeProviderKey: 'activity',
    ),
    _DrawerMenuItem(
      icon: Icons.timeline,
      label: 'Timeline',
      screen: const TimelineScreen(),
      sectionHeader: 'MESH',
      iconColor: Colors.indigo.shade400,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.people_alt_outlined,
      label: 'Presence',
      screen: const PresenceScreen(),
      iconColor: Colors.green.shade400,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.public,
      label: 'World Map',
      screen: const WorldMeshScreen(),
      iconColor: Colors.blue.shade400,
      requiresConnection: false, // Shows global mesh data from server
    ),
    _DrawerMenuItem(
      icon: Icons.view_in_ar,
      label: '3D Mesh View',
      screen: const Mesh3DScreen(),
      iconColor: Colors.cyan.shade400,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.route,
      label: 'Routes',
      screen: const RoutesScreen(),
      iconColor: Colors.purple.shade400,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.wifi_find,
      label: 'Reachability',
      screen: const MeshReachabilityScreen(),
      iconColor: Colors.teal.shade400,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.monitor_heart_outlined,
      label: 'Mesh Health',
      screen: const MeshHealthDashboard(),
      iconColor: Colors.pink.shade400,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.terminal,
      label: 'Device Logs',
      screen: const DeviceLogsScreen(),
      iconColor: Colors.grey.shade500,
      requiresConnection: true,
    ),

    // Shop - below MESH section
    // _DrawerMenuItem(
    //   icon: Icons.store_outlined,
    //   label: 'Device Shop',
    //   screen: const DeviceShopScreen(),
    //   sectionHeader: 'SHOP',
    //   iconColor: Colors.amber.shade600,
    //   requiresConnection: false,
    // ),

    // Premium Features - mixed requirements
    _DrawerMenuItem(
      icon: Icons.palette_outlined,
      label: 'Theme Pack',
      screen: const ThemeSettingsScreen(),
      premiumFeature: PremiumFeature.premiumThemes,
      sectionHeader: 'PREMIUM',
      iconColor: Colors.purple.shade400,
    ),
    _DrawerMenuItem(
      icon: Icons.music_note_outlined,
      label: 'Ringtone Pack',
      screen: const RingtoneScreen(),
      premiumFeature: PremiumFeature.customRingtones,
      iconColor: Colors.pink.shade300,
    ),
    _DrawerMenuItem(
      icon: Icons.widgets_outlined,
      label: 'Widgets',
      screen: const WidgetBuilderScreen(),
      premiumFeature: PremiumFeature.homeWidgets,
      iconColor: Colors.deepOrange.shade400,
    ),
    _DrawerMenuItem(
      icon: Icons.auto_awesome,
      label: 'Automations',
      screen: const AutomationsScreen(),
      premiumFeature: PremiumFeature.automations,
      iconColor: Colors.yellow.shade700,
      requiresConnection: true,
    ),
    _DrawerMenuItem(
      icon: Icons.webhook_outlined,
      label: 'IFTTT Integration',
      screen: const IftttConfigScreen(),
      premiumFeature: PremiumFeature.iftttIntegration,
      iconColor: Colors.blue.shade300,
    ),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Messages',
    ),
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _NavItem(
      icon: Icons.sensors_outlined,
      activeIcon: Icons.sensors,
      label: 'Signals',
    ),
    _NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Nodes',
    ),
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
  ];

  Widget _buildScreen(int index) {
    // All screens are wrapped with ConnectionRequiredWrapper to show consistent
    // "No Device Connected" UI when disconnected. The wrapper renders a full
    // Scaffold when disconnected so user sees consistent UI across all tabs.
    switch (index) {
      case 0:
        return const ConnectionRequiredWrapper(
          screenTitle: 'Messages',
          child: MessagesContainerScreen(),
        );
      case 1:
        return const ConnectionRequiredWrapper(
          screenTitle: 'Map',
          child: MapScreen(),
        );
      case 2:
        return ConnectionRequiredWrapper(
          screenTitle: 'Signals',
          child: PresenceFeedScreen(key: presenceFeedScreenKey),
        );
      case 3:
        return const ConnectionRequiredWrapper(
          screenTitle: 'Nodes',
          child: NodesScreen(),
        );
      case 4:
        // Dashboard requires connection for live widget data
        return const ConnectionRequiredWrapper(
          screenTitle: 'Dashboard',
          child: WidgetDashboardScreen(),
        );
      default:
        return const ConnectionRequiredWrapper(
          screenTitle: 'Messages',
          child: MessagesContainerScreen(),
        );
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
    final sections = <_DrawerMenuSection>[];
    _DrawerMenuSection? currentSection;

    for (var i = 0; i < _drawerMenuItems.length; i++) {
      final item = _drawerMenuItems[i];

      if (item.sectionHeader != null) {
        // Start new section
        if (currentSection != null) {
          sections.add(currentSection);
        }
        currentSection = _DrawerMenuSection(item.sectionHeader!, []);
      }

      if (currentSection != null) {
        currentSection.items.add(_DrawerMenuItemWithIndex(item, i));
      } else {
        // Items before any section header go in a special section
        if (sections.isEmpty || sections.last.title.isNotEmpty) {
          sections.add(_DrawerMenuSection('', []));
        }
        sections.last.items.add(_DrawerMenuItemWithIndex(item, i));
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
            delegate: _DrawerStickyHeaderDelegate(
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
              }

              // Check if this item should show a NEW chip
              final isNew =
                  item.whatsNewBadgeKey != null &&
                  unseenBadgeKeys.contains(item.whatsNewBadgeKey);

              return Column(
                children: [
                  _DrawerMenuTile(
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
                            if (item.tabIndex != null) {
                              // Tab-based item — switch bottom-nav index
                              Navigator.of(context).pop(); // close drawer
                              ref
                                  .read(mainShellIndexProvider.notifier)
                                  .setIndex(item.tabIndex!);
                            } else if (isPremium && !allowNavigation) {
                              // Upsell disabled - redirect to subscription screen
                              _navigateFromDrawer(
                                context,
                                const SubscriptionScreen(),
                              );
                            } else if (item.screen != null) {
                              // Push screen with back button for consistent navigation
                              // If upsell is enabled, the screen handles gating on actions
                              _navigateFromDrawer(context, item.screen!);
                            }
                          },
                  ),
                  // Add spacing between items within a section
                  if (!isLastInSection) const SizedBox(height: 4),
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
              'ACCOUNT',
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
            error: (e, st) => _DrawerMenuTile(
              icon: Icons.person_outline,
              label: 'Account',
              isSelected: false,
              onTap: () {
                ref.haptics.tabChange();
                final firstItem = _drawerMenuItems[0];
                if (firstItem.tabIndex != null) {
                  Navigator.of(context).pop();
                  ref
                      .read(mainShellIndexProvider.notifier)
                      .setIndex(firstItem.tabIndex!);
                } else if (firstItem.screen != null) {
                  _navigateFromDrawer(context, firstItem.screen!);
                }
              },
            ),
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

    final displayName = profile?.displayName ?? 'Guest';
    final initials = profile?.initials ?? '?';
    final avatarUrl = profile?.avatarUrl;

    String getSyncStatusText() {
      if (!isSignedIn) return 'Not signed in';
      if (!isOnline) return 'Offline';
      return switch (syncStatus) {
        SyncStatus.syncing => 'Syncing...',
        SyncStatus.error => 'Sync error',
        SyncStatus.synced => 'Synced',
        SyncStatus.idle => 'View Profile',
      };
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.haptics.tabChange();
          // Navigate to Account screen if not signed in, Profile screen otherwise
          if (isSignedIn) {
            _navigateFromDrawer(context, const ProfileScreen());
          } else {
            _navigateFromDrawer(context, const AccountSubscriptionsScreen());
          }
        },
        borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
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
    final theme = Theme.of(context);
    // Use themeModeProvider for brightness to stay in sync with toggle button
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
            const _DrawerNodeHeader(),

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

                  // Admin section (only visible to shop admins)
                  SliverToBoxAdapter(
                    child: _DrawerAdminSection(
                      onNavigate: (screen) {
                        _navigateFromDrawer(context, screen);
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
                      child: _DrawerMenuTile(
                        icon: Icons.help_outline,
                        label: 'Help & Support',
                        isSelected: false,
                        iconColor: Colors.blue.shade400,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SettingsButton(
                  onTap: () {
                    _navigateFromDrawer(context, const SettingsScreen());
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
    ref.listen(clientNotificationStreamProvider, (previous, next) {
      next.whenData((notification) {
        final level = notification.level;
        final message = notification.message;
        final levelName = level.name;

        // Show appropriate snackbar based on severity level
        if (level == LogRecord_Level.ERROR ||
            level == LogRecord_Level.CRITICAL) {
          showErrorSnackBar(context, 'Firmware: $message');
          // Also show a local push notification for critical errors
          // This ensures user sees the error even if app is backgrounded
          NotificationService().showFirmwareNotification(
            title: 'Meshtastic Device Error',
            message: message,
            level: levelName,
          );
        } else if (level == LogRecord_Level.WARNING) {
          showWarningSnackBar(context, 'Firmware: $message');
          // Push notification for warnings too - they're important
          NotificationService().showFirmwareNotification(
            title: 'Meshtastic Device Warning',
            message: message,
            level: levelName,
          );
        } else if (level == LogRecord_Level.INFO) {
          showInfoSnackBar(context, 'Firmware: $message');
        }
        // DEBUG and TRACE levels are not shown to user
      });
    });

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
    final showReconnectionBanner = !isConnected && hasEverPaired;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      drawerEdgeDragWidth: 40,
      body: Stack(
        children: [
          // Main content (fills available space)
          // Allow user interaction even when reconnection banner is showing
          // The app should remain usable with cached data while reconnecting
          Positioned.fill(
            child: AnimatedSwitcher(
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
                key: ValueKey('main_${ref.watch(mainShellIndexProvider)}'),
                child: _buildScreen(ref.watch(mainShellIndexProvider)),
              ),
            ),
          ),

          // Reconnection status banner - overlays content when disconnected after having paired before
          if (showReconnectionBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopStatusBanner(
                autoReconnectState: autoReconnectState,
                autoReconnectEnabled: autoReconnectEnabled,
                onRetry: () {
                  ref
                      .read(deviceConnectionProvider.notifier)
                      .startBackgroundConnection();
                },
                onGoToScanner: () =>
                    Navigator.of(context).pushNamed('/scanner'),
                deviceState: deviceState,
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        key: mainShellBottomNavKey,
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = ref.watch(mainShellIndexProvider) == index;

                // Calculate badge count for each tab
                int badgeCount = 0;
                if (index == 0) {
                  // Messages tab - show unread count
                  badgeCount = ref.watch(unreadMessagesCountProvider);
                } else if (index == 2) {
                  // Signals tab - show active signal count
                  badgeCount = ref.watch(activeSignalCountProvider);
                } else if (index == 3) {
                  // Nodes tab - show new nodes count
                  badgeCount = ref.watch(newNodesCountProvider);
                } else if (index == 4) {
                  // Dashboard tab - no badge needed
                  badgeCount = 0;
                }

                return _NavBarItem(
                  icon: isSelected ? item.activeIcon : item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  badgeCount: badgeCount,
                  showWarningBadge: false,
                  showReconnectingBadge: false,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Clear new nodes badge when navigating to Nodes tab
                    if (index == 3) {
                      ref.read(newNodesCountProvider.notifier).reset();
                    }
                    ref.read(mainShellIndexProvider.notifier).setIndex(index);
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final bool showWarningBadge;
  final bool showReconnectingBadge;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    this.showWarningBadge = false,
    this.showReconnectingBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine icon color
    final accentColor = theme.colorScheme.primary;
    Color iconColor;
    if (isSelected) {
      iconColor = accentColor;
    } else if (showReconnectingBadge) {
      iconColor = Colors.amber;
    } else if (showWarningBadge) {
      iconColor = Colors.orange;
    } else {
      iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    // Determine label color
    Color labelColor;
    if (isSelected) {
      labelColor = accentColor;
    } else if (showReconnectingBadge) {
      labelColor = Colors.amber;
    } else if (showWarningBadge) {
      labelColor = Colors.orange;
    } else {
      labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: AppCurves.overshoot,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 350),
                  curve: AppCurves.overshoot,
                  child: isSelected
                      ? ShaderMask(
                          shaderCallback: (bounds) {
                            final gradientColors = AccentColors.gradientFor(
                              accentColor,
                            );
                            return LinearGradient(
                              colors: [gradientColors[0], gradientColors[1]],
                            ).createShader(bounds);
                          },
                          child: AnimatedMorphIcon(
                            icon: icon,
                            size: 24,
                            color: Colors.white,
                          ),
                        )
                      : AnimatedMorphIcon(
                          icon: icon,
                          size: 24,
                          color: iconColor,
                        ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: badgeCount > 9 ? 4 : 0,
                        vertical: 0,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showReconnectingBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: _PulsingDot(color: Colors.amber),
                  )
                else if (showWarningBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            isSelected
                ? ShaderMask(
                    shaderCallback: (bounds) {
                      final gradientColors = AccentColors.gradientFor(
                        accentColor,
                      );
                      return LinearGradient(
                        colors: [gradientColors[0], gradientColors[1]],
                      ).createShader(bounds);
                    },
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  )
                : AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: AppCurves.overshoot,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                      color: labelColor,
                      fontFamily: AppTheme.fontFamily,
                    ),
                    child: Text(label),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Menu tile for the navigation drawer
class _DrawerMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPremium;
  final bool isLocked;
  final bool showTryIt;
  final bool isDisabled;
  final VoidCallback? onTap;
  final int? badgeCount;
  final Color? iconColor;
  final bool showNewChip;

  const _DrawerMenuTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPremium = false,
    this.isLocked = false,
    this.showTryIt = false,
    this.isDisabled = false,
    this.badgeCount,
    this.iconColor,
    this.showNewChip = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final lockedColor = Colors.grey.shade600;
    final disabledAlpha = 0.35;

    return BouncyTap(
      onTap: onTap,
      enabled: !isDisabled,
      scaleFactor: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : isLocked
              ? lockedColor.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: accentColor.withValues(alpha: 0.3))
              : isLocked
              ? Border.all(color: lockedColor.withValues(alpha: 0.15))
              : null,
        ),
        child: Opacity(
          opacity: isDisabled ? disabledAlpha : 1.0,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.2)
                      : isLocked
                      ? lockedColor.withValues(alpha: 0.1)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? accentColor
                          : isLocked
                          ? lockedColor
                          : iconColor ??
                                theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                    ),
                    // Badge overlay on icon
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount! > 99 ? '99+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // NEW dot indicator on icon (shown when no count badge)
                    if (showNewChip && (badgeCount == null || badgeCount! <= 0))
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryMagenta,
                                AppTheme.primaryPurple,
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFamily: AppTheme.fontFamily,
                          color: isSelected
                              ? accentColor
                              : isLocked
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                )
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                        ),
                      ),
                    ),
                    if (showNewChip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryMagenta,
                              AppTheme.primaryPurple,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryMagenta.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.fontFamily,
                            color: SemanticColors.onAccent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Show lock icon and PRO badge for locked premium features
              if (isLocked) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [lockedColor, lockedColor.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: lockedColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (showTryIt) ...[
                // Show "TRY IT" badge when upsell is enabled but not owned
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'TRY IT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.amber,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isPremium) ...[
                // Show unlocked badge for purchased premium features
                Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: Colors.green.shade400,
                ),
              ] else if (isSelected) ...[
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: accentColor.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Node info header for the drawer - shows current node details
class _DrawerNodeHeader extends ConsumerWidget {
  const _DrawerNodeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final connectionStateAsync = ref.watch(connectionStateProvider);

    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (e, s) => false,
    );

    // Get node display info
    final nodeName = myNode?.longName ?? 'Not Connected';
    final nodeId = myNodeNum != null ? '!${myNodeNum.toRadixString(16)}' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node avatar - same as nodes screen for own node
          NodeAvatar(
            text: myNode?.shortName ?? '--',
            color: isConnected ? accentColor : theme.dividerColor,
            size: 56,
            showOnlineIndicator: true,
            onlineStatus: isConnected
                ? OnlineStatus.online
                : OnlineStatus.offline,
            batteryLevel: myNode?.batteryLevel,
            showBatteryBadge: myNode?.batteryLevel != null,
            border: isConnected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Node info - flexible column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and status on same row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nodeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Connection status indicator (compact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? AppTheme.successGreen.withValues(alpha: 0.15)
                            : AppTheme.errorRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isConnected ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontFamily: AppTheme.fontFamily,
                              color: isConnected
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isConnected && nodeId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    nodeId,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: AppTheme.fontFamily,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 2,
            ),
          ),
        );
      },
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

/// Admin section in the drawer - visible to shop admins with PIN protection
class _DrawerAdminSection extends ConsumerStatefulWidget {
  final void Function(Widget screen) onNavigate;

  const _DrawerAdminSection({required this.onNavigate});

  @override
  ConsumerState<_DrawerAdminSection> createState() =>
      _DrawerAdminSectionState();
}

class _DrawerAdminSectionState extends ConsumerState<_DrawerAdminSection> {
  Future<void> _handleAdminTap() async {
    ref.haptics.tabChange();

    // Show PIN verification dialog
    final verified = await AdminPinDialog.show(context);
    if (!mounted) return;

    if (verified) {
      widget.onNavigate(const AdminScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isShopAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (!isAdmin) return const SizedBox.shrink();

        final theme = Theme.of(context);

        // Combined badge count for admin notifications
        final badgeCount = ref.watch(adminNotificationCountProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 14,
                          color: Colors.orange.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.orange.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Single Admin entry with PIN protection
                  _DrawerMenuTile(
                    icon: Icons.shield_outlined,
                    label: 'Admin Dashboard',
                    isSelected: false,
                    iconColor: Colors.orange.shade400,
                    badgeCount: badgeCount > 0 ? badgeCount : null,
                    onTap: _handleAdminTap,
                  ),
                ],
              ),
            ),

            // Divider after admin section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(
                color: theme.dividerColor.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.1 : 0.2,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Helper class for grouping drawer menu items into sections
class _DrawerMenuSection {
  final String title;
  final List<_DrawerMenuItemWithIndex> items;

  _DrawerMenuSection(this.title, this.items);
}

/// Helper class to track menu item with its original index
class _DrawerMenuItemWithIndex {
  final _DrawerMenuItem item;
  final int index;

  _DrawerMenuItemWithIndex(this.item, this.index);
}

/// Sticky header delegate for drawer section headers
class _DrawerStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final ThemeData theme;

  _DrawerStickyHeaderDelegate({required this.title, required this.theme});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
          padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 32;

  @override
  double get minExtent => 32;

  @override
  bool shouldRebuild(covariant _DrawerStickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}

// Replaced by `TopStatusBanner` in `lib/core/widgets/top_status_banner.dart`.
// The global banner is now centralized; this legacy class was removed to avoid duplication.
