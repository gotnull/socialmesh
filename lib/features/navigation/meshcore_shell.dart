// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/node_avatar.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../providers/app_providers.dart';
import '../../providers/meshcore_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import '../meshcore/screens/meshcore_contacts_screen.dart';
import '../meshcore/screens/meshcore_channels_screen.dart';
import '../meshcore/screens/meshcore_tools_screen.dart';
import '../meshcore/screens/meshcore_map_screen.dart';
import '../meshcore/screens/meshcore_settings_screen.dart';

// MeshCore bottom navigation tab items
class _MeshCoreNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _MeshCoreNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Provider for controlling the currently selected tab in MeshCoreShell
class MeshCoreShellIndexNotifier extends Notifier<int> {
  @override
  int build() => 0; // Start on Contacts tab

  void setIndex(int idx) {
    state = idx;
  }
}

final meshCoreShellIndexProvider =
    NotifierProvider<MeshCoreShellIndexNotifier, int>(
      MeshCoreShellIndexNotifier.new,
    );

/// Notifier to expose the MeshCore shell's scaffold key for drawer access.
/// This mirrors mainShellScaffoldKeyProvider for consistency.
class MeshCoreShellScaffoldKeyNotifier
    extends Notifier<GlobalKey<ScaffoldState>?> {
  @override
  GlobalKey<ScaffoldState>? build() => null;

  void setKey(GlobalKey<ScaffoldState>? key) {
    state = key;
  }
}

/// Provider to expose the MeshCore shell's scaffold key for drawer access.
/// Used by MeshCoreHamburgerMenuButton to open the drawer from nested screens.
final meshCoreShellScaffoldKeyProvider =
    NotifierProvider<
      MeshCoreShellScaffoldKeyNotifier,
      GlobalKey<ScaffoldState>?
    >(MeshCoreShellScaffoldKeyNotifier.new);

/// Widget to create a hamburger menu button for MeshCore app bars.
/// Mirrors HamburgerMenuButton from MainShell for consistent UX.
class MeshCoreHamburgerMenuButton extends ConsumerWidget {
  const MeshCoreHamburgerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = ref.watch(meshCoreShellScaffoldKeyProvider);
    final theme = Theme.of(context);

    return IconButton(
      icon: Icon(
        Icons.menu,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        // Open the drawer using the provider-stored scaffold key
        final scaffoldState = scaffoldKey?.currentState;
        if (scaffoldState != null) {
          scaffoldState.openDrawer();
        } else {
          // Fallback: try to find a Scaffold ancestor
          try {
            Scaffold.of(context).openDrawer();
          } catch (e) {
            // If no Scaffold ancestor found, log the issue
            AppLogging.debug(
              '⚠️ MeshCoreHamburgerMenuButton: Could not open drawer',
            );
          }
        }
      },
      tooltip: 'Menu',
    );
  }
}

/// Device status button for MeshCore app bars.
/// Shows connection status with colored indicator and opens MeshCore device sheet.
/// Mirrors DeviceStatusButton from MainShell for consistent UX.
class MeshCoreDeviceStatusButton extends ConsumerWidget {
  const MeshCoreDeviceStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final isConnecting = linkStatus.isConnecting;

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.router,
            color: isConnected
                ? context.accentColor
                : isConnecting
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
                    : isConnecting
                    ? AppTheme.warningYellow
                    : AppTheme.errorRed,
                shape: BoxShape.circle,
                border: Border.all(color: context.background, width: 2),
              ),
            ),
          ),
        ],
      ),
      onPressed: () => showMeshCoreDeviceSheet(context),
      tooltip: 'Device',
    );
  }
}

/// Shows the MeshCore device sheet as a modal bottom sheet
void showMeshCoreDeviceSheet(BuildContext context) {
  AppBottomSheet.showScrollable(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (scrollController) =>
        _MeshCoreDeviceSheetContent(scrollController: scrollController),
  );
}

