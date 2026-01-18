// Connection State Management
//
// This file implements the deferred connection architecture where:
// - App startup is independent of device connection
// - Device connection happens asynchronously in the background
// - Features are gated based on connection requirements
//
// Key concepts:
// - `DevicePairingState`: Device connection lifecycle (independent of app state)
// - `DeviceConnectionNotifier`: Manages async device connection
// - `FeatureRequirement`: Declares what features need to function
// - `FeatureAvailabilityNotifier`: Computed feature availability

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/transport.dart';
import 'app_providers.dart';

// =============================================================================
// DEVICE PAIRING STATE
// =============================================================================

/// Device pairing/connection lifecycle state.
/// This is independent of app initialization state.
enum DevicePairingState {
  /// No device has ever been paired (first launch)
  neverPaired,

  /// Was paired before but not currently connected
  disconnected,

  /// Actively scanning for known device
  scanning,

  /// BLE connection in progress
  connecting,

  /// BLE connected, waiting for protocol configuration
  configuring,

  /// Fully connected and protocol configured
  connected,

  /// Connection error (BT disabled, device unavailable, auth failed)
  error,
}

/// Reason for disconnection or error
enum DisconnectReason {
  /// No error - normal state
  none,

  /// Device not found during scan
  deviceNotFound,

  /// Bluetooth is disabled
  bluetoothDisabled,

  /// BLE connection failed
  connectionFailed,

  /// Protocol configuration timeout
  configTimeout,

  /// PIN/authentication cancelled or failed
  authFailed,

  /// User manually disconnected
  userDisconnected,

  /// Device disconnected unexpectedly
  unexpectedDisconnect,
}

/// Complete device connection state with metadata
class DeviceConnectionState2 {
  final DevicePairingState state;
  final DisconnectReason reason;
  final String? errorMessage;
  final DeviceInfo? device;
  final DateTime? lastConnectedAt;
  final int reconnectAttempts;
  final int? myNodeNum;

  const DeviceConnectionState2({
    required this.state,
    this.reason = DisconnectReason.none,
    this.errorMessage,
    this.device,
    this.lastConnectedAt,
    this.reconnectAttempts = 0,
    this.myNodeNum,
  });

  bool get isConnected => state == DevicePairingState.connected;
  bool get isConnecting =>
      state == DevicePairingState.connecting ||
      state == DevicePairingState.configuring;
  bool get isScanning => state == DevicePairingState.scanning;
  bool get hasError => state == DevicePairingState.error;
  bool get wasPreviouslyPaired => state != DevicePairingState.neverPaired;

  DeviceConnectionState2 copyWith({
    DevicePairingState? state,
    DisconnectReason? reason,
    String? errorMessage,
    DeviceInfo? device,
    DateTime? lastConnectedAt,
    int? reconnectAttempts,
    int? myNodeNum,
  }) {
    return DeviceConnectionState2(
      state: state ?? this.state,
      reason: reason ?? this.reason,
      errorMessage: errorMessage ?? this.errorMessage,
      device: device ?? this.device,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      myNodeNum: myNodeNum ?? this.myNodeNum,
    );
  }

  @override
  String toString() =>
      'DeviceConnectionState2(state: $state, reason: $reason, device: ${device?.name})';
}

// =============================================================================
// DEVICE CONNECTION NOTIFIER
// =============================================================================

/// Manages device connection lifecycle independently from app initialization.
/// Starts connection asynchronously in background after app is ready.
class DeviceConnectionNotifier extends Notifier<DeviceConnectionState2> {
  StreamSubscription<DeviceConnectionState>? _connectionSubscription;
  Timer? _scanTimer;
  bool _isInitialized = false;
  bool _userDisconnected = false; // Track if user manually disconnected
  bool _backgroundScanInProgress = false; // Guard against concurrent scans

