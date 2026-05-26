// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// lint-allow: scaffold — transient loader widgets, visible for milliseconds only
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show Stripe;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:socialmesh/services/transport/background_ble_service.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_providers.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:socialmesh/features/scanner/widgets/connecting_animation.dart';
import 'firebase_options.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/widgets/glass_scaffold.dart';
import 'core/widgets/loading_indicator.dart';
import 'core/transport.dart';
import 'core/platform/platform_capabilities.dart';
import 'core/platform/platform_capabilities_provider.dart';
import 'core/platform/sqflite_init.dart';
import 'services/config/remote_flag_overrides_service.dart';
import 'services/protocol/protocol_service.dart' show OperationalReadiness;

import 'services/transport/background_message_processor.dart';
import 'core/accessibility_theme_adapter.dart';
import 'l10n/app_localizations.dart';
import 'core/l10n/l10n_extension.dart';
import 'core/logging.dart';
import 'core/logging/os_log_bridge.dart';
import 'core/safety/error_handler.dart';
import 'core/safety/lifecycle_mixin.dart';
import 'features/debug/app_log_screen.dart' as app_log;
import 'core/widgets/connecting_content.dart';
import 'core/widgets/gradient_border_container.dart';
import 'core/routing/route_guard.dart';
import 'providers/splash_mesh_provider.dart';
import 'providers/connection_providers.dart' as conn;
import 'providers/lifecycle_command_provider.dart';
import 'providers/locale_provider.dart';
import 'models/canned_response.dart';
import 'models/tapback.dart';
import 'models/user_profile.dart';
import 'providers/app_providers.dart';
import 'providers/meshcore_lifecycle_provider.dart';
import 'providers/auth_providers.dart';
import 'providers/profile_providers.dart';
import 'providers/telemetry_providers.dart';
import 'providers/subscription_providers.dart';
import 'providers/cloud_sync_entitlement_providers.dart';
import 'providers/analytics_providers.dart';
import 'providers/signal_providers.dart';
import 'providers/app_lifecycle_provider.dart';
import 'providers/connectivity_providers.dart';
import 'providers/presence_providers.dart';
import 'providers/glyph_provider.dart';
import 'providers/accessibility_providers.dart';
import 'features/automations/automation_providers.dart';
import 'features/automations/automation_import_screen.dart';
import 'features/external_purchase/confirming_unlock_overlay.dart';
import 'features/license_org/invite_accept_screen.dart';
import 'features/widget_builder/widget_import_screen.dart';
import 'models/mesh_models.dart';
import 'models/social.dart';
import 'services/app_intents/app_intents_service.dart';
import 'services/deep_link_manager.dart';
import 'utils/snackbar.dart';
import 'utils/text_sanitizer.dart';
import 'services/profile/profile_cloud_sync_service.dart';
import 'services/privacy_consent_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/push_notification_service.dart';
import 'services/content_moderation/profanity_checker.dart';
import 'services/firmware/device_hardware_catalog.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/messaging/messaging_screen.dart';
import 'features/channels/channels_screen.dart';
import 'features/channels/channel_form_screen.dart';
import 'features/nodes/nodes_screen.dart';
import 'features/qr_scanner/universal_qr_scanner_screen.dart';
import 'features/map/map_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/account_subscriptions_screen.dart';
import 'features/device/device_config_screen.dart';
import 'features/settings/device_management_screen.dart';
import 'features/navigation/main_shell.dart';
import 'features/navigation/app_root_shell.dart';
import 'features/legal/legal_acceptance_screen.dart';
import 'features/legal/eligibility_gate_screen.dart';
import 'core/widgets/legal_document_sheet.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/screens/mesh_brain_emotion_test_screen.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/presence/presence_screen.dart';
import 'features/discovery/node_discovery_overlay.dart';
import 'features/routes/route_detail_screen.dart';
import 'features/globe/globe_screen.dart';
import 'features/reachability/mesh_reachability_screen.dart';
import 'features/feedback/my_bug_reports_screen.dart';
import 'features/admin/bug_reports/admin_bug_reports_screen.dart';
import 'features/mesh_canvas/screens/mesh_canvas_overview_screen.dart';
import 'features/sip/sip_hub_screen.dart';
import 'features/sip/sip_dm_screen.dart';
import 'providers/sip_providers.dart';
import 'services/protocol/sip/sip_dm.dart';
import 'features/social/screens/post_detail_screen.dart';
import 'features/social/screens/profile_social_screen.dart';
import 'features/signals/screens/signal_detail_screen.dart';
import 'features/widget_builder/marketplace/widget_marketplace_screen.dart';
import 'features/widget_builder/marketplace/widget_marketplace_service.dart';
import 'features/widget_builder/marketplace/marketplace_providers.dart';
import 'services/user_presence_service.dart';
import 'services/accessibility_preferences_service.dart';
import 'services/channel_crypto_service.dart';
import 'services/channel_invite_service.dart';
import 'features/aether/screens/aether_flight_detail_screen.dart';
import 'features/aether/providers/aether_providers.dart';
import 'features/aether/models/aether_flight.dart';
import 'features/onboarding/app_shell_provider.dart';
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

  // Resolve the host platform capability bundle once at boot. Every
  // downstream init that today assumed mobile is gated on this; the
  // resolved value is also pushed into the ProviderScope override at
  // runApp so Riverpod consumers read the same answer.
  final platformCapabilities = PlatformCapabilities.detect();
  AppLogging.platform('boot: $platformCapabilities');

  // Desktop persistence: sqflite needs the FFI backend before any
  // openDatabase() call. Mobile platforms keep the default sqflite
  // backend; web resolves the conditional-import stub (no-op).
  if (platformCapabilities.supportsLocalDatabase &&
      platformCapabilities.platformFamily == PlatformFamily.desktop) {
    await initDesktopSqflite();
    AppLogging.platform('boot: sqflite ffi backend activated for desktop');
  }

  // Tee debugPrint into iOS os_log so Dart logs are visible via MCP log
  // capture. Debug + iOS only - no-op everywhere else.
  OsLogBridge.setup();

  // Initialize centralized error handler FIRST - catches errors during startup
  AppErrorHandler.initialize();

  // Load environment variables. Skipped on web because the .env asset
  // contains values that crash flutter_dotenv's web parser (Uncaught
  // SyntaxError during the fetched-asset parse step). Web is dashboard /
  // read-only this pass and does not need runtime env values; the
  // logging channels that read env vars all default-on when dotenv is
  // unavailable (`_safeGetEnv` returns null and the channel uses its
  // default).
  if (platformCapabilities.platformFamily != PlatformFamily.web) {
    await dotenv.load(fileName: '.env');
  } else {
    AppLogging.platform('boot: skipping dotenv.load on web');
  }

  // Bridge category-based console logging into the in-app log viewer.
  // Categories that call _appLogSink (currently mqttProxy) will appear
  // in the AppLogScreen for support visibility.
  AppLogging.setAppLogSink((level, source, message) {
    const levels = [
      app_log.LogLevel.debug,
      app_log.LogLevel.info,
      app_log.LogLevel.warning,
      app_log.LogLevel.error,
    ];
    app_log.AppLogger().log(levels[level.clamp(0, 3)], source, message);
  });

  if (platformCapabilities.supportsBle) {
    FlutterBluePlus.setLogLevel(LogLevel.none);
    // Initialize Android foreground service configuration for background BLE.
    // Must be called before any FlutterForegroundTask.start() call.
    BackgroundBleService.instance.init();
  } else {
    AppLogging.platform(
      'boot: BLE unsupported on this platform - skipping flutter_blue_plus '
      'and BackgroundBleService init',
    );
  }

  // Initialize profanity checker (load banned words from assets)
  await ProfanityChecker.instance.load();

  // Load the Meshtastic hardware catalog (architecture mapping for firmware
  // updates) from the bundled asset before any UI can query it.
  await DeviceHardwareCatalog.instance.load();

  // Initialize accessibility preferences before UI renders
  // This ensures text scaling and density are applied from first frame
  await AccessibilityPreferencesService().initialize();

  // Stripe SDK init for the external (off-store) Payment Sheet path.
  // The publishable key is mode-aware on the server (the createCheckout
  // response carries the active key) but Stripe.publishableKey must be
  // set before the Payment Sheet can be presented. The test key gets us
  // a working init; the server re-sets the key on each Stripe checkout
  // so live builds use the live key without an app upgrade.
  if (AppFeatureFlags.isStripePurchasesEnabled) {
    try {
      final publishableKey =
          dotenv.env['STRIPE_TEST_PUBLISHABLE_KEY'] ??
          dotenv.env['STRIPE_LIVE_PUBLISHABLE_KEY'] ??
          '';
      if (publishableKey.isNotEmpty) {
        Stripe.publishableKey = publishableKey;
        final merchantId = dotenv.env['STRIPE_APPLE_MERCHANT_ID']?.trim() ?? '';
        if (merchantId.isNotEmpty) {
          Stripe.merchantIdentifier = merchantId;
        }
        // Required for redirect-based methods (Stripe Link's "Back to
        // <app>" button, 3DS auth, etc.) on Android. The SDK passes
        // this scheme as the redirect target; when the user finishes
        // the external flow, the URL hits Android's intent router,
        // app_links surfaces it to Flutter, and our DeepLinkManager
        // forwards it to Stripe.instance.handleURLCallback so the
        // SDK can complete the pending Payment Sheet flow. See
        // DeepLinkManager._maybeHandleStripeRedirect.
        Stripe.urlScheme = 'socialmesh';
        await Stripe.instance.applySettings();
        AppLogging.purchase(
          'boot: Stripe SDK initialised '
          '(merchantId=${merchantId.isEmpty ? '<none>' : merchantId}, '
          'urlScheme=socialmesh)',
        );
      } else {
        AppLogging.purchase(
          'boot: STRIPE_PURCHASES_ENABLED on but no publishable key in .env — Payment Sheet will not work',
        );
      }
    } catch (e) {
      AppLogging.purchase('boot: Stripe init failed (non-fatal): $e');
    }
  }

  // Initialize Firebase core BEFORE runApp — per Google's official docs.
  // This is a local operation (reads google-services.json), no network needed.
  // Auth is available immediately once this completes.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogging.app('🔥 Firebase core initialized');

    // Remote env-flag overrides: apply cached overrides immediately,
    // then subscribe to Firestore in the background. Never blocks
    // startup on the network.
    unawaited(RemoteFlagOverridesService.instance.initialise());

    // Gate telemetry — disabled by default until consent is verified in
    // _initializeFirebaseServices(). This ensures zero collection between
    // Firebase.initializeApp() and the consent check.
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } catch (_) {
      // Best-effort — if this fails, _initializeFirebaseServices will retry.
    }

    // iOS simulator cannot receive silent APN pushes, so Firebase Phone
    // Auth falls back to reCAPTCHA via SFSafariViewController — which
    // cascades our Flutter bottom sheet out of the visible view when it
    // dismisses (UIKit unwinds the modal stack). Firebase's
    // appVerificationDisabledForTesting skips both silent APN and
    // reCAPTCHA when the phone is whitelisted in Firebase Console as a
    // test number. Release builds strip this block entirely because
    // kDebugMode is false — so shipped App Store binaries always run
    // real APN + real reCAPTCHA + real SMS.
    if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
        AppLogging.mfa(
          '⚠️ Debug iOS: appVerificationDisabledForTesting=true — '
          'reCAPTCHA skipped; requires Firebase Console test phone '
          'whitelist to sign in',
        );
      } catch (e) {
        AppLogging.mfa('appVerificationDisabledForTesting failed: $e');
      }
    }

    // Ensure every install has a Firebase identity. Best-effort with a
    // short timeout so a slow or offline network never blocks startup
    // beyond a few seconds. See [_ensureAnonymousAuth] for the rationale
    // (closes a class of "unauthenticated" failures across reportBug,
    // unlock-code redemption, and any future authenticated callable).
    await _ensureAnonymousAuth().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        AppLogging.auth(
          '🔥 Anonymous sign-in timed out — continuing offline; will retry on next foreground',
        );
      },
    );

    firebaseReadyCompleter.complete(true);
  } catch (e) {
    AppLogging.app('Firebase unavailable: $e - app running in offline mode');
    firebaseReadyCompleter.complete(false);
  }

  // Ancillary services (Firestore settings, Analytics, Push, etc.)
  // run in background — they must never block app startup or sign-in.
  // The catchError guard prevents any escaping async error from surfacing
  // as a PlatformDispatcher error (the "_handlePlatformError" spike).
  unawaited(
    _initializeFirebaseServices().catchError((Object e, StackTrace st) {
      AppLogging.app('⚠️ _initializeFirebaseServices failed (non-fatal): $e');
    }),
  );

  runApp(
    ProviderScope(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(platformCapabilities),
      ],
      child: const SocialMeshApp(),
    ),
  );
}

