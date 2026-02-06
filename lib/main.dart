// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:socialmesh/features/scanner/widgets/connecting_animation.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/transport.dart';
import 'core/accessibility_theme_adapter.dart';
import 'core/logging.dart';
import 'core/safety/error_handler.dart';
import 'core/safety/lifecycle_mixin.dart';
import 'core/widgets/connecting_content.dart';
import 'core/widgets/gradient_border_container.dart';
import 'core/routing/route_guard.dart';
import 'providers/splash_mesh_provider.dart';
import 'providers/connection_providers.dart' as conn;
import 'providers/lifecycle_command_provider.dart';
import 'models/canned_response.dart';
import 'models/tapback.dart';
import 'models/user_profile.dart';
import 'providers/app_providers.dart';
import 'providers/auth_providers.dart';
import 'providers/profile_providers.dart';
import 'providers/telemetry_providers.dart';
import 'providers/subscription_providers.dart';
import 'providers/cloud_sync_entitlement_providers.dart';
import 'providers/analytics_providers.dart';
import 'providers/signal_providers.dart';
import 'providers/connectivity_providers.dart';
import 'providers/presence_providers.dart';
import 'providers/glyph_provider.dart';
import 'providers/accessibility_providers.dart';
import 'providers/meshcore_providers.dart';
import 'services/meshcore/connection_coordinator.dart' show ConnectionResult;
import 'features/automations/automation_providers.dart';
import 'features/automations/automation_import_screen.dart';
import 'features/widget_builder/widget_import_screen.dart';
import 'models/mesh_models.dart';
import 'models/social.dart';
import 'services/app_intents/app_intents_service.dart';
import 'services/deep_link_manager.dart';
import 'services/profile/profile_cloud_sync_service.dart';
import 'services/notifications/push_notification_service.dart';
import 'services/content_moderation/profanity_checker.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/messaging/messaging_screen.dart';
import 'features/channels/channels_screen.dart';
import 'features/nodes/nodes_screen.dart';
import 'features/qr_scanner/universal_qr_scanner_screen.dart';
import 'features/map/map_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/account_subscriptions_screen.dart';
import 'features/device/device_config_screen.dart';
import 'features/settings/device_management_screen.dart';
import 'features/navigation/main_shell.dart';
import 'features/navigation/app_root_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/screens/mesh_brain_emotion_test_screen.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/presence/presence_screen.dart';
import 'features/discovery/node_discovery_overlay.dart';
import 'features/routes/route_detail_screen.dart';
import 'features/globe/globe_screen.dart';
import 'features/reachability/mesh_reachability_screen.dart';
import 'features/social/screens/post_detail_screen.dart';
import 'features/social/screens/profile_social_screen.dart';
import 'features/signals/screens/signal_detail_screen.dart';
import 'features/widget_builder/marketplace/widget_marketplace_screen.dart';
import 'features/widget_builder/marketplace/widget_marketplace_service.dart';
import 'features/widget_builder/marketplace/marketplace_providers.dart';
import 'services/user_presence_service.dart';
import 'services/accessibility_preferences_service.dart';
// import 'features/intro/intro_screen.dart';
import 'models/route.dart' as route_model;
import 'core/navigation.dart';

/// Global completer to signal when Firebase is ready
/// Used by providers that need Firestore
final Completer<bool> firebaseReadyCompleter = Completer<bool>();

/// Future that completes when Firebase is initialized (or fails)
Future<bool> get firebaseReady => firebaseReadyCompleter.future;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize centralized error handler FIRST - catches errors during startup
  AppErrorHandler.initialize();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  FlutterBluePlus.setLogLevel(LogLevel.none);

  // Initialize profanity checker (load banned words from assets)
  await ProfanityChecker.instance.load();

  // Initialize accessibility preferences before UI renders
  // This ensures text scaling and density are applied from first frame
  await AccessibilityPreferencesService().initialize();

  // Initialize Firebase in background - don't block app startup
  // This ensures the app works fully offline
  _initializeFirebaseInBackground();

  runApp(const ProviderScope(child: SocialmeshApp()));
}

/// Initialize Firebase without blocking the main app.
/// Firebase/Crashlytics are nice-to-have for error reporting but
/// should never prevent the app from working offline.
Future<void> _initializeFirebaseInBackground() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        AppLogging.debug('Firebase init timed out - continuing offline');
        throw TimeoutException('Firebase initialization timed out');
      },
    );

    // Configure Firestore settings to prevent cache corruption crashes
    // See: https://github.com/firebase/flutterfire/issues/9661
    // The crash occurs when Firestore's local cache gets corrupted on iOS.
    // This must be set BEFORE any Firestore access to take effect.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      // Firestore cache may be corrupted - try disabling persistence
      // This allows the app to continue working, losing local cache only
      AppLogging.debug('Firestore settings failed, trying without cache: $e');
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
        );
      } catch (e2) {
        // Firestore completely broken - continue without it
        AppLogging.debug('Firestore unavailable: $e2');
      }
    }

    // Note: FlutterError.onError and PlatformDispatcher.onError are now
    // configured by AppErrorHandler.initialize() which provides better
    // error classification (fatal vs non-fatal) and prevents image/lifecycle
    // errors from crashing the app.

    // Initialize Firebase Analytics
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    // Initialize profile cloud sync service (requires Firebase)
    initProfileCloudSyncService();

    // Initialize push notifications for social features
    await PushNotificationService().initialize();

    // Signal that Firebase is ready
    AppLogging.debug('🔥 Firebase initialized successfully');
    firebaseReadyCompleter.complete(true);
  } catch (e) {
    // Firebase failed to initialize (no internet, timeout, etc.)
    // App continues working fully offline - this is expected behavior
    AppLogging.debug('Firebase unavailable: $e - app running in offline mode');
  }

  // Listen for connectivity changes and attempt to resolve pending images
  try {
    final connectivity = Connectivity();
    connectivity.onConnectivityChanged.listen((results) {
      AppLogging.signals('CONNECTIVITY_CHANGE: $results');
      if (!results.contains(ConnectivityResult.none) && results.isNotEmpty) {
        // Try resolving any pending images now that connectivity may be restored
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final ctx = navigatorKey.currentContext;
            if (ctx == null) {
              AppLogging.signals(
                'CONNECTIVITY_CHANGE: navigator context not ready',
              );
              return;
            }
            final container = ProviderScope.containerOf(ctx, listen: false);
            final sigService = container.read(signalServiceProvider);
            sigService.attemptResolveAllPendingImages();
          } catch (e) {
            AppLogging.signals(
              'CONNECTIVITY_CHANGE: resolver invocation failed: $e',
            );
          }
        });
      }
    });
  } catch (e) {
    AppLogging.signals('Connectivity listener not available: $e');
    firebaseReadyCompleter.complete(false);
  }
}

class SocialmeshApp extends ConsumerStatefulWidget {
  const SocialmeshApp({super.key});

  @override
  ConsumerState<SocialmeshApp> createState() => _SocialmeshAppState();
}

