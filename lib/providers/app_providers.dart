import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../core/logging.dart';
import '../core/transport.dart';
import '../services/transport/ble_transport.dart';
import '../services/transport/usb_transport.dart';
import '../services/protocol/protocol_service.dart';
import '../services/storage/storage_service.dart';
import '../services/notifications/notification_service.dart';
import '../services/messaging/offline_queue_service.dart';
import '../services/location/location_service.dart';
import '../services/live_activity/live_activity_service.dart';
import '../services/ifttt/ifttt_service.dart';
import '../features/automations/automation_providers.dart';
import '../features/automations/automation_engine.dart';
import '../models/mesh_models.dart';
import '../generated/meshtastic/mesh.pbenum.dart' as pbenum;

// Logger
final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
});

// App initialization state
enum AppInitState {
  uninitialized,
  initializing,
  initialized,
  needsOnboarding,
  needsScanner, // Auto-reconnect failed or no saved device
  needsRegionSetup, // Connected but region not configured
  error,
}

class AppInitNotifier extends Notifier<AppInitState> {
  @override
  AppInitState build() => AppInitState.uninitialized;

  /// Manually set state to initialized (e.g., after successful connection from scanner)
  void setInitialized() {
    state = AppInitState.initialized;
  }

  /// Set state to needsScanner (e.g., user skipped auto-reconnect)
  void setNeedsScanner() {
    state = AppInitState.needsScanner;
  }

  Future<void> initialize() async {
    if (state == AppInitState.initializing) return;

    state = AppInitState.initializing;
    try {
      // Initialize notification service
      await NotificationService().initialize();

      // Initialize storage services
      await ref.read(settingsServiceProvider.future);
      await ref.read(messageStorageProvider.future);
      await ref.read(nodeStorageProvider.future);

      // Initialize IFTTT service
      await ref.read(iftttServiceProvider).init();

      // Initialize automation engine (loads automations from storage)
      await ref.read(automationEngineInitProvider.future);

      // Check for onboarding completion
      final settings = await ref.read(settingsServiceProvider.future);
      if (!settings.onboardingComplete) {
        state = AppInitState.needsOnboarding;
        return;
      }

      // Check for auto-reconnect settings
      final lastDeviceId = settings.lastDeviceId;
      final lastDeviceName = settings.lastDeviceName;
      final shouldAutoReconnect = settings.autoReconnect;

      if (lastDeviceId != null && shouldAutoReconnect) {
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.scanning);

        final transport = ref.read(transportProvider);
        try {
          DeviceInfo? lastDevice;

          // Scan for devices and try to find the last connected one
          await for (final device in transport.scan(
            timeout: const Duration(seconds: 5),
          )) {
            if (device.id == lastDeviceId) {
              lastDevice = device;
              break;
            }
          }

          if (lastDevice != null) {
            // Use stored name if scan didn't provide one
            if (lastDevice.name.isEmpty || lastDevice.name == 'Unknown') {
              lastDevice = DeviceInfo(
                id: lastDevice.id,
                name: lastDeviceName ?? lastDevice.name,
                type: lastDevice.type,
                rssi: lastDevice.rssi,
              );
            }

            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.connecting);
            await transport.connect(lastDevice);

            // Verify connection was successful at BLE level
            if (transport.state != DeviceConnectionState.connected) {
              throw Exception('Connection failed');
            }

            // Start protocol service
            final protocol = ref.read(protocolServiceProvider);
            AppLogging.app('AppInit: Calling protocol.start()...');

            // Set device info for hardware model inference
            protocol.setDeviceName(lastDevice.name);
            protocol.setBleModelNumber(transport.bleModelNumber);
            protocol.setBleManufacturerName(transport.bleManufacturerName);

            await protocol.start();
            AppLogging.debug(
              '🔵 AppInit: protocol.start() returned, myNodeNum=${protocol.myNodeNum}',
            );

            // Verify protocol actually received configuration from device
            // If PIN was cancelled or authentication failed, myNodeNum will be null
            if (protocol.myNodeNum == null) {
              AppLogging.debug(
                '❌ AppInit: myNodeNum is NULL - throwing exception',
              );
              await transport.disconnect();
              throw Exception(
                'Authentication failed - no configuration received',
              );
            }

            // Start phone GPS location updates
            final locationService = ref.read(locationServiceProvider);
            await locationService.startLocationUpdates();

            ref.read(connectedDeviceProvider.notifier).setState(lastDevice);
            AppLogging.debug(
              '🎯 Auto-reconnect: Setting autoReconnectState to success',
            );
            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.success);

            // Skip region check entirely during auto-reconnect
            // If we have a lastConnectedDeviceId, user has successfully connected before
            // The region was either already set on device or user configured it previously
            // Forcing region selection on every reconnect is wrong - the device retains its config
            AppLogging.debug(
              '✅ Auto-reconnect: Skipping region check (reconnecting to known device)',
            );

            // Mark region as configured since we're reconnecting to a known device
            if (!settings.regionConfigured) {
              await settings.setRegionConfigured(true);
              AppLogging.debug('✅ Auto-reconnect: Marked region as configured');
            }
          } else {
            // Device not found during scan - go to scanner
            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.idle);
            state = AppInitState.needsScanner;
            return;
          }
        } catch (e) {
          AppLogging.debug('Auto-reconnect failed: $e');
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.failed);
          // Connection failed (user cancelled PIN, timeout, etc.) - go to scanner
          state = AppInitState.needsScanner;
          return;
        }
      }

      AppLogging.debug('🎯 AppInitNotifier: Setting state to initialized');
      state = AppInitState.initialized;
    } catch (e) {
      AppLogging.debug('App initialization failed: $e');
      state = AppInitState.error;
    }
  }
}