/// Ensure the user has a Firebase auth identity.
///
/// If no user is signed in (real or anonymous), kicks off
/// `signInAnonymously`. Best-effort: logs and returns on any failure so
/// startup is never blocked. The next foreground-to-background-to-
/// foreground cycle will re-run this through normal app lifecycle if
/// it failed (no explicit retry plumbing — keeping it simple).
///
/// Why we need it:
///   - Several Cloud Function callables (`reportBug`, future tightened
///     versions of admin callables) require `request.auth` to be
///     populated. Without a Firebase identity those calls fail with
///     `unauthenticated`.
///   - External-purchase entitlements are now device-scoped (install
///     ID), but we still want a Firebase uid for non-purchase
///     authenticated paths.
///   - When the user later signs in with real credentials, use
///     `linkWithCredential` (not `signInWith…`) to upgrade the anon
///     account in place. That preserves the uid and any Firestore
///     data keyed off it.
///
/// Production rollout note:
///   Once the app version that ships this helper is broadly deployed,
///   the backend can be tightened to require `request.auth` on
///   `reportBug` (currently it accepts unauthenticated calls — see
///   [backend/functions/src/index.ts] reportBug, line ~2510). Don't
///   tighten the backend before this client change has rolled out, or
///   older clients break.
Future<void> _ensureAnonymousAuth() async {
  try {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      AppLogging.auth(
        '🔥 Firebase auth already present: uid=${current.uid} '
        'anonymous=${current.isAnonymous}',
      );
      return;
    }
    AppLogging.auth('🔥 No Firebase user — signing in anonymously');
    final cred = await FirebaseAuth.instance.signInAnonymously();
    AppLogging.auth('🔥 Anonymous sign-in succeeded: uid=${cred.user?.uid}');
  } catch (e) {
    AppLogging.auth(
      '🔥 Anonymous sign-in failed (non-fatal, app continues): $e',
    );
  }
}

/// SharedPreferences key tracking Firestore initialization success.
/// Set to `false` before the first Firestore access, set to `true` after
/// success. On next startup, if still `false`, we know the previous
/// init crashed (typically LevelDB cache corruption) and clear the
/// persistence cache before retrying.
const String _kFirestoreInitOk = 'firestore_init_ok';

/// Detect whether Firestore crashed during the previous app session
/// and proactively repair the corrupted LevelDB persistence cache
/// before any Firestore operation triggers [FirestoreClient::Initialize].
///
/// `clearPersistence()` deletes the cache directory without initializing
/// the native client, so it is safe to call even when the cache is corrupt.
/// If that also fails, falls back to manual directory deletion.
Future<void> _repairFirestoreCacheIfNeeded() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final previousInitOk = prefs.getBool(_kFirestoreInitOk) ?? true;
    if (previousInitOk) return;

    AppLogging.storage(
      'Firestore init failed last session — clearing persistence cache',
    );

    try {
      // clearPersistence() works before the native client is started,
      // so it won't trigger the same crash.
      await FirebaseFirestore.instance.clearPersistence();
      AppLogging.storage('Firestore persistence cleared via SDK');
    } catch (e) {
      AppLogging.storage('clearPersistence() failed ($e) — deleting manually');
      await _deleteFirestoreCacheDirectory();
    }

    // Reset the flag so we don't clear on every startup.
    await prefs.setBool(_kFirestoreInitOk, true);
  } catch (e) {
    AppLogging.storage('Firestore cache repair check failed: $e');
  }
}

/// Fallback: manually delete the Firestore LevelDB directory when
/// `clearPersistence()` itself throws (deeply corrupted state).
Future<void> _deleteFirestoreCacheDirectory() async {
  try {
    final appSupportDir = await getApplicationSupportDirectory();

    // Firestore uses different cache directory names across SDK versions.
    // The crash path shows `firestore/__FIRAPP_DEFAULT/social-mesh-app/main/LOCK`
    // so we must delete both the legacy and current paths.
    final candidatePaths = [
      '${appSupportDir.path}/firestore',
      '${appSupportDir.path}/google-cloud-firestore',
    ];

    var deleted = false;
    for (final path in candidatePaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        AppLogging.storage('Deleted Firestore cache directory: $path');
        deleted = true;
      }
    }

    if (!deleted) {
      AppLogging.storage('No Firestore cache directories found to delete');
    }
  } catch (e) {
    AppLogging.storage('Manual Firestore cache deletion failed: $e');
  }
}