  @override
  DeviceConnectionState2 build() {
    // Clean up subscriptions when provider is disposed
    ref.onDispose(() {
      AppLogging.connection('🔌 DeviceConnectionNotifier: Disposing...');
      _connectionSubscription?.cancel();
      _scanTimer?.cancel();
    });

    return const DeviceConnectionState2(state: DevicePairingState.neverPaired);
  }

  /// Initialize the connection manager.
  /// Call this after app services are ready.
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Already initialized, skipping',
      );
      return;
    }
    _isInitialized = true;
    _userDisconnected = false;

    AppLogging.connection('🔌 DeviceConnectionNotifier: Initializing...');

    // Check if we have a previously paired device
    final settings = await ref.read(settingsServiceProvider.future);
    final lastDeviceId = settings.lastDeviceId;

    if (lastDeviceId == null) {
      // Never paired before
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: No previous device, state=neverPaired',
      );
      state = const DeviceConnectionState2(
        state: DevicePairingState.neverPaired,
      );
      return;
    }

    // Had a device before - mark as disconnected and start background connection
    AppLogging.connection(
      '🔌 DeviceConnectionNotifier: Previous device found: $lastDeviceId',
    );
    state = const DeviceConnectionState2(
      state: DevicePairingState.disconnected,
    );

    // Listen to transport connection state changes
    _setupConnectionListener();

    // Start background connection attempt if auto-reconnect enabled
    if (settings.autoReconnect) {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Auto-reconnect enabled, scheduling connection...',
      );
      // Small delay to let UI render first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_userDisconnected) {
          startBackgroundConnection();
        } else {
          AppLogging.connection(
            '🔌 DeviceConnectionNotifier: Skipping auto-connect - user disconnected',
          );
        }
      });
    } else {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Auto-reconnect disabled',
      );
    }
  }

  /// Set up listener for transport connection state changes
  void _setupConnectionListener() {
    final transport = ref.read(transportProvider);

    _connectionSubscription?.cancel();
    _connectionSubscription = transport.stateStream.listen((transportState) {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Transport state changed: $transportState (userDisconnected=$_userDisconnected)',
      );

      switch (transportState) {
        case DeviceConnectionState.connected:
          // BLE connected but may still need protocol config
          if (state.state != DevicePairingState.connected &&
              state.state != DevicePairingState.configuring) {
            AppLogging.connection(
              '🔌 DeviceConnectionNotifier: BLE connected, state=configuring',
            );
            state = state.copyWith(state: DevicePairingState.configuring);
            // BLE auto-reconnected - need to start protocol
            _initializeProtocolAfterAutoReconnect();
          }
          break;
        case DeviceConnectionState.disconnected:
          if (_userDisconnected) {
            AppLogging.connection(
              '🔌 DeviceConnectionNotifier: Disconnected (user-initiated), NOT triggering reconnect',
            );
          } else {
            AppLogging.connection(
              '🔌 DeviceConnectionNotifier: Disconnected (unexpected), handling...',
            );
          }
          _handleDisconnect(
            _userDisconnected
                ? DisconnectReason.userDisconnected
                : DisconnectReason.unexpectedDisconnect,
          );
          break;
        case DeviceConnectionState.connecting:
          AppLogging.connection(
            '🔌 DeviceConnectionNotifier: state=connecting',
          );
          state = state.copyWith(state: DevicePairingState.connecting);
          break;
        case DeviceConnectionState.disconnecting:
          AppLogging.connection(
            '🔌 DeviceConnectionNotifier: state=disconnecting (transitional)',
          );
          // Transitional state, ignore
          break;
        case DeviceConnectionState.error:
          AppLogging.connection('🔌 DeviceConnectionNotifier: state=error');
          state = state.copyWith(
            state: DevicePairingState.error,
            reason: DisconnectReason.connectionFailed,
          );
          break;
      }
    });
  }

  /// Initialize protocol after BLE auto-reconnected (without going through _connectToDevice)
  Future<void> _initializeProtocolAfterAutoReconnect() async {
    AppLogging.connection(
      '🔌 _initializeProtocolAfterAutoReconnect: BLE auto-reconnected, starting protocol...',
    );

    try {
      final transport = ref.read(transportProvider);
      final protocol = ref.read(protocolServiceProvider);

      // Get device info from transport or use stored info
      final deviceName = state.device?.name ?? 'Unknown';
      protocol.setDeviceName(deviceName);
      protocol.setBleModelNumber(transport.bleModelNumber);
      protocol.setBleManufacturerName(transport.bleManufacturerName);

      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Starting protocol for $deviceName...',
      );
      await protocol.start();

      // Verify we got configuration
      if (protocol.myNodeNum == null) {
        AppLogging.connection(
          '🔌 _initializeProtocolAfterAutoReconnect: Protocol started but no myNodeNum',
        );
        return;
      }

      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Protocol ready! myNodeNum: ${protocol.myNodeNum}',
      );

      // Update state to connected
      state = state.copyWith(
        state: DevicePairingState.connected,
        lastConnectedAt: DateTime.now(),
        myNodeNum: protocol.myNodeNum,
        reason: DisconnectReason.none,
        reconnectAttempts: 0,
      );

      // Update legacy providers
      if (state.device != null) {
        ref.read(connectedDeviceProvider.notifier).setState(state.device);
      }
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.success);
    } catch (e) {
      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Error: $e',
      );
    }
  }

  /// Start background connection attempt to known device
  Future<void> startBackgroundConnection() async {
    // Check if user manually disconnected - don't auto-reconnect
    if (_userDisconnected) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - user manually disconnected',
      );
      return;
    }

    // Guard against concurrent scans - only one background scan at a time
    if (_backgroundScanInProgress) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - scan already in progress',
      );
      return;
    }

    final settings = await ref.read(settingsServiceProvider.future);
    final lastDeviceId = settings.lastDeviceId;
    final lastDeviceName = settings.lastDeviceName;

    if (lastDeviceId == null) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: No device to reconnect to',
      );
      return;
    }

    // Check Bluetooth state first
    final btState = await FlutterBluePlus.adapterState.first;
    if (btState != BluetoothAdapterState.on) {
      AppLogging.connection('🔌 startBackgroundConnection: Bluetooth is off');
      state = state.copyWith(
        state: DevicePairingState.error,
        reason: DisconnectReason.bluetoothDisabled,
        errorMessage: 'Bluetooth is disabled',
      );
      return;
    }

    // Mark scan as in progress
    _backgroundScanInProgress = true;

    AppLogging.connection(
      '🔌 startBackgroundConnection: Starting scan for: $lastDeviceId',
    );
    state = state.copyWith(state: DevicePairingState.scanning);

    // Also update legacy auto-reconnect state for compatibility
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.scanning);

    final transport = ref.read(transportProvider);
    DeviceInfo? foundDevice;

    try {
      // Aggressive BLE cleanup - device may have just been released by another app
      AppLogging.connection(
        '🔌 startBackgroundConnection: Aggressive BLE cleanup starting...',
      );

      // 1. Stop any existing scan
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore
      }

      // 2. Check system devices for stale connections to our target
      try {
        final systemDevices = await FlutterBluePlus.systemDevices([]);
        for (final device in systemDevices) {
          if (device.remoteId.toString() == lastDeviceId) {
            AppLogging.connection(
              '🔌 startBackgroundConnection: Found target in system devices, cleaning up...',
            );
            try {
              if (Platform.isAndroid) {
                await device.clearGattCache();
              }
              await device.disconnect();
            } catch (e) {
              // Ignore cleanup errors
            }
          }
        }
      } catch (e) {
        // Ignore
      }

      // 3. Android: Also check bonded devices
      if (Platform.isAndroid) {
        try {
          final bondedDevices = await FlutterBluePlus.bondedDevices;
          for (final device in bondedDevices) {
            if (device.remoteId.toString() == lastDeviceId) {
              AppLogging.connection(
                '🔌 startBackgroundConnection: Found target in bonded devices, cleaning up...',
              );
              try {
                await device.clearGattCache();
                if (device.isConnected) {
                  await device.disconnect();
                }
              } catch (e) {
                // Ignore
              }
            }
          }
        } catch (e) {
          // Ignore
        }
      }

      // 4. Wait for BLE to reset (longer on Android due to GATT cache)
      final resetDelay = Platform.isAndroid ? 1500 : 1000;
      AppLogging.connection(
        '🔌 startBackgroundConnection: Waiting ${resetDelay}ms for BLE reset...',
      );
      await Future.delayed(Duration(milliseconds: resetDelay));

      // Scan for 5 seconds
      AppLogging.connection(
        '🔌 startBackgroundConnection: Starting 5s scan...',
      );
      await for (final device in transport.scan(
        timeout: const Duration(seconds: 5),
      )) {
        // Check again if user disconnected during scan
        if (_userDisconnected) {
          AppLogging.connection(
            '🔌 startBackgroundConnection: User disconnected during scan, aborting',
          );
          return;
        }
        AppLogging.connection(
          '🔌 startBackgroundConnection: Found device ${device.id} (looking for $lastDeviceId)',
        );
        if (device.id == lastDeviceId) {
          foundDevice = device;
          AppLogging.connection(
            '🔌 startBackgroundConnection: Target device found!',
          );
          break;
        }
      }

      if (foundDevice == null) {
        AppLogging.connection(
          '🔌 startBackgroundConnection: Device not found in scan',
        );
        state = state.copyWith(
          state: DevicePairingState.disconnected,
          reason: DisconnectReason.deviceNotFound,
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.failed);
        return;
      }

      // Use stored name if scan didn't provide one
      if (foundDevice.name.isEmpty || foundDevice.name == 'Unknown') {
        foundDevice = DeviceInfo(
          id: foundDevice.id,
          name: lastDeviceName ?? foundDevice.name,
          type: foundDevice.type,
          rssi: foundDevice.rssi,
        );
      }

      // Final check before connecting
      if (_userDisconnected) {
        AppLogging.connection(
          '🔌 startBackgroundConnection: User disconnected before connect, aborting',
        );
        return;
      }

      await _connectToDevice(foundDevice);
    } catch (e) {
      AppLogging.connection('🔌 startBackgroundConnection: Error: $e');
      state = state.copyWith(
        state: DevicePairingState.disconnected,
        reason: DisconnectReason.connectionFailed,
        errorMessage: e.toString(),
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.failed);
    } finally {
      _backgroundScanInProgress = false;
    }
  }

  /// Connect to a specific device
  Future<void> connectToDevice(DeviceInfo device) async {
    await _connectToDevice(device);
  }

  Future<void> _connectToDevice(DeviceInfo device) async {
    AppLogging.connection('Connecting to: ${device.name} (${device.id})');

    state = state.copyWith(
      state: DevicePairingState.connecting,
      device: device,
    );
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.connecting);

    final transport = ref.read(transportProvider);

    try {
      await transport.connect(device);

      if (transport.state != DeviceConnectionState.connected) {
        throw Exception('BLE connection failed');
      }

      state = state.copyWith(state: DevicePairingState.configuring);

      // Clear previous device data
      await clearDeviceDataBeforeConnectRef(ref);

      // Start protocol service
      final protocol = ref.read(protocolServiceProvider);
      protocol.setDeviceName(device.name);
      protocol.setBleModelNumber(transport.bleModelNumber);
      protocol.setBleManufacturerName(transport.bleManufacturerName);

      AppLogging.connection('Starting protocol...');
      await protocol.start();

      // Verify we got configuration
      if (protocol.myNodeNum == null) {
        AppLogging.connection(
          'Protocol started but no myNodeNum - auth failed',
        );
        await transport.disconnect();
        throw Exception('Authentication failed');
      }

      AppLogging.connection('Connected! myNodeNum: ${protocol.myNodeNum}');

      // Start location updates
      final locationService = ref.read(locationServiceProvider);
      await locationService.startLocationUpdates();

      // Update state
      state = state.copyWith(
        state: DevicePairingState.connected,
        device: device,
        lastConnectedAt: DateTime.now(),
        myNodeNum: protocol.myNodeNum,
        reason: DisconnectReason.none,
        reconnectAttempts: 0,
      );

      // Update legacy providers for compatibility
      ref.read(connectedDeviceProvider.notifier).setState(device);
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.success);

      // Mark region as configured (reconnecting to known device)
      final settings = await ref.read(settingsServiceProvider.future);
      if (!settings.regionConfigured) {
        await settings.setRegionConfigured(true);
      }
    } catch (e) {
      AppLogging.connection('Connection failed: $e');

      final reason = e.toString().contains('Authentication')
          ? DisconnectReason.authFailed
          : e.toString().contains('timeout')
          ? DisconnectReason.configTimeout
          : DisconnectReason.connectionFailed;

      state = state.copyWith(
        state: DevicePairingState.error,
        reason: reason,
        errorMessage: e.toString(),
        reconnectAttempts: state.reconnectAttempts + 1,
      );

      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.failed);

      rethrow;
    }
  }

  /// Handle disconnection
  void _handleDisconnect(DisconnectReason reason) {
    AppLogging.connection(
      '🔌 _handleDisconnect: reason=$reason, currentState=${state.state}',
    );

    if (state.state == DevicePairingState.neverPaired) {
      AppLogging.connection('🔌 _handleDisconnect: Never paired, ignoring');
      return; // No device to reconnect to
    }

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: reason,
    );

    ref.read(connectedDeviceProvider.notifier).setState(null);

    // If user disconnected, don't trigger any auto-reconnect behavior
    if (reason == DisconnectReason.userDisconnected) {
      AppLogging.connection(
        '🔌 _handleDisconnect: User-initiated disconnect, no auto-reconnect',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
    }
  }

  /// Manually disconnect - prevents auto-reconnect
  Future<void> disconnect() async {
    AppLogging.connection('🔌 disconnect(): Starting manual disconnect...');

    // Mark that user intentionally disconnected - prevents any auto-reconnect
    _userDisconnected = true;
    _backgroundScanInProgress = false; // Clear scan guard to allow future scans
    AppLogging.connection('🔌 disconnect(): Set _userDisconnected=true');

    // Also sync with the global userDisconnectedProvider
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(true);

    _scanTimer?.cancel();

    // Stop any active scans before disconnecting
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore
    }

    final transport = ref.read(transportProvider);
    AppLogging.connection('🔌 disconnect(): Calling transport.disconnect()...');
    await transport.disconnect();
    AppLogging.connection('🔌 disconnect(): Transport disconnected');

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.userDisconnected,
    );

    ref.read(connectedDeviceProvider.notifier).setState(null);
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);

    AppLogging.connection('🔌 disconnect(): Manual disconnect complete');
  }

  /// Clear the user disconnected flag - call when user explicitly wants to reconnect
  void clearUserDisconnected() {
    AppLogging.connection(
      '🔌 clearUserDisconnected(): Clearing flag to allow reconnect',
    );
    _userDisconnected = false;

    // Also sync with the global userDisconnectedProvider
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
  }

  /// Retry connection after error
  Future<void> retryConnection() async {
    if (state.state == DevicePairingState.neverPaired) return;

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.none,
    );

    await startBackgroundConnection();
  }

  /// Mark as paired after first successful connection from scanner
  bool _reconciledThisSession = false;

  void markAsPaired(DeviceInfo device, int? myNodeNum) {
    state = DeviceConnectionState2(
      state: DevicePairingState.connected,
      device: device,
      lastConnectedAt: DateTime.now(),
      myNodeNum: myNodeNum,
    );

    // Run one-shot reconciliation for this node on connect
    if (!_reconciledThisSession && myNodeNum != null) {
      _reconciledThisSession = true;
      AppLogging.connection('🔌 Running reconnect canary for node $myNodeNum');
      // Fire-and-forget reconcile
      Future.microtask(() async {
        try {
          await ref
              .read(messagesProvider.notifier)
              .reconcileFromStorageForNode(myNodeNum);
        } catch (e) {
          AppLogging.connection('🔌 Reconnect canary error: $e');
        }
      });
    }
  }
}

