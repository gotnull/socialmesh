// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — navigation shell root scaffold with drawer and bottom nav
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/navigation.dart';
import '../incidents/providers/mesh_incident_providers.dart';
import '../incidents/widgets/help_mode/incident_help_banner.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/safety/lifecycle_mixin.dart';
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
import '../world_mesh/world_mesh_screen.dart';
import '../settings/subscription_screen.dart';
import '../settings/translation_settings_screen.dart';
import '../widget_builder/widget_builder_screen.dart';
import '../reachability/mesh_reachability_screen.dart';
import '../mesh_health/widgets/mesh_health_dashboard.dart';
import '../profile/profile_screen.dart';
import '../debug/device_logs_screen.dart';
import '../mesh_canvas/screens/mesh_canvas_overview_screen.dart';
import '../nodedex/screens/nodedex_shell_screen.dart';
import '../operations/presentation/operations_screen.dart';
import '../aether/screens/aether_screen.dart';
import '../file_transfer/screens/file_transfers_container_screen.dart';
import '../aether/providers/aether_flight_matcher_provider.dart';
import '../aether/providers/aether_flight_lifecycle_provider.dart';
import '../aether/widgets/aether_flight_detected_overlay.dart';
// import '../global_layer/screens/global_layer_hub_screen.dart';
import '../sip/sip_hub_screen.dart';
import '../mrrp_harness/mrrp_harness_home_screen.dart';
import '../mesh_capacity/mesh_capacity_screen.dart';
import '../mesh_explorer/mesh_explorer_screen.dart';
import '../mesh_feed/screens/mesh_feed_screen.dart';
import '../nodeboard/screens/nodeboard_list_screen.dart';
import '../incidents/screens/mesh_incident_list_screen.dart';
import '../tak/screens/tak_screen.dart';
import '../../providers/mesh_explorer_providers.dart';
import '../../providers/whats_new_providers.dart';
import '../../core/whats_new/whats_new_sheet.dart';
import '../legal/privacy_choice_sheet.dart';
import 'widgets/drawer_enterprise_section.dart';
import 'providers/bottom_tab_providers.dart';
import 'providers/drawer_customization_providers.dart';
import 'widgets/drawer_customize_button.dart';
import 'widgets/drawer_menu_tile.dart';
import 'widgets/drawer_node_header.dart';
import 'widgets/drawer_sticky_header.dart';
import 'widgets/nav_bar_item.dart';

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

/// Provider for controlling the currently selected bottom tab in MainShell.
///
/// Cold-start lands on the user's configured `defaultLandingTab` (default 2
/// = Nodes, matching the historical app behaviour). The setting is read
/// once synchronously off the already-loaded SettingsService; if the
/// service isn't ready yet, we fall back to the original default so the
/// app never crashes on bootstrap.
class MainShellIndexNotifier extends Notifier<int> {
  static const int _legacyDefault = 2; // Nodes tab

  @override
  int build() {
    final settings = ref.read(settingsServiceProvider).value;
    final stored = settings?.defaultLandingTab ?? _legacyDefault;
    // Clamp to the valid tab range so a stale persisted index from a
    // hypothetical future build can't crash the controller. The nav has
    // 4 tabs (0..3).
    return stored.clamp(0, 3);
  }

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
    final newPeerCount = ref.watch(newMeshPeerCountProvider);
    final hasUnseenWhatsNew = ref.watch(whatsNewHasUnseenProvider);