/// Initialize ancillary Firebase services in background.
/// Firebase core is already initialized in main(). These are best-effort
/// and must never block the app, sign-in, or crash on failure.
Future<void> _initializeFirebaseServices() async {
  if (!firebaseReadyCompleter.isCompleted ||
      !(await firebaseReadyCompleter.future)) {
    return;
  }

  // Before ANY Firestore access, repair corrupted cache from a previous crash.
  // Must happen before setLoggingEnabled / settings / any snapshot listener.
  await _repairFirestoreCacheIfNeeded();

  try {
    await FirebaseFirestore.setLoggingEnabled(false);
  } catch (e) {
    AppLogging.storage('Firestore logging config failed: $e');
  }

  // Mark init as "in progress" — cleared to true after success.
  // If the app crashes during the block below, the flag stays false and
  // the next startup will call _repairFirestoreCacheIfNeeded().
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFirestoreInitOk, false);
  } catch (_) {}

  // Configure Firestore settings to prevent cache corruption crashes
  // See: https://github.com/firebase/flutterfire/issues/9661
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    AppLogging.storage('Firestore settings failed, trying without cache: $e');
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    } catch (e2) {
      AppLogging.storage('Firestore unavailable: $e2');
    }
  }

  // Proactive LevelDB probe: force the native client to open the database
  // NOW while the _kFirestoreInitOk flag is still false. If this crashes
  // (LevelDB LOCK / corruption), the flag stays false and the next launch
  // will run _repairFirestoreCacheIfNeeded() before retrying.
  //
  // Without this probe the flag was set to true immediately after Settings
  // assignment, but LevelDB only opens on the first real query — by which
  // point the flag was already true, so a crash there would never trigger
  // repair on the next launch.
  try {
    await FirebaseFirestore.instance
        .collection('_probe')
        .doc('_init')
        .get(const GetOptions(source: Source.cache))
        .timeout(const Duration(seconds: 5));
    AppLogging.storage('Firestore LevelDB probe succeeded');
  } catch (e) {
    // A "not found in cache" error is fine — it means LevelDB opened.
    // Only a LevelDB / LOCK error is a real problem, and in that case
    // the fatal assertion already crashed the process (flag stays false).
    AppLogging.storage('Firestore probe completed with expected error: $e');
  }

  // Firestore initialized successfully — mark flag so next startup
  // skips the cache repair step.
  try {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(_kFirestoreInitOk, true);
  } catch (_) {}

  // Apply persisted privacy consent state.
  // On first launch (no consent), both remain disabled (set to false above).
  // After terms acceptance, consent is persisted and re-applies here.
  try {
    prefs ??= await SharedPreferences.getInstance();
    final consentService = PrivacyConsentService(prefs);
    await consentService.applyPersistedConsent();
  } catch (e) {
    AppLogging.app('Privacy consent apply failed: $e');
  }

  try {
    initProfileCloudSyncService();
  } catch (e) {
    AppLogging.sync('Profile cloud sync init failed: $e');
  }

  try {
    await PushNotificationService().initialize();
  } catch (e) {
    AppLogging.notifications('Push notification init failed: $e');
  }

  // Listen for connectivity changes and attempt to resolve pending images
  try {
    final connectivity = Connectivity();
    connectivity.onConnectivityChanged.listen((results) {
      AppLogging.social('CONNECTIVITY_CHANGE: $results');
      if (!results.contains(ConnectivityResult.none) && results.isNotEmpty) {
        // Try resolving any pending images now that connectivity may be restored
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final ctx = navigatorKey.currentContext;
            if (ctx == null) {
              AppLogging.social(
                'CONNECTIVITY_CHANGE: navigator context not ready',
              );
              return;
            }
            final container = ProviderScope.containerOf(ctx, listen: false);
            final sigService = container.read(signalServiceProvider);
            sigService.attemptResolveAllPendingImages();
          } catch (e) {
            AppLogging.social(
              'CONNECTIVITY_CHANGE: resolver invocation failed: $e',
            );
          }
        });
      }
    });
  } catch (e) {
    AppLogging.social('Connectivity listener not available: $e');
  }
}

class SocialMeshApp extends ConsumerStatefulWidget {
  const SocialMeshApp({super.key});

  @override
  ConsumerState<SocialMeshApp> createState() => _SocialMeshAppState();
}

