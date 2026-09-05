// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'radio_scope_providers.dart';
import '../config/admin_config.dart';

import '../core/ble_system_devices.dart';
import '../core/boot_timeline.dart';
import '../core/constants.dart';
import '../core/logging.dart';
import '../core/radio_scope.dart';
import '../core/platform/noop_device_transport.dart';
import '../core/platform/platform_capabilities.dart';
import '../core/platform/platform_capabilities_provider.dart';
import '../core/safety/error_handler.dart';
import '../core/transport.dart';
import '../core/units/distance_format.dart';
import '../dev/demo/demo.dart';
import '../services/transport/ble_transport.dart';
import '../services/transport/network_transport.dart';
import '../services/transport/usb_transport_factory.dart';
import '../services/backup/device_config_backup_service.dart';
import '../services/carplay/carplay_feature_flags.dart';
import '../services/protocol/admin_target.dart';
import '../services/protocol/meshtastic_readiness_flag.dart';
import '../services/protocol/protocol_service.dart';
import '../services/protocol/reticulum/reticulum_fragment_event.dart';
import '../services/storage/storage_service.dart';
import '../services/storage/message_database.dart';
import '../services/mesh_packet_dedupe_store.dart';
import '../services/notifications/notification_service.dart';
import '../services/messaging/offline_queue_service.dart';
import '../l10n/l10n_utils.dart';
import '../services/location/location_service.dart';
import '../services/location/phone_position_governor.dart';
import '../services/live_activity/live_activity_service.dart';
import '../models/presence_confidence.dart';
import '../services/nodes/node_identity_store.dart';
import '../features/nodes/node_display_name_resolver.dart';
import '../services/ifttt/ifttt_service.dart';
import '../services/notifications/push_notification_service.dart';
import '../services/messaging/message_utils.dart';
import '../services/bug_report_service.dart';
import '../services/config/mesh_firestore_config_service.dart';
import '../features/automations/automation_providers.dart';
import '../features/automations/automation_engine.dart';
import '../features/nodedex/providers/nodedex_providers.dart';
import '../features/widget_builder/storage/widget_storage_service.dart';
import '../features/widget_builder/widget_sync_providers.dart';
import 'cloud_sync_entitlement_providers.dart';
import 'reticulum_providers.dart';
import '../core/auth/claims_provider.dart';
import '../models/mesh_models.dart';
import '../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../generated/meshtastic/mesh.pb.dart' as mesh_pb;
import 'meshcore_providers.dart';
import 'social_providers.dart';
import '../services/meshcore/connection_coordinator.dart'
    show MeshCoreTcpDeviceId;
import 'connection_providers.dart';
import 'age_eligibility_provider.dart';
import 'file_transfer_providers.dart';
import 'mqtt_client_proxy_providers.dart';
import 'peer_safety_providers.dart';
import '../services/messaging/dm_retry_coordinator.dart';
import '../services/notifications/channel_mute_prefs.dart';
import '../features/settings/background_connection_screen.dart'
    show
        kLiveActivityEnabled,
        kLiveActivityDestination,
        LiveActivityDestination;
import 'sip_providers.dart';
import '../services/protocol/sip/sip_dm.dart';

// App initialization state - purely about app lifecycle, NOT device connection
// Device connection is handled separately by DeviceConnectionNotifier in connection_providers.dart
enum AppInitState {
  uninitialized,
  initializing,
  ready, // App services loaded, UI can be shown (renamed from initialized)
  needsAgeEligibility, // User has not confirmed 16+ or policy version bumped
  needsOnboarding,
  needsTermsAcceptance, // Terms version changed or never accepted
  needsScanner, // First launch after onboarding, need to pair a device
  error,
  // REMOVED: needsRegionSetup - handled by MainShell when connected
  // Note: 'initialized' renamed to 'ready' to clarify it's about app, not device
}

class AppInitNotifier extends Notifier<AppInitState> {
  /// Guard to prevent _initializeBackgroundServices() from running more than
  /// once. Without this, each call to initialize() (onboarding, terms
  /// acceptance, etc.) fires a new background-services pass that eventually
  /// calls startBackgroundConnection() — which can disconnect an already-live
  /// connection and create a cascade of reconnect cycles.
  bool _backgroundServicesStarted = false;

  /// Device-connection init completion, tracked separately from
  /// [_backgroundServicesStarted]. One-time services must never re-run,
  /// but a device-connection init that threw must stay retryable on the
  /// next initialize() call — otherwise a transient failure here kills
  /// auto-reconnect for the entire session. Set only after the init block
  /// completes without throwing (the already-connected skip and the
  /// autoReconnect-disabled path both count as successful completion).
  bool _deviceConnectionInitDone = false;
  bool _deviceConnectionInitInFlight = false;

  /// Centralised state setter with logging for every transition.
  void _transition(AppInitState to, [String caller = '']) {
    final from = state;
    state = to;
    AppLogging.connection(
      '🎯 AppInitNotifier: $from → $to${caller.isNotEmpty ? ' ($caller)' : ''}',
    );
  }

  @override
  AppInitState build() {
    AppLogging.connection(
      '🎯 AppInitNotifier.build() called '
      '(backgroundServicesStarted=$_backgroundServicesStarted)',
    );
    return AppInitState.uninitialized;
  }

  /// Manually set state to ready (e.g., after successful connection from scanner)
  void setReady() {
    _transition(AppInitState.ready, 'setReady');
  }

  /// Alias for backward compatibility
  void setInitialized() => setReady();

  /// Set state to needsScanner (e.g., first launch after onboarding)
  void setNeedsScanner() {
    _transition(AppInitState.needsScanner, 'setNeedsScanner');
  }

  /// Test seam: force any [AppInitState] without going through the
  /// production transition gates. Used by appShellProvider tests
  /// that need to drive the splash / age / error / terms-acceptance
  /// gates which the production API does not expose.
  @visibleForTesting
  void debugForceStateForTesting(AppInitState forced) {
    _transition(forced, 'debugForceStateForTesting');
  }

  /// Initialize core app services (NO device connection here).
  /// Device connection is handled asynchronously by DeviceConnectionNotifier.
  Future<void> initialize() async {
    if (state == AppInitState.initializing) {
      AppLogging.connection(
        '🎯 AppInitNotifier.initialize() SKIPPED — already initializing',
      );
      return;
    }

    _transition(AppInitState.initializing, 'initialize');
    try {
      // Phase 1: Critical services (fast, <500ms target)
      // Initialize notification service. Gated on capability: on platforms
      // without notifications (web today, desktop pending wiring) this
      // call would reach dart:io Platform.is* internally and crash boot.
      final caps = ref.read(platformCapabilitiesProvider);
      if (caps.supportsNotifications) {
        await NotificationService().initialize();
        // Launch-time clear-on-open: a cold start never fires a `resumed`
        // lifecycle transition, so without this a badge set during the
        // previous background session would survive the relaunch. cancelAll
        // inside clearBadge does not erase the plugin's launch details, so
        // cold-start notification tap routing is unaffected.
        await NotificationService().clearBadge();
      } else {
        AppLogging.platform(
          'AppInit: notifications unsupported on ${caps.platformFamily.name} - skipping NotificationService init',
        );
      }
      BootTimeline.instance.mark('appInit_notifications');

      // Initialize storage services
      final settings = await ref.read(settingsServiceProvider.future);
      BootTimeline.instance.mark('appInit_settings');

      // Check age eligibility FIRST — must confirm 16+ before anything else
      final ageState = await ref.read(ageEligibilityProvider.future);
      BootTimeline.instance.mark('appInit_age');
      if (ageState.needsConfirmation) {
        _transition(
          AppInitState.needsAgeEligibility,
          'initialize:needsAgeEligibility', // lint-allow: hardcoded-string
        );
        return;
      }

      // Check for onboarding completion FIRST
      if (!settings.onboardingComplete) {
        _transition(
          AppInitState.needsOnboarding,
          'initialize:!onboardingComplete', // lint-allow: hardcoded-string
        );
        return;
      }

      // Terms acceptance is NOT checked here — it is gated in _AppRouter
      // when state is ready, so that terms appear AFTER device setup
      // (scanner + region select) but BEFORE the main shell. Returning
      // users with a terms version bump will hit the gate there.

      // Check if device was ever paired
      final lastDeviceId = settings.lastDeviceId;
      final hasEverPaired = lastDeviceId != null;

      // Restore transport type from persisted lastDeviceType BEFORE any
      // auto-reconnect path fires. On cold start transportTypeProvider
      // defaults to BLE — a TCP last-device would otherwise route
      // through the BLE scan loop looking for a `tcp:...` id and spin
      // at "Connecting…" indefinitely. This sync does NOT classify or
      // clear anything; it simply aligns the transport provider with
      // the persisted target family.
      if (hasEverPaired) {
        restoreTransportTypeFromSettings(ref, settings);
      }

      // Phase 2: Background services (can complete after UI shows)
      // These run in parallel but don't block app ready state.
      // Guarded so only the first initialize() call triggers them —
      // subsequent calls (e.g. from terms acceptance) skip this to
      // avoid duplicate startBackgroundConnection() disrupting an
      // already-active connection.
      if (!_backgroundServicesStarted) {
        _backgroundServicesStarted = true;
        _initializeBackgroundServices();
      } else if (!_deviceConnectionInitDone) {
        // One-time services already ran (or are running), but the
        // device-connection init failed on a previous pass. Retry just
        // that block; the in-flight guard inside makes an overlap with a
        // still-running first pass a no-op.
        AppLogging.connection(
          '🎯 AppInitNotifier: retrying device-connection init '
          '(previous attempt did not complete)',
        );
        _startDeviceConnectionInit();
      }

      // Determine initial state based on whether user has ever paired
      // AND whether auto-reconnect is enabled
      if (hasEverPaired) {
        // User has paired before - check if auto-reconnect is enabled
        if (settings.autoReconnect) {
          // Auto-reconnect enabled - go to main UI, connection happens in background
          _transition(AppInitState.ready, 'initialize:paired+autoReconnect');
          AppLogging.connection(BootTimeline.instance.summary('appInit_ready'));
        } else {
          // Auto-reconnect disabled - go to scanner so user can manually connect
          // This respects the user's choice to not auto-connect
          _transition(
            AppInitState.needsScanner,
            'initialize:paired+noAutoReconnect', // lint-allow: hardcoded-string
          );
        }
      } else {
        // Never paired - need to go through scanner first
        _transition(AppInitState.needsScanner, 'initialize:noPreviousDevice');
      }
    } catch (e) {
      AppLogging.debug('App initialization failed: $e');
      _transition(AppInitState.error, 'initialize:error($e)');
    }
  }

  /// Initialize non-critical services in background
  Future<void> _initializeBackgroundServices() async {
    try {
      // Eagerly activate the file transfer engine FIRST, before any
      // async work. The engine wires a stream listener on the protocol
      // service's broadcast StreamController — if this runs late (after
      // slow DB opens below), incoming file-transfer packets are silently
      // dropped because broadcast streams discard events with no listener.
      // This MUST be synchronous (ref.read, not await) and at the top.
      try {
        ref.read(fileTransferEngineProvider);
        AppLogging.fileTransfer(
          'Engine eagerly initialised during background init',
        );
      } catch (e) {
        AppLogging.fileTransfer('Eager engine init failed: $e');
      }

      // These can complete after UI is shown.
      // Each is in its own try/catch so a single failure does NOT prevent
      // the device-connection code below from running. Without this,
      // a corrupt DB, failed migration, or hanging platform channel
      // silently kills auto-reconnect for the entire session.
      try {
        await ref.read(messageStorageProvider.future);
      } catch (e) {
        AppLogging.debug('Message storage init failed: $e');
      }
      try {
        await ref.read(nodeStorageProvider.future);
      } catch (e) {
        AppLogging.debug('Node storage init failed: $e');
      }
      try {
        await ref.read(iftttServiceProvider).init();
      } catch (e) {
        AppLogging.debug('IFTTT service init failed: $e');
      }
      try {
        await ref.read(automationEngineInitProvider.future);
      } catch (e) {
        AppLogging.debug('Automation engine init failed: $e');
      }

      // Eagerly activate the org claims provider so cached claims are
      // available immediately for enterprise query layers.
      ref.read(claimsProvider);

      // Eagerly activate Cloud Sync services so they start on login,
      // not only when the user navigates to specific screens.
      // Without this, sync only fires when a screen watches the provider
      // (e.g. widget sync only ran when the dashboard rendered custom widgets).
      try {
        AppLogging.sync('[AppInit] Eagerly activating Automation sync...');
        await ref.read(automationStoreProvider.future);
        final autoSync = ref.read(automationSyncServiceProvider);
        AppLogging.sync(
          '[AppInit] Automation sync service eagerly activated '
          '(service=${autoSync != null ? "created" : "NULL"})',
        );
        AppLogging.debug('Automation sync service eagerly activated');
      } catch (e) {
        AppLogging.sync('[AppInit] Automation sync eager init FAILED: $e');
        AppLogging.debug('Automation sync eager init skipped: $e');
      }
      try {
        AppLogging.sync(
          '[AppInit] Step 1/3: Awaiting widgetSqliteStoreProvider...',
        );
        final store = await ref.read(widgetSqliteStoreProvider.future);
        AppLogging.sync(
          '[AppInit] Step 1/3 OK: WidgetSqliteStore ready '
          '(hashCode=${identityHashCode(store)}, '
          'syncEnabled=${store.syncEnabled}, '
          'count=${store.count})',
        );

        // Resolve the storage service BEFORE starting sync — this runs
        // the one-time SharedPreferences → SQLite migration which calls
        // enqueueAllForSync(), ensuring migrated widgets are in the outbox
        // before the first sync cycle drains it.
        AppLogging.sync(
          '[AppInit] Step 2/3: Awaiting widgetStorageServiceProvider (migration)...',
        );
        await ref.read(widgetStorageServiceProvider.future);
        AppLogging.sync(
          '[AppInit] Step 2/3 OK: WidgetStorageService ready '
          '(hasStore=${WidgetStorageService.hasStore}, '
          'store.syncEnabled=${store.syncEnabled}, '
          'store.count=${store.count})',
        );

        AppLogging.sync(
          '[AppInit] Step 3/3: Reading widgetSyncServiceProvider...',
        );
        final canWrite = ref.read(canCloudSyncWriteProvider);
        AppLogging.sync(
          '[AppInit] Step 3/3: canCloudSyncWriteProvider = $canWrite',
        );
        final widgetSync = ref.read(widgetSyncServiceProvider);
        AppLogging.sync(
          '[AppInit] Step 3/3 OK: widgetSyncServiceProvider returned '
          '${widgetSync != null ? "WidgetSyncService(hashCode=${identityHashCode(widgetSync)}, enabled=${widgetSync.isEnabled})" : "NULL — SYNC IS DISABLED!"} '
          'store.syncEnabled=${store.syncEnabled}',
        );
        if (widgetSync == null) {
          AppLogging.sync(
            '[AppInit] WARNING: Widget sync service is NULL! '
            'Possible causes: store not ready, entitlement not resolved. '
            'canWrite=$canWrite',
          );
        }
        AppLogging.debug('Widget sync service eagerly activated');
      } catch (e, stack) {
        AppLogging.sync('[AppInit] Widget sync eager init FAILED: $e');
        AppLogging.sync('[AppInit] Widget sync failure stack: $stack');
        AppLogging.debug('Widget sync eager init skipped: $e');
      }

      AppLogging.debug('Background services initialized');
    } catch (e) {
      // Non-critical, log but don't fail — device connection below still runs.
      AppLogging.debug('Background service init error: $e');
    }

    await _startDeviceConnectionInit();

    // MQTT client proxy: eagerly activate so it starts relaying when
    // the device sends an MQTT config with proxyToClientEnabled=true.
    try {
      ref.read(mqttClientProxyForwarderProvider);
      ref.read(mqttClientProxyAutoConnectProvider);
      AppLogging.mqttProxy('Client proxy providers activated');
    } catch (e) {
      AppLogging.mqttProxy('Client proxy activation failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Device connection: runs OUTSIDE the storage/sync try-catch so that a
  // failed DB open or hanging platform channel can never silently prevent
  // auto-reconnect. This is the #1 user-visible consequence of the old
  // structure — the user stays on "Disconnected" with no reconnect attempt.
  //
  // This block only reads the device-connection notifier; it never
  // re-registers stream listeners or re-creates one-time services, so a
  // retry from initialize() cannot duplicate side effects. Overlap with
  // an explicit or resume-triggered restore is deduped downstream by
  // RestoreSessionCoordinator's single-flight guard.
  // ---------------------------------------------------------------------
  Future<void> _startDeviceConnectionInit() async {
    if (_deviceConnectionInitInFlight) return;
    _deviceConnectionInitInFlight = true;
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      if (settings.autoReconnect && settings.lastDeviceId != null) {
        // Skip if the device is already connected (e.g. the scanner
        // established a live connection during onboarding before this
        // background init finished). Without this check,
        // startBackgroundConnection()'s aggressive BLE cleanup would
        // disconnect the active connection, triggering a cascade of
        // reconnect cycles that can leave the app stuck.
        final connState = ref.read(deviceConnectionProvider);
        if (connState.isConnected ||
            connState.state == DevicePairingState.configuring) {
          AppLogging.debug(
            '🔄 AppInitNotifier: Device already connected/configuring — '
            'skipping background connection',
          );
        } else {
          AppLogging.debug(
            '🔄 AppInitNotifier: Starting background device connection...',
          );
          // Initialize and start background connection via the new notifier
          await ref.read(deviceConnectionProvider.notifier).initialize();
          ref
              .read(deviceConnectionProvider.notifier)
              .startBackgroundConnection();
        }
      }
      _deviceConnectionInitDone = true;
    } catch (e) {
      // Done flag stays false so the next initialize() call retries.
      // Retries fire only on external initialize() triggers, never on a
      // timer, so a persistently failing init cannot loop.
      AppLogging.debug('Background device connection init error: $e');
    } finally {
      _deviceConnectionInitInFlight = false;
    }
  }
}

/// Check data integrity after connection and clear stale data if needed.
final appInitProvider = NotifierProvider<AppInitNotifier, AppInitState>(
  AppInitNotifier.new,
);

// Storage services
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Settings refresh trigger - increment this to force settings UI to rebuild
class SettingsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final settingsRefreshProvider = NotifierProvider<SettingsRefreshNotifier, int>(
  SettingsRefreshNotifier.new,
);

/// App version info from pubspec.yaml
final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  // Just show version - build number is omitted since we use semantic versioning only
  return packageInfo.version;
});

/// Cached settings service instance
SettingsService? _cachedSettingsService;

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  // Watch the refresh trigger to rebuild when settings change
  ref.watch(settingsRefreshProvider);

  // Return cached instance if available (already initialized)
  if (_cachedSettingsService != null) {
    // Sync AdminConfig static flags with persisted settings
    AdminConfig.setEnabled(_cachedSettingsService!.adminModeEnabled);
    AdminConfig.setPremiumUpsellEnabled(
      _cachedSettingsService!.premiumUpsellEnabled,
    );
    return _cachedSettingsService!;
  }

  final service = SettingsService();
  await service.init();
  _cachedSettingsService = service;

  // Initialize AdminConfig static flags from persisted settings
  AdminConfig.setEnabled(service.adminModeEnabled);
  AdminConfig.setPremiumUpsellEnabled(service.premiumUpsellEnabled);

  return service;
});

final bugReportServiceProvider = Provider<BugReportService>((ref) {
  final service = BugReportService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for animations enabled setting (optimized for frequent access)
final animationsEnabledProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.animationsEnabled,
    orElse: () => true,
  );
});

/// Provider for 3D animations enabled setting (optimized for frequent access)
final animations3DEnabledProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.animations3DEnabled,
    orElse: () => true,
  );
});

/// Debug setting: mesh-only mode for signals (disable cloud features).
final meshOnlyDebugModeProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.meshOnlyDebugMode,
    orElse: () => false,
  );
});

/// Debug setting: premium upsell mode (explore features before purchase).
/// When enabled, users can navigate to premium features but see upsell on actions.
final premiumUpsellEnabledProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.premiumUpsellEnabled,
    orElse: () => false,
  );
});

/// Real-time Firestore config watcher - syncs remote config changes to local storage.
/// This allows admin to change config in Firestore console and have it apply globally.
/// Watch this provider from a widget that's always mounted (e.g., MainShell).
final firestoreConfigWatcherProvider = StreamProvider<MeshConfigData?>((
  ref,
) async* {
  // Wait for settings service to be ready. Read, not watch: this provider
  // invalidates settingsServiceProvider below to notify its watchers, and
  // watching it here would dispose this stream mid-loop on every sync.
  // The service instance is a cached singleton, so a one-time read is safe.
  final settingsService = await ref.read(settingsServiceProvider.future);

  // Initialize Firestore service if needed
  await MeshFirestoreConfigService.instance.initialize();

  if (!MeshFirestoreConfigService.instance.isAvailable) {
    AppLogging.settings('⚠️ Firestore not available for config watching');
    yield null;
    return;
  }

  AppLogging.settings('👀 Starting real-time Firestore config watcher');

  await for (final config in MeshFirestoreConfigService.instance.configStream) {
    if (config != null) {
      // Sync premium upsell flag to local storage
      final currentValue = settingsService.premiumUpsellEnabled;
      if (config.premiumUpsellEnabled != currentValue) {
        AppLogging.settings(
          '🔄 Syncing premiumUpsellEnabled: $currentValue -> ${config.premiumUpsellEnabled}',
        );
        await settingsService.setPremiumUpsellEnabled(
          config.premiumUpsellEnabled,
        );
        // Update AdminConfig static flag
        AdminConfig.setPremiumUpsellEnabled(config.premiumUpsellEnabled);
        if (!ref.mounted) return;
        // Invalidate settings provider to trigger rebuild
        ref.invalidate(settingsServiceProvider);
      }

      // Sync premium gated features map to local storage
      final prefs = await SharedPreferences.getInstance();
      final featuresJson = config.premiumGatedFeatures.entries
          .map((e) => '${e.key}:${e.value}')
          .join(',');
      await prefs.setString('premium_gated_features', featuresJson);
      AppLogging.settings('🔄 Synced premium gated features: $featuresJson');

      // Reload SharedPreferences to ensure cached values are updated
      await prefs.reload();
      if (!ref.mounted) return;

      // Trigger refresh for any providers watching premium feature gates
      ref.read(premiumGatedFeaturesRefreshProvider.notifier).refresh();
    }
    yield config;
  }
});

/// Trigger to force premium gated features to refresh
/// Incremented when Firestore sync updates the SharedPreferences
class PremiumGatedFeaturesRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final premiumGatedFeaturesRefreshProvider =
    NotifierProvider<PremiumGatedFeaturesRefreshNotifier, int>(
      PremiumGatedFeaturesRefreshNotifier.new,
    );

/// Check if a premium feature should show the "Try It" upsell popup.
/// This does NOT control whether the feature is gated - features are ALWAYS premium-gated.
/// This only controls whether to show the promotional "Try It" upsell when blocked.
///
/// Firestore values:
/// - `customRingtones: true` = Show "Try It" upsell when user taps
/// - `customRingtones: false` = Don't show upsell (silently block)
///
/// Usage: After checking premium, show upsell only if this returns true.
final premiumFeatureGateProvider = Provider.family<bool, String>((
  ref,
  featureKey,
) {
  // Translation Pack is sold separately (not part of Complete Pack) —
  // it uses a standard price badge, not the "Try It" upsell flow.
  if (featureKey == 'translation') return false;

  // Watch refresh trigger to rebuild when Firestore syncs new values
  ref.watch(premiumGatedFeaturesRefreshProvider);

  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) {
      // Global kill switch - if premium upsell is disabled, all features are free
      if (!settings.premiumUpsellEnabled) return false;

      // Check granular feature gate from SharedPreferences (sync read)
      // This is safe because SharedPreferences caches values in memory after first load
      try {
        // Note: Using synchronous access - SharedPreferences is already initialized
        // by this point via settingsServiceProvider
        final featuresJson =
            settings.prefs.getString('premium_gated_features') ?? '';
        if (featuresJson.isEmpty) {
          return true; // Gate by default if no config
        }

        final features = Map<String, bool>.fromEntries(
          featuresJson.split(',').where((s) => s.contains(':')).map((entry) {
            final parts = entry.split(':');
            return MapEntry(parts[0], parts[1] == 'true');
          }),
        );

        // Firestore: true = show upsell, false = don't show
        // Return the value directly (default to true if not found)
        return features[featureKey] ?? true;
      } catch (e) {
        AppLogging.settings('⚠️ Failed to parse premium gated features: $e');
        return true; // Gate by default on error
      }
    },
    orElse: () => true, // Gate by default if settings not loaded
  );
});

/// Debug setting: admin mode enabled (full debug features visible).
/// Unlocked via secret 7-tap gesture + PIN, persisted in SharedPreferences.
final adminModeEnabledProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.adminModeEnabled,
    orElse: () => false,
  );
});

/// Debug setting: show all BLE devices in scanner (dev mode only).
/// When enabled, scanner shows ALL BLE devices regardless of protocol detection.
final showAllBleDevicesProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.showAllBleDevices,
    orElse: () => false,
  );
});

// Message storage service (SQLite-backed)
//
// Radio-scoped: watching radioScopeProvider reopens the database against the
// connected radio's own file, and rebuilds MessagesNotifier off it.
final messageStorageProvider = FutureProvider<MessageDatabase>((ref) async {
  ref.watch(radioScopeProvider);
  final service = MessageDatabase();
  await service.init();
  bindStoreToRadioScope(ref, service, service.close);
  return service;
});

// Node storage service - persists nodes and positions
final nodeStorageProvider = FutureProvider<NodeStorageService>((ref) async {
  ref.watch(radioScopeProvider);
  final service = NodeStorageService();
  await service.init();
  return service;
});

// Node identity store - persists node long/short names separately
final nodeIdentityStoreProvider = FutureProvider<NodeIdentityStore>((
  ref,
) async {
  ref.watch(radioScopeProvider);
  final service = NodeIdentityStore();
  await service.init();
  return service;
});

// Device favorites service - persists favorite/ignored node numbers
final deviceFavoritesProvider = FutureProvider<DeviceFavoritesService>((
  ref,
) async {
  ref.watch(radioScopeProvider);
  final service = DeviceFavoritesService();
  await service.init();
  return service;
});

class NodeIdentityNotifier extends Notifier<Map<int, NodeIdentity>> {
  NodeIdentityStore? _store;
  bool _loaded = false;
  final Set<int> _bleStripLoggedNodes = {};

  @override
  Map<int, NodeIdentity> build() {
    final storeAsync = ref.watch(nodeIdentityStoreProvider);
    _store = storeAsync.value;
    if (!_loaded && _store != null) {
      _load();
    }
    return {};
  }

  Future<void> _load() async {
    if (_store == null) return;
    final identities = await _store!.getAllIdentities();
    if (identities.isNotEmpty) {
      final sanitized = _sanitizeIdentities(identities);
      state = sanitized;
      if (!_identitiesEqual(identities, sanitized)) {
        await _store!.saveAllIdentities(sanitized);
      }
    }
    _loaded = true;
  }

  Map<int, NodeIdentity> _sanitizeIdentities(
    Map<int, NodeIdentity> identities,
  ) {
    final sanitized = <int, NodeIdentity>{};
    for (final entry in identities.entries) {
      final identity = entry.value;
      final longIsBle = NodeDisplayNameResolver.isBleDefaultName(
        identity.longName,
      );
      final shortIsBle = NodeDisplayNameResolver.isBleDefaultName(
        identity.shortName,
      );
      if (longIsBle || shortIsBle) {
        final bleValue = longIsBle ? identity.longName : identity.shortName;
        if (_bleStripLoggedNodes.add(identity.nodeNum)) {
          AppLogging.protocol(
            'NODE_NAME_STRIP_BLE node=!${identity.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')} '
            'old=$bleValue',
          );
        }
        sanitized[entry.key] = identity.copyWith(
          longName: longIsBle ? null : identity.longName,
          shortName: shortIsBle ? null : identity.shortName,
        );
      } else {
        sanitized[entry.key] = identity;
      }
    }
    return sanitized;
  }

  bool _identitiesEqual(Map<int, NodeIdentity> a, Map<int, NodeIdentity> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if (entry.value.longName != other.longName ||
          entry.value.shortName != other.shortName ||
          entry.value.lastUpdatedAt != other.lastUpdatedAt ||
          entry.value.lastSeenAt != other.lastSeenAt) {
        return false;
      }
    }
    return true;
  }

  NodeIdentity? getIdentity(int nodeNum) => state[nodeNum];

  Map<int, NodeIdentity> getAllIdentities() => state;

  Future<void> upsertIdentity({
    required int nodeNum,
    String? longName,
    String? shortName,
    int? updatedAtMs,
    int? lastSeenAtMs,
  }) async {
    if (_store == null) return;
    final updated = await _store!.upsert(
      current: state,
      nodeNum: nodeNum,
      longName: longName,
      shortName: shortName,
      updatedAtMs: updatedAtMs,
      lastSeenAtMs: lastSeenAtMs,
    );
    if (!identical(updated, state)) {
      state = updated;
    }
  }
}

final nodeIdentityProvider =
    NotifierProvider<NodeIdentityNotifier, Map<int, NodeIdentity>>(
      NodeIdentityNotifier.new,
    );

// Transport
class TransportTypeNotifier extends Notifier<TransportType> {
  @override
  TransportType build() => TransportType.ble;

  void setType(TransportType type) => state = type;
}

final transportTypeProvider =
    NotifierProvider<TransportTypeNotifier, TransportType>(
      TransportTypeNotifier.new,
    );

/// The active [NetworkTransport] host:port, set before switching
/// [transportTypeProvider] to [TransportType.network].
class _NetworkHostNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String host) => state = host;
}

class _NetworkPortNotifier extends Notifier<int> {
  @override
  int build() => kMeshtasticDefaultPort;
  void set(int port) => state = port;
}

final networkTransportHostProvider =
    NotifierProvider<_NetworkHostNotifier, String>(_NetworkHostNotifier.new);
final networkTransportPortProvider =
    NotifierProvider<_NetworkPortNotifier, int>(_NetworkPortNotifier.new);

final transportProvider = Provider<DeviceTransport>((ref) {
  final caps = ref.watch(platformCapabilitiesProvider);
  final requested = ref.watch(transportTypeProvider);
  final resolved = _resolveTransportType(requested, caps);

  if (!_transportSupported(resolved, caps)) {
    return NoopDeviceTransport(requested);
  }

  switch (resolved) {
    case TransportType.ble:
      return BleTransport();
    case TransportType.usb:
      return createUsbTransport();
    case TransportType.network:
      final host = ref.watch(networkTransportHostProvider);
      final port = ref.watch(networkTransportPortProvider);
      return NetworkTransport(host: host, port: port);
  }
});

/// Map a requested transport type to one supported by the current host.
///
/// Falls through in priority order `network -> ble -> usb`. If none of
/// the three is supported on this host (web today), the caller receives
/// the originally-requested type back and is expected to use the
/// [NoopDeviceTransport] returned by [_unsupportedTransport]. Splitting
/// these two responsibilities keeps the supported-platform switch in
/// `transportProvider` readable while preserving the original intent for
/// logging.
TransportType _resolveTransportType(
  TransportType requested,
  PlatformCapabilities caps,
) {
  if (_transportSupported(requested, caps)) return requested;

  for (final candidate in const [
    TransportType.network,
    TransportType.ble,
    TransportType.usb,
  ]) {
    if (_transportSupported(candidate, caps)) {
      AppLogging.platform(
        'transportProvider: requested $requested unsupported on '
        '${caps.platformFamily.name} - falling back to $candidate',
      );
      return candidate;
    }
  }

  AppLogging.platform(
    'transportProvider: no supported transport on ${caps.platformFamily.name} '
    '- returning Noop for $requested',
  );
  return requested;
}

bool _transportSupported(TransportType type, PlatformCapabilities caps) {
  switch (type) {
    case TransportType.ble:
      return caps.supportsBle;
    case TransportType.usb:
      return caps.supportsSerial;
    case TransportType.network:
      return caps.supportsTcp;
  }
}

/// Dedicated BLE scanner — always a `BleTransport`, independent of the
/// session's active [transportTypeProvider]. Scanner UI uses this so a
/// BLE scan works even while the session transport is pinned to
/// network (e.g. user just disconnected from a TCP radio and opened the
/// scanner to pick a BLE device). Without it, `transportProvider.scan()`
/// would return `NetworkTransport.scan()` — an immediately-empty stream
/// — and the scanner would spin forever at "Looking for devices…".
///
/// Not used for connect: the connect path goes through
/// [prepareForDeviceTransition] which flips [transportTypeProvider]
/// and then uses `transportProvider` for the actual connection.
final bleScanTransportProvider = Provider<DeviceTransport>((ref) {
  final caps = ref.watch(platformCapabilitiesProvider);
  if (!caps.supportsBle) {
    AppLogging.platform(
      'bleScanTransportProvider: BLE unsupported on '
      '${caps.platformFamily.name} - returning NoopDeviceTransport',
    );
    final noop = NoopDeviceTransport(TransportType.ble);
    ref.onDispose(noop.dispose);
    return noop;
  }
  final transport = BleTransport();
  ref.onDispose(transport.dispose);
  return transport;
});

// Connection state - create a stream that emits current state immediately,
// then listens for future updates. This fixes the issue where the dashboard
// subscribes after the state has already changed to connected.
//
// NOTE: This provider watches only the Meshtastic transport. For MeshCore,
// use unifiedConnectionStateProvider which considers both protocols.
final connectionStateProvider = StreamProvider<DeviceConnectionState>((
  ref,
) async* {
  final transport = ref.watch(transportProvider);

  // Immediately emit the current state
  yield transport.state;

  // Then emit all future state changes
  await for (final state in transport.stateStream) {
    yield state;
  }
});

/// Unified connection state that considers both Meshtastic and MeshCore protocols.
///
/// This provider should be used by UI components that need to know if ANY
/// protocol is connected, not just Meshtastic. It checks:
/// 1. If lastDeviceProtocol is 'meshcore', returns connected if MeshCore coordinator
///    reports an active connection (not just DevicePairingState)
/// 2. Otherwise, returns the Meshtastic transport state
///
/// This prevents the UI from showing "Disconnected" when MeshCore is actually connected,
/// and also prevents showing "Connected" when MeshCore has actually disconnected but
/// DevicePairingState wasn't updated yet.
final unifiedConnectionStateProvider = Provider<DeviceConnectionState>((ref) {
  // Check if we should be using MeshCore
  final settingsAsync = ref.watch(settingsServiceProvider);
  final settings = settingsAsync.asData?.value;

  if (settings?.lastDeviceProtocol == 'meshcore') {
    // For MeshCore, check the actual coordinator connection state
    // This is more reliable than DevicePairingState which can be stale
    final coordinator = ref.watch(connectionCoordinatorProvider);
    if (coordinator.isConnected) {
      return DeviceConnectionState.connected;
    }
    if (coordinator.isConnecting) {
      return DeviceConnectionState.connecting;
    }
    return DeviceConnectionState.disconnected;
  }

  // For Meshtastic, use the transport state
  final connectionStateAsync = ref.watch(connectionStateProvider);
  return connectionStateAsync.when(
    data: (state) => state,
    loading: () => DeviceConnectionState.disconnected,
    error: (_, _) => DeviceConnectionState.disconnected,
  );
});

/// Stream of [OperationalReadiness] transitions for the Meshtastic
/// protocol service. Distinct from [unifiedConnectionStateProvider] which
/// reflects raw transport (BLE/TCP/USB) link state — readiness only
/// reaches `ready` when the two-phase handshake completes in the current
/// session generation. UI banners and TX guards should observe this
/// rather than transport state.
///
/// MeshCore is unaffected — it has its own connection coordinator.
final meshtasticReadinessProvider = StreamProvider<OperationalReadiness>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  return protocol.readinessStream;
});

/// Snapshot of [MeshtasticReadinessFlags] read from the current `.env`
/// environment + build mode. Watchdog auto-rebuild is gated by
/// `flags.watchdogEnabled` (default OFF in release, ON in debug/profile,
/// env override wins). Other moving parts of the readiness fix are not
/// flagged.
final meshtasticReadinessFlagsProvider = Provider<MeshtasticReadinessFlags>((
  _,
) {
  try {
    return MeshtasticReadinessFlags.fromEnv();
  } catch (_) {
    // dotenv may be uninitialised in some test contexts.
    return MeshtasticReadinessFlags.disabled;
  }
});

/// Convenience predicate: protocol is fully operational and TX is safe.
/// Watching this is the recommended way for UI to gate "send" buttons or
/// to suppress the "Configuring SocialMesh…" banner.
final meshtasticOperationalProvider = Provider<bool>((ref) {
  final readinessAsync = ref.watch(meshtasticReadinessProvider);
  return readinessAsync.maybeWhen(
    data: (r) => r == OperationalReadiness.ready,
    orElse: () => false,
  );
});