    // New-peer count for hamburger badge
    final totalBadgeCount = newPeerCount;

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
    AppLogging.connection('🏠 MainShell: initState hashCode=$hashCode');
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
          AppLogging.app('WhatsNew: suppressed - region setup still needed');
        } else {
          // Surface the privacy choice prompt first if the user has not
          // yet made an explicit consent decision. Self-guards on
          // hasMadeChoice so it is a no-op once the user has picked.
          // What's New still runs after; the prompts stack cleanly via
          // their own post-frame callbacks.
          PrivacyChoiceSheet.showIfNeeded();
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
    AppLogging.connection('🏠 MainShell: dispose hashCode=$hashCode');
    // Note: We don't clear the scaffold key here because:
    // 1. Modifying providers during dispose causes Riverpod exceptions
    // 2. When MainShell is recreated, initState will set a new key anyway
    // 3. If MainShell is permanently gone, the key becomes naturally stale
    super.dispose();
  }

  /// Default-order bottom-nav items, keyed by stable id. The user's
  /// chosen order (persisted as a list of ids) is resolved by
  /// [bottomTabOrderProvider]; the renderer in [_buildBottomNavRow]
  /// looks each resolved id up in this map. Index 0..3 of the legacy
  /// `mainShellIndexProvider` always refers to a LOGICAL tab
  /// (Messages=0, Map=1, Nodes=2, Dashboard=3) regardless of physical
  /// position, so badge wiring and the `defaultLandingTab` setting
  /// continue to work without semantic shifts.
  Map<String, NavItem> _buildNavItemsById(AppLocalizations l10n) => {
    bottomTabIdMessages: NavItem(
      id: bottomTabIdMessages,
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: l10n.navigationMessages,
    ),
    bottomTabIdMap: NavItem(
      id: bottomTabIdMap,
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: l10n.navigationMap,
    ),
    bottomTabIdNodes: NavItem(
      id: bottomTabIdNodes,
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: l10n.navigationNodes,
    ),
    bottomTabIdDashboard: NavItem(
      id: bottomTabIdDashboard,
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: l10n.navigationDashboard,
    ),
  };

  // The logical tab index for a given id. Stays in lockstep with
  // `_buildNavItemsById` so `_buildScreen` / badge wiring / the
  // `defaultLandingTab` setting all keep talking in logical indices.
  int _logicalIndexForId(String id) {
    switch (id) {
      case bottomTabIdMessages:
        return 0;
      case bottomTabIdMap:
        return 1;
      case bottomTabIdNodes:
        return 2;
      case bottomTabIdDashboard:
        return 3;
    }
    return 0;
  }

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
    // This catches firmware updates / factory resets / never-configured
    // devices that have a UNSET region. The `!regionConfigured` second-
    // guess was removed because it could lock out the picker for a
    // device that genuinely needed setup: any prior code path that
    // persisted `regionConfigured=true` without an actual successful
    // apply (a bug fixed in `_persistAndDismiss`) would leave the
    // device stranded on the nodes screen with no way to set its
    // region. `needsRegionSetupProvider` already gates on
    // `regionAsync.isLoading`, so the brief-UNSET-during-reconnect
    // race the old guard was protecting against is no longer a
    // concern - the picker only renders when the device has settled
    // on a confirmed UNSET region.
    if (isConnected && needsRegionSetup) {
      AppLogging.app(
        '⚠️ MainShell: Connected but region is UNSET '
        '(regionConfigured=$regionConfigured) - forcing region setup',
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

    // Whether the global Incident Mode help banner is currently showing. Like
    // the reconnection banner, a visible help banner occupies the top of the
    // shell and must own the status-bar inset, so the main content below must
    // NOT also add it (otherwise a gap appears beneath the banner).
    final showHelpBanner = ref
        .watch(activeHelpRequestsProvider)
        .maybeWhen(data: (list) => list.isNotEmpty, orElse: () => false);
    // Either banner occupying the top means the content drops its own top inset.
    final topInsetOwnedByBanner = _bannerActuallyVisible || showHelpBanner;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const _MainDrawer(),
      drawerEdgeDragWidth: 40,
      // When the drawer closes (swipe out, tap-out, back gesture, or
      // any other dismiss path), force-exit the drawer's edit mode so
      // the next open starts in normal mode. Without this the user
      // would re-open mid-edit with the banner + minus badges still
      // visible, which is jarring.
      onDrawerChanged: (isOpen) {
        if (!isOpen) {
          ref.read(drawerEditModeProvider.notifier).exit();
        }
      },
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
              // setNeedsScanner triggers the existing home `_AppRouter`
              // to rebuild and render ScannerScreen via
              // `appShellProvider`. Pop any screens stacked on top of
              // the AppRouter so the user actually sees it.
              // `pushNamedAndRemoveUntil('/app', ...)` would create a
              // SECOND AppRouter on top of the persistent home route
              // - the two AppRouters then diverge as state changes
              // and the one on top is stuck on stale state.
              ref.read(appInitProvider.notifier).setNeedsScanner();
              final nav = navigatorKey.currentState;
              if (nav != null) {
                AppLogging.connection(
                  'RECONNECT_CANCEL_ROUTE_POP_TO_ROOT source=banner '
                  'method=popUntil(isFirst)',
                );
                nav.popUntil((route) => route.isFirst);
              } else {
                AppLogging.connection(
                  'RECONNECT_CANCEL_ROUTE_POP_TO_ROOT source=banner '
                  'method=local_fallback (navigatorKey.currentState=null)',
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            deviceState: deviceState,
          ),

          // Incident Mode global help banner. Self-gating: renders nothing
          // unless there is at least one active trusted help request (and the
          // Incident Mode flags are on). Tapping opens the responder inbox.
          // When the reconnection banner is visible it owns the status-bar
          // inset and the help banner stacks beneath it; otherwise the help
          // banner is topmost and consumes the inset itself.
          IncidentHelpBanner(applyTopInset: !_bannerActuallyVisible),

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
                top: topInsetOwnedByBanner
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
                    // Bottom-nav reorder banner. Renders here, INSIDE
                    // the body Stack, so its transparent top edge
                    // reveals actual body content underneath — which
                    // is the only way to get the chip-row-style soft
                    // fade in a Scaffold without `extendBody: true`
                    // (the bottomNavigationBar slot has no body
                    // content behind it, so placing the banner
                    // there paints onto an empty region and the
                    // fade is invisible). The banner sits flush
                    // with the bottom of the body area, which is
                    // directly above the bottom-nav row's top edge.
                    if (ref.watch(bottomNavEditModeProvider))
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _BottomNavEditBanner(),
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
          // NOTE: The reorder edit-mode banner used to live HERE in
          // the bottomNavigationBar Column, but the bottomNavigationBar
          // slot has no body content behind it, so the banner's
          // transparent top edge couldn't fade into anything visible.
          // It now renders inside the body Stack (search for
          // `_BottomNavEditBanner` above), positioned at the bottom
          // of the body area, where the body's own painted content
          // shows through the fade.
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
    final navItemsById = _buildNavItemsById(l10n);
    final resolvedOrder =
        ref.watch(bottomTabOrderProvider).value ?? defaultBottomTabOrder;
    final editMode = ref.watch(bottomNavEditModeProvider);
    final currentLogicalIndex = ref.watch(mainShellIndexProvider);

    // Builds the NavBarItem widget for a tab at the given physical
    // position. The same widget renders in both modes so the visual
    // identity is preserved across the edit transition.
    Widget buildTab(int physicalPosition) {
      final tabId = resolvedOrder[physicalPosition];
      final item = navItemsById[tabId];
      if (item == null) {
        // Unknown id (shouldn't happen because the provider already
        // reconciles against the default set, but be defensive
        // against future Phase 2 tab additions colliding with an
        // older render path).
        return const SizedBox.shrink();
      }
      final logicalIndex = _logicalIndexForId(tabId);
      final isSelected = currentLogicalIndex == logicalIndex;

      // Badge wiring stays keyed off the LOGICAL tab identity so a
      // reorder never swaps badges between tabs.
      int badgeCount = 0;
      if (tabId == bottomTabIdMessages) {
        badgeCount = ref.watch(unreadMessagesCountProvider);
      } else if (tabId == bottomTabIdNodes) {
        final hideBadge =
            ref.watch(settingsServiceProvider).value?.hideNewNodesBadge ??
            false;
        badgeCount = hideBadge ? 0 : ref.watch(newNodesCountProvider);
      }

      return NavBarItem(
        icon: isSelected ? item.activeIcon : item.icon,
        label: item.label,
        isSelected: isSelected,
        badgeCount: badgeCount,
        showWarningBadge: false,
        showReconnectingBadge: false,
        onTap: () {
          ref.haptics.tabChange();
          // Tap in edit mode performs BOTH actions: exit edit mode
          // and select the tapped tab. Guarantees a single-tap exit
          // path so the user never gets stuck.
          if (editMode) {
            ref.read(bottomNavEditModeProvider.notifier).exit();
          }
          if (logicalIndex == 2) {
            ref.read(newNodesCountProvider.notifier).reset();
          }
          if (logicalIndex == 0) {
            // Tapping Messages with unread jumps straight to the sub-tab
            // holding it. DMs (Contacts) take priority over channels since
            // they are addressed to the user personally. Set before
            // setIndex so a fresh container build sees the pending request.
            if (ref.read(hasUnreadDmProvider)) {
              ref.read(messagesSubtabRequestProvider.notifier).request(0);
            } else if (ref.read(hasUnreadChannelProvider)) {
              ref.read(messagesSubtabRequestProvider.notifier).request(1);
            }
          }
          ref.read(mainShellIndexProvider.notifier).setIndex(logicalIndex);
        },
      );
    }

    if (!editMode) {
      // Non-edit mode keeps the canonical `Row(Expanded NavBarItem)`
      // layout. Long-press anywhere on a tab enters edit mode.
      return Row(
        children: List.generate(resolvedOrder.length, (physicalPosition) {
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () {
                HapticFeedback.mediumImpact();
                ref.read(bottomNavEditModeProvider.notifier).enter();
              },
              child: buildTab(physicalPosition),
            ),
          );
        }),
      );
    }

    // Edit mode uses ReorderableListView so unselected tabs slide
    // smoothly out of the way to make space for the moved tab, the
    // same animation behaviour as the drawer's SliverReorderableList.
    //
    // Layout caveats (both regressed first cuts of this feature):
    //   * ReorderableListView is a scrollable, so it does NOT
    //     support intrinsic height measurement. Wrapping in
    //     IntrinsicHeight collapses the row to zero cross-axis
    //     size and the tabs disappear entirely.
    //   * `shrinkWrap: true` with no explicit cross-axis bound also
    //     misbehaves: the scrollable measures itself against the
    //     ancestor Column's incoming constraints, which are
    //     unbounded in the bottom-nav slot, and the resulting
    //     viewport tries to consume infinite height — pushing
    //     siblings (including the AppBar) off-screen.
    //
    // Both of those failure modes manifest as "tabs gone" or
    // "AppBar disappeared" reports. The reliable shape is a
    // LayoutBuilder for cross-axis-aware tab widths plus a fixed
    // SizedBox height matching the NavBarItem's natural rendered
    // size in non-edit mode (so toggling between modes is a no-op
    // visually).
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / resolvedOrder.length;
        return SizedBox(
          // Matches the rendered height of `NavBarItem` in non-edit
          // mode (icon 24 + spacer 4 + label ~16 + vertical padding
          // 16 = ~60). 64 leaves a small buffer for the ±0.025-rad
          // wiggle rotation so the tile corners don't get clipped.
          height: 64,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            proxyDecorator: (child, index, animation) {
              // Strip the default Material elevation shadow so the
              // dragged tab reads as a lifted version of itself
              // rather than a card with a chunky drop shadow.
              return Material(
                color: Colors.transparent,
                elevation: 0,
                child: child,
              );
            },
            itemCount: resolvedOrder.length,
            itemBuilder: (context, position) {
              final tabId = resolvedOrder[position];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(tabId),
                index: position,
                child: SizedBox(
                  width: tabWidth,
                  child: _BottomTabWiggle(
                    tabId: tabId,
                    child: buildTab(position),
                  ),
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              HapticFeedback.selectionClick();
              ref
                  .read(bottomTabOrderProvider.notifier)
                  .reorder(oldIndex, newIndex);
            },
          ),
        );
      },
    );
  }
}

