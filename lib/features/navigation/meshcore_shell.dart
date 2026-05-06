// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — navigation shell root scaffold with drawer and bottom nav

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/node_avatar.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../core/widgets/status_banner.dart';
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
import '../meshcore/screens/meshcore_qr_scanner_screen.dart';

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

/// Context-aware leading button for MeshCore app bars.
///
/// On the MeshCore shell's root tabs (Contacts / Channels / Map /
/// Tools — i.e. routes where `Navigator.canPop` is `false`), this
/// renders a hamburger and opens the shell's drawer. On any pushed
/// route above the shell (Settings, Device Info, etc.) it instead
/// renders a back arrow and pops the route.
///
/// D25: pre-D25 the button always tried to open the drawer via the
/// shell's scaffold key, which silently failed on pushed routes
/// because the shell's `Scaffold` is not on top of the navigator
/// stack — the drawer surface couldn't reach the foreground. Tapping
/// did nothing visible. Splitting the behaviour by route depth makes
/// the button do the obviously-correct thing in each context without
/// touching any callsite.
class MeshCoreHamburgerMenuButton extends ConsumerWidget {
  const MeshCoreHamburgerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.canPop(context);
    final scaffoldKey = ref.watch(meshCoreShellScaffoldKeyProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return IconButton(
      icon: Icon(
        canPop ? Icons.arrow_back : Icons.menu,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();

        if (canPop) {
          // Pushed route — back arrow path. Never attempt to open
          // the drawer; the shell's scaffold isn't on top of the
          // navigator stack so `openDrawer` would silently no-op.
          Navigator.pop(context);
          return;
        }

        // Shell-root route — open the drawer using the provider-
        // stored scaffold key.
        final scaffoldState = scaffoldKey?.currentState;
        if (scaffoldState != null) {
          scaffoldState.openDrawer();
        } else {
          // Fallback: try to find a Scaffold ancestor (e.g. during
          // tests where the shell key hasn't been published yet).
          try {
            Scaffold.of(context).openDrawer();
          } catch (e) {
            AppLogging.debug(
              '⚠️ MeshCoreHamburgerMenuButton: Could not open drawer',
            );
          }
        }
      },
      tooltip: canPop ? l10n.commonGoBack : l10n.meshcoreShellMenuTooltip,
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
      tooltip: context.l10n.meshcoreShellDeviceTooltip,
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

class _MeshCoreShellState extends ConsumerState<MeshCoreShell>
    with LifecycleSafeMixin<MeshCoreShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Register scaffold key after build so drawer can be opened from nested screens
    safePostFrame(() {
      ref.read(meshCoreShellScaffoldKeyProvider.notifier).setKey(_scaffoldKey);
    });
  }

  @override
  void dispose() {
    // Clear scaffold key on dispose
    ref.read(meshCoreShellScaffoldKeyProvider.notifier).setKey(null);
    super.dispose();
  }

  List<_MeshCoreNavItem> _navItems(BuildContext context) => [
    _MeshCoreNavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: context.l10n.meshcoreShellNavContacts,
    ),
    _MeshCoreNavItem(
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum,
      label: context.l10n.meshcoreShellNavChannels,
    ),
    _MeshCoreNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: context.l10n.meshcoreShellNavMap,
    ),
    _MeshCoreNavItem(
      icon: Icons.build_outlined,
      activeIcon: Icons.build,
      label: context.l10n.meshcoreShellNavTools,
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
    final deviceName =
        linkStatus.deviceName ?? context.l10n.meshcoreShellDefaultDeviceName;

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
            _buildReconnectingBanner(context, deviceName),
          // Main content. D23: when the disconnected banner is shown
          // it consumes the system top safe-area itself (via its
          // SafeArea wrapper). The inner per-tab `GlassScaffold`
          // would otherwise re-pad for the status bar from
          // `MediaQuery.padding.top`, leaving a ~50 px dark gap
          // between the banner and the inner app bar (most visible
          // on the disconnected Tools empty-state). Stripping
          // `removeTop: true` here tells the inner scaffolds the top
          // padding has already been consumed, collapsing the gap.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: showReconnectionBanner,
              child: IndexedStack(
                index: selectedIndex,
                children: List.generate(
                  _navItems(context).length,
                  (index) => _buildScreen(index),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, theme, selectedIndex),
    );
  }