class _SocialmeshAppState extends ConsumerState<SocialmeshApp>
    with WidgetsBindingObserver, LifecycleSafeMixin {
  StreamSubscription<NotificationNavigation>? _pushNotificationSubscription;

  /// Guard to prevent concurrent reconnect attempts.
  bool _reconnectInFlight = false;

  /// Timestamp of last reconnect attempt for cooldown.
  DateTime? _lastReconnectAttempt;

  /// Minimum interval between reconnect attempts (prevents iOS resume spam).
  static const _reconnectCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appInitProvider.notifier).initialize();
      // Load accent color from settings
      _loadAccentColor();
      // Set user online presence
      _initializePresence();
      // Initialize shake-to-report bug listener
      ref.read(bugReportServiceProvider).initialize();
      // Setup App Intents for iOS Shortcuts integration
      ref.read(appIntentsServiceProvider).setup();
      // Initialize RevenueCat for purchases
      _initializePurchases();
      // Initialize deep link handling (lifecycle-safe via DeepLinkManager)
      _initializeDeepLinks();
      // Initialize push notification navigation
      _initializePushNotificationNavigation();
      // Initialize glyph service (Nothing Phone)
      _initializeGlyphService();
    });
  }

  @override
  void dispose() {
    _pushNotificationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Mark app as active for lifecycle-aware commands
      ref.read(lifecycleCommandManagerProvider).setAppActive(true);
      _handleAppResumed();
      // Set user online when app returns to foreground
      ref.read(userPresenceServiceProvider).setOnline();
      // Process any due scheduled automations on resume
      _processScheduledAutomationsOnResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Mark app as inactive - prevents device commands from background
      ref.read(lifecycleCommandManagerProvider).setAppActive(false);
      // Set user offline when app goes to background
      ref.read(userPresenceServiceProvider).setOffline();
      // Sync scheduled automations to platform scheduler for background execution
      _syncScheduledAutomationsToPlatform();
    }
  }

  /// Sync scheduled automations to platform scheduler when app goes to background
  Future<void> _syncScheduledAutomationsToPlatform() async {
    try {
      final bridgeAsync = ref.read(schedulerBridgeInitProvider);
      if (bridgeAsync.hasValue) {
        final bridge = bridgeAsync.value!;
        await bridge.syncToPlatform();
        AppLogging.automations('Synced schedules to platform on background');
      }
    } catch (e) {
      AppLogging.automations('Failed to sync schedules to platform: $e');
    }
  }

  /// Process any due scheduled automations when app returns to foreground
  void _processScheduledAutomationsOnResume() {
    try {
      final bridgeAsync = ref.read(schedulerBridgeInitProvider);
      if (bridgeAsync.hasValue) {
        final bridge = bridgeAsync.value!;
        bridge.processOnResume();
        AppLogging.automations('Processed scheduled automations on resume');
      }
    } catch (e) {
      AppLogging.automations('Failed to process schedules on resume: $e');
    }
  }

  /// Handle app returning to foreground.
  ///
  /// Uses protocol-aware state checks to avoid reconnecting while already
  /// connected (MeshCore) or while a reconnect is in progress.
  Future<void> _handleAppResumed() async {
    AppLogging.connection('📱 APP RESUMED: Checking connection state...');

    // Use protocol-aware connection state checks
    final isLinkConnected = ref.read(isLinkConnectedProvider);
    final isLinkConnecting = ref.read(isLinkConnectingProvider);
    final autoReconnectState = ref.read(autoReconnectStateProvider);
    final userDisconnected = ref.read(userDisconnectedProvider);
    final deviceConnectionState = ref.read(conn.deviceConnectionProvider);

    // Get protocol for logging
    final settingsAsync = ref.read(settingsServiceProvider);
    final protocol =
        settingsAsync.asData?.value.lastDeviceProtocol ?? 'unknown';

    AppLogging.connection(
      '📱 APP RESUMED: protocol=$protocol, '
      'isLinkConnected=$isLinkConnected, '
      'isLinkConnecting=$isLinkConnecting, '
      'autoReconnectState=$autoReconnectState, '
      'userDisconnected=$userDisconnected',
    );

    // If the active protocol link is connected, do nothing
    if (isLinkConnected) {
      AppLogging.connection(
        '📱 APP RESUMED: $protocol link already connected, doing nothing',
      );
      return;
    }

    // If the active protocol link is connecting, do nothing
    if (isLinkConnecting) {
      AppLogging.connection(
        '📱 APP RESUMED: $protocol link is connecting, doing nothing',
      );
      return;
    }

    // If already trying to reconnect, don't interfere
    if (autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting) {
      AppLogging.connection(
        '📱 APP RESUMED: Reconnect already in progress, doing nothing',
      );
      return;
    }

    // CRITICAL: Check the global userDisconnected flag
    if (userDisconnected) {
      AppLogging.connection(
        '📱 APP RESUMED: User manually disconnected (global flag), NOT triggering reconnect',
      );
      return;
    }

    // Also check disconnect reason (belt and suspenders)
    if (deviceConnectionState.reason ==
        conn.DisconnectReason.userDisconnected) {
      AppLogging.connection(
        '📱 APP RESUMED: User manually disconnected (reason), NOT triggering reconnect',
      );
      return;
    }

    // Refresh connectivity on resume (airplane mode toggles may require a recheck)
    try {
      ref.read(connectivityStatusProvider.notifier).checkNow();
    } catch (e) {
      AppLogging.connection('📱 APP RESUMED: Connectivity refresh failed: $e');
    }

    // If disconnected and we have a saved device, try to reconnect
    // This handles the case where user turned device back on after auto-reconnect failed
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      final lastDeviceId = settings.lastDeviceId;

      if (lastDeviceId != null && settings.autoReconnect) {
        AppLogging.connection(
          '📱 APP RESUMED: Disconnected with saved device, triggering reconnect...',
        );

        // Reset to idle first to allow reconnect to proceed
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);

        // Trigger reconnect
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.scanning);

        // Start the reconnect process
        _performReconnectOnResume(lastDeviceId);
      } else {
        AppLogging.connection(
          '📱 APP RESUMED: No saved device or auto-reconnect disabled',
        );
      }
    } catch (e) {
      AppLogging.connection('📱 APP RESUMED: Error checking settings: $e');
    }
  }

  /// Perform a single reconnect attempt when app resumes.
  ///
  /// Includes reentrancy guard and cooldown to prevent duplicate attempts.
  /// Routes to appropriate protocol based on lastDeviceProtocol setting.
  Future<void> _performReconnectOnResume(String deviceId) async {
    // Reentrancy guard: only one reconnect attempt at a time
    if (_reconnectInFlight) {
      AppLogging.connection(
        '📱 RECONNECT ON RESUME: BLOCKED - reconnect already in flight',
      );
      return;
    }

    // Cooldown check: prevent rapid-fire reconnect attempts
    if (_lastReconnectAttempt != null) {
      final elapsed = DateTime.now().difference(_lastReconnectAttempt!);
      if (elapsed < _reconnectCooldown) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: BLOCKED - cooldown (${elapsed.inMilliseconds}ms < ${_reconnectCooldown.inMilliseconds}ms)',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }
    }

    // Re-check connection state (may have changed since _handleAppResumed)
    final isLinkConnected = ref.read(isLinkConnectedProvider);
    final isLinkConnecting = ref.read(isLinkConnectingProvider);
    if (isLinkConnected || isLinkConnecting) {
      AppLogging.connection(
        '📱 RECONNECT ON RESUME: BLOCKED - link already connected/connecting',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    }

    AppLogging.connection(
      '📱 RECONNECT ON RESUME: Starting for device: $deviceId',
    );

    _reconnectInFlight = true;
    _lastReconnectAttempt = DateTime.now();

    try {
      // CRITICAL: Check the global userDisconnected flag
      if (ref.read(userDisconnectedProvider)) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: BLOCKED - user manually disconnected (global flag)',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }

      // Also check device connection state reason
      final deviceState = ref.read(conn.deviceConnectionProvider);
      if (deviceState.reason == conn.DisconnectReason.userDisconnected) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: BLOCKED - user manually disconnected (reason)',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }

      // Check protocol type to route to appropriate reconnect path
      final settings = await ref.read(settingsServiceProvider.future);
      final lastProtocol = settings.lastDeviceProtocol;

      if (lastProtocol == 'meshcore') {
        await _performMeshCoreReconnectOnResume(deviceId, settings);
      } else {
        await _performMeshtasticReconnectOnResume(deviceId, settings);
      }
    } finally {
      // Always clear the mutex, even on exceptions
      _reconnectInFlight = false;
      AppLogging.connection('📱 RECONNECT ON RESUME: Completed, mutex cleared');
    }
  }

  /// Reconnect to a MeshCore device on app resume.
  ///
  /// On iOS, service UUID filtering during scans can miss MeshCore devices
  /// because iOS may not include service UUIDs in the advertisement packet.
  /// This method uses a multi-strategy approach:
  /// 1. First try direct connection by device identifier (most reliable on iOS)
  /// 2. Fall back to unfiltered scan matching by device identifier
  Future<void> _performMeshCoreReconnectOnResume(
    String deviceId,
    dynamic settings,
  ) async {
    AppLogging.connection(
      '📱 RECONNECT ON RESUME: MeshCore protocol detected, deviceId=$deviceId',
    );

    try {
      // Strategy 1: Try direct connect by device identifier (no scan needed)
      // On iOS, this is the most reliable way to reconnect to a known peripheral
      AppLogging.connection(
        '📱 RECONNECT ON RESUME: Strategy 1 - attempting direct connect by ID...',
      );

      DeviceInfo? foundDevice;

      try {
        // Check system devices first (peripherals iOS already knows about)
        final systemDevices = await FlutterBluePlus.systemDevices([]);
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: Found ${systemDevices.length} system devices',
        );

        for (final device in systemDevices) {
          AppLogging.connection(
            '📱 RECONNECT ON RESUME: System device: ${device.remoteId}',
          );
          if (device.remoteId.toString() == deviceId) {
            AppLogging.connection(
              '📱 RECONNECT ON RESUME: Target found in system devices!',
            );
            foundDevice = DeviceInfo(
              id: device.remoteId.toString(),
              name: device.platformName.isNotEmpty
                  ? device.platformName
                  : settings.lastDeviceName ?? 'MeshCore Device',
              type: TransportType.ble,
              address: device.remoteId.toString(),
            );
            break;
          }
        }

        // If not found in system devices, create a device reference by ID
        // This allows iOS to connect to a known peripheral without scanning
        if (foundDevice == null) {
          AppLogging.connection(
            '📱 RECONNECT ON RESUME: Not in system devices, creating device by ID...',
          );
          foundDevice = DeviceInfo(
            id: deviceId,
            name: settings.lastDeviceName ?? 'MeshCore Device',
            type: TransportType.ble,
            address: deviceId,
          );
        }
      } catch (e) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: System devices check failed: $e',
        );
        // Create device reference anyway
        foundDevice = DeviceInfo(
          id: deviceId,
          name: settings.lastDeviceName ?? 'MeshCore Device',
          type: TransportType.ble,
          address: deviceId,
        );
      }

      // Try direct connection first
      AppLogging.connection(
        '📱 RECONNECT ON RESUME: Attempting direct connect to ${foundDevice.id}...',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);

      final coordinator = ref.read(connectionCoordinatorProvider);
      var result = await coordinator.connect(device: foundDevice);

      if (result.success) {
        // Direct connect succeeded!
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: Direct connect succeeded!',
        );
        await _finalizeMeshCoreReconnect(foundDevice, result);
        return;
      }

      // Strategy 2: Direct connect failed, try scanning without service filter
      // On iOS, service UUID filtering can miss devices that don't advertise
      // their service UUIDs in the advertisement packet
      AppLogging.connection(
        '📱 RECONNECT ON RESUME: Direct connect failed (${result.errorMessage}), '
        'trying Strategy 2 - unfiltered scan...',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);

      final transport = ref.read(transportProvider);

      // Use scanAll=true to avoid iOS service UUID filtering issues
      AppLogging.connection(
        '📱 RECONNECT ON RESUME: Starting 10s unfiltered scan (scanAll=true), '
        'matching by deviceId=$deviceId',
      );
      final scanStream = transport.scan(
        timeout: const Duration(seconds: 10),
        scanAll: true, // Important: don't filter by service UUID
      );

      foundDevice = null;
      await for (final device in scanStream) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: Scan found: ${device.id} (${device.name})',
        );
        if (device.id == deviceId) {
          foundDevice = device;
          AppLogging.connection(
            '📱 RECONNECT ON RESUME: Target MeshCore device found in scan!',
          );
          break;
        }
      }

      if (foundDevice == null) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: MeshCore device not found in unfiltered scan',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }

      // Try to connect to the scanned device
      AppLogging.connection(
        '📱 RECONNECT ON RESUME: Connecting to scanned MeshCore device...',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);

      result = await coordinator.connect(device: foundDevice);

      if (!result.success) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: MeshCore connect failed: ${result.errorMessage}',
        );
        throw Exception(result.errorMessage ?? 'MeshCore connection failed');
      }

      await _finalizeMeshCoreReconnect(foundDevice, result);
    } catch (e) {
      AppLogging.connection('📱 RECONNECT ON RESUME: MeshCore failed: $e');
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
    }
  }

  /// Finalize MeshCore reconnection by updating providers and state.
  Future<void> _finalizeMeshCoreReconnect(
    DeviceInfo device,
    ConnectionResult result,
  ) async {
    // Update providers
    ref.read(connectedDeviceProvider.notifier).setState(device);

    // Mark as paired with isMeshCore=true
    final nodeIdHex = result.deviceInfo?.nodeId ?? '0';
    final nodeNumParsed = int.tryParse(nodeIdHex, radix: 16);
    ref
        .read(conn.deviceConnectionProvider.notifier)
        .markAsPaired(device, nodeNumParsed, isMeshCore: true);

    // Clear userDisconnected flags
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
    ref.read(conn.deviceConnectionProvider.notifier).clearUserDisconnected();

    AppLogging.connection(
      '📱 RECONNECT ON RESUME: MeshCore connected: ${result.deviceInfo?.displayName}',
    );

    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.success);

    await Future.delayed(const Duration(milliseconds: 500));
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
  }

  /// Reconnect to a Meshtastic device on app resume.
  Future<void> _performMeshtasticReconnectOnResume(
    String deviceId,
    dynamic settings,
  ) async {
    AppLogging.connection('📱 RECONNECT ON RESUME: Meshtastic protocol');

    try {
      final transport = ref.read(transportProvider);

      // Quick scan to find the device
      AppLogging.connection('📱 RECONNECT ON RESUME: Starting 8s scan...');
      final scanStream = transport.scan(timeout: const Duration(seconds: 8));
      DeviceInfo? foundDevice;

      await for (final device in scanStream) {
        AppLogging.connection('📱 RECONNECT ON RESUME: Found ${device.id}');
        if (device.id == deviceId) {
          foundDevice = device;
          AppLogging.connection('📱 RECONNECT ON RESUME: Target device found!');
          break;
        }
      }

      if (foundDevice != null) {
        AppLogging.connection('📱 RECONNECT ON RESUME: Connecting...');
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.connecting);

        await transport.connect(foundDevice);

        if (transport.state == DeviceConnectionState.connected) {
          AppLogging.connection(
            '📱 RECONNECT ON RESUME: BLE connected, starting protocol...',
          );
          // Clear all previous device data before starting new connection
          await clearDeviceDataBeforeConnect(ref);

          final protocol = ref.read(protocolServiceProvider);

          // Set device info for hardware model inference
          protocol.setDeviceName(foundDevice.name);
          protocol.setBleModelNumber(transport.bleModelNumber);
          protocol.setBleManufacturerName(transport.bleManufacturerName);

          await protocol.start();

          if (protocol.myNodeNum == null) {
            AppLogging.connection(
              '📱 RECONNECT ON RESUME: No myNodeNum - auth may have failed',
            );
            await transport.disconnect();
            throw Exception('Authentication failed');
          }

          AppLogging.connection(
            '📱 RECONNECT ON RESUME: Protocol started, myNodeNum=${protocol.myNodeNum}',
          );
          ref.read(connectedDeviceProvider.notifier).setState(foundDevice);
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.success);

          // Start location updates
          final locationService = ref.read(locationServiceProvider);
          await locationService.startLocationUpdates();

          AppLogging.connection('📱 RECONNECT ON RESUME: ✅ Success!');

          await Future.delayed(const Duration(milliseconds: 500));
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.idle);
        } else {
          AppLogging.connection(
            '📱 RECONNECT ON RESUME: BLE connect failed, transport.state=${transport.state}',
          );
          throw Exception('Connection failed');
        }
      } else {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: Device not found in scan',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
      }
    } catch (e) {
      AppLogging.connection('📱 RECONNECT ON RESUME: Failed: $e');
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
    }
  }

  Future<void> _initializePurchases() async {
    try {
      final service = await ref.read(subscriptionServiceProvider.future);
      AppLogging.debug('💰 RevenueCat initialized');

      // If user is already signed in, sync RevenueCat with Firebase UID
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        AppLogging.subscriptions(
          '💰 User already signed in, syncing RevenueCat with Firebase UID...',
        );
        await service.logIn(firebaseUser.uid);
        AppLogging.subscriptions('💰 RevenueCat synced with Firebase UID');
      }

      // Initialize cloud sync entitlement service
      final cloudSyncService = ref.read(cloudSyncEntitlementServiceProvider);
      await cloudSyncService.initialize();
      AppLogging.debug('☁️ Cloud sync entitlement service initialized');
    } catch (e) {
      AppLogging.debug('💰 RevenueCat init failed: $e');
    }
  }

  Future<void> _initializeDeepLinks() async {
    try {
      // Use DeepLinkManager for lifecycle-safe navigation
      final deepLinkManager = ref.read(deepLinkManagerProvider);
      await deepLinkManager.initialize();
      AppLogging.debug('🔗 Deep link manager initialized');
    } catch (e) {
      AppLogging.debug('🔗 Deep link init failed: $e');
    }
  }

  /// Initialize glyph service (Nothing Phone)
  Future<void> _initializeGlyphService() async {
    try {
      await ref.read(glyphServiceInitProvider.future);
      final isSupported = ref.read(glyphSupportedProvider);
      if (isSupported) {
        AppLogging.app('🔆 Glyph interface ready');
      }
    } catch (e) {
      AppLogging.app('🔆 Glyph init failed: $e');
    }
  }

  /// Initialize push notification navigation handling
  /// Must wait for Firebase to be ready before accessing PushNotificationService
  Future<void> _initializePushNotificationNavigation() async {
    try {
      // Wait for Firebase to be ready - if it fails, skip push notifications
      final isReady = await firebaseReady;
      if (!isReady) {
        AppLogging.notifications(
          '🔔 Push notification navigation skipped - Firebase not available',
        );
        return;
      }

      _pushNotificationSubscription = PushNotificationService()
          .onNotificationNavigation
          .listen(_handlePushNotificationNavigation);
      AppLogging.notifications('🔔 Push notification navigation initialized');
    } catch (e) {
      AppLogging.notifications(
        '🔔 Push notification navigation init failed: $e',
      );
    }
  }

  /// Handle navigation from push notification tap
  void _handlePushNotificationNavigation(NotificationNavigation nav) {
    AppLogging.notifications(
      '🔔 Handling notification navigation: ${nav.type} -> ${nav.targetId}',
    );

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogging.notifications('🔔 Navigator not available');
      return;
    }

    // Small delay to ensure app is fully loaded after cold start
    Future.delayed(const Duration(milliseconds: 500), () {
      switch (nav.type) {
        case 'new_follower':
        case 'follow_request':
        case 'follow_request_accepted':
          // Navigate to the user's profile
          if (nav.targetId != null) {
            navigator.pushNamed(
              '/profile',
              arguments: {'userId': nav.targetId},
            );
          }
          break;

        case 'new_like':
        case 'new_comment':
        case 'new_reply':
        case 'mention':
          // Navigate to the post
          if (nav.targetId != null) {
            navigator.pushNamed(
              '/post-detail',
              arguments: {'postId': nav.targetId},
            );
          }
          break;

        case 'new_signal':
          // Navigate to the signal detail screen
          if (nav.targetId != null) {
            navigator.pushNamed(
              '/signal-detail',
              arguments: {'signalId': nav.targetId},
            );
          }
          break;

        default:
          AppLogging.notifications('🔔 Unknown notification type: ${nav.type}');
      }
    });
  }

  Future<void> _loadAccentColor() async {
    final settings = await ref.read(settingsServiceProvider.future);

    // Local accent color is now loaded automatically by AccentColorNotifier.build()
    // Just load the theme mode from local settings
    final localThemeModeIndex = settings.themeMode;
    final localThemeMode = ThemeMode.values[localThemeModeIndex];
    ref.read(themeModeProvider.notifier).setThemeMode(localThemeMode);

    // Wait for Firebase to be ready before syncing from cloud
    final isFirebaseReady = await firebaseReady.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        AppLogging.debug('⏱️ Firebase ready timeout, using local accent color');
        return false;
      },
    );

    if (!isFirebaseReady) {
      AppLogging.debug('📱 Firebase not ready, using local accent color');
      return;
    }

    // Then sync from cloud in background (may override local)
    try {
      // Wait for auth state to be ready
      final authState = await ref.read(authStateProvider.future);
      AppLogging.debug('🎨 Auth state: ${authState?.email ?? "not signed in"}');

      // If user is signed in, sync from cloud
      if (authState != null) {
        AppLogging.debug('🎨 User signed in, reading profile (no invalidate)');
        // NOTE: Don't invalidate userProfileProvider here!
        // UserProfileNotifier.build() already calls fullSync() which syncs from cloud.
        // Invalidating here causes redundant Firestore writes (batches 6, 7, 8).

        AppLogging.debug('🎨 Waiting for profile future...');
        final profile = await ref.read(userProfileProvider.future);
        final prefs = profile?.preferences;

        AppLogging.debug('🎨 Profile loaded: ${profile?.displayName}');
        AppLogging.debug(
          '🎨 Profile accentColorIndex: ${profile?.accentColorIndex}',
        );
        AppLogging.debug('🎨 Profile updatedAt: ${profile?.updatedAt}');
        AppLogging.debug('🎨 Profile isSynced: ${profile?.isSynced}');

        // Update accent color from cloud if available
        final colorIndex = profile?.accentColorIndex;
        AppLogging.debug('🎨 Cloud profile accentColorIndex: $colorIndex');
        if (colorIndex != null &&
            colorIndex >= 0 &&
            colorIndex < AccentColors.all.length) {
          final cloudColor = AccentColors.all[colorIndex];
          AppLogging.debug(
            '🎨 Setting color to: ${AccentColors.names[colorIndex]}',
          );
          await ref.read(accentColorProvider.notifier).setColor(cloudColor);
          AppLogging.debug(
            '🎨 Updated accent color from cloud: ${AccentColors.names[colorIndex]}',
          );
        } else {
          AppLogging.debug(
            '🎨 No valid accentColorIndex in profile, colorIndex=$colorIndex',
          );
        }

        // Update theme mode from cloud preferences
        // NOTE: We intentionally DON'T sync theme from cloud to local.
        // Theme preference is device-specific and local storage is the source of truth.
        // Cloud sync is only used for backup/restore scenarios, not for overwriting
        // user's current device preference.
        // The drawer toggle and theme settings screen both save to local AND cloud,
        // so cloud stays in sync, but we don't let cloud override local on startup.

        // Load remaining cloud preferences
        await _loadRemainingCloudPreferences(settings, prefs);
      }
    } catch (e) {
      AppLogging.debug('☁️ Cloud sync failed, using local settings: $e');
    }
  }

  /// Initialize user presence tracking
  Future<void> _initializePresence() async {
    // Initialize extended presence service first (loads cached remote presence)
    final extendedPresenceService = ref.read(extendedPresenceServiceProvider);
    await extendedPresenceService.init();

    // Wait for Firebase to be ready
    final isFirebaseReady = await firebaseReady.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );

    if (!isFirebaseReady) return;

    // Wait for user to be signed in
    final authState = await ref.read(authStateProvider.future);
    if (authState != null) {
      ref.read(userPresenceServiceProvider).setOnline();
    }
  }

  Future<void> _loadRemainingCloudPreferences(
    dynamic settings,
    UserPreferences? prefs,
  ) async {
    if (prefs == null) return;

    // Load notification settings from cloud
    if (prefs.notificationsEnabled != null) {
      await settings.setNotificationsEnabled(prefs.notificationsEnabled!);
    }
    if (prefs.newNodeNotificationsEnabled != null) {
      await settings.setNewNodeNotificationsEnabled(
        prefs.newNodeNotificationsEnabled!,
      );
    }
    if (prefs.directMessageNotificationsEnabled != null) {
      await settings.setDirectMessageNotificationsEnabled(
        prefs.directMessageNotificationsEnabled!,
      );
    }
    if (prefs.channelMessageNotificationsEnabled != null) {
      await settings.setChannelMessageNotificationsEnabled(
        prefs.channelMessageNotificationsEnabled!,
      );
    }
    if (prefs.notificationSoundEnabled != null) {
      await settings.setNotificationSoundEnabled(
        prefs.notificationSoundEnabled!,
      );
    }
    if (prefs.notificationVibrationEnabled != null) {
      await settings.setNotificationVibrationEnabled(
        prefs.notificationVibrationEnabled!,
      );
    }

    // Load haptic settings from cloud
    if (prefs.hapticFeedbackEnabled != null) {
      await settings.setHapticFeedbackEnabled(prefs.hapticFeedbackEnabled!);
    }
    if (prefs.hapticIntensity != null) {
      await settings.setHapticIntensity(prefs.hapticIntensity!);
    }

    // Load animation settings from cloud
    if (prefs.animationsEnabled != null) {
      await settings.setAnimationsEnabled(prefs.animationsEnabled!);
    }
    if (prefs.animations3DEnabled != null) {
      await settings.setAnimations3DEnabled(prefs.animations3DEnabled!);
    }

    // Load canned responses from cloud
    if (prefs.cannedResponsesJson != null) {
      try {
        final jsonList = jsonDecode(prefs.cannedResponsesJson!) as List;
        final responses = jsonList
            .map((j) => CannedResponse.fromJson(j))
            .toList();
        await settings.setCannedResponses(responses);
        AppLogging.debug(
          '📝 Loaded ${responses.length} canned responses from cloud',
        );
      } catch (e) {
        AppLogging.debug('Failed to parse canned responses: $e');
      }
    }

    // Load tapback configs from cloud
    if (prefs.tapbackConfigsJson != null) {
      try {
        final jsonList = jsonDecode(prefs.tapbackConfigsJson!) as List;
        final configs = jsonList.map((j) => TapbackConfig.fromJson(j)).toList();
        await settings.setTapbackConfigs(configs);
        AppLogging.debug(
          '👍 Loaded ${configs.length} tapback configs from cloud',
        );
      } catch (e) {
        AppLogging.debug('Failed to parse tapback configs: $e');
      }
    }

    // Load ringtone from cloud
    if (prefs.ringtoneRtttl != null && prefs.ringtoneName != null) {
      await settings.setSelectedRingtone(
        rtttl: prefs.ringtoneRtttl!,
        name: prefs.ringtoneName!,
      );
      AppLogging.debug('🔔 Loaded ringtone from cloud: ${prefs.ringtoneName}');
    }

    // Load splash mesh config from cloud
    if (prefs.splashMeshSize != null) {
      await settings.setSplashMeshConfig(
        size: prefs.splashMeshSize!,
        animationType: prefs.splashMeshAnimationType ?? 'tumble',
        glowIntensity: prefs.splashMeshGlowIntensity ?? 0.5,
        lineThickness: prefs.splashMeshLineThickness ?? 0.5,
        nodeSize: prefs.splashMeshNodeSize ?? 0.8,
        useAccelerometer: prefs.splashMeshUseAccelerometer ?? true,
        accelerometerSensitivity: prefs.splashMeshAccelSensitivity ?? 0.5,
        accelerometerFriction: prefs.splashMeshAccelFriction ?? 0.97,
        physicsMode: prefs.splashMeshPhysicsMode ?? 'momentum',
        enableTouch: prefs.splashMeshEnableTouch ?? true,
        enablePullToStretch: prefs.splashMeshEnablePullToStretch ?? false,
        touchIntensity: prefs.splashMeshTouchIntensity ?? 0.5,
        stretchIntensity: prefs.splashMeshStretchIntensity ?? 0.3,
      );
      // Invalidate the provider so it reloads with new config
      ref.invalidate(splashMeshConfigProvider);
      AppLogging.debug('✨ Loaded splash mesh config from cloud');
    }

    // Load automations from cloud
    if (prefs.automationsJson != null) {
      try {
        final automationRepo = ref.read(automationRepositoryProvider);
        await automationRepo.loadFromJson(prefs.automationsJson!);
        AppLogging.automations(
          '⚡ Loaded ${automationRepo.automations.length} automations from cloud',
        );
      } catch (e) {
        AppLogging.automations('Failed to parse automations: $e');
      }
    }

    // Load IFTTT config from cloud
    if (prefs.iftttConfigJson != null) {
      try {
        final iftttService = ref.read(iftttServiceProvider);
        await iftttService.loadFromJson(prefs.iftttConfigJson!);
        AppLogging.debug('🔗 Loaded IFTTT config from cloud');
      } catch (e) {
        AppLogging.debug('Failed to parse IFTTT config: $e');
      }
    }

    AppLogging.debug('☁️ Loaded user preferences from cloud profile');
  }

  @override
  Widget build(BuildContext context) {
    // Watch auto-reconnect and live activity managers at app level
    // so they stay active regardless of which screen is shown
    ref.watch(autoReconnectManagerProvider);
    ref.watch(bluetoothStateListenerProvider);
    ref.watch(liveActivityManagerProvider);

    // Watch telemetry logger to automatically save telemetry data
    ref.watch(telemetryLoggerProvider);

    // Watch accent color for dynamic theme (with default fallback)
    // Using when() to handle all states including errors gracefully
    final accentColor = ref
        .watch(accentColorProvider)
        .when(
          data: (color) => color,
          loading: () => AccentColors.magenta,
          error: (e, st) => AccentColors.magenta,
        );

    // Watch theme mode for dark/light switching
    final themeMode = ref.watch(themeModeProvider);

    // Watch accessibility preferences for theme adjustments
    final accessibilityPrefs = ref.watch(accessibilityPreferencesProvider);

    // Apply accessibility preferences to themes
    final lightTheme = AccessibilityThemeAdapter.applyPreferences(
      baseTheme: AppTheme.lightTheme(accentColor),
      preferences: accessibilityPrefs,
    );
    final darkTheme = AccessibilityThemeAdapter.applyPreferences(
      baseTheme: AppTheme.darkTheme(accentColor),
      preferences: accessibilityPrefs,
    );

    // Note: We intentionally don't watch analyticsObserverProvider here
    // because changing the navigatorObservers list causes the navigator
    // to be recreated, which destroys all current routes (including the
    // scanner). Instead, we use a stable delegating observer that will
    // pick up the real analytics observer when Firebase initializes.

    return RepaintBoundary(
      key: appRepaintBoundaryKey,
      child: MaterialApp(
        title: 'Socialmesh',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,

        navigatorObservers: [
          _KeyboardDismissObserver(),
          _DelegatingAnalyticsObserver(ref),
        ],
        home: const _AppRouter(),
        routes: {
          '/scanner': (context) => const ScannerScreen(),
          '/messages': (context) => const MessagingScreen(),
          '/channels': (context) => const ChannelsScreen(),
          '/nodes': (context) => const NodesScreen(),
          '/qr-scanner': (context) => const UniversalQrScannerScreen(),
          '/map': (context) => const MapScreen(),
          '/globe': (context) => const GlobeScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/account': (context) => const AccountSubscriptionsScreen(),
          '/device-config': (context) => _buildProtectedRoute(
            context,
            '/device-config',
            const DeviceConfigScreen(),
          ),
          '/device-management': (context) => _buildProtectedRoute(
            context,
            '/device-management',
            const DeviceManagementScreen(),
          ),
          // Note: Region setup is NOT a named route - it's navigated to directly
          // from scanner using MaterialPageRoute to avoid route guard interference
          // during the device reboot that occurs when setting region.
          '/main': (context) => const MainShell(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/emotion-test': (context) => const MeshBrainEmotionTestScreen(),
          '/timeline': (context) => const TimelineScreen(),
          '/presence': (context) => const PresenceScreen(),
          '/reachability': (context) => const MeshReachabilityScreen(),
        },
        onGenerateRoute: (settings) {
          // Check route requirements before building
          if (RouteRegistry.isDeviceRequired(settings.name)) {
            // This route requires device - it will be checked by the builder
          }

          // Handle routes that need arguments
          if (settings.name == '/route-detail') {
            final route = settings.arguments as route_model.Route;
            return MaterialPageRoute(
              builder: (context) => RouteDetailScreen(route: route),
            );
          }
          if (settings.name == '/map') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => MapScreen(
                initialLatitude: args?['latitude'] as double?,
                initialLongitude: args?['longitude'] as double?,
                initialLocationLabel: args?['label'] as String?,
              ),
            );
          }
          if (settings.name == '/post-detail') {
            final args = settings.arguments as Map<String, dynamic>?;
            final postId = args?['postId'] as String?;
            if (postId != null) {
              return MaterialPageRoute(
                builder: (context) => PostDetailScreen(postId: postId),
              );
            }
          }
          if (settings.name == '/profile') {
            final args = settings.arguments as Map<String, dynamic>?;
            final userId = args?['userId'] as String?;
            final displayName = args?['displayName'] as String?;

            AppLogging.qr(
              '🔗 RouteGenerator: /profile - userId=$userId, displayName=$displayName, args=$args',
            );

            // Direct userId takes precedence (internal navigation)
            if (userId != null) {
              AppLogging.qr(
                'QR - 🔗 RouteGenerator: Using direct userId=$userId',
              );
              return MaterialPageRoute(
                builder: (context) => ProfileSocialScreen(userId: userId),
              );
            }

            // Display name lookup (from deep links)
            if (displayName != null) {
              AppLogging.qr(
                '🔗 RouteGenerator: Using displayName lookup for $displayName',
              );
              return MaterialPageRoute(
                builder: (context) =>
                    _ProfileDisplayNameLoader(displayName: displayName),
              );
            }

            AppLogging.qr(
              '🔗 RouteGenerator: ERROR - /profile route has no userId or displayName!',
            );
          }
          if (settings.name == '/signal-detail') {
            final args = settings.arguments as Map<String, dynamic>?;
            final signalId = args?['signalId'] as String?;
            if (signalId != null) {
              return MaterialPageRoute(
                builder: (context) => _SignalDetailLoader(signalId: signalId),
              );
            }
          }
          if (settings.name == '/widget-detail') {
            final args = settings.arguments as Map<String, dynamic>?;
            final widgetId = args?['widgetId'] as String?;
            if (widgetId != null) {
              return MaterialPageRoute(
                builder: (context) => _WidgetDetailLoader(widgetId: widgetId),
              );
            }
          }
          if (settings.name == '/automation-import') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => AutomationImportScreen(
                base64Data: args?['base64Data'] as String?,
                firestoreId: args?['firestoreId'] as String?,
              ),
            );
          }
          if (settings.name == '/widget-import') {
            final args = settings.arguments as Map<String, dynamic>?;
            final base64Data = args?['base64Data'] as String?;
            final firestoreId = args?['firestoreId'] as String?;
            if (base64Data != null || firestoreId != null) {
              return MaterialPageRoute(
                builder: (context) => WidgetImportScreen(
                  base64Data: base64Data,
                  firestoreId: firestoreId,
                ),
              );
            }
          }
          return null;
        },
      ),
    );
  }

  /// Build a protected route that checks device connection requirements
  Widget _buildProtectedRoute(
    BuildContext context,
    String routeName,
    Widget screen,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final isConnected = ref.watch(conn.isDeviceConnectedProvider);

        if (isConnected) {
          return screen;
        }

        // Show blocked screen
        return _BlockedRouteScreen(
          routeName: routeName,
          message:
              RouteRegistry.getMetadata(routeName)?.blockedMessage ??
              'Connect device to access this screen',
        );
      },
    );
  }
}