final deviceConnectionProvider =
    NotifierProvider<DeviceConnectionNotifier, DeviceConnectionState2>(
      DeviceConnectionNotifier.new,
    );

// =============================================================================
// FEATURE REQUIREMENT SYSTEM
// =============================================================================

/// Feature requirements for gating
enum FeatureRequirement {
  /// No requirements - always available (settings, about, account)
  none,

  /// Requires network (Firebase) - social features
  network,

  /// Can work with cached data when disconnected
  cached,

  /// Requires active device connection
  deviceConnection,
}

/// Feature identifiers for the registry
enum FeatureId {
  // Tier 0 - No requirements (always available)
  settings,
  about,
  account,
  profileView,
  deviceShop,
  subscription,
  themeSettings,

  // Tier 1 - Network only (social/cloud features)
  socialFeed,
  stories,
  followers,
  cloudSync,
  socialPost,
  socialComment,
  socialLike,
  profileEdit,
  worldMap,

  // Tier 2 - Cached data (works offline with previous data)
  messageHistory,
  nodeList,
  channelList,
  mapView,
  timeline,
  presence,

  // Tier 3 - Device connection required (mesh operations)
  sendMessage,
  deviceConfig,
  traceroute,
  nodeActions,
  channelConfig,
  positionShare,
  requestPosition,
  sendBell,
  requestTelemetry,
  removeNode,
  rebootDevice,
  factoryReset,
  setOwner,
  regionSetup,
  rangeTest,
  storeForward,
}