  /// State-aware reconnecting banner (D27).
  ///
  /// Renders one of four shapes driven by [autoReconnectStateProvider]:
  ///
  /// - `scanning` / `connecting` -> loading spinner + "Reconnecting…" with
  ///   a Cancel button that drives an authoritative user-cancel and routes
  ///   to Scanner.
  /// - `failed` -> error banner with Retry + Go to Scanner.
  /// - `idle` (default) -> existing `Disconnected from <device>` shape
  ///   with a single Reconnect button.
  /// - `success` -> caller already hides the banner via `showReconnectionBanner`.
  ///
  /// Mirrors Meshtastic's [TopStatusBanner] UX conceptually but is a
  /// MeshCore-specific duplicate by design (D27 boundary): no Meshtastic UI
  /// is touched, and a future deduplication pass can fold the two together
  /// once both are battle-tested.
  Widget _buildReconnectingBanner(BuildContext context, String deviceName) {
    final autoState = ref.watch(autoReconnectStateProvider);
    final isScanning = autoState == AutoReconnectState.scanning;
    final isConnecting = autoState == AutoReconnectState.connecting;
    final isReconnecting = isScanning || isConnecting;
    final isFailed = autoState == AutoReconnectState.failed;
    final l10n = context.l10n;

    if (isReconnecting) {
      return SafeArea(
        bottom: false,
        child: StatusBanner.info(
          title: isScanning
              ? l10n.meshcoreShellSearchingFor(deviceName)
              : l10n.meshcoreShellReconnectingTo(deviceName),
          icon: Icons.bluetooth_searching_rounded,
          isLoading: true,
          margin: const EdgeInsets.all(AppTheme.spacing12),
          trailing: TextButton(
            onPressed: _cancelReconnectAndGoToScanner,
            child: Text(l10n.meshcoreShellCancelReconnect),
          ),
        ),
      );
    }

    if (isFailed) {
      return SafeArea(
        bottom: false,
        child: StatusBanner.error(
          title: l10n.meshcoreShellReconnectFailedTitle(deviceName),
          subtitle: l10n.meshcoreShellReconnectFailedSubtitle,
          icon: Icons.error_outline_rounded,
          margin: const EdgeInsets.all(AppTheme.spacing12),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _goToScanner,
                child: Text(l10n.meshcoreShellGoToScanner),
              ),
              const SizedBox(width: AppTheme.spacing4),
              TextButton(
                onPressed: _reconnect,
                child: Text(l10n.meshcoreShellRetry),
              ),
            ],
          ),
        ),
      );
    }

    // idle / disconnected default
    return SafeArea(
      bottom: false,
      child: StatusBanner.error(
        title: l10n.meshcoreShellDisconnectedFrom(deviceName),
        icon: Icons.link_off_rounded,
        margin: const EdgeInsets.all(AppTheme.spacing12),
        trailing: TextButton(
          onPressed: _reconnect,
          child: Text(l10n.meshcoreShellReconnectButton),
        ),
      ),
    );
  }

  /// Authoritative user-cancel + route replacement to Scanner.
  ///
  /// Mirrors Meshtastic's banner Cancel flow: drive
  /// [DeviceConnectionNotifier.userCancelAutoReconnect] (sets
  /// `userDisconnected=true` and tears down any in-flight transport) then
  /// route-replace into the scanner via `setNeedsScanner` + `/app` so we
  /// don't end up stacking a scanner on top of a still-mounted shell.
  Future<void> _cancelReconnectAndGoToScanner() async {
    AppLogging.connection(
      'event=shell.banner.cancel reason=user_tap protocol=meshcore',
    );
    await ref
        .read(conn.deviceConnectionProvider.notifier)
        .userCancelAutoReconnect();
    if (!mounted) return;
    _goToScanner();
  }

  /// Route-replace into the scanner.
  void _goToScanner() {
    ref.read(appInitProvider.notifier).setNeedsScanner();
    Navigator.of(context).pushNamedAndRemoveUntil('/app', (route) => false);
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
            children: List.generate(_navItems(context).length, (index) {
              final item = _navItems(context)[index];
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
                  _buildSectionHeader(
                    context.l10n.meshcoreShellDrawerSectionHeader,
                  ),

                  _MeshCoreDrawerMenuTile(
                    icon: Icons.person_add_rounded,
                    label: context.l10n.meshcoreShellDrawerAddContact,
                    iconColor: AccentColors.cyan,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showAddContact();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  _MeshCoreDrawerMenuTile(
                    icon: Icons.add_rounded,
                    label: context.l10n.meshcoreShellDrawerAddChannel,
                    iconColor: AccentColors.purple,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showAddChannel();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  _MeshCoreDrawerMenuTile(
                    icon: Icons.radar_rounded,
                    label: context.l10n.meshcoreShellDrawerDiscoverContacts,
                    iconColor: AccentColors.green,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showDiscoverContacts();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  _MeshCoreDrawerMenuTile(
                    icon: Icons.qr_code_rounded,
                    label: context.l10n.meshcoreShellDrawerMyContactCode,
                    iconColor: AccentColors.orange,
                    onTap: () {
                      ref.haptics.tabChange();
                      Navigator.pop(context);
                      _showMyContactCode();
                    },
                  ),

                  const SizedBox(height: AppTheme.spacing8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Divider(
                      color: theme.dividerColor.withValues(alpha: dividerAlpha),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),

                  _MeshCoreDrawerMenuTile(
                    icon: Icons.settings_outlined,
                    label: context.l10n.meshcoreShellDrawerSettings,
                    iconColor: SemanticColors.muted,
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
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                12,
                16,
                16,
              ),
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
                    label: Text(context.l10n.meshcoreShellDrawerDisconnect),
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
          const SizedBox(width: AppTheme.spacing6),
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

  /// Reconnect tap from the banner.
  ///
  /// Routes through [dispatchReconnectMeshCoreAware] (D27) so the
  /// reconnect runs on the protocol-aware path, advances
  /// [autoReconnectStateProvider] (which the banner watches), and
  /// reuses the same dispatch the auto-reconnect manager uses. The
  /// previous direct-coordinator implementation bypassed
  /// `autoReconnectState`, leaving the banner in a "Disconnected"
  /// shape while the connect was in flight.
  void _reconnect() {
    AppLogging.connection(
      'event=shell.banner.action action=reconnect protocol=meshcore',
    );
    final settings = ref.read(settingsServiceProvider).asData?.value;
    final deviceId = settings?.lastDeviceId;
    if (deviceId == null) {
      showErrorSnackBar(context, context.l10n.meshcoreShellNoSavedDevice);
      return;
    }
    // Clear any prior user-disconnected flag so the banner Retry tap
    // re-arms the auto-reconnect manager.
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.scanning);
    dispatchReconnectMeshCoreAwareForWidget(ref, deviceId);
  }

  /// Drawer Disconnect tap.
  ///
  /// D27: route through `userCancelAutoReconnect` (sets `userDisconnected=true`,
  /// tears down the transport, sets `autoReconnectState=idle`) instead of a
  /// raw `coordinator.disconnect()`. Without this gate the new
  /// `meshCoreLifecycleProvider` would observe the coordinator-driven
  /// `MeshConnectionState.disconnected` transition and immediately
  /// dispatch an auto-reconnect, defeating the user's intent.
  void _disconnect() async {
    AppLogging.connection('event=shell.drawer.disconnect protocol=meshcore');
    await ref
        .read(conn.deviceConnectionProvider.notifier)
        .userCancelAutoReconnect();
    // Belt-and-braces: also drive the coordinator's own disconnect so any
    // MeshCore-specific cleanup (capture, adapter teardown) runs even if
    // userCancelAutoReconnect's `transportProvider.disconnect()` was a
    // no-op for our coordinator-owned transport.
    final coordinator = ref.read(connectionCoordinatorProvider);
    await coordinator.disconnect();
  }

  void _showAddContact() {
    ref.read(meshCoreShellIndexProvider.notifier).setIndex(0);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const MeshCoreQrScannerScreen(mode: MeshCoreScanMode.contact),
      ),
    );
  }

  void _showAddChannel() {
    ref.read(meshCoreShellIndexProvider.notifier).setIndex(1);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const MeshCoreQrScannerScreen(mode: MeshCoreScanMode.channel),
      ),
    );
  }

  void _showDiscoverContacts() {
    // Send advertisement to discover other nodes
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreShellNotConnected);
      return;
    }

    // Send self advertisement command
    session.sendCommand(0x07);
    showSuccessSnackBar(context, context.l10n.meshcoreShellAdvertisementSent);
  }

  void _showMyContactCode() {
    final selfInfo = ref.read(meshCoreSelfInfoProvider);
    final info = selfInfo.selfInfo;
    if (info == null) {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreShellDeviceInfoNotAvailable,
      );
      return;
    }

    final pubKeyHex = info.pubKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final shareCode = '${info.nodeName}:$pubKeyHex';

    QrShareSheet.show(
      context: context,
      title: info.nodeName.isNotEmpty
          ? info.nodeName
          : context.l10n.meshcoreShellUnnamedNode,
      subtitle: context.l10n.meshcoreShellScanToAddContact,
      qrData: shareCode,
      infoText: context.l10n.meshcoreShellShareContactInfo,
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
        : linkStatus.deviceName ??
              context.l10n.meshcoreShellDefaultDeviceNameFull;

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
        : context.l10n.meshcoreShellDefaultInitials;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 20, 20, 16),
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
          const SizedBox(width: AppTheme.spacing12),
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
                    const SizedBox(width: AppTheme.spacing8),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                          const SizedBox(width: AppTheme.spacing4),
                          Text(
                            isConnected
                                ? context.l10n.meshcoreShellStatusOnline
                                : context.l10n.meshcoreShellStatusOffline,
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
                  const SizedBox(height: AppTheme.spacing4),
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
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        child: Row(
          children: [
            // Icon container - matches MainShell drawer
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppTheme.spacing10),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Icon(
                icon,
                size: 22,
                color:
                    iconColor ??
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: AppTheme.spacing14),
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
          borderRadius: BorderRadius.circular(AppTheme.radius16),
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
            const SizedBox(height: AppTheme.spacing4),
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
    extends ConsumerState<_MeshCoreDeviceSheetContent>
    with LifecycleSafeMixin<_MeshCoreDeviceSheetContent> {
  bool _disconnecting = false;

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final selfInfo = ref.watch(meshCoreSelfInfoProvider);
    final isConnected = linkStatus.isConnected;
    final isConnecting = linkStatus.isConnecting;

    final nodeName = selfInfo.selfInfo?.nodeName.isNotEmpty == true
        ? selfInfo.selfInfo!.nodeName
        : linkStatus.deviceName ??
              context.l10n.meshcoreShellDefaultDeviceNameFull;

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
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isConnected
                      ? context.accentColor.withValues(alpha: 0.15)
                      : context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  Icons.router,
                  color: isConnected
                      ? context.accentColor
                      : context.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
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
                    const SizedBox(height: AppTheme.spacing4),
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
                        const SizedBox(width: AppTheme.spacing6),
                        Text(
                          isConnected
                              ? context.l10n.meshcoreShellStatusConnected
                              : isConnecting
                              ? context.l10n.meshcoreShellStatusConnecting
                              : context.l10n.meshcoreShellStatusDisconnected,
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
            padding: const EdgeInsets.all(AppTheme.spacing20),
            children: [
              // Device Info
              _buildSectionTitle(
                context,
                context.l10n.meshcoreShellSectionDeviceInfo,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildDeviceInfoCard(context, selfInfo, nodeId, isConnected),
              const SizedBox(height: AppTheme.spacing24),

              // Quick Actions
              _buildSectionTitle(
                context,
                context.l10n.meshcoreShellSectionQuickActions,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _MeshCoreActionTile(
                icon: Icons.person_add_rounded,
                title: context.l10n.meshcoreShellDrawerAddContact,
                subtitle: context.l10n.meshcoreShellAddContactSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(meshCoreShellIndexProvider.notifier).setIndex(0);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MeshCoreQrScannerScreen(
                        mode: MeshCoreScanMode.contact,
                      ),
                    ),
                  );
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.add_rounded,
                title: context.l10n.meshcoreShellJoinChannel,
                subtitle: context.l10n.meshcoreShellJoinChannelSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(meshCoreShellIndexProvider.notifier).setIndex(1);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MeshCoreQrScannerScreen(
                        mode: MeshCoreScanMode.channel,
                      ),
                    ),
                  );
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.qr_code_rounded,
                title: context.l10n.meshcoreShellDrawerMyContactCode,
                subtitle: context.l10n.meshcoreShellShareContactSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  _showMyContactCode();
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.radar_rounded,
                title: context.l10n.meshcoreShellDrawerDiscoverContacts,
                subtitle: context.l10n.meshcoreShellDiscoverSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  _discoverContacts();
                },
              ),
              _MeshCoreActionTile(
                icon: Icons.settings_outlined,
                title: context.l10n.meshcoreShellAppSettings,
                subtitle: context.l10n.meshcoreShellAppSettingsSubtitle,
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
              const SizedBox(height: AppTheme.spacing24),

              // Connection Actions
              if (isConnected) ...[
                _buildSectionTitle(
                  context,
                  context.l10n.meshcoreShellSectionConnection,
                ),
                const SizedBox(height: AppTheme.spacing12),
                _buildDisconnectButton(context),
              ],
              const SizedBox(height: AppTheme.spacing32),
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
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border),
      ),
      child: InfoTable(
        rows: [
          InfoTableRow(
            label: context.l10n.meshcoreShellInfoProtocol,
            value: context.l10n.meshcoreShellInfoProtocolValue,
            icon: Icons.hub_rounded,
            iconColor: AccentColors.cyan,
          ),
          if (info != null) ...[
            InfoTableRow(
              label: context.l10n.meshcoreShellInfoNodeName,
              value: info.nodeName.isNotEmpty
                  ? info.nodeName
                  : context.l10n.meshcoreShellUnknown,
              icon: Icons.label_rounded,
            ),
            if (nodeId.isNotEmpty)
              InfoTableRow(
                label: context.l10n.meshcoreShellInfoNodeId,
                value: nodeId,
                icon: Icons.tag_rounded,
              ),
            InfoTableRow(
              label: context.l10n.meshcoreShellInfoPublicKey,
              value: info.pubKey
                  .take(8)
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join()
                  .toUpperCase(),
              icon: Icons.key_rounded,
            ),
          ],
          InfoTableRow(
            label: context.l10n.meshcoreShellInfoStatus,
            value: isConnected
                ? context.l10n.meshcoreShellStatusOnline
                : context.l10n.meshcoreShellStatusOffline,
            icon: Icons.circle,
            iconColor: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectButton(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: SizedBox(
        width: double.infinity,
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
          label: Text(
            _disconnecting
                ? context.l10n.meshcoreShellDisconnecting
                : context.l10n.meshcoreShellDisconnect,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorRed,
            side: BorderSide(
              color: _disconnecting
                  ? AppTheme.errorRed.withValues(alpha: 0.5)
                  : AppTheme.errorRed,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context) async {
    final coordinator = ref.read(connectionCoordinatorProvider);
    final nav = Navigator.of(context);
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.meshcoreShellDisconnect,
      message: context.l10n.meshcoreShellDisconnectConfirmMessage,
      confirmLabel: context.l10n.meshcoreShellDisconnect,
      isDestructive: true,
    );

    if (!mounted) return;
    if (confirmed == true) {
      safeSetState(() => _disconnecting = true);

      // Close sheet first
      nav.pop();

      // Perform disconnect
      await coordinator.disconnect();
    }
  }

  void _showMyContactCode() {
    final selfInfo = ref.read(meshCoreSelfInfoProvider);
    final info = selfInfo.selfInfo;
    if (info == null) {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreShellDeviceInfoNotAvailable,
      );
      return;
    }

    final pubKeyHex = info.pubKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final shareCode = '${info.nodeName}:$pubKeyHex';

    QrShareSheet.show(
      context: context,
      title: info.nodeName.isNotEmpty
          ? info.nodeName
          : context.l10n.meshcoreShellUnnamedNode,
      subtitle: context.l10n.meshcoreShellScanToAddContact,
      qrData: shareCode,
      infoText: context.l10n.meshcoreShellShareContactInfo,
    );
  }

  void _discoverContacts() {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreShellNotConnected);
      return;
    }
    session.sendCommand(0x07);
    showSuccessSnackBar(
      context,
      context.l10n.meshcoreShellAdvertisementSentListening,
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
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(icon, color: context.accentColor, size: 22),
                ),
                const SizedBox(width: AppTheme.spacing14),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
