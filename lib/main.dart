import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:socialmesh/features/scanner/widgets/connecting_animation.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/transport.dart';
import 'core/logging.dart';
import 'core/widgets/connecting_content.dart';
import 'providers/splash_mesh_provider.dart';
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
import 'features/automations/automation_providers.dart';
import 'models/mesh_models.dart';
import 'services/app_intents/app_intents_service.dart';
import 'services/deep_link_service.dart';
import 'services/profile/profile_cloud_sync_service.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/messaging/messaging_screen.dart';
import 'features/channels/channels_screen.dart';
import 'features/nodes/nodes_screen.dart';
import 'features/nodes/node_qr_scanner_screen.dart';
import 'features/map/map_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/qr_import_screen.dart';
import 'features/device/device_config_screen.dart';
import 'features/device/region_selection_screen.dart';
import 'features/navigation/main_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/screens/mesh_brain_emotion_test_screen.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/presence/presence_screen.dart';
import 'features/discovery/node_discovery_overlay.dart';
import 'features/routes/route_detail_screen.dart';
import 'features/globe/globe_screen.dart';
import 'features/reachability/mesh_reachability_screen.dart';
// import 'features/intro/intro_screen.dart';
import 'models/route.dart' as route_model;

/// Global completer to signal when Firebase is ready
/// Used by providers that need Firestore
final Completer<bool> firebaseReadyCompleter = Completer<bool>();

/// Future that completes when Firebase is initialized (or fails)
Future<bool> get firebaseReady => firebaseReadyCompleter.future;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  FlutterBluePlus.setLogLevel(LogLevel.none);

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

    // Configure Crashlytics only if Firebase initialized successfully
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Initialize Firebase Analytics
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    // Initialize profile cloud sync service (requires Firebase)
    initProfileCloudSyncService();

    // Set up async error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Signal that Firebase is ready
    AppLogging.debug('🔥 Firebase initialized successfully');
    firebaseReadyCompleter.complete(true);
  } catch (e) {
    // Firebase failed to initialize (no internet, timeout, etc.)
    // App continues working fully offline - this is expected behavior
    AppLogging.debug('Firebase unavailable: $e - app running in offline mode');
    firebaseReadyCompleter.complete(false);
  }
}

class SocialmeshApp extends ConsumerStatefulWidget {
  const SocialmeshApp({super.key});

  @override
  ConsumerState<SocialmeshApp> createState() => _SocialmeshAppState();
}

