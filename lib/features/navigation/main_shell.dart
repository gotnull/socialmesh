import 'dart:io';

import '../../core/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/node_avatar.dart';
import '../../models/user_profile.dart' show UserPreferences;
import '../../core/widgets/animations.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../models/subscription_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/social_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/haptic_service.dart';
import '../channels/channels_screen.dart';
import '../messaging/messaging_screen.dart';
import '../nodes/nodes_screen.dart';
import '../map/map_screen.dart';
import '../dashboard/widget_dashboard_screen.dart';
import '../scanner/scanner_screen.dart';
import '../device/region_selection_screen.dart';
import '../timeline/timeline_screen.dart';
import '../routes/routes_screen.dart';
import '../automations/automations_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../settings/ringtone_screen.dart';
import '../settings/ifttt_config_screen.dart';
import '../presence/presence_screen.dart';
import '../mesh3d/mesh_3d_screen.dart';
import '../world_mesh/world_mesh_screen.dart';
import '../settings/subscription_screen.dart';
import '../widget_builder/widget_builder_screen.dart';
import '../reachability/mesh_reachability_screen.dart';
// Removed: import '../sky_tracker/screens/sky_tracker_screen.dart';
import '../device_shop/screens/device_shop_screen.dart';
import '../device_shop/screens/shop_admin_dashboard.dart';
import '../device_shop/screens/review_moderation_screen.dart';
import '../device_shop/providers/admin_shop_providers.dart';
import '../mesh_health/widgets/mesh_health_dashboard.dart';
import '../social/social.dart';
import '../social/screens/reported_content_screen.dart';

/// Combined admin notification count provider
final adminNotificationCountProvider = Provider<int>((ref) {
  final reviewCount = ref
      .watch(pendingReviewCountProvider)
      .when(data: (count) => count, loading: () => 0, error: (e, stack) => 0);
  final reportCount = ref
      .watch(pendingReportCountProvider)
      .when(data: (count) => count, loading: () => 0, error: (e, stack) => 0);
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

/// Widget to create a hamburger menu button for app bars
/// Automatically shows a back button if the screen was pushed onto the navigation stack
class HamburgerMenuButton extends ConsumerWidget {
  const HamburgerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = ref.watch(mainShellScaffoldKeyProvider);
    final theme = Theme.of(context);
    final adminNotificationCount = ref.watch(adminNotificationCountProvider);

    // Check if we're NOT at the first route (meaning we were pushed onto the stack)
    // Using ModalRoute.of(context)?.isFirst is more reliable than canPop()
    // as it checks if this specific route is the first in the navigator
    final modalRoute = ModalRoute.of(context);
    final isFirstRoute = modalRoute?.isFirst ?? true;
    final canPop = !isFirstRoute && Navigator.of(context).canPop();

    if (canPop) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        tooltip: 'Back',
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.menu,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            // Try to open the drawer from MainShell
            // If drawer couldn't be opened (e.g., context issue), show as bottom sheet
            if (scaffoldKey?.currentState != null) {
              scaffoldKey!.currentState!.openDrawer();
            } else {
              _showQuickAccessSheet(context, ref);
            }
          },
          tooltip: 'Menu',
        ),
        if (adminNotificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
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
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  adminNotificationCount > 99
                      ? '99+'
                      : '$adminNotificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showQuickAccessSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Quick Access',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontFamily,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
            // Quick access items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  _QuickAccessTile(
                    icon: Icons.public,
                    label: 'World Map',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WorldMeshScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessTile(
                    icon: Icons.view_in_ar,
                    label: '3D Mesh View',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const Mesh3DScreen()),
                      );
                    },
                  ),
                  _QuickAccessTile(
                    icon: Icons.timeline,
                    label: 'Timeline',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TimelineScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessTile(
                    icon: Icons.people_alt_outlined,
                    label: 'Presence',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PresenceScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessTile(
                    icon: Icons.route,
                    label: 'Routes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RoutesScreen()),
                      );
                    },
                  ),
                  _QuickAccessTile(
                    icon: Icons.auto_awesome,
                    label: 'Automations',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AutomationsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessTile(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick access tile for modal sheet
class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

/// Drawer menu item data for quick access screens
class _DrawerMenuItem {
  final IconData icon;
  final String label;
  final Widget screen;
  final PremiumFeature? premiumFeature;
  final String? sectionHeader;
  final Color? iconColor;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.screen,
    this.premiumFeature,
    this.sectionHeader,
    this.iconColor,
  });
}