/// MeshCore-specific app shell.
///
/// This shell is mounted ONLY when activeProtocol == meshcore.
/// It has its own navigation, drawer, and screens that are completely
/// separate from the Meshtastic shell (MainShell).
///
/// Key design:
/// - Contacts tab (primary for MeshCore)
/// - Channels tab
/// - Map tab
/// - Tools/Settings tab
class MeshCoreShell extends ConsumerStatefulWidget {
  const MeshCoreShell({super.key});

  @override
  ConsumerState<MeshCoreShell> createState() => _MeshCoreShellState();
}

class _MeshCoreShellState extends ConsumerState<MeshCoreShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Register scaffold key after build so drawer can be opened from nested screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meshCoreShellScaffoldKeyProvider.notifier).setKey(_scaffoldKey);
    });
  }

  @override
  void dispose() {
    // Clear scaffold key on dispose
    ref.read(meshCoreShellScaffoldKeyProvider.notifier).setKey(null);
    super.dispose();
  }

  final List<_MeshCoreNavItem> _navItems = [
    const _MeshCoreNavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Contacts',
    ),
    const _MeshCoreNavItem(
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum,
      label: 'Channels',
    ),
    const _MeshCoreNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: 'Map',
    ),
    const _MeshCoreNavItem(
      icon: Icons.build_outlined,
      activeIcon: Icons.build,
      label: 'Tools',
    ),
  ];

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const MeshCoreContactsScreen();
      case 1:
        return const MeshCoreChannelsScreen();
      case 2:
        return const MeshCoreMapScreen();
      case 3:
        return const MeshCoreToolsScreen();
      default:
        return const MeshCoreContactsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = ref.watch(meshCoreShellIndexProvider);
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final isConnecting = linkStatus.isConnecting;
    final deviceName = linkStatus.deviceName ?? 'MeshCore';

    // Determine if we should show reconnection banner
    final showReconnectionBanner = !isConnected && !isConnecting;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildDrawer(context, theme),
      body: Column(
        children: [
          // Top status banner for disconnection/reconnection
          if (showReconnectionBanner)
            _buildDisconnectedBanner(context, theme, deviceName),
          // Main content
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: List.generate(
                _navItems.length,
                (index) => _buildScreen(index),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, theme, selectedIndex),
    );
  }

  Widget _buildDisconnectedBanner(
    BuildContext context,
    ThemeData theme,
    String deviceName,
  ) {
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.link_off_rounded, color: AppTheme.errorRed, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Disconnected from $deviceName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.errorRed,
                ),
              ),
            ),
            TextButton(
              onPressed: _reconnect,
              child: Text(
                'Reconnect',
                style: TextStyle(color: AppTheme.errorRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, ThemeData theme, int selected) {
    return Container(
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
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = index == selected;

              return _MeshCoreNavBarItem(
                icon: isSelected ? item.activeIcon : item.icon,
                label: item.label,
                isSelected: isSelected,
                onTap: () {
                  ref.haptics.tabChange();
                  ref.read(meshCoreShellIndexProvider.notifier).setIndex(index);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ThemeData theme) {
    final currentMode = ref.watch(themeModeProvider);
    final isDark =
        currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final dividerAlpha = isDark ? 0.1 : 0.2;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Same rounded corners as MainShell
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Node Info Header - matches MainShell _DrawerNodeHeader
            const _MeshCoreDrawerNodeHeader(),

            // Divider after header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  // MeshCore section header
                  _buildSectionHeader('MESHCORE'),

                  _MeshCoreDrawerMenuTile(
                    icon: Icons.person_add_rounded,
                    label: 'Add Contact',
                    iconColor: AccentColors.cyan,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showAddContact();
                    },
                  ),
                  const SizedBox(height: 4),
                  _MeshCoreDrawerMenuTile(
                    icon: Icons.add_rounded,
                    label: 'Add Channel',
                    iconColor: AccentColors.purple,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showAddChannel();
                    },
                  ),
                  const SizedBox(height: 4),
                  _MeshCoreDrawerMenuTile(
                    icon: Icons.radar_rounded,
                    label: 'Discover Contacts',
                    iconColor: AccentColors.green,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showDiscoverContacts();
                    },
                  ),
                  const SizedBox(height: 4),
                  _MeshCoreDrawerMenuTile(
                    icon: Icons.qr_code_rounded,
                    label: 'My Contact Code',
                    iconColor: AccentColors.orange,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showMyContactCode();
                    },
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Divider(
                      color: theme.dividerColor.withValues(alpha: dividerAlpha),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _MeshCoreDrawerMenuTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    iconColor: Colors.grey.shade500,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const MeshCoreSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Divider before footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),

            // Footer with settings button and disconnect - matches MainShell
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  // Settings button (circular) - matches MainShell _SettingsButton
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const MeshCoreSettingsScreen(),
                        ),
                      );
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Disconnect button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _disconnect();
                    },
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Disconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: BorderSide(
                        color: AppTheme.errorRed.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Row(
        children: [
          Icon(
            Icons.router_rounded,
            size: 14,
            color: AccentColors.cyan.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AccentColors.cyan.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _reconnect() async {
    if (!mounted) return;

    // Get saved device info
    final settingsAsync = ref.read(settingsServiceProvider);
    final settings = settingsAsync.asData?.value;
    final deviceId = settings?.lastDeviceId;
    final deviceName = settings?.lastDeviceName ?? 'MeshCore Device';

    if (deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved device to reconnect to')),
      );
      return;
    }

    // Show reconnecting feedback
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Reconnecting to $deviceName...')));

    // Create device info and attempt connection
    final device = DeviceInfo(
      id: deviceId,
      name: deviceName,
      type: TransportType.ble,
      address: deviceId,
    );

    final coordinator = ref.read(connectionCoordinatorProvider);
    final result = await coordinator.connect(device: device);

    if (!mounted) return;

    if (result.success) {
      // Update connection providers
      ref.read(connectedDeviceProvider.notifier).setState(device);

      final nodeIdHex = result.deviceInfo?.nodeId ?? '0';
      final nodeNumParsed = int.tryParse(nodeIdHex, radix: 16);
      ref
          .read(conn.deviceConnectionProvider.notifier)
          .markAsPaired(device, nodeNumParsed, isMeshCore: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected to ${result.deviceInfo?.displayName ?? deviceName}',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reconnect failed: ${result.errorMessage ?? "Unknown error"}',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _disconnect() async {
    final coordinator = ref.read(connectionCoordinatorProvider);
    await coordinator.disconnect();
  }

  void _showAddContact() {
    // Navigate to Contacts tab
    ref.read(meshCoreShellIndexProvider.notifier).setIndex(0);
    showInfoSnackBar(context, 'Use the + button to add a contact');
  }

  void _showAddChannel() {
    // Navigate to Channels tab
    ref.read(meshCoreShellIndexProvider.notifier).setIndex(1);
    showInfoSnackBar(context, 'Use the menu to create or join a channel');
  }

  void _showDiscoverContacts() {
    // Send advertisement to discover other nodes
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, 'Not connected');
      return;
    }

    // Send self advertisement command
    session.sendCommand(0x07);
    showSuccessSnackBar(context, 'Advertisement sent - listen for responses');
  }

  void _showMyContactCode() {
    final selfInfo = ref.read(meshCoreSelfInfoProvider);
    final info = selfInfo.selfInfo;
    if (info == null) {
      showErrorSnackBar(context, 'Device info not available');
      return;
    }

    final pubKeyHex = info.pubKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final shareCode = '${info.nodeName}:$pubKeyHex';

    QrShareSheet.show(
      context: context,
      title: info.nodeName.isNotEmpty ? info.nodeName : 'Unnamed Node',
      subtitle: 'Scan to add as contact',
      qrData: shareCode,
      infoText: '${pubKeyHex.substring(0, 16)}...',
      primaryButtonLabel: 'Copy Code',
      onShare: () {
        Clipboard.setData(ClipboardData(text: shareCode));
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Contact code copied');
      },
    );
  }
}

/// Drawer node header - matches MainShell _DrawerNodeHeader exactly
class _MeshCoreDrawerNodeHeader extends ConsumerWidget {
  const _MeshCoreDrawerNodeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final linkStatus = ref.watch(linkStatusProvider);
    final selfInfo = ref.watch(meshCoreSelfInfoProvider);
    final isConnected = linkStatus.isConnected;

    final nodeName = selfInfo.selfInfo?.nodeName.isNotEmpty == true
        ? selfInfo.selfInfo!.nodeName
        : linkStatus.deviceName ?? 'MeshCore Device';

    final nodeId = selfInfo.selfInfo != null
        ? selfInfo.selfInfo!.pubKey
              .take(4)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase()
        : '';

    // Get initials for avatar
    final initials = nodeName.length >= 2
        ? nodeName.substring(0, 2).toUpperCase()
        : 'MC';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node avatar - matches MainShell drawer exactly
          NodeAvatar(
            text: initials,
            color: isConnected ? accentColor : theme.dividerColor,
            size: 56,
            showOnlineIndicator: true,
            onlineStatus: isConnected
                ? OnlineStatus.online
                : OnlineStatus.offline,
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
                    // Connection status indicator (compact) - matches MainShell exactly
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

/// Drawer menu tile - matches MainShell _DrawerMenuTile styling exactly
class _MeshCoreDrawerMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _MeshCoreDrawerMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Icon container - matches MainShell drawer
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color:
                    iconColor ??
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: AppTheme.fontFamily,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nav bar item - matches MainShell _NavBarItem styling exactly
class _MeshCoreNavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MeshCoreNavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    // Determine icon color - matches MainShell exactly
    final iconColor = isSelected
        ? accentColor
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    // Determine label color - matches MainShell exactly
    final labelColor = isSelected
        ? accentColor
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

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
                  : AnimatedMorphIcon(icon: icon, size: 24, color: iconColor),
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

/// MeshCore device sheet content - shows MeshCore-specific device info and actions
class _MeshCoreDeviceSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _MeshCoreDeviceSheetContent({required this.scrollController});

  @override
  ConsumerState<_MeshCoreDeviceSheetContent> createState() =>
      _MeshCoreDeviceSheetContentState();
}

class _MeshCoreDeviceSheetContentState
    extends ConsumerState<_MeshCoreDeviceSheetContent> {
  bool _disconnecting = false;

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final selfInfo = ref.watch(meshCoreSelfInfoProvider);
    final isConnected = linkStatus.isConnected;
    final isConnecting = linkStatus.isConnecting;

    final nodeName = selfInfo.selfInfo?.nodeName.isNotEmpty == true
        ? selfInfo.selfInfo!.nodeName
        : linkStatus.deviceName ?? 'MeshCore Device';

    final nodeId = selfInfo.selfInfo != null
        ? selfInfo.selfInfo!.pubKey
              .take(4)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase()
        : '';

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isConnected
                      ? context.accentColor.withValues(alpha: 0.15)
                      : context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.router,
                  color: isConnected
                      ? context.accentColor
                      : context.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nodeName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? context.accentColor
                                : isConnecting
                                ? AppTheme.warningYellow
                                : context.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected
                              ? 'Connected'
                              : isConnecting
                              ? 'Connecting...'
                              : 'Disconnected',
                          style: TextStyle(
                            fontSize: 14,
                            color: isConnected
                                ? context.accentColor
                                : isConnecting
                                ? AppTheme.warningYellow
                                : context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.textTertiary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(color: context.border, height: 1),
        // Content
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Device Info
              _buildSectionTitle(context, 'Device Information'),
              const SizedBox(height: 12),
              _buildDeviceInfoCard(context, selfInfo, nodeId, isConnected),
              const SizedBox(height: 24),

              // Quick Actions
              _buildSectionTitle(context, 'Quick Actions'),
              const SizedBox(height: 12),
              _MeshCoreActionTile(
                icon: Icons.person_add_rounded,
                title: 'Add Contact',
                subtitle: 'Scan QR or enter contact code',
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(meshCoreShellIndexProvider.notifier).setIndex(0);
                  showInfoSnackBar(
                    context,
                    'Use the + button to add a contact',
                  );
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.add_rounded,
                title: 'Join Channel',
                subtitle: 'Scan QR or enter channel code',
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(meshCoreShellIndexProvider.notifier).setIndex(1);
                  showInfoSnackBar(context, 'Use the menu to join a channel');
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.qr_code_rounded,
                title: 'My Contact Code',
                subtitle: 'Share your contact info',
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  _showMyContactCode();
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.radar_rounded,
                title: 'Discover Contacts',
                subtitle: 'Send advertisement to find nearby nodes',
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  _discoverContacts();
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.settings_outlined,
                title: 'App Settings',
                subtitle: 'Notifications, theme, preferences',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const MeshCoreSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Connection Actions
              if (isConnected) ...[
                _buildSectionTitle(context, 'Connection'),
                const SizedBox(height: 12),
                _buildDisconnectButton(context),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.textTertiary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildDeviceInfoCard(
    BuildContext context,
    MeshCoreSelfInfoState selfInfoState,
    String nodeId,
    bool isConnected,
  ) {
    final info = selfInfoState.selfInfo;

    return Container(
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: InfoTable(
        rows: [
          InfoTableRow(
            label: 'Protocol',
            value: 'MeshCore',
            icon: Icons.hub_rounded,
            iconColor: AccentColors.cyan,
          ),
          if (info != null) ...[
            InfoTableRow(
              label: 'Node Name',
              value: info.nodeName.isNotEmpty ? info.nodeName : 'Unknown',
              icon: Icons.label_rounded,
            ),
            if (nodeId.isNotEmpty)
              InfoTableRow(
                label: 'Node ID',
                value: nodeId,
                icon: Icons.tag_rounded,
              ),
            InfoTableRow(
              label: 'Public Key',
              value: info.pubKey
                  .take(8)
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join()
                  .toUpperCase(),
              icon: Icons.key_rounded,
            ),
          ],
          InfoTableRow(
            label: 'Status',
            value: isConnected ? 'Online' : 'Offline',
            icon: Icons.circle,
            iconColor: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _disconnecting ? null : () => _disconnect(context),
        icon: _disconnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.errorRed,
                ),
              )
            : const Icon(Icons.link_off, size: 20),
        label: Text(_disconnecting ? 'Disconnecting...' : 'Disconnect'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorRed,
          side: BorderSide(
            color: _disconnecting
                ? AppTheme.errorRed.withValues(alpha: 0.5)
                : AppTheme.errorRed,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('Disconnect'),
        content: const Text(
          'Are you sure you want to disconnect from this MeshCore device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      setState(() => _disconnecting = true);

      // Close sheet first
      Navigator.pop(context);

      // Perform disconnect
      final coordinator = ref.read(connectionCoordinatorProvider);
      await coordinator.disconnect();
    }
  }

  void _showMyContactCode() {
    final selfInfo = ref.read(meshCoreSelfInfoProvider);
    final info = selfInfo.selfInfo;
    if (info == null) {
      showErrorSnackBar(context, 'Device info not available');
      return;
    }

    final pubKeyHex = info.pubKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final shareCode = '${info.nodeName}:$pubKeyHex';

    QrShareSheet.show(
      context: context,
      title: info.nodeName.isNotEmpty ? info.nodeName : 'Unnamed Node',
      subtitle: 'Scan to add as contact',
      qrData: shareCode,
      infoText: '${pubKeyHex.substring(0, 16)}...',
      primaryButtonLabel: 'Copy Code',
      onShare: () {
        Clipboard.setData(ClipboardData(text: shareCode));
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Contact code copied');
      },
    );
  }

  void _discoverContacts() {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, 'Not connected');
      return;
    }
    session.sendCommand(0x07);
    showSuccessSnackBar(
      context,
      'Advertisement sent - listening for responses',
    );
  }
}

/// Action tile for MeshCore device sheet - matches Meshtastic's _ActionTile styling
class _MeshCoreActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _MeshCoreActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: context.accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
