// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/admin_config.dart';
import '../core/logging.dart';
import '../core/transport.dart';
import '../dev/demo/demo.dart';
import '../services/transport/ble_transport.dart';
import '../services/transport/usb_transport.dart';
import '../services/protocol/protocol_service.dart';
import '../services/storage/storage_service.dart';
import '../services/mesh_packet_dedupe_store.dart';
import '../services/notifications/notification_service.dart';
import '../services/messaging/offline_queue_service.dart';
import '../services/location/location_service.dart';
import '../services/live_activity/live_activity_service.dart';
import '../models/presence_confidence.dart';
import '../services/nodes/node_identity_store.dart';
import '../features/nodes/node_display_name_resolver.dart';
import '../services/ifttt/ifttt_service.dart';
import '../services/notifications/push_notification_service.dart';
import '../services/messaging/message_utils.dart';
import '../services/bug_report_service.dart';
import '../features/automations/automation_providers.dart';
import '../features/automations/automation_engine.dart';
import '../models/mesh_models.dart';
import '../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../generated/meshtastic/mesh.pb.dart' as mesh_pb;
import 'social_providers.dart';
import 'telemetry_providers.dart';
import 'connection_providers.dart';

// App initialization state - purely about app lifecycle, NOT device connection
// Device connection is handled separately by DeviceConnectionNotifier in connection_providers.dart
enum AppInitState {
  uninitialized,
  initializing,
  ready, // App services loaded, UI can be shown (renamed from initialized)
  needsOnboarding,
  needsScanner, // First launch after onboarding, need to pair a device
  error,
  // REMOVED: needsRegionSetup - handled by MainShell when connected
  // Note: 'initialized' renamed to 'ready' to clarify it's about app, not device
}

class AppInitNotifier extends Notifier<AppInitState> {
  @override
  AppInitState build() => AppInitState.uninitialized;

  /// Manually set state to ready (e.g., after successful connection from scanner)
  void setReady() {
    state = AppInitState.ready;
  }

  /// Alias for backward compatibility
  void setInitialized() => setReady();

  /// Set state to needsScanner (e.g., first launch after onboarding)
  void setNeedsScanner() {
    state = AppInitState.needsScanner;
  }

  /// Initialize core app services (NO device connection here).
  /// Device connection is handled asynchronously by DeviceConnectionNotifier.
  Future<void> initialize() async {
    if (state == AppInitState.initializing) return;

    state = AppInitState.initializing;
    try {
      // Phase 1: Critical services (fast, <500ms target)
      // Initialize notification service
      await NotificationService().initialize();

      // Initialize storage services
      final settings = await ref.read(settingsServiceProvider.future);

      // Check for onboarding completion FIRST
      if (!settings.onboardingComplete) {
        state = AppInitState.needsOnboarding;
        return;
      }

      // Check if device was ever paired
      final lastDeviceId = settings.lastDeviceId;
      final hasEverPaired = lastDeviceId != null;

      // Phase 2: Background services (can complete after UI shows)
      // These run in parallel but don't block app ready state
      _initializeBackgroundServices();

      // Determine initial state based on whether user has ever paired
      if (hasEverPaired) {
        // User has paired before - go directly to main UI
        // Device connection will happen in background via DeviceConnectionNotifier
        AppLogging.connection(
          '🎯 AppInitNotifier: User has paired before, setting ready',
        );
        state = AppInitState.ready;
      } else {
        // Never paired - need to go through scanner first
        AppLogging.connection(
          '🎯 AppInitNotifier: No previous device, setting needsScanner',
        );
        state = AppInitState.needsScanner;
      }
    } catch (e) {
      AppLogging.debug('App initialization failed: $e');
      state = AppInitState.error;
    }
  }