/// Main navigation shell with bottom navigation bar
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 3; // Start on Nodes tab
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedDrawerItem =
      -1; // -1 means no drawer item selected (showing main nav)

  @override
  void initState() {
    super.initState();
    // Set the scaffold key provider so screens can access the drawer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainShellScaffoldKeyProvider.notifier).setKey(_scaffoldKey);
    });
  }

  /// Drawer menu items for quick access screens not in bottom nav
  /// Organized into logical sections with headers
  final List<_DrawerMenuItem> _drawerMenuItems = [
    // Social - index 0, account tile navigates here
    _DrawerMenuItem(
      icon: Icons.forum_outlined,
      label: 'Social',
      screen: const SocialHubScreen(),
      iconColor: Colors.deepPurple.shade400,
    ),

    // Activity
    _DrawerMenuItem(
      icon: Icons.timeline,
      label: 'Timeline',
      screen: const TimelineScreen(),
      sectionHeader: 'ACTIVITY',
      iconColor: Colors.indigo.shade400,
    ),
    _DrawerMenuItem(
      icon: Icons.people_alt_outlined,
      label: 'Presence',
      screen: const PresenceScreen(),
      iconColor: Colors.green.shade400,
    ),

    // Mesh Features
    _DrawerMenuItem(
      icon: Icons.public,
      label: 'World Map',
      screen: const WorldMeshScreen(),
      sectionHeader: 'MESH FEATURES',
      iconColor: Colors.blue.shade400,
    ),
    _DrawerMenuItem(
      icon: Icons.view_in_ar,
      label: '3D Mesh View',
      screen: const Mesh3DScreen(),
      iconColor: Colors.cyan.shade400,
    ),
    _DrawerMenuItem(
      icon: Icons.route,
      label: 'Routes',
      screen: const RoutesScreen(),
      iconColor: Colors.purple.shade400,
    ),
    _DrawerMenuItem(
      icon: Icons.wifi_find,
      label: 'Reachability',
      screen: const MeshReachabilityScreen(),
      iconColor: Colors.teal.shade400,
    ),
    _DrawerMenuItem(
      icon: Icons.monitor_heart_outlined,
      label: 'Mesh Health',
      screen: const MeshHealthDashboard(),
      iconColor: Colors.pink.shade400,
    ),

    // Tools
    _DrawerMenuItem(
      icon: Icons.store,
      label: 'Device Shop',
      screen: const DeviceShopScreen(),
      sectionHeader: 'TOOLS',
      iconColor: Colors.amber.shade600,
    ),

    // Premium Features
    _DrawerMenuItem(
      icon: Icons.palette_outlined,
      label: 'Theme Pack',
      screen: const ThemeSettingsScreen(),
      premiumFeature: PremiumFeature.premiumThemes,
      sectionHeader: 'PREMIUM FEATURES',
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
      icon: Icons.wifi_tethering_outlined,
      activeIcon: Icons.wifi_tethering,
      label: 'Channels',
    ),
    _NavItem(
      icon: Icons.message_outlined,
      activeIcon: Icons.message,
      label: 'Messages',
    ),
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
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
    // If a drawer item is selected, show that screen
    if (_selectedDrawerItem >= 0 &&
        _selectedDrawerItem < _drawerMenuItems.length) {
      return _drawerMenuItems[_selectedDrawerItem].screen;
    }
    // Otherwise show the bottom nav screen
    switch (index) {
      case 0:
        return const ChannelsScreen();
      case 1:
        return const MessagingScreen();
      case 2:
        return const MapScreen();
      case 3:
        return const NodesScreen();
      case 4:
        return const WidgetDashboardScreen();
      default:
        return const ChannelsScreen();
    }
  }

  /// Build drawer menu slivers with sticky section headers
  List<Widget> _buildDrawerMenuSlivers(BuildContext context, ThemeData theme) {
    final slivers = <Widget>[];

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
              final globalIndex = itemWithIndex.index;
              final isSelected = _selectedDrawerItem == globalIndex;
              final isLastInSection = index == section.items.length - 1;

              // Check if this is a premium feature and if user has access
              final isPremium = item.premiumFeature != null;
              final hasAccess =
                  !isPremium ||
                  ref.watch(hasFeatureProvider(item.premiumFeature!));

              return Column(
                children: [
                  _DrawerMenuTile(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    isPremium: isPremium,
                    isLocked: isPremium && !hasAccess,
                    iconColor: item.iconColor,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.of(context).pop();

                      if (isPremium && !hasAccess) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const SubscriptionScreen(),
                          ),
                        );
                      } else {
                        setState(() {
                          _selectedDrawerItem = globalIndex;
                        });
                      }
                    },
                  ),
                  // Add divider after last item in section
                  if (isLastInSection && !isLastSection)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Divider(
                        color: theme.dividerColor.withValues(alpha: 0.1),
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
              isSelected: _selectedDrawerItem == 0,
              onTap: () {
                ref.haptics.tabChange();
                Navigator.of(context).pop();
                setState(() {
                  _selectedDrawerItem = 0;
                });
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

    final displayName = profile?.displayName ?? 'Mesh User';
    final initials = profile?.initials ?? '?';
    final avatarUrl = profile?.avatarUrl;

    String getSyncStatusText() {
      if (!isSignedIn) return 'Not signed in';
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
          Navigator.of(context).pop();
          setState(() {
            _selectedDrawerItem = 0;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? (avatarUrl.startsWith('http')
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: accentColor,
                                          ),
                                        ),
                                      );
                                    },
                                errorBuilder: (ctx, err, stack) =>
                                    _buildInitials(initials, accentColor),
                              )
                            : Image.file(
                                File(avatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    _buildInitials(initials, accentColor),
                              ))
                      : _buildInitials(initials, accentColor),
                ),
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
                        if (syncStatus == SyncStatus.syncing)
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

  Widget _buildInitials(String initials, Color accentColor) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);

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
              child: Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),

            // Account section - inline so setState works
            _buildAccountSection(context, theme),

            // Divider after account
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
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
                        Navigator.of(context).pop();
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => screen));
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
                        color: theme.dividerColor.withValues(alpha: 0.1),
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
              child: Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),

            // Theme toggle & Settings
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  const _ThemeToggleButton(),
                  const Spacer(),
                  _SettingsButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
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

    // Check if we need to show the "Connect Device" screen
    // Show it when: not connected AND not reconnecting AND auto-reconnect is disabled
    // This forces manual connection when the user has opted out of auto-reconnect
    final autoReconnectEnabled =
        settingsAsync.whenOrNull(data: (settings) => settings.autoReconnect) ??
        true;

    // Only gate on auto-reconnect if we're genuinely disconnected
    // If connected (even with auto-reconnect disabled), show the main app
    if (!isConnected && !isReconnecting && !autoReconnectEnabled) {
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
      return const RegionSelectionScreen(isInitialSetup: true);
    }

    // Build the main scaffold with Drawer
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      drawerEdgeDragWidth: 40, // Edge area for swipe gesture
      body: AnimatedSwitcher(
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
            _selectedDrawerItem >= 0
                ? 'drawer_$_selectedDrawerItem'
                : 'main_$_currentIndex',
          ),
          child: _buildScreen(_currentIndex),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
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
                final isSelected =
                    _currentIndex == index && _selectedDrawerItem < 0;

                // Show warning badge on Device tab (index 4) when disconnected
                final showWarningBadge = index == 4 && !isConnected;
                // Show reconnecting indicator
                final showReconnectingBadge = index == 4 && isReconnecting;
                // Show badge on Nodes tab (index 3) when new nodes discovered
                final showNodesBadge = index == 3 && _hasNewNodes(ref);

                return _NavBarItem(
                  icon: isSelected ? item.activeIcon : item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  showBadge:
                      (index == 1 && _hasUnreadMessages(ref)) || showNodesBadge,
                  showWarningBadge: showWarningBadge && !showReconnectingBadge,
                  showReconnectingBadge: showReconnectingBadge,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Clear new nodes badge when navigating to Nodes tab
                    if (index == 3) {
                      ref.read(newNodesCountProvider.notifier).reset();
                    }
                    setState(() {
                      _currentIndex = index;
                      _selectedDrawerItem = -1; // Clear drawer selection
                    });
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasUnreadMessages(WidgetRef ref) {
    return ref.watch(hasUnreadMessagesProvider);
  }

  bool _hasNewNodes(WidgetRef ref) {
    return ref.watch(newNodesCountProvider) > 0;
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
  final bool showBadge;
  final bool showWarningBadge;
  final bool showReconnectingBadge;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.showBadge = false,
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
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
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedMorphIcon(
                    icon: icon,
                    size: 24,
                    color: iconColor,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
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
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
  final VoidCallback onTap;
  final int? badgeCount;
  final Color? iconColor;

  const _DrawerMenuTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPremium = false,
    this.isLocked = false,
    this.badgeCount,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final goldColor = Colors.amber.shade600;

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : isLocked
              ? goldColor.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: accentColor.withValues(alpha: 0.3))
              : isLocked
              ? Border.all(color: goldColor.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.2)
                    : isLocked
                    ? goldColor.withValues(alpha: 0.1)
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
                        ? goldColor
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
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontFamily: AppTheme.fontFamily,
                  color: isSelected
                      ? accentColor
                      : isLocked
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            // Show lock icon and PRO badge for locked premium features
            if (isLocked) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [goldColor, goldColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: goldColor.withValues(alpha: 0.3),
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

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentMode = ref.watch(themeModeProvider);
    final isDark =
        currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
        ref.read(themeModeProvider.notifier).setThemeMode(newMode);

        // Save to storage
        final settings = await ref.read(settingsServiceProvider.future);
        await settings.setThemeMode(newMode.index);

        // Sync to cloud profile
        ref
            .read(userProfileProvider.notifier)
            .updatePreferences(UserPreferences(themeModeIndex: newMode.index));
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
          isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          size: 22,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
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

/// Admin section in the drawer - only visible to shop admins
class _DrawerAdminSection extends ConsumerWidget {
  final void Function(Widget screen) onNavigate;

  const _DrawerAdminSection({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isShopAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (!isAdmin) return const SizedBox.shrink();

        final theme = Theme.of(context);

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

                  // Shop Admin Dashboard
                  _DrawerMenuTile(
                    icon: Icons.dashboard_customize,
                    label: 'Shop Admin',
                    isSelected: false,
                    iconColor: Colors.purple.shade400,
                    onTap: () {
                      ref.haptics.tabChange();
                      onNavigate(const ShopAdminDashboard());
                    },
                  ),

                  // Review Moderation
                  _DrawerMenuTile(
                    icon: Icons.rate_review_outlined,
                    label: 'Review Moderation',
                    isSelected: false,
                    iconColor: Colors.amber.shade600,
                    badgeCount: ref
                        .watch(pendingReviewCountProvider)
                        .when(
                          data: (count) => count,
                          loading: () => null,
                          error: (e, stack) => null,
                        ),
                    onTap: () {
                      ref.haptics.tabChange();
                      onNavigate(const ReviewModerationScreen());
                    },
                  ),

                  // Reported Content
                  _DrawerMenuTile(
                    icon: Icons.flag_outlined,
                    label: 'Reported Content',
                    isSelected: false,
                    iconColor: Colors.red.shade400,
                    badgeCount: ref
                        .watch(pendingReportCountProvider)
                        .when(
                          data: (count) => count,
                          loading: () => null,
                          error: (e, stack) => null,
                        ),
                    onTap: () {
                      ref.haptics.tabChange();
                      onNavigate(const ReportedContentScreen());
                    },
                  ),
                ],
              ),
            ),

            // Divider after admin section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
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
    return Container(
      color: theme.scaffoldBackgroundColor,
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