/// Banner-friendly classification of the Meshtastic protocol state.
/// Keeps `unifiedConnectionStateProvider` untouched globally — only
/// presentation surfaces that explicitly opt-in (currently
/// `TopStatusBanner`) consume this.
enum MeshtasticBannerState {
  /// Either MeshCore is the active protocol, or readiness is `ready`,
  /// or the readiness stream has not delivered a value yet.
  /// **Banner falls through to its existing logic in this case** —
  /// no Configuring/Recovering override.
  passthrough,

  /// Readiness is `linkConnected | handshakePhase1 | handshakePhase2`,
  /// or `idle` while the transport is still connected (the brief
  /// `ready -> idle -> linkConnected` window during an active restore).
  /// Banner shows "Configuring SocialMesh…" and suppresses dismiss.
  configuring,

  /// Readiness is `degraded` — phase-2 timed out or a transport blip
  /// hit mid-handshake. Banner shows the recovering CTA.
  recovering,
}

/// Derived banner state for the Meshtastic protocol. MeshCore sessions
/// always return [MeshtasticBannerState.passthrough] so the existing
/// banner logic remains unchanged for that protocol.
final meshtasticBannerStateProvider = Provider<MeshtasticBannerState>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  final settings = settingsAsync.asData?.value;
  if (settings?.lastDeviceProtocol == 'meshcore') {
    return MeshtasticBannerState.passthrough;
  }

  final readinessAsync = ref.watch(meshtasticReadinessProvider);
  final readiness = readinessAsync.maybeWhen(
    data: (r) => r,
    orElse: () => null,
  );
  if (readiness == null || readiness == OperationalReadiness.ready) {
    return MeshtasticBannerState.passthrough;
  }
  if (readiness == OperationalReadiness.degraded) {
    return MeshtasticBannerState.recovering;
  }
  if (readiness == OperationalReadiness.idle) {
    // The brief `ready -> idle -> linkConnected` window during a
    // restore: keep showing Configuring instead of flashing
    // Disconnected. If the transport is also down, the protocol is
    // genuinely stopped — pass through to existing Disconnected logic.
    final transport = ref.watch(transportProvider);
    return transport.isConnected
        ? MeshtasticBannerState.configuring
        : MeshtasticBannerState.passthrough;
  }
  // linkConnected | handshakePhase1 | handshakePhase2
  return MeshtasticBannerState.configuring;
});

/// Whether the active protocol link is connected.
///
/// This checks the correct state source based on the active protocol:
/// - For MeshCore: checks ConnectionCoordinator.isConnected
/// - For Meshtastic: checks the Meshtastic transport state
///
/// Use this in resume/reconnect logic to avoid reconnecting while connected.
final isLinkConnectedProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  final settings = settingsAsync.asData?.value;

  if (settings?.lastDeviceProtocol == 'meshcore') {
    final coordinator = ref.watch(connectionCoordinatorProvider);
    return coordinator.isConnected;
  }

  // For Meshtastic, check transport state
  final connectionStateAsync = ref.watch(connectionStateProvider);
  return connectionStateAsync.when(
    data: (state) => state == DeviceConnectionState.connected,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Whether the active protocol link is currently connecting.
///
/// This checks the correct state source based on the active protocol:
/// - For MeshCore: checks ConnectionCoordinator.isConnecting
/// - For Meshtastic: checks transport state == connecting
///
/// Use this in resume/reconnect logic to avoid starting concurrent reconnects.
final isLinkConnectingProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  final settings = settingsAsync.asData?.value;

  if (settings?.lastDeviceProtocol == 'meshcore') {
    final coordinator = ref.watch(connectionCoordinatorProvider);
    return coordinator.isConnecting;
  }

  // For Meshtastic, check transport state
  final connectionStateAsync = ref.watch(connectionStateProvider);
  return connectionStateAsync.when(
    data: (state) => state == DeviceConnectionState.connecting,
    loading: () => false,
    error: (_, _) => false,
  );
});

// ============================================================================
// Link Status - Single source of truth for connection UI
// ============================================================================

/// Connection status for the link.
enum LinkConnectionStatus { disconnected, connecting, connected }

/// Protocol type for the link (mirrors MeshProtocolType but for link status).
enum LinkProtocol { unknown, meshtastic, meshcore }

/// Unified link status model that combines connection state and protocol info.
///
/// This is the SINGLE SOURCE OF TRUTH for connection UI. All UI components
/// (banners, screens, indicators) should use this instead of checking
/// individual Meshtastic or MeshCore providers.
class LinkStatus {
  final LinkProtocol protocol;
  final LinkConnectionStatus status;
  final String? deviceName;
  final String? deviceId;

  const LinkStatus({
    required this.protocol,
    required this.status,
    this.deviceName,
    this.deviceId,
  });

  bool get isConnected => status == LinkConnectionStatus.connected;
  bool get isConnecting => status == LinkConnectionStatus.connecting;
  bool get isDisconnected => status == LinkConnectionStatus.disconnected;
  bool get isMeshCore => protocol == LinkProtocol.meshcore;
  bool get isMeshtastic => protocol == LinkProtocol.meshtastic;

  static const disconnected = LinkStatus(
    protocol: LinkProtocol.unknown,
    status: LinkConnectionStatus.disconnected,
  );

  @override
  String toString() =>
      'LinkStatus(protocol: $protocol, status: $status, device: $deviceName)';
}

/// The single source of truth for connection state across the app.
///
/// This provider derives the correct connection status by checking the
/// appropriate source based on the saved protocol preference:
/// - For MeshCore: checks ConnectionCoordinator state
/// - For Meshtastic: checks the transport state
///
/// Use this provider in ALL UI components that need to show connection status:
/// - Top status banner
/// - Device status button
/// - Nodes screen
/// - Any "connected/disconnected" indicators
final linkStatusProvider = Provider<LinkStatus>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  final settings = settingsAsync.asData?.value;

  final lastDeviceId = settings?.lastDeviceId;
  final lastDeviceName = settings?.lastDeviceName;
  final savedProtocol = settings?.lastDeviceProtocol;

  // CRITICAL: Check what's ACTUALLY connected, not what was saved.
  // This prevents "Connected to MeshCore" showing when Meshtastic is active.

  // CRITICAL: Watch the MeshCore connection state stream for reactivity.
  // The coordinator itself is a singleton that doesn't trigger rebuilds -
  // we need to watch its stateStream via this StreamProvider so that
  // linkStatusProvider rebuilds when MeshCore connects/disconnects.
  // This fixes the navigation bug where the wrong shell was shown after
  // connecting to MeshCore because this provider wasn't rebuilding.
  ref.watch(meshCoreConnectionStateProvider);

  // 1. Check if MeshCore is actively connected/connecting
  final coordinator = ref.watch(connectionCoordinatorProvider);
  if (coordinator.isConnected) {
    final meshDeviceInfo = coordinator.deviceInfo;
    return LinkStatus(
      protocol: LinkProtocol.meshcore,
      status: LinkConnectionStatus.connected,
      deviceName: meshDeviceInfo?.displayName ?? lastDeviceName,
      deviceId: meshDeviceInfo?.nodeId ?? lastDeviceId,
    );
  }
  if (coordinator.isConnecting) {
    return LinkStatus(
      protocol: LinkProtocol.meshcore,
      status: LinkConnectionStatus.connecting,
      deviceName: lastDeviceName,
      deviceId: lastDeviceId,
    );
  }

  // 2. Check if Meshtastic transport is actively connected/connecting
  final connectionStateAsync = ref.watch(connectionStateProvider);
  final transportState = connectionStateAsync.when(
    data: (state) => state,
    loading: () => DeviceConnectionState.disconnected,
    error: (_, _) => DeviceConnectionState.disconnected,
  );

  if (transportState == DeviceConnectionState.connected ||
      transportState == DeviceConnectionState.connecting) {
    final linkStatus = transportState == DeviceConnectionState.connected
        ? LinkConnectionStatus.connected
        : LinkConnectionStatus.connecting;

    return LinkStatus(
      protocol: LinkProtocol.meshtastic,
      status: linkStatus,
      deviceName: lastDeviceName,
      deviceId: lastDeviceId,
    );
  }

  // 3. Neither protocol is actively connected - use saved protocol for "last known"
  //    but status is disconnected
  if (lastDeviceId != null) {
    final protocol = savedProtocol == 'meshcore'
        ? LinkProtocol.meshcore
        : LinkProtocol.meshtastic;

    return LinkStatus(
      protocol: protocol,
      status: LinkConnectionStatus.disconnected,
      deviceName: lastDeviceName,
      deviceId: lastDeviceId,
    );
  }

  // No device saved
  return LinkStatus.disconnected;
});

// ============================================================================
// Protocol Capabilities - What features each protocol supports
// ============================================================================

/// Capabilities of the current protocol.
///
/// Use this to gate features that are protocol-specific. Screens and widgets
/// should check capabilities, not protocol enums directly. This allows
/// gradual feature rollout and clean separation of concerns.
class ProtocolCapabilities {
  // ---- Node/Contact Discovery ----

  /// Meshtastic-style mesh-wide node discovery with telemetry.
  final bool supportsNodes;

  /// MeshCore-style contact discovery via adverts.
  final bool supportsMeshCoreContacts;

  /// MeshCore contact code (QR sharing).
  final bool supportsContactCodes;

  /// MeshCore "Discover Contacts" active scanning.
  final bool supportsContactDiscovery;

  // ---- Channels ----

  /// Meshtastic channel configuration.
  final bool supportsChannels;

  /// MeshCore channel/room concept.
  final bool supportsMeshCoreChannels;

  // ---- Map/Location ----

  /// Position packets and map display.
  final bool supportsMap;

  /// MeshCore trace path features.
  final bool supportsTracePath;

  /// MeshCore antenna coverage analysis.
  final bool supportsAntennaCoverage;

  /// MeshCore line of sight analysis.
  final bool supportsLineOfSight;

  // ---- Messaging ----

  /// Direct text messaging.
  final bool supportsMessaging;

  // ---- Telemetry & Diagnostics ----

  /// Battery, signal, environment telemetry.
  final bool supportsTelemetry;

  /// MeshCore Rx Log (received packets log).
  final bool supportsRxLog;

  /// MeshCore noise floor monitoring.
  final bool supportsNoiseFloor;

  /// MeshCore nearby node discovery scan.
  final bool supportsNearbyNodeDiscovery;

  // ---- Device Configuration ----

  /// Full device/radio configuration.
  final bool supportsDeviceConfig;

  const ProtocolCapabilities({
    required this.supportsNodes,
    required this.supportsMeshCoreContacts,
    required this.supportsContactCodes,
    required this.supportsContactDiscovery,
    required this.supportsChannels,
    required this.supportsMeshCoreChannels,
    required this.supportsMap,
    required this.supportsTracePath,
    required this.supportsAntennaCoverage,
    required this.supportsLineOfSight,
    required this.supportsMessaging,
    required this.supportsTelemetry,
    required this.supportsRxLog,
    required this.supportsNoiseFloor,
    required this.supportsNearbyNodeDiscovery,
    required this.supportsDeviceConfig,
  });

  /// Full capabilities for Meshtastic protocol.
  static const meshtastic = ProtocolCapabilities(
    supportsNodes: true,
    supportsMeshCoreContacts: false,
    supportsContactCodes: false,
    supportsContactDiscovery: false,
    supportsChannels: true,
    supportsMeshCoreChannels: false,
    supportsMap: true,
    supportsTracePath: false,
    supportsAntennaCoverage: false,
    supportsLineOfSight: false,
    supportsMessaging: true,
    supportsTelemetry: true,
    supportsRxLog: false,
    supportsNoiseFloor: false,
    supportsNearbyNodeDiscovery: false,
    supportsDeviceConfig: true,
  );

  /// Capabilities for MeshCore protocol.
  /// These reflect what the MeshCore firmware/app supports.
  static const meshcore = ProtocolCapabilities(
    supportsNodes: false, // MeshCore uses contacts, not nodes
    supportsMeshCoreContacts: true,
    supportsContactCodes: true,
    supportsContactDiscovery: true,
    supportsChannels: false, // MeshCore has its own channel concept
    supportsMeshCoreChannels: true,
    supportsMap: true, // MeshCore has map features
    supportsTracePath: true,
    supportsAntennaCoverage: true,
    supportsLineOfSight: true,
    supportsMessaging: true,
    supportsTelemetry: false, // Different telemetry model
    supportsRxLog: true,
    supportsNoiseFloor: true,
    supportsNearbyNodeDiscovery: true,
    supportsDeviceConfig: false, // Different config model
  );

  /// No capabilities when not connected.
  static const none = ProtocolCapabilities(
    supportsNodes: false,
    supportsMeshCoreContacts: false,
    supportsContactCodes: false,
    supportsContactDiscovery: false,
    supportsChannels: false,
    supportsMeshCoreChannels: false,
    supportsMap: false,
    supportsTracePath: false,
    supportsAntennaCoverage: false,
    supportsLineOfSight: false,
    supportsMessaging: false,
    supportsTelemetry: false,
    supportsRxLog: false,
    supportsNoiseFloor: false,
    supportsNearbyNodeDiscovery: false,
    supportsDeviceConfig: false,
  );

  /// Whether this is effectively a MeshCore session.
  bool get isMeshCore =>
      supportsMeshCoreContacts || supportsMeshCoreChannels || supportsRxLog;

  /// Whether this is effectively a Meshtastic session.
  bool get isMeshtastic => supportsNodes || supportsChannels;
}

/// Provider for protocol capabilities based on the current link protocol.
///
/// Use this to gate UI features that depend on protocol support.
/// Example:
/// ```dart
/// final capabilities = ref.watch(protocolCapabilitiesProvider);
/// if (!capabilities.supportsNodes) {
///   return ProtocolNotSupportedView(feature: 'Nodes');
/// }
/// ```
final protocolCapabilitiesProvider = Provider<ProtocolCapabilities>((ref) {
  final linkStatus = ref.watch(linkStatusProvider);

  return switch (linkStatus.protocol) {
    LinkProtocol.meshtastic => ProtocolCapabilities.meshtastic,
    LinkProtocol.meshcore => ProtocolCapabilities.meshcore,
    LinkProtocol.unknown => ProtocolCapabilities.none,
  };
});

// ============================================================================
// Active Protocol Provider - The SINGLE source of truth for protocol routing
// ============================================================================

/// The active protocol used for shell routing.
///
/// This determines which shell (MeshtasticShell or MeshCoreShell) is mounted.
/// It is derived from the actual connection state, NOT from user settings.
///
/// Values:
/// - `none`: No active connection → show scanner/onboarding
/// - `meshtastic`: Meshtastic device connected or was last connected
/// - `meshcore`: MeshCore device connected or was last connected
enum ActiveProtocol { none, meshtastic, meshcore }

/// Provider for the active protocol.
///
/// This is THE source of truth for deciding which app shell to render.
/// The connection layer (ConnectionCoordinator, transport) sets this,
/// NOT UI components.
///
/// When this changes, the previous shell must be completely unmounted
/// to avoid any state leakage between protocols.
final activeProtocolProvider = Provider<ActiveProtocol>((ref) {
  final linkStatus = ref.watch(linkStatusProvider);

  // If connected or connecting, use that protocol
  if (linkStatus.isConnected || linkStatus.isConnecting) {
    return switch (linkStatus.protocol) {
      LinkProtocol.meshcore => ActiveProtocol.meshcore,
      LinkProtocol.meshtastic => ActiveProtocol.meshtastic,
      LinkProtocol.unknown => ActiveProtocol.none,
    };
  }

  // If disconnected but we have a saved device, use that protocol
  // This allows the shell to persist after temporary disconnects
  if (linkStatus.deviceId != null) {
    return switch (linkStatus.protocol) {
      LinkProtocol.meshcore => ActiveProtocol.meshcore,
      LinkProtocol.meshtastic => ActiveProtocol.meshtastic,
      LinkProtocol.unknown => ActiveProtocol.none,
    };
  }

  // No connection history - show onboarding/scanner
  return ActiveProtocol.none;
});

// Currently connected device
class ConnectedDeviceNotifier extends Notifier<DeviceInfo?> {
  @override
  DeviceInfo? build() => null;

  void setState(DeviceInfo? device) => state = device;
}

final connectedDeviceProvider =
    NotifierProvider<ConnectedDeviceNotifier, DeviceInfo?>(
      ConnectedDeviceNotifier.new,
    );

// Auto-reconnect state
// - idle: No reconnection in progress
// - manualConnecting: User manually initiated connection (don't auto-reconnect on failure)
// - scanning: Auto-reconnect is scanning for the device
// - connecting: Auto-reconnect is connecting to the device
// - failed: Auto-reconnect failed (all retries exhausted)
// - success: Auto-reconnect succeeded
enum AutoReconnectState {
  idle,
  manualConnecting,
  scanning,
  connecting,
  failed,
  success,
}

class AutoReconnectStateNotifier extends Notifier<AutoReconnectState> {
  @override
  AutoReconnectState build() => AutoReconnectState.idle;

  void setState(AutoReconnectState newState) => state = newState;
}

final autoReconnectStateProvider =
    NotifierProvider<AutoReconnectStateNotifier, AutoReconnectState>(
      AutoReconnectStateNotifier.new,
    );

/// Tracks if user manually disconnected - prevents auto-reconnect until user explicitly connects.
/// This is separate from autoReconnectState to avoid state confusion.
class UserDisconnectedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setUserDisconnected(bool value) {
    AppLogging.connection(
      '🔌 UserDisconnectedNotifier: setUserDisconnected($value)',
    );
    state = value;
  }
}

final userDisconnectedProvider =
    NotifierProvider<UserDisconnectedNotifier, bool>(
      UserDisconnectedNotifier.new,
    );

/// Tracks when a config/admin write has been sent to the local node,
/// which is expected to trigger a firmware reboot. This flag is consumed
/// by the auto-reconnect flow to:
///   1. Increase patience before pairing invalidation (reboot + SSL cert
///      gen can take 30–120s on ESP32).
///   2. Enable logical device matching (BLE UUID may change on reboot).
///
/// Set by the protocol service stream listener. Cleared automatically
/// after a successful reconnect or when the reconnect flow gives up.
class RebootExpectedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRebootExpected(bool value) {
    AppLogging.connection(
      '🔄 RebootExpectedNotifier: setRebootExpected($value)',
    );
    state = value;
  }
}

final rebootExpectedProvider = NotifierProvider<RebootExpectedNotifier, bool>(
  RebootExpectedNotifier.new,
);

/// True when the connect target is a different physical device than the
/// last one we connected to. Both IDs must be present and non-equal; if
/// either is null we treat it as a fresh / first connect and let the
/// caller's explicit `clearNodeData` decision stand.
@visibleForTesting
bool isDeviceSwitchForTest(String? previousDeviceId, String? newDeviceId) =>
    _isDeviceSwitch(previousDeviceId, newDeviceId);

bool _isDeviceSwitch(String? previousDeviceId, String? newDeviceId) {
  if (previousDeviceId == null || newDeviceId == null) return false;
  return previousDeviceId != newDeviceId;
}

/// Classifies whether connecting to a device whose raw BLE UUID differs
/// from the last-persisted one is actually a **transport rebind** of the
/// same physical radio (BLE peripheral UUID rotated — common on ESP32 /
/// nRF hardware) rather than a genuine switch to a different radio.
///
/// Logical identity is derived from stable Meshtastic identifiers that
/// survive BLE UUID rotation:
///   * `lastMyNodeNum`  — firmware node number; its last 4 hex digits
///                        appear as the suffix in default Meshtastic BLE
///                        names (`Meshtastic_XXXX`). Strongest signal.
///   * `lastDeviceName` — full advertised BLE name. Medium signal; used
///                        when the node-number suffix check is unavailable
///                        or the name has been customised.
///
/// Returns `true` only when we have positive evidence of rebind. When we
/// can't tell, returns `false` and the caller falls back to the existing
/// raw-UUID `_isDeviceSwitch` comparison (conservative: clears on
/// mismatch). Uses [bleNameMatchesNodeNum] so the suffix semantics stay
/// identical to [_tryLogicalDeviceMatch].
bool isLogicalTransportRebind({
  required String newDeviceName,
  required String newDeviceId,
  required String? previousDeviceId,
  required int? lastMyNodeNum,
  required String? lastDeviceName,
}) {
  // No prior connection — nothing to rebind to.
  if (previousDeviceId == null) return false;
  // Raw ID already matches — not a rebind, just a normal reconnect. The
  // caller's `_isDeviceSwitch` check will also return false here.
  if (newDeviceId == previousDeviceId) return false;

  // Strong: BLE name carries the prior node number suffix.
  if (lastMyNodeNum != null) {
    final fullHex = lastMyNodeNum.toRadixString(16).padLeft(4, '0');
    final suffix = fullHex.substring(fullHex.length - 4);
    if (bleNameMatchesNodeNum(newDeviceName, suffix)) return true;
  }

  // Medium: advertised name exactly matches the prior device name.
  if (lastDeviceName != null &&
      lastDeviceName.isNotEmpty &&
      newDeviceName == lastDeviceName) {
    return true;
  }

  return false;
}

/// Broader logical-identity check that works across transports.
///
/// [isLogicalTransportRebind] was BLE-only. Same physical radio can also
/// surface under a TCP/mDNS endpoint (e.g. `tcp:meshtastic_abcd.local:4403`)
/// whose hostname carries the same 4-hex node suffix. This predicate
/// centralises both checks in one place so the transition classifier
/// can answer "same logical radio?" consistently regardless of the pair
/// of transports involved.
@visibleForTesting
bool isLogicalSameRadio({
  required String newDeviceName,
  required String newDeviceId,
  required TransportType newDeviceType,
  required int? lastMyNodeNum,
  required String? lastDeviceName,
}) {
  if (lastMyNodeNum != null) {
    final fullHex = lastMyNodeNum.toRadixString(16).padLeft(4, '0');
    final suffix = fullHex.substring(fullHex.length - 4);
    if (bleNameMatchesNodeNum(newDeviceName, suffix)) return true;
    // mDNS / TCP host often embeds the same suffix: `meshtastic_abcd.local`.
    // Match it as a hex token bounded by non-alnum so we don't hit
    // coincidental 4-char substrings inside unrelated words.
    final loweredSuffix = suffix.toLowerCase();
    final boundary = RegExp(
      r'(^|[^a-z0-9])' + loweredSuffix + r'([^a-z0-9]|$)',
    );
    if (boundary.hasMatch(newDeviceName.toLowerCase())) return true;
    if (newDeviceType == TransportType.network) {
      final endpoint = _parseNetworkEndpointId(newDeviceId);
      if (endpoint != null && boundary.hasMatch(endpoint.host)) return true;
    }
  }
  if (lastDeviceName != null &&
      lastDeviceName.isNotEmpty &&
      newDeviceName == lastDeviceName) {
    return true;
  }
  return false;
}

/// Parse the persisted `last_device_type` string back to [TransportType].
/// Returns `null` when the stored value is missing or unrecognised — the
/// caller must treat that as "transport family unknown".
TransportType? transportTypeFromString(String? stored) {
  switch (stored) {
    case 'ble':
      return TransportType.ble;
    case 'usb':
      return TransportType.usb;
    case 'network':
      return TransportType.network;
  }
  return null;
}

String _transportTypeToString(TransportType type) {
  switch (type) {
    case TransportType.ble:
      return 'ble';
    case TransportType.usb:
      return 'usb';
    case TransportType.network:
      return 'network';
  }
}

/// Canonical taxonomy of active-device transitions. A single source of
/// truth for "preserve vs clear vs rehydrate" — consumed by every connect
/// entrypoint via [prepareForDeviceTransition].
enum DeviceTransitionKind {
  /// No prior device persisted — first connect after install / reset.
  firstEver,

  /// Raw ids identical — ordinary reconnect to same physical device on
  /// the same transport.
  sameDevice,

  /// Raw ids differ but logical identity matches AND transport family
  /// is unchanged (classic ESP32/nRF BLE UUID rotation).
  transportRebind,

  /// Raw ids differ but logical identity matches AND transport family
  /// CHANGED (same radio reached over a different transport — e.g. BLE
  /// to TCP). Persisted node cache is preserved, but session-scoped
  /// state must be reset and the new session must run a fresh hydrate.
  sameRadioCrossTransport,

  /// Different physical radio — destructive switch. Nodes cleared.
  deviceSwitch,
}

class ActiveDeviceTransition {
  const ActiveDeviceTransition({
    required this.kind,
    required this.previousDeviceId,
    required this.newDeviceId,
    required this.previousTransportType,
    required this.newTransportType,
  });

  final DeviceTransitionKind kind;
  final String? previousDeviceId;
  final String newDeviceId;
  final TransportType? previousTransportType;
  final TransportType newTransportType;

  /// Destructive clear of persisted node cache. Only `deviceSwitch`.
  bool get clearNodes => kind == DeviceTransitionKind.deviceSwitch;

  /// Logical identity matches — suppress `_isDeviceSwitch` auto-clear
  /// inside [clearDeviceDataBeforeConnectRef]. Covers both same-family
  /// rebinds and same-radio cross-transport.
  bool get isLogicalRebind =>
      kind == DeviceTransitionKind.transportRebind ||
      kind == DeviceTransitionKind.sameRadioCrossTransport;

  /// Transport family changed — the transportTypeProvider must be
  /// flipped so the next protocolServiceProvider rebuild instantiates
  /// the right transport.
  bool get transportFamilyChanged =>
      previousTransportType != null &&
      previousTransportType != newTransportType;

  /// Force fresh hydration of session-scoped in-memory state even
  /// though persisted node cache is preserved (scenario D).
  bool get forceFreshHydration =>
      kind == DeviceTransitionKind.sameRadioCrossTransport;
}

/// Pure classifier — no side effects. Consumed by [prepareForDeviceTransition]
/// and by unit tests that pin the matrix row-by-row.
@visibleForTesting
ActiveDeviceTransition classifyDeviceTransition({
  required String newDeviceId,
  required String newDeviceName,
  required TransportType newDeviceType,
  required String? previousDeviceId,
  required String? previousDeviceType,
  required int? lastMyNodeNum,
  required String? lastDeviceName,
}) {
  final previousTransportType = transportTypeFromString(previousDeviceType);

  if (previousDeviceId == null) {
    return ActiveDeviceTransition(
      kind: DeviceTransitionKind.firstEver,
      previousDeviceId: null,
      newDeviceId: newDeviceId,
      previousTransportType: previousTransportType,
      newTransportType: newDeviceType,
    );
  }

  if (newDeviceId == previousDeviceId) {
    return ActiveDeviceTransition(
      kind: DeviceTransitionKind.sameDevice,
      previousDeviceId: previousDeviceId,
      newDeviceId: newDeviceId,
      previousTransportType: previousTransportType,
      newTransportType: newDeviceType,
    );
  }

  final sameRadio = isLogicalSameRadio(
    newDeviceName: newDeviceName,
    newDeviceId: newDeviceId,
    newDeviceType: newDeviceType,
    lastMyNodeNum: lastMyNodeNum,
    lastDeviceName: lastDeviceName,
  );

  if (sameRadio) {
    final transportChanged =
        previousTransportType != null && previousTransportType != newDeviceType;
    return ActiveDeviceTransition(
      kind: transportChanged
          ? DeviceTransitionKind.sameRadioCrossTransport
          : DeviceTransitionKind.transportRebind,
      previousDeviceId: previousDeviceId,
      newDeviceId: newDeviceId,
      previousTransportType: previousTransportType,
      newTransportType: newDeviceType,
    );
  }

  return ActiveDeviceTransition(
    kind: DeviceTransitionKind.deviceSwitch,
    previousDeviceId: previousDeviceId,
    newDeviceId: newDeviceId,
    previousTransportType: previousTransportType,
    newTransportType: newDeviceType,
  );
}

/// The node number to bind the storage scope to when the device id itself
/// is not yet mapped to a radio.
///
/// `lastMyNodeNum` describes the radio we last talked to, so it is only the
/// right answer when this connect reaches that same radio: the same device
/// id, a rotated BLE UUID, or the same radio over another transport. On a
/// genuine switch it names the *other* radio, and returning it would point
/// the new radio at the previous one's data — exactly the leak scoping
/// exists to close.
@visibleForTesting
int? scopeNodeNumForTransition(
  ActiveDeviceTransition transition,
  int? lastMyNodeNum,
) => _scopeNodeNumForTransition(transition, lastMyNodeNum);

int? _scopeNodeNumForTransition(
  ActiveDeviceTransition transition,
  int? lastMyNodeNum,
) {
  switch (transition.kind) {
    case DeviceTransitionKind.sameDevice:
    case DeviceTransitionKind.transportRebind:
    case DeviceTransitionKind.sameRadioCrossTransport:
      return lastMyNodeNum;
    case DeviceTransitionKind.firstEver:
    case DeviceTransitionKind.deviceSwitch:
      return null;
  }
}

/// Central pre-connect preparation. **Must** be called before
/// `ref.read(transportProvider)` in every connect entrypoint — it
/// decides the transition kind, clears state in the correct order to
/// avoid the NodesNotifier `_init` hydration race, persists the new
/// identity, and only then flips `transportTypeProvider`.
///
/// Returns the classification so callers can log or conditionally act
/// on it (e.g. skip redundant protocol setup). Callers must NOT make
/// their own clear/setType decisions after this returns.
Future<ActiveDeviceTransition> prepareForDeviceTransitionRef(
  Ref ref, {
  required DeviceInfo device,
  String? deviceProtocol,
}) async {
  final settings = await ref.read(settingsServiceProvider.future);
  final transition = classifyDeviceTransition(
    newDeviceId: device.id,
    newDeviceName: device.name,
    newDeviceType: device.type,
    previousDeviceId: settings.lastDeviceId,
    previousDeviceType: settings.lastDeviceType,
    lastMyNodeNum: settings.lastMyNodeNum,
    lastDeviceName: settings.lastDeviceName,
  );

  AppLogging.connection(
    '🔄 DEVICE TRANSITION: kind=${transition.kind.name} '
    'prev=${transition.previousDeviceId} new=${transition.newDeviceId} '
    'prevType=${transition.previousTransportType?.name} '
    'newType=${transition.newTransportType.name} '
    'clearNodes=${transition.clearNodes} '
    'forceFreshHydration=${transition.forceFreshHydration}',
  );

  // Persist new identity BEFORE clear so a crash mid-transition cannot
  // leave the app re-classifying this same transition on next launch.
  // Node suffix / name-match fallbacks used by classifyDeviceTransition
  // all key off lastMyNodeNum + lastDeviceName, which are updated
  // independently as the handshake progresses.
  await settings.setLastDevice(
    device.id,
    _transportTypeToString(device.type),
    deviceName: device.name,
    protocol: deviceProtocol,
  );

  // Clear — ordering is critical: this runs while transportTypeProvider
  // still points at the OLD transport so the OLD NodesNotifier is the
  // one whose state is reset + whose epoch is bumped. If we flipped
  // transport type first, the provider rebuild would spawn a fresh
  // NodesNotifier whose `_init` would immediately `await loadNodes()`
  // on still-populated storage — and any write back via its async
  // resumption would resurrect the old nodes we're trying to clear.
  await clearDeviceDataBeforeConnectRef(
    ref,
    clearNodeData: transition.clearNodes,
    previousDeviceId: transition.previousDeviceId,
    newDeviceId: transition.newDeviceId,
    isTransportRebind: transition.isLogicalRebind,
  );

  // Point storage at the radio we are connecting to. Runs AFTER the
  // in-memory clear above and BEFORE the transport flip: the clear bumps
  // NodesNotifier's epoch, so doing it after the scope change would
  // abandon the hydration the scope change just started, and the new
  // radio's cached nodes would stay unloaded for the session.
  await RadioScope.instance.useDevice(
    deviceId: device.id,
    label: device.name,
    knownNodeNum: _scopeNodeNumForTransition(
      transition,
      settings.lastMyNodeNum,
    ),
  );

  // For same-radio cross-transport: preserve the persisted node cache
  // but reset session-scoped in-memory state so the new session starts
  // clean. clearDeviceDataBeforeConnectRef already clears channels and
  // the new-nodes badge. The NodesNotifier rebuild (triggered by the
  // transport type flip below) will re-`_init` against preserved
  // storage — that's the fresh hydrate.
  if (transition.forceFreshHydration) {
    AppLogging.connection(
      '🔄 DEVICE TRANSITION: forceFreshHydration — preserving persisted '
      'node cache but rebuilding NodesNotifier against new transport',
    );
  }

  // Flip transport type AFTER clear. For sameDevice / transportRebind
  // this is a no-op (family unchanged). For deviceSwitch / sameRadioCross
  // the rebuild picks up the new BleTransport / NetworkTransport and
  // the fresh ProtocolService.
  if (transition.transportFamilyChanged) {
    AppLogging.connection(
      '🔄 DEVICE TRANSITION: transport family flip '
      '${transition.previousTransportType?.name} → '
      '${transition.newTransportType.name}',
    );
    if (transition.newTransportType == TransportType.network) {
      final endpoint = _parseNetworkEndpointId(device.id);
      if (endpoint != null) {
        ref.read(networkTransportHostProvider.notifier).set(endpoint.host);
        ref.read(networkTransportPortProvider.notifier).set(endpoint.port);
      }
    }
    ref
        .read(transportTypeProvider.notifier)
        .setType(transition.newTransportType);
  }

  return transition;
}

/// Restore [transportTypeProvider] to match the persisted `lastDeviceType`.
/// MUST run at cold-start (before any auto-reconnect path fires) for the
/// TCP-resume case: `transportTypeProvider` defaults to BLE on a fresh
/// process, so a TCP last-device would otherwise hit the BLE scan loop
/// looking for a `tcp:...` endpoint id and spin forever at "Connecting…".
///
/// Idempotent: no-op if the stored type is null/unknown or already matches
/// the current provider value. Seeds `networkTransportHost/Port` when the
/// persisted device is a network endpoint so the rebuilt `NetworkTransport`
/// binds to the right address.
///
/// This is distinct from [prepareForDeviceTransitionRef] — it does NOT
/// classify, clear, or persist anything. It is a pure read-from-settings
/// → write-to-transport-providers sync.
void restoreTransportTypeFromSettings(Ref ref, SettingsService settings) {
  final restoredType = transportTypeFromString(settings.lastDeviceType);
  if (restoredType == null) return;
  if (ref.read(transportTypeProvider) == restoredType) return;
  AppLogging.connection(
    '🔄 TRANSPORT RESTORE: ${ref.read(transportTypeProvider).name} → '
    '${restoredType.name} from persisted lastDeviceType',
  );
  if (restoredType == TransportType.network) {
    final deviceId = settings.lastDeviceId;
    if (deviceId != null) {
      final endpoint = _parseNetworkEndpointId(deviceId);
      if (endpoint != null) {
        ref.read(networkTransportHostProvider.notifier).set(endpoint.host);
        ref.read(networkTransportPortProvider.notifier).set(endpoint.port);
      }
    }
  }
  ref.read(transportTypeProvider.notifier).setType(restoredType);
}

/// Public entry point for the reconnect strategy dispatcher. Callers
/// outside this library (e.g. `connection_providers.startBackgroundConnection`
/// when it detects a `directEndpoint` transport) use this to hand off
/// into the right reconnect path without reimplementing the BLE vs
/// network routing. Internal callers still use `_dispatchReconnect`.
void dispatchReconnectForDevice(Ref ref, String deviceId) {
  dispatchReconnectMeshCoreAware(ref, deviceId);
}

/// D27: Protocol-aware reconnect dispatch.
///
/// When the saved peer is a MeshCore device, route the reconnect through
/// [DeviceConnectionNotifier.startMeshCoreReconnect] so the coordinator's
/// own TCP/BLE routing decides the transport. The Meshtastic
/// `transportProvider.reconnectMode` is never consulted for MeshCore.
///
/// Why: `_dispatchReconnect` switches on `transportProvider.reconnectMode`,
/// but MeshCore connections live on a separate ConnectionCoordinator
/// singleton and never register as `transportProvider`. For a TCP-saved
/// MeshCore peer the Meshtastic transport defaults to BLE/scanBased and
/// the dispatcher would otherwise route to `_performReconnect` → BLE scan
/// → `PlatformException(CBManagerStateUnsupported)` when iOS suppresses
/// BT during permission dialogs. Defence-in-depth: every existing
/// MeshCore-bail in app_providers.dart still stands; this helper turns
/// three ad-hoc checks into one named consolidation point.
///
/// Logging: emits `event=reconnect.requested protocol=<...> transport=<...>`
/// at the meshcore log namespace so the field test matrix can verify
/// route selection without inspecting BLE platform calls.
void dispatchReconnectMeshCoreAware(Ref ref, String deviceId) {
  final settings = ref.read(settingsServiceProvider).asData?.value;
  if (_routeMeshCoreReconnect(
    deviceId: deviceId,
    lastProtocol: settings?.lastDeviceProtocol,
    onMeshCore: () => ref
        .read(deviceConnectionProvider.notifier)
        .startMeshCoreReconnect(deviceId),
  )) {
    return;
  }
  _dispatchReconnect(ref, deviceId);
}

