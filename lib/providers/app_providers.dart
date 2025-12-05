import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
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
  error,
}

class AppInitNotifier extends StateNotifier<AppInitState> {
  final Ref _ref;

  AppInitNotifier(this._ref) : super(AppInitState.uninitialized);

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
      await _ref.read(settingsServiceProvider.future);
      await _ref.read(messageStorageProvider.future);
      await _ref.read(nodeStorageProvider.future);

      // Initialize IFTTT service
      await _ref.read(iftttServiceProvider).init();

      // Initialize automation engine (loads automations from storage)
      await _ref.read(automationEngineInitProvider.future);

      // Check for onboarding completion
      final settings = await _ref.read(settingsServiceProvider.future);
      if (!settings.onboardingComplete) {
        state = AppInitState.needsOnboarding;
        return;
      }

      // Check for auto-reconnect settings
      final lastDeviceId = settings.lastDeviceId;
      final lastDeviceName = settings.lastDeviceName;
      final shouldAutoReconnect = settings.autoReconnect;

      if (lastDeviceId != null && shouldAutoReconnect) {
        _ref.read(autoReconnectStateProvider.notifier).state =
            AutoReconnectState.scanning;

        final transport = _ref.read(transportProvider);
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

            _ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.connecting;
            await transport.connect(lastDevice);

            // Verify connection was successful at BLE level
            if (transport.state != DeviceConnectionState.connected) {
              throw Exception('Connection failed');
            }

            // Start protocol service
            final protocol = _ref.read(protocolServiceProvider);
            debugPrint('🔵 AppInit: Calling protocol.start()...');
            await protocol.start();
            debugPrint(
              '🔵 AppInit: protocol.start() returned, myNodeNum=${protocol.myNodeNum}',
            );

            // Verify protocol actually received configuration from device
            // If PIN was cancelled or authentication failed, myNodeNum will be null
            if (protocol.myNodeNum == null) {
              debugPrint('❌ AppInit: myNodeNum is NULL - throwing exception');
              await transport.disconnect();
              throw Exception(
                'Authentication failed - no configuration received',
              );
            }

            // Start phone GPS location updates
            final locationService = _ref.read(locationServiceProvider);
            await locationService.startLocationUpdates();

            _ref.read(connectedDeviceProvider.notifier).state = lastDevice;
            debugPrint(
              '🎯 Auto-reconnect: Setting autoReconnectState to success',
            );
            _ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.success;
          } else {
            // Device not found during scan - go to scanner
            _ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.idle;
            state = AppInitState.needsScanner;
            return;
          }
        } catch (e) {
          debugPrint('Auto-reconnect failed: $e');
          _ref.read(autoReconnectStateProvider.notifier).state =
              AutoReconnectState.failed;
          // Connection failed (user cancelled PIN, timeout, etc.) - go to scanner
          state = AppInitState.needsScanner;
          return;
        }
      }

      debugPrint('🎯 AppInitNotifier: Setting state to initialized');
      state = AppInitState.initialized;
    } catch (e) {
      debugPrint('App initialization failed: $e');
      state = AppInitState.error;
    }
  }
}

final appInitProvider = StateNotifierProvider<AppInitNotifier, AppInitState>((
  ref,
) {
  return AppInitNotifier(ref);
});

// Storage services
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  final logger = ref.watch(loggerProvider);
  return SecureStorageService(logger: logger);
});

/// Settings refresh trigger - increment this to force settings UI to rebuild
final settingsRefreshProvider = StateProvider<int>((ref) => 0);

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
final transportTypeProvider = StateProvider<TransportType>((ref) {
  return TransportType.ble;
});