class _SocialMeshAppState extends ConsumerState<SocialMeshApp>
    with WidgetsBindingObserver, LifecycleSafeMixin {
  StreamSubscription<NotificationNavigation>? _pushNotificationSubscription;
  StreamSubscription<String>? _localNotificationTapSubscription;

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
      // Start the Apple Watch companion bridge (iOS only). The bridge
      // is internally gated on WCSession.isSupported() and on the
      // WATCH_COMPANION_ENABLED feature flag; on Android / iPad-only
      // builds this resolves to a no-op. Idempotent: safe under hot
      // restart.
      if (Platform.isIOS) {
        unawaited(ref.read(watchCompanionChannelBridgeProvider).start());
      }
    });
  }

  @override
  void dispose() {
    _pushNotificationSubscription?.cancel();
    _localNotificationTapSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Notify the centralized lifecycle provider so all timer-based providers
    // can pause/resume automatically (battery drain prevention).
    ref.read(appLifecycleProvider.notifier).didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Mark app as active for lifecycle-aware commands
      ref.read(lifecycleCommandManagerProvider).setAppActive(true);
      // Foreground/background handoff (W2.3): stop background notification
      // dispatch and merge background-persisted messages into the UI.
      _handleBackgroundToForegroundHandoff();
      _handleAppResumed();
      // Set user online when app returns to foreground
      ref.read(userPresenceServiceProvider).setOnline();
      // Process any due scheduled automations on resume
      _processScheduledAutomationsOnResume();
      // Resume RSSI polling and GPS location updates (paused on background).
      _resumeProtocolPolling();
      _resumeLocationUpdates();
      // Clear the app icon badge whenever the user brings the app to the
      // foreground — they are now actively using it and any unread count
      // shown on the icon is stale.
      NotificationService().clearBadge();
    } else if (state == AppLifecycleState.paused) {
      // Only trigger background handoff when the app is *truly* paused
      // (i.e. no longer visible). `inactive` (notification shade, system
      // dialog) must NOT enable the BackgroundMessageProcessor because the
      // foreground ProtocolService is still the primary data handler; both
      // listening to the same broadcast BLE stream would create duplicates.
      ref.read(lifecycleCommandManagerProvider).setAppActive(false);
      // Foreground/background handoff (W2.3): enable background notification
      // dispatch so messages received in the background produce notifications.
      _handleForegroundToBackgroundHandoff();
      // Set user offline when app goes to background
      ref.read(userPresenceServiceProvider).setOffline();
      // Sync scheduled automations to platform scheduler for background execution
      _syncScheduledAutomationsToPlatform();
      // Pause RSSI polling to conserve battery. BLE readRssi() every 2s
      // wakes the Bluetooth stack and triggers Live Activity UserDefaults
      // writes — ~14,400 unnecessary BLE round-trips over an 8-hour night.
      _pauseProtocolPolling();
      _pauseLocationUpdates();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Mark lifecycle as inactive but do NOT enable the background message
      // processor — the foreground ProtocolService is still handling data.
      ref.read(lifecycleCommandManagerProvider).setAppActive(false);
      // Pause RSSI polling and GPS location updates even on `inactive`.
      // iOS sends `inactive` before `paused`, and sometimes never reaches
      // `paused` at all (app switcher, notification shade). Without this,
      // BLE readRssi() every 2s and GPS every 30s keep firing.
      _pauseProtocolPolling();
      _pauseLocationUpdates();
    }
  }

  /// Pause BLE RSSI polling when the app is backgrounded.
  void _pauseProtocolPolling() {
    try {
      ref.read(protocolServiceProvider).pauseRssiPolling();
    } catch (_) {
      // Protocol service may not be initialized yet — safe to ignore.
    }
  }

  /// Resume BLE RSSI polling when the app returns to the foreground.
  void _resumeProtocolPolling() {
    try {
      ref.read(protocolServiceProvider).resumeRssiPolling();
    } catch (_) {
      // Protocol service may not be initialized yet — safe to ignore.
    }
  }

  /// Pause GPS location timer when the app is backgrounded.
  ///
  /// The location service sends the phone's GPS position to the mesh every
  /// 30 seconds. Each tick wakes the GPS radio, computes a fix, serializes a
  /// protobuf, and sends it over BLE — all for a position update that nobody
  /// is looking at. Pausing eliminates this entirely; the mesh retains the
  /// last-known position on the lock screen / Live Activity.
  void _pauseLocationUpdates() {
    try {
      final locationService = ref.read(locationServiceProvider);
      if (!locationService.isRunning) return; // Already stopped — skip noise.
      locationService.stopLocationUpdates();
      AppLogging.app('🔋 Location updates paused (app backgrounded)');
    } catch (_) {
      // Location service may not be initialized yet — safe to ignore.
    }
  }

  /// Resume GPS location timer when the app returns to the foreground.
  void _resumeLocationUpdates() {
    try {
      final locationService = ref.read(locationServiceProvider);
      // Only restart if the service was previously running (i.e. we're
      // connected to a device that expects position updates).
      final isConnected = ref.read(isLinkConnectedProvider);
      if (isConnected) {
        locationService.startLocationUpdates();
        AppLogging.app('🔋 Location updates resumed (app foregrounded)');
      }
    } catch (_) {
      // Location service may not be initialized yet — safe to ignore.
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
        unawaited(bridge.processOnResume());
        AppLogging.automations('Processed scheduled automations on resume');
      }
    } catch (e) {
      AppLogging.automations('Failed to process schedules on resume: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground / background handoff (W2.3)
  // ---------------------------------------------------------------------------

  /// Called when the app transitions to the background (`paused`).
  ///
  /// Enables the background message processor so messages received while the
  /// UI is paused are persisted and produce local notifications.
  void _handleForegroundToBackgroundHandoff() {
    final processor = BackgroundMessageProcessor.instance;
    processor.processingEnabled = true;
    processor.notificationsEnabled = true;
    AppLogging.ble(
      'Handoff: app paused, background processing & notifications enabled',
    );
  }

  /// Called when the app returns to the foreground.
  ///
  /// 1. Stops the background processor's data processing and notification
  ///    dispatch so only the foreground ProtocolService handles BLE data.
  /// 2. Merges background-persisted messages into the UI state.
  /// 3. Drains buffered non-message packets for foreground processing.
  void _handleBackgroundToForegroundHandoff() {
    final processor = BackgroundMessageProcessor.instance;

    // Stop background processing and notification dispatch so only the
    // foreground ProtocolService handles BLE data.
    processor.processingEnabled = false;
    processor.notificationsEnabled = false;

    // Merge any messages persisted by the background processor.
    final bgIds = Set<String>.from(processor.persistedMessageIds);
    if (bgIds.isNotEmpty) {
      AppLogging.ble(
        'Handoff: merging ${bgIds.length} background messages into UI',
      );
      ref.read(messagesProvider.notifier).mergeBackgroundMessages(bgIds);
      processor.persistedMessageIds.clear();
    }

    // Drain buffered non-message packets. These will be fully processed by the
    // foreground ProtocolService on the next data cycle. For now we just clear
    // the buffer to prevent unbounded growth; full packet replay is deferred
    // to a future iteration.
    final bufferedCount = processor.pendingPackets.length;
    if (bufferedCount > 0) {
      AppLogging.ble(
        'Handoff: discarding $bufferedCount buffered non-message packets '
        '(foreground processing on resume is not yet wired)',
      );
      processor.pendingPackets.clear();
    }

    AppLogging.ble(
      'Handoff: app foregrounded, background processing & notifications off',
    );
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

    // iOS-state-restoration safety net (Meshtastic only).
    //
    // After force-close + reopen or long background idle, iOS Core
    // Bluetooth restores the GATT link but `flutter_blue_plus` does not
    // auto-resubscribe FROMNUM notifications. The transport reports
    // `connected`, the existing early-return below skips reconnect,
    // and the protocol stays wedged (phase-2 stalled, parameters
    // "Unknown", TX silently fails) until the user manually reconnects.
    //
    // Trigger a coordinator-managed restore if the BLE link is up but
    // the protocol has not reached `ready`. The coordinator's
    // user-disconnect / in-flight / transport-disconnected pre-checks
    // make this safe; we only call it when there is a real wedge to
    // recover from. MeshCore is unaffected — it has its own coordinator.
    if (protocol != 'meshcore' && isLinkConnected && !userDisconnected) {
      final readiness = ref
          .read(meshtasticReadinessProvider)
          .maybeWhen(data: (r) => r, orElse: () => null);
      // `idle` is the no-active-session case (cold start before any
      // protocol.start() has run) — leave it to the existing
      // disconnected-with-saved-device branch below to drive a fresh
      // connect. `ready` means the session is healthy — don't disturb.
      // We only restore from the in-between wedged states.
      final isWedged =
          readiness != null &&
          readiness != OperationalReadiness.ready &&
          readiness != OperationalReadiness.idle;
      if (isWedged) {
        AppLogging.connection(
          '📱 APP RESUMED: BLE link connected but protocol wedged '
          '(readiness=$readiness) — triggering restoreSession',
        );
        try {
          await ref
              .read(conn.deviceConnectionProvider.notifier)
              .restoreSessionForLifecycleResume();
        } catch (e) {
          AppLogging.connection(
            '📱 APP RESUMED: restoreSessionForLifecycleResume failed: $e',
          );
        }
        // Whether the restore succeeded or aborted (stale, in-flight,
        // user-disconnect race), the existing branches below still need
        // to run their checks — fall through.
      }
    }

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

    // If user is manually connecting from Scanner (tapped a device),
    // don't trigger resume-reconnect to the OLD saved device. Scanner
    // owns the connection flow while manualConnecting is set — it will
    // clear this state on success, retry, or dispose.
    if (autoReconnectState == AutoReconnectState.manualConnecting) {
      AppLogging.connection(
        '📱 APP RESUMED: User is manually connecting from Scanner, '
        'not triggering resume-reconnect to saved device',
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
      if (!mounted) return;
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

      // Restore transport type from persisted lastDeviceType. At cold
      // start transportTypeProvider defaults to BLE — without this, a
      // resume for a previously-connected TCP device would run
      // `transport.scan()` against BleTransport and never find its
      // endpoint. The rest of the resume path reads transportProvider
      // (and the device-transition helper) and relies on it already
      // matching the device family.
      if (!mounted) return;
      final restoredType = transportTypeFromString(settings.lastDeviceType);
      if (restoredType != null &&
          ref.read(transportTypeProvider) != restoredType) {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: restoring transport type to '
          '${restoredType.name} from persisted lastDeviceType',
        );
        if (restoredType == TransportType.network) {
          final endpoint = parseNetworkEndpointId(deviceId);
          if (endpoint != null) {
            ref.read(networkTransportHostProvider.notifier).set(endpoint.host);
            ref.read(networkTransportPortProvider.notifier).set(endpoint.port);
          }
        }
        ref.read(transportTypeProvider.notifier).setType(restoredType);
      }

      if (lastProtocol == 'meshcore') {
        // D27: route through the protocol-aware dispatcher so TCP-saved
        // peers reconnect via `connectMeshCoreTcp` and BLE-saved peers
        // run the coordinator's BLE strategies. The previous in-place
        // `_performMeshCoreReconnectOnResume` hardcoded `TransportType.ble`
        // for every MeshCore peer, which is the bug surfaced during the
        // D26 smoke (TCP-saved + GPS dialog → `CBManagerStateUnsupported`).
        // Live smoke confirmed this still fired even after the original
        // D27 dispatch consolidation; folding it into the same dispatcher
        // closes the last on-resume gap.
        dispatchReconnectMeshCoreAwareForWidget(ref, deviceId);
      } else {
        await _performMeshtasticReconnectOnResume(deviceId, settings);
      }
    } finally {
      // Always clear the mutex, even on exceptions
      _reconnectInFlight = false;
      AppLogging.connection('📱 RECONNECT ON RESUME: Completed, mutex cleared');
    }
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
        if (!mounted) return;
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

        // Run central transition prep BEFORE transport.connect so
        // transportTypeProvider matches the device family and the
        // classifier decides preserve-vs-clear-vs-rehydrate via a
        // single source of truth. On resume this is usually
        // `sameDevice`, but if the user's last session was TCP and the
        // resume lands on BLE (or vice-versa) we still need to flip
        // transport type and (when logical identity matches) force a
        // fresh hydrate.
        await prepareForDeviceTransition(
          ref,
          device: foundDevice,
          deviceProtocol: 'meshtastic',
        );
        if (!mounted) return;

        // Re-read transport after prep — transportTypeProvider may have
        // been flipped to the correct family.
        final connectTransport = ref.read(transportProvider);
        await connectTransport.connect(foundDevice);

        if (connectTransport.state == DeviceConnectionState.connected) {
          AppLogging.connection(
            '📱 RECONNECT ON RESUME: BLE connected, starting protocol...',
          );

          if (!mounted) return;
          final protocol = ref.read(protocolServiceProvider);

          // Set device info for hardware model inference
          protocol.setDeviceName(foundDevice.name);
          protocol.setBleModelNumber(connectTransport.bleModelNumber);
          protocol.setBleManufacturerName(connectTransport.bleManufacturerName);

          await protocol.start();

          if (protocol.myNodeNum == null) {
            AppLogging.connection(
              '📱 RECONNECT ON RESUME: No myNodeNum - auth may have failed',
            );
            await connectTransport.disconnect();
            throw Exception('Authentication failed');
          }

          AppLogging.connection(
            '📱 RECONNECT ON RESUME: Protocol started, myNodeNum=${protocol.myNodeNum}',
          );
          if (!mounted) return;
          ref.read(connectedDeviceProvider.notifier).setState(foundDevice);
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.success);

          // Start location updates
          final locationService = ref.read(locationServiceProvider);
          await locationService.startLocationUpdates();

          AppLogging.connection('📱 RECONNECT ON RESUME: ✅ Success!');

          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.idle);
        } else {
          AppLogging.connection(
            '📱 RECONNECT ON RESUME: BLE connect failed, '
            'transport.state=${connectTransport.state}',
          );
          throw Exception('Connection failed');
        }
      } else {
        AppLogging.connection(
          '📱 RECONNECT ON RESUME: Device not found in scan',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.failed);
      }
    } catch (e) {
      AppLogging.connection('📱 RECONNECT ON RESUME: Failed: $e');
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.failed);
    }
  }

  Future<void> _initializePurchases() async {
    try {
      final service = await ref.read(subscriptionServiceProvider.future);
      AppLogging.subscriptions('💰 RevenueCat initialized');

      // service.initialize() already called Purchases.configure() with the
      // current Firebase UID (when signed in), so no logIn / pre-login
      // syncPurchases hop is needed here. A single refresh pulls the latest
      // entitlements; explicit Restore is exposed via the Restore button.
      final firebaseUser = FirebaseAuth.instance.currentUser;
      AppLogging.subscriptions(
        '💰 [Bootstrap] firebaseUser=${firebaseUser?.uid ?? "(anonymous)"}',
      );
      await service.refreshPurchases();
      AppLogging.subscriptions('💰 [Bootstrap] complete');

      // Initialize cloud sync entitlement service AFTER purchases are
      // bootstrapped so its initial RC read sees the freshly-synced state.
      if (!mounted) return;
      final cloudSyncService = ref.read(cloudSyncEntitlementServiceProvider);
      await cloudSyncService.initialize();
      AppLogging.subscriptions('☁️ Cloud sync entitlement service initialized');
    } catch (e) {
      AppLogging.subscriptions('💰 RevenueCat init failed: $e');
    }
  }

  Future<void> _initializeDeepLinks() async {
    try {
      // Use DeepLinkManager for lifecycle-safe navigation
      if (!mounted) return;
      final deepLinkManager = ref.read(deepLinkManagerProvider);
      await deepLinkManager.initialize();
      AppLogging.app('🔗 Deep link manager initialized');
    } catch (e) {
      AppLogging.app('🔗 Deep link init failed: $e');
    }
  }

  /// Initialize glyph service (Nothing Phone)
  Future<void> _initializeGlyphService() async {
    try {
      await ref.read(glyphServiceInitProvider.future);
      if (!mounted) return;
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

      // Also listen for foreground local notification taps. Two
      // payload conventions exist:
      //   1. `type|deepLink` — used by FCM payloads converted into
      //      local notifications (announcements, etc.). The deep link
      //      itself can contain `:` (e.g. `https://...`), so the `|`
      //      separator is what splits type from link.
      //   2. `type:targetId[:more]` — the historical NotificationService
      //      convention for SIP handshake / peer-found / pet / aether /
      //      TAK / firmware notifications. First segment is the type,
      //      rest is the target identifier.
      // Both feed the same `_handlePushNotificationNavigation`
      // dispatcher, so we normalise here.
      _localNotificationTapSubscription = NotificationService()
          .onPushNotificationTap
          .listen((payload) {
            String type;
            String? targetId;
            String? deepLink;
            if (payload.contains('|')) {
              final parts = payload.split('|');
              type = parts.first;
              deepLink = parts.length > 1 ? parts.sublist(1).join('|') : null;
            } else if (payload.contains(':')) {
              final parts = payload.split(':');
              type = parts.first;
              targetId = parts.length > 1 ? parts.sublist(1).join(':') : null;
            } else {
              type = payload;
            }
            _handlePushNotificationNavigation(
              NotificationNavigation(
                type: type,
                targetId: targetId,
                deepLink: deepLink,
              ),
            );
          });

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

        case 'bug_report_response':
          // Navigate to My Bug Reports screen
          navigator.pushNamed(
            '/my-bug-reports',
            arguments: nav.targetId != null ? {'reportId': nav.targetId} : null,
          );
          break;

        case 'bug_report':
          // Navigate to Admin Bug Reports screen (admin tapped notification)
          navigator.pushNamed('/admin-bug-reports');
          break;

        case 'announcement':
          // Navigate using the deep link if provided
          if (nav.deepLink != null && nav.deepLink!.isNotEmpty) {
            final link = nav.deepLink!;
            AppLogging.notifications('🔔 Announcement deep link: $link');
            // Only navigate if the deep link starts with '/' (internal route).
            // External URLs or malformed values must not hit pushNamed.
            if (link.startsWith('/')) {
              navigator.pushNamed(link);
            } else {
              AppLogging.notifications(
                '🔔 Ignoring non-route deep link: $link',
              );
            }
          }
          break;

        case 'sip_handshake':
          // Handshake completed → land on the DM thread for the
          // matching peer if a session already exists. If the user
          // taps very early (session not yet created) or after the
          // session was cleaned up, fall back to the SIP hub so they
          // can re-enter from the peer card.
          _routeToSipHandshakeCompleted(navigator, nav.targetId);
          break;

        case 'sip_handshake_request':
        case 'sip_handshake_declined':
          // Handshake-specific notifications always route to SipHub.
          // The SIP hub surfaces inbound HS_HELLO consent banners
          // (request) and declined-handshake state on the peer card
          // (declined). Skip the push when already on the hub so
          // back-tapping doesn't reveal a stack of duplicate hubs.
          // Consent is still a manual tap — never auto-accepted.
          if (!_topRouteIsSipHub(navigator)) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => const SipHubScreen(),
                settings: const RouteSettings(name: _kSipHubRouteName),
              ),
            );
          }
          break;

        case 'sip_peer_found':
          // Peer-discovery notifications route to whichever surface
          // the operator has enabled. The notification body itself is
          // already feature-aware (see selectPeerFoundBody); the tap
          // destination must match so a MeshCanvas-only user lands on
          // MeshCanvas, not on a Handshake hub they cannot use.
          //
          //   - Handshake on (with or without MeshCanvas) → SipHub.
          //     Hub is the canonical peer-connect surface; MeshCanvas
          //     is reachable from the drawer.
          //   - Handshake off, MeshCanvas on → MeshCanvas overview.
          //   - Both off → no-op (the body selector also returns null
          //     in this case so the notification never fires).
          if (AppFeatureFlags.isHandshakeEnabled) {
            if (!_topRouteIsSipHub(navigator)) {
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => const SipHubScreen(),
                  settings: const RouteSettings(name: _kSipHubRouteName),
                ),
              );
            }
          } else if (AppFeatureFlags.isMeshCanvasEnabled) {
            if (!_topRouteIsMeshCanvasOverview(navigator)) {
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => const MeshCanvasOverviewScreen(),
                  settings: const RouteSettings(
                    name: _kMeshCanvasOverviewRouteName,
                  ),
                ),
              );
            }
          }
          break;

        default:
          AppLogging.notifications('🔔 Unknown notification type: ${nav.type}');
      }
    });
  }

  /// Resolve the SIP DM session for [peerNodeIdStr] and push
  /// `SipDmScreen`. Falls back to `SipHubScreen` when the peer ID is
  /// missing or no active session matches — the hub is always a safe
  /// landing.
  void _routeToSipHandshakeCompleted(
    NavigatorState navigator,
    String? peerNodeIdStr,
  ) {
    final peerNodeId = peerNodeIdStr != null
        ? int.tryParse(peerNodeIdStr)
        : null;
    if (peerNodeId != null) {
      final sessions = ref.read(sipActiveSessionsProvider);
      final match = sessions
          .where((s) => s.peerNodeId == peerNodeId)
          .fold<SipDmSession?>(null, (_, s) => s);
      if (match != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => SipDmScreen(sessionTag: match.sessionTag),
          ),
        );
        return;
      }
      AppLogging.notifications(
        '🔔 sip_handshake tap: no active session for peer $peerNodeId, '
        'falling back to hub',
      );
    }
    if (!_topRouteIsSipHub(navigator)) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const SipHubScreen(),
          settings: const RouteSettings(name: _kSipHubRouteName),
        ),
      );
    }
  }

  /// Route name used to identify a [SipHubScreen] in the navigator
  /// stack. A named route lets [_topRouteIsSipHub] short-circuit
  /// duplicate pushes when a notification tap arrives while the hub
  /// is already on top — without it, a second push stacks an
  /// identical Handshake screen and the user has to tap back twice
  /// to return.
  ///
  /// Matches the `runtimeType.toString()` convention used by
  /// `navigateFromDrawer` (see `main_shell.dart`) so that whether
  /// the hub was reached via the drawer or pushed from a previous
  /// notification, the same name is used.
  static const String _kSipHubRouteName = 'SipHubScreen';
  static const String _kMeshCanvasOverviewRouteName =
      'MeshCanvasOverviewScreen';

  /// True if the topmost route on [navigator]'s stack is a
  /// [SipHubScreen] (identified by the [_kSipHubRouteName] tag).
  /// Uses `popUntil` with a stop-on-first-iteration predicate to
  /// inspect the top route without modifying the stack.
  bool _topRouteIsSipHub(NavigatorState navigator) {
    var top = false;
    navigator.popUntil((route) {
      top = route.settings.name == _kSipHubRouteName;
      return true; // stop iteration immediately, no actual pop
    });
    return top;
  }

  /// Mirror of [_topRouteIsSipHub] for the MeshCanvas overview.
  bool _topRouteIsMeshCanvasOverview(NavigatorState navigator) {
    var top = false;
    navigator.popUntil((route) {
      top = route.settings.name == _kMeshCanvasOverviewRouteName;
      return true;
    });
    return top;
  }

  Future<void> _loadAccentColor() async {
    final settings = await ref.read(settingsServiceProvider.future);

    // Local accent color is now loaded automatically by AccentColorNotifier.build()
    // Just load the theme mode from local settings
    final localThemeModeIndex = settings.themeMode;
    final localThemeMode = ThemeMode.values[localThemeModeIndex];
    if (!mounted) return;
    ref.read(themeModeProvider.notifier).setThemeMode(localThemeMode);

    // Wait for Firebase to be ready before syncing from cloud
    final isFirebaseReady = await firebaseReady.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        AppLogging.app('⏱️ Firebase ready timeout, using local accent color');
        return false;
      },
    );

    if (!isFirebaseReady) {
      AppLogging.app('📱 Firebase not ready, using local accent color');
      return;
    }

    // Then sync from cloud in background (may override local)
    try {
      // Wait for auth state to be ready
      final authState = await ref.read(authStateProvider.future);
      AppLogging.sync('🎨 Auth state: ${authState?.email ?? "not signed in"}');

      // If user is signed in, sync from cloud
      if (authState != null) {
        AppLogging.sync('🎨 User signed in, reading profile (no invalidate)');
        // NOTE: Don't invalidate userProfileProvider here!
        // UserProfileNotifier.build() already calls fullSync() which syncs from cloud.
        // Invalidating here causes redundant Firestore writes (batches 6, 7, 8).

        AppLogging.sync('🎨 Waiting for profile future...');
        final profile = await ref.read(userProfileProvider.future);
        final prefs = profile?.preferences;

        AppLogging.sync('🎨 Profile loaded: ${profile?.displayName}');
        AppLogging.sync(
          '🎨 Profile accentColorIndex: ${profile?.accentColorIndex}',
        );
        AppLogging.sync('🎨 Profile updatedAt: ${profile?.updatedAt}');
        AppLogging.sync('🎨 Profile isSynced: ${profile?.isSynced}');

        // Update accent color from cloud if available
        final colorIndex = profile?.accentColorIndex;
        AppLogging.sync('🎨 Cloud profile accentColorIndex: $colorIndex');
        if (colorIndex != null &&
            colorIndex >= 0 &&
            colorIndex < AccentColors.all.length) {
          final cloudColor = AccentColors.all[colorIndex];
          AppLogging.sync(
            '🎨 Setting color to: ${AccentColors.names[colorIndex]}',
          );
          await ref.read(accentColorProvider.notifier).setColor(cloudColor);
          AppLogging.sync(
            '🎨 Updated accent color from cloud: ${AccentColors.names[colorIndex]}',
          );
        } else {
          AppLogging.sync(
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
      AppLogging.sync('☁️ Cloud sync failed, using local settings: $e');
    }
  }

  /// Initialize user presence tracking
  Future<void> _initializePresence() async {
    // Initialize extended presence service first (loads cached remote presence)
    if (!mounted) return;
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
    if (!mounted) return;
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
        AppLogging.sync(
          '📝 Loaded ${responses.length} canned responses from cloud',
        );
      } catch (e) {
        AppLogging.sync('Failed to parse canned responses: $e');
      }
    }

    // Load tapback configs from cloud
    if (prefs.tapbackConfigsJson != null) {
      try {
        final jsonList = jsonDecode(prefs.tapbackConfigsJson!) as List;
        final configs = jsonList.map((j) => TapbackConfig.fromJson(j)).toList();
        await settings.setTapbackConfigs(configs);
        AppLogging.sync(
          '👍 Loaded ${configs.length} tapback configs from cloud',
        );
      } catch (e) {
        AppLogging.sync('Failed to parse tapback configs: $e');
      }
    }

    // Load ringtone from cloud
    if (prefs.ringtoneRtttl != null && prefs.ringtoneName != null) {
      await settings.setSelectedRingtone(
        rtttl: prefs.ringtoneRtttl!,
        name: prefs.ringtoneName!,
      );
      AppLogging.sync('🔔 Loaded ringtone from cloud: ${prefs.ringtoneName}');
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
      if (!mounted) return;
      // Invalidate the provider so it reloads with new config
      ref.invalidate(splashMeshConfigProvider);
      AppLogging.sync('✨ Loaded splash mesh config from cloud');
    }

    // Load automations from cloud
    if (prefs.automationsJson != null) {
      try {
        final automationRepo = ref.read(automationRepositoryProvider);
        await automationRepo.loadFromJson(prefs.automationsJson!);
        if (!mounted) return;
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
        AppLogging.ifttt('🔗 Loaded IFTTT config from cloud');
      } catch (e) {
        AppLogging.ifttt('Failed to parse IFTTT config: $e');
      }
    }

    AppLogging.sync('☁️ Loaded user preferences from cloud profile');
  }

  @override
  Widget build(BuildContext context) {
    // Watch auto-reconnect and live activity managers at app level
    // so they stay active regardless of which screen is shown
    ref.watch(autoReconnectManagerProvider);
    ref.watch(bluetoothStateListenerProvider);
    // D27: MeshCore-specific foreground/disconnect reconnect listener.
    // Closes the gap left by the Meshtastic-only autoReconnectManager,
    // which bails on `lastDeviceProtocol == 'meshcore'`.
    ref.watch(meshCoreLifecycleProvider);
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
        title: 'SocialMesh', // lint-allow: hardcoded-string
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        builder: (context, child) {
          // Clamp Dynamic Type / text scale to prevent layout overflow
          // on devices with large accessibility text settings.
          final mediaQuery = MediaQuery.of(context);
          final clampedTextScaler = mediaQuery.textScaler.clamp(
            maxScaleFactor: 1.3,
          );
          final disableAnimations =
              mediaQuery.disableAnimations ||
              accessibilityPrefs.reduceMotionMode.shouldReduceMotion;
          // ConfirmingUnlockOverlay sits above every route so the
          // post-redirect "Confirming your unlock…" state can surface
          // regardless of which screen the user is on when the deep
          // link arrives. Idle stage renders nothing.
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: clampedTextScaler,
              disableAnimations: disableAnimations,
            ),
            child: ConfirmingUnlockOverlay(child: child!),
          );
        },
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (locales, supportedLocales) {
          // Flutter's default resolution can pass unsupported locales (e.g.
          // ro_RO) to the AppLocalizations delegate, which throws a
          // FlutterError. Resolve manually: prefer first device locale whose
          // language code matches a supported locale, otherwise fall back to
          // the first supported locale (English).
          if (locales != null) {
            for (final locale in locales) {
              for (final supported in supportedLocales) {
                if (supported.languageCode == locale.languageCode) {
                  return supported;
                }
              }
            }
          }
          return supportedLocales.first;
        },
        navigatorObservers: [
          _KeyboardDismissObserver(),
          _DelegatingAnalyticsObserver(ref),
        ],
        home: const _AppRouter(),
        routes: {
          // Reset route: replaces the entire nav stack with _AppRouter,
          // which reads appInitProvider and shows the correct screen.
          // The route widget carries an explicit ValueKey so it does
          // NOT collide with `home: const _AppRouter()` (no key) under
          // Flutter's element-matching: same runtimeType but different
          // keys keeps the route boundary's State separate from the
          // home's State. The widget itself is still const-constructible
          // (ValueKey is const), so the builder returns the SAME
          // canonical instance on every call, which is what prevents
          // the routes-map rebuild from triggering an Element swap on
          // every frame.
          '/app': (context) => const _AppRouter(key: ValueKey('app_root')),
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
          // License org invite (slice N+5). Deep-link router lands
          // here with the plaintext LINV token in arguments; we push
          // the InviteAcceptScreen which prompts the user for
          // explicit consent before calling acceptLicenseOrgInvite.
          if (settings.name == '/invite') {
            final args = settings.arguments as Map<String, dynamic>?;
            final token = args?['token'] as String?;
            if (token == null || token.isEmpty) {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Invalid invite link')),
                ),
              );
            }
            return InviteAcceptScreen.route(token);
          }
          if (settings.name == '/my-bug-reports') {
            final args = settings.arguments as Map<String, dynamic>?;
            final reportId = args?['reportId'] as String?;
            final focusReply = args?['focusReply'] as bool? ?? false;
            return MaterialPageRoute(
              builder: (context) => MyBugReportsScreen(
                initialReportId: reportId,
                initialFocusReply: focusReply,
              ),
            );
          }
          if (settings.name == '/admin-bug-reports') {
            return MaterialPageRoute(
              builder: (context) => const AdminBugReportsScreen(),
            );
          }
          // Check route requirements before building
          if (RouteRegistry.isDeviceRequired(settings.name)) {
            // This route requires device - it will be checked by the builder
          }

          // Handle legal document deep links
          if (settings.name == '/legal/terms') {
            final args = settings.arguments as Map<String, dynamic>?;
            final anchor = args?['sectionAnchor'] as String?;
            return MaterialPageRoute(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (anchor != null) {
                    LegalDocumentSheet.showTermsSection(context, anchor);
                  } else {
                    LegalDocumentSheet.showTerms(context);
                  }
                });
                return const MainShell();
              },
            );
          }
          if (settings.name == '/legal/privacy') {
            return MaterialPageRoute(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  LegalDocumentSheet.showPrivacy(context);
                });
                return const MainShell();
              },
            );
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
          if (settings.name == '/channel-import') {
            final args = settings.arguments as Map<String, dynamic>?;
            final firestoreId = args?['firestoreId'] as String?;
            if (firestoreId != null) {
              return MaterialPageRoute(
                builder: (context) =>
                    _ChannelImportLoader(firestoreId: firestoreId),
              );
            }
          }
          if (settings.name == '/channel-invite') {
            final args = settings.arguments as Map<String, dynamic>?;
            final inviteId = args?['inviteId'] as String?;
            final inviteSecret = args?['inviteSecret'] as String?;
            if (inviteId != null && inviteSecret != null) {
              return MaterialPageRoute(
                builder: (context) => _ChannelInviteRedeemer(
                  inviteId: inviteId,
                  inviteSecret: inviteSecret,
                ),
              );
            }
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
          if (settings.name == '/aether-flight') {
            final args = settings.arguments as Map<String, dynamic>?;
            final shareId = args?['shareId'] as String?;
            if (shareId != null) {
              return MaterialPageRoute(
                builder: (context) =>
                    _AetherFlightDeepLinkLoader(shareId: shareId),
              );
            }
          }
          return null;
        },
        onUnknownRoute: (settings) {
          AppLogging.notifications(
            '🔔 Unknown route: ${settings.name} — falling back to home',
          );
          return MaterialPageRoute(builder: (_) => const _AppRouter());
        },
      ),
    );
  }

  /// Build a protected route that checks device connection requirements.
  ///
  /// Previously returned a "Device Required" blocking screen on
  /// disconnect. That screen was a dead-end UI that confused users
  /// (especially after a factory-reset writeCharacteristic failure
  /// dropped the BLE link mid-action). It's been removed entirely —
  /// disconnects on a protected route now route directly to the
  /// Scanner so the user can pick a device and reconnect.
  Widget _buildProtectedRoute(
    BuildContext context,
    String routeName,
    Widget screen,
  ) {
    return _ProtectedRouteHost(routeName: routeName, screen: screen);
  }
}