/// Loader widget that fetches signal data and navigates to SignalDetailScreen
class _SignalDetailLoader extends ConsumerWidget {
  final String signalId;

  const _SignalDetailLoader({required this.signalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading Signal')),
      body: FutureBuilder<Post?>(
        future: ref.read(signalServiceProvider).getSignalById(signalId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading signal: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final signal = snapshot.data;
          if (signal == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.signal_wifi_off, size: 48),
                  const SizedBox(height: 16),
                  const Text('Signal not found'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          // Navigate to signal detail screen with the loaded signal
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Use global navigatorKey to avoid "Navigator.of() called with
            // a context that does not contain a Navigator" crash when
            // the widget is disposed before the callback runs
            final navigator = navigatorKey.currentState;
            if (navigator == null) {
              return;
            }
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => SignalDetailScreen(signal: signal),
              ),
            );
          });

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

/// Loader widget that fetches widget data from marketplace or shared_widgets collection
/// and navigates to appropriate screen.
///
/// Tries marketplace API first, then falls back to shared_widgets Firestore collection.
class _WidgetDetailLoader extends ConsumerStatefulWidget {
  final String widgetId;

  const _WidgetDetailLoader({required this.widgetId});

  @override
  ConsumerState<_WidgetDetailLoader> createState() =>
      _WidgetDetailLoaderState();
}

class _WidgetDetailLoaderState extends ConsumerState<_WidgetDetailLoader> {
  bool _isLoading = true;
  String? _error;
  MarketplaceWidget? _marketplaceWidget;
  bool _isSharedWidget = false;

  @override
  void initState() {
    super.initState();
    _loadWidget();
  }

  Future<void> _loadWidget() async {
    AppLogging.widgets(
      '[WidgetDetailLoader] Loading widget: ${widget.widgetId}',
    );

    try {
      // First try marketplace API
      final service = ref.read(marketplaceServiceProvider);
      try {
        final marketplaceWidget = await service.getWidget(widget.widgetId);
        AppLogging.widgets(
          '[WidgetDetailLoader] Found in marketplace: ${marketplaceWidget.name}',
        );
        if (mounted) {
          setState(() {
            _marketplaceWidget = marketplaceWidget;
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        AppLogging.widgets(
          '[WidgetDetailLoader] Not in marketplace, trying shared_widgets: $e',
        );
      }

      // Fall back to shared_widgets collection
      final doc = await FirebaseFirestore.instance
          .collection('shared_widgets')
          .doc(widget.widgetId)
          .get();

      if (doc.exists) {
        AppLogging.widgets(
          '[WidgetDetailLoader] Found in shared_widgets collection',
        );
        if (mounted) {
          setState(() {
            _isSharedWidget = true;
            _isLoading = false;
          });
        }
        return;
      }

      // Widget not found anywhere
      AppLogging.widgets(
        '[WidgetDetailLoader] Widget not found in marketplace or shared_widgets',
      );
      if (mounted) {
        setState(() {
          _error = 'Widget not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogging.widgets('[WidgetDetailLoader] Error loading widget: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading widget: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Widget')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Widget')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // If it's a shared widget, redirect to import screen
    if (_isSharedWidget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = navigatorKey.currentState;
        if (navigator == null) return;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                WidgetImportScreen(firestoreId: widget.widgetId),
          ),
        );
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Widget')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If it's a marketplace widget, redirect to details screen
    if (_marketplaceWidget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = navigatorKey.currentState;
        if (navigator == null) return;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                WidgetDetailsScreen(marketplaceWidget: _marketplaceWidget!),
          ),
        );
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Widget')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Shouldn't reach here
    return Scaffold(
      appBar: AppBar(title: const Text('Loading Widget')),
      body: const Center(child: Text('Something went wrong')),
    );
  }
}

/// Loader widget that looks up a user by display name and navigates to their profile
class _ProfileDisplayNameLoader extends ConsumerWidget {
  final String displayName;

  const _ProfileDisplayNameLoader({required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppLogging.qr(
      'QR - 🔗 ProfileLoader: Building for displayName=$displayName',
    );
    final profileSyncService = ref.watch(profileCloudSyncServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('@$displayName')),
      body: FutureBuilder<String?>(
        future: profileSyncService.getUserIdByDisplayName(displayName),
        builder: (context, snapshot) {
          AppLogging.qr(
            '🔗 ProfileLoader: FutureBuilder state=${snapshot.connectionState}, '
            'hasError=${snapshot.hasError}, data=${snapshot.data}',
          );

          if (snapshot.connectionState == ConnectionState.waiting) {
            AppLogging.qr(
              'QR - 🔗 ProfileLoader: Waiting for userId lookup...',
            );
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            AppLogging.qr(
              '🔗 ProfileLoader: ERROR looking up user: ${snapshot.error}',
            );
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error looking up user: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final userId = snapshot.data;
          if (userId == null) {
            AppLogging.qr(
              '🔗 ProfileLoader: User "@$displayName" NOT FOUND in Firestore',
            );
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off, size: 48),
                  const SizedBox(height: 16),
                  Text('User "@$displayName" not found'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          // Navigate to profile screen with the looked up userId
          AppLogging.qr(
            '🔗 ProfileLoader: Found userId=$userId for displayName=$displayName, '
            'navigating to ProfileSocialScreen',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppLogging.qr('🔗 ProfileLoader: Executing pushReplacement');
            // Use global navigatorKey to avoid "Navigator.of() called with
            // a context that does not contain a Navigator" crash when
            // the widget is disposed before the callback runs
            final navigator = navigatorKey.currentState;
            if (navigator == null) {
              AppLogging.qr(
                '🔗 ProfileLoader: Navigator not available, skipping navigation',
              );
              return;
            }
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => ProfileSocialScreen(userId: userId),
              ),
            );
          });

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

/// Screen shown when a device-required route is accessed while disconnected
class _BlockedRouteScreen extends ConsumerWidget {
  final String routeName;
  final String message;

  const _BlockedRouteScreen({required this.routeName, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final deviceState = ref.watch(conn.deviceConnectionProvider);
    final isInvalidated = deviceState.isTerminalInvalidated;

    // Customize UI based on whether pairing was invalidated (factory reset, etc.)
    final iconData = isInvalidated
        ? Icons.error_outline
        : Icons.bluetooth_disabled;
    final iconColor = isInvalidated ? Colors.red : Colors.orange;
    final bgColor = isInvalidated
        ? Colors.red.withValues(alpha: 0.1)
        : Colors.orange.withValues(alpha: 0.1);
    final title = isInvalidated ? 'Device Reset' : 'Device Not Connected';
    final description = isInvalidated
        ? 'Your device was factory reset or replaced.\n\nGo to Settings → Bluetooth, forget the Meshtastic device, then scan again.'
        : message;

    return Scaffold(
      appBar: AppBar(title: const Text('Device Required')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 40, color: iconColor),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/scanner');
                  },
                  icon: const Icon(Icons.bluetooth_searching),
                  label: Text(
                    isInvalidated ? 'Scan for Devices' : 'Connect Device',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/main');
                    }
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App router handles initialization and navigation flow
/// NOTE: With deferred connection, MainShell is shown as soon as app is 'ready'.
/// Device connection happens asynchronously via DeviceConnectionNotifier.
class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  @override
  void initState() {
    super.initState();
    // Listen for app ready state and signal deep link manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppReady();
    });
  }

  void _checkAppReady() {
    final initState = ref.read(appInitProvider);
    if (initState == AppInitState.ready) {
      // App is ready, mark deep links ready (in next frame to ensure navigation is set up)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(deepLinkReadyProvider.notifier).setReady();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(appInitProvider);

    // Check readiness whenever state changes
    if (initState == AppInitState.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(deepLinkReadyProvider.notifier).setReady();
        }
      });
    }

    switch (initState) {
      case AppInitState.uninitialized:
      case AppInitState.initializing:
        return const _SplashScreen();
      case AppInitState.error:
        return const _ErrorScreen();
      case AppInitState.needsOnboarding:
        return const OnboardingScreen();
      case AppInitState.needsScanner:
        // First time user needs to pair a device before using mesh features
        return const ScannerScreen();
      case AppInitState.ready:
        // App is ready - route to protocol-specific shell
        // AppRootShell watches activeProtocolProvider and routes to:
        // - MainShell for Meshtastic/none
        // - MeshCoreShell for MeshCore
        return const AppRootShell();
    }
  }
}

/// Splash screen shown during app initialization
class _SplashScreen extends ConsumerStatefulWidget {
  const _SplashScreen();

  @override
  ConsumerState<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  // late IntroAnimationType _selectedAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Pick a random animation type for this session
    // _selectedAnimation =
    //     IntroAnimationType.values[DateTime.now().millisecondsSinceEpoch %
    //         IntroAnimationType.values.length];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final discoveredNodes = ref.watch(discoveredNodesQueueProvider);

    // Listen for new node discoveries during splash
    ref.listen<MeshNode?>(nodeDiscoveryNotifierProvider, (previous, next) {
      if (next != null) {
        ref.read(discoveredNodesQueueProvider.notifier).addNode(next);
      }
    });

    // Determine status info based on current state
    final statusInfo = _getStatusInfo(autoReconnectState, connectionState);

    return Scaffold(
      backgroundColor: context.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Apple TV style angled grid of discovered nodes - BEHIND EVERYTHING
          if (discoveredNodes.isNotEmpty)
            Positioned.fill(
              child: _AppleTVAngledGrid(
                entries: discoveredNodes.take(20).toList(),
                onDismiss: (id) {
                  ref
                      .read(discoveredNodesQueueProvider.notifier)
                      .removeNode(id);
                },
              ),
            ),
          // Random intro animation as background - replaces floating icons
          // Positioned.fill(child: _buildRandomBackground()),
          // Beautiful parallax floating icons background - full screen
          const Positioned.fill(child: ConnectingAnimationBackground()),
          // Content with SafeArea
          SafeArea(
            child: Center(
              child: ConnectingContent(
                statusInfo: statusInfo,
                showMeshNode: true, // Show mesh node on splash
                pulseAnimation: _pulseAnimation,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final appVersionAsync = ref.watch(appVersionProvider);
          final versionText = appVersionAsync.when(
            data: (version) => 'Socialmesh v$version',
            loading: () => 'Socialmesh',
            error: (_, _) => 'Socialmesh',
          );

          return Container(
            color: context.background,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    versionText,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '© 2026 Socialmesh. All rights reserved.',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget _buildRandomBackground() {
  //   return buildIntroAnimation(_selectedAnimation);
  // }

  ConnectionStatusInfo _getStatusInfo(
    AutoReconnectState autoState,
    AsyncValue<DeviceConnectionState> connState,
  ) {
    switch (autoState) {
      case AutoReconnectState.idle:
        return ConnectionStatusInfo.initializing(context.accentColor);
      case AutoReconnectState.manualConnecting:
        // User is manually connecting to a device
        return ConnectionStatusInfo.connecting(context.accentColor);
      case AutoReconnectState.scanning:
        return ConnectionStatusInfo.scanning(context.accentColor);
      case AutoReconnectState.connecting:
        final isConnected =
            connState.whenOrNull(
              data: (state) => state == DeviceConnectionState.connected,
            ) ??
            false;
        if (isConnected) {
          return ConnectionStatusInfo.configuring(context.accentColor);
        }
        return ConnectionStatusInfo.connecting(context.accentColor);
      case AutoReconnectState.success:
        return ConnectionStatusInfo.connected();
      case AutoReconnectState.failed:
        return ConnectionStatusInfo.failed();
    }
  }
}

/// Apple TV style full-screen angled grid of discovered nodes
/// Matches the Apple TV+ promotional image with diagonal scrolling grid
class _AppleTVAngledGrid extends StatefulWidget {
  final List<DiscoveredNodeEntry> entries;
  final void Function(String id) onDismiss;

  const _AppleTVAngledGrid({required this.entries, required this.onDismiss});

  @override
  State<_AppleTVAngledGrid> createState() => _AppleTVAngledGridState();
}

class _AppleTVAngledGridState extends State<_AppleTVAngledGrid>
    with TickerProviderStateMixin {
  late AnimationController _scrollController;
  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    // Continuous scrolling animation
    _scrollController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    // Initial fade in
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );

    _fadeInController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Card dimensions - portrait oriented like Apple TV movie posters
    const cardWidth = 140.0;
    const cardHeight = 180.0;
    const horizontalGap = 16.0;
    const verticalGap = 16.0;

    // More columns and rows to fill the rotated space
    const columns = 5;
    const rows = 6;

    return AnimatedBuilder(
      animation: Listenable.merge([_scrollController, _fadeInController]),
      builder: (context, child) {
        // Scroll offset for continuous motion
        final scrollOffset = _scrollController.value * 500;

        return Stack(
          children: [
            // The angled grid
            Opacity(
              opacity: _fadeInAnimation.value,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  // Just rotate Z for diagonal angle - NO perspective distortion
                  // This keeps cards rectangular, just tilted
                  ..rotateZ(-0.25)
                  // Position the grid - offset to fill screen nicely
                  ..leftTranslateByVector3(
                    Vector3(screenWidth * 0.1, -screenHeight * 0.15, 0),
                  ),
                child: SizedBox(
                  width: screenWidth * 3,
                  height: screenHeight * 3,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var row = 0; row < rows; row++)
                        for (var col = 0; col < columns; col++)
                          _buildCard(
                            row: row,
                            col: col,
                            columns: columns,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            horizontalGap: horizontalGap,
                            verticalGap: verticalGap,
                            scrollOffset: scrollOffset,
                          ),
                    ],
                  ),
                ),
              ),
            ),
            // Gradient fade on bottom-left corner (like Apple TV)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        context.background,
                        context.background.withValues(alpha: 0.95),
                        context.background.withValues(alpha: 0.7),
                        context.background.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.15, 0.3, 0.45, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Additional fade on bottom edge
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: screenHeight * 0.4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        context.background,
                        context.background.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Fade on left edge
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: screenWidth * 0.3,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        context.background,
                        context.background.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard({
    required int row,
    required int col,
    required int columns,
    required double cardWidth,
    required double cardHeight,
    required double horizontalGap,
    required double verticalGap,
    required double scrollOffset,
  }) {
    // Only show actual discovered nodes, no repeats
    final index = row * columns + col;
    final entry = index < widget.entries.length ? widget.entries[index] : null;

    // Stagger offset for alternating rows (brick pattern)
    final rowOffset = (row.isOdd) ? (cardWidth + horizontalGap) * 0.5 : 0.0;

    // Base position with scroll offset
    final x = col * (cardWidth + horizontalGap) + rowOffset + scrollOffset;
    final y = row * (cardHeight + verticalGap);

    // Wrap position for infinite scroll effect
    final totalWidth =
        columns * (cardWidth + horizontalGap) +
        (cardWidth + horizontalGap) * 0.5;
    final wrappedX = (x % totalWidth) - cardWidth;

    // Stagger animation delay
    final staggerDelay = (row * 80) + (col * 60);

    return _AppleTVGridCard(
      key: ValueKey('grid_${row}_$col'),
      entry: entry,
      x: wrappedX,
      y: y,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      staggerDelay: staggerDelay,
    );
  }
}

class _AppleTVGridCard extends StatefulWidget {
  final DiscoveredNodeEntry? entry;
  final double x;
  final double y;
  final double cardWidth;
  final double cardHeight;
  final int staggerDelay;

  const _AppleTVGridCard({
    super.key,
    required this.entry,
    required this.x,
    required this.y,
    required this.cardWidth,
    required this.cardHeight,
    required this.staggerDelay,
  });

  @override
  State<_AppleTVGridCard> createState() => _AppleTVGridCardState();
}

class _AppleTVGridCardState extends State<_AppleTVGridCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _slideOutController;
  late AnimationController _textAnimationController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Slide-out state
  bool _isSlidingOut = false;
  late bool _slideEast; // true = slide east, false = slide west
  final _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Randomly choose slide direction
    _slideEast = _random.nextBool();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideOutController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Slide animation - angled exit
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideOutController, curve: Curves.easeInCubic),
    );

    // Staggered start
    Future.delayed(Duration(milliseconds: widget.staggerDelay), () {
      if (mounted) {
        _controller.forward();
        // Start text animation slightly after card appears
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _textAnimationController.forward();
            _shimmerController.repeat();
          }
        });
      }
    });

    // Schedule slide-out after display period
    Future.delayed(Duration(milliseconds: widget.staggerDelay + 6000), () {
      _startSlideOut();
    });
  }

  void _startSlideOut() {
    if (!mounted || _isSlidingOut || widget.entry == null) return;

    setState(() {
      _isSlidingOut = true;
    });

    _slideOutController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _slideOutController.dispose();
    _textAnimationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.entry?.node;
    final shortName = node?.shortName ?? '';
    final displayName = node?.displayName ?? '';
    final nodeId =
        node?.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '';

    // Don't render empty placeholder cards - only render discovered nodes
    if (widget.entry == null) {
      return Positioned(
        left: widget.x,
        top: widget.y,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value * 0.15,
                child: child,
              ),
            );
          },
          child: Container(
            width: widget.cardWidth,
            height: widget.cardHeight,
            decoration: BoxDecoration(
              color: context.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
        ),
      );
    }

    // Build the card content widget
    final cardContent = _buildCardContent(
      context,
      shortName,
      displayName,
      nodeId,
    );

    return Positioned(
      left: widget.x,
      top: widget.y,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _slideOutController]),
        builder: (context, child) {
          // Calculate slide-out transformation
          final slideProgress = _slideAnimation.value;
          final screenWidth = MediaQuery.of(context).size.width;

          // Angled slide: move both horizontally and slightly vertically
          final slideDistance = screenWidth * 1.5; // Slide past screen edge
          final horizontalOffset = _slideEast
              ? slideDistance * slideProgress
              : -slideDistance * slideProgress;

          // Slight vertical component for angled effect (20% of horizontal)
          final verticalOffset = slideDistance * 0.2 * slideProgress;

          // Rotate slightly as it slides for more dynamic effect
          final rotationAngle = (_slideEast ? 0.15 : -0.15) * slideProgress;

          // Fade out as it slides
          final opacity = _fadeAnimation.value * (1.0 - slideProgress * 0.7);

          // Normal card with entry animations
          return Transform.translate(
            offset: Offset(horizontalOffset, verticalOffset),
            child: Transform.rotate(
              angle: rotationAngle,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(opacity: opacity * 0.95, child: child),
              ),
            ),
          );
        },
        child: cardContent,
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    String shortName,
    String displayName,
    String nodeId,
  ) {
    return Container(
      width: widget.cardWidth,
      height: widget.cardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.card,
            context.surface,
            context.card.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.accentColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(4, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Subtle gradient overlay for depth
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),
            ),
            // Animated shimmer overlay - subtle highlight sweep
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                return Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.transparent,
                            context.accentColor.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                          stops: [
                            (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                            _shimmerController.value,
                            (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Discovered badge with pulse animation
                  AnimatedBuilder(
                    animation: _textAnimationController,
                    builder: (context, child) {
                      final slideValue = Curves.easeOutBack.transform(
                        _textAnimationController.value.clamp(0.0, 1.0),
                      );
                      return Transform.translate(
                        offset: Offset(-20 * (1 - slideValue), 0),
                        child: Opacity(opacity: slideValue, child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.accentColor.withValues(alpha: 0.5),
                            context.accentColor.withValues(alpha: 0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_tethering,
                            color: context.accentColor,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DISCOVERED',
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Large short name with character-by-character reveal
                  if (shortName.isNotEmpty)
                    Center(
                      child: AnimatedBuilder(
                        animation: _textAnimationController,
                        builder: (context, _) {
                          return _buildAnimatedShortName(
                            context,
                            shortName,
                            _textAnimationController.value,
                          );
                        },
                      ),
                    ),
                  const Spacer(),
                  // Node name with typewriter effect
                  AnimatedBuilder(
                    animation: _textAnimationController,
                    builder: (context, _) {
                      final progress = Curves.easeOut.transform(
                        ((_textAnimationController.value - 0.3) / 0.5).clamp(
                          0.0,
                          1.0,
                        ),
                      );
                      final visibleChars = (displayName.length * progress)
                          .round();
                      final displayText = displayName.substring(
                        0,
                        visibleChars,
                      );
                      return Text(
                        displayText,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  // Node ID with glitch/scan effect
                  AnimatedBuilder(
                    animation: _textAnimationController,
                    builder: (context, _) {
                      return _buildGlitchNodeId(
                        context,
                        nodeId,
                        _textAnimationController.value,
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

  /// Build animated short name with per-character effects
  Widget _buildAnimatedShortName(
    BuildContext context,
    String shortName,
    double progress,
  ) {
    final chars = shortName.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(chars.length, (index) {
        // Stagger each character
        final charProgress = ((progress - (index * 0.1)) / 0.6).clamp(0.0, 1.0);
        final scale = Curves.elasticOut.transform(charProgress);
        final opacity = Curves.easeOut.transform(charProgress);

        // Random glitch offset that settles
        final glitchFactor = (1 - charProgress) * (1 - charProgress);
        final glitchX = ((_random.nextDouble() - 0.5) * 10 * glitchFactor);
        final glitchY = ((_random.nextDouble() - 0.5) * 10 * glitchFactor);

        return Transform.translate(
          offset: Offset(glitchX, glitchY),
          child: Transform.scale(
            scale: 0.5 + (scale * 0.5),
            child: Opacity(
              opacity: opacity,
              child: Text(
                chars[index],
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: context.accentColor.withValues(
                        alpha: 0.5 * opacity,
                      ),
                      blurRadius: 8 * (1 - charProgress) + 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Build glitchy node ID with scanning effect
  Widget _buildGlitchNodeId(
    BuildContext context,
    String nodeId,
    double progress,
  ) {
    // Delayed start for node ID
    final adjustedProgress = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);

    if (adjustedProgress <= 0) {
      return const SizedBox(height: 12);
    }

    final fullId = '!$nodeId';
    final scanPosition = (adjustedProgress * 1.5).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(fullId.length, (index) {
        final charPosition = index / fullId.length;
        final isRevealed = charPosition < scanPosition;
        final isAtScanLine = (charPosition - scanPosition).abs() < 0.15;

        // Glitch characters near scan line
        String displayChar = fullId[index];
        if (isAtScanLine && adjustedProgress < 0.95) {
          final glitchChars = '0123456789abcdef!@#%&';
          displayChar = glitchChars[_random.nextInt(glitchChars.length)];
        }

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 50),
          opacity: isRevealed ? 1.0 : 0.0,
          child: Text(
            isRevealed
                ? (isAtScanLine && adjustedProgress < 0.95
                      ? displayChar
                      : fullId[index])
                : ' ',
            style: TextStyle(
              color: isAtScanLine ? context.accentColor : context.textTertiary,
              fontSize: 10,
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w500,
              shadows: isAtScanLine
                  ? [
                      Shadow(
                        color: context.accentColor.withValues(alpha: 0.8),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// Animated node card for splash screen (legacy - kept for reference)
class _SplashNodeCard extends StatefulWidget {
  final DiscoveredNodeEntry entry;
  final VoidCallback onDismiss;

  const _SplashNodeCard({required this.entry, required this.onDismiss});

  @override
  State<_SplashNodeCard> createState() => _SplashNodeCardState();
}

class _SplashNodeCardState extends State<_SplashNodeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Start fade out after delay
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.entry.node;
    final shortName = node.shortName ?? '';
    final displayName = node.displayName;
    final nodeId = node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          ),
        );
      },
      child: GradientBorderContainer(
        borderRadius: 12,
        borderWidth: 2,
        accentOpacity: 0.3,
        backgroundColor: context.card.withValues(alpha: 0.95),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Node icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: shortName.isNotEmpty
                    ? Text(
                        shortName.substring(0, shortName.length.clamp(0, 2)),
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(Icons.person, color: context.accentColor, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            // Node info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '!$nodeId',
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 11,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            // Discovered badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar, size: 12, color: context.accentColor),
                  SizedBox(width: 4),
                  Text(
                    'Found',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
}

/// Error screen shown when initialization fails
class _ErrorScreen extends ConsumerWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to initialize the app. Please try again.',
                style: context.titleSmallStyle?.copyWith(
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(appInitProvider.notifier).initialize();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigator observer that dismisses keyboard on route changes.
/// Prevents keyboard from persisting when navigating between screens.
class _KeyboardDismissObserver extends NavigatorObserver {
  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissKeyboard();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
  }
}

/// A delegating analytics observer that forwards calls to the real
/// Firebase Analytics observer when available.
///
/// This allows us to have a stable navigator observer list that doesn't
/// change when Firebase initializes, preventing navigator recreation
/// which would destroy current routes.
class _DelegatingAnalyticsObserver extends NavigatorObserver {
  final WidgetRef _ref;

  _DelegatingAnalyticsObserver(this._ref);

  FirebaseAnalyticsObserver? get _delegate {
    return _ref.read(analyticsObserverProvider);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _delegate?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didRemove(route, previousRoute);
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    _delegate?.didStartUserGesture(route, previousRoute);
  }

  @override
  void didStopUserGesture() {
    _delegate?.didStopUserGesture();
  }
}