class _SocialmeshAppState extends ConsumerState<SocialmeshApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appInitProvider.notifier).initialize();
      // Load accent color from settings
      _loadAccentColor();
      // Setup App Intents for iOS Shortcuts integration
      ref.read(appIntentsServiceProvider).setup();
      // Initialize RevenueCat for purchases
      _initializePurchases();
      // Initialize deep link handling
      _initializeDeepLinks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  /// Handle app returning to foreground
  /// This cleans up stale BLE state and triggers reconnect if needed
  Future<void> _handleAppResumed() async {
    AppLogging.liveActivity('App resumed - checking BLE state');

    final transport = ref.read(transportProvider);
    final autoReconnectState = ref.read(autoReconnectStateProvider);

    // If we think we're connected, verify the connection is still valid
    if (transport.state == DeviceConnectionState.connected) {
      AppLogging.liveActivity('App resumed - transport reports connected');
      return;
    }

    // If already trying to reconnect, don't interfere
    if (autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting) {
      AppLogging.liveActivity('App resumed - reconnect already in progress');
      return;
    }

    // If disconnected and we have a saved device, try to reconnect
    // This handles the case where user turned device back on after auto-reconnect failed
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      final lastDeviceId = settings.lastDeviceId;

      if (lastDeviceId != null && settings.autoReconnect) {
        AppLogging.liveActivity(
          'App resumed - disconnected, triggering reconnect scan',
        );

        // Reset to idle first to allow reconnect to proceed
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);

        // Trigger reconnect by simulating a disconnect event
        // The autoReconnectManager will pick this up
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.scanning);

        // Start the reconnect process
        _performReconnectOnResume(lastDeviceId);
      } else {
        AppLogging.debug(
          '📱 App resumed - transport reports disconnected (no saved device or auto-reconnect disabled)',
        );
      }
    } catch (e) {
      AppLogging.liveActivity('App resumed - error checking settings: $e');
    }
  }

  /// Perform a single reconnect attempt when app resumes
  Future<void> _performReconnectOnResume(String deviceId) async {
    AppLogging.liveActivity(
      'Attempting reconnect on resume for device: $deviceId',
    );

    try {
      final transport = ref.read(transportProvider);

      // Quick scan to find the device
      final scanStream = transport.scan(timeout: const Duration(seconds: 8));
      DeviceInfo? foundDevice;

      await for (final device in scanStream) {
        if (device.id == deviceId) {
          foundDevice = device;
          break;
        }
      }

      if (foundDevice != null) {
        AppLogging.liveActivity('Device found on resume, connecting...');
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.connecting);

        await transport.connect(foundDevice);

        if (transport.state == DeviceConnectionState.connected) {
          // Clear all previous device data before starting new connection
          await clearDeviceDataBeforeConnect(ref);

          final protocol = ref.read(protocolServiceProvider);

          // Set device info for hardware model inference
          protocol.setDeviceName(foundDevice.name);
          protocol.setBleModelNumber(transport.bleModelNumber);
          protocol.setBleManufacturerName(transport.bleManufacturerName);

          await protocol.start();

          ref.read(connectedDeviceProvider.notifier).setState(foundDevice);
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.success);

          // Start location updates
          final locationService = ref.read(locationServiceProvider);
          await locationService.startLocationUpdates();

          AppLogging.liveActivity('✅ Reconnected successfully on resume!');

          await Future.delayed(const Duration(milliseconds: 500));
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.idle);
        } else {
          throw Exception('Connection failed');
        }
      } else {
        AppLogging.liveActivity('Device not found on resume scan');
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
      }
    } catch (e) {
      AppLogging.liveActivity('Reconnect on resume failed: $e');
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
    }
  }

  Future<void> _initializePurchases() async {
    try {
      await ref.read(subscriptionServiceProvider.future);
      AppLogging.debug('💰 RevenueCat initialized');

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
      final deepLinkService = ref.read(deepLinkServiceProvider);
      await deepLinkService.initialize();

      // Listen for deep links and handle them
      deepLinkService.linkStream.listen((link) {
        _handleDeepLink(link);
      });

      AppLogging.debug('🔗 Deep link service initialized');
    } catch (e) {
      AppLogging.debug('🔗 Deep link init failed: $e');
    }
  }

  Future<void> _handleDeepLink(DeepLinkData link) async {
    AppLogging.debug('🔗 Handling deep link: ${link.runtimeType}');

    switch (link) {
      case NodeDeepLink():
        await _handleNodeDeepLink(link);
      case ChannelDeepLink():
        _handleChannelDeepLink(link);
      case ProfileDeepLink():
        _handleProfileDeepLink(link);
      case WidgetDeepLink():
        _handleWidgetDeepLink(link);
      case LocationDeepLink():
        _handleLocationDeepLink(link);
    }
  }

  Future<void> _handleNodeDeepLink(NodeDeepLink link) async {
    final deepLinkService = ref.read(deepLinkServiceProvider);
    final success = await deepLinkService.handleNodeLink(link);

    if (success && mounted) {
      // Navigate to nodes screen and show success
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }

      // Show notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Node "${link.longName ?? 'Unknown'}" added',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: context.accentColor,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).pushNamed('/nodes');
            },
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add node from link'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleChannelDeepLink(ChannelDeepLink link) {
    // Navigate to channel QR import screen with the data
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamed('/qr-import', arguments: {'base64Data': link.base64Data});
    }
  }

  void _handleProfileDeepLink(ProfileDeepLink link) {
    AppLogging.debug('🔗 Profile deep link: ${link.profileId}');
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamed('/profile', arguments: {'userId': link.profileId});
    }
  }

  void _handleWidgetDeepLink(WidgetDeepLink link) {
    AppLogging.debug('🔗 Widget deep link: ${link.widgetId}');
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamed('/widget-detail', arguments: {'widgetId': link.widgetId});
    }
  }

  void _handleLocationDeepLink(LocationDeepLink link) {
    // Navigate to map screen centered on location
    if (mounted) {
      Navigator.of(context).pushNamed(
        '/map',
        arguments: {
          'latitude': link.latitude,
          'longitude': link.longitude,
          'label': link.label,
        },
      );
    }
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
        AppLogging.debug('🎨 User signed in, invalidating profile provider');
        // Invalidate profile to trigger fresh cloud sync
        ref.invalidate(userProfileProvider);

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
        if (prefs?.themeModeIndex != null) {
          final themeMode = ThemeMode.values[prefs!.themeModeIndex!];
          ref.read(themeModeProvider.notifier).setThemeMode(themeMode);
          await settings.setThemeMode(prefs.themeModeIndex!);
          AppLogging.debug(
            '🎨 Updated theme mode from cloud: ${themeMode.name}',
          );
        }

        // Load remaining cloud preferences
        await _loadRemainingCloudPreferences(settings, prefs);
      }
    } catch (e) {
      AppLogging.debug('☁️ Cloud sync failed, using local settings: $e');
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
        AppLogging.debug(
          '⚡ Loaded ${automationRepo.automations.length} automations from cloud',
        );
      } catch (e) {
        AppLogging.debug('Failed to parse automations: $e');
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
    ref.watch(liveActivityManagerProvider);

    // Watch telemetry logger to automatically save telemetry data
    ref.watch(telemetryLoggerProvider);

    // Watch accent color for dynamic theme (with default fallback)
    final accentColorAsync = ref.watch(accentColorProvider);
    final accentColor = accentColorAsync.asData?.value ?? AccentColors.magenta;

    // Watch theme mode for dark/light switching
    final themeMode = ref.watch(themeModeProvider);

    // Analytics observer (nullable until Firebase initializes)
    final analyticsObserver = ref.watch(analyticsObserverProvider);

    return MaterialApp(
      title: 'Socialmesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(accentColor),
      darkTheme: AppTheme.darkTheme(accentColor),
      themeMode: themeMode,
      navigatorObservers: [if (analyticsObserver != null) analyticsObserver],
      home: const _AppRouter(),
      routes: {
        '/scanner': (context) => const ScannerScreen(),
        '/messages': (context) => const MessagingScreen(),
        '/channels': (context) => const ChannelsScreen(),
        '/nodes': (context) => const NodesScreen(),
        '/node-qr-scanner': (context) => const NodeQrScannerScreen(),
        '/map': (context) => const MapScreen(),
        '/globe': (context) => const GlobeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/qr-import': (context) => const QrImportScreen(),
        '/channel-qr-scanner': (context) => const QrImportScreen(),
        '/device-config': (context) => const DeviceConfigScreen(),
        '/region-setup': (context) =>
            const RegionSelectionScreen(isInitialSetup: true),
        '/main': (context) => const MainShell(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/emotion-test': (context) => const MeshBrainEmotionTestScreen(),
        '/timeline': (context) => const TimelineScreen(),
        '/presence': (context) => const PresenceScreen(),
        '/reachability': (context) => const MeshReachabilityScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle routes that need arguments
        if (settings.name == '/route-detail') {
          final route = settings.arguments as route_model.Route;
          return MaterialPageRoute(
            builder: (context) => RouteDetailScreen(route: route),
          );
        }
        return null;
      },
    );
  }
}