// Stateful host so we can latch a single pop when the device is
// disconnected. A naive `Consumer.builder + postFrame + nav` would
// loop: every Riverpod state change rebuilds the Consumer, schedules
// another postFrame, fires another nav. The latch ensures the pop
// fires exactly once per mount.
//
// Pop semantics: this widget pops back to the home AppRouter root
// (`popUntil((r) => r.isFirst)`) rather than pushing a fresh /scanner
// route. The home AppRouter renders the right shell via
// `appShellProvider` from its single canonical mount point:
//
//   - intentional disconnect (factory reset, manual disconnect):
//     appInit is already `needsScanner`, so the home AppRouter
//     renders Scanner.
//   - transient disconnect (signal flap, peripheral reboot): appInit
//     stays `ready`, so the home AppRouter renders MainShell with
//     the recovery banner.
//
// Pushing a new `/scanner` route would mount a SECOND AppRouter
// stack on top of the persistent home AppRouter and fork the shell
// hierarchy, exactly like the `pushNamedAndRemoveUntil('/app')`
// pattern this codebase removed elsewhere.
class _ProtectedRouteHost extends ConsumerStatefulWidget {
  final String routeName;
  final Widget screen;

  const _ProtectedRouteHost({required this.routeName, required this.screen});

  @override
  ConsumerState<_ProtectedRouteHost> createState() =>
      _ProtectedRouteHostState();
}