/// Feature registry - maps features to their requirements
const Map<FeatureId, FeatureRequirement> _featureRegistry = {
  // Tier 0 - Always available
  FeatureId.settings: FeatureRequirement.none,
  FeatureId.about: FeatureRequirement.none,
  FeatureId.account: FeatureRequirement.none,
  FeatureId.profileView: FeatureRequirement.none,
  FeatureId.deviceShop: FeatureRequirement.none,
  FeatureId.subscription: FeatureRequirement.none,
  FeatureId.themeSettings: FeatureRequirement.none,

  // Tier 1 - Network required
  FeatureId.socialFeed: FeatureRequirement.network,
  FeatureId.stories: FeatureRequirement.network,
  FeatureId.followers: FeatureRequirement.network,
  FeatureId.cloudSync: FeatureRequirement.network,
  FeatureId.socialPost: FeatureRequirement.network,
  FeatureId.socialComment: FeatureRequirement.network,
  FeatureId.socialLike: FeatureRequirement.network,
  FeatureId.profileEdit: FeatureRequirement.network,
  FeatureId.worldMap: FeatureRequirement.network,

  // Tier 2 - Cached data
  FeatureId.messageHistory: FeatureRequirement.cached,
  FeatureId.nodeList: FeatureRequirement.cached,
  FeatureId.channelList: FeatureRequirement.cached,
  FeatureId.mapView: FeatureRequirement.cached,
  FeatureId.timeline: FeatureRequirement.cached,
  FeatureId.presence: FeatureRequirement.cached,

  // Tier 3 - Device connection required
  FeatureId.sendMessage: FeatureRequirement.deviceConnection,
  FeatureId.deviceConfig: FeatureRequirement.deviceConnection,
  FeatureId.traceroute: FeatureRequirement.deviceConnection,
  FeatureId.nodeActions: FeatureRequirement.deviceConnection,
  FeatureId.channelConfig: FeatureRequirement.deviceConnection,
  FeatureId.positionShare: FeatureRequirement.deviceConnection,
  FeatureId.requestPosition: FeatureRequirement.deviceConnection,
  FeatureId.sendBell: FeatureRequirement.deviceConnection,
  FeatureId.requestTelemetry: FeatureRequirement.deviceConnection,
  FeatureId.removeNode: FeatureRequirement.deviceConnection,
  FeatureId.rebootDevice: FeatureRequirement.deviceConnection,
  FeatureId.factoryReset: FeatureRequirement.deviceConnection,
  FeatureId.setOwner: FeatureRequirement.deviceConnection,
  FeatureId.regionSetup: FeatureRequirement.deviceConnection,
  FeatureId.rangeTest: FeatureRequirement.deviceConnection,
  FeatureId.storeForward: FeatureRequirement.deviceConnection,
};