/// WidgetRef variant of [dispatchReconnectMeshCoreAware]. Mirrors the
/// `prepareForDeviceTransition` pattern: a thin wrapper for widget-layer
/// callers (banner Reconnect tap, etc.) that re-uses the same routing
/// rule as the internal `Ref` variant.
void dispatchReconnectMeshCoreAwareForWidget(WidgetRef ref, String deviceId) {
  final settings = ref.read(settingsServiceProvider).asData?.value;
  if (_routeMeshCoreReconnect(
    deviceId: deviceId,
    lastProtocol: settings?.lastDeviceProtocol,
    onMeshCore: () => ref
        .read(deviceConnectionProvider.notifier)
        .startMeshCoreReconnect(deviceId),
  )) {
    return;
  }
  // Meshtastic widget-layer callers should not normally hit this path
  // (autoReconnectManager owns Meshtastic dispatch). If this fires we
  // log it loudly so a future regression can be tracked down rather
  // than silently routing into the BLE scan loop.
  AppLogging.connection(
    '⚠️ dispatchReconnectMeshCoreAwareForWidget: non-meshcore protocol '
    'reached widget-layer reconnect dispatcher (deviceId=$deviceId) — '
    'ignoring; Meshtastic widgets should drive autoReconnectManager',
  );
}

/// Shared routing rule used by both Ref and WidgetRef variants. Returns
/// `true` if the call was handled by the MeshCore branch (caller should
/// short-circuit), `false` if the caller should run its Meshtastic path.
bool _routeMeshCoreReconnect({
  required String deviceId,
  required String? lastProtocol,
  required void Function() onMeshCore,
}) {
  if (lastProtocol != 'meshcore') return false;
  final transportTag = MeshCoreTcpDeviceId.tryParse(deviceId) != null
      ? 'tcp'
      : 'ble';
  AppLogging.connection(
    '🔄 dispatchReconnect: protocol=meshcore transport=$transportTag '
    'deviceId=$deviceId',
  );
  AppLogging.meshcore(
    'event=reconnect.requested protocol=meshcore transport=$transportTag',
  );
  onMeshCore();
  return true;
}

/// Test-only seam over [_routeMeshCoreReconnect]. Returns whether the
/// MeshCore branch was taken and, if so, the transport tag the dispatcher
/// would have logged. Exists so D27 routing tests can pin the rule
/// without standing up the full container + DeviceConnectionNotifier
/// + Meshtastic transport graph.
@visibleForTesting
({bool routed, String? transportTag}) routeMeshCoreReconnectForTest({
  required String deviceId,
  required String? lastProtocol,
}) {
  String? tag;
  final routed = _routeMeshCoreReconnect(
    deviceId: deviceId,
    lastProtocol: lastProtocol,
    onMeshCore: () {
      tag = MeshCoreTcpDeviceId.tryParse(deviceId) != null ? 'tcp' : 'ble';
    },
  );
  return (routed: routed, transportTag: tag);
}

/// WidgetRef wrapper for widget-layer callers (scanner, etc.). Delegates
/// to the Ref variant via the underlying container reference.
Future<ActiveDeviceTransition> prepareForDeviceTransition(
  WidgetRef ref, {
  required DeviceInfo device,
  String? deviceProtocol,
}) async {
  final settings = await ref.read(settingsServiceProvider.future);
  final transition = classifyDeviceTransition(
    newDeviceId: device.id,
    newDeviceName: device.name,
    newDeviceType: device.type,
    previousDeviceId: settings.lastDeviceId,
    previousDeviceType: settings.lastDeviceType,
    lastMyNodeNum: settings.lastMyNodeNum,
    lastDeviceName: settings.lastDeviceName,
  );

  AppLogging.connection(
    '🔄 DEVICE TRANSITION: kind=${transition.kind.name} '
    'prev=${transition.previousDeviceId} new=${transition.newDeviceId} '
    'prevType=${transition.previousTransportType?.name} '
    'newType=${transition.newTransportType.name} '
    'clearNodes=${transition.clearNodes} '
    'forceFreshHydration=${transition.forceFreshHydration}',
  );

  await settings.setLastDevice(
    device.id,
    _transportTypeToString(device.type),
    deviceName: device.name,
    protocol: deviceProtocol,
  );

  await clearDeviceDataBeforeConnect(
    ref,
    clearNodeData: transition.clearNodes,
    previousDeviceId: transition.previousDeviceId,
    newDeviceId: transition.newDeviceId,
    isTransportRebind: transition.isLogicalRebind,
  );

  // See the Ref variant for why this runs between the in-memory clear and
  // the transport flip.
  await RadioScope.instance.useDevice(
    deviceId: device.id,
    label: device.name,
    knownNodeNum: _scopeNodeNumForTransition(
      transition,
      settings.lastMyNodeNum,
    ),
  );

  if (transition.forceFreshHydration) {
    AppLogging.connection(
      '🔄 DEVICE TRANSITION: forceFreshHydration — preserving persisted '
      'node cache but rebuilding NodesNotifier against new transport',
    );
  }

  if (transition.transportFamilyChanged) {
    AppLogging.connection(
      '🔄 DEVICE TRANSITION: transport family flip '
      '${transition.previousTransportType?.name} → '
      '${transition.newTransportType.name}',
    );
    if (transition.newTransportType == TransportType.network) {
      final endpoint = _parseNetworkEndpointId(device.id);
      if (endpoint != null) {
        ref.read(networkTransportHostProvider.notifier).set(endpoint.host);
        ref.read(networkTransportPortProvider.notifier).set(endpoint.port);
      }
    }
    ref
        .read(transportTypeProvider.notifier)
        .setType(transition.newTransportType);
  }

  return transition;
}

/// Resets the in-memory view of the mesh before connecting to a
/// (potentially different) device. Should be called BEFORE protocol.start()
/// in all connection paths.
///
/// **This never deletes persisted data.** Isolation between radios is a
/// storage-scope concern now: each radio's stores live under its own scope
/// ([RadioScope]), so a switch swaps datasets and the previous radio's
/// history survives for when the user goes back to it. What this clears is
/// the in-memory node map and channel list, which would otherwise still be
/// showing the previous radio's mesh while the new one hydrates.
///
/// When both [previousDeviceId] and [newDeviceId] are non-null AND differ,
/// the in-memory reset happens regardless of [clearNodeData], so the new
/// radio never renders the previous one's nodes.
///
/// Pass [isTransportRebind] as `true` when the caller has already
/// determined (e.g. via `_tryLogicalDeviceMatch` or [isLogicalRebindForTest])
/// that the new BLE UUID belongs to the SAME physical radio as the last
/// one — BLE peripheral UUIDs rotate on ESP32 / nRF hardware. When true,
/// the raw-UUID mismatch auto-reset is suppressed so a same-radio reconnect
/// keeps the mesh on screen.
Future<void> clearDeviceDataBeforeConnect(
  WidgetRef ref, {
  bool clearNodeData = false,
  String? previousDeviceId,
  String? newDeviceId,
  bool isTransportRebind = false,
}) async {
  final isDeviceSwitch = _isDeviceSwitch(previousDeviceId, newDeviceId);
  if (isDeviceSwitch && isTransportRebind) {
    AppLogging.app(
      '🔁 Transport rebind ($previousDeviceId -> $newDeviceId) — same '
      'physical radio under a new BLE UUID; suppressing the device-switch '
      'reset so the mesh stays on screen',
    );
  } else if (isDeviceSwitch && !clearNodeData) {
    AppLogging.app(
      '🔁 Device switch detected ($previousDeviceId -> $newDeviceId) — '
      'resetting the in-memory node map so the new radio does not render '
      'the previous one\'s mesh while it hydrates',
    );
    clearNodeData = true;
  }

  // Capture every synchronous notifier reference before any await
  // below. If the caller is a widget that has already unmounted by
  // the time we get here (Scanner navigating away mid-connect), the
  // very first ref.read throws synchronously. Wrap the whole capture
  // block and bail; the awaited storage clears below have their own
  // try/catch and will short-circuit naturally on the disposed-ref
  // path. Crashlytics [E 4dfe564d] regressed on 1.39.0+174 because the
  // first attempt only handled mid-clear invalidation; this second
  // attempt handles before-capture invalidation too.
  final int messageCount;
  final NodesNotifier? nodesNotifier;
  final ChannelsNotifier channelsNotifier;
  final NewNodesCountNotifier newNodesNotifier;
  try {
    messageCount = ref.read(messagesProvider).length;
    nodesNotifier = clearNodeData ? ref.read(nodesProvider.notifier) : null;
    channelsNotifier = ref.read(channelsProvider.notifier);
    newNodesNotifier = ref.read(newNodesCountProvider.notifier);
  } catch (e) {
    AppLogging.app(
      '[E 4dfe564d] clearDeviceDataBeforeConnect: caller ref invalidated '
      'before sync capture (Scanner likely unmounted mid-connect); '
      'skipping clear: $e',
    );
    return;
  }

  AppLogging.app(
    '🧹 Clearing device data before new connection '
    '(preserving $messageCount messages${clearNodeData ? '' : ' and nodes'})...',
  );

  // Messages are intentionally NOT cleared here. They must survive
  // reconnections so that push-notification-delivered messages (and all
  // other user-received messages) are not lost. The deduplication logic
  // in MessagesNotifier (by id, packetId, content-fingerprint, and
  // signature) already prevents duplicates when the device re-sends
  // messages after reconnection.

  // Nodes are intentionally NOT cleared here by default. Like messages,
  // they must survive reconnections so that previously discovered mesh
  // nodes (which may exceed the device's limited NodeDB capacity of ~80)
  // are not lost. The merge logic in NodesNotifier handles deduplication
  // by nodeNum when the device re-sends its NodeDB after reconnection.
  // Pass clearNodeData: true only when switching to a new device or
  // explicitly forgetting the current one.
  // In-memory only. The persisted stores are radio-scoped, so the previous
  // radio's nodes, telemetry and routes stay in its own scope rather than
  // being deleted — see [RadioScope]. What has to go is the in-memory view,
  // which still holds the previous radio's mesh until the new one hydrates.
  nodesNotifier?.clearNodesInMemory();
  channelsNotifier.clearChannels();

  // Reset new-nodes badge counter so it doesn't accumulate across reconnections.
  // Without this, every reconnect re-discovers the same nodes and inflates the count.
  newNodesNotifier.reset();

  AppLogging.app(
    '✅ Device data cleared (in-memory nodes '
    '${clearNodeData ? 'reset' : 'preserved'}) - ready for fresh data from device',
  );
}

/// Ref-based version for use in providers (non-widget contexts).
/// See [clearDeviceDataBeforeConnect] for the device-switch auto-clear
/// and [isTransportRebind] semantics — they apply identically here.
Future<void> clearDeviceDataBeforeConnectRef(
  Ref ref, {
  bool clearNodeData = false,
  String? previousDeviceId,
  String? newDeviceId,
  bool isTransportRebind = false,
}) async {
  final isDeviceSwitch = _isDeviceSwitch(previousDeviceId, newDeviceId);
  if (isDeviceSwitch && isTransportRebind) {
    AppLogging.app(
      '🔁 Transport rebind ($previousDeviceId -> $newDeviceId) — same '
      'physical radio under a new BLE UUID; suppressing the device-switch '
      'reset so the mesh stays on screen',
    );
  } else if (isDeviceSwitch && !clearNodeData) {
    AppLogging.app(
      '🔁 Device switch detected ($previousDeviceId -> $newDeviceId) — '
      'resetting the in-memory node map so the new radio does not render '
      'the previous one\'s mesh while it hydrates',
    );
    clearNodeData = true;
  }
  final messageCount = ref.read(messagesProvider).length;
  AppLogging.app(
    '🧹 Clearing device data before new connection '
    '(preserving $messageCount messages${clearNodeData ? '' : ' and nodes'})...',
  );

  // Messages are intentionally NOT cleared here. They must survive
  // reconnections so that push-notification-delivered messages (and all
  // other user-received messages) are not lost. The deduplication logic
  // in MessagesNotifier (by id, packetId, content-fingerprint, and
  // signature) already prevents duplicates when the device re-sends
  // messages after reconnection.

  // Nodes are intentionally NOT cleared here by default. Like messages,
  // they must survive reconnections so that previously discovered mesh
  // nodes (which may exceed the device's limited NodeDB capacity of ~80)
  // are not lost. The merge logic in NodesNotifier handles deduplication
  // by nodeNum when the device re-sends its NodeDB after reconnection.
  // Pass clearNodeData: true only when switching to a new device or
  // explicitly forgetting the current one.
  // In-memory only. The persisted stores are radio-scoped, so the previous
  // radio's nodes, telemetry and routes stay in its own scope rather than
  // being deleted — see [RadioScope]. What has to go is the in-memory view,
  // which still holds the previous radio's mesh until the new one hydrates.
  if (clearNodeData) {
    ref.read(nodesProvider.notifier).clearNodesInMemory();
  }
  ref.read(channelsProvider.notifier).clearChannels();

  // Reset new-nodes badge counter so it doesn't accumulate across reconnections.
  ref.read(newNodesCountProvider.notifier).reset();

  AppLogging.app(
    '✅ Device data cleared (in-memory nodes '
    '${clearNodeData ? 'reset' : 'preserved'}) - ready for fresh data from device',
  );
}

// Store the last known device ID for reconnection attempts
class LastConnectedDeviceIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setId(String? id) => state = id;
}

final _lastConnectedDeviceIdProvider =
    NotifierProvider<LastConnectedDeviceIdNotifier, String?>(
      LastConnectedDeviceIdNotifier.new,
    );

/// Helper to clear the last connected device ID when the pairing is invalid.
void clearSavedDeviceId(Ref ref) {
  ref.read(_lastConnectedDeviceIdProvider.notifier).setId(null);
}

/// Bluetooth adapter state provider - tracks Bluetooth on/off
/// This is exposed so UI can react to Bluetooth state changes
final bluetoothStateProvider = StreamProvider<BluetoothAdapterState>((ref) {
  return FlutterBluePlus.adapterState;
});

/// Bluetooth state listener - monitors Bluetooth being turned off/on
/// and handles reconnection when Bluetooth is turned back on
final bluetoothStateListenerProvider = Provider<void>((ref) {
  AppLogging.connection('🔵 BLUETOOTH STATE LISTENER INITIALIZED');

  ref.listen<AsyncValue<BluetoothAdapterState>>(bluetoothStateProvider, (
    previous,
    next,
  ) async {
    // Extract the values from AsyncValue using when()
    final prevState = previous?.when(
      data: (state) => state,
      loading: () => null,
      error: (e, st) => null,
    );
    final currentState = next.when(
      data: (state) => state,
      loading: () => null,
      error: (e, st) => null,
    );

    AppLogging.connection(
      '🔵 Bluetooth state changed: $prevState -> $currentState',
    );

    // Handle Bluetooth being turned off
    if (currentState == BluetoothAdapterState.off &&
        prevState == BluetoothAdapterState.on) {
      AppLogging.connection(
        '🔵 Bluetooth turned OFF - connection will be lost',
      );
      // When Bluetooth is turned off, mark the disconnect as NOT user-initiated
      // (unless user had already disconnected before turning off BT)
      // The transport will handle the actual disconnection
    }

    // Handle Bluetooth being turned back on
    if (currentState == BluetoothAdapterState.on &&
        prevState == BluetoothAdapterState.off) {
      AppLogging.connection(
        '🔵 Bluetooth turned ON - checking if reconnect needed',
      );

      // Skip for MeshCore - this reconnect logic uses Meshtastic scanning
      final settings = await ref.read(settingsServiceProvider.future);
      if (settings.lastDeviceProtocol == 'meshcore') {
        AppLogging.connection(
          '🔵 Bluetooth ON but last device was MeshCore - not using Meshtastic reconnect',
        );
        return;
      }

      // Check if user manually disconnected - if so, don't auto-reconnect
      final userDisconnected = ref.read(userDisconnectedProvider);
      if (userDisconnected) {
        AppLogging.connection(
          '🔵 Bluetooth ON but user manually disconnected - not reconnecting',
        );
        return;
      }

      // Check if we have a device to reconnect to
      final lastDeviceId = ref.read(_lastConnectedDeviceIdProvider);
      if (lastDeviceId == null) {
        AppLogging.connection(
          '🔵 Bluetooth ON but no previous device to reconnect to',
        );
        return;
      }

      // Check current connection state using when() for proper null handling
      final connectionStateAsync = ref.read(connectionStateProvider);
      final connectionState = connectionStateAsync.when(
        data: (state) => state,
        loading: () => null,
        error: (e, st) => null,
      );
      if (connectionState == DeviceConnectionState.connected) {
        AppLogging.connection(
          '🔵 Bluetooth ON but already connected - no action needed',
        );
        return;
      }

      // Check auto-reconnect state
      final autoReconnectState = ref.read(autoReconnectStateProvider);
      if (autoReconnectState == AutoReconnectState.scanning ||
          autoReconnectState == AutoReconnectState.connecting) {
        AppLogging.connection(
          '🔵 Bluetooth ON but reconnect already in progress',
        );
        return;
      }

      // Trigger a reconnect attempt after a short delay to let BT stabilize
      AppLogging.connection(
        '🔵 Bluetooth ON - scheduling reconnect attempt in 2s',
      );

      Future.delayed(const Duration(seconds: 2), () async {
        // Recheck auto-reconnect setting (user may have toggled it during delay)
        final currentSettings = await ref.read(settingsServiceProvider.future);
        if (!currentSettings.autoReconnect) {
          AppLogging.connection(
            '🔵 BT reconnect cancelled - auto-reconnect disabled in settings',
          );
          return;
        }

        // Recheck conditions after delay
        final stillUserDisconnected = ref.read(userDisconnectedProvider);
        if (stillUserDisconnected) {
          AppLogging.connection(
            '🔵 BT reconnect cancelled - user disconnected during delay',
          );
          return;
        }

        // Recheck connection state
        final currentConnStateAsync = ref.read(connectionStateProvider);
        final currentConnState = currentConnStateAsync.when(
          data: (state) => state,
          loading: () => null,
          error: (e, st) => null,
        );
        if (currentConnState == DeviceConnectionState.connected) {
          AppLogging.connection(
            '🔵 BT reconnect cancelled - already connected',
          );
          return;
        }

        final currentAutoState = ref.read(autoReconnectStateProvider);
        if (currentAutoState == AutoReconnectState.scanning ||
            currentAutoState == AutoReconnectState.connecting) {
          AppLogging.connection(
            '🔵 BT reconnect cancelled - reconnect already in progress',
          );
          return;
        }

        // If the active transport is network, Bluetooth coming back on
        // is irrelevant — do not restart a BLE scan loop behind the
        // user's back. The network reconnect path is driven by the
        // autoReconnectManagerProvider listener on transport state.
        final dispatchTransport = ref.read(transportProvider);
        if (dispatchTransport.reconnectMode ==
            TransportReconnectMode.directEndpoint) {
          AppLogging.connection(
            '🔵 Bluetooth ON but active transport is '
            '${dispatchTransport.type.name} — skipping BLE reconnect',
          );
          return;
        }

        AppLogging.connection(
          '🔵 Bluetooth ON - starting reconnect for device: $lastDeviceId',
        );

        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.scanning);

        // D27: route through the protocol-aware dispatcher even though
        // the MeshCore guard above already returned early. Defence in
        // depth — a future regression in the early-return logic must
        // not be able to reintroduce a BLE scan for a saved MeshCore
        // peer.
        dispatchReconnectMeshCoreAware(ref, lastDeviceId);
      });
    }
  });
});

// Auto-reconnect manager - monitors connection and attempts to reconnect on unexpected disconnect
final autoReconnectManagerProvider = Provider<void>((ref) {
  AppLogging.connection('AUTO-RECONNECT MANAGER INITIALIZED');

  // Listen for config writes to the local node. These trigger firmware
  // reboot, so we enter recovery mode (increased patience + logical
  // matching) before the BLE disconnect event even arrives.
  StreamSubscription<void>? configWriteSub;
  void setupConfigWriteListener() {
    configWriteSub?.cancel();
    try {
      final protocol = ref.read(protocolServiceProvider);
      configWriteSub = protocol.localConfigWriteStream.listen((_) {
        AppLogging.connection(
          '🔄 Config write to local node detected — entering reboot recovery mode',
        );
        ref.read(rebootExpectedProvider.notifier).setRebootExpected(true);
      });
    } catch (_) {
      // Protocol service may not be initialized yet — that's fine,
      // the listener will be set up on next connection.
    }
  }

  setupConfigWriteListener();
  ref.onDispose(() => configWriteSub?.cancel());

  // Track the last connected device ID when we connect
  ref.listen<DeviceInfo?>(connectedDeviceProvider, (previous, next) {
    AppLogging.debug(
      '🔄 connectedDeviceProvider changed: ${previous?.id} -> ${next?.id}',
    );
    if (next != null) {
      AppLogging.connection('Storing device ID for reconnect: ${next.id}');
      ref.read(_lastConnectedDeviceIdProvider.notifier).setId(next.id);
      // Clear reboot-expected flag on successful connect — the reboot
      // cycle is complete and the new connection is established.
      ref.read(rebootExpectedProvider.notifier).setRebootExpected(false);
      // Re-subscribe to config writes on new connection (protocol service
      // may have been recreated).
      setupConfigWriteListener();
    }
  });

  // Listen for connection state changes
  // NOTE: This listener is for Meshtastic transport only.
  // MeshCore connection state is managed by ConnectionCoordinator.
  ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
    previous,
    next,
  ) {
    AppLogging.connection(
      'connectionStateProvider changed: $previous -> $next',
    );

    next.whenData((state) async {
      // Check if last device was MeshCore - if so, ignore Meshtastic transport state
      final settings = await ref.read(settingsServiceProvider.future);
      if (settings.lastDeviceProtocol == 'meshcore') {
        AppLogging.connection(
          '🔄 IGNORED: connectionStateProvider is Meshtastic-only, '
          'last device was MeshCore',
        );
        return;
      }

      final lastDeviceId = ref.read(_lastConnectedDeviceIdProvider);
      final autoReconnectState = ref.read(autoReconnectStateProvider);
      final userDisconnected = ref.read(userDisconnectedProvider);

      AppLogging.debug(
        '🔄 Connection state: $state (lastDeviceId: $lastDeviceId, '
        'reconnectState: $autoReconnectState, userDisconnected: $userDisconnected)',
      );

      // If connection comes back while we're in a reconnecting state,
      // reset to idle (the reconnect succeeded, possibly via BLE auto-reconnect)
      if (state == DeviceConnectionState.connected &&
          (autoReconnectState == AutoReconnectState.scanning ||
              autoReconnectState == AutoReconnectState.connecting)) {
        AppLogging.debug(
          '🔄 ✅ Connection restored while reconnecting - resetting to idle',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }

      // When connected, opportunistically refresh linked node metadata
      // after a delay to allow node info to be received from the device
      if (state == DeviceConnectionState.connected) {
        _refreshLinkedNodeMetadataAfterDelay(ref);
      }

      // CRITICAL: Check if user manually disconnected - never auto-reconnect in this case
      if (userDisconnected) {
        AppLogging.connection(
          '🔄 BLOCKED: User manually disconnected - not auto-reconnecting',
        );
        return;
      }

      // If user is manually connecting to a device, don't trigger auto-reconnect
      // This prevents auto-reconnect to the OLD saved device when the user taps
      // a DIFFERENT device and it times out (e.g., device is already connected to another phone)
      if (autoReconnectState == AutoReconnectState.manualConnecting) {
        AppLogging.connection(
          '🔄 BLOCKED: User is manually connecting - not auto-reconnecting',
        );
        return;
      }

      // Check if auto-reconnect is enabled in settings BEFORE triggering reconnect
      // (settings was already fetched above for protocol check)
      if (!settings.autoReconnect) {
        AppLogging.connection(
          '🔄 BLOCKED: Auto-reconnect is disabled in settings',
        );
        return;
      }

      // If disconnected and we have a device to reconnect to
      // Allow reconnect if state is idle OR success (just connected but not reset yet)
      final canAttemptReconnect =
          autoReconnectState == AutoReconnectState.idle ||
          autoReconnectState == AutoReconnectState.success;

      AppLogging.connection('Can attempt reconnect: $canAttemptReconnect');

      if (state == DeviceConnectionState.disconnected &&
          lastDeviceId != null &&
          canAttemptReconnect) {
        AppLogging.connection('🚀 Device disconnected, STARTING reconnect...');

        // Set state to scanning immediately to prevent duplicate triggers
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.scanning);

        // Run reconnect via protocol-aware dispatcher. The early MeshCore
        // bail above already returned, so this path is Meshtastic-only;
        // we keep the helper for defence in depth (D27).
        dispatchReconnectMeshCoreAware(ref, lastDeviceId);
      } else {
        AppLogging.connection('NOT attempting reconnect - conditions not met');
      }
    });
  });
});

/// Dispatch reconnection to the strategy that matches the active transport.
///
/// BLE → scan-based `_performReconnect` (existing BLE flow).
/// Network → direct-endpoint `_performNetworkReconnect` (no BLE scanning).
/// USB is scan-based via the existing path.
///
/// Kept as a single call-site helper so neither path can race the other
/// — a previous regression reset `transportTypeProvider` back to BLE on
/// disconnect which caused network peers to silently fall into a BLE
/// scan loop. See `DeviceConnectionNotifier._handleDisconnect` for the
/// transport-type preservation rule.
void _dispatchReconnect(Ref ref, String deviceId) {
  final transport = ref.read(transportProvider);
  switch (transport.reconnectMode) {
    case TransportReconnectMode.directEndpoint:
      AppLogging.connection(
        '🔄 _dispatchReconnect: transport=${transport.type.name} → '
        'network endpoint reconnect',
      );
      _performNetworkReconnect(ref, deviceId);
      return;
    case TransportReconnectMode.scanBased:
      _performReconnect(ref, deviceId);
      return;
  }
}

/// Parse a `tcp:host:port` deviceId (the identity format produced by
/// `NetworkConnectionSection` and `MdnsDiscoverySection`) into endpoint
/// components. Returns `null` if the id is not a network endpoint id.
@visibleForTesting
({String host, int port})? parseNetworkEndpointIdForTest(String deviceId) =>
    _parseNetworkEndpointId(deviceId);

/// Public accessor for callers outside this library (e.g. `main.dart`
/// startup path restoring the persisted transport family). Same
/// behaviour as the test-only variant above.
({String host, int port})? parseNetworkEndpointId(String deviceId) =>
    _parseNetworkEndpointId(deviceId);

({String host, int port})? _parseNetworkEndpointId(String deviceId) {
  // Normalize before parsing so `TCP:Node.Local:4403 ` and
  // `tcp:node.local:4403` collapse to the same reconnect key.
  // Hostnames are case-insensitive per RFC 4343.
  final trimmed = deviceId.trim();
  if (!trimmed.toLowerCase().startsWith('tcp:')) return null;
  final rest = trimmed.substring(4);
  if (rest.isEmpty) return null;

  String host;
  String portStr;

  // IPv6-bracketed form: `tcp:[::1]:4403`. Current UI does not emit this
  // shape but the parser accepts it so a future IPv6 discovery path
  // cannot silently produce an unreconnectable endpoint id.
  if (rest.startsWith('[')) {
    final close = rest.indexOf(']');
    if (close < 0) return null;
    host = rest.substring(1, close);
    if (close + 1 >= rest.length || rest[close + 1] != ':') return null;
    portStr = rest.substring(close + 2);
  } else {
    final lastColon = rest.lastIndexOf(':');
    if (lastColon <= 0 || lastColon == rest.length - 1) return null;
    host = rest.substring(0, lastColon);
    portStr = rest.substring(lastColon + 1);
  }

  host = host.trim().toLowerCase();
  if (host.isEmpty) return null;

  final port = int.tryParse(portStr);
  if (port == null || port <= 0 || port > 65535) return null;
  return (host: host, port: port);
}

/// Single in-flight network reconnect sentinel.
///
/// `_dispatchReconnect`'s callers already check `autoReconnectState` to
/// gate entry, but several lifecycle paths can race: transport
/// disconnect listener, connectivity-restored listener, BLE-on listener
/// (guarded for network), app-resume. A stuck state transition between
/// those guards — e.g. state still `scanning` from a previous run that
/// got abandoned mid-async — would let two callers both land in
/// `_performNetworkReconnect` and each call `transport.connect(...)`.
/// A single bool locked for the lifetime of the retry loop is cheap
/// belt-and-suspenders that fails closed regardless of state.
bool _networkReconnectInFlight = false;

@visibleForTesting
bool get networkReconnectInFlightForTest => _networkReconnectInFlight;

/// Direct-endpoint reconnect for TCP/network transport.
///
/// The BLE `_performReconnect` loop scans for BLE peripherals, which is
/// meaningless for a TCP peer. Network reconnect is an address-based
/// `connect()` with bounded backoff — no scanning, no logical matching,
/// no BLE cleanup.
///
/// Invariants:
/// - Uses the active `transportProvider` (already the NetworkTransport
///   because disconnect no longer resets `transportTypeProvider`).
/// - Does NOT kick off any BLE scans or listeners.
/// - Yields immediately if the user manually disconnected or started a
///   manual connection elsewhere (same guards as BLE path).
/// - At most one loop runs at a time (`_networkReconnectInFlight`).
/// - Bounded attempts so a dead endpoint does not burn battery forever.
///
/// Log tags: all lines prefixed `NET RECONNECT` so real-world failures
/// can be reconstructed by grepping a single token.
Future<void> _performNetworkReconnect(Ref ref, String deviceId) async {
  if (_networkReconnectInFlight) {
    AppLogging.connection(
      'NET RECONNECT: skipped — another reconnect loop is already active',
    );
    return;
  }
  _networkReconnectInFlight = true;
  try {
    await _runNetworkReconnect(ref, deviceId);
  } finally {
    _networkReconnectInFlight = false;
  }
}

Future<void> _runNetworkReconnect(Ref ref, String deviceId) async {
  AppLogging.connection('NET RECONNECT: start for endpoint "$deviceId"');

  final endpoint = _parseNetworkEndpointId(deviceId);
  if (endpoint == null) {
    AppLogging.connection(
      'NET RECONNECT: abandoned — deviceId "$deviceId" is not a '
      'tcp:host:port endpoint',
    );
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
    return;
  }

  if (ref.read(userDisconnectedProvider)) {
    AppLogging.connection(
      'NET RECONNECT: abandoned — user manually disconnected',
    );
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
    return;
  }

  final settings = await ref.read(settingsServiceProvider.future);
  if (!settings.autoReconnect) {
    AppLogging.connection(
      'NET RECONNECT: abandoned — auto-reconnect disabled in settings',
    );
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
    return;
  }

  // Keep the network endpoint pinned on the transport providers so the
  // provider factory rebuilds the NetworkTransport against the same
  // address we are about to reconnect to.
  ref.read(networkTransportHostProvider.notifier).set(endpoint.host);
  ref.read(networkTransportPortProvider.notifier).set(endpoint.port);

  const maxAttempts = 5;
  const baseDelay = Duration(seconds: 2);

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (ref.read(userDisconnectedProvider)) {
      AppLogging.connection(
        'NET RECONNECT: abandoned in loop — user manually disconnected',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    }
    final loopAutoState = ref.read(autoReconnectStateProvider);
    if (loopAutoState == AutoReconnectState.manualConnecting) {
      AppLogging.connection(
        'NET RECONNECT: abandoned — user is manually connecting',
      );
      return;
    }

    final transport = ref.read(transportProvider);
    // Defensive: if the transport type was explicitly switched away from
    // network by the user while we were retrying, abort rather than
    // fight their choice.
    if (transport.type != TransportType.network) {
      AppLogging.connection(
        'NET RECONNECT: abandoned — transport switched to '
        '${transport.type.name}',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    }
    if (transport.state == DeviceConnectionState.connected ||
        transport.state == DeviceConnectionState.connecting) {
      AppLogging.connection(
        'NET RECONNECT: abandoned — transport already '
        '${transport.state.name}',
      );
      return;
    }

    AppLogging.connection(
      'NET RECONNECT: attempt $attempt/$maxAttempts to '
      '${endpoint.host}:${endpoint.port}',
    );
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.connecting);

    final deviceInfo = DeviceInfo(
      id: deviceId,
      name: deviceId,
      type: TransportType.network,
      address: '${endpoint.host}:${endpoint.port}',
    );

    try {
      // Central transition prep — for NET RECONNECT this is almost
      // always `sameDevice` (we're reconnecting to the persisted TCP
      // endpoint), so no destructive clear fires. Still routed through
      // the helper so the preserve-vs-clear-vs-rehydrate decision
      // lives in exactly one place across BLE and TCP paths.
      await prepareForDeviceTransitionRef(
        ref,
        device: deviceInfo,
        deviceProtocol: 'meshtastic',
      );

      await transport.connect(deviceInfo);
      if (transport.state != DeviceConnectionState.connected) {
        throw Exception('TCP connect did not reach connected state');
      }
      AppLogging.connection(
        'NET RECONNECT: transport connected to '
        '${endpoint.host}:${endpoint.port} — starting protocol handshake',
      );

      ref.read(connectedDeviceProvider.notifier).setState(deviceInfo);

      final protocol = ref.read(protocolServiceProvider);
      protocol.setDeviceName(deviceInfo.name);
      protocol.setBleModelNumber(transport.bleModelNumber);
      protocol.setBleManufacturerName(transport.bleManufacturerName);

      // Restored: NET RECONNECT awaits protocol.start() so it doesn't
      // return AutoReconnectState.success until config has actually been
      // received. Removing this for the "single-owner" experiment broke
      // TCP — the transport-state listener fired its own start() in
      // parallel and the unawaited NET RECONNECT path turned the
      // connection over before config completed, producing endless
      // "Transport disconnected during configuration" loops. The
      // idempotency guard in `ProtocolService.start()` collapses the
      // listener's parallel call into a no-op so we still avoid
      // duplicate `_dataSubscription` listeners.
      await protocol.start();

      if (transport.state != DeviceConnectionState.connected) {
        throw Exception('Connection dropped before protocol start completed');
      }

      final locationService = ref.read(locationServiceProvider);
      await locationService.startLocationUpdates();

      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.success);
      AppLogging.connection(
        'NET RECONNECT: success — handshake complete on '
        '${endpoint.host}:${endpoint.port}',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    } catch (e) {
      AppLogging.connection(
        'NET RECONNECT: attempt $attempt/$maxAttempts failed — $e',
      );
      // Ensure any half-open socket is released before the next attempt
      // so the retry sees a clean transport state.
      try {
        await transport.disconnect();
      } catch (_) {}
      if (attempt < maxAttempts) {
        final delay = baseDelay * attempt;
        AppLogging.connection('NET RECONNECT: retrying in ${delay.inSeconds}s');
        await Future.delayed(delay);
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.scanning);
      }
    }
  }

  AppLogging.connection(
    'NET RECONNECT: exhausted $maxAttempts attempts — giving up',
  );
  ref
      .read(autoReconnectStateProvider.notifier)
      .setState(AutoReconnectState.failed);
}