/// Check data integrity after connection and clear stale data if needed.
final appInitProvider = NotifierProvider<AppInitNotifier, AppInitState>(
  AppInitNotifier.new,
);

// Storage services
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  final logger = ref.watch(loggerProvider);
  return SecureStorageService(logger: logger);
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

/// Cached settings service instance
SettingsService? _cachedSettingsService;

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  // Watch the refresh trigger to rebuild when settings change
  ref.watch(settingsRefreshProvider);

  // Return cached instance if available (already initialized)
  if (_cachedSettingsService != null) {
    return _cachedSettingsService!;
  }
  final logger = ref.watch(loggerProvider);

  final service = SettingsService(logger: logger);
  await service.init();
  _cachedSettingsService = service;
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

// Message storage service
final messageStorageProvider = FutureProvider<MessageStorageService>((
  ref,
) async {
  final logger = ref.watch(loggerProvider);
  final service = MessageStorageService(logger: logger);
  await service.init();
  return service;
});

// Node storage service - persists nodes and positions
final nodeStorageProvider = FutureProvider<NodeStorageService>((ref) async {
  final logger = ref.watch(loggerProvider);
  final service = NodeStorageService(logger: logger);
  await service.init();
  return service;
});

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
enum AutoReconnectState { idle, scanning, connecting, failed, success }

class AutoReconnectStateNotifier extends Notifier<AutoReconnectState> {
  @override
  AutoReconnectState build() => AutoReconnectState.idle;

  void setState(AutoReconnectState newState) => state = newState;
}