final transportProvider = Provider<DeviceTransport>((ref) {
  final type = ref.watch(transportTypeProvider);
  final logger = ref.watch(loggerProvider);

  switch (type) {
    case TransportType.ble:
      return BleTransport(logger: logger);
    case TransportType.usb:
      return UsbTransport(logger: logger);
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
final connectedDeviceProvider = StateProvider<DeviceInfo?>((ref) => null);

// Auto-reconnect state
enum AutoReconnectState { idle, scanning, connecting, failed, success }

final autoReconnectStateProvider = StateProvider<AutoReconnectState>((ref) {
  return AutoReconnectState.idle;
});

// Store the last known device ID for reconnection attempts
final _lastConnectedDeviceIdProvider = StateProvider<String?>((ref) => null);

// Auto-reconnect manager - monitors connection and attempts to reconnect on unexpected disconnect
final autoReconnectManagerProvider = Provider<void>((ref) {
  debugPrint('🔄 AUTO-RECONNECT MANAGER INITIALIZED');

  // Track the last connected device ID when we connect
  ref.listen<DeviceInfo?>(connectedDeviceProvider, (previous, next) {
    debugPrint(
      '🔄 connectedDeviceProvider changed: ${previous?.id} -> ${next?.id}',
    );
    if (next != null) {
      debugPrint('🔄 Storing device ID for reconnect: ${next.id}');
      ref.read(_lastConnectedDeviceIdProvider.notifier).state = next.id;
    }
  });

  // Listen for connection state changes
  ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
    previous,
    next,
  ) {
    debugPrint('🔄 connectionStateProvider changed: $previous -> $next');

    next.whenData((state) {
      final lastDeviceId = ref.read(_lastConnectedDeviceIdProvider);
      final autoReconnectState = ref.read(autoReconnectStateProvider);

      debugPrint(
        '🔄 Connection state: $state (lastDeviceId: $lastDeviceId, '
        'reconnectState: $autoReconnectState)',
      );

      // If connection comes back while we're in a reconnecting state,
      // reset to idle (the reconnect succeeded, possibly via BLE auto-reconnect)
      if (state == DeviceConnectionState.connected &&
          (autoReconnectState == AutoReconnectState.scanning ||
              autoReconnectState == AutoReconnectState.connecting)) {
        debugPrint(
          '🔄 ✅ Connection restored while reconnecting - resetting to idle',
        );
        ref.read(autoReconnectStateProvider.notifier).state =
            AutoReconnectState.idle;
        return;
      }

      // If disconnected and we have a device to reconnect to
      // Allow reconnect if state is idle OR success (just connected but not reset yet)
      final canAttemptReconnect =
          autoReconnectState == AutoReconnectState.idle ||
          autoReconnectState == AutoReconnectState.success;

      debugPrint('🔄 Can attempt reconnect: $canAttemptReconnect');

      if (state == DeviceConnectionState.disconnected &&
          lastDeviceId != null &&
          canAttemptReconnect) {
        debugPrint('🔄 🚀 Device disconnected, STARTING reconnect...');

        // Set state to scanning immediately to prevent duplicate triggers
        ref.read(autoReconnectStateProvider.notifier).state =
            AutoReconnectState.scanning;

        // Run reconnect in a separate async function to avoid listener issues
        _performReconnect(ref, lastDeviceId);
      } else {
        debugPrint('🔄 NOT attempting reconnect - conditions not met');
      }
    });
  });
});

/// Performs the actual reconnection logic
Future<void> _performReconnect(Ref ref, String deviceId) async {
  debugPrint('🔄 _performReconnect STARTED for device: $deviceId');

  try {
    // Wait for device to reboot (Meshtastic devices take ~8-15 seconds)
    debugPrint('🔄 Waiting 10s for device to reboot...');
    await Future.delayed(const Duration(seconds: 10));

    // Check if cancelled
    final currentState = ref.read(autoReconnectStateProvider);
    debugPrint('🔄 After delay, reconnect state is: $currentState');
    if (currentState == AutoReconnectState.idle) {
      debugPrint('🔄 Reconnect cancelled (state is idle)');
      return;
    }

    // Check settings for auto-reconnect preference
    debugPrint('🔄 Checking settings...');
    final settings = await ref.read(settingsServiceProvider.future);
    debugPrint('🔄 Auto-reconnect setting: ${settings.autoReconnect}');
    if (!settings.autoReconnect) {
      debugPrint('🔄 Auto-reconnect disabled in settings');
      ref.read(autoReconnectStateProvider.notifier).state =
          AutoReconnectState.idle;
      return;
    }

    final transport = ref.read(transportProvider);
    debugPrint('🔄 Got transport, current state: ${transport.state}');

    // Try up to 8 times (device may take a while to become discoverable after reboot)
    const maxRetries = 8;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      // Check if cancelled
      if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
        debugPrint('🔄 Reconnect cancelled');
        return;
      }

      debugPrint('🔄 Scan attempt $attempt/$maxRetries for device: $deviceId');

      DeviceInfo? foundDevice;

      try {
        debugPrint('🔄 Stopping any existing scan...');
        await FlutterBluePlus.stopScan();
        await Future.delayed(const Duration(milliseconds: 500));

        debugPrint('🔄 Starting fresh BLE scan...');

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

        debugPrint('🔄 Scan started, listening for results...');

        // Listen to scan results
        subscription = FlutterBluePlus.scanResults.listen(
          (results) {
            for (final r in results) {
              final foundId = r.device.remoteId.toString();
              debugPrint('🔄 Found device: $foundId (looking for $deviceId)');

              if (foundId == deviceId && !completer.isCompleted) {
                debugPrint('🔄 ✓ Target device found!');
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
            debugPrint('🔄 Scan stream error: $e');
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          },
        );

        // Also listen for scan completion
        FlutterBluePlus.isScanning.listen((isScanning) {
          if (!isScanning && !completer.isCompleted) {
            debugPrint('🔄 Scan completed (isScanning = false)');
            completer.complete(null);
          }
        });

        // Wait for result or scan completion
        debugPrint('🔄 Waiting for scan result (15s timeout)...');
        foundDevice = await completer.future.timeout(
          const Duration(seconds: 16),
          onTimeout: () {
            debugPrint('🔄 Completer timeout reached');
            return null;
          },
        );
        debugPrint('🔄 Got scan result: ${foundDevice?.id}');

        // Clean up
        await FlutterBluePlus.stopScan();
        subscription.cancel();
        debugPrint('🔄 Cleanup done');
      } catch (e, stack) {
        debugPrint('🔄 Scan error: $e');
        debugPrint('🔄 Stack: $stack');
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
      }

      debugPrint('🔄 After scan. foundDevice: ${foundDevice != null}');

      if (foundDevice != null) {
        debugPrint('🔄 Device found! Connecting...');
        ref.read(autoReconnectStateProvider.notifier).state =
            AutoReconnectState.connecting;

        try {
          await transport.connect(foundDevice);

          // Check if cancelled (connection may have been restored by another path)
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            debugPrint('🔄 Reconnect cancelled (already connected)');
            return;
          }

          // Wait a moment for connection to stabilize
          debugPrint('🔄 Waiting for connection to stabilize...');
          await Future.delayed(const Duration(seconds: 2));

          // Check if cancelled again
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            debugPrint('🔄 Reconnect cancelled (already connected)');
            return;
          }

          // Check if still connected
          if (transport.state != DeviceConnectionState.connected) {
            debugPrint('🔄 ❌ Connection dropped after connect, retrying...');
            if (attempt < maxRetries) {
              ref.read(autoReconnectStateProvider.notifier).state =
                  AutoReconnectState.scanning;
              await Future.delayed(const Duration(seconds: 3));
              continue; // Try again
            }
            throw Exception('Connection dropped after connect');
          }

          // Update connected device
          ref.read(connectedDeviceProvider.notifier).state = foundDevice;

          // Check if cancelled before starting protocol
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            debugPrint('🔄 Reconnect cancelled (already connected)');
            return;
          }

          // Restart protocol service
          debugPrint('🔄 Starting protocol service...');
          final protocol = ref.read(protocolServiceProvider);
          await protocol.start();
          debugPrint('🔄 Protocol service started!');

          // Check if cancelled after protocol start
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            debugPrint('🔄 Reconnect cancelled (already connected)');
            return;
          }

          // Check again if still connected after protocol start
          await Future.delayed(const Duration(milliseconds: 500));
          if (transport.state != DeviceConnectionState.connected) {
            debugPrint(
              '🔄 ❌ Connection dropped after protocol start, retrying...',
            );
            if (attempt < maxRetries) {
              ref.read(autoReconnectStateProvider.notifier).state =
                  AutoReconnectState.scanning;
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
            ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.success;
            debugPrint('🔄 ✅ Reconnection successful and stable!');

            // Reset to idle
            await Future.delayed(const Duration(milliseconds: 500));
            ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.idle;
            return; // Success!
          } else {
            debugPrint('🔄 ❌ Connection dropped at final check');
            if (attempt < maxRetries) {
              ref.read(autoReconnectStateProvider.notifier).state =
                  AutoReconnectState.scanning;
              await Future.delayed(const Duration(seconds: 3));
              continue;
            }
          }
        } catch (e) {
          debugPrint('🔄 ❌ Connect error: $e');
          // Check if we should abort (connection restored via another path)
          if (ref.read(autoReconnectStateProvider) == AutoReconnectState.idle) {
            debugPrint(
              '🔄 Reconnect cancelled (already connected), ignoring error',
            );
            return;
          }
          if (attempt < maxRetries) {
            ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.scanning;
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
        }
      } else {
        debugPrint('🔄 Device not found in attempt $attempt, waiting 5s...');
        if (attempt < maxRetries) {
          // Wait longer before next retry - device may still be rebooting
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }

    // All retries exhausted
    debugPrint('🔄 ❌ Failed to reconnect after $maxRetries attempts');
    ref.read(autoReconnectStateProvider.notifier).state =
        AutoReconnectState.failed;

    // Don't clear the device ID - user might want to manually reconnect
    // Just reset to idle after showing failure
    await Future.delayed(const Duration(seconds: 2));
    ref.read(autoReconnectStateProvider.notifier).state =
        AutoReconnectState.idle;
  } catch (e, stackTrace) {
    debugPrint('🔄 ❌ Unexpected error during reconnect: $e');
    debugPrint('🔄 Stack trace: $stackTrace');
    ref.read(autoReconnectStateProvider.notifier).state =
        AutoReconnectState.idle;
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

  debugPrint(
    '🟢 ProtocolService provider created - instance: ${service.hashCode}',
  );

  // Set up notification reaction callback to send emoji DMs
  NotificationService().onReactionSelected =
      (int toNodeNum, String emoji) async {
        try {
          debugPrint('🔔 Sending reaction "$emoji" to node $toNodeNum');
          await service.sendMessage(text: emoji, to: toNodeNum, wantAck: true);
          debugPrint('🔔 Reaction sent successfully');
        } catch (e) {
          debugPrint('🔔 Failed to send reaction: $e');
        }
      };

  // Keep the service alive for the lifetime of the app
  ref.onDispose(() {
    debugPrint(
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
class LiveActivityManagerNotifier extends StateNotifier<bool> {
  final LiveActivityService _liveActivityService;
  final Ref _ref;
  StreamSubscription<double>? _channelUtilSubscription;

  LiveActivityManagerNotifier(this._liveActivityService, this._ref)
    : super(false) {
    _init();
  }

  void _init() {
    // Listen for connection state changes
    _ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
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
    _ref.listen<Map<int, MeshNode>>(nodesProvider, (previous, current) {
      if (!state || !_liveActivityService.isActive) return;
      _updateFromNodes(current);
    });
  }

  Future<void> _startLiveActivity() async {
    final connectedDevice = _ref.read(connectedDeviceProvider);
    final myNodeNum = _ref.read(myNodeNumProvider);
    final nodes = _ref.read(nodesProvider);
    final protocol = _ref.read(protocolServiceProvider);

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

    // Count online nodes
    final onlineCount = nodes.values.where((n) => n.isOnline).length;

    debugPrint(
      '📱 Starting Live Activity: device=$deviceName, shortName=$shortName, '
      'battery=$batteryLevel%, rssi=$rssi, nodes=$onlineCount',
    );

    final success = await _liveActivityService.startMeshActivity(
      deviceName: deviceName,
      shortName: shortName,
      nodeNum: myNodeNum ?? 0,
      batteryLevel: batteryLevel,
      signalStrength: rssi,
      nodesOnline: onlineCount,
    );

    if (success) {
      state = true;

      // Set up telemetry listener for channel utilization updates
      _channelUtilSubscription?.cancel();
      _channelUtilSubscription = protocol.channelUtilStream.listen((
        channelUtil,
      ) {
        if (!_liveActivityService.isActive) return;

        final currentNodes = _ref.read(nodesProvider);
        final currentMyNodeNum = _ref.read(myNodeNumProvider);
        final currentNode = currentMyNodeNum != null
            ? currentNodes[currentMyNodeNum]
            : null;

        final currentOnlineCount = currentNodes.values
            .where((n) => n.isOnline)
            .length;

        _liveActivityService.updateActivity(
          batteryLevel: currentNode?.batteryLevel,
          signalStrength: currentNode?.rssi,
          nodesOnline: currentOnlineCount,
          channelUtilization: channelUtil,
        );
      });
    }
  }

  void _updateFromNodes(Map<int, MeshNode> nodes) {
    final myNodeNum = _ref.read(myNodeNumProvider);
    if (myNodeNum == null) return;

    final myNode = nodes[myNodeNum];
    if (myNode == null) return;

    final onlineCount = nodes.values.where((n) => n.isOnline).length;

    _liveActivityService.updateActivity(
      deviceName: myNode.longName,
      shortName: myNode.shortName,
      batteryLevel: myNode.batteryLevel,
      signalStrength: myNode.rssi,
      nodesOnline: onlineCount,
    );
  }

  Future<void> _endLiveActivity() async {
    _channelUtilSubscription?.cancel();
    _channelUtilSubscription = null;
    await _liveActivityService.endActivity();
    state = false;
    debugPrint('📱 Ended Live Activity - device disconnected');
  }

  @override
  void dispose() {
    _channelUtilSubscription?.cancel();
    _liveActivityService.endAllActivities();
    super.dispose();
  }
}

final liveActivityManagerProvider =
    StateNotifierProvider<LiveActivityManagerNotifier, bool>((ref) {
      final liveActivityService = ref.watch(liveActivityServiceProvider);
      return LiveActivityManagerNotifier(liveActivityService, ref);
    });

// Messages with persistence
class MessagesNotifier extends StateNotifier<List<Message>> {
  final ProtocolService _protocol;
  final MessageStorageService? _storage;
  final Ref _ref;
  final Map<int, String> _packetToMessageId = {};

  MessagesNotifier(this._protocol, this._storage, this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // Load persisted messages
    if (_storage != null) {
      final savedMessages = await _storage.loadMessages();
      if (savedMessages.isNotEmpty) {
        state = savedMessages;
        debugPrint('📨 Loaded ${savedMessages.length} messages from storage');
      }
    }

    // Listen for new messages
    _protocol.messageStream.listen((message) {
      // Skip sent messages - they're handled via optimistic UI in messaging_screen
      if (message.sent) {
        return;
      }
      state = [...state, message];
      // Persist the new message
      _storage?.saveMessage(message);

      // Trigger notification for received messages
      _notifyNewMessage(message);
    });

    // Listen for delivery status updates
    _protocol.deliveryStream.listen(_handleDeliveryUpdate);
  }

  void _notifyNewMessage(Message message) {
    debugPrint('🔔 _notifyNewMessage called for message from ${message.from}');

    // Check master notification toggle
    final settingsAsync = _ref.read(settingsServiceProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings == null) {
      debugPrint('🔔 Settings not available, skipping notification');
      return;
    }
    if (!settings.notificationsEnabled) {
      debugPrint('🔔 Notifications disabled in settings');
      return;
    }

    // Get sender name from nodes
    final nodes = _ref.read(nodesProvider);
    final senderNode = nodes[message.from];
    final senderName = senderNode?.displayName ?? 'Unknown';
    debugPrint('🔔 Sender: $senderName');

    // Check if it's a channel message or direct message
    final isChannelMessage = message.channel != null && message.channel! > 0;
    debugPrint(
      '🔔 Is channel message: $isChannelMessage (channel: ${message.channel})',
    );

    if (isChannelMessage) {
      // Check channel message setting
      if (!settings.channelMessageNotificationsEnabled) {
        debugPrint('🔔 Channel notifications disabled');
        return;
      }

      // Channel message notification
      final channels = _ref.read(channelsProvider);
      final channel = channels
          .where((c) => c.index == message.channel)
          .firstOrNull;
      final channelName = channel?.name ?? 'Channel ${message.channel}';

      debugPrint(
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
        debugPrint('🔔 DM notifications disabled');
        return;
      }

      // Direct message notification
      debugPrint('🔔 Showing DM notification from: $senderName');
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
    final engine = _ref.read(automationEngineProvider);

    String? channelName;
    if (isChannelMessage) {
      final channels = _ref.read(channelsProvider);
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
    debugPrint('🤖 Automation: Processed message from $senderName');
  }

  void _triggerIftttForMessage(
    Message message,
    String senderName,
    bool isChannelMessage,
  ) {
    final iftttService = _ref.read(iftttServiceProvider);
    debugPrint(
      'IFTTT: Checking message trigger - isActive=${iftttService.isActive}',
    );
    if (!iftttService.isActive) {
      debugPrint('IFTTT: Not active, skipping message trigger');
      return;
    }

    String? channelName;
    if (isChannelMessage) {
      final channels = _ref.read(channelsProvider);
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
    debugPrint(
      '📨 Delivery update received: packetId=${update.packetId}, '
      'delivered=${update.delivered}, error=${update.error?.message}',
    );
    debugPrint(
      '📨 Currently tracking packets: ${_packetToMessageId.keys.toList()}',
    );

    final messageId = _packetToMessageId[update.packetId];
    if (messageId == null) {
      debugPrint('📨 ❌ Delivery update for unknown packet ${update.packetId}');
      return;
    }

    final messageIndex = state.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) {
      debugPrint('📨 ❌ Delivery update for message not in state: $messageId');
      return;
    }

    final message = state[messageIndex];

    // If message is already delivered, ignore subsequent updates (especially failures)
    // This handles the case where we get ACK followed by a timeout/error packet
    if (message.status == MessageStatus.delivered) {
      debugPrint(
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
      debugPrint('📨 ✅ Message delivered, stopped tracking: $messageId');
    } else {
      debugPrint('📨 ❌ Message failed: $messageId - ${update.error?.message}');
    }
  }

  void trackPacket(int packetId, String messageId) {
    _packetToMessageId[packetId] = messageId;
    debugPrint('📨 Tracking packet $packetId -> message $messageId');
    debugPrint(
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

final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>(
  (ref) {
    final protocol = ref.watch(protocolServiceProvider);
    final storageAsync = ref.watch(messageStorageProvider);
    final storage = storageAsync.valueOrNull;
    return MessagesNotifier(protocol, storage, ref);
  },
);

// Nodes
class NodesNotifier extends StateNotifier<Map<int, MeshNode>> {
  final ProtocolService _protocol;
  final NodeStorageService? _storage;
  final Ref _ref;

  NodesNotifier(this._protocol, this._storage, this._ref) : super({}) {
    _init();
  }

  Future<void> _init() async {
    // Load persisted nodes (with their positions) first
    if (_storage != null) {
      final savedNodes = await _storage.loadNodes();
      if (savedNodes.isNotEmpty) {
        debugPrint('📍 Loaded ${savedNodes.length} nodes from storage');
        final nodeMap = <int, MeshNode>{};
        for (final node in savedNodes) {
          nodeMap[node.nodeNum] = node;
          if (node.hasPosition) {
            debugPrint(
              '📍 Node ${node.nodeNum} has stored position: ${node.latitude}, ${node.longitude}',
            );
          }
        }
        state = nodeMap;
      }
    }

    // Then merge with existing nodes from protocol service
    // Protocol nodes take precedence but preserve stored positions if new nodes don't have them
    final protocolNodes = Map<int, MeshNode>.from(_protocol.nodes);
    for (final entry in protocolNodes.entries) {
      var node = entry.value;
      final existing = state[entry.key];
      // If protocol node has no position but stored node does, preserve stored position
      if (!node.hasPosition && existing != null && existing.hasPosition) {
        node = node.copyWith(
          latitude: existing.latitude,
          longitude: existing.longitude,
          altitude: existing.altitude,
        );
      }
      state = {...state, entry.key: node};
    }

    // Listen for new nodes
    _protocol.nodeStream.listen((node) {
      final isNewNode = !state.containsKey(node.nodeNum);
      final existing = state[node.nodeNum];

      // Preserve position from storage if new node doesn't have one
      if (!node.hasPosition && existing != null && existing.hasPosition) {
        node = node.copyWith(
          latitude: existing.latitude,
          longitude: existing.longitude,
          altitude: existing.altitude,
        );
      }

      state = {...state, node.nodeNum: node};

      // Persist node to storage
      _storage?.saveNode(node);

      // Increment new nodes counter if this is a genuinely new node
      if (isNewNode) {
        _ref.read(newNodesCountProvider.notifier).state++;
        // Trigger notification for new node discovery
        _ref.read(nodeDiscoveryNotifierProvider.notifier).notifyNewNode(node);
      }

      // Trigger IFTTT webhook for node updates
      _triggerIftttForNode(node, existing);

      // Trigger automation engine for node updates
      _triggerAutomationForNode(node, existing);
    });
  }

  void _triggerIftttForNode(MeshNode node, MeshNode? previousNode) {
    final iftttService = _ref.read(iftttServiceProvider);
    if (!iftttService.isActive) return;

    iftttService.processNodeUpdate(node, previousNode: previousNode);
  }

  void _triggerAutomationForNode(MeshNode node, MeshNode? previousNode) {
    final engine = _ref.read(automationEngineProvider);
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
  }

  void clearNodes() {
    state = {};
    _storage?.clearNodes();
  }
}

final nodesProvider = StateNotifierProvider<NodesNotifier, Map<int, MeshNode>>((
  ref,
) {
  final protocol = ref.watch(protocolServiceProvider);
  final storageAsync = ref.watch(nodeStorageProvider);
  final storage = storageAsync.valueOrNull;
  return NodesNotifier(protocol, storage, ref);
});

// Channels
class ChannelsNotifier extends StateNotifier<List<ChannelConfig>> {
  final ProtocolService _protocol;

  ChannelsNotifier(this._protocol) : super([]) {
    debugPrint(
      '🔵 ChannelsNotifier constructor - protocol has ${_protocol.channels.length} channels',
    );
    for (var c in _protocol.channels) {
      debugPrint(
        '  Channel ${c.index}: name="${c.name}", psk.length=${c.psk.length}',
      );
    }

    // Initialize with existing channels (include Primary, exclude DISABLED)
    state = _protocol.channels
        .where((c) => c.index == 0 || c.role != 'DISABLED')
        .toList();
    debugPrint('🔵 ChannelsNotifier initialized with ${state.length} channels');

    // Listen for future channel updates
    _protocol.channelStream.listen((channel) {
      debugPrint(
        '🔵 ChannelsNotifier received channel update: index=${channel.index}, name="${channel.name}"',
      );
      final index = state.indexWhere((c) => c.index == channel.index);
      if (index >= 0) {
        debugPrint('  Updating existing channel at position $index');
        state = [
          ...state.sublist(0, index),
          channel,
          ...state.sublist(index + 1),
        ];
      } else {
        debugPrint('  Adding new channel');
        state = [...state, channel];
      }
      debugPrint('  Total channels now: ${state.length}');
    });
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
    StateNotifierProvider<ChannelsNotifier, List<ChannelConfig>>((ref) {
      final protocol = ref.watch(protocolServiceProvider);
      return ChannelsNotifier(protocol);
    });

// My node number - updates when received from device
class MyNodeNumNotifier extends StateNotifier<int?> {
  final ProtocolService _protocol;

  MyNodeNumNotifier(this._protocol) : super(null) {
    // Initialize with existing myNodeNum from protocol service
    state = _protocol.myNodeNum;

    _protocol.myNodeNumStream.listen((nodeNum) {
      state = nodeNum;
    });
  }
}

final myNodeNumProvider = StateNotifierProvider<MyNodeNumNotifier, int?>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  return MyNodeNumNotifier(protocol);
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
final newNodesCountProvider = StateProvider<int>((ref) => 0);

/// Node discovery notifier - triggers notifications when new nodes are found
class NodeDiscoveryNotifier extends StateNotifier<MeshNode?> {
  final NotificationService _notificationService;
  final Ref _ref;

  NodeDiscoveryNotifier(this._notificationService, this._ref) : super(null);

  Future<void> notifyNewNode(MeshNode node) async {
    // Always update state to trigger UI animations (discovery cards)
    state = node;

    // Only show local notifications when app is fully initialized (not during startup/connecting)
    final appState = _ref.read(appInitProvider);
    if (appState != AppInitState.initialized) return;

    // Check master notification toggle and new node setting
    final settingsAsync = _ref.read(settingsServiceProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings == null) return;
    if (!settings.notificationsEnabled) return;
    if (!settings.newNodeNotificationsEnabled) return;

    await _notificationService.showNewNodeNotification(
      node,
      playSound: settings.notificationSoundEnabled,
      vibrate: settings.notificationVibrationEnabled,
    );
  }
}

final nodeDiscoveryNotifierProvider =
    StateNotifierProvider<NodeDiscoveryNotifier, MeshNode?>((ref) {
      return NodeDiscoveryNotifier(NotificationService(), ref);
    });

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
