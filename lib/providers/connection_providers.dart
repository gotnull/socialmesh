// SPDX-License-Identifier: GPL-3.0-or-later
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

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/transport.dart';
import '../services/meshcore/connection_coordinator.dart' show ConnectionResult;
import 'app_providers.dart';
import 'connectivity_providers.dart';
import 'meshcore_providers.dart';

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

  /// Saved device pairing is permanently invalid (device reset/forget)
  pairedDeviceInvalidated,
}

/// Reasons the saved pairing was invalidated.
enum PairingInvalidationReason {
  /// Device reset or pairing info removed on the hardware.
  peerReset('peer_removed_pairing'),

  /// Device could not be found after repeated scans.
  missingDevice('device_not_found');

  final String logValue;
  const PairingInvalidationReason(this.logValue);
}

/// Detect whether the given exception signals the device removed pairing state.
/// This happens when:
/// - iOS: Error code 14 or "Peer removed pairing information" message
/// - Android: GATT status 5 (GATT_INSUFFICIENT_AUTHENTICATION) during connect/MTU,
///   or "device is disconnected" during requestMtu which indicates bond mismatch
bool isPairingInvalidationError(Object error) {
  if (error is FlutterBluePlusException) {
    // iOS: Error code 14 means peer removed pairing
    final isApplePeerReset =
        error.platform == ErrorPlatform.apple && error.code == 14;
    final hasPeerResetMessage = (error.description ?? '').contains(
      'Peer removed pairing information',
    );
    if (isApplePeerReset || hasPeerResetMessage) {
      return true;
    }

    // Android: Error code 5 is GATT_INSUFFICIENT_AUTHENTICATION (bond mismatch)
    // This happens when device expects bonded connection but phone doesn't have bond
    final isAndroidAuthError =
        error.platform == ErrorPlatform.android && error.code == 5;
    if (isAndroidAuthError) {
      return true;
    }
  }

  final message = error.toString();

  // iOS specific message
  if (message.contains('Peer removed pairing information')) {
    return true;
  }

  // Android: "device is disconnected" during requestMtu usually means bond mismatch
  // The device was connected but immediately disconnected during MTU negotiation
  if (message.contains('requestMtu') &&
      message.contains('device is disconnected')) {
    return true;
  }

  // Our custom message when device disconnects during connection setup
  // This typically happens on Android when there's a bond mismatch
  if (message.contains('Device disconnected during connection setup')) {
    return true;
  }

  return false;
}

/// Extract the apple-specific error code when available.
int? pairingInvalidationAppleCode(Object error) {
  if (error is FlutterBluePlusException &&
      error.platform == ErrorPlatform.apple) {
    return error.code;
  }
  return null;
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
  final int connectionSessionId;

  const DeviceConnectionState2({
    required this.state,
    this.reason = DisconnectReason.none,
    this.errorMessage,
    this.device,
    this.lastConnectedAt,
    this.reconnectAttempts = 0,
    this.myNodeNum,
    this.connectionSessionId = 0,
  });

  bool get isConnected => state == DevicePairingState.connected;
  bool get isConnecting =>
      state == DevicePairingState.connecting ||
      state == DevicePairingState.configuring;
  bool get isScanning => state == DevicePairingState.scanning;
  bool get hasError => state == DevicePairingState.error;
  bool get isTerminalInvalidated =>
      state == DevicePairingState.pairedDeviceInvalidated;
  bool get wasPreviouslyPaired => state != DevicePairingState.neverPaired;

  DeviceConnectionState2 copyWith({
    DevicePairingState? state,
    DisconnectReason? reason,
    String? errorMessage,
    DeviceInfo? device,
    DateTime? lastConnectedAt,
    int? reconnectAttempts,
    int? myNodeNum,
    int? connectionSessionId,
  }) {
    return DeviceConnectionState2(
      state: state ?? this.state,
      reason: reason ?? this.reason,
      errorMessage: errorMessage ?? this.errorMessage,
      device: device ?? this.device,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      myNodeNum: myNodeNum ?? this.myNodeNum,
      connectionSessionId: connectionSessionId ?? this.connectionSessionId,
    );
  }

  @override
  String toString() =>
      'DeviceConnectionState2(state: $state, reason: $reason, device: ${device?.name}, session: $connectionSessionId)';
}