/// Performs the actual reconnection logic
Future<void> _performReconnect(Ref ref, String deviceId) async {
  AppLogging.connection('_performReconnect STARTED for device: $deviceId');

  try {
    // CRITICAL: Check if user manually disconnected before waiting
    if (ref.read(userDisconnectedProvider)) {
      AppLogging.connection(
        '_performReconnect ABORTED: User manually disconnected',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    }

    // Wait for device to reboot (Meshtastic devices take ~8-15 seconds).
    // ESP32 devices performing SSL certificate generation after WiFi/network
    // config changes take significantly longer (60-120s), so we extend
    // the initial delay during reboot recovery to avoid premature scans.
    final rebootExpected = ref.read(rebootExpectedProvider);
    final initialDelay = rebootExpected
        ? const Duration(seconds: 20)
        : const Duration(seconds: 10);
    AppLogging.connection(
      'Waiting ${initialDelay.inSeconds}s for device to reboot '
      '(rebootExpected=$rebootExpected)...',
    );
    await Future.delayed(initialDelay);

    // CRITICAL: Check again after delay - user may have disconnected while waiting
    if (ref.read(userDisconnectedProvider)) {
      AppLogging.connection(
        '_performReconnect ABORTED after delay: User manually disconnected',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    }

    // Check if cancelled
    final currentState = ref.read(autoReconnectStateProvider);
    AppLogging.connection('After delay, reconnect state is: $currentState');
    if (currentState == AutoReconnectState.idle) {
      AppLogging.connection('Reconnect cancelled (state is idle)');
      return;
    }

    // CRITICAL: If the user started manually connecting to a (possibly
    // different) device while we were waiting, abort immediately.
    // Without this, _performReconnect continues its scan loop and will
    // connect to the OLD device, disconnecting the user's chosen device.
    if (currentState == AutoReconnectState.manualConnecting) {
      AppLogging.connection(
        '_performReconnect ABORTED after delay: User is manually connecting '
        '— not disrupting their connection',
      );
      return;
    }

    // If the reconnect was externally cancelled (e.g. TopStatusBanner
    // watchdog timeout or user tapped Cancel), abort gracefully.
    if (currentState == AutoReconnectState.failed) {
      AppLogging.connection(
        '_performReconnect ABORTED after delay: '
        'State set to failed externally (watchdog/cancel)',
      );
      return;
    }

    // CRITICAL: If the saved device ID changed while we were waiting
    // (user connected to a different device via Scanner), abort.
    final currentSavedDeviceId = ref.read(_lastConnectedDeviceIdProvider);
    if (currentSavedDeviceId != null && currentSavedDeviceId != deviceId) {
      AppLogging.connection(
        '_performReconnect ABORTED after delay: Saved device changed '
        '($deviceId → $currentSavedDeviceId) — user connected to a different device',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    }

    // Check settings for auto-reconnect preference
    AppLogging.connection('Checking settings...');
    final settings = await ref.read(settingsServiceProvider.future);
    AppLogging.connection('Auto-reconnect setting: ${settings.autoReconnect}');
    if (!settings.autoReconnect) {
      AppLogging.connection('Auto-reconnect disabled in settings');
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      return;
    }

    final transport = ref.read(transportProvider);
    AppLogging.connection('Got transport, current state: ${transport.state}');

    // Try up to 8 times (device may take a while to become discoverable after reboot)
    const maxRetries = 8;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      // CRITICAL: Check user disconnect flag at start of each attempt
      if (ref.read(userDisconnectedProvider)) {
        AppLogging.connection(
          '_performReconnect ABORTED in loop: User manually disconnected',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }

      // Check if cancelled
      final loopState = ref.read(autoReconnectStateProvider);
      if (loopState == AutoReconnectState.idle) {
        AppLogging.connection('Reconnect cancelled');
        return;
      }

      // CRITICAL: If the user started manually connecting (tapped a device
      // in Scanner), abort the background reconnect immediately. Continuing
      // would find the OLD device and call transport.connect(), which
      // disconnects the user's chosen device — creating a reconnect loop.
      if (loopState == AutoReconnectState.manualConnecting) {
        AppLogging.connection(
          '_performReconnect ABORTED in loop (attempt $attempt): '
          'User is manually connecting — yielding to Scanner',
        );
        return;
      }

      // If the reconnect was externally cancelled (e.g. TopStatusBanner
      // watchdog timeout or user tapped Cancel), abort gracefully.
      if (loopState == AutoReconnectState.failed) {
        AppLogging.connection(
          '_performReconnect ABORTED in loop (attempt $attempt): '
          'State set to failed externally (watchdog/cancel)',
        );
        return;
      }

      // CRITICAL: If the transport is already connected (user connected
      // to a device via Scanner while we were scanning), do NOT proceed
      // — calling transport.connect() on a different device would
      // disconnect the live connection.
      final transportState = ref.read(transportProvider).state;
      if (transportState == DeviceConnectionState.connected ||
          transportState == DeviceConnectionState.connecting) {
        AppLogging.connection(
          '_performReconnect ABORTED in loop (attempt $attempt): '
          'Transport already ${transportState.name} — not disrupting live connection',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }

      // Check if the saved device changed (user connected to different device)
      final loopSavedId = ref.read(_lastConnectedDeviceIdProvider);
      if (loopSavedId != null && loopSavedId != deviceId) {
        AppLogging.connection(
          '_performReconnect ABORTED in loop (attempt $attempt): '
          'Saved device changed ($deviceId → $loopSavedId)',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
        return;
      }

      if (ref.read(deviceConnectionProvider).state ==
          DevicePairingState.pairedDeviceInvalidated) {
        AppLogging.connection(
          '_performReconnect ABORTED: Saved device invalidated',
        );
        return;
      }

      AppLogging.connection(
        'Scan attempt $attempt/$maxRetries for device: $deviceId',
      );

      DeviceInfo? foundDevice;

      try {
        AppLogging.connection('Stopping any existing scan...');
        await FlutterBluePlus.stopScan();
        await Future.delayed(const Duration(milliseconds: 500));

        AppLogging.connection('Starting fresh BLE scan...');

        // Use FlutterBluePlus directly for more control
        final completer = Completer<DeviceInfo?>();
        StreamSubscription? subscription;

        // Meshtastic service UUID
        const serviceUuid = MeshtasticBleUuids.serviceUuid;

        // Collect ALL Meshtastic candidates for logical matching.
        // If the exact BLE ID is not found (e.g. ESP32 changed UUID
        // after reboot), we attempt to match by node identity.
        final allCandidates = <String, DeviceInfo>{};

        // Start scan with 15 second timeout
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 15),
          withServices: [Guid(serviceUuid)],
        );

        AppLogging.connection('Scan started, listening for results...');

        // Listen to scan results
        subscription = FlutterBluePlus.scanResults.listen(
          (results) {
            for (final r in results) {
              final foundId = r.device.remoteId.toString();
              AppLogging.connection(
                'Found device: $foundId (looking for $deviceId)',
              );

              final deviceInfo = DeviceInfo(
                id: foundId,
                name: r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : 'Meshtastic Device',
                type: TransportType.ble,
                address: foundId,
                rssi: r.rssi,
              );

              // Track all Meshtastic candidates by BLE ID
              allCandidates[foundId] = deviceInfo;

              // Fast path: exact BLE ID match
              if (foundId == deviceId && !completer.isCompleted) {
                AppLogging.connection('✓ Target device found (exact BLE ID)!');
                completer.complete(deviceInfo);
              }
            }
          },
          onError: (e) {
            AppLogging.connection('Scan stream error: $e');
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          },
        );

        // Also listen for scan completion
        FlutterBluePlus.isScanning.listen((isScanning) {
          if (!isScanning && !completer.isCompleted) {
            AppLogging.connection('Scan completed (isScanning = false)');
            completer.complete(null);
          }
        });

        // Wait for result or scan completion
        AppLogging.connection('Waiting for scan result (15s timeout)...');
        foundDevice = await completer.future.timeout(
          const Duration(seconds: 16),
          onTimeout: () {
            AppLogging.connection('Completer timeout reached');
            return null;
          },
        );
        AppLogging.connection('Got scan result: ${foundDevice?.id}');

        // Clean up
        await FlutterBluePlus.stopScan();
        subscription.cancel();
        AppLogging.connection('Cleanup done');

        // ── Logical matching fallback ──
        // If exact BLE ID was not found but other Meshtastic devices
        // were discovered, attempt to match by node identity. Meshtastic
        // BLE names follow the pattern "Meshtastic_XXXX" where XXXX is
        // the last 4 hex digits of the node number. This is stable
        // across reboots even when the BLE peripheral UUID changes
        // (common on ESP32 devices).
        if (foundDevice == null && allCandidates.isNotEmpty) {
          foundDevice = _tryLogicalDeviceMatch(
            ref,
            allCandidates: allCandidates,
            previousDeviceId: deviceId,
          );
        }
      } catch (e, stack) {
        AppLogging.connection('Scan error: $e');
        AppLogging.connection('Stack: $stack');
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
      }

      AppLogging.connection('After scan. foundDevice: ${foundDevice != null}');

      if (foundDevice != null) {
        // CRITICAL: Final guard before connecting — if the user manually
        // connected to a different device while we were scanning, do NOT
        // call transport.connect() because it would disconnect their device.
        final preConnectState = ref.read(autoReconnectStateProvider);
        final preConnectTransport = ref.read(transportProvider).state;
        if (preConnectState == AutoReconnectState.manualConnecting ||
            preConnectState == AutoReconnectState.idle) {
          AppLogging.connection(
            '_performReconnect ABORTED before connect: '
            'state=$preConnectState — not disrupting user connection',
          );
          if (preConnectState != AutoReconnectState.idle) {
            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.idle);
          }
          return;
        }
        if (preConnectTransport == DeviceConnectionState.connected ||
            preConnectTransport == DeviceConnectionState.connecting) {
          AppLogging.connection(
            '_performReconnect ABORTED before connect: '
            'transport already ${preConnectTransport.name}',
          );
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.idle);
          return;
        }

        AppLogging.connection('Device found! Connecting...');

        // If this device was matched via logical identity (not exact BLE
        // ID), update the persisted transport identity so future fast-path
        // reconnects use the new BLE UUID.
        final isTransportRebind = foundDevice.id != deviceId;
        if (isTransportRebind) {
          AppLogging.connection(
            '🔄 TRANSPORT REBIND: BLE ID changed $deviceId → ${foundDevice.id} '
            '(logical match by name: ${foundDevice.name})',
          );
          // Update in-memory last-connected ID so subsequent loop
          // iterations and abort-checks use the correct value.
          ref
              .read(_lastConnectedDeviceIdProvider.notifier)
              .setId(foundDevice.id);
        }

        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.connecting);

        try {
          await transport.connect(foundDevice);

          // Check if cancelled (connection may have been restored by another path)
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            AppLogging.connection('Reconnect cancelled (already connected)');
            return;
          }

          // Wait a moment for connection to stabilize
          AppLogging.connection('Waiting for connection to stabilize...');
          await Future.delayed(const Duration(seconds: 2));

          // Check if cancelled again
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            AppLogging.connection('Reconnect cancelled (already connected)');
            return;
          }

          // Check if still connected
          if (transport.state != DeviceConnectionState.connected) {
            AppLogging.connection(
              '❌ Connection dropped after connect, retrying...',
            );
            if (attempt < maxRetries) {
              ref
                  .read(autoReconnectStateProvider.notifier)
                  .setState(AutoReconnectState.scanning);
              await Future.delayed(const Duration(seconds: 3));
              continue; // Try again
            }
            throw Exception('Connection dropped after connect');
          }

          // Update connected device
          ref.read(connectedDeviceProvider.notifier).setState(foundDevice);

          // Check if cancelled before starting protocol
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            AppLogging.connection('Reconnect cancelled (already connected)');
            return;
          }

          // Restart protocol service
          AppLogging.connection('Starting protocol service...');

          // Central transition prep — single source of truth for the
          // preserve-vs-clear-vs-rehydrate decision. The classifier
          // inside will detect a same-radio BLE UUID rotation as
          // `transportRebind` (no clear) via lastMyNodeNum / name
          // match, independently of the `isTransportRebind` we
          // computed from the logical-match fallback during scan.
          await prepareForDeviceTransitionRef(
            ref,
            device: foundDevice,
            deviceProtocol: 'meshtastic',
          );

          final protocol = ref.read(protocolServiceProvider);

          // Set device info for hardware model inference
          protocol.setDeviceName(foundDevice.name);
          protocol.setBleModelNumber(transport.bleModelNumber);
          protocol.setBleManufacturerName(transport.bleManufacturerName);

          // Canonical restore (refresh notifications -> stop -> bind
          // session generation -> start) instead of a raw protocol.start().
          // The coordinator's single-flight also collapses the race with
          // the transport state-listener reconnect path, which fires on
          // the same `connected` transition.
          await ref
              .read(deviceConnectionProvider.notifier)
              .restoreSessionForAutoReconnect();
          AppLogging.connection('Protocol service started!');

          // Check if cancelled after protocol start
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            AppLogging.connection('Reconnect cancelled (already connected)');
            return;
          }

          // Check again if still connected after protocol start
          await Future.delayed(const Duration(milliseconds: 500));
          if (transport.state != DeviceConnectionState.connected) {
            AppLogging.debug(
              '🔄 ❌ Connection dropped after protocol start, retrying...',
            );
            if (attempt < maxRetries) {
              ref
                  .read(autoReconnectStateProvider.notifier)
                  .setState(AutoReconnectState.scanning);
              await Future.delayed(const Duration(seconds: 3));
              continue; // Try again
            }
            throw Exception('Connection dropped after protocol start');
          }

          // Restart phone GPS location updates
          final locationService = ref.read(locationServiceProvider);
          await locationService.startLocationUpdates();

          // Final check - if we're still connected, declare success.
          // (Note: prepareForDeviceTransitionRef above already persisted
          // the new BLE id to settings, so no REBIND COMPLETE write is
          // needed here — the prep runs pre-clear specifically so the
          // new id survives even if protocol start subsequently fails.)
          if (transport.state == DeviceConnectionState.connected) {
            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.success);
            AppLogging.connection('✅ Reconnection successful and stable!');

            // Reset to idle
            await Future.delayed(const Duration(milliseconds: 500));
            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.idle);
            return; // Success!
          } else {
            AppLogging.connection('❌ Connection dropped at final check');
            if (attempt < maxRetries) {
              ref
                  .read(autoReconnectStateProvider.notifier)
                  .setState(AutoReconnectState.scanning);
              await Future.delayed(const Duration(seconds: 3));
              continue;
            }
          }
        } catch (e) {
          if (isPairingInvalidationError(e)) {
            await ref
                .read(deviceConnectionProvider.notifier)
                .handlePairingInvalidation(
                  PairingInvalidationReason.peerReset,
                  appleCode: pairingInvalidationAppleCode(e),
                );
            return;
          }

          AppLogging.connection('❌ Connect error: $e');
          // Check if we should abort (connection restored via another path)
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            AppLogging.debug(
              '🔄 Reconnect cancelled (already connected), ignoring error',
            );
            return;
          }
          if (attempt < maxRetries) {
            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.scanning);
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
        }
      } else {
        AppLogging.connection(
          'Device not found in attempt $attempt, waiting 5s...',
        );

        // During reboot recovery, do NOT report missing device — the
        // node is expected to be offline while regenerating its SSL
        // certificate and restarting. Without this guard,
        // reportMissingSavedDevice() fires invalidation after just 3
        // misses, dumping the user to the scanner screen even though
        // the scan loop has 8 retries specifically to handle slow reboots.
        final rebootRecovery = ref.read(rebootExpectedProvider);
        if (!rebootRecovery) {
          final invalidated = await ref
              .read(deviceConnectionProvider.notifier)
              .reportMissingSavedDevice();
          if (invalidated) {
            return;
          }
        } else {
          AppLogging.connection(
            '🔄 Reboot recovery active — skipping invalidation check '
            '(attempt $attempt/$maxRetries)',
          );
        }
        if (attempt < maxRetries) {
          // Wait longer before next retry - device may still be rebooting
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }

    // All retries exhausted
    AppLogging.connection('❌ Failed to reconnect after $maxRetries attempts');
    // Clear reboot recovery flag — we gave it our best shot.
    ref.read(rebootExpectedProvider.notifier).setRebootExpected(false);
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.failed);

    // Don't clear the device ID - user might want to manually reconnect
    // Just reset to idle after showing failure
    await Future.delayed(const Duration(seconds: 2));
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
  } catch (e, stackTrace) {
    AppLogging.connection('❌ Unexpected error during reconnect: $e');
    AppLogging.connection('Stack trace: $stackTrace');
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
  }
}

/// Attempts to match a Meshtastic device by logical identity when the
/// exact BLE peripheral UUID is not found (e.g. after ESP32 reboot that
/// changes the BLE MAC address).
///
/// Meshtastic BLE advertisements use the name pattern "Meshtastic_XXXX"
/// (or custom short name variants like "WIS_XXXX") where the last 4
/// characters are the hex representation of the lower 16 bits of the
/// node number. This suffix is derived from the node number stored in
/// flash and is stable across reboots.
///
/// Matching tiers:
///   Strong — BLE name suffix matches the last 4 hex digits of
///            `lastMyNodeNum` (persisted from the previous session).
///   Medium — BLE advertised name exactly matches `lastDeviceName`.
///   Weak   — any single Meshtastic device (never auto-matched).
///
/// Only strong matches are used for automatic rebind. Medium matches
/// are logged but not auto-bound (future: could present a chooser).
DeviceInfo? _tryLogicalDeviceMatch(
  Ref ref, {
  required Map<String, DeviceInfo> allCandidates,
  required String previousDeviceId,
}) {
  final settings = ref.read(settingsServiceProvider).value;
  if (settings == null) return null;

  final lastNodeNum = settings.lastMyNodeNum;
  final lastDeviceName = settings.lastDeviceName;

  AppLogging.connection(
    '🔍 LOGICAL MATCH: Trying to match ${allCandidates.length} '
    'candidate(s) — lastNodeNum=${lastNodeNum != null ? lastNodeNum.toRadixString(16) : "null"}, '
    'lastDeviceName=$lastDeviceName, previousBleId=$previousDeviceId',
  );

  // Log all candidates for diagnostics
  for (final entry in allCandidates.entries) {
    AppLogging.connection(
      '🔍 LOGICAL MATCH: Candidate bleId=${entry.key}, '
      'name=${entry.value.name}',
    );
  }

  // ── Strong match: node number suffix in BLE name ──
  if (lastNodeNum != null) {
    final expectedSuffix = lastNodeNum
        .toRadixString(16)
        .padLeft(4, '0')
        .substring(lastNodeNum.toRadixString(16).padLeft(4, '0').length - 4);

    final strongMatches = allCandidates.values.where((device) {
      return bleNameMatchesNodeNum(device.name, expectedSuffix);
    }).toList();

    if (strongMatches.length == 1) {
      final match = strongMatches.first;
      AppLogging.connection(
        '🔍 LOGICAL MATCH: ✅ STRONG match found! '
        'name=${match.name} bleId=${match.id} '
        '(suffix=$expectedSuffix matches nodeNum=${lastNodeNum.toRadixString(16)})',
      );
      return match;
    }

    if (strongMatches.length > 1) {
      AppLogging.connection(
        '🔍 LOGICAL MATCH: ⚠️ Multiple strong matches '
        '(${strongMatches.length}) — ambiguous, not auto-binding. '
        'Names: ${strongMatches.map((d) => d.name).join(", ")}',
      );
      // Ambiguous: multiple devices with the same node number suffix.
      // This is very unlikely but possible with cloned devices.
      return null;
    }

    AppLogging.connection(
      '🔍 LOGICAL MATCH: No strong match by nodeNum suffix ($expectedSuffix)',
    );
  }

  // ── Medium match: exact advertised name ──
  if (lastDeviceName != null && lastDeviceName.isNotEmpty) {
    final nameMatches = allCandidates.values.where((device) {
      return device.name == lastDeviceName;
    }).toList();

    if (nameMatches.length == 1) {
      final match = nameMatches.first;
      AppLogging.connection(
        '🔍 LOGICAL MATCH: 🟡 MEDIUM match by name="${match.name}" '
        'bleId=${match.id} — name matches lastDeviceName. '
        'Auto-binding (single candidate with exact name).',
      );
      // Single device with exact same name — safe to rebind.
      // This handles cases where lastMyNodeNum was cleared or unknown
      // but the device name is distinctive enough.
      return match;
    }

    if (nameMatches.isNotEmpty) {
      AppLogging.connection(
        '🔍 LOGICAL MATCH: 🟡 ${nameMatches.length} name matches '
        'for "$lastDeviceName" — ambiguous, not auto-binding',
      );
    }
  }

  AppLogging.connection(
    '🔍 LOGICAL MATCH: ❌ No safe logical match found among '
    '${allCandidates.length} candidate(s)',
  );
  return null;
}

/// Returns `true` if [bleName] ends with the 4-hex suffix [expectedSuffix].
///
/// Meshtastic default names are "Meshtastic_XXXX". Custom short names
/// follow similar patterns. We check case-insensitively whether the
/// portion after the last underscore matches.
@visibleForTesting
bool bleNameMatchesNodeNum(String bleName, String expectedSuffix) {
  final underscoreIndex = bleName.lastIndexOf('_');
  if (underscoreIndex < 0 || underscoreIndex >= bleName.length - 1) {
    return false;
  }
  final nameSuffix = bleName.substring(underscoreIndex + 1).toLowerCase();
  return nameSuffix == expectedSuffix.toLowerCase();
}

// Current RSSI stream from protocol service
final currentRssiProvider = StreamProvider<int>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);
  await for (final rssi in protocol.rssiStream) {
    yield rssi;
  }
});

// Current SNR (Signal-to-Noise Ratio) stream from protocol service
final currentSnrProvider = StreamProvider<double>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);
  await for (final snr in protocol.snrStream) {
    yield snr;
  }
});

// Current channel utilization stream from protocol service
final currentChannelUtilProvider = StreamProvider<double>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);
  await for (final util in protocol.channelUtilStream) {
    yield util;
  }
});

// Push notification service provider (wraps existing singleton)
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService();
});

// Deliberately does NOT watch radioScopeProvider, unlike the other scoped
// stores. protocolServiceProvider watches this provider, so a rebuild here
// tears down the live ProtocolService - and the scope promotion that fires
// when a first-ever radio reports its node number lands seconds AFTER the
// config handshake completed, which replaced a configured protocol instance
// with a fresh one that never ran start(). The session then looked connected
// but had no channels, no config, and no handshake. The store instead
// re-scopes itself: RadioScope closes it before a scope switch, and the next
// hasSeen/markSeen reopens it against the new scope's database path.
final meshPacketDedupeStoreProvider = Provider<MeshPacketDedupeStore>((ref) {
  final store = MeshPacketDedupeStore();
  unawaited(
    store.init().catchError((Object e) {
      AppLogging.protocol('MeshPacketDedupeStore init failed (non-fatal): $e');
    }),
  );
  ref.onDispose(() {
    RadioScope.instance.unregisterCloser(store);
    unawaited(store.dispose());
  });
  return store;
});

// Protocol service - singleton instance that persists across rebuilds
// Display-units preference (metric/imperial) sourced from the device's
// Meshtastic DisplayConfig. Seeds from the cached config, then tracks live
// updates from the device. Falls back to metric when no config is known yet.
final displayUnitsStreamProvider = StreamProvider<MeasurementUnits>((
  ref,
) async* {
  final protocol = ref.watch(protocolServiceProvider);
  MeasurementUnits toUnits(
    config_pbenum.Config_DisplayConfig_DisplayUnits? units,
  ) => units == config_pbenum.Config_DisplayConfig_DisplayUnits.IMPERIAL
      ? MeasurementUnits.imperial
      : MeasurementUnits.metric;
  yield toUnits(protocol.currentDisplayConfig?.units);
  yield* protocol.displayConfigStream.map((c) => toUnits(c.units));
});

// Synchronous accessor every distance formatter reads. Distance strings must
// route through `formatDistanceMeters` with this value so toggling Imperial in
// Display Settings is honoured app-wide.
final measurementUnitsProvider = Provider<MeasurementUnits>((ref) {
  return ref.watch(displayUnitsStreamProvider).asData?.value ??
      MeasurementUnits.metric;
});

final protocolServiceProvider = Provider<ProtocolService>((ref) {
  final transport = ref.watch(transportProvider);
  final dedupeStore = ref.watch(meshPacketDedupeStoreProvider);
  final service = ProtocolService(transport, dedupeStore: dedupeStore);

  // Trust + Safety gate. The adapter holds a closure that re-reads
  // the live `PeerSafetyManager` on each call, so changing block
  // state here propagates to the protocol layer without needing
  // this provider to rebuild. `ref.read` (not watch) is deliberate.
  service.attachPeerSafetyGate(ref.read(peerSafetyGateProvider));

  service.onIdentityUpdate =
      ({
        required int nodeNum,
        String? longName,
        String? shortName,
        int? lastSeenAtMs,
      }) {
        ref
            .read(nodeIdentityProvider.notifier)
            .upsertIdentity(
              nodeNum: nodeNum,
              longName: longName,
              shortName: shortName,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
              lastSeenAtMs: lastSeenAtMs,
            );
      };

  // Clear a pending unfavorite tombstone once the device's NodeDB replay
  // confirms is_favorite=false. `ref.read` is deliberate: the callback
  // fires long after provider build.
  service.onNodeDbFavoriteReported = (int nodeNum, bool isFavorite) {
    if (isFavorite) return;
    final favorites = ref.read(deviceFavoritesProvider).value;
    if (favorites != null && favorites.isTombstoned(nodeNum)) {
      unawaited(favorites.clearUnfavoriteTombstone(nodeNum));
      AppLogging.nodes(
        'Unfavorite tombstone confirmed by device for node $nodeNum',
      );
    }
  };

  AppLogging.debug(
    '🟢 ProtocolService provider created - instance: ${service.hashCode}',
  );

  // Set up notification reaction callback to send true tapbacks.
  NotificationService()
      .onReactionSelected = (MessageReactionTarget target, String emoji) async {
    try {
      final toNodeNum = target.isChannelMessage ? 0xFFFFFFFF : target.toNodeNum;
      AppLogging.app(
        'Sending reaction "$emoji" to node $toNodeNum '
        '(channel=${target.channelIndex}, replyPacketId=${target.replyPacketId})',
      );
      await service.sendMessage(
        text: emoji,
        to: toNodeNum,
        channel: target.channelIndex ?? 0,
        wantAck: !target.isChannelMessage,
        source: MessageSource.reaction,
        replyId: target.replyPacketId,
        isEmoji: true,
      );
      AppLogging.app('Reaction sent successfully');
    } catch (e) {
      AppLogging.app('Failed to send reaction: $e');
    }
  };

  // Reticulum subsystem: dispatch port-76 fragment events to the
  // capture writer, NodeDex bridge, and stats notifier. All three are
  // pushed-to from this single listener; none of them ref.watch
  // protocolServiceProvider, which keeps the provider DAG acyclic.
  //
  // Gated by AppFeatureFlags.isReticulumTunnelEnabled. When the flag
  // is off (default), no providers are instantiated and no
  // subscription is created — the broadcast controller in ProtocolService
  // exists but never has any listeners, and its handler is short-
  // circuited at the switch in _handleMeshPacket. Net cost when off:
  // a single boolean comparison per port-76 packet.
  StreamSubscription<ReticulumFragmentEvent>? reticulumSub;
  if (AppFeatureFlags.isReticulumTunnelEnabled) {
    // Eagerly init the stats notifier so it's alive (and its tick
    // timer is running) from app boot, not just when the diagnostics
    // UI is first opened.
    ref.read(reticulumStatsProvider.notifier);

    reticulumSub = service.reticulumFragmentStream.listen((event) {
      try {
        ref.read(reticulumCaptureWriterProvider).write(event);
        ref.read(reticulumNodeDexBridgeProvider).onFragment(event);
        ref.read(reticulumStatsProvider.notifier).recordFragment(event);
        // Phase 2: feed the reassembler when the per-user toggle is
        // on. This is independent of the build-time env flag — the
        // env flag gates the entire subsystem; this gates only the
        // reassembly layer (since it produces RNS-frame events that
        // a future Phase 3 bridge would consume).
        if (ref.read(reticulumFlagsProvider).reassemblyEnabled) {
          ref.read(reticulumReassemblerProvider).onFragment(event);
        }
      } catch (e) {
        AppLogging.reticulum('pipeline_dispatch_error error=$e');
      }
    });
  }

  // Keep the service alive for the lifetime of the app
  ref.onDispose(() {
    AppLogging.debug(
      '🔴 ProtocolService being disposed - instance: ${service.hashCode}',
    );
    // Clear the callback when disposing
    NotificationService().onReactionSelected = null;
    reticulumSub?.cancel();
    service.stop();
  });

  return service;
});

/// Stream provider for client notifications from firmware.
/// These are important messages (errors, warnings) that should be shown to the user.
final clientNotificationStreamProvider =
    StreamProvider<mesh_pb.ClientNotification>((ref) {
      final protocol = ref.watch(protocolServiceProvider);
      return protocol.clientNotificationStream;
    });

/// Stream provider for device firmware debug logs (from LogRadio BLE characteristic).
/// Only available when connected via BLE.
final deviceLogStreamProvider = StreamProvider<mesh_pb.LogRecord>((ref) {
  final transport = ref.watch(transportProvider);

  // Device logs are only available via BLE transport
  if (transport is BleTransport) {
    return transport.deviceLogStream;
  }

  // Return an empty stream for non-BLE transports
  return const Stream.empty();
});

// Phone position publish governor — centralized rate-limiting and distance
// gating for all phone-GPS-to-mesh publish paths. Shared across
// LocationService, SharePositionCommand, WidgetActionHandler, and dashboard
// quick actions. Enforces minInterval (300s auto / 60s manual) and
// minDistance (150m) so stationary users do not spam the mesh.
final phonePositionGovernorProvider = Provider<PhonePositionGovernor>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  final governor = PhonePositionGovernor(
    protocol,
    isLocationSharingEnabled: () {
      return _cachedSettingsService?.providePhoneLocation ?? false;
    },
  );
  return governor;
});