/// Get the requirement for a feature
FeatureRequirement getFeatureRequirement(FeatureId feature) {
  return _featureRegistry[feature] ?? FeatureRequirement.none;
}

/// Check if a feature requires device connection
bool featureRequiresDevice(FeatureId feature) {
  return getFeatureRequirement(feature) == FeatureRequirement.deviceConnection;
}

/// Feature availability state
class FeatureAvailability {
  final Map<FeatureId, bool> availability;
  final bool isDeviceConnected;
  final bool isNetworkAvailable;

  const FeatureAvailability({
    required this.availability,
    required this.isDeviceConnected,
    required this.isNetworkAvailable,
  });

  bool isAvailable(FeatureId feature) => availability[feature] ?? false;

  String? getUnavailabilityReason(FeatureId feature) {
    if (isAvailable(feature)) return null;

    final requirement = _featureRegistry[feature] ?? FeatureRequirement.none;
    switch (requirement) {
      case FeatureRequirement.none:
        return null;
      case FeatureRequirement.network:
        return 'Network connection required';
      case FeatureRequirement.cached:
        return null; // Cached features always show something
      case FeatureRequirement.deviceConnection:
        return 'Connect device to use this feature';
    }
  }
}

/// Computes feature availability based on connection states
class FeatureAvailabilityNotifier extends Notifier<FeatureAvailability> {
  @override
  FeatureAvailability build() {
    final deviceState = ref.watch(deviceConnectionProvider);
    // For now, assume network is available (could add network connectivity provider)
    const isNetworkAvailable = true;

    final availability = <FeatureId, bool>{};

    for (final entry in _featureRegistry.entries) {
      final feature = entry.key;
      final requirement = entry.value;

      bool available;
      switch (requirement) {
        case FeatureRequirement.none:
          available = true;
          break;
        case FeatureRequirement.network:
          available = isNetworkAvailable;
          break;
        case FeatureRequirement.cached:
          available = true; // Always show cached, but may be stale
          break;
        case FeatureRequirement.deviceConnection:
          available = deviceState.isConnected;
          break;
      }
      availability[feature] = available;
    }

    return FeatureAvailability(
      availability: availability,
      isDeviceConnected: deviceState.isConnected,
      isNetworkAvailable: isNetworkAvailable,
    );
  }
}

final featureAvailabilityProvider =
    NotifierProvider<FeatureAvailabilityNotifier, FeatureAvailability>(
      FeatureAvailabilityNotifier.new,
    );

// =============================================================================
// CONVENIENCE PROVIDERS
// =============================================================================

/// Simple boolean for checking if device is connected
final isDeviceConnectedProvider = Provider<bool>((ref) {
  return ref.watch(deviceConnectionProvider).isConnected;
});

/// Check if a specific feature is available
final featureAvailableProvider = Provider.family<bool, FeatureId>((
  ref,
  feature,
) {
  return ref.watch(featureAvailabilityProvider).isAvailable(feature);
});

/// Get unavailability reason for a feature
final featureUnavailabilityReasonProvider = Provider.family<String?, FeatureId>(
  (ref, feature) {
    return ref
        .watch(featureAvailabilityProvider)
        .getUnavailabilityReason(feature);
  },
);