// =============================================================================
// DEVICE CONNECTION NOTIFIER
// =============================================================================

/// Manages device connection lifecycle independently from app initialization.
/// Starts connection asynchronously in background after app is ready.
class DeviceConnectionNotifier extends Notifier<DeviceConnectionState2> {
  StreamSubscription<DeviceConnectionState>? _connectionSubscription;
  Timer? _scanTimer;
  Timer? _retryTimer; // Timer for retry attempts
  bool _isInitialized = false;
  bool _userDisconnected = false; // Track if user manually disconnected
  bool _backgroundScanInProgress = false; // Guard against concurrent scans
  int _missingDeviceAttempts = 0;
  DateTime? _firstMissingAttemptAt;
  static const int _maxInvalidationAttempts = 3;
  static const Duration _invalidationWindow = Duration(seconds: 120);
  int _connectionSessionId = 0;
  int _reconnectAttempt = 0; // Current retry attempt (0-based)
  int _maxReconnectAttempts = 3; // Max retries for normal reconnect
  static const int _maxReconnectAttemptsRegion =
      6; // Max retries during region apply (device reboot)

  int _nextConnectionSessionId() {
    _connectionSessionId += 1;
    return _connectionSessionId;
  }

  @override
  DeviceConnectionState2 build() {
    // Clean up subscriptions when provider is disposed
    ref.onDispose(() {
      AppLogging.connection('🔌 DeviceConnectionNotifier: Disposing...');
      _connectionSubscription?.cancel();
      _scanTimer?.cancel();
      _retryTimer?.cancel();
    });

    return const DeviceConnectionState2(state: DevicePairingState.neverPaired);
  }

  /// Test-only method to set state directly.
  /// Do not use in production code.
  @visibleForTesting
  void setTestState(DeviceConnectionState2 newState) {
    state = newState;
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

    // Set up connectivity listener for auto-retry when internet comes back online
    // This helps reconnect after region change (device reboot) when connectivity is restored
    _setupConnectivityListener();

    // Check if we have a previously paired device
    final settings = await ref.read(settingsServiceProvider.future);
    final lastDeviceId = settings.lastDeviceId;

    if (lastDeviceId == null) {
      // Never paired before
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: No previous device, state=neverPaired',
      );
      state = DeviceConnectionState2(
        state: DevicePairingState.neverPaired,
        connectionSessionId: _connectionSessionId,
      );
      return;
    }

    // Had a device before - mark as disconnected and start background connection
    AppLogging.connection(
      '🔌 DeviceConnectionNotifier: Previous device found: $lastDeviceId',
    );
    state = DeviceConnectionState2(
      state: DevicePairingState.disconnected,
      connectionSessionId: _connectionSessionId,
    );