class _ProtectedRouteHostState extends ConsumerState<_ProtectedRouteHost> {
  bool _popScheduled = false;

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(conn.isDeviceConnectedProvider);

    if (isConnected) {
      return widget.screen;
    }

    if (_popScheduled) {
      return const SizedBox.shrink();
    }
    _popScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppLogging.connection(
        'PROTECTED_ROUTE_POP route=${widget.routeName} method=popUntil(isFirst) '
        '(device disconnected)',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
    return const SizedBox.shrink();
  }
}

/// Loader widget that fetches signal data and navigates to SignalDetailScreen
class _SignalDetailLoader extends ConsumerWidget {
  final String signalId;

  const _SignalDetailLoader({required this.signalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deepLinkLoadingSignal)),
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
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    context.l10n.deepLinkErrorLoadingSignal(
                      '${snapshot.error}',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonGoBack),
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
                  const SizedBox(height: AppTheme.spacing16),
                  Text(context.l10n.deepLinkSignalNotFound),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonGoBack),
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

/// Loader widget that fetches an Aether flight by share ID and navigates
/// to [AetherFlightDetailScreen].
class _AetherFlightDeepLinkLoader extends ConsumerWidget {
  final String shareId;

  const _AetherFlightDeepLinkLoader({required this.shareId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deepLinkLoadingFlight)),
      body: FutureBuilder<AetherFlight>(
        future: ref.read(aetherShareServiceProvider).fetchFlight(shareId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    snapshot.hasError
                        ? context.l10n.deepLinkErrorLoadingFlight(
                            '${snapshot.error}',
                          )
                        : context.l10n.deepLinkFlightNotFound,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonGoBack),
                  ),
                ],
              ),
            );
          }

          final flight = snapshot.data!;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = navigatorKey.currentState;
            if (navigator == null) return;
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => AetherFlightDetailScreen(flight: flight),
              ),
            );
          });

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