/// App router handles initialization and navigation flow
class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitProvider);

    switch (initState) {
      case AppInitState.uninitialized:
      case AppInitState.initializing:
        return const _SplashScreen();
      case AppInitState.error:
        return const _ErrorScreen();
      case AppInitState.needsOnboarding:
        return const OnboardingScreen();
      case AppInitState.needsScanner:
        return const ScannerScreen();
      case AppInitState.needsRegionSetup:
        return const RegionSelectionScreen(isInitialSetup: true);
      case AppInitState.initialized:
        return const MainShell();
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
          // Random intro animation as background - replaces floating icons
          // Positioned.fill(child: _buildRandomBackground()),
          // Beautiful parallax floating icons background - full screen
          const Positioned.fill(child: ConnectingAnimationBackground()),
          // Content with SafeArea
          SafeArea(
            child: Stack(
              children: [
                // Main centered content - unaffected by node cards
                Center(
                  child: ConnectingContent(
                    statusInfo: statusInfo,
                    showMeshNode: true, // Show mesh node on splash
                    pulseAnimation: _pulseAnimation,
                  ),
                ),
                // Node discovery cards - absolutely positioned at bottom
                if (discoveredNodes.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: discoveredNodes.take(4).map((entry) {
                        return _SplashNodeCard(
                          key: ValueKey(entry.id),
                          entry: entry,
                          onDismiss: () {
                            ref
                                .read(discoveredNodesQueueProvider.notifier)
                                .removeNode(entry.id);
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

/// Animated node card for splash screen
class _SplashNodeCard extends StatefulWidget {
  final DiscoveredNodeEntry entry;
  final VoidCallback onDismiss;

  const _SplashNodeCard({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

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
    final longName = node.longName ?? '';
    final shortName = node.shortName ?? '';
    final displayName = longName.isNotEmpty
        ? longName
        : shortName.isNotEmpty
        ? shortName
        : 'Unknown Node';
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: context.accentColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                    style: const TextStyle(
                      color: Colors.white,
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
                      fontFamily: 'monospace',
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to initialize the app. Please try again.',
                style: TextStyle(fontSize: 16, color: context.textSecondary),
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