// Location service - provides phone GPS to mesh devices
// Like iOS Meshtastic app, sends phone GPS coordinates to mesh
// when device doesn't have its own GPS hardware.
// Gated by SettingsService.providePhoneLocation (default: false),
// matching the standard Meshtastic companion app behaviour (opt-in, default off).
// All publishes route through PhonePositionGovernor for rate limiting.
final locationServiceProvider = Provider<LocationService>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  final governor = ref.watch(phonePositionGovernorProvider);
  final service = LocationService(
    protocol,
    isLocationSharingEnabled: () {
      // Read from cached settings synchronously. The callback is
      // evaluated on every 30-second tick inside LocationService,
      // mirroring the standard Meshtastic companion app pattern where
      // the location-sharing preference is checked on every tick.
      return _cachedSettingsService?.providePhoneLocation ?? false;
    },
    governor: governor,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// IFTTT service - handles webhook triggers
final iftttServiceProvider = Provider<IftttService>((ref) {
  final service = IftttService();
  return service;
});

// Live Activity service - shows device status on iOS Lock Screen and Dynamic Island
final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  final service = LiveActivityService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// Live Activity manager - monitors connection and updates Live Activity
class LiveActivityManagerNotifier extends Notifier<bool> {
  StreamSubscription<double>? _channelUtilSubscription;
  StreamSubscription<int>? _rssiSubscription;
  StreamSubscription<double>? _snrSubscription;
  late LiveActivityService _liveActivityService;

  /// Last BLE RSSI value from the protocol service's polling timer.
  /// This is the Bluetooth signal strength between the phone and the radio,
  /// NOT the mesh radio's self-RSSI (which is always null for the local node).
  int? _lastBleRssi;

  /// Last SNR value from received mesh packets.
  double? _lastSnr;

  /// Debounce timer for node-triggered Live Activity updates.
  ///
  /// During initial config the radio dumps ~42 NodeInfo packets in rapid
  /// succession. Each one triggers [_updateFromNodes] which crosses the
  /// Flutter→native bridge to write UserDefaults. Debouncing coalesces
  /// the burst into a single write after the storm settles (500 ms).
  Timer? _nodeUpdateDebounce;
  static const _nodeUpdateDebounceDelay = Duration(milliseconds: 500);

  /// Coalesce timer for stream-driven Live Activity updates (RSSI, SNR,
  /// channel utilization). Instead of crossing the native bridge on every
  /// individual stream event, we set a dirty flag and flush all accumulated
  /// changes in a single `updateActivity()` call every 2 seconds. This
  /// reduces native bridge calls by ~60-80% compared to per-event updates.
  Timer? _coalesceTimer;
  static const _coalesceInterval = Duration(seconds: 2);
  bool _streamDirty = false;

  /// Ring buffer of recent BLE RSSI samples — feeds the lock-screen aurora
  /// curve. Oldest first, newest last. Capped at [_signalHistoryCap] entries
  /// to keep UserDefaults writes small and the SwiftUI Path render cheap.
  final List<int> _signalHistory = <int>[];
  static const int _signalHistoryCap = 30;

  /// User's chosen Live Activity destination mode (mesh / bestPeer /
  /// activePeer). Reloaded from SharedPreferences each time a new activity
  /// starts so changes in the settings screen apply on the next reconnect.
  LiveActivityDestination _destinationMode = LiveActivityDestination.mesh;

  @override
  bool build() {
    _liveActivityService = ref.watch(liveActivityServiceProvider);

    // Set up disposal
    ref.onDispose(() {
      _channelUtilSubscription?.cancel();
      _rssiSubscription?.cancel();
      _snrSubscription?.cancel();
      _nodeUpdateDebounce?.cancel();
      _coalesceTimer?.cancel();
      _liveActivityService.endAllActivities();
    });

    _init();
    return false;
  }

  void _init() {
    // Listen for connection state changes
    // NOTE: This listener is for Meshtastic transport only.
    // MeshCore devices don't support Live Activities via this path.
    ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
      previous,
      current,
    ) {
      current.whenData((connectionState) async {
        try {
          // Skip for MeshCore devices - they use ConnectionCoordinator state
          final settings = await ref.read(settingsServiceProvider.future);
          if (!ref.mounted) return;
          if (settings.lastDeviceProtocol == 'meshcore') {
            return;
          }

          if (connectionState == DeviceConnectionState.connected && !state) {
            _startLiveActivity();
          } else if (connectionState == DeviceConnectionState.disconnected &&
              state) {
            _endLiveActivity();
          }
        } catch (e) {
          // Provider may have been disposed during the async gap —
          // swallow the error to prevent ProviderElement._notifyListeners crash.
          AppLogging.debug(
            'LiveActivityManager: ignoring error in listener: $e',
          );
        }
      });
    }, fireImmediately: true);

    // Listen for node updates to refresh battery/signal/online count.
    // Debounced to avoid 42+ rapid UserDefaults writes during initial
    // config when the radio dumps all NodeInfo packets at once.
    ref.listen<Map<int, MeshNode>>(nodesProvider, (previous, current) {
      if (!state || !_liveActivityService.isActive) return;
      _nodeUpdateDebounce?.cancel();
      _nodeUpdateDebounce = Timer(_nodeUpdateDebounceDelay, () {
        _updateFromNodes(current);
      });
    });
  }

  Future<void> _startLiveActivity() async {
    // Respect the user's in-app Live Activity preference.
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(kLiveActivityEnabled) ?? true;
    if (!enabled) {
      AppLogging.debug(
        '📱 Live Activity disabled by user preference — skipping',
      );
      return;
    }

    // Reload destination mode every start so the settings screen takes
    // effect on the next reconnect without a full app relaunch.
    _destinationMode = LiveActivityDestination.fromValue(
      prefs.getInt(kLiveActivityDestination) ?? 0,
    );

    final connectedDevice = ref.read(connectedDeviceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final protocol = ref.read(protocolServiceProvider);

    // Get my node info for display
    MeshNode? myNode;
    if (myNodeNum != null && nodes.containsKey(myNodeNum)) {
      myNode = nodes[myNodeNum];
    }

    final deviceName =
        myNode?.longName ?? connectedDevice?.name ?? 'Meshtastic';
    final shortName = myNode?.shortName ?? '????';
    final batteryLevel = myNode?.batteryLevel;

    // Use BLE RSSI (phone↔radio Bluetooth signal) instead of myNode.rssi
    // (mesh radio self-RSSI, which is always null for the local node).
    _lastBleRssi = protocol.lastRssi;
    _lastSnr = protocol.lastSnr;
    final rssi = _lastBleRssi;
    final snr = _lastSnr?.toInt();

    final activeCount = _activeNodeCount(nodes);
    final totalCount = nodes.length;

    // Find nearest node with distance
    final nearestNode = _findNearestNode(nodes, myNodeNum);

    // Resolve the route's "destination" half per the user's setting.
    final destination = _resolveDestination(nodes, myNodeNum);

    // Seed signal history with the current sample so the lock-screen
    // aurora isn't empty until the rssi stream emits.
    _signalHistory.clear();
    if (rssi != null) _signalHistory.add(rssi);

    AppLogging.debug(
      '📱 Starting Live Activity: device=$deviceName, shortName=$shortName, '
      'battery=$batteryLevel%, rssi=$rssi, snr=$snr, '
      'nodes=$activeCount/$totalCount, dest=${_destinationMode.name}→${destination.label}',
    );

    final success = await _liveActivityService.startMeshActivity(
      deviceName: deviceName,
      shortName: shortName,
      nodeNum: myNodeNum ?? 0,
      batteryLevel: batteryLevel,
      signalStrength: rssi,
      snr: snr,
      nodesOnline: activeCount,
      totalNodes: totalCount,
      channelUtilization: myNode?.channelUtilization,
      airtime: myNode?.airUtilTx,
      sentPackets: myNode?.numPacketsTx ?? 0,
      receivedPackets: myNode?.numPacketsRx ?? 0,
      badPackets: myNode?.numPacketsRxBad ?? 0,
      uptimeSeconds: myNode?.uptimeSeconds,
      temperature: myNode?.temperature,
      humidity: myNode?.humidity,
      voltage: myNode?.voltage,
      nearestNodeDistance: nearestNode?.$2,
      nearestNodeName: nearestNode?.$1.shortName ?? nearestNode?.$1.longName,
      firmwareVersion: myNode?.firmwareVersion,
      hardwareModel: myNode?.hardwareModel,
      role: myNode?.role,
      latitude: myNode?.latitude,
      longitude: myNode?.longitude,
      destinationLabel: destination.label,
      destinationLongName: destination.longName,
      destinationLastHeardSec: destination.lastHeardSec,
      destinationNextEventSec: destination.nextEventSec,
      linkStatus: _linkStatusFromAge(destination.lastHeardSec),
      signalHistory: List<int>.unmodifiable(_signalHistory),
    );

    if (success) {
      state = true;

      // Start the coalesce timer that flushes accumulated stream changes
      // to the native Live Activity bridge every 2 seconds.
      _startCoalesceTimer();

      // Set up BLE RSSI listener — accumulates into the coalesce window
      // instead of crossing the native bridge on every poll event. Also
      // feeds the signal-history ring buffer that the lock-screen aurora
      // curve renders from.
      _rssiSubscription?.cancel();
      _rssiSubscription = protocol.rssiStream.listen((rssi) {
        if (!_liveActivityService.isActive) return;
        _lastBleRssi = rssi;
        _signalHistory.add(rssi);
        if (_signalHistory.length > _signalHistoryCap) {
          _signalHistory.removeRange(
            0,
            _signalHistory.length - _signalHistoryCap,
          );
        }
        _streamDirty = true;
      });

      // Set up SNR listener — accumulates into the coalesce window.
      _snrSubscription?.cancel();
      _snrSubscription = protocol.snrStream.listen((snr) {
        if (!_liveActivityService.isActive) return;
        _lastSnr = snr;
        _streamDirty = true;
      });

      // Set up telemetry listener for channel utilization — accumulates
      // into the coalesce window.
      _channelUtilSubscription?.cancel();
      _channelUtilSubscription = protocol.channelUtilStream.listen((
        channelUtil,
      ) {
        if (!_liveActivityService.isActive) return;
        _streamDirty = true;
      });
    }
  }

  /// Start the periodic coalesce timer. Every [_coalesceInterval] it checks
  /// the dirty flag and, if set, performs a single batched `updateActivity()`
  /// call with all current telemetry values. This replaces 3+ individual
  /// native bridge calls per stream event with at most 1 call per interval.
  void _startCoalesceTimer() {
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer.periodic(_coalesceInterval, (_) {
      if (!_streamDirty || !_liveActivityService.isActive) return;
      _streamDirty = false;
      _flushCoalescedUpdate();
    });
  }

  /// Flush all accumulated stream values to the Live Activity in a single
  /// native bridge call.
  void _flushCoalescedUpdate() {
    final currentNodes = ref.read(nodesProvider);
    final currentMyNodeNum = ref.read(myNodeNumProvider);
    final currentNode = currentMyNodeNum != null
        ? currentNodes[currentMyNodeNum]
        : null;

    final currentOnlineCount = _activeNodeCount(currentNodes);
    final currentNearestNode = _findNearestNode(currentNodes, currentMyNodeNum);
    final destination = _resolveDestination(currentNodes, currentMyNodeNum);

    _liveActivityService.updateActivity(
      batteryLevel: currentNode?.batteryLevel,
      signalStrength: _lastBleRssi,
      snr: _lastSnr?.toInt(),
      nodesOnline: currentOnlineCount,
      totalNodes: currentNodes.length,
      channelUtilization: currentNode?.channelUtilization,
      airtime: currentNode?.airUtilTx,
      sentPackets: currentNode?.numPacketsTx,
      receivedPackets: currentNode?.numPacketsRx,
      badPackets: currentNode?.numPacketsRxBad,
      uptimeSeconds: currentNode?.uptimeSeconds,
      temperature: currentNode?.temperature,
      humidity: currentNode?.humidity,
      voltage: currentNode?.voltage,
      nearestNodeDistance: currentNearestNode?.$2,
      nearestNodeName:
          currentNearestNode?.$1.shortName ?? currentNearestNode?.$1.longName,
      destinationLabel: destination.label,
      destinationLongName: destination.longName,
      destinationLastHeardSec: destination.lastHeardSec,
      destinationNextEventSec: destination.nextEventSec,
      linkStatus: _linkStatusFromAge(destination.lastHeardSec),
      signalHistory: List<int>.unmodifiable(_signalHistory),
    );
  }

  void _updateFromNodes(Map<int, MeshNode> nodes) {
    final myNodeNum = ref.read(myNodeNumProvider);
    if (myNodeNum == null) return;

    final myNode = nodes[myNodeNum];
    if (myNode == null) return;

    final onlineCount = _activeNodeCount(nodes);
    final totalCount = nodes.length;
    final nearestNode = _findNearestNode(nodes, myNodeNum);
    final destination = _resolveDestination(nodes, myNodeNum);

    AppLogging.debug(
      '📱 Live Activity update: nodes=$onlineCount/$totalCount, '
      'dest=${_destinationMode.name}→${destination.label}',
    );

    _liveActivityService.updateActivity(
      deviceName: myNode.longName,
      shortName: myNode.shortName,
      batteryLevel: myNode.batteryLevel,
      signalStrength: _lastBleRssi,
      snr: _lastSnr?.toInt(),
      nodesOnline: onlineCount,
      totalNodes: totalCount,
      channelUtilization: myNode.channelUtilization,
      airtime: myNode.airUtilTx,
      sentPackets: myNode.numPacketsTx,
      receivedPackets: myNode.numPacketsRx,
      badPackets: myNode.numPacketsRxBad,
      uptimeSeconds: myNode.uptimeSeconds,
      temperature: myNode.temperature,
      humidity: myNode.humidity,
      voltage: myNode.voltage,
      nearestNodeDistance: nearestNode?.$2,
      nearestNodeName: nearestNode?.$1.shortName ?? nearestNode?.$1.longName,
      destinationLabel: destination.label,
      destinationLongName: destination.longName,
      destinationLastHeardSec: destination.lastHeardSec,
      destinationNextEventSec: destination.nextEventSec,
      linkStatus: _linkStatusFromAge(destination.lastHeardSec),
      signalHistory: List<int>.unmodifiable(_signalHistory),
    );
  }

  int _activeNodeCount(Map<int, MeshNode> nodes) {
    final now = DateTime.now();
    return nodes.values
        .where((node) => PresenceCalculator.isOnline(node.lastHeard, now: now))
        .length;
  }

  /// Find the nearest node with a valid distance from my node
  (MeshNode, double)? _findNearestNode(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    if (myNodeNum == null) return null;

    MeshNode? nearestNode;
    double? nearestDistance;

    for (final node in nodes.values) {
      // Skip my own node
      if (node.nodeNum == myNodeNum) continue;

      // Skip nodes without distance
      final distance = node.distance;
      if (distance == null || distance <= 0) continue;

      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearestNode = node;
      }
    }

    if (nearestNode != null && nearestDistance != null) {
      return (nearestNode, nearestDistance);
    }
    return null;
  }

  /// Resolves the route's "destination" half per the user's chosen mode.
  /// Falls back to the mesh-wide view when peer-mode targets aren't
  /// available (no online peers, no active DM, etc.).
  _DestinationData _resolveDestination(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    switch (_destinationMode) {
      case LiveActivityDestination.bestPeer:
        final best = _findBestPeer(nodes, myNodeNum);
        if (best != null) return _peerToDestination(best);
        return _meshDestination(nodes, myNodeNum);
      case LiveActivityDestination.activePeer:
        final active = _findActiveDmPeer(nodes);
        if (active != null) return _peerToDestination(active);
        return _meshDestination(nodes, myNodeNum);
      case LiveActivityDestination.mesh:
        return _meshDestination(nodes, myNodeNum);
    }
  }

  /// Mesh-wide destination — uses "MESH" as the label and the most
  /// recent lastHeard timestamp from any non-self node as the freshness
  /// signal. Empty mesh → idle.
  _DestinationData _meshDestination(Map<int, MeshNode> nodes, int? myNodeNum) {
    DateTime? mostRecent;
    for (final node in nodes.values) {
      if (node.nodeNum == myNodeNum) continue;
      final heard = node.lastHeard;
      if (heard == null) continue;
      if (mostRecent == null || heard.isAfter(mostRecent)) {
        mostRecent = heard;
      }
    }
    final lastHeardSec = mostRecent == null
        ? -1
        : DateTime.now().difference(mostRecent).inSeconds;
    return _DestinationData(
      label: 'MESH',
      longName: 'Whole network',
      lastHeardSec: lastHeardSec,
      nextEventSec: 0,
    );
  }

  /// Strongest-signal online peer — by `MeshNode.rssi` (mesh-layer
  /// RSSI as observed by the local radio when the peer last spoke).
  /// `null` if no peer has a valid RSSI reading.
  MeshNode? _findBestPeer(Map<int, MeshNode> nodes, int? myNodeNum) {
    final now = DateTime.now();
    MeshNode? best;
    int? bestRssi;
    for (final node in nodes.values) {
      if (node.nodeNum == myNodeNum) continue;
      if (!PresenceCalculator.isOnline(node.lastHeard, now: now)) continue;
      final rssi = node.rssi;
      if (rssi == null || rssi >= 0) continue;
      if (bestRssi == null || rssi > bestRssi) {
        bestRssi = rssi;
        best = node;
      }
    }
    return best;
  }

  /// Most-recently-active DM peer — picks the SipDmSession with the
  /// freshest message (or createdAtMs if no messages yet) and looks up
  /// the matching MeshNode. `null` if no active sessions or the peer
  /// isn't in the node table.
  MeshNode? _findActiveDmPeer(Map<int, MeshNode> nodes) {
    final sessions = ref.read(sipActiveSessionsProvider);
    if (sessions.isEmpty) return null;

    SipDmSession? freshest;
    int freshestMs = 0;
    for (final session in sessions) {
      final lastMs = session.messages.isNotEmpty
          ? session.messages.last.timestampMs
          : session.createdAtMs;
      if (lastMs > freshestMs) {
        freshestMs = lastMs;
        freshest = session;
      }
    }
    if (freshest == null) return null;
    return nodes[freshest.peerNodeId];
  }

  /// Convert a peer MeshNode into the destination tuple. Last-heard
  /// is computed from `lastHeard` against now.
  _DestinationData _peerToDestination(MeshNode peer) {
    final lastHeardSec = peer.lastHeard == null
        ? -1
        : DateTime.now().difference(peer.lastHeard!).inSeconds;
    final shortName = peer.shortName ?? '';
    final longName = peer.longName ?? '';
    final label = shortName.isNotEmpty
        ? shortName.toUpperCase()
        : (longName.isNotEmpty ? longName : '????');
    return _DestinationData(
      label: label,
      longName: longName.isNotEmpty ? longName : label,
      lastHeardSec: lastHeardSec,
      nextEventSec: 0,
    );
  }

  /// Map last-heard age (in seconds) to a coarse link-status bucket
  /// that the lock-screen renders as a green/amber/red status pill.
  /// Negative ages mean "never heard" → idle.
  String _linkStatusFromAge(int lastHeardSec) {
    if (lastHeardSec < 0) return 'idle';
    if (lastHeardSec <= 30) return 'ok';
    if (lastHeardSec <= 120) return 'stale';
    if (lastHeardSec <= 600) return 'lost';
    return 'idle';
  }

  /// Ends the current Live Activity immediately.
  ///
  /// Called when the user disables the Live Activity toggle in settings.
  Future<void> endLiveActivity() => _endLiveActivity();

  Future<void> _endLiveActivity() async {
    _channelUtilSubscription?.cancel();
    _channelUtilSubscription = null;
    _rssiSubscription?.cancel();
    _rssiSubscription = null;
    _snrSubscription?.cancel();
    _snrSubscription = null;
    _nodeUpdateDebounce?.cancel();
    _nodeUpdateDebounce = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _streamDirty = false;
    _lastBleRssi = null;
    _lastSnr = null;
    _signalHistory.clear();
    await _liveActivityService.endActivity();
    state = false;
    AppLogging.debug('📱 Ended Live Activity - device disconnected');
  }
}

/// Resolved "destination" half of the Live Activity route row — what
/// the user picked in settings, materialized into displayable strings
/// + age fields the SwiftUI side can render directly.
class _DestinationData {
  const _DestinationData({
    required this.label,
    required this.longName,
    required this.lastHeardSec,
    required this.nextEventSec,
  });

  final String label;
  final String longName;

  /// Seconds since the destination was last heard. Negative → never heard.
  final int lastHeardSec;

  /// Seconds until the next expected event for this destination
  /// (e.g. beacon ETA). 0 when no schedule is known.
  final int nextEventSec;
}

final liveActivityManagerProvider =
    NotifierProvider<LiveActivityManagerNotifier, bool>(
      LiveActivityManagerNotifier.new,
    );

// Messages with persistence
class MessagesNotifier extends Notifier<List<Message>> {
  final Map<int, String> _packetToMessageId = {};

  /// When an outbound DM receives an implicit mesh ack (realAck=false) we
  /// intentionally keep its entry in [_packetToMessageId] so a later explicit
  /// recipient ack can upgrade `realAck` false → true.
  ///
  /// [_ackUpgradeWindow] is a *UX-bound truth window*, not a protocol-derived
  /// bound — the mesh protocol does not guarantee an explicit ack will arrive
  /// in any particular interval (long multi-hop paths, heavy duty-cycle
  /// restrictions in EU868/AU915, or sleeping/intermittent nodes can
  /// theoretically delay an explicit ack by several minutes). The window
  /// encodes how long the app still cares about upgrading certainty before
  /// the user has moved on. Late-arriving explicit acks after eviction land
  /// in the "untracked packet" log branch — safe; the message stays
  /// delivered with `realAck=false`.
  final Map<int, DateTime> _implicitAckedAt = {};
  static const Duration _ackUpgradeWindow = Duration(minutes: 5);
  final LinkedHashMap<String, DateTime> _recentMessageSignatures =
      LinkedHashMap();
  static const Duration _duplicateSignatureWindow = Duration(seconds: 5);

  /// Maximum timestamp drift allowed when matching message content across
  /// delivery paths (e.g. push notification vs device protocol stream).
  /// Push timestamps may be seconds-level while device timestamps are
  /// packet-level, so allow up to 60 seconds of drift.
  static const Duration _contentDedupeWindow = Duration(seconds: 60);
  MessageDatabase? _storage;
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<MessageDeliveryUpdate>? _deliverySubscription;

  // Reconciliation guard per-node for this app session
  final Set<int> _reconciledNodesThisSession = {};

  StreamSubscription<ContentRefreshEvent>? _pushSubscription;
  bool _storageLoaded = false;

  /// Completer for the initial storage load. Tests can await this to ensure
  /// _loadFromStorage() has finished before adding messages.
  final Completer<void> _storageLoadCompleter = Completer<void>();

  /// Track the protocol instance we are currently subscribed to so that
  /// [build] re-runs (triggered by [messageStorageProvider] resolution)
  /// do not cancel in-flight stream subscriptions unnecessarily.
  ///
  /// ## Invariant (CRITICAL — do not break)
  ///
  /// This field and all `StreamSubscription` fields (`_messageSubscription`,
  /// `_deliverySubscription`, `_pushSubscription`) MUST be set to `null` in
  /// [ref.onDispose]. The skip-guard in [_subscribeToStreams] checks
  /// `_messageSubscription != null` to decide whether to re-subscribe.
  /// A cancelled-but-non-null subscription fools the guard into thinking
  /// we are still listening, permanently killing incoming message
  /// processing on broadcast streams (which do not buffer).
  ///
  /// Bug history: commit `78b6a52b` (8 Apr 2026) added the skip-guard
  /// without nulling in dispose → all incoming messages silently dropped
  /// after the first `build()` re-run. Fixed in `7bc1dc8e` (9 Apr 2026).
  /// See `/memories/repo/messages-stream-subscription-bug.md`.
  ProtocolService? _subscribedProtocol;

  /// Await this in tests to ensure the initial storage load has completed.
  Future<void> get storageReady => _storageLoadCompleter.future;

  @override
  List<Message> build() {
    final storageAsync = ref.watch(messageStorageProvider);
    _storage = storageAsync.value;

    // If storage failed to initialize, log the error and ensure the
    // completer is unblocked so messages can still flow (in-memory only).
    if (storageAsync.hasError) {
      AppLogging.messages(
        '❌ messageStorageProvider failed: ${storageAsync.error}',
      );
      if (!_storageLoadCompleter.isCompleted) {
        _storageLoadCompleter.complete();
      }
    }

    // Use ref.listen for protocol changes instead of ref.watch.
    // ref.watch would cause build() to re-run on every reconnect,
    // resetting state to [] and wiping all in-memory messages.
    // ref.listen re-subscribes streams without touching message state.
    ref.listen(protocolServiceProvider, (previous, next) {
      AppLogging.messages(
        '📨 Protocol service changed — re-subscribing message streams',
      );
      _subscribeToStreams(next);
    });

    // Set up disposal for stream subscriptions.
    //
    // CRITICAL — MUST null every reference after cancelling.
    //
    // Riverpod calls ref.onDispose() between build() cycles (e.g. when
    // messageStorageProvider transitions AsyncLoading → AsyncData).  The
    // next build() calls _subscribeToStreams(), whose skip-guard checks
    // `_messageSubscription != null`.  If we cancel without nulling, the
    // guard sees a non-null *cancelled* subscription and skips, leaving
    // the broadcast stream listener permanently dead.  Broadcast streams
    // do NOT buffer — missed events are lost forever.
    //
    // This exact bug shipped in 78b6a52b (8 Apr 2026) and silently broke
    // ALL incoming message processing (no UI, no notifications, no DB
    // persistence) until fixed in 7bc1dc8e (9 Apr 2026).
    //
    // Rule: if you add a skip-guard that checks `!= null`, the matching
    // dispose/cancel MUST set the reference to null.  Always.
    ref.onDispose(() {
      AppLogging.messages('📨 ref.onDispose: cancelling stream subscriptions');
      _messageSubscription?.cancel();
      _messageSubscription = null;
      _deliverySubscription?.cancel();
      _deliverySubscription = null;
      _pushSubscription?.cancel();
      _pushSubscription = null;
      _subscribedProtocol = null;
    });

    // Subscribe to current protocol streams
    final protocol = ref.read(protocolServiceProvider);
    _subscribeToStreams(protocol);

    // Load persisted messages asynchronously.
    // Wrapped in error handler to ensure _storageLoadCompleter always
    // completes — an unhandled exception here would permanently block
    // every incoming message that awaits the completer.
    _loadFromStorage().catchError((Object e, StackTrace s) {
      AppLogging.messages('❌ _loadFromStorage failed: $e\n$s');
      if (!_storageLoadCompleter.isCompleted) {
        _storageLoadCompleter.complete();
      }
    });

    // Ensure the retry coordinator is running.  We use ref.read()
    // instead of ref.watch() to avoid a circular dependency:
    // messagesProvider → dmRetryCoordinatorProvider → messagesProvider.
    // The coordinator stays alive via ref.keepAlive() in its own provider.
    ref.read(dmRetryCoordinatorProvider);

    return [];
  }

  /// Load messages from persistent storage into state.
  /// Only runs once per provider lifetime; subsequent protocol changes
  /// do not reload (messages remain in memory).
  Future<void> _loadFromStorage() async {
    if (_storageLoaded) {
      if (!_storageLoadCompleter.isCompleted) {
        _storageLoadCompleter.complete();
      }
      return;
    }
    if (_storage == null) {
      AppLogging.messages(
        '📨 _loadFromStorage: storage is null — completer NOT completed '
        '(waiting for messageStorageProvider to resolve)',
      );
      // Do NOT complete the completer when storage is unavailable.
      // Stream listeners must wait until storage has actually loaded
      // to prevent a race where messages arrive via BLE, get added to
      // state, and are then overwritten by _loadFromStorage setting
      // state = savedMessages (which may not include the just-arrived
      // messages because the DB query started before the save).
      return;
    }

    // Demo mode: seed sample messages if enabled and storage is empty
    if (DemoConfig.isEnabled) {
      final existing = await _storage!.loadMessages();
      if (existing.isEmpty) {
        AppLogging.debug('${DemoConfig.modeLabel} Seeding demo messages');
        if (!ref.mounted) {
          if (!_storageLoadCompleter.isCompleted) {
            _storageLoadCompleter.complete();
          }
          return;
        }
        state = DemoData.sampleMessages;
        _storageLoaded = true;
        if (!_storageLoadCompleter.isCompleted) {
          _storageLoadCompleter.complete();
        }
        return;
      }
    }

    final savedMessages = await _storage!.loadMessages();
    if (!ref.mounted) {
      if (!_storageLoadCompleter.isCompleted) {
        _storageLoadCompleter.complete();
      }
      return;
    }
    _storageLoaded = true;

    if (savedMessages.isNotEmpty) {
      // Keep canonical tapbacks in SQLite as raw messages, but exclude them
      // from the visible message state. The timeline/domain layer groups
      // them back under their parent by replyId.
      final regularMessages = savedMessages.where((m) {
        if (m.isCanonicalTapback) return false;
        return true;
      }).toList();
      // Reset any messages stuck in the retrying state from a previous
      // session (the app was killed while a retry was in flight).
      // This is done here rather than in DmRetryCoordinator.start()
      // because at start time, messagesProvider may not have loaded yet.
      //
      // Pending outbound messages get the same treatment: the offline
      // queue that would have sent them is in-memory only, so after a
      // restart nothing will ever transmit them. Mark them failed so the
      // user sees the retry affordance instead of a bubble that looks
      // queued forever. Messages still held by the live queue (hot
      // restart, provider container reuse) are left alone.
      final liveQueueIds = ref
          .read(offlineQueueProvider)
          .queue
          .map((q) => q.id)
          .toSet();
      final orphanedPending = <Message>[];
      final resetMessages = regularMessages.map((m) {
        if (m.status == MessageStatus.retrying) {
          AppLogging.messages(
            'MessagesNotifier: reset stale retrying → unconfirmed: ${m.id}',
          );
          return m.copyWith(status: MessageStatus.unconfirmed);
        }
        if (m.status == MessageStatus.pending &&
            m.sent &&
            !m.received &&
            !liveQueueIds.contains(m.id)) {
          AppLogging.messages(
            'MessagesNotifier: orphaned pending → failed: ${m.id}',
          );
          final failed = m.copyWith(
            status: MessageStatus.failed,
            errorMessage: safeL10n().messagingUnsentAppRestart,
          );
          orphanedPending.add(failed);
          return failed;
        }
        return m;
      }).toList();
      state = resetMessages;
      // Persist the pending → failed conversion. Device reconcile and
      // background merges re-read storage rows; a state-only conversion
      // would be resurrected to pending by the stale row on reconnect.
      for (final failed in orphanedPending) {
        await _storage!.saveMessage(failed);
      }
      AppLogging.messages(
        'Loaded ${regularMessages.length} messages from storage '
        '(${savedMessages.length - regularMessages.length} tapbacks excluded)',
      );
      for (final msg in savedMessages) {
        _recordMessageSignature(msg);
      }
      // Debug: Log channel messages details
      for (final m in savedMessages.where((m) => m.isBroadcast)) {
        AppLogging.messages(
          '📨 Stored broadcast: from=${m.from}, to=${m.to.toRadixString(16)}, '
          'channel=${m.channel}, text="${m.text.substring(0, m.text.length.clamp(0, 20))}"',
        );
      }
    }

    if (!_storageLoadCompleter.isCompleted) {
      _storageLoadCompleter.complete();
    }
  }

  /// Subscribe to protocol message and delivery streams.
  ///
  /// Cancels any previous subscriptions before creating new ones so that
  /// protocol changes (reconnect) simply re-wire streams without resetting
  /// in-memory message state.
  ///
  /// ## Skip-guard contract
  ///
  /// The guard below skips re-subscription when the protocol instance has
  /// not changed AND the subscription reference is non-null (meaning it
  /// was not disposed).  This relies on [ref.onDispose] nulling
  /// `_messageSubscription` and `_subscribedProtocol` — see the dispose
  /// block in [build] and the doc comment on [_subscribedProtocol] for
  /// why this invariant matters.
  ///
  /// **If you modify the guard condition, verify that the dispose block
  /// still nulls every field the guard reads.**
  void _subscribeToStreams(ProtocolService protocol) {
    // Skip re-subscription if we are already listening to this exact
    // protocol instance.  This prevents build() re-runs (caused by
    // messageStorageProvider async resolution) from cancelling an
    // in-flight subscription that has messages queued while waiting
    // for _storageLoadCompleter.
    //
    // SAFETY: this guard works ONLY because ref.onDispose nulls
    // _messageSubscription.  A cancelled-but-non-null subscription
    // would fool this check and permanently kill message processing.
    if (identical(protocol, _subscribedProtocol) &&
        _messageSubscription != null) {
      AppLogging.messages(
        '📨 _subscribeToStreams: skipping — same protocol instance '
        '(hash=${protocol.hashCode}), subscription active',
      );
      return;
    }
    AppLogging.messages(
      '📨 _subscribeToStreams: subscribing to protocol hash=${protocol.hashCode}, '
      'previousHash=${_subscribedProtocol?.hashCode}, '
      'hadSubscription=${_messageSubscription != null}',
    );
    _subscribedProtocol = protocol;

    // Cancel previous subscriptions
    _messageSubscription?.cancel();
    _deliverySubscription?.cancel();
    _pushSubscription?.cancel();

    // Listen for new messages
    _messageSubscription = protocol.messageStream.listen((message) async {
      if (!ref.mounted) return;

      AppLogging.messages(
        '📨 Stream received message id=${message.id}, '
        'storageCompleterDone=${_storageLoadCompleter.isCompleted}',
      );

      // Wait for persisted messages to load before processing incoming
      // messages. Without this, early BLE packets could arrive while
      // state is still empty, bypassing dedup, and then duplicated once
      // storage loads and sets state = savedMessages.
      await _storageLoadCompleter.future;
      if (!ref.mounted) return;

      AppLogging.messages(
        '📨 New message: from=${message.from}, to=${message.to.toRadixString(16)}, '
        'channel=${message.channel}, isBroadcast=${message.isBroadcast}, sent=${message.sent}, id=${message.id}',
      );

      if (message.sent) {
        // Sent tapback reactions: route to tapback storage only, never
        // add them to the main message list (matches Meshtastic Android
        // which stores reactions in a separate table).
        // Sent tapback reactions: route to tapback storage only.
        final sentIsTapback = message.isCanonicalTapback;
        if (sentIsTapback) {
          AppLogging.messages(
            '🏷️ Sent tapback — persisting hidden reaction row only',
          );
          await _persistHiddenTapback(message);
          return;
        }

        final existingMessage = state.firstWhereOrNull((m) {
          if (m.id == message.id) return true;
          if (m.packetId != null &&
              message.packetId != null &&
              m.packetId == message.packetId) {
            return true;
          }
          return false;
        });
        if (existingMessage != null) {
          AppLogging.messages(
            '📨 Skipping duplicate sent message id=${message.id}',
          );
          return;
        }
        if (_isDuplicateMessage(message)) {
          AppLogging.messages(
            '📨 Deduped sent message by signature: id=${message.id}',
          );
          return;
        }
        _addMessageToState(message);

        if (message.packetId != null && message.id.isNotEmpty) {
          trackPacket(message.packetId!, message.id);
        }
        return;
      }

      if (_isDuplicateMessage(message)) {
        AppLogging.messages(
          '📨 Duplicate incoming message ignored: id=${message.id}',
        );
        return;
      }

      // Canonical tapbacks stay in SQLite but never become standalone chat
      // bubbles. Only trust explicit protobuf tapbacks: isEmoji + replyId.
      final isTapback = message.isCanonicalTapback;
      if (isTapback) {
        AppLogging.messages(
          '🏷️ Incoming tapback detected — persisting hidden reaction row '
          '(not adding to message state, isEmoji=${message.isEmoji}, '
          'replyId=${message.replyId})',
        );
        await _persistHiddenTapback(message);
        return;
      }

      _addMessageToState(message);
      AppLogging.messages(
        '📨 _addMessageToState DONE: id=${message.id}, '
        'channel=${message.channel}, isBroadcast=${message.isBroadcast}, '
        'stateSize=${state.length}',
      );
      _notifyNewMessage(message);
    });

    // Listen for message push events from PushNotificationService and persist them
    final push = ref.read(pushNotificationServiceProvider);
    _pushSubscription = push.onContentRefresh.listen((event) {
      if (!ref.mounted) return;
      final type = event.contentType;
      final payload = event.payload;
      if (payload == null) return;

      if (type == 'direct_message' || type == 'channel_message') {
        AppLogging.messages(
          '📨 Handling push message event: type=$type, keys=${payload.keys.toList()}',
        );
        final parsed = parsePushMessagePayload(payload);
        if (parsed == null) {
          AppLogging.messages('📨 Could not parse push payload into Message');
          return;
        }

        // Add to state using canonical addMessage (will dedupe by id)
        addMessage(parsed);
        AppLogging.messages(
          '📨 Push message persisted locally: id=${parsed.id}, from=${parsed.from}, to=${parsed.to}',
        );
      }
    });

    // Listen for delivery status updates
    _deliverySubscription = protocol.deliveryStream.listen((update) {
      if (!ref.mounted) return;
      _handleDeliveryUpdate(update);
    });
  }

  void _notifyNewMessage(Message message) {
    AppLogging.app('_notifyNewMessage called for message from ${message.from}');

    // Skip notifications for sent messages (including own tapbacks)
    if (message.sent) {
      AppLogging.app('Skipping notification for sent message');
      return;
    }

    if (message.isCanonicalTapback) {
      AppLogging.app('Skipping notification for canonical tapback');
      return;
    }

    // Check master notification toggle
    final settingsAsync = ref.read(settingsServiceProvider);
    final settings = settingsAsync.value;
    if (settings == null) {
      AppLogging.app('Settings not available, skipping notification');
      return;
    }
    if (!settings.notificationsEnabled) {
      AppLogging.app('Notifications disabled in settings');
      return;
    }

    // Suppress notification if the user has muted this channel. Read the
    // persisted mute set directly from settings.prefs (the same
    // SharedPreferences instance MutedChannelsNotifier writes to) rather than
    // mutedChannelsProvider, whose state is an empty set until its async
    // hydration finishes. During a reconnect message flood the provider can
    // still be empty, so reading it would let a muted channel notify.
    // Per-channel mute applies to broadcasts only; a DM is never silenced by a
    // channel mute even though it carries a channel index.
    final muteChannelIndex = muteIndexForMessage(
      isBroadcast: message.isBroadcast,
      channel: message.channel,
    );
    if (muteChannelIndex != null &&
        isChannelMutedInPrefs(settings.prefs, muteChannelIndex)) {
      AppLogging.app(
        'Channel $muteChannelIndex is muted, skipping notification',
      );
      return;
    }

    // Get sender name - prefer node lookup, fallback to message's cached sender info
    final nodes = ref.read(nodesProvider);
    final senderNode = nodes[message.from];
    final senderName = senderNode?.displayName ?? message.senderDisplayName;
    final senderShortName = senderNode?.shortName ?? message.senderShortName;
    AppLogging.app('Sender: $senderName');

    final notificationBody = message.text;

    // Check if it's a channel message (broadcast) or direct message.
    // Use isBroadcast — the `to` field — as the discriminator. The channel
    // index alone is not sufficient because both DMs and broadcasts on the
    // Primary Channel have channel == 0.
    final isChannelMessage = message.isBroadcast;
    AppLogging.debug(
      '🔔 Is channel message: $isChannelMessage (channel: ${message.channel})',
    );

    String? channelName;
    if (isChannelMessage) {
      // Check channel message setting
      if (!settings.channelMessageNotificationsEnabled) {
        AppLogging.app('Channel notifications disabled');
        return;
      }

      // Get channel name
      final channels = ref.read(channelsProvider);
      final channel = channels
          .where((c) => c.index == message.channel)
          .firstOrNull;
      channelName =
          channel?.name ??
          'Channel ${message.channel}'; // lint-allow: hardcoded-string

      AppLogging.debug(
        '🔔 Queueing channel notification: $senderName in $channelName',
      );
    } else {
      // Check direct message setting
      if (!settings.directMessageNotificationsEnabled) {
        AppLogging.app('DM notifications disabled');
        return;
      }

      AppLogging.app('Queueing DM notification from: $senderName');
    }

    // When the CarPlay communication banner is guaranteed to post, it is the
    // single user-facing banner, so suppress the standard notification here to
    // avoid a duplicate. This gate is false unless a native banner will
    // actually fire (see CarPlayFeatureFlags.suppressesStandardNotification):
    // enabling the writer alone must never silence message notifications.
    // Emoji-only and empty-text messages still take the standard path because
    // the CarPlay donation skips them, so they would otherwise get no
    // notification.
    final carPlayHandlesNotification =
        CarPlayFeatureFlags.fromEnv().suppressesStandardNotification &&
        !message.isEmoji &&
        message.text.trim().isNotEmpty;
    if (carPlayHandlesNotification) {
      AppLogging.app(
        'CarPlay communication enabled; standard notification suppressed '
        '(communication notification handles message ${message.id})',
      );
    } else {
      // Queue notification for batching (handles flood protection)
      ref
          .read(notificationBatchProvider.notifier)
          .queueMessage(
            PendingMessageNotification(
              senderName: senderName,
              senderShortName: senderShortName,
              message: notificationBody,
              fromNodeNum: message.from,
              replyPacketId: message.packetId,
              channelIndex: isChannelMessage ? (message.channel ?? 0) : null,
              channelName: channelName,
            ),
          );
    }

    // Canonical tapbacks are metadata, not standalone message events.
    if (message.isCanonicalTapback) return;

    // Trigger IFTTT webhook for message received
    _triggerIftttForMessage(message, senderName, isChannelMessage);

    // Trigger automation engine for message
    _triggerAutomationForMessage(message, senderName, isChannelMessage);
  }

  void _triggerAutomationForMessage(
    Message message,
    String senderName,
    bool isChannelMessage,
  ) {
    final engine = ref.read(automationEngineProvider);

    String? channelName;
    if (isChannelMessage) {
      final channels = ref.read(channelsProvider);
      final channel = channels
          .where((c) => c.index == message.channel)
          .firstOrNull;
      channelName =
          channel?.name ??
          'Channel ${message.channel}'; // lint-allow: hardcoded-string
    }

    final automationMessage = AutomationMessage(
      from: message.from,
      text: message.text,
      channel: message.channel,
      hopCount: message.hopCount,
    );

    engine.processMessage(
      automationMessage,
      senderName: senderName,
      channelName: channelName,
    );
    AppLogging.automations('Automation: Processed message from $senderName');
  }

  void _triggerIftttForMessage(
    Message message,
    String senderName,
    bool isChannelMessage,
  ) {
    final iftttService = ref.read(iftttServiceProvider);
    AppLogging.debug(
      'IFTTT: Checking message trigger - isActive=${iftttService.isActive}',
    );
    if (!iftttService.isActive) {
      AppLogging.ifttt(' Not active, skipping message trigger');
      return;
    }

    String? channelName;
    if (isChannelMessage) {
      final channels = ref.read(channelsProvider);
      final channel = channels
          .where((c) => c.index == message.channel)
          .firstOrNull;
      channelName =
          channel?.name ??
          'Channel ${message.channel}'; // lint-allow: hardcoded-string
    }

    iftttService.processMessage(
      from: message.from,
      text: message.text,
      senderName: senderName,
      channelName: channelName,
    );
  }

  void _handleDeliveryUpdate(MessageDeliveryUpdate update) {
    AppLogging.debug(
      '📨 Delivery update received: packetId=${update.packetId}, '
      'delivered=${update.delivered}, error=${update.error?.message}',
    );
    AppLogging.debug(
      '📨 Currently tracking packets: ${_packetToMessageId.keys.toList()}',
    );

    // Drop tracking entries that have lingered past the window in which an
    // explicit recipient ack can still usefully upgrade realAck. Runs
    // lazily on each delivery event — no timer, no extra subscriptions.
    _sweepExpiredImplicitAcks();

    final messageId = _packetToMessageId[update.packetId];
    if (messageId == null) {
      // Protocol-internal packets (position requests, admin ops) generate
      // routing reports but are not tracked in the chat delivery map.
      // Log at protocol level to avoid cluttering debug output.
      AppLogging.protocol(
        'Delivery update for untracked packet ${update.packetId}',
      );
      return;
    }

    final messageIndex = state.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) {
      AppLogging.debug(
        '📨 ❌ Delivery update for message not in state: $messageId',
      );
      return;
    }

    final message = state[messageIndex];