/// Loader widget that fetches a shared channel securely from Firestore.
/// Decrypts the PSK from the user's encrypted key blob.
class _ChannelImportLoader extends ConsumerWidget {
  final String firestoreId;

  const _ChannelImportLoader({required this.firestoreId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cryptoService = ref.read(channelCryptoServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deepLinkImportChannel)),
      body: FutureBuilder<ChannelConfig?>(
        future: cryptoService.fetchSecureChannel(firestoreId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    context.l10n.deepLinkErrorLoadingChannel(
                      '${snapshot.error}',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonGoBack),
                  ),
                ],
              ),
            );
          }

          final channel = snapshot.data;
          if (channel == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(context.l10n.deepLinkChannelNotAvailable),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    context.l10n.deepLinkChannelNotAvailableDescription,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonGoBack),
                  ),
                ],
              ),
            );
          }

          // Navigate to channel form for import.
          // Zero out positionPrecision — it is a per-device preference and
          // must not propagate from the sharer to the recipient.
          final importChannel = channel.copyWith(positionPrecision: 0);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = navigatorKey.currentState;
            if (navigator == null) return;
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => ChannelFormScreen(
                  existingChannel: importChannel,
                  channelIndex: importChannel.index,
                ),
              ),
            );
          });

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

/// Redeems a channel invite link and joins the channel.
///
/// Flow:
/// 1. Calls `redeemChannelInvite` Cloud Function
/// 2. On success, fetches the decrypted PSK via `ChannelCryptoService`
/// 3. Navigates to `ChannelFormScreen` with the imported channel
class _ChannelInviteRedeemer extends ConsumerStatefulWidget {
  final String inviteId;
  final String inviteSecret;

  const _ChannelInviteRedeemer({
    required this.inviteId,
    required this.inviteSecret,
  });

  @override
  ConsumerState<_ChannelInviteRedeemer> createState() =>
      _ChannelInviteRedeemerState();
}

