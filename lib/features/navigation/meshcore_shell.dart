// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — navigation shell root scaffold with drawer and bottom nav

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/navigation.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../core/widgets/status_banner.dart';
import '../../providers/app_providers.dart';
import '../../providers/meshcore_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../automations/automations_screen.dart';
import '../meshcore/dashboard/meshcore_dashboard_screen.dart';
import '../meshcore/screens/meshcore_nodes_screen.dart';
import '../meshcore/screens/meshcore_messages_container_screen.dart';
import '../meshcore/screens/meshcore_tools_screen.dart';
import '../meshcore/screens/meshcore_map_screen.dart';
import '../meshcore/screens/meshcore_settings_screen.dart';
import '../meshcore/screens/meshcore_qr_scanner_screen.dart';
import '../meshcore/widgets/meshcore_device_sheet.dart';
import '../meshcore/widgets/meshcore_sync_progress_bar.dart';
import 'widgets/drawer_menu_tile.dart';
import 'widgets/drawer_sticky_header.dart';
import '../settings/ifttt_config_screen.dart';
import '../settings/ringtone_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../widget_builder/widget_builder_screen.dart';
import '../meshcore/widgets/meshcore_drawer_node_header.dart';
import '../meshcore/widgets/meshcore_shell_nav_bar_item.dart';
import '../../core/constants.dart';
import '../teams/presentation/teams_screen.dart';

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
        MeshCoreDeviceSheetContent(scrollController: scrollController),
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
    // The provider that owns the scaffold key can itself be torn down
    // before this State's dispose runs (route tree teardown order is
    // not deterministic). Guard the ref.read so a disposed-provider
    // throw does not crash the route exit. Crashlytics [E c2ba2914].
    try {
      ref.read(meshCoreShellScaffoldKeyProvider.notifier).setKey(null);
    } catch (e) {
      AppLogging.app(
        '[E c2ba2914] meshcore_shell dispose: scaffoldKey clear skipped: $e',
      );
    }
    super.dispose();
  }

  List<_MeshCoreNavItem> _navItems(BuildContext context) => [
    _MeshCoreNavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: context.l10n.navigationMessages,
    ),
    _MeshCoreNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: context.l10n.meshcoreShellNavMap,
    ),
    _MeshCoreNavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: context.l10n.navigationNodes,
    ),
    _MeshCoreNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: context.l10n.meshcoreShellNavDashboard,
    ),
  ];

  // Tab order mirrors `MainShell._buildScreen`: Messages / Map /
  // Nodes / Dashboard. The Messages tab houses both Contacts and
  // Channels in sub-tabs; the Nodes tab is the standalone contact
  // roster (full discovered-peer list) — same shape as Meshtastic's
  // MessagesContainerScreen + NodesScreen split.
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const MeshCoreMessagesContainerScreen();
      case 1:
        return const MeshCoreMapScreen();
      case 2:
        return const MeshCoreNodesScreen();
      case 3:
        return const MeshCoreDashboardScreen();
      default:
        return const MeshCoreMessagesContainerScreen();
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
          // Initial-sync progress (MO-4): thin bar that fills while the
          // contacts/channels roster drains, then collapses. Self-hides
          // when no sync is active.
          const MeshCoreSyncProgressBar(),
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
  ///
  /// Used by the banner Cancel flow. Delegates to [_routeToScanner] so
  /// the same root-navigator + setNeedsScanner pattern handles all
  /// MeshCore-shell exit paths.
  void _goToScanner() => _routeToScanner();

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

              return MeshCoreNavBarItem(
                icon: isSelected ? item.activeIcon : item.icon,
                label: item.label,
                isSelected: isSelected,
                onTap: () {
                  // Guard against tap-up events that fire after the
                  // shell element has been disposed (e.g. user tapped
                  // a nav tab the same frame Disconnect tore the
                  // shell down). Crashlytics issue 5f6578e8 traced
                  // here: `setIndex` triggered a Riverpod
                  // notification on the build watch at line 282,
                  // hitting a defunct ConsumerStatefulElement and
                  // failing the framework
                  // `_lifecycleState != defunct` assertion.
                  if (!mounted) return;
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
    final l10n = context.l10n;

    // Drawer structure mirrors `_MainDrawer` in `main_shell.dart`:
    // header -> divider -> Expanded(CustomScrollView with sliver
    // sections) -> divider -> footer Row(settings cog). Each section
    // uses `SliverPersistentHeader(DrawerStickyHeaderDelegate)` for
    // the section title and `SliverList` of canonical `DrawerMenuTile`
    // entries. Customization (reorder / hide) is Meshtastic-only
    // today and intentionally out of scope here.
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
            MeshCoreDrawerNodeHeader(
              onSelfTap: () {
                Navigator.of(context).maybePop();
                showMeshCoreDeviceSheet(context);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  const SliverPadding(padding: EdgeInsets.only(top: 8)),

                  // MESHCORE section: protocol-specific entries that
                  // only make sense in the MeshCore shell.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: DrawerStickyHeaderDelegate(
                      title: l10n.meshcoreShellDrawerSectionHeader,
                      theme: theme,
                    ),
                  ),
                  _buildSectionTiles(
                    theme: theme,
                    dividerAlpha: dividerAlpha,
                    isLastSection: false,
                    tiles: [
                      DrawerMenuTile(
                        icon: Icons.person_add_rounded,
                        label: l10n.meshcoreShellDrawerAddContact,
                        isSelected: false,
                        iconColor: AccentColors.cyan,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          _showAddContact();
                        },
                      ),
                      DrawerMenuTile(
                        icon: Icons.add_rounded,
                        label: l10n.meshcoreShellDrawerAddChannel,
                        isSelected: false,
                        iconColor: context.accentColor,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          _showAddChannel();
                        },
                      ),
                      DrawerMenuTile(
                        icon: Icons.radar_rounded,
                        label: l10n.meshcoreShellDrawerDiscoverContacts,
                        isSelected: false,
                        iconColor: AccentColors.green,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          _showDiscoverContacts();
                        },
                      ),
                      DrawerMenuTile(
                        icon: Icons.qr_code_rounded,
                        label: l10n.meshcoreShellDrawerMyContactCode,
                        isSelected: false,
                        iconColor: AccentColors.orange,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          _showMyContactCode();
                        },
                      ),
                    ],
                  ),

                  // TOOLS section: Tools + Settings sit under a Tools
                  // header so the section breaks read consistently
                  // with Meshtastic's grouped layout.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: DrawerStickyHeaderDelegate(
                      title: l10n.navigationSectionTools,
                      theme: theme,
                    ),
                  ),
                  _buildSectionTiles(
                    theme: theme,
                    dividerAlpha: dividerAlpha,
                    isLastSection: false,
                    tiles: [
                      // Organisation membership has nothing to do with
                      // which radio protocol is active, so Teams is
                      // reachable from both shells.
                      if (AppFeatureFlags.isTeamsEnabled)
                        DrawerMenuTile(
                          icon: Icons.groups_outlined,
                          label: l10n.navigationTeams,
                          isSelected: false,
                          iconColor: AccentColors.teal,
                          onTap: () {
                            ref.haptics.tabChange();
                            Navigator.pop(context);
                            Navigator.push(context, TeamsScreen.route());
                          },
                        ),
                      DrawerMenuTile(
                        icon: Icons.build_outlined,
                        label: l10n.meshcoreShellNavTools,
                        isSelected: false,
                        iconColor: SemanticColors.muted,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const MeshCoreToolsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // PREMIUM section: cross-protocol entries that
                  // landed during Phases 3-4. `isLocked` reflects the
                  // user's `hasFeatureProvider` for each entitlement.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: DrawerStickyHeaderDelegate(
                      title: l10n.navigationSectionPremium,
                      theme: theme,
                    ),
                  ),
                  _buildSectionTiles(
                    theme: theme,
                    dividerAlpha: dividerAlpha,
                    isLastSection: true,
                    tiles: [
                      DrawerMenuTile(
                        icon: Icons.palette_outlined,
                        label: l10n.navigationThemePack,
                        isSelected: false,
                        isPremium: true,
                        isLocked: !ref.watch(
                          hasFeatureProvider(PremiumFeature.premiumThemes),
                        ),
                        iconColor: AccentColors.purple,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const ThemeSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      DrawerMenuTile(
                        icon: Icons.music_note_outlined,
                        label: l10n.navigationRingtonePack,
                        isSelected: false,
                        isPremium: true,
                        isLocked: !ref.watch(
                          hasFeatureProvider(PremiumFeature.customRingtones),
                        ),
                        iconColor: AccentColors.pink,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const RingtoneScreen(),
                            ),
                          );
                        },
                      ),
                      DrawerMenuTile(
                        icon: Icons.widgets_outlined,
                        label: l10n.navigationWidgets,
                        isSelected: false,
                        isPremium: true,
                        isLocked: !ref.watch(
                          hasFeatureProvider(PremiumFeature.homeWidgets),
                        ),
                        iconColor: AccentColors.coral,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const WidgetBuilderScreen(),
                            ),
                          );
                        },
                      ),
                      DrawerMenuTile(
                        icon: Icons.auto_awesome,
                        label: l10n.navigationAutomations,
                        isSelected: false,
                        isPremium: true,
                        isLocked: !ref.watch(
                          hasFeatureProvider(PremiumFeature.automations),
                        ),
                        iconColor: AccentColors.yellow,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AutomationsScreen(),
                            ),
                          );
                        },
                      ),
                      DrawerMenuTile(
                        icon: Icons.webhook_outlined,
                        label: l10n.navigationIftttIntegration,
                        isSelected: false,
                        isPremium: true,
                        isLocked: !ref.watch(
                          hasFeatureProvider(PremiumFeature.iftttIntegration),
                        ),
                        iconColor: AccentColors.sky,
                        onTap: () {
                          ref.haptics.tabChange();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const IftttConfigScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Bottom Help & Support tile, matches MainShell.
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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverToBoxAdapter(
                      child: DrawerMenuTile(
                        icon: Icons.help_outline,
                        label: l10n.navigationHelpSupport,
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
                  const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                12,
                16,
                16,
              ),
              child: Row(
                children: [
                  _MeshCoreSettingsCog(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a section's SliverList with the canonical Meshtastic
  // inter-tile spacing (`SizedBox(height: spacing4)` between
  // consecutive tiles) plus a section-end divider when the section
  // isn't the last one. Mirrors the per-section render in
  // `MainShell._buildDrawerMenuSlivers` so the visual rhythm between
  // tiles + section breaks reads identically across both shells.
  Widget _buildSectionTiles({
    required ThemeData theme,
    required double dividerAlpha,
    required List<Widget> tiles,
    required bool isLastSection,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final isLastInSection = index == tiles.length - 1;
          return Column(
            children: [
              tiles[index],
              if (!isLastInSection) const SizedBox(height: AppTheme.spacing4),
              if (isLastInSection && !isLastSection)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Divider(
                    color: theme.dividerColor.withValues(alpha: dividerAlpha),
                  ),
                ),
            ],
          );
        }, childCount: tiles.length),
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

  /// Shared route-replace into the Scanner via the declarative
  /// `appInitProvider.setNeedsScanner` + global `navigatorKey`.
  /// Used by the drawer Disconnect, the device-sheet Disconnect, and
  /// `_goToScanner` (the banner Cancel flow).
  void _routeToScanner() {
    // setNeedsScanner triggers the existing home `_AppRouter` to
    // rebuild and render ScannerScreen via the declarative
    // `appShellProvider` flow. We only need to pop screens stacked
    // on top of the AppRouter. `pushNamedAndRemoveUntil('/app', ...)`
    // would create a SECOND AppRouter on top of the persistent home
    // route, with its own ScannerScreen, and the two AppRouters would
    // then diverge as the flow advances.
    ref.read(appInitProvider.notifier).setNeedsScanner();
    final nav = navigatorKey.currentState;
    if (nav != null) {
      AppLogging.connection(
        'MESHCORE_DISCONNECT_ROUTE_POP_TO_ROOT source=shell '
        'method=popUntil(isFirst)',
      );
      nav.popUntil((route) => route.isFirst);
    } else {
      AppLogging.connection(
        'MESHCORE_DISCONNECT_ROUTE_POP_TO_ROOT source=shell '
        'method=local_fallback (navigatorKey.currentState=null)',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
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

  Future<void> _showDiscoverContacts() async {
    // Send advertisement to discover other nodes
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreShellNotConnected);
      return;
    }

    try {
      await session.sendCommand(0x07);
      if (mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.meshcoreShellAdvertisementSent,
        );
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreShellNotConnected);
      }
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
}

// Circular settings-cog button shown in the drawer footer, mirroring
// `_SettingsButton` in MainShell. Same shape (44x44 circle with a
// hairline border) so the two shells' footer rhythm matches.
class _MeshCoreSettingsCog extends StatelessWidget {
  final VoidCallback onTap;

  const _MeshCoreSettingsCog({required this.onTap});

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

/// Nav bar item - matches MainShell _NavBarItem styling exactly