    // Listen to transport connection state changes
    // BUT only for Meshtastic protocol - MeshCore uses its own transport
    final lastProtocol = settings.lastDeviceProtocol;
    if (lastProtocol != 'meshcore') {
      _setupConnectionListener();
    } else {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: MeshCore device - skipping Meshtastic listener',
      );
    }

    // Start background connection attempt if auto-reconnect enabled
    if (settings.autoReconnect) {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Auto-reconnect enabled, scheduling connection...',
      );
      // Small delay to let UI render first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_userDisconnected) {
          // Route to appropriate protocol's connect method
          if (lastProtocol == 'meshcore') {
            _startMeshCoreBackgroundConnection(lastDeviceId, settings);
          } else {
            startBackgroundConnection();
          }
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

  /// Set up listener for connectivity changes to auto-retry device connection
  /// when internet comes back online after region change (device reboot).
  /// This ensures the "Device not found - Retry" banner automatically retries
  /// when connectivity is restored.
  void _setupConnectivityListener() {
    ref.listen<ConnectivityStatus>(connectivityStatusProvider, (
      previous,
      next,
    ) {
      // Only act when connectivity changes from offline to online
      final wasOffline = previous == null || !previous.online;
      final isNowOnline = next.online;

      if (!wasOffline || !isNowOnline) return;

      AppLogging.connection(
        '🔌 Connectivity restored: checking if reconnect needed...',
      );

      // Skip if user manually disconnected
      if (_userDisconnected) {
        AppLogging.connection(
          '🔌 Connectivity restored but user disconnected - skipping auto-reconnect',
        );
        return;
      }

      // Check if we need to reconnect
      // Note: We avoid reading regionConfigProvider here to prevent circular dependency.
      // The region apply reconnect is handled via autoReconnectState.
      final autoReconnectState = ref.read(autoReconnectStateProvider);
      final isFailed = autoReconnectState == AutoReconnectState.failed;
      final isScanning = autoReconnectState == AutoReconnectState.scanning;
      final isConnecting = autoReconnectState == AutoReconnectState.connecting;
      final isDisconnected = state.state == DevicePairingState.disconnected;

      // Trigger reconnect if:
      // 1. Previous reconnect failed (e.g., device not found after region reboot)
      // 2. Currently scanning/connecting/retrying (connectivity came back during retry)
      // 3. We're disconnected but not by user
      if (isFailed || isScanning || isConnecting || isDisconnected) {
        AppLogging.connection(
          '🔌 Connectivity restored: triggering reconnect '
          '(failed=$isFailed, scanning=$isScanning, connecting=$isConnecting, disconnected=$isDisconnected)',
        );
        // Reset retry counter to give fresh attempts after connectivity restored
        _reconnectAttempt = 0;
        _retryTimer?.cancel();
        // Small delay to ensure network stack is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (ref.mounted && !_userDisconnected) {
            startBackgroundConnection();
          }
        });
      }
    });
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
    // Check if we should handle this reconnection
    // We handle it in these cases:
    // 1. autoReconnectState == connecting (our background reconnect initiated it)
    final autoReconnectState = ref.read(autoReconnectStateProvider);

    // Note: We don't check regionConfigProvider here to avoid circular dependency
    // during initialization. If region apply is in progress, the auto-reconnect
    // state will be set to 'connecting' which we check above.
    final shouldHandleReconnect =
        autoReconnectState == AutoReconnectState.connecting;

    if (!shouldHandleReconnect) {
      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: SKIPPING - '
        'autoReconnect=$autoReconnectState, '
        'scanner is handling connection',
      );
      return;
    }

    AppLogging.connection(
      '🔌 _initializeProtocolAfterAutoReconnect: BLE auto-reconnected, starting protocol... '
      '(autoReconnect=$autoReconnectState)',
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
      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Marking DevicePairingState.connected',
      );
      state = state.copyWith(
        state: DevicePairingState.connected,
        lastConnectedAt: DateTime.now(),
        myNodeNum: protocol.myNodeNum,
        reason: DisconnectReason.none,
        reconnectAttempts: 0,
        connectionSessionId: _nextConnectionSessionId(),
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

    // CRITICAL: Don't disrupt an already-connected device.
    // Without this guard, the aggressive BLE cleanup below disconnects
    // the active connection (finds it in system devices and calls
    // device.disconnect()), creating a cascade of disconnect→reconnect
    // cycles that can leave the app in a broken state.
    // This commonly happens when _initializeBackgroundServices() fires
    // multiple times (e.g. onboarding + terms acceptance both call
    // initialize()) while the scanner has already established a live
    // connection.
    if (state.isConnected) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - device already connected',
      );
      return;
    }

    // Also skip if we're in the middle of configuring (protocol handshake)
    if (state.state == DevicePairingState.configuring) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - connection configuring',
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

    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: Saved device invalidated, skipping reconnect',
      );
      return;
    }

    final settings = await ref.read(settingsServiceProvider.future);

    // Check if auto-reconnect is enabled in settings
    if (!settings.autoReconnect) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - auto-reconnect disabled in settings',
      );
      return;
    }

    final lastDeviceId = settings.lastDeviceId;
    final lastDeviceName = settings.lastDeviceName;
    final lastProtocol = settings.lastDeviceProtocol;

    if (lastDeviceId == null) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: No device to reconnect to',
      );
      return;
    }

    // MeshCore auto-reconnect uses _startMeshCoreBackgroundConnection instead
    if (lastProtocol == 'meshcore') {
      AppLogging.connection(
        '🔌 startBackgroundConnection: MeshCore device - use _startMeshCoreBackgroundConnection',
      );
      _backgroundScanInProgress = false;
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
          '🔌 startBackgroundConnection: Device not found in scan (attempt ${_reconnectAttempt + 1})',
        );

        // Check if we're in region apply flow - use more aggressive retry
        final regionState = ref.read(regionConfigProvider);
        final isRegionApplying =
            regionState.applyStatus == RegionApplyStatus.applying;

        // Set max attempts based on context
        _maxReconnectAttempts = isRegionApplying
            ? _maxReconnectAttemptsRegion // 6 attempts (60s) for region reboot
            : 3; // 3 attempts (30s) for normal reconnect

        // Check if we should retry
        if (_reconnectAttempt < _maxReconnectAttempts) {
          _reconnectAttempt++;
          final retryDelay = isRegionApplying
              ? 10000
              : 10000; // 10s between retries
          AppLogging.connection(
            '🔌 startBackgroundConnection: Will retry in ${retryDelay}ms '
            '(attempt $_reconnectAttempt/$_maxReconnectAttempts, regionApplying=$isRegionApplying)',
          );

          // Schedule retry
          _retryTimer?.cancel();
          _retryTimer = Timer(Duration(milliseconds: retryDelay), () {
            if (ref.mounted && !_userDisconnected) {
              AppLogging.connection(
                '🔌 startBackgroundConnection: Retry timer fired, attempt $_reconnectAttempt',
              );
              startBackgroundConnection();
            }
          });

          // Keep state as scanning during retry
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.scanning);
          return;
        }

        // Max retries exceeded
        AppLogging.connection(
          '🔌 startBackgroundConnection: Max retries exceeded ($_maxReconnectAttempts attempts)',
        );
        _reconnectAttempt = 0; // Reset for next disconnect event

        final invalidated = await reportMissingSavedDevice();
        if (!invalidated) {
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.failed);
        }
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

      // Reset retry counter on successful device find
      _reconnectAttempt = 0;
      _retryTimer?.cancel();

      await _connectToDevice(foundDevice);
    } catch (e) {
      if (state.state == DevicePairingState.pairedDeviceInvalidated) {
        return;
      }

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

  /// Start background connection for MeshCore device.
  ///
  /// Uses the same direct-connect-by-id strategy as resume reconnect.
  /// On iOS, scanning with service UUID filters can miss MeshCore devices,
  /// so we attempt direct connect first, then fall back to unfiltered scan.
  Future<void> _startMeshCoreBackgroundConnection(
    String deviceId,
    dynamic settings,
  ) async {
    AppLogging.connection(
      '🔌 MeshCore background connect: Starting for device: $deviceId',
    );

    // Guard against concurrent connection attempts
    if (_backgroundScanInProgress) {
      AppLogging.connection(
        '🔌 MeshCore background connect: BLOCKED - connection already in progress',
      );
      return;
    }

    // Check if already connected
    final coordinator = ref.read(connectionCoordinatorProvider);
    if (coordinator.isConnected) {
      AppLogging.connection(
        '🔌 MeshCore background connect: Already connected, skipping',
      );
      return;
    }

    if (coordinator.isConnecting) {
      AppLogging.connection(
        '🔌 MeshCore background connect: Connection already in progress, skipping',
      );
      return;
    }

    // Check Bluetooth state first
    final btState = await FlutterBluePlus.adapterState.first;
    if (btState != BluetoothAdapterState.on) {
      AppLogging.connection('🔌 MeshCore background connect: Bluetooth is off');
      state = state.copyWith(
        state: DevicePairingState.error,
        reason: DisconnectReason.bluetoothDisabled,
        errorMessage: 'Bluetooth is disabled',
      );
      return;
    }

    _backgroundScanInProgress = true;

    try {
      // Update state to scanning/connecting
      state = state.copyWith(state: DevicePairingState.scanning);
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);

      // Strategy 1: Direct connect by device identifier
      AppLogging.connection(
        '🔌 MeshCore background connect: Strategy 1 - direct connect by ID',
      );

      DeviceInfo foundDevice;

      // Check system devices first (iOS may know about the peripheral)
      try {
        final systemDevices = await FlutterBluePlus.systemDevices([]);
        AppLogging.connection(
          '🔌 MeshCore background connect: Found ${systemDevices.length} system devices',
        );

        DeviceInfo? fromSystem;
        for (final device in systemDevices) {
          if (device.remoteId.toString() == deviceId) {
            AppLogging.connection(
              '🔌 MeshCore background connect: Target found in system devices',
            );
            fromSystem = DeviceInfo(
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

        foundDevice =
            fromSystem ??
            DeviceInfo(
              id: deviceId,
              name: settings.lastDeviceName ?? 'MeshCore Device',
              type: TransportType.ble,
              address: deviceId,
            );
      } catch (e) {
        AppLogging.connection(
          '🔌 MeshCore background connect: System devices check failed: $e',
        );
        foundDevice = DeviceInfo(
          id: deviceId,
          name: settings.lastDeviceName ?? 'MeshCore Device',
          type: TransportType.ble,
          address: deviceId,
        );
      }

      // Try direct connection
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);
      state = state.copyWith(state: DevicePairingState.connecting);

      var result = await coordinator.connect(device: foundDevice);

      if (result.success) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Direct connect succeeded!',
        );
        await _finalizeMeshCoreConnect(foundDevice, result, settings);
        return;
      }

      // Strategy 2: Fall back to unfiltered scan
      AppLogging.connection(
        '🔌 MeshCore background connect: Direct connect failed (${result.errorMessage}), '
        'trying Strategy 2 - unfiltered scan',
      );

      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);
      state = state.copyWith(state: DevicePairingState.scanning);

      final transport = ref.read(transportProvider);
      DeviceInfo? scannedDevice;

      await for (final device in transport.scan(
        timeout: const Duration(seconds: 10),
        scanAll: true, // Don't filter by service UUID
      )) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Scan found: ${device.id}',
        );
        if (device.id == deviceId) {
          scannedDevice = device;
          break;
        }
      }

      if (scannedDevice == null) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Device not found in scan',
        );
        state = state.copyWith(
          state: DevicePairingState.disconnected,
          reason: DisconnectReason.deviceNotFound,
          errorMessage: 'Device not found',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.failed);
        return;
      }

      // Try connect with scanned device
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);
      state = state.copyWith(state: DevicePairingState.connecting);

      result = await coordinator.connect(device: scannedDevice);

      if (!result.success) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Scanned device connect failed: ${result.errorMessage}',
        );
        state = state.copyWith(
          state: DevicePairingState.disconnected,
          reason: DisconnectReason.connectionFailed,
          errorMessage: result.errorMessage ?? 'Connection failed',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.failed);
        return;
      }

      AppLogging.connection(
        '🔌 MeshCore background connect: Scanned device connect succeeded!',
      );
      await _finalizeMeshCoreConnect(scannedDevice, result, settings);
    } catch (e) {
      AppLogging.connection('🔌 MeshCore background connect: Error: $e');
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

  /// Finalize MeshCore connection by updating all state providers.
  Future<void> _finalizeMeshCoreConnect(
    DeviceInfo device,
    ConnectionResult result,
    dynamic settings,
  ) async {
    // Update connected device provider
    ref.read(connectedDeviceProvider.notifier).setState(device);

    // Parse node ID for pairing state
    final nodeIdHex = result.deviceInfo?.nodeId ?? '0';
    final nodeNumParsed = int.tryParse(nodeIdHex, radix: 16);

    // Update pairing state
    state = state.copyWith(
      state: DevicePairingState.connected,
      device: device,
      myNodeNum: nodeNumParsed,
      reason: DisconnectReason.none,
      connectionSessionId: _nextConnectionSessionId(),
    );

    // Mark as paired in the pairing helper (with MeshCore flag)
    markAsPaired(device, nodeNumParsed, isMeshCore: true);

    // Clear user disconnected flags
    _userDisconnected = false;
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);

    AppLogging.connection(
      '🔌 MeshCore background connect: Finalized, device=${result.deviceInfo?.displayName}',
    );

    // Set success state briefly then idle
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.success);

    await Future.delayed(const Duration(milliseconds: 500));
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
  }

  Future<bool> reportMissingSavedDevice() async {
    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      return true;
    }

    final now = DateTime.now();
    if (_firstMissingAttemptAt == null ||
        now.difference(_firstMissingAttemptAt!) > _invalidationWindow) {
      _firstMissingAttemptAt = now;
      _missingDeviceAttempts = 0;
    }

    _missingDeviceAttempts++;

    if (_missingDeviceAttempts >= _maxInvalidationAttempts) {
      await handlePairingInvalidation(PairingInvalidationReason.missingDevice);
      return true;
    }

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.deviceNotFound,
      errorMessage: 'Device not found',
    );

    return false;
  }

  void _resetInvalidationTracking() {
    _missingDeviceAttempts = 0;
    _firstMissingAttemptAt = null;
  }

  /// Public helper so other providers can force an invalidation.
  Future<void> handlePairingInvalidation(
    PairingInvalidationReason reason, {
    int? appleCode,
  }) async {
    await _handlePairingInvalidated(reason: reason, appleCode: appleCode);
  }

  Future<void> _handlePairingInvalidated({
    required PairingInvalidationReason reason,
    int? appleCode,
  }) async {
    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      return;
    }

    final settings = await ref.read(settingsServiceProvider.future);
    final savedDeviceId =
        state.device?.id ?? settings.lastDeviceId ?? 'unknown';
    final appleCodeLabel = appleCode?.toString() ?? 'n/a';

    AppLogging.connection(
      'PAIRING_INVALIDATED deviceId=$savedDeviceId reason=${reason.logValue} appleCode=$appleCodeLabel',
    );

    _resetInvalidationTracking();
    _backgroundScanInProgress = false;
    _scanTimer?.cancel();
    _userDisconnected = false;

    final transport = ref.read(transportProvider);
    try {
      await transport.disconnect();
    } catch (_) {
      // Ignore disconnect errors during invalidation.
    }

    await clearDeviceDataBeforeConnectRef(ref);
    await settings.clearLastDevice();
    clearSavedDeviceId(ref);
    ref.read(connectedDeviceProvider.notifier).setState(null);
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.failed);

    state = DeviceConnectionState2(
      state: DevicePairingState.pairedDeviceInvalidated,
      reason: DisconnectReason.deviceNotFound,
      errorMessage: 'Device was reset or replaced. Set it up again.',
      connectionSessionId: _connectionSessionId,
    );
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

      // Update state immediately so consumers know we're connected
      AppLogging.connection(
        'Device fully connected – allowing Go Active to enable',
      );
      state = state.copyWith(
        state: DevicePairingState.connected,
        device: device,
        lastConnectedAt: DateTime.now(),
        myNodeNum: protocol.myNodeNum,
        reason: DisconnectReason.none,
        reconnectAttempts: 0,
        connectionSessionId: _nextConnectionSessionId(),
      );

      // Update legacy providers for compatibility
      ref.read(connectedDeviceProvider.notifier).setState(device);
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.success);
      _resetInvalidationTracking();

      // Start location updates after signalling connection
      final locationService = ref.read(locationServiceProvider);
      await locationService.startLocationUpdates();

      // Mark region as configured (reconnecting to known device)
      final settings = await ref.read(settingsServiceProvider.future);
      if (!settings.regionConfigured) {
        await settings.setRegionConfigured(true);
      }
    } catch (e) {
      if (isPairingInvalidationError(e)) {
        await handlePairingInvalidation(
          PairingInvalidationReason.peerReset,
          appleCode: pairingInvalidationAppleCode(e),
        );
        rethrow;
      }

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

    // Debug: Log stack trace to identify who triggered this disconnect
    if (kDebugMode) {
      AppLogging.connection(
        '🔌 _handleDisconnect called from:\n${StackTrace.current}',
      );
    }

    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      AppLogging.connection(
        '🔌 _handleDisconnect: Saved device invalidated, ignoring',
      );
      return;
    }

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
    } else {
      // Unexpected disconnect (e.g., device reboot after region change).
      // Do NOT call startBackgroundConnection() here — the
      // autoReconnectManagerProvider listener on connectionStateProvider
      // already detects this disconnect and calls _performReconnect(),
      // which has its own scan loop with retry logic. Calling
      // startBackgroundConnection() from here creates a dual-scan race:
      // both _performReconnect's FlutterBluePlus.startScan AND
      // startBackgroundConnection's transport.scan run concurrently,
      // causing BLE contention, interleaved scan results, and
      // connection failures.
      //
      // startBackgroundConnection() is still used for app-launch
      // reconnect (called from initialize()), which is the correct
      // single-path reconnect on startup.
      AppLogging.connection(
        '🔌 _handleDisconnect: Unexpected disconnect — '
        'autoReconnectManagerProvider will handle reconnect',
      );
      // Reset retry counter so the next startBackgroundConnection
      // (if triggered by autoReconnectManager) starts fresh.
      _reconnectAttempt = 0;
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
    _retryTimer?.cancel();
    _reconnectAttempt = 0; // Reset retry counter

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

  /// Mark as paired after first successful connection from scanner.
  ///
  /// [isMeshCore] - If true, this is a MeshCore connection. The Meshtastic
  /// transport listener will NOT be set up (MeshCore uses its own transport).
  /// This prevents the immediate disconnect that occurs when the Meshtastic
  /// transport's disconnected state triggers `_handleDisconnect`.
  bool _reconciledThisSession = false;

  void markAsPaired(
    DeviceInfo device,
    int? myNodeNum, {
    bool isMeshCore = false,
  }) {
    // CRITICAL: Only set up the Meshtastic connection listener for Meshtastic devices.
    // MeshCore uses ConnectionCoordinator which manages its own transport.
    // Setting up the Meshtastic listener for MeshCore would cause immediate
    // disconnect because the Meshtastic transport is in disconnected state.
    if (!isMeshCore) {
      _setupConnectionListener();
      AppLogging.connection(
        '🔌 markAsPaired: Meshtastic device, transport listener active',
      );
    } else {
      // For MeshCore, cancel any existing Meshtastic transport listener
      // to prevent spurious disconnect events
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      AppLogging.connection(
        '🔌 markAsPaired: MeshCore device, skipping Meshtastic transport listener',
      );
    }

    // Mark as initialized so future calls don't re-run build() initialization
    _isInitialized = true;
    _userDisconnected = false;

    state = DeviceConnectionState2(
      state: DevicePairingState.connected,
      device: device,
      lastConnectedAt: DateTime.now(),
      myNodeNum: myNodeNum,
      connectionSessionId: _nextConnectionSessionId(),
    );
    _resetInvalidationTracking();

    AppLogging.connection(
      '🔌 markAsPaired: device=${device.id}, myNodeNum=$myNodeNum, isMeshCore=$isMeshCore',
    );

    // Run one-shot reconciliation for this node on connect (Meshtastic only)
    // MeshCore doesn't use the same message storage/reconciliation
    if (!isMeshCore && !_reconciledThisSession && myNodeNum != null) {
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
  final deviceState = ref.watch(deviceConnectionProvider);
  // Consider the device connected as soon as the state passes through connection
  // or configuration phases so UI can react immediately while background work
  // (location updates, feed refresh, etc.) continues.
  if (deviceState.isConnected) return true;
  if (deviceState.state == DevicePairingState.connecting ||
      deviceState.state == DevicePairingState.configuring) {
    return true;
  }
  // Also check the transport directly as a fallback - the transport may be
  // connected even if deviceConnectionProvider hasn't updated yet
  final transport = ref.watch(transportProvider);
  if (transport.isConnected) return true;
  return false;
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