/// Continuous gentle wiggle to signal "tabs are draggable" while in
/// edit mode. Each tab uses a slot-derived phase offset so the row
/// doesn't sway in unison (which would read as a single object
/// rotating rather than a set of movable tiles).
class _BottomTabWiggle extends StatefulWidget {
  final String tabId;
  final Widget child;

  const _BottomTabWiggle({required this.tabId, required this.child});

  @override
  State<_BottomTabWiggle> createState() => _BottomTabWiggleState();
}

class _BottomTabWiggleState extends State<_BottomTabWiggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Phase offset derived from the id's hashCode so adjacent tabs
    // are visibly out of phase regardless of order.
    final phase = (widget.tabId.hashCode % 2 == 0) ? 0.0 : 0.5;
    _rotation = Tween<double>(begin: -0.025, end: 0.025).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(phase, 1.0, curve: Curves.easeInOut),
        reverseCurve: Interval(phase, 1.0, curve: Curves.easeInOut),
      ),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) =>
          Transform.rotate(angle: _rotation.value, child: child),
      child: widget.child,
    );
  }
}

/// Slim banner that renders directly above the bottom nav row while
/// the user is in reorder edit mode. Provides:
///   * a leading icon + "Drag to reorder tabs" copy so the affordance
///     is unambiguous (the wiggle alone is easy to miss);
///   * a "Done" button that exits edit mode WITHOUT touching the
///     active tab (tap-on-tab still doubles as exit+select, so users
///     have both flows: navigate-and-exit OR exit-in-place).
///
/// Mounted INSIDE the body Stack (not in the bottomNavigationBar
/// slot) and positioned flush against the body's bottom edge, so
/// the banner's transparent top edge reveals the actual body
/// content beneath it. This is the chip-row-style soft fade
/// behaviour the user expects: the body content visually fades into
/// the banner's surface tint as you scan downward.
///
/// Two earlier attempts that did NOT work, kept here as a warning
/// to future-me:
///   * `EdgeFade.top` wrapping the banner — paints scaffold-bg ON
///     TOP of the banner from a sibling Positioned. In the
///     bottomNavigationBar slot there is nothing painted behind
///     the banner, so the fade darkens an already-dark top edge
///     without producing a visible blend.
///   * Internal `context.background -> context.surface` gradient
///     while still mounted in the bottomNavigationBar slot. The
///     body screens paint their own backgrounds (gradients,
///     glassy cards), so even a perfect match to
///     `scaffoldBackgroundColor` produces a visible seam against
///     the body's painted content.
///
/// The only working shape is to mount inside the body Stack so the
/// banner overlays real body content and a transparent-to-surface
/// gradient genuinely fades from "see-through" to "banner".
class _BottomNavEditBanner extends ConsumerWidget {
  const _BottomNavEditBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = context.accentColor;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Three explicit stops ending at 1.0 instead of a two-
          // stop list ending at 0.05. Functionally identical (fade
          // from transparent to solid in the top ~5%, solid for
          // the rest) but terminating at 1.0 is the conventional
          // form `ui.Gradient.linear` validates against on every
          // platform. A two-stop list `[0.0, 0.X]` that does not
          // reach 1.0 crashed mid-paint in production (Crashlytics:
          // LinearGradient.createShader -> new Gradient.linear,
          // typically on the banner mount frame). Matching the RGB
          // on both ends of the fade so the interpolation is
          // alpha-only.
          colors: [
            context.surface.withValues(alpha: 0),
            context.surface.withValues(alpha: 0.96),
            context.surface.withValues(alpha: 0.96),
          ],
          stops: const [0.0, 0.05, 1.0],
        ),
        border: Border(
          bottom: BorderSide(
            color: context.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing8,
            AppTheme.spacing8,
          ),
          child: Row(
            children: [
              Icon(Icons.swap_horiz, size: 18, color: accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  context.l10n.bottomNavReorderBannerTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(bottomNavEditModeProvider.notifier).exit();
                },
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing4,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.bottomNavReorderBannerDone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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

/// Right-aligned quick light/dark toggle for the drawer footer.
/// Shows the icon of the mode it will switch TO (sun while dark,
/// moon while light). Mirrors [_SettingsButton]'s circular style.
class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeToggleButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: isDark
          ? context.l10n.appearanceThemeModeLight
          : context.l10n.appearanceThemeModeDark,
      child: GestureDetector(
        onTap: onTap,
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
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 22,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

/// Owns its own state so chevron expand/collapse and per-tile provider
/// watches don't bubble up and rebuild [MainShell] (and the rest of the
/// scaffold/bottom-nav) on every drawer interaction.
class _MainDrawer extends ConsumerStatefulWidget {
  const _MainDrawer();

  @override
  ConsumerState<_MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends ConsumerState<_MainDrawer>
    with LifecycleSafeMixin<_MainDrawer> {
  /// Drawer-item labels currently expanded to reveal nested children.
  /// Keyed by label since labels are unique within the drawer.
  final Set<String> _expandedDrawerItems = <String>{};

  /// Quick light/dark flip from the drawer footer. The full
  /// System/Light/Dark picker lives in Appearance & Accessibility;
  /// this toggles between the two explicit modes based on the
  /// currently rendered brightness and persists the choice.
  Future<void> _toggleThemeMode() async {
    HapticFeedback.selectionClick();
    final mode = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    final notifier = ref.read(themeModeProvider.notifier);
    final settingsService = await ref.read(settingsServiceProvider.future);
    if (!mounted) return;
    await settingsService.setThemeMode(mode.index);
    notifier.setThemeMode(mode);
  }

  List<DrawerMenuItem> _buildDrawerMenuItems(AppLocalizations l10n) => [
    DrawerMenuItem(
      id: 'nodedex',
      icon: Icons.auto_stories_outlined,
      label: l10n.navigationNodeDex,
      // The map and the groups screen are tabs inside the NodeDex shell
      // rather than drawer children: they are two more ways of reading the
      // same collection, so they belong beside it, not under it.
      screen: const NodeDexShellScreen(),
      sectionHeader: l10n.navigationSectionDiscover,
      iconColor: AccentColors.yellow,
      requiresConnection: false,
      whatsNewBadgeKey: 'nodedex',
    ),
    if (AppFeatureFlags.isNodeBoardEnabled)
      DrawerMenuItem(
        id: 'nodeboard',
        icon: Icons.dashboard_outlined,
        label: l10n.nodeboardDrawerLabel,
        screen: const NodeBoardListScreen(),
        iconColor: AccentColors.coral,
        requiresConnection: false,
        whatsNewBadgeKey: 'nodeboard',
      ),
    if (AppFeatureFlags.isOperationsEnabled)
      DrawerMenuItem(
        id: 'operations',
        icon: Icons.flag_outlined,
        label: l10n.navigationOperations,
        screen: const OperationsScreen(),
        iconColor: AccentColors.emerald,
        requiresConnection: false,
        whatsNewBadgeKey: 'operations',
      ),
    if (AppFeatureFlags.isMeshCanvasEnabled)
      DrawerMenuItem(
        id: 'mesh_canvas',
        icon: Icons.grid_view_outlined,
        label: l10n.meshCanvasDrawerLabel,
        screen: const MeshCanvasOverviewScreen(),
        iconColor: AccentColors.purple,
        requiresConnection: false,
        whatsNewBadgeKey: 'mesh_canvas',
      ),
    DrawerMenuItem(
      id: 'presence',
      icon: Icons.people_alt_outlined,
      label: l10n.navigationPresence,
      screen: const PresenceScreen(),
      iconColor: AccentColors.green,
      requiresConnection: true,
    ),
    DrawerMenuItem(
      id: 'world_map',
      icon: Icons.public,
      label: l10n.navigationWorldMap,
      screen: const WorldMeshScreen(),
      iconColor: AccentColors.blue,
      requiresConnection: false,
    ),
    if (AppFeatureFlags.isMeshExplorerEnabled)
      DrawerMenuItem(
        id: 'mesh_explorer',
        icon: Icons.explore_outlined,
        label: l10n.meshExplorerDrawerLabel,
        screen: const MeshExplorerScreen(),
        iconColor: AccentColors.teal,
        requiresConnection: true,
        badgeProviderKey: 'mesh_explorer',
      ),
    DrawerMenuItem(
      id: 'mesh_capacity',
      icon: Icons.network_check,
      label: l10n.meshCapacityScreenTitle,
      screen: const MeshCapacityScreen(),
      iconColor: AccentColors.cyan,
      requiresConnection: true,
      whatsNewBadgeKey: 'mesh_capacity',
    ),
    if (AppFeatureFlags.isMeshFeedEnabled)
      DrawerMenuItem(
        id: 'mesh_feed',
        icon: Icons.dynamic_feed_outlined,
        label: l10n.meshFeedDrawerLabel,
        screen: const MeshFeedScreen(),
        iconColor: AccentColors.orange,
        requiresConnection: false,
      ),
    DrawerMenuItem(
      id: 'telemetry',
      icon: Icons.insights_outlined,
      label: l10n.navigationTelemetry,
      screen: const TelemetryHubScreen(),
      sectionHeader: l10n.navigationSectionTools,
      iconColor: AccentColors.green,
      requiresConnection: false,
    ),
    if (AppFeatureFlags.isFileTransferEnabled)
      DrawerMenuItem(
        id: 'file_transfers',
        icon: Icons.swap_vert,
        label: l10n.navigationFileTransfers,
        screen: const FileTransfersContainerScreen(),
        iconColor: AccentColors.cyan,
        requiresConnection: true,
        whatsNewBadgeKey: 'file_transfers',
      ),
    if (AppFeatureFlags.isAetherEnabled)
      DrawerMenuItem(
        id: 'aether',
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
        id: 'tak_gateway',
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
        id: 'tak_map',
        icon: Icons.military_tech,
        label: l10n.navigationTakMap,
        tabIndex: 1,
        requestsTakMode: true,
        iconColor: AccentColors.orange,
        requiresConnection: false,
      ),
    // Handshake drawer entry. Gated on isHandshakeEnabled (the user's
    // intent flag for the Handshake feature) NOT isSipEnabled (the
    // SIP transport availability). Since MeshCanvas also implicitly
    // turns on SIP transport, gating on isSipEnabled would leak the
    // Handshake UI into a MeshCanvas-only build.
    if (AppFeatureFlags.isHandshakeEnabled)
      DrawerMenuItem(
        id: 'sip',
        icon: Icons.wifi_tethering,
        label: l10n.sipBadgeLabel,
        screen: const SipHubScreen(),
        iconColor: AccentColors.teal,
        requiresConnection: true,
        whatsNewBadgeKey: 'sip',
      ),
    if (AppFeatureFlags.isMrrpHarnessEnabled && AppFeatureFlags.isMrrpEnabled)
      DrawerMenuItem(
        id: 'mrrp_harness',
        icon: Icons.hub,
        label: l10n.mrrpHarnessDrawerLabel,
        screen: const MrrpHarnessHomeScreen(),
        iconColor: AccentColors.purple,
        requiresConnection: true,
      ),
    if (AppFeatureFlags.isMeshIncidentsEnabled)
      DrawerMenuItem(
        id: 'mesh_incidents',
        icon: Icons.warning_amber_outlined,
        label: l10n.navigationMeshIncidents,
        screen: const MeshIncidentListScreen(),
        iconColor: AccentColors.red,
        requiresConnection: true,
      ),
    DrawerMenuItem(
      id: 'timeline',
      icon: Icons.timeline,
      label: l10n.navigationTimeline,
      screen: const TimelineScreen(),
      sectionHeader: l10n.navigationSectionAdvanced,
      iconColor: AccentColors.indigo,
    ),
    DrawerMenuItem(
      id: 'routes',
      icon: Icons.route,
      label: l10n.navigationRoutes,
      screen: const RoutesScreen(),
      iconColor: AccentColors.purple,
    ),
    DrawerMenuItem(
      id: 'reachability',
      icon: Icons.wifi_find,
      label: l10n.navigationReachability,
      screen: const MeshReachabilityScreen(),
      iconColor: AccentColors.teal,
      requiresConnection: true,
    ),
    DrawerMenuItem(
      id: 'mesh_health',
      icon: Icons.monitor_heart_outlined,
      label: l10n.navigationMeshHealth,
      screen: const MeshHealthDashboard(),
      iconColor: AccentColors.pink,
      requiresConnection: true,
    ),
    DrawerMenuItem(
      id: 'device_logs',
      icon: Icons.terminal,
      label: l10n.navigationDeviceLogs,
      screen: const DeviceLogsScreen(),
      iconColor: AccentColors.slate,
      requiresConnection: true,
    ),
    if (AppFeatureFlags.isTranslationEnabled)
      DrawerMenuItem(
        id: 'translation_pack',
        icon: Icons.translate_outlined,
        label: l10n.navigationTranslationPack,
        screen: const TranslationSettingsScreen(),
        premiumFeature: PremiumFeature.translation,
        sectionHeader: l10n.navigationSectionPremium,
        iconColor: AccentColors.teal,
        whatsNewBadgeKey: 'translation_pack',
      ),
    DrawerMenuItem(
      id: 'theme_pack',
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
      id: 'ringtone_pack',
      icon: Icons.music_note_outlined,
      label: l10n.navigationRingtonePack,
      screen: const RingtoneScreen(),
      premiumFeature: PremiumFeature.customRingtones,
      iconColor: AccentColors.pink,
    ),
    DrawerMenuItem(
      id: 'widgets',
      icon: Icons.widgets_outlined,
      label: l10n.navigationWidgets,
      screen: const WidgetBuilderScreen(),
      premiumFeature: PremiumFeature.homeWidgets,
      iconColor: AccentColors.coral,
    ),
    DrawerMenuItem(
      id: 'automations',
      icon: Icons.auto_awesome,
      label: l10n.navigationAutomations,
      screen: const AutomationsScreen(),
      premiumFeature: PremiumFeature.automations,
      iconColor: AccentColors.yellow,
    ),
    DrawerMenuItem(
      id: 'ifttt_integration',
      icon: Icons.webhook_outlined,
      label: l10n.navigationIftttIntegration,
      screen: const IftttConfigScreen(),
      premiumFeature: PremiumFeature.iftttIntegration,
      iconColor: AccentColors.sky,
    ),
  ];

  Widget _buildDrawerTile(
    DrawerMenuItem item, {
    required BuildContext context,
    required bool isConnected,
    required Set<String> unseenBadgeKeys,
    bool isChild = false,
  }) {
    final editMode = ref.watch(drawerEditModeProvider);
    final isPremium = item.premiumFeature != null;
    final hasAccess =
        !isPremium || ref.watch(hasFeatureProvider(item.premiumFeature!));

    final featureKey = item.premiumFeature?.name ?? '';
    final upsellEnabled = isPremium
        ? ref.watch(premiumFeatureGateProvider(featureKey))
        : false;
    final allowNavigation = hasAccess || upsellEnabled;

    final needsConnection = item.requiresConnection && !isConnected;

    int? badgeCount;
    if (item.badgeProviderKey == 'mesh_explorer') {
      badgeCount = ref.watch(newMeshPeerCountProvider);
      if (badgeCount == 0) badgeCount = null;
    }

    final isNew =
        item.whatsNewBadgeKey != null &&
        unseenBadgeKeys.contains(item.whatsNewBadgeKey) &&
        !(isPremium && hasAccess);

    final hasChildren = item.hasChildren;
    final isExpanded = _expandedDrawerItems.contains(item.label);

    // Customizable means the item carries a stable id. Top-level
    // items with ids can be both hidden and reordered; children with
    // ids can be hidden (the reorder UI is suppressed for them by
    // DrawerMenuTile because they never live inside the section
    // SliverReorderableList).
    final canCustomize = item.id != null;
    final tile = DrawerMenuTile(
      icon: item.icon,
      label: item.label,
      isSelected: false,
      isPremium: isPremium && hasAccess,
      isLocked: isPremium && !hasAccess && !upsellEnabled,
      showTryIt: isPremium && !hasAccess && upsellEnabled,
      isDisabled: needsConnection,
      iconColor: item.iconColor,
      badgeCount: badgeCount,
      showNewChip: isNew,
      isChild: isChild,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      editMode: editMode && canCustomize,
      removeSemanticsLabel: canCustomize
          ? context.l10n.drawerRemoveItemLabel(item.label)
          : null,
      onRemove: editMode && canCustomize
          ? () {
              HapticFeedback.mediumImpact();
              ref.read(drawerCustomizationProvider.notifier).hide(item.id!);
            }
          : null,
      onChevronTap: hasChildren
          ? () {
              ref.haptics.tabChange();
              setState(() {
                if (_expandedDrawerItems.contains(item.label)) {
                  _expandedDrawerItems.remove(item.label);
                } else {
                  _expandedDrawerItems.add(item.label);
                }
              });
            }
          : null,
      onTap: needsConnection
          ? null
          : () {
              ref.haptics.tabChange();
              if (item.whatsNewBadgeKey != null) {
                ref
                    .read(whatsNewProvider.notifier)
                    .dismissBadgeKey(item.whatsNewBadgeKey!);
              }
              if (item.badgeProviderKey == 'mesh_explorer') {
                ref.read(newMeshPeerCountProvider.notifier).clear();
              }
              if (item.tabIndex != null) {
                Navigator.of(context).pop();
                if (item.requestsTakMode) {
                  ref.read(mapTakModeProvider.notifier).request();
                }
                ref
                    .read(mainShellIndexProvider.notifier)
                    .setIndex(item.tabIndex!);
              } else if (isPremium && !allowNavigation) {
                navigateFromDrawer(context, const SubscriptionScreen());
              } else if (item.onOpen != null) {
                Navigator.of(context).pop();
                item.onOpen!(context);
              } else if (item.screen != null) {
                final pushed = item.requiresConnection
                    ? RequiresConnectionGuard(child: item.screen!)
                    : item.screen!;
                navigateFromDrawer(
                  context,
                  pushed,
                  routeName: item.screen!.runtimeType.toString(),
                );
              }
            },
    );

    // Outer long-press detector — entry point to drawer edit mode for
    // any customizable item. Once edit mode is active the inner
    // DrawerMenuTile suppresses its own tap and surfaces the remove
    // badge + drag handle instead. Non-customizable items still
    // long-press into edit mode (so the user can discover the feature)
    // but they themselves are not editable.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: editMode || isChild
          ? null
          : () {
              HapticFeedback.mediumImpact();
              ref.read(drawerEditModeProvider.notifier).enter();
            },
      child: tile,
    );
  }

  List<Widget> _buildDrawerMenuSlivers(BuildContext context, ThemeData theme) {
    final slivers = <Widget>[];
    final currentMode = ref.watch(themeModeProvider);
    final isDark =
        currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final dividerAlpha = isDark ? 0.1 : 0.2;

    final connectionStateAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (_, _) => false,
    );

    final unseenBadgeKeys = ref.watch(whatsNewUnseenBadgeKeysProvider);

    slivers.add(const SliverPadding(padding: EdgeInsets.only(top: 8)));

    final l10n = context.l10n;
    final editMode = ref.watch(drawerEditModeProvider);
    final customization =
        ref.watch(drawerCustomizationProvider).value ??
        DrawerCustomizationState.empty;
    final defaultItems = _buildDrawerMenuItems(l10n);

    // Section membership is intrinsic — derived from default position
    // — not positional in the rendered list. This decoupling is the
    // whole point of the reorder model: once a user moves an item,
    // its section membership is preserved, so it can't end up
    // visually orphaned in the section above.
    final membership = deriveSectionMembership(defaultItems);
    final visibleItems = applyDrawerCustomization(defaultItems, customization);

    // Bucket visible items by intrinsic section, then apply the
    // user's intra-section custom order to each bucket.
    final itemsBySection = <String, List<DrawerMenuItem>>{};
    for (final item in visibleItems) {
      final sectionId = item.id != null
          ? (membership.sectionByItemId[item.id] ?? '')
          : '';
      (itemsBySection[sectionId] ??= <DrawerMenuItem>[]).add(item);
    }
    final orderedBySection = <String, List<DrawerMenuItem>>{
      for (final entry in itemsBySection.entries)
        entry.key: applySectionOrder(entry.value, customization.customOrder),
    };

    for (
      var sectionIndex = 0;
      sectionIndex < membership.sectionTitlesInOrder.length;
      sectionIndex++
    ) {
      final sectionTitle = membership.sectionTitlesInOrder[sectionIndex];
      final isLastSection =
          sectionIndex == membership.sectionTitlesInOrder.length - 1;
      final sectionItems = orderedBySection[sectionTitle] ?? const [];
      if (sectionItems.isEmpty) continue;

      if (sectionTitle.isNotEmpty) {
        slivers.add(
          SliverPersistentHeader(
            pinned: true,
            delegate: DrawerStickyHeaderDelegate(
              title: sectionTitle,
              theme: theme,
            ),
          ),
        );
      }

      if (editMode) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverReorderableList(
              itemCount: sectionItems.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;

                final fromItem = sectionItems[oldIndex];
                final fromId = fromItem.id;
                if (fromId == null) return;

                // Apply the local reorder to this section's items.
                final newSectionOrder = [...sectionItems];
                newSectionOrder.removeAt(oldIndex);
                newSectionOrder.insert(
                  newIndex.clamp(0, newSectionOrder.length),
                  fromItem,
                );

                // Build the new flat customOrder by concatenating each
                // section's items (in section order). This keeps
                // intra-section ordering as the user just set it AND
                // freezes the per-section snapshot for every other
                // section so they don't drift on the next re-render.
                final newGlobalIds = <String>[];
                for (final st in membership.sectionTitlesInOrder) {
                  final items = (st == sectionTitle)
                      ? newSectionOrder
                      : (orderedBySection[st] ?? const <DrawerMenuItem>[]);
                  for (final item in items) {
                    if (item.id != null) newGlobalIds.add(item.id!);
                  }
                }

                ref
                    .read(drawerCustomizationProvider.notifier)
                    .setOrder(newGlobalIds);
              },
              itemBuilder: (context, index) {
                final item = sectionItems[index];
                final tile = _buildDrawerTile(
                  item,
                  context: context,
                  isConnected: isConnected,
                  unseenBadgeKeys: unseenBadgeKeys,
                );
                return ReorderableDelayedDragStartListener(
                  key: ValueKey('drawer_edit_${item.id ?? item.label}'),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
                    child: tile,
                  ),
                );
              },
            ),
          ),
        );
        continue;
      }

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = sectionItems[index];
              final isLastInSection = index == sectionItems.length - 1;

              final parentTile = _buildDrawerTile(
                item,
                context: context,
                isConnected: isConnected,
                unseenBadgeKeys: unseenBadgeKeys,
              );

              final isExpanded =
                  item.hasChildren && _expandedDrawerItems.contains(item.label);

              return Column(
                key: ValueKey('drawer_item_${item.label}'),
                children: [
                  parentTile,
                  if (isExpanded)
                    ...item.children!.map(
                      (child) => Padding(
                        key: ValueKey('drawer_child_${child.label}'),
                        padding: const EdgeInsets.only(top: AppTheme.spacing4),
                        child: _buildDrawerTile(
                          child,
                          context: context,
                          isConnected: isConnected,
                          unseenBadgeKeys: unseenBadgeKeys,
                          isChild: true,
                        ),
                      ),
                    ),
                  if (!isLastInSection)
                    const SizedBox(height: AppTheme.spacing4),
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
            }, childCount: sectionItems.length),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildAccountSection(BuildContext context, ThemeData theme) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final user = authState.value;
    final isSignedIn = user != null;
    final isAnonymous = user?.isAnonymous ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          profileAsync.when(
            data: (profile) => _buildProfileTile(
              context,
              theme,
              profile,
              isSignedIn,
              isAnonymous,
            ),
            loading: () => const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, st) => _buildProfileTile(
              context,
              theme,
              null,
              isSignedIn,
              isAnonymous,
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
    bool isAnonymous,
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
          if (isSignedIn && !isAnonymous) {
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

  @override
  Widget build(BuildContext context) {
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
            const DrawerNodeHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),
            _buildAccountSection(context, theme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: dividerAlpha),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  ..._buildDrawerMenuSlivers(context, theme),
                  SliverToBoxAdapter(
                    child: DrawerEnterpriseSection(
                      onNavigate: (screen) {
                        navigateFromDrawer(context, screen);
                      },
                    ),
                  ),
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
                  _SettingsButton(
                    onTap: () {
                      navigateFromDrawer(context, const SettingsScreen());
                    },
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  // Customize-sidebar entry point. Tap → summary sheet
                  // with reset CTA. Long-press → enter edit mode
                  // directly. In edit mode this widget renders as a
                  // "Done" pill that exits.
                  const DrawerCustomizeButton(),
                  const Spacer(),
                  // Quick light/dark theme flip. Three-way System option
                  // lives in Settings → Appearance & Accessibility.
                  _ThemeToggleButton(
                    isDark: context.isDarkMode,
                    onTap: _toggleThemeMode,
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