    // DM-only gate for realAck, mirroring meshtastic-ios (`toUser != nil`).
    // Broadcast/channel messages cannot carry a meaningful "recipient"
    // acknowledgement — any raw realAck signal on a broadcast is discarded
    // here as defence in depth, even though broadcast sends normally use
    // wantAck=false and therefore never enter _packetToMessageId.
    final rawRealAck = update.realAck && message.isDirect;

    // If message is already delivered, ignore subsequent updates (especially
    // failures — this handles the case where we get ACK followed by a
    // timeout/error packet). The one exception is a weak→strong ack upgrade:
    // an implicit mesh ack (realAck == false) can legitimately be superseded
    // by a later explicit recipient ack (realAck == true). Never downgrade.
    if (message.status == MessageStatus.delivered) {
      final canUpgrade =
          update.isSuccess && rawRealAck && message.realAck != true;
      if (!canUpgrade) {
        AppLogging.debug(
          '📨 ⏭️ Ignoring update for already-delivered message: $messageId',
        );
        return;
      }
      AppLogging.messages(
        '🛰️ Upgrading $messageId realAck ${message.realAck} → true '
        '(explicit recipient ack superseded earlier implicit ack)',
      );
    }

    // A broadcast cannot carry a routing failure addressed back to us — its
    // only meaningful signal is the implicit mesh ack (heard/repeated). Should
    // a stray routing error ever arrive for a tracked broadcast packet, leave
    // the message at "sent to radio" rather than flipping it to "failed".
    if (message.isBroadcast && !update.isSuccess) {
      AppLogging.debug(
        '📨 ⏭️ Ignoring non-success update for broadcast message: $messageId',
      );
      return;
    }

    Message updatedMessage;
    if (update.isSuccess) {
      // Confirmed — clear all retry state; the message is delivered.
      // realAck is forward-only: true wins over false/null; false does not
      // overwrite an earlier true. Broadcasts cannot gain realAck=true.
      final nextRealAck = !message.isDirect
          ? message.realAck
          : (message.realAck == true ? true : rawRealAck);
      AppLogging.messages(
        '🛰️ $messageId → delivered (realAck=$nextRealAck, '
        'direct=${message.isDirect}, packetId=${update.packetId})',
      );
      updatedMessage = message.copyWith(
        status: MessageStatus.delivered,
        autoRetryEnabled: false,
        retryCount: 0,
        acked: true,
        realAck: nextRealAck,
        clearLastAttemptAt: true,
      );
    } else {
      updatedMessage = message.copyWith(
        status: MessageStatus.failed,
        routingError: update.error,
        errorMessage: update.error?.message,
      );
    }

    state = [
      ...state.sublist(0, messageIndex),
      updatedMessage,
      ...state.sublist(messageIndex + 1),
    ];
    _storage?.saveMessage(updatedMessage);

    // Stop tracking after successful delivery so future error packets cannot
    // regress the state. For DMs acked only by a relay (implicit mesh ack),
    // stay tracked so a later explicit recipient ack can upgrade realAck
    // false → true, bounded by _implicitAckUpgradeWindow via the lazy sweep
    // above. The already-delivered guard still blocks failures either way.
    if (update.isSuccess && rawRealAck) {
      _packetToMessageId.remove(update.packetId);
      _implicitAckedAt.remove(update.packetId);
      AppLogging.debug('📨 ✅ Message delivered, stopped tracking: $messageId');
    } else if (update.isSuccess) {
      // Implicit ack (or a non-DM success) — record the timestamp so we can
      // evict the tracking entry if no explicit ack ever follows. Overwrites
      // any prior stamp so a duplicate implicit ack refreshes the window.
      _implicitAckedAt[update.packetId] = DateTime.now();
      AppLogging.debug(
        '📨 📶 Implicit mesh ack for $messageId — awaiting explicit recipient ack',
      );
    } else {
      AppLogging.debug(
        '📨 ❌ Message failed: $messageId - ${update.error?.message}',
      );
    }
  }

  void trackPacket(int packetId, String messageId) {
    _packetToMessageId[packetId] = messageId;
    // Fresh tracking — drop any stale implicit-ack timestamp carried over
    // from a reused packet id in the unlikely event of wraparound.
    _implicitAckedAt.remove(packetId);
    AppLogging.debug('📨 Tracking packet $packetId -> message $messageId');
    AppLogging.debug(
      '📨 Current tracked packets: ${_packetToMessageId.keys.toList()}',
    );
  }

  /// Evict tracking entries for packets that received an implicit mesh ack
  /// but never a follow-up explicit recipient ack. Called lazily from
  /// [_handleDeliveryUpdate] so we pay nothing outside the routing path.
  /// Visible for testing.
  void _sweepExpiredImplicitAcks({DateTime? now}) {
    if (_implicitAckedAt.isEmpty) return;
    final wallNow = now ?? DateTime.now();
    final cutoff = wallNow.subtract(_ackUpgradeWindow);
    final expired = <int>[];
    for (final entry in _implicitAckedAt.entries) {
      if (entry.value.isBefore(cutoff)) {
        expired.add(entry.key);
      }
    }
    if (expired.isEmpty) return;
    for (final pid in expired) {
      final stamp = _implicitAckedAt[pid];
      final age = stamp == null ? null : wallNow.difference(stamp);
      _packetToMessageId.remove(pid);
      _implicitAckedAt.remove(pid);
      AppLogging.messages(
        '🧹 ACK TRACK EXPIRE packetId=$pid age=${age?.inSeconds}s '
        '(window=${_ackUpgradeWindow.inMinutes}m)',
      );
    }
  }

  /// Test-only hook to force the sweep with a provided clock.
  @visibleForTesting
  void debugSweepExpiredImplicitAcks({required DateTime now}) =>
      _sweepExpiredImplicitAcks(now: now);

  /// Remove a packet from the delivery-tracking map.
  ///
  /// Called before a resend so that a late delivery failure for the
  /// *previous* packet ID cannot incorrectly overwrite the new in-flight
  /// state.
  void untrackPacket(int packetId) {
    _packetToMessageId.remove(packetId);
    _implicitAckedAt.remove(packetId);
    AppLogging.debug('📨 Untracked stale packet $packetId');
  }

  void addMessage(Message message) {
    if (_isDuplicateMessage(message)) {
      AppLogging.messages('📨 Duplicate message ignored: id=${message.id}');
      _mergeDuplicateRxMetadata(message);
      return;
    }

    if (message.isCanonicalTapback) {
      AppLogging.messages(
        '🏷️ addMessage: persisting canonical tapback id=${message.id}',
      );
      unawaited(_persistHiddenTapback(message));
      return;
    }

    String convKey;
    if (message.isBroadcast) {
      convKey = 'channel:${message.channel ?? 0}';
    } else {
      final other = message.from == ref.read(myNodeNumProvider)
          ? message.to
          : message.from;
      convKey = 'dm:$other';
    }

    AppLogging.messages(
      '📨 addMessage: id=${message.id}, from=${message.from}, to=${message.to}, channel=${message.channel}, convKey=$convKey',
    );

    _addMessageToState(message);
  }

  bool _isDuplicateMessage(Message message) {
    // Layer 1: Exact message ID match
    if (message.id.isNotEmpty && state.any((m) => m.id == message.id)) {
      AppLogging.messages('📨 Dedup Layer 1 (ID match): id=${message.id}');
      return true;
    }
    // Layer 2: Packet ID match
    if (message.packetId != null &&
        state.any((m) => m.packetId == message.packetId)) {
      AppLogging.messages(
        '📨 Dedup Layer 2 (packetId match): packetId=${message.packetId}',
      );
      return true;
    }
    // Layer 3: Recent signature (short sliding window for rapid-fire)
    final signature = _messageSignature(message);
    if (_recentMessageSignatures.containsKey(signature)) {
      AppLogging.messages(
        '📨 Dedup Layer 3 (signature match): from=${message.from}',
      );
      return true;
    }
    // Layer 4: Content-fingerprint match against full state.
    // Catches push-to-device replays where the push-delivered message has a
    // deterministic SHA1 id and the device-delivered copy has a random UUID,
    // so layers 1-3 miss it once the signature window expires.
    // Skip for user-sent messages — the user deliberately resending the same
    // text is intentional, not a duplicate. Skip canonical tapbacks too:
    // state only ever holds non-tapback rows, so a content match against it
    // can never be the same physical reaction — only a regular message that
    // happens to share the emoji text.
    if (!message.sent &&
        !message.isCanonicalTapback &&
        _isContentDuplicate(message)) {
      AppLogging.messages(
        '📨 Dedup Layer 4 (content match): from=${message.from}, '
        'channel=${message.channel}, text="${message.text.substring(0, message.text.length.clamp(0, 20))}"',
      );
      return true;
    }
    AppLogging.messages(
      '📨 Dedup passed all layers: id=${message.id}, '
      'packetId=${message.packetId}, stateSize=${state.length}',
    );
    return false;
  }

  /// Returns true if [message] has the same sender, text, and
  /// channel as an existing message in state whose timestamp is within
  /// [_contentDedupeWindow].
  ///
  /// For messages on non-null channels, the `to` field is NOT compared
  /// because push notifications may use the local node num as the
  /// recipient while the actual mesh packet uses the broadcast address
  /// (0xFFFFFFFF). For DMs (channel is null), the `to` comparison is
  /// applied to prevent false matches between different conversations.
  bool _isContentDuplicate(Message message) {
    for (final m in state) {
      if (m.from != message.from) continue;
      if (m.text != message.text) continue;
      // Normalize channels: treat null as -1 so that null != 0 (Primary
      // Channel) — they are semantically different (unknown vs index 0).
      final mCh = m.channel ?? -1;
      final msgCh = message.channel ?? -1;
      if (mCh != msgCh) continue;
      // For DM messages (channel is null / -1), also compare the recipient
      // to prevent DMs to different nodes from being falsely deduped.
      // For channel messages (channel >= 0), skip the `to` comparison —
      // push notifications may set `to` to the local node num while the
      // mesh packet uses 0xFFFFFFFF (broadcast).
      if (mCh < 0 && m.to != message.to) continue;
      final diff = m.timestamp.difference(message.timestamp).abs();
      if (diff <= _contentDedupeWindow) {
        return true;
      }
    }
    return false;
  }

  /// Merge receive-path metadata from a discarded duplicate into the
  /// already-stored copy of the same packet.
  ///
  /// Policy: the first locally observed delivery path wins. A stored
  /// message with a known transport (`viaMqtt` non-null) is never
  /// overwritten — a later MQTT copy of a packet first heard over RF (or
  /// vice versa) must not rewrite history. Only the unknown → known
  /// direction is filled in, which covers copies that arrived without
  /// radio metadata (push-delivered or legacy background rows) being
  /// upgraded by the real packet. The same fill-if-absent rule is applied
  /// to the other receive-path fields carried by the packet.
  ///
  /// Matching is restricted to packet identity (message id or packetId) —
  /// content-fingerprint duplicates are too fuzzy to attribute metadata to.
  void _mergeDuplicateRxMetadata(Message incoming) {
    if (incoming.viaMqtt == null &&
        incoming.hopCount == null &&
        incoming.rxSnr == null &&
        incoming.rxRssi == null &&
        incoming.relayNode == null) {
      return;
    }
    final existing = state.firstWhereOrNull(
      (m) =>
          (incoming.id.isNotEmpty && m.id == incoming.id) ||
          (incoming.packetId != null && m.packetId == incoming.packetId),
    );
    if (existing == null || !existing.received) return;

    final merged = existing.copyWith(
      viaMqtt: existing.viaMqtt ?? incoming.viaMqtt,
      hopCount: existing.hopCount ?? incoming.hopCount,
      rxSnr: existing.rxSnr ?? incoming.rxSnr,
      rxRssi: existing.rxRssi ?? incoming.rxRssi,
      relayNode: existing.relayNode ?? incoming.relayNode,
    );
    final changed =
        merged.viaMqtt != existing.viaMqtt ||
        merged.hopCount != existing.hopCount ||
        merged.rxSnr != existing.rxSnr ||
        merged.rxRssi != existing.rxRssi ||
        merged.relayNode != existing.relayNode;
    if (!changed) return;

    AppLogging.messages(
      '📨 Merged rx metadata from duplicate into ${existing.id}: '
      'viaMqtt=${merged.viaMqtt}, hopCount=${merged.hopCount}',
    );
    state = state.map((m) => m.id == existing.id ? merged : m).toList();
    _storage?.saveMessage(merged);
  }

  void _addMessageToState(Message message) {
    state = [...state, message];
    _lastInsertAt = DateTime.now();
    _storage?.saveMessage(message);
    _recordMessageSignature(message);
    _recordNodeDexActivity(message);
  }

  /// Timestamp of the last message added to the in-memory state. Used by
  /// the BLE receive-pipeline diagnostics to distinguish failure class C
  /// (DB insert / state add stopped) from earlier classes — if the
  /// protocol service's `lastTextMessageEmittedAt` is recent but
  /// `lastInsertAt` is stale, the stall is between the message stream
  /// emit and the state add.
  DateTime? _lastInsertAt;
  DateTime? get lastInsertAt => _lastInsertAt;

  /// Forward inbound traffic to NodeDex so the Discovery card's
  /// `Messages` count and `Last Seen` reflect chat activity, not just
  /// node-tick encounters. Outgoing messages (where `from == myNodeNum`)
  /// are skipped, as are messages with no resolved sender.
  ///
  /// Receiving a text message is direct proof that the sender was
  /// on-mesh at [Message.timestamp], independent of whether the
  /// [nodesProvider] tick path observed a fresh `node.lastHeard` value
  /// for that sender.
  ///
  /// Carries its own idempotency guard ([_nodeDexHookKey] +
  /// [_nodeDexHookDedupWindow]) keyed on packet identity rather than
  /// row identity. The foreground `_isDuplicateMessage` path catches
  /// most duplicates before they reach this hook, but
  /// [mergeBackgroundMessages] only checks id + 60s content dedup —
  /// missing the `packetId` axis on purpose, since push payloads can
  /// lack `packetId` and a `null == null` match would over-suppress
  /// distinct messages. So a foreground UUID copy and a later
  /// background-merged SHA1 copy of the same physical packet, separated
  /// by more than 60s of timestamp skew, can both reach this hook. The
  /// hook-local key uses `packetId` when present (with sender + recipient
  /// + channel context to avoid cross-conversation collisions when packet
  /// ids wrap or are reused) and falls back to a TTL-bounded sender +
  /// channel + text signature otherwise.
  static const Duration _nodeDexHookDedupWindow = Duration(minutes: 5);
  final Map<String, DateTime> _nodeDexHookKeys = {};
  int _nodeDexHookAcceptedCount = 0;

  String _nodeDexHookKey(Message message) {
    final to = message.to;
    final channel = message.channel ?? '';
    if (message.packetId != null) {
      return 'pid:${message.from}:$to:$channel:${message.packetId}';
    }
    return 'sig:${message.from}:$to:$channel:${message.text}';
  }

  void _recordNodeDexActivity(Message message) {
    final myNum = ref.read(myNodeNumProvider);
    if (myNum != null && message.from == myNum) return;
    if (message.from == 0) return;

    final key = _nodeDexHookKey(message);
    final now = DateTime.now();
    final priorAt = _nodeDexHookKeys[key];
    if (priorAt != null && now.difference(priorAt) <= _nodeDexHookDedupWindow) {
      AppLogging.nodeDex(
        'Skipping NodeDex hook (duplicate key=$key, '
        'prior at ${priorAt.toIso8601String()})',
      );
      return;
    }
    _nodeDexHookKeys[key] = now;
    _nodeDexHookKeys.removeWhere(
      (_, ts) => now.difference(ts) > _nodeDexHookDedupWindow,
    );
    _nodeDexHookAcceptedCount++;

    final notifier = ref.read(nodeDexProvider.notifier);
    notifier.recordMessage(message.from);
    final encounterRecorded = notifier.recordEncounter(
      message.from,
      timestamp: message.timestamp,
    );

    AppLogging.nodeDex(
      'Inbound ${message.isBroadcast ? "channel" : "DM"} message → '
      'NodeDex: from=${message.from}, '
      'ts=${message.timestamp.toIso8601String()}, key=$key, '
      'recordMessage=true, encounterRecorded=$encounterRecorded',
    );
  }

  @visibleForTesting
  void recordNodeDexActivityForTest(Message message) =>
      _recordNodeDexActivity(message);

  @visibleForTesting
  int get nodeDexHookAcceptedCountForTest => _nodeDexHookAcceptedCount;

  @visibleForTesting
  Map<String, DateTime> get nodeDexHookKeysForTest => _nodeDexHookKeys;

  @visibleForTesting
  void resetNodeDexHookForTest() {
    _nodeDexHookKeys.clear();
    _nodeDexHookAcceptedCount = 0;
  }

  Future<void> _persistHiddenTapback(Message message) async {
    await _storage?.saveMessage(message);
    _recordMessageSignature(message);
    ref.read(messageTimelineEpochProvider.notifier).bump();
  }

  // Signature for the short-window rapid-fire dedupe (Layer 3). It must
  // collapse cross-path copies of the same physical packet (which always
  // share sender, text, timestamp, and replyId) while never collapsing
  // distinct packets from different senders. Message timestamps derive
  // from rxTime, which has one-second resolution, and broker-fed rooms
  // deliver in bursts - so several members reacting with the same emoji
  // in the same second is normal traffic, not a duplicate. Sender and
  // replyId keep those apart.
  String _messageSignature(Message message) {
    final target = message.isBroadcast
        ? 'channel:${message.channel ?? 0}' // lint-allow: hardcoded-string
        : 'dm:${message.from == ref.read(myNodeNumProvider) ? message.to : message.from}';
    return '$target|${message.from}|${message.replyId ?? 0}|${message.text}|'
        '${message.timestamp.millisecondsSinceEpoch}';
  }

  void _recordMessageSignature(Message message) {
    final signature = _messageSignature(message);
    final now = DateTime.now();
    _recentMessageSignatures[signature] = now;
    final cutoff = now.subtract(_duplicateSignatureWindow);
    _recentMessageSignatures.removeWhere(
      (_, timestamp) => timestamp.isBefore(cutoff),
    );
  }

  void updateMessage(String messageId, Message updatedMessage) {
    // Guard: never regress from delivered — a late status update
    // (e.g. pending→sent arriving after ACK already set delivered)
    // must not overwrite the terminal delivered state.
    if (updatedMessage.status != MessageStatus.delivered) {
      final current = state.firstWhereOrNull((m) => m.id == messageId);
      if (current != null && current.status == MessageStatus.delivered) {
        AppLogging.debug(
          '📨 ⏭️ Skipping update that would downgrade delivered '
          'message: $messageId (attempted ${updatedMessage.status.name})',
        );
        return;
      }
    }
    state = state.map((m) => m.id == messageId ? updatedMessage : m).toList();
    _storage?.saveMessage(updatedMessage);
  }

  /// Mark all incoming messages from a specific node as read (for DM conversations).
  void markConversationAsRead(int nodeNum) {
    var changed = false;
    state = state.map((m) {
      if (m.received && m.from == nodeNum && !m.read) {
        changed = true;
        final updated = m.copyWith(read: true);
        _storage?.saveMessage(updated);
        return updated;
      }
      return m;
    }).toList();
    if (changed) {
      AppLogging.messages('📨 Marked conversation with node $nodeNum as read');
    }
  }

  /// Mark all incoming broadcast messages on a specific channel as read.
  void markChannelAsRead(int channelIndex) {
    var changed = false;
    state = state.map((m) {
      if (m.received && m.isBroadcast && m.channel == channelIndex && !m.read) {
        changed = true;
        final updated = m.copyWith(read: true);
        _storage?.saveMessage(updated);
        return updated;
      }
      return m;
    }).toList();
    if (changed) {
      AppLogging.messages('📨 Marked channel $channelIndex messages as read');
    }
  }

  void deleteMessage(String messageId) {
    state = state.where((m) => m.id != messageId).toList();
    _storage?.deleteMessage(messageId);
  }

  void clearMessages() {
    state = [];
    _storage?.clearMessages();
  }

  /// Delete every locally-stored message belonging to a specific
  /// channel index. Returns the number of in-memory rows filtered
  /// out. DMs (channel == null) are unaffected.
  Future<int> deleteChannelMessages(int channelIndex) async {
    final removed = state.where((m) => m.channel == channelIndex).length;
    state = state.where((m) => m.channel != channelIndex).toList();
    await _storage?.deleteMessagesForChannel(channelIndex);
    return removed;
  }

  List<Message> getMessagesForNode(int nodeNum) {
    return state.where((m) => m.from == nodeNum || m.to == nodeNum).toList();
  }

  /// Rehydrate UI state for a given node from local storage if needed.
  /// If there are persisted messages for that node in the past [windowDays]
  /// days but the in-memory state has zero, this will load and insert them.
  Future<void> reconcileFromStorageForNode(
    int nodeNum, {
    int windowDays = 7,
  }) async {
    if (_storage == null) return;
    if (_reconciledNodesThisSession.contains(nodeNum)) {
      AppLogging.messages(
        '📨 Reconciliation already performed for node $nodeNum this session',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final since = now - windowDays * 24 * 60 * 60 * 1000;

    final localCount = await _storage!.countMessagesForNode(
      nodeNum,
      sinceMillis: since,
    );
    final uiCount = state
        .where(
          (m) =>
              (m.from == nodeNum || m.to == nodeNum) &&
              m.timestamp.millisecondsSinceEpoch >= since,
        )
        .length;

    if (localCount > 0 && uiCount == 0) {
      AppLogging.messages(
        '⚠️ Reconnect canary: conversationKey=dm:$nodeNum or node-scoped, localCount=$localCount, uiCount=$uiCount, nodeIdentity=$nodeNum, since=$since, now=$now, source="reconnect_canary"',
      );

      final messages = await _storage!.loadMessagesForNode(
        nodeNum,
        sinceMillis: since,
      );
      var added = 0;
      for (final m in messages) {
        if (m.isCanonicalTapback) continue;
        if (!state.any((s) => s.id == m.id)) {
          state = [...state, m];
          added++;
        }
      }
      if (added > 0) {
        AppLogging.messages(
          '✅ Rehydrate: Added $added messages for node $nodeNum',
        );
      } else {
        AppLogging.messages(
          'ℹ️ Rehydrate: No messages added for node $nodeNum (deduped)',
        );
      }
    }

    _reconciledNodesThisSession.add(nodeNum);
  }

  /// Force rehydrate all messages from storage into memory (debug helper).
  /// Returns a map with counts: { 'total': X, 'inserted': Y }
  Future<Map<String, int>> forceRehydrateAllFromStorage() async {
    if (_storage == null) return {'total': 0, 'inserted': 0};
    final all = await _storage!.loadMessages();
    final total = all.length;
    var inserted = 0;
    for (final m in all) {
      if (m.isCanonicalTapback) continue;
      if (!state.any((s) => s.id == m.id)) {
        state = [...state, m];
        inserted++;
      }
    }
    AppLogging.messages('🔧 Force rehydrate: total=$total, inserted=$inserted');
    return {'total': total, 'inserted': inserted};
  }

  /// Merge messages persisted by the background processor into the in-memory
  /// state. Called on foreground resume so the UI picks up any messages that
  /// arrived while the app was backgrounded.
  ///
  /// Unlike [forceRehydrateAllFromStorage], this only inserts messages whose
  /// IDs are in [backgroundIds], keeping the merge targeted and fast.
  ///
  /// Uses both ID-based and content-based dedup to prevent a background-
  /// persisted message from duplicating a foreground-delivered copy that
  /// arrived under a different UUID (e.g. race between ProtocolService and
  /// BackgroundMessageProcessor on the same broadcast BLE stream).
  Future<int> mergeBackgroundMessages(Set<String> backgroundIds) async {
    if (_storage == null || backgroundIds.isEmpty) return 0;
    final all = await _storage!.loadMessages();
    var inserted = 0;
    for (final m in all) {
      if (!backgroundIds.contains(m.id)) continue;
      if (m.isCanonicalTapback) continue;
      // ID-based dedup
      if (state.any((s) => s.id == m.id)) continue;
      // Content-based dedup (same sender, text, channel within 60 s)
      if (_isContentDuplicate(m)) {
        AppLogging.messages(
          '📨 Skipped background merge (content duplicate): id=${m.id}, '
          'from=${m.from}, channel=${m.channel}',
        );
        continue;
      }
      state = [...state, m];
      _recordMessageSignature(m);
      _recordNodeDexActivity(m);
      inserted++;
    }
    if (inserted > 0) {
      AppLogging.messages(
        '📨 Merged $inserted background messages into UI state',
      );
    }
    return inserted;
  }
}

final messagesProvider = NotifierProvider<MessagesNotifier, List<Message>>(
  MessagesNotifier.new,
);

class MessageTimelineEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state++;
  }
}

final messageTimelineEpochProvider =
    NotifierProvider<MessageTimelineEpochNotifier, int>(
      MessageTimelineEpochNotifier.new,
    );