  /// Initialize non-critical services in background
  Future<void> _initializeBackgroundServices() async {
    try {
      // These can complete after UI is shown
      await ref.read(messageStorageProvider.future);
      await ref.read(nodeStorageProvider.future);
      await ref.read(iftttServiceProvider).init();
      await ref.read(automationEngineInitProvider.future);
      AppLogging.debug('Background services initialized');

      // Start background device connection (if auto-reconnect enabled)
      // This happens AFTER storage is ready so we can load cached data
      final settings = await ref.read(settingsServiceProvider.future);
      if (settings.autoReconnect && settings.lastDeviceId != null) {
        AppLogging.debug(
          '🔄 AppInitNotifier: Starting background device connection...',
        );
        // Initialize and start background connection via the new notifier
        await ref.read(deviceConnectionProvider.notifier).initialize();
        ref.read(deviceConnectionProvider.notifier).startBackgroundConnection();
      }
    } catch (e) {
      // Non-critical, log but don't fail
      AppLogging.debug('Background service init error: $e');
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

// Message storage service
final messageStorageProvider = FutureProvider<MessageStorageService>((
  ref,
) async {
  final service = MessageStorageService();
  await service.init();
  return service;
});

// Node storage service - persists nodes and positions
final nodeStorageProvider = FutureProvider<NodeStorageService>((ref) async {
  final service = NodeStorageService();
  await service.init();
  return service;
});

// Node identity store - persists node long/short names separately
final nodeIdentityStoreProvider = FutureProvider<NodeIdentityStore>((
  ref,
) async {
  final service = NodeIdentityStore();
  await service.init();
  return service;
});

// Device favorites service - persists favorite/ignored node numbers
final deviceFavoritesProvider = FutureProvider<DeviceFavoritesService>((
  ref,
) async {
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

final transportProvider = Provider<DeviceTransport>((ref) {
  final type = ref.watch(transportTypeProvider);

  switch (type) {
    case TransportType.ble:
      return BleTransport();
    case TransportType.usb:
      return UsbTransport();
  }
});

// Connection state - create a stream that emits current state immediately,
// then listens for future updates. This fixes the issue where the dashboard
// subscribes after the state has already changed to connected.
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

/// Helper function to clear all device-specific data before connecting to a (potentially different) device.
/// This follows the Meshtastic iOS approach of always fetching fresh data from the device.
/// Should be called BEFORE protocol.start() in all connection paths.
Future<void> clearDeviceDataBeforeConnect(WidgetRef ref) async {
  AppLogging.app('🧹 Clearing device data before new connection...');

  // Clear in-memory state
  ref.read(messagesProvider.notifier).clearMessages();
  ref.read(nodesProvider.notifier).clearNodes();
  ref.read(channelsProvider.notifier).clearChannels();

  // Clear persistent message and node storage
  final messageStorage = await ref.read(messageStorageProvider.future);
  await messageStorage.clearMessages();

  final nodeStorage = await ref.read(nodeStorageProvider.future);
  await nodeStorage.clearNodes();

  // Clear telemetry data (device metrics, environment metrics, positions, etc.)
  final telemetryStorage = await ref.read(telemetryStorageProvider.future);
  await telemetryStorage.clearAllData();

  // Clear routes
  final routeStorage = await ref.read(routeStorageProvider.future);
  await routeStorage.clearAllRoutes();

  AppLogging.app('✅ Device data cleared - ready for fresh data from device');
}

/// Ref-based version for use in providers (non-widget contexts)
Future<void> clearDeviceDataBeforeConnectRef(Ref ref) async {
  AppLogging.app('🧹 Clearing device data before new connection...');

  // Clear in-memory state
  ref.read(messagesProvider.notifier).clearMessages();
  ref.read(nodesProvider.notifier).clearNodes();
  ref.read(channelsProvider.notifier).clearChannels();

  // Clear persistent message and node storage
  final messageStorage = await ref.read(messageStorageProvider.future);
  await messageStorage.clearMessages();

  final nodeStorage = await ref.read(nodeStorageProvider.future);
  await nodeStorage.clearNodes();

  // Clear telemetry data (device metrics, environment metrics, positions, etc.)
  final telemetryStorage = await ref.read(telemetryStorageProvider.future);
  await telemetryStorage.clearAllData();

  // Clear routes
  final routeStorage = await ref.read(routeStorageProvider.future);
  await routeStorage.clearAllRoutes();

  AppLogging.app('✅ Device data cleared - ready for fresh data from device');
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
  ) {
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

      Future.delayed(const Duration(seconds: 2), () {
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

        AppLogging.connection(
          '🔵 Bluetooth ON - starting reconnect for device: $lastDeviceId',
        );

        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.scanning);

        _performReconnect(ref, lastDeviceId);
      });
    }
  });
});