class _ChannelInviteRedeemerState extends ConsumerState<_ChannelInviteRedeemer>
    with LifecycleSafeMixin<_ChannelInviteRedeemer> {
  late Future<void> _redeemFuture;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _redeemFuture = _redeem();
  }

  Future<void> _redeem() async {
    try {
      final inviteService = ref.read(channelInviteServiceProvider);
      final result = await inviteService.redeemInvite(
        inviteId: widget.inviteId,
        inviteSecret: widget.inviteSecret,
      );

      if (!canUpdateUI) return;

      if (result.alreadyMember) {
        // Check if the channel actually exists locally — user may have
        // deleted it from the device but their Firestore membership remains.
        final localChannels = ref.read(channelsProvider);
        final stillLocal = localChannels.any(
          (c) =>
              c.name == result.channel.name &&
              c.name.isNotEmpty &&
              c.role != 'DISABLED',
        );

        if (stillLocal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = navigatorKey.currentState;
            if (navigator == null) return;
            navigator.pop();
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              showInfoSnackBar(ctx, ctx.l10n.deepLinkAlreadyHaveChannel);
            }
          });
          return;
        }
        // Channel was deleted locally — fall through to re-add it
      }

      // Fetch the decrypted channel (key blob was written by the server)
      final cryptoService = ref.read(channelCryptoServiceProvider);
      final channel = await cryptoService.fetchSecureChannel(result.channelId);

      if (!canUpdateUI) return;

      if (channel == null) {
        setState(() => _error = Exception('could not decrypt'));
        return;
      }

      // Navigate to channel form.
      // Zero out positionPrecision — it is a per-device preference and must
      // not propagate from the sharer to the recipient.
      final importChannel = channel.copyWith(positionPrecision: 0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = navigatorKey.currentState;
        if (navigator == null) return;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChannelFormScreen(
              existingChannel: importChannel,
              channelIndex: importChannel.index,
            ),
          ),
        );
      });
    } catch (e) {
      AppLogging.channels('[ChannelInvite] Redemption failed: $e');
      if (!canUpdateUI) return;
      setState(() => _error = e);
    }
  }

  String _friendlyError(Object error, AppLocalizations l10n) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('expired')) return l10n.deepLinkInviteExpired;
    if (msg.contains('revoked')) return l10n.deepLinkInviteRevoked;
    if (msg.contains('maximum')) {
      return l10n.deepLinkInviteUsageLimitReached;
    }
    if (msg.contains('invalid invite secret')) {
      return l10n.deepLinkInviteLinkInvalid;
    }
    if (msg.contains('channel no longer exists') ||
        msg.contains('channel not found')) {
      return l10n.deepLinkChannelNoLongerExists;
    }
    if (msg.contains('not-found') || msg.contains('not found')) {
      return l10n.deepLinkInviteNotFound;
    }
    if (msg.contains('unauthenticated')) return l10n.deepLinkPleaseSignIn;
    return l10n.deepLinkFailedToJoinChannel;
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold.body(
      title: context.l10n.deepLinkJoinChannel,
      body: FutureBuilder<void>(
        future: _redeemFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: SnackBarType.error.iconColor.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radius20),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 32,
                        color: SnackBarType.error.iconColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    Text(
                      _friendlyError(_error!, context.l10n),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        side: BorderSide(color: context.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                        ),
                      ),
                      child: Text(context.l10n.commonGoBack),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LoadingIndicator(size: 32, strokeWidth: 3),
                const SizedBox(height: AppTheme.spacing20),
                Text(
                  context.l10n.deepLinkJoiningChannel,
                  style: TextStyle(fontSize: 15, color: context.textSecondary),
                ),
              ],
            ),
          );
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

class _WidgetDetailLoaderState extends ConsumerState<_WidgetDetailLoader>
    with LifecycleSafeMixin<_WidgetDetailLoader> {
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
          _error = 'widget_not_found';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogging.widgets('[WidgetDetailLoader] Error loading widget: $e');
      if (mounted) {
        setState(() {
          _error = '$e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.deepLinkLoadingWidget)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      final errorText = _error == 'widget_not_found'
          ? context.l10n.deepLinkWidgetNotFound
          : context.l10n.deepLinkErrorLoadingWidget(_error!);
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.deepLinkLoadingWidget)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(errorText),
              const SizedBox(height: AppTheme.spacing16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonGoBack),
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
        appBar: AppBar(title: Text(context.l10n.deepLinkLoadingWidget)),
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
        appBar: AppBar(title: Text(context.l10n.deepLinkLoadingWidget)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Shouldn't reach here
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deepLinkLoadingWidget)),
      body: Center(child: Text(context.l10n.deepLinkSomethingWentWrong)),
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
      appBar: AppBar(
        title: Text(context.l10n.deepLinkProfileTitle(displayName)),
      ),
      body: profileSyncService == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(context.l10n.deepLinkCloudServicesNotAvailable),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonGoBack),
                  ),
                ],
              ),
            )
          : FutureBuilder<String?>(
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
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppTheme.errorRed,
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Text(
                          context.l10n.deepLinkErrorLookingUpUser(
                            '${snapshot.error}',
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(context.l10n.commonGoBack),
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
                        const SizedBox(height: AppTheme.spacing16),
                        Text(context.l10n.deepLinkUserNotFound(displayName)),
                        const SizedBox(height: AppTheme.spacing16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(context.l10n.commonGoBack),
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

/// App router handles initialization and navigation flow
/// NOTE: With deferred connection, MainShell is shown as soon as app is 'ready'.
/// Device connection happens asynchronously via DeviceConnectionNotifier.
class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter({super.key});

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
    // Diagnostic listeners. `ref.watch(appShellProvider)` in build()
    // is the actual rebuild driver; these listeners just log
    // transitions so the route changes are observable in the log.
    //
    // History note: this State used to also force `setState()` from
    // multiple layers of listeners (appShell + flow + appInit) as a
    // fail-safe for a dispose-race where `ref.watch` dep tracking
    // could go silent after navigator dances like
    // `pushNamedAndRemoveUntil('/app', ...)`. That entire class of
    // bug was retired in two stages:
    //   1. All `pushNamedAndRemoveUntil('/app')` callsites became
    //      `popUntil((r) => r.isFirst)`, so there's no more route-stack
    //      swap that triggers the dep-tracking reset.
    //   2. The onboarding flow's region states (regionRequired /
    //      writingRegion / awaitingReboot / awaitingReconnect /
    //      awaitingReadiness) were collapsed into a direct
    //      `connecting -> checkingConfig -> ready` flow. Region
    //      selection lives entirely on MainShell's inline picker now,
    //      driven by `needsRegionSetupProvider`. AppRouter only
    //      switches between `splash | scanner | mainShell`, which is
    //      a tiny shell graph that `ref.watch` handles without help.
    ref.listenManual<AppInitState>(appInitProvider, (previous, next) {
      AppLogging.connection(
        'APP_ROUTER_LISTEN: appInit prev=$previous next=$next '
        'hashCode=$hashCode',
      );
    });
    ref.listenManual<AppShellResolution>(appShellProvider, (previous, next) {
      AppLogging.connection(
        'APP_ROUTER_LISTEN: appShell '
        'prev=${previous?.shell.name}/${previous?.reason} '
        'next=${next.shell.name}/${next.reason} '
        'hashCode=$hashCode',
      );
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
    // Diagnostic that fires on EVERY build, before any provider read.
    // Pairs with APP_SHELL below so we can distinguish "_AppRouter
    // never rebuilt" from "_AppRouter rebuilt but provider returned
    // unexpected shell".
    AppLogging.connection('🎯 _AppRouter: build entry hashCode=$hashCode');

    // Also peek the canonical signal feeds so the next log line lets
    // us correlate widget-tree vs provider state without needing to
    // query the device live.
    final appInitSnapshot = ref.read(appInitProvider);
    AppLogging.connection(
      '🎯 _AppRouter: build appInit=$appInitSnapshot hashCode=$hashCode',
    );

    // Single source of truth for shell selection. Combines
    // appInitProvider (boot lifecycle) with the onboarding flow
    // coordinator so Scanner/Region/MainShell ownership lives in
    // one declarative mapper instead of being split across widgets,
    // notifiers, and a Navigator.push/pop dance.
    final resolution = ref.watch(appShellProvider);

    // Check readiness whenever state changes
    if (resolution.shell == AppShell.mainShell) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(deepLinkReadyProvider.notifier).setReady();
        }
      });
    }

    AppLogging.connection(
      'APP_SHELL: route=${resolution.shell.name} '
      'reason=${resolution.reason} hashCode=$hashCode',
    );

    switch (resolution.shell) {
      case AppShell.splash:
        return const _SplashScreen();
      case AppShell.error:
        return const _ErrorScreen();
      case AppShell.ageEligibility:
        return const EligibilityGateScreen();
      case AppShell.onboarding:
        return const OnboardingScreen();
      case AppShell.termsAcceptance:
        return const LegalAcceptanceScreen();
      case AppShell.scanner:
        return const ScannerScreen();
      case AppShell.mainShell:
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
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(disableAnimations: false),
      child: Scaffold(
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
              data: (version) =>
                  'SocialMesh v$version', // lint-allow: hardcoded-string
              loading: () => 'SocialMesh',
              error: (_, _) => 'SocialMesh',
            );

            return Container(
              color: context.background,
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 16),
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
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      '© 2026 SocialMesh. All rights reserved.',
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
              borderRadius: BorderRadius.circular(AppTheme.radius16),
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
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
              padding: const EdgeInsets.all(AppTheme.spacing12),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_tethering,
                            color: context.accentColor,
                            size: 10,
                          ),
                          const SizedBox(width: AppTheme.spacing4),
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
                      final displayText = safeTruncateCodeUnits(
                        displayName,
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
                  const SizedBox(height: AppTheme.spacing4),
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
      return const SizedBox(height: AppTheme.spacing12);
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
                borderRadius: BorderRadius.circular(AppTheme.radius10),
              ),
              child: Center(
                child: shortName.isNotEmpty
                    ? Text(
                        safeTruncate(shortName, 2),
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(Icons.person, color: context.accentColor, size: 18),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
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
                    '!$nodeId', // lint-allow: hardcoded-string
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
                borderRadius: BorderRadius.circular(AppTheme.radius6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar, size: 12, color: context.accentColor),
                  SizedBox(width: AppTheme.spacing4),
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
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: AppTheme.spacing24),
              Text(
                'Something went wrong', // lint-allow: hardcoded-string
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'Failed to initialize the app. Please try again.', // lint-allow: hardcoded-string
                style: context.titleSmallStyle?.copyWith(
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppTheme.spacing32),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(context.l10n.commonRetry),
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