/// Bounded DM resend and auto-retry coordinator.
///
/// Kept alive by [MessagesNotifier] which watches this provider in its
/// [build] method, so the coordinator runs for the full lifetime of the
/// messages provider — even when no conversation screen is open.
///
/// The coordinator is foreground-only: the internal [Timer] only fires
/// while the app process is active.  On app restart the coordinator will
/// reset any messages stuck in [MessageStatus.retrying] back to
/// [MessageStatus.unconfirmed] so that auto-retry can resume from the
/// next tick if still within the expiry window and attempt limit.
final dmRetryCoordinatorProvider = Provider<DmRetryCoordinator>((ref) {
  ref.keepAlive();
  final coordinator = DmRetryCoordinator(ref);
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

// Nodes
class NodesNotifier extends Notifier<Map<int, MeshNode>> {
  NodeStorageService? _storage;
  DeviceFavoritesService? _deviceFavorites;
  StreamSubscription<MeshNode>? _nodeSubscription;
  final Set<int> _fallbackLoggedNodes = {};
  final Set<int> _bleStripLoggedNodes = {};
  bool _enforcingFavoriteIntents = false;

  /// Monotonic counter bumped by [clearNodes]. `_init`'s storage load is
  /// async; if a destructive clear fires while `await loadNodes()` is
  /// in flight, the in-memory `savedNodes` variable resolves with the
  /// pre-clear snapshot. Without this epoch check, the resumption
  /// would then `state = nodeMap(...)` and resurrect the very nodes we
  /// just cleared. On resume we compare the captured epoch against
  /// the live one and abandon the stale write.
  int _clearEpoch = 0;

  /// Haversine distance in meters between two lat/lon points.
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Compute distance from myNode to [node] and return the node with
  /// the distance field set. Returns [node] unchanged if either node
  /// lacks a valid position.
  MeshNode _withDistance(MeshNode node, MeshNode? myNode) {
    if (myNode == null || !myNode.hasPosition || !node.hasPosition) {
      return node;
    }
    if (node.nodeNum == myNode.nodeNum) return node;
    final d = _haversineMeters(
      myNode.latitude!,
      myNode.longitude!,
      node.latitude!,
      node.longitude!,
    );
    return node.copyWith(distance: d);
  }

  /// Recompute distance for every node relative to [myNode] and
  /// update state in a single pass. Only called when myNode's
  /// position changes.
  void _recomputeAllDistances(MeshNode myNode) {
    if (!myNode.hasPosition) return;
    // Reads every node from state: pending writes must land first.
    _flushPendingNodeWrites();
    final updated = <int, MeshNode>{};
    var changed = false;
    for (final entry in state.entries) {
      final node = entry.value;
      if (node.nodeNum == myNode.nodeNum || !node.hasPosition) {
        updated[entry.key] = node;
        continue;
      }
      final d = _haversineMeters(
        myNode.latitude!,
        myNode.longitude!,
        node.latitude!,
        node.longitude!,
      );
      if (node.distance != d) {
        updated[entry.key] = node.copyWith(distance: d);
        changed = true;
      } else {
        updated[entry.key] = node;
      }
    }
    if (changed) {
      state = updated;
    }
  }

  /// Debounced batch save: collect node updates and flush after a delay
  final Map<int, MeshNode> _pendingSaves = {};
  Timer? _saveTimer;
  static const _saveDebounceDuration = Duration(seconds: 2);

  /// Coalesced emission buffer (flag-gated via
  /// [AppFeatureFlags.isNodeEmissionCoalescingEnabled]). Non-structural
  /// per-packet updates pend here and commit in one state write per
  /// window; structural events (new node, own node, position change)
  /// flush synchronously so discovery and map latency are unchanged.
  /// Side effects (saves, counters, IFTTT, automations) stay per-event
  /// and never depend on the flush. Every other state writer in this
  /// class must flush pending writes first to preserve write ordering,
  /// and reads of "the freshest version of node X" must consult the
  /// pending buffer before committed state.
  final Map<int, MeshNode> _pendingNodeWrites = {};
  Timer? _coalesceTimer;
  static const _coalesceWindow = Duration(milliseconds: 250);

  void _flushPendingNodeWrites() {
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    if (_pendingNodeWrites.isEmpty) return;
    if (!ref.mounted) {
      _pendingNodeWrites.clear();
      return;
    }
    state = {...state, ..._pendingNodeWrites};
    _pendingNodeWrites.clear();
  }

  @visibleForTesting
  void flushPendingNodeWrites() => _flushPendingNodeWrites();

  @override
  Map<int, MeshNode> build() {
    final protocol = ref.watch(protocolServiceProvider);
    final storageAsync = ref.watch(nodeStorageProvider);
    final deviceFavoritesAsync = ref.watch(deviceFavoritesProvider);
    _storage = storageAsync.value;
    _deviceFavorites = deviceFavoritesAsync.value;

    // Listen for identity changes and apply to existing nodes
    ref.listen<Map<int, NodeIdentity>>(nodeIdentityProvider, (previous, next) {
      if (!ref.mounted) return;
      _applyIdentityUpdates(next);
    });

    // Once the device NodeDB replay completes, re-assert favourite intents
    // the device missed: the favourite admin messages are fire-and-forget,
    // so a dropped packet (or a NodeDB not persisted to flash before a
    // reboot) leaves the device out of sync with the user's last action.
    ref.listen<AsyncValue<OperationalReadiness>>(meshtasticReadinessProvider, (
      previous,
      next,
    ) {
      if (!ref.mounted) return;
      final becameReady =
          next.value == OperationalReadiness.ready &&
          previous?.value != OperationalReadiness.ready;
      if (becameReady) {
        unawaited(_enforceFavoriteIntents());
      }
    });

    // Set up disposal
    ref.onDispose(() {
      _nodeSubscription?.cancel();
      // Flush any pending saves before disposing
      _flushPendingSaves();
      _saveTimer?.cancel();
      _coalesceTimer?.cancel();
      _coalesceTimer = null;
      _pendingNodeWrites.clear();
    });

    // Initialize asynchronously
    _init(protocol);

    return {};
  }

  MeshNode _mergeIdentity(MeshNode node, NodeIdentity? identity) {
    if (identity == null) return node;

    final identityLong = identity.longName?.trim();
    final identityShort = identity.shortName?.trim();

    final newLongName = (identityLong != null && identityLong.isNotEmpty)
        ? identityLong
        : node.longName;
    final newShortName = (identityShort != null && identityShort.isNotEmpty)
        ? identityShort
        : node.shortName;

    if (newLongName == node.longName && newShortName == node.shortName) {
      return node;
    }

    return node.copyWith(longName: newLongName, shortName: newShortName);
  }

  MeshNode _stripBleNamesIfNeeded(MeshNode node) {
    final longIsBle = NodeDisplayNameResolver.isBleDefaultName(node.longName);
    final shortIsBle = NodeDisplayNameResolver.isBleDefaultName(node.shortName);
    if (!longIsBle && !shortIsBle) return node;

    final bleValue = longIsBle ? node.longName : node.shortName;
    if (_bleStripLoggedNodes.add(node.nodeNum)) {
      AppLogging.protocol(
        'NODE_NAME_STRIP_BLE node=!${node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')} '
        'old=$bleValue',
      );
    }

    return node.copyWith(clearLongName: longIsBle, clearShortName: shortIsBle);
  }

  void _applyIdentityUpdates(Map<int, NodeIdentity> identities) {
    // Reads every node from state: pending writes must land first.
    _flushPendingNodeWrites();
    if (state.isEmpty) return;
    var changed = false;
    final updated = <int, MeshNode>{};
    for (final entry in state.entries) {
      final node = entry.value;
      final merged = _mergeIdentity(node, identities[entry.key]);
      updated[entry.key] = merged;
      if (merged.longName != node.longName ||
          merged.shortName != node.shortName) {
        changed = true;
      }
    }
    if (changed) {
      state = updated;
    }
  }

  void _logFallbackIfNeeded(MeshNode node) {
    final hasName =
        (node.longName != null && node.longName!.trim().isNotEmpty) ||
        (node.shortName != null && node.shortName!.trim().isNotEmpty);
    if (!hasName && _fallbackLoggedNodes.add(node.nodeNum)) {
      AppLogging.protocol(
        'NODE_NAME_FALLBACK node=!${node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')} reason=no_identity',
      );
    }
  }

  /// Schedule a node to be saved. Debounces multiple saves into a single batch.
  void _scheduleSave(MeshNode node) {
    _pendingSaves[node.nodeNum] = node;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, _flushPendingSaves);
  }

  /// Flush all pending node saves to storage in a single batch operation.
  void _flushPendingSaves() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_pendingSaves.isEmpty || _storage == null) return;

    final nodesToSave = _pendingSaves.values.toList();
    _pendingSaves.clear();

    AppLogging.debug('Flushing ${nodesToSave.length} pending node saves');
    _storage!.saveNodes(nodesToSave);
  }

  Future<void> _init(ProtocolService protocol) async {
    // isIgnored is still managed by DeviceFavoritesService (protocol service
    // does not read it from NodeInfo yet). isFavorite follows the iOS pattern:
    // it lives directly on the persisted MeshNode record and is updated from
    // NodeInfo packets — no separate cache layer.
    final ignoredSet = _deviceFavorites?.ignored ?? <int>{};
    // Explicit user unfavorites the device has not confirmed yet. While a
    // node is tombstoned, neither a stored record nor a device-reported
    // favourite may resurrect isFavorite.
    final tombstones = _deviceFavorites?.unfavoriteTombstones ?? <int>{};
    final identities = ref.read(nodeIdentityProvider);

    // When _storage is null the entire method body runs synchronously
    // (no awaits) before build() returns, so `state` is not yet
    // initialised.  Track whether we hit an await so the protocol-merge
    // below can safely read `state` only when it is readable.
    var stateReadable = false;

    // Load persisted nodes (with their positions) first. Capture the
    // clear-epoch before the await so we can detect a destructive
    // clear that fired during the async gap.
    final initEpoch = _clearEpoch;
    if (_storage != null) {
      final savedNodes = await _storage!.loadNodes();
      if (!ref.mounted) return;
      if (_clearEpoch != initEpoch) {
        AppLogging.nodes(
          'NodesNotifier._init: abandoning stale load — destructive '
          'clearNodes() fired during storage await '
          '(epoch $initEpoch → $_clearEpoch); starting empty',
        );
        // Do not write `state = nodeMap(...)` — state was already set
        // to {} by clearNodes(). Proceed to the protocol-merge step
        // using the current (empty) state as the base.
        stateReadable = true;
      } else if (savedNodes.isNotEmpty) {
        AppLogging.nodes('Loaded ${savedNodes.length} nodes from storage');
        final nodeMap = <int, MeshNode>{};
        for (var node in savedNodes) {
          final sanitized = _stripBleNamesIfNeeded(node);
          if (sanitized.longName != node.longName ||
              sanitized.shortName != node.shortName) {
            node = sanitized;
            _scheduleSave(node);
          }
          // isFavorite: trust the value persisted on the MeshNode itself (iOS
          // CoreData pattern), except for tombstoned nodes: an explicit user
          // unfavorite overrides a stored record that a stale device flag may
          // have resurrected before the tombstone existed. isIgnored still
          // comes from DeviceFavoritesService because the protocol service
          // doesn't read it from NodeInfo yet.
          node = node.copyWith(
            isFavorite: node.isFavorite && !tombstones.contains(node.nodeNum),
            isIgnored: ignoredSet.contains(node.nodeNum),
          );
          node = _mergeIdentity(node, identities[node.nodeNum]);
          nodeMap[node.nodeNum] = node;
          if (node.hasPosition) {
            AppLogging.debug(
              '📍 Node ${node.nodeNum} has stored position: ${node.latitude}, ${node.longitude}',
            );
          }
          _logFallbackIfNeeded(node);
        }
        state = nodeMap;
      }
      // We hit at least one await (_storage!.loadNodes()), so build()
      // has returned and `state` is now safe to read.
      stateReadable = true;
    }

    // Then merge with existing nodes from protocol service
    // Protocol nodes take precedence but preserve stored positions if new nodes don't have them
    final protocolNodes = Map<int, MeshNode>.from(protocol.nodes);

    // NOTE: No replaceAllFavorites / favorites-cache sync here.
    // Following the iOS CoreData pattern, isFavorite lives directly on the
    // MeshNode record. The stored node already carries the correct value from
    // the previous session; incoming NodeInfo packets update it via the stream
    // listener below. There is no separate "favorites sidecar" to reconcile.

    // After a storage await, state may contain nodes added by
    // addOrUpdateNode() during the async gap — use it.  On the
    // synchronous path (_storage == null) state is uninitialised,
    // so start from an empty map.
    final baseNodes = stateReadable ? state : <int, MeshNode>{};
    final updatedState = Map<int, MeshNode>.from(baseNodes);
    for (final entry in protocolNodes.entries) {
      var node = entry.value;
      final existing = baseNodes[entry.key];
      if (existing != null) {
        // Preserve stored properties that don't come from protocol
        node = node.copyWith(
          // Preserve position if protocol node doesn't have one
          latitude: node.hasPosition ? node.latitude : existing.latitude,
          longitude: node.hasPosition ? node.longitude : existing.longitude,
          altitude: node.hasPosition ? node.altitude : existing.altitude,
          // isFavorite: OR the protocol value with the stored value.
          // Protocol preserves isFavorite via copyWith for non-NodeInfo packets
          // (position, telemetry), and sets it from nodeInfo.isFavorite for
          // NodeInfo packets. OR-ing ensures a stored favourite is not lost
          // when the protocol snapshot was built from a placeholder node
          // (hardcoded false) whose NodeInfo hasn't arrived yet. Tombstoned
          // nodes are the exception: the user explicitly unfavorited them, so
          // a stale device flag must not resurrect the favourite.
          isFavorite:
              (node.isFavorite || existing.isFavorite) &&
              !tombstones.contains(node.nodeNum),
          // isIgnored still comes from DeviceFavoritesService (protocol
          // service does not read isIgnored from NodeInfo yet).
          isIgnored: ignoredSet.contains(node.nodeNum),
          // Preserve stored telemetry that protocol nodes from the
          // initial NodeDB dump don't carry. These fields arrive via
          // later telemetry packets; without this the stored last-known
          // values are clobbered with null on every reconnect.
          batteryLevel: node.batteryLevel ?? existing.batteryLevel,
          temperature: node.temperature ?? existing.temperature,
          humidity: node.humidity ?? existing.humidity,
          voltage: node.voltage ?? existing.voltage,
          channelUtilization:
              node.channelUtilization ?? existing.channelUtilization,
          airUtilTx: node.airUtilTx ?? existing.airUtilTx,
          uptimeSeconds: node.uptimeSeconds ?? existing.uptimeSeconds,
          barometricPressure:
              node.barometricPressure ?? existing.barometricPressure,
          gasResistance: node.gasResistance ?? existing.gasResistance,
          iaq: node.iaq ?? existing.iaq,
          lux: node.lux ?? existing.lux,
          whiteLux: node.whiteLux ?? existing.whiteLux,
          irLux: node.irLux ?? existing.irLux,
          uvLux: node.uvLux ?? existing.uvLux,
          windDirection: node.windDirection ?? existing.windDirection,
          windSpeed: node.windSpeed ?? existing.windSpeed,
          windGust: node.windGust ?? existing.windGust,
          windLull: node.windLull ?? existing.windLull,
          weight: node.weight ?? existing.weight,
          radiation: node.radiation ?? existing.radiation,
          rainfall1h: node.rainfall1h ?? existing.rainfall1h,
          rainfall24h: node.rainfall24h ?? existing.rainfall24h,
          soilMoisture: node.soilMoisture ?? existing.soilMoisture,
          soilTemperature: node.soilTemperature ?? existing.soilTemperature,
          envDistance: node.envDistance ?? existing.envDistance,
          envCurrent: node.envCurrent ?? existing.envCurrent,
          envVoltage: node.envVoltage ?? existing.envVoltage,
          ch1Voltage: node.ch1Voltage ?? existing.ch1Voltage,
          ch1Current: node.ch1Current ?? existing.ch1Current,
          ch2Voltage: node.ch2Voltage ?? existing.ch2Voltage,
          ch2Current: node.ch2Current ?? existing.ch2Current,
          ch3Voltage: node.ch3Voltage ?? existing.ch3Voltage,
          ch3Current: node.ch3Current ?? existing.ch3Current,
          pm10Standard: node.pm10Standard ?? existing.pm10Standard,
          pm25Standard: node.pm25Standard ?? existing.pm25Standard,
          pm100Standard: node.pm100Standard ?? existing.pm100Standard,
          pm10Environmental:
              node.pm10Environmental ?? existing.pm10Environmental,
          pm25Environmental:
              node.pm25Environmental ?? existing.pm25Environmental,
          pm100Environmental:
              node.pm100Environmental ?? existing.pm100Environmental,
          particles03um: node.particles03um ?? existing.particles03um,
          particles05um: node.particles05um ?? existing.particles05um,
          particles10um: node.particles10um ?? existing.particles10um,
          particles25um: node.particles25um ?? existing.particles25um,
          particles50um: node.particles50um ?? existing.particles50um,
          particles100um: node.particles100um ?? existing.particles100um,
          co2: node.co2 ?? existing.co2,
          numPacketsTx: node.numPacketsTx ?? existing.numPacketsTx,
          numPacketsRx: node.numPacketsRx ?? existing.numPacketsRx,
          numPacketsRxBad: node.numPacketsRxBad ?? existing.numPacketsRxBad,
          numOnlineNodes: node.numOnlineNodes ?? existing.numOnlineNodes,
          numTotalNodes: node.numTotalNodes ?? existing.numTotalNodes,
          numTxDropped: node.numTxDropped ?? existing.numTxDropped,
          noiseFloor: node.noiseFloor ?? existing.noiseFloor,
          nodeStatus: node.nodeStatus ?? existing.nodeStatus,
          firmwareVersion: node.firmwareVersion ?? existing.firmwareVersion,
          hasWifi: node.hasWifi || existing.hasWifi,
          hasBluetooth: node.hasBluetooth || existing.hasBluetooth,
          positionTimestamp:
              node.positionTimestamp ?? existing.positionTimestamp,
          firstHeard: existing.firstHeard ?? node.firstHeard,
          distance: node.distance ?? existing.distance,
          satsInView: node.satsInView ?? existing.satsInView,
          gpsAccuracy: node.gpsAccuracy ?? existing.gpsAccuracy,
          groundSpeed: node.groundSpeed ?? existing.groundSpeed,
          groundTrack: node.groundTrack ?? existing.groundTrack,
          precisionBits: node.precisionBits ?? existing.precisionBits,
        );
      } else {
        // New node: isFavorite comes from the protocol node directly
        // (set by NodeInfo or hardcoded false for placeholders), unless the
        // user tombstoned it (e.g. the device replays a favourite for a node
        // no longer in local storage). isIgnored comes from
        // DeviceFavoritesService.
        node = node.copyWith(
          isFavorite: node.isFavorite && !tombstones.contains(node.nodeNum),
          isIgnored: ignoredSet.contains(node.nodeNum),
        );
      }
      node = _stripBleNamesIfNeeded(node);
      node = _mergeIdentity(node, identities[node.nodeNum]);
      updatedState[entry.key] = node;
      _logFallbackIfNeeded(node);
    }
    state = updatedState;

    // Compute distances now that all nodes (including myNode) are loaded.
    final myNodeNum = ref.read(myNodeNumProvider);
    if (myNodeNum != null) {
      final myNode = state[myNodeNum];
      if (myNode != null && myNode.hasPosition) {
        _recomputeAllDistances(myNode);
      }
    }

    // Listen for new nodes
    _nodeSubscription = protocol.nodeStream.listen((node) {
      if (!ref.mounted) return;
      final isNewNode =
          !state.containsKey(node.nodeNum) &&
          !_pendingNodeWrites.containsKey(node.nodeNum);
      // Consecutive packets for one node inside a coalesce window must
      // merge against the freshest pending value, not committed state.
      final existing = _pendingNodeWrites[node.nodeNum] ?? state[node.nodeNum];

      // isIgnored is still managed by DeviceFavoritesService (protocol
      // service does not read it from NodeInfo yet).
      final currentIgnored = _deviceFavorites?.ignored ?? <int>{};
      // Read fresh per event: tombstones change as the user toggles
      // favourites and as devices confirm unfavorites.
      final currentTombstones =
          _deviceFavorites?.unfavoriteTombstones ?? <int>{};

      if (existing != null) {
        // Preserve stored properties that don't come from protocol.
        // The protocol service emits MeshNode via copyWith, so fields
        // already on the node are preserved. But position and user
        // preferences need explicit merging.
        //
        // Telemetry fields (battery, voltage, etc.) are also preserved
        // from existing when the incoming node lacks them. While the
        // protocol's _nodes map usually carries these via copyWith,
        // timing windows during _init re-invocations or placeholder
        // emissions can produce nodes without telemetry. Without this
        // preservation, battery stats become stale and only recover
        // on reconnect (which re-populates _nodes from scratch).
        node = node.copyWith(
          // Preserve position if new node doesn't have one
          latitude: node.hasPosition ? node.latitude : existing.latitude,
          longitude: node.hasPosition ? node.longitude : existing.longitude,
          altitude: node.hasPosition ? node.altitude : existing.altitude,
          // iOS CoreData pattern: isFavorite lives on the node record.
          // Protocol preserves it via copyWith for non-NodeInfo packets
          // and sets it from nodeInfo.isFavorite for NodeInfo packets.
          // OR with existing prevents a placeholder node (hardcoded false)
          // from clobbering a stored favourite whose NodeInfo hasn't
          // arrived yet. Explicit user unfavourite goes through
          // setNodeFavorite, which tombstones the node; the tombstone
          // suppresses a stale device favourite here until the device
          // confirms the unfavorite.
          isFavorite:
              (node.isFavorite || existing.isFavorite) &&
              !currentTombstones.contains(node.nodeNum),
          isIgnored: currentIgnored.contains(node.nodeNum),
          // Preserve firstHeard — always keep the earliest value
          firstHeard: existing.firstHeard ?? node.firstHeard,
          // Preserve telemetry from existing state when incoming node
          // lacks it (e.g. placeholder emissions, _updateNodeLastHeard
          // before _handleTelemetry on the same packet, or _init race
          // conditions during provider stabilization).
          batteryLevel: node.batteryLevel ?? existing.batteryLevel,
          voltage: node.voltage ?? existing.voltage,
          channelUtilization:
              node.channelUtilization ?? existing.channelUtilization,
          airUtilTx: node.airUtilTx ?? existing.airUtilTx,
          uptimeSeconds: node.uptimeSeconds ?? existing.uptimeSeconds,
          temperature: node.temperature ?? existing.temperature,
          humidity: node.humidity ?? existing.humidity,
        );
      } else {
        // New node: isFavorite comes from protocol directly, unless the
        // user tombstoned it.
        node = node.copyWith(
          isFavorite:
              node.isFavorite && !currentTombstones.contains(node.nodeNum),
          isIgnored: currentIgnored.contains(node.nodeNum),
        );
      }

      node = _stripBleNamesIfNeeded(node);

      // Note: Identity store is updated via ProtocolService.onIdentityUpdate callback
      // which is set up in protocolServiceProvider. This avoids duplicate upserts.

      // Apply cached identity (if any) to ensure stable display names
      final identities = ref.read(nodeIdentityProvider);
      node = _mergeIdentity(node, identities[node.nodeNum]);

      // Compute distance from myNode for this node (or recompute all
      // when myNode's own position changes).
      final myNodeNum = ref.read(myNodeNumProvider);
      final isOwnNode = myNodeNum != null && node.nodeNum == myNodeNum;
      if (myNodeNum != null && !isOwnNode) {
        final myNode = _pendingNodeWrites[myNodeNum] ?? state[myNodeNum];
        node = _withDistance(node, myNode);
      }
      final positionChanged =
          existing == null ||
          existing.latitude != node.latitude ||
          existing.longitude != node.longitude;

      // Structural events commit synchronously so discovery overlays and
      // map markers keep today's latency; pure lastHeard/RSSI/telemetry
      // churn coalesces into one emission per window. With the flag off
      // every event commits synchronously, which is the pre-coalescing
      // behavior verbatim.
      final flushNow =
          !AppFeatureFlags.isNodeEmissionCoalescingEnabled ||
          isNewNode ||
          isOwnNode ||
          (node.hasPosition && positionChanged);
      _pendingNodeWrites[node.nodeNum] = node;
      if (flushNow) {
        _flushPendingNodeWrites();
      } else {
        _coalesceTimer ??= Timer(_coalesceWindow, _flushPendingNodeWrites);
      }
      if (isOwnNode && positionChanged && node.hasPosition) {
        _recomputeAllDistances(node);
      }

      _logFallbackIfNeeded(node);

      // Schedule debounced persist to storage (batches multiple updates)
      _scheduleSave(node);

      // Increment new nodes counter if this is a genuinely new node
      if (isNewNode) {
        ref.read(newNodesCountProvider.notifier).increment();
        // Trigger notification for new node discovery
        ref.read(nodeDiscoveryNotifierProvider.notifier).notifyNewNode(node);
      }

      // Trigger IFTTT webhook for node updates
      _triggerIftttForNode(node, existing);

      // Trigger automation engine for node updates
      _triggerAutomationForNode(node, existing);

      // Update cached metadata for linked nodes when identity changes
      onLinkedNodeUpdated(ref, node, existing);
    });
  }

  void _triggerIftttForNode(MeshNode node, MeshNode? previousNode) {
    final iftttService = ref.read(iftttServiceProvider);
    if (!iftttService.isActive) return;

    iftttService.processNodeUpdate(node, previousNode: previousNode);
  }

  void _triggerAutomationForNode(MeshNode node, MeshNode? previousNode) {
    final engine = ref.read(automationEngineProvider);
    engine.processNodeUpdate(node, previousNode: previousNode);
  }

  void addOrUpdateNode(MeshNode node) {
    // Explicit writes must not be reordered before earlier stream
    // updates still sitting in the coalesce buffer.
    _flushPendingNodeWrites();
    final identities = ref.read(nodeIdentityProvider);
    node = _stripBleNamesIfNeeded(node);
    final merged = _mergeIdentity(node, identities[node.nodeNum]);
    state = {...state, node.nodeNum: merged};
    _logFallbackIfNeeded(merged);
    _scheduleSave(merged);
  }

  /// Re-sends favourite admin messages the device missed.
  ///
  /// Runs on each transition into [OperationalReadiness.ready], when
  /// `protocol.nodes` reflects the device's replayed NodeDB. Tombstoned
  /// nodes the device still reports as favourite get remove_favorite_node
  /// re-sent; sidecar favourites the device lost get set_favorite_node
  /// re-sent. These are localAdmin packets addressed to the local node
  /// only (never mesh traffic), so airtime cost is negligible.
  Future<void> _enforceFavoriteIntents() async {
    if (_enforcingFavoriteIntents) return;
    final favService = _deviceFavorites;
    if (favService == null) return;
    final protocol = ref.read(protocolServiceProvider);
    if (!protocol.isOperational) return;
    _enforcingFavoriteIntents = true;
    try {
      // Snapshot targets before any await so no state reads happen
      // across async gaps.
      final deviceNodes = protocol.nodes;
      final pendingRemovals = favService.unfavoriteTombstones
          .where((n) => deviceNodes[n]?.isFavorite == true)
          .toList();
      final appNodes = state;
      final pendingAdds = favService.favorites
          .where(
            (n) =>
                deviceNodes[n] != null &&
                !deviceNodes[n]!.isFavorite &&
                appNodes[n]?.isFavorite == true,
          )
          .toList();
      for (final nodeNum in pendingRemovals) {
        try {
          await protocol.removeFavoriteNode(nodeNum);
          AppLogging.nodes(
            '[NodesNotifier] re-sent remove_favorite_node for tombstoned '
            'node $nodeNum',
          );
        } catch (e) {
          AppLogging.nodes(
            '[NodesNotifier] re-send remove_favorite_node failed '
            'node=$nodeNum error=$e',
          );
        }
      }
      for (final nodeNum in pendingAdds) {
        try {
          await protocol.setFavoriteNode(nodeNum);
          AppLogging.nodes(
            '[NodesNotifier] re-sent set_favorite_node for node $nodeNum',
          );
        } catch (e) {
          AppLogging.nodes(
            '[NodesNotifier] re-send set_favorite_node failed '
            'node=$nodeNum error=$e',
          );
        }
      }
    } finally {
      _enforcingFavoriteIntents = false;
    }
  }

  /// Records an explicit user favorite/unfavorite intent and updates state.
  ///
  /// Unfavorites are tombstoned so a stale device NodeDB flag cannot
  /// resurrect them on reconnect; the tombstone clears when a device
  /// confirms is_favorite=false (see onNodeDbFavoriteReported wiring) or
  /// when the user re-favorites. Callers still own the protocol admin
  /// send; this method owns the sidecar and provider state.
  Future<void> setNodeFavorite(int nodeNum, bool favorite) async {
    final favService = _deviceFavorites;
    if (favorite) {
      await favService?.addFavorite(nodeNum);
      await favService?.clearUnfavoriteTombstone(nodeNum);
    } else {
      await favService?.removeFavorite(nodeNum);
      await favService?.addUnfavoriteTombstone(nodeNum);
    }
    if (!ref.mounted) return;
    final node = _pendingNodeWrites[nodeNum] ?? state[nodeNum];
    if (node != null) {
      addOrUpdateNode(node.copyWith(isFavorite: favorite));
    }
  }

  void removeNode(int nodeNum) {
    // Drop any pending write for this node first: a later flush must
    // not resurrect a node the user just removed.
    _pendingNodeWrites.remove(nodeNum);
    _flushPendingNodeWrites();
    final newState = Map<int, MeshNode>.from(state);
    newState.remove(nodeNum);
    state = newState;
    // Also remove from persistent storage
    _storage?.deleteNode(nodeNum);
  }

  void clearNodes() => _clear(clearStorage: true);

  /// Drops the in-memory node map but leaves the persisted cache alone.
  ///
  /// Used when the connection moves to another radio: each radio's nodes
  /// live in its own storage scope, so the previous radio's cache must
  /// survive while the view resets for the new one.
  void clearNodesInMemory() => _clear(clearStorage: false);

  void _clear({required bool clearStorage}) {
    // Bump the epoch first so any `_init` currently awaiting
    // `loadNodes()` will detect the clear on resumption and abandon its
    // stale-state writeback. See `_clearEpoch` docs.
    _clearEpoch++;
    // Pending stream updates predate the clear and must die with it;
    // a later flush must not resurrect cleared nodes.
    _pendingNodeWrites.clear();
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    state = {};
    if (clearStorage) {
      _storage?.clearNodes();
    }
  }
}

final nodesProvider = NotifierProvider<NodesNotifier, Map<int, MeshNode>>(
  NodesNotifier.new,
);

/// Cross-feature selector for a single peer's last-heard timestamp.
///
/// Exists so features outside `lib/features/nodes/` (e.g. NodePet's
/// peer live-state derivation) can observe peer presence freshness
/// without importing another feature module — the module boundary
/// rule forbids `features/pet/` from importing `features/nodedex/`
/// or `features/nodes/`, and `lib/providers/` is the sanctioned
/// shared root.
///
/// Returns null when the node is not yet in the nodes map. Consumers
/// treat null as "never seen" — rendered as the [PeerPetLiveBand.unknown]
/// band downstream.
final peerLastSeenProvider = Provider.family<DateTime?, int>((ref, nodeNum) {
  return ref.watch(nodesProvider)[nodeNum]?.lastHeard;
});

// Channels
class ChannelsNotifier extends Notifier<List<ChannelConfig>> {
  StreamSubscription<ChannelConfig>? _channelSubscription;

  @override
  List<ChannelConfig> build() {
    final protocol = ref.watch(protocolServiceProvider);

    // Set up disposal
    ref.onDispose(() {
      _channelSubscription?.cancel();
    });

    AppLogging.debug(
      '🔵 ChannelsNotifier build - protocol has ${protocol.channels.length} channels',
    );
    for (var c in protocol.channels) {
      AppLogging.debug(
        '  Channel ${c.index}: name="${c.name}", psk.length=${c.psk.length}',
      );
    }

    // Initialize with existing channels (include Primary, exclude DISABLED)
    final initial = protocol.channels
        .where((c) => c.index == 0 || c.role != 'DISABLED')
        .toList();
    AppLogging.debug(
      '🔵 ChannelsNotifier initialized with ${initial.length} channels',
    );

    // Listen for future channel updates
    _channelSubscription = protocol.channelStream.listen((channel) {
      if (!ref.mounted) return;
      AppLogging.debug(
        '🔵 ChannelsNotifier received channel update: '
        'index=${channel.index}, name="${channel.name}", '
        'positionPrecision=${channel.positionPrecision}, positionEnabled=${channel.positionEnabled}',
      );
      final index = state.indexWhere((c) => c.index == channel.index);
      if (index >= 0) {
        AppLogging.debug('  Updating existing channel at position $index');
        state = [
          ...state.sublist(0, index),
          channel,
          ...state.sublist(index + 1),
        ];
      } else {
        AppLogging.debug('  Adding new channel');
        state = [...state, channel];
      }
      AppLogging.debug('  Total channels now: ${state.length}');
    });

    return initial;
  }

  void setChannel(ChannelConfig channel) {
    final index = state.indexWhere((c) => c.index == channel.index);
    if (index >= 0) {
      state = [
        ...state.sublist(0, index),
        channel,
        ...state.sublist(index + 1),
      ];
    } else {
      state = [...state, channel];
    }
  }

  void removeChannel(int channelIndex) {
    state = state.where((c) => c.index != channelIndex).toList();
  }

  void clearChannels() {
    state = [];
  }
}

final channelsProvider =
    NotifierProvider<ChannelsNotifier, List<ChannelConfig>>(
      ChannelsNotifier.new,
    );

/// Device-config backup service. Captures the current device's channels,
/// LoRa/device/module config, and owner into a [DeviceConfigBundle], and
/// applies one back to the device on restore. Backed by a thin gateway
/// over [ProtocolService] so unit tests can fake the wire layer.
final deviceConfigBackupServiceProvider = Provider<DeviceConfigBackupService>((
  ref,
) {
  final protocol = ref.watch(protocolServiceProvider);
  return DeviceConfigBackupService(
    gateway: ProtocolServiceBackupGateway(
      protocol,
      () => ref.read(channelsProvider),
    ),
  );
});

// My node number - updates when received from device
class MyNodeNumNotifier extends Notifier<int?> {
  StreamSubscription<int>? _myNodeNumSubscription;
  StreamSubscription<OperationalReadiness>? _readinessSubscription;

  @override
  int? build() {
    final protocol = ref.watch(protocolServiceProvider);

    // Set up disposal
    ref.onDispose(() {
      _myNodeNumSubscription?.cancel();
      _readinessSubscription?.cancel();
    });

    // The node number arrives before the radio's own NodeInfo, so the
    // first scope binding has no public key to hand. Re-bind once the
    // session is ready: by then the own node carries its key, which is
    // what lets the scope resolver recognise a radio that firmware 2.8
    // renumbered and fold its old history under the new number.
    _readinessSubscription = protocol.readinessStream.listen((readiness) {
      if (!ref.mounted) return;
      if (readiness != OperationalReadiness.ready) return;
      final nodeNum = protocol.myNodeNum;
      if (nodeNum == null) return;
      unawaited(_bindRadioScope(protocol, nodeNum));
    });

    // Initialize with existing myNodeNum from protocol service
    final initial = protocol.myNodeNum;

    // Listen for updates and persist the myNodeNum
    // Note: Data clearing now happens proactively in clearDeviceDataBeforeConnect()
    // before each connection, so this is mainly for persistence and edge cases
    _myNodeNumSubscription = protocol.myNodeNumStream.listen((
      newNodeNum,
    ) async {
      if (!ref.mounted) return;
      // Persist the current myNodeNum so we can track device identity
      await _saveMyNodeNum(newNodeNum);
      state = newNodeNum;
    });

    return initial;
  }

  /// Persist the current myNodeNum
  Future<void> _saveMyNodeNum(int nodeNum) async {
    final settingsAsync = ref.read(settingsServiceProvider);
    final settings = settingsAsync.value;
    if (settings != null) {
      await settings.setLastMyNodeNum(nodeNum);
    }
    // The radio has told us who it is. Bind storage to that identity: a
    // first-ever connect opened a provisional scope keyed by device id, and
    // this promotes it (and remembers the mapping, so the next connect to
    // the same device lands in the right scope before a single byte is
    // read).
    await _bindRadioScope(ref.read(protocolServiceProvider), nodeNum);
  }

  Future<void> _bindRadioScope(ProtocolService protocol, int nodeNum) async {
    final settings = ref.read(settingsServiceProvider).value;
    await RadioScope.instance.useNodeNum(
      nodeNum,
      deviceId: settings?.lastDeviceId,
      label: settings?.lastDeviceName,
      ownPublicKey: protocol.nodes[nodeNum]?.publicKey,
    );
  }
}

final myNodeNumProvider = NotifierProvider<MyNodeNumNotifier, int?>(
  MyNodeNumNotifier.new,
);

/// Effective device identity for message attribution. Falls back to the
/// persisted lastMyNodeNum while the protocol has not yet learned
/// myNodeNum this session (disconnected cold start), so outbound bubbles
/// composed or loaded before the config exchange still attribute to the
/// user instead of rendering as inbound.
final effectiveMyNodeNumProvider = Provider<int?>((ref) {
  final live = ref.watch(myNodeNumProvider);
  if (live != null) return live;
  return ref.watch(settingsServiceProvider).value?.lastMyNodeNum;
});

// ============================================================================
// REMOTE ADMINISTRATION
// ============================================================================

/// State for remote administration - tracks which node is being configured
class RemoteAdminState {
  final int? targetNodeNum;
  final String? targetNodeName;
  final bool isConfiguring;

  const RemoteAdminState({
    this.targetNodeNum,
    this.targetNodeName,
    this.isConfiguring = false,
  });

  /// Whether we're configuring a remote node (not our connected device)
  bool get isRemote => targetNodeNum != null;

  RemoteAdminState copyWith({
    int? targetNodeNum,
    String? targetNodeName,
    bool? isConfiguring,
    bool clearTarget = false,
  }) {
    return RemoteAdminState(
      targetNodeNum: clearTarget ? null : (targetNodeNum ?? this.targetNodeNum),
      targetNodeName: clearTarget
          ? null
          : (targetNodeName ?? this.targetNodeName),
      isConfiguring: isConfiguring ?? this.isConfiguring,
    );
  }

  @override
  String toString() =>
      'RemoteAdminState(target: ${targetNodeNum != null ? '0x${targetNodeNum!.toRadixString(16)} ($targetNodeName)' : 'local'}, isConfiguring: $isConfiguring)';
}

/// Notifier for managing remote administration target
class RemoteAdminNotifier extends Notifier<RemoteAdminState> {
  @override
  RemoteAdminState build() {
    // Auto-clear remote target when BLE connection drops. This prevents
    // stale remote targets from surviving across disconnect/reconnect
    // cycles, where the next reconnect would silently dispatch admin
    // writes to a stale remote and inject the wrong session passkey.
    ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
      previous,
      next,
    ) {
      final wasConnected =
          previous?.asData?.value == DeviceConnectionState.connected;
      final isDisconnected =
          next.asData?.value != DeviceConnectionState.connected;
      if (wasConnected && isDisconnected && state.isRemote) {
        AppLogging.protocol(
          'BLE disconnected — clearing remote admin target '
          '${state.targetNodeNum?.toRadixString(16)}',
        );
        state = const RemoteAdminState();
      }
    });
    return const RemoteAdminState();
  }

  /// Set the target node for remote configuration.
  ///
  /// Side effect: fire-and-forgets a `getDeviceMetadata` admin request to
  /// the new remote target so the response's `sessionPasskey` lands in
  /// `ProtocolService._adminSessions` before any user-initiated config
  /// screen issues its first admin packet.
  ///
  /// Without this pre-warm, the first remote admin packet (e.g. a
  /// `getConfig` from any config screen) is sent without a
  /// `sessionPasskey`, which firmware versions that require a passkey for
  /// non-bootstrap admin operations reject with `NO_CHANNEL` even when the
  /// remote already has the sender's public key in its `admin_key` list.
  ///
  /// Pre-warm failures are intentionally swallowed: the next user-initiated
  /// admin packet will simply send without a passkey (the existing
  /// `_applySessionPasskey` no-op fallback) — same behaviour as before this
  /// change, so a failed pre-warm never regresses callers.
  void setTarget(int nodeNum, String? nodeName) {
    state = RemoteAdminState(
      targetNodeNum: nodeNum,
      targetNodeName: nodeName,
      isConfiguring: false,
    );
    unawaited(_prewarmSessionPasskey(nodeNum));
  }

  Future<void> _prewarmSessionPasskey(int nodeNum) async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      if (!protocol.isConnected) {
        AppLogging.protocol(
          '🔑 Remote admin target set to ${nodeNum.toRadixString(16)} but '
          'transport not connected — sessionPasskey pre-warm skipped',
        );
        return;
      }
      AppLogging.protocol(
        '🔑 Pre-warming sessionPasskey for remote target '
        '${nodeNum.toRadixString(16)} via getDeviceMetadata',
      );
      await protocol.getDeviceMetadata(target: AdminTarget.remote(nodeNum));
    } catch (e) {
      AppLogging.protocol(
        '🔑 sessionPasskey pre-warm failed for ${nodeNum.toRadixString(16)}: '
        '$e (non-fatal; subsequent admin operations will retry without '
        'passkey)',
      );
    }
  }

  /// Clear the target (configure local device)
  void clearTarget() {
    state = const RemoteAdminState();
  }

  /// Set the configuring state
  void setConfiguring(bool isConfiguring) {
    state = state.copyWith(isConfiguring: isConfiguring);
  }

  /// Get the target node number (null = local device)
  int? get targetNodeNum => state.targetNodeNum;
}

final remoteAdminProvider =
    NotifierProvider<RemoteAdminNotifier, RemoteAdminState>(
      RemoteAdminNotifier.new,
    );

/// Provider that returns the target node number for admin operations
/// Returns null if configuring local device, or the remote node number otherwise
final remoteAdminTargetProvider = Provider<int?>((ref) {
  final remoteState = ref.watch(remoteAdminProvider);
  return remoteState.targetNodeNum;
});

/// Unread messages count provider
/// Returns the count of messages that were received from other nodes
/// and not yet read (messages where received=true and from != myNodeNum).
/// Includes both DM and channel/broadcast messages.
final unreadMessagesCountProvider = Provider<int>((ref) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  if (myNodeNum == null) return 0;

  return messages
      .where(
        (m) =>
            !m.isCanonicalTapback &&
            m.received &&
            m.from != myNodeNum &&
            !m.read,
      )
      .length;
});

/// Has unread messages provider - simple boolean check
final hasUnreadMessagesProvider = Provider<bool>((ref) {
  return ref.watch(unreadMessagesCountProvider) > 0;
});

/// Unread DM count — only direct messages, excludes broadcasts/channels.
/// Used by the Contacts tab badge so it only lights up for DM unreads.
final unreadDmCountProvider = Provider<int>((ref) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  if (myNodeNum == null) return 0;

  return messages
      .where(
        (m) =>
            !m.isCanonicalTapback &&
            m.received &&
            m.from != myNodeNum &&
            !m.read &&
            m.isDirect,
      )
      .length;
});

/// Whether there are unread DMs specifically.
final hasUnreadDmProvider = Provider<bool>((ref) {
  return ref.watch(unreadDmCountProvider) > 0;
});

/// Unread channel/broadcast message count — excludes DMs.
/// Used by the Channels tab badge.
final unreadChannelCountProvider = Provider<int>((ref) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  if (myNodeNum == null) return 0;

  return messages
      .where(
        (m) => m.received && m.from != myNodeNum && !m.read && m.isBroadcast,
      )
      .length;
});

/// Whether there are unread channel messages specifically.
final hasUnreadChannelProvider = Provider<bool>((ref) {
  return ref.watch(unreadChannelCountProvider) > 0;
});

/// Per-channel unread counts keyed by channel index.
/// Used by channel tiles to show individual unread badges.
final channelUnreadCountsProvider = Provider<Map<int, int>>((ref) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  if (myNodeNum == null) return {};

  final counts = <int, int>{};
  for (final m in messages) {
    // Skip tapback emoji reactions — they are metadata, not messages
    if (m.isCanonicalTapback) continue;
    if (m.received && m.from != myNodeNum && !m.read && m.isBroadcast) {
      final ch = m.channel ?? 0;
      counts[ch] = (counts[ch] ?? 0) + 1;
    }
  }
  return counts;
});

/// New nodes count - tracks number of newly discovered nodes since last check
/// Reset when user views the Nodes tab
class NewNodesCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
  void reset() => state = 0;
}

final newNodesCountProvider = NotifierProvider<NewNodesCountNotifier, int>(
  NewNodesCountNotifier.new,
);

/// Node discovery notifier - triggers notifications when new nodes are found
class NodeDiscoveryNotifier extends Notifier<MeshNode?> {
  @override
  MeshNode? build() => null;

  Future<void> notifyNewNode(MeshNode node) async {
    // Always update state to trigger UI animations (discovery cards)
    state = node;

    // Only show local notifications when app is fully ready (not during startup/connecting)
    final appState = ref.read(appInitProvider);
    if (appState != AppInitState.ready) return;

    // Suppress notifications during initial config sync after connect/reconnect
    // This prevents 50+ notifications when reconnecting to a device with known nodes
    final protocol = ref.read(protocolServiceProvider);
    if (!protocol.configurationComplete) return;

    // Check master notification toggle and new node setting
    final settingsAsync = ref.read(settingsServiceProvider);
    final settings = settingsAsync.value;
    if (settings == null) return;
    if (!settings.notificationsEnabled) return;
    if (!settings.newNodeNotificationsEnabled) return;

    // Check if we're in discovery cooldown period
    final cooldown = ref.read(nodeDiscoveryCooldownProvider.notifier);
    if (cooldown.isInCooldown) {
      // Track node during cooldown but don't notify yet
      cooldown.trackDiscoveredNode(node);
      return;
    }

    // Queue notification for batching (handles flood protection)
    ref
        .read(notificationBatchProvider.notifier)
        .queueNode(PendingNodeNotification(node: node));
  }
}

final nodeDiscoveryNotifierProvider =
    NotifierProvider<NodeDiscoveryNotifier, MeshNode?>(
      NodeDiscoveryNotifier.new,
    );

/// State for node discovery cooldown tracking
class NodeDiscoveryCooldownState {
  final DateTime? connectionTime;
  final List<MeshNode> discoveredDuringCooldown;
  final Duration cooldownDuration;

  const NodeDiscoveryCooldownState({
    this.connectionTime,
    this.discoveredDuringCooldown = const [],
    this.cooldownDuration = const Duration(minutes: 3),
  });

  bool get isInCooldown {
    if (connectionTime == null) return false;
    final elapsed = DateTime.now().difference(connectionTime!);
    return elapsed < cooldownDuration;
  }

  NodeDiscoveryCooldownState copyWith({
    DateTime? connectionTime,
    List<MeshNode>? discoveredDuringCooldown,
    Duration? cooldownDuration,
  }) {
    return NodeDiscoveryCooldownState(
      connectionTime: connectionTime ?? this.connectionTime,
      discoveredDuringCooldown:
          discoveredDuringCooldown ?? this.discoveredDuringCooldown,
      cooldownDuration: cooldownDuration ?? this.cooldownDuration,
    );
  }
}