final autoReconnectStateProvider =
    NotifierProvider<AutoReconnectStateNotifier, AutoReconnectState>(
      AutoReconnectStateNotifier.new,
    );

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

      AppLogging.debug(
        '🔄 Connection state: $state (lastDeviceId: $lastDeviceId, '
        'reconnectState: $autoReconnectState)',
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
    // Wait for device to reboot (Meshtastic devices take ~8-15 seconds)
    AppLogging.connection('Waiting 10s for device to reboot...');
    await Future.delayed(const Duration(seconds: 10));

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
      // Check if cancelled
      if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
        AppLogging.connection('Reconnect cancelled');
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

// Protocol service - singleton instance that persists across rebuilds
final protocolServiceProvider = Provider<ProtocolService>((ref) {
  final transport = ref.watch(transportProvider);
  final logger = ref.watch(loggerProvider);
  final service = ProtocolService(transport, logger: logger);

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

    // Count online and total nodes
    final onlineCount = nodes.values.where((n) => n.isOnline).length;
    final totalCount = nodes.length;

    // Find nearest node with distance
    final nearestNode = _findNearestNode(nodes, myNodeNum);

    AppLogging.debug(
      '📱 Starting Live Activity: device=$deviceName, shortName=$shortName, '
      'battery=$batteryLevel%, rssi=$rssi, snr=$snr, nodes=$onlineCount/$totalCount',
    );

    final success = await _liveActivityService.startMeshActivity(
      deviceName: deviceName,
      shortName: shortName,
      nodeNum: myNodeNum ?? 0,
      batteryLevel: batteryLevel,
      signalStrength: rssi,
      snr: snr,
      nodesOnline: onlineCount,
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

        final currentOnlineCount = currentNodes.values
            .where((n) => n.isOnline)
            .length;

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

    final onlineCount = nodes.values.where((n) => n.isOnline).length;
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
  MessageStorageService? _storage;

  @override
  List<Message> build() {
    final protocol = ref.watch(protocolServiceProvider);
    final storageAsync = ref.watch(messageStorageProvider);
    _storage = storageAsync.value;

    // Initialize asynchronously
    _init(protocol);

    return [];
  }

  Future<void> _init(ProtocolService protocol) async {
    // Load persisted messages
    if (_storage != null) {
      final savedMessages = await _storage!.loadMessages();
      if (savedMessages.isNotEmpty) {
        state = savedMessages;
        AppLogging.messages(
          'Loaded ${savedMessages.length} messages from storage',
        );
      }
    }

    // Listen for new messages
    protocol.messageStream.listen((message) {
      // For sent messages, check if they're already in state (from optimistic UI)
      // If not (e.g., from automations, app intents, reactions), we need to add them
      if (message.sent) {
        // Check if this message is already tracked (from optimistic UI in messaging_screen)
        // Match by id, or by packetId if both are non-null
        final existingMessage = state.where((m) {
          if (m.id == message.id) return true;
          if (m.packetId != null &&
              message.packetId != null &&
              m.packetId == message.packetId) {
            return true;
          }
          return false;
        }).firstOrNull;
        if (existingMessage != null) {
          // Already tracked via optimistic UI, skip to avoid duplicates
          return;
        }
        // Not tracked - this is from automation or other background send
        // Add it to state and persist
        state = [...state, message];
        _storage?.saveMessage(message);

        // Track the packet for delivery updates if it has a packetId and messageId
        // This ensures background-sent messages (Siri, automations, etc.) get delivery status updates
        if (message.packetId != null && message.id.isNotEmpty) {
          trackPacket(message.packetId!, message.id);
        }
        return;
      }
      state = [...state, message];
      // Persist the new message
      _storage?.saveMessage(message);

      // Trigger notification for received messages
      _notifyNewMessage(message);
    });

    // Listen for delivery status updates
    protocol.deliveryStream.listen(_handleDeliveryUpdate);
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

    // Get sender name from nodes
    final nodes = ref.read(nodesProvider);
    final senderNode = nodes[message.from];
    final senderName = senderNode?.displayName ?? 'Unknown';
    AppLogging.app('Sender: $senderName');

    // Check if it's a channel message or direct message
    final isChannelMessage = message.channel != null && message.channel! > 0;
    AppLogging.debug(
      '🔔 Is channel message: $isChannelMessage (channel: ${message.channel})',
    );

    if (isChannelMessage) {
      // Check channel message setting
      if (!settings.channelMessageNotificationsEnabled) {
        AppLogging.app('Channel notifications disabled');
        return;
      }

      // Channel message notification
      final channels = ref.read(channelsProvider);
      final channel = channels
          .where((c) => c.index == message.channel)
          .firstOrNull;
      final channelName = channel?.name ?? 'Channel ${message.channel}';

      AppLogging.debug(
        '🔔 Showing channel notification: $senderName in $channelName',
      );
      NotificationService().showChannelMessageNotification(
        senderName: senderName,
        senderShortName: senderNode?.shortName,
        channelName: channelName,
        message: message.text,
        channelIndex: message.channel!,
        fromNodeNum: message.from,
        playSound: settings.notificationSoundEnabled,
        vibrate: settings.notificationVibrationEnabled,
      );
    } else {
      // Check direct message setting
      if (!settings.directMessageNotificationsEnabled) {
        AppLogging.app('DM notifications disabled');
        return;
      }

      // Direct message notification
      AppLogging.app('Showing DM notification from: $senderName');
      NotificationService().showNewMessageNotification(
        senderName: senderName,
        senderShortName: senderNode?.shortName,
        message: message.text,
        fromNodeNum: message.from,
        playSound: settings.notificationSoundEnabled,
        vibrate: settings.notificationVibrationEnabled,
      );
    }

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
    // Check for duplicate by ID to prevent optimistic UI + stream double-add
    if (state.any((m) => m.id == message.id)) {
      return;
    }
    state = [...state, message];
    _storage?.saveMessage(message);
  }

  void updateMessage(String messageId, Message updatedMessage) {
    state = state.map((m) => m.id == messageId ? updatedMessage : m).toList();
    _storage?.saveMessage(updatedMessage);
  }

  void clearMessages() {
    state = [];
    _storage?.clearMessages();
  }

  List<Message> getMessagesForNode(int nodeNum) {
    return state.where((m) => m.from == nodeNum || m.to == nodeNum).toList();
  }
}

final messagesProvider = NotifierProvider<MessagesNotifier, List<Message>>(
  MessagesNotifier.new,
);

// Nodes
class NodesNotifier extends Notifier<Map<int, MeshNode>> {
  Timer? _stalenessTimer;
  NodeStorageService? _storage;

  /// Timeout after which a node is considered offline (15 minutes)
  /// The iOS Meshtastic app uses 120 minutes, but we use 15 minutes as a
  /// reasonable compromise that's responsive while accounting for nodes
  /// that don't send packets frequently.
  static const _offlineTimeoutMinutes = 15;

  @override
  Map<int, MeshNode> build() {
    final protocol = ref.watch(protocolServiceProvider);
    final storageAsync = ref.watch(nodeStorageProvider);
    _storage = storageAsync.value;

    // Set up disposal
    ref.onDispose(() {
      _stalenessTimer?.cancel();
    });

    // Initialize asynchronously
    _init(protocol);

    return {};
  }

  Future<void> _init(ProtocolService protocol) async {
    // Load persisted nodes (with their positions) first
    if (_storage != null) {
      final savedNodes = await _storage!.loadNodes();
      if (savedNodes.isNotEmpty) {
        AppLogging.nodes('Loaded ${savedNodes.length} nodes from storage');
        final nodeMap = <int, MeshNode>{};
        for (final node in savedNodes) {
          nodeMap[node.nodeNum] = node;
          if (node.hasPosition) {
            AppLogging.debug(
              '📍 Node ${node.nodeNum} has stored position: ${node.latitude}, ${node.longitude}',
            );
          }
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
          // Always preserve user preferences from storage
          isFavorite: existing.isFavorite,
          isIgnored: existing.isIgnored,
        );
      }
      state = {...state, entry.key: node};
    }

    // Start periodic staleness check (every 30 seconds)
    _stalenessTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkNodeStaleness(),
    );

    // Listen for new nodes
    protocol.nodeStream.listen((node) {
      final isNewNode = !state.containsKey(node.nodeNum);
      final existing = state[node.nodeNum];

      if (existing != null) {
        // Preserve stored properties that don't come from protocol
        node = node.copyWith(
          // Preserve position if new node doesn't have one
          latitude: node.hasPosition ? node.latitude : existing.latitude,
          longitude: node.hasPosition ? node.longitude : existing.longitude,
          altitude: node.hasPosition ? node.altitude : existing.altitude,
          // Always preserve user preferences from storage
          isFavorite: existing.isFavorite,
          isIgnored: existing.isIgnored,
        );
      }

      state = {...state, node.nodeNum: node};

      // Persist node to storage
      _storage?.saveNode(node);

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
    });
  }

  /// Check all nodes for staleness and trigger automation/IFTTT if node went offline
  /// Note: isOnline is now a computed property based on lastHeard (120min threshold)
  /// This method triggers side effects when a node transitions to offline
  void _checkNodeStaleness() {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(minutes: _offlineTimeoutMinutes));

    for (final entry in state.entries) {
      final node = entry.value;
      // Skip nodes that are already offline or have no lastHeard
      if (node.lastHeard == null) continue;

      // Check if node just went stale (hasn't been heard from in _offlineTimeoutMinutes)
      // and trigger automations for the offline transition
      if (node.lastHeard!.isBefore(cutoff) && !node.isOnline) {
        AppLogging.debug(
          '⚠️ Node ${node.displayName} (${node.nodeNum}) is offline - '
          'last heard ${now.difference(node.lastHeard!).inMinutes}m ago',
        );

        // Trigger automation/IFTTT for the offline transition
        _triggerIftttForNode(node, node);
        _triggerAutomationForNode(node, node);

        // Persist the updated node (to update lastHeard if needed)
        _storage?.saveNode(node);
      }
    }
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
    state = {...state, node.nodeNum: node};
    _storage?.saveNode(node);
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
  @override
  List<ChannelConfig> build() {
    final protocol = ref.watch(protocolServiceProvider);

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
    protocol.channelStream.listen((channel) {
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
  @override
  int? build() {
    final protocol = ref.watch(protocolServiceProvider);

    // Initialize with existing myNodeNum from protocol service
    final initial = protocol.myNodeNum;

    // Listen for updates
    protocol.myNodeNumStream.listen((nodeNum) {
      state = nodeNum;
    });

    return initial;
  }
}

final myNodeNumProvider = NotifierProvider<MyNodeNumNotifier, int?>(
  MyNodeNumNotifier.new,
);

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

    // Only show local notifications when app is fully initialized (not during startup/connecting)
    final appState = ref.read(appInitProvider);
    if (appState != AppInitState.initialized) return;

    // Check master notification toggle and new node setting
    final settingsAsync = ref.read(settingsServiceProvider);
    final settings = settingsAsync.value;
    if (settings == null) return;
    if (!settings.notificationsEnabled) return;
    if (!settings.newNodeNotificationsEnabled) return;

    await NotificationService().showNewNodeNotification(
      node,
      playSound: settings.notificationSoundEnabled,
      vibrate: settings.notificationVibrationEnabled,
    );
  }
}

final nodeDiscoveryNotifierProvider =
    NotifierProvider<NodeDiscoveryNotifier, MeshNode?>(
      NodeDiscoveryNotifier.new,
    );

/// Current device region - stream that emits region updates
final deviceRegionProvider = StreamProvider<pbenum.RegionCode>((ref) async* {
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

/// Needs region setup - true if region is UNSET
final needsRegionSetupProvider = Provider<bool>((ref) {
  final regionAsync = ref.watch(deviceRegionProvider);
  return regionAsync.whenOrNull(
        data: (region) => region == pbenum.RegionCode.UNSET_REGION,
      ) ??
      false;
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