// Auto-reconnect manager - monitors connection and attempts to reconnect on unexpected disconnect
final autoReconnectManagerProvider = Provider<void>((ref) {
  AppLogging.connection('AUTO-RECONNECT MANAGER INITIALIZED');

  // Track the last connected device ID when we connect
  ref.listen<DeviceInfo?>(connectedDeviceProvider, (previous, next) {
    AppLogging.debug(
      '🔄 connectedDeviceProvider changed: ${previous?.id} -> ${next?.id}',
    );
    if (next != null) {
      AppLogging.connection('Storing device ID for reconnect: ${next.id}');
      ref.read(_lastConnectedDeviceIdProvider.notifier).setId(next.id);
    }
  });

  // Listen for connection state changes
  ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
    previous,
    next,
  ) {
    AppLogging.connection(
      'connectionStateProvider changed: $previous -> $next',
    );

    next.whenData((state) {
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

        // Run reconnect in a separate async function to avoid listener issues
        _performReconnect(ref, lastDeviceId);
      } else {
        AppLogging.connection('NOT attempting reconnect - conditions not met');
      }
    });
  });
});

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

    // Wait for device to reboot (Meshtastic devices take ~8-15 seconds)
    AppLogging.connection('Waiting 10s for device to reboot...');
    await Future.delayed(const Duration(seconds: 10));

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
      if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
        AppLogging.connection('Reconnect cancelled');
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
        const serviceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';

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

              if (foundId == deviceId && !completer.isCompleted) {
                AppLogging.connection('✓ Target device found!');
                final deviceInfo = DeviceInfo(
                  id: foundId,
                  name: r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : 'Meshtastic Device',
                  type: TransportType.ble,
                  address: foundId,
                  rssi: r.rssi,
                );
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
      } catch (e, stack) {
        AppLogging.connection('Scan error: $e');
        AppLogging.connection('Stack: $stack');
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
      }

      AppLogging.connection('After scan. foundDevice: ${foundDevice != null}');

      if (foundDevice != null) {
        AppLogging.connection('Device found! Connecting...');
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

          // Clear all previous device data before starting new connection
          await clearDeviceDataBeforeConnectRef(ref);

          final protocol = ref.read(protocolServiceProvider);

          // Set device info for hardware model inference
          protocol.setDeviceName(foundDevice.name);
          protocol.setBleModelNumber(transport.bleModelNumber);
          protocol.setBleManufacturerName(transport.bleManufacturerName);

          await protocol.start();
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

          // Final check - if we're still connected, declare success
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
        final invalidated = await ref
            .read(deviceConnectionProvider.notifier)
            .reportMissingSavedDevice();
        if (invalidated) {
          return;
        }
        if (attempt < maxRetries) {
          // Wait longer before next retry - device may still be rebooting
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }

    // All retries exhausted
    AppLogging.connection('❌ Failed to reconnect after $maxRetries attempts');
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

final meshPacketDedupeStoreProvider = Provider<MeshPacketDedupeStore>((ref) {
  final store = MeshPacketDedupeStore();
  unawaited(store.init());
  ref.onDispose(() {
    store.dispose();
  });
  return store;
});

// Protocol service - singleton instance that persists across rebuilds
final protocolServiceProvider = Provider<ProtocolService>((ref) {
  final transport = ref.watch(transportProvider);
  final dedupeStore = ref.watch(meshPacketDedupeStoreProvider);
  final service = ProtocolService(transport, dedupeStore: dedupeStore);

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

  AppLogging.debug(
    '🟢 ProtocolService provider created - instance: ${service.hashCode}',
  );

  // Set up notification reaction callback to send emoji DMs
  NotificationService().onReactionSelected =
      (int toNodeNum, String emoji) async {
        try {
          AppLogging.app('Sending reaction "$emoji" to node $toNodeNum');
          await service.sendMessage(
            text: emoji,
            to: toNodeNum,
            wantAck: true,
            source: MessageSource.reaction,
          );
          AppLogging.app('Reaction sent successfully');
        } catch (e) {
          AppLogging.app('Failed to send reaction: $e');
        }
      };

  // Keep the service alive for the lifetime of the app
  ref.onDispose(() {
    AppLogging.debug(
      '🔴 ProtocolService being disposed - instance: ${service.hashCode}',
    );
    // Clear the callback when disposing
    NotificationService().onReactionSelected = null;
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

// Location service - provides phone GPS to mesh devices
// Like iOS Meshtastic app, sends phone GPS coordinates to mesh
// when device doesn't have its own GPS hardware
final locationServiceProvider = Provider<LocationService>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  final service = LocationService(protocol);

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
  late LiveActivityService _liveActivityService;

  @override
  bool build() {
    _liveActivityService = ref.watch(liveActivityServiceProvider);

    // Set up disposal
    ref.onDispose(() {
      _channelUtilSubscription?.cancel();
      _liveActivityService.endAllActivities();
    });

    _init();
    return false;
  }

  void _init() {
    // Listen for connection state changes
    ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
      previous,
      current,
    ) {
      current.whenData((connectionState) {
        if (connectionState == DeviceConnectionState.connected && !state) {
          _startLiveActivity();
        } else if (connectionState == DeviceConnectionState.disconnected &&
            state) {
          _endLiveActivity();
        }
      });
    }, fireImmediately: true);

    // Listen for node updates to refresh battery/signal/online count
    ref.listen<Map<int, MeshNode>>(nodesProvider, (previous, current) {
      if (!state || !_liveActivityService.isActive) return;
      _updateFromNodes(current);
    });
  }

  Future<void> _startLiveActivity() async {
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
    final rssi = myNode?.rssi;
    final snr = myNode?.snr;

    final activeCount = _activeNodeCount(nodes);
    final totalCount = nodes.length;

    // Find nearest node with distance
    final nearestNode = _findNearestNode(nodes, myNodeNum);

    AppLogging.debug(
      '📱 Starting Live Activity: device=$deviceName, shortName=$shortName, '
      'battery=$batteryLevel%, rssi=$rssi, snr=$snr, nodes=$activeCount/$totalCount',
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
    );

    if (success) {
      state = true;

      // Set up telemetry listener for channel utilization updates
      _channelUtilSubscription?.cancel();
      _channelUtilSubscription = protocol.channelUtilStream.listen((
        channelUtil,
      ) {
        if (!_liveActivityService.isActive) return;

        final currentNodes = ref.read(nodesProvider);
        final currentMyNodeNum = ref.read(myNodeNumProvider);
        final currentNode = currentMyNodeNum != null
            ? currentNodes[currentMyNodeNum]
            : null;

        final currentOnlineCount = _activeNodeCount(currentNodes);

        final currentNearestNode = _findNearestNode(
          currentNodes,
          currentMyNodeNum,
        );

        _liveActivityService.updateActivity(
          batteryLevel: currentNode?.batteryLevel,
          signalStrength: currentNode?.rssi,
          snr: currentNode?.snr,
          nodesOnline: currentOnlineCount,
          totalNodes: currentNodes.length,
          channelUtilization: channelUtil,
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
              currentNearestNode?.$1.shortName ??
              currentNearestNode?.$1.longName,
        );
      });
    }
  }

  void _updateFromNodes(Map<int, MeshNode> nodes) {
    final myNodeNum = ref.read(myNodeNumProvider);
    if (myNodeNum == null) return;

    final myNode = nodes[myNodeNum];
    if (myNode == null) return;

    final onlineCount = _activeNodeCount(nodes);
    final totalCount = nodes.length;
    final nearestNode = _findNearestNode(nodes, myNodeNum);

    AppLogging.debug('📱 Live Activity update: nodes=$onlineCount/$totalCount');

    _liveActivityService.updateActivity(
      deviceName: myNode.longName,
      shortName: myNode.shortName,
      batteryLevel: myNode.batteryLevel,
      signalStrength: myNode.rssi,
      snr: myNode.snr,
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
    );
  }

  int _activeNodeCount(Map<int, MeshNode> nodes) {
    final now = DateTime.now();
    return nodes.values
        .where(
          (node) => PresenceCalculator.fromLastHeard(
            node.lastHeard,
            now: now,
          ).isActive,
        )
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

  Future<void> _endLiveActivity() async {
    _channelUtilSubscription?.cancel();
    _channelUtilSubscription = null;
    await _liveActivityService.endActivity();
    state = false;
    AppLogging.debug('📱 Ended Live Activity - device disconnected');
  }
}

final liveActivityManagerProvider =
    NotifierProvider<LiveActivityManagerNotifier, bool>(
      LiveActivityManagerNotifier.new,
    );

// Messages with persistence
class MessagesNotifier extends Notifier<List<Message>> {
  final Map<int, String> _packetToMessageId = {};
  final LinkedHashMap<String, DateTime> _recentMessageSignatures =
      LinkedHashMap();
  static const Duration _duplicateSignatureWindow = Duration(seconds: 5);
  MessageStorageService? _storage;
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<MessageDeliveryUpdate>? _deliverySubscription;

  // Reconciliation guard per-node for this app session
  final Set<int> _reconciledNodesThisSession = {};

  @override
  List<Message> build() {
    final protocol = ref.watch(protocolServiceProvider);
    final storageAsync = ref.watch(messageStorageProvider);
    _storage = storageAsync.value;

    // Set up disposal for stream subscriptions
    ref.onDispose(() {
      _messageSubscription?.cancel();
      _deliverySubscription?.cancel();
    });

    // Initialize asynchronously
    _init(protocol);

    return [];
  }

  Future<void> _init(ProtocolService protocol) async {
    // Demo mode: seed sample messages if enabled and storage is empty
    if (DemoConfig.isEnabled && _storage != null) {
      final existing = await _storage!.loadMessages();
      if (existing.isEmpty) {
        AppLogging.debug('${DemoConfig.modeLabel} Seeding demo messages');
        state = DemoData.sampleMessages;
        return;
      }
    }

    // Load persisted messages
    if (_storage != null) {
      final savedMessages = await _storage!.loadMessages();
      if (savedMessages.isNotEmpty) {
        if (!ref.mounted) return;
        state = savedMessages;
        AppLogging.messages(
          'Loaded ${savedMessages.length} messages from storage',
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
    }

    // Listen for new messages
    _messageSubscription = protocol.messageStream.listen((message) {
      if (!ref.mounted) return;
      AppLogging.messages(
        '📨 New message: from=${message.from}, to=${message.to.toRadixString(16)}, '
        'channel=${message.channel}, isBroadcast=${message.isBroadcast}, sent=${message.sent}, id=${message.id}',
      );

      if (message.sent) {
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

      _addMessageToState(message);
      _notifyNewMessage(message);
    });

    // Listen for message push events from PushNotificationService and persist them
    final push = ref.watch(pushNotificationServiceProvider);
    final pushSub = push.onContentRefresh.listen((event) {
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

    ref.onDispose(() {
      _messageSubscription?.cancel();
      _deliverySubscription?.cancel();
      pushSub.cancel();
    });

    // Listen for delivery status updates
    _deliverySubscription = protocol.deliveryStream.listen((update) {
      if (!ref.mounted) return;
      _handleDeliveryUpdate(update);
    });

    // Ensure we can be explicitly asked to rehydrate from storage (for debug or reconnect canary)
    // Adds two helper functions on the notifier: reconcileFromStorageForNode and forceRehydrateAllFromStorage
  }

  void _notifyNewMessage(Message message) {
    AppLogging.app('_notifyNewMessage called for message from ${message.from}');

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

    // Get sender name - prefer node lookup, fallback to message's cached sender info
    final nodes = ref.read(nodesProvider);
    final senderNode = nodes[message.from];
    final senderName = senderNode?.displayName ?? message.senderDisplayName;
    final senderShortName = senderNode?.shortName ?? message.senderShortName;
    AppLogging.app('Sender: $senderName');

    // Check if it's a channel message or direct message
    final isChannelMessage = message.channel != null && message.channel! > 0;
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
      channelName = channel?.name ?? 'Channel ${message.channel}';

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

    // Queue notification for batching (handles flood protection)
    ref
        .read(notificationBatchProvider.notifier)
        .queueMessage(
          PendingMessageNotification(
            senderName: senderName,
            senderShortName: senderShortName,
            message: message.text,
            fromNodeNum: message.from,
            channelIndex: isChannelMessage ? message.channel : null,
            channelName: channelName,
          ),
        );

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
      channelName = channel?.name ?? 'Channel ${message.channel}';
    }

    final automationMessage = AutomationMessage(
      from: message.from,
      text: message.text,
      channel: message.channel,
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
      channelName = channel?.name ?? 'Channel ${message.channel}';
    }

    iftttService.processMessage(
      message,
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

    final messageId = _packetToMessageId[update.packetId];
    if (messageId == null) {
      AppLogging.debug(
        '📨 ❌ Delivery update for unknown packet ${update.packetId}',
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

    // If message is already delivered, ignore subsequent updates (especially failures)
    // This handles the case where we get ACK followed by a timeout/error packet
    if (message.status == MessageStatus.delivered) {
      AppLogging.debug(
        '📨 ⏭️ Ignoring update for already-delivered message: $messageId',
      );
      return;
    }

    final updatedMessage = message.copyWith(
      status: update.isSuccess ? MessageStatus.delivered : MessageStatus.failed,
      routingError: update.error,
      errorMessage: update.error?.message,
    );

    state = [
      ...state.sublist(0, messageIndex),
      updatedMessage,
      ...state.sublist(messageIndex + 1),
    ];
    _storage?.saveMessage(updatedMessage);

    // Stop tracking after successful delivery to ignore future error packets
    if (update.isSuccess) {
      _packetToMessageId.remove(update.packetId);
      AppLogging.debug('📨 ✅ Message delivered, stopped tracking: $messageId');
    } else {
      AppLogging.debug(
        '📨 ❌ Message failed: $messageId - ${update.error?.message}',
      );
    }
  }

  void trackPacket(int packetId, String messageId) {
    _packetToMessageId[packetId] = messageId;
    AppLogging.debug('📨 Tracking packet $packetId -> message $messageId');
    AppLogging.debug(
      '📨 Current tracked packets: ${_packetToMessageId.keys.toList()}',
    );
  }

  void addMessage(Message message) {
    if (_isDuplicateMessage(message)) {
      AppLogging.messages('📨 Duplicate message ignored: id=${message.id}');
      return;
    }

    String convKey;
    if (message.channel != null && message.channel! > 0) {
      convKey = 'channel:${message.channel}';
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
    if (message.id.isNotEmpty && state.any((m) => m.id == message.id)) {
      return true;
    }
    if (message.packetId != null &&
        state.any((m) => m.packetId == message.packetId)) {
      return true;
    }
    final signature = _messageSignature(message);
    if (_recentMessageSignatures.containsKey(signature)) {
      return true;
    }
    return false;
  }

  void _addMessageToState(Message message) {
    state = [...state, message];
    _storage?.saveMessage(message);
    _recordMessageSignature(message);
  }

  String _messageSignature(Message message) {
    final target = message.channel != null && message.channel! > 0
        ? 'channel:${message.channel}'
        : 'dm:${message.from == ref.read(myNodeNumProvider) ? message.to : message.from}';
    return '$target|${message.text}|${message.timestamp.millisecondsSinceEpoch}';
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
    state = state.map((m) => m.id == messageId ? updatedMessage : m).toList();
    _storage?.saveMessage(updatedMessage);
  }

  void deleteMessage(String messageId) {
    state = state.where((m) => m.id != messageId).toList();
    _storage?.deleteMessage(messageId);
  }

  void clearMessages() {
    state = [];
    _storage?.clearMessages();
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
      if (!state.any((s) => s.id == m.id)) {
        state = [...state, m];
        inserted++;
      }
    }
    AppLogging.messages('🔧 Force rehydrate: total=$total, inserted=$inserted');
    return {'total': total, 'inserted': inserted};
  }
}

final messagesProvider = NotifierProvider<MessagesNotifier, List<Message>>(
  MessagesNotifier.new,
);

// Nodes
class NodesNotifier extends Notifier<Map<int, MeshNode>> {
  NodeStorageService? _storage;
  DeviceFavoritesService? _deviceFavorites;
  StreamSubscription<MeshNode>? _nodeSubscription;
  final Set<int> _fallbackLoggedNodes = {};
  final Set<int> _bleStripLoggedNodes = {};

  /// Debounced batch save: collect node updates and flush after a delay
  final Map<int, MeshNode> _pendingSaves = {};
  Timer? _saveTimer;
  static const _saveDebounceDuration = Duration(seconds: 2);

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

    // Set up disposal
    ref.onDispose(() {
      _nodeSubscription?.cancel();
      // Flush any pending saves before disposing
      _flushPendingSaves();
      _saveTimer?.cancel();
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
    // Demo mode: seed sample nodes if enabled and storage is empty
    if (DemoConfig.isEnabled && _storage != null) {
      final existing = await _storage!.loadNodes();
      if (existing.isEmpty) {
        AppLogging.debug('${DemoConfig.modeLabel} Seeding demo nodes');
        state = {for (final node in DemoData.sampleNodes) node.nodeNum: node};
        return;
      }
    }

    // Get persisted favorites/ignored from DeviceFavoritesService
    final favoritesSet = _deviceFavorites?.favorites ?? <int>{};
    final ignoredSet = _deviceFavorites?.ignored ?? <int>{};
    final identities = ref.read(nodeIdentityProvider);

    // Load persisted nodes (with their positions) first
    if (_storage != null) {
      final savedNodes = await _storage!.loadNodes();
      if (savedNodes.isNotEmpty) {
        AppLogging.nodes('Loaded ${savedNodes.length} nodes from storage');
        final nodeMap = <int, MeshNode>{};
        for (var node in savedNodes) {
          final sanitized = _stripBleNamesIfNeeded(node);
          if (sanitized.longName != node.longName ||
              sanitized.shortName != node.shortName) {
            node = sanitized;
            _scheduleSave(node);
          }
          // Apply persisted favorites/ignored status from DeviceFavoritesService
          node = node.copyWith(
            isFavorite: favoritesSet.contains(node.nodeNum),
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
    }

    // Then merge with existing nodes from protocol service
    // Protocol nodes take precedence but preserve stored positions if new nodes don't have them
    final protocolNodes = Map<int, MeshNode>.from(protocol.nodes);
    for (final entry in protocolNodes.entries) {
      var node = entry.value;
      final existing = state[entry.key];
      if (existing != null) {
        // Preserve stored properties that don't come from protocol
        node = node.copyWith(
          // Preserve position if protocol node doesn't have one
          latitude: node.hasPosition ? node.latitude : existing.latitude,
          longitude: node.hasPosition ? node.longitude : existing.longitude,
          altitude: node.hasPosition ? node.altitude : existing.altitude,
          // Always preserve user preferences from DeviceFavoritesService
          isFavorite: favoritesSet.contains(node.nodeNum),
          isIgnored: ignoredSet.contains(node.nodeNum),
        );
      } else {
        // New node - apply favorites/ignored from service
        node = node.copyWith(
          isFavorite: favoritesSet.contains(node.nodeNum),
          isIgnored: ignoredSet.contains(node.nodeNum),
        );
      }
      node = _stripBleNamesIfNeeded(node);
      node = _mergeIdentity(node, identities[node.nodeNum]);
      state = {...state, entry.key: node};
      _logFallbackIfNeeded(node);
    }

    // Listen for new nodes
    _nodeSubscription = protocol.nodeStream.listen((node) {
      if (!ref.mounted) return;
      final isNewNode = !state.containsKey(node.nodeNum);
      final existing = state[node.nodeNum];

      // Get latest favorites/ignored status
      final currentFavorites = _deviceFavorites?.favorites ?? <int>{};
      final currentIgnored = _deviceFavorites?.ignored ?? <int>{};

      if (existing != null) {
        // Preserve stored properties that don't come from protocol
        node = node.copyWith(
          // Preserve position if new node doesn't have one
          latitude: node.hasPosition ? node.latitude : existing.latitude,
          longitude: node.hasPosition ? node.longitude : existing.longitude,
          altitude: node.hasPosition ? node.altitude : existing.altitude,
          // Always preserve user preferences from DeviceFavoritesService
          isFavorite: currentFavorites.contains(node.nodeNum),
          isIgnored: currentIgnored.contains(node.nodeNum),
        );
      } else {
        // New node - apply favorites/ignored from service
        node = node.copyWith(
          isFavorite: currentFavorites.contains(node.nodeNum),
          isIgnored: currentIgnored.contains(node.nodeNum),
        );
      }

      node = _stripBleNamesIfNeeded(node);

      // Note: Identity store is updated via ProtocolService.onIdentityUpdate callback
      // which is set up in protocolServiceProvider. This avoids duplicate upserts.

      // Apply cached identity (if any) to ensure stable display names
      final identities = ref.read(nodeIdentityProvider);
      node = _mergeIdentity(node, identities[node.nodeNum]);

      state = {...state, node.nodeNum: node};

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
    final identities = ref.read(nodeIdentityProvider);
    node = _stripBleNamesIfNeeded(node);
    final merged = _mergeIdentity(node, identities[node.nodeNum]);
    state = {...state, node.nodeNum: merged};
    _logFallbackIfNeeded(merged);
    _scheduleSave(merged);
  }

  void removeNode(int nodeNum) {
    final newState = Map<int, MeshNode>.from(state);
    newState.remove(nodeNum);
    state = newState;
    // Also remove from persistent storage
    _storage?.deleteNode(nodeNum);
  }

  void clearNodes() {
    state = {};
    _storage?.clearNodes();
  }
}

final nodesProvider = NotifierProvider<NodesNotifier, Map<int, MeshNode>>(
  NodesNotifier.new,
);

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

// My node number - updates when received from device
class MyNodeNumNotifier extends Notifier<int?> {
  StreamSubscription<int>? _myNodeNumSubscription;

  @override
  int? build() {
    final protocol = ref.watch(protocolServiceProvider);

    // Set up disposal
    ref.onDispose(() {
      _myNodeNumSubscription?.cancel();
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
  }
}

final myNodeNumProvider = NotifierProvider<MyNodeNumNotifier, int?>(
  MyNodeNumNotifier.new,
);

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
  RemoteAdminState build() => const RemoteAdminState();

  /// Set the target node for remote configuration
  void setTarget(int nodeNum, String? nodeName) {
    state = RemoteAdminState(
      targetNodeNum: nodeNum,
      targetNodeName: nodeName,
      isConfiguring: false,
    );
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
/// and not yet read (messages where received=true and from != myNodeNum)
final unreadMessagesCountProvider = Provider<int>((ref) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  if (myNodeNum == null) return 0;

  return messages.where((m) => m.received && m.from != myNodeNum).length;
});

/// Has unread messages provider - simple boolean check
final hasUnreadMessagesProvider = Provider<bool>((ref) {
  return ref.watch(unreadMessagesCountProvider) > 0;
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

        await NotificationService().showBatchedNodesNotification(
          nodes: nodes,
          playSound: playSound,
          vibrate: vibrate,
        );
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
        if (isSameDevice &&
            (state.applyStatus == RegionApplyStatus.applying ||
                state.applyStatus == RegionApplyStatus.applied)) {
          AppLogging.protocol(
            'REGION_FLOW choose=${state.regionChoice?.name ?? "null"} session=${state.connectionSessionId} '
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
        AppLogging.protocol(
          'REGION_FLOW choose=null session=${next.connectionSessionId} status=idle reason=new_session device=$currentDeviceId',
        );
        return;
      }

      if (state.applyStatus == RegionApplyStatus.applying) {
        if (next.isTerminalInvalidated) {
          state = state.copyWith(applyStatus: RegionApplyStatus.failed);
          AppLogging.protocol(
            'REGION_FLOW choose=${state.regionChoice?.name ?? "null"} session=${state.connectionSessionId} status=failed reason=pairing_invalidated',
          );
          return;
        }

        // NOTE: We intentionally DO NOT mark as failed on disconnect during apply.
        // Setting region causes device reboot, which triggers a temporary disconnect.
        // The _awaitRegionConfirmation method handles this expected disconnect/reconnect cycle.
        // Marking as failed here would abort the operation before reconnection can complete.
        if (previous?.isConnected == true && !next.isConnected) {
          AppLogging.protocol(
            'REGION_FLOW choose=${state.regionChoice?.name ?? "null"} session=${state.connectionSessionId} status=applying disconnect_expected=true reason=device_reboot',
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
          AppLogging.protocol(
            'REGION_FLOW choose=${region.name} session=${state.connectionSessionId} status=applied reason=region_stream',
          );
        }
      });
    });

    return RegionConfigState(
      connectionSessionId: connectionState.connectionSessionId,
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
      AppLogging.protocol(
        'REGION_FLOW choose=${region.name} session=$sessionId status=failed reason=not_connected',
      );
      throw StateError('Cannot set region while disconnected');
    }

    // If already applied for this region, skip
    if (state.applyStatus == RegionApplyStatus.applied &&
        state.regionChoice == region) {
      AppLogging.protocol(
        'REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=already_applied',
      );
      return;
    }

    if (state.applyStatus == RegionApplyStatus.applying &&
        state.regionChoice == region &&
        state.connectionSessionId == sessionId) {
      AppLogging.protocol(
        'REGION_FLOW choose=${region.name} session=$sessionId status=applying reason=already_applying',
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
    AppLogging.protocol(
      'REGION_FLOW choose=${region.name} session=$sessionId device=$deviceId status=applying reason=$reason',
    );

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setRegion(region);
      await _awaitRegionConfirmation(region, sessionId);

      // If we get here, _awaitRegionConfirmation completed successfully.
      // This means the device rebooted and reconnected, confirming the region was applied.
      // Note: The session ID will have changed because reconnection creates a new session.
      // This is expected behavior - don't treat session change as an error here.

      if (!ref.mounted) return;

      // The region stream listener might have already set status to applied
      if (state.applyStatus == RegionApplyStatus.applied) {
        return;
      }

      // Mark as applied - the reconnection confirms success
      state = state.copyWith(applyStatus: RegionApplyStatus.applied);
      AppLogging.protocol(
        'REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=reconnect_confirmed',
      );
    } catch (e) {
      if (!ref.mounted) rethrow;

      // Check if the region was actually applied despite the error (e.g., timeout during reconnect
      // but region stream already confirmed the change)
      final protocol = ref.read(protocolServiceProvider);
      if (state.applyStatus == RegionApplyStatus.applied &&
          state.regionChoice == region) {
        AppLogging.protocol(
          'REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=confirmed_despite_error',
        );
        // Region was confirmed by stream - don't treat as failure
        return;
      }
      if (protocol.currentRegion == region) {
        // Device has the correct region - mark as applied
        state = state.copyWith(applyStatus: RegionApplyStatus.applied);
        AppLogging.protocol(
          'REGION_FLOW choose=${region.name} session=$sessionId status=applied reason=device_has_region',
        );
        return;
      }

      // Only set failed if we're still in applying state
      if (state.applyStatus == RegionApplyStatus.applying) {
        state = state.copyWith(applyStatus: RegionApplyStatus.failed);
        AppLogging.protocol(
          'REGION_FLOW choose=${region.name} session=$sessionId status=failed reason=${e.runtimeType}',
        );
      }
      rethrow;
    }
  }

  Future<void> _awaitRegionConfirmation(
    config_pbenum.Config_LoRaConfig_RegionCode region,
    int sessionId,
  ) async {
    // Capture the device ID so we can verify reconnect is to the same device
    final targetDeviceId = ref.read(deviceConnectionProvider).device?.id;
    final protocol = ref.read(protocolServiceProvider);

    final completer = Completer<void>();
    ProviderSubscription<DeviceConnectionState2>? connectionSub;
    bool sawDisconnect = false;
    bool sawReconnect = false;

    void completeSuccess() {
      if (!completer.isCompleted) {
        AppLogging.protocol(
          'REGION_FLOW session=$sessionId region_confirmed=${region.name}',
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
      AppLogging.protocol(
        'REGION_FLOW session=$sessionId already_has_region=${region.name}',
      );
      return; // Device already has the region - no need to wait for reboot
    }

    // Setting region causes device reboot, which causes disconnect/reconnect.
    // We track the connection state through this cycle:
    // 1. Connected -> Disconnected (expected reboot)
    // 2. Disconnected -> Connecting -> Connected (auto-reconnect)
    // 3. Once reconnected and protocol is ready, we complete
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
        AppLogging.protocol(
          'REGION_FLOW session=$sessionId disconnect_during_apply (expected for reboot)',
        );
        return;
      }

      // If we see terminal invalidation, that's a real error
      if (next.isTerminalInvalidated) {
        completeError(
          StateError('Region apply canceled - terminal invalidation'),
        );
        return;
      }

      // Track reconnect - but only complete if device is fully connected
      // (state == DevicePairingState.connected, not just .connecting)
      if (sawDisconnect &&
          !sawReconnect &&
          next.isConnected &&
          next.state == DevicePairingState.connected) {
        final reconnectedDeviceId = next.device?.id;
        if (targetDeviceId != null && reconnectedDeviceId != targetDeviceId) {
          completeError(
            StateError(
              'Region apply canceled - reconnected to different device',
            ),
          );
          return;
        }
        sawReconnect = true;
        AppLogging.protocol(
          'REGION_FLOW session=$sessionId reconnected_after_reboot newSession=${next.connectionSessionId}',
        );

        // Device is fully reconnected - region change succeeded
        // The device only reboots after accepting the region, so if we're
        // connected again, the region was applied successfully.
        completeSuccess();
      }
    });

    try {
      await completer.future.timeout(
        const Duration(seconds: 90), // Increased timeout for slow reboots
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for device to reconnect after region change',
        ),
      );
    } finally {
      connectionSub.close();
    }
  }
}

final regionConfigProvider =
    NotifierProvider<RegionConfigNotifier, RegionConfigState>(
      RegionConfigNotifier.new,
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
  // This prevents showing region selection during the reboot/reconnect cycle
  final isSameDevice =
      regionState.targetDeviceId != null &&
      currentDeviceId != null &&
      regionState.targetDeviceId == currentDeviceId;
  if (isSameDevice &&
      (regionState.applyStatus == RegionApplyStatus.applying ||
          regionState.applyStatus == RegionApplyStatus.applied)) {
    return false;
  }

  // Only need setup if we're idle (not applying/applied) for this session
  if (regionState.connectionSessionId != sessionId) return false;
  return regionState.applyStatus == RegionApplyStatus.idle;
});

/// Offline message queue provider
final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  final service = OfflineQueueService();
  final protocol = ref.watch(protocolServiceProvider);

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
  final currentState = ref.read(connectionStateProvider);
  currentState.whenData((state) {
    service.setConnectionState(state == DeviceConnectionState.connected);
  });

  // Listen to connection state changes for future updates
  ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
    prev,
    next,
  ) {
    next.whenData((state) {
      service.setConnectionState(state == DeviceConnectionState.connected);
    });
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

    final notificationService = NotificationService();

    // Show batched notifications
    if (messages.length == 1) {
      // Single message - show regular notification
      final msg = messages.first;
      if (msg.isChannelMessage) {
        await notificationService.showChannelMessageNotification(
          senderName: msg.senderName,
          senderShortName: msg.senderShortName,
          channelName: msg.channelName ?? 'Channel',
          message: msg.message,
          channelIndex: msg.channelIndex!,
          fromNodeNum: msg.fromNodeNum,
          playSound: playSound,
          vibrate: vibrate,
        );
      } else {
        await notificationService.showNewMessageNotification(
          senderName: msg.senderName,
          senderShortName: msg.senderShortName,
          message: msg.message,
          fromNodeNum: msg.fromNodeNum,
          playSound: playSound,
          vibrate: vibrate,
        );
      }
    } else if (messages.isNotEmpty) {
      // Multiple messages - show batched
      await notificationService.showBatchedMessagesNotification(
        messages: messages,
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