/// Discovery cooldown - prevents notification floods when first connecting
/// to a device that's discovering many nodes. During cooldown (default 3 min),
/// individual node notifications are suppressed and a summary is shown afterward.
class NodeDiscoveryCooldownNotifier
    extends Notifier<NodeDiscoveryCooldownState> {
  Timer? _cooldownTimer;

  @override
  NodeDiscoveryCooldownState build() {
    // Start cooldown timer when connection is established
    ref.listen(connectionStateProvider, (previous, next) {
      if (next == AsyncData(DeviceConnectionState.connected)) {
        _startCooldown();
      } else if (next == AsyncData(DeviceConnectionState.disconnected)) {
        _resetCooldown();
      }
    });

    return const NodeDiscoveryCooldownState();
  }

  bool get isInCooldown => state.isInCooldown;

  /// Track a node discovered during cooldown period
  void trackDiscoveredNode(MeshNode node) {
    if (!state.isInCooldown) return;

    final updated = [...state.discoveredDuringCooldown, node];
    state = state.copyWith(discoveredDuringCooldown: updated);

    AppLogging.notifications(
      '🔔 Node discovered during cooldown: ${node.displayName} '
      '(${updated.length} total during cooldown)',
    );
  }

  /// Start the cooldown period
  void _startCooldown() {
    _cooldownTimer?.cancel();
    state = NodeDiscoveryCooldownState(
      connectionTime: DateTime.now(),
      discoveredDuringCooldown: [],
      cooldownDuration: state.cooldownDuration,
    );

    AppLogging.notifications(
      '🔔 Started node discovery cooldown for ${state.cooldownDuration.inMinutes} minutes',
    );

    // Schedule cooldown end
    _cooldownTimer = Timer(state.cooldownDuration, _onCooldownComplete);
  }

  /// Reset cooldown (e.g., on disconnect)
  void _resetCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    state = const NodeDiscoveryCooldownState();
    AppLogging.notifications('🔔 Reset node discovery cooldown');
  }

  /// Public seam: restart the cooldown window from "now".
  ///
  /// Used by the Device Management → Reset Node Database flow. After a
  /// node-db reset the radio rebuilds its NodeDB from neighbour
  /// broadcasts, which trickle in over the next few minutes. Restarting
  /// the cooldown gives the Nodes screen a bounded "Discovering"
  /// window — without this, the unbounded shimmer at
  /// `nodes_screen.dart` (the `nodesList.isEmpty + isConnected`
  /// branch) renders skeleton cards forever because the radio's TCP
  /// connection stays up across the reset and the cooldown never
  /// re-arms via the disconnect→connect listener.
  void restartCooldown() {
    AppLogging.notifications(
      '🔔 Restarting node discovery cooldown (e.g. after node-db reset)',
    );
    _startCooldown();
  }

  /// Called when cooldown period ends
  Future<void> _onCooldownComplete() async {
    final discoveredCount = state.discoveredDuringCooldown.length;

    AppLogging.notifications(
      '🔔 Node discovery cooldown complete - '
      '$discoveredCount nodes discovered',
    );

    // Show summary notification if nodes were discovered during cooldown
    if (discoveredCount > 0) {
      // Check settings one more time
      final settingsAsync = ref.read(settingsServiceProvider);
      final settings = settingsAsync.value;
      if (settings != null &&
          settings.notificationsEnabled &&
          settings.newNodeNotificationsEnabled) {
        // Show batched notification for all nodes discovered during cooldown
        final nodes = state.discoveredDuringCooldown
            .map((node) => PendingNodeNotification(node: node))
            .toList();

        final playSound = settings.notificationSoundEnabled;
        final vibrate = settings.notificationVibrationEnabled;

        try {
          await NotificationService().showBatchedNodesNotification(
            nodes: nodes,
            playSound: playSound,
            vibrate: vibrate,
          );
        } catch (e) {
          AppLogging.notifications(
            '🔔 Error showing batched node notification: $e',
          );
        }
      }
    }

    // Clear cooldown state (but keep connectionTime to prevent re-entry)
    state = state.copyWith(discoveredDuringCooldown: []);
  }
}

final nodeDiscoveryCooldownProvider =
    NotifierProvider<NodeDiscoveryCooldownNotifier, NodeDiscoveryCooldownState>(
      NodeDiscoveryCooldownNotifier.new,
    );

/// Current device region - stream that emits region updates
final deviceRegionProvider =
    StreamProvider<config_pbenum.Config_LoRaConfig_RegionCode>((ref) async* {
      final protocol = ref.watch(protocolServiceProvider);

      // Emit current region if available
      if (protocol.currentRegion != null) {
        yield protocol.currentRegion!;
      }

      // Emit future updates
      await for (final region in protocol.regionStream) {
        yield region;
      }
    });

enum RegionApplyStatus { idle, applying, applied, failed }

/// How long a completed region apply keeps suppressing the region picker
/// across reconnects of the same device. Long enough to cover the reboot
/// and reconnect cycle the apply triggers (including slow radios), short
/// enough that a later re-flash or factory reset, which brings the same
/// device back with region UNSET, is treated as the real setup need it is.
const Duration kRegionAppliedCarryOver = Duration(minutes: 3);

/// True when [state] records a region apply that completed recently enough
/// to still be part of its own reboot and reconnect cycle.
bool regionAppliedWithinCarryOver(
  RegionConfigState state, {
  DateTime Function() now = DateTime.now,
}) {
  if (state.applyStatus != RegionApplyStatus.applied) return false;
  final attemptedAt = state.lastAttemptAtMs;
  if (attemptedAt == null) return false;
  final age = now().millisecondsSinceEpoch - attemptedAt;
  return age >= 0 && age <= kRegionAppliedCarryOver.inMilliseconds;
}

class RegionConfigState {
  final config_pbenum.Config_LoRaConfig_RegionCode? regionChoice;
  final RegionApplyStatus applyStatus;
  final int? lastAttemptAtMs;
  final int connectionSessionId;

  /// The device ID we're applying region for. Used to preserve state across
  /// reconnects (device reboots after region change) but reset when switching devices.
  final String? targetDeviceId;

  const RegionConfigState({
    this.regionChoice,
    this.applyStatus = RegionApplyStatus.idle,
    this.lastAttemptAtMs,
    this.connectionSessionId = 0,
    this.targetDeviceId,
  });

  RegionConfigState copyWith({
    config_pbenum.Config_LoRaConfig_RegionCode? regionChoice,
    RegionApplyStatus? applyStatus,
    int? lastAttemptAtMs,
    int? connectionSessionId,
    String? targetDeviceId,
    bool clearRegionChoice = false,
    bool clearLastAttemptAt = false,
    bool clearTargetDeviceId = false,
  }) {
    return RegionConfigState(
      regionChoice: clearRegionChoice
          ? null
          : regionChoice ?? this.regionChoice,
      applyStatus: applyStatus ?? this.applyStatus,
      lastAttemptAtMs: clearLastAttemptAt
          ? null
          : lastAttemptAtMs ?? this.lastAttemptAtMs,
      connectionSessionId: connectionSessionId ?? this.connectionSessionId,
      targetDeviceId: clearTargetDeviceId
          ? null
          : targetDeviceId ?? this.targetDeviceId,
    );
  }
}

class RegionConfigNotifier extends Notifier<RegionConfigState> {
  @override
  RegionConfigState build() {
    final connectionState = ref.read(deviceConnectionProvider);

    ref.listen<DeviceConnectionState2>(deviceConnectionProvider, (
      previous,
      next,
    ) {
      // Check if session ID changed
      if (previous?.connectionSessionId != next.connectionSessionId) {
        final currentDeviceId = next.device?.id;
        final isSameDevice =
            state.targetDeviceId != null &&
            currentDeviceId != null &&
            state.targetDeviceId == currentDeviceId;

        // IMPORTANT: During region apply, the device reboots and reconnects with a NEW session.
        // If we're currently applying OR just applied a region to the SAME device,
        // don't reset state - preserve across the expected reboot/reconnect cycle.
        //
        // "Just applied" is bounded in time. An apply that finished long ago
        // must not keep suppressing the region picker: a radio that is later
        // re-flashed or factory reset comes back on the same device id with
        // region UNSET, and a stale "applied" here hid the picker for it.
        if (isSameDevice &&
            (state.applyStatus == RegionApplyStatus.applying ||
                regionAppliedWithinCarryOver(state))) {
          AppLogging.connection(
            '🌍 REGION_FLOW choose=${state.regionChoice?.name ?? "null"} session=${state.connectionSessionId} '
            'new_session=${next.connectionSessionId} status=${state.applyStatus.name} reason=session_change_same_device',
          );
          // Update the session ID but keep the apply status
          state = state.copyWith(connectionSessionId: next.connectionSessionId);
          return;
        }

        // Different device or idle state - reset for new session
        state = RegionConfigState(
          connectionSessionId: next.connectionSessionId,
          targetDeviceId: currentDeviceId,
        );
        AppLogging.connection(
          '🌍 REGION_FLOW choose=null session=${next.connectionSessionId} status=idle reason=new_session device=$currentDeviceId',
        );
        return;
      }

      if (state.applyStatus == RegionApplyStatus.applying) {
        if (next.isTerminalInvalidated) {
          state = state.copyWith(applyStatus: RegionApplyStatus.failed);
          AppLogging.connection(
            '🌍 REGION_FLOW choose=${state.regionChoice?.name ?? "null"} session=${state.connectionSessionId} status=failed reason=pairing_invalidated',
          );
          return;
        }

        // NOTE: We intentionally DO NOT mark as failed on disconnect during apply.
        // Setting region causes device reboot, which triggers a temporary disconnect.
        // The _awaitRegionConfirmation method handles this expected disconnect/reconnect cycle.
        // Marking as failed here would abort the operation before reconnection can complete.
        if (previous?.isConnected == true && !next.isConnected) {
          AppLogging.connection(
            '🌍 REGION_FLOW choose=${state.regionChoice?.name ?? "null"} session=${state.connectionSessionId} status=applying disconnect_expected=true reason=device_reboot',
          );
          // DO NOT set applyStatus to failed - let _awaitRegionConfirmation handle it
          return;
        }
      }
    });

    ref.listen<
      AsyncValue<config_pbenum.Config_LoRaConfig_RegionCode>
    >(deviceRegionProvider, (previous, next) {
      next.whenData((region) {
        if (state.applyStatus == RegionApplyStatus.applying &&
            state.regionChoice != null &&
            region == state.regionChoice) {
          state = state.copyWith(applyStatus: RegionApplyStatus.applied);
          AppLogging.connection(
            '🌍 REGION_FLOW choose=${region.name} session=${state.connectionSessionId} status=applied reason=region_stream',
          );
        }
      });
    });

    return RegionConfigState(
      connectionSessionId: connectionState.connectionSessionId,
    );
  }

  // Wipes in-memory region-flow state back to its initial shape so a
  // subsequent reconnect to the SAME hardware doesn't carry the
  // pre-wipe `regionChoice` + `applyStatus=applied` forward. Used by
  // the factory-reset paths after the device's actual region has been
  // wiped to UNSET. Safe to call after the calling widget unmounts -
  // notifiers outlive the State that captures them.
  void reset() {
    final sessionId = ref.read(deviceConnectionProvider).connectionSessionId;
    state = RegionConfigState(connectionSessionId: sessionId);
    AppLogging.connection(
      '🌍 REGION_FLOW reset session=$sessionId reason=factory_reset',
    );
  }

  Future<void> applyRegion(
    config_pbenum.Config_LoRaConfig_RegionCode region, {
    String reason = 'user_action',
  }) async {
    final connectionState = ref.read(deviceConnectionProvider);
    final sessionId = connectionState.connectionSessionId;
    final deviceId = connectionState.device?.id;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (!connectionState.isConnected) {
      state = state.copyWith(
        regionChoice: region,
        applyStatus: RegionApplyStatus.failed,
        lastAttemptAtMs: nowMs,
        connectionSessionId: sessionId,
        targetDeviceId: deviceId,
      );
      AppLogging.connection(
        '🌍 REGION_FLOW choose=${region.name} session=$sessionId status=failed reason=not_connected',
      );
      throw StateError('Cannot set region while disconnected');
    }

    // If already applied for this region, skip
    if (state.applyStatus == RegionApplyStatus.applied &&
        state.regionChoice == region) {
      AppLogging.connection(
        '🌍 REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=already_applied',
      );
      return;
    }

    if (state.applyStatus == RegionApplyStatus.applying &&
        state.regionChoice == region &&
        state.connectionSessionId == sessionId) {
      AppLogging.connection(
        '🌍 REGION_FLOW choose=${region.name} session=$sessionId status=applying reason=already_applying',
      );
      return;
    }

    state = state.copyWith(
      regionChoice: region,
      applyStatus: RegionApplyStatus.applying,
      lastAttemptAtMs: nowMs,
      connectionSessionId: sessionId,
      targetDeviceId: deviceId,
    );
    // Toggle the leaf in-flight provider that `_handleDisconnect`
    // reads (avoids the regionConfigProvider circular dependency).
    ref.read(regionApplyInFlightProvider.notifier).setActive(true);
    AppLogging.connection(
      '🌍 REGION_FLOW choose=${region.name} session=$sessionId device=$deviceId status=applying reason=$reason',
    );

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setRegion(region);
      await _awaitRegionConfirmation(region, sessionId);

      // If we get here, _awaitRegionConfirmation completed successfully:
      // either the device rebooted and came back ready with the region,
      // or (firmware 2.8+) it applied the region live and the read-back
      // confirmed it. In the reboot case the session ID will have
      // changed - that is expected, not an error.

      if (!ref.mounted) return;

      // The region stream listener might have already set status to applied
      if (state.applyStatus == RegionApplyStatus.applied) {
        return;
      }

      // Mark as applied - the reconnection confirms success
      state = state.copyWith(applyStatus: RegionApplyStatus.applied);
      AppLogging.connection(
        '🌍 REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=reconnect_confirmed',
      );
    } catch (e) {
      if (!ref.mounted) rethrow;

      // Check if the region was actually applied despite the error (e.g., timeout during reconnect
      // but region stream already confirmed the change)
      final protocol = ref.read(protocolServiceProvider);
      if (state.applyStatus == RegionApplyStatus.applied &&
          state.regionChoice == region) {
        AppLogging.connection(
          '🌍 REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=confirmed_despite_error',
        );
        // Region was confirmed by stream - don't treat as failure
        return;
      }
      if (protocol.currentRegion == region) {
        // Device has the correct region - mark as applied
        state = state.copyWith(applyStatus: RegionApplyStatus.applied);
        AppLogging.connection(
          '🌍 REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=device_has_region',
        );
        return;
      }

      // Only set failed if we're still in applying state
      if (state.applyStatus == RegionApplyStatus.applying) {
        state = state.copyWith(applyStatus: RegionApplyStatus.failed);
        AppLogging.connection(
          '🌍 REGION_FLOW choose=${region.name} session=$sessionId status=failed reason=${e.runtimeType}',
        );
      }
      rethrow;
    } finally {
      // Always clear the in-flight flag at the end of an apply
      // attempt — regardless of success / failure / early return —
      // so `_handleDisconnect` can resume normal scanner-routing
      // behaviour as soon as the apply has settled.
      if (ref.mounted) {
        ref.read(regionApplyInFlightProvider.notifier).setActive(false);
      }
    }
  }

  /// Delay before the first LoRa config read-back after a region write.
  /// Long enough for firmware that reboots on LoRa changes to have
  /// dropped the link, so a probe never completes the wait on a device
  /// that is about to go down.
  static const _regionLiveProbeInitialDelay = Duration(seconds: 12);

  /// Interval between LoRa config read-backs while the link stays up.
  static const _regionLiveProbeInterval = Duration(seconds: 5);

  Future<void> _awaitRegionConfirmation(
    config_pbenum.Config_LoRaConfig_RegionCode region,
    int sessionId,
  ) async {
    // Capture the device ID so we can verify reconnect is to the same device
    final targetDeviceId = ref.read(deviceConnectionProvider).device?.id;
    final protocol = ref.read(protocolServiceProvider);

    final completer = Completer<void>();
    ProviderSubscription<DeviceConnectionState2>? connectionSub;
    ProviderSubscription<AsyncValue<OperationalReadiness>>? readinessSub;
    StreamSubscription<config_pbenum.Config_LoRaConfig_RegionCode>? regionSub;
    Timer? liveProbeTimer;
    bool sawDisconnect = false;
    bool sawReconnect = false;
    bool readinessReady = false;
    bool deviceMatches = true;

    void completeSuccess(String reason) {
      if (!completer.isCompleted) {
        AppLogging.connection(
          'REGION_CONFIRMATION: ready target=${targetDeviceId ?? "null"} '
          'session=$sessionId region=${region.name} reason=$reason',
        );
        completer.complete();
      }
    }

    void completeError(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    // Check if already confirmed (device already has the region)
    // This handles test scenarios where setRegion completes synchronously
    if (protocol.currentRegion == region) {
      AppLogging.connection(
        '🌍 REGION_FLOW session=$sessionId already_has_region=${region.name}',
      );
      return; // Device already has the region - no need to wait for reboot
    }

    AppLogging.connection(
      'REGION_CONFIRMATION: waiting readiness target=${targetDeviceId ?? "null"} '
      'session=$sessionId region=${region.name}',
    );

    // Setting region causes device reboot, which causes disconnect/reconnect.
    // Confirmation requires the protocol to reach
    // OperationalReadiness.ready in this cycle. The connection-state
    // listener tracks the disconnect/reconnect arc and the target-device
    // identity; the readiness listener gates the actual completion.
    // DevicePairingState.connected by itself fires too early (before
    // phase-2 hydration) and was timing the scanner's hard-timeout out.
    connectionSub = ref.listen<DeviceConnectionState2>(deviceConnectionProvider, (
      previous,
      next,
    ) {
      if (!ref.mounted) {
        completeError(StateError('Region apply canceled'));
        return;
      }

      // Track disconnect (expected during region change)
      if (!sawDisconnect && !next.isConnected) {
        sawDisconnect = true;
        AppLogging.connection(
          '🌍 REGION_FLOW session=$sessionId disconnect_during_apply (expected for reboot)',
        );
        return;
      }

      // If we see terminal invalidation (apple-code 14, peer reset,
      // bond lost), surface it as a typed error so the scanner /
      // region-selection screen can route to re-pair guidance instead
      // of stranding on Connecting.
      if (next.isTerminalInvalidated) {
        AppLogging.connection(
          'REGION_CONFIRMATION: pairing_invalidated target=${targetDeviceId ?? "null"} '
          'session=$sessionId',
        );
        completeError(
          const _RegionPairingInvalidatedException(
            'Region apply canceled - pairing invalidated',
          ),
        );
        return;
      }

      // Track reconnect identity. Don't complete here unless live
      // protocol readiness is already ready — the readiness arm owns
      // completion when it transitions to ready. We sync-read
      // `protocol.readiness` instead of trusting a cached
      // `readinessReady` flag because Riverpod can replay a STALE
      // ready emission from the prior session through a freshly
      // attached listener (observed: connection arm fired
      // `connected_then_ready` while live readiness was still phase2,
      // because a gen=1 ready emission set the flag before the
      // device-reboot disconnect even happened).
      if (sawDisconnect &&
          !sawReconnect &&
          next.isConnected &&
          next.state == DevicePairingState.connected) {
        final reconnectedDeviceId = next.device?.id;
        if (targetDeviceId != null && reconnectedDeviceId != targetDeviceId) {
          deviceMatches = false;
          completeError(
            StateError(
              'Region apply canceled - reconnected to different device',
            ),
          );
          return;
        }
        sawReconnect = true;
        AppLogging.connection(
          '🌍 REGION_FLOW session=$sessionId reconnected_after_reboot newSession=${next.connectionSessionId}',
        );
        final liveReadiness = protocol.readiness;
        if (liveReadiness == OperationalReadiness.ready) {
          completeSuccess('connected_then_ready');
        } else {
          AppLogging.connection(
            'REGION_CONFIRMATION: connected_not_ready '
            'readiness=${liveReadiness.name} session=$sessionId',
          );
        }
      }
    });

    readinessSub = ref.listen<AsyncValue<OperationalReadiness>>(
      meshtasticReadinessProvider,
      (previous, next) {
        if (!ref.mounted) return;
        final readiness = next.asData?.value;
        if (readiness == null) return;
        if (readiness != OperationalReadiness.ready) {
          // Drop the cached flag when readiness drops away from ready.
          // Without this, a stale ready replay (e.g. Riverpod-cached
          // value from before a disconnect) would persist across the
          // reboot cycle and the connection arm would prematurely
          // complete on the next sawReconnect.
          if (readinessReady) {
            AppLogging.connection(
              'REGION_CONFIRMATION: readiness_dropped '
              'readiness=${readiness.name} session=$sessionId',
            );
            readinessReady = false;
          }
          // Useful diagnostic so a stuck phase-2 is visible in logs.
          if (readiness != OperationalReadiness.idle &&
              readiness != OperationalReadiness.linkConnected) {
            AppLogging.connection(
              'REGION_CONFIRMATION: connected_not_ready readiness=${readiness.name} '
              'session=$sessionId',
            );
          }
          return;
        }
        readinessReady = true;
        if (!deviceMatches) return;
        if (!sawDisconnect) {
          // Defensive: if the device never rebooted (firmware accepted
          // region without reset), the connection-arm flag stays false
          // forever. Allow ready to land confirmation when the protocol
          // already reflects the requested region.
          if (protocol.currentRegion == region) {
            completeSuccess('ready_no_reboot');
          }
          return;
        }
        completeSuccess('ready_after_reboot');
      },
    );

    // Firmware 2.8+ applies LoRa config live: the radio is reprogrammed
    // in place and the device does not reboot. The link never drops,
    // readiness never leaves ready, and neither arm above can fire, so
    // the wait would run into the timeout even though the region was
    // accepted. Confirm the write by reading the LoRa config back
    // instead: the region stream echoes the device's answer, and a
    // match while no disconnect has been seen proves the device holds
    // the requested region in the current session.
    //
    // Older firmware schedules its reboot a few seconds after the
    // write and would answer a probe with the new region before going
    // down. Completing on that answer would drop the in-flight guard
    // just as the device disconnects, so the first probe waits out
    // that window. Once a disconnect is seen the probe stays silent
    // and the reconnect / readiness arms own completion.
    regionSub = protocol.regionStream.listen((reported) {
      if (sawDisconnect || !deviceMatches) return;
      if (reported == region) {
        completeSuccess('live_apply_confirmed');
      }
    });
    void probeLiveRegion() {
      if (completer.isCompleted || sawDisconnect) return;
      if (!protocol.isConnected ||
          protocol.readiness != OperationalReadiness.ready) {
        return;
      }
      AppLogging.connection(
        'REGION_CONFIRMATION: live_probe target=${targetDeviceId ?? "null"} '
        'session=$sessionId region=${region.name}',
      );
      unawaited(protocol.getLoRaConfig());
    }

    liveProbeTimer = Timer(_regionLiveProbeInitialDelay, () {
      probeLiveRegion();
      liveProbeTimer = Timer.periodic(
        _regionLiveProbeInterval,
        (_) => probeLiveRegion(),
      );
    });

    try {
      await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          AppErrorHandler.addBreadcrumb(
            'Region: 90s confirmation timeout ' // lint-allow: hardcoded-string
            '(region=${region.name}, session=$sessionId, ' // lint-allow: hardcoded-string
            'sawDisconnect=$sawDisconnect, sawReconnect=$sawReconnect, ' // lint-allow: hardcoded-string
            'readinessReady=$readinessReady)', // lint-allow: hardcoded-string
          );
          throw TimeoutException(
            'Timed out waiting for device to reconnect after region change',
          );
        },
      );
    } finally {
      connectionSub.close();
      readinessSub.close();
      liveProbeTimer?.cancel();
      await regionSub.cancel();
    }
  }
}

/// Region-confirmation aborted because the BLE pairing was invalidated
/// (peer reset, apple-code 14, bond removed) during the reconnect cycle.
/// `applyRegion`'s catch promotes this to a re-pair UX path instead of
/// silently absorbing it as a generic timeout.
class _RegionPairingInvalidatedException implements Exception {
  final String message;
  const _RegionPairingInvalidatedException(this.message);

  @override
  String toString() => 'RegionPairingInvalidatedException: $message';
}

final regionConfigProvider =
    NotifierProvider<RegionConfigNotifier, RegionConfigState>(
      RegionConfigNotifier.new,
    );

/// Lightweight leaf provider that mirrors `regionConfigProvider.state.
/// applyStatus == applying`. Exists ONLY to break a circular
/// dependency: `RegionConfigNotifier.build()` listens to
/// `deviceConnectionProvider`, so reading `regionConfigProvider` from
/// `DeviceConnectionNotifier._handleDisconnect` would close the cycle
/// and Riverpod 3.x throws `CircularDependencyError`. This provider has
/// no upstream dependencies — it's set/cleared imperatively by
/// `RegionConfigNotifier` at the apply-start and apply-finish edges.
class RegionApplyInFlightNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool value) {
    state = value;
  }
}

final regionApplyInFlightProvider =
    NotifierProvider<RegionApplyInFlightNotifier, bool>(
      RegionApplyInFlightNotifier.new,
    );

/// Needs region setup - true if region is UNSET and we're not actively applying/applied
final needsRegionSetupProvider = Provider<bool>((ref) {
  final regionAsync = ref.watch(deviceRegionProvider);
  final regionState = ref.watch(regionConfigProvider);
  final connectionState = ref.watch(deviceConnectionProvider);
  final sessionId = connectionState.connectionSessionId;
  final currentDeviceId = connectionState.device?.id;

  // If region data is loading, don't show setup (wait for it)
  if (regionAsync.isLoading) return false;

  // Check device region from stream
  final isUnset =
      regionAsync.whenOrNull(
        data: (region) =>
            region == config_pbenum.Config_LoRaConfig_RegionCode.UNSET,
      ) ??
      false;
  if (!isUnset) return false;

  // If we're applying or just applied region to THIS device, don't show setup
  // This prevents showing region selection during the reboot/reconnect cycle.
  // "Just applied" is time-bounded (see [regionAppliedWithinCarryOver]): a
  // radio that reports UNSET again long after an apply has genuinely lost
  // its region (re-flash, factory reset) and needs the picker.
  final isSameDevice =
      regionState.targetDeviceId != null &&
      currentDeviceId != null &&
      regionState.targetDeviceId == currentDeviceId;
  if (isSameDevice &&
      (regionState.applyStatus == RegionApplyStatus.applying ||
          regionAppliedWithinCarryOver(regionState))) {
    return false;
  }

  // Session-mismatch case: deviceConnectionProvider just rotated its
  // connectionSessionId (e.g. markAsPaired fired after a fresh BLE
  // connect), and the regionConfigProvider hasn't caught up yet. The
  // device region is UNSET; the right answer is "yes, this session
  // still needs setup". Returning false here was the source of a
  // picker-auto-dismiss race: MainShell's inline guard
  // (`isConnected && needsRegionSetup && !regionConfigured`) flipped
  // false for the brief window between the connection session bump
  // and the region notifier's `new_session` event landing, which
  // unmounted RegionSelectionScreen even though the user was actively
  // looking at it.
  if (regionState.connectionSessionId != sessionId) return true;
  return regionState.applyStatus == RegionApplyStatus.idle;
});

/// Offline message queue provider
final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  final service = OfflineQueueService();
  final protocol = ref.watch(protocolServiceProvider);

  ref.onDispose(() {
    service.dispose();
  });

  // Initialize with send callback that uses pre-tracking
  service.initialize(
    sendCallback:
        ({
          required String text,
          required int to,
          required int channel,
          required bool wantAck,
          required String messageId,
        }) async {
          if (wantAck) {
            // Use pre-tracking to avoid race condition
            return protocol.sendMessageWithPreTracking(
              text: text,
              to: to,
              channel: channel,
              wantAck: wantAck,
              messageId: messageId,
              onPacketIdGenerated: (packetId) {
                ref
                    .read(messagesProvider.notifier)
                    .trackPacket(packetId, messageId);
              },
            );
          } else {
            return protocol.sendMessage(
              text: text,
              to: to,
              channel: channel,
              wantAck: wantAck,
              messageId: messageId,
            );
          }
        },
    updateCallback:
        (
          String messageId,
          MessageStatus status, {
          int? packetId,
          String? errorMessage,
        }) {
          final notifier = ref.read(messagesProvider.notifier);
          final messages = ref.read(messagesProvider);
          final message = messages.firstWhere(
            (m) => m.id == messageId,
            orElse: () => Message(from: 0, to: 0, text: ''),
          );
          if (message.text.isNotEmpty) {
            notifier.updateMessage(
              messageId,
              message.copyWith(
                status: status,
                packetId: packetId,
                errorMessage: errorMessage,
              ),
            );
            // Note: trackPacket is now called in pre-tracking callback before send
          }
        },
    readyToSendCallback: () {
      // Ready when protocol has fully completed config exchange
      // (configurationComplete ensures we've received configCompleteId)
      return protocol.configurationComplete;
    },
  );

  // Check current connection state immediately (in case we're already connected)
  // Skip for MeshCore - this queue uses Meshtastic protocol
  // Note: We check settings asynchronously to avoid blocking provider initialization
  () async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!ref.mounted) return;
    if (settings.lastDeviceProtocol != 'meshcore') {
      final currentState = ref.read(connectionStateProvider);
      currentState.whenData((state) {
        service.setConnectionState(state == DeviceConnectionState.connected);
      });
    }
  }();

  // Listen to connection state changes for future updates
  // Gate for MeshCore - connectionStateProvider watches Meshtastic transport only
  ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
    prev,
    next,
  ) async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!ref.mounted) return;
    if (settings.lastDeviceProtocol == 'meshcore') return; // Skip for MeshCore
    next.whenData((state) {
      service.setConnectionState(state == DeviceConnectionState.connected);
    });
  });

  // Drain as soon as the protocol becomes ready. The connection-edge
  // trigger races config exchange (the queue's readiness wait gives up
  // after 10s); a readiness transition is the authoritative signal that
  // configurationComplete flipped, so the queue never has to win that race.
  ref.listen<AsyncValue<OperationalReadiness>>(meshtasticReadinessProvider, (
    previous,
    next,
  ) async {
    final becameReady =
        next.value == OperationalReadiness.ready &&
        previous?.value != OperationalReadiness.ready;
    if (!becameReady) return;
    final settings = await ref.read(settingsServiceProvider.future);
    if (!ref.mounted) return;
    if (settings.lastDeviceProtocol == 'meshcore') return; // Skip for MeshCore
    service.processQueueIfNeeded();
  });

  return service;
});

/// Pending messages count provider
final pendingMessagesCountProvider = StreamProvider<int>((ref) async* {
  final queue = ref.watch(offlineQueueProvider);
  yield queue.pendingCount;
  await for (final items in queue.queueStream) {
    yield items.length;
  }
});

/// Timer for debouncing linked node metadata refresh
Timer? _linkedNodeMetadataRefreshTimer;

/// Refreshes linked node metadata after a delay to allow node info to arrive
/// from the device. Debounced to avoid multiple refreshes on rapid reconnects.
void _refreshLinkedNodeMetadataAfterDelay(Ref ref) {
  // Cancel any pending refresh
  _linkedNodeMetadataRefreshTimer?.cancel();

  // Wait 10 seconds for node info to arrive from the device before refreshing
  _linkedNodeMetadataRefreshTimer = Timer(const Duration(seconds: 10), () {
    refreshLinkedNodeMetadata(ref);
    _linkedNodeMetadataRefreshTimer = null;
  });
}

// ============================================================
// NOTIFICATION BATCHING - Handles notification floods during sync
// ============================================================

/// State for the notification batch system
class NotificationBatchState {
  final List<PendingMessageNotification> pendingMessages;
  final List<PendingNodeNotification> pendingNodes;

  const NotificationBatchState({
    this.pendingMessages = const [],
    this.pendingNodes = const [],
  });

  NotificationBatchState copyWith({
    List<PendingMessageNotification>? pendingMessages,
    List<PendingNodeNotification>? pendingNodes,
  }) {
    return NotificationBatchState(
      pendingMessages: pendingMessages ?? this.pendingMessages,
      pendingNodes: pendingNodes ?? this.pendingNodes,
    );
  }
}

/// Batches notifications and flushes them after a debounce period
/// This prevents notification floods during sync operations
class NotificationBatchNotifier extends Notifier<NotificationBatchState> {
  Timer? _flushTimer;

  /// Debounce duration - wait this long after last notification before flushing
  static const _debounceDuration = Duration(seconds: 2);

  /// Maximum batch size before forcing a flush
  static const _maxBatchSize = 50;

  @override
  NotificationBatchState build() => const NotificationBatchState();

  /// Queue a message notification for batching
  void queueMessage(PendingMessageNotification message) {
    final newMessages = [...state.pendingMessages, message];
    state = state.copyWith(pendingMessages: newMessages);

    AppLogging.notifications(
      '🔔 Queued message notification (${newMessages.length} pending)',
    );

    _scheduleFlush();
  }

  /// Queue a node notification for batching
  void queueNode(PendingNodeNotification node) {
    final newNodes = [...state.pendingNodes, node];
    state = state.copyWith(pendingNodes: newNodes);

    AppLogging.notifications(
      '🔔 Queued node notification (${newNodes.length} pending)',
    );

    _scheduleFlush();
  }

  /// Schedule a flush after the debounce period
  void _scheduleFlush() {
    // Cancel existing timer
    _flushTimer?.cancel();

    // Check if we've hit max batch size
    final totalPending =
        state.pendingMessages.length + state.pendingNodes.length;
    if (totalPending >= _maxBatchSize) {
      AppLogging.notifications('🔔 Max batch size reached, flushing now');
      _flush();
      return;
    }

    // Schedule flush after debounce period
    _flushTimer = Timer(_debounceDuration, _flush);
  }

  /// Flush all pending notifications
  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    final messages = state.pendingMessages;
    final nodes = state.pendingNodes;

    // Clear state immediately
    state = const NotificationBatchState();

    if (messages.isEmpty && nodes.isEmpty) return;

    AppLogging.notifications(
      '🔔 Flushing ${messages.length} messages and ${nodes.length} nodes',
    );

    // Get settings
    final settingsAsync = ref.read(settingsServiceProvider);
    final settings = settingsAsync.value;
    final playSound = settings?.notificationSoundEnabled ?? true;
    final vibrate = settings?.notificationVibrationEnabled ?? true;
    final masterEnabled = settings?.notificationsEnabled ?? true;
    final channelEnabled = settings?.channelMessageNotificationsEnabled ?? true;
    final dmEnabled = settings?.directMessageNotificationsEnabled ?? true;

    // If master notifications toggle is off, skip everything
    if (!masterEnabled) {
      AppLogging.notifications(
        '🔔 Master notifications disabled, skipping flush',
      );
      return;
    }

    // Re-check category settings — they may have changed since enqueue
    final filteredMessages = messages.where((msg) {
      if (msg.isChannelMessage) return channelEnabled;
      return dmEnabled;
    }).toList();

    if (filteredMessages.length < messages.length) {
      final channelFiltered = messages
          .where((m) => m.isChannelMessage && !channelEnabled)
          .length;
      final dmFiltered = messages
          .where((m) => !m.isChannelMessage && !dmEnabled)
          .length;
      AppLogging.notifications(
        '🔔 Filtered $channelFiltered channel and $dmFiltered DM notifications (settings changed since queue)',
      );
    }

    if (filteredMessages.isEmpty && nodes.isEmpty) return;

    final notificationService = NotificationService();

    // Show batched notifications
    try {
      if (filteredMessages.length == 1) {
        // Single message - show regular notification
        final msg = filteredMessages.first;
        if (msg.isChannelMessage) {
          await notificationService.showChannelMessageNotification(
            senderName: msg.senderName,
            senderShortName: msg.senderShortName,
            channelName: msg.channelName ?? 'Channel',
            message: msg.message,
            channelIndex: msg.channelIndex!,
            fromNodeNum: msg.fromNodeNum,
            replyPacketId: msg.replyPacketId,
            playSound: playSound,
            vibrate: vibrate,
          );
        } else {
          await notificationService.showNewMessageNotification(
            senderName: msg.senderName,
            senderShortName: msg.senderShortName,
            message: msg.message,
            fromNodeNum: msg.fromNodeNum,
            replyPacketId: msg.replyPacketId,
            playSound: playSound,
            vibrate: vibrate,
          );
        }
      } else if (filteredMessages.isNotEmpty) {
        // Multiple messages - show batched
        await notificationService.showBatchedMessagesNotification(
          messages: filteredMessages,
          playSound: playSound,
          vibrate: vibrate,
        );
      }

      if (nodes.isNotEmpty) {
        // Nodes - batched handles single vs multiple internally
        await notificationService.showBatchedNodesNotification(
          nodes: nodes,
          playSound: playSound,
          vibrate: vibrate,
        );
      }
    } catch (e) {
      // Platform channel errors from the notification plugin are non-critical.
      // Log and swallow so they don't propagate as unhandled exceptions.
      AppLogging.notifications('🔔 Error showing batched notification: $e');
    }
  }

  /// Force flush all pending notifications immediately
  Future<void> flushNow() async {
    await _flush();
  }

  /// Cancel all pending notifications without showing them
  void cancelPending() {
    _flushTimer?.cancel();
    _flushTimer = null;
    state = const NotificationBatchState();
    AppLogging.notifications('🔔 Cancelled all pending notifications');
  }
}

final notificationBatchProvider =
    NotifierProvider<NotificationBatchNotifier, NotificationBatchState>(
      NotificationBatchNotifier.new,
    );

/// Snapshot of the BLE / protocol receive pipeline used by support and
/// debug surfaces. Re-reads the protocol service on every watch, so
/// individual fields reflect the latest counters/timestamps. Pure read
/// — does not register subscriptions on its own.
final bleReceivePipelineDiagnosticsProvider =
    Provider<ReceivePipelineDiagnostics>((ref) {
      final protocol = ref.watch(protocolServiceProvider);
      return protocol.receivePipelineDiagnostics;
    });
